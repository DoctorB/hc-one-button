-- Warlock leveling policy against the real class module, Engine selection and
-- secure macro helpers. Fixtures vary pet geometry, Soul Shards and wand state.
local e=setmetatable({}, {__index=_G}); e._G=e
e.HCOneButton={Internal=e,Data={},Core={},Classes={},Systems={},UI={},Advisor={Engine={}}}
e.PLAYER_CLASS="WARLOCK"; e.MACRO_LIMIT=255
local known,usable,cooldown,buffs,debuffs,ctx
local wand,shards,petSpells,petCooldown,petTarget,enemies,targetGUID
local now=100
e.GetTime=function() return now end
e.IsKnown=function(id) return known[id]==true end
e.IsUsable=function(id) return known[id]==true and usable[id]~=false end
e.CooldownReady=function(id) return not cooldown[id] end
e.CooldownRemaining=function(id) return cooldown[id] and 4 or 0 end
e.SafeNumber=function(v,fallback) return tonumber(v) or fallback end
e.SafeString=function(v,fallback) return type(v)=="string" and v or fallback end
e.HasWandEquipped=function() return wand end
e.StablePlayerBuff=function(id) return buffs[id]~=nil,buffs[id] or 0 end
e.HasPlayerBuff=e.StablePlayerBuff
e.HasMyTargetDebuff=function(id) return debuffs[id]==true end
e.StableMyTargetDebuff=e.HasMyTargetDebuff
e.SpellName=function(id) return "Localized"..tostring(id) end
e.TalentSpec=function() return ctx.spec,"Test tree",1 end
e.UnitHealthPct=function(unit) return unit=="player" and ctx.player.hp or ctx.target.hp,true end
e.UnitPowerPct=function() return ctx.player.mana,true end
e.UnitPowerType=function() return 0 end
e.UnitExists=function(unit)
    if unit=="pettarget" then return petTarget~=nil end
    return unit=="pet" and ctx.pet.alive
end
e.UnitIsUnit=function(a,b) return a=="pettarget" and b=="target" and petTarget=="target" end
e.SafeBoolean=function(v,fallback) if v==nil then return fallback end return v==true end
e.SafeUnitGUID=function(unit) return unit=="target" and targetGUID or nil end
e.HostileLiveTarget=function() return ctx.hostile and targetGUID~=nil end
e.CountActiveEnemies=function() return enemies end
e.GetItemCount=function(id) return id==6265 and shards or 0 end
e.GetPetActionInfo=function(slot) return petSpells[slot] end
e.GetPetActionCooldown=function(slot)
    if petCooldown[slot] then return now-1,8,1 end
    return 0,0,1
end
local function load(path)
    local chunk=assert(loadfile("HCOneButton/"..path)); setfenv(chunk,e); chunk()
end
load("Data/Spells.lua"); local s=e.HCOneButton.Data.Spells; e.S=s
load("Core/Macros.lua"); load("Advisor/Engine.lua"); load("Classes/Warlock.lua")
local engine=e.HCOneButton.Advisor.Engine
local warlock=e.HCOneButton.Classes.WARLOCK
engine.BuildClassContext=function() return ctx end
engine.SurvivalReserve=function() return ctx.combat.reserve end
local checks=0
local function expect(actual,wanted,label)
    checks=checks+1
    assert(actual==wanted,label..": got "..tostring(actual)..", wanted "..tostring(wanted))
end
local function reset()
    known={}
    for _,id in ipairs({s.SHOOT,s.SHADOW_BOLT,s.CORRUPTION,s.CURSE_AGONY,s.IMMOLATE,s.LIFE_TAP,
        s.DRAIN_LIFE,s.DRAIN_SOUL,s.DEMON_SKIN,s.FEAR,s.HEALTH_FUNNEL}) do known[id]=true end
    usable,cooldown,buffs,petSpells,petCooldown={},{},{[s.DEMON_SKIN]=100},{},{}
    debuffs={[s.CORRUPTION]=true,[s.CURSE_AGONY]=true,[s.IMMOLATE]=true}
    ctx={inCombat=true,hostile=true,spec=1,player={hp=100,mana=80,level=20,grouped=false},
        target={hp=70,close=false,onPlayer=false},combat={reserve=80},
        pet={alive=true,hp=100,tanking=true}}
    wand,shards,petTarget,enemies,targetGUID=true,3,"target",1,"Creature-mob-1"
    warlock.petOffSince,warlock.engagedGUID=nil,nil
    engine.ResetStabilization()
end
local function choose()
    return warlock:GetRecommendation(ctx.inCombat,ctx.hostile,ctx.target.hp,ctx.spec)
end
local function candidate(id)
    for _,c in ipairs(warlock:GetCandidates(ctx)) do if c.id==id then return c end end
