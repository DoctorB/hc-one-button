local rt = assert(loadfile("tests/helpers/warrior_runtime.lua"))()()
local e, I, S, Engine, W = rt.env, rt.internal, rt.S, rt.Engine, rt.Warrior
local state, checks = rt.reset(), 0
local function expect(actual, expected, label)
    checks=checks+1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function reset() state=rt.reset() end
local function recommend() return I.Recommend() end
local function expectHS(label, kind)
    local id, _, key, reason, actualKind = recommend()
    expect(id,S.HEROIC_STRIKE,label)
    expect(key,"CAST MANUALLY",label .. " uses dedicated spell slot")
    expect(actualKind,kind or "action",label .. " severity")
    return reason
end

-- The starting kit spends at 25 with the unchanged saved base of 35. A
-- deliberate base of 20 works, regardless of level difference or risk.
for _, level in ipairs({1,6,10,19,30,40,60}) do
    for _, delta in ipairs({-3,0,3}) do
        reset(); state.level=level; state.targetLevel=level+delta; state.rage=25
        expectHS("undeveloped kit " .. level .. "/" .. delta)
        expect(e.HCOB_DB.warriorHeroicRage,35,"saved base is not overwritten")
        state.rage=24; expect(recommend(),nil,"below effective threshold waits")
        e.HCOB_DB.warriorHeroicRage=20; state.rage=20
        expectHS("custom base 20 is honored")
    end
end
reset(); e.HCOB_DB.warriorHeroicRage=50; state.rage=40
expectHS("higher custom base retains its ten-point early-kit adjustment")
state.rage=39; expect(recommend(),nil,"custom higher base is not discarded")

-- Learning a core spender restores the developed budget. Ready core strikes
-- and procs stay ahead of HS, including during pessimistic fight forecasts.
for _, spell in ipairs({S.MORTAL_STRIKE,S.BLOODTHIRST,S.WHIRLWIND}) do
    reset(); state.level=40; state.known[spell]=true; state.usable[spell]=false
    state.rage=34; expect(recommend(),nil,"learned core retains budget")
    state.rage=35; expectHS("developed threshold")
    state.usable[spell]=true; state.trend="caution"
    expect(recommend(),spell,"core spell available during caution")
end
reset(); state.known[S.OVERPOWER]=true; state.rage=5; state.trend="caution"
expect(recommend(),S.OVERPOWER,"reactive attack needs no generic forty-rage gate")
reset(); state.known[S.EXECUTE]=true; state.targetHP=20; state.rage=15
expect(recommend(),S.EXECUTE,"learned Execute still wins")

