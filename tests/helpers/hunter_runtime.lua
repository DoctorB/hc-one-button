-- Real Hunter policy, range, spell, macro, stabilization and combat-log code.
-- Only client inputs (and unrelated telemetry persistence) are simulated.
return function()
local env = setmetatable({}, {__index=_G})
env._G = env
local I = setmetatable({PLAYER_CLASS="HUNTER", MACRO_LIMIT=255}, {__index=env})
env.HCOneButton = {Internal=I, Data={}, Core={}, Classes={}, Hunter={}, Systems={}, UI={},
    Advisor={Engine={kindPriority={idle=0, action=40, buff=20, caution=70, interrupt=90, danger=100}}}}
local function load(path)
    local chunk = assert(loadfile("HCOneButton/" .. path))
    setfenv(chunk, env)
    chunk()
end
load("Data/Spells.lua")
local S, state = env.HCOneButton.Data.Spells
I.S = S
local names, ids = {}, {}
for name, id in pairs(S) do names[id], ids[name] = name, id end
env.GetTime = function() return state.now end
env.GetSpellInfo = function(id)
    local name = names[id] or (ids[id] and id)
    return name, nil, 1, name == names[S.AIMED_SHOT] and 3000 or 0
end
env.IsPlayerSpell = function(id) return state.known[id] == true end
env.IsUsableSpell = function(name) return state.usable[ids[name]] ~= false end
env.GetSpellCooldown = function(id)
    if state.cooldowns[id] then return state.now, state.cooldowns[id], 1 end
    return 0, 0, 1
end
env.IsSpellInRange = function(name) return state.ranges[ids[name]] end
env.IsCurrentSpell = function(name) return name == names[state.queued] end
local function autoQuery() return state.autoActive end
env.IsAutoRepeatSpell = autoQuery
env.GetUnitSpeed = function() return state.moving and 7 or 0 end
env.UnitRangedDamage = function() return 2.8 end
env.IsPlayerAttacking = function() return state.meleeActive end
env.CheckInteractDistance = function() return state.interact end
env.CanAccessValue = function() return true end
env.SafeBoolean = function(v, fallback) if v == nil then return fallback end; return v == true or v == 1 end
env.SafeNumber = function(v, fallback) return tonumber(v) or fallback end
env.SafeString = function(v, fallback) return type(v) == "string" and v or fallback end
env.Clamp = function(v, low, high) return math.max(low, math.min(high, v)) end
env.UnitExists = function(unit)
    if unit == "pet" then return state.pet end
    if unit == "target" then return state.hostile end
    if unit == "targettarget" then return state.targetOfTarget ~= nil end
    return unit == "player"
end
env.UnitIsDead = function(unit) return unit == "pet" and state.petDead or false end
env.UnitIsDeadOrGhost = env.UnitIsDead
env.UnitCanAttack = function() return state.hostile end
env.UnitIsUnit = function(a, b) return a == "targettarget" and b == state.targetOfTarget end
env.UnitHealthPct = function(unit) return unit == "pet" and state.petHP or state.hp, true end
env.UnitPowerPct = function() return state.mana, true end
env.UnitAffectingCombat = function() return state.inCombat end
env.InCombatLockdown = env.UnitAffectingCombat
env.CountActiveEnemies = function() return state.enemies end
env.PlayerLevel = function() return state.level end
env.SafeUnitLevel = function(unit) return unit == "player" and state.level or state.targetLevel end
env.SafeUnitClassification = function() return "normal" end
env.SafeUnitGUID = function(unit)
    if unit == "player" then return "player" end
    if unit == "pet" then return state.pet and "pet" or nil end
    return state.guid
end
env.HasMyTargetDebuff = function(id) return state.debuffs[id] == true end
env.StablePlayerBuff = function(id) return state.buffs[id] == true end
env.StablePetBuff = function(id) return state.petBuffs[id] == true end
env.UnitCastingInfo = function() return state.casting end
env.UnitChannelInfo = function() return state.channeling end
env.IsPlayerOrPetGUID = function(guid) return guid == "player" or guid == "pet" end
env.MarkEnemy = function() end
env.RemoveEnemy = function() end
env.CombatLogGetCurrentEventInfo = function() return unpack(state.event, 1, 14) end
load("Core/SpellUtils.lua")
load("Core/Range.lua")
load("Core/Macros.lua")
load("Hunter/Pet.lua")
load("Hunter/Ammo.lua")
load("Hunter/Aspects.lua")
load("Classes/Hunter.lua")
load("Advisor/Engine.lua")
load("Systems/CombatLog.lua")
local H, Engine, Class = env.HCOneButton.Hunter, env.HCOneButton.Advisor.Engine, env.HCOneButton.Classes.HUNTER
Engine.SurvivalReserve = function() return state.reserve, "test" end
Engine.RollingDynamics = function() return state.dynamics end
Engine.TargetOnPlayer = function() return state.targetOfTarget == "player" end
H.InvalidateFood = function() end
H.PetIsEating = function() return false end
H.Happiness = function() return 3 end
H.FeedMacro = function() return "/stopmacro" end
local function reset()
    state = {now=100, known={}, usable={}, cooldowns={}, ranges={}, buffs={}, debuffs={}, petBuffs={},
        hostile=true, inCombat=true, level=6, targetLevel=6, targetHP=70, mana=100, hp=100,
        pet=false, petHP=100, reserve=80, autoActive=true, meleeActive=true, enemies=1, guid="target-a"}
    state.known[S.AUTO_SHOT], state.known[S.RAPTOR_STRIKE], state.known[S.ARCANE_SHOT] = true, true, true
    state.ranges[S.AUTO_SHOT], state.ranges[S.ARCANE_SHOT], state.ranges[S.RAPTOR_STRIKE] = true, true, false
    I.knownSpellNames = {}
    env.HCOB_DB = {combatLogging=false}
    H.ResetTargetState(true)
    H.lastAutoShotAt, H.lastMeleeAt, H.combatEnteredAt, H.autoRepeatActive = nil, nil, nil, false
    Engine.ResetStabilization()
    env.IsAutoRepeatSpell = autoQuery
    return state
end
local function recommend()
    return Class:GetRecommendation(state.inCombat, state.hostile, state.targetHP, state.spec or 1)
end
local function candidate(id)
    recommend()
    for _, c in ipairs(Engine.lastCandidates or {}) do if c.id == id then return c end end
end
local function event(kind, id, dest, source)
    state.event = {[1]=state.now, [2]=kind, [4]=source or "player", [8]=dest or state.guid,
        [12]=id, [13]=names[id] or state.eventName}
    I.CombatLogHandler()
end
reset()
return {env=env, I=I, S=S, H=H, Class=Class, Engine=Engine, names=names,
    reset=reset, recommend=recommend, candidate=candidate, event=event}
end
