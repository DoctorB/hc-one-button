-- Real Warrior/engine/spell/survival modules; only WoW inputs and trend selection are mocked.
return function()
local env = setmetatable({}, {__index=_G})
env._G = env
local S = {
    ATTACK=6603, HEROIC_STRIKE=78, CLEAVE=845, EXECUTE=5308,
    BATTLE_SHOUT=6673, REND=772, CHARGE=100, THUNDER_CLAP=6343, SUNDER_ARMOR=7386,
    HAMSTRING=1715, DEMO_SHOUT=1160, BLOODRAGE=2687,
    OVERPOWER=7384, MORTAL_STRIKE=12294, BLOODTHIRST=23881,
    WHIRLWIND=1680, SHIELD_WALL=871, RETALIATION=20230, PUMMEL=6552, SHIELD_BASH=72,
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
env.GetSpellCooldown = function(id)
    if state.cooldowns[id] then return state.now, state.cooldowns[id], 1 end
    return 0, 0, 1
end
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
env.CountActiveEnemies = function() return state.enemies end
env.PlayerLevel = function() return state.level end
env.SafeUnitLevel = function() return state.targetLevel end
env.SafeUnitClassification = function() return "normal" end
env.HasMyTargetDebuff = function(id) return state.debuffs[id] ~= nil, state.debuffs[id] or 0 end
env.StablePlayerBuff = function(id)
    return id == S.BATTLE_SHOUT and state.shout, state.shout and 60 or 0
end
env.TalentSpec = function() return 1 end
env.ActiveTargetCast = function() return state.targetCast end
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
env.InterruptRecommendation = function() return env.HCOneButton.Classes.WARRIOR:GetInterruptRecommendation() end

local function reset()
    state = {
        now=103, speed=3.5, hp=100, targetHP=70, targetLevel=6,
        rage=50, level=6, enemies=1, inCombat=true, shout=true, known={}, learnedNames={}, usable={}, debuffs={}, cooldowns={},
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
    internal.PLAYER_CLASS="WARRIOR"
    env.HCOneButton.Classes.WARRIOR.riskWarningsOnly=true
    env.HCOneButton.UI.SurvivalStrip=nil
    return state
end

reset()
return {env=env, internal=internal, S=S, names=names, Engine=Engine,
    Warrior=env.HCOneButton.Classes.WARRIOR, reset=reset}
end
