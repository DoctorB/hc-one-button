local now = 100
local playerLevel = 30
local playerHP, petHP = 100, 100
local powerToken, powerPct = "MANA", 100
local petExists, petDead = false, false
local recentlyBandaged = false
local playerChannel, playerHelpfulCast, playerDamageCast = false, false, false
local counts, cooldowns = {}, {}

HCOneButton = {
    Core={}, Data={}, Classes={}, UI={}, Hunter={},
    Advisor={Engine={}}, Systems={Consumables={}},
}
HCOneButton.Internal = setmetatable({}, {__index=_G})
HCOB_DB = {dangerHP=35, prePullSafety=true}
PLAYER_CLASS = "MAGE"
S = {
    SHIELD_WALL=871, RETALIATION=20230, DIVINE_SHIELD=642, DIVINE_PROTECTION=498,
    FEIGN_DEATH=5384, SCATTER_SHOT=19503, VANISH=1856, EVASION=5277, SPRINT=2983,
    PSYCHIC_SCREAM=8122, ICE_BLOCK=11958, FROST_NOVA=122, BLINK=1953,
    DEATH_COIL=6789, FEAR=5782, STONECLAW_TOTEM=5730, EARTHBIND_TOTEM=2484,
    NATURES_GRASP=16689, BARKSKIN=22812, DASH=1850,
}

function GetTime() return now end
function PlayerLevel() return playerLevel end
function UnitLevel() return playerLevel end
function GetItemCount(id) return counts[id] or 0 end
function GetItemInfo(id)
    local minimum = ({[13446]=45,[3928]=35,[1710]=21,[929]=12,[858]=3,[118]=1,
        [13444]=49,[13443]=41,[6149]=31,[3827]=22,[3385]=14,[2455]=5})[id] or 0
    return "Item " .. tostring(id), nil, nil, nil, minimum, nil, nil, nil, nil, "Icon " .. tostring(id)
end
function GetItemCooldown(id)
    local remaining = cooldowns[id] or 0
    return remaining > 0 and now or 0, remaining, 1
end
function IsUsableItem() return true end
function UnitHealthPct(unit)
    if unit == "pet" then return petHP, true end
    return playerHP, true
end
function UnitPowerType() return 0, powerToken end
function UnitPowerPct() return powerPct, true end
function UnitExists(unit) return unit == "pet" and petExists or unit == "player" end
function UnitIsDead(unit) return unit == "pet" and petDead end
function SpellName(_, fallback) return fallback end
function AuraByName(_, name)
    if name == "Recently Bandaged" and recentlyBandaged then return true, 42 end
    return false, 0
end
function UnitChannelInfo(unit)
    if unit == "player" and playerChannel then
        return "First Aid", nil, nil, now * 1000, (now + 8) * 1000, false, false, 3273
    end
end
function UnitCastingInfo(unit)
    if unit == "player" and playerHelpfulCast then
        return "Lesser Heal", nil, nil, now * 1000, (now + 2.5) * 1000, false, 1, false, 2050
    end
    if unit == "player" and playerDamageCast then
        return "Frostbolt", nil, nil, now * 1000, (now + 3) * 1000, false, 2, false, 116
    end
end
function IsHelpfulSpell(identifier)
    return identifier == 2050 or identifier == "Lesser Heal"
end
function CanAccessValue(value) return value ~= nil end
function SafeNumber(value, fallback) return tonumber(value) or fallback end
function SafeString(value, fallback) return type(value) == "string" and value or fallback end
function SafeBoolean(value, fallback) return value == nil and (fallback and true or false) or (value and true or false) end

assert(dofile("HCOneButton/Systems/Consumables.lua") == nil)
assert(dofile("HCOneButton/Advisor/Readiness.lua") == nil)

local C = HCOneButton.Systems.Consumables
local Engine = HCOneButton.Advisor.Engine

local function expect(actual, wanted, label)
    assert(actual == wanted, string.format("%s: expected %s, got %s", label, tostring(wanted), tostring(actual)))
