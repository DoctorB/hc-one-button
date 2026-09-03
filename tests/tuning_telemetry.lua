local hostGlobal = _G
local environment = setmetatable({}, {__index = hostGlobal})
environment._G = environment

local clock = 0
local powerType, powerToken, power, powerMaximum = 0, "MANA", 80, 100
local playerHP, targetHP, petHP = 92, 75, 88
local enemies = 1

environment.PLAYER_CLASS = "DRUID"
environment.VERSION = "1.28.6"
environment.S = {HEROIC_STRIKE = 78, CLEAVE = 845}
environment.HCOB_DB = {
    criticalHP=22, dangerHP=35, enemyWindow=8, hcDangerAdvisor=true,
    prePullSafety=true, smartDisplay=true, warriorAutoRend=true,
    warriorHeroicRage=35, warriorSunderBase=1,
}
environment.GetTime = function() return clock end
environment.GetServerTime = function() return 1788400000 end
environment.PlayerLevel = function() return 42 end
environment.TalentSpec = function() return 2, "Feral", 31 end
environment.TalentTabCompat = function(tab) return "Tab " .. tab, tab == 2 and 31 or 0 end
environment.GetNumTalents = function() return 0 end
environment.GetSpellBookItemName = function() return nil end
environment.IsKnown = function(id) return id == 101 or id == 102 end
environment.SpellName = function(id) return ({[101]="Claw", [102]="Rake", [999]="Healing Potion"})[id] or ("Spell " .. tostring(id)) end
environment.GetInventoryItemLink = function(_, slot) return "item:" .. tostring(1000 + slot) end
environment.GetInventoryItemID = function(_, slot) return 1000 + slot end
environment.GetNumGroupMembers = function() return 0 end
environment.IsInInstance = function() return false, "none" end
environment.UnitIsPlayer = function() return false end
environment.UnitExists = function(unit) return unit == "player" or unit == "target" or unit == "pet" end
environment.UnitIsDead = function() return false end
environment.UnitPowerType = function() return powerType, powerToken end
environment.SafeUnitPower = function(_, requestedType, fallback)
    if requestedType == powerType then return power end
    if requestedType == 0 then return 64 end
    return fallback
end
environment.SafeUnitPowerMax = function(_, requestedType, fallback)
    if requestedType == powerType then return powerMaximum end
    if requestedType == 0 then return 100 end
    return fallback
end
environment.GetComboPoints = function() return powerToken == "ENERGY" and 3 or 0 end
environment.UnitHealthPct = function(unit)
    if unit == "player" then return playerHP, true end
    if unit == "target" then return targetHP, true end
    if unit == "pet" then return petHP, true end
    return nil, false
end
environment.SafeUnitHealth = function(unit, fallback)
    local pct = unit == "player" and playerHP or (unit == "target" and targetHP or (unit == "pet" and petHP or nil))
    return pct or fallback
end
environment.SafeUnitHealthMax = function(unit, fallback)
    return (unit == "player" or unit == "target" or unit == "pet") and 100 or fallback
end
environment.SafeUnitLevel = function(unit, fallback) return unit == "target" and 43 or fallback end
environment.SafeUnitClassification = function(unit, fallback) return unit == "target" and "normal" or fallback end
environment.CountActiveEnemies = function() return enemies end

environment.HCOneButton = {
    Internal = environment,
    Systems = {},
    Classes = {DRUID = {GetBaseActionInfo = function() return 101 end}},
    UI = {ActionPanel = {actions = {DRUID = {101, 102}}}},
    Advisor = {Engine = {lastCandidates = {}}},
}

local chunk = assert(loadfile("HCOneButton/Systems/TuningTelemetry.lua"))
setfenv(chunk, environment)
chunk()

local tuningAPI = assert(environment.HCOneButton.Systems.TuningTelemetry)
assert(tuningAPI.CONTRACT_VERSION == 1, "unexpected telemetry contract")

local fight = {startClock=0, duration=8, endReason="combat_end", died=false}
environment.currentFight = fight
environment.InitFightTuningTelemetry(fight)
assert(fight.tuning and fight.tuning.context.class == "DRUID", "fight context was not initialized")
assert(fight.tuning.context.spec == "Feral", "spec context missing")
assert(fight.tuning.context.buildSignature:find("^h1%-"), "anonymous build signature missing")
assert(fight.tuning.policy.settings.smartDisplay == true, "policy snapshot missing")
assert(fight.tuning.sessionId:find("^s"), "runtime session identifier missing")

environment.HCOneButton.Advisor.Engine.lastCandidates = {{
    id=101, title="CLAW", tag="damage", score=70, effectiveScore=74,
    tuningMeta={energyFloor=35, form="cat"},
}, {id=102, title="RAKE", tag="dot", score=63}}
environment.HCOneButton.Advisor.Engine.lastDynamics = {confidence=0.75, ttk=8, ttd=15}
clock = 1
environment.RecordTuningRecommendation(101, "CLAW", "BASE", "damage", 68, enemies, true)
clock = 1.1
environment.RecordTuningRecommendation(101, "CLAW", "BASE", "damage", 67, enemies, true)
clock = 1.3
environment.RecordTuningBaseInput()
clock = 1.5
environment.RecordTuningAction(101, "unit_success")