-- Safety warnings retain offensive choices; ONLY configured critical HP
-- forces a defensive/escape spell. Enabling control spells must not change this.
for _, hp in ipairs({100,60,37,35,25,21}) do
    for _, trend in ipairs({"caution","danger"}) do
        reset(); state.hp=hp; state.trend=trend; state.rage=25
        state.known[S.HAMSTRING]=true; state.known[S.RETALIATION]=true
        local reason=expectHS("risk " .. hp .. "/" .. trend, hp<=35 and "danger" or trend)
        expect(type(reason)=="string" and #reason>0,true,"risk remains explained")
    end
end
reset(); state.hp=20; state.known[S.HAMSTRING]=true
local id, _, _, _, kind=recommend()
expect(id,S.HAMSTRING,"critical HP preempts damage"); expect(kind,"danger","critical warning")
e.HCOB_DB.criticalHP=30; state.hp=30
expect(recommend(),S.HAMSTRING,"custom critical boundary")
state.hp=31; state.rage=25; expectHS("above custom critical stays offensive","danger")
reset(); state.hp=20
id, _, _, _, kind=recommend()
expect(id,nil,"critical without learned defense never invents one"); expect(kind,"danger","critical without spell")

-- Same class-spell decision on a risky multi-pull; learned Cleave is preferred
-- only when its own budget is met. Core AoE still outranks a queued dump.
for _, enemies in ipairs({2,3,5}) do
    reset(); state.enemies=enemies; state.hp=45; state.rage=30
    state.known[S.CLEAVE]=true
    id, _, _, _, kind=recommend()
    expect(id,S.CLEAVE,"multi-pull continues damage " .. enemies)
    expect(kind,"danger","multi-pull warning retained")
    state.rage=29; expect(recommend(),S.HEROIC_STRIKE,"Cleave budget does not block affordable HS")
    state.rage=50; state.known[S.WHIRLWIND]=true
    expect(recommend(),S.WHIRLWIND,"learned AoE remains first choice")
    state.hp=20; state.known[S.HAMSTRING]=true
    expect(recommend(),S.HAMSTRING,"critical multi-pull preempts damage")
end

-- Active buffs/debuffs and the next-swing queue are not spammed. Failed API
-- usability and unknown ranks never become phantom offensive suggestions.
reset(); state.rage=25; state.shout=false
expect(recommend(),S.BATTLE_SHOUT,"missing combat Shout applies")
state.shout=true; expectHS("healthy Shout not refreshed")
state.queued=S.HEROIC_STRIKE; expect(recommend(),nil,"queued HS suppressed")
state.queued=S.CLEAVE; expect(recommend(),nil,"shared queued Cleave suppressed")
state.queued=nil; state.usable[S.HEROIC_STRIKE]=false
expect(recommend(),nil,"unusable HS suppressed")
state.usable[S.HEROIC_STRIKE]=true; state.known[S.HEROIC_STRIKE]=nil
expect(recommend(),nil,"unknown HS suppressed")
I.knownSpellNames[rt.names[S.HEROIC_STRIKE]]=true
state.learnedNames[rt.names[S.HEROIC_STRIKE]]=true
expectHS("higher learned rank recognized by name")
reset(); state.inCombat=false; state.shout=false
expect(recommend(),S.CHARGE,"out-of-combat opener never replaced by Shout")

reset(); state.targetHP=25; state.rage=20
expectHS("no reserve for unlearned Execute")
state.known[S.EXECUTE]=true; state.rage=50; state.trend="danger"
local title
id,title= recommend(); expect(id,nil,"Execute pooling survives warning")
expect(title,"POOL FOR EXECUTE","pooling feedback survives warning")
state.rage=85; expectHS("near-cap release during warning","danger")

-- No stale warning leaks to the next decision. Manual recovery and interrupts
-- remain ahead of the offensive scorer; no other class opts into this policy.
reset(); state.trend="caution"; state.rage=25; expectHS("warning on","caution")
state.trend=nil; expectHS("warning clears")
state.trend="danger"; e.HCOB_DB.hcDangerAdvisor=false; expectHS("trend option off")
state.hp=30; expectHS("HP warning independent of trend option","danger")
state.hp=100; e.HCOneButton.UI.SurvivalStrip={ManualUsePending=function() return true end}
id,title=recommend(); expect(id,nil,"manual recovery priority"); expect(title,"MANUAL PRIORITY","manual hold feedback")
reset(); state.trend="danger"; state.known[S.PUMMEL]=true; state.targetCast={name="Enemy cast"}
expect(recommend(),S.PUMMEL,"interrupt beats offensive warning")
reset(); W.riskWarningsOnly=false; state.hp=35; state.known[S.HAMSTRING]=true
expect(recommend(),S.HAMSTRING,"legacy danger route unchanged for non-opted class")
state.hp=100; state.trend="danger"
expect(recommend(),S.HAMSTRING,"legacy trend danger route unchanged")

-- Warning color must not turn ordinary spell changes into urgent swaps.
reset(); state.trend="danger"; state.rage=25
expect(Engine.Stabilize(recommend()),S.HEROIC_STRIKE,"initial warning action")
state.shout=false; state.now=state.now+.01
expect(Engine.Stabilize(recommend()),S.HEROIC_STRIKE,"warning swap still confirms")
state.now=state.now+.10
expect(Engine.Stabilize(recommend()),S.HEROIC_STRIKE,"transient warning action held")
state.now=state.now+.11
expect(Engine.Stabilize(recommend()),S.BATTLE_SHOUT,"stable warning action released")
state.hp=20; state.known[S.HAMSTRING]=true
expect(Engine.Stabilize(recommend()),S.HAMSTRING,"true emergency bypasses warning confirmation")
reset(); state.rage=50
expect(Engine.Stabilize(recommend()),S.HEROIC_STRIKE,"swing request visible before impact")
I.lastAutoAttack=state.now
expect(Engine.Stabilize(recommend()),nil,"fresh swing immediately clears stale unqueued request")

-- Invalid saved numeric values cannot disable spending or corrupt thresholds.
for _, value in ipairs({"invalid",0/0,math.huge,-math.huge}) do
    reset(); e.HCOB_DB.warriorHeroicRage=value
    expect(W:HeroicRageThreshold(70),25,"invalid base uses default")
end
reset(); e.HCOB_DB.warriorHeroicRage="50"
expect(W:HeroicRageThreshold(70),40,"numeric saved string")
e.HCOB_DB.warriorHeroicRage=1
expect(W:HeroicRageThreshold(70),20,"lower bound")
e.HCOB_DB.warriorHeroicRage=100
expect(W:HeroicRageThreshold(70),60,"upper base bound")

-- Real stabilizer + 120ms heartbeat across five swing speeds and 12 phases.
-- The old 90ms worst case now leaves at least 400ms to react before impact.
local minimumLead=math.huge
for _, speed in ipairs({1.3,2.0,2.8,3.5,4.0}) do
    for phase=0,11 do
        reset(); state.speed=speed; state.rage=25; state.now=100
        Engine.Stabilize(recommend())
        local first
        for tick=0,math.ceil(speed/.12) do
            state.now=100+phase/100+tick*.12
            if state.now>=100+speed then break end
            if Engine.Stabilize(recommend())==S.HEROIC_STRIKE then first=first or state.now end
        end
        expect(first~=nil,true,"swing visible " .. speed .. "/" .. phase)
        local lead=100+speed-first; minimumLead=math.min(minimumLead,lead)
        expect(lead>=.40,true,"human reaction margin")
        state.queued=S.HEROIC_STRIKE
        expect(Engine.Stabilize(recommend()),nil,"ack clears displayed queued action immediately")
    end
end
print(string.format("Warrior offensive leveling: %d checks PASS; minimum simulated swing lead %.2fs",checks,minimumLead))
