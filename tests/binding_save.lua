HCOneButton = {
    Internal = setmetatable({}, {__index = _G}),
}

HCOB_DB = {}
local currentSet = 1
local getShouldError = false
local saveShouldError = false
local savedSet

function GetCurrentBindingSet()
    if getShouldError then error("temporary binding-set failure") end
    return currentSet
end

function SaveBindings(bindingSet)
    if saveShouldError then error("save failure") end
    assert(bindingSet == 1 or bindingSet == 2, "SaveBindings received invalid set")
    savedSet = bindingSet
    return true
end

assert(dofile("HCOneButton/Systems/Bindings.lua") == nil)
local SaveCurrentBindings = HCOneButton.Internal.SaveCurrentBindings
assert(type(SaveCurrentBindings) == "function", "SaveCurrentBindings was not exported to the private environment")

local function expect(actual, wanted, label)
    assert(actual == wanted, string.format("%s: expected %s, got %s", label, tostring(wanted), tostring(actual)))
end

local cases = {
    {value=1, wanted=1, label="account"},
    {value=2, wanted=2, label="character"},
    {value=0, wanted=1, label="temporary zero"},
    {value=3, wanted=1, label="invalid numeric"},
    {value=nil, wanted=1, label="nil"},
    {value="2", wanted=2, label="numeric string"},
}

for _, case in ipairs(cases) do
    currentSet = case.value
    savedSet = nil
    local ok = SaveCurrentBindings()
    expect(ok, true, case.label .. " save")
    expect(savedSet, case.wanted, case.label .. " set")
end

getShouldError = true
savedSet = nil
expect(SaveCurrentBindings(), true, "GetCurrentBindingSet error save")
expect(savedSet, 1, "GetCurrentBindingSet error fallback")
getShouldError = false

saveShouldError = true
local ok, err = SaveCurrentBindings()
expect(ok, false, "SaveBindings error contained")
assert(type(err) == "string" and err:find("save failure", 1, true), "SaveBindings error was not returned")

print("binding save regression: PASS")
