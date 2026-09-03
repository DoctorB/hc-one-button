-- HCOneButton adaptive-tuning telemetry contract.
-- Collects bounded, structured and class-neutral decision/action data. It does
-- not change recommendations; future local tuners consume the saved contract.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

HCOB.Systems.TuningTelemetry = HCOB.Systems.TuningTelemetry or {}
local T = HCOB.Systems.TuningTelemetry

T.CONTRACT_VERSION = 1
T.MAX_ACTION_EVENTS = 96
T.MAX_INPUT_EVENTS = 64
T.MAX_DECISION_BUCKETS = 48
T.MAX_CANDIDATE_BUCKETS = 64

local POLICY_KEYS = {
    "criticalHP", "dangerHP", "enemyWindow", "hcDangerAdvisor", "prePullSafety", "smartDisplay",
    "warriorAutoRend", "warriorHeroicRage", "warriorSunderBase",
}

local function Finite(value, fallback)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return fallback end
    return value
end

local function Clean(value, maxLength)
    local text = tostring(value or ""):gsub("[\r\n\t]+", " "):gsub("%s+", " ")
    maxLength = tonumber(maxLength) or 48
    if #text > maxLength then text = text:sub(1, maxLength) end
    return text
end

local function HashParts(parts)
    local hash = 5381
    for _, value in ipairs(parts or {}) do
        local text = tostring(value or "")
        for i=1,#text do hash = (hash * 33 + text:byte(i)) % 4294967291 end
        hash = (hash * 33 + 31) % 4294967291
    end
    return "h1-" .. string.format("%.0f", hash)
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e, f, g
end

local function BoolCall(fn, ...)
    local value = Call(fn, ...)
    return value == true or value == 1
end

local function RuntimeSessionId()
    if type(telemetryRuntimeSessionId) == "string" and telemetryRuntimeSessionId ~= "" then
        return telemetryRuntimeSessionId
    end
    local wallClock = (GetServerTime and GetServerTime()) or (time and time()) or 0
    local sessionClock = (GetTime and GetTime()) or 0
    local randomPart = math.random and math.random(100000, 999999) or 0
    telemetryRuntimeSessionId = string.format("s%d-%d-%d", math.floor(wallClock), math.floor(sessionClock * 1000), randomPart)
    return telemetryRuntimeSessionId
end

