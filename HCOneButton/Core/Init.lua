-- HCOneButton architecture bootstrap.
local addonName = ...

HCOneButton = type(HCOneButton) == "table" and HCOneButton or {}
local HCOB = HCOneButton
HCOB.VERSION = "1.27.5"

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

-- SavedVariables must retain the exact global names declared by the TOC.
if type(HCOB_DB) ~= "table" then
    HCOB.RecordSavedVariableRepair("HCOB_DB")
    HCOB_DB = {}
end
if type(HCOB_CombatLog) ~= "table" then
    HCOB.RecordSavedVariableRepair("HCOB_CombatLog")
    HCOB_CombatLog = {}
end
HCOB.DB = HCOB_DB
HCOB.CombatLog = HCOB_CombatLog

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
E.HCOB_DB = HCOB_DB
E.HCOB_CombatLog = HCOB_CombatLog

HCOB.UI.ActionPanel = type(HCOB.UI.ActionPanel) == "table" and HCOB.UI.ActionPanel or {}
HCOB.Advisor.Engine = type(HCOB.Advisor.Engine) == "table" and HCOB.Advisor.Engine or {}
HCOB.Systems.ProfessionCoach = type(HCOB.Systems.ProfessionCoach) == "table" and HCOB.Systems.ProfessionCoach or {}
HCOB.Systems.Feedback = type(HCOB.Systems.Feedback) == "table" and HCOB.Systems.Feedback or {}
HCOB.UI.Feedback = type(HCOB.UI.Feedback) == "table" and HCOB.UI.Feedback or {}

_G.BINDING_HEADER_HCOB = "HC One Button"
_G["BINDING_NAME_CLICK HCOneButtonFrame:LeftButton"] = "HC One Button"
