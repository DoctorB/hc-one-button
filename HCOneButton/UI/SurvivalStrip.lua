-- Secure survival consumable strip.
-- The protected item assignment is frozen throughout combat; only visual
-- state (count/cooldown/highlight) may change while combat-locked.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Strip = HCOB.UI.SurvivalStrip
local Consumables = HCOB.Systems.Consumables

Strip.buttons = Strip.buttons or {}
Strip.roleToButton = Strip.roleToButton or {}
Strip.pendingConfigure = false

local function CooldownText(remaining)
    remaining = tonumber(remaining) or 0
    if remaining <= 0.05 then return "" end
    if remaining >= 60 then return tostring(math.ceil(remaining / 60)) .. "m" end
    if remaining >= 10 then return tostring(math.ceil(remaining)) end
    return string.format("%.1f", remaining)
end

local function CurrentScale()
    return Clamp(tonumber(HCOB_DB and HCOB_DB.scale) or 1.0, 0.70, 1.60)
end

function Strip.ApplyScale(scale)
    if InCombatLockdown and InCombatLockdown() then return false end
    scale = Clamp(tonumber(scale) or CurrentScale(), 0.70, 1.60)
    if Strip.frame then Strip.frame:SetScale(scale) end
    for _, button in ipairs(Strip.buttons) do
        if button then button:SetScale(scale) end
    end
    return true
end

function Strip.Configure()
    if InCombatLockdown and InCombatLockdown() then
        Strip.pendingConfigure = true
        return false
    end
    Consumables.RequestItemData()
    Consumables.Refresh()
    for _, role in ipairs(Consumables.roleOrder) do
        local button = Strip.roleToButton[role]
        local item = Consumables.GetRole(role)
        if button and item then
            if item.available then
                button:SetAttribute("type1", "item")
                button:SetAttribute("item1", "item:" .. tostring(item.id))
                button:SetAttribute("macrotext1", nil)
                button.assignedItemID = item.id
            else
                button:SetAttribute("type1", "macro")
                button:SetAttribute("macrotext1", "/stopmacro")
                button:SetAttribute("item1", nil)
                button.assignedItemID = nil
            end
            button.displayItemID = item.id
            button.itemName = item.name
            button.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
    end
    Strip.pendingConfigure = false
    Strip.UpdateStates()
    Strip.SyncVisibility()
    return true
end

function Strip.Highlight(role)
    Strip.recommendedRole = role
    for _, button in ipairs(Strip.buttons) do
        button.recommended = role ~= nil and button.role == role
        if button.recommended then
            button.glow:SetVertexColor(1, 0.78, 0.08)
            button.glow:Show()
            button.recommendedBG:Show()
        else
            button.glow:Hide()
            button.recommendedBG:Hide()
        end
    end
end

