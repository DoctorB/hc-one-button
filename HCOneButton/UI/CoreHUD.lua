-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

btn = CreateFrame("Button", "HCOneButtonFrame", UIParent, "SecureActionButtonTemplate")
btn:SetSize(82, 82)
btn:SetFrameStrata("HIGH")
btn:SetFrameLevel(5)
btn:SetClampedToScreen(true)
btn:EnableMouse(true)
btn:SetMovable(true)
btn:RegisterForDrag("LeftButton")
-- Secure click timing must match the client action-button mode.
-- Register both phases, then let SecureActionButtonTemplate select the phase
-- through useOnKeyDown. This fixes CLICK bindings (including BUTTON4) on
-- clients with ActionButtonUseKeyDown enabled.
btn:RegisterForClicks("AnyDown", "AnyUp")
hcobUseKeyDown = true
if GetCVar then
    local v = GetCVar("ActionButtonUseKeyDown")
    if v ~= nil then hcobUseKeyDown = tostring(v) ~= "0" end
end
btn:SetAttribute("useOnKeyDown", hcobUseKeyDown)
btn:SetPoint("CENTER", UIParent, "CENTER", HCOB_DB.x or 0, HCOB_DB.y or -180)
btn:SetScale(HCOB_DB.scale or 1.0)

bg = btn:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.025, 0.028, 0.034, 0.99)

icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetPoint("TOPLEFT", 5, -5)
icon:SetPoint("BOTTOMRIGHT", -5, 5)
icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

border = btn:CreateTexture(nil, "OVERLAY")
border:SetAllPoints()
border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

glow = btn:CreateTexture(nil, "OVERLAY")
glow:SetPoint("TOPLEFT", -12, 12)
glow:SetPoint("BOTTOMRIGHT", 12, -12)
glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
glow:SetBlendMode("ADD")
glow:SetAlpha(0.75)
glow:Hide()

label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("TOP", btn, "BOTTOM", 0, -5)
label:SetText("HC ONE")

hint = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetPoint("TOP", label, "BOTTOM", 0, -2)
hint:SetText("")

reasonText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
reasonText:SetPoint("TOP", hint, "BOTTOM", 0, -1)
reasonText:SetWidth(220)
reasonText:SetText("")

-- v1.9 compact HUD: these legacy captions lived below the secure button and
-- collided with the Advisor/bars when the button was scaled down. The base
-- action is now communicated by the button itself + the Advisor status.
label:Hide()
hint:Hide()
reasonText:Hide()

resourceText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
resourceText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -7, 7)
resourceText:SetText("")

hpText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hpText:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 7, 7)
hpText:SetText("")

enemyText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
enemyText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -7, -7)
enemyText:SetText("")

classText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
classText:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -7)
classText:SetText(PLAYER_CLASS and PLAYER_CLASS:sub(1,3) or "HC")

-- Non-clickable Advisor: shows the situational spell to cast manually.
-- v1.9: compact layout scaled with the button. The old UI had
-- a tall banner and text below BASE that became disproportionate at scales
-- such as 0.7. Now: icon + short badge + title + key + reason, all within 82px.