end

-- Highest owned tier that the character can actually use wins. A stronger
-- but level-locked potion must not replace the secure assignment.
counts[118], counts[1710], counts[13446] = 5, 2, 1
local potion = C.FindBest("healingPotion")
expect(potion.id, 1710, "highest usable healing potion")
expect(potion.count, 2, "selected potion count")
expect(C.FindExpected("healingPotion").id, 1710, "level-appropriate empty icon")

-- When both Classic item cooldown paths exist, an active result must win over
-- a transient ready result so shared potion cooldown feedback cannot flicker.
local legacyGetItemCooldown = GetItemCooldown
C_Item = {GetItemCooldown=function(id)
    if id == 1710 then return {startTime=90, duration=30, isEnabled=true} end
end}
GetItemCooldown = function() return 0, 0, 1 end
local potionStart, potionDuration, potionEnabled, potionRemaining = C.GetCooldown(1710)
expect(potionStart, 90, "active item cooldown start")
expect(potionDuration, 30, "active item cooldown duration")
expect(potionEnabled, true, "active item cooldown enabled")
expect(potionRemaining, 20, "active item cooldown wins over transient ready API")
C_Item = nil
GetItemCooldown = legacyGetItemCooldown

-- All improved Healthstone item variants are recognized.
counts[19013] = 1
expect(C.FindBest("healthstone").id, 19013, "improved major Healthstone variant")
counts[19013] = nil

counts[1251] = 4
C.Refresh()
expect(C.SelectHealingRole(false), "bandage", "out-of-combat recovery conserves potions")
expect(C.SelectHealingRole(true), "healingPotion", "combat recovery excludes bandage")

-- Healthy baseline passes; rage is never treated as a missing pre-pull resource.
local result = Engine.EvaluatePrePullReadiness({playerLevel=playerLevel, targetTough=false})
expect(result.state, "ready", "healthy readiness")
powerToken, powerPct = "RAGE", 0
result = Engine.EvaluatePrePullReadiness({playerLevel=playerLevel, targetTough=false})
expect(result.state, "ready", "rage excluded from recovery gate")

playerHP = 60
result = Engine.EvaluatePrePullReadiness({playerLevel=playerLevel, targetTough=false})
expect(result.state, "recover", "low health recovery gate")
expect(result.title, "RECOVER FIRST", "low health title")
playerHP, powerToken, powerPct = 100, "MANA", 25
result = Engine.EvaluatePrePullReadiness({playerLevel=playerLevel, targetTough=false})
expect(result.state, "recover", "low mana recovery gate")
powerToken, powerPct = "ENERGY", 40
result = Engine.EvaluatePrePullReadiness({playerLevel=playerLevel, targetTough=false})
expect(result.state, "prepare", "energy preparation gate")

-- Pet classes receive actionable preparation feedback without affecting
-- pre-pet levels; a badly hurt existing pet is a recovery stop.
PLAYER_CLASS, powerToken, powerPct = "HUNTER", "MANA", 100
result = Engine.EvaluatePrePullReadiness({playerLevel=30, targetTough=false})
expect(result.state, "prepare", "missing hunter pet")
petExists, petHP = true, 55
result = Engine.EvaluatePrePullReadiness({playerLevel=30, targetTough=false})
expect(result.state, "recover", "low pet health")
PLAYER_CLASS, petExists, petHP = "MAGE", false, 100

-- Missing stock escalates only for a tough target. Cooldowns and the Recently
-- Bandaged lock are included without using full-health IsUsableItem results.
for id in pairs(counts) do counts[id] = nil end
C.Refresh()
result = Engine.EvaluatePrePullReadiness({playerLevel=30, targetTough=true})
expect(result.state, "highrisk", "tough target without healing stock")
expect(result.title, "HIGH RISK", "missing stock title")
local _, _, _, _, riskKind = Engine.PrePullRecommendation({playerLevel=30, targetTough=true})
expect(riskKind, "danger", "high-risk visual severity")

