-- Visual inspector for per-character Local Adaptive Tuning.
-- Viewing preferences and the explicit two-step reset are the only writes.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

HCOB.UI.AdaptiveTuning = HCOB.UI.AdaptiveTuning or {}
local UI = HCOB.UI.AdaptiveTuning

local ROW_HEIGHT = 54
local BAR_HALF_WIDTH = 104

function UI.SituationLabel(key)
    if not key then return "Awaiting comparable choices" end
    local enemies, resource, phase = tostring(key):match("^(%a+):(%a+):(%a+)$")
    if not enemies then return "Recorded situation" end
    return (enemies == "multi" and "2+ targets" or "1 target") .. " / "
        .. (resource == "low" and "low" or (resource == "high" and "high" or "mid"))
        .. " resource / " .. (phase == "finish" and "<=30% HP" or ">30% HP")
end

local function Finite(value, fallback)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return fallback end
    return value
end

local function SpellTexture(spellId)
    if spellId and C_Spell and C_Spell.GetSpellTexture then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellId)
        if ok and texture then return texture end
    end
    if spellId and GetSpellTexture then
        local ok, texture = pcall(GetSpellTexture, spellId)
        if ok and texture then return texture end
    end
    return 134400 -- INV_Misc_QuestionMark
end

local function AddSolid(parent, layer, r, g, b, a)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetColorTexture(r, g, b, a)
    return texture
end

local function StatusFor(model)
    if model.learningSupported == false then return "NOT SUPPORTED", 0.70, 0.72, 0.76 end
    if not model.enabled then return "DISABLED", 0.55, 0.58, 0.62 end
    if not model.contextAvailable then return "NO CONTEXT", 0.95, 0.60, 0.24 end
    if not model.ready then return "CALIBRATING", 1.00, 0.78, 0.22 end
    if (model.activeAdjustments or 0) > 0 then return "ADAPTED", 0.18, 0.95, 0.64 end
    return "READY · BASELINE", 0.35, 0.82, 1.00
end

local function ContextLabel(model)
    local spec = model.specName and model.specName ~= "" and model.specName
        or ((model.specIndex or 0) > 0 and ("Spec " .. model.specIndex) or "No specialization")
    local levelStart = math.max(1, math.floor(Finite(model.levelBand, 1) or 1))
    return string.format("%s  ·  %s  ·  Levels %d–%d  ·  %s",
        tostring(model.class or "?"), tostring(spec), levelStart, levelStart + 4,
        tostring(model.mode or "solo"):upper())
end

