local env = setmetatable({}, {__index=_G})
env._G = env
env.HCOB_DB = {}
env.S = {HEROIC_STRIKE=78, CLEAVE=845}
env.playerGUID = "player"
env.SafeString = function(v, fallback) return type(v) == "string" and v or fallback end
env.SafeNumber = function(v, fallback) return tonumber(v) or fallback end
env.SafeBoolean = function(v, fallback) if type(v) == "boolean" then return v end; return fallback end
env.SafeUnitGUID = function(unit) return unit == "pet" and "our-pet" or "player" end
env.IsPlayerOrPetGUID = function(guid) return guid == "player" or guid == "our-pet" end
env.COMBATLOG_OBJECT_TYPE_PLAYER = 1
env.COMBATLOG_OBJECT_CONTROL_PLAYER = 2
env.COMBATLOG_OBJECT_REACTION_HOSTILE = 4
env.bit = {band=function(a, b)
    local result, place = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then result = result + place end
        a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
    end
    return result
end}
env.HCOneButton = {Internal=env}
local chunk = assert(loadfile("HCOneButton/Systems/CombatLog.lua"))
setfenv(chunk, env)
chunk()
env.AddEnemyToFight = function() end
env.AbilityRecord = function() return {hits=0, damage=0, overkill=0, resisted=0, blocked=0, absorbed=0,
    crits=0, misses=0, casts=0, missTypes={}} end

local function check(event, src, srcFlags, dst, dstFlags, expected, aura)
    env.currentFight = {tuning={context={mode="solo",pvp=false},adaptiveContextKey="cached-pve"},
        damageDone=0, outgoingHits=0, maxHitDone=0, crits=0, petDamage=0,
        damageTaken=0, incomingHits=0, maxHitTaken=0, healingDone=0,
        misses=0,dodges=0,parries=0,blocks=0,resists=0}
    local args = {[2]=event,[4]=src,[5]="Source",[6]=srcFlags,[8]=dst,[9]="Destination",[10]=dstFlags,
        [12]=123,[13]="Spell",[14]=1,[15]=aura or 10,[16]=0}
    env.ProcessCombatTelemetry(args)
    assert(env.currentFight.tuning.context.pvp == expected,
        event .. " " .. src .. " -> " .. dst .. ": incorrect PvP classification")
    assert(env.currentFight.tuning.context.mode == (expected and "pvp" or "solo"))
    assert((env.currentFight.tuning.adaptiveContextKey == nil) == expected,
        "PvP cache invalidation inconsistent with event")
end

check("SPELL_HEAL", "friendly", 3, "player", 3, false)
check("SPELL_HEAL", "player", 3, "friendly", 3, false)
check("SPELL_AURA_APPLIED", "friendly", 3, "player", 3, false, "BUFF")
check("SPELL_AURA_APPLIED", "friendly", 3, "player", 3, false, "DEBUFF")
check("SPELL_DAMAGE", "bystander", 7, "other-bystander", 3, false)
check("SPELL_DAMAGE", "friendly", 3, "creature", 0, false)
check("SPELL_DAMAGE", "creature", 4, "player", 3, false)
check("SPELL_AURA_APPLIED", "creature", 4, "player", 3, false, "DEBUFF")
check("SPELL_DAMAGE", "enemy", 7, "player", 3, true)
check("SPELL_DAMAGE", "player", 3, "enemy", 7, true)
check("SPELL_MISSED", "player", 3, "neutral-duel-player", 3, true, "MISS")
check("SPELL_DAMAGE", "enemy-pet", 6, "our-pet", 2, true)
check("SPELL_DAMAGE", "our-pet", 2, "enemy-pet", 6, true)
check("SPELL_AURA_APPLIED", "enemy", 7, "player", 3, true, "DEBUFF")
check("SPELL_INTERRUPT", "enemy", 7, "our-pet", 2, true)

print("tuning actual-PvP event isolation: PASS")
