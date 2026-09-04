-- HCOneButton local adaptive priority learner.
-- Learns only from eligible per-character telemetry and applies small bounded
-- score corrections to offensive candidates. Survival gates and protected
-- execution remain entirely owned by the normal Advisor engine.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

HCOB.Systems.AdaptiveTuner = HCOB.Systems.AdaptiveTuner or {}
local A = HCOB.Systems.AdaptiveTuner

A.SCHEMA_VERSION = 2
A.REVISION = 2
A.MIN_CONTEXT_FIGHTS = 8
A.MIN_ARM_FIGHTS = 4
A.MAX_SCORE_BIAS = 4
A.MAX_CONTEXTS = 24
A.MAX_ARMS_PER_CONTEXT = 64

local TUNABLE_TAGS = {
    damage=true, dot=true, finisher=true, aoe=true, burst=true,
    efficiency=true, sustain=true, weave=true, core=true, dump=true,
    setup=true,
}

local function Finite(value, fallback)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return fallback end
    return value
end

local function Bound(value, low, high)
    value = Finite(value, low) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

local function RoundQuarter(value)
    if value >= 0 then return math.floor(value * 4 + 0.5) / 4 end
    return math.ceil(value * 4 - 0.5) / 4
end

local function Count(values)
    local result = 0
    for _ in pairs(values or {}) do result = result + 1 end
    return result
end

local function Now()
    return (GetServerTime and GetServerTime()) or (time and time()) or 0
end

local function Store()
    if type(HCOB_CharacterDB) ~= "table" then return nil end
    if type(HCOB_CharacterDB.adaptive) ~= "table" then HCOB_CharacterDB.adaptive = {} end
    local store = HCOB_CharacterDB.adaptive
    local version = Finite(store.version, nil)
    if not version or version < A.SCHEMA_VERSION then
        store.version = A.SCHEMA_VERSION
        store.enabled = true
        store.contexts = type(store.contexts) == "table" and store.contexts or {}
        store.upgradedAt = Now()
    end
    if type(store.enabled) ~= "boolean" then store.enabled = true end
    if store.viewProfile ~= "pvp" then store.viewProfile = "pve" end
    if type(store.contexts) ~= "table" then store.contexts = {} end
    store.totalEligible = math.max(0, math.floor(Finite(store.totalEligible, 0) or 0))
    return store
end

local function ContextKey(context, talentSignature)
    if type(context) ~= "table" then return nil end
    local telemetry = HCOB.Systems and HCOB.Systems.TuningTelemetry
    local hash = telemetry and telemetry.HashParts
    local level = math.max(1, math.floor(Finite(context.level, 1) or 1))
    local levelBand = math.floor((level - 1) / 5) * 5 + 1
    local parts = {
        "adaptive1", context.class or PLAYER_CLASS or "?", context.specIndex or 0,
        context.mode or "solo", levelBand, talentSignature or context.talentSignature or "?",
        context.spellbookSignature or "?",
    }
    if hash then return hash(parts), levelBand end
    return table.concat(parts, ":"), levelBand
end

