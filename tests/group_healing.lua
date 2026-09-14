-- Real group triage, class contracts, secure macro construction and Advisor.
-- Client state is simulated; native secure execution is inspected, not bypassed.
local checks=0
local function expect(actual,wanted,label)
    checks=checks+1
    assert(actual==wanted,label..": expected "..tostring(wanted)..", got "..tostring(actual))
end
local function runtime(class)
    local e=setmetatable({}, {__index=_G}); e._G=e
    local function load(path)
        local f=assert(loadfile("HCOneButton/"..path)); setfenv(f,e); f("HCOneButton")
    end
    e.HCOneButton={Internal=e,UI={},Classes={},Core={},Data={},Systems={},Advisor={Engine={}}}
    load("Data/Spells.lua")
    e.S=e.HCOneButton.Data.Spells
    e.PLAYER_CLASS=class or "PRIEST"; e.now=100; e.combat=false; e.partyCount=2; e.raid=false
    e.HCOB_DB={groupHealing=true,secureActions=true,dangerHP=35,criticalHP=20,hcDangerAdvisor=false,prePullSafety=false}
    e.names={}; e.known={}; e.cost={}; e.seconds={}; e.cooldowns={}; e.unusable={}; e.bindings={}
    for name,id in pairs(e.S) do e.names[id]=name; e.known[id]=true; e.cost[name]=100; e.seconds[name]=2.5 end
    for _,id in ipairs({e.S.RENEW,e.S.POWER_WORD_SHIELD,e.S.REJUVENATION}) do e.seconds[e.names[id]]=0 end
    e.units={player={hp=100,mana=1000,guid="self",name="Player"},
        party1={hp=30,guid="one",name="Marco"},party2={hp=90,guid="two",name="Lucia"},
        target={hp=100,guid="enemy",name="Enemy",hostile=true}}
    e.auras={}; e.ranges={}; e.widgets={}
    local function unit(u) return e.units[u=="mouseover" and (e.mouseover or "none") or u] end
    e.GetTime=function() return e.now end
    e.IsInRaid=function() return e.raid end
    e.GetNumSubgroupMembers=function() return e.partyCount end
    e.GetNumGroupMembers=function() return e.raidCount end
    e.UnitExists=function(u) return unit(u)~=nil end
    e.UnitCanAssist=function(_,u) return unit(u) and not unit(u).hostile and not unit(u).neutral end
    e.UnitCanAttack=function(_,u) return unit(u) and unit(u).hostile end
    e.UnitIsUnit=function(a,b) return unit(a) and unit(b) and unit(a).guid==unit(b).guid or false end
    e.UnitIsConnected=function(u) return unit(u) and not unit(u).offline end
    e.UnitIsDeadOrGhost=function(u) return unit(u) and (unit(u).dead or unit(u).hp==0) or false end
    e.UnitIsDead=e.UnitIsDeadOrGhost
    e.UnitIsCharmed=function(u) return unit(u) and unit(u).charmed or false end
    e.UnitGUID=function(u) return unit(u) and unit(u).guid end
    e.UnitName=function(u) return unit(u) and unit(u).name end
    e.UnitHealthPct=function(u) return unit(u) and unit(u).hp,unit(u) and not unit(u).unknown end
    e.UnitHealthMax=function(u) return unit(u) and (unit(u).maxHP or 1000) end
    e.UnitGetIncomingHeals=function(u) return unit(u) and unit(u).incoming end
    e.UnitPower=function() return e.units.player.mana end
    e.UnitPowerMax=function() return 1000 end
    e.UnitPowerPct=function() return e.units.player.mana/10,true end
    e.UnitPowerType=function() return 0,"MANA" end
    e.UnitAffectingCombat=function() return e.combat end
    e.InCombatLockdown=function() return e.combat end
    e.GetUnitSpeed=function() return e.speed or 0 end
    e.IsMounted=function() return e.mounted end
    e.UnitCastingInfo=function() if e.casting then return "Heal",nil,nil,0,103000,false,"cast",false,2050 end end
    e.UnitChannelInfo=function() if e.channel then return "First Aid",nil,nil,0,108000,false,false,746 end end
    e.SpellName=function(id,fallback) return e.names[id] or fallback end
    e.SpellCastSeconds=function(id) return e.seconds[e.names[id]] or 3 end
    e.GetSpellInfo=function(name) return name,nil,nil,(e.seconds[name] or 3)*1000 end
    e.GetSpellPowerCost=function(name) return {{type=0,cost=e.cost[name]}} end
    e.IsKnown=function(id) return e.known[id] or false end
    e.IsUsable=function(id) return not e.unusable[id] end
    e.CooldownReady=function(id) return not e.cooldowns[id] end
    e.IsSpellInRange=function(_,u) if e.ranges[u]=="unknown" then return nil end; return e.ranges[u]==false and 0 or 1 end
    e.GetBindingKey=function(command) return e.bindings[command] end
    e.SafeNumber=function(v,d) return type(v)=="number" and v==v and math.abs(v)<math.huge and v or d end
    e.SafeString=function(v,d) return type(v)=="string" and v or d end
    e.SafeBoolean=function(v,d) if v==nil then return d end; return v==true or v==1 end
    e.CanAccessValue=function() return true end
    e.CanAccessTable=function(v) return type(v)=="table" end
    e.Clamp=function(v,lo,hi) return math.max(lo,math.min(hi,v)) end
    e.UnitAura=function(u,index,filter)
        local aura=(e.auras[u] or {})[index]
        if aura and (not filter or filter==aura.filter) then return e.names[aura.id],nil,nil,nil,30,e.now+(aura.remaining or 20),aura.source or "player" end
    end
    e.ClearTuningPending=function() e.cleared=(e.cleared or 0)+1 end
    local methods={}
    e.CreateFrame=function(kind,name,parent,template)
        local w=setmetatable({kind=kind,name=name,template=template,attrs={},scripts={},events={}}, {__index=methods})
        e.widgets[#e.widgets+1]=w; return w
    end
    for _,name in ipairs({"SetSize","SetPoint","SetAlpha","EnableMouse"}) do methods[name]=function() end end
    function methods:SetAttribute(k,v) assert(not e.combat,"protected write in combat"); self.attrs[k]=v end
    function methods:RegisterForClicks(...) self.clicks={...} end
    function methods:SetScript(k,v) self.scripts[k]=v end
    function methods:RegisterEvent(event) self.events[event]=true end
    e.UIParent={}
    for _,path in ipairs({"Core/Auras.lua","Core/Range.lua","Advisor/Engine.lua","Advisor/GroupHealing.lua",
        "Classes/Priest.lua","Classes/Paladin.lua","Classes/Shaman.lua","Classes/Druid.lua","UI/GroupHealing.lua"}) do load(path) end
    e.G=e.HCOneButton.Advisor.GroupHealing; e.UI=e.HCOneButton.UI.GroupHealing
    for slot=1,4 do e.bindings[e.G.BindingCommand(slot)]="F"..(5+slot) end
    e.UI.Configure()
    e.pick=function() e.G.Recommend(e.units.player.hp); return e.G.current end
    e.addAura=function(u,id,remaining,source,filter) e.auras[u]=e.auras[u] or {}; table.insert(e.auras[u],{id=id,remaining=remaining,source=source,filter=filter or "HELPFUL"}) end
    return e
end

if ...=="fixture" then return runtime end

for _,class in ipairs({"PRIEST","PALADIN","SHAMAN","DRUID"}) do
    local e=runtime(class)
    local wanted=({PRIEST=e.S.FLASH_HEAL,PALADIN=e.S.FLASH_LIGHT,SHAMAN=e.S.LESSER_HEALING_WAVE,DRUID=e.S.REGROWTH})[class]
    e.units.party1.hp=35
    expect(e.pick().id,wanted,class.." learned quick heal")
    expect(e.pick().unit,"party1",class.." injured member selected")
    e.units.party1.hp=55
    expect(e.pick().slot,2,class.." direct heal for larger noncritical deficit")
    e.units.party1.hp=90
    expect(e.pick(),nil,class.." no unnecessary healing")
    for slot,button in ipairs(e.UI.buttons) do
        local macro=button.attrs.macrotext1
        expect(button.template,"SecureActionButtonTemplate","native secure button")
        expect(button.clicks[1],"LeftButtonUp","one input edge")
        expect(button.attrs.useOnKeyDown,false,"no double cast on key release")
        if button.spellID then
            assert(macro:find("/cast [@mouseover,help,nodead] ",1,true),"mouseover-only cast")
            assert(macro:find("[@mouseover,nohelp]",1,true),"neutral/invalid mouseover must stop")
            assert(not macro:find("@player",1,true) and not macro:find("/target",1,true),"no self or target fallback")
            assert(not macro:find("/stopcasting",1,true),"repeated input must not cancel an active heal")
            assert(not macro:find("Rank",1,true) and #macro<=255,"localized rankless bounded macro")
            expect(macro:find("/cancelform",1,true)~=nil,class=="DRUID","Druid-only form cancel")
        else expect(macro,"/stopmacro","unavailable role is inert") end
    end
    local frozen=e.UI.buttons[1].attrs.macrotext1
    e.combat=true; e.known[wanted]=false
    expect(e.UI.Configure(),false,"learned spell changes deferred in combat")
    expect(e.UI.buttons[1].attrs.macrotext1,frozen,"native macro frozen in combat")
    expect(e.UI.pending,true,"rebuild marked pending")
    e.combat=false; e.UI.Configure()
    expect(e.UI.pending,false,"deferred rebuild completed")
end

local e=runtime()
for id in pairs(e.known) do e.known[id]=false end
e.known[e.S.LESSER_HEAL]=true; e.UI.Configure()
expect(e.pick().id,e.S.LESSER_HEAL,"low-level Priest does not require talents or later heals")
e.names[e.S.LESSER_HEAL]="Soins inférieurs"; e.UI.Configure()
assert(e.UI.buttons[1].attrs.macrotext1:find("Soins inférieurs",1,true),"localized highest-rank resolution")
e.known[e.S.HEAL]=true; e.UI.Configure(); expect(e.UI.spells[2],e.S.HEAL,"upgrade direct heal when learned")
e.known[e.S.GREATER_HEAL]=true; e.UI.Configure(); expect(e.UI.spells[2],e.S.GREATER_HEAL,"later Greater Heal replaces obsolete family")

for _,property in ipairs({"offline","dead","charmed","hostile","neutral","unknown"}) do
    e=runtime(); e.units.party1[property]=true
    expect(e.pick(),nil,"reject "..property.." teammate")
end
for _,hp in ipairs({0,-1,0/0,math.huge,101}) do
    e=runtime(); e.units.party1.hp=hp
    expect(e.pick(),nil,"invalid/dead/full HP rejected")
end
e=runtime(); e.ranges.party1=false; expect(e.pick(),nil,"out-of-range teammate rejected")
e.ranges.party1="unknown"; expect(e.pick(),nil,"unknown range does not advertise a cast")
e=runtime(); e.units.party1.incoming=700; expect(e.pick(),nil,"incoming heals cover the deficit")
e.units.party1.incoming=100; expect(e.pick().slot,1,"partial incoming healing still leaves urgent deficit")
e=runtime(); e.units.party2.hp=15; expect(e.pick().unit,"party2","most injured reachable teammate wins")
e.ranges.party2=false; expect(e.pick().unit,"party1","unreachable lowest HP cannot starve other heals")
e=runtime(); e.raid=true; e.raidCount=3
e.units.raid1=e.units.player; e.units.raid2=e.units.party1; e.units.raid3=e.units.party2
expect(e.pick().unit,"raid2","raid scan excludes player and uses current roster")
e.partyCount=4; e.units.raid2.hp=100; expect(e.pick(),nil,"party list is not double scanned inside a raid")
e=runtime(); e.partyCount=0; expect(e.pick(),nil,"solo characters unchanged")
e=runtime(); e.bindings={}; expect(e.pick(),nil,"unbound group advice does not block the normal rotation")
e.bindings[e.G.BindingCommand(1)]="F6"; e.units.party1.hp=55
expect(e.pick().slot,1,"one bound quick heal can cover a moderate deficit too")
e=runtime(); e.HCOB_DB.groupHealing=false; expect(e.pick(),nil,"persisted advice toggle respected")
e=runtime(); e.HCOB_DB.secureActions=false; expect(e.pick(),nil,"disabled secure actions cannot advertise group bind")
e=runtime(); e.units.player.hp=60; expect(e.pick(),nil,"own recovery has priority")
e=runtime(); e.units.player.hp=70; e.HCOB_DB.dangerHP=70; expect(e.pick(),nil,"configured danger threshold protected")
e=runtime(); e.mounted=true; expect(e.pick(),nil,"mounted player is not asked to heal")
e=runtime(); e.names[15473]="Shadowform"; e.addAura("player",15473)
expect(e.pick(),nil,"Shadowform is never implicitly cancelled")

e=runtime(); e.units.party1.hp=75
expect(e.pick().id,e.S.RENEW,"moderate deficit gets missing Renew")
e.addAura("party1",e.S.RENEW,20); expect(e.pick(),nil,"own active Renew is not spammed")
e.auras.party1[1].remaining=2; expect(e.pick().id,e.S.RENEW,"expiring Renew can be refreshed")
e=runtime("DRUID"); e.units.party1.hp=75
expect(e.pick().id,e.S.REJUVENATION,"Druid HoT support")
e.addAura("party1",e.S.REJUVENATION,20); expect(e.pick(),nil,"own Rejuvenation not spammed")
e.units.party1.hp=35; e.addAura("party1",e.S.REGROWTH,20)
expect(e.pick().id,e.S.HEALING_TOUCH,"active Regrowth favors direct heal")
e.units.party1.hp=20; expect(e.pick().id,e.S.REGROWTH,"critical direct Regrowth remains possible")
e=runtime(); e.units.party1.hp=20
expect(e.pick().id,e.S.POWER_WORD_SHIELD,"critical ally can get a shield")
e.addAura("party1",e.S.WEAKENED_SOUL,30,"other","HARMFUL")
expect(e.pick().id,e.S.FLASH_HEAL,"Weakened Soul excludes Shield")
e.auras.party1={}; e.addAura("party1",e.S.POWER_WORD_SHIELD,20,"other")
expect(e.pick().id,e.S.FLASH_HEAL,"existing shield from another Priest is respected")
e=runtime(); e.units.party1.hp=75; e.speed=7
expect(e.pick().id,e.S.RENEW,"instant HoTs remain available while moving")
e.units.party1.hp=35; expect(e.pick().id,e.S.RENEW,"moving can fall back to an instant heal")
e.unusable[e.S.RENEW]=true; expect(e.pick(),nil,"hardcast is not offered while moving")

e=runtime(); e.units.party1.hp=55; e.units.player.mana=240
expect(e.pick(),nil,"noncritical heal must leave 15% recovery mana")
e.units.player.mana=250; expect(e.pick().slot,2,"exact reserve boundary allowed")
e.cost[e.names[e.UI.spells[2]]]=200; expect(e.pick().id,e.S.FLASH_HEAL,"live cost rejects direct heal but permits cheaper quick heal")
e.cost[e.names[e.UI.spells[1]]]=200; expect(e.pick().id,e.S.RENEW,"cheaper HoT remains a fallback")
e.cost[e.names[e.S.RENEW]]=200; expect(e.pick(),nil,"live rank/talent mana reserve applies to every heal")
e=runtime(); e.units.player.mana=199; e.units.party1.hp=35
expect(e.pick(),nil,"urgent heal must leave 10% recovery mana")
e.units.player.mana=200; expect(e.pick().slot,1,"urgent reserve boundary allowed")
e.GetSpellPowerCost=function() error("API unavailable") end
e.units.player.mana=249; expect(e.pick(),nil,"missing cost has a conservative fallback")
e.units.player.mana=250; expect(e.pick().slot,1,"urgent fallback boundary")
e=runtime(); e.cooldowns[e.UI.spells[1]]=true; e.units.party1.hp=35
expect(e.pick().slot,2,"cooldown rejects quick spell but allows direct alternative")
e.unusable[e.UI.spells[2]]=true; expect(e.pick().id,e.S.RENEW,"instant heal remains a fallback")
e.unusable[e.S.RENEW]=true; expect(e.pick(),nil,"unusable alternatives also rejected")

-- Input tracking: GUID-scoped instant grace, rank matching, failures and own auras.
e=runtime(); e.units.party1.hp=75; e.mouseover="party1"
e.G.NoteInput(e.S.RENEW); expect(e.cleared,1,"group input invalidates self-tuning evidence")
e.names[6074]=e.names[e.S.RENEW]
e.G.HandleCast("UNIT_SPELLCAST_SUCCEEDED","player","one",6074)
expect(e.G.IsOtherUnitCast(6074),true,"higher-rank group cast recognized")
e.NotePlayerSpellcastSucceeded(6074)
expect(e.StablePlayerBuff(e.S.RENEW),false,"group Renew cannot fabricate a self Renew buff")
expect(e.pick(),nil,"instant aura arrival grace prevents repeat request")
e.units.party1.guid="replacement"; expect(e.pick().id,e.S.RENEW,"roster replacement does not inherit old member aura grace")
e.units.party1.guid="one"; e.now=e.now+1.01
expect(e.pick().id,e.S.RENEW,"unobserved aura grace eventually expires")
e.G.NoteInput(e.S.RENEW); e.G.HandleCast("UNIT_SPELLCAST_FAILED","player","two",e.S.RENEW)
expect(e.G.IsOtherUnitCast(e.S.RENEW),false,"failed group attempt clears cast evidence")
e.mouseover=nil; local cleared=e.cleared; e.G.NoteInput(e.S.RENEW)
expect(e.cleared,cleared,"invalid mouseover does not clear tuning")
e.mouseover="party1"; e.casting=true; e.G.NoteInput(e.S.RENEW)
expect(e.cleared,cleared,"pressing during an existing cast does not replace attribution")

-- Full engine ordering and generic (non-identifying) telemetry-facing strings.
e=runtime(); e.units.party1.hp=35
e.PlayerLevel=function() return 30 end; e.SafeUnitLevel=e.PlayerLevel
e.TalentSpec=function() return 1 end
e.SafeUnitClassification=function() return "normal" end
e.CountActiveEnemies=function() return 0 end
e.ActiveTargetCast=function() return e.enemyCast end
e.InterruptRecommendation=function() return 999,"INTERRUPT","CTRL","stop cast" end
e.PanicRecommendation=function() return 998,"SELF EMERGENCY","SELF","survive" end
e.HCOneButton.Classes.PRIEST.GetRecommendation=function() return 997,"DAMAGE","MANUAL","normal" end
e.HCOneButton.Advisor.Engine.PrePullRecommendation=function() end
local id,title,key,reason,kind=e.Recommend()
expect(id,nil,"group heal never publishes a self-heal action ID")
expect(title,"GROUP HEAL","generic telemetry title")
expect(key,"GROUP MOUSEOVER","distinct input route")
expect(kind,"groupheal","distinct priority kind")
assert(not reason:find("Marco",1,true) and not reason:find("one",1,true),"identity leaked into telemetry reason")
expect(e.G.current.name,"Marco","live UI gets selected member")
e.casting=true; expect(e.Recommend(),nil,"cast suspends recommendations")
expect(e.G.current,nil,"cast cannot leave stale group UI state")
e.casting=false; e.units.party1.hp=100; expect(e.Recommend(),997,"healed party releases normal rotation")
e.units.party1.hp=35; e.combat=true; e.units.player.hp=10
expect(e.Recommend(),998,"own emergency preempts group healing")
e.units.player.hp=100; e.enemyCast={name="Fireball"}
expect(e.Recommend(),999,"interrupt preempts group healing")
e.enemyCast=nil; e.HCOneButton.UI.SurvivalStrip={ManualUsePending=function() return true end}
id,title=e.Recommend(); expect(title,"MANUAL PRIORITY","manual consumable handoff retains first priority")
expect(e.G.current,nil,"manual consumable clears group UI")

for _,class in ipairs({"WARRIOR","HUNTER","MAGE","WARLOCK","ROGUE"}) do
    e=runtime(class); expect(e.pick(),nil,class.." has no group-heal suggestions")
    for _,b in ipairs(e.UI.buttons) do expect(b.attrs.macrotext1,"/stopmacro",class.." has inert group bindings") end
end
print("Group healing / mouseover regression: PASS ("..checks.." checks)")
