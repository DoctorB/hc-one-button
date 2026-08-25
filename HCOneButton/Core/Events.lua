-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local eventFrame = CreateFrame("Frame")
local events = {
    "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED",
    "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_TALENT_UPDATE",
    "UNIT_POWER_UPDATE", "UNIT_HEALTH", "UNIT_AURA", "SPELL_UPDATE_COOLDOWN", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS",
    "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_PET", "PET_BAR_UPDATE", "UNIT_HAPPINESS",
    "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL",
    "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED",
    "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
}
for _, e in ipairs(events) do pcall(eventFrame.RegisterEvent, eventFrame, e) end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local eventArg1, eventArg2 = ...
    local function HandleEvent()
        local class = HCOB.Classes and HCOB.Classes[PLAYER_CLASS]
        if class and class.HandleEvent then class:HandleEvent(event, eventArg1, eventArg2) end

        if event == "PLAYER_LOGIN" then
            playerGUID = SafeUnitGUID("player")
            RebuildKnownSpellNames()
            InitCombatLogDB()
            ApplyVisualTheme()
            CreateOptionsPanel()
            BuildMacros()
            MigrateOldBindings()
            RefreshButtonState()
            UpdateDisplay()
            print("|cff00ff98HC One Button v"..VERSION.." loaded:|r " .. (UnitClass("player") or PLAYER_CLASS) .. " L" .. PlayerLevel() .. ". /hcob help")
        elseif event == "PLAYER_REGEN_DISABLED" then
            -- Start empty. The selected target is not proof of engagement; the
            -- combat log will add enemies only after a real damage/miss exchange
            -- with player or pet. This prevents false x2 alerts on combat entry.
            activeEnemies = {}
            if HCOB_DB.combatLogging ~= false and not runtimeTelemetryDisabled then SafeRun("TelemetryStart", StartCombatTelemetry) end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if currentFight and HCOB_DB.combatLogging ~= false and not runtimeTelemetryDisabled then SafeRun("TelemetryFinalize", FinalizeCombatTelemetry, "combat_end") end
            activeEnemies = {}; activeTargetCast=nil
            if pendingRebuild then BuildMacros() end
            if HCOB.UI.ActionPanel then HCOB.UI.ActionPanel.SyncVisibility() end
            MigrateOldBindings()
        elseif event == "PLAYER_TARGET_CHANGED" then
            activeTargetCast=nil
            if HCOB.Advisor.Engine and HCOB.Advisor.Engine.ResetDynamics then HCOB.Advisor.Engine.ResetDynamics() end
            -- Legal smartness: out of combat we may rebuild the secure macro for
            -- the selected target (e.g. decide whether Rend is worth one GCD).
            if not InCombatLockdown() then BuildMacros() end
        elseif event == "PLAYER_LEVEL_UP" or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" or event == "UNIT_PET" or event == "PET_BAR_UPDATE" then
            if event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" then RebuildKnownSpellNames() end
            BuildMacros()
            if event == "PLAYER_LEVEL_UP" and C_Timer and C_Timer.After then
                C_Timer.After(1.0, function()
                    SafeRun("LevelUpRebuild", BuildMacros)
                    SafeRun("LevelUpPlan", PrintPlan)
                end)
            end
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            SafeCombatLogHandler()
        elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
            local taintedBy, protectedFunction = eventArg1, eventArg2
            if taintedBy == addonName or taintedBy == "HCOneButton" then
                RecordRuntimeError(event, tostring(protectedFunction or "protected action"))
                runtimeSmartDisabled = true
            end
        end
    end

    local ok = SafeRun("Event:" .. tostring(event), HandleEvent)
    if not ok and event == "PLAYER_LOGIN" then
        print("|cffff5555HCOB:|r partial initialization. The secure binding may require /reload after /hcob errors.")
    end
end)

-- No more 0.12s NewTicker: it was the main error multiplier.
-- A single throttled OnUpdate keeps the HUD smooth while drastically limiting
-- the number of calls and placing every update behind the fail-safe.
local updateDriver = CreateFrame("Frame")
local updateElapsed = 0
updateDriver:SetScript("OnUpdate", function(_, elapsed)
    updateElapsed = updateElapsed + (elapsed or 0)
    local interval = UnitAffectingCombat("player") and 0.20 or 0.50
    if updateElapsed < interval then return end
    updateElapsed = 0
    if currentFight and HCOB_DB.combatLogging ~= false and not runtimeTelemetryDisabled then
        local ok = SafeRun("TelemetrySample", SampleCombatTelemetry)
        if not ok then runtimeTelemetryDisabled = true end
    end
    UpdateDisplay()
end)
