-- HCOneButton local adaptive priority learner.
-- Learns bounded situational preferences from confirmed co-eligible choices.
-- Emergencies and spell eligibility remain owned by the normal Advisor engine.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

HCOB.Systems.AdaptiveTuner = HCOB.Systems.AdaptiveTuner or {}
local A = HCOB.Systems.AdaptiveTuner

A.SCHEMA_VERSION = 2
A.REVISION = 4
A.MIN_CONTEXT_FIGHTS = 8
A.MIN_ARM_FIGHTS = 4
A.MAX_SCORE_BIAS = 12
A.MAX_SITUATIONS = 12
A.MAX_CONTEXTS = 24
A.MAX_ARMS_PER_CONTEXT = 64

local TUNABLE_TAGS = {
    damage=true, dot=true, finisher=true, aoe=true, burst=true,
    efficiency=true, sustain=true, weave=true, core=true, dump=true,
    setup=true,
    proc=true, buff=true, resource=true, mitigation=true, form=true,
    aspect=true, survival=true, control=true,
}

-- Emergency cooldowns are never experiments, even when the current HP looks
-- healthy. Other actions are classified at the actual decision, not by class.
local EMERGENCY_IDS = {
    [871]=true, [20230]=true, [642]=true, [498]=true, [633]=true,
    [5384]=true, [1856]=true, [11958]=true, [12472]=true,
    [22842]=true, [6789]=true,
}
local CONDITIONAL_TAGS = {survival=true, control=true, mitigation=true,
    resource=true, buff=true, form=true, aspect=true, sustain=true, proc=true}

local function Finite(value, fallback)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return fallback end
    return value
end

function A.DecisionState()
    local hp, readable
    if UnitHealthPct then hp, readable = UnitHealthPct("player") end
    local targetHP = UnitHealthPct and UnitHealthPct("target")
    local petHP, petReadable
    if UnitHealthPct then petHP, petReadable = UnitHealthPct("pet") end
    if petReadable == false then petHP = nil end
    local engine = HCOB.Advisor and HCOB.Advisor.Engine
    local reserve = engine and engine.SurvivalReserve and engine.SurvivalReserve()
    local power = UnitPowerPct and UnitPowerPct("player", UnitPowerType and UnitPowerType("player") or 0)
    local enemies = CountActiveEnemies and CountActiveEnemies() or 1
    return {hp=hp, readable=readable ~= false and type(hp) == "number",
        reserve=reserve, power=power, targetHP=targetHP, petHP=petHP, enemies=enemies}
end

function A.SituationKey(state)
    state = state or A.DecisionState()
    local power = Finite(state.power, 50)
    return (Finite(state.enemies, 1) >= 2 and "multi" or "single") .. ":"
        .. (power <= 35 and "low" or (power >= 80 and "high" or "normal")) .. ":"
        .. (Finite(state.targetHP, 100) <= 30 and "finish" or "main")
end

