-- HCOneButton architecture bootstrap.
local addonName = ...

HCOneButton = type(HCOneButton) == "table" and HCOneButton or {}
local HCOB = HCOneButton
HCOB.VERSION = "1.28.2"

HCOB.Core = type(HCOB.Core) == "table" and HCOB.Core or {}
HCOB.Data = type(HCOB.Data) == "table" and HCOB.Data or {}
HCOB.Classes = type(HCOB.Classes) == "table" and HCOB.Classes or {}
HCOB.Advisor = type(HCOB.Advisor) == "table" and HCOB.Advisor or {}
HCOB.UI = type(HCOB.UI) == "table" and HCOB.UI or {}
HCOB.Systems = type(HCOB.Systems) == "table" and HCOB.Systems or {}
HCOB.Hunter = type(HCOB.Hunter) == "table" and HCOB.Hunter or {}

HCOB.SavedVariableRepairs = {}
local savedVariableRepairSet = {}
function HCOB.RecordSavedVariableRepair(path)
    path = tostring(path or "unknown")
    if savedVariableRepairSet[path] then return end
    savedVariableRepairSet[path] = true
    HCOB.SavedVariableRepairs[#HCOB.SavedVariableRepairs + 1] = path
end

-- SavedVariables are loaded by WoW after addon files execute and before
-- ADDON_LOADED fires. Downstream chunks still need table-shaped placeholders
-- during file load, so keep bootstrap tables here but do not treat them as the
-- persistent roots. ADDON_LOADED will rebind the private environment to the
-- real globals declared by the TOC.
local bootstrapDB = type(_G.HCOB_DB) == "table" and _G.HCOB_DB or {}
local bootstrapCombatLog = type(_G.HCOB_CombatLog) == "table" and _G.HCOB_CombatLog or {}
HCOB.DB = bootstrapDB
HCOB.CombatLog = bootstrapCombatLog

-- One private cross-file runtime environment. It behaves like the old single
-- Lua chunk's top-level locals while keeping every runtime symbol inside the
-- HCOneButton namespace instead of creating dozens of globals.
HCOB.Internal = type(HCOB.Internal) == "table" and HCOB.Internal or {}
local E = HCOB.Internal
local mt = getmetatable(E) or {}
mt.__index = _G
setmetatable(E, mt)
E.HCOB = HCOB
E.addonName = addonName
E.HCOB_DB = bootstrapDB
E.HCOB_CombatLog = bootstrapCombatLog

function HCOB.BindSavedVariables()
    local db = _G.HCOB_DB
    if type(db) ~= "table" then
        HCOB.RecordSavedVariableRepair("HCOB_DB")
        db = {}
        _G.HCOB_DB = db
    end

    local combatLog = _G.HCOB_CombatLog
    if type(combatLog) ~= "table" then
        HCOB.RecordSavedVariableRepair("HCOB_CombatLog")
        combatLog = {}
        _G.HCOB_CombatLog = combatLog
    end

    HCOB.DB = db
    HCOB.CombatLog = combatLog
    E.HCOB_DB = db
    E.HCOB_CombatLog = combatLog
    return db, combatLog
end

HCOB.UI.ActionPanel = type(HCOB.UI.ActionPanel) == "table" and HCOB.UI.ActionPanel or {}
HCOB.Advisor.Engine = type(HCOB.Advisor.Engine) == "table" and HCOB.Advisor.Engine or {}
HCOB.Systems.ProfessionCoach = type(HCOB.Systems.ProfessionCoach) == "table" and HCOB.Systems.ProfessionCoach or {}
HCOB.Systems.Feedback = type(HCOB.Systems.Feedback) == "table" and HCOB.Systems.Feedback or {}
HCOB.UI.Feedback = type(HCOB.UI.Feedback) == "table" and HCOB.UI.Feedback or {}
HCOB.UI.SurvivalStrip = type(HCOB.UI.SurvivalStrip) == "table" and HCOB.UI.SurvivalStrip or {}
HCOB.Systems.Consumables = type(HCOB.Systems.Consumables) == "table" and HCOB.Systems.Consumables or {}

_G.BINDING_HEADER_HCOB = "HC One Button"
_G["BINDING_NAME_CLICK HCOneButtonFrame:LeftButton"] = "HC One Button"
