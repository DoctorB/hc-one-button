-- Revision-3 integration: actual scoring -> displayed advice -> confirmed cast
-- -> finalized telemetry -> comparison learner -> a different later decision.
local function loadInto(env, path)
    local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk()
end
local function runtime(class)
    local env = setmetatable({}, {__index=_G}); env._G=env
    env.PLAYER_CLASS, env.VERSION = class, "1.29.2"
    env.HCOB_DB, env.HCOB_CharacterDB = {}, {}
    env.S = {HEROIC_STRIKE=78, CLEAVE=845}
    env.now, env.hp, env.targetHP, env.power, env.reserve, env.enemies = 100,90,75,50,55,1
    env.targetGUID = "test-target"
    env.GetTime=function() return env.now end
    env.GetServerTime=function() return env.now end
    env.PlayerLevel=function() return 30 end
    env.TalentSpec=function() return 1,"Spec",10 end
    env.TalentTabCompat=function() return "Tab",0 end
    env.GetNumTalents=function() return 0 end
    env.GetNumGroupMembers=function() return 0 end
    env.IsInInstance=function() return false,"none" end
    env.IsKnown=function() return true end
    env.SpellName=function(id) return "Spell " .. tostring(id) end
    env.SpellCastSeconds=function() return env.castSeconds or 0 end
    env.UnitHealthPct=function(unit) return unit == "player" and env.hp or env.targetHP, env.readable ~= false end
    env.UnitPowerType=function() return 1,"RAGE" end
    env.UnitPowerPct=function() return env.power,true end
    env.SafeUnitPower=function() return env.power end
    env.SafeUnitPowerMax=function() return 100 end
    env.SafeUnitLevel=function() return 30 end
    env.SafeUnitClassification=function() return "normal" end
    env.SafeUnitGUID=function() return env.targetGUID end
    env.CountActiveEnemies=function() return env.enemies end
    env.print=function() end
    env.HCOneButton={Internal=env,Core={},Systems={},UI={ActionPanel={actions={}}},Advisor={Engine={}}}
    loadInto(env,"HCOneButton/Systems/TuningTelemetry.lua")
    loadInto(env,"HCOneButton/Systems/AdaptiveTuner.lua")
    loadInto(env,"HCOneButton/Advisor/Engine.lua")
    env.HCOneButton.Advisor.Engine.SurvivalReserve=function() return env.reserve,"SAFE" end
    return env,env.HCOneButton.Systems.AdaptiveTuner,env.HCOneButton.Systems.TuningTelemetry,env.HCOneButton.Advisor.Engine
end
local function start(env,t)
    env.now=env.now+20
    local fight={startClock=env.now,duration=10,endReason="combat_end",died=false,dps=50,hpMinPct=90}
    env.currentFight=fight; t.InitFight(fight)
    return fight
end
local function candidate(id,tag,score)
    return {id=id,tag=tag,title="Spell " .. id,key="TEST",reason="Test baseline",score=score}
