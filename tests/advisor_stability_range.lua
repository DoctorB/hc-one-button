local now = 0
local rangeState = true
local usable = {}
local ready = {}
local cooldownRemaining = {}
local harmful = {}
local maxRange = {}
local idMaxRange = {}
local queuedSwingSpell = nil
local names = {
    [78] = "Heroic Strike",
    [101] = "Ranged A",
    [102] = "Ranged B",
    [103] = "Emergency",
    [201] = "Friendly Heal",
    [301] = "Melee Strike",
    [401] = "Forced Class Base",
}

HCOneButton = {
    Core = {}, Classes = {}, UI = {}, Systems = {}, Hunter = {},
    Advisor = {Engine = {kindPriority = {idle=0, buff=20, action=40, caution=70, interrupt=90, danger=100}}},
}
HCOneButton.Internal = setmetatable({}, {__index = _G})
HCOneButton.Internal.S = {HEROIC_STRIKE=78, CLEAVE=845}

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
function TalentSpec() return 1, "TEST" end
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
    GetSpellInfo = function(identifier)
        local id = type(identifier) == "number" and identifier or nil
        if not id then
            for candidate, name in pairs(names) do
                if name == identifier then id = candidate break end
            end
        end
        if not id then return nil end
        local bound = type(identifier) == "number" and idMaxRange[id] or nil
        return {minRange = 0, maxRange = bound ~= nil and bound or (maxRange[id] or 0)}
    end,
    IsSpellHarmful = function(identifier)
        local id = type(identifier) == "number" and identifier or nil
        if not id then
            for candidate, name in pairs(names) do
                if name == identifier then id = candidate break end
            end
        end
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
function IsQueuedMeleeSwingSpell(id) return id == queuedSwingSpell end

maxRange[101], maxRange[102], maxRange[103] = 30, 30, 30
maxRange[201], maxRange[301] = 40, 5
maxRange[401] = 0
harmful[101], harmful[102], harmful[103], harmful[301] = true, true, true, true
idMaxRange[101] = 0 -- rank-1 ID metadata is incomplete; localized learned name is correct

assert(dofile("HCOneButton/Core/Range.lua") == nil)
assert(dofile("HCOneButton/Advisor/Engine.lua") == nil)

local Engine = HCOneButton.Advisor.Engine

local function expect(actual, wanted, label)
    assert(actual == wanted, string.format("%s: expected %s, got %s", label, tostring(wanted), tostring(actual)))
end

-- Shared ranged state: range, usability and cooldown all participate.
rangeState = true
expect(Engine.RangedActionState(101), "ready", "ranged ready")
local rankedMinRange, rankedMaxRange = Engine.SpellRangeBounds(101)
expect(rankedMinRange, 0, "localized rank-safe min range")
expect(rankedMaxRange, 30, "localized rank-safe max range")
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
expect(Engine.RangedActionState(401, true), "out", "class-owned ranged base forced")

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

-- A class-owned BASE remains protected even when client spell metadata cannot
-- classify its rank-1 ID as harmful/ranged.
PLAYER_CLASS = "WARLOCK"
HCOneButton.Classes.WARLOCK = {
    GetBaseActionInfo = function() return 401, "FORCED BASE" end,
    IsRangedBaseAction = function(_, spellId) return spellId == 401 end,
}
id, title, key, _, kind = Engine.ApplyTargetCastability(401, "FORCED BASE", "BASE", "cast", "action")
expect(id, nil, "forced base out of range id")
expect(title, "OUT OF RANGE", "forced base out of range title")
expect(kind, "caution", "forced base out of range severity")
id, title, key, _, kind = Engine.RangedBaseRecommendation(false, true)
expect(id, nil, "forced base pull id while out")
expect(title, "OUT OF RANGE", "forced base pull title while out")
expect(key, "MOVE CLOSER", "forced base pull key while out")
rangeState = true
id, title, key, _, kind = Engine.RangedBaseRecommendation(false, true)
expect(id, 401, "forced base pull id while ready")
expect(title, "PULL READY", "forced base pull title while ready")
expect(key, "PRESS BASE", "forced base pull key while ready")

local warlockFile = assert(io.open("HCOneButton/Classes/Warlock.lua", "rb"))
local warlockSource = warlockFile:read("*a")
warlockFile:close()
assert(warlockSource:find('/petattack [combat,harm]', 1, true), "Warlock petattack must require combat")
assert(not warlockSource:find('AddLine(lines, "/petattack [harm]"', 1, true), "unsafe Warlock petattack returned")

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

-- A queued on-next-swing action is acknowledged immediately instead of being
-- retained by the normal 0.20s recommendation swap confirmation.
Engine.ResetStabilization()
queuedSwingSpell = nil
now = 2.30
id = Engine.Stabilize(78, "HEROIC STRIKE", "ALT+SHIFT", "queue it", "action")
expect(id, 78, "initial Heroic Strike")
queuedSwingSpell = 78
now = 2.31
id = Engine.Stabilize(nil, "BASE OK", "KEEP SPAMMING", "queued", "idle")
expect(id, nil, "queued Heroic Strike cleared immediately")
queuedSwingSpell = nil

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