-- Rectangular panel borders. Do not stretch UI-Quickslot2 across wide frames:
-- that texture is made for square action buttons and creates a false inner rectangle.
function HCOB_MakeRectBorder(frame, r, g, b, a)
    if not frame then return end
    frame.HCOBRectBorder = frame.HCOBRectBorder or {}
    local e = frame.HCOBRectBorder
    if #e == 0 then
        e[1] = frame:CreateTexture(nil, "BORDER")
        e[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        e[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        e[1]:SetHeight(1)
        e[2] = frame:CreateTexture(nil, "BORDER")
        e[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        e[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        e[2]:SetHeight(1)
        e[3] = frame:CreateTexture(nil, "BORDER")
        e[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        e[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        e[3]:SetWidth(1)
        e[4] = frame:CreateTexture(nil, "BORDER")
        e[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        e[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        e[4]:SetWidth(1)
        for i=1,4 do e[i]:SetColorTexture(1,1,1,1) end
    end
    HCOB_SetRectBorderColor(frame, r, g, b, a)
end

function HCOB_SetRectBorderColor(frame, r, g, b, a)
    if not frame or not frame.HCOBRectBorder then return end
    for i=1,4 do
        local t = frame.HCOBRectBorder[i]
        if t then t:SetVertexColor(r or 1, g or 1, b or 1, a or 1) end
    end
end

-- v1.18.7 unified Core HUD. BASE + Advisor + telemetry footer are rendered
-- inside one visual shell so they read as a single addon component. The secure
-- BASE button itself remains independent; this frame is purely visual.
HCOB_CoreShell = CreateFrame("Frame", "HCOneButtonCoreShell", UIParent)
HCOB_CoreShell:SetSize(376, 118)
HCOB_CoreShell:SetPoint("TOPLEFT", btn, "TOPLEFT", -4, 4)
HCOB_CoreShell:SetFrameStrata("HIGH")
HCOB_CoreShell:SetFrameLevel(1)
HCOB_CoreShell:EnableMouse(false)
HCOB_CoreShell.bg = HCOB_CoreShell:CreateTexture(nil, "BACKGROUND")
HCOB_CoreShell.bg:SetAllPoints()
HCOB_CoreShell.bg:SetColorTexture(0.012, 0.014, 0.018, 0.96)
HCOB_MakeRectBorder(HCOB_CoreShell, 0, 0, 0, 0)


swingBG = CreateFrame("Frame", nil, btn)
swingBG:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -4)
swingBG:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", 0, -4)
swingBG:SetHeight(4)
swingBGTex = swingBG:CreateTexture(nil, "BACKGROUND")
swingBGTex:SetAllPoints()
swingBGTex:SetColorTexture(0.15, 0.15, 0.15, 0.9)
swingFill = swingBG:CreateTexture(nil, "ARTWORK")
swingFill:SetPoint("TOPLEFT")
swingFill:SetPoint("BOTTOMLEFT")
swingFill:SetWidth(1)
swingFill:SetColorTexture(0.9, 0.75, 0.2, 0.95)

hpBarBG = CreateFrame("Frame", nil, btn)
hpBarBG:SetPoint("TOPLEFT", swingBG, "BOTTOMLEFT", 0, -2)
hpBarBG:SetPoint("TOPRIGHT", swingBG, "BOTTOMRIGHT", 0, -2)
hpBarBG:SetHeight(5)
hpBarBGTex = hpBarBG:CreateTexture(nil, "BACKGROUND")
hpBarBGTex:SetAllPoints()
hpBarBGTex:SetColorTexture(0.16, 0.04, 0.04, 0.9)
hpBarFill = hpBarBG:CreateTexture(nil, "ARTWORK")
hpBarFill:SetPoint("TOPLEFT")
hpBarFill:SetPoint("BOTTOMLEFT")
hpBarFill:SetWidth(1)
hpBarFill:SetColorTexture(0.9, 0.15, 0.15, 0.95)

powerBarBG = CreateFrame("Frame", nil, btn)
powerBarBG:SetPoint("TOPLEFT", hpBarBG, "BOTTOMLEFT", 0, -2)
powerBarBG:SetPoint("TOPRIGHT", hpBarBG, "BOTTOMRIGHT", 0, -2)
powerBarBG:SetHeight(5)
powerBarBGTex = powerBarBG:CreateTexture(nil, "BACKGROUND")
powerBarBGTex:SetAllPoints()
powerBarBGTex:SetColorTexture(0.05, 0.05, 0.05, 0.9)
powerBarFill = powerBarBG:CreateTexture(nil, "ARTWORK")
powerBarFill:SetPoint("TOPLEFT")
powerBarFill:SetPoint("BOTTOMLEFT")
powerBarFill:SetWidth(1)
powerBarFill:SetColorTexture(0.2, 0.55, 1.0, 0.95)

panelShadow = btn:CreateTexture(nil, "BORDER")
panelShadow:SetPoint("TOPLEFT", -8, 8)
panelShadow:SetPoint("BOTTOMRIGHT", 8, -8)
panelShadow:SetColorTexture(0, 0, 0, 0.35)
panelShadow:Hide()

optionsPanel = nil
settingsCategory = nil
settingsBridgePanel = nil
function GetClassColor()
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[PLAYER_CLASS]
    if c then return c.r, c.g, c.b end
    return 0.95, 0.82, 0.15
end

function ApplyVisualTheme()
    local cr, cg, cb = GetClassColor()
    classText:SetTextColor(cr, cg, cb)
    border:SetVertexColor(0.42, 0.48, 0.52, 0.95)
    if advisor.iconBorder then advisor.iconBorder:SetVertexColor(0.42, 0.48, 0.52, 0.95) end
    -- v1.27.2: CoreShell border is alert-only. Normal/pull/buff states stay borderless.
    HCOB_SetRectBorderColor(HCOB_CoreShell, 0, 0, 0, 0)
    dpsValue:SetTextColor(0.72, 0.90, 1.0)
    if HCOB.UI.ActionPanel and HCOB.UI.ActionPanel.title then HCOB.UI.ActionPanel.title:SetTextColor(math.min(1,cr+0.18),math.min(1,cg+0.18),math.min(1,cb+0.18)) end
    label:SetTextColor(1, 0.97, 0.86)
    hint:SetTextColor(0.6, 0.84, 1)
    resourceText:SetTextColor(1, 1, 1)
    hpText:SetTextColor(1, 1, 1)
    panelShadow:Show()
end

function ApplyHUDScale()
    -- Scaling protected buttons while combat-locked can be rejected/taint-prone.
    -- Options already open only out of combat, but keep this helper safe for
    -- slash commands and any future callers. The saved value is applied on the
    -- next out-of-combat RefreshButtonState().
    if InCombatLockdown and InCombatLockdown() then
        pendingHUDScale = true
        return false
    end

    local hudScale = Clamp(tonumber(HCOB_DB.scale) or 1.0, 0.70, 1.60)
    local actionFactor = Clamp(tonumber(HCOB_DB.actionScale) or 1.0, 0.80, 1.50)
    local actionEffectiveScale = hudScale * actionFactor

    btn:SetScale(hudScale)
    HCOB_CoreShell:SetScale(hudScale)
    advisor:SetScale(hudScale)
    dpsMeter:SetScale(hudScale)

    -- The Fixed Action Panel is part of the combat HUD. actionScale remains an
    -- optional *relative* fine-tuning factor, but the main HUD scale always
    -- affects it. This fixes the old split where changing HUD scale resized
    -- BASE/Advisor while leaving the action palette at a different size.
    if HCOB.UI.ActionPanel and HCOB.UI.ActionPanel.frame then
        HCOB.UI.ActionPanel.frame:SetScale(actionEffectiveScale)
        for _, ab in ipairs(HCOB.UI.ActionPanel.buttons or {}) do
            if ab then ab:SetScale(actionEffectiveScale) end
        end
    end

    -- Profession Coach is visually attached to the combat HUD and follows the
    -- primary HUD scale. It deliberately does not inherit the Action Panel's
    -- optional relative multiplier.
    if HCOB.Systems and HCOB.Systems.ProfessionCoach and HCOB.Systems.ProfessionCoach.ApplyHUDScale then
        HCOB.Systems.ProfessionCoach.ApplyHUDScale(hudScale)
    end

    -- DiagnosticPixel intentionally stays unscaled (currently 8x8) for the external reader.
    pendingHUDScale = false
    return true
end

function RefreshButtonState()
    ApplyHUDScale()
    if HCOB_DB.visible then btn:Show() else btn:Hide() end
    if HCOB_DB.visible and HCOB_DB.showAdvisor ~= false then HCOB_CoreShell:Show() else HCOB_CoreShell:Hide() end
    -- Advisor/DPS are not secure: they can be shown/hidden without
    -- touching the button protected attributes.
    if HCOB_DB.visible and HCOB_DB.showAdvisor ~= false then advisor:Show() else advisor:Hide() end
    if HCOB_DB.visible and HCOB_DB.showDPSMeter ~= false then dpsMeter:Show() else dpsMeter:Hide() end
    if HCOB.UI.ActionPanel then HCOB.UI.ActionPanel.SyncVisibility() end
    if HCOB_DB.visible and HCOB_DB.diagPixel ~= false then diagPixel:Show() else diagPixel:Hide() end
    if HCOB_DB.locked then
        label:SetTextColor(1, 0.97, 0.86)
    end
end


function RecentDPSAverage(limit)
    local fights = HCOB_CombatLog and HCOB_CombatLog.fights or {}
    local need = tonumber(limit) or 5
    local damage, duration, count = 0, 0, 0
    -- Prefer fights from the current addon version so old experimental builds
    -- do not pollute the small meter. Fall back to any recent fights if needed.
    for pass=1,2 do
        damage, duration, count = 0, 0, 0
        for i=#fights,1,-1 do
            local f = fights[i]
            if pass == 2 or f.addonVersion == VERSION then
                local d = tonumber(f.totalDamage) or 0
                local t = tonumber(f.duration) or 0
                if t > 0 then
                    damage = damage + d
                    duration = duration + t
                    count = count + 1
                    if count >= need then break end
                end
            end
        end
        if count > 0 then break end
    end
    return duration > 0 and damage / duration or 0, count
end

function UpdateDPSMeter()
    if HCOB_DB.showDPSMeter == false or not HCOB_DB.visible then
        dpsMeter:Hide()
        return
    end
    dpsMeter:Show()
    local avg5, avgCount = RecentDPSAverage(5)
    if currentFight then
        local elapsed = math.max(0.05, GetTime() - (currentFight.startClock or GetTime()))
        local damage = (tonumber(currentFight.damageDone) or 0) + (tonumber(currentFight.petDamage) or 0)
        local dps = damage / elapsed
        dpsValue:SetText(string.format("DPS %.1f", dps))
        dpsMeta:SetText(string.format("AVG%d %.1f | DMG %d | %.1fs", math.max(1, avgCount), avg5, damage, elapsed))
    else
        local fights = HCOB_CombatLog and HCOB_CombatLog.fights or {}
        local last = fights[#fights]
        if last then
            dpsValue:SetText(string.format("LAST %.1f", tonumber(last.dps) or 0))
            dpsMeta:SetText(string.format("AVG%d %.1f | DMG %d | %.1fs", math.max(1, avgCount), avg5, tonumber(last.totalDamage) or 0, tonumber(last.duration) or 0))
        else
            dpsValue:SetText("DPS --")
            dpsMeta:SetText("AVG5 -- | DMG 0 | 0.0s")
        end
    end
end


btn:SetScript("OnDragStart", function(self) if not InCombatLockdown() and not HCOB_DB.locked then self:StartMoving() end end)
btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, px, py = self:GetPoint(1)
    HCOB_DB.x, HCOB_DB.y = px, py
end)

function ModifierLine(key, value)
    if value and value ~= "" then return key .. ": " .. value end
end

btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local localizedClass = UnitClass("player") or PLAYER_CLASS
    local specIndex, specName = TalentSpec()
    GameTooltip:AddLine("HC One Button v" .. VERSION)
    GameTooltip:AddLine(localizedClass .. " L" .. PlayerLevel() .. " - " .. tostring(specName) .. " (tree " .. specIndex .. ")", 1, 1, 1)
    GameTooltip:AddLine("SPAM: safe base action. Advisor: situational spell to cast manually.", 0.3, 1, 0.3, true)
    if currentMods and currentMods.desc then
        local d = currentMods.desc
        GameTooltip:AddLine(ModifierLine("SHIFT", d.shift) or "", 0.8,0.8,0.8, true)
        GameTooltip:AddLine(ModifierLine("CTRL", d.ctrl) or "", 0.8,0.8,0.8, true)
        GameTooltip:AddLine(ModifierLine("ALT", d.alt) or "", 0.8,0.8,0.8, true)
        GameTooltip:AddLine(ModifierLine("CTRL+SHIFT", d.ctrlshift) or "", 0.8,0.8,0.8, true)
        GameTooltip:AddLine(ModifierLine("ALT+SHIFT", d.altshift) or "", 0.8,0.8,0.8, true)
        GameTooltip:AddLine(ModifierLine("ALT+CTRL", d.altctrl) or "", 0.8,0.8,0.8, true)
        GameTooltip:AddLine(ModifierLine("ALL MODS", d.all) or "", 0.8,0.8,0.8, true)
    end
    GameTooltip:AddLine("/hcob help", 0.7,0.7,0.7)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
btn:HookScript("PostClick", function(self, mouseButton, down)
    if currentFight and mouseButton == "LeftButton" then
        currentFight.baseClicks = (tonumber(currentFight.baseClicks) or 0) + 1
    end
end)