end
local cases={
    {"WARRIOR",6343,"mitigation",772,"dot"},
    {"PALADIN",19740,"buff",20271,"damage"},
    {"HUNTER",1495,"proc",3044,"burst"},
    {"ROGUE",14251,"proc",1752,"damage"},
    {"PRIEST",139,"sustain",585,"damage"},
    {"MAGE",120,"control",116,"damage"},
    {"WARLOCK",1454,"resource",686,"damage"},
    {"DRUID",768,"form",5176,"damage"},
    {"SHAMAN",324,"buff",403,"damage"},
}
for _,case in ipairs(cases) do
    local class,id,tag,other,otherTag=unpack(case)
    local env,a,t,engine=runtime(class)
    local trained
    for index=1,16 do
        local fight=start(env,t)
        local preferred=index>8
        fight.dps=preferred and 110 or 50
        local candidates={candidate(id,tag,preferred and 90 or 60),candidate(other,otherTag,preferred and 60 or 90)}
        local selected,title,key,reason=engine.SelectCandidate(candidates)
        t.RecordRecommendation(selected,title,key,"action",env.reserve,1,true)
        env.now=env.now+0.1
        t.RecordAction(selected,"unit_success")
        env.now=fight.startClock+10
        t.FinalizeFight(fight)
        assert(fight.tuning.eligibility.adaptive and fight.tuning.choiceEvidence, class .. ": lost comparison evidence")
        assert(not fight.tuning._choiceWindow, "ephemeral target identity leaked to saved fight")
        trained=fight
    end
    local fight=start(env,t)
    local selected,title,key,reason=engine.SelectCandidate({candidate(other,otherTag,80),candidate(id,tag,74)})
    assert(engine.lastBaseline.id == other and selected == id, class .. ": learner did not change a real six-point baseline gap")
    assert(reason:find("Local tuning",1,true), class .. ": no user-visible explanation")
    for _=1,50 do t.RecordRecommendation(selected,title,key,"action",env.reserve,1,true) end
    assert(fight.tuning.impact.evaluated==1 and fight.tuning.impact.changed==1,"frame rate inflated displayed decision counts")
    env.now=env.now+0.1; t.RecordAction(selected,"unit_success"); t.RecordAction(selected,"combat_success")
    assert(fight.tuning.impact.executed==1,"duplicate cast events inflated executed impact")
    env.now=fight.startClock+10; fight.dps=110; t.FinalizeFight(fight)
    local model=a.GetDisplayModel()
    assert(model.impact.changed>=1 and model.impact.executed>=1,class .. ": inspector omitted actual impact")
    local bias=a.GetCandidateBias(candidate(id,tag,74))
    assert(bias>0 and bias<=12)
    env.power=90
    assert(a.GetCandidateBias(candidate(id,tag,74))==0,"normal resource evidence leaked into high-resource situation")
    env.power=50
    a.SetEnabled(false)
    engine.ResetStabilization()
    assert(engine.SelectCandidate({candidate(other,otherTag,80),candidate(id,tag,74)})==other,"OFF did not restore baseline")
    a.SetEnabled(true)
    local fixed=candidate(871,"survival",80)
    engine.ResetStabilization()
    assert(engine.SelectCandidate({fixed,candidate(id,tag,74)})==871,"learned choice displaced emergency")
    local protectedView=a.Policy(fixed,{hp=100,reserve=100,readable=true,enemies=1})
    assert(not protectedView,"emergency became an experiment at healthy HP")
    env.hp=50
    assert(not a.Policy(candidate(id,tag,74)),class .. ": situational action not protected under pressure")
end

-- Capture the pending decision through the nil cast hold; never attribute a
-- stale or different-target recommendation to a later successful cast.
local env,a,t,engine=runtime("MAGE")
env.castSeconds=2.5
local fight=start(env,t)
local id,title,key=engine.SelectCandidate({candidate(116,"damage",80),candidate(133,"damage",75)})
t.RecordRecommendation(id,title,key,"action",55,1,true)
engine.lastCandidates,engine.lastBaseline={},nil
env.now=env.now+0.2
t.RecordRecommendation(nil,"CAST ACTIVE","LET IT FINISH","caution",55,1,true)
env.now=env.now+2.3
t.RecordAction(id,"unit_success")
assert(fight.tuning.choiceEvidence["116:damage"].chosen,"cast hold lost confirmed choice")
assert(fight.tuning.matchedActions==1,"cast hold lost adherence")
env.now=fight.startClock+10; t.FinalizeFight(fight)
assert(fight.tuning.eligibility.adaptive,"valid non-instant cast became ineligible")

-- Safe recovery casts use a separate HUD hold but still belong to the same
-- previously eligible choice. This does not change the hold or allow casting.
fight=start(env,t)
env.hp,env.reserve=90,80
id,title,key=engine.SelectCandidate({candidate(2061,"survival",80),candidate(585,"damage",75)})
t.RecordRecommendation(id,title,key,"action",80,1,true)
engine.lastCandidates,engine.lastBaseline={},nil
env.now=env.now+0.2
t.RecordRecommendation(nil,"RECOVERY ACTIVE","LET IT FINISH","caution",80,1,true)
env.now=env.now+2.3
t.RecordAction(id,"unit_success")
assert(fight.tuning.choiceEvidence["2061:survival"].chosen,"recovery hold lost a safe confirmed choice")

