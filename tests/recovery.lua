-- Real inventory, aura, secure strip and Advisor modules with simulated APIs.
-- No real item is consumed; secure execution is inspected, not bypassed.
local checks=0
local function expect(actual,wanted,label)
    checks=checks+1
    assert(actual==wanted,label..": expected "..tostring(wanted)..", got "..tostring(actual))
end
local function runtime(class)
    local e=setmetatable({}, {__index=_G}); e._G=e
    e.HCOneButton={Internal=e,Core={},Data={},UI={SurvivalStrip={}},Systems={Consumables={}},Advisor={Engine={}},Classes={}}
    e.HCOB_DB={visible=true,showAdvisor=true,secureActions=true,showConsumables=true,scale=1,prePullSafety=false}
    e.PLAYER_CLASS=class or "MAGE"; e.now=100; e.level=30; e.hp=50; e.mana=30; e.hpKnown=true; e.manaKnown=true
    e.counts={}; e.meta={}; e.cooldowns={}; e.auras={}; e.widgets={}; e.infoCalls=0; e.requests={}
    e.GetTime=function() return e.now end
    e.timers={}
    e.C_Timer={After=function(delay,callback) e.timers[#e.timers+1]={at=e.now+delay,callback=callback} end}
    e.advance=function(seconds)
        e.now=e.now+seconds
        local pending=e.timers; e.timers={}
        for _, timer in ipairs(pending) do
            if timer.at<=e.now then timer.callback() else e.timers[#e.timers+1]=timer end
        end
    end
    e.PlayerLevel=function() return e.level end
    e.UnitLevel=function() return e.level end
    e.UnitExists=function() return true end
    e.GetItemCount=function(id,bank,uses)
        assert(bank==false and uses==false,"bank contents / charges must not count")
        return e.counts[id] or 0
    end
    e.GetItemInfo=function(id)
        e.infoCalls=e.infoCalls+1
        if e.infoError then error("cache failure") end
        local m=e.meta[id]
        if not m then return end
        return m.name or ("Item "..id),nil,m.quality or 1,1,m.minimum,nil,nil,nil,nil,"icon",1,m.classID or 0,0,m.bindType or 0
    end
    e.C_Item={RequestLoadItemDataByID=function(id) e.requests[id]=(e.requests[id] or 0)+1 end}
    e.GetItemCooldown=function(id) local d=e.cooldowns[id] or 0; return d>0 and e.now or 0,d,1 end
    e.IsUsableItem=function(id) return e.unusable~=id end
    e.InCombatLockdown=function() return e.combat==true end
    e.UnitAffectingCombat=e.InCombatLockdown
    e.UnitIsDeadOrGhost=function() return e.dead end
    e.IsMounted=function() return e.mounted end
    e.IsFlying=function() return e.flying end
    e.GetUnitSpeed=function() return e.speed or 0 end
    e.GetShapeshiftForm=function() return e.form or 0 end
    e.UnitHealthPct=function(unit) if unit=="target" then return 100,true end; return e.hp,e.hpKnown end
    e.UnitPowerMax=function(_,power) assert(power==0,"query mana explicitly"); return e.PLAYER_CLASS=="WARRIOR" and 0 or 100 end
    e.UnitPowerPct=function(_,power) assert(power==0,"read mana explicitly"); return e.mana,e.manaKnown end
    e.UnitPowerType=function() return 0,"MANA" end
    e.UnitCastingInfo=function() if e.casting then return "Heal",nil,nil,e.now*1000,(e.now+2)*1000,false,1,false,2050 end end
    e.UnitChannelInfo=function() if e.channel then return "First Aid",nil,nil,e.now*1000,(e.now+8)*1000,false,false,3273 end end
    e.SpellName=function(id) if id==433 then return "Nourriture" elseif id==430 then return "Boisson" end end
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index) return e.auras[index] end}
    e.CanAccessTable=function(v) return type(v)=="table" end
    e.CanAccessValue=function(v) return v~=nil end
    e.SafeString=function(v,d) return type(v)=="string" and v or d end
    e.SafeNumber=function(v,d) return tonumber(v) or d end
    e.SafeBoolean=function(v,d) if v==nil then return d end; return v==true end
    e.Clamp=function(v,lo,hi) return math.max(lo,math.min(hi,v)) end
    e.HCOB_MakeRectBorder=function() end
    e.hcobUseKeyDown=true
    local methods={}
    local function widget(kind,name,parent)
        local w=setmetatable({kind=kind,name=name,parent=parent,scripts={},attrs={},points={},width=376,height=58,shown=true}, {__index=methods})
        e.widgets[#e.widgets+1]=w
        if name then e[name]=w end
        return w
    end
    for _, method in ipairs({"SetFrameStrata","EnableMouse","SetJustifyH","SetColorTexture","SetTextColor","SetVertexColor","SetBlendMode","SetDrawEdge","SetHideCountdownNumbers","RegisterEvent"}) do
        methods[method]=function() end
    end
    function methods:SetColorTexture(r,g,b,a) self.color={r,g,b,a} end
    function methods:SetSize(w,h) self.width,self.height=w,h end
    function methods:GetWidth() return self.width end
    function methods:SetWidth(w) self.width=w end
    function methods:SetPoint(...) self.points[#self.points+1]={...} end
    function methods:SetAllPoints() end
    function methods:SetAttribute(k,v)
        assert(not e.combat,"secure attribute changed in combat")
        self.attrs[k]=v; self.writes=(self.writes or 0)+1
    end
    function methods:RegisterForClicks(...) self.clicks={...} end
    function methods:SetScript(k,v) self.scripts[k]=v end
    function methods:SetTexture(v) self.texture=v end
    function methods:SetAlpha(v) self.alpha=v end
    function methods:SetDesaturated(v) self.desaturated=v end
    function methods:SetText(v) self.text=v end
    function methods:SetScale(v) assert(not e.combat,"scale changed in combat"); self.scale=v end
    function methods:SetCooldown(start,duration) self.cooldown={start,duration} end
    function methods:Show() self.shown=true end
    function methods:Hide() self.shown=false end
    function methods:IsShown() return self.shown end
    function methods:CreateTexture() return widget("Texture",nil,self) end
    function methods:CreateFontString() return widget("FontString",nil,self) end
    e.CreateFrame=widget
    e.UIParent=widget("Frame")
    e.HCOB_CoreShell=widget("Frame")
    e.HCOneButton.UI.ActionPanel={frame=widget("Frame"),idToSlot={[123]=1,[456]=2}}
    e.advisor=widget("Frame")
    e.SetDisplay=function(id,title,key,reason,kind)
        e.display={id=id,title=title,key=key,reason=reason,kind=kind}
        e.UpdateDiagnosticPixel(id)
    end
    e.HCOneButton.Systems.ProfessionCoach={Reanchor=function() e.reanchors=(e.reanchors or 0)+1 end}
    for _, path in ipairs({"Core/Auras.lua","Systems/Consumables.lua","Systems/Recovery.lua","UI/SurvivalStrip.lua","Advisor/Engine.lua","UI/DiagnosticPixel.lua"}) do
        local chunk=assert(loadfile("HCOneButton/"..path)); setfenv(chunk,e); chunk()
    end
    e.C=e.HCOneButton.Systems.Consumables; e.R=e.HCOneButton.Systems.Recovery; e.strip=e.HCOneButton.UI.SurvivalStrip
    for _, w in ipairs(e.widgets) do if w.scripts.OnEvent then e.events=w end end
    e.add=function(id,count,minimum) e.counts[id]=count; e.meta[id]={minimum=minimum or 0} end
    e.eat=function(food,drink)
        e.auras={}
        if food then e.auras[#e.auras+1]={name="Nourriture",duration=30,expirationTime=e.now+20} end
        if drink then e.auras[#e.auras+1]={name="Boisson",duration=30,expirationTime=e.now+20} end
    end
    e.click=function(role)
        local b=e.strip.roleToButton[role]
        b.scripts.PreClick(b,"LeftButton",false)
        return b.attrs.macrotext1
    end
    e.configure=function() e.strip.Configure() end
    return e
end

local e=runtime()
expect(#e.C.roleOrder,6,"six roles")
expect(table.concat(e.C.roleOrder,","),"healingPotion,healthstone,manaPotion,bandage,food,drink","existing order preserved")
e.add(117,4,0); e.add(3770,2,15); e.add(8952,9,45); e.add(1205,3,15)
e.configure()
expect(e.C.GetRole("food").id,3770,"highest usable food tier")
expect(e.C.GetRole("drink").id,1205,"water selected")
expect(e.strip.roleToButton.food.countText.text,"2","quantity is visible")
e.add(1114,1,15); e.configure()
expect(e.C.GetRole("food").id,1114,"conjured food wins equal tier")
e.add(3771,1,25); e.configure()
expect(e.C.GetRole("food").id,3771,"stronger real food beats weaker conjured food")
e.add(3772,8,25); e.add(1708,3,25); e.configure()
expect(e.C.GetRole("drink").id,3772,"conjured water at equal tier")
e.level=60; e.add(22895,5,55); e.add(8079,6,55); e.configure()
expect(e.C.GetRole("food").id,22895,"top Classic conjured food")
expect(e.C.GetRole("drink").id,8079,"top Classic conjured water")
for _, role in ipairs({"food","drink"}) do
    local seen={}
    for _, entry in ipairs(e.R.catalog[role]) do
        assert(not seen[entry.id],"duplicate catalogue ID"); seen[entry.id]=true
        assert(entry.level>=0 and entry.level<=55 and entry.rank>=1 and entry.rank<=7,"invalid tier")
    end
end
e=runtime(); e.add(117,4,0); e.add(3770,2,31); e.configure()
expect(e.C.GetRole("food").id,117,"live item requirement overrides catalogue")
e.meta[3770]=nil; e.configure(); e.configure()
expect(e.C.GetRole("food").id,117,"uncached food not assigned")
expect(e.requests[3770],1,"missing item data requested once")
e.meta[3770]={minimum=15}; e.events.scripts.OnEvent(nil,"GET_ITEM_INFO_RECEIVED")
expect(e.C.GetRole("food").id,3770,"item cache event upgrades selection")
e=runtime(); e.add(5472,8,0); e.add(769,9,0); e.add(19301,2,0); e.configure()
expect(e.C.GetRole("food").id,nil,"buff food, raw reagents and PvP-only food not selected")
e.add(117,2); e.meta[117].bindType=4; e.configure()
expect(e.C.GetRole("food").id,nil,"quest-bound item excluded")
e.meta[117].bindType=0; e.infoError=true; e.configure()
expect(e.C.GetRole("food").id,nil,"failed item cache does not create assignment")

for _, class in ipairs({"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","MAGE","WARLOCK","DRUID","SHAMAN"}) do
    e=runtime(class); e.add(117,3); e.add(159,4); e.configure()
    local manaUser=class~="ROGUE" and class~="WARRIOR"
    expect(e.R.UsesMana(),manaUser,class.." mana policy")
    expect(e.C.GetRole("drink").available,manaUser,class.." drink availability")
    expect(e.strip.frame.width,376,"strip width preserved")
    expect(e.strip.frame.height,58,"strip height preserved")
    local lastRight=0
    for _, b in ipairs(e.strip.buttons) do
        local anchor=b.points[1]; local x=anchor[4]
        assert(x>=lastRight+8 and x+b.width<=366,"buttons overlap or escape strip")
        lastRight=x+b.width
    end
    expect(e.strip.roleToButton.healingPotion.name,"HCOneButtonSurvival1","old button name retained")
    expect(e.strip.roleToButton.bandage.name,"HCOneButtonSurvival4","old bandage name retained")
    expect(e.strip.roleToButton.food.clicks[1],"LeftButtonUp","recovery uses one release edge")
    expect(e.strip.roleToButton.food.attrs.useOnKeyDown,false,"no double-edge food use")
    e.strip.ApplyScale(1.4); expect(e.strip.roleToButton.drink.scale,1.4,"shared HUD scale")
    e.HCOB_DB.showConsumables=false; e.strip.SyncVisibility()
    expect(e.strip.roleToButton.food.shown,false,"existing visibility preference applies")
    expect(e.strip.frame.shown,false,"frame hidden with strip")
    e.HCOB_DB.showConsumables=true; e.strip.SyncVisibility()
    expect(e.strip.roleToButton.food.shown,true,"show restores recovery buttons")
end

e=runtime(); e.add(117,3); e.add(159,4); e.add(1251,2); e.add(118,2); e.configure()
expect(e.C.RecommendForState(50,false),"food","plain food before out-of-combat bandage/potion")
e.hp=100
expect(e.C.RecommendForState(100,false),"drink","low mana water highlight")
expect(e.R.CanUse("food",e.C.GetRole("food")),false,"full health does not consume food")
e.hp=50; e.eat(true,false)
expect(e.R.State().hold,true,"active eating pauses pull")
expect(e.C.RecommendForState(50,false),"drink","can add water while eating")
expect(e.click("food"),"/stopmacro","active food cannot be restarted by click")
assert(e.click("drink"):find("/use item:159",1,true),"water can start alongside food")
e.eat(true,true)
expect(e.C.RecommendForState(50,false),nil,"no replacement consumable while both recoveries are active")
e.strip.UpdateStates()
expect(e.strip.status.text,"EAT + DRINK","combined status")
expect(e.strip.roleToButton.food.cdText.text,"EAT","food-active cue")
expect(e.strip.roleToButton.drink.cdText.text,"DRNK","drink-active cue")
e.hp=100; e.mana=100
expect(e.R.State().hold,false,"full resources release pull without waiting for aura expiry")
e.eat(false,false); expect(e.R.State().hold,false,"standing up clears recovery")
e.auras={{name="Well Fed",duration=900,expirationTime=e.now+800}}; e.hp=50
expect(e.R.State().hold,false,"Well Fed never pauses combat")
e.auras={}; e.mana=30; e.now=e.now+2
local macro=e.click("food")
assert(macro:find("[combat]",1,true) and macro:find("/use item:117",1,true),"native combat guard missing")
expect(e.R.State().hold,false,"a click alone is not evidence of eating")
expect(e.click("food"),"/stopmacro","double click guarded before aura arrives")
e.now=e.now+1; assert(e.click("food"):find("/use item:117",1,true),"failed attempt cannot lock button indefinitely")
e.combat=true; e.eat(true,true)
local frozen=e.strip.roleToButton.food.attrs.macrotext1
e.events.scripts.OnEvent(nil,"PLAYER_REGEN_DISABLED")
e.click("food")
expect(e.strip.roleToButton.food.attrs.macrotext1,frozen,"secure assignment never changed in combat")
expect(e.R.State().hold,false,"stale food aura cannot hide combat")
expect(e.C.RecommendForState(30,true),"healingPotion","combat still selects emergency potion")
e.counts[117]=0; e.add(3770,8,15); e.events.scripts.OnEvent(nil,"BAG_UPDATE_DELAYED")
expect(e.strip.roleToButton.food.assignedItemID,117,"combat freezes item ID")
expect(e.strip.roleToButton.food.countText.text,"0","combat quantity follows assigned item")
expect(e.strip.pendingConfigure,true,"bag changes deferred")
e.combat=false; e.eat(false,false); e.events.scripts.OnEvent(nil,"PLAYER_REGEN_ENABLED")
expect(e.strip.roleToButton.food.assignedItemID,3770,"new item assigned after combat")
expect(e.strip.pendingConfigure,false,"deferred assignment resolved")
e.counts[3770]=0; e.configure()
expect(e.strip.roleToButton.food.assignedItemID,nil,"empty bag clears old item")
expect(e.click("food"),"/stopmacro","no stale item-use macro")

for _, property in ipairs({"combat","dead","mounted","flying","casting","channel"}) do
    e=runtime(); e.add(117,3); e.add(159,3); e.configure(); e[property]=true
    expect(e.R.CanUse("food",e.C.GetRole("food")),false,"food blocked: "..property)
    expect(e.R.CanUse("drink",e.C.GetRole("drink")),false,"water blocked: "..property)
    if property=="casting" or property=="channel" then
        assert(e.click("food"):find("/stopcasting",1,true),"explicit rest click can interrupt "..property)
    elseif not e.combat then expect(e.click("food"),"/stopmacro","click blocked: "..property) end
end
e=runtime("DRUID"); e.add(159,4); e.configure(); e.form=1
expect(e.R.UsesMana(),true,"Druid hidden mana retained")
local usable,reason=e.R.CanUse("drink",e.C.GetRole("drink"))
expect(usable,false,"Druid must leave form manually"); expect(reason,"SHIFT OUT","Druid form guidance")
e.form=0; e.speed=7; expect(e.click("drink"),"/stopmacro","moving prevents recovery")
e.speed=0; e.manaKnown=false; expect(e.click("drink"),"/stopmacro","unknown mana does not consume water")
e.manaKnown=true; e.unusable=159; expect(e.click("drink"),"/stopmacro","client usability respected")
e.unusable=nil; e.cooldowns[159]=5; expect(e.click("drink"),"/stopmacro","cooldown respected")
e=runtime(); e.add(117,3); e.configure(); local before=e.infoCalls
for _, event in ipairs({"UNIT_AURA","UNIT_HEALTH","UNIT_POWER_UPDATE","PLAYER_STARTED_MOVING","BAG_UPDATE_COOLDOWN"}) do
    e.events.scripts.OnEvent(nil,event,"player")
end
expect(e.infoCalls,before,"visual events must not rescan inventory/cache")
e=runtime(); e.add(117,3); e.add(159,3); e.configure()
expect(e.C.HasHealingStock(),false,"food is not emergency healing stock")
local stocked=e.C.HealingCooldownState(); expect(stocked,false,"food does not satisfy tough-pull emergency readiness")
e.hp=50; e.eat(true,false); e.HostileLiveTarget=function() return true end
e.CountActiveEnemies=function() return 0 end
local id,title,key,_,kind=e.Recommend()
expect(id,nil,"recovery exposes no spell action")
expect(title,"EATING","Advisor shows current recovery")
expect(key,"LET IT FINISH","Advisor does not prompt a pull")
expect(kind,"caution","recovery hold is immediate")
e.HCOneButton.Advisor.Engine.kindPriority={action=40,caution=70}
e.HCOneButton.Advisor.Engine.Stabilize(123,"OPENER","PRESS BASE","", "action")
e.CooldownReady=function() return true end; e.IsKnown=function() return true end; e.IsUsable=function() return true end
e.HCOneButton.Advisor.Engine.IsRangedHostileSpell=function() return false end
id,title=e.HCOneButton.Advisor.Engine.Stabilize(e.Recommend())
expect(id,nil,"active recovery clears a previously displayed opener immediately")
expect(title,"EATING","stabilized recovery title")
e.C_UnitAuras=nil
e.UnitAura=function(_,index) if index==1 then return "Nourriture",nil,nil,nil,30,e.now+20,"player" end end
expect(e.R.State().food,true,"legacy localized aura fallback")
e=runtime(); e.level=12; e.add(117,3,1); e.add(2685,4,10); e.add(3770,2,15); e.configure()
expect(e.C.GetRole("food").id,2685,"cooked tier-3 food is usable before vendor tier-3 food")
e.hp=85; expect(e.C.RecommendForState(85,false),"food","85% boundary still saves potions")
e.hp=-1; expect(e.click("food"),"/stopmacro","invalid health fails closed")
e.hp=50; e.meta[2685].minimum=-1; e.configure()
expect(e.C.GetRole("food").id,117,"invalid use requirement is rejected")
e=runtime(); e.add(117,3); e.configure(); e.hp=100; e.eat(true,false)
e.HostileLiveTarget=function() return false end; e.CountActiveEnemies=function() return 0 end
e.SafeUnitLevel=function() return 30 end; e.SafeUnitClassification=function() return "normal" end
e.TalentSpec=function() return 1 end
e.HCOneButton.Classes.MAGE={GetRecommendation=function() return 123,"NEXT ACTION","MANUAL","test" end}
id,title=e.Recommend()
expect(id,123,"full HP releases Advisor even if food aura persists")
e.hp=50; e.eat(false,false); id,title=e.Recommend()
expect(id,123,"interrupted food immediately restores normal Advisor policy")
e.eat(true,true); e.combat=true; e.hp=10
e.PanicRecommendation=function() return 999,"ESCAPE","MANUAL","emergency" end
id,title=e.Recommend()
expect(id,999,"combat emergency overrides stale food/drink auras")
expect(title,"ESCAPE","panic guidance preserved")
e=runtime(); e.add(117,3)
e.C_Item.GetItemInfo=e.GetItemInfo; e.GetItemInfo=nil
assert(e.R.FindBest("food").id==117,"namespaced item metadata API fallback")

-- Manual survival precedence: exercise real strip/Advisor/pixel code together.
local function ready(class)
    local state=runtime(class)
    state.add(118,3); state.add(5512,3); state.add(2455,3); state.add(1251,3)
    state.add(117,3); state.add(159,3); state.configure()
    state.HostileLiveTarget=function() return false end
    state.CountActiveEnemies=function() return 0 end
    state.SafeUnitLevel=function() return 30 end
    state.SafeUnitClassification=function() return "normal" end
    state.TalentSpec=function() return 1 end
    state.HCOneButton.Classes[state.PLAYER_CLASS]={GetRecommendation=function() return 123,"NEW ACTION","MANUAL","test" end}
    state.HCOneButton.Advisor.Engine.kindPriority={action=40,caution=70,danger=100}
    state.PanicRecommendation=function() return 456,"PANIC","MANUAL","test" end
    state.CooldownReady=function() return true end
    state.IsKnown=function() return true end
    state.IsUsable=function() return true end
    state.HCOneButton.Advisor.Engine.IsRangedHostileSpell=function() return false end
    return state
end
for _, class in ipairs({"WARRIOR","HUNTER","MAGE","WARLOCK","PRIEST","ROGUE","PALADIN","SHAMAN","DRUID"}) do
    e=ready(class)
    for _, role in ipairs({"healingPotion","healthstone","manaPotion","bandage"}) do
        local b=e.strip.roleToButton[role]
        expect(b.clicks[1],"LeftButtonUp",class.." one physical click edge for "..role)
        expect(#b.clicks,1,"no second edge")
        expect(b.attrs.useOnKeyDown,false,"key-down preference cannot double-cancel")
        expect(b.attrs.type1,"macro","native macro action")
        expect(b.attrs.item1,nil,"old item attribute removed")
        local macro=b.attrs.macrotext1
        assert(macro:find("/cancelqueuedspell\n/stopcasting\n",1,true)==1,"queue must be cleared before the cast")
        assert(macro:find("/use [@player] item:"..b.assignedItemID,1,true),"survival consumable uses self without changing target")
        expect(macro:find("/stopattack",1,true)~=nil,role=="bandage","only bandage stops melee auto-attack")
        assert(#macro<=255,"secure macro length")
        e.combat=true
        local writes=b.writes
        local frozen=b.attrs.macrotext1
        e.UpdateDiagnosticPixel(123)
        e.click(role)
        expect(e.strip.ManualUsePending(),true,class.." handoff starts")
        expect(e.diagPixelTex.color[1],0,"output cleared synchronously before native action")
        expect(e.display.id,nil,"HUD action cleared synchronously")
        expect(e.display.title,"MANUAL PRIORITY","visible manual handoff")
        expect(b.writes,writes,"no protected writes in combat")
        expect(b.attrs.macrotext1,frozen,"frozen macro preserved")
        e.UpdateDiagnosticPixel(456)
        expect(e.diagPixelTex.color[1],0,"even a direct output update is suppressed")
        e.hp=10
        local id,title=e.Recommend()
        expect(id,nil,"manual handoff precedes panic recommendation")
        expect(title,"MANUAL PRIORITY","handoff visible during danger")
        e.advance(.41)
        expect(e.strip.ManualUsePending(),false,"failed/instant attempt cannot latch")
        id,title=e.Recommend()
        expect(id,456,"fresh panic recommendation resumes")
        e.hp=50; e.combat=false
    end
end

e=ready()
e.UpdateDiagnosticPixel(123); e.AcknowledgeDiagnosticPixelCast(123)
e.click("healingPotion")
e.UpdateDiagnosticPixel(456)
e.advance(.07)
expect(e.diagPixelTex.color[1],0,"old ACK timer cannot reopen output during handoff")
e.advance(.4)
expect(e.diagPixelTex.color[1],0,"handoff timeout never replays discarded suggestion")
e.UpdateDiagnosticPixel(e.Recommend())
expect(e.diagPixelTex.color[1],12/255,"only fresh decision releases output")

e=ready()
e.HCOneButton.Advisor.Engine.Stabilize(456,"PANIC","MANUAL","test","danger")
e.UpdateDiagnosticPixel(123); e.AcknowledgeDiagnosticPixelCast(123)
e.click("bandage"); e.UpdateDiagnosticPixel(456)
expect(e.HCOneButton.Advisor.Engine.displayState,nil,"manual input discards old stabilized danger")
e.advance(.6)
expect(e.diagPixelTex.color[1],0,"late ACK callback cannot replay an obsolete decision after handoff")
e.channel=true
local resumedID,resumedTitle=e.HCOneButton.Advisor.Engine.Stabilize(e.Recommend())
expect(resumedID,nil,"new channel replaces old stabilized danger")
expect(resumedTitle,"CHANNEL ACTIVE","live channel state wins after handoff")
e.channel=false
e.UpdateDiagnosticPixel(e.Recommend())
expect(e.diagPixelTex.color[1],12/255,"channel interruption restores fresh output")

e=ready()
local b=e.strip.roleToButton.healingPotion
b.scripts.PreClick(b,"LeftButton",true)
expect(e.strip.ManualUsePending(),false,"down edge ignored")
b.scripts.PreClick(b,"RightButton",false)
expect(e.strip.ManualUsePending(),false,"right click ignored")
e.counts[118]=0; e.configure(); e.click("healingPotion")
expect(e.strip.ManualUsePending(),false,"empty unassigned button ignored")
e=ready(); e.cooldowns[118]=120; e.click("healingPotion"); e.advance(.41)
expect(e.strip.ManualUsePending(),false,"cooldown failure cannot leave output locked")
e=ready(); e.click("healingPotion"); e.advance(.3); e.click("healthstone"); e.advance(.2)
expect(e.strip.ManualUsePending(),true,"a second deliberate click gets its own handoff")
e.advance(.21); expect(e.strip.ManualUsePending(),false,"second handoff expires")

for _, field in ipairs({"channel","casting"}) do
    e=ready(); e[field]=true; e.click("bandage")
    e.advance(.41)
    local id,title=e.Recommend()
    expect(id,nil,"active "..field.." holds beyond the click window")
    assert(title=="CHANNEL ACTIVE" or title=="CAST ACTIVE","real cast/channel owns ongoing hold")
    e.advance(5); expect(e.Recommend(),nil,"long action still protected")
    e[field]=false
    expect(e.Recommend(),123,"actual action end resumes a fresh decision")
end
for _, role in ipairs({"food","drink"}) do
    e=ready(); e.casting=true
    local macro=e.click(role)
    assert(macro:find("/stopmacro [combat][mounted][flying]\n/cancelqueuedspell\n/stopcasting\n/stopattack\n/use item:",1,true)==1,
        "rest guards must precede all cancellation commands")
    expect(e.strip.ManualUsePending(),true,"explicit rest click starts handoff")
    e.casting=false; e.eat(role=="food",role=="drink"); e.advance(.41)
    expect(e.Recommend(),nil,"real recovery aura owns longer hold")
    e.eat(false,false); expect(e.Recommend(),123,"interrupted recovery releases hold")
    e=ready(); e.combat=true; e.click(role)
    expect(e.strip.ManualUsePending(),false,"combat-rejected rest click cannot hide danger")
    e=ready(); e.hp=100; e.mana=100; e.click(role)
    expect(e.strip.ManualUsePending(),false,"full resources do not trigger a handoff")
end

e=ready(); e.GetNetStats=function() return 0,0,25,400 end
e.click("healingPotion"); e.advance(.5)
expect(e.strip.ManualUsePending(),true,"world latency extends handoff")
e.advance(.41); expect(e.strip.ManualUsePending(),false,"latency handoff remains bounded")
for _, invalid in ipairs({-1,math.huge,0/0,"invalid"}) do
    e=ready(); e.GetNetStats=function() return 0,0,25,invalid end
    e.click("healingPotion"); e.advance(.41)
    expect(e.strip.ManualUsePending(),false,"invalid latency uses finite fallback")
end
e=ready(); e.GetNetStats=function() error("unavailable") end
e.click("healingPotion"); e.advance(.41)
expect(e.strip.ManualUsePending(),false,"latency API failure cannot latch")
e=ready(); e.GetNetStats=function() return 0,0,25,100000 end
e.click("healingPotion"); e.advance(1.51)
expect(e.strip.ManualUsePending(),false,"excessive latency cannot suppress indefinitely")
print("Between-pull recovery regression: PASS ("..checks.." checks)")
