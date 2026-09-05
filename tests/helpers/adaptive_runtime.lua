-- Isolated WoW runtime for attribution and inspector integration regressions.
local function loadInto(env, path)
    local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk()
end
local function runtime(class)
    local env = setmetatable({}, {__index=_G}); env._G=env
    env.PLAYER_CLASS, env.VERSION = class, "1.29.4"
    env.HCOB_DB, env.HCOB_CharacterDB = {}, {}
    env.S = {HEROIC_STRIKE=78, CLEAVE=845}
    env.now, env.hp, env.targetHP, env.power, env.reserve, env.enemies = 100,90,75,50,80,1
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
    env.IsUsable=function() return true end
    env.CooldownReady=function() return true end
    env.CooldownRemaining=function() return 0 end
    env.SpellName=function(id) return "Spell " .. tostring(id) end
    env.SpellCastSeconds=function() return env.castSeconds or 0 end
    env.UnitAttackSpeed=function() return env.swingSpeed or 2.5 end
    env.IsQueuedMeleeSwingSpell=function(id) return env.queued == id end
    env.UnitHealthPct=function(unit) return unit == "player" and env.hp or env.targetHP, true end
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
    local engine=env.HCOneButton.Advisor.Engine
    engine.SurvivalReserve=function() return env.reserve,"SAFE" end
    engine.IsRangedHostileSpell=function() return false end
    engine.kindPriority={action=30,idle=0,danger=90}
    return env,env.HCOneButton.Systems.AdaptiveTuner,env.HCOneButton.Systems.TuningTelemetry,engine
end
local function start(env,t)
    env.now=env.now+20
    local fight={startClock=env.now,duration=10,endReason="combat_end",died=false,dps=50,hpMinPct=90}
    env.currentFight=fight; t.InitFight(fight)
    env.HCOneButton.Advisor.Engine.ResetStabilization()
    return fight
end
local function candidate(id,tag,score)
    return {id=id,tag=tag,title="Spell " .. id,key="TEST",reason="Test baseline",score=score}
end
local function display(env,t,engine,candidates)
    local id,title,key,reason=engine.SelectCandidate(candidates)
    local kind=id and "action" or "idle"
    id,title,key,reason,kind=engine.Stabilize(id,title or "BASE OK",key,reason,kind)
    t.RecordRecommendation(id,title,key,kind,env.reserve,env.enemies,true)
    return id
end
return {runtime=runtime,start=start,candidate=candidate,display=display,loadInto=loadInto}