function A.Policy(candidate, state)
    if type(candidate) ~= "table" then return false, "Unavailable action" end
    local id = Finite(candidate.id or candidate.spellId)
    if not id or id == 6603 or id == 75 then return false, "Attack mode / non-spell guidance" end
    if EMERGENCY_IDS[id] then return false, "Emergency cooldown: fixed priority" end
    if not TUNABLE_TAGS[candidate.tag] then return false, "Fixed " .. tostring(candidate.tag or "action") .. " policy" end
    if type(candidate.tuningMeta) == "table" and candidate.tuningMeta.required then return false, "Required by class policy" end
    if CONDITIONAL_TAGS[candidate.tag] then
        state = state or A.DecisionState()
        local hp, reserve, petHP = Finite(state.hp), Finite(state.reserve), Finite(state.petHP)
        if not state.readable or not hp or not reserve then return false, "Safety state unavailable" end
        if hp <= 60 or reserve < 45 or Finite(state.enemies, 1) >= 3 then
            return false, "Pressure: preserve recovery / control / resources"
        end
        if candidate.tag == "survival" and (hp < 75 or reserve < 60) then
            return false, "Recovery needed: fixed priority"
        end
        if id == 136 and (not petHP or petHP <= 60) then
            return false, "Pet recovery needed: fixed priority"
        end
    end
    return true, CONDITIONAL_TAGS[candidate.tag] and "Adaptive when safe; protected under pressure" or "Adaptive priority"
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

    local overkill = 0
    for _, abilities in ipairs({fight.abilities or {}, fight.petAbilities or {}}) do
        if type(abilities) == "table" then
            for _, ability in pairs(abilities) do
                if type(ability) == "table" then overkill = overkill + math.max(0, Finite(ability.overkill, 0)) end
            end
        end
    end
    local dps = math.max(0, Finite(fight.dps, 0) - overkill / math.max(0.05, Finite(fight.duration, 1)))
    local baselineDps = Finite(baseline.dpsAverage, 0) or 0
    local dpsIndex = baseline.fights >= 3 and Bound((dps / math.max(0.1, baselineDps) - 0.65) / 0.70, 0, 1) or 0.5
    local hpFloor = Finite(fight.hpMinPct, 100) or 100
    local survival = Bound((hpFloor - 20) / 75, 0, 1)
    local capPct = 0
    for token, resource in pairs(fight.tuning and fight.tuning.resources or {}) do
        if (token == "RAGE" or token == "ENERGY") and type(resource) == "table" then
            capPct = math.max(capPct, Bound(resource.capPct, 0, 100))
        end
    end
    local reward = dpsIndex * 0.55 + survival * 0.35 + (1 - capPct / 100) * 0.10

    baseline.fights = (baseline.fights or 0) + 1
    baseline.dpsAverage = EWMA(baselineDps, dps, baseline.fights, 0.16)
    baseline.lastSeenAt = Now()
    return reward, survival, dpsIndex, difficulty, dps, capPct
end

local function RecomputeBiases(context)
    local active = 0
    for _, arm in pairs(context.arms or {}) do
        if type(arm) == "table" then
            -- Legacy fight-wide correlations remain inspectable evidence, but
            -- are not silently promoted into the wider revision-3 score range.
            arm.bias = 0
            for _, situation in pairs(type(arm.situations) == "table" and arm.situations or {}) do
                if type(situation) == "table" then
                    local yes = type(situation.chosen) == "table" and situation.chosen or {}
                    local no = type(situation.other) == "table" and situation.other or {}
                    local ny, nn = Finite(yes.n, 0), Finite(no.n, 0)
                    local bias = 0
                    if context.fights >= A.MIN_CONTEXT_FIGHTS and ny >= A.MIN_ARM_FIGHTS and nn >= A.MIN_ARM_FIGHTS then
                        local delta = Finite(yes.mean, 0) - Finite(no.mean, 0)
                        local safety = Finite(yes.safety, 0) - Finite(no.safety, 0)
                        local se = math.sqrt(math.max(0, Finite(yes.m2, 0) / (ny - 1) / ny
                            + Finite(no.m2, 0) / (nn - 1) / nn))
                        local signal = math.max(0, math.abs(delta) - 1.5 * se - 0.04)
                        local raw = (delta < 0 and -1 or 1) * signal * 30
                        -- A faster result cannot earn a positive preference at
                        -- the expense of a materially worse health floor.
                        if safety < -0.08 then raw = math.min(0, raw) end
                        bias = RoundQuarter(Bound(raw * math.min(1, math.min(ny, nn) / 8), -A.MAX_SCORE_BIAS, A.MAX_SCORE_BIAS))
                    end
                    situation.bias = bias
                    if math.abs(bias) >= 0.25 then active = active + 1 end
                end
            end
        end
    end
    return active
end

local function ObserveComparison(bucket, reward, survival)
    bucket.n = (Finite(bucket.n, 0) or 0) + 1
    local delta = reward - Finite(bucket.mean, 0)
    bucket.mean = Finite(bucket.mean, 0) + delta / bucket.n
    bucket.m2 = math.max(0, Finite(bucket.m2, 0) + delta * (reward - bucket.mean))
    bucket.safety = Finite(bucket.safety, 0) + (survival - Finite(bucket.safety, 0)) / bucket.n
end

