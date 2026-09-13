-- Aggressive leveling policy against real Priest + selection/macro code.
-- Fixtures vary learned spells, native rank/talent costs and fight state.
local e=setmetatable({}, {__index=_G}); e._G=e
e.HCOneButton={Internal=e,Data={},Core={},Classes={},Systems={},UI={},Advisor={Engine={}}}
e.PLAYER_CLASS="PRIEST"; e.MACRO_LIMIT=255
local known,usable,cooldown,buffs,debuffs,costs,castMS,ctx
local maxMana,wand,heal,queriedName,costFailure
local now=100
e.GetTime=function() return now end
e.IsKnown=function(id) return known[id]==true end
e.IsUsable=function(id) return known[id]==true and usable[id]~=false end
e.CooldownReady=function(id) return not cooldown[id] end
e.CooldownRemaining=function(id) return cooldown[id] and 4 or 0 end
e.SafeNumber=function(v,fallback) return tonumber(v) or fallback end
e.SafeUnitPowerMax=function() return maxMana end
e.HasWandEquipped=function() return wand end
e.StablePlayerBuff=function(id) return buffs[id]~=nil,buffs[id] or 0 end
e.HasPlayerBuff=e.StablePlayerBuff
e.HasMyTargetDebuff=function(id) return debuffs[id]==true end
e.SpellName=function(id) return "Localized"..id end
e.SpellCastSeconds=function(id) return (castMS[id] and castMS[id]>0) and castMS[id]/1000 or 3 end
e.TalentSpec=function() return ctx.spec,"Test tree",ctx.player.level>=10 and 1 or 0 end
e.UnitHealthPct=function(unit) return unit=="player" and ctx.player.hp or ctx.target.hp,true end
e.UnitPowerPct=function() return ctx.player.mana,true end
e.UnitPowerType=function() return 0 end
e.CountActiveEnemies=function() return 1 end
local function nativeCost(name)
    queriedName=name
    if costFailure then error("cost unavailable") end
    local id=tonumber(name:match("Localized(%d+)"))
    local cost=costs[id]
    if type(cost)=="table" then return cost end
    if cost~=nil then return {{type=0,cost=cost}} end
end
e.GetSpellPowerCost=nativeCost
e.GetSpellInfo=function(name)
    local id=type(name)=="number" and name or tonumber(name:match("Localized(%d+)"))
    return e.SpellName(id),nil,"icon",castMS[id]
end
local function load(path)
    local chunk=assert(loadfile("HCOneButton/"..path)); setfenv(chunk,e); chunk()
end
load("Data/Spells.lua"); local s=e.HCOneButton.Data.Spells; e.S=s
load("Core/Macros.lua"); load("Advisor/Engine.lua"); load("Classes/Priest.lua")
load("Systems/AdaptiveTuner.lua")
local engine=e.HCOneButton.Advisor.Engine
local priest=e.HCOneButton.Classes.PRIEST
local tuner=e.HCOneButton.Systems.AdaptiveTuner
engine.BuildClassContext=function() return ctx end
engine.PlayerHasDebuff=function(id) return debuffs[id]==true end
engine.PriestHealSpell=function() return heal end
engine.SurvivalReserve=function() return ctx.combat.reserve end
local checks=0
local function expect(actual,wanted,label)
    checks=checks+1
    assert(actual==wanted,label..": got "..tostring(actual)..", wanted "..tostring(wanted))
end
local function reset()
    known={[s.SHOOT]=true,[s.SMITE]=true,[s.MIND_BLAST]=true,[s.SHADOW_WORD_PAIN]=true,[s.POWER_WORD_SHIELD]=true}
    usable,cooldown,debuffs,costs={},{},{[s.SHADOW_WORD_PAIN]=true},{}
    buffs={[s.POWER_WORD_SHIELD]=100}
    castMS={[s.SMITE]=2000,[s.MIND_BLAST]=1500,[s.MIND_FLAY]=0,[s.HOLY_FIRE]=3500}
    ctx={inCombat=true,hostile=true,spec=3,player={hp=100,mana=60,level=10,grouped=false},
        target={hp=60,close=false},combat={reserve=80},pet={}}
    maxMana,wand,heal,costFailure=1000,true,nil,false
    e.GetSpellPowerCost=nativeCost; e.C_Spell=nil
    e.HCOneButton.Systems.AdaptiveTuner=nil
    engine.ResetStabilization()