function Strip.UpdateStates()
    local healingStock = false
    local healingCooldownReady = false
    local recommendedUsable = false
    for _, button in ipairs(Strip.buttons) do
        local itemID = button.assignedItemID
        local count = itemID and Consumables.GetItemCount(itemID) or 0
        local startTime, duration, enabled, remaining = 0, 0, false, 0
        if itemID then startTime, duration, enabled, remaining = Consumables.GetRoleCooldown(button.role, itemID) end
        local usable = count > 0 and enabled and remaining <= 0.05
        if usable and IsUsableItem then
            local ok, value = pcall(IsUsableItem, itemID)
            if ok and value ~= nil then usable = value == true or value == 1 end
        end
        if button.role == "healthstone" or button.role == "healingPotion" or button.role == "bandage" then
            healingStock = healingStock or count > 0
            healingCooldownReady = healingCooldownReady or (count > 0 and enabled and remaining <= 0.05)
        end
        if button.recommended and usable then recommendedUsable = true end

        button.countText:SetText(count > 0 and tostring(count) or "0")
        button.cdText:SetText(CooldownText(remaining))
        if button.cooldown then
            if enabled and startTime > 0 and duration > 0 and remaining > 0.05 then
                button.cooldown:SetCooldown(startTime, duration)
                button.cooldown:Show()
            else
                button.cooldown:Hide()
            end
        end
        if button.icon.SetDesaturated then button.icon:SetDesaturated(not usable) end
        button.icon:SetAlpha(count > 0 and (usable and 1.0 or 0.48) or 0.20)
        if button.recommended and usable then
            button.border:SetVertexColor(1, 0.72, 0.08, 1)
            button.glow:Show()
            button.recommendedBG:Show()
        elseif count <= 0 then
            button.border:SetVertexColor(0.45, 0.10, 0.08, 0.92)
            button.glow:Hide()
            button.recommendedBG:Hide()
        elseif remaining > 0.05 then
            button.border:SetVertexColor(0.24, 0.42, 0.62, 0.95)
            button.glow:Hide()
            button.recommendedBG:Hide()
        elseif usable then
            button.border:SetVertexColor(0.18, 0.72, 0.30, 0.98)
            button.glow:Hide()
            button.recommendedBG:Hide()
        else
            button.border:SetVertexColor(0.38, 0.38, 0.40, 0.90)
            button.glow:Hide()
            button.recommendedBG:Hide()
        end
    end
    if Strip.status then
        if Strip.pendingConfigure then
            Strip.status:SetText("UPDATE AFTER COMBAT")
            Strip.status:SetTextColor(1, 0.70, 0.20)
        elseif Strip.recommendedRole and recommendedUsable then
            Strip.status:SetText("USE HIGHLIGHT")
            Strip.status:SetTextColor(1, 0.78, 0.18)
        elseif healingStock and healingCooldownReady then
            Strip.status:SetText("TOOLS READY")
            Strip.status:SetTextColor(0.45, 1, 0.55)
        elseif healingStock then
            Strip.status:SetText("TOOLS UNAVAILABLE")
            Strip.status:SetTextColor(1, 0.70, 0.20)
        else
            Strip.status:SetText("RESTOCK")
            Strip.status:SetTextColor(1, 0.35, 0.25)
        end
    end
end

function Strip.SyncVisibility()
    if InCombatLockdown and InCombatLockdown() then return false end
    if not Strip.frame then return false end
    local show = HCOB_DB and HCOB_DB.visible ~= false and HCOB_DB.showAdvisor ~= false
        and HCOB_DB.secureActions ~= false and HCOB_DB.showConsumables ~= false
    if show then Strip.frame:Show() else Strip.frame:Hide() end
    for _, button in ipairs(Strip.buttons) do
        if show then button:Show() else button:Hide() end
    end
    local coach = HCOB.Systems and HCOB.Systems.ProfessionCoach
    if coach and coach.Reanchor then coach.Reanchor() end
    return show
end

local function ShowTooltip(button)
    if not GameTooltip then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.itemName or (Consumables.roleLabels[button.role] or "Consumable"), 1, 0.82, 0.15)
    GameTooltip:AddLine(Consumables.roleDescriptions[button.role] or "Survival consumable", 0.72, 0.86, 1, true)
    local count = button.assignedItemID and Consumables.GetItemCount(button.assignedItemID) or 0
    GameTooltip:AddLine("Quantity: " .. tostring(count), count > 0 and 0.45 or 1, count > 0 and 1 or 0.30, count > 0 and 0.45 or 0.25)
    if button.assignedItemID then
        local _, _, _, remaining = Consumables.GetRoleCooldown(button.role, button.assignedItemID)
        if remaining > 0.05 then
            GameTooltip:AddLine("Cooldown: " .. CooldownText(remaining), 1, 0.72, 0.25)
        else
            GameTooltip:AddLine("Click to use", 0.45, 1, 0.45)
        end
    else
        GameTooltip:AddLine("None in bags - restock before a risky pull", 1, 0.35, 0.25, true)
    end
    if Strip.pendingConfigure then
        GameTooltip:AddLine("Bag changed in combat; secure assignment updates afterward.", 1, 0.72, 0.25, true)
    end
    GameTooltip:Show()
end

