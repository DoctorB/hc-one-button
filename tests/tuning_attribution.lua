local h=dofile("tests/helpers/adaptive_runtime.lua")
local runtime,start,candidate,display=h.runtime,h.start,h.candidate,h.display

-- Same displayed advice + changed fresh candidates must not create :action
-- duplicates or reclassify a confirmed cast. Exercise tags across all classes.
local cases={
    {"WARRIOR",6673,"buff",772,"dot"},
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
    local fight=start(env,t)
    display(env,t,engine,{candidate(id,tag,84),candidate(other,otherTag,61)})
    env.now=env.now+0.1
    assert(display(env,t,engine,{candidate(other,otherTag,61)})==id)
    t.RecordAction(id,"unit_success")
    assert(fight.tuning.decisions[id .. ":" .. tag].accepted==1,class .. ": lost accepted role")
    assert(not fight.tuning.decisions[id .. ":action"],class .. ": duplicate fallback role")
    assert(fight.tuning.choiceEvidence[id .. ":" .. tag].chosen,class .. ": stabilized choice lost")
    env.now=fight.startClock+10; t.FinalizeFight(fight)
    assert(not fight.tuning._recentDecisions and not fight.tuning._pendingActions and not fight.tuning._confirmations,
        "runtime target/decision identities leaked into SavedVariables")
end

-- Log 4220: two available candidates -> queued HS -> next Sunder advice ->
-- delayed HS success. Both genuine casts belong to their own recommendation.
for _,id in ipairs({78,845}) do
    for _,inputOrder in ipairs({"before","after","queue_event"}) do
        local env,a,t,engine=runtime("WARRIOR")
        local fight=start(env,t)
        display(env,t,engine,{candidate(id,"dump",74),candidate(7386,"setup",63)})
        env.now=env.now+0.081; env.queued=id
        if inputOrder=="before" then t.RecordInput(id,"action_panel") end
        if inputOrder=="queue_event" then t.RecordQueueState() end
        display(env,t,engine,{candidate(7386,"setup",63)})
        if inputOrder=="after" then t.RecordInput(id,"action_panel") end
        t.CancelPending(id,"failed-repeat") -- a repeated key cannot cancel a confirmed queue
        t.RecordInput(7386,"action_panel")
        env.now=fight.startClock+0.84; env.queued=nil
        t.RecordAction(id,"unit_success")
        t.RecordAction(7386,"unit_success")
        t.RecordAction(id,"combat_success") -- interleaved duplicate sources
        assert(fight.tuning.actionStats[tostring(id)].count==1,"interleaved cast duplicate")
        assert(fight.tuning.actionStats[tostring(id)].matched==1,"queued cast lost attribution")
        assert(fight.tuning.actionStats[tostring(id)].deviations==0,"false player override")
        assert(fight.tuning.decisions["7386:setup"].accepted==1,"HS consumed Sunder's pending cast")
        assert(fight.tuning.choiceEvidence[id .. ":dump"].chosen,"queued comparison lost")
        assert(not fight.tuning.choiceEvidence["7386:setup"].chosen,"alternative was rewritten by later cast")
    end
end

-- Failure of a repeated keypress is not interruption of the cast already in
-- progress. Cast GUIDs distinguish those attempts without entering saved data.
do
    local env,a,t,engine=runtime("MAGE")
    env.castSeconds=2.5
    local fight=start(env,t)
    display(env,t,engine,{candidate(101,"damage",90),candidate(102,"damage",70)})
    t.RecordInput(101,"action_panel"); t.CapturePending(101,"cast-started")
    t.CancelPending(101,"failed-repeat")
    assert(fight.tuning._pendingActions[101],"failed repeated key cancelled a different cast")
    env.now=env.now+2.5; t.RecordAction(101,"unit_success")
    assert(fight.tuning.choiceEvidence["101:damage"].chosen,"cast GUID isolation lost confirmed evidence")
end

-- Slow swing + nil HUD: expiry follows weapon speed, not instant-spell time.
do
    local env,a,t,engine=runtime("WARRIOR")
    env.swingSpeed=4.0
    local fight=start(env,t)
    display(env,t,engine,{candidate(78,"dump",74)})
    t.RecordInput(78,"action_panel")
    env.now=env.now+0.04; env.queued=78
    display(env,t,engine,{})
    env.now=fight.startClock+4.1; env.queued=nil
    t.RecordAction(78,"unit_success")
    assert(fight.tuning.decisions["78:dump"].accepted==1,"slow swing lost attribution")
    assert(not fight.tuning.choiceEvidence,"single action invented a comparison")
end

-- Non-instant spells: cast-start capture works even without an Action Panel
-- input and survives an intervening recommendation. Never borrow another target.
for _,class in ipairs({"MAGE","PRIEST","WARLOCK","DRUID","SHAMAN"}) do
    for _,invalid in ipairs({"valid","expired","target","target_return","interrupted"}) do
        local env,a,t,engine=runtime(class)
        env.castSeconds=2.5
        local fight=start(env,t)
        display(env,t,engine,{candidate(101,"damage",90),candidate(102,"damage",70)})
        t.CapturePending(101)
        env.now=env.now+0.2
        t.RecordRecommendation(nil,"CAST ACTIVE",nil,"caution",80,1,true)
        env.now=fight.startClock+2.6
        if invalid=="expired" then env.now=fight.startClock+20
        elseif invalid=="target" then env.targetGUID="another-target"
        elseif invalid=="target_return" then t.ClearPending()
        elseif invalid=="interrupted" then t.CancelPending(101) end
        t.RecordAction(101,"unit_success")
        assert((fight.tuning.choiceEvidence~=nil)==(invalid=="valid"),class .. ": invalid confirmation " .. invalid)
    end
end

-- Actual combat-log ingestion must canonicalize learned ranks before filtering
-- queue outcomes (284/1608 are HS ranks; 7369 is a Cleave rank).
do
    local env,a,t,engine=runtime("WARRIOR")
    local baseNames=env.SpellName
    env.SpellName=function(id)
        if id==284 or id==1608 then return baseNames(78) end
        if id==7369 then return baseNames(845) end
        return baseNames(id)
    end
    env.HCOneButton.UI.ActionPanel.actions.WARRIOR={78,845}
    env.playerGUID="player"
    env.SafeString=function(v,fallback) return type(v)=="string" and v or fallback end
    env.SafeNumber=function(v,fallback) return tonumber(v) or fallback end
    env.SafeBoolean=function(v,fallback) if type(v)=="boolean" then return v end; return fallback end
    env.SafeUnitGUID=function(unit) return unit=="pet" and "pet" or "player" end
    env.IsPlayerOrPetGUID=function(guid) return guid=="player" or guid=="pet" end
    h.loadInto(env,"HCOneButton/Systems/CombatLog.lua")
    env.AddEnemyToFight=function() end
    env.AbilityRecord=function() return {hits=0,damage=0,overkill=0,resisted=0,blocked=0,absorbed=0,
        crits=0,misses=0,casts=0,missTypes={}} end
    for _,rank in ipairs({78,284,1608,845,7369}) do
        local fight=start(env,t)
        fight.damageDone,fight.outgoingHits,fight.maxHitDone,fight.crits=0,0,0,0
        fight.misses,fight.dodges,fight.parries,fight.blocks,fight.resists=0,0,0,0,0
        local id=t.CanonicalActionId(rank)
        local args={[2]="SPELL_DAMAGE",[4]="player",[5]="Player",[6]=0,[8]="enemy",[9]="Enemy",[10]=0,
            [12]=rank,[13]=env.SpellName(rank),[14]=1,[15]=10,[16]=0}
        env.ProcessCombatTelemetry(args)
        assert(fight.tuning.queue[tostring(id)].consumed==1,"learned rank damage lost queue outcome")
        args[2],args[15]="SPELL_MISSED","MISS"
        env.ProcessCombatTelemetry(args)
        assert(fight.tuning.queue[tostring(id)].missed==1,"learned rank miss lost queue outcome")
        env.now=env.now+0.1; t.RecordAction(rank,"unit_success")
        env.now=env.now+0.4; t.SampleResources(fight)
        assert(fight.tuning.queue[tostring(id)].cleared==0,"consumed/missed rank became cancelled queue")
    end
end

-- A fresh pressure-protected recommendation invalidates an unstarted safe
-- opportunity, but an already-started spell retains the decision made then.
for _,started in ipairs({false,true}) do
    local env,a,t,engine=runtime("WARRIOR")
    local fight=start(env,t)
    display(env,t,engine,{candidate(6343,"mitigation",80),candidate(772,"dot",60)})
    if started then t.RecordInput(6343,"action_panel") end
    env.hp=40; env.reserve=30; env.now=env.now+0.1
    display(env,t,engine,{candidate(6343,"mitigation",80),candidate(772,"dot",60)})
    t.RecordAction(6343,"unit_success")
    assert((fight.tuning.choiceEvidence~=nil)==started,"pressure reused an unstarted old comparison")
end

-- Repeated failed keypresses cannot keep an old input alive indefinitely.
do
    local env,a,t,engine=runtime("MAGE")
    local fight=start(env,t)
    display(env,t,engine,{candidate(101,"damage",90),candidate(102,"damage",70)})
    t.RecordInput(101,"action_panel")
    local expires=fight.tuning._pendingActions[101].expires
    for i=1,5 do env.now=env.now+0.1; t.RecordInput(101,"action_panel") end
    assert(fight.tuning._pendingActions[101].expires==expires,"keypresses inflated pending lifetime")
end

-- A pending attempt without comparative evidence cannot acquire a new choice
-- snapshot later, or lend its longer lifetime to an unrelated expired window.
do
    local env,a,t,engine=runtime("MAGE")
    env.castSeconds=2.5
    local fight=start(env,t)
    display(env,t,engine,{candidate(101,"damage",90)})
    fight.tuning._decision.window=nil; fight.tuning._choiceWindow=nil
    t.CapturePending(101)
    env.now=env.now+0.1
    display(env,t,engine,{candidate(101,"damage",90),candidate(102,"damage",70)})
    t.RecordAction(101,"unit_success")
    assert(not fight.tuning.choiceEvidence,"pending cast borrowed newly available alternatives")
end

print("tuning attribution / queue / all-class event-order regression: PASS")
