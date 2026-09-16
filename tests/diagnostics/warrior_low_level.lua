-- Standalone diagnosis, not a target rotation policy or a DPS simulation.
-- Run from the repository root with Lua 5.1. The real Warrior, spell helpers,
-- survival reserve, candidate selection, recommendation router and display
-- stabilization are loaded; client state and the selected fight trend are mocked.
-- Thresholds are printed rather than asserted so this probe remains useful
-- when the low-level spending policy changes.
local env = setmetatable({}, {__index=_G})
env._G = env
local S = {
    ATTACK=6603, HEROIC_STRIKE=78, CLEAVE=845, EXECUTE=5308,
    BATTLE_SHOUT=6673, REND=772, CHARGE=100, THUNDER_CLAP=6343,
    HAMSTRING=1715, DEMO_SHOUT=1160, BLOODRAGE=2687,
    OVERPOWER=7384, MORTAL_STRIKE=12294, BLOODTHIRST=23881,
    WHIRLWIND=1680, SHIELD_WALL=871, RETALIATION=20230,
}
local names, ids = {}, {}
for name, id in pairs(S) do names[id], ids[name] = name, id end
local state
local internal = setmetatable({S=S, PLAYER_CLASS="WARRIOR"}, {__index=env})
env.HCOneButton = {
    Internal=internal, Core={}, Classes={}, Systems={}, UI={},
    Advisor={Engine={kindPriority={idle=0, buff=20, action=40,
        caution=70, interrupt=90, danger=100}}},
}
env.GetTime = function() return state.now end
env.MainhandSpeed = function() return state.speed end
env.GetSpellInfo = function(id) return names[id] end
env.IsPlayerSpell = function(id) return state.known[id] == true end
env.IsUsableSpell = function(name)
    local id = ids[name]
    return (state.known[id] == true or state.learnedNames[name] == true) and state.usable[id] ~= false
end
env.GetSpellCooldown = function() return 0, 0, 1 end
env.IsCurrentSpell = function(name) return name == names[state.queued] end
env.CanAccessValue = function() return true end
env.SafeBoolean = function(value, fallback)
    if value == nil then return fallback end
    return value == true or value == 1
end
env.SafeNumber = function(value, fallback) return tonumber(value) or fallback end
env.Clamp = function(value, low, high) return math.max(low, math.min(high, value)) end
env.SafeUnitPower = function() return state.rage end
env.UnitPowerType = function() return 1 end
env.UnitPowerPct = function() return state.rage, true end
env.UnitHealthPct = function(unit) return unit == "target" and state.targetHP or state.hp, true end
env.UnitAffectingCombat = function() return state.inCombat end
env.HostileLiveTarget = function() return true end
env.CountActiveEnemies = function() return 1 end
env.PlayerLevel = function() return 6 end
env.SafeUnitLevel = function() return state.targetLevel end
env.SafeUnitClassification = function() return "normal" end
env.HasMyTargetDebuff = function(id) return state.debuffs[id] ~= nil, state.debuffs[id] or 0 end
env.StablePlayerBuff = function(id)
    return id == S.BATTLE_SHOUT and state.shout, state.shout and 60 or 0
end
env.TalentSpec = function() return 1 end
env.ActiveTargetCast = function() return nil end
env.FightDynamics = function()
    if state.trend then return {ttk=14, ttd=12, confidence=1} end
end

local function load(path)
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk()
end
load("HCOneButton/Core/SpellUtils.lua")
load("HCOneButton/Classes/Warrior.lua")
load("HCOneButton/Advisor/Engine.lua")
load("HCOneButton/Advisor/Survival.lua")
local Engine = env.HCOneButton.Advisor.Engine
Engine.RollingDynamics = function() return nil end
Engine.TrendState = function() return state.trend end
Engine.RangedBaseRecommendation = function() return nil end
Engine.IsRangedHostileSpell = function() return false end
Engine.PrePullRecommendation = function() return nil end

local function reset()
    state = {
        now=103, speed=3.5, hp=100, targetHP=70, targetLevel=6,
        rage=50, inCombat=true, shout=true, known={}, learnedNames={}, usable={}, debuffs={},
    }
    for _, id in ipairs({S.HEROIC_STRIKE, S.BATTLE_SHOUT, S.REND, S.CHARGE, S.THUNDER_CLAP}) do
        state.known[id] = true
    end
    -- Maintenance has already been applied. This isolates why an otherwise
    -- usable damage spender is withheld, without repeatedly requesting auras.
    state.debuffs[S.REND], state.debuffs[S.THUNDER_CLAP] = 12, 20
    internal.currentFight = {startClock=95}
    internal.currentWarriorAutoRend = false
    internal.lastAutoAttack = 100
    internal.knownSpellNames = {}
    env.HCOB_DB = {warriorHeroicRage=35, warriorSunderBase=true}
    Engine.ResetStabilization()
end

local checked = 0
local function expect(actual, wanted, label)
    checked = checked + 1
    assert(actual == wanted, string.format("%s: expected %s, got %s", label, tostring(wanted), tostring(actual)))
