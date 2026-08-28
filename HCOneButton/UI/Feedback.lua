-- HCOneButton in-game feedback/report window.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

HCOB.UI.Feedback = HCOB.UI.Feedback or {}
local UI = HCOB.UI.Feedback

local function CountLines(text)
    local n = 1
    for _ in tostring(text or ""):gmatch("\n") do n = n + 1 end
    return n
end

local function SetReportText(frame, text, selectAll)
    frame.reportEdit:SetText(text or "")
    frame.reportEdit:SetHeight(math.max(330, CountLines(text) * 14 + 24))
    if frame.reportScroll.UpdateScrollChildRect then frame.reportScroll:UpdateScrollChildRect() end
    frame.reportScroll:SetVerticalScroll(0)
    frame.status:SetText("Report generated. Click 'Select report', then press Ctrl+C and paste it into a new CurseForge issue.")
    if selectAll then
        frame.reportEdit:SetFocus()
        frame.reportEdit:HighlightText()
    end
end

local function DetailedChecked(frame)
    return frame.detailedCheck and frame.detailedCheck:GetChecked() and true or false
end

local function Generate(frame, mode)
    local feedback = HCOB.Systems and HCOB.Systems.Feedback
    mode = mode == "doctor" and "doctor" or (mode == "recent" and "recent" or "last")
    if not feedback or (mode == "doctor" and not feedback.GenerateDoctorReport) or (mode ~= "doctor" and not feedback.GenerateReport) then
        frame.status:SetText("Feedback system unavailable. Try /reload.")
        return
    end
    frame.reportMode = mode
    if frame.regenerateButton then frame.regenerateButton:SetText(mode == "doctor" and "Refresh Doctor" or "Refresh Last Fight") end
    if frame.heading then frame.heading:SetText(mode == "doctor" and "HCOneButton Doctor" or "Report a Problem / Send Feedback") end
    if frame.detailedCheck and frame.detailedCheck.SetEnabled then frame.detailedCheck:SetEnabled(mode ~= "doctor") end
    if mode == "doctor" then
        SetReportText(frame, feedback.GenerateDoctorReport(), false)
        frame.status:SetText("Read-only Doctor snapshot generated. Select the report and press Ctrl+C to share it.")
    else
        SetReportText(frame, feedback.GenerateReport(mode, DetailedChecked(frame)), false)
    end
end

