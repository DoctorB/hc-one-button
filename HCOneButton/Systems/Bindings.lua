-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

BIND_COMMAND = "CLICK HCOneButtonFrame:LeftButton"
OLD_BIND_COMMAND = "CLICK HCWarriorOneButtonFrame:LeftButton"

function NormalizeBindingKey(key)
    key = (key or ""):upper():gsub("%s+", "")
    key = key:gsub("MOUSEBUTTON", "BUTTON"):gsub("MOUSE", "BUTTON"):gsub("MB", "BUTTON")
    return key
end

function SaveCurrentBindings()
    local bindingSet = GetCurrentBindingSet and GetCurrentBindingSet() or 1
    if SaveBindings then SaveBindings(bindingSet) end
end

function MigrateOldBindings()
    if HCOB_DB.bindingMigrationDone then return end
    if InCombatLockdown() then return end
    local keys = { GetBindingKey(OLD_BIND_COMMAND) }
    local migrated = 0
    for _, key in ipairs(keys) do
        if key and key ~= "" then
            SetBindingClick(key, "HCOneButtonFrame", "LeftButton")
            migrated = migrated + 1
        end
    end
    if migrated > 0 then
        SaveCurrentBindings()
        print("|cff00ff98HCOB:|r automatically migrated the old HCWarriorOneButton binding.")
    end
    HCOB_DB.bindingMigrationDone = true
end

function BindKey(key)
    if InCombatLockdown() then print("|cffff5555HCOB:|r change bindings out of combat."); return end
    key = NormalizeBindingKey(key)
    if key == "" then print("|cffffcc00HCOB:|r esempio: /hcob bind BUTTON4 oppure /hcob bind Q"); return end
    local old = GetBindingAction(key)
    if SetBindingClick(key, "HCOneButtonFrame", "LeftButton") then
        SaveCurrentBindings()
        if old and old ~= "" and old ~= BIND_COMMAND then print("|cffffcc00HCOB:|r " .. key .. " was previously: " .. old) end
        print("|cff00ff98HCOB:|r " .. key .. " assigned and saved.")
    end
end

function UnbindKey(key)
    if InCombatLockdown() then print("|cffff5555HCOB:|r change bindings out of combat."); return end
    key = NormalizeBindingKey(key)
    if GetBindingAction(key) == BIND_COMMAND then SetBinding(key); SaveCurrentBindings(); print("|cff00ff98HCOB:|r binding removed from " .. key)
    else print("|cffffcc00HCOB:|r " .. key .. " is not assigned to HC One Button.") end
end

function PrintKeys()
    local keys = { GetBindingKey(BIND_COMMAND) }
    if #keys == 0 then print("|cffffcc00HCOB:|r no binding.") else print("|cff00ff98HCOB:|r bind: " .. table.concat(keys, ", ")) end
end

function BindTest(key)
    key = NormalizeBindingKey(key or "BUTTON4")
    local action = GetBindingAction and GetBindingAction(key) or ""
    local keys = { GetBindingKey(BIND_COMMAND) }
    local cvar = GetCVar and GetCVar("ActionButtonUseKeyDown") or "?"
    local useDown = btn:GetAttribute("useOnKeyDown")
    print("|cff00ff98HCOB BINDTEST:|r key=" .. tostring(key))
    print("action=" .. tostring(action ~= "" and action or "<none>"))
    print("bind HCOB=" .. (#keys > 0 and table.concat(keys, ", ") or "<none>"))
    print("ActionButtonUseKeyDown=" .. tostring(cvar) .. " | HCOB useOnKeyDown=" .. tostring(useDown))
    local macro = btn:GetAttribute("macrotext1") or ""
    print("macro BASE=" .. (macro ~= "" and macro:gsub("\n", " | ") or "<empty>"))
    if action == BIND_COMMAND then
        print("|cff00ff98HCOB BINDTEST: OK|r " .. key .. " points to HCOneButtonFrame:LeftButton")
    else
        print("|cffff5555HCOB BINDTEST: FAIL|r use /hcob bind " .. key .. " out of combat")
    end
end