local function ComparisonBias(situation, contextFights)
    if type(situation) ~= "table" or type(situation.chosen) ~= "table" or type(situation.other) ~= "table"
       or Finite(contextFights, 0) < A.MIN_CONTEXT_FIGHTS
       or Finite(situation.chosen.n, 0) < A.MIN_ARM_FIGHTS
       or Finite(situation.other.n, 0) < A.MIN_ARM_FIGHTS then return 0 end
    return Bound(situation.bias, -A.MAX_SCORE_BIAS, A.MAX_SCORE_BIAS)
end

-- One first confirmed choice per action and fight, with a genuine alternative
-- available at that decision. Repeated reader inputs are not extra evidence.
function A.RecordChoice(fight, window, spellId)
    if not A.IsEnabled() or not window or not window.candidates then return end
    local selected
    for _, candidate in ipairs(window.candidates) do
        if candidate.spellId == spellId then selected = candidate end
    end
    if not selected or #window.candidates < 2 then return end
    local tuning = fight.tuning
    tuning.choiceEvidence = tuning.choiceEvidence or {}
    for _, candidate in ipairs(window.candidates) do
        local key = CandidateKey(candidate.spellId, candidate.tag)
        if not tuning.choiceEvidence[key] and Count(tuning.choiceEvidence) < A.MAX_ARMS_PER_CONTEXT then
            tuning.choiceEvidence[key] = {spellId=candidate.spellId, tag=candidate.tag,
                title=candidate.title, situation=window.situation, chosen=candidate == selected}
        end
    end
end

local function ObserveOutcome(arm, reward, survival, dpsIndex)
    arm.fights = (arm.fights or 0) + 1
    arm.rewardAverage = EWMA(Finite(arm.rewardAverage, reward) or reward, reward, arm.fights, 0.20)
    arm.survivalAverage = EWMA(Finite(arm.survivalAverage, survival) or survival, survival, arm.fights, 0.20)
    arm.dpsIndexAverage = EWMA(Finite(arm.dpsIndexAverage, dpsIndex) or dpsIndex, dpsIndex, arm.fights, 0.20)
    arm.lastSeenAt = Now()
end

function A.GetCandidateBias(candidate, state)
    local store = Store()
    if not store or store.enabled ~= true or not A.Policy(candidate, state) then return 0 end
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
    local situation = type(arm.situations) == "table" and arm.situations[A.SituationKey(state)] or nil
    local bias = ComparisonBias(situation, context.fights)
    if bias ~= 0 and tuning then
        tuning.adaptiveApplied = true
        tuning.adaptiveMaxBias = math.max(Finite(tuning.adaptiveMaxBias, 0) or 0, math.abs(bias))
    end
    return bias
end