function Strip.CreateFrames()
    if Strip.frame then return end
    local anchor = HCOB.UI.ActionPanel and HCOB.UI.ActionPanel.frame
    local width = (HCOB_CoreShell and HCOB_CoreShell.GetWidth and HCOB_CoreShell:GetWidth()) or 376
    Strip.frame = CreateFrame("Frame", "HCOneButtonSurvivalStrip", UIParent)
    Strip.frame:SetSize(width, 58)
    if anchor then Strip.frame:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    else Strip.frame:SetPoint("TOP", HCOB_CoreShell, "BOTTOM", 0, -64) end
    Strip.frame:SetFrameStrata("HIGH")
    Strip.frame:EnableMouse(false)
    Strip.frame.bg = Strip.frame:CreateTexture(nil, "BACKGROUND")
    Strip.frame.bg:SetAllPoints()
    Strip.frame.bg:SetColorTexture(0.012, 0.014, 0.018, 0.96)
    HCOB_MakeRectBorder(Strip.frame, 0.22, 0.52, 0.34, 0.90)

    local title = Strip.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 9, -12)
    title:SetText("SURVIVAL")
    title:SetTextColor(0.55, 1, 0.68)
    Strip.status = Strip.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
    Strip.status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
    Strip.status:SetWidth(76)
    Strip.status:SetJustifyH("LEFT")
    Strip.status:SetText("RESTOCK")

    for index, role in ipairs(Consumables.roleOrder) do
        local button = CreateFrame("Button", "HCOneButtonSurvival" .. index, UIParent, "SecureActionButtonTemplate")
        button:SetSize(34, 34)
        button:SetPoint("TOPLEFT", Strip.frame, "TOPLEFT", 92 + (index - 1) * 68, -7)
        button:SetFrameStrata("HIGH")
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetAttribute("useOnKeyDown", hcobUseKeyDown)
        button.role = role

        button.bg = button:CreateTexture(nil, "BACKGROUND")
        button.bg:SetAllPoints()
        button.bg:SetColorTexture(0.025, 0.028, 0.034, 0.99)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 3, -3)
        button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        button.recommendedBG = button:CreateTexture(nil, "ARTWORK")
        button.recommendedBG:SetAllPoints(button.icon)
        button.recommendedBG:SetColorTexture(1, 0.72, 0.02, 0.16)
        button.recommendedBG:Hide()

        button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button.cooldown:SetAllPoints(button.icon)
        if button.cooldown.SetDrawEdge then button.cooldown:SetDrawEdge(true) end
        if button.cooldown.SetHideCountdownNumbers then button.cooldown:SetHideCountdownNumbers(true) end
        button.cooldown:Hide()
        button.cdText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.cdText:SetPoint("CENTER")
        button.cdText:SetTextColor(1, 0.92, 0.72)
        button.cdText:SetText("")
        button.countText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.countText:SetPoint("BOTTOMRIGHT", -3, 3)
        button.countText:SetText("0")
        button.label = Strip.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
        button.label:SetPoint("TOP", button, "BOTTOM", 0, -2)
        button.label:SetText(Consumables.roleLabels[role] or role)
        button.label:SetTextColor(0.72, 0.82, 0.88)
        button.border = button:CreateTexture(nil, "OVERLAY")
        button.border:SetAllPoints()
        button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        button.glow = button:CreateTexture(nil, "OVERLAY")
        button.glow:SetPoint("TOPLEFT", -7, 7)
        button.glow:SetPoint("BOTTOMRIGHT", 7, -7)
        button.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        button.glow:SetBlendMode("ADD")
        button.glow:SetAlpha(0.90)
        button.glow:Hide()
        button:SetScript("OnEnter", ShowTooltip)
        button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

        Strip.buttons[index] = button
        Strip.roleToButton[role] = button
    end
    Strip.ApplyScale(CurrentScale())
end

Strip.CreateFrames()

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_LEVEL_UP", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_AURA", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "ACTIONBAR_UPDATE_COOLDOWN"}) do
    pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" and unit ~= "player" then return end
    if event == "PLAYER_REGEN_DISABLED" then
        Consumables.RefreshCountsOnly()
        Strip.UpdateStates()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Strip.Configure()
    elseif InCombatLockdown and InCombatLockdown() then
        if event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED" or event == "PLAYER_LEVEL_UP" then
            Strip.pendingConfigure = true
            Consumables.RefreshCountsOnly()
        end
        Strip.UpdateStates()
    elseif event == "BAG_UPDATE_COOLDOWN" then
        Strip.UpdateStates()
    else
        Strip.Configure()
    end
end)
