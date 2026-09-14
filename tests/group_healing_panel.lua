-- Real panel/options/triage with guarded protected operations and fixed roster units.
local runtime=assert(loadfile("tests/group_healing.lua"))("fixture")
local checks=0
local function check(value,label) checks=checks+1; assert(value,label) end
local function setup(class,saved,solo,legacyMouse)
    local e=runtime(class)
    if solo then e.partyCount=0; e.units.party1=nil; e.units.party2=nil end
    e.HCOB_CharacterDB=saved or {}
    e.UISpecialFrames={}
    e.UpdateDisplay=function() e.updates=(e.updates or 0)+1 end
    e.print=function() end
    local widgets={}; local methods={}
    local overrides={}; local bindingOrder=0
    e.ClearOverrideBindings=function(frame)
        assert(not e.combat,"insecure binding cleanup in combat")
        overrides[frame]=nil
    end
    e.permanentBindings={BUTTON3="TOGGLEAUTORUN",BUTTON4="OLD_MOUSE4",BUTTON5="OLD_MOUSE5",["CTRL-BUTTON3"]="OLD_CTRL3"}
    e.macroInvocations={}
    -- Execute our actual snippets against a deliberately small restricted
    -- handle. This models override ownership, not the client's mouse routing.
    local function secureSnippet(frame,attribute)
        local body=frame.attrs[attribute]
        if not body then return end
        local handle={}
        function handle:ClearBindings() overrides[frame]=nil end
        function handle:SetBindingClick(priority,key,target,button)
            assert(priority==true and target==self,"hover binding must be owned by its clicked row")
            bindingOrder=bindingOrder+1
            overrides[frame]=overrides[frame] or {}
            overrides[frame][key]={owner=frame,target=frame,button=button,order=bindingOrder}
        end
        local chunk=assert(loadstring("return function(self)\n"..body.."\nend"))
        setfenv(chunk,{})
        chunk()(handle)
    end
    e.binding=function(key)
        local best
        for _,bindings in pairs(overrides) do
            local binding=bindings[key]
            if binding and (not best or binding.order>best.order) then best=binding end
        end
        return best or e.permanentBindings[key]
    end
    local function forbidPermanentBindings() error("panel must not change permanent bindings") end
    e.SetBinding=forbidPermanentBindings; e.SetBindingClick=forbidPermanentBindings; e.SaveBindings=forbidPermanentBindings
    local nativeMouseIndex={LeftButton=1,RightButton=2,MiddleButton=3,Button4=4,Button5=5}
    e.nativeSecureClick=function(row,button,down)
        -- Our explicit false attribute selects release independently of CVars.
        assert(row.attrs.useOnKeyDown==false and row.attrs.pressAndHoldAction==false)
        if down or not e.UnitExists(row.attrs.unit) then return end
        local suffix=nativeMouseIndex[button]
        local prefix=e.modifier or ""
        if suffix and row.attrs[prefix.."type"..suffix]=="macro" then
            e.macroInvocations[#e.macroInvocations+1]={row=row,text=row.attrs[prefix.."macrotext"..suffix]}
        end
    end
    local function widget(kind,name,parent,template)
        local w=setmetatable({kind=kind,name=name,parent=parent,template=template,attrs={},scripts={},events={},
            width=1920,height=1080,shown=true,points={}}, {__index=methods})
        w.protected=(template and template:find("Secure")) or (parent and parent.protected)
        if template and template:find("SecureActionButtonTemplate",1,true) then w.scripts.OnClick=e.nativeSecureClick end
        if template and template:find("SecureHandlerEnterLeaveTemplate",1,true) then
            w.scripts.OnEnter=function(self,motion)
                if motion then self.entered=true; secureSnippet(self,"_onenter") end
            end
            w.scripts.OnLeave=function(self,motion)
                if motion and self.entered then self.entered=nil; secureSnippet(self,"_onleave") end
            end
        end
        if template and template:find("SecureHandlerShowHideTemplate",1,true) then
            w.scripts.OnShow=function(self) secureSnippet(self,"_onshow") end
            w.scripts.OnHide=function(self) secureSnippet(self,"_onhide") end
        end
        widgets[#widgets+1]=w
        return w
    end
    local function visibleSnapshot()
        local before={}
        for _,w in ipairs(widgets) do before[w]=w:IsVisible() end
        return before
    end
    local function changedVisibility(before)
        for _,w in ipairs(widgets) do
            local visible=w:IsVisible()
            if before[w]~=visible then
                local script=w.scripts[visible and "OnShow" or "OnHide"]
                if script then script(w) end
            end
        end
    end
    local function safe(w) if w.protected then assert(not e.combat,"protected mutation in combat: "..tostring(w.name)) end end
    for _,name in ipairs({"SetFrameStrata","SetClampedToScreen","RegisterForDrag","SetJustifyH",
        "SetTextColor","SetStatusBarTexture","SetMinMaxValues","Raise","SetMovable","StartMoving","StopMovingOrSizing"}) do methods[name]=function() end end
    function methods:EnableMouse(enabled) safe(self); self.mouseEnabled=enabled end
    if not legacyMouse then
        function methods:SetPassThroughButtons(...) safe(self); self.passThrough={...} end
    end
    function methods:SetSize(w,h) safe(self); self.width,self.height=w,h end
    function methods:SetWidth(w) safe(self); self.width=w end
    function methods:SetHeight(h) safe(self); self.height=h end
    function methods:SetPoint(...) safe(self); self.points[#self.points+1]={...} end
    function methods:ClearAllPoints() safe(self); self.points={} end
    function methods:SetScale(v) safe(self); self.scale=v end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:GetEffectiveScale() return self.scale or 1 end
    function methods:SetAttribute(k,v) safe(self); self.attrs[k]=v end
    function methods:RegisterForClicks(...) self.clicks={...} end
    function methods:SetScript(event,fn) self.scripts[event]=fn end
    function methods:HookScript(event,fn)
        local original=self.scripts[event]
        self.scripts[event]=function(...) if original then original(...) end; fn(...) end
    end
    function methods:Click(button,down)
        if not self:IsVisible() then return end
        local edge=down and "Down" or "Up"
        local registered=false
        for _,value in ipairs(self.clicks or {}) do
            if value=="Any"..edge or value==button..edge then registered=true end
        end
        if not registered then return end
        for _,event in ipairs({"PreClick","OnClick","PostClick"}) do
            if self.scripts[event] then self.scripts[event](self,button,down) end
        end
    end
    function methods:RegisterEvent(event) self.events[event]=true end
    function methods:IsShown() return self.shown end
    function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function methods:Show() safe(self); local before=visibleSnapshot(); self.shown=true; changedVisibility(before) end
    function methods:Hide() safe(self); local before=visibleSnapshot(); self.shown=false; changedVisibility(before) end
    function methods:SetChecked(v) self.checked=v end
    function methods:GetChecked() return self.checked end
    function methods:SetText(v) self.text=v end
    function methods:SetValue(v) self.value=v end
    function methods:SetStatusBarColor(...) self.color={...} end
    function methods:SetColorTexture(...) self.color={...} end
    function methods:SetAllPoints() end
    function methods:CreateFontString() local w=widget("FontString",nil,self); w.protected=false; return w end
    function methods:CreateTexture() local w=widget("Texture",nil,self); w.protected=false; return w end
    e.CreateFrame=function(kind,name,parent,template)
        local w=widget(kind,name,parent,template)
        if template=="BasicFrameTemplateWithInset" then w.TitleText=w:CreateFontString() end
        if template=="InterfaceOptionsCheckButtonTemplate" then w.Text=w:CreateFontString() end
        return w
    end
    e.UIParent=widget("Frame","UIParent")
    e.SecureButton_GetModifierPrefix=function() return e.modifier or "" end
    e.cursorX,e.cursorY=0,0
    e.GetCursorPosition=function() return e.cursorX,e.cursorY end
    local drivers={}
    local function evaluate(expression)
        for clause in expression:gmatch("[^;]+") do
            local condition,action=clause:match("%[([^%]]+)%]%s*(%a+)")
            if not condition then return clause:match("%a+")=="show" end
            local valid=true; local unit
            for value in condition:gmatch("[^,]+") do
                if value:sub(1,1)=="@" then unit=value:sub(2)
                elseif value=="combat" then valid=valid and e.combat
                elseif value=="group:raid" then valid=valid and e.raid
                elseif value=="group:party" then valid=valid and (e.raid or e.partyCount>0)
                elseif value=="exists" then valid=valid and e.UnitExists(unit)
                else error("unsupported test condition: "..value) end
            end
            if valid then return action=="show" end
        end
        return false
    end
    e.drivers=function()
        local before=visibleSnapshot()
        for frame,expression in pairs(drivers) do frame.shown=evaluate(expression) end
        changedVisibility(before)
    end
    e.RegisterStateDriver=function(frame,attribute,expression)
        assert(not e.combat,"state driver changed in combat")
        assert(attribute=="visibility"); drivers[frame]=expression; e.drivers()
    end
    local function load(path) local f=assert(loadfile("HCOneButton/"..path)); setfenv(f,e); f() end
    load("UI/WindowManager.lua"); load("UI/GroupHealingPanel.lua"); load("UI/GroupHealingOptions.lua")
    e.P=e.HCOneButton.UI.GroupHealingPanel; e.O=e.HCOneButton.UI.GroupHealingOptions
    e.W=e.HCOneButton.UI.WindowManager
    e.UI.Configure()
    e.widgets=widgets
    e.enter=function(row) row.scripts.OnEnter(row,true) end
    e.leave=function(row) row.scripts.OnLeave(row,true) end
    e.key=function(key,down)
        local binding=e.binding(key)
        if type(binding)=="table" then binding.target:Click(binding.button,down) end
    end
    e.event=function(event)
        for _,w in ipairs(widgets) do if w.events[event] and w.scripts.OnEvent then w.scripts.OnEvent(w,event) end end
        e.drivers()
    end
    return e
end

for _,class in ipairs({"PRIEST","PALADIN","SHAMAN","DRUID"}) do
    local e=setup(class); local p=e.P
    check(p.frame and p.frame.parent==e.UIParent and p.frame.scale==1,class.." independent HUD anchor/scale")
    check(p.frame:IsVisible(),class.." visible with party")
    for unit,row in pairs(p.rows) do
        check(row.attrs.unit==unit,class.." fixed unit")
        check(row.mouseEnabled==true,class.." healing row explicitly receives mouse input")
        check(row.health.mouseEnabled==false,"visual health bar cannot intercept clicks")
        check(row.passThrough and #row.passThrough==0,"middle/side buttons stay on the healing row")
        check(row.scripts.OnClick==e.nativeSecureClick,"native secure click handler is not replaced")
        check(row.attrs.useOnKeyDown==false and row.attrs.pressAndHoldAction==false
            and row.clicks[1]=="AnyUp" and row.clicks[2]=="AnyDown","both input edges, one action on release")
        local macro=row.attrs.macrotext1
        check(macro:find("/cast [@"..unit..",help,nodead] ",1,true)~=nil,"fixed-unit native cast")
        check(not macro:find("mouseover",1,true) and not macro:find("/target",1,true),"no implicit/health targeting")
        check(not macro:find("Rank",1,true),"highest learned rank: no explicit rank")
        check(row.attrs["alt-ctrl-shift-macrotext1"]=="/stopmacro","combined modifiers inert")
    end
    check(not p.rows.party3:IsVisible(),"empty rows hidden")
    e.bindings={}; e.units.party1.hp=35
    local suggestion=e.pick()
    check(suggestion and suggestion.panel and suggestion.key=="Right click",class.." no keyboard bind needed")
    p.Refresh(); check(p.rows.party1.hint.text:find("Right click",1,true),"suggested row shows click")
    e.units.party1.guid="replacement"; p.Refresh()
    check(p.rows.party1.hint.text=="","stale GUID does not highlight replacement")
    e.HCOB_DB.groupHealing=false
    check(not e.pick() and p.frame:IsVisible() and p.actions["1"],"advice OFF preserves manual panel")
    p.Settings().enabled=false; p.Configure()
    check(not p.frame:IsVisible() and not p.ActionFor(e.UI.spells[1],"party1"),"disabled panel is not advertised")
    e.HCOB_DB.groupHealing=true
    check(not e.pick(),"no advice with no click or keyboard action")
end

-- Contract checks for our mouse setup and observer, not an emulation of WoW's
-- native hit-testing or secure spell execution. Exercise physical button names,
-- including MiddleButton, with each supported modifier and healer class.
for _,class in ipairs({"PRIEST","PALADIN","SHAMAN","DRUID"}) do
    local mouse=setup(class); local panel=mouse.P
    local calls={}
    mouse.G.NoteInput=function(id,unit) calls[#calls+1]={id=id,unit=unit} end
    for _,prefix in ipairs(panel.prefixes) do
        mouse.modifier=prefix
        for index,button in ipairs({"LeftButton","RightButton","MiddleButton","Button4","Button5"}) do
            check(panel.SetRole(prefix,index,1),class.." assign learned heal to "..prefix..button)
            for _,unit in ipairs({"player","party1"}) do
                local row=panel.rows[unit]
                check(row.attrs[prefix.."type"..index]=="macro"
                    and row.attrs[prefix.."macrotext"..index]==mouse.G.Macro(mouse.UI.spells[1],unit),
                    class.." click macro preserves assigned spell and fixed unit")
                local count=#calls
                row.scripts.PreClick(row,button,true)
                check(#calls==count,"press does not record a release-only action")
                row.scripts.PreClick(row,button,false)
                check(#calls==count+1 and calls[#calls].id==mouse.UI.spells[1] and calls[#calls].unit==unit,
                    class.." "..prefix..button.." records the clicked row once on release")
            end
        end
    end
    local older=setup(class,nil,true,true)
    check(older.P.frame:IsVisible() and older.P.rows.player.mouseEnabled==true
        and older.P.rows.player.health.mouseEnabled==false,"optional pass-through API is not required")
end

for _,class in ipairs({"PRIEST","PALADIN","SHAMAN","DRUID"}) do
    local solo=setup(class,nil,true); local panel=solo.P
    check(panel.frame:IsVisible() and panel.rows.player:IsVisible(),class.." solo login shows own real bar")
    check(panel.rows.player.name.text=="Player" and panel.rows.player.percent.text=="100%","solo name and health are real")
    for index=1,4 do check(not panel.rows["party"..index]:IsVisible(),"no fabricated solo party members") end
    check(panel.rows.player.attrs.macrotext1:find("/cast [@player,help,nodead] ",1,true),"solo click heals player at native rank")
    solo.units.player.hp=42; panel.Refresh()
    check(panel.rows.player.percent.text=="42%","solo health updates live")
    check(not solo.pick(),"solo panel does not create group recommendations")
    panel.Settings().enabled=false; panel.Configure()
    local reload=setup(class,solo.HCOB_CharacterDB,true)
    check(not reload.P.frame:IsVisible(),"explicit OFF survives solo reload")
end

local e=setup(); local p=e.P
-- Hover overrides: actual generated snippets and inherited hooks, with the
-- native binding/macro dispatch modeled at the boundary (no real spell cast).
for _,class in ipairs({"PRIEST","PALADIN","SHAMAN","DRUID"}) do
    local h=setup(class); local panel=h.P
    local player,party=panel.rows.player,panel.rows.party1
    check(h.binding("BUTTON3")=="TOGGLEAUTORUN",class.." no override before entering a row")
    check(not panel.header.attrs._onenter,"title does not reserve healing bindings")
    h.enter(player)
    check(#h.macroInvocations==0,"hovering never casts")
    for _,prefix in ipairs({"","shift-","ctrl-","alt-","alt-ctrl-","alt-shift-","ctrl-shift-","alt-ctrl-shift-"}) do
        h.modifier=prefix
        for index=3,5 do
            local key=prefix:upper().."BUTTON"..index
            local binding=h.binding(key)
            local button=index==3 and "MiddleButton" or "Button"..index
            check(type(binding)=="table" and binding.owner==player and binding.button==button,
                class.." "..key.." owned by hovered row")
            local before=#h.macroInvocations
            h.key(key,true)
            check(#h.macroInvocations==before,"key down cannot fire a release-only heal")
            h.key(key,false)
            check(#h.macroInvocations==before+1 and h.macroInvocations[#h.macroInvocations].text==player.attrs[prefix.."macrotext"..index],
                "key release selects the same configured macro exactly once")
        end
    end
    check(h.binding("BUTTON1")==nil and h.binding("BUTTON2")==nil,"left/right never overridden")
    check(h.binding("F6")==nil and h.binding("MOUSEWHEELUP")==nil,"keyboard and scrolling untouched")
    h.modifier=""; local before=#h.macroInvocations
    player:Click("LeftButton",true); player:Click("LeftButton",false)
    player:Click("RightButton",true); player:Click("RightButton",false)
    check(#h.macroInvocations==before+2,"direct left/right still invoke one macro each")
    -- Enter the new owner before a late leave from the previous row.
    h.enter(party); h.leave(player)
    check(h.binding("BUTTON3").owner==party,"late leave cannot clear another row's bindings")
    panel.SetRole("",3,1)
    check(h.binding("BUTTON3").owner==party,"out-of-combat rebuild retains current owner")
    before=#h.macroInvocations; h.key("BUTTON3",true); h.key("BUTTON3",false)
    check(#h.macroInvocations==before+1 and h.macroInvocations[#h.macroInvocations].text==h.G.Macro(h.UI.spells[1],"party1"),
        "temporary binding follows new spell assignment without changing target")
    panel.SetRole("",3,0); h.key("BUTTON3",false)
    check(h.macroInvocations[#h.macroInvocations].text=="/stopmacro","None cannot fall through to a permanent action")
    h.leave(party)
    check(h.binding("BUTTON3")=="TOGGLEAUTORUN" and h.binding("CTRL-BUTTON3")=="OLD_CTRL3","leaving restores existing game bindings")
    h.enter(player); player.scripts.OnLeave(player,false)
    check(h.binding("BUTTON3")=="TOGGLEAUTORUN","out-of-combat dialog overlap clears bindings without pointer motion")
    h.enter(player); panel.Settings().enabled=false; panel.Configure()
    check(h.binding("BUTTON3")=="TOGGLEAUTORUN","parent panel hide clears child-owned bindings")
    panel.Settings().enabled=true; panel.Configure()
    check(h.binding("BUTTON3")=="TOGGLEAUTORUN","show does not reactivate an old hover")
    h.enter(party); h.combat=true
    h.units.party1=nil; h.drivers()
    check(h.binding("BUTTON3")=="TOGGLEAUTORUN","secure roster hide clears bindings in combat")
    h.enter(player); h.key("BUTTON3",true); h.key("BUTTON3",false)
    check(h.binding("BUTTON3").owner==player,"hover/click binding works in combat without insecure mutation")
    h.leave(player)
    check(h.binding("BUTTON3")=="TOGGLEAUTORUN","combat leave cleans up only through the secure handler")
    h.enter(player)
    h.raid=true; h.drivers()
    check(h.binding("BUTTON3")=="TOGGLEAUTORUN","combat raid transition clears overrides through parent hide")
    h.combat=false; h.raid=false; panel.Configure(); h.enter(player)
    player:Hide(); player:Show()
    check(h.binding("BUTTON3")=="TOGGLEAUTORUN","explicit row hide/show cannot leave stale bindings")
    check(h.permanentBindings.BUTTON3=="TOGGLEAUTORUN" and h.permanentBindings.BUTTON4=="OLD_MOUSE4"
        and h.permanentBindings.BUTTON5=="OLD_MOUSE5","permanent bindings are unchanged")
end

check(p.SetRole("",1,3),"assign Renew to left click")
check(p.rows.party1.attrs.macrotext1:find("RENEW",1,true),"chosen heal is applied")
check(p.SetRole("",3,4),"assign Shield to middle click")
check(p.rows.party1.attrs.macrotext3:find("POWER_WORD_SHIELD",1,true),"middle shield")
check(p.SetRole("ctrl-",5,2),"modifier assignment")
check(p.rows.party1.attrs["ctrl-macrotext5"]:find("GREATER_HEAL",1,true),"Ctrl Mouse5 direct heal")
check(p.SetRole("",2,0) and p.rows.party1.attrs.macrotext2=="/stopmacro","None is inert")
check(not p.SetRole("wrong-",1,2) and not p.SetRole("",6,2) and not p.SetRole("",1,99),"invalid assignments rejected")
e.units.mouseover=e.units.party2
e.modifier=""; p.rows.party1.scripts.PreClick(p.rows.party1,"LeftButton",false)
check(e.G.IsOtherUnitCast(e.S.RENEW),"click records group intent")
e.G.HandleCast("UNIT_SPELLCAST_SUCCEEDED","player","cast",e.S.RENEW)
e.bindings={}; e.units.party1.hp=75; e.units.party2.hp=75
check(e.pick().unit=="party2","confirmation grace follows clicked bar, not mouseover")
e.known[e.S.RENEW]=false; e.UI.Configure()
check(p.rows.party1.attrs.macrotext1=="/stopmacro","unknown spell cannot cast")
e.known[e.S.RENEW]=true; e.names[e.S.RENEW]="Rénovation"; e.UI.Configure()
check(p.rows.party1.attrs.macrotext1:find("Rénovation",1,true),"localized rankless cast refresh")

p.Place(100,-80)
check(p.Settings().x==100 and p.Settings().y==-80,"independent position persisted")
e.cursorX,e.cursorY=20,30; p.header.scripts.OnDragStart()
e.cursorX,e.cursorY=50,90; p.frame.scripts.OnUpdate(p.frame,.1)
p.header.scripts.OnDragStop()
check(p.Settings().x==130 and p.Settings().y==-20,"header drag saves UIParent coordinates")
check(e.HCOB_DB.x==nil and e.HCOB_DB.scale==nil,"drag does not change main HUD saved fields")
p.Settings().locked=true; p.header.scripts.OnDragStart(); check(not p.drag,"position lock respected")
local restored=setup("PRIEST",e.HCOB_CharacterDB)
check(restored.P.Settings().x==130 and restored.P.Settings().y==-20,"position survives reload")
check(restored.P.Role("",1)==3 and restored.P.Role("ctrl-",5)==2,"clicks survive reload")
check(setup("PRIEST").P.Role("",1)==2,"another character has independent settings")
local corrupt=setup("PRIEST",{groupHealingPanel={enabled="bad",locked=1,x=0/0,y=math.huge,clicks={["1"]="bad",["2"]=-1,["3"]=0/0}}})
check(corrupt.P.Settings().enabled and not corrupt.P.Settings().locked,"malformed flags repaired")
check(corrupt.P.Settings().x==-310 and corrupt.P.Settings().y==0,"malformed position repaired")
check(corrupt.P.Role("",1)==2 and corrupt.P.Role("",2)==1,"malformed click assignments repaired")

e=setup("PRIEST",nil,true); p=e.P
check(p.frame:IsVisible(),"solo panel stays visible without preview")
local parent=e.CreateFrame("Frame","Options",e.UIParent)
e.W.Register("options",parent); e.W.Open("options")
check(e.O.Open() and e.O.frame:IsShown() and not parent:IsShown(),"Options child navigation")
local lastBottom=176
for _,row in ipairs(e.O.rows) do
    local point=row.points[1]
    local x,y=point[2],-point[3]
    check(x>=24 and x+row.width<=496 and y>=lastBottom+14 and y+row.height<397,"click assignment rows have clearance")
    lastBottom=y+row.height
end
check(e.O.frame.scripts.OnDragStart and e.O.frame.scripts.OnDragStop,"configuration can move aside for the panel preview")
e.O.preview.scripts.OnClick()
check(p.frame:IsVisible() and p.rows.party1:IsVisible(),"solo preview allows positioning")
e.O.rows[1].scripts.OnClick(); check(e.O.menu:IsShown(),"spell selection menu opens")
e.O.menu.entries[5].scripts.OnClick()
check(p.Role("",1)==3 and not e.O.menu:IsShown(),"Renew selected from spell menu")
e.O.tabs["alt-"].scripts.OnClick(); e.O.rows[3].scripts.OnClick(); e.O.menu.entries[6].scripts.OnClick()
check(p.Role("alt-",3)==4,"Alt middle shield via UI")
e.O.frame:Hide()
check(parent:IsShown() and not p.preview and p.frame:IsVisible() and p.rows.player:IsVisible()
    and not p.rows.party1:IsVisible(),"X/Escape ends empty-row preview but keeps real solo bar")
e.O.Open(); e.O.preview.scripts.OnClick()
local frozen=p.rows.party1.attrs.macrotext1
e.combat=true; e.drivers(); e.event("PLAYER_REGEN_DISABLED")
check(p.frame:IsVisible() and p.rows.player:IsVisible() and not p.rows.party1:IsVisible()
    and not e.O.frame:IsShown() and not parent:IsShown(),"combat preserves solo bar but closes dialog and empty preview rows")
check(not p.Configure() and p.pending,"combat rebuild deferred")
check(not p.SetRole("",1,4) and p.rows.party1.attrs.macrotext1==frozen,"combat assignments frozen")
check(not p.Place(0,0) and not p.Center() and not e.O.Open(),"protected position/configuration blocked")
e.partyCount=2
e.units.party1={hp=75,guid="one",name="Marco"}; e.units.party2={hp=80,guid="two",name="Lucia"}
e.drivers(); e.event("GROUP_ROSTER_UPDATE")
check(p.frame:IsVisible() and p.rows.party1:IsVisible() and p.rows.party2:IsVisible(),"party join during combat handled by secure driver")
e.units.party3={hp=40,guid="three",name="New member"}; e.partyCount=3; e.drivers(); p.Refresh()
check(p.rows.party3:IsVisible() and p.rows.party3.name.text=="New member","combat roster update uses fixed party units")
e.units.party3=nil; e.drivers(); p.Refresh(); check(not p.rows.party3:IsVisible(),"combat departure hides row securely")
e.partyCount=0; e.units.party1=nil; e.units.party2=nil; e.drivers(); e.event("GROUP_ROSTER_UPDATE")
check(p.frame:IsVisible() and p.rows.player:IsVisible() and not p.rows.party1:IsVisible(),"leaving party in combat keeps own bar")
e.raid=true; e.drivers(); check(not p.frame:IsVisible(),"party grid hidden in raid; keyboard advice remains available")
e.combat=false; e.raid=false; e.UI.Configure()
check(not p.pending and p.frame:IsVisible(),"deferred rebuild completed out of combat")
e.O.Open(); e.O.enabled:SetChecked(false); e.O.enabled.scripts.OnClick(e.O.enabled)
check(not p.frame:IsVisible() and not p.Settings().enabled,"panel visibility toggle persists")
e.O.locked:SetChecked(true); e.O.locked.scripts.OnClick(e.O.locked)
check(p.Settings().locked,"position lock option persists")
e.O.reset.scripts.OnClick(); check(p.Role("",1)==2 and p.Role("alt-",3)==0,"reset clicks preserves other preferences")
for _,class in ipairs({"WARRIOR","ROGUE","HUNTER","MAGE","WARLOCK"}) do
    local other=setup(class); check(not other.P.frame and not other.O.Open(),class.." no healer panel")
end
print("Party click-healing panel regression: PASS ("..checks.." checks)")
