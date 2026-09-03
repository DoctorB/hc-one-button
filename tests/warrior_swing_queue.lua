local hostGlobal = _G
local environment = setmetatable({}, {__index=hostGlobal})
environment._G = environment
environment.print = function() end

local now, rage, enemyCount = 100, 50, 1
local queuedName = nil
local known, usable = {}, {}
local S = {
    HEROIC_STRIKE=78, CLEAVE=845, EXECUTE=5308, BATTLE_SHOUT=6673, CHARGE=100,
    SHIELD_WALL=871, RETALIATION=20230, HAMSTRING=1715,
    THUNDER_CLAP=6343, DEMO_SHOUT=1160,
}

local names = {
    [S.HEROIC_STRIKE]="Heroic Strike",
    [S.CLEAVE]="Cleave",
    [S.EXECUTE]="Execute",
}

local internal = setmetatable({
    S=S, currentFight=nil, currentWarriorAutoRend=false,
    lastAutoAttack=100,
}, {__index=environment})
environment.HCOneButton = {
    Internal=internal,
    Core={}, Classes={WARRIOR={}},
    Advisor={Engine={}},
}
environment.HCOB_DB = {warriorHeroicRage=35, warriorSunderBase=false}

environment.GetTime = function() return now end
environment.MainhandSpeed = function() return 3.5 end
environment.GetSpellInfo = function(id) return names[id] end
environment.IsPlayerSpell = function(id) return known[id] == true end
environment.IsUsableSpell = function(name) return usable[name] == true end
environment.IsCurrentSpell = function(name) return name == queuedName end
environment.CanAccessValue = function() return true end
environment.SafeBoolean = function(value, fallback)
    if value == nil then return fallback end
    return value == true or value == 1
