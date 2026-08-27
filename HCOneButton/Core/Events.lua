-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local eventFrame = CreateFrame("Frame")
local events = {
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED",
    "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_TALENT_UPDATE",
    "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_AURA", "UNIT_TARGET",
    "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "PLAYER_COMBO_POINTS",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_INTERRUPTED",
    "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS",
    "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_PET", "PET_BAR_UPDATE", "UNIT_HAPPINESS",
    "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL",
    "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED",
    "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
}
for _, e in ipairs(events) do pcall(eventFrame.RegisterEvent, eventFrame, e) end

-- Responsiveness 1.27.3 ----------------------------------------------------
-- Important state changes request an Advisor refresh immediately instead of
-- waiting for the heartbeat. A tiny coalescing window prevents UNIT_AURA /
-- UNIT_POWER bursts from turning into dozens of full evaluations per frame.
-- Telemetry percentages remain heartbeat-sampled so event density cannot bias
-- fight statistics; event-driven refreshes still record recommendation changes.
local COMBAT_HEARTBEAT = 0.12
local IDLE_HEARTBEAT = 0.30
local EVENT_MIN_INTERVAL = 0.035
local updateElapsed = 0
local lastAdvisorUpdateAt = 0
local advisorEventReady = false
local advisorUpdatePending = false

local function RunAdvisorRefresh(recordTelemetrySample)
    if not advisorEventReady then return end
    lastAdvisorUpdateAt = GetTime()
    UpdateDisplay(recordTelemetrySample)
end

local function RequestAdvisorRefresh()
    if not advisorEventReady then return end
    local now = GetTime()
    local wait = EVENT_MIN_INTERVAL - (now - (lastAdvisorUpdateAt or 0))
    if wait <= 0 then
        RunAdvisorRefresh(false)
        return
    end
    if advisorUpdatePending then return end
    advisorUpdatePending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(math.max(0.001, wait), function()
            advisorUpdatePending = false
            -- A heartbeat may have refreshed the Advisor while this timer was
            -- waiting. In that case the state is already current; skip the
            -- redundant evaluation instead of creating a second burst.
            if (GetTime() - (lastAdvisorUpdateAt or 0)) >= EVENT_MIN_INTERVAL then
                RunAdvisorRefresh(false)
            end
        end)
    else
        -- The regular heartbeat remains a safe fallback on clients where a
        -- timer cannot be scheduled.
        advisorUpdatePending = false
    end
end

