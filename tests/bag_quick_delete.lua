-- Real modules, simulated WoW APIs only. Never touches a live inventory.
local checks = 0
local function check(value, label) checks=checks+1; assert(value, label) end
local function runtime(legacy)
    local e = setmetatable({}, {__index=_G})
    e._G=e; e.HCOB_DB={bagQuickDelete=true}
    e.HCOneButton={Internal=e,Systems={},UI={}}
    e.items={}; e.deleted=0; e.pickups=0; e.normalClicks=0
    e.ctrl=true; e.alt=true; e.messages={}
    e.print=function(v) e.messages[#e.messages+1]=v end
    e.InCombatLockdown=function() return e.combat end
    e.UnitAffectingCombat=function() return e.combat end
    e.UnitIsDeadOrGhost=function() return e.dead end
    e.SpellIsTargeting=function() return e.targeting end
    e.IsControlKeyDown=function() return e.ctrl end
    e.IsAltKeyDown=function() return e.alt end
    e.IsShiftKeyDown=function() return e.shift end
    e.GetCursorInfo=function() if e.cursor then return unpack(e.cursor) end end
    local function info(bag,slot)
        if e.infoError then error("uncached") end
        local v=e.items[bag..":"..slot]
        if not legacy then return v end
        if v then return 1,v.stackCount,v.isLocked,v.quality,false,v.hasLoot,v.hyperlink end
    end
    local function pickup(bag,slot)
        e.pickups=e.pickups+1
        if e.pickupError then error("blocked") end
        if e.pickupNoop then return end
        local v=e.items[bag..":"..slot]
        e.cursor={"item",v.itemID,v.hyperlink}
        if e.wrongPickup then e.cursor[2]=999; e.cursor[3]="item:999:0" end
        e.items[bag..":"..slot]=nil
    end
    local api={GetContainerNumSlots=function() return 20 end,GetContainerItemInfo=info,
        GetContainerItemQuestInfo=function()
            if legacy then return e.quest==true,e.questID end
            return {isQuestItem=e.quest==true,questID=e.questID}
        end,PickupContainerItem=pickup}
    if legacy then for k,v in pairs(api) do e[k]=v end else e.C_Container=api end
    e.GetItemInfo=function(link)
        if e.uncached then return end
        for _, v in pairs(e.items) do
            if v.hyperlink==link then return "Test item",link,v.quality,1,1,"Trade goods","Other",20,"",1,1,e.classID or 7,0,e.bindType or 0 end
        end
    end
    e.DeleteCursorItem=function()
        if e.deleteError then error("protected") end
        e.deleted=e.deleted+1; e.cursor=nil
    end
    e.StaticPopupDialogs={}
    e.StaticPopup_Show=function(which,link,count,data)
        if e.popupUnavailable then return end
        e.popup={which=which,link=link,count=count,data=data}
        return e.popup
    end
    e.StaticPopup_Hide=function(which)
        if e.popup and e.popup.which==which then
            e.StaticPopupDialogs[which].OnHide(); e.popup=nil
        end
    end
    local methods={}
    local function widget(kind,name,parent)
        local w=setmetatable({kind=kind,name=name,parent=parent,scripts={},shown=true,id=1,x=80,y=90,width=32,height=32,scale=1}, {__index=methods})
        e.widgets[#e.widgets+1]=w; if name then e[name]=w end
        return w
    end
    e.widgets={}
    function methods:SetScript(k,v) self.scripts[k]=v end
    function methods:RegisterEvent() end
    function methods:GetName() return self.name end
    function methods:GetParent() return self.parent end
    function methods:GetID() return self.id end
    function methods:Hide() self.shown=false end
    function methods:Show() self.shown=true end
    function methods:IsVisible() return self.shown end
    function methods:GetRect() return self.x,self.y,self.width,self.height end
    function methods:GetEffectiveScale() return self.scale end
    function methods:GetFrameStrata() return "HIGH" end
    function methods:GetFrameLevel() return 10 end
    function methods:SetFrameStrata(v) self.strata=v end
    function methods:SetFrameLevel(v) self.level=v end
    function methods:ClearAllPoints() end
    function methods:SetPoint(...) self.point={...} end
    function methods:SetSize(w,h) self.width,self.height=w,h end
    function methods:SetPassThroughButtons(...)
        if e.passError then error("API unavailable") end
        self.pass={...}
    end
    function methods:RegisterForClicks(...) self.clicks={...} end
    function methods:SetAllPoints() end
    function methods:SetColorTexture() end
    function methods:SetText(v) self.text=v end
    function methods:CreateTexture() return widget("Texture",nil,self) end
    function methods:CreateFontString() return widget("FontString",nil,self) end
    e.CreateFrame=widget
    e.UIParent=widget("Frame","UIParent")
    e.GetMouseFoci=function() return {e.focus} end
    e.MouseIsOver=function(w) return e.hover==w end
    local parent=widget("Frame","ContainerFrame1"); parent.id=0
    e.standard=widget("Button","ContainerFrame1Item20",parent)
    e.standard.scripts.OnClick=function() e.normalClicks=e.normalClicks+1 end
    e.focus=e.standard; e.hover=e.standard
    local root=widget("Frame","ElvUI_ContainerFrame")
    root.Bags={[0]={}}
    e.elv=widget("Button","ElvUI_ContainerFrameBag0Slot1",root)
    e.elv.bagFrame=root; e.elv.BagID=0; e.elv.SlotID=1; root.Bags[0][1]=e.elv
    for _, path in ipairs({"Systems/BagQuickDelete.lua","UI/BagQuickDelete.lua"}) do
        local chunk=assert(loadfile("HCOneButton/"..path)); setfenv(chunk,e); chunk()
    end
    e.q=e.HCOneButton.Systems.BagQuickDelete; e.ui=e.HCOneButton.UI.BagQuickDelete
    for _, w in ipairs(e.widgets) do if w.scripts.OnEvent then e.controller=w end end
    e.add=function(quality,count,id)
        id=id or 123
        e.items["0:1"]={stackCount=count or 3,quality=quality or 0,itemID=id,isLocked=false,hasLoot=false,hyperlink="|Hitem:"..id..":0|h[Test]|h"}
    end
    e.sync=function()
        e.ui.Sync()
        for _, w in ipairs(e.widgets) do if w.pass then e.overlay=w end end
    end
    e.click=function()
        e.sync(); check(e.overlay and e.overlay.shown,"overlay not armed")
        e.overlay.scripts.OnMouseDown(e.overlay,"RightButton")
        e.overlay.scripts.OnClick(e.overlay,"RightButton")
    end
    e.accept=function()
        local p=assert(e.popup)
        e.StaticPopupDialogs[p.which].OnAccept(nil,p.data)
    end
    return e
end

for _, legacy in ipairs({false,true}) do
    local e=runtime(legacy); e.add(0,8); e.click()
    check(e.deleted==1 and e.pickups==1 and not e.popup,"gray stack needs exactly one manual click")
    check(e.normalClicks==0,"delete must not invoke normal item use")
    check(table.concat(e.overlay.pass,",")=="LeftButton,MiddleButton,Button4,Button5","non-right buttons must pass through")
    check(e.overlay.clicks[1]=="RightButtonUp","must not delete on mouse-down")
    for quality=1,5 do
        e=runtime(legacy); e.add(quality,7); e.click()
        check(e.deleted==0 and e.pickups==0 and e.popup.count=="7","higher-quality item moved before confirmation")
        e.accept(); check(e.deleted==1,"confirmed quality "..quality.." failed")
        e.q.Confirm(e.popup.data); check(e.deleted==1,"confirmation replay deleted twice")
    end
    for _, property in ipairs({"combat","dead","targeting","quest","uncached","infoError"}) do
        e=runtime(legacy); e.add(); e[property]=true
        local item=e.q.SafeInspect(0,1)
        check(not item and e.deleted==0 and e.pickups==0,"unsafe state accepted: "..property)
    end
    for _, change in ipairs({function(x) x.HCOB_DB.bagQuickDelete=false end,
        function(x) x.cursor={"spell",42} end,function(x) x.questID=42 end,
        function(x) x.classID=12 end,function(x) x.bindType=4 end,
        function(x) x.items["0:1"].isLocked=true end,function(x) x.items["0:1"].hasLoot=true end,
        function(x) x.items["0:1"].quality=nil end,function(x) x.add(1,1,6948) end}) do
        e=runtime(legacy); e.add(); change(e)
        check(not e.q.SafeInspect(0,1) and e.pickups==0,"unsafe metadata accepted")
    end
    e=runtime(legacy); e.add()
    for _, pair in ipairs({{-1,1},{5,1},{0,0},{0,21},{0,1.5},{"0",1}}) do
        check(not e.q.SafeInspect(unpack(pair)),"non-carried slot accepted")
    end
end

-- Stale confirmations, including swapping identical item IDs/stack contents.
for _, change in ipairs({function(e) e.add(1,3,456) end,function(e) e.items["0:1"].stackCount=2 end,
    function(e) e.items["0:1"].hyperlink=e.items["0:1"].hyperlink.."suffix" end,
    function(e) e.items["0:1"].isLocked=true end,function(e) e.cursor={"item",456,"item:456:0"} end,
    function(e) e.combat=true end,function(e) e.HCOB_DB.bagQuickDelete=false end,
    function(e) e.q.InventoryChanged() end,function(e) e.q.Cancel() end}) do
    local e=runtime(); e.add(1); e.click(); local item=e.popup.data; change(e); e.q.Confirm(item)
    check(e.pickups==0 and e.deleted==0,"stale confirmation destroyed an item")
end
for _, failure in ipairs({"pickupError","pickupNoop","wrongPickup","deleteError","popupUnavailable"}) do
    local e=runtime(); e.add(failure=="popupUnavailable" and 1 or 0); e[failure]=true; e.click()
    check(e.deleted==0,"unsafe API failure: "..failure)
    if failure=="wrongPickup" then check(e.cursor[2]==999,"foreign cursor was cleared") end
    if failure=="deleteError" then check(e.cursor[2]==123,"blocked client cursor was silently cleared") end
end

local e=runtime(); e.add(); e.focus=e.elv; e.hover=e.elv; e.click()
check(e.deleted==1,"ElvUI bag item not supported")
e=runtime(); e.add(); e.focus=e.elv; e.hover=e.elv; e.ElvUI_ContainerFrame.isBank=true; e.sync()
check(not e.overlay.shown,"bank widget was intercepted")
e=runtime(); e.add(); e.elv.bagFrame={}; e.focus=e.elv; e.hover=e.elv; e.sync()
check(not e.overlay.shown,"unregistered addon widget was intercepted")
e=runtime(); e.add(); e.standard.parent.id=-1; e.sync()
check(not e.overlay.shown,"standard bank was intercepted")
for _, key in ipairs({"ctrl","alt","shift"}) do
    e=runtime(); e.add(); e[key]=(key=="shift"); e.sync()
    check(not e.overlay or not e.overlay.shown,"wrong modifier intercepted: "..key)
end
e=runtime(); e.add(); e.sync(); e.focus=e.overlay
e.controller.scripts.OnUpdate(); check(e.overlay.shown,"overlay lost its source under the cursor")
e.standard.scale=0.8; e.UIParent.scale=0.5; e.controller.scripts.OnUpdate()
check(e.overlay.width==51.2 and e.overlay.point[4]==128,"scaled bag overlay misaligned")
e.overlay.scripts.OnMouseDown(e.overlay,"RightButton"); e.items["0:1"].stackCount=2
e.overlay.scripts.OnClick(e.overlay,"RightButton"); check(e.deleted==0,"stack changed between down/up")
e=runtime(); e.add(); e.sync(); e.overlay.scripts.OnMouseDown(e.overlay,"RightButton")
e.controller.scripts.OnEvent(nil,"BAG_UPDATE"); e.overlay.scripts.OnClick(e.overlay,"RightButton")
check(e.deleted==0,"bag event kept stale pressed item")
e=runtime(); e.add(1); e.click(); e.combat=true; e.controller.scripts.OnEvent(nil,"PLAYER_REGEN_DISABLED")
check(not e.popup and not e.controller.scripts.OnUpdate and not e.overlay.shown,"combat did not cancel UI")
e=runtime(); e.add(1); e.click(); e.HCOB_DB.bagQuickDelete=false; e.sync()
check(not e.popup and not e.controller.scripts.OnUpdate,"opt-out left a live confirmation")
e=runtime(); e.add(); e.sync(); e.alt=false; e.controller.scripts.OnEvent(nil,"MODIFIER_STATE_CHANGED")
check(not e.overlay.shown and not e.controller.scripts.OnUpdate,"modifier release did not restore normal clicks")
e=runtime(); e.add(); e.sync(); e.standard.shown=false; e.controller.scripts.OnUpdate()
check(not e.overlay.shown,"closed bags left a mouse blocker")
e=runtime(); e.add(); e.sync(); e.overlay.scripts.OnClick(e.overlay,"RightButton")
check(e.deleted==0,"click without matching mouse-down deleted an item")
e=runtime(); e.add(); e.sync(); e.overlay.scripts.OnMouseDown(e.overlay,"LeftButton")
e.overlay.scripts.OnClick(e.overlay,"LeftButton"); check(e.deleted==0,"left click deleted an item")
e.standard.scripts.OnClick(); check(e.normalClicks==1,"original bag click script was modified")
e=runtime(); e.add(); e.GetMouseFoci=nil; e.GetMouseFocus=function() return e.standard end; e.click()
check(e.deleted==1,"legacy mouse focus fallback failed")
e=runtime(); e.add(); e.passError=true; e.sync()
check(not e.controller.scripts.OnUpdate and #e.messages==1,"unsupported mouse API did not fail closed")
e.sync(); check(#e.messages==1,"unsupported API floods chat / keeps retrying")
e=runtime(); e.add(); e.sync(); e.standard.GetRect=function() error("missing UI data") end
e.controller.scripts.OnUpdate()
check(not e.overlay.shown and not e.controller.scripts.OnUpdate,"UI refresh failure left an input blocker")
e=runtime(); e.add(1); e.click(); e.controller.scripts.OnEvent(nil,"PLAYER_DEAD")
check(not e.popup and not e.controller.scripts.OnUpdate,"death event failed to cancel before unit flags update")
e=runtime(); e.add(); e.sync(); e.controller.scripts.OnEvent(nil,"PLAYER_LOGOUT")
check(not e.overlay.shown and not e.controller.scripts.OnUpdate,"logout left overlay active")
e=runtime(); e.add(1); e.StaticPopup_Show=function() error("popup failure") end; e.click()
check(e.pickups==0 and not e.q.HasPending(),"popup error moved an item or left stale state")
for _, key in ipairs({"isLocked","hasLoot","stackCount","hyperlink","quality"}) do
    e=runtime(); e.add(); e.items["0:1"][key]=nil
    check(not e.q.SafeInspect(0,1) and e.pickups==0,"missing metadata was treated as safe: "..key)
end
e=runtime(); e.add(); e.C_Container.GetContainerItemQuestInfo=function() return {} end
check(not e.q.SafeInspect(0,1),"unknown quest status was treated as safe")
e=runtime(); e.add(); e.sync(); e.overlay.scripts.OnMouseDown(e.overlay,"RightButton")
e.standard.parent.id=1; e.overlay.scripts.OnClick(e.overlay,"RightButton")
check(e.deleted==0,"reused bag frame deleted from a different bag")
e=runtime(); e.add(); e.sync(); e.overlay.scripts.OnMouseDown(e.overlay,"RightButton")
e.hover=nil; e.overlay.scripts.OnClick(e.overlay,"RightButton")
check(e.deleted==0,"release outside original item deleted a stack")
e=runtime(); e.add(1); e.click(); e.controller.scripts.OnEvent(nil,"BAG_UPDATE")
check(not e.popup and not e.q.HasPending() and e.pickups==0,"inventory events executed a deletion")
print("Bag quick delete regression: PASS ("..checks.." checks; simulated inventory only)")