powerType, powerToken, power, powerMaximum = 3, "ENERGY", 46, 100
enemies, targetHP = 2, 54
environment.HCOneButton.Advisor.Engine.lastCandidates = {{id=102, title="RAKE", tag="dot", score=69}}
clock = 2
environment.RecordTuningRecommendation(102, "RAKE", "SHIFT+2", "damage", 61, enemies, true)
environment.SampleTuningResources(fight)
clock = 2.4
environment.RecordTuningInput(102, "action_panel")
clock = 2.6
environment.RecordTuningAction(999, "unit_success")

environment.TuningMetricIncrement("druid.bleed.refresh", 2)
environment.TuningMetricObserve("druid.energy.before_builder", 46)
environment.TuningMetricObserve("druid.energy.before_builder", 54)

-- Bounded traces remain useful without allowing SavedVariables to grow with
-- combat duration or a noisy keyboard/reader loop.
for i=1,70 do
    clock = 3 + i * 0.1
    environment.RecordTuningInput(i % 2 == 0 and 101 or 102, "action_panel")
end

clock = 10
fight.duration = 10
environment.FinalizeFightTuningTelemetry(fight)

local tuning = fight.tuning
assert(tuning.resources.MANA and tuning.resources.ENERGY, "resource/form changes were merged")
assert(tuning.resources.MANA.samples >= 1 and tuning.resources.ENERGY.samples >= 1, "resource samples missing")
assert(tuning.secondary.comboMax == 3, "combo-point context missing")
assert(tuning.secondary.petHpAverage == 88, "pet context missing")
assert(tuning.decisions["101:damage"].meta.energyFloor == 35, "candidate tuning metadata missing")
assert(tuning.decisions["101:damage"].key == "BASE" and tuning.decisions["102:dot"].key == "SHIFT+2",
    "decision input hint missing")
assert(tuning.decisions["101:damage"].accepted == 1, "accepted recommendation missing")
assert(tuning.decisions["101:damage"].reactionSamples == 1 and math.abs(tuning.decisions["101:damage"].reactionSum - 0.5) < 0.001,
    "recommendation reaction time is incorrect")
assert(tuning.candidates["101:damage"].samples == 2 and tuning.candidates["101:damage"].selected == 2,
    "selected candidate exposure missing")
assert(tuning.candidates["102:dot"].samples == 3 and tuning.candidates["102:dot"].selected == 1
    and math.abs(tuning.candidates["102:dot"].scoreAverage - 65) < 0.001,
    "alternative candidate score aggregation missing")
assert(math.abs(tuning.decisions["101:damage"].ttkAverage - 8) < 0.001
    and math.abs(tuning.decisions["101:damage"].ttdAverage - 15) < 0.001,
    "fight-dynamics context missing")
assert(tuning.comparableActions == 2 and tuning.matchedActions == 1, "action correlation is incorrect")
assert(math.abs(tuning.adherencePct - 50) < 0.001, "adherence calculation is incorrect")
assert(tuning.metrics["druid.bleed.refresh"].value == 2, "generic counter extension missing")
assert(tuning.metrics["druid.energy.before_builder"].count == 2, "generic observation extension missing")
assert(#tuning.inputs == tuningAPI.MAX_INPUT_EVENTS and tuning.inputTraceDropped > 0, "input trace was not bounded")
assert(tuning.eligibility.safety and tuning.eligibility.dps and tuning.eligibility.adaptive,
    "clean all-class fight should be eligible for future tuning")
assert(tuning._decision == nil and tuning._lastActionId == nil, "runtime-only telemetry state leaked into the saved fight")

local function containsSensitive(value, seen)
    if type(value) == "string" then return value:find("Sensitive", 1, true) ~= nil end
    if type(value) ~= "table" then return false end
    seen = seen or {}
    if seen[value] then return false end
    seen[value] = true
    for key, child in pairs(value) do
        if containsSensitive(key, seen) or containsSensitive(child, seen) then return true end
    end
    return false
end
environment.UnitName = function() return "SensitiveCharacter" end
environment.UnitGUID = function() return "SensitiveGUID" end
assert(not containsSensitive(tuning), "adaptive telemetry captured character identity")

-- A PvP transition at finalization must invalidate adaptive/DPS learning even
-- if the initial target was an NPC.
environment.UnitIsPlayer = function() return false end
local pvpFight = {startClock=10, duration=6, endReason="combat_end", died=false}
environment.currentFight = pvpFight
clock = 10
environment.InitFightTuningTelemetry(pvpFight)
environment.UnitIsPlayer = function(unit) return unit == "target" end
clock = 16
environment.RecordTuningRecommendation(101, "CLAW", "BASE", "damage", 70, 1, true)
environment.RecordTuningAction(101, "unit_success")
environment.FinalizeFightTuningTelemetry(pvpFight)
assert(pvpFight.tuning.context.pvp and not pvpFight.tuning.eligibility.adaptive and not pvpFight.tuning.eligibility.dps,
    "PvP telemetry was not excluded")

print("adaptive tuning telemetry contract regression: PASS")
