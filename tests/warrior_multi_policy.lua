local hostGlobal = _G
local environment = setmetatable({}, {__index=hostGlobal})
environment._G = environment
environment.print = function() end

local rage, reserve, enemyCount = 20, 70, 2
local known, usable, ready, debuffs = {}, {}, {}, {}
local S = {
    HEROIC_STRIKE=78, CLEAVE=845, EXECUTE=5308, OVERPOWER=7384,
    MORTAL_STRIKE=12294, BLOODTHIRST=23881, WHIRLWIND=1680,
    HAMSTRING=1715, SHIELD_WALL=871, RETALIATION=20230,
    THUNDER_CLAP=6343, DEMO_SHOUT=1160, PUMMEL=6552,
    SHIELD_BASH=72, BATTLE_SHOUT=6673,
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
environment.HasMyTargetDebuff = function(id)
    local state = debuffs[id]
    return state ~= nil, state or 0
end
environment.StablePlayerBuff = function() return false, 0 end
environment.SpellName = function(id) return id and ("Spell" .. tostring(id)) end
environment.UnitHealthPct = function() return 90, true end
environment.CountActiveEnemies = function() return enemyCount end
environment.PlayerLevel = function() return 40 end
environment.SafeUnitLevel = function() return 40 end
environment.SafeUnitClassification = function() return "normal" end
environment.GetTime = function() return 100 end

local Engine = environment.HCOneButton.Advisor.Engine
Engine.SurvivalReserve = function() return reserve, reserve <= 45 and "LOW" or "HIGH" end
Engine.RollingDynamics = function() return nil end
Engine.AddCandidate = function(list, id, title, key, reason, score, tag, displayKind)
    list[#list + 1] = {
        id=id, title=title, key=key, reason=reason,
        score=score, tag=tag, displayKind=displayKind,
    }
end
Engine.SelectCandidate = function(list)
    local best
    for _, candidate in ipairs(list or {}) do
        if not best or candidate.score > best.score then best = candidate end
    end
    if best then return best.id, best.title, best.key, best.reason, best.displayKind end
end

local chunk = assert(loadfile("HCOneButton/Classes/Warrior.lua"))
setfenv(chunk, environment)
assert(chunk() == nil)
local Warrior = environment.HCOneButton.Classes.WARRIOR

local function expect(actual, wanted, label)
    assert(actual == wanted, string.format("%s: expected %s, got %s", label, tostring(wanted), tostring(actual)))
end

local function enable(id, canUse)
    known[id], ready[id] = true, true
    usable[id] = canUse ~= false
end

local function reset()
    rage, reserve, enemyCount = 20, 70, 2
    known, usable, ready, debuffs = {}, {}, {}, {}
end

-- Missing mitigation is applied once, in order.
reset()
enable(S.THUNDER_CLAP)
enable(S.DEMO_SHOUT)
local id, title = Warrior:GetMultiPullRecommendation(2, 90, 80)
expect(id, S.THUNDER_CLAP, "missing Thunder Clap")
debuffs[S.THUNDER_CLAP] = 20
id = Warrior:GetMultiPullRecommendation(2, 90, 80)
expect(id, S.DEMO_SHOUT, "missing Demoralizing Shout")

-- Healthy debuffs do not consume more Rage/GCDs. Their final three seconds are
-- refreshable, after which a healthy two-target pull yields to normal scoring.
debuffs[S.DEMO_SHOUT] = 20
id, title = Warrior:GetMultiPullRecommendation(2, 90, 80)
expect(id, nil, "healthy two-target setup has no forced action")
expect(title, nil, "healthy two-target setup yields to rotation")
enable(S.MORTAL_STRIKE)
id = Warrior:GetRecommendation(true, true, 80, 1)
expect(id, S.MORTAL_STRIKE, "healthy two-target pull resumes core DPS scorer")
debuffs[S.THUNDER_CLAP] = 3
id = Warrior:GetMultiPullRecommendation(2, 90, 80)
expect(id, S.THUNDER_CLAP, "Thunder Clap final-three-second refresh")

-- Survival Reserve remains authoritative even when raw HP is still high.
debuffs[S.THUNDER_CLAP], debuffs[S.DEMO_SHOUT] = 20, 20
reserve = 45
enable(S.HAMSTRING)
id, title = Warrior:GetMultiPullRecommendation(2, 90, 80)
expect(id, S.HAMSTRING, "low-reserve two-target escape setup")
expect(title, "MULTI x2 - RISK", "low-reserve warning preserved")

-- Three-target setup also suppresses healthy debuffs and cannot advertise an
-- unusable Retaliation in the wrong stance.
reset()
enable(S.RETALIATION, false)
enable(S.THUNDER_CLAP)
enable(S.DEMO_SHOUT)
debuffs[S.THUNDER_CLAP], debuffs[S.DEMO_SHOUT] = 20, 20
id, title = Warrior:GetMultiPullRecommendation(3, 90, 80)
expect(id, nil, "unusable Retaliation suppressed")
expect(title, "3+ MOBS - GET OUT", "three-target danger warning preserved")
usable[S.RETALIATION] = true
id = Warrior:GetMultiPullRecommendation(3, 90, 80)
expect(id, S.RETALIATION, "usable Retaliation preserved")

-- Interrupt choice follows actual stance/equipment usability instead of
-- returning the first learned spell whose cooldown happens to be ready.
reset()
enable(S.PUMMEL, false)
enable(S.SHIELD_BASH, true)
id = Warrior:GetInterruptRecommendation()
expect(id, S.SHIELD_BASH, "usable Shield Bash selected over unusable Pummel")
usable[S.SHIELD_BASH] = false
id = Warrior:GetInterruptRecommendation()
expect(id, nil, "no unusable interrupt recommendation")
usable[S.PUMMEL] = true
id = Warrior:GetInterruptRecommendation()
expect(id, S.PUMMEL, "usable Pummel keeps priority")

print("warrior multi-pull/debuff usability regression: PASS")
