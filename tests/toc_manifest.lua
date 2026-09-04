local function read(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*a")
    file:close()
    return content
end

local function exists(path)
    local file = io.open(path, "rb")
    if not file then return false end
    file:close()
    return true
end

local function normalizeNewlines(content)
    return (content:gsub("\r\n", "\n"))
end

local toc = read("HCOneButton/HCOneButton.toc")
local entries, positions, seen = {}, {}, {}
for line in toc:gmatch("[^\r\n]+") do
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" and not line:find("^##") then
        assert(not seen[line], "duplicate TOC entry: " .. line)
        seen[line] = true
        entries[#entries + 1] = line
        positions[line] = #entries
        local filesystemPath = "HCOneButton/" .. line:gsub("\\", "/")
        assert(exists(filesystemPath), "missing TOC reference: " .. filesystemPath)
        assert(not line:find("^tests[/\\]"), "test harness must not be loaded by the addon")
    end
end

assert(entries[1] == "Core/Init.lua", "Core/Init.lua must remain the first TOC chunk")
assert(entries[2] == "Data/Spells.lua", "Data/Spells.lua must load immediately after bootstrap")
assert(positions["Core/State.lua"] < positions["Core/Utils.lua"], "State must load before Utils")
assert(positions["Core/Range.lua"] < positions["Advisor/Engine.lua"], "range primitives must load before Advisor Engine")
assert(positions["Systems/Consumables.lua"] < positions["Advisor/Readiness.lua"], "consumable inventory must load before readiness")
assert(positions["Advisor/Readiness.lua"] < positions["Advisor/Engine.lua"], "readiness must load before Advisor Engine")
assert(positions["Advisor/Engine.lua"] < positions["Classes/Warrior.lua"], "Advisor Engine must load before class modules")
assert(positions["Classes/Druid.lua"] < positions["UI/CoreHUD.lua"], "all class modules must load before UI")
assert(positions["UI/ActionPanel.lua"] < positions["UI/SurvivalStrip.lua"], "Survival strip must anchor after Action Panel")
assert(positions["UI/WindowManager.lua"] < positions["UI/AdaptiveTuning.lua"], "Window Manager must load before Adaptive Tuning details")
assert(positions["UI/Options.lua"] < positions["UI/AdaptiveTuning.lua"], "Options must load before its Adaptive Tuning child")
assert(positions["Systems/TuningTelemetry.lua"] < positions["Systems/CombatLog.lua"], "adaptive telemetry contract must load before combat log")
assert(positions["Systems/TuningTelemetry.lua"] < positions["Systems/AdaptiveTuner.lua"], "telemetry contract must load before adaptive learner")
assert(positions["Systems/AdaptiveTuner.lua"] < positions["Systems/CombatLog.lua"], "adaptive learner must load before combat log")
assert(entries[#entries] == "Bindings.xml", "Bindings.xml must remain the final TOC entry")

local tocVersion = assert(toc:match("## Version:%s*([^\r\n]+)"), "TOC version missing")
assert(toc:find("## SavedVariablesPerCharacter: HCOB_CharacterDB", 1, true),
    "anonymous per-character telemetry profile SavedVariable missing")
local init = read("HCOneButton/Core/Init.lua")
local runtimeVersion = assert(init:match('HCOB%.VERSION%s*=%s*"([^"]+)"'), "runtime version missing")
assert(tocVersion == runtimeVersion, "TOC/runtime version mismatch")
local state = read("HCOneButton/Core/State.lua")
assert(state:match('VERSION = HCOB%.VERSION or "([^"]+)"') == tocVersion, "fallback runtime version mismatch")

local readme = read("README.md")
local packagedReadme = read("HCOneButton/README.md")
local changelog = read("CHANGELOG.md")
local packagedChangelog = read("HCOneButton/CHANGELOG.md")
assert(readme == packagedReadme, "README copies diverged")
assert(changelog == packagedChangelog, "CHANGELOG copies diverged")
assert(readme:find("Current version:** `" .. tocVersion .. "`", 1, true), "README current version mismatch")
assert(changelog:find("current release is `" .. tocVersion .. "`", 1, true), "CHANGELOG current version mismatch")
assert(normalizeNewlines(read("LICENSE")) == normalizeNewlines(read("HCOneButton/LICENSE")),
    "LICENSE copies diverged")

local options = read("HCOneButton/UI/Options.lua")
assert(options:find('CreateCheckBox(panel, "Local Adaptive Tuning"', 1, true),
    "Local Adaptive Tuning checkbox missing from Options")
assert(options:find("Options.IsAdaptiveTuningEnabled, Options.SetAdaptiveTuningEnabled", 1, true),
    "Local Adaptive Tuning checkbox is not wired to its persistent option accessors")
assert(options:find('adaptiveDetailsBtn:SetText("View learned adjustments...")', 1, true),
    "Local Adaptive Tuning details button missing from Options")
assert(options:find('adaptiveDetailsBtn:SetScript("OnClick", Options.OpenAdaptiveTuningDetails)', 1, true),
    "Local Adaptive Tuning details button is not wired to its child window")
assert(options:find('tip:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -658)', 1, true),
    "Options explanatory text is not anchored in its dedicated footer")
assert(options:find('tip:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -658)', 1, true),
    "Options explanatory footer is not constrained inside the panel")
assert(not options:find('tip:SetPoint("TOPLEFT", reportBtn', 1, true),
    "Options explanatory text can overlap right-column CTAs")

local adaptiveUI = read("HCOneButton/UI/AdaptiveTuning.lua")
assert(adaptiveUI:find('WindowManager.Register("adaptive_tuning", frame)', 1, true),
    "Adaptive Tuning details are not registered with the Window Manager")
assert(adaptiveUI:find('windows.OpenChild("adaptive_tuning", "options")', 1, true),
    "Adaptive Tuning details do not restore their Options parent")
assert(adaptiveUI:find('windows.Close("adaptive_tuning", false)', 1, true),
    "Adaptive Tuning details do not close safely when combat starts")
assert(adaptiveUI:find('table.insert(UISpecialFrames, "HCOneButtonAdaptiveTuningPanel")', 1, true),
    "Adaptive Tuning details are not registered for standard Escape-key closing")

print(string.format("TOC/version/package manifest regression: PASS (%d references)", #entries))