function A.IsCandidateTunable(candidate, state)
    return A.Policy(candidate, state)
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
    local reward, survival, dpsIndex, difficulty, effectiveDps, capPct = FightReward(fight, context)
    context.rewardAverage = EWMA(Finite(context.rewardAverage, reward) or reward, reward, context.fights, 0.14)
    context.survivalAverage = EWMA(Finite(context.survivalAverage, survival) or survival, survival, context.fights, 0.14)

    for key, candidate in pairs(tuning.candidates or {}) do
        local arm = EnsureArm(context, key, candidate)
        if arm then arm.opportunities = (arm.opportunities or 0) + (Finite(candidate.samples, 0) or 0) end
    end
    for key, evidence in pairs(tuning.choiceEvidence or {}) do
        if type(evidence) == "table" and TUNABLE_TAGS[evidence.tag] and type(evidence.situation) == "string" then
            local arm = EnsureArm(context, key, evidence)
            if arm then
                arm.situations = type(arm.situations) == "table" and arm.situations or {}
                local situation = arm.situations[evidence.situation]
                if not situation and Count(arm.situations) < A.MAX_SITUATIONS then
                    situation = {chosen={}, other={}, bias=0}
                    arm.situations[evidence.situation] = situation
                end
                if type(situation) == "table" then
                    local side = evidence.chosen and "chosen" or "other"
                    situation[side] = type(situation[side]) == "table" and situation[side] or {}
                    ObserveComparison(situation[side], reward, survival)
                end
            end
        end
    end
    context.impact = type(context.impact) == "table" and context.impact or {}
    for _, name in ipairs({"evaluated", "changed", "executed"}) do
        context.impact[name] = Finite(context.impact[name], 0) + Finite(tuning.impact and tuning.impact[name], 0)
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
    local comparativeSituations = 0
    for _, arm in pairs(context.arms) do
        for _, situation in pairs(type(arm.situations) == "table" and arm.situations or {}) do
            if type(situation) == "table" and Finite(type(situation.chosen) == "table" and situation.chosen.n, 0) >= A.MIN_ARM_FIGHTS
               and Finite(type(situation.other) == "table" and situation.other.n, 0) >= A.MIN_ARM_FIGHTS then
                comparativeSituations = comparativeSituations + 1
            end
        end
    end
    tuning.learning.processed = true
    tuning.learning.contextFights = context.fights
    tuning.learning.ready = context.fights >= A.MIN_CONTEXT_FIGHTS and comparativeSituations > 0
    tuning.learning.reward = reward
    tuning.learning.survival = survival
    tuning.learning.difficulty = difficulty
    tuning.learning.effectiveDps, tuning.learning.resourceCapPct = effectiveDps, capPct
    store.lastLearnedAt = Now()
    if context.fights >= A.MIN_CONTEXT_FIGHTS and not context.readyAnnounced then
        context.readyAnnounced = true
        print("|cff00ff98HCOB ADAPTIVE:|r fight baseline collected; priority learning still needs 4 chosen + 4 alternative fights per situation.")
    end
    if activeAdjustments > 0 and not context.comparisonsAnnounced then
        context.adjustmentsAnnounced = true
        context.comparisonsAnnounced = true
        print("|cff00ff98HCOB ADAPTIVE:|r first situational adjustments are active. Use /hcob tuning status for observed impact.")
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
        contextAvailable=model.contextAvailable == true, learningSupported=model.learningSupported, impact=model.impact,
        state=model.state, comparisonSituations=model.comparisonSituations, matureSituations=model.matureSituations,
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
        arms={}, spells={}, protectedObserved=0, impact={evaluated=0, changed=0, executed=0},
        comparisonSituations=0, matureSituations=0,
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
    model.contextCalibrated = model.fights >= A.MIN_CONTEXT_FIGHTS
    for _, name in ipairs({"evaluated", "changed", "executed"}) do
        model.impact[name] = Finite(context and type(context.impact) == "table" and context.impact[name], 0)
    end

    local activeAdjustments = 0
    local arms = context and type(context.arms) == "table" and context.arms or {}
    for key, arm in pairs(arms) do
        if type(arm) == "table" then
            local spellId = Finite(arm.spellId, nil)
            if spellId and spellId > 0 and spellId == math.floor(spellId) then
                local fights = math.max(0, math.floor(Finite(arm.fights, 0) or 0))
                local tunable, policy = A.Policy(arm, {hp=100, petHP=100, reserve=100, readable=true, enemies=1})
                local situations = type(arm.situations) == "table" and arm.situations or {}
                local hasRows = false
                local function addRow(situationKey, situation)
                    local bias = tunable and ComparisonBias(situation, model.fights) or 0
                    if math.abs(bias) >= 0.25 then activeAdjustments = activeAdjustments + 1 end
                    local chosen = situation and Finite(type(situation.chosen) == "table" and situation.chosen.n, 0) or 0
                    local other = situation and Finite(type(situation.other) == "table" and situation.other.n, 0) or 0
                    local mature = tunable and model.contextCalibrated and chosen >= A.MIN_ARM_FIGHTS and other >= A.MIN_ARM_FIGHTS
                    if tunable and chosen + other > 0 then model.comparisonSituations = model.comparisonSituations + 1 end
                    if mature then model.matureSituations = model.matureSituations + 1 end
                    model.arms[#model.arms + 1] = {
                        key=tostring(key) .. ":" .. tostring(situationKey or "observed"), spellId=spellId,
                        title=tostring(arm.title or arm.spellId or "Unknown action"), policy=policy, protected=not tunable,
                        situation=situationKey, tag=tostring(arm.tag or "action"), fights=fights,
                        role=tostring(key):match(":([^:]+)$") or tostring(arm.tag or "action"),
                        chosenFights=chosen, otherFights=other, mature=mature,
                        opportunities=math.max(0, math.floor(Finite(arm.opportunities, 0) or 0)),
                        accepted=math.max(0, math.floor(Finite(arm.accepted, 0) or 0)),
                        userOverrides=math.max(0, math.floor(Finite(arm.userOverrides, 0) or 0)),
                        bias=bias, active=math.abs(bias) >= 0.25,
                    }
                end
                for situationKey, situation in pairs(situations) do
                    if type(situation) == "table" then addRow(situationKey, situation); hasRows=true end
                end
                if not hasRows then addRow() end
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
    -- Group presentation only: never merge roles/situations or promote legacy
    -- unclassified outcomes into comparative training data.
    local groups = {}
    for _, row in ipairs(model.arms) do
        local group = groups[row.spellId]
        if not group then
            local name = SpellName and SpellName(row.spellId)
            group = {key="spell:" .. row.spellId, spellId=row.spellId, title=name or row.title,
                details={}, summary=true, protected=true, active=false, minBias=0, maxBias=0,
                roleCount=0, situationCount=0, comparisonCount=0, matureCount=0, roles={}}
            groups[row.spellId] = group
            model.spells[#model.spells + 1] = group
        end
        group.details[#group.details + 1] = row
        if not group.roles[row.role] then group.roles[row.role]=true; group.roleCount=group.roleCount + 1 end
        if row.situation then group.situationCount = group.situationCount + 1 end
        if not row.protected and row.chosenFights + row.otherFights > 0 then group.comparisonCount = group.comparisonCount + 1 end
        if row.mature then group.matureCount = group.matureCount + 1 end
        group.protected = group.protected and row.protected
        group.active = group.active or row.active
        if not row.protected and row.situation then
            group.minBias = group.hasRange and math.min(group.minBias, row.bias) or row.bias
            group.maxBias = group.hasRange and math.max(group.maxBias, row.bias) or row.bias
            group.hasRange = true
        end
    end
    for _, group in ipairs(model.spells) do
        table.sort(group.details, function(left, right) return left.key < right.key end)
        group.state = group.protected and "FIXED" or (group.active and "LEARNED"
            or (group.matureCount > 0 and "BASELINE" or (group.comparisonCount > 0 and "COMPARING" or "OBSERVING")))
        if group.protected then model.protectedObserved = model.protectedObserved + 1 end
    end
    table.sort(model.spells, function(left, right)
        if left.active ~= right.active then return left.active end
        if left.title ~= right.title then return left.title < right.title end
        return left.key < right.key
    end)
    model.learnedActions = #model.spells
    model.activeAdjustments = activeAdjustments
    model.ready = model.matureSituations > 0
    model.state = not model.learningSupported and "NOT SUPPORTED" or (not model.enabled and "DISABLED"
        or (not model.contextAvailable and "NO CONTEXT" or (activeAdjustments > 0 and "ADAPTED"
        or (model.ready and "BASELINE" or (model.comparisonSituations > 0 and "COMPARING" or "OBSERVING")))))
    return model
end

function A.PrintStatus()
    local status = A.Status()
    print(string.format("|cff00ff98HCOB ADAPTIVE:|r %s | eligible fights %d | contexts %d",
        status.enabled and "ON" or "OFF", status.totalEligible, status.contexts))
    local state = status.state or "UNAVAILABLE"
    print(string.format("%s / %s: %d/%d fights | observed spells %d | learned corrections %d | %s",
        status.viewProfile == "pvp" and "PvP" or "Normal (PvE)", tostring(status.mode or "unknown"),
        status.contextFights, A.MIN_CONTEXT_FIGHTS, status.learnedActions, status.activeAdjustments,
        state))
    if not status.learningSupported then
        print("PvP learning is not supported. This view does not enable PvP tuning or reuse PvE corrections.")
    elseif status.contextAvailable and status.contextFights == 0 and status.contexts > 0 then
        print("No evidence for the current build/level band/solo-group context. Other saved contexts are preserved, not applied here.")
    end
    if status.enabled and status.learningSupported then
        print(string.format("Observed impact: %d/%d displayed choices changed; %d changed choices executed. Not a measured DPS gain.",
            status.impact.changed, status.impact.evaluated, status.impact.executed))
        print("Local situational comparisons; emergency priorities and cast/range/aura gates remain fixed.")
    end
end

AdaptiveTuningBias = A.GetCandidateBias