counts[1710], cooldowns[1710] = 1, 30
C.Refresh()
result = Engine.EvaluatePrePullReadiness({playerLevel=30, targetTough=true})
expect(result.state, "prepare", "healing tool cooldown")
expect(C.SelectHealingRole(false), nil, "cooling healing tool is not highlighted")
cooldowns[1710], counts[1710], counts[1251] = nil, nil, 1
recentlyBandaged = true
C.Refresh()
local stocked, ready = C.HealingCooldownState()
expect(stocked, true, "bandage stock detected")
expect(ready, false, "Recently Bandaged prevents ready state")
expect(C.SelectHealingRole(false), nil, "Recently Bandaged item is not highlighted")
local bandageStart, bandageDuration, bandageEnabled, bandageRemaining = C.GetRoleCooldown("bandage", 1251)
expect(bandageDuration, 60, "Recently Bandaged visual cooldown duration")
expect(bandageRemaining, 42, "Recently Bandaged visual cooldown remaining")
expect(bandageEnabled, true, "Recently Bandaged visual cooldown enabled")
expect(bandageStart, 82, "Recently Bandaged visual cooldown start")

counts[1251], counts[1710], recentlyBandaged = nil, 1, false
C.Refresh()
expect(C.RecommendForState(35, true), "healingPotion", "danger threshold boundary highlight")
cooldowns[3827], counts[3827] = 30, 1
C.Refresh()
powerToken, powerPct = "MANA", 20
expect(C.RecommendForState(100, true), nil, "cooling mana potion is not highlighted")
cooldowns[3827], counts[3827] = nil, nil
powerPct = 100

HCOB_DB.prePullSafety = false
result = Engine.EvaluatePrePullReadiness({playerLevel=30, targetTough=true})
expect(result.state, "disabled", "saved pre-pull toggle")
HCOB_DB.prePullSafety = true

-- Full Engine integration: the gate must run before a class opener, while a
-- ready melee class receives the new universal PULL READY fallback.
local targetLevel, targetClassification = 30, "normal"
function UnitAffectingCombat() return false end
function HostileLiveTarget() return true end
function SafeUnitLevel() return targetLevel end
function SafeUnitClassification() return targetClassification end
function CountActiveEnemies() return 0 end
function ActiveTargetCast() return nil end
function FightDynamics() return nil end
function TalentSpec() return 1, "TEST" end
function IsKnown() return true end
function IsUsable() return true end
function CooldownReady() return true end
function HasPlayerBuff() return false end
function HasMyTargetDebuff() return false end
function SpellCastSeconds() return 0 end
function HasWandEquipped() return false end
function Clamp(value, low, high) return math.max(low, math.min(high, value)) end
HCOneButton.Advisor.Engine.kindPriority = {idle=0,buff=20,action=40,caution=70,interrupt=90,danger=100}
HCOneButton.Advisor.Engine.RangedBaseRecommendation = function() return nil end
HCOneButton.Advisor.Engine.IsRangedHostileSpell = function() return false end
HCOneButton.Classes.MAGE = {
    GetRecommendation = function() return 999, "OPENER", "BASE", "class opener", "action" end,
    GetBuffRecommendation = function() return nil end,
}
assert(dofile("HCOneButton/Advisor/Engine.lua") == nil)

counts[1710], counts[1251], cooldowns[1710] = 1, nil, nil
recentlyBandaged = false
C.Refresh()
playerHP, powerToken, powerPct = 60, "MANA", 100
local _, title = HCOneButton.Internal.Recommend()
expect(title, "RECOVER FIRST", "recovery gate precedes class opener")

playerHP = 100
HCOneButton.Classes.MAGE.GetRecommendation = function() return nil end
local _, readyTitle, readyKey = HCOneButton.Internal.Recommend()
expect(readyTitle, "PULL READY", "universal melee pull-ready fallback")
expect(readyKey, "PRESS BASE", "pull-ready input")

