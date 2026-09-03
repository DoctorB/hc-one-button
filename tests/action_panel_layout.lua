local function read(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*a")
    file:close()
    return content
end

local function extractTable(source, assignment)
    local assignmentAt = assert(source:find(assignment, 1, true), "assignment missing: " .. assignment)
    local equalsAt = assert(source:find("=", assignmentAt, true), "equals missing: " .. assignment)
    local openAt = assert(source:find("{", equalsAt, true), "table missing: " .. assignment)
    local tableSource = assert(source:sub(openAt):match("^(%b{})"), "unbalanced table: " .. assignment)
    return tableSource
end

HCOneButton = {Data = {}}
assert(dofile("HCOneButton/Data/Spells.lua") == nil)
local spells = HCOneButton.Data.Spells
local source = read("HCOneButton/UI/ActionPanel.lua")

local function evaluate(tableSource, environment)
    local chunk = assert(loadstring("return " .. tableSource))
    setfenv(chunk, environment or {})
    return chunk()
end

local actions = evaluate(extractTable(source, "HCOB.UI.ActionPanel.actions"), {S = spells})
local defaultKeys = evaluate(extractTable(source, "HCOB.UI.ActionPanel.defaultSlotKeys"))

local expectedCounts = {
    WARRIOR=20, PALADIN=14, HUNTER=20, ROGUE=17, PRIEST=16,
    MAGE=19, WARLOCK=15, DRUID=20, SHAMAN=15,
}

local knownSpellIds = {}
for name, id in pairs(spells) do
    assert(type(name) == "string" and type(id) == "number", "invalid spell catalog entry")
    knownSpellIds[id] = true
end

assert(#defaultKeys == 20, "Action Panel must expose exactly 20 default slot keys")
local seenKeys = {}
for slot, key in ipairs(defaultKeys) do
    assert(type(key) == "string" and key ~= "", "empty default key at slot " .. slot)
    assert(not seenKeys[key], "duplicate default key: " .. key)
    seenKeys[key] = true
end

local classCount = 0
for classToken, expectedCount in pairs(expectedCounts) do
    classCount = classCount + 1
    local list = assert(actions[classToken], classToken .. " action layout missing")
    assert(#list == expectedCount,
        string.format("%s layout changed: expected %d slots, got %d", classToken, expectedCount, #list))
    assert(#list <= #defaultKeys, classToken .. " exceeds available binding/pixel slots")

    local seenIds = {}
    for slot, id in ipairs(list) do
        assert(type(id) == "number" and knownSpellIds[id],
            string.format("%s slot %d references an unknown spell ID", classToken, slot))
        assert(not seenIds[id], string.format("%s duplicates spell ID %d", classToken, id))
        seenIds[id] = true

        -- Diagnostic Pixel Protocol V3 encodes slot as R = slot * 12.
        local red = slot * 12
        assert(red >= 12 and red <= 240, classToken .. " has an unencodable diagnostic slot")
    end
end

for classToken in pairs(actions) do
    assert(expectedCounts[classToken], "unexpected class layout: " .. tostring(classToken))
end
assert(classCount == 9, "all nine Classic classes must have deterministic layouts")
assert(actions.WARRIOR[19] == spells.CHARGE, "Warrior existing slot 19 changed")
assert(actions.WARRIOR[20] == spells.CLEAVE, "Warrior Cleave must append at slot 20")
assert(source:find('if id == S.HEROIC_STRIKE or id == S.CLEAVE then', 1, true),
    "queued Warrior strikes must use the queue-safe Action Panel macro path")
assert(source:find('CastLine(id, "harm", true)', 1, true),
    "queued Warrior Action Panel macro must use bang-cast semantics")

print("action panel deterministic layout regression: PASS")
