local hostGlobal = _G
local environment = setmetatable({}, {__index=hostGlobal})
environment._G = environment

local now = 100
local auras = {player={}, pet={}, target={}}
local targetGUID = "Creature-mob-1"
local names = {
    [1001]="Test Armor",
    [1002]="Mend Pet",
    [2001]="Test Armor", -- higher rank of the same aura
    [3001]="Test Corruption",
}

local internal = setmetatable({}, {__index=environment})
environment.HCOneButton = {Internal=internal}
environment.GetTime = function() return now end
environment.UnitExists = function(unit) return unit == "player" or unit == "pet" or (unit == "target" and targetGUID ~= nil) end
environment.SafeUnitGUID = function(unit) return unit == "target" and targetGUID or nil end
environment.SpellName = function(id) return names[id] end
environment.SafeString = function(value, fallback) return type(value) == "string" and value or fallback end
environment.SafeNumber = function(value, fallback) return tonumber(value) or fallback end
environment.CanAccessTable = function(value) return type(value) == "table" end
environment.C_UnitAuras = {
    GetAuraDataByIndex = function(unit, index)
        if index ~= 1 then return nil end
        return auras[unit] and auras[unit][1] or nil
    end,
}

local chunk = assert(loadfile("HCOneButton/Core/Auras.lua"))
setfenv(chunk, environment)
assert(chunk() == nil)

local function expect(actual, wanted, label)
    assert(actual == wanted, string.format("%s: expected %s, got %s", label, tostring(wanted), tostring(actual)))
end

auras.player[1] = {name="Test Armor", duration=120, expirationTime=160}
local active, remaining = internal.StablePlayerBuff(1001)
expect(active, true, "active player aura detected")
expect(math.floor(remaining), 60, "active player aura remaining")

-- One empty Classic aura sample is hidden, but a real removal becomes visible
-- after the bounded debounce rather than for the whole original duration.
auras.player[1] = nil
now = 100.20
active = internal.StablePlayerBuff(1001)
expect(active, true, "transient player aura miss suppressed")
now = 101.10
active = internal.StablePlayerBuff(1001)
expect(active, false, "stable player aura removal exposed")

-- A successful higher-rank cast masks the immediate spellcast/UNIT_AURA race
-- without looking like a near-expiry aura to refresh callers.
now = 200
internal.NotePlayerSpellcastSucceeded(2001)
active, remaining = internal.StablePlayerBuff(1001)
expect(active, true, "rank-safe successful cast grace")
expect(remaining, 999, "successful cast grace is not near expiry")

-- A refresh can leave the old near-expiry aura visible for one frame. The
-- successful cast acknowledgement must still win over that stale metadata.
auras.player[1] = {name="Test Armor", duration=120, expirationTime=205}
active, remaining = internal.StablePlayerBuff(1001)
expect(active, true, "successful refresh keeps aura active")
expect(remaining, 999, "old near-expiry aura cannot retrigger refresh")
auras.player[1] = nil
now = 201.10
active = internal.StablePlayerBuff(1001)
expect(active, false, "successful cast grace is bounded")

-- The same stabilization applies to maintained pet auras such as Mend Pet.
now = 300
auras.pet[1] = {name="Mend Pet", duration=10, expirationTime=308}
active, remaining = internal.StablePetBuff(1002)
expect(active, true, "active pet aura detected")
expect(math.floor(remaining), 8, "active pet aura remaining")
auras.pet[1] = nil
now = 300.20
active = internal.StablePetBuff(1002)
expect(active, true, "transient pet aura miss suppressed")
now = 301.10
active = internal.StablePetBuff(1002)
expect(active, false, "stable pet aura removal exposed")

-- A DoT reaches the target aura list after UNIT_SPELLCAST_SUCCEEDED. The
-- cast must count as applied meanwhile so the same slot is not shown again.
now = 400
expect(internal.StableMyTargetDebuff(3001), false, "missing target debuff exposed")
internal.NotePlayerSpellcastSucceeded(3001)
now = 400.30
active, remaining = internal.StableMyTargetDebuff(3001)
expect(active, true, "target debuff cast grace before the aura arrives")
expect(remaining, 999, "target debuff cast grace is not near expiry")
targetGUID = "Creature-mob-2"
expect(internal.StableMyTargetDebuff(3001), false, "target debuff grace bound to the cast target")
targetGUID = "Creature-mob-1"
now = 401.60
expect(internal.StableMyTargetDebuff(3001), false, "resisted DoT is offered again after the grace")
internal.NotePlayerSpellcastSucceeded(3001)
auras.target[1] = {name="Test Corruption", duration=18, expirationTime=419.60}
active, remaining = internal.StableMyTargetDebuff(3001)
expect(active, true, "visible target debuff detected")
expect(math.floor(remaining), 18, "visible target debuff remaining")
auras.target[1] = nil
expect(internal.StableMyTargetDebuff(3001), false, "visible aura ends the cast grace")

-- A 2 s cast-time DoT leaves the cast bar before UNIT_SPELLCAST_SUCCEEDED.
-- The window opened at cast start must cover that gap.
environment.SpellCastSeconds = function() return 2 end
now = 500
internal.NotePlayerSpellcastStart(3001, "cast-1")
now = 502.05
expect(internal.StableMyTargetDebuff(3001), true, "cast-time DoT covered between cast end and success")
internal.NotePlayerSpellcastFailed("cast-other")
expect(internal.StableMyTargetDebuff(3001), true, "failure of another press keeps the running cast window")
internal.NotePlayerSpellcastFailed("cast-1")
expect(internal.StableMyTargetDebuff(3001), false, "failed or interrupted cast is offered again")
now = 600
internal.NotePlayerSpellcastStart(3001, "cast-2")
now = 602.00
internal.NotePlayerSpellcastSucceeded(3001)
internal.NotePlayerSpellcastFailed("cast-2")
expect(internal.StableMyTargetDebuff(3001), true, "success replaces the cast-start window")
now = 603.60
expect(internal.StableMyTargetDebuff(3001), false, "cast-time DoT window is bounded after success")

print("stable self/pet aura policy regression: PASS")