end
local function choose()
    return priest:GetRecommendation(ctx.inCombat,ctx.hostile,ctx.target.hp,ctx.spec)
end
local function candidate(id)
    for _,c in ipairs(priest:GetCandidates(ctx)) do if c.id==id then return c end end
end

-- The old 55% target / 52% mana thresholds must not send a funded priest
-- into wand-only combat. These checks exercise the real scoring selector.
for _,spec in ipairs({1,2,3}) do
    for _,mana in ipairs({40,52,75,100}) do
        reset();ctx.spec=spec;ctx.player.mana=mana;ctx.target.hp=50
        expect(choose(),s.MIND_BLAST,"burst beats early wand, tree "..spec.." mana "..mana)
        cooldown[s.MIND_BLAST]=true
        local id,_,key=choose()
        expect(id,s.SMITE,"learned Smite fills burst cooldown across trees")
        expect(key,"CAST MANUALLY","Smite never points at a wand BASE modifier")
    end
end
reset();ctx.player.level=9;ctx.spec=3;known[s.MIND_BLAST]=nil
expect(choose(),s.SMITE,"pre-talent fallback retains learned Smite")
ctx.player.level=10
expect(choose(),s.SMITE,"first Shadow point cannot remove Smite")
ctx.player.level=15
expect(choose(),s.SMITE,"early Shadow leveling does not require unlearned Mind Flay")
for _,spec in ipairs({1,2,3}) do
    reset();ctx.spec=spec;ctx.player.level=30;cooldown[s.MIND_BLAST]=true;known[s.MIND_FLAY]=true
    expect(choose(),s.MIND_FLAY,"learned Mind Flay works in mixed tree "..spec)
    usable[s.MIND_FLAY]=false
    expect(choose(),s.SMITE,"unusable learned filler falls back to Smite")
    usable[s.SMITE]=false
    expect(candidate(s.SMITE),nil,"native usability excludes restricted Holy spells")
end
reset();buffs[s.SPIRIT_TAP]=100
expect(choose(),s.MIND_BLAST,"Spirit Tap alone does not suppress burst")
cooldown[s.MIND_BLAST]=true
expect(choose(),s.SMITE,"Spirit Tap alone does not suppress filler")

-- Set up a useful DoT once; do not reapply active effects or buy too few ticks.
reset();debuffs[s.SHADOW_WORD_PAIN]=nil
expect(choose(),s.SHADOW_WORD_PAIN,"DoT setup before ordinary burst on a durable target")
debuffs[s.SHADOW_WORD_PAIN]=true
expect(candidate(s.SHADOW_WORD_PAIN),nil,"active Pain excluded")
debuffs[s.SHADOW_WORD_PAIN]=nil;ctx.combat.ttk=8.99
expect(candidate(s.SHADOW_WORD_PAIN),nil,"Pain needs nine seconds of useful lifetime")
ctx.combat.ttk=9
expect(candidate(s.SHADOW_WORD_PAIN)~=nil,true,"Pain lifetime boundary")
ctx.target.hp=39
expect(candidate(s.SHADOW_WORD_PAIN),nil,"no late low-HP DoT setup without evidence")
reset();known[s.HOLY_FIRE]=true;cooldown[s.MIND_BLAST]=true;ctx.combat.ttk=12
expect(choose(),s.HOLY_FIRE,"learned Holy Fire can contribute in a mixed build")
debuffs[s.HOLY_FIRE]=true
expect(candidate(s.HOLY_FIRE),nil,"active Holy Fire DoT not overwritten")
debuffs[s.HOLY_FIRE]=nil;ctx.combat.ttk=9.49
expect(candidate(s.HOLY_FIRE),nil,"Holy Fire reserves cast time plus useful ticks")
ctx.combat.ttk=9.5
expect(candidate(s.HOLY_FIRE)~=nil,true,"Holy Fire lifetime boundary")