local function EventNeedsAdvisorRefresh(event, unit)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_TARGET_CHANGED" then return true end
    if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE" or event == "PLAYER_COMBO_POINTS" or event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" then return true end
    if event == "UNIT_PET" or event == "PET_BAR_UPDATE" or event == "UNIT_HAPPINESS" then return true end
    if event == "START_AUTOREPEAT_SPELL" or event == "STOP_AUTOREPEAT_SPELL" then return true end
    if event == "PLAYER_LEVEL_UP" or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_TALENT_UPDATE" then return true end
    if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then return unit == "player" end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_AURA" then return unit == "player" or unit == "target" or unit == "pet" end
    if event == "UNIT_TARGET" then return unit == "target" or unit == "pet" end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_SUCCEEDED"
       or event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_CHANNEL_INTERRUPTED" then
        return unit == "target"
    end
    if (event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED") and PLAYER_CLASS == "HUNTER" then return true end
    return false
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local eventArg1, eventArg2 = ...

    local function EnsureSavedVariablesReady()
        if savedVariablesReady then return true end
        if not HCOB.BindSavedVariables then return false end
        HCOB.BindSavedVariables()
        if InitializeSavedVariables then InitializeSavedVariables() end
        savedVariablesReady = true
        return true
    end

    if event == "ADDON_LOADED" then
        if eventArg1 ~= addonName then return end
        local ok = SafeRun("SavedVariablesInit", EnsureSavedVariablesReady)
        if not ok then
            print("|cffff5555HCOB:|r SavedVariables initialization failed. Use /hcob errors for details.")
        end
        return
    end
    local beforeCastKey, beforeEnemies
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        beforeCastKey = activeTargetCast and (tostring(activeTargetCast.guid) .. ":" .. tostring(activeTargetCast.spellId)) or ""
        beforeEnemies = CountActiveEnemies()
    end

    local function HandleEvent()
        if event == "PLAYER_LOGIN" then
            -- ADDON_LOADED is the normal initialization point. Keep this
            -- fallback for test harnesses or unusual load paths that omit it,
            -- and make the persistent tables ready before class login hooks.
            EnsureSavedVariablesReady()
        end

        local class = HCOB.Classes and HCOB.Classes[PLAYER_CLASS]
        if class and class.HandleEvent then class:HandleEvent(event, eventArg1, eventArg2) end

        if event == "PLAYER_LOGIN" then
            playerGUID = SafeUnitGUID("player")
            RebuildKnownSpellNames()
            InitCombatLogDB()
            if RestoreHUDPosition then RestoreHUDPosition() end
            ApplyVisualTheme()
            CreateOptionsPanel()
            BuildMacros()
            MigrateOldBindings()
            RefreshButtonState()
            UpdateDisplay(true)
            lastAdvisorUpdateAt = GetTime()
            advisorEventReady = true
            print("|cff00ff98HC One Button v"..VERSION.." loaded:|r " .. (UnitClass("player") or PLAYER_CLASS) .. " L" .. PlayerLevel() .. ". /hcob help")
            if HCOB.SavedVariableRepairs and #HCOB.SavedVariableRepairs > 0 then
                print("|cffffcc00HCOB:|r repaired invalid SavedVariables: " .. table.concat(HCOB.SavedVariableRepairs, ", ") .. ".")
            end
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
            if pendingHUDScale then
                RefreshButtonState()
            elseif HCOB.UI.ActionPanel then
                HCOB.UI.ActionPanel.SyncVisibility()
            end
            MigrateOldBindings()
        elseif event == "PLAYER_TARGET_CHANGED" then
            activeTargetCast=nil
            if HCOB.Advisor.Engine and HCOB.Advisor.Engine.ResetDynamics then HCOB.Advisor.Engine.ResetDynamics() end
            if HCOB.Advisor.Engine and HCOB.Advisor.Engine.ResetStabilization then HCOB.Advisor.Engine.ResetStabilization() end
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

    if ok and advisorEventReady and event ~= "PLAYER_LOGIN" then
        if EventNeedsAdvisorRefresh(event, eventArg1) then
            RequestAdvisorRefresh()
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            -- Do not refresh for every damage tick. Combat-log events only
            -- force an immediate evaluation when they changed multi-pull state
            -- or the tracked hostile cast used by the interrupt gate.
            local afterCastKey = activeTargetCast and (tostring(activeTargetCast.guid) .. ":" .. tostring(activeTargetCast.spellId)) or ""
            local afterEnemies = CountActiveEnemies()
            if afterCastKey ~= beforeCastKey or afterEnemies ~= beforeEnemies then RequestAdvisorRefresh() end
        end
    end
end)

-- The heartbeat is now a fallback for continuously changing facts that have no
-- reliable event (notably range/movement and rolling dynamics). Important HP,
-- resource, aura, cooldown, target and pet changes use the event path above.
local updateDriver = CreateFrame("Frame")
updateDriver:SetScript("OnUpdate", function(_, elapsed)
    updateElapsed = updateElapsed + (elapsed or 0)
    local interval = UnitAffectingCombat("player") and COMBAT_HEARTBEAT or IDLE_HEARTBEAT
    if updateElapsed < interval then return end
    updateElapsed = 0
    lastAdvisorUpdateAt = GetTime()
    if currentFight and HCOB_DB.combatLogging ~= false and not runtimeTelemetryDisabled then
        local ok = SafeRun("TelemetrySample", SampleCombatTelemetry)
        if not ok then runtimeTelemetryDisabled = true end
    end
    UpdateDisplay(true)
end)
