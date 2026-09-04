-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

HCOB.UI.Options = HCOB.UI.Options or {}
local Options = HCOB.UI.Options

function Options.IsAdaptiveTuningEnabled()
    local tuner = HCOB.Systems and HCOB.Systems.AdaptiveTuner
    return tuner and tuner.IsEnabled and tuner.IsEnabled() or false
end

function Options.SetAdaptiveTuningEnabled(enabled)
    local tuner = HCOB.Systems and HCOB.Systems.AdaptiveTuner
    if not tuner or not tuner.SetEnabled then return false end
    return tuner.SetEnabled(enabled == true)
end

function Options.OpenAdaptiveTuningDetails()
    if InCombatLockdown and InCombatLockdown() then
        print("|cffffcc00HCOB:|r open Adaptive Tuning details out of combat.")
        return false
    end
    local details = HCOB.UI and HCOB.UI.AdaptiveTuning
    if not details or not details.Open then
        print("|cffff5555HCOB:|r Adaptive Tuning details are unavailable. Try /reload.")
        return false
    end
    details.Open(true)
    return true
end

function Center()
    if InCombatLockdown() then print("|cffff5555HCOB:|r center the HUD out of combat."); return end
    btn:ClearAllPoints(); btn:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    SaveHUDPosition(btn); HCOB_DB.visible = true; btn:Show()
end

function Toggle(key, arg)
    if arg ~= "on" and arg ~= "off" then print("|cffffcc00HCOB:|r use on or off."); return end
    HCOB_DB[key] = arg == "on"
    print("|cff00ff98HCOB:|r " .. key .. " = " .. arg)
end

function OpenOptionsPanel()
    if not optionsPanel then
        print("|cffff5555HCOB:|r options panel is not available yet. Try /reload.")
        return
    end
    if InCombatLockdown() then
        print("|cffffcc00HCOB:|r open options out of combat.")
        return
    end
    local windows = HCOB.UI and HCOB.UI.WindowManager
    if windows and windows.Open then
        windows.Open("options")
    else
        optionsPanel:Show()
        optionsPanel:Raise()
    end
end

function OpenBlizzardSettingsPanel()
    if InCombatLockdown() then
        print("|cffffcc00HCOB:|r open settings out of combat.")
        return
    end
    if Settings and Settings.OpenToCategory and settingsCategory then
        local categoryID = settingsCategory.GetID and settingsCategory:GetID() or settingsCategory.ID
        if categoryID then
            local ok = pcall(Settings.OpenToCategory, categoryID)
            if ok then return end
        end
    end
    OpenOptionsPanel()
end

sliderSerial = 0

