local hostGlobal = _G
local environment = setmetatable({}, {__index=hostGlobal})
environment._G = environment
environment.print = function() end

local known, buffs, petBuffs = {}, {}, {}
local now = 100

local internal = setmetatable({}, {__index=environment})
environment.HCOneButton = {
    Internal=internal, Core={}, Data={}, Classes={}, Hunter={},
    Advisor={Engine={}}, UI={}, Systems={},
}

local function loadInto(path)
    local chunk = assert(loadfile(path))
    setfenv(chunk, environment)
    return chunk()
end

environment.GetTime = function() return now end
environment.IsKnown = function(id) return known[id] == true end
environment.IsUsable = function(id) return known[id] == true end
environment.CooldownReady = function() return true end
environment.StablePlayerBuff = function(id)
    local remaining = buffs[id]
    return remaining ~= nil, remaining or 0
end
environment.HasPlayerBuff = environment.StablePlayerBuff
environment.StablePetBuff = function(id)
    local remaining = petBuffs[id]
    return remaining ~= nil, remaining or 0
end
environment.HasMyTargetDebuff = function() return false end
environment.SpellName = function(id, fallback) return id and ("Spell" .. tostring(id)) or fallback end
environment.UnitHealthPct = function() return 100, true end
environment.UnitPowerPct = function() return 100, true end
environment.UnitPowerType = function() return 0 end
environment.SafeUnitPower = function() return 100 end
environment.SafeUnitLevel = function(_, fallback) return fallback end
environment.SafeUnitClassification = function(_, fallback) return fallback end
environment.SafeNumber = function(value, fallback) return tonumber(value) or fallback end
environment.SafeBoolean = function(value, fallback) return value == nil and fallback or value == true end
environment.CanAccessValue = function(value) return value ~= nil end
environment.PlayerLevel = function() return 60 end
environment.TalentSpec = function() return 1 end
environment.MainhandSpeed = function() return 3.0 end
environment.GetComboPoints = function() return 1 end
environment.GetShapeshiftFormID = function() return 0 end
environment.CountActiveEnemies = function() return 1 end
environment.ActiveTargetCast = function() return nil end
environment.HostileLiveTarget = function() return true end
environment.UnitExists = function() return true end
environment.IsInGroup = function() return false end
environment.GetWeaponEnchantInfo = function() return true end
environment.GetItemCount = function() return 0 end
environment.HasWandEquipped = function() return false end
environment.SpellCastSeconds = function() return 0 end
environment.Clamp = function(value, low, high) return math.max(low, math.min(high, value)) end
environment.AuraByName = function() return false, 0 end

loadInto("HCOneButton/Data/Spells.lua")
local S = environment.HCOneButton.Data.Spells
internal.S = S

