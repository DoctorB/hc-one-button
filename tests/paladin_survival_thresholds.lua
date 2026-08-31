local hostGlobal = _G
local environment = setmetatable({}, {__index=hostGlobal})
environment._G = environment
environment.print = function() end

local hp, enemies, reserve = 100, 1, 60
local ready = {}

local S = {
    DIVINE_SHIELD=642, DIVINE_PROTECTION=498, LAY_ON_HANDS=633,
    HAMMER_JUSTICE=853, FLASH_LIGHT=19750, HOLY_LIGHT=635,
}

local internal = setmetatable({S=S}, {__index=environment})
environment.HCOneButton = {
    Internal=internal,
    Classes={PALADIN={}},
    Advisor={Engine={lastDynamics=nil}},
}

environment.SafeNumber = function(value, fallback) return tonumber(value) or fallback end
environment.UnitHealthPct = function() return hp, true end
environment.CountActiveEnemies = function() return enemies end
environment.IsKnown = function(id) return id ~= nil end
environment.CooldownReady = function(id) return ready[id] ~= false end
environment.IsUsable = function(id) return ready[id] ~= false end
environment.SpellName = function(id, fallback) return id and ("Spell" .. tostring(id)) or fallback end

local Engine = environment.HCOneButton.Advisor.Engine
Engine.SurvivalReserve = function() return reserve, reserve <= 28 and "CRITICAL" or "MED" end
Engine.PaladinHealSpell = function() return S.FLASH_LIGHT end
Engine.ManaPct = function() return 70 end
Engine.TargetIsClose = function() return true end

local chunk = assert(loadfile("HCOneButton/Classes/Paladin.lua"))
setfenv(chunk, environment)
assert(chunk() == nil)

local Paladin = environment.HCOneButton.Classes.PALADIN

local function expect(actual, wanted, label)
    assert(actual == wanted, string.format("%s: expected %s, got %s", label, tostring(wanted), tostring(actual)))
end

local function panic(context)
    return Paladin:GetPanicRecommendation(context or {
        hp=hp, enemies=enemies, reserve=reserve,
    })
end

-- Stable single-target danger must preserve Divine Shield above the immediate
-- emergency threshold, even though the global danger gate calls panic policy.
hp, enemies, reserve = 35, 1, 60
local id = panic()
expect(id, S.DIVINE_PROTECTION, "stable 35% HP preserves Divine Shield")

hp = 26
id = panic()
expect(id, S.DIVINE_PROTECTION, "26% HP preserves Divine Shield without added pressure")

-- The immediate threshold remains unconditional, while Lay on Hands retains
-- priority at the existing extreme-emergency boundary.
hp = 25
id = panic()
expect(id, S.DIVINE_SHIELD, "25% HP immediate Divine Shield")
hp = 18
id = panic()
expect(id, S.LAY_ON_HANDS, "18% HP Lay on Hands priority")

-- Between 26% and 35%, concrete pressure unlocks Divine Shield.
hp, enemies, reserve = 35, 2, 60
id = panic()
expect(id, S.DIVINE_SHIELD, "two-target pressure Divine Shield")

enemies, reserve = 1, 28
id = panic()
expect(id, S.DIVINE_SHIELD, "critical reserve Divine Shield")

reserve = 60
id = panic({
    hp=35, enemies=1, reserve=60,
    dynamics={confidence=0.60, ttd=6},
})
expect(id, S.DIVINE_SHIELD, "six-second lethal forecast Divine Shield")

-- A warning above 35% HP never spends Divine Shield solely because the trend
-- is unfavorable or three enemies are present.
id = panic({
    hp=60, enemies=1, reserve=60,
    dynamics={confidence=0.60, ttd=9},
})
expect(id, S.HAMMER_JUSTICE, "moderate trend prefers control")

hp, enemies, reserve = 60, 3, 60
local multiID, multiTitle = Paladin:GetMultiPullRecommendation(enemies, hp, 100)
expect(multiID, S.DIVINE_PROTECTION, "healthy three-target pull preserves Divine Shield")
expect(multiTitle, "3+ MOBS - STABILIZE", "multi-pull title does not demand bubble")

-- With lesser immunity unavailable, moderate danger must prefer control/heal
-- instead of escalating to Lay on Hands.
hp, enemies, reserve = 35, 1, 60
ready[S.DIVINE_PROTECTION] = false
id = panic()
expect(id, S.HAMMER_JUSTICE, "moderate danger control fallback")
ready[S.HAMMER_JUSTICE] = false
id = panic()
expect(id, S.FLASH_LIGHT, "moderate danger healing fallback")

print("paladin survival thresholds regression: PASS")
