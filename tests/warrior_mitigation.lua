local rt = assert(loadfile("tests/helpers/warrior_runtime.lua"))()()
local e, I, S, W, Engine = rt.env, rt.internal, rt.S, rt.Warrior, rt.Engine
local checks, state = 0
local function expect(actual, wanted, label)
    checks=checks+1
    assert(actual==wanted,label..": expected "..tostring(wanted)..", got "..tostring(actual))
end
local function reset()
    state=rt.reset(); state.level=16; state.targetLevel=16; state.rage=25
    state.known[S.DEMO_SHOUT]=true; state.known[S.SUNDER_ARMOR]=true
    state.debuffs[S.THUNDER_CLAP]=nil; I.currentFight.startClock=state.now
    e.AuraByName=nil
end
local function candidate(id)
    W:GetRecommendation(true,true,state.targetHP,1)
    for _, c in ipairs(Engine.lastCandidates or {}) do if c.id==id then return true end end
    return false
end
-- Capture the real scorer's inputs without replacing its selection logic.
local select = Engine.SelectCandidate
Engine.SelectCandidate=function(list) Engine.lastCandidates=list; return select(list) end

for _,delta in ipairs({-2,0,1,2}) do
    reset(); state.targetLevel=state.level+delta
    expect(I.Recommend(),S.HEROIC_STRIKE,"healthy normal target keeps damage")
    expect(candidate(S.DEMO_SHOUT),false,"level alone does not request Demo")
    expect(candidate(S.THUNDER_CLAP),false,"level alone does not request Clap")
    expect(candidate(S.SUNDER_ARMOR),false,"unknown lifetime does not request Sunder")
end
reset(); state.hp=55
expect(candidate(S.DEMO_SHOUT),false,"low starting health alone is not melee pressure")
Engine.lastMeleeAt=state.now
expect(candidate(S.DEMO_SHOUT),true,"recent melee at reduced HP permits mitigation")
expect(candidate(S.THUNDER_CLAP),true,"Clap shares measured pressure guard")
Engine.lastMeleeAt=state.now-4.01
expect(candidate(S.DEMO_SHOUT),false,"stale incoming attack is not current pressure")
for _,classification in ipairs({"elite","rareelite","worldboss"}) do
    reset(); state.classification=classification
    expect(candidate(S.DEMO_SHOUT),true,"elite mitigation remains available")
end
reset(); state.enemies=2
expect(candidate(S.DEMO_SHOUT),true,"multi-pull mitigation remains available")
state.inRange=false
expect(candidate(S.DEMO_SHOUT),false,"no AoE shout before reaching target")
expect(candidate(S.THUNDER_CLAP),false,"no Clap outside proven reach")
expect(W:IsPendingRecommendationValid(S.DEMO_SHOUT),false,"stale out-of-range hint withdrawn")
state.inRange=nil
expect(candidate(S.DEMO_SHOUT),false,"unknown reach is not assumed in range")
state.inRange=true; state.enemies=1
expect(W:IsPendingRecommendationValid(S.DEMO_SHOUT),false,"cleared pressure withdraws mitigation")

-- Rank-safe acknowledgement is bounded, does not leak to another target and
-- does not treat a resisted cast as a 30-second successful aura.
reset(); state.enemies=2
local oldName=I.SpellName
I.SpellName=function(id) if id==6190 then return oldName(S.DEMO_SHOUT) end return oldName(id) end
W:HandleEvent("UNIT_SPELLCAST_SUCCEEDED","player",nil,6190)
state.now=state.now+1.7
expect(candidate(S.DEMO_SHOUT),false,"no repeated shout during application grace")
state.now=state.now+.31
expect(candidate(S.DEMO_SHOUT),true,"resist/absent aura can retry after grace")
W:HandleEvent("UNIT_SPELLCAST_SUCCEEDED","player",nil,6190)
state.guid="target-b"
expect(candidate(S.DEMO_SHOUT),true,"target switch does not inherit cast grace")
I.SpellName=oldName

-- Healthy auras supplied by any caster suppress repeats, including brief API
-- gaps. Real removal and the final three-second refresh still work.
reset(); state.enemies=2
local active, remaining=true,30
e.AuraByName=function(unit,name,filter,mine)
    expect(mine,false,"another player's same debuff is respected")
    return active,remaining
end
expect(candidate(S.DEMO_SHOUT),false,"healthy aura suppressed")
active=false; state.now=state.now+.1
expect(candidate(S.DEMO_SHOUT),false,"single aura-read miss suppressed")
state.now=state.now+.76
expect(candidate(S.DEMO_SHOUT),true,"real aura removal becomes eligible")
active=true; remaining=3
expect(candidate(S.DEMO_SHOUT),true,"last-three-second refresh remains available")
remaining=30; candidate(S.DEMO_SHOUT); active=false; state.guid="target-c"
expect(candidate(S.DEMO_SHOUT),true,"observation cache cannot cross targets")

-- Fight Club's DPR comparison values armor reduction as offensive setup with
-- a payoff proportional to remaining HP. Do not lump Sunder into mitigation
-- or impose a new delay/reservation for a not-yet-queued Heroic Strike.
reset(); state.targetHP=80; state.rage=15
expect(candidate(S.SUNDER_ARMOR),true,"early offensive Sunder stays eligible")
expect(candidate(S.DEMO_SHOUT),false,"offensive setup is distinct from mitigation")
state.debuffs[S.SUNDER_ARMOR]=25
expect(candidate(S.SUNDER_ARMOR),false,"maintained armor reduction not spammed")
state.debuffs[S.SUNDER_ARMOR]=nil; state.targetHP=59
expect(candidate(S.SUNDER_ARMOR),false,"late target skips setup")
state.targetHP=80; state.dynamics={ttk=8,confidence=1}
expect(candidate(S.SUNDER_ARMOR),false,"short measured fight skips setup")
state.dynamics={ttk=20,confidence=1}; state.queued=S.HEROIC_STRIKE
expect(candidate(S.SUNDER_ARMOR),false,"already queued damage keeps its Rage")
state.rage=30
state.now=state.now+0.8 -- allow the verified aura-removal grace to expire
expect(candidate(S.SUNDER_ARMOR),true,"both funded actions can coexist")
reset(); state.hp=20; state.known[S.HAMSTRING]=true
expect(I.Recommend(),S.HAMSTRING,"critical health still preempts offense")
print(string.format("Warrior measured mitigation: %d checks PASS",checks))