end

local function threshold(label, configure)
    reset()
    if configure then configure() end
    for rage=15,100 do
        state.rage = rage
        local id = internal.Recommend()
        if id == S.HEROIC_STRIKE then
            print(string.format("%-48s first HS: %2d rage | reserve %.1f", label, rage, Engine.SurvivalReserve()))
            return rage
        end
    end
    error(label .. ": Heroic Strike never offered, even at 100 rage")
end

print("Level 6, equal-level target, maintained auras, open swing window:")
threshold("Healthy / default option 35")
threshold("Healthy / option lowered to 20", function() env.HCOB_DB.warriorHeroicRage=20 end)
threshold("Healthy / option raised to 50", function() env.HCOB_DB.warriorHeroicRage=50 end)
threshold("37% player HP / default option 35", function() state.hp=37 end)
threshold("Caution trend / no Hamstring learned", function() state.trend="caution" end)
threshold("Caution trend / option lowered to 20", function()
    state.trend="caution"; env.HCOB_DB.warriorHeroicRage=20
end)
threshold("Target at 25% / Execute not learned", function() state.targetHP=25 end)

reset()
state.rage=35
local normalID = internal.Recommend()
state.trend="caution"
local cautionID, cautionTitle = internal.Recommend()
print(string.format("Same 35-rage state: normal=%s | caution=%s (%s)",
    tostring(names[normalID]), tostring(names[cautionID]), tostring(cautionTitle)))

-- Safety and mechanics checks do not prescribe the disputed Rage threshold.
reset()
state.rage=100
expect(internal.Recommend(), S.HEROIC_STRIKE, "spends high Rage near swing")
state.now=100.5
expect(internal.Recommend(), nil, "does not advertise HS for entire slow swing")
state.now=103
state.queued=S.HEROIC_STRIKE
expect(internal.Recommend(), nil, "does not repeat an armed Heroic Strike")
state.queued=S.CLEAVE
expect(internal.Recommend(), nil, "shared queue blocks Heroic Strike")
state.queued=nil
state.usable[S.HEROIC_STRIKE]=false
expect(internal.Recommend(), nil, "unusable HS is not requested")
state.usable[S.HEROIC_STRIKE]=true
state.known[S.HEROIC_STRIKE]=nil
expect(internal.Recommend(), nil, "unlearned HS is not requested")
internal.knownSpellNames[names[S.HEROIC_STRIKE]]=true
state.learnedNames[names[S.HEROIC_STRIKE]]=true
expect(internal.Recommend(), S.HEROIC_STRIKE, "learned higher-rank name fallback")

reset()
state.rage=50
state.shout=false
expect(internal.Recommend(), S.BATTLE_SHOUT, "missing combat buff still applied")
state.shout=true
expect(internal.Recommend(), S.HEROIC_STRIKE, "active buff does not consume the suggestion")
state.targetHP=25
expect(internal.Recommend(), S.HEROIC_STRIKE, "no pooling for unlearned Execute")
state.known[S.EXECUTE]=true
local id, title = internal.Recommend()
expect(id, nil, "learned Execute preserves Rage")
expect(title, "POOL FOR EXECUTE", "learned Execute hold is explicit")
state.hp=20
local _, _, _, _, kind = internal.Recommend()
expect(kind, "danger", "real HP emergency preempts damage")

-- Use the real 0.20s stabilizer and a 0.12s refresh interval over varied
-- heartbeat phases. Check that HS actually becomes visible before the swing,
-- not just that the class scorer briefly emits it.
local scenarios, minimumVisible, minimumSpeed = 0, math.huge, nil
for _, speed in ipairs({1.3, 2.0, 2.8, 3.5, 4.0}) do
    for phase=0,11 do
        reset()
        state.speed=speed
        state.rage=50
        state.now=100
        Engine.Stabilize(internal.Recommend())
        local firstVisible
        for tick=0,math.ceil(speed/0.12) do
            state.now=100 + phase/100 + tick*0.12
            if state.now >= 100 + speed then break end
            local visible = Engine.Stabilize(internal.Recommend())
            if visible == S.HEROIC_STRIKE then
                firstVisible=firstVisible or state.now
            end
        end
        expect(firstVisible ~= nil, true, "visible swing window " .. speed .. "/" .. phase)
        local visibleLead=100+speed-firstVisible
        if visibleLead < minimumVisible then minimumVisible, minimumSpeed=visibleLead, speed end
        state.queued=S.HEROIC_STRIKE
        expect(Engine.Stabilize(internal.Recommend()), nil, "queue acknowledgment clears the displayed HS")
        scenarios=scenarios+1
    end
end
print(string.format("Swing + display: %d/%d timing scenarios; shortest visible lead %.2fs (%.1fs weapon)",
    scenarios, scenarios, minimumVisible, minimumSpeed))
print(string.format("Safety/mechanics assertions: %d passed. No live combat data or DPS estimate used.", checked))