function CreateCheckBox(parent, labelText, tooltipText, getValue, setValue, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(labelText)
    cb.tooltipText = tooltipText
    cb:SetChecked(getValue())
    cb:SetScript("OnClick", function(self) setValue(self:GetChecked() and true or false) end)
    cb.Refresh = function(self) self:SetChecked(getValue()) end
    return cb
end

function CreateSlider(parent, labelText, minv, maxv, step, getValue, setValue, x, y, lowText, highText, fmt)
    sliderSerial = sliderSerial + 1
    local name = "HCOneButtonSlider" .. sliderSerial
    local sl = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    sl:SetPoint("TOPLEFT", x, y)
    sl:SetWidth(220)
    sl:SetMinMaxValues(minv, maxv)
    sl:SetValueStep(step)
    if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
    local text = _G[name .. "Text"]
    local low = _G[name .. "Low"]
    local high = _G[name .. "High"]
    if text then text:SetText(labelText) end
    if low then low:SetText(lowText or tostring(minv)) end
    if high then high:SetText(highText or tostring(maxv)) end
    sl:SetScript("OnValueChanged", function(self, value)
        value = math.floor((value / step) + 0.5) * step
        if step < 1 then value = math.floor(value * 100 + 0.5) / 100 end
        setValue(value)
        if self.ValueText then self.ValueText:SetText(fmt and fmt:format(value) or tostring(value)) end
    end)
    local val = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    val:SetPoint("TOP", sl, "BOTTOM", 0, 0)
    sl.ValueText = val
    sl.Refresh = function(self)
        self:SetValue(getValue())
        if self.ValueText then self.ValueText:SetText(fmt and fmt:format(getValue()) or tostring(getValue())) end
    end
    sl:Refresh()
    return sl
end

function CreateOptionsPanel()
    if optionsPanel then return end

    -- Standalone window: /hcob options always opens this one, independently
    -- from future changes to the Blizzard Settings API.
    local panel = CreateFrame("Frame", "HCOneButtonOptionsPanel", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(700, 760)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    panel:Hide()

    if panel.TitleText then
        panel.TitleText:SetText("HC One Button - Options")
    end

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -36)
    title:SetText("HC One Button")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
    subtitle:SetWidth(650)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Local addon panel. Changes are automatically saved to SavedVariables.")

    local info = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    info:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -18)
    info:SetText("Appearance and behavior")

    local controls = {}
    local function add(control) table.insert(controls, control); return control end

    add(CreateCheckBox(panel, "Show HUD", "Show or hide the complete HC One Button combat HUD.", function() return HCOB_DB.visible end, function(v) HCOB_DB.visible = v; RefreshButtonState() end, 24, -118))
    add(CreateCheckBox(panel, "Lock position", "Disable button dragging.", function() return HCOB_DB.locked end, function(v) HCOB_DB.locked = v end, 24, -145))
    add(CreateCheckBox(panel, "Alert sounds", "Play sounds for danger and interrupts.", function() return HCOB_DB.soundAlerts end, function(v) HCOB_DB.soundAlerts = v end, 24, -172))
    add(CreateCheckBox(panel, "Show swing timer", "Show the next auto-attack swing bar.", function() return HCOB_DB.showSwing end, function(v) HCOB_DB.showSwing = v; UpdateDisplay() end, 24, -199))
    add(CreateCheckBox(panel, "Smart HUD", "Analyze buffs, target, cooldowns and danger. If an API errors, Smart HUD is disabled for the session without stopping the secure button.", function() return HCOB_DB.smartDisplay ~= false end, function(v) HCOB_DB.smartDisplay = v; if v then runtimeSmartDisabled = false end; UpdateDisplay() end, 24, -226))
    add(CreateCheckBox(panel, "Show Advisor", "Show the right-side panel with the situational spell to cast manually.", function() return HCOB_DB.showAdvisor ~= false end, function(v) HCOB_DB.showAdvisor = v; RefreshButtonState(); UpdateDisplay() end, 24, -253))
    add(CreateCheckBox(panel, "Profession Coach", "Enable the event-driven profession leveling coach. When disabled, its panel stays hidden and profession refresh/scans are suspended.", function()
        local prof = HCOB.Systems and HCOB.Systems.ProfessionCoach
        if prof and prof.IsEnabled then return prof.IsEnabled() end
        return HCOB_DB.profCoach ~= false
    end, function(v)
        local prof = HCOB.Systems and HCOB.Systems.ProfessionCoach
        if prof and prof.SetEnabled then prof.SetEnabled(v) else HCOB_DB.profCoach = v end
    end, 24, -280))
    add(CreateCheckBox(panel, "Pre-pull safety gate", "Require healthy HP/resources/pet state before the Advisor displays PULL READY; warns about missing healing stock on tough targets.", function()
        return HCOB_DB.prePullSafety ~= false
    end, function(v)
        HCOB_DB.prePullSafety = v
        UpdateDisplay()
    end, 24, -307))
    add(CreateCheckBox(panel, "Survival consumables strip", "Show secure click buttons for the best healing potion, Healthstone, mana potion and bandage in your bags.", function()
        return HCOB_DB.showConsumables ~= false
    end, function(v)
        HCOB_DB.showConsumables = v
        if HCOB.UI.SurvivalStrip then HCOB.UI.SurvivalStrip.SyncVisibility() end
        UpdateDisplay()
    end, 24, -334))
    add(CreateCheckBox(panel, "HC danger advisor", "Multi-pull and fight trend: enter CAUTION/DANGER before relying on HP threshold alone.", function() return HCOB_DB.hcDangerAdvisor ~= false end, function(v) HCOB_DB.hcDangerAdvisor = v; UpdateDisplay() end, 350, -82))
    if PLAYER_CLASS == "WARRIOR" then
        -- All class-specific controls live together, including the Rage slider.
        -- This section is never created for another class; saved keys/callbacks
        -- remain unchanged when moving the controls into their own parent.
        local warrior = CreateFrame("Frame", nil, panel)
        warrior:SetPoint("TOPLEFT", 24, -378)
        warrior:SetSize(294, 142)
        local background = warrior:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.055, 0.045, 0.030, 0.90)
        local accent = warrior:CreateTexture(nil, "BORDER")
        accent:SetPoint("TOPLEFT", 0, 0)
        accent:SetPoint("BOTTOMLEFT", 0, 0)
        accent:SetWidth(3)
        accent:SetColorTexture(0.78, 0.61, 0.43, 0.90)
        local heading = warrior:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        heading:SetPoint("TOPLEFT", 12, -12)
        heading:SetText("Warrior - Combat policy")
        add(CreateCheckBox(warrior, "Smart pre-pull Rend", "Out of combat, if the target is equal/near-equal level or elite, prepare one Rend on the opener. Skip trivial mobs.", function() return HCOB_DB.warriorAutoRend ~= false end, function(v) HCOB_DB.warriorAutoRend = v; BuildMacros(); UpdateDisplay() end, 10, -30))
        add(CreateCheckBox(warrior, "Situational Sunder", "Sunder remains in the Advisor against durable targets; it is not spammed at low levels.", function() return HCOB_DB.warriorSunderBase ~= false end, function(v) HCOB_DB.warriorSunderBase = v; BuildMacros(); UpdateDisplay() end, 10, -57))
        add(CreateSlider(warrior, "Heroic Strike rage threshold", 20, 70, 1, function() return HCOB_DB.warriorHeroicRage or 35 end, function(v) HCOB_DB.warriorHeroicRage = v; UpdateDisplay() end, 37, -110, "20", "70", "%d rage"))
        panel.warriorSection = warrior
    end

    local learningTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    learningTitle:SetPoint("TOPLEFT", 350, -372)
    learningTitle:SetText("Combat data and learning")
    add(CreateCheckBox(panel, "Combat logger", "Store compact statistics from recent fights in SavedVariables. Use /hcob log last for a summary.", function() return HCOB_DB.combatLogging ~= false end, function(v) HCOB_DB.combatLogging = v; if not v and currentFight then FinalizeCombatTelemetry("logging_off") end end, 350, -392))

    add(CreateCheckBox(panel, "Mini DPS meter", "Show current and recent average DPS below the Advisor. Requires Combat logger.", function() return HCOB_DB.showDPSMeter ~= false end, function(v) HCOB_DB.showDPSMeter = v; RefreshButtonState(); UpdateDPSMeter() end, 350, -422))

    add(CreateCheckBox(panel, "Local Adaptive Tuning", "Per-character and persisted across reload/logout. Learns only from eligible fights while Combat logger is enabled and applies small bounded offensive adjustments. Healing, survival, control and interrupt winners remain protected.", Options.IsAdaptiveTuningEnabled, Options.SetAdaptiveTuningEnabled, 350, -452))

    local adaptiveDetailsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    adaptiveDetailsBtn:SetSize(210, 25)
    adaptiveDetailsBtn:SetPoint("TOPLEFT", 350, -486)
    adaptiveDetailsBtn:SetText("View learned adjustments...")
    adaptiveDetailsBtn:SetScript("OnClick", Options.OpenAdaptiveTuningDetails)

    local actionBindTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    actionBindTitle:SetPoint("TOPLEFT", 350, -535)
    actionBindTitle:SetText("Fixed Action Panel bindings")
    add(CreateCheckBox(panel, "Auto-apply slot bindings", "Automatically apply and save configured bindings to secure Action panel slots. Warning: configured keys replace existing WoW/addon bindings. Changes are allowed only out of combat.", function() return HCOB_DB.actionSlotAutoBind ~= false end, function(v)
        HCOB_DB.actionSlotAutoBind = v
        if v and HCOB.UI.ActionPanel then HCOB.UI.ActionPanel.ApplySlotBindings() end
    end, 350, -555))

    local actionBindBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    actionBindBtn:SetSize(190, 27)
    actionBindBtn:SetPoint("TOPLEFT", 350, -591)
    actionBindBtn:SetText("Configure slot bindings...")
    actionBindBtn:SetScript("OnClick", function()
        if HCOB.UI.ActionPanel and HCOB.UI.ActionPanel.OpenBindingOptions then HCOB.UI.ActionPanel.OpenBindingOptions(true) end
    end)

    add(CreateSlider(panel, "HUD scale", 0.70, 1.60, 0.05, function() return HCOB_DB.scale or 1 end, function(v) HCOB_DB.scale = v; RefreshButtonState() end, 350, -120, "0.7", "1.6", "%.2f"))
    add(CreateSlider(panel, "Danger HP", 20, 70, 1, function() return HCOB_DB.dangerHP or 35 end, function(v) HCOB_DB.dangerHP = v; UpdateDisplay() end, 350, -183, "20", "70", "%d%%"))
    add(CreateSlider(panel, "Critical HP", 10, 40, 1, function() return HCOB_DB.criticalHP or 20 end, function(v) HCOB_DB.criticalHP = v; UpdateDisplay() end, 350, -246, "10", "40", "%d%%"))
    add(CreateSlider(panel, "Enemy window", 3, 12, 1, function() return HCOB_DB.enemyWindow or 6 end, function(v) HCOB_DB.enemyWindow = v end, 350, -309, "3", "12", "%ds"))

    local centerBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    centerBtn:SetSize(125, 25)
    centerBtn:SetPoint("TOPLEFT", 24, PLAYER_CLASS == "WARRIOR" and -534 or -388)
    centerBtn:SetText("Center HUD")
    centerBtn:SetScript("OnClick", Center)

    local planBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    planBtn:SetSize(125, 25)
    planBtn:SetPoint("LEFT", centerBtn, "RIGHT", 10, 0)
    planBtn:SetText("Print plan")
    planBtn:SetScript("OnClick", PrintPlan)

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(125, 25)
    resetBtn:SetPoint("TOPLEFT", centerBtn, "BOTTOMLEFT", 0, -12)
    resetBtn:SetText("Reset defaults")
    resetBtn:SetScript("OnClick", function()
        HCOB_DB.visible = true
        HCOB_DB.locked = false
        HCOB_DB.scale = 1.0
        HCOB_DB.actionScale = 1.0
        HCOB_DB.dangerHP = 35
        HCOB_DB.criticalHP = 20
        HCOB_DB.soundAlerts = true
        HCOB_DB.enemyWindow = 6
        HCOB_DB.showSwing = true
        HCOB_DB.smartDisplay = true
        HCOB_DB.showAdvisor = true
        HCOB_DB.showDPSMeter = true
        HCOB_DB.hcDangerAdvisor = true
        HCOB_DB.warriorSunderBase = true
        HCOB_DB.warriorHeroicSpam = false
        HCOB_DB.warriorHeroicSafeBaseV111 = true
        HCOB_DB.warriorAutoRend = true
        HCOB_DB.warriorHeroicRage = 35
        HCOB_DB.combatLogging = true
        HCOB_DB.combatLogMaxFights = 60
        HCOB_DB.profCoach = true
        HCOB_DB.actionSlotAutoBind = true
        HCOB_DB.actionSlotKeys = nil
        HCOB_DB.prePullSafety = true
        HCOB_DB.showConsumables = true
        if HCOB.Systems and HCOB.Systems.AdaptiveTuner and HCOB.Systems.AdaptiveTuner.SetEnabled then HCOB.Systems.AdaptiveTuner.SetEnabled(true) end
        runtimeSmartDisabled = false
        runtimeCombatLogDisabled = false
        runtimeErrors = {}
        RefreshButtonState()
        if HCOB.UI.ActionPanel then HCOB.UI.ActionPanel.ApplySlotBindings(); HCOB.UI.ActionPanel.RefreshBindingOptions() end
        if HCOB.UI.SurvivalStrip then HCOB.UI.SurvivalStrip.Configure(); HCOB.UI.SurvivalStrip.SyncVisibility() end
        if HCOB.Systems and HCOB.Systems.ProfessionCoach and HCOB.Systems.ProfessionCoach.SetEnabled then HCOB.Systems.ProfessionCoach.SetEnabled(true) end
        if panel.Refresh then panel:Refresh() end
        UpdateDisplay()
    end)

    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    closeBtn:SetSize(125, 25)
    closeBtn:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        local windows = HCOB.UI and HCOB.UI.WindowManager
        if windows and windows.Close then windows.Close("options", false) else panel:Hide() end
    end)

    local reportBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reportBtn:SetSize(190, 27)
    reportBtn:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -13)
    reportBtn:SetText("Report a problem...")
    reportBtn:SetScript("OnClick", function()
        if HCOB.UI.Feedback and HCOB.UI.Feedback.Open then
            HCOB.UI.Feedback.Open("last", true)
        else
            print("|cffff5555HCOB:|r feedback window unavailable. Try /reload.")
        end
    end)

    -- Keep the explanatory copy in a dedicated full-width footer below both
    -- columns. Anchoring it to the left-side Report button allowed the text to
    -- flow underneath the binding CTA when the right column grew.
    local footerRule = panel:CreateTexture(nil, "ARTWORK")
    footerRule:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -647)
    footerRule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -647)
    footerRule:SetHeight(1)
    footerRule:SetColorTexture(0.30, 0.34, 0.40, 0.55)

    local tip = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tip:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -658)
    tip:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -658)
    tip:SetJustifyH("LEFT")
    tip:SetText("Options persist across reload/logout: account-wide settings use HCOB_DB, while Local Adaptive Tuning is stored per character. HUD scale resizes BASE, Advisor, Action Panel, Survival strip, DPS and Profession Coach together. Secure consumable assignments update only out of combat. Secondary windows replace Options and return here when closed. Use Report a problem after a suspicious fight to generate an anonymized CurseForge-ready diagnostic report.")

    panel.controls = controls
    panel.Refresh = function(self)
        for _, c in ipairs(self.controls or {}) do
            if c.Refresh then c:Refresh() end
        end
    end
    panel:SetScript("OnShow", function(self) self:Refresh() end)
    optionsPanel = panel
    if HCOB.UI and HCOB.UI.WindowManager and HCOB.UI.WindowManager.Register then
        HCOB.UI.WindowManager.Register("options", panel)
    end

    -- Optional integration with ESC > Options > AddOns.
    -- Keep a separate canvas so we do not depend on the behavior
    -- of the popup frame used by /hcob options.
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local bridge = CreateFrame("Frame", "HCOneButtonSettingsBridge")
        bridge.name = "HC One Button"

        local bTitle = bridge:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        bTitle:SetPoint("TOPLEFT", 16, -16)
        bTitle:SetText("HC One Button")

        local bText = bridge:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        bText:SetPoint("TOPLEFT", bTitle, "BOTTOMLEFT", 0, -14)
        bText:SetWidth(560)
        bText:SetJustifyH("LEFT")
        bText:SetText("Full options are available in the dedicated addon panel.")

        local openBtn = CreateFrame("Button", nil, bridge, "UIPanelButtonTemplate")
        openBtn:SetSize(190, 28)
        openBtn:SetPoint("TOPLEFT", bText, "BOTTOMLEFT", 0, -18)
        openBtn:SetText("Open HC One Button")
        openBtn:SetScript("OnClick", OpenOptionsPanel)

        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, bridge, bridge.name)
        if ok and category then
            pcall(Settings.RegisterAddOnCategory, category)
            settingsCategory = category
            settingsBridgePanel = bridge
        end
    elseif InterfaceOptions_AddCategory then
        -- Older clients: register a small legacy bridge directly.
        local bridge = CreateFrame("Frame", "HCOneButtonSettingsBridge", UIParent)
        bridge.name = "HC One Button"
        local bTitle = bridge:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        bTitle:SetPoint("TOPLEFT", 16, -16)
        bTitle:SetText("HC One Button")
        local openBtn = CreateFrame("Button", nil, bridge, "UIPanelButtonTemplate")
        openBtn:SetSize(190, 28)
        openBtn:SetPoint("TOPLEFT", 16, -58)
        openBtn:SetText("Open HC One Button")
        openBtn:SetScript("OnClick", OpenOptionsPanel)
        pcall(InterfaceOptions_AddCategory, bridge)
        settingsBridgePanel = bridge
    end
end
