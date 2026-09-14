-- Fixed-unit, player-clicked party healing. No health-based secure targeting.
local HCOB=HCOneButton
local E=HCOB.Internal
setfenv(1,E)
local G=HCOB.Advisor.GroupHealing
local P={rows={},actions={},prefixes={"","shift-","ctrl-","alt-"},
    mouseNames={"Left click","Right click","Middle click","Mouse 4","Mouse 5"}}
HCOB.UI.GroupHealingPanel=P
local modifiers={"","shift-","ctrl-","alt-","alt-ctrl-","alt-shift-","ctrl-shift-","alt-ctrl-shift-"}
local mouseIndex={LeftButton=1,RightButton=2,MiddleButton=3,Button4=4,Button5=5}
-- Native secure hover handlers own these transient overrides, including in
-- combat. Only mouse 3-5 are reserved; left/right retain their direct clicks.
-- Bind every modifier combination so an unassigned combo remains a no-op
-- instead of falling through to a permanent action-bar/game binding.
local clearHoverBindings="self:ClearBindings()"
local hoverBindings={clearHoverBindings}
for _,prefix in ipairs(modifiers) do
    for index=3,5 do
        local mouse=index==3 and "MiddleButton" or "Button"..index
        hoverBindings[#hoverBindings+1]='self:SetBindingClick(true, "'..prefix:upper()..'BUTTON'..index..'", self, "'..mouse..'")'
    end
end
hoverBindings=table.concat(hoverBindings,"\n")
local width,height=236,278
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function truth(v) return v==true or v==1 end
function P.Supported()
    return PLAYER_CLASS=="PRIEST" or PLAYER_CLASS=="PALADIN" or PLAYER_CLASS=="SHAMAN" or PLAYER_CLASS=="DRUID"
end
function P.Settings()
    if type(HCOB_CharacterDB.groupHealingPanel)~="table" then HCOB_CharacterDB.groupHealingPanel={} end
    local s=HCOB_CharacterDB.groupHealingPanel
    if type(s.enabled)~="boolean" then s.enabled=true end
    if type(s.locked)~="boolean" then s.locked=false end
    if type(s.clicks)~="table" then s.clicks={} end
    for _,prefix in ipairs(P.prefixes) do
        for index=1,5 do
            local key=prefix..index
            local value=s.clicks[key]
            if value~=nil and (not finite(value) or value%1~=0 or value<0 or value>4) then s.clicks[key]=nil end
        end
    end
    if not finite(s.x) then s.x=-310 end
    if not finite(s.y) then s.y=0 end
    return s
end
function P.Role(prefix,index)
    local selected=P.Settings().clicks[prefix..index]
    if selected~=nil then return selected end
    if prefix=="" then
        if index==1 then return 2 end
        if index==2 then return 1 end
        if index==3 then return PLAYER_CLASS=="PRIEST" and 4 or (PLAYER_CLASS=="DRUID" and 3 or 0) end
    elseif prefix=="shift-" and index==1 then return 3 end
    return 0
end
function P.Label(prefix,index)
    return (prefix=="" and "" or prefix:sub(1,-2):upper().." + ")..P.mouseNames[index]
end
function P.SetRole(prefix,index,role)
    if InCombatLockdown() then return false end
    local allowed=false
    for _,value in ipairs(P.prefixes) do if value==prefix then allowed=true end end
    if not allowed or not finite(index) or index%1~=0 or index<1 or index>5 then return false end
    if role~=nil and (not finite(role) or role%1~=0 or role<0 or role>4) then return false end
    P.Settings().clicks[prefix..index]=role
    P.Configure()
    if UpdateDisplay then UpdateDisplay() end
    return true
end
local function text(parent,font,x,y,w)
    local f=parent:CreateFontString(nil,"OVERLAY",font)
    f:SetPoint("TOPLEFT",x,y); f:SetWidth(w); f:SetJustifyH("LEFT")
    return f
end
local function background(parent,r,g,b,a)
    local t=parent:CreateTexture(nil,"BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(r,g,b,a); return t
end
function P.Place(x,y)
    if InCombatLockdown() or not P.frame then return false end
    if not finite(x) or not finite(y) then return false end
    local halfW=math.max(0,(UIParent:GetWidth()-width)/2)
    local halfH=math.max(0,(UIParent:GetHeight()-height)/2)
    local s=P.Settings()
    s.x=math.max(-halfW,math.min(halfW,x)); s.y=math.max(-halfH,math.min(halfH,y))
    P.frame:ClearAllPoints(); P.frame:SetPoint("CENTER",UIParent,"CENTER",s.x,s.y)
    return true
end
function P.Center()
    if InCombatLockdown() then return false end
    return P.Place(0,0)
end
local function input(row,mouse,down)
    if down then return end
    local prefix=SecureButton_GetModifierPrefix(row)
    local index=mouseIndex[mouse]
    local action=index and P.actions[prefix..index]
    if action then G.NoteInput(action.id,row.unit) end
end
function P.Create()
    if P.frame then return P.frame end
    if InCombatLockdown() or not P.Supported() then return end
    -- UIParent, never the HCOB HUD: independent anchor, scale and visibility.
    local frame=CreateFrame("Frame","HCOneButtonGroupHealingPanel",UIParent,"SecureHandlerStateTemplate")
    frame:SetSize(width,height); frame:SetScale(1); frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM"); background(frame,.012,.027,.025,.96)
    local header=CreateFrame("Frame",nil,frame)
    header:SetPoint("TOPLEFT",0,0); header:SetSize(width,30)
    background(header,.025,.22,.16,1)
    text(header,"GameFontNormal",10,-8,216):SetText("HC One Button  |  Party heals")
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function()
        if InCombatLockdown() or P.Settings().locked then return end
        local x,y=GetCursorPosition(); local s=P.Settings()
        P.drag={x=x,y=y,baseX=s.x,baseY=s.y}
    end)
    header:SetScript("OnDragStop",function() P.drag=nil end)
    P.header=header
    for index=1,5 do
        local unit=index==1 and "player" or "party"..(index-1)
        local row=CreateFrame("Button","HCOneButtonPartyHeal"..index,frame,
            "SecureActionButtonTemplate,SecureHandlerEnterLeaveTemplate,SecureHandlerShowHideTemplate")
        row.unit=unit; row:SetAttribute("unit",unit)
        -- Binding clicks can deliver both edges. The native action handler
        -- accepts the release only; PreClick likewise ignores the press.
        row:SetAttribute("useOnKeyDown",false); row:SetAttribute("pressAndHoldAction",false)
        row:RegisterForClicks("AnyUp","AnyDown")
        row:SetAttribute("_onenter",hoverBindings)
        row:SetAttribute("_onleave",clearHoverBindings)
        row:SetAttribute("_onhide",clearHoverBindings)
        row:SetAttribute("_onshow",clearHoverBindings)
        -- The secure row owns every mouse button, including middle/side clicks.
        -- Click registration alone is not a substitute for mouse hit-testing.
        row:EnableMouse(true)
        if row.SetPassThroughButtons then row:SetPassThroughButtons() end
        row:SetSize(220,42); row:SetPoint("TOPLEFT",8,-34-(index-1)*44)
        row.background=background(row,.06,.09,.085,1)
        row.health=CreateFrame("StatusBar",nil,row)
        row.health:EnableMouse(false) -- visual child must not cover the secure hit area
        row.health:SetPoint("TOPLEFT",2,-2); row.health:SetSize(216,23)
        row.health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        row.health:SetMinMaxValues(0,100)
        row.name=text(row.health,"GameFontHighlightSmall",5,-5,155)
        row.percent=text(row.health,"GameFontHighlightSmall",159,-5,50)
        row.percent:SetJustifyH("RIGHT")
        row.hint=text(row,"GameFontHighlightSmall",6,-28,209)
        row:SetScript("PreClick",input)
        -- Preserve the inherited secure handlers when adding tooltip hooks.
        row:HookScript("OnEnter",function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:AddLine(UnitName(self.unit) or "Empty party slot",.5,1,.8)
            for _,prefix in ipairs(P.prefixes) do
                for button=1,5 do
                    local action=P.actions[prefix..button]
                    if action then GameTooltip:AddDoubleLine(P.Label(prefix,button),SpellName(action.id),1,1,1,.7,1,.85) end
                end
            end
            GameTooltip:AddLine("Click this bar to heal. Your target is unchanged.",.8,.8,.8,true)
            GameTooltip:Show()
        end)
        row:HookScript("OnLeave",function(self)
            -- A dialog appearing under a stationary cursor can send a
            -- non-motion leave, ignored by the secure hover template. Clear
            -- this row's overrides out of combat as well; never set bindings
            -- or touch protected state from this insecure hook in combat.
            if not InCombatLockdown() then ClearOverrideBindings(self) end
            if GameTooltip then GameTooltip:Hide() end
        end)
        P.rows[unit]=row
    end
    P.footer=text(frame,"GameFontHighlightSmall",10,-260,216)
    frame:SetScript("OnUpdate",function(_,elapsed)
        if P.drag then
            if InCombatLockdown() then P.drag=nil
            else
                local x,y=GetCursorPosition(); local d=P.drag; local scale=UIParent:GetEffectiveScale()
                P.Place(d.baseX+(x-d.x)/scale,d.baseY+(y-d.y)/scale)
            end
        end
        P.elapsed=(P.elapsed or 0)+elapsed
        if P.elapsed>=.1 then P.elapsed=0; P.Refresh() end
    end)
    frame:SetScript("OnHide",function() P.drag=nil end)
    P.frame=frame
    return frame
end
function P.Configure()
    if InCombatLockdown() then P.pending=true; return false end
    local frame=P.Create()
    if not frame then return false end
    local s=P.Settings(); P.Place(s.x,s.y)
    local spells=HCOB.UI.GroupHealing.spells
    P.actions={}
    for _,prefix in ipairs(P.prefixes) do
        for index=1,5 do
            local id=spells[P.Role(prefix,index)]
            if id then P.actions[prefix..index]={id=id,label=P.Label(prefix,index)} end
        end
    end
    for unit,row in pairs(P.rows) do
        -- Explicitly block unassigned modifier combinations; no fallback cast.
        for _,prefix in ipairs(modifiers) do
            for index=1,5 do
                local action=P.actions[prefix..index]
                row:SetAttribute(prefix.."type"..index,"macro")
                row:SetAttribute(prefix.."macrotext"..index,G.Macro(action and action.id,unit))
            end
        end
        local visibility="[@"..unit..",exists] show; hide"
        if P.preview then visibility="[combat,@"..unit..",exists] show; [combat] hide; show" end
        RegisterStateDriver(row,"visibility",visibility)
    end
    -- Keep the real player row available solo, including after closing Options.
    -- Party rows still use fixed-unit existence drivers; previews never cast on
    -- a synthetic unit or redirect an empty row to the player.
    local visibility="[group:raid] hide; [@player,exists] show; hide"
    if P.preview then visibility="[combat,group:raid] hide; [@player,exists] show; hide" end
    if not s.enabled then visibility="hide" end
    RegisterStateDriver(frame,"visibility",visibility)
    P.pending=false
    P.Refresh()
    return true
end
function P.ActionFor(id,unit)
    local row=P.rows[unit]
    if not row or not row:IsVisible() or not P.frame or not P.frame:IsVisible() then return end
    for _,prefix in ipairs(P.prefixes) do
        for index=1,5 do
            local action=P.actions[prefix..index]
            if action and action.id==id then return action.label end
        end
    end
end
function P.Refresh()
    if not P.frame then return end
    local suggestion=G.current
    P.footer:SetText(P.Settings().locked and "Position locked  |  Options to configure" or "Drag title to move  |  Hover for clicks")
    for unit,row in pairs(P.rows) do
        local exists=truth(UnitExists(unit))
        local connected=exists and truth(UnitIsConnected(unit))
        local dead=exists and truth(UnitIsDeadOrGhost(unit))
        local hp,known=UnitHealthPct(unit)
        local readable=known and finite(hp)
        local percent=readable and math.max(0,math.min(100,hp)) or 0
        row.name:SetText(exists and (UnitName(unit) or unit) or "Empty party slot")
        row.percent:SetText(not exists and "--" or (not connected and "OFF" or (dead and "DEAD" or (readable and math.floor(percent+.5).."%" or "--"))))
        row.health:SetValue(percent)
        local chosen=suggestion and suggestion.unit==unit and suggestion.guid==UnitGUID(unit)
            and P.ActionFor(suggestion.id,unit)
        if chosen then
            row.background:SetColorTexture(.1,.45,.33,1)
            row.hint:SetText(chosen..": "..SpellName(suggestion.id))
        else
            row.background:SetColorTexture(.06,.09,.085,1)
            row.hint:SetText(not exists and "Preview - no unit to heal" or "")
        end
        if not connected or dead then row.health:SetStatusBarColor(.25,.25,.25)
        elseif percent<=35 then row.health:SetStatusBarColor(.65,.13,.12)
        elseif percent<=65 then row.health:SetStatusBarColor(.55,.35,.07)
        else row.health:SetStatusBarColor(.05,.38,.25) end
    end
end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_REGEN_DISABLED" then
        P.drag=nil; P.preview=false
        -- Drivers hide empty preview rows/raid previews in combat, not the real solo player.
        P.pending=true
    end
    P.Refresh()
end)