local Engine = environment.HCOneButton.Advisor.Engine
Engine.AddCandidate = function(list, id, title, key, reason, score, tag, displayKind)
    list[#list + 1] = {id=id, title=title, key=key, reason=reason, score=score or 0, tag=tag, displayKind=displayKind}
end
Engine.SelectCandidate = function(list)
    local best
    for _, candidate in ipairs(list or {}) do
        if not best or candidate.score > best.score then best = candidate end
    end
    if best then return best.id, best.title, best.key, best.reason, best.displayKind end
end
Engine.ManaPct = function() return 100 end
Engine.SurvivalReserve = function() return 80, "HIGH" end
Engine.RollingDynamics = function() return nil end
Engine.TargetIsClose = function() return false end
Engine.TargetOnPlayer = function() return false end
Engine.TargetCreatureTypeID = function() return nil end
Engine.PlayerHasDebuff = function() return false end
Engine.PaladinHealSpell = function() return nil end
Engine.PriestHealSpell = function() return nil end
Engine.TotemActive = function() return false end

environment.HCOneButton.Core.ClassAPI = {
    IsKnown=environment.IsKnown, IsUsable=environment.IsUsable,
    CooldownReady=environment.CooldownReady,
    HasPlayerBuff=environment.HasPlayerBuff,
    StablePlayerBuff=environment.StablePlayerBuff,
    HasMyTargetDebuff=environment.HasMyTargetDebuff,
    SpellCastSeconds=environment.SpellCastSeconds,
    HasWandEquipped=environment.HasWandEquipped,
    SpellName=environment.SpellName,
    AuraByName=environment.AuraByName,
    Clamp=environment.Clamp,
}

loadInto("HCOneButton/Hunter/Aspects.lua")
for _, file in ipairs({"Paladin", "Priest", "Mage", "Warlock", "Druid", "Shaman", "Hunter", "Rogue"}) do
    loadInto("HCOneButton/Classes/" .. file .. ".lua")
end

local Hunter = environment.HCOneButton.Hunter
Hunter.PetAlive = function() return false end
Hunter.ManaPct = function() return 100 end
Hunter.PetHP = function() return nil end
Hunter.TargetIsClose = function() return false end
Hunter.CanShootTarget = function() return true end
Hunter.TargetElapsed = function() return 0 end
Hunter.AfterAutoWindow = function() return false end
Hunter.RangedStableSeconds = function() return 3 end
Hunter.ThreatSnapshot = function() return {state="unknown"} end
Hunter.ThreatPenalty = function() return 0 end
Hunter.AutoShotNeedsRestart = function() return false end
Hunter.MeleeAutoActive = function() return true end
Hunter.TravelStableSeconds = function() return 0 end
Hunter.TargetOnPlayer = function() return false end
Hunter.PetIsTanking = function() return true end

local combatContext = {
    inCombat=true, hostile=true, spec=1,
    player={hp=100, mana=100, grouped=false},
    target={hp=80, close=false, tough=false, onPlayer=false},
    combat={reserve=80, reserveLabel="HIGH", ttk=nil, dynamics=nil},
    pet={alive=false, hp=0, tanking=false},
}
local idleContext = {
    inCombat=false, hostile=true, spec=1,
    player=combatContext.player, target=combatContext.target,
    combat=combatContext.combat, pet=combatContext.pet,
}

local function expect(actual, wanted, label)
    assert(actual == wanted, string.format("%s: expected %s, got %s", label, tostring(wanted), tostring(actual)))
end

local scenarios = {
    {
        token="PALADIN", aura=S.BLESSING_MIGHT, competitor=S.SEAL_RIGHTEOUSNESS,
        evaluate=function(inCombat) return environment.HCOneButton.Classes.PALADIN:GetRecommendation(inCombat, true, 80, 3) end,
    },
    {
        token="PRIEST", aura=S.INNER_FIRE, competitor=S.MIND_BLAST,
        evaluate=function(inCombat) return Engine.SelectCandidate(environment.HCOneButton.Classes.PRIEST:GetCandidates(inCombat and combatContext or idleContext)) end,
    },
    {
        token="MAGE", aura=S.ARCANE_INTELLECT, competitor=S.FROSTBOLT,
        evaluate=function(inCombat) return environment.HCOneButton.Classes.MAGE:GetRecommendation(inCombat, true, 80, 3) end,
    },
    {
        token="WARLOCK", aura=S.DEMON_ARMOR, competitor=S.CORRUPTION,
        evaluate=function(inCombat) return Engine.SelectCandidate(environment.HCOneButton.Classes.WARLOCK:GetCandidates(inCombat and combatContext or idleContext)) end,
    },
    {
        token="DRUID", aura=S.MARK_WILD, competitor=S.WRATH,
        evaluate=function(inCombat) return environment.HCOneButton.Classes.DRUID:GetRecommendation(inCombat, true, 80, 1) end,
    },
    {
        token="SHAMAN", aura=S.LIGHTNING_SHIELD, competitor=S.STORMSTRIKE,
        evaluate=function(inCombat) return environment.HCOneButton.Classes.SHAMAN:GetRecommendation(inCombat, true, 80, 2) end,
    },
}

for _, scenario in ipairs(scenarios) do
    known, buffs, petBuffs = {[scenario.aura]=true}, {}, {}
    expect(scenario.evaluate(false), nil, scenario.token .. " missing aura out of combat")
    expect(scenario.evaluate(true), scenario.aura, scenario.token .. " missing aura in combat")

    known[scenario.competitor] = true
    expect(scenario.evaluate(true), scenario.aura, scenario.token .. " missing aura beats normal rotation")
    known[scenario.competitor] = nil

    buffs[scenario.aura] = 60
    expect(scenario.evaluate(true), nil, scenario.token .. " healthy active aura")

    buffs[scenario.aura] = 10
    expect(scenario.evaluate(true), scenario.aura, scenario.token .. " final-ten-second refresh")
end

-- Contextual combat auras do not use the long-buff refresh boundary, but they
-- must still remain silent while active and outside combat.
known, buffs, petBuffs = {[S.ASPECT_HAWK]=true}, {}, {}
local HunterClass = environment.HCOneButton.Classes.HUNTER
expect(HunterClass:GetRecommendation(false, true, 80, 1), nil, "HUNTER aspect out of combat")
expect(HunterClass:GetRecommendation(true, true, 80, 1), S.ASPECT_HAWK, "HUNTER missing combat aspect")
buffs[S.ASPECT_HAWK] = 999
expect(HunterClass:GetRecommendation(true, true, 80, 1), nil, "HUNTER active combat aspect")

known, buffs, petBuffs = {[S.MEND_PET]=true}, {}, {}
Hunter.PetAlive = function() return true end
Hunter.PetHP = function() return 20 end
expect(HunterClass:GetRecommendation(false, true, 80, 1), nil, "HUNTER Mend Pet out of combat")
expect(HunterClass:GetRecommendation(true, true, 80, 1), S.MEND_PET, "HUNTER missing Mend Pet aura")
petBuffs[S.MEND_PET] = 8
expect(HunterClass:GetRecommendation(true, true, 80, 1), nil, "HUNTER active Mend Pet aura")

known, buffs, petBuffs = {[S.SLICE_DICE]=true}, {}, {}
local RogueClass = environment.HCOneButton.Classes.ROGUE
expect(RogueClass:GetRecommendation(false, true, 80, 2), nil, "ROGUE Slice and Dice out of combat")
expect(RogueClass:GetRecommendation(true, true, 80, 2), S.SLICE_DICE, "ROGUE missing Slice and Dice aura")
buffs[S.SLICE_DICE] = 8
expect(RogueClass:GetRecommendation(true, true, 80, 2), nil, "ROGUE active Slice and Dice aura")

print("multi-class maintenance aura regression: PASS")