end

-- Baseline: funded, DoTs up, pet tanking at range.
reset()
expect(choose(),s.SHADOW_BOLT,"funded filler with DoTs up")
debuffs[s.CORRUPTION]=nil
expect(choose(),s.CORRUPTION,"missing Corruption is applied first")

-- A mob the pet holds within ~10 yards is not a reason to stop casting.
reset();ctx.target.close=true
expect(candidate(s.SHADOW_BOLT)~=nil,true,"Shadow Bolt next to a pet-held mob")
ctx.player.mana=30
expect(candidate(s.SHOOT)~=nil,true,"wand next to a pet-held mob")
reset();ctx.target.close=true;debuffs[s.IMMOLATE]=nil;ctx.spec=3
expect(candidate(s.IMMOLATE)~=nil,true,"Immolate next to a pet-held mob")
-- The same distance is still exposed when the mob is on the player or loose.
for _,geometry in ipairs({{onPlayer=true,tanking=true},{onPlayer=false,tanking=false}}) do
    reset();ctx.target.close=true;ctx.target.onPlayer=geometry.onPlayer;ctx.pet.tanking=geometry.tanking
    debuffs[s.IMMOLATE]=nil;ctx.player.mana=30
    expect(candidate(s.SHADOW_BOLT),nil,"exposed Shadow Bolt excluded")
    expect(candidate(s.IMMOLATE),nil,"exposed Immolate excluded")
    expect(candidate(s.SHOOT),nil,"exposed wand excluded")
    ctx.target.hp=10
    expect(candidate(s.DRAIN_SOUL),nil,"exposed Drain Soul excluded")
end

-- Soul Shard economy: Drain Soul must beat the finishing wand below the cap.
for _,mana in ipairs({10,30,80}) do
    reset();ctx.target.hp=10;ctx.player.mana=mana;shards=0
    expect(choose(),s.DRAIN_SOUL,"Drain Soul beats finishing wand at mana "..mana)
end
reset();ctx.target.hp=10;shards=5
expect(candidate(s.DRAIN_SOUL),nil,"no Drain Soul at the shard cap")
expect(choose(),s.SHOOT,"wand finishes at the shard cap")
reset();known[s.SHADOWBURN]=true;ctx.target.hp=20
for count,eligible in pairs({[0]=false,[1]=false,[2]=false,[3]=true,[5]=true}) do
    shards=count
    expect(candidate(s.SHADOWBURN)~=nil,eligible,"Shadowburn keeps two shards in reserve ("..count..")")
end
shards=1;ctx.combat.reserve=44
expect(candidate(s.SHADOWBURN)~=nil,true,"low survival reserve may spend the reserve shards")
shards=0;usable[s.SHADOWBURN]=false
expect(candidate(s.SHADOWBURN),nil,"native usability still requires a shard")

-- Health Funnel keeps the tanking pet alive; Drain Life is only the fallback.
reset();ctx.pet.hp=30
expect(choose(),s.HEALTH_FUNNEL,"hurt tanking pet gets Health Funnel")
expect(candidate(s.DRAIN_LIFE),nil,"full-HP warlock does not Drain Life for the pet")
ctx.pet.hp=41
expect(candidate(s.HEALTH_FUNNEL),nil,"healthy enough pet keeps damage going")
ctx.pet.hp=30;ctx.player.hp=54
expect(candidate(s.HEALTH_FUNNEL),nil,"low warlock HP cannot pay for Health Funnel")
reset();ctx.pet.hp=20;ctx.target.onPlayer=true
expect(candidate(s.HEALTH_FUNNEL),nil,"mob on the player: no Health Funnel")
reset();ctx.pet.hp=20;ctx.target.hp=18
expect(candidate(s.HEALTH_FUNNEL),nil,"nearly dead target: no Health Funnel")
reset();ctx.pet.hp=20;known[s.HEALTH_FUNNEL]=nil
expect(choose(),s.DRAIN_LIFE,"without Health Funnel the critical pet falls back to Drain Life")
reset();ctx.pet.hp=30;known[s.DEATH_COIL]=true;ctx.target.close=true;ctx.player.hp=60
expect(choose(),s.DEATH_COIL,"survival control still outranks Health Funnel")