function UI.FilterArms(model, activeOnly)
    local result = {}
    for _, arm in ipairs(model and model.arms or {}) do
        if not activeOnly or arm.active then result[#result + 1] = arm end
    end
    return result
end

local function EnsureRow(frame, index)
    local row = frame.rows[index]
    if row then return row end

    row = CreateFrame("Frame", nil, frame.rowContent)
    row:SetSize(690, ROW_HEIGHT - 2)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:EnableMouse(true)

    row.background = AddSolid(row, "BACKGROUND", 0.055, 0.065, 0.085, index % 2 == 0 and 0.88 or 0.68)
    row.background:SetAllPoints()
    row.accent = AddSolid(row, "BORDER", 0.16, 0.80, 0.62, 0.85)
    row.accent:SetPoint("TOPLEFT", 0, 0)
    row.accent:SetPoint("BOTTOMLEFT", 0, 0)
    row.accent:SetWidth(3)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(34, 34)
    row.icon:SetPoint("LEFT", 10, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", 54, -8)
    row.name:SetWidth(205)
    row.name:SetJustifyH("LEFT")

    row.meta = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.meta:SetPoint("TOPLEFT", 54, -28)
    row.meta:SetWidth(215)
    row.meta:SetJustifyH("LEFT")
    row.meta:SetTextColor(0.62, 0.66, 0.72)

    row.bar = CreateFrame("Frame", nil, row)
    row.bar:SetSize(BAR_HALF_WIDTH * 2, 14)
    row.bar:SetPoint("LEFT", 278, 1)
    row.bar.background = AddSolid(row.bar, "BACKGROUND", 0.018, 0.022, 0.030, 0.95)
    row.bar.background:SetAllPoints()
    row.bar.negative = AddSolid(row.bar, "ARTWORK", 0.92, 0.29, 0.30, 0.90)
    row.bar.positive = AddSolid(row.bar, "ARTWORK", 0.12, 0.88, 0.62, 0.90)
    row.bar.center = AddSolid(row.bar, "OVERLAY", 1.00, 0.82, 0.24, 0.95)
    row.bar.center:SetPoint("TOP", 0, 2)
    row.bar.center:SetPoint("BOTTOM", 0, -2)
    row.bar.center:SetWidth(2)

    row.delta = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.delta:SetPoint("LEFT", 500, 1)
    row.delta:SetWidth(76)
    row.delta:SetJustifyH("CENTER")

    row.evidence = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.evidence:SetPoint("LEFT", 580, 1)
    row.evidence:SetWidth(100)
    row.evidence:SetJustifyH("CENTER")

    row:SetScript("OnEnter", function(self)
        if not GameTooltip or not self.arm then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.arm.title or "Adaptive action", 1, 0.82, 0.2)
        GameTooltip:AddLine(self.arm.policy or "Base eligibility rules remain unchanged.", 0.82, 0.84, 0.88, true)
        GameTooltip:AddLine("Situation: " .. UI.SituationLabel(self.arm.situation), 0.82, 0.84, 0.88, true)
        GameTooltip:AddLine("Resource: low <=35%, high >=80%. HP phase refers to the target.", 0.72, 0.76, 0.82, true)
        GameTooltip:AddLine("Chosen vs another available action, in distinct fights. Observational evidence, not proven DPS gain.", 0.72, 0.76, 0.82, true)
        GameTooltip:AddLine(string.format("Local correction: %+.2f / ±%.0f", self.arm.bias or 0, self.maxBias or 12), 0.25, 0.95, 0.68)
        GameTooltip:AddLine(string.format("Outcomes: %d · accepted: %d · alternatives: %d", self.arm.fights or 0, self.arm.accepted or 0, self.arm.userOverrides or 0), 0.72, 0.76, 0.82)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    frame.rows[index] = row
    return row
end

local function RefreshRow(row, arm, maxBias, index)
    local bias = Finite(arm.bias, 0) or 0
    maxBias = math.max(0.25, Finite(maxBias, 12) or 12)
    row.arm, row.maxBias = arm, maxBias
    row.icon:SetTexture(SpellTexture(arm.spellId))
    row.name:SetText(arm.title or "Unknown action")
    row.meta:SetText(arm.protected and ("FIXED: " .. tostring(arm.tag or "action"))
        or UI.SituationLabel(arm.situation))
    row.evidence:SetText(string.format("%d chosen\n%d alternative", arm.chosenFights or 0, arm.otherFights or 0))
    row.delta:SetText(arm.protected and "FIXED" or string.format("%+.2f", bias))
    if bias > 0 then row.delta:SetTextColor(0.18, 0.95, 0.65)
    elseif bias < 0 then row.delta:SetTextColor(1.00, 0.38, 0.36)
    else row.delta:SetTextColor(0.66, 0.69, 0.74) end

    row.bar.positive:ClearAllPoints()
    row.bar.negative:ClearAllPoints()
    row.bar.positive:Hide()
    row.bar.negative:Hide()
    local width = math.max(1, math.min(BAR_HALF_WIDTH, math.abs(bias) / maxBias * BAR_HALF_WIDTH))
    if bias > 0 then
        row.bar.positive:SetPoint("TOPLEFT", row.bar, "TOP", 1, -1)
        row.bar.positive:SetPoint("BOTTOMLEFT", row.bar, "BOTTOM", 1, 1)
        row.bar.positive:SetWidth(width)
        row.bar.positive:Show()
    elseif bias < 0 then
        row.bar.negative:SetPoint("TOPRIGHT", row.bar, "TOP", -1, -1)
        row.bar.negative:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOM", -1, 1)
        row.bar.negative:SetWidth(width)
        row.bar.negative:Show()
    end
    row.accent:SetColorTexture(bias > 0 and 0.12 or (bias < 0 and 0.92 or 0.38),
        bias > 0 and 0.88 or (bias < 0 and 0.29 or 0.42),
        bias > 0 and 0.62 or (bias < 0 and 0.30 or 0.48), 0.9)
    row.background:SetColorTexture(0.055, 0.065, 0.085, index % 2 == 0 and 0.88 or 0.68)
    row:Show()
end

local function DisarmReset(frame)
    frame.resetArmedUntil = nil
    if frame.resetButton then frame.resetButton:SetText("Reset Learning") end
end

local function ClearRows(frame)
    frame.model = nil
    frame.stateText:SetText("UNAVAILABLE")
    frame.stateText:SetTextColor(0.95, 0.60, 0.24)
    frame.stateAccent:SetColorTexture(0.95, 0.60, 0.24, 0.92)
    frame.accountText:SetText("No learned data were changed.")
    frame.progress:SetValue(0)
    frame.progressText:SetText("Data unavailable")
    for _, row in ipairs(frame.rows or {}) do row:Hide() end
    if frame.rowContent then frame.rowContent:SetHeight(1) end
    if frame.scroll then
        frame.scroll:SetVerticalScroll(0)
        if frame.scroll.UpdateScrollChildRect then frame.scroll:UpdateScrollChildRect() end
    end
end

function UI.Refresh()
    local frame = UI.frame
    if not frame then return end
    local tuner = HCOB.Systems and HCOB.Systems.AdaptiveTuner
    if not tuner or not tuner.GetDisplayModel then
        ClearRows(frame)
        frame.contextText:SetText("Adaptive learner unavailable")
        frame.summaryText:SetText("Try /reload. No SavedVariables were changed.")
        frame.emptyText:SetText("Unable to read Local Adaptive Tuning data.")
        frame.emptyText:Show()
        return
    end

    local ok, model = pcall(tuner.GetDisplayModel)
    if not ok or type(model) ~= "table" then
        ClearRows(frame)
        frame.contextText:SetText("Adaptive data unavailable")
        frame.summaryText:SetText("The inspector failed closed; gameplay priorities were not changed.")
        frame.emptyText:SetText("Unable to build the current tuning view.")
        frame.emptyText:Show()
        return
    end
    frame.model = model
    for profile, button in pairs(frame.profileButtons or {}) do
        if profile == model.viewProfile then button:Disable() else button:Enable() end
    end

    local viewSignature = tostring(model.contextKey or "none") .. ":" .. tostring(frame.activeOnly == true)
    if frame.viewSignature ~= viewSignature then
        frame.viewSignature = viewSignature
        frame.scroll:SetVerticalScroll(0)
    end

    local status, r, g, b = StatusFor(model)
    frame.contextText:SetText(ContextLabel(model))
    frame.stateText:SetText(status)
    frame.stateText:SetTextColor(r, g, b)
    frame.stateAccent:SetColorTexture(r, g, b, 0.92)
    frame.summaryText:SetText(string.format(
        "%d/%d eligible fights in this context  ·  %d observed actions  ·  %d learned corrections",
        model.fights or 0, model.minContextFights or 8, model.learnedActions or 0, model.activeAdjustments or 0))
    if model.learningSupported == false then
        frame.summaryText:SetText("Viewing PvP only. Learning and priority corrections are not supported for this profile.")
    end
    local impact = model.impact or {}
    frame.accountText:SetText(string.format(
        "Choices changed: %d / %d\nExecuted: %d\nObserved impact, not DPS gain",
        impact.changed or 0, impact.evaluated or 0, impact.executed or 0))

    local minimum = math.max(1, model.minContextFights or 8)
    frame.progress:SetMinMaxValues(0, minimum)
    frame.progress:SetValue(math.min(minimum, model.fights or 0))
    frame.progressText:SetText(model.learningSupported == false and "PvP learning not supported"
        or (model.ready and "Context ready; each situation needs 4 chosen + 4 alternative fights"
            or string.format("Calibration %d/%d", model.fights or 0, minimum)))

    local arms = UI.FilterArms(model, frame.activeOnly == true)
    for index, arm in ipairs(arms) do RefreshRow(EnsureRow(frame, index), arm, model.maxBias, index) end
    for index=#arms + 1,#frame.rows do frame.rows[index]:Hide() end
    frame.rowContent:SetHeight(math.max(1, #arms * ROW_HEIGHT))
    if frame.scroll.UpdateScrollChildRect then frame.scroll:UpdateScrollChildRect() end

    if #arms == 0 then
        if model.learningSupported == false then
            frame.emptyText:SetText("PvP learning is not supported.\nThis tab is a separate view, not a gameplay switch.\nPvP fights are excluded; Normal (PvE) corrections are never reused here.")
        elseif frame.activeOnly and #(model.arms or {}) > 0 then
            frame.emptyText:SetText("No active corrections in this context. Disable the filter to see calibration evidence.")
        elseif not model.contextAvailable then
            frame.emptyText:SetText("The current class/build context is unavailable. Close the window and try /reload.")
        elseif (model.fights or 0) == 0 then
            frame.emptyText:SetText("No eligible fights for the current build, level band and solo/group context yet.\nOther saved contexts are preserved, not applied here.\nPlay normally with Combat logger enabled to calibrate this context.")
        else
            frame.emptyText:SetText("No spell opportunities have been recorded in this context yet.")
        end
        frame.emptyText:Show()
    else
        frame.emptyText:Hide()
    end

    frame.protectedText:SetText(string.format(
        "|cff4fe6b0SAFETY FIRST|r  Emergencies stay fixed. Recovery/control are protected under pressure. Cast, range and aura rules are unchanged.  ·  %d fixed action%s observed",
        model.protectedObserved or 0, (model.protectedObserved or 0) == 1 and "" or "s"))
end

function UI.Create()
    if UI.frame then return UI.frame end

    local frame = CreateFrame("Frame", "HCOneButtonAdaptiveTuningPanel", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(780, 680)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()
    if frame.TitleText then frame.TitleText:SetText("HC One Button - Local Adaptive Tuning") end

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -36)
    title:SetText("Local Adaptive Tuning")

    local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
    subtitle:SetWidth(730)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Local comparisons for this build. Every learned situation stays visible; fixed actions explain their protection. No random exploration.")

    frame.profileButtons = {}
    for index, profile in ipairs({"pve", "pvp"}) do
        local viewProfile = profile
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(140, 26)
        button:SetPoint("TOPLEFT", 22 + (index - 1) * 148, -88)
        button:SetText(profile == "pve" and "Normal (PvE)" or "PvP")
        button:SetScript("OnClick", function()
            local tuner = HCOB.Systems and HCOB.Systems.AdaptiveTuner
            if tuner and tuner.SetViewProfile and tuner.SetViewProfile(viewProfile) then
                DisarmReset(frame)
                UI.Refresh()
            end
        end)
        frame.profileButtons[profile] = button
    end
    local viewHint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    viewHint:SetPoint("TOPLEFT", 324, -95)
    viewHint:SetWidth(430)
    viewHint:SetJustifyH("LEFT")
    viewHint:SetText("View only. Selecting a target never switches tabs.")

    local card = CreateFrame("Frame", nil, frame)
    card:SetPoint("TOPLEFT", 22, -129)
    card:SetSize(736, 112)
    card.background = AddSolid(card, "BACKGROUND", 0.025, 0.038, 0.052, 0.96)
    card.background:SetAllPoints()
    frame.stateAccent = AddSolid(card, "BORDER", 0.18, 0.95, 0.64, 0.92)
    frame.stateAccent:SetPoint("TOPLEFT", 0, 0)
    frame.stateAccent:SetPoint("BOTTOMLEFT", 0, 0)
    frame.stateAccent:SetWidth(5)

    frame.contextText = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.contextText:SetPoint("TOPLEFT", 18, -14)
    frame.contextText:SetWidth(520)
    frame.contextText:SetJustifyH("LEFT")

    frame.stateText = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.stateText:SetPoint("TOPRIGHT", -18, -14)
    frame.stateText:SetWidth(160)
    frame.stateText:SetJustifyH("RIGHT")

    frame.summaryText = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.summaryText:SetPoint("TOPLEFT", frame.contextText, "BOTTOMLEFT", 0, -11)
    frame.summaryText:SetWidth(690)
    frame.summaryText:SetJustifyH("LEFT")

    frame.progress = CreateFrame("StatusBar", nil, card)
    frame.progress:SetPoint("BOTTOMLEFT", 18, 17)
    frame.progress:SetSize(470, 15)
    frame.progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    frame.progress:SetStatusBarColor(0.16, 0.82, 0.61, 0.95)
    local progressBG = AddSolid(frame.progress, "BACKGROUND", 0.01, 0.015, 0.022, 0.95)
    progressBG:SetAllPoints()
    frame.progressText = frame.progress:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.progressText:SetPoint("CENTER", 0, 0)

    frame.accountText = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.accountText:SetPoint("LEFT", frame.progress, "RIGHT", 16, 0)
    frame.accountText:SetWidth(220)
    frame.accountText:SetJustifyH("LEFT")
    frame.accountText:SetTextColor(0.58, 0.63, 0.70)

    local section = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    section:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 2, -18)
    section:SetText("SITUATIONAL PRIORITIES")

    frame.activeFilter = CreateFrame("CheckButton", nil, frame, "InterfaceOptionsCheckButtonTemplate")
    frame.activeFilter:SetPoint("TOPRIGHT", -194, -257)
    frame.activeFilter.Text:SetText("Active only")
    frame.activeFilter:SetChecked(false)
    frame.activeFilter.tooltipText = "Hide zero-bias actions. Learned corrections apply only when tuning is enabled and the gameplay context is eligible."
    frame.activeFilter:SetScript("OnClick", function(self)
        frame.activeOnly = self:GetChecked() and true or false
        DisarmReset(frame)
        UI.Refresh()
    end)

    local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refresh:SetSize(104, 24)
    refresh:SetPoint("TOPRIGHT", -24, -260)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function() DisarmReset(frame); UI.Refresh() end)

    frame.legendText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.legendText:SetPoint("TOPLEFT", 26, -293)
    frame.legendText:SetWidth(728)
    frame.legendText:SetJustifyH("LEFT")
    frame.legendText:SetText("|cffff615cLeft (-)|r: lower priority  ·  |cffffd134Center (0)|r: unchanged baseline  ·  |cff2ee6a6Right (+)|r: higher priority\nScore points, not damage %. Each row is a learned situation; safety rules remain unchanged.")

    local actionHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    actionHeader:SetPoint("TOPLEFT", 78, -330)
    actionHeader:SetText("ACTION / EVIDENCE")
    local correctionHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    correctionHeader:SetPoint("TOPLEFT", 304, -330)
    correctionHeader:SetText("−12       BASE POLICY       +12")
    local outcomesHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    outcomesHeader:SetPoint("TOPRIGHT", -57, -330)
    outcomesHeader:SetText("COMPARISONS")

    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 24, -348)
    frame.scroll:SetPoint("BOTTOMRIGHT", -46, 102)
    frame.rowContent = CreateFrame("Frame", nil, frame.scroll)
    frame.rowContent:SetSize(690, 1)
    frame.scroll:SetScrollChild(frame.rowContent)
    frame.rows = {}

    local scrollBG = AddSolid(frame, "BACKGROUND", 0.012, 0.017, 0.024, 0.86)
    scrollBG:SetPoint("TOPLEFT", frame.scroll, "TOPLEFT", -4, 4)
    scrollBG:SetPoint("BOTTOMRIGHT", frame.scroll, "BOTTOMRIGHT", 24, -4)

    frame.emptyText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.emptyText:SetPoint("CENTER", frame.scroll, "CENTER", 0, 0)
    frame.emptyText:SetWidth(580)
    frame.emptyText:SetJustifyH("CENTER")
    frame.emptyText:SetTextColor(0.68, 0.72, 0.78)

    frame.protectedText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.protectedText:SetPoint("BOTTOMLEFT", 26, 67)
    frame.protectedText:SetWidth(718)
    frame.protectedText:SetJustifyH("LEFT")

    local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reset:SetSize(132, 26)
    reset:SetPoint("BOTTOMLEFT", 24, 24)
    reset:SetText("Reset Learning")
    reset:SetScript("OnClick", function(self)
        if InCombatLockdown and InCombatLockdown() then
            frame.protectedText:SetText("|cffff5555Reset Local Adaptive Tuning out of combat.|r")
            return
        end
        local now = (GetTime and GetTime()) or 0
        if frame.resetArmedUntil and now <= frame.resetArmedUntil then
            local tuner = HCOB.Systems and HCOB.Systems.AdaptiveTuner
            if tuner and tuner.Reset and tuner.Reset() then
                DisarmReset(frame)
                UI.Refresh()
            end
            return
        end
        frame.resetArmedUntil = now + 5
        self:SetText("Confirm Reset")
        frame.protectedText:SetText("|cffffcc00Click Confirm Reset within 5 seconds to clear this character's learned contexts. Normal combat history is preserved.|r")
    end)
    frame.resetButton = reset

    local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    close:SetSize(134, 26)
    close:SetPoint("BOTTOMRIGHT", -24, 24)
    close:SetText("Back to Options")
    close:SetScript("OnClick", function()
        local windows = HCOB.UI and HCOB.UI.WindowManager
        if windows and windows.Close then windows.Close("adaptive_tuning") else frame:Hide() end
    end)
    frame.closeButton = close

    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent", function(self)
        if not self:IsShown() then return end
        local windows = HCOB.UI and HCOB.UI.WindowManager
        if windows and windows.Close then windows.Close("adaptive_tuning", false) else self:Hide() end
        print("|cffffcc00HCOB:|r Adaptive Tuning details closed because combat started.")
    end)
    frame:SetScript("OnShow", function() DisarmReset(frame); UI.Refresh() end)
    frame:SetScript("OnHide", function() DisarmReset(frame); if GameTooltip then GameTooltip:Hide() end end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.refreshElapsed = (self.refreshElapsed or 0) + elapsed
        if self.refreshElapsed < 1 then return end
        self.refreshElapsed = 0
        -- Preserve the confirmation warning while armed; automatic updates must
        -- neither confirm a reset nor replace its explanation before timeout.
        if self.resetArmedUntil then
            if ((GetTime and GetTime()) or 0) <= self.resetArmedUntil then return end
            DisarmReset(self)
        end
        UI.Refresh()
    end)

    UI.frame = frame
    if UISpecialFrames then table.insert(UISpecialFrames, "HCOneButtonAdaptiveTuningPanel") end
    if HCOB.UI and HCOB.UI.WindowManager and HCOB.UI.WindowManager.Register then
        HCOB.UI.WindowManager.Register("adaptive_tuning", frame)
    end
    return frame
end

function UI.Open(fromOptions)
    if InCombatLockdown and InCombatLockdown() then
        print("|cffffcc00HCOB:|r open Adaptive Tuning details out of combat.")
        return false
    end
    local frame = UI.Create()
    local alreadyShown = frame.IsShown and frame:IsShown()
    if frame.closeButton then frame.closeButton:SetText(fromOptions and "Back to Options" or "Close") end
    local windows = HCOB.UI and HCOB.UI.WindowManager
    if windows and windows.Open then
        if fromOptions then windows.OpenChild("adaptive_tuning", "options") else windows.Open("adaptive_tuning") end
    else
        frame:Show()
        if frame.Raise then frame:Raise() end
    end
    if alreadyShown then UI.Refresh() end
    return true
end
