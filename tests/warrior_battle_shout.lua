local hostGlobal = _G
local environment = setmetatable({}, {__index=hostGlobal})
environment._G = environment
environment.print = function() end

local rage = 15
local battleShoutActive, battleShoutRemaining = false, 0
local now = 100

local S = {
    BATTLE_SHOUT=6673, HEROIC_STRIKE=78, CHARGE=100, SHIELD_WALL=871,
    RETALIATION=20230, HAMSTRING=1715, THUNDER_CLAP=6343, DEMO_SHOUT=1160,
}

local internal = setmetatable({
    S=S, knownSpellNames={}, currentFight=nil, currentWarriorAutoRend=false,
}, {__index=environment})
environment.HCOneButton = {
    Internal=internal,
    Classes={WARRIOR={}},
    Advisor={Engine={}},
}
environment.HCOB_DB = {warriorHeroicRage=35, warriorSunderBase=false}

environment.SafeNumber = function(value, fallback) return tonumber(value) or fallback end
environment.SafeUnitPower = function() return rage end
environment.UnitPowerType = function() return 1 end
environment.UnitHealthPct = function() return 100, true end
environment.CountActiveEnemies = function() return 1 end
environment.PlayerLevel = function() return 30 end
environment.SafeUnitLevel = function() return 30 end
environment.SafeUnitClassification = function() return "normal" end
environment.GetTime = function() return now end
environment.IsKnown = function(id) return id == S.BATTLE_SHOUT end
environment.IsUsable = function(id) return id == S.BATTLE_SHOUT end
environment.CooldownReady = function() return false end
environment.HasMyTargetDebuff = function() return false end
environment.HasPlayerBuff = function(id)
    if id == S.BATTLE_SHOUT then return battleShoutActive, battleShoutRemaining end
    return false, 0
end
environment.StablePlayerBuff = environment.HasPlayerBuff
environment.SpellName = function(id)
    if id == S.BATTLE_SHOUT or id == 5242 then return "Battle Shout" end
end

local Engine = environment.HCOneButton.Advisor.Engine
Engine.SurvivalReserve = function() return 80, "HIGH" end
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

-- Missing Battle Shout is deliberately manual outside combat, but must enter
-- the combat rotation when there is enough Rage and fight duration.
battleShoutActive, battleShoutRemaining = false, 0
local id = Warrior:GetBuffRecommendation(false)
expect(id, nil, "missing out-of-combat Battle Shout suppressed")
id = Warrior:GetRecommendation(true, true, 80, 1)
expect(id, S.BATTLE_SHOUT, "missing combat Battle Shout requested")
id = Warrior:GetRecommendation(true, true, 25, 1)
expect(id, S.BATTLE_SHOUT, "missing combat Battle Shout ignores short-fight estimate")

-- A healthy active duration is never refreshed.
battleShoutActive, battleShoutRemaining = true, 60
id = Warrior:GetBuffRecommendation(false)
expect(id, nil, "60-second out-of-combat Battle Shout suppressed")
id = Warrior:GetRecommendation(true, true, 80, 1)
expect(id, nil, "60-second combat Battle Shout suppressed")

-- The exact ten-second boundary is refreshable only in combat; lower Rage
-- still preserves the manual refresh decision.
battleShoutActive, battleShoutRemaining, now = true, 10, 102
id = Warrior:GetBuffRecommendation(false)
expect(id, nil, "ten-second out-of-combat refresh suppressed")
id = Warrior:GetRecommendation(true, true, 80, 1)
expect(id, S.BATTLE_SHOUT, "ten-second combat refresh")

rage = 9
id = Warrior:GetRecommendation(true, true, 80, 1)
expect(id, nil, "combat refresh preserves Rage floor")

-- Once the buff expires and is reported absent, it remains manual outside
-- combat. Shared aura tests cover rank-safe spellcast/aura-race protection.
rage = 15
battleShoutActive, battleShoutRemaining, now = false, 0, 200
id = Warrior:GetBuffRecommendation(false)
expect(id, nil, "expired Battle Shout remains manual")

local eventsSource = assert(io.open("HCOneButton/Core/Events.lua", "rb")):read("*a")
assert(eventsSource:find("class:HandleEvent(event, eventArg1, eventArg2, eventArg3)", 1, true),
    "class event dispatch must forward UNIT_SPELLCAST spellID")

print("warrior Battle Shout maintenance regression: PASS")
