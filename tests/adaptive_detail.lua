local hostGlobal = _G
local environment = setmetatable({}, {__index=hostGlobal})
environment._G = environment
environment.print = function() end
environment.InCombatLockdown = function() return false end

local calls = {}
local windows = {
    OpenChild=function(name, parent) calls[#calls + 1] = {"child", name, parent}; return true end,
    Open=function(name) calls[#calls + 1] = {"open", name}; return true end,
}
environment.HCOneButton = {
    Internal=environment,
    Systems={AdaptiveTuner={}},
    UI={WindowManager=windows},
}

local chunk = assert(loadfile("HCOneButton/UI/AdaptiveTuning.lua"))
setfenv(chunk, environment)
chunk()

local ui = assert(environment.HCOneButton.UI.AdaptiveTuning)
local model = {arms={
    {title="Zero", bias=0, active=false},
    {title="Positive", bias=1.25, active=true},
    {title="Negative", bias=-0.5, active=true},
}}
assert(#ui.FilterArms(model, false) == 3, "detail view hid calibration rows without a filter")
assert(#ui.FilterArms(model, true) == 2, "detail view active-only filter is incorrect")

local closeText
local fakeFrame = {
    closeButton={SetText=function(_, value) closeText = value end},
    IsShown=function() return false end,
    Show=function() end,
    Raise=function() end,
}
ui.Create = function() return fakeFrame end
ui.Refresh = function() calls[#calls + 1] = {"refresh"} end

assert(ui.Open(true), "detail view did not open from Options")
assert(closeText == "Back to Options", "detail view did not expose parent navigation")
assert(calls[1][1] == "child" and calls[1][2] == "adaptive_tuning" and calls[1][3] == "options",
    "detail view did not use WindowManager.OpenChild with Options parent")

calls = {}
assert(ui.Open(false), "standalone detail view did not open")
assert(closeText == "Close", "standalone detail view kept the parent-navigation label")
assert(calls[1][1] == "open" and calls[1][2] == "adaptive_tuning",
    "standalone detail view did not use WindowManager.Open")

calls = {}
environment.InCombatLockdown = function() return true end
assert(ui.Open(true) == false and #calls == 0, "detail view opened during combat lockdown")

print("adaptive detail view/navigation regression: PASS")