-- Any active player cast/channel immediately clears the next rotation
-- recommendation. A nil spell makes Diagnostic Pixel black until the real
-- cast duration ends or the cast is interrupted.
function UnitAffectingCombat() return true end
HCOneButton.Classes.MAGE.GetRecommendation = function() return 999, "ROTATION", "BASE", "damage", "action" end
playerChannel = true
local holdID, holdTitle, holdKey, _, holdKind = HCOneButton.Internal.Recommend()
expect(holdID, nil, "active channel clears rotation spell")
expect(holdTitle, "CHANNEL ACTIVE", "active channel title")
expect(holdKey, "LET IT FINISH", "active channel instruction")
expect(holdKind, "caution", "active channel bypasses display stabilization")
HCOneButton.Advisor.Engine.ResetStabilization()
HCOneButton.Advisor.Engine.Stabilize(999, "ROTATION", "BASE", "damage", "action")
holdID, holdTitle, holdKey, _, holdKind = HCOneButton.Advisor.Engine.Stabilize(HCOneButton.Internal.Recommend())
expect(holdID, nil, "channel hold immediately clears stabilized pixel spell")
expect(holdTitle, "CHANNEL ACTIVE", "channel hold immediately replaces stabilized rotation")
playerChannel, playerHelpfulCast = false, true
holdID, holdTitle, holdKey = HCOneButton.Internal.Recommend()
expect(holdID, nil, "helpful cast clears rotation spell")
expect(holdTitle, "RECOVERY ACTIVE", "helpful cast recovery title")
expect(holdKey, "LET IT FINISH", "helpful cast instruction")
playerHelpfulCast, playerDamageCast = false, true
holdID, holdTitle, holdKey = HCOneButton.Internal.Recommend()
expect(holdID, nil, "offensive cast clears next rotation spell")
expect(holdTitle, "CAST ACTIVE", "offensive cast title")
expect(holdKey, "LET IT FINISH", "offensive cast instruction")
playerDamageCast = false
holdID, holdTitle = HCOneButton.Internal.Recommend()
expect(holdID, 999, "rotation resumes after offensive cast ends")
expect(holdTitle, "ROTATION", "post-cast recommendation title")
function UnitAffectingCombat() return false end
HCOneButton.Advisor.Engine.ResetStabilization()
HCOneButton.Classes.MAGE.GetRecommendation = function() return nil end

targetLevel = 33
local _, riskTitle = HCOneButton.Internal.Recommend()
expect(riskTitle, "HIGH RISK", "+3 target preempts pull-ready")
targetLevel = 31
local escapeReady = false
IsKnown = function(id) return id == S.ICE_BLOCK end
CooldownReady = function() return escapeReady end
CooldownRemaining = function() return 45 end
local _, escapeTitle, escapeKey = HCOneButton.Internal.Recommend()
expect(escapeTitle, "PREPARE", "tough pull escape cooldown gate")
expect(escapeKey, "WAIT FOR ESCAPE", "escape cooldown instruction")
escapeReady = true
local _, escapeReadyTitle = HCOneButton.Internal.Recommend()
expect(escapeReadyTitle, "PULL READY", "ready escape passes tough pull gate")
targetLevel = 30

local source = assert(io.open("HCOneButton/UI/SurvivalStrip.lua", "rb")):read("*a")
assert(source:find('SecureActionButtonTemplate', 1, true), "survival buttons must be secure")
assert(source:find('button:SetAttribute("type1", "item")', 1, true), "secure item action missing")
assert(source:find('Strip.pendingConfigure = true', 1, true), "combat-deferred assignment missing")
assert(source:find('button.assignedItemID', 1, true), "visual state must follow frozen secure assignment")
assert(source:find('Consumables.GetRoleCooldown(button.role, itemID)', 1, true), "button must include role-specific cooldown locks")
assert(source:find('"UNIT_AURA"', 1, true), "bandage lock must refresh from player auras")
assert(not source:find("UseContainerItem", 1, true), "survival strip must never use an item automatically")

print("consumables/readiness regression: PASS")
