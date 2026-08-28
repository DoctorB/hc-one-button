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
assert(entries[#entries] == "Bindings.xml", "Bindings.xml must remain the final TOC entry")

local tocVersion = assert(toc:match("## Version:%s*([^\r\n]+)"), "TOC version missing")
local init = read("HCOneButton/Core/Init.lua")
local runtimeVersion = assert(init:match('HCOB%.VERSION%s*=%s*"([^"]+)"'), "runtime version missing")
assert(tocVersion == runtimeVersion, "TOC/runtime version mismatch")

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

print(string.format("TOC/version/package manifest regression: PASS (%d references)", #entries))
