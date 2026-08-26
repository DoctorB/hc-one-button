-- HCOneButton architecture bootstrap.
local addonName = ...

HCOneButton = HCOneButton or {}
local HCOB = HCOneButton
HCOB.VERSION = "1.27.5"

HCOB.Core = HCOB.Core or {}
HCOB.Data = HCOB.Data or {}
HCOB.Classes = HCOB.Classes or {}
HCOB.Advisor = HCOB.Advisor or {}
HCOB.UI = HCOB.UI or {}
HCOB.Systems = HCOB.Systems or {}
HCOB.Hunter = HCOB.Hunter or {}

-- SavedVariables must retain the exact global names declared by the TOC.
HCOB_DB = HCOB_DB or {}
HCOB_CombatLog = HCOB_CombatLog or {}
HCOB.DB = HCOB_DB
HCOB.CombatLog = HCOB_CombatLog

-- One private cross-file runtime environment. It behaves like the old single
-- Lua chunk's top-level locals while keeping every runtime symbol inside the
-- HCOneButton namespace instead of creating dozens of globals.
HCOB.Internal = HCOB.Internal or {}
local E = HCOB.Internal
local mt = getmetatable(E) or {}
mt.__index = _G
setmetatable(E, mt)
E.HCOB = HCOB
E.addonName = addonName
E.HCOB_DB = HCOB_DB
E.HCOB_CombatLog = HCOB_CombatLog

HCOB.UI.ActionPanel = HCOB.UI.ActionPanel or {}
HCOB.Advisor.Engine = HCOB.Advisor.Engine or {}
HCOB.Systems.ProfessionCoach = HCOB.Systems.ProfessionCoach or {}
HCOB.Systems.Feedback = HCOB.Systems.Feedback or {}
HCOB.UI.Feedback = HCOB.UI.Feedback or {}

_G.BINDING_HEADER_HCOB = "HC One Button"
_G["BINDING_NAME_CLICK HCOneButtonFrame:LeftButton"] = "HC One Button"