local function TalentSignature()
    local parts = {PLAYER_CLASS or "?", PlayerLevel and PlayerLevel() or 0}
    for tab=1,3 do
        local points = 0
        if TalentTabCompat then
            local _, tabPoints = TalentTabCompat(tab)
            points = tonumber(tabPoints) or 0
        end
        parts[#parts + 1] = "tab" .. tab .. "=" .. tostring(tonumber(points) or 0)
        local count = Finite(Call(GetNumTalents, tab), 0) or 0
        for index=1,math.max(0, math.floor(count)) do
            local a, b, c, d, e, f = Call(GetTalentInfo, tab, index)
            local rank
            if type(a) == "number" and type(b) == "string" then rank = tonumber(f) or tonumber(e) or 0
            else rank = tonumber(e) or tonumber(f) or 0 end
            parts[#parts + 1] = tostring(math.floor(rank))
        end
    end
    return HashParts(parts)
end

local function SpellbookSignature()
    local parts = {}
    local modern = C_SpellBook and C_SpellBook.GetSpellBookItemName and Enum and Enum.SpellBookSpellBank
    local legacy = GetSpellBookItemName
    for index=1,600 do
        local name, rank, spellId
        if modern then
            name = Call(C_SpellBook.GetSpellBookItemName, index, Enum.SpellBookSpellBank.Player)
            if C_SpellBook.GetSpellBookItemInfo then
                local info = Call(C_SpellBook.GetSpellBookItemInfo, index, Enum.SpellBookSpellBank.Player)
                if type(info) == "table" then spellId = info.spellID or info.actionID end
            end
        elseif legacy then
            name, rank = Call(GetSpellBookItemName, index, BOOKTYPE_SPELL or "spell")
            if GetSpellBookItemInfo then
                local _, id = Call(GetSpellBookItemInfo, index, BOOKTYPE_SPELL or "spell")
                spellId = id
            end
        else
            break
        end
        if not name then break end
        parts[#parts + 1] = tostring(name) .. ":" .. tostring(rank or "") .. ":" .. tostring(spellId or "")
    end
    if #parts == 0 then
        local list = HCOB.UI and HCOB.UI.ActionPanel and HCOB.UI.ActionPanel.actions and HCOB.UI.ActionPanel.actions[PLAYER_CLASS] or {}
        for _, id in ipairs(list) do parts[#parts + 1] = tostring(id) .. "=" .. tostring(IsKnown and IsKnown(id) or false) end
    end
    return HashParts(parts)
end

local function EquipmentSignature()
    local parts = {}
    for slot=1,19 do
        local link = Call(GetInventoryItemLink, "player", slot)
        local id = Call(GetInventoryItemID, "player", slot)
        parts[#parts + 1] = tostring(slot) .. "=" .. tostring(link or id or 0)
    end
    return HashParts(parts)
end

local function GroupContext()
    local groupSize = Finite(Call(GetNumGroupMembers), nil)
    if groupSize == nil then
        local party = Finite(Call(GetNumPartyMembers), 0) or 0
        groupSize = party > 0 and party + 1 or 1
    elseif groupSize <= 0 then
        groupSize = 1
    end
    local inInstance, instanceType = Call(IsInInstance)
    inInstance = inInstance == true or inInstance == 1
    instanceType = Clean(instanceType or "none", 20)
    local targetPlayer = BoolCall(UnitIsPlayer, "target")
    local pvp = targetPlayer or instanceType == "pvp" or instanceType == "arena"
    local mode = pvp and "pvp" or (groupSize > 1 and "group" or "solo")
    return math.floor(groupSize), inInstance, instanceType, targetPlayer, pvp, mode
end

local function UnitPct(unit)
    if UnitHealthPct then
        local value, readable = UnitHealthPct(unit)
        if readable ~= false then return Finite(value, nil) end
    end
    local value = SafeUnitHealth and SafeUnitHealth(unit, nil) or nil
    local maximum = SafeUnitHealthMax and SafeUnitHealthMax(unit, nil) or nil
    if value and maximum and maximum > 0 then return value / maximum * 100 end
    return nil
end

local function ResourceSnapshot()
    local powerType, token = Call(UnitPowerType, "player")
    powerType = Finite(powerType, 0) or 0
    local power = SafeUnitPower and SafeUnitPower("player", powerType, 0) or 0
    local powerMax = SafeUnitPowerMax and SafeUnitPowerMax("player", powerType, 0) or 0
    local mana = SafeUnitPower and SafeUnitPower("player", 0, 0) or 0
    local manaMax = SafeUnitPowerMax and SafeUnitPowerMax("player", 0, 0) or 0
    local combo = Finite(Call(GetComboPoints, "player", "target"), 0) or 0
    local petHP = UnitPct("pet")
    return {
        powerType=powerType, powerToken=Clean(token or ("POWER" .. tostring(powerType)), 20),
        power=Finite(power, 0) or 0, powerMax=Finite(powerMax, 0) or 0,
        mana=Finite(mana, 0) or 0, manaMax=Finite(manaMax, 0) or 0,
        combo=combo, hp=UnitPct("player"), targetHP=UnitPct("target"), petHP=petHP,
        enemies=CountActiveEnemies and CountActiveEnemies() or 1,
    }
end

local function ContextSnapshot()
    local groupSize, inInstance, instanceType, targetPlayer, pvp, mode = GroupContext()
    local talent = TalentSignature()
    local spellbook = SpellbookSignature()
    local equipment = EquipmentSignature()
    local specIndex, specName, specPoints = 0, "Unknown", 0
    if TalentSpec then specIndex, specName, specPoints = TalentSpec() end
    local snapshot = ResourceSnapshot()
    return {
        class=PLAYER_CLASS, level=PlayerLevel and PlayerLevel() or 0,
        specIndex=specIndex, spec=Clean(specName, 32), specPoints=specPoints,
        talentSignature=talent, spellbookSignature=spellbook, equipmentSignature=equipment,
        buildSignature=HashParts({PLAYER_CLASS, PlayerLevel and PlayerLevel() or 0, talent, spellbook, equipment}),
        groupSize=groupSize, inInstance=inInstance, instanceType=instanceType, targetPlayer=targetPlayer, pvp=pvp, mode=mode,
        playerHealthMax=SafeUnitHealthMax and SafeUnitHealthMax("player", 0) or 0,
        activePowerType=snapshot.powerToken, activePowerMax=snapshot.powerMax, manaMax=snapshot.manaMax,
        petPresent=BoolCall(UnitExists, "pet"), petDead=BoolCall(UnitIsDead, "pet"),
        targetLevel=SafeUnitLevel and SafeUnitLevel("target", nil) or nil,
        targetClassification=SafeUnitClassification and SafeUnitClassification("target", nil) or nil,
        targetHealthMax=SafeUnitHealthMax and SafeUnitHealthMax("target", nil) or nil,
    }
end

local function PolicySnapshot()
    local settings, parts = {}, {VERSION, PLAYER_CLASS, "policy1"}
    for _, key in ipairs(POLICY_KEYS) do
        local value = HCOB_DB and HCOB_DB[key]
        if type(value) == "number" or type(value) == "boolean" or type(value) == "string" then
            settings[key] = value
            parts[#parts + 1] = key .. "=" .. tostring(value)
        end
    end
    return {version=VERSION, revision=1, signature=HashParts(parts), settings=settings}
end

local function CanonicalActionId(spellId)
    spellId = tonumber(spellId)
    if not spellId then return nil end
    local panel = HCOB.UI and HCOB.UI.ActionPanel
    local list = panel and panel.actions and panel.actions[PLAYER_CLASS] or {}
    local actualName = SpellName and SpellName(spellId) or nil
    for _, id in ipairs(list) do
        if id == spellId then return id end
        if actualName and SpellName and SpellName(id) == actualName then return id end
    end
    return spellId
end

local function SameAction(first, second)
    if first == nil or second == nil then return false end
    first, second = tonumber(first), tonumber(second)
    if first and second and first == second then return true end
    local firstName = first and SpellName and SpellName(first) or nil
    local secondName = second and SpellName and SpellName(second) or nil
    return firstName ~= nil and firstName == secondName
end

local function CountKeys(values)
    local count = 0
    for _ in pairs(values or {}) do count = count + 1 end
    return count
end

local function CopyMeta(meta)
    if type(meta) ~= "table" then return nil end
    local result, count = {}, 0
    for key, value in pairs(meta) do
        if count >= 12 then break end
        if type(key) == "string" and (type(value) == "number" or type(value) == "boolean" or type(value) == "string") then
            result[Clean(key, 32)] = type(value) == "string" and Clean(value, 48) or value
            count = count + 1
        end
    end
    return count > 0 and result or nil
end

local function SelectedCandidate(spellId)
    local engine = HCOB.Advisor and HCOB.Advisor.Engine
    local candidates = engine and engine.lastCandidates
    if type(candidates) ~= "table" then return nil end
    for _, candidate in ipairs(candidates) do
        if SameAction(candidate.id, spellId) then return candidate end
    end
    return nil
end

local function DecisionKey(spellId, kind, title, tag)
    if spellId then return tostring(CanonicalActionId(spellId)) .. ":" .. Clean(tag or kind or "action", 20) end
    return "none:" .. Clean(kind or "idle", 12) .. ":" .. Clean(title or "", 24)
end

local function DecisionBucket(tuning, key, spellId, kind, title, keyHint)
    local buckets = tuning.decisions
    local bucket = buckets[key]
    if bucket then return bucket end
    if CountKeys(buckets) >= T.MAX_DECISION_BUCKETS then key = "other"; bucket = buckets[key] end
    if not bucket then
        bucket = {spellId=CanonicalActionId(spellId), kind=Clean(kind or "idle", 16), title=Clean(title, 40), key=Clean(keyHint, 24), offers=0, samples=0, seconds=0, accepted=0, deviations=0}
        buckets[key] = bucket
    end
    return bucket
end

local function CloseDecision(fight, now)
    local tuning = fight and fight.tuning
    local state = tuning and tuning._decision
    if not state then return end
    local bucket = tuning.decisions[state.key]
    if bucket then bucket.seconds = (bucket.seconds or 0) + math.max(0, now - (state.since or now)) end
    tuning._decision = nil
end

local function SampleCandidates(tuning, selectedSpellId)
    local engine = HCOB.Advisor and HCOB.Advisor.Engine
    local candidates = engine and engine.lastCandidates
    if type(candidates) ~= "table" then return end
    tuning.candidateSamples = (tuning.candidateSamples or 0) + 1
    local seen = {}
    for i=1,math.min(12, #candidates) do
        local candidate = candidates[i]
        local spellId = CanonicalActionId(candidate.id)
        local tag = Clean(candidate.tag or "action", 20)
        local key = tostring(spellId or "none") .. ":" .. tag
        if not seen[key] then
            seen[key] = true
            local bucket = tuning.candidates[key]
            if not bucket and CountKeys(tuning.candidates) < T.MAX_CANDIDATE_BUCKETS then
                bucket = {spellId=spellId, tag=tag, title=Clean(candidate.title, 40), samples=0, selected=0}
                tuning.candidates[key] = bucket
            end
            if bucket then
                local score = Finite(candidate.effectiveScore or candidate.score, 0) or 0
                bucket.samples = bucket.samples + 1
                bucket.selected = bucket.selected + (SameAction(spellId, selectedSpellId) and 1 or 0)
                bucket.scoreSum = (bucket.scoreSum or 0) + score
                bucket.scoreMin = math.min(bucket.scoreMin or score, score)
                bucket.scoreMax = math.max(bucket.scoreMax or score, score)
                bucket.meta = CopyMeta(candidate.tuningMeta) or bucket.meta
            else
                tuning.candidateBucketsDropped = (tuning.candidateBucketsDropped or 0) + 1
            end
        end
    end
end

function T.InitFight(fight)
    if type(fight) ~= "table" then return end
    fight.tuning = {
        contract=T.CONTRACT_VERSION, sessionId=RuntimeSessionId(),
        context=ContextSnapshot(), policy=PolicySnapshot(),
        decisions={}, candidates={}, actions={}, actionStats={}, inputs={}, inputStats={}, resources={}, metrics={},
        actionTraceDropped=0, inputTraceDropped=0,
    }
    T.SampleResources(fight)
end

function T.RecordRecommendation(spellId, title, keyHint, kind, reserve, enemies, recordSample)
    local fight = currentFight
    local tuning = fight and fight.tuning
    if not tuning then return end
    local now = GetTime()
    local elapsed = math.max(0, now - (fight.startClock or now))
    local candidate = SelectedCandidate(spellId)
    local key = DecisionKey(spellId, kind, title, candidate and candidate.tag)
    local signature = key .. ":" .. Clean(kind or "idle", 16) .. ":" .. Clean(title, 40)
    local state = tuning._decision
    if not state or state.signature ~= signature then
        CloseDecision(fight, now)
        local bucket = DecisionBucket(tuning, key, spellId, kind, title, keyHint)
        bucket.offers = (bucket.offers or 0) + 1
        if candidate then
            bucket.tag = Clean(candidate.tag, 20)
            bucket.lastScore = Finite(candidate.effectiveScore or candidate.score, nil)
            bucket.meta = CopyMeta(candidate.tuningMeta)
        end
        tuning._decision = {key=key, signature=signature, spellId=CanonicalActionId(spellId), since=now, elapsed=elapsed, accepted=false}
        state = tuning._decision
    end
    if recordSample == false then return end
    SampleCandidates(tuning, spellId)
    local bucket = tuning.decisions[state.key]
    if not bucket then return end
    local snapshot = ResourceSnapshot()
    bucket.samples = (bucket.samples or 0) + 1
    bucket.powerSum = (bucket.powerSum or 0) + snapshot.power
    bucket.powerMax = math.max(bucket.powerMax or 0, snapshot.powerMax)
    if snapshot.hp then bucket.hpSum = (bucket.hpSum or 0) + snapshot.hp; bucket.hpSamples = (bucket.hpSamples or 0) + 1 end
    if snapshot.targetHP then bucket.targetHpSum = (bucket.targetHpSum or 0) + snapshot.targetHP; bucket.targetHpSamples = (bucket.targetHpSamples or 0) + 1 end
    bucket.enemiesSum = (bucket.enemiesSum or 0) + (Finite(enemies, snapshot.enemies) or snapshot.enemies)
    if reserve ~= nil then bucket.reserveSum = (bucket.reserveSum or 0) + (Finite(reserve, 0) or 0); bucket.reserveSamples = (bucket.reserveSamples or 0) + 1 end
    local dynamics = HCOB.Advisor and HCOB.Advisor.Engine and HCOB.Advisor.Engine.lastDynamics
    local confidence = dynamics and Finite(dynamics.confidence, nil) or nil
    if confidence then
        bucket.confidenceSum = (bucket.confidenceSum or 0) + confidence
        bucket.confidenceSamples = (bucket.confidenceSamples or 0) + 1
        local ttk, ttd = Finite(dynamics.ttk, nil), Finite(dynamics.ttd, nil)
        if ttk and ttk < 1000 then bucket.ttkSum = (bucket.ttkSum or 0) + ttk; bucket.ttkSamples = (bucket.ttkSamples or 0) + 1 end
        if ttd and ttd < 1000 then bucket.ttdSum = (bucket.ttdSum or 0) + ttd; bucket.ttdSamples = (bucket.ttdSamples or 0) + 1 end
    end
end

local function EventSnapshot(fight, spellId, source)
    local tuning = fight.tuning
    local snapshot = ResourceSnapshot()
    local state = tuning._decision
    return {
        t=math.max(0, GetTime() - (fight.startClock or GetTime())), spellId=CanonicalActionId(spellId), source=source,
        recommendedId=state and state.spellId or nil, match=state and SameAction(state.spellId, spellId) or false,
        power=snapshot.power, powerMax=snapshot.powerMax, powerType=snapshot.powerToken,
        mana=snapshot.mana, manaMax=snapshot.manaMax, combo=snapshot.combo,
        hp=snapshot.hp, targetHP=snapshot.targetHP, petHP=snapshot.petHP, enemies=snapshot.enemies,
    }
end

function T.RecordInput(spellId, source)
    local fight = currentFight
    local tuning = fight and fight.tuning
    if not tuning then return end
    spellId, source = CanonicalActionId(spellId), Clean(source or "unknown", 20)
    local now = GetTime()
    local dedupe = tostring(spellId) .. ":" .. source
    if tuning._lastInputKey == dedupe and (now - (tuning._lastInputAt or 0)) < 0.08 then return end
    tuning._lastInputKey, tuning._lastInputAt = dedupe, now
    local stats = tuning.inputStats[tostring(spellId or source)] or {spellId=spellId, source=source, count=0, matched=0}
    stats.count = stats.count + 1
    local event = EventSnapshot(fight, spellId, source)
    if event.match then stats.matched = stats.matched + 1 end
    tuning.inputStats[tostring(spellId or source)] = stats
    if #tuning.inputs < T.MAX_INPUT_EVENTS then tuning.inputs[#tuning.inputs + 1] = event
    else tuning.inputTraceDropped = tuning.inputTraceDropped + 1 end
end

function T.RecordBaseInput()
    local class = HCOB.Classes and HCOB.Classes[PLAYER_CLASS]
    local spellId
    if class and class.GetBaseActionInfo then spellId = class:GetBaseActionInfo(TalentSpec and TalentSpec() or nil) end
    T.RecordInput(spellId, "base")
end

function T.RecordAction(spellId, source)
    local fight = currentFight
    local tuning = fight and fight.tuning
    spellId = CanonicalActionId(spellId)
    if not tuning or not spellId then return end
    source = Clean(source or "cast", 20)
    local now = GetTime()
    if tuning._lastActionId == spellId and (now - (tuning._lastActionAt or 0)) < 0.18
       and tuning._lastActionSource ~= source then return end
    tuning._lastActionId, tuning._lastActionAt, tuning._lastActionSource = spellId, now, source

    local event = EventSnapshot(fight, spellId, source)
    local stats = tuning.actionStats[tostring(spellId)] or {spellId=spellId, count=0, matched=0, deviations=0, reactionSum=0, reactionSamples=0}
    stats.count = stats.count + 1
    local state = tuning._decision
    if state and state.spellId then
        tuning.comparableActions = (tuning.comparableActions or 0) + 1
        local bucket = tuning.decisions[state.key]
        if event.match then
            tuning.matchedActions = (tuning.matchedActions or 0) + 1
            if not state.accepted then
                local reaction = math.max(0, now - (state.since or now))
                state.accepted = true
                stats.matched = stats.matched + 1
                stats.reactionSum = stats.reactionSum + reaction
                stats.reactionSamples = stats.reactionSamples + 1
                event.reaction = reaction
                if bucket then
                    bucket.accepted = (bucket.accepted or 0) + 1
                    bucket.reactionSum = (bucket.reactionSum or 0) + reaction
                    bucket.reactionSamples = (bucket.reactionSamples or 0) + 1
                end
            end
        else
            stats.deviations = stats.deviations + 1
            if bucket then bucket.deviations = (bucket.deviations or 0) + 1 end
        end
    end
    tuning.actionStats[tostring(spellId)] = stats
    if #tuning.actions < T.MAX_ACTION_EVENTS then tuning.actions[#tuning.actions + 1] = event
    else tuning.actionTraceDropped = tuning.actionTraceDropped + 1 end

    if spellId == S.HEROIC_STRIKE or spellId == S.CLEAVE then
        tuning.queue = tuning.queue or {}
        local queue = tuning.queue[tostring(spellId)] or {spellId=spellId, armed=0, consumed=0, missed=0, cleared=0}
        queue.armed = queue.armed + 1
        tuning.queue[tostring(spellId)] = queue
        tuning._lastQueuedSpell = spellId
    end
end

function T.RecordQueueOutcome(spellId, outcome)
    local fight = currentFight
    local tuning = fight and fight.tuning
    spellId = CanonicalActionId(spellId)
    if not tuning or (spellId ~= S.HEROIC_STRIKE and spellId ~= S.CLEAVE) then return end
    tuning.queue = tuning.queue or {}
    local queue = tuning.queue[tostring(spellId)] or {spellId=spellId, armed=0, consumed=0, missed=0, cleared=0}
    outcome = outcome == "missed" and "missed" or "consumed"
    queue[outcome] = (queue[outcome] or 0) + 1
    tuning.queue[tostring(spellId)] = queue
    tuning._lastQueueOutcomeAt = GetTime()
    tuning._lastQueuedSpell = nil
end

function T.SampleResources(fight)
    fight = fight or currentFight
    local tuning = fight and fight.tuning
    if not tuning then return end
    local snapshot = ResourceSnapshot()
    local key = snapshot.powerToken
    local bucket = tuning.resources[key] or {samples=0, sum=0, min=snapshot.power, max=snapshot.power, capSamples=0, highSamples=0, maximum=0}
    bucket.samples = bucket.samples + 1
    bucket.sum = bucket.sum + snapshot.power
    bucket.min = math.min(bucket.min or snapshot.power, snapshot.power)
    bucket.max = math.max(bucket.max or snapshot.power, snapshot.power)
    bucket.maximum = math.max(bucket.maximum or 0, snapshot.powerMax)
    if snapshot.powerMax > 0 and snapshot.power >= snapshot.powerMax * 0.80 then bucket.highSamples = bucket.highSamples + 1 end
    if snapshot.powerMax > 0 and snapshot.power >= snapshot.powerMax * 0.99 then bucket.capSamples = bucket.capSamples + 1 end
    tuning.resources[key] = bucket

    tuning.secondary = tuning.secondary or {samples=0, manaSum=0, manaMin=snapshot.mana, manaMaxObserved=snapshot.mana, comboSum=0, comboMax=0, petHpSum=0, petHpSamples=0}
    local secondary = tuning.secondary
    secondary.samples = secondary.samples + 1
    secondary.manaSum = secondary.manaSum + snapshot.mana
    secondary.manaMin = math.min(secondary.manaMin or snapshot.mana, snapshot.mana)
    secondary.manaMaxObserved = math.max(secondary.manaMaxObserved or snapshot.mana, snapshot.mana)
    secondary.manaMaximum = math.max(secondary.manaMaximum or 0, snapshot.manaMax)
    secondary.comboSum = secondary.comboSum + snapshot.combo
    secondary.comboMax = math.max(secondary.comboMax or 0, snapshot.combo)
    if snapshot.petHP then secondary.petHpSum = secondary.petHpSum + snapshot.petHP; secondary.petHpSamples = secondary.petHpSamples + 1 end

    if PLAYER_CLASS == "WARRIOR" and IsQueuedMeleeSwingSpell then
        local queued = IsQueuedMeleeSwingSpell(S.HEROIC_STRIKE) and S.HEROIC_STRIKE or (IsQueuedMeleeSwingSpell(S.CLEAVE) and S.CLEAVE or nil)
        if tuning._lastQueuedSpell and not queued and (GetTime() - (tuning._lastQueueOutcomeAt or 0)) > 0.25 then
            tuning.queue = tuning.queue or {}
            local queue = tuning.queue[tostring(tuning._lastQueuedSpell)] or {spellId=tuning._lastQueuedSpell, armed=0, consumed=0, missed=0, cleared=0}
            queue.cleared = (queue.cleared or 0) + 1
            tuning.queue[tostring(tuning._lastQueuedSpell)] = queue
        end
        tuning._lastQueuedSpell = queued
        if MainhandSwingQueueOpen then
            local open = MainhandSwingQueueOpen()
            if open and not queued then tuning.queueOpportunitySamples = (tuning.queueOpportunitySamples or 0) + 1 end
        end
    end
end

local function MetricName(name)
    name = Clean(name, 56):gsub("[^%w_%.%-]", "_")
    return name ~= "" and name or nil
end

function T.Increment(name, amount)
    local tuning = currentFight and currentFight.tuning
    name, amount = MetricName(name), Finite(amount, 1) or 1
    if not tuning or not name then return end
    local metric = tuning.metrics[name] or {kind="counter", value=0}
    metric.value = (metric.value or 0) + amount
    tuning.metrics[name] = metric
end

function T.Observe(name, value)
    local tuning = currentFight and currentFight.tuning
    name, value = MetricName(name), Finite(value, nil)
    if not tuning or not name or value == nil then return end
    local metric = tuning.metrics[name] or {kind="distribution", count=0, sum=0, min=value, max=value}
    metric.count = (metric.count or 0) + 1
    metric.sum = (metric.sum or 0) + value
    metric.min = math.min(metric.min or value, value)
    metric.max = math.max(metric.max or value, value)
    tuning.metrics[name] = metric
end

function T.FinalizeFight(fight)
    local tuning = fight and fight.tuning
    if not tuning then return end
    CloseDecision(fight, GetTime())
    for _, bucket in pairs(tuning.resources or {}) do
        local samples = math.max(1, bucket.samples or 0)
        bucket.average = (bucket.sum or 0) / samples
        bucket.highPct = (bucket.highSamples or 0) / samples * 100
        bucket.capPct = (bucket.capSamples or 0) / samples * 100
    end
    for _, bucket in pairs(tuning.candidates or {}) do
        local samples = math.max(1, bucket.samples or 0)
        bucket.scoreAverage = (bucket.scoreSum or 0) / samples
        bucket.selectedPct = (bucket.selected or 0) / samples * 100
    end
    for _, bucket in pairs(tuning.decisions or {}) do
        if (bucket.hpSamples or 0) > 0 then bucket.hpAverage = bucket.hpSum / bucket.hpSamples end
        if (bucket.targetHpSamples or 0) > 0 then bucket.targetHpAverage = bucket.targetHpSum / bucket.targetHpSamples end
        if (bucket.samples or 0) > 0 then
            bucket.powerAverage = (bucket.powerSum or 0) / bucket.samples
            bucket.enemiesAverage = (bucket.enemiesSum or 0) / bucket.samples
        end
        if (bucket.reserveSamples or 0) > 0 then bucket.reserveAverage = bucket.reserveSum / bucket.reserveSamples end
        if (bucket.confidenceSamples or 0) > 0 then bucket.confidenceAverage = bucket.confidenceSum / bucket.confidenceSamples end
        if (bucket.ttkSamples or 0) > 0 then bucket.ttkAverage = bucket.ttkSum / bucket.ttkSamples end
        if (bucket.ttdSamples or 0) > 0 then bucket.ttdAverage = bucket.ttdSum / bucket.ttdSamples end
    end
    local secondary = tuning.secondary
    if secondary then
        local samples = math.max(1, secondary.samples or 0)
        secondary.manaAverage = (secondary.manaSum or 0) / samples
        secondary.comboAverage = (secondary.comboSum or 0) / samples
        if (secondary.petHpSamples or 0) > 0 then secondary.petHpAverage = secondary.petHpSum / secondary.petHpSamples end
    end
    local comparable = tonumber(tuning.comparableActions) or 0
    local matched = tonumber(tuning.matchedActions) or 0
    tuning.adherencePct = comparable > 0 and matched / comparable * 100 or nil

    local context = tuning.context or {}
    local finalContext = ContextSnapshot()
    context.pvp = context.pvp == true or finalContext.pvp == true
    if context.pvp then context.mode = "pvp" end
    context.changedDuringFight = finalContext.talentSignature ~= context.talentSignature
        or finalContext.spellbookSignature ~= context.spellbookSignature
        or finalContext.equipmentSignature ~= context.equipmentSignature
        or finalContext.groupSize ~= context.groupSize
        or finalContext.instanceType ~= context.instanceType
    local reasons = {}
    local duration = tonumber(fight.duration) or 0
    if duration < 4 then reasons[#reasons + 1] = "short" end
    if context.pvp then reasons[#reasons + 1] = "pvp" end
    if fight.endReason ~= "combat_end" then reasons[#reasons + 1] = "incomplete" end
    if context.changedDuringFight then reasons[#reasons + 1] = "context_changed" end
    if fight.died then reasons[#reasons + 1] = "death" end
    if comparable < 1 then reasons[#reasons + 1] = "no_correlated_actions" end
    if comparable > 0 and (tuning.adherencePct or 0) < 35 then reasons[#reasons + 1] = "low_adherence" end
    tuning.eligibility = {
        mode=context.mode, safety=(duration >= 2 and not context.pvp and fight.endReason == "combat_end"),
        dps=(duration >= 4 and not context.pvp and not fight.died and fight.endReason == "combat_end" and not context.changedDuringFight),
        adaptive=(duration >= 4 and not context.pvp and not fight.died and fight.endReason == "combat_end" and not context.changedDuringFight and comparable >= 1 and (tuning.adherencePct or 0) >= 35),
        reasons=reasons,
    }
    tuning._decision = nil
    tuning._lastInputKey, tuning._lastInputAt = nil, nil
    tuning._lastActionId, tuning._lastActionAt, tuning._lastActionSource = nil, nil, nil
    tuning._lastQueuedSpell, tuning._lastQueueOutcomeAt = nil, nil
end

-- Stable internal/public extension points for every class module. Future class
-- tuners add observations here without changing the SavedVariables schema.
T.HashParts = HashParts
T.ContextSnapshot = ContextSnapshot
T.PolicySnapshot = PolicySnapshot
T.CanonicalActionId = CanonicalActionId
T.SameAction = SameAction

InitFightTuningTelemetry = T.InitFight
RecordTuningRecommendation = T.RecordRecommendation
RecordTuningInput = T.RecordInput
RecordTuningBaseInput = T.RecordBaseInput
RecordTuningAction = T.RecordAction
RecordTuningQueueOutcome = T.RecordQueueOutcome
SampleTuningResources = T.SampleResources
FinalizeFightTuningTelemetry = T.FinalizeFight
TuningMetricIncrement = T.Increment
TuningMetricObserve = T.Observe
