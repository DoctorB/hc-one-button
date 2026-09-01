local hostGlobal = _G
local environment = setmetatable({}, {__index=hostGlobal})
environment._G = environment
environment.print = function() end

local rage, reserve = 0, 60
local known, usable, ready, debuffs = {}, {}, {}, {}

local S = {
    EXECUTE=5308, OVERPOWER=7384, MORTAL_STRIKE=12294, BLOODTHIRST=23881,
    WHIRLWIND=1680, HEROIC_STRIKE=78, HAMSTRING=1715, SHIELD_WALL=871,
    RETALIATION=20230, THUNDER_CLAP=6343, DEMO_SHOUT=1160,
}

local internal = setmetatable({S=S, knownSpellNames={}}, {__index=environment})
environment.HCOneButton = {
    Internal=internal,
    Classes={WARRIOR={}},
    Advisor={Engine={}},
}
environment.HCOB_DB = {warriorHeroicRage=35}

environment.SafeNumber = function(value, fallback) return tonumber(value) or fallback end
environment.UnitPowerType = function() return 1 end
environment.SafeUnitPower = function() return rage end
environment.IsKnown = function(id) return known[id] == true end
environment.IsUsable = function(id) return usable[id] == true end
environment.CooldownReady = function(id) return ready[id] == true end
environment.HasMyTargetDebuff = function(id) return debuffs[id] == true end
environment.SpellName = function(id) return id and ("Spell" .. tostring(id)) end

local Engine = environment.HCOneButton.Advisor.Engine
Engine.SurvivalReserve = function() return reserve, reserve < 30 and "CRITICAL" or "MED" end

local chunk = assert(loadfile("HCOneButton/Classes/Warrior.lua"))
setfenv(chunk, environment)
assert(chunk() == nil)

local Warrior = environment.HCOneButton.Classes.WARRIOR

local function expect(actual, wanted, label)
    assert(actual == wanted, string.format("%s: expected %s, got %s", label, tostring(wanted), tostring(actual)))
end

local function enable(id)
    known[id], usable[id], ready[id] = true, true, true
end

local function reset()
    rage, reserve = 0, 60
    known, usable, ready, debuffs = {}, {}, {}, {}
end

local caution = {
    hp=64, targetHP=70, reserve=44,
    text="You ~12s / mob ~10s",
}

-- Below the excess-Rage threshold, escape preparation keeps priority.
reset()
rage = 35
enable(S.HAMSTRING)
local id = Warrior:GetCautionRecommendation(caution)
expect(id, S.HAMSTRING, "low Rage keeps Hamstring priority")

-- Once Rage is high, spend it before returning to the escape plan. Core and
-- proc spenders beat Heroic Strike when both are available.
reset()
rage = 50
enable(S.HAMSTRING)
enable(S.HEROIC_STRIKE)
id = Warrior:GetCautionRecommendation(caution)
expect(id, S.HEROIC_STRIKE, "excess Rage beats preventive Hamstring")

enable(S.MORTAL_STRIKE)
id = Warrior:GetCautionRecommendation(caution)
expect(id, S.MORTAL_STRIKE, "core strike beats Heroic Strike")

enable(S.OVERPOWER)
id = Warrior:GetCautionRecommendation(caution)
expect(id, S.OVERPOWER, "reactive Overpower beats core strike")

-- With Hamstring already active and no excess Rage, caution remains a visual
-- escape warning instead of inventing an offensive action.
reset()
rage = 35
enable(S.HAMSTRING)
debuffs[S.HAMSTRING] = true
id = Warrior:GetCautionRecommendation(caution)
expect(id, nil, "no forced spender below threshold")

-- A controlled two-target pull may spend excess Rage after mitigation/debuff
-- setup, while true panic paths still preempt DPS.
reset()
rage = 50
enable(S.HEROIC_STRIKE)
local multiID, multiTitle, _, _, multiKind = Warrior:GetMultiPullRecommendation(2, 75, 70)
expect(multiID, S.HEROIC_STRIKE, "stable two-target Rage dump")
expect(multiTitle, "MULTI x2 - SPEND RAGE", "stable multi-pull spender title")
expect(multiKind, "caution", "stable multi-pull severity")

multiID, _, _, _, multiKind = Warrior:GetMultiPullRecommendation(2, 60, 70)
expect(multiID, S.HEROIC_STRIKE, "risky two-target Rage dump")
expect(multiKind, "danger", "risky multi-pull keeps danger severity")

reset()
rage = 100
enable(S.HEROIC_STRIKE)
enable(S.HAMSTRING)
multiID = Warrior:GetMultiPullRecommendation(3, 90, 70)
expect(multiID, S.HAMSTRING, "three-target panic preempts Rage dump")

multiID = Warrior:GetMultiPullRecommendation(2, 50, 70)
expect(multiID, S.HAMSTRING, "low-HP multi-pull panic preempts Rage dump")

print("warrior escape Rage regression: PASS")
