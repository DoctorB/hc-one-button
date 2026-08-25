-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

_G.SLASH_HCOB1 = "/hcob"
_G.SLASH_HCOB2 = "/hconebutton"
SlashCmdList.HCOB = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local cmd, arg = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd or "help"
    if cmd == "bind" then BindKey(arg)
    elseif cmd == "unbind" then UnbindKey(arg)
    elseif cmd == "petfood" then HCOB.Hunter.PrintFoodStatus()
    elseif cmd == "hunter" then
        if HCOB.Hunter.PrintManagementStatus then HCOB.Hunter.PrintManagementStatus() else print("|cffff5555HCOB HUNTER:|r management module unavailable") end
    elseif cmd == "ammo" then
        if HCOB.Hunter.PrintAmmoStatus then HCOB.Hunter.PrintAmmoStatus() else print("|cffff5555HCOB HUNTER:|r management module unavailable") end
    elseif cmd == "petskills" then
        if HCOB.Hunter.PrintPetSkillStatus then HCOB.Hunter.PrintPetSkillStatus() else print("|cffff5555HCOB HUNTER:|r management module unavailable") end
    elseif cmd == "keys" then PrintKeys()
    elseif cmd == "bindtest" then BindTest(arg ~= "" and arg or "BUTTON4")
    elseif cmd == "center" then Center()
    elseif cmd == "options" or cmd == "config" then OpenOptionsPanel()
    elseif cmd == "settings" then OpenBlizzardSettingsPanel()
    elseif cmd == "show" then if not InCombatLockdown() then HCOB_DB.visible=true; RefreshButtonState() end
    elseif cmd == "hide" then if not InCombatLockdown() then HCOB_DB.visible=false; RefreshButtonState() end
    elseif cmd == "lock" then HCOB_DB.locked=true; print("|cff00ff98HCOB:|r position locked.")
    elseif cmd == "unlock" then HCOB_DB.locked=false; print("|cff00ff98HCOB:|r position unlocked.")
    elseif cmd == "plan" or cmd == "rotation" or cmd == "macro" then PrintPlan()
    elseif cmd == "mods" then if currentMods and currentMods.desc then local d=currentMods.desc; print("SHIFT="..tostring(d.shift).." | CTRL="..tostring(d.ctrl).." | ALT="..tostring(d.alt)); print("CTRL+SHIFT="..tostring(d.ctrlshift).." | ALT+SHIFT="..tostring(d.altshift).." | ALT+CTRL="..tostring(d.altctrl).." | ALL="..tostring(d.all)) end
    elseif cmd == "smart" then
        if arg == "on" then HCOB_DB.smartDisplay=true; runtimeSmartDisabled=false; print("|cff00ff98HCOB:|r Smart HUD ON."); UpdateDisplay()
        elseif arg == "off" then HCOB_DB.smartDisplay=false; print("|cff00ff98HCOB:|r Smart HUD OFF; the secure button remains active."); UpdateDisplay()
        else print("|cffffcc00HCOB:|r /hcob smart on|off") end
    elseif cmd == "advisor" then
        if arg == "on" or arg == "off" then
            HCOB_DB.showAdvisor = (arg == "on")
            RefreshButtonState(); UpdateDisplay()
            print("|cff00ff98HCOB:|r Advisor " .. string.upper(arg) .. ".")
        elseif arg == "debug" then
            HCOB.Advisor.Engine.DebugPrint()
        else print("|cffffcc00HCOB:|r /hcob advisor on|off|debug") end
    elseif cmd == "diagpixel" then
        if arg == "on" or arg == "off" then
            HCOB_DB.diagPixel = (arg == "on")
            RefreshButtonState(); UpdateDisplay()
            print("|cff00ff98HCOB:|r Diagnostic pixel " .. string.upper(arg) .. ".")
        else print("|cffffcc00HCOB:|r /hcob diagpixel on|off") end
    elseif cmd == "hsspam" then
        HCOB_DB.warriorHeroicSpam = false
        print("|cffffcc00HCOB:|r Heroic Strike was removed from BASE spam in v1.11: use the Advisor (ALT+SHIFT) when you reach the rage threshold.")
    elseif cmd == "rendspam" then
        if arg == "on" or arg == "off" then
            HCOB_DB.warriorAutoRend = (arg == "on")
            BuildMacros(); UpdateDisplay()
            print("|cff00ff98HCOB:|r Smart pre-pull Rend " .. string.upper(arg) .. ".")
        else print("|cffffcc00HCOB:|r /hcob rendspam on|off") end
    elseif cmd == "sunder" then
        if PLAYER_CLASS ~= "WARRIOR" then
            print("|cffffcc00HCOB:|r this option is Warrior-only.")
        elseif arg == "on" or arg == "off" then
            HCOB_DB.warriorSunderBase = (arg == "on")
            BuildMacros(); UpdateDisplay()
            print("|cff00ff98HCOB:|r Sunder base " .. string.upper(arg) .. ".")
        else
            print("|cffffcc00HCOB:|r /hcob sunder on|off")
        end
    elseif cmd == "hsrage" then
        local v = tonumber(arg)
        if v then
            HCOB_DB.warriorHeroicRage = Clamp(v, 20, 70)
            print("|cff00ff98HCOB:|r Heroic Strike recommended from " .. HCOB_DB.warriorHeroicRage .. " rage.")
            UpdateDisplay()
        else print("|cffffcc00HCOB:|r /hcob hsrage 20-70") end
    elseif cmd == "errors" then
        if #runtimeErrors == 0 then print("|cff00ff98HCOB:|r no errors caught in this session.")
        else
            print("|cffffcc00HCOB: recent caught errors|r")
            for i, e in ipairs(runtimeErrors) do print(i .. ") [" .. tostring(e.area) .. "] " .. tostring(e.message)) end
        end
        print("SmartSafe="..tostring(runtimeSmartDisabled).." CombatLogSafe="..tostring(runtimeCombatLogDisabled).." TelemetrySafe="..tostring(runtimeTelemetryDisabled))
    elseif cmd == "reseterrors" then runtimeErrors={}; runtimeSmartDisabled=false; runtimeCombatLogDisabled=false; runtimeTelemetryDisabled=false; print("|cff00ff98HCOB:|r fail-safe reset."); UpdateDisplay()
    elseif cmd == "log" then
        local sub, rest = (arg or ""):match("^(%S+)%s*(.-)$")
        sub = sub or "status"
        if sub == "on" then HCOB_DB.combatLogging=true; runtimeTelemetryDisabled=false; print("|cff00ff98HCOB LOG:|r ON")
        elseif sub == "off" then if currentFight then SafeRun("TelemetryFinalize", FinalizeCombatTelemetry, "logging_off") end; HCOB_DB.combatLogging=false; print("|cff00ff98HCOB LOG:|r OFF")
        elseif sub == "last" then PrintLastCombatLog()
        elseif sub == "stats" then PrintCombatLogStats()
        elseif sub == "clear" then ClearCombatLog()
        elseif sub == "max" then
            local v=tonumber(rest); if v then HCOB_DB.combatLogMaxFights=Clamp(math.floor(v),10,200); TrimCombatLog(); print("|cff00ff98HCOB LOG:|r max saved fights="..HCOB_DB.combatLogMaxFights) else print("/hcob log max 10-200") end
        elseif sub == "session" then
            InitCombatLogDB(); if rest and rest ~= "" then HCOB_CombatLog.session=rest; print("|cff00ff98HCOB LOG:|r session="..rest) else print("|cff00ff98HCOB LOG:|r session="..tostring(HCOB_CombatLog.session)) end
        elseif sub == "export" then
            InitCombatLogDB(); print("|cff00ff98HCOB LOG EXPORT:|r use /reload to force a save, then copy WTF/Account/<account>/SavedVariables/HCOneButton.lua. Table: HCOB_CombatLog")
        else
            InitCombatLogDB(); print("|cff00ff98HCOB LOG:|r "..(HCOB_DB.combatLogging~=false and "ON" or "OFF").." | saved fights="..#HCOB_CombatLog.fights.."/"..tostring(HCOB_DB.combatLogMaxFights).." | total="..tostring(HCOB_CombatLog.totalFights).." | telemetrySafe="..tostring(runtimeTelemetryDisabled))
            print("/hcob log on|off | last | stats | export | clear | max 60 | session name")
        end
    elseif cmd == "prof" then
        if HCOB.Systems.ProfessionCoach and HCOB.Systems.ProfessionCoach.HandleSlash then HCOB.Systems.ProfessionCoach.HandleSlash(arg) else print("|cffff5555HCOB PROF:|r module unavailable") end
    elseif cmd == "actions" then
        if InCombatLockdown() then print("|cffff5555HCOB:|r change the Actions panel out of combat."); return end
        local sub, value = (arg or ""):match("^(%S+)%s*(.-)$")
        sub = sub or "on"
        if sub == "scale" then
            local v = tonumber(value)
            if v then
                HCOB_DB.actionScale = Clamp(v,0.8,1.5)
                RefreshButtonState()
                print("|cff00ff98HCOB:|r actionScale="..tostring(HCOB_DB.actionScale))
            else
                print("|cffffcc00HCOB:|r /hcob actions scale 0.8-1.5")
            end
            return
        elseif sub == "binds" then
            if HCOB.UI.ActionPanel then HCOB.UI.ActionPanel.PrintSlotBindings() end
            return
        elseif sub == "bind" then
            local v = (value or ""):lower()
            if v == "off" then
                HCOB_DB.actionSlotAutoBind = false
                print("|cffffcc00HCOB:|r Actions slot auto-bind OFF (already saved bindings remain unchanged).")
            else
                HCOB_DB.actionSlotAutoBind = true
                if HCOB.UI.ActionPanel then HCOB.UI.ActionPanel.ApplySlotBindings(); HCOB.UI.ActionPanel.PrintSlotBindings() end
                print("|cff00ff98HCOB:|r Actions slot auto-bind ON.")
            end
            return
        elseif sub == "off" then
            HCOB_DB.secureActions=false
        else
            HCOB_DB.secureActions=true
        end
        if HCOB.UI.ActionPanel then HCOB.UI.ActionPanel.Configure(); HCOB.UI.ActionPanel.SyncVisibility(); HCOB.UI.ActionPanel.UpdateStates() end
        print("|cff00ff98HCOB:|r clickable actions="..tostring(HCOB_DB.secureActions ~= false).." scale="..tostring(HCOB_DB.actionScale or 1.0))
    elseif cmd == "dps" then
        Toggle("showDPSMeter", arg)
        -- Do not touch the SecureActionButton during combat for a simple
        -- meter toggle: the DPS panel is non-secure and can update itself.
        UpdateDPSMeter()
    elseif cmd == "sound" then Toggle("soundAlerts", arg)
    elseif cmd == "swing" then Toggle("showSwing", arg)
    elseif cmd == "scale" then
        if InCombatLockdown() then print("|cffff5555HCOB:|r change scale out of combat."); return end
        local v=tonumber(arg); if v then v=Clamp(v,0.7,1.6); HCOB_DB.scale=v; RefreshButtonState(); print("|cff00ff98HCOB:|r scale="..v) else print("/hcob scale 0.7-1.6") end
    elseif cmd == "danger" then
        local v=tonumber(arg); if v then HCOB_DB.dangerHP=Clamp(v,20,70); print("|cff00ff98HCOB:|r dangerHP="..HCOB_DB.dangerHP) end
    elseif cmd == "critical" then
        local v=tonumber(arg); if v then HCOB_DB.criticalHP=Clamp(v,10,40); print("|cff00ff98HCOB:|r criticalHP="..HCOB_DB.criticalHP) end
    elseif cmd == "status" or cmd == "test" then
        local _, localizedClass = UnitClass("player"); local si,sn=TalentSpec()
        local macro=btn:GetAttribute("macrotext1") or ""
        print("|cff00ff98HCOB v"..VERSION..":|r "..tostring(localizedClass).." L"..PlayerLevel().." spec="..tostring(sn).."("..si..") macro="..#macro.."/"..MACRO_LIMIT)
        print("SmartHUD="..tostring(HCOB_DB.smartDisplay ~= false).." safeMode="..tostring(runtimeSmartDisabled).." combatLogSafe="..tostring(runtimeCombatLogDisabled).." telemetrySafe="..tostring(runtimeTelemetryDisabled).." errors="..#runtimeErrors.." heroicBase=false heroicKnown="..tostring(IsKnown(S.HEROIC_STRIKE)).." hsRage="..tostring(HCOB_DB.warriorHeroicRage or 35).." autoRend="..tostring(currentWarriorAutoRend).." sunderAdaptive="..tostring(HCOB_DB.warriorSunderBase ~= false).." dpsMeter="..tostring(HCOB_DB.showDPSMeter ~= false).." hcDanger="..tostring(HCOB_DB.hcDangerAdvisor ~= false))
        PrintKeys()
    else
        print("|cff00ff98HC One Button v"..VERSION.."|r - all Classic Era classes")
        print("/hcob bind BUTTON4 | Q   /hcob keys   /hcob bindtest [BUTTON4]   /hcob unbind BUTTON4")
        print("/hcob plan   /hcob mods   /hcob status   /hcob hunter   /hcob ammo   /hcob petfood   /hcob petskills   /hcob prof [on|off|refresh]   /hcob actions on|off|scale 1.0|bind on|off|binds")
        print("/hcob center   /hcob show|hide   /hcob lock|unlock   /hcob options   /hcob settings")
        print("/hcob scale 1.1")
        print("/hcob danger 35   /hcob critical 20   /hcob sound on|off   /hcob swing on|off   /hcob dps on|off")
        print("/hcob smart on|off   /hcob advisor on|off|debug   /hcob diagpixel on|off   /hcob rendspam on|off   /hcob sunder on|off   /hcob hsrage 35")
        print("/hcob errors   /hcob reseterrors")
        print("/hcob log last   /hcob log stats   /hcob log export   /hcob log on|off")
        print("Automatically updates with level, trainer, talents, gear and forms.")
    end
end