for _,invalid in ipairs({"target","expired","emergency"}) do
    fight=start(env,t)
    id,title,key=engine.SelectCandidate({candidate(116,"damage",80),candidate(133,"damage",75)})
    t.RecordRecommendation(id,title,key,"action",55,1,true)
    if invalid=="target" then env.targetGUID="different-target"
    elseif invalid=="expired" then env.now=env.now+5
    else
        engine.lastCandidates,engine.lastBaseline={},nil
        t.RecordRecommendation(11958,"ICE BLOCK","ALL MODS","danger",20,1,true)
    end
    t.RecordAction(id,"unit_success")
    assert(not fight.tuning.choiceEvidence,"invalid choice window entered comparisons: " .. invalid)
end
-- A stabilizer can briefly keep an older still-eligible spell on screen even
-- with tuning OFF. That difference is not an adaptive intervention.
env,a,t,engine=runtime("MAGE")
a.SetEnabled(false)
fight=start(env,t)
engine.SelectCandidate({candidate(116,"damage",70),candidate(133,"damage",80)})
t.RecordRecommendation(116,"STABILIZED OLD SPELL","TEST","action",55,1,true)
t.RecordAction(116,"unit_success")
assert(fight.tuning.impact.changed==0 and fight.tuning.impact.executed==0,
    "display stabilization was falsely counted as adaptive impact")

-- Review cycle 1: manual alternatives, duplicate roles and valid safety data.
env,a,t,engine=runtime("MAGE")
fight=start(env,t)
id,title,key=engine.SelectCandidate({candidate(116,"proc",90),candidate(116,"damage",70),candidate(133,"damage",60)})
t.RecordRecommendation(id,title,key,"action",55,1,true)
t.RecordAction(133,"unit_success")
assert(fight.tuning.choiceEvidence["116:proc"] and not fight.tuning.choiceEvidence["116:damage"],
    "one spell with two roles was treated as two independent alternatives")
env.now=fight.startClock+10; t.FinalizeFight(fight)
assert(fight.tuning.adherencePct==0 and fight.tuning.eligibility.adaptive,
    "a confirmed eligible player alternative was rejected merely for disagreeing with the Advisor")

fight=start(env,t)
id,title,key=engine.SelectCandidate({candidate(116,"proc",90),candidate(116,"damage",70)})
t.RecordRecommendation(id,title,key,"action",55,1,true); t.RecordAction(id,"unit_success")
assert(not fight.tuning.choiceEvidence,"a spell was compared against itself")
for _,bad in ipairs({0/0,math.huge,-math.huge,false,"invalid"}) do
    assert(not a.Policy(candidate(6343,"mitigation",79),{hp=bad,reserve=70,readable=true}),"invalid health bypassed safety")
    assert(not a.Policy(candidate(6343,"mitigation",79),{hp=90,reserve=bad,readable=true}),"invalid reserve bypassed safety")
end
assert(not a.Policy(candidate(136,"survival",99),{hp=100,petHP=15,reserve=90,readable=true}),"healthy owner allowed pet emergency tuning")
assert(a.Policy(candidate(6343,"mitigation",79),{hp="90",reserve="70",readable=true}),"numeric safety values failed normalization")
local previousHealth=env.UnitHealthPct
env.reserve=90
env.UnitHealthPct=function(unit)
    if unit=="pet" then return 100,false end -- real Utils fallback for unreadable HP
    return 100,true
end
assert(not a.Policy(candidate(136,"survival",99)),"unreadable pet HP fallback was mistaken for healthy HP")
env.UnitHealthPct=previousHealth

-- Review cycle 2: safe special routes preserve their exact cold/OFF baseline;
-- a mature comparison can choose another eligible action, never an absent one.
env,a,t,engine=runtime("WARRIOR")
env.ClassRecommendation=function()
    return engine.SelectCandidate({candidate(6343,"mitigation",79),candidate(772,"dot",69)})
end
fight=start(env,t)
assert(engine.AdaptSpecial(6343,"MULTI CONTROL","CTRL","Original","caution",true,true,75)==6343,
    "cold learner changed the special baseline")
