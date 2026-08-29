local hostGlobal = _G

local function loadInto(environment, path, ...)
    local chunk = assert(loadfile(path))
    setfenv(chunk, environment)
    return chunk(...)
end

local function contains(list, wanted)
    for _, value in ipairs(list or {}) do
        if value == wanted then return true end
    end
    return false
end

local function expect(actual, wanted, label)
    assert(actual == wanted, string.format("%s: expected %s, got %s", label, tostring(wanted), tostring(actual)))
end

local function newRuntime()
    local environment = setmetatable({}, {__index = hostGlobal})
    environment._G = environment
    environment.print = function() end

    local frames = {}
    function environment.CreateFrame()
        local frame = {events = {}, scripts = {}}
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(script, handler) self.scripts[script] = handler end
        frames[#frames + 1] = frame
        return frame
    end

    local counters = {}
    local function counted(name)
        return function()
            counters[name] = (counters[name] or 0) + 1
        end
    end

    environment.UnitClass = function() return "Warlock", "WARLOCK" end
    environment.UnitGUID = function(unit) return unit == "player" and "Player-Test" or nil end
    environment.UnitLevel = function() return 42 end
    environment.UnitAffectingCombat = function() return false end
    environment.GetTime = function() return 10 end
    environment.RebuildKnownSpellNames = counted("spells")
    environment.InitCombatLogDB = counted("combatlog")
    environment.RestoreHUDPosition = counted("position")
    environment.ApplyVisualTheme = counted("theme")
    environment.CreateOptionsPanel = counted("options")
    environment.BuildMacros = counted("macros")
    environment.MigrateOldBindings = counted("bindings")
    environment.RefreshButtonState = counted("refresh")
    environment.UpdateDisplay = counted("display")

    loadInto(environment, "HCOneButton/Core/Init.lua", "HCOneButton")
    loadInto(environment, "HCOneButton/Data/Spells.lua")
    loadInto(environment, "HCOneButton/Core/State.lua")
    loadInto(environment, "HCOneButton/Core/Utils.lua")

    environment.HCOneButton.Classes.WARLOCK = {
        HandleEvent = function(_, event)
            counters["class:" .. event] = (counters["class:" .. event] or 0) + 1
        end,
    }

    loadInto(environment, "HCOneButton/Core/Events.lua")
    assert(frames[1] and type(frames[1].scripts.OnEvent) == "function", "event frame was not initialized")
    assert(frames[1].events.ADDON_LOADED and frames[1].events.PLAYER_LOGIN, "lifecycle events were not registered")
    return environment, frames[1], counters
end

local function fire(frame, event, ...)
    return frame.scripts.OnEvent(frame, event, ...)
end

-- Normal WoW path: addon chunks first use bootstrap tables, then ADDON_LOADED
-- rebinds every public/private reference to the SavedVariables supplied by WoW.
local environment, eventFrame, counters = newRuntime()
local bootstrapDB = environment.HCOneButton.DB
local persistentDB = {
    visible = false,
    scale = "1.25",
    x = 125,
    y = -75,
    hudPoint = "TOPLEFT",
    hudRelativePoint = "BOTTOMLEFT",
    actionSlotKeys = "invalid",
    customValue = "preserve me",
}
local persistentCombatLog = {fights = {{duration = 12}}}
environment.HCOB_DB = persistentDB
environment.HCOB_CombatLog = persistentCombatLog

fire(eventFrame, "ADDON_LOADED", "AnotherAddon")
expect(environment.HCOneButton.DB, bootstrapDB, "foreign ADDON_LOADED ignored")

fire(eventFrame, "ADDON_LOADED", "HCOneButton")
expect(environment.HCOneButton.DB, persistentDB, "public DB rebound")
expect(environment.HCOneButton.CombatLog, persistentCombatLog, "public combat log rebound")
expect(environment.HCOneButton.Internal.HCOB_DB, persistentDB, "private DB rebound")
expect(environment.HCOneButton.Internal.HCOB_CombatLog, persistentCombatLog, "private combat log rebound")
expect(persistentDB.visible, false, "valid setting preserved")
expect(persistentDB.scale, 1.25, "numeric string repaired")
expect(persistentDB.actionSlotKeys, nil, "invalid binding map repaired")
expect(persistentDB.customValue, "preserve me", "unknown setting preserved")
expect(persistentDB.actionSlotAutoBind, true, "fresh binding default installed")
expect(persistentDB.prePullSafety, true, "fresh pre-pull safety default installed")
expect(persistentDB.showConsumables, true, "fresh Survival strip default installed")
expect(persistentDB.warriorHeroicSpam, false, "unsafe legacy heroic spam disabled")
assert(contains(environment.HCOneButton.SavedVariableRepairs, "HCOB_DB.scale"), "scale repair was not recorded")
assert(contains(environment.HCOneButton.SavedVariableRepairs, "HCOB_DB.actionSlotKeys"), "binding-map repair was not recorded")

local point, relativePoint, x, y = environment.HCOneButton.Internal.ReadHUDPosition()
expect(point, "TOPLEFT", "saved HUD point restored")
expect(relativePoint, "BOTTOMLEFT", "saved HUD relative point restored")
expect(x, 125, "saved HUD x restored")
expect(y, -75, "saved HUD y restored")

local movedFrame = {}
function movedFrame:GetPoint()
    return "BOTTOMRIGHT", environment.UIParent, "TOPRIGHT", -42.5, 86.25
end
environment.HCOneButton.Internal.HCOB_DB = {}
assert(environment.HCOneButton.Internal.SaveHUDPosition(movedFrame), "HUD drag position was not saved")
expect(persistentDB.hudPoint, "BOTTOMRIGHT", "drag point persisted to global DB")
expect(persistentDB.hudRelativePoint, "TOPRIGHT", "drag relative point persisted to global DB")
expect(persistentDB.x, -42.5, "drag x persisted to global DB")
expect(persistentDB.y, 86.25, "drag y persisted to global DB")
expect(environment.HCOneButton.Internal.HCOB_DB, persistentDB, "stale private DB rebound during drag save")

fire(eventFrame, "PLAYER_LOGIN")
for _, name in ipairs({"spells", "combatlog", "position", "theme", "options", "macros", "bindings", "refresh", "display"}) do
    expect(counters[name], 1, "PLAYER_LOGIN hook " .. name)
end
expect(counters["class:PLAYER_LOGIN"], 1, "class login hook")
expect(environment.HCOneButton.Internal.savedVariablesReady, true, "saved variables ready flag")

-- Defensive fallback: PLAYER_LOGIN must initialize persistent roots even if a
-- harness or unusual client path omits ADDON_LOADED.
local fallbackEnvironment, fallbackFrame, fallbackCounters = newRuntime()
local fallbackDB = {dangerHP = 41}
local fallbackLog = {fights = {}}
fallbackEnvironment.HCOB_DB = fallbackDB
fallbackEnvironment.HCOB_CombatLog = fallbackLog
fire(fallbackFrame, "PLAYER_LOGIN")
expect(fallbackEnvironment.HCOneButton.DB, fallbackDB, "PLAYER_LOGIN fallback DB rebound")
expect(fallbackEnvironment.HCOneButton.CombatLog, fallbackLog, "PLAYER_LOGIN fallback log rebound")
expect(fallbackDB.dangerHP, 41, "fallback preserved setting")
expect(fallbackDB.actionSlotAutoBind, true, "fallback installed defaults")
expect(fallbackCounters.macros, 1, "fallback completed login")

-- Malformed roots are replaced instead of leaking invalid values downstream.
local repairEnvironment, repairFrame = newRuntime()
repairEnvironment.HCOB_DB = "invalid root"
repairEnvironment.HCOB_CombatLog = 99
fire(repairFrame, "ADDON_LOADED", "HCOneButton")
assert(type(repairEnvironment.HCOB_DB) == "table", "malformed HCOB_DB root was not replaced")
assert(type(repairEnvironment.HCOB_CombatLog) == "table", "malformed combat-log root was not replaced")
assert(contains(repairEnvironment.HCOneButton.SavedVariableRepairs, "HCOB_DB"), "DB root repair was not recorded")
assert(contains(repairEnvironment.HCOneButton.SavedVariableRepairs, "HCOB_CombatLog"), "combat-log root repair was not recorded")

print("saved variables lifecycle regression: PASS")
