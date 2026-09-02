local hostGlobal = _G
local environment = setmetatable({}, {__index = hostGlobal})
environment._G = environment
environment.print = function() end

local function loadInto(path, ...)
    local chunk = assert(loadfile(path))
    setfenv(chunk, environment)
    return chunk(...)
end

local currentSpec = 1
local currentCombat = true
local currentFormID = 0
local wandEquipped = false

environment.TalentSpec = function() return currentSpec, "TEST", 20 end
environment.PlayerLevel = function() return 60 end
environment.UnitAffectingCombat = function() return currentCombat end
environment.GetShapeshiftFormID = function() return currentFormID end
environment.UnitPowerType = function() return currentFormID == 1 and 3 or (currentFormID == 5 and 1 or 0) end
environment.HasWandEquipped = function() return wandEquipped end
environment.IsKnown = function(id) return id ~= nil end
environment.SpellName = function(id, fallback) return id and ("Spell" .. tostring(id)) or fallback end
environment.CanAccessValue = function(value) return value ~= nil end
environment.SafeNumber = function(value, fallback) return tonumber(value) or fallback end
environment.NewLines = function() return {} end
environment.AddLine = function(lines, value, priority)
    if value and value ~= "" then lines[#lines + 1] = {text = value, priority = priority or 5} end
end
environment.FitMacro = function(lines)
    local text = {}
    for _, line in ipairs(lines or {}) do text[#text + 1] = line.text end
    local macro = table.concat(text, "\n")
    assert(#macro <= 255, "test macro exceeded secure macro limit")
    return macro ~= "" and macro or "/stopmacro"
end
environment.CastLine = function(id, condition, bang)
    if not id then return nil end
    local prefix = condition and ("[" .. condition .. "] ") or ""
    return "/cast " .. prefix .. (bang and "!" or "") .. environment.SpellName(id)
end
environment.BuildSpellMacro = function(id, condition, _, allowUnknown)
    if not id and not allowUnknown then return "/stopmacro" end
    local prefix = condition and ("[" .. condition .. "] ") or ""
    return "/cast " .. prefix .. environment.SpellName(id, "Unknown")
end

loadInto("HCOneButton/Core/Init.lua", "HCOneButton")
loadInto("HCOneButton/Data/Spells.lua")
environment.HCOneButton.Internal.S = environment.HCOneButton.Data.Spells
environment.HCOneButton.Internal.currentWarriorAutoRend = false

local classTokens = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "MAGE", "WARLOCK", "DRUID", "SHAMAN"}
local classFiles = {"Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Mage", "Warlock", "Druid", "Shaman"}
for _, file in ipairs(classFiles) do
    assert(loadInto("HCOneButton/Classes/" .. file .. ".lua") == nil)
end

local requiredContracts = {
    "GetRecommendation", "GetSurvivalReserve", "GetPanicRecommendation", "GetMultiPullRecommendation",
    "GetInterruptRecommendation", "BuildMainMacro", "BuildModifierMacros", "GetBaseActionInfo",
}

for _, token in ipairs(classTokens) do
    local class = environment.HCOneButton.Classes[token]
    assert(type(class) == "table", token .. " module missing")
    assert(class.classToken == token, token .. " classToken mismatch")
    assert(type(class.fallbackSpec) == "number" and class.fallbackSpec >= 1 and class.fallbackSpec <= 3,
        token .. " fallbackSpec invalid")
    for _, contract in ipairs(requiredContracts) do
        assert(type(class[contract]) == "function", token .. " missing " .. contract)
    end

    currentSpec, currentCombat, currentFormID, wandEquipped = class.fallbackSpec, true, 0, false
    local ok, macro = pcall(class.BuildMainMacro, class)
    assert(ok, token .. " BASE macro failed: " .. tostring(macro))
    assert(type(macro) == "string" and macro ~= "" and #macro <= 255, token .. " BASE macro invalid")

    -- Generic self-buff hooks must never feed the out-of-combat Advisor. Class
    -- openers remain owned by GetRecommendation and are tested separately.
    if class.GetBuffRecommendation then
        local buffID = class:GetBuffRecommendation(false)
        assert(buffID == nil, token .. " requested a maintenance aura out of combat")
    end
end

local S = environment.HCOneButton.Data.Spells
local classes = environment.HCOneButton.Classes

-- Melee classes expose no ranged BASE contract.
for _, token in ipairs({"WARRIOR", "PALADIN", "ROGUE"}) do
    assert(classes[token].IsRangedBaseAction == nil, token .. " unexpectedly declares ranged BASE")
end

-- Caster/ranged classes must recognize the exact current BASE and reject an
-- unrelated spell. These calls exercise the same class contract used by Range.lua.
local rangedScenarios = {
    {token="HUNTER", spec=2, wanted=S.AUTO_SHOT},
    {token="MAGE", spec=3, wanted=S.FROSTBOLT},
    {token="WARLOCK", spec=1, wanted=S.SHADOW_BOLT},
    {token="PRIEST", spec=1, wanted=S.SMITE},
    {token="SHAMAN", spec=1, wanted=S.LIGHTNING_BOLT},
    {token="DRUID", spec=1, wanted=S.WRATH},
}
for _, scenario in ipairs(rangedScenarios) do
    currentSpec, currentCombat, currentFormID, wandEquipped = scenario.spec, true, 0, false
    local class = classes[scenario.token]
    assert(type(class.IsRangedBaseAction) == "function", scenario.token .. " ranged BASE contract missing")
    local id = class:GetBaseActionInfo(currentSpec)
    assert(id == scenario.wanted, scenario.token .. " unexpected ranged BASE action")
    assert(class:IsRangedBaseAction(id) == true, scenario.token .. " rejected its ranged BASE")
    assert(class:IsRangedBaseAction(S.ATTACK) == false, scenario.token .. " accepted unrelated melee attack")
end

-- Hybrid state transitions must stop reporting ranged BASE in melee forms/specs.
currentSpec = 2
local shamanBase = classes.SHAMAN:GetBaseActionInfo(currentSpec)
assert(shamanBase == S.ATTACK and classes.SHAMAN:IsRangedBaseAction(shamanBase) == false,
    "Enhancement Shaman BASE must remain melee")

currentSpec, currentFormID = 2, 1
local druidBase = classes.DRUID:GetBaseActionInfo(currentSpec)
assert(druidBase == S.CLAW and classes.DRUID:IsRangedBaseAction(druidBase) == false,
    "Cat Druid BASE must remain melee")

-- Macro safety invariants that must never regress.
currentSpec, currentFormID, wandEquipped = 1, 0, false
local warlockMacro = classes.WARLOCK:BuildMainMacro()
assert(warlockMacro:find("/petattack [combat,harm]", 1, true), "Warlock pet attack is not combat-gated")
assert(not warlockMacro:find("/petattack [harm]", 1, true), "Warlock unsafe pet pull returned")

currentCombat = true
local warriorMacro = classes.WARRIOR:BuildMainMacro()
assert(not warriorMacro:find(environment.SpellName(S.HEROIC_STRIKE), 1, true), "Heroic Strike returned to BASE spam")

print("class contracts/base macro regression: PASS")
