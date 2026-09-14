-- Configuration is separate from the combat panel and uses normal dialog navigation.
local HCOB=HCOneButton
local E=HCOB.Internal
setfenv(1,E)
local P=HCOB.UI.GroupHealingPanel
local G=HCOB.Advisor.GroupHealing
local O={prefix="",rows={}}
HCOB.UI.GroupHealingOptions=O
local function label(parent,value,x,y,w,h)
    local f=parent:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
    f:SetPoint("TOPLEFT",x,y); f:SetSize(w,h); f:SetJustifyH("LEFT"); f:SetText(value)
    return f
end
local function button(parent,value,x,y,w,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT",x,y); b:SetSize(w,26); b:SetText(value); b:SetScript("OnClick",fn)
    return b
end
local function actionName(role)
    if role==0 then return "None" end
    local id=HCOB.UI.GroupHealing.spells[role]
    return id and (SpellName(id).." - "..G.labels[role]) or (G.labels[role].." (not learned)")
end
function O.Refresh()
    if not O.frame then return end
    local s=P.Settings()
    O.enabled:SetChecked(s.enabled); O.locked:SetChecked(s.locked)
    for index,row in ipairs(O.rows) do
        local value=actionName(P.Role(O.prefix,index))
        if s.clicks[O.prefix..index]==nil then value="Default: "..value end
        row:SetText(value)
    end
    for prefix,tab in pairs(O.tabs) do
        tab:SetText((prefix==O.prefix and "|cff66ffbb" or "")..(prefix=="" and "Normal" or prefix:sub(1,-2):upper()).."|r")
    end
    O.preview:SetText(P.preview and "Hide preview" or "Preview / move")
end
local function openChoices(index)
    if InCombatLockdown() then return end
    local menu=O.menu
    menu:Hide(); menu:ClearAllPoints(); menu:SetPoint("TOPLEFT",O.rows[index],"BOTTOMLEFT",0,-2)
    local choices={{text="Default (follow learned spells)"},{role=0,text="None"}}
    for role=1,4 do
        if HCOB.UI.GroupHealing.spells[role] then choices[#choices+1]={role=role,text=actionName(role)} end
    end
    for i,entry in ipairs(menu.entries) do
        local choice=choices[i]
        if choice then
            entry:SetText(choice.text); entry:Show()
            entry:SetScript("OnClick",function()
                if InCombatLockdown() then return end
                P.SetRole(O.prefix,index,choice.role); menu:Hide(); O.Refresh()
            end)
        else entry:Hide() end
    end
    menu:SetHeight(#choices*28+8); menu:Show()
end
function O.Create()
    if O.frame then return O.frame end
    local frame=CreateFrame("Frame","HCOneButtonGroupHealingOptions",UIParent,"BasicFrameTemplateWithInset")
    frame:SetSize(520,536); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true); frame:Hide()
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function(self) if not InCombatLockdown() then self:StartMoving() end end)
    frame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    frame.TitleText:SetText("HC One Button - Party healing")
    label(frame,"Click your bar or a teammate's to heal. Also visible while solo.\nThese mouse bindings only affect this panel; your target stays unchanged.",24,-42,470,36)
    local function checkbox(value,x,y,key)
        local c=CreateFrame("CheckButton",nil,frame,"InterfaceOptionsCheckButtonTemplate")
        c:SetPoint("TOPLEFT",x,y); c.Text:SetText(value)
        c:SetScript("OnClick",function(self)
            if InCombatLockdown() then O.Refresh(); return end
            P.Settings()[key]=self:GetChecked() and true or false
            P.Configure(); O.Refresh(); if UpdateDisplay then UpdateDisplay() end
        end)
        return c
    end
    O.enabled=checkbox("Show party panel",22,-86,"enabled")
    O.locked=checkbox("Lock panel position",272,-86,"locked")
    label(frame,"Choose a modifier, then assign a spell to each mouse button.",24,-125,470,18)
    O.tabs={}
    for index,prefix in ipairs(P.prefixes) do
        O.tabs[prefix]=button(frame,"",24+(index-1)*119,-150,112,function()
            O.prefix=prefix; O.menu:Hide(); O.Refresh()
        end)
    end
    for index,name in ipairs(P.mouseNames) do
        label(frame,name,24,-196-(index-1)*41,104,26)
        O.rows[index]=button(frame,"",134,-196-(index-1)*41,360,function() openChoices(index) end)
    end
    label(frame,"Highest learned rank is automatic. Roles follow learned spell families.\nOne modifier at a time; combined modifiers do nothing. Configure and move\nout of combat. The panel covers you + 4 party members, not raid groups.",24,-397,472,44)
    O.preview=button(frame,"Preview / move",24,-448,145,function()
        if InCombatLockdown() then return end
        if not P.Settings().enabled then print("|cffffcc00HCOB:|r enable Show party panel before previewing it."); return end
        P.preview=not P.preview; P.Configure(); O.Refresh()
    end)
    O.center=button(frame,"Center panel",179,-448,145,function() P.Center() end)
    O.reset=button(frame,"Reset clicks",334,-448,160,function()
        if InCombatLockdown() then return end
        P.Settings().clicks={}; P.Configure(); O.menu:Hide(); O.Refresh()
        if UpdateDisplay then UpdateDisplay() end
    end)
    button(frame,"Back to Options",334,-488,160,function() HCOB.UI.WindowManager.Close("group_healing") end)
    O.menu=CreateFrame("Frame",nil,frame)
    O.menu:SetSize(360,176); O.menu:SetFrameStrata("TOOLTIP"); O.menu:EnableMouse(true)
    local bg=O.menu:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(.025,.05,.04,1)
    O.menu.entries={}
    for index=1,6 do O.menu.entries[index]=button(O.menu,"",4,-4-(index-1)*28,352,function() end) end
    O.menu:Hide()
    frame:SetScript("OnShow",O.Refresh)
    frame:SetScript("OnHide",function()
        frame:StopMovingOrSizing()
        O.menu:Hide(); P.preview=false
        P.Configure() -- defers all protected changes if combat just began
    end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:SetScript("OnEvent",function(_,event)
        if event=="PLAYER_REGEN_DISABLED" then HCOB.UI.WindowManager.Close("group_healing",false)
        elseif frame:IsShown() then O.menu:Hide(); O.Refresh() end
    end)
    HCOB.UI.WindowManager.Register("group_healing",frame)
    if UISpecialFrames then table.insert(UISpecialFrames,"HCOneButtonGroupHealingOptions") end
    O.frame=frame
    return frame
end
function O.Open()
    if InCombatLockdown() then print("|cffffcc00HCOB:|r configure party healing out of combat."); return false end
    if not P.Supported() then return false end
    HCOB.UI.GroupHealing.Configure()
    O.Create()
    HCOB.UI.WindowManager.OpenChild("group_healing","options")
    return true
end