-- Without a wand Shadow Bolt is the filler through the tail and on less mana.
reset();wand=false;ctx.target.hp=20;ctx.player.mana=30
expect(choose(),s.SHADOW_BOLT,"no-wand Shadow Bolt below 28% target HP")
ctx.player.mana=29
expect(candidate(s.SHADOW_BOLT),nil,"no-wand mana floor")
reset();ctx.player.mana=41
expect(candidate(s.SHADOW_BOLT),nil,"wand users keep the 42% Shadow Bolt gate")
reset();wand=false;ctx.player.mana=29;ctx.target.hp=50
local id,title,key=warlock:GetIdleRecommendation(true,true)
expect(id,nil,"no-wand idle has no action")
expect(key,"WAIT / RECOVER","no-wand idle never asks for BASE spam")
expect(title,"LET DOTS AND PET WORK","no-wand idle title")
wand=true
expect(warlock:GetIdleRecommendation(true,true),nil,"wand users keep the shared wand fallback")
wand=false
expect(warlock:GetIdleRecommendation(false,true),nil,"idle wait is combat only")

-- Out-of-combat opener (pet already sent by BASE) instead of a wand tick;
-- Life Tap first when low.
reset();ctx.inCombat=false
expect(choose(),s.SHADOW_BOLT,"Shadow Bolt opener")
local opener=candidate(s.SHADOW_BOLT)
expect(opener.key,"CAST MANUALLY","opener is a manual cast")
ctx.player.mana=40
expect(choose(),s.LIFE_TAP,"pre-pull Life Tap before the opener")
ctx.player.hp=70
expect(choose(),s.SHADOW_BOLT,"no pre-pull Life Tap on low HP")
ctx.player.mana=20
expect(choose(),s.CORRUPTION,"cheap Corruption opener on low mana")
ctx.hostile=false
expect(#warlock:GetCandidates(ctx),0,"no opener without a hostile target")
ctx.hostile=true;known[s.SHADOW_BOLT]=nil;known[s.CORRUPTION]=nil;ctx.player.mana=80;ctx.player.hp=100
expect(#warlock:GetCandidates(ctx),0,"no unlearned opener")

-- Targeting alone never pulls: no opener slot for the pixel reader until a
-- BASE press on this target (or the pet already attacking it).
for _,hasWand in ipairs({true,false}) do
    reset();ctx.inCombat=false;petTarget=nil;wand=hasWand
    expect(candidate(s.SHADOW_BOLT),nil,"no opener on a fresh target, wand "..tostring(hasWand))
    expect(candidate(s.CORRUPTION),nil,"no DoT opener on a fresh target, wand "..tostring(hasWand))
    local pullId,pullTitle,pullKey=warlock:GetIdleRecommendation(false,true)
    expect(pullId,nil,"PULL READY has no spell, wand "..tostring(hasWand))
    expect(pullTitle,"PULL READY","fresh target waits for the pull, wand "..tostring(hasWand))
    expect(pullKey,"PRESS BASE","fresh target asks for BASE, wand "..tostring(hasWand))
    expect(choose(),nil,"fresh target selects nothing, wand "..tostring(hasWand))
    ctx.player.mana=40
    expect(choose(),s.LIFE_TAP,"pre-pull Life Tap does not pull, wand "..tostring(hasWand))
    ctx.player.mana=80
    warlock:OnBaseInput()
    expect(choose(),s.SHADOW_BOLT,"BASE press starts the opener, wand "..tostring(hasWand))
    local _,engagedTitle=warlock:GetIdleRecommendation(false,true)
    if hasWand then
        expect(engagedTitle,nil,"engaged wand user keeps the shared wand fallback")
    else
        expect(engagedTitle,"NO OPENER READY","engaged no-wand idle waits for mana")
    end
    targetGUID="Creature-mob-2"
    expect(candidate(s.SHADOW_BOLT),nil,"a new target needs a new BASE press, wand "..tostring(hasWand))
end
reset();ctx.inCombat=false;petTarget=nil;ctx.pet.alive=false
warlock:OnBaseInput()
expect(choose(),s.SHADOW_BOLT,"BASE press engages even without a pet")
ctx.hostile=false;targetGUID="Creature-mob-3";warlock:OnBaseInput()
expect(warlock.engagedGUID,"Creature-mob-1","BASE on a non-hostile target does not engage")
reset();ctx.inCombat=false;petTarget=nil;warlock:OnBaseInput()
ctx.inCombat=true;warlock:GetCandidates(ctx)
expect(warlock.engagedGUID,nil,"combat clears the engagement mark")
ctx.inCombat=false
expect(candidate(s.SHADOW_BOLT),nil,"after combat the next pull needs BASE again")

-- Spell Lock is offered only when the Felhunter can actually cast it.
reset()
expect(warlock:GetInterruptRecommendation(),nil,"no Felhunter, no Spell Lock")
petSpells[4]=e.SpellName(s.SPELL_LOCK)
expect(warlock:GetInterruptRecommendation(),s.SPELL_LOCK,"ready Spell Lock")
petCooldown[4]=true
expect(warlock:GetInterruptRecommendation(),nil,"Spell Lock on cooldown is not an interrupt")
petCooldown[4]=nil;e.GetPetActionCooldown=nil
expect(warlock:GetInterruptRecommendation(),s.SPELL_LOCK,"missing cooldown API keeps the old behavior")

-- Pre-pull readiness pet fixes.
reset();known[s.SUMMON_IMP]=true;known[s.SUMMON_VOIDWALKER]=true
shards=1
expect(warlock:GetPetRecoverySpell("missing"),s.SUMMON_VOIDWALKER,"Voidwalker when a shard is available")
shards=0
expect(warlock:GetPetRecoverySpell("missing"),s.SUMMON_IMP,"Imp without shards")
known[s.SUMMON_IMP]=nil
expect(warlock:GetPetRecoverySpell("missing"),nil,"no learned summon")
expect(warlock:GetPetRecoverySpell("hurt"),s.HEALTH_FUNNEL,"hurt pet gets Health Funnel")
known[s.HEALTH_FUNNEL]=nil
expect(warlock:GetPetRecoverySpell("hurt"),nil,"unlearned Health Funnel stays text only")

-- Single-press BASE: pet plus wand in every tree; pet only without a wand.
for _,spec in ipairs({1,2,3}) do
    reset();ctx.spec=spec
    local macro=warlock:BuildMainMacro()
    expect(macro:find("/petattack [harm]",1,true)~=nil,true,"BASE sends the pet at once, tree "..spec)
    expect(macro:find("combat",1,true),nil,"pet attack is not combat-gated, tree "..spec)
    expect(macro:find("!"..e.SpellName(s.SHOOT),1,true)~=nil,true,"wand BASE in tree "..spec)
    expect(macro:find(e.SpellName(s.SHADOW_BOLT),1,true),nil,"no Shadow Bolt in BASE, tree "..spec)
    expect((warlock:GetBaseActionInfo(spec)),s.SHOOT,"wand base action, tree "..spec)
    wand=false
    expect(warlock:BuildMainMacro(),"/petattack [harm]","no-wand BASE only commands the pet, tree "..spec)
    local baseId,description=warlock:GetBaseActionInfo(spec)
    expect(baseId,nil,"no-wand BASE has no spell")
    expect(description,"PET ATTACK","no-wand BASE description")
    expect(warlock:IsRangedBaseAction(s.SHADOW_BOLT),false,"Shadow Bolt is not BASE")
end
reset();wand=false
local idleId,idleTitle,idleKey=warlock:GetIdleRecommendation(false,true)
expect(idleId,nil,"no-wand pull wait has no action")
expect(idleTitle,"NO OPENER READY","engaged no-wand pull waits for mana")
expect(idleKey,"WAIT / RECOVER","engaged no-wand pull wait never asks for BASE")
expect(warlock:GetIdleRecommendation(false,false),nil,"no idle without a hostile target")
wand=true
expect(warlock:GetIdleRecommendation(false,true),nil,"engaged wand user keeps the shared wand fallback")

-- Pet not on the target: one BASE press after a one-second grace.
local function petNotice()
    for _,c in ipairs(warlock:GetCandidates(ctx)) do if c.title=="PET NOT ATTACKING" then return c end end
end
reset();ctx.pet.tanking=false;petTarget=nil
expect(petNotice(),nil,"grace period hides the first frame")
now=now+0.99
expect(petNotice(),nil,"grace period still running")
now=now+0.02
local notice=petNotice()
expect(notice~=nil,true,"idle pet raises the notice")
expect(notice.id,nil,"notice has no spell for the pixel reader")
expect(notice.key,"PRESS BASE ONCE","notice asks for a single BASE press")
expect(choose(),nil,"notice outranks ordinary damage")
petTarget="other"
expect(petNotice()~=nil,true,"pet on another target raises the notice")
petTarget="target"
expect(petNotice(),nil,"pet on the target clears the notice")
petTarget=nil
expect(petNotice(),nil,"clearing restarts the grace period")
now=now+1.1
expect(petNotice()~=nil,true,"notice returns after a new grace period")
enemies=2
expect(petNotice(),nil,"multi-mob pulls may split pet and warlock targets")
enemies=1;ctx.pet.tanking=true
expect(petNotice(),nil,"mob on the pet needs no notice")
ctx.pet.tanking=false;ctx.pet.alive=false
expect(petNotice(),nil,"no pet, no notice")
ctx.pet.alive=true;ctx.inCombat=false;warlock:GetCandidates(ctx)
expect(warlock.petOffSince,nil,"leaving combat resets the grace period")
ctx.inCombat=true
expect(petNotice(),nil,"new combat starts a new grace period")
print("Warlock leveling regression: "..checks.." checks PASS")