-- Native cost data supersedes static mana gates, including rank and talents.
reset();ctx.player.mana=30;costs[s.MIND_BLAST]=150
expect(candidate(s.MIND_BLAST)~=nil,true,"cast exactly preserves 15% reserve")
expect(queriedName:find("Localized",1,true)==1,true,"cost queries use localized names")
ctx.player.mana=29.99
expect(candidate(s.MIND_BLAST),nil,"reject one cast below post-cast reserve")
ctx.player.mana=30;costs[s.MIND_BLAST]=151
expect(candidate(s.MIND_BLAST),nil,"higher learned rank cost cannot spend banked mana")
costs[s.MIND_BLAST]=140
expect(candidate(s.MIND_BLAST)~=nil,true,"native talent cost reduction creates a real cast opportunity")
reset();ctx.player.hp=70;ctx.player.mana=40;costs[s.MIND_BLAST]=150
expect(candidate(s.MIND_BLAST)~=nil,true,"pressure banks 25%")
costs[s.MIND_BLAST]=151
expect(candidate(s.MIND_BLAST),nil,"pressure reserve remains protected")
reset();ctx.player.mana=40;costs[s.MIND_BLAST]=200;costs[s.POWER_WORD_SHIELD]=250
expect(candidate(s.MIND_BLAST),nil,"bank known recovery cost above percentage floor")
heal=s.LESSER_HEAL;known[heal]=true;costs[heal]=150
expect(candidate(s.MIND_BLAST)~=nil,true,"available cheaper recovery can be banked")
debuffs[s.WEAKENED_SOUL]=true;costs[heal]=250;costs[s.POWER_WORD_SHIELD]=10
expect(candidate(s.MIND_BLAST),nil,"unavailable Shield cannot masquerade as recovery reserve")
reset();ctx.player.mana=40;costs[s.MIND_BLAST]=0
expect(candidate(s.MIND_BLAST)~=nil,true,"known zero-cost cast is valid")
for _,bad in ipairs({-1,math.huge,0/0,"invalid"}) do
    costs[s.MIND_BLAST]={{type=0,cost=bad}}
    expect(priest:SpellManaCost(s.MIND_BLAST),nil,"invalid cost stays unknown")
end
costs[s.MIND_BLAST]={{type=3,cost=1},{type=0,cost=50}}
expect(priest:SpellManaCost(s.MIND_BLAST),50,"select mana rather than another resource")
costFailure=true;e.C_Spell={GetSpellPowerCost=function() return {{type=0,cost=123}} end}
expect(priest:SpellManaCost(s.MIND_BLAST),123,"modern cost API fallback after legacy failure")
e.C_Spell=nil
expect(priest:SpellManaCost(s.MIND_BLAST),nil,"failing APIs never invent free spells")
ctx.player.mana=34.99
expect(candidate(s.MIND_BLAST),nil,"unknown cost uses 35% burst fallback")
ctx.player.mana=35
expect(candidate(s.MIND_BLAST)~=nil,true,"fallback burst gate below former 46%")
costFailure=false;costs[s.MIND_BLAST]=1;maxMana=nil;ctx.player.mana=34.99
expect(candidate(s.MIND_BLAST),nil,"missing maximum mana cannot use partial cost data")

-- Cast horizon uses the localized learned spell rather than rank-1 timing.
reset();cooldown[s.MIND_BLAST]=true;ctx.combat.ttk=2.5
local infoAPI=e.GetSpellInfo
e.GetSpellInfo=function(name)
    if name==e.SpellName(s.SMITE) then return name,nil,"icon",3000 end
    return infoAPI(name)
end
expect(candidate(s.SMITE),nil,"learned three-second cast cannot fit a short remaining fight")
e.GetSpellInfo=function(name)
    if name==e.SpellName(s.SMITE) then return name,nil,"icon",2000 end
    return infoAPI(name)
end
expect(candidate(s.SMITE)~=nil,true,"current cast-time reduction is honored")
e.GetSpellInfo=infoAPI
ctx.combat.ttk=1.8
expect(candidate(s.MIND_BLAST),nil,"cooldown remains a hard eligibility condition")
cooldown[s.MIND_BLAST]=nil
expect(candidate(s.MIND_BLAST),nil,"burst must land before estimated death")
ctx.combat.ttk=1.85
expect(candidate(s.MIND_BLAST)~=nil,true,"burst landing boundary")
reset();ctx.target.close=true
expect(candidate(s.SMITE)~=nil,true,"Shield permits near-target casting")
known[s.MIND_FLAY]=true
expect(candidate(s.MIND_FLAY)~=nil,true,"Shield permits near-target channel")
buffs[s.POWER_WORD_SHIELD]=nil
expect(candidate(s.SMITE)~=nil,true,"healthy high-reserve caster can cast under mild melee pressure")
expect(candidate(s.MIND_FLAY),nil,"unshielded close channel remains excluded")
ctx.player.hp=79
expect(candidate(s.SMITE),nil,"unsafe close filler remains excluded")
reset();ctx.combat.dynamics={confidence=0.7,ttd=2}
expect(candidate(s.MIND_BLAST),nil,"credible imminent death suppresses offensive hard casts")
ctx.combat.dynamics.confidence=0.1
expect(candidate(s.MIND_BLAST)~=nil,true,"uncertain TTD does not fabricate an imminent death")