local function FindContext(store, telemetryContext)
    local key, levelBand = ContextKey(telemetryContext)
    local context = key and store.contexts[key]
    if type(context) == "table" then return context, key, levelBand, key end
    local latest, latestKey, latestAt
    local aliases = telemetryContext and telemetryContext.legacyTalentSignatures
    if type(aliases) == "table" then
        for index=1,math.min(5, #aliases) do
            local oldKey = ContextKey(telemetryContext, aliases[index])
            local old = oldKey and store.contexts[oldKey]
            if type(old) == "table" then
                local seen = Finite(old.lastSeenAt, 0) or 0
                if not latest or seen > latestAt or (seen == latestAt and oldKey < latestKey) then
                    latest, latestKey, latestAt = old, oldKey, seen
                end
            end
        end
    end
    return latest, key, levelBand, latestKey
end

local function CandidateKey(spellId, tag)
    local telemetry = HCOB.Systems and HCOB.Systems.TuningTelemetry
    if telemetry and telemetry.CandidateKey then return telemetry.CandidateKey(spellId, tag) end
    return tostring(tonumber(spellId) or spellId or "none") .. ":" .. tostring(tag or "action")
end

local function DifficultyKey(context)
    context = context or {}
    local classification = tostring(context.targetClassification or "normal")
    if classification == "elite" or classification == "rareelite" or classification == "worldboss" then return "elite" end
    local playerLevel = Finite(context.level, 1) or 1
    local targetLevel = Finite(context.targetLevel, playerLevel) or playerLevel
    local delta = targetLevel - playerLevel
    if delta <= -2 then return "easy" end
    if delta >= 2 then return "hard" end
    return "even"
end

local function EvictOldestContext(store)
    if Count(store.contexts) < A.MAX_CONTEXTS then return end
    local oldestKey, oldestAt
    for key, context in pairs(store.contexts) do
        local seen = type(context) == "table" and (Finite(context.lastSeenAt, 0) or 0) or -1
        if not oldestAt or seen < oldestAt or (seen == oldestAt and tostring(key) < tostring(oldestKey)) then
            oldestKey, oldestAt = key, seen
        end
    end
    if oldestKey then store.contexts[oldestKey] = nil end
end

local function EnsureContext(store, telemetryContext)
    local context, key, levelBand, storedKey = FindContext(store, telemetryContext)
    if not key then return nil, nil end
    if context and storedKey ~= key then
        -- Re-key the latest compatible legacy context; preserve its evidence,
        -- notifications and counters. Other archived contexts are not merged.
        store.contexts[key], store.contexts[storedKey] = context, nil
        if store.lastContextKey == storedKey then store.lastContextKey = key end
    end
    if type(context) ~= "table" then
        EvictOldestContext(store)
        context = {
            version=1, class=telemetryContext.class or PLAYER_CLASS,
            specIndex=Finite(telemetryContext.specIndex, 0) or 0,
            mode=telemetryContext.mode or "solo", levelBand=levelBand,
            fights=0, rewardAverage=0, survivalAverage=0,
            arms={}, baselines={}, createdAt=Now(), lastSeenAt=Now(),
        }
        store.contexts[key] = context
    end
    if type(context.arms) ~= "table" then context.arms = {} end
    if type(context.baselines) ~= "table" then context.baselines = {} end
    context.fights = math.max(0, math.floor(Finite(context.fights, 0) or 0))
    context.rewardAverage = Bound(context.rewardAverage, 0, 1)
    context.survivalAverage = Bound(context.survivalAverage, 0, 1)
    for armKey, arm in pairs(context.arms) do
        if type(arm) ~= "table" then context.arms[armKey] = nil end
    end
    context.lastSeenAt = Now()
    return context, key
end

local function EnsureArm(context, key, source)
    local arm = context.arms[key]
    if type(arm) ~= "table" then
        if Count(context.arms) >= A.MAX_ARMS_PER_CONTEXT then return nil end
        arm = {
            spellId=source and source.spellId or nil, tag=source and source.tag or "action",
            title=source and source.title or nil, fights=0, opportunities=0,
            accepted=0, userOverrides=0, offers=0, rewardAverage=0, survivalAverage=0, bias=0,
        }
        context.arms[key] = arm
    end
    arm.fights = math.max(0, math.floor(Finite(arm.fights, 0) or 0))
    arm.opportunities = math.max(0, Finite(arm.opportunities, 0) or 0)
    arm.accepted = math.max(0, Finite(arm.accepted, 0) or 0)
    arm.userOverrides = math.max(0, Finite(arm.userOverrides, 0) or 0)
    arm.offers = math.max(0, Finite(arm.offers, 0) or 0)
    arm.rewardAverage = Bound(arm.rewardAverage, 0, 1)
    arm.survivalAverage = Bound(arm.survivalAverage, 0, 1)
    arm.dpsIndexAverage = Bound(arm.dpsIndexAverage, 0, 1)
    arm.bias = Bound(arm.bias, -A.MAX_SCORE_BIAS, A.MAX_SCORE_BIAS)
    return arm
end

local function EWMA(previous, value, samples, alpha)
    if samples <= 1 then return value end
    return previous + (value - previous) * alpha
end

local function FightReward(fight, context)
    local telemetryContext = fight.tuning and fight.tuning.context or {}
    local difficulty = DifficultyKey(telemetryContext)
    local baseline = context.baselines[difficulty]
    if type(baseline) ~= "table" then baseline = {fights=0, dpsAverage=0}; context.baselines[difficulty] = baseline end
    baseline.fights = math.max(0, math.floor(Finite(baseline.fights, 0) or 0))
    baseline.dpsAverage = math.max(0, Finite(baseline.dpsAverage, 0) or 0)

    local dps = math.max(0, Finite(fight.dps, 0) or 0)
    local baselineDps = Finite(baseline.dpsAverage, 0) or 0
    local dpsIndex = baseline.fights >= 3 and Bound((dps / math.max(0.1, baselineDps) - 0.65) / 0.70, 0, 1) or 0.5
    local hpFloor = Finite(fight.hpMinPct, 100) or 100
    local survival = Bound((hpFloor - 20) / 75, 0, 1)
    local reward = dpsIndex * 0.65 + survival * 0.35

    baseline.fights = (baseline.fights or 0) + 1
    baseline.dpsAverage = EWMA(baselineDps, dps, baseline.fights, 0.16)
    baseline.lastSeenAt = Now()
    return reward, survival, dpsIndex, difficulty
end

local function RecomputeBiases(context)
    local active = 0
    for _, arm in pairs(context.arms or {}) do
        local bias = 0
        if type(arm) == "table" and TUNABLE_TAGS[arm.tag]
           and (Finite(context.fights, 0) or 0) >= A.MIN_CONTEXT_FIGHTS
           and (Finite(arm.fights, 0) or 0) >= A.MIN_ARM_FIGHTS then
            local rewardDelta = (Finite(arm.rewardAverage, 0) or 0) - (Finite(context.rewardAverage, 0) or 0)
            local safetyDelta = (Finite(arm.survivalAverage, 0) or 0) - (Finite(context.survivalAverage, 0) or 0)
            local confidence = Bound(((Finite(arm.fights, 0) or 0) - A.MIN_ARM_FIGHTS + 1) / 8, 0, 1)
            local raw = rewardDelta * 12
            if safetyDelta < -0.08 then raw = math.min(raw, safetyDelta * 14) end
            if math.abs(raw) < 0.35 then raw = 0 end
            bias = RoundQuarter(Bound(raw * confidence, -A.MAX_SCORE_BIAS, A.MAX_SCORE_BIAS))
        end
        if type(arm) == "table" then
            arm.bias = bias
            if math.abs(bias) >= 0.25 then active = active + 1 end
        end
    end
    return active
end

local function ObserveOutcome(arm, reward, survival, dpsIndex)
    arm.fights = (arm.fights or 0) + 1
    arm.rewardAverage = EWMA(Finite(arm.rewardAverage, reward) or reward, reward, arm.fights, 0.20)
    arm.survivalAverage = EWMA(Finite(arm.survivalAverage, survival) or survival, survival, arm.fights, 0.20)
    arm.dpsIndexAverage = EWMA(Finite(arm.dpsIndexAverage, dpsIndex) or dpsIndex, dpsIndex, arm.fights, 0.20)
    arm.lastSeenAt = Now()
end

function A.GetCandidateBias(candidate)
    local store = Store()
    if not store or store.enabled ~= true or type(candidate) ~= "table" or not TUNABLE_TAGS[candidate.tag] then return 0 end
    local tuning = currentFight and currentFight.tuning
    local telemetryContext = tuning and tuning.context
    -- Never reuse the last learned build blindly. If combat logging is off or
    -- the current fight context is unavailable, there is no reliable way to
    -- prove that talents/spellbook/mode still match, so fail closed to zero.
    if not telemetryContext or telemetryContext.pvp == true or telemetryContext.mode == "pvp" then return 0 end
    local key = tuning.adaptiveContextKey
    if not key then
        local _, canonicalKey, _, storedKey = FindContext(store, telemetryContext)
        key = storedKey or canonicalKey
        tuning.adaptiveContextKey = key
    end
    local context = key and store.contexts[key] or nil
    if type(context) ~= "table" or (Finite(context.fights, 0) or 0) < A.MIN_CONTEXT_FIGHTS then return 0 end
    local arms = type(context.arms) == "table" and context.arms or {}
    local arm = arms[CandidateKey(candidate.id, candidate.tag)]
    if type(arm) ~= "table" then return 0 end
    local bias = arm and Bound(arm.bias, -A.MAX_SCORE_BIAS, A.MAX_SCORE_BIAS) or 0
    if bias ~= 0 and tuning then
        tuning.adaptiveApplied = true
        tuning.adaptiveMaxBias = math.max(Finite(tuning.adaptiveMaxBias, 0) or 0, math.abs(bias))
    end
    return bias
end

function A.IsCandidateTunable(candidate)
    return type(candidate) == "table" and TUNABLE_TAGS[candidate.tag] == true
end

function A.LearnFight(fight)
    local store = Store()
    local tuning = fight and fight.tuning
    if not store or type(tuning) ~= "table" then return end
    tuning.learning = {revision=A.REVISION, enabled=store.enabled == true, processed=false}
    if store.enabled ~= true then tuning.learning.reason = "disabled"; return end
    if tuning.context and (tuning.context.pvp == true or tuning.context.mode == "pvp") then
        tuning.learning.reason = "pvp"; return
    end
    if not tuning.eligibility or tuning.eligibility.adaptive ~= true then
        tuning.learning.reason = tuning.eligibility and table.concat(tuning.eligibility.reasons or {}, ",") or "ineligible"
        return
    end

    local context, contextKey = EnsureContext(store, tuning.context or {})
    if not context then tuning.learning.reason = "context_unavailable"; return end
    store.lastContextKey = contextKey
    store.totalEligible = (store.totalEligible or 0) + 1
    context.fights = (context.fights or 0) + 1
    local reward, survival, dpsIndex, difficulty = FightReward(fight, context)
    context.rewardAverage = EWMA(Finite(context.rewardAverage, reward) or reward, reward, context.fights, 0.14)
    context.survivalAverage = EWMA(Finite(context.survivalAverage, survival) or survival, survival, context.fights, 0.14)

    for key, candidate in pairs(tuning.candidates or {}) do
        local arm = EnsureArm(context, key, candidate)
        if arm then arm.opportunities = (arm.opportunities or 0) + (Finite(candidate.samples, 0) or 0) end
    end
    local observedThisFight = {}
    for key, decision in pairs(tuning.decisions or {}) do
        local accepted = math.max(0, Finite(decision.accepted, 0) or 0)
        if accepted > 0 then
            local arm = EnsureArm(context, key, decision)
            if arm then
                arm.accepted = (arm.accepted or 0) + accepted
                arm.offers = (arm.offers or 0) + math.max(1, Finite(decision.offers, 1) or 1)
                ObserveOutcome(arm, reward, survival, dpsIndex)
                observedThisFight[key] = true
            end
        end
    end

    -- If the player deliberately cast another action that was also an eligible
    -- candidate during the fight, treat it as conservative evidence for that
    -- alternative. Aggregate telemetry cannot prove exact frame-level
    -- causality, so each arm receives at most one outcome update per fight.
    for _, stats in pairs(tuning.actionStats or {}) do
        local overrides = math.max(0, Finite(stats.deviations, 0) or 0)
        if overrides > 0 and stats.spellId then
            local bestKey, bestCandidate, bestSamples
            for candidateKey, candidate in pairs(tuning.candidates or {}) do
                local samples = math.max(0, Finite(candidate.samples, 0) or 0)
                if candidate.spellId == stats.spellId and samples > 0
                   and (not bestSamples or samples > bestSamples or (samples == bestSamples and tostring(candidateKey) < tostring(bestKey))) then
                    bestKey, bestCandidate, bestSamples = candidateKey, candidate, samples
                end
            end
            if bestKey then
                local arm = EnsureArm(context, bestKey, bestCandidate)
                if arm then
                    arm.userOverrides = (arm.userOverrides or 0) + overrides
                    if not observedThisFight[bestKey] then
                        ObserveOutcome(arm, reward, survival, dpsIndex)
                        observedThisFight[bestKey] = true
                    end
                end
            end
        end
    end
    local activeAdjustments = RecomputeBiases(context)
    tuning.learning.processed = true
    tuning.learning.contextFights = context.fights
    tuning.learning.ready = context.fights >= A.MIN_CONTEXT_FIGHTS
    tuning.learning.reward = reward
    tuning.learning.survival = survival
    tuning.learning.difficulty = difficulty
    store.lastLearnedAt = Now()
    if context.fights >= A.MIN_CONTEXT_FIGHTS and not context.readyAnnounced then
        context.readyAnnounced = true
        print("|cff00ff98HCOB ADAPTIVE:|r calibration complete for this class/build context; bounded offensive tuning is now available.")
    end
    if activeAdjustments > 0 and not context.adjustmentsAnnounced then
        context.adjustmentsAnnounced = true
        print("|cff00ff98HCOB ADAPTIVE:|r first learned priority adjustments are active. Use /hcob tuning status for details.")
    end
end

function A.IsEnabled()
    local store = Store()
    return store and store.enabled == true or false
end

function A.SetViewProfile(profile)
    local store = Store()
    if not store or (profile ~= "pve" and profile ~= "pvp") then return false end
    store.viewProfile = profile
    return true
end

function A.SetEnabled(enabled)
    local store = Store()
    if not store then return false end
    store.enabled = enabled == true
    return true
end

function A.Reset()
    local store = Store()
    if not store then return false end
    store.contexts = {}
    store.totalEligible = 0
    store.lastContextKey = nil
    store.lastLearnedAt = nil
    store.resetAt = Now()
    return true
end

function A.Status()
    local model = A.GetDisplayModel()
    return {
        enabled=model.enabled, contexts=model.contexts, totalEligible=model.totalEligible,
        contextFights=model.fights or 0, learnedActions=model.learnedActions or 0,
        activeAdjustments=model.activeAdjustments or 0, ready=model.ready == true,
        viewProfile=model.viewProfile, mode=model.mode, contextKey=model.contextKey,
        contextAvailable=model.contextAvailable == true, learningSupported=model.learningSupported,
    }
end

function A.GetDisplayModel(profile)
    local store = Store()
    profile = profile or (store and store.viewProfile) or "pve"
    profile = profile == "pvp" and "pvp" or "pve"
    local model = {
        enabled=store and store.enabled == true or false,
        contexts=store and Count(store.contexts) or 0,
        totalEligible=store and store.totalEligible or 0,
        minContextFights=A.MIN_CONTEXT_FIGHTS,
        minArmFights=A.MIN_ARM_FIGHTS,
        maxBias=A.MAX_SCORE_BIAS,
        viewProfile=profile, learningSupported=profile ~= "pvp",
        arms={}, protectedObserved=0,
    }
    if not store then return model end

    local telemetry = HCOB.Systems and HCOB.Systems.TuningTelemetry
    local liveContext
    if telemetry and telemetry.ContextSnapshot then
        local ok, value = pcall(telemetry.ContextSnapshot)
        if ok and type(value) == "table" then liveContext = value end
    end
    -- Inspection is an explicit view choice, never a guess based on the target
    -- or last learned fight. It does not switch the gameplay/learning policy.
    if liveContext then
        local copy = {}
        for key, value in pairs(liveContext) do copy[key] = value end
        local grouped = (Finite(liveContext.groupSize, 1) or 1) > 1 or liveContext.mode == "group"
        copy.mode = profile == "pvp" and "pvp" or (grouped and "group" or "solo")
        liveContext = copy
    end
    local context, liveKey, levelBand = FindContext(store, liveContext)
    -- PvP learning is not supported. Never expose stored/corrupt PvP entries as
    -- active corrections, and never substitute the normal PvE profile here.
    if not model.learningSupported then context = nil end

    model.contextKey = liveKey
    model.class = liveContext and liveContext.class or PLAYER_CLASS or "?"
    model.specIndex = math.max(0, math.floor(Finite(liveContext and liveContext.specIndex, 0) or 0))
    model.specName = tostring(liveContext and liveContext.spec or "")
    model.mode = tostring(liveContext and liveContext.mode or "solo")
    model.levelBand = levelBand or math.max(1, math.floor(Finite(liveContext and liveContext.level, 1) or 1))
    model.contextAvailable = liveKey ~= nil
    model.fights = context and math.max(0, math.floor(Finite(context.fights, 0) or 0)) or 0
    model.ready = model.fights >= A.MIN_CONTEXT_FIGHTS

    local learnedActions, activeAdjustments = 0, 0
    local arms = context and type(context.arms) == "table" and context.arms or {}
    for key, arm in pairs(arms) do
        if type(arm) == "table" then
            if TUNABLE_TAGS[arm.tag] then
                local fights = math.max(0, math.floor(Finite(arm.fights, 0) or 0))
                local bias = Bound(arm.bias, -A.MAX_SCORE_BIAS, A.MAX_SCORE_BIAS)
                if fights > 0 then learnedActions = learnedActions + 1 end
                if math.abs(bias) >= 0.25 then activeAdjustments = activeAdjustments + 1 end
                model.arms[#model.arms + 1] = {
                    key=tostring(key), spellId=Finite(arm.spellId, nil),
                    title=tostring(arm.title or arm.spellId or "Unknown action"),
                    tag=tostring(arm.tag or "action"), fights=fights,
                    opportunities=math.max(0, math.floor(Finite(arm.opportunities, 0) or 0)),
                    accepted=math.max(0, math.floor(Finite(arm.accepted, 0) or 0)),
                    userOverrides=math.max(0, math.floor(Finite(arm.userOverrides, 0) or 0)),
                    bias=bias, active=math.abs(bias) >= 0.25,
                }
            else
                model.protectedObserved = model.protectedObserved + 1
            end
        end
    end
    table.sort(model.arms, function(left, right)
        local leftBias, rightBias = math.abs(left.bias), math.abs(right.bias)
        if leftBias ~= rightBias then return leftBias > rightBias end
        if left.fights ~= right.fights then return left.fights > right.fights end
        if left.title ~= right.title then return left.title < right.title end
        return left.key < right.key
    end)
    model.learnedActions = learnedActions
    model.activeAdjustments = activeAdjustments
    return model
end

function A.PrintStatus()
    local status = A.Status()
    print(string.format("|cff00ff98HCOB ADAPTIVE:|r %s | eligible fights %d | contexts %d",
        status.enabled and "ON" or "OFF", status.totalEligible, status.contexts))
    local state = not status.learningSupported and "NOT SUPPORTED"
        or (not status.contextAvailable and "NO CONTEXT")
        or (not status.enabled and "DISABLED") or (status.ready and "READY" or "CALIBRATING")
    print(string.format("%s / %s: %d/%d fights | learned actions %d | learned corrections %d | %s",
        status.viewProfile == "pvp" and "PvP" or "Normal (PvE)", tostring(status.mode or "unknown"),
        status.contextFights, A.MIN_CONTEXT_FIGHTS, status.learnedActions, status.activeAdjustments,
        state))
    if not status.learningSupported then
        print("PvP learning is not supported. This view does not enable PvP tuning or reuse PvE corrections.")
    elseif status.contextAvailable and status.contextFights == 0 and status.contexts > 0 then
        print("No evidence for the current build/level band/solo-group context. Other saved contexts are preserved, not applied here.")
    end
    if status.enabled and status.learningSupported then
        print("Learning is local and bounded to offensive priorities; Hardcore safety gates are never tuned.")
    end
end

AdaptiveTuningBias = A.GetCandidateBias