end
environment.SafeNumber = function(value, fallback) return tonumber(value) or fallback end
environment.Clamp = function(value, low, high) return math.max(low, math.min(high, value)) end
environment.SafeUnitPower = function() return rage end
environment.UnitPowerType = function() return 1 end
environment.UnitHealthPct = function() return 100, true end
environment.CountActiveEnemies = function() return enemyCount end
environment.PlayerLevel = function() return 30 end
environment.SafeUnitLevel = function() return 30 end
environment.SafeUnitClassification = function() return "normal" end
environment.HasMyTargetDebuff = function() return false end
environment.StablePlayerBuff = function() return false, 0 end
environment.NewLines = function() return {} end
environment.AddLine = function(lines, line) if line then lines[#lines + 1] = line end end
environment.FitMacro = function(lines) return table.concat(lines or {}, "\n") end
environment.CastLine = function(id, condition, bang)
    if not known[id] then return nil end
    local prefix = condition and ("[" .. condition .. "] ") or ""
    return "/cast " .. prefix .. (bang and "!" or "") .. names[id]
end
environment.BuildSpellMacro = function() return "/stopmacro" end

local Engine = environment.HCOneButton.Advisor.Engine
Engine.SurvivalReserve = function() return 80, "HIGH" end
Engine.RollingDynamics = function() return nil end
Engine.AddCandidate = function(list, id, title, key, reason, score, tag, displayKind)
    list[#list + 1] = {
        id=id, title=title, key=key, reason=reason,
        score=score, tag=tag, displayKind=displayKind,
    }
end
Engine.SelectCandidate = function(list)
    local best
    for _, candidate in ipairs(list or {}) do
        if not best or candidate.score > best.score then best = candidate end
    end
    if best then return best.id, best.title, best.key, best.reason, best.displayKind end
end

local spellUtils = assert(loadfile("HCOneButton/Core/SpellUtils.lua"))
setfenv(spellUtils, environment)
assert(spellUtils() == nil)

known[S.HEROIC_STRIKE] = true
usable[names[S.HEROIC_STRIKE]] = true

local warriorChunk = assert(loadfile("HCOneButton/Classes/Warrior.lua"))
setfenv(warriorChunk, environment)
assert(warriorChunk() == nil)
local Warrior = environment.HCOneButton.Classes.WARRIOR

local function expect(actual, wanted, label)
    assert(actual == wanted, string.format("%s: expected %s, got %s", label, tostring(wanted), tostring(actual)))
end

-- A slow weapon no longer exposes Heroic Strike throughout the entire swing.
now = 100.50 -- 3.0s until the next 3.5s swing
local id = Warrior:GetRecommendation(true, true, 70, 1)
expect(id, nil, "Heroic Strike hidden outside queue window")

-- The final adaptive window is long enough for the 50Hz reader to observe.
now = 103.00 -- 0.5s remaining; 3.5 * 0.17 = 0.595s window
id = Warrior:GetRecommendation(true, true, 70, 1)
expect(id, S.HEROIC_STRIKE, "Heroic Strike shown near next swing")

-- One successful queue acknowledgement suppresses all further requests,
-- including when Cleave occupies the shared next-swing queue.
queuedName = names[S.HEROIC_STRIKE]
id = Warrior:GetRecommendation(true, true, 70, 1)
expect(id, nil, "queued Heroic Strike not repeated")
queuedName = names[S.CLEAVE]
id = Warrior:GetRecommendation(true, true, 70, 1)
expect(id, nil, "queued Cleave blocks Heroic Strike")
queuedName = nil

-- Between 21% and 30%, an Execute-capable Warrior preserves Rage instead of
-- feeding another queued strike. Near the cap, spending is released so Rage
-- generation is not wasted.
internal.lastAutoAttack = 100
now, rage, enemyCount = 103.00, 50, 1
known[S.EXECUTE], usable[names[S.EXECUTE]] = true, true
id, title = Warrior:GetRecommendation(true, true, 25, 1)
expect(id, nil, "Execute pooling suppresses Heroic Strike")
expect(title, "POOL FOR EXECUTE", "Execute pooling feedback")
rage = 85
id = Warrior:GetRecommendation(true, true, 25, 1)
expect(id, S.HEROIC_STRIKE, "near-cap Rage releases Execute pool")

-- Cleave occupies the appended deterministic slot and wins over Heroic Strike
-- only on a controlled multi-target swing window.
known[S.EXECUTE], usable[names[S.EXECUTE]] = nil, nil
known[S.CLEAVE], usable[names[S.CLEAVE]] = true, true
rage, enemyCount = 50, 2
id = Warrior:GetRecommendation(true, true, 70, 1)
expect(id, S.CLEAVE, "Cleave preferred for multi-target swing dump")
enemyCount = 1
id = Warrior:GetRecommendation(true, true, 70, 1)
expect(id, S.HEROIC_STRIKE, "Heroic Strike retained for single target")

-- Heroic Strike/Cleave combat-log records are main-hand swings and therefore
-- must reset the timer just like white hits and misses.
expect(internal.IsMainhandSwingCombatEvent("SWING_DAMAGE", nil), true, "white hit resets swing")
expect(internal.IsMainhandSwingCombatEvent("SPELL_DAMAGE", S.HEROIC_STRIKE), true, "Heroic Strike hit resets swing")
expect(internal.IsMainhandSwingCombatEvent("SPELL_MISSED", S.CLEAVE), true, "Cleave miss resets swing")
expect(internal.IsMainhandSwingCombatEvent("SPELL_DAMAGE", 999), false, "ordinary spell does not reset swing")

-- Until the first swing has established a timestamp, preserve the safe legacy
-- fallback rather than making a high-Rage dump impossible at combat start.
internal.lastAutoAttack = nil
now, rage, enemyCount = 110, 50, 1
id = Warrior:GetRecommendation(true, true, 70, 1)
expect(id, S.HEROIC_STRIKE, "first-swing fallback")

-- The secure modifier uses !Heroic Strike so duplicate physical inputs cannot
-- toggle an already queued strike off before it lands.
local macros = Warrior:BuildModifierMacros()
assert(macros.altshift:find("/cast !Heroic Strike", 1, true), "Heroic Strike modifier must be queue-safe")

local eventsFile = assert(io.open("HCOneButton/Core/Events.lua", "rb"))
local eventsSource = eventsFile:read("*a")
eventsFile:close()
assert(eventsSource:find('"CURRENT_SPELL_CAST_CHANGED"', 1, true), "queue changes must refresh the Advisor")

print("warrior on-next-swing queue regression: PASS")
