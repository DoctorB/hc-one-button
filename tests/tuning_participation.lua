-- New-fight quality through real telemetry, combat-event routing and learner.
local env=setmetatable({}, {__index=_G})
env._G=env
env.print=function() end
local now, target, level, classification, targetIsPlayer = 0,"enemy",17,"normal",false
env.HCOneButton={Internal=env,Systems={},UI={},Advisor={Engine={}}}
env.HCOB_DB={combatLogging=true}
env.HCOB_CharacterDB={adaptive={version=2,enabled=true,contexts={}}}
env.PLAYER_CLASS,env.VERSION,env.playerGUID="ROGUE","1.29.6","player"
env.S={}
env.GetTime=function() return now end
env.GetServerTime=function() return 1000+now end
env.PlayerLevel=function() return 17 end
env.UnitPowerType=function() return 3,"ENERGY" end
env.SafeUnitPower=function() return 60 end
env.SafeUnitPowerMax=function() return 100 end
env.UnitHealthPct=function() return 100,true end
env.SafeUnitHealthMax=function(unit) if unit=="player" or env.SafeUnitGUID(unit) then return 300 end return 0 end
env.GetNumGroupMembers=function() return 2 end
env.IsInInstance=function() return false,"none" end
env.UnitExists=function(unit) return env.SafeUnitGUID(unit)~=nil end
env.UnitIsPlayer=function(unit) return unit=="player" or (unit=="target" and targetIsPlayer) end
env.SafeUnitGUID=function(unit) return ({player="player",pet="pet",target=target})[unit] end
env.SafeUnitLevel=function() return level end
env.SafeUnitClassification=function() return classification end
env.SafeUnitName=function() return "Observed NPC" end
env.UnitCanAttack=function(_,unit) return unit=="target" and target~=nil and not targetIsPlayer end
env.UnitAffectingCombat=function() return true end
env.SafeString=function(v,fallback) return type(v)=="string" and v or fallback end
env.SafeNumber=function(v,fallback) return tonumber(v) or fallback end
env.SafeBoolean=function(v,fallback) if type(v)=="boolean" then return v end return fallback end
env.SpellName=function(id) return "Spell"..id end
env.TableCount=function(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
env.IsDamageEvent=function(e) return e=="SPELL_DAMAGE" or e=="SWING_DAMAGE" end
env.IsMissEvent=function(e) return e=="SPELL_MISSED" or e=="SWING_MISSED" end
env.CombatLogFlagIsHostile=function(f) return f==1 end
env.DamagePayload=function() return 1752,"Spell1752",20,0,0,0,0,false end
env.MissPayload=function() return 1752,"Spell1752","MISS" end
for _,path in ipairs({"TuningTelemetry","TuningParticipation","AdaptiveTuner","CombatLog"}) do
    local chunk=assert(loadfile("HCOneButton/Systems/"..path..".lua"));setfenv(chunk,env);chunk()
end
local T,P,A=env.HCOneButton.Systems.TuningTelemetry,env.HCOneButton.Systems.TuningParticipation,env.HCOneButton.Systems.AdaptiveTuner
local checks=0
local function expect(actual,wanted,label)
    checks=checks+1;assert(actual==wanted,label..": got "..tostring(actual)..", expected "..tostring(wanted))
end
local function begin()
    now=0
    local f={startClock=0,duration=10,endReason="combat_end",level=17,hpMinPct=100,dps=20,damageDone=0,petDamage=0,
        damageTaken=0,healingDone=0,outgoingHits=0,incomingHits=0,maxHitDone=0,maxHitTaken=0,crits=0,misses=0,dodges=0,parries=0,blocks=0,resists=0}
    env.currentFight=f;T.InitFight(f);P.Begin(f)
    f.tuning.comparableActions,f.tuning.matchedActions=1,1
    return f
end
local function event(name,source,dest,overheal)
    local args={[2]=name,[4]=source or "player",[5]="Source",[6]=1,[8]=dest or "enemy",[9]="Enemy",[10]=1,[12]=1752,[13]="Spell1752",[15]=20,[16]=0}
    if name=="SWING_DAMAGE" then args[12],args[13],args[14],args[15]=20,0,1,0 end
    if name=="SWING_MISSED" then args[12]="MISS" end
    if name=="SPELL_MISSED" then args[15]="MISS" end
    if overheal then args[16]=overheal end
    env.ProcessCombatTelemetry(args)
end
local function finish(f,duration)
    f.duration=duration or 10;now=f.duration;T.FinalizeFight(f)
end
for _,class in ipairs({"WARRIOR","ROGUE","PALADIN","HUNTER","WARLOCK","MAGE","PRIEST","SHAMAN","DRUID"}) do
    env.PLAYER_CLASS=class;target=nil;level=0
    local f=begin()
    expect(f.tuning.context.targetLevel,nil,class.." unknown is not level zero")
    now=0.5;event("SWING_MISSED","enemy","player")
    expect(f.tuning.sampleQuality.knownTarget,false,class.." unknown foe is not invented")
    target="enemy";level=18;P.Sample(f)
    expect(f.tuning.context.targetLevel,18,class.." recover actual opponent level")
    expect(f.target,"Observed NPC",class.." report recovers missing target")
    finish(f)
    expect(f.tuning.eligibility.adaptive,true,class.." valid participation remains eligible")
    expect(f.tuning.learning.processed,true,class.." learner received valid fight")
    expect(f.tuning.learning.difficulty,"even",class.." real level controls difficulty")
    expect(f.tuning._qualityTarget,nil,class.." runtime GUID removed")
end
env.PLAYER_CLASS="ROGUE";target=nil;level=0
local f=begin();now=1;event("SWING_DAMAGE");finish(f)
expect(f.tuning.eligibility.adaptive,false,"unknown target excluded from learning")
expect(f.tuning.learning.reason,"unknown_target","unknown target reason persisted")
expect(f.damageDone,20,"raw damage remains available")
expect(f.duration,10,"raw fight duration is not rewritten")

target="other";level=17;f=begin();now=1;event("SWING_DAMAGE");P.Sample(f);finish(f)
expect(f.tuning.sampleQuality.knownTarget,false,"unrelated selected NPC cannot fill metadata")

target="enemy";f=begin();now=6.5;event("SPELL_CAST_SUCCESS","player","player")
expect(f.tuning.sampleQuality.firstEvent,nil,"noncombat utility success is not participation")
now=8.568;event("SPELL_DAMAGE");finish(f,9.784)
expect(f.tuning.eligibility.adaptive,false,"late tag after Skinning is not a DPS sample")
expect(f.tuning.learning.reason,"late_participation","late entry is explained")
expect(f.tuning.eligibility.safety,true,"safety history is preserved")

f=begin();now=1;event("SPELL_DAMAGE");finish(f,30)
expect(f.tuning.eligibility.adaptive,true,"long resource/control waits are not late entry")
f=begin();now=4;event("SPELL_DAMAGE");finish(f,10)
expect(f.tuning.eligibility.adaptive,true,"four-second pull/cast allowance")
f=begin();now=5;event("SPELL_DAMAGE");finish(f,20)
expect(f.tuning.eligibility.adaptive,true,"25 percent entry boundary")
f=begin();now=5.01;event("SPELL_DAMAGE");finish(f,20)
expect(f.tuning.eligibility.adaptive,false,"late entry beyond both boundaries")

for _,kind in ipairs({"SPELL_CAST_START","SPELL_INTERRUPT"}) do
    f=begin();now=0.1;event(kind);finish(f)
    expect(f.tuning.eligibility.adaptive,true,kind.." supports early participation")
end
f=begin();now=0.1;event("SPELL_DAMAGE","pet","enemy");finish(f)
expect(f.tuning.eligibility.adaptive,true,"pet-first damage is participation")
expect(f.petDamage,20,"pet accounting remains unchanged")
f=begin();now=0.1;event("SPELL_HEAL","player","ally");now=5;event("SWING_DAMAGE","enemy","player");finish(f)
expect(f.tuning.sampleQuality.firstEvent,0.1,"effective early healing counts")
expect(f.tuning.eligibility.adaptive,true,"healing before damage is not late entry")

targetIsPlayer=true;f=begin();now=0.1;event("SPELL_DAMAGE");finish(f)
expect(f.tuning.sampleQuality.knownTarget,false,"selected player cannot become NPC baseline")
targetIsPlayer=false;classification="worldboss";level=-1
f=begin();now=0.1;event("SPELL_DAMAGE");finish(f)
expect(f.tuning.learning.difficulty,"elite","known boss class survives unknown numeric level")
classification="normal";level=17
f=begin();now=0.1;event("SPELL_DAMAGE");target="other";level=50;P.Sample(f);finish(f)
expect(f.tuning.context.targetLevel,17,"later target selection does not rewrite observed difficulty")
target=nil;f=begin();finish(f)
expect(f.tuning.learning.reason,"unknown_target,no_participation","idle group combat is explained")

target="enemy";level=17
f=begin();now=0.1;event("SPELL_HEAL","player","ally",20)
expect(f.tuning.sampleQuality.firstEvent,nil,"pure overheal is not participation")
now=8;event("SPELL_DAMAGE");finish(f)
expect(f.tuning.learning.reason,"late_participation","overheal cannot conceal a late tag")

local guidAPI,levelAPI=env.SafeUnitGUID,env.SafeUnitLevel
env.SafeUnitGUID=function(unit) if unit=="targettarget" then return "enemy" end return guidAPI(unit) end
target="ally";f=begin();now=0.1;event("SPELL_DAMAGE");finish(f)
expect(f.tuning.sampleQuality.knownTarget,true,"ally target can expose the actual opponent")
env.SafeUnitGUID=guidAPI
target="enemy";env.SafeUnitLevel=function() error("unreadable API") end
f=begin();now=0.1;event("SPELL_DAMAGE");finish(f)
expect(f.tuning.learning.reason,"unknown_target","unreadable level is excluded without crashing")
env.SafeUnitLevel=levelAPI

-- Older/direct consumers without sampleQuality still must not classify 0 as easy.
f=begin();f.tuning.sampleQuality=nil;f.tuning.context.targetLevel=0;finish(f)
expect(f.tuning.learning.difficulty,"unknown","legacy zero-level metadata is not easy")

f=begin();now=0.1;event("SPELL_DAMAGE")
f.tuning.resources={broken={samples="not a number"}}
expect(pcall(T.FinalizeFight,f),false,"fixture fails during later resource finalization")
expect(f.tuning._qualityTarget,nil,"runtime identity is erased before later finalization errors")

-- Full logger lifecycle: real start, periodic sampling, finalization and storage.
local historical={id=1,class="ROGUE",damageDone=24,duration=9.784}
env.HCOB_CombatLog={fights={historical},totalFights=1,session="Fixture"}
env.HCOneButton.RecordSavedVariableRepair=function() end
env.SafeUnitHealth=function() return 300 end
env.TalentSpec=function() return 1,"Combat",7 end
env.Clamp=function(n,low,high) return math.max(low,math.min(high,n)) end
now=0;target=nil;level=0;env.currentFight=nil
env.StartCombatTelemetry()
f=env.currentFight
expect(f.tuning.sampleQuality.version,1,"logger start initializes quality contract")
now=1;event("SWING_DAMAGE","enemy","player")
target="enemy";level=17;now=2;env.SampleCombatTelemetry()
expect(f.tuning.context.targetLevel,17,"periodic logger sample recovers opponent")
f.tuning.comparableActions,f.tuning.matchedActions=1,1
now=10;env.FinalizeCombatTelemetry("combat_end")
expect(env.currentFight,nil,"logger closes eligible fight")
expect(env.HCOB_CombatLog.fights[2],f,"eligible fight enters history")
expect(f.tuning.eligibility.adaptive,true,"full lifecycle learns eligible fight")
expect(f.tuning._qualityTarget,nil,"stored fight has no quality GUID")
expect(env.HCOB_CombatLog.fights[1],historical,"historical fight identity is unchanged")
expect(historical.damageDone,24,"historical damage is unchanged")

now=0;env.StartCombatTelemetry();f=env.currentFight
now=6;event("SPELL_CAST_SUCCESS","player","player")
now=8.568;event("SPELL_DAMAGE")
f.tuning.comparableActions,f.tuning.matchedActions=1,1
now=9.784;env.FinalizeCombatTelemetry("combat_end")
expect(env.HCOB_CombatLog.fights[3],f,"excluded late tag still enters raw history")
expect(f.tuning.learning.reason,"late_participation","full lifecycle explains late tag")
expect(f.totalDamage,20,"excluded fight keeps original damage")

print("All-class tuning participation regression: "..checks.." checks PASS")