function UI.Create()
    if UI.frame then return UI.frame end

    local frame = CreateFrame("Frame", "HCOneButtonFeedbackPanel", UIParent, "BasicFrameTemplateWithInset")
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
    if frame.TitleText then frame.TitleText:SetText("HC One Button - Report a Problem") end

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -38)
    title:SetText("Report a Problem / Send Feedback")
    frame.heading = title

    local intro = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    intro:SetWidth(730)
    intro:SetJustifyH("LEFT")
    intro:SetText("1) Reproduce the issue and finish the fight.  2) Generate a report below.  3) Select it and press Ctrl+C.  4) Open the CurseForge Issues page, create a new issue and paste the report. HCOneButton cannot open your browser or copy to the system clipboard automatically.")

    local urlLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    urlLabel:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -14)
    urlLabel:SetText("CurseForge Issues:")

    local urlEdit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    urlEdit:SetSize(560, 24)
    urlEdit:SetPoint("LEFT", urlLabel, "RIGHT", 10, 0)
    urlEdit:SetAutoFocus(false)
    urlEdit:SetText((HCOB.Systems.Feedback and HCOB.Systems.Feedback.GetIssueURL and HCOB.Systems.Feedback.GetIssueURL()) or "https://www.curseforge.com/wow/addons/hconebutton/issues")
    urlEdit:SetCursorPosition(0)
    urlEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    urlEdit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    frame.urlEdit = urlEdit

    local selectURL = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectURL:SetSize(105, 24)
    selectURL:SetPoint("TOPLEFT", urlLabel, "BOTTOMLEFT", 0, -10)
    selectURL:SetText("Select URL")
    selectURL:SetScript("OnClick", function()
        urlEdit:SetFocus(); urlEdit:HighlightText()
        frame.status:SetText("URL selected. Press Ctrl+C, then paste it into your browser.")
    end)

    local lastBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    lastBtn:SetSize(165, 26)
    lastBtn:SetPoint("LEFT", selectURL, "RIGHT", 12, 0)
    lastBtn:SetText("Generate Last Fight")
    lastBtn:SetScript("OnClick", function() Generate(frame, "last") end)

    local recentBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    recentBtn:SetSize(165, 26)
    recentBtn:SetPoint("LEFT", lastBtn, "RIGHT", 8, 0)
    recentBtn:SetText("Generate Recent Fights")
    recentBtn:SetScript("OnClick", function() Generate(frame, "recent") end)

    local detailed = CreateFrame("CheckButton", nil, frame, "InterfaceOptionsCheckButtonTemplate")
    detailed:SetPoint("LEFT", recentBtn, "RIGHT", 12, 0)
    detailed.Text:SetText("Detailed telemetry")
    detailed:SetChecked(false)
    detailed.tooltipText = "Include the complete stored Advisor trace, top candidate scores and ability telemetry. Personal character/realm data is not exported."
    frame.detailedCheck = detailed

    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", selectURL, "BOTTOMLEFT", 0, -10)
    status:SetWidth(720)
    status:SetJustifyH("LEFT")
    status:SetText("Generate a report after the problematic fight. Last Fight is usually best for an Advisor bug report.")
    frame.status = status

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -42, 66)
    frame.reportScroll = scroll

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    edit:SetWidth(704)
    edit:SetHeight(330)
    edit:SetTextInsets(8, 8, 8, 8)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnTextChanged", function(self)
        self:SetHeight(math.max(330, CountLines(self:GetText()) * 14 + 24))
        if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    end)
    scroll:SetScrollChild(edit)
    frame.reportEdit = edit

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", scroll, "TOPLEFT", -5, 5)
    bg:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 25, -5)
    bg:SetColorTexture(0.02, 0.02, 0.025, 0.82)

    local selectReport = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectReport:SetSize(170, 26)
    selectReport:SetPoint("BOTTOMLEFT", 22, 24)
    selectReport:SetText("Select Report (Ctrl+C)")
    selectReport:SetScript("OnClick", function()
        edit:SetFocus(); edit:HighlightText()
        status:SetText("Report selected. Press Ctrl+C, open CurseForge Issues, create a new issue and press Ctrl+V.")
    end)

    local regenerate = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    regenerate:SetSize(140, 26)
    regenerate:SetPoint("LEFT", selectReport, "RIGHT", 10, 0)
    regenerate:SetText("Refresh Last Fight")
    regenerate:SetScript("OnClick", function() Generate(frame, frame.reportMode or "last") end)
    frame.regenerateButton = regenerate

    local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    close:SetSize(100, 26)
    close:SetPoint("BOTTOMRIGHT", -22, 24)
    close:SetText("Close")
    close:SetScript("OnClick", function()
        edit:ClearFocus(); urlEdit:ClearFocus()
        local windows = HCOB.UI and HCOB.UI.WindowManager
        if windows and windows.Close then windows.Close("feedback") else frame:Hide() end
    end)
    frame.closeButton = close

    frame:SetScript("OnHide", function() edit:ClearFocus(); urlEdit:ClearFocus() end)
    frame:SetScript("OnShow", function(self)
        if not self.reportEdit:GetText() or self.reportEdit:GetText() == "" then Generate(self, "last") end
    end)

    UI.frame = frame
    if HCOB.UI and HCOB.UI.WindowManager and HCOB.UI.WindowManager.Register then
        HCOB.UI.WindowManager.Register("feedback", frame)
    end
    return frame
end

function UI.Open(mode, fromOptions)
    local frame = UI.Create()
    if frame.closeButton then frame.closeButton:SetText(fromOptions and "Back to Options" or "Close") end
    local windows = HCOB.UI and HCOB.UI.WindowManager
    if windows and windows.Open then
        if fromOptions then windows.OpenChild("feedback", "options") else windows.Open("feedback") end
    else
        frame:Show()
        frame:Raise()
    end
    Generate(frame, mode == "doctor" and "doctor" or (mode == "recent" and "recent" or "last"))
end

function UI.Generate(mode, detailed)
    local frame = UI.Create()
    frame.detailedCheck:SetChecked(detailed and true or false)
    if frame.closeButton then frame.closeButton:SetText("Close") end
    local windows = HCOB.UI and HCOB.UI.WindowManager
    if windows and windows.Open then windows.Open("feedback") else frame:Show(); frame:Raise() end
    Generate(frame, mode == "doctor" and "doctor" or (mode == "recent" and "recent" or "last"))
end