-- Seed mature evidence only to isolate routing from the separately tested learner.
fight.tuning.eligibility={adaptive=true}
fight.tuning.candidates={
    ["6343:mitigation"]={spellId=6343,tag="mitigation",title="Thunder Clap",samples=1},
    ["772:dot"]={spellId=772,tag="dot",title="Rend",samples=1},
}
a.LearnFight(fight)
local store=env.HCOB_CharacterDB.adaptive
local ctx=store.contexts[store.lastContextKey]; ctx.fights=8
ctx.arms["6343:mitigation"].situations={["single:normal:main"]={chosen={n=8},other={n=8},bias=-12}}
ctx.arms["772:dot"].situations={["single:normal:main"]={chosen={n=8},other={n=8},bias=12}}
engine.ResetStabilization()
assert(engine.AdaptSpecial(6343,"MULTI CONTROL","CTRL","Original","caution",true,true,75)==772,
    "special route still bypassed mature safe comparisons")
env.hp=50
assert(engine.AdaptSpecial(6343,"MULTI CONTROL","CTRL","Original","caution",true,true,75)==6343,
    "special route displaced required mitigation under pressure")
assert(#engine.lastCandidates==0 and not engine.lastBaseline,"protected special route leaked comparison candidates")
env.hp=90
a.SetEnabled(false)
assert(engine.AdaptSpecial(6343,"MULTI CONTROL","CTRL","Original","caution",true,true,75)==6343,"OFF changed special baseline")
a.SetEnabled(true)
assert(engine.AdaptSpecial(999,"ABSENT","CTRL","Original","caution",true,true,75)==999,"special route invented eligibility")
local group=ctx.arms["772:dot"].situations["single:normal:main"]
for _,bad in ipairs({true,false,12,"invalid"}) do
    group.chosen=bad
    assert(a.GetCandidateBias(candidate(772,"dot",69))==0,"malformed comparisons affected gameplay")
    assert(pcall(a.GetDisplayModel),"malformed comparison crashed inspector")
    assert(pcall(a.LearnFight,fight),"malformed comparison crashed learning")
end
group.chosen={n=3}; group.other={n=8}; group.bias=12
assert(a.GetCandidateBias(candidate(772,"dot",69))==0,"unqualified saved bias bypassed sample gate")

-- The objective discounts overkill and resource-cap waste, without claiming a
-- causal DPS improvement from observational outcomes.
fight=start(env,t); fight.dps=100; fight.duration=10
fight.abilities={test={overkill=100}}; fight.petAbilities={test={overkill=50}}
fight.tuning.eligibility={adaptive=true}; fight.tuning.resources={RAGE={capPct=75}}
a.LearnFight(fight)
assert(fight.tuning.learning.effectiveDps==85 and fight.tuning.learning.resourceCapPct==75,
    "objective ignored recorded overkill / capped resource waste")
-- Real Warrior candidate generation: mitigation can compete, but a healthy
-- debuff remains absent from the candidates regardless of learned preference.
env,a,t,engine=runtime("WARRIOR")
env.HCOneButton.Data={}; env.HCOneButton.Classes={}; env.knownSpellNames={}
loadInto(env,"HCOneButton/Data/Spells.lua"); env.S=env.HCOneButton.Data.Spells
env.SafeNumber=function(value,fallback) return tonumber(value) or fallback end
env.IsKnown=function(spell) return spell==6343 or spell==7386 or spell==772 end
env.IsUsable=function() return true end; env.CooldownReady=function() return true end
env.StablePlayerBuff=function() return true,120 end
env.HasMyTargetDebuff=function(spell) return spell==6343 and env.clapActive or false,20 end
engine.RollingDynamics=function() return nil end
loadInto(env,"HCOneButton/Classes/Warrior.lua")
fight=start(env,t)
local warrior=env.HCOneButton.Classes.WARRIOR
warrior:GetRecommendation(true,true,75,1)
local clap,sunder
for _,entry in ipairs(engine.lastCandidates) do
    if entry.id==6343 then clap=entry end
    if entry.id==7386 then sunder=entry end
end
assert(clap and sunder and a.Policy(clap) and a.Policy(sunder),"real Warrior omitted safe Clap / Sunder opportunities")
env.clapActive=true
warrior:GetRecommendation(true,true,75,1)
for _,entry in ipairs(engine.lastCandidates) do assert(entry.id~=6343,"tuning bypassed real Thunder Clap refresh gate") end
print("situational adaptive decisions / all-class impact integration: PASS")
