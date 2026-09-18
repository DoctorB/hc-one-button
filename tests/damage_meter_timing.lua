-- Real combat-log routing, enemy deaths, persistence and backwards-compatible
-- display metrics. No replay/execution of user SavedVariables.
local env=setmetatable({}, {__index=_G}); env._G=env
env.HCOneButton={Internal=env,Systems={},UI={},Advisor={Engine={}},RecordSavedVariableRepair=function() end}
env.HCOB_DB={combatLogging=true}; env.HCOB_CharacterDB={logProfileId="fixture"}
env.HCOB_CombatLog={fights={},totalFights=0,session="fixture"}
env.VERSION="test"; env.playerGUID="player"; env.S={}; env.now=0
env.GetTime=function() return env.now end
env.GetServerTime=env.GetTime
env.PlayerLevel=function() return 16 end
env.TalentSpec=function() return 1,"Spec",5 end
env.SafeUnitGUID=function(unit) return ({player="player",pet="pet",target="selected"})[unit] end
env.SafeUnitName=function() return "Unengaged selected target" end
env.SafeUnitLevel=function() return 16 end
env.SafeUnitClassification=function() return "normal" end
env.SafeUnitHealth=function() return 300 end
env.SafeUnitHealthMax=env.SafeUnitHealth
env.UnitHealthPct=function() return 100,true end
env.UnitPowerType=function() return 1,"RAGE" end
env.SafeUnitPower=function() return 30 end
env.SafeUnitPowerMax=function() return 100 end
env.UnitExists=function() return true end
env.UnitCanAttack=function() return true end
env.UnitAffectingCombat=function() return true end
env.SafeString=function(v,f) return type(v)=="string" and v or f end
env.SafeNumber=function(v,f) return tonumber(v) or f end
env.SafeBoolean=function(v,f) if type(v)=="boolean" then return v end return f end
env.Clamp=function(v,l,h) return math.max(l,math.min(h,v)) end
env.SpellName=function(id) return "Spell"..id end
local output={}; env.print=function(s) output[#output+1]=s end
local chunk=assert(loadfile("HCOneButton/Systems/CombatLog.lua")); setfenv(chunk,env); chunk()
local checks=0
local function expect(actual,wanted,label)
    checks=checks+1
    assert(actual==wanted,label..": expected "..tostring(wanted)..", got "..tostring(actual))
end
local function close(actual,wanted,label) expect(math.abs(actual-wanted)<.00001,true,label) end
local function begin()
    env.now=0; env.StartCombatTelemetry(); return env.currentFight
end
local function event(at,kind,source,dest,damage)
    env.now=at
    local args={[2]=kind,[4]=source,[5]=source,[8]=dest,[9]=dest,[12]=damage or 50,[13]=0,[15]=0}
    if kind=="SWING_MISSED" then args[12]="MISS" end
    if kind=="SPELL_DAMAGE" or kind=="SPELL_PERIODIC_DAMAGE" then
        args[12],args[13],args[15],args[16]=101,"Spell101",damage or 50,0
    end
    env.ProcessCombatTelemetry(args)
end
for _,class in ipairs({"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","MAGE","WARLOCK","DRUID","SHAMAN"}) do
    env.PLAYER_CLASS=class
    local f=begin()
    event(1,"SWING_DAMAGE","player","enemy",100)
    env.now=8
    close(env.DamageMeterDuration(f),8,class.." long swing/resource wait is counted")
    event(10,"SWING_DAMAGE","player","enemy",200)
    event(10,"PARTY_KILL","player","enemy")
    event(10.1,"UNIT_DIED",nil,"enemy")
    env.now=16
    close(env.DamageMeterDuration(f),10,class.." only confirmed post-kill tail is frozen")
    env.FinalizeFightTuningTelemetry=function(fight)
        close(fight.duration,16,"learning keeps full combat duration")
        close(fight.dps,18.75,"learning keeps original combat DPS")
    end
    env.FinalizeCombatTelemetry("combat_end")
    env.FinalizeFightTuningTelemetry=nil
    close(f.damageDuration,10,"new display duration persisted")
    close(f.damageDps,30,"new display DPS persisted")
    expect(f.kills,1,"duplicate death confirmation counted once")
    expect(f._damageEnemies,nil,"runtime enemy identities removed")
    expect(f._damageStoppedAt,nil,"temporary freeze removed")
    close(env.DamageMeterValues(f),30,"saved display uses new denominator")
    close(env.RecentCharacterDPSAverage(1),30,"average uses same denominator")
end
env.PLAYER_CLASS="WARRIOR"
local f=begin()
event(1,"SWING_DAMAGE","player","a",100)
event(2,"SWING_MISSED","b","player")
event(3,"UNIT_DIED",nil,"a")
env.now=8; close(env.DamageMeterDuration(f),8,"living second enemy prevents freeze")
event(10,"SWING_DAMAGE","pet","b",100)
event(10,"UNIT_DIED",nil,"b")
env.now=15; close(env.DamageMeterValues(f),20,"pet damage and death participate")
event(16,"SWING_MISSED","player","c")
close(env.DamageMeterDuration(f),16,"chain pull resumes including the inter-pull gap")
event(20,"SWING_DAMAGE","player","c",100)
event(20,"UNIT_DIED",nil,"c")
env.now=25; env.FinalizeCombatTelemetry("combat_end")
close(f.damageDuration,20,"last engaged enemy determines cutoff")
close(f.duration,25,"chain-pull raw interval preserved")

f=begin(); event(1,"SPELL_DAMAGE","player","enemy",100)
event(8,"SPELL_PERIODIC_DAMAGE","pet","enemy",50)
event(10,"SPELL_PERIODIC_DAMAGE","player","enemy",50)
event(10,"UNIT_DIED",nil,"enemy")
env.now=16; env.FinalizeCombatTelemetry("combat_end")
close(f.damageDuration,10,"spell/DoT/pet routing shares confirmed-death timing")
close(f.damageDps,20,"spell/DoT numerator includes player and pet")

-- Recorded timing that prompted this change: no removal of approach time,
-- only the confirmed post-kill interval before PLAYER_REGEN_ENABLED.
f=begin(); event(.977,"SWING_DAMAGE","player","enemy",140)
event(10.228,"SPELL_DAMAGE","player","enemy",171)
event(10.228,"PARTY_KILL","player","enemy")
env.now=16.502; env.FinalizeCombatTelemetry("combat_end")
close(f.damageDps,311/10.228,"recorded timing displays damage-window DPS")
close(f.dps,311/16.502,"same recorded timing preserves original learner DPS")

f=begin(); event(1,"SWING_DAMAGE","player","enemy",100)
env.now=16; env.FinalizeCombatTelemetry("combat_end")
close(f.damageDuration,16,"fleeing/lost/unknown death is not a confirmed kill")
for _,reason in ipairs({"logout","reload"}) do
    f=begin(); event(1,"SWING_DAMAGE","player","enemy",100); event(10,"UNIT_DIED",nil,"enemy")
    env.now=16; env.FinalizeCombatTelemetry(reason)
    close(f.damageDuration,16,"interrupted recording keeps full interval")
end
f=begin(); event(1,"SWING_DAMAGE","player","enemy",100); event(10,"UNIT_DIED",nil,"enemy")
event(12,"UNIT_DIED",nil,"player")
env.now=16; env.FinalizeCombatTelemetry("combat_end")
close(f.damageDuration,16,"player death does not hide lethal aftermath")
local legacy={duration=16,totalDamage=320,dps=20}
close(env.DamageMeterValues(legacy),20,"legacy records use their recorded duration")
expect(legacy.damageDuration,nil,"legacy record not rewritten")
for _,bad in ipairs({-1,math.huge,0/0,"bad"}) do
    legacy.damageDuration=bad
    close(env.DamageMeterDuration(legacy),16,"invalid saved display timing ignored")
end
print(string.format("Damage meter timing: %d checks PASS",checks))
