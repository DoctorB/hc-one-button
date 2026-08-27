local now = 0
local rangeState = true
local usable = {}
local ready = {}
local cooldownRemaining = {}
local harmful = {}
local maxRange = {}
local names = {
    [101] = "Ranged A",
    [102] = "Ranged B",
    [103] = "Emergency",
    [201] = "Friendly Heal",
    [301] = "Melee Strike",
}

HCOneButton = {
    Core = {}, Classes = {}, UI = {}, Systems = {}, Hunter = {},
    Advisor = {Engine = {kindPriority = {idle=0, buff=20, action=40, caution=70, interrupt=90, danger=100}}},
}
HCOneButton.Internal = setmetatable({}, {__index = _G})

function GetTime() return now end
function UnitExists(unit) return unit == "target" end
function UnitCanAttack() return true end
function UnitIsDead() return false end
function CanAccessValue() return true end
function SafeBoolean(value, fallback)
    if value == nil then return fallback end
    return value == true or value == 1
end
function SpellName(id, fallback) return names[id] or fallback end
function IsKnown(id) return names[id] ~= nil end
function IsUsable(id) return usable[id] ~= false end
function CooldownReady(id) return ready[id] ~= false end
function CooldownRemaining(id) return cooldownRemaining[id] or (ready[id] == false and 8 or 0) end
function IsSpellInRange()
    if rangeState == nil then return nil end
    return rangeState and 1 or 0
end
function GetSpellInfo(id)
    local spellId = type(id) == "number" and id or nil
    if not spellId then
        for candidate, name in pairs(names) do
            if name == id then spellId = candidate break end
        end
    end
    if not spellId then return nil end
    return names[spellId], nil, nil, 0, 0, maxRange[spellId] or 0, spellId
end

C_Spell = {
    GetSpellInfo = function(id)
        return {minRange = 0, maxRange = maxRange[id] or 0}
    end,
    IsSpellHarmful = function(id)
        return harmful[id] == true
    end,
    IsSpellInRange = function()
        return rangeState
    end,
}

-- Engine.lua captures these helpers in ClassAPI while loading.
function HasPlayerBuff() return false end
function HasMyTargetDebuff() return false end
function SpellCastSeconds() return 0 end
function HasWandEquipped() return false end
function AuraByName() return nil end
function Clamp(value, low, high) return math.max(low, math.min(high, value)) end

maxRange[101], maxRange[102], maxRange[103] = 30, 30, 30
maxRange[201], maxRange[301] = 40, 5
harmful[101], harmful[102], harmful[103], harmful[301] = true, true, true, true

assert(dofile("HCOneButton/Core/Range.lua") == nil)
assert(dofile("HCOneButton/Advisor/Engine.lua") == nil)

local Engine = HCOneButton.Advisor.Engine

local function expect(actual, wanted, label)
    assert(actual == wanted, string.format("%s: expected %s, got %s", label, tostring(wanted), tostring(actual)))
end

-- Shared ranged state: range, usability and cooldown all participate.
rangeState = true
expect(Engine.RangedActionState(101), "ready", "ranged ready")
local savedCSpell = C_Spell
C_Spell = nil
local minRange, legacyMaxRange = Engine.SpellRangeBounds(101)
expect(minRange, 0, "legacy min range")
expect(legacyMaxRange, 30, "legacy max range")
C_Spell = savedCSpell
usable[101] = false
expect(Engine.RangedActionState(101), "unavailable", "ranged unusable")
usable[101] = true
rangeState = false
expect(Engine.RangedActionState(101), "out", "ranged out")
rangeState = nil
expect(Engine.RangedActionState(101), "unknown", "ranged unknown")
rangeState = false
expect(Engine.RangedActionState(301), nil, "melee unaffected")

-- Only hostile ranged spells become an explicit movement instruction.
local id, title, key, _, kind = Engine.ApplyTargetCastability(101, "RANGED A", "BASE", "cast", "action")
expect(id, nil, "out of range id")
expect(title, "OUT OF RANGE", "out of range title")
expect(key, "MOVE CLOSER", "out of range key")
expect(kind, "caution", "out of range severity")
id = Engine.ApplyTargetCastability(201, "HEAL", "ALT", "heal", "action")
expect(id, 201, "friendly spell unaffected")
id = Engine.ApplyTargetCastability(301, "MELEE", "BASE", "strike", "action")
expect(id, 301, "melee recommendation unaffected")

-- A transient normal recommendation never reaches the display.
rangeState = true
Engine.ResetStabilization()
now = 0
id = Engine.Stabilize(101, "A", "BASE", "a", "action")
expect(id, 101, "initial action")
now = 1.00
id = Engine.Stabilize(102, "B", "BASE", "b", "action")
expect(id, 101, "first alternate sample held")
now = 1.10
id = Engine.Stabilize(101, "A", "BASE", "a", "action")
expect(id, 101, "transient alternate discarded")
now = 1.20
id = Engine.Stabilize(102, "B", "BASE", "b", "action")
expect(id, 101, "stable alternate starts pending")
now = 1.31
id = Engine.Stabilize(102, "B", "BASE", "b", "action")
expect(id, 101, "stable alternate still pending")
now = 1.41
id = Engine.Stabilize(102, "B", "BASE", "b", "action")
expect(id, 102, "stable alternate committed")

-- Safety escalation and an invalid old action remain immediate.
now = 1.42
id = Engine.Stabilize(103, "PANIC", "ALL MODS", "danger", "danger")
expect(id, 103, "danger escalation immediate")
now = 1.43
id = Engine.Stabilize(102, "SECOND PANIC", "ALL MODS", "danger", "danger")
expect(id, 102, "equal-priority danger change immediate")
Engine.ResetStabilization()
now = 2.00
id = Engine.Stabilize(101, "A", "BASE", "a", "action")
usable[101] = false
now = 2.01
id = Engine.Stabilize(102, "B", "BASE", "b", "action")
expect(id, 102, "invalid old action replaced immediately")
usable[101] = true

Engine.ResetStabilization()
now = 2.20
id = Engine.Stabilize(101, "A", "BASE", "a", "action")
ready[101], cooldownRemaining[101] = false, 1.20
now = 2.21
id = Engine.Stabilize(102, "B", "BASE", "b", "action")
expect(id, 101, "global cooldown does not cause an immediate swap")
ready[101], cooldownRemaining[101] = true, nil

-- Idle-to-action transitions are debounced too, avoiding a one-frame proc or
-- threshold sample flashing briefly over BASE OK.
Engine.ResetStabilization()
now = 3.00
id = Engine.Stabilize(nil, "BASE OK", "KEEP SPAMMING", "idle", "idle")
expect(id, nil, "initial idle")
now = 3.10
id = Engine.Stabilize(101, "A", "BASE", "a", "action")
expect(id, nil, "idle-to-action first sample held")
now = 3.31
id = Engine.Stabilize(101, "A", "BASE", "a", "action")
expect(id, 101, "idle-to-action stable sample committed")

print("advisor stability/range regression: PASS")
