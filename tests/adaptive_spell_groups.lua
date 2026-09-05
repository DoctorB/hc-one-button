local h=dofile("tests/helpers/adaptive_runtime.lua")
local env,a,t,engine=h.runtime("WARRIOR")
local function learn(id,tag)
    local fight=h.start(env,t)
    h.display(env,t,engine,{h.candidate(id,tag,80)})
    env.now=env.now+0.1; t.RecordAction(id,"unit_success")
    env.now=fight.startClock+10; t.FinalizeFight(fight)
    return fight
end
for i=1,8 do learn(6673,"buff") end
local model=a.GetDisplayModel()
assert(model.fights==8 and model.contextCalibrated,"fight calibration lost")
assert(not model.ready and model.state=="OBSERVING" and model.activeAdjustments==0,
    "eight fights without comparisons falsely reported ready")
assert(model.learnedActions==1 and #model.spells==1,"distinct spell count incorrect")
local store=env.HCOB_CharacterDB.adaptive
local context=store.contexts[store.lastContextKey]
context.arms["6673:action"]={spellId=6673,tag="action",title="BATTLE SHOUT",accepted=1,fights=1}
context.arms["1715:danger"]={spellId=1715,tag="action",title="FIGHT WORSENING"}
context.arms["1715:caution"]={spellId=1715,tag="action",title="UNFAVORABLE FIGHT"}
model=a.GetDisplayModel()
assert(#model.arms==4 and #model.spells==2 and model.learnedActions==2,"legacy duplicates were not grouped")
assert(model.protectedObserved==1,"mixed tunable/legacy spell became entirely fixed")
local shout
for _,group in ipairs(model.spells) do if group.spellId==6673 then shout=group end end
assert(shout and shout.title==env.SpellName(6673) and #shout.details==2,"spell label used a warning title")
assert(context.arms["6673:action"].accepted==1 and not context.arms["6673:buff"].situations,
    "presentation merged historical outcomes into comparison evidence")
context.arms.bad={spellId="invalid",tag="dot"}
assert(#a.GetDisplayModel().spells==2,"malformed spell ID hid the valid inspector rows")
context.arms["6673:buff"].situations={
    ["single:normal:main"]={chosen={n=4},other={n=1},bias=5},
}
model=a.GetDisplayModel()
assert(model.state=="COMPARING" and not model.ready and model.activeAdjustments==0,
    "one-sided/insufficient evidence was treated as trained")
context.arms["6673:buff"].situations["single:normal:main"].other.n=4
context.arms["6673:buff"].situations["single:normal:main"].bias=0
model=a.GetDisplayModel()
assert(model.state=="BASELINE" and model.ready and model.matureSituations==1,
    "mature but indistinguishable evidence should honestly remain baseline")
context.arms["6673:buff"].situations={
    ["single:normal:main"]={chosen={n=4},other={n=4},bias=-2},
    ["single:low:main"]={chosen={n=5},other={n=6},bias=3},
}
model=a.GetDisplayModel()
assert(model.state=="ADAPTED" and model.activeAdjustments==2 and model.learnedActions==2)
shout=model.spells[1]
assert(shout.spellId==6673 and shout.minBias==-2 and shout.maxBias==3,
    "opposing situations were averaged into a misleading correction")
assert(#shout.details==3 and shout.situationCount==2 and shout.matureCount==2)
assert(not shout.chosenFights and not shout.otherFights,"aggregate group invented independent fights")
local status=a.Status()
assert(status.state==model.state and status.learnedActions==model.learnedActions and status.ready==model.ready,
    "slash status and visual inspector disagree")
a.SetEnabled(false)
model=a.GetDisplayModel()
assert(model.state=="DISABLED" and model.spells[1].active,"OFF should preserve inspection, not claim enabled gameplay")
a.SetViewProfile("pvp")
model=a.GetDisplayModel()
assert(model.state=="NOT SUPPORTED" and #model.spells==0 and not model.ready,"PvP borrowed PvE groups")
print("adaptive spell grouping / evidence states / legacy preservation: PASS")