-- Genuine emergencies stay above damage; low mana / short finishes use wand.
reset();ctx.player.hp=60;buffs[s.POWER_WORD_SHIELD]=nil
expect(choose(),s.POWER_WORD_SHIELD,"Shield retains priority under pressure")
buffs[s.POWER_WORD_SHIELD]=100;heal=s.LESSER_HEAL;known[heal]=true
expect(choose(),heal,"needed healing retains priority over burst")
ctx.target.close=true;ctx.player.hp=45;known[s.PSYCHIC_SCREAM]=true
expect(choose(),s.PSYCHIC_SCREAM,"urgent close control retains priority")
reset();ctx.player.mana=25
expect(choose(),s.SHOOT,"conserve at low mana")
ctx.player.mana=65;ctx.target.hp=20
expect(choose(),s.SHOOT,"short or unknown near-death finish conserves mana")
ctx.combat.ttk=8
expect(choose(),s.MIND_BLAST,"credible longer finish can use burst")
reset();wand=false;known[s.MIND_BLAST]=nil;ctx.target.hp=5
expect(choose(),s.SMITE,"no-wand character still finishes low-HP enemies")
ctx.player.mana=10
expect(choose(),nil,"no-wand budget cannot be bypassed by filler")
local id,title,key=priest:GetIdleRecommendation(true,true)
expect(id,nil,"no-wand idle has no action")
expect(key,"WAIT / RECOVER","no-wand idle cannot re-offer rejected Smite BASE")
expect(priest:GetIdleRecommendation(true,false),nil,"no target remains passive")
wand=true;known[s.SHOOT]=nil
id,title,key=priest:GetIdleRecommendation(true,true)
expect(key,"WAIT / RECOVER","equipped but unlearned Shoot cannot bypass no-wand guard")

-- Real tuner policy and extreme bounded biases: an old wand preference must
-- not recreate early wand-only combat, and emergencies cannot be displaced.
reset();e.HCOneButton.Systems.AdaptiveTuner=tuner
tuner.GetCandidateBias=function(c) return c.id==s.SHOOT and tuner.MAX_SCORE_BIAS or -tuner.MAX_SCORE_BIAS end
engine.lastClassActionId=s.SHOOT;engine.lastClassActionAt=now
expect(choose(),s.MIND_BLAST,"extreme learned bias cannot hide funded burst")
cooldown[s.MIND_BLAST]=true
engine.lastClassActionId=s.SHOOT;engine.lastClassActionAt=now
expect(choose(),s.SMITE,"extreme learned bias plus hysteresis cannot hide funded filler")
ctx.player.hp=45;buffs[s.POWER_WORD_SHIELD]=nil;cooldown[s.MIND_BLAST]=nil
tuner.GetCandidateBias=function(c) return c.tag=="damage" and 12 or -12 end
expect(choose(),s.POWER_WORD_SHIELD,"actual tuner safety policy protects emergency baseline")

-- Leveling openers and secure contract: no learned-rank suffix or new slot.
reset();ctx.inCombat=false;ctx.player.level=1;wand=false;known[s.MIND_BLAST]=nil
expect(choose(),s.SMITE,"level-one learned cast-time opener")
ctx.player.level=10;known[s.MIND_BLAST]=true
expect(choose(),s.MIND_BLAST,"leveling burst opener")
known[s.HOLY_FIRE]=true;ctx.spec=2
expect(choose(),s.HOLY_FIRE,"Holy build retains its learned opener")
ctx.hostile=false
expect(#priest:GetCandidates(ctx),0,"out-of-combat aura maintenance remains absent")
wand=true
expect(priest:BuildMainMacro(),"/cast [harm] !"..e.SpellName(s.SHOOT),"BASE remains a manual wand start")
expect(e.BuildSpellMacro(s.SMITE,"harm"),"/cast [harm] "..e.SpellName(s.SMITE),"Smite uses localized rankless secure cast")
expect(e.BuildSpellMacro(s.MIND_BLAST,"harm"),"/cast [harm] "..e.SpellName(s.MIND_BLAST),"burst uses localized rankless secure cast")
print("Priest aggressive leveling regression: "..checks.." checks PASS")
