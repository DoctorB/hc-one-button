local addonName = ...
HCOB_DB = HCOB_DB or {}
HCOB_CombatLog = HCOB_CombatLog or {}

BINDING_HEADER_HCOB = "HC One Button"
_G["BINDING_NAME_CLICK HCOneButtonFrame:LeftButton"] = "HC One Button"

local VERSION = "1.21.1"
local MACRO_LIMIT = 255

local _, PLAYER_CLASS = UnitClass("player")

local S = {
    -- Warrior
    ATTACK=6603, CHARGE=100, HEROIC_STRIKE=78, REND=772, SUNDER_ARMOR=7386, THUNDER_CLAP=6343, BATTLE_SHOUT=6673,
    BLOODRAGE=2687, HAMSTRING=1715, OVERPOWER=7384, EXECUTE=5308, MORTAL_STRIKE=12294,
    BLOODTHIRST=23881, SHIELD_BASH=72, PUMMEL=6552, DEMO_SHOUT=1160, RETALIATION=20230,
    SHIELD_WALL=871, BERSERKER_RAGE=18499, WHIRLWIND=1680,

    -- Paladin
    SEAL_RIGHTEOUSNESS=21084, SEAL_COMMAND=20375, JUDGEMENT=20271, BLESSING_MIGHT=19740,
    CONSECRATION=26573, HAMMER_JUSTICE=853, DIVINE_PROTECTION=498, LAY_ON_HANDS=633,
    EXORCISM=879, HAMMER_WRATH=24275, HOLY_LIGHT=635, FLASH_LIGHT=19750, DIVINE_SHIELD=642, SEAL_CRUSADER=21082,

    -- Hunter
    AUTO_SHOT=75, SERPENT_STING=1978, ARCANE_SHOT=3044, MULTI_SHOT=2643, HUNTERS_MARK=1130,
    ASPECT_HAWK=13165, ASPECT_CHEETAH=5118, ASPECT_MONKEY=13163, CONCUSSIVE_SHOT=5116,
    WING_CLIP=2974, RAPTOR_STRIKE=2973, MONGOOSE_BITE=1495, SCATTER_SHOT=19503, AIMED_SHOT=19434,
    MEND_PET=136, FEED_PET=6991, FEED_PET_EFFECT=1539, FEIGN_DEATH=5384, INTIMIDATION=19577, BESTIAL_WRATH=19574, RAPID_FIRE=3045,
    FREEZING_TRAP=1499,

    -- Rogue
    SINISTER_STRIKE=1752, EVISCERATE=2098, HEMORRHAGE=16511, STEALTH=1784, GOUGE=1776,
    KICK=1766, SPRINT=2983, EVASION=5277, VANISH=1856, BLADE_FLURRY=13877, SLICE_DICE=5171, GARROTE=703, CHEAP_SHOT=1833, KIDNEY_SHOT=408, BLIND=2094, ADRENALINE_RUSH=13750,

    -- Priest
    SMITE=585, SHADOW_WORD_PAIN=589, POWER_WORD_SHIELD=17, MIND_BLAST=8092, MIND_FLAY=15407,
    SHOOT=5019, FORTITUDE=1243, PSYCHIC_SCREAM=8122, SILENCE=15487, RENEW=139, FADE=586, LESSER_HEAL=2050, HEAL=2054, FLASH_HEAL=2061, INNER_FIRE=588, HOLY_FIRE=14914, WEAKENED_SOUL=6788,

    -- Mage
    FIREBALL=133, FROSTBOLT=116, ARCANE_MISSILES=5143, FIRE_BLAST=2136, FROST_NOVA=122,
    ARCANE_INTELLECT=1459, BLINK=1953, COUNTERSPELL=2139, MANA_SHIELD=1463, ICE_BLOCK=11958,
    FROST_ARMOR=168, ICE_ARMOR=7302, MAGE_ARMOR=6117, POLYMORPH=118, EVOCATION=12051,
    ICE_BARRIER=11426, COLD_SNAP=12472, PYROBLAST=11366, SCORCH=2948, CONE_OF_COLD=120,
    ARCANE_EXPLOSION=1449, BLIZZARD=10, CLEARCASTING=12536,

    -- Warlock
    SHADOW_BOLT=686, CORRUPTION=172, CURSE_AGONY=980, IMMOLATE=348, FEAR=5782, LIFE_TAP=1454,
    DRAIN_LIFE=689, DEMON_SKIN=687, DEMON_ARMOR=706, SPELL_LOCK=19244, DEATH_COIL=6789,
    SHADOWBURN=17877, DRAIN_SOUL=1120, CURSE_WEAKNESS=702,

    -- Druid
    WRATH=5176, MOONFIRE=8921, MARK_WILD=1126, BEAR_FORM=5487, CAT_FORM=768, RAKE=1822,
    CLAW=1082, FEROCIOUS_BITE=22568, MAUL=6807, ENTANGLING_ROOTS=339, DASH=1850,
    TRAVEL_FORM=783, FERAL_CHARGE=16979, BASH=5211, BARKSKIN=22812, NATURES_GRASP=16689,

    -- Shaman
    LIGHTNING_BOLT=403, EARTH_SHOCK=8042, FLAME_SHOCK=8050, LIGHTNING_SHIELD=324,
    STORMSTRIKE=17364, EARTHBIND_TOTEM=2484, GHOST_WOLF=2645, HEALING_WAVE=331,
    STONECLAW_TOTEM=5730, FROST_SHOCK=8056, SEARING_TOTEM=3599, FIRE_NOVA_TOTEM=1535, CHAIN_LIGHTNING=421,
}

local CLASS_FALLBACK_SPEC = {
    WARRIOR=1, PALADIN=3, HUNTER=1, ROGUE=2, PRIEST=3,
    SHAMAN=2, MAGE=3, WARLOCK=1, DRUID=2,
}

local function Default(key, value)
    if HCOB_DB[key] == nil then HCOB_DB[key] = value end
end
Default("visible", true)
Default("x", 0)
Default("y", -180)
Default("scale", 1.0)
Default("dangerHP", 35)
Default("criticalHP", 20)
Default("soundAlerts", true)
Default("enemyWindow", 6)
Default("showSwing", true)
Default("locked", false)
Default("showOptionsHint", true)
Default("smartDisplay", true)
Default("warriorHeroicRage", 35)
Default("showAdvisor", true)
Default("showDPSMeter", true)
Default("hcDangerAdvisor", true)
Default("warriorSunderBase", true)
Default("warriorHeroicSpam", false)
Default("warriorAutoRend", true)
Default("combatLogging", true)
Default("diagPixel", true)
Default("profCoach", true)
Default("secureActions", true)
Default("actionScale", 1.0)
Default("actionSlotAutoBind", true)

-- v1.11: Heroic Strike must never live in the BASE SPAM macro. A secure macro
-- cannot test the player's current rage, so putting !Heroic Strike in the base
-- button queued it even when rage was scarce. Migrate existing SavedVariables
-- once so upgrades from older versions cannot retain the unsafe behavior.
if HCOB_DB.warriorHeroicSafeBaseV111 ~= true then
    HCOB_DB.warriorHeroicSpam = false
    HCOB_DB.warriorHeroicSafeBaseV111 = true
end
Default("combatLogMaxFights", 60)

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function SpellInfo(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if info then return info.name, info.iconID, info.castTime or 0 end
    end
    if GetSpellInfo then
        local name, _, icon, castTime = GetSpellInfo(id)
        return name, icon, castTime or 0
    end
end

local function SpellName(id, fallback)
    local name = SpellInfo(id)
    return name or fallback
end

local function SpellIcon(id, fallbackTexture)
    if id then
        local _, icon = SpellInfo(id)
        if icon then return icon end
        if C_Spell and C_Spell.GetSpellTexture then
            local ok, texture = pcall(C_Spell.GetSpellTexture, id)
            if ok and texture then return texture end
        end
        if GetSpellTexture then
            local ok, texture = pcall(GetSpellTexture, id)
            if ok and texture then return texture end
        end
    end
    return fallbackTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function SpellCastSeconds(id)
    local _, _, ms = SpellInfo(id)
    if not ms or ms <= 0 then return 3 end
    return Clamp(ms / 1000, 0.5, 8)
end

local knownSpellNames = {}

local function RebuildKnownSpellNames()
    local cache = {}
    -- Classic abilities have separate spellIDs per rank.  Checking only the
    -- rank-1 ID can therefore return false even though a higher rank is in the
    -- spellbook.  Cache localized spell names from the actual player spellbook.
    if C_SpellBook and C_SpellBook.GetSpellBookItemName and Enum and Enum.SpellBookSpellBank then
        for i = 1, 600 do
            local ok, name = pcall(C_SpellBook.GetSpellBookItemName, i, Enum.SpellBookSpellBank.Player)
            if not ok or not name then break end
            cache[name] = true
        end
    elseif GetSpellBookItemName then
        local book = BOOKTYPE_SPELL or "spell"
        for i = 1, 600 do
            local ok, name = pcall(GetSpellBookItemName, i, book)
            if not ok or not name then break end
            cache[name] = true
        end
    end
    knownSpellNames = cache
end

local function IsKnown(id)
    if not id then return false end
    -- A true exact-ID answer is authoritative. A false answer is NOT: on
    -- Classic it may simply mean the player knows a higher rank of the spell.
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and known == true then return true end
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, id)
        if ok and known == true then return true end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, id)
        if ok and known == true then return true end
    end
    local name = SpellName(id)
    return name and knownSpellNames[name] == true or false
end

local function IsUsable(id)
    if not IsKnown(id) then return false end
    if C_Spell and C_Spell.IsSpellUsable then
        local ok, usable = pcall(C_Spell.IsSpellUsable, id)
        if ok and usable ~= nil then return usable and true or false end
    end
    if IsUsableSpell then
        local usable = IsUsableSpell(SpellName(id))
        return usable and true or false
    end
    return false
end

local function CooldownRemaining(id)
    if not id then return 999 end
    local startTime, duration, enabled
    if C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(id)
        if cd then
            startTime, duration, enabled = cd.startTime, cd.duration, cd.isEnabled
        end
    elseif GetSpellCooldown then
        startTime, duration, enabled = GetSpellCooldown(id)
    end
    if enabled == false or enabled == 0 then return 999 end
    if not startTime or startTime == 0 or not duration or duration == 0 then return 0 end
    return math.max(0, startTime + duration - GetTime())
end

local function CooldownReady(id)
    return CooldownRemaining(id) <= 0.05
end

local function PlayerLevel()
    return UnitLevel("player") or 1
end

local function UnitHealthPct(unit)
    if not UnitExists(unit) then return 100 end
    local maxHP = UnitHealthMax(unit) or 0
    if maxHP <= 0 then return 100 end
    return ((UnitHealth(unit) or 0) / maxHP) * 100
end

local function AuraByName(unit, wantedName, filter, onlyMine)
    if not wantedName or not UnitExists(unit) then return false, 0 end

    -- Classic Era 1.15.x espone C_UnitAuras. Preferiamo la API strutturata:
    -- evita dipendenze dall'ordine dei return legacy di UnitAura, che è cambiato
    -- più volte tra le patch Classic.
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local auraFilter = filter or "HELPFUL"
        if onlyMine then auraFilter = auraFilter .. "|PLAYER" end
        for i = 1, 40 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, auraFilter)
            if not ok then break end
            if not aura then break end
            if aura.name == wantedName then
                local remains = 999
                local duration = aura.duration or 0
                local expirationTime = aura.expirationTime or 0
                if duration > 0 and expirationTime > 0 then
                    remains = math.max(0, expirationTime - GetTime())
                end
                return true, remains
            end
        end
        return false, 0
    end

    -- Fallback legacy, sempre protetto: un'API incompatibile non deve mai
    -- trasformarsi in una valanga di errori durante lo spam.
    if UnitAura then
        for i = 1, 40 do
            local ok, name, _, _, _, duration, expirationTime, source = pcall(UnitAura, unit, i, filter)
            if not ok or not name then break end
            if name == wantedName and (not onlyMine or source == "player") then
                local remains = 999
                if duration and duration > 0 and expirationTime and expirationTime > 0 then
                    remains = math.max(0, expirationTime - GetTime())
                end
                return true, remains
            end
        end
    end
    return false, 0
end

local function HasPlayerBuff(id)
    return AuraByName("player", SpellName(id), "HELPFUL", false)
end

local function HasMyTargetDebuff(id)
    return AuraByName("target", SpellName(id), "HARMFUL", true)
end

local function HostileLiveTarget()
    return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
end

local function TalentTabCompat(index)
    -- Classic Era 1.15.8+ changed GetTalentTabInfo from the legacy
    -- name, texture, pointsSpent... layout to
    -- id, name, description, icon, pointsSpent... .
    -- Detect the layout at runtime so the addon also remains compatible
    -- with older Classic branches.
    local a, b, c, d, e = GetTalentTabInfo(index)
    local name, points
    if type(a) == "number" and type(b) == "string" then
        name = b
        points = tonumber(e) or 0
    else
        name = type(a) == "string" and a or (type(b) == "string" and b or nil)
        points = tonumber(c) or tonumber(e) or 0
    end
    return name, points
end

local function TalentSpec()
    local fallback = CLASS_FALLBACK_SPEC[PLAYER_CLASS] or 1
    if not GetTalentTabInfo or PlayerLevel() < 10 then
        return fallback, "Leveling", 0
    end
    local bestIndex, bestName, bestPoints = fallback, "Leveling", -1
    for i = 1, 3 do
        local name, points = TalentTabCompat(i)
        if points > bestPoints then
            bestIndex, bestName, bestPoints = i, (name or ("Tree " .. i)), points
        end
    end
    if bestPoints <= 0 then bestIndex = fallback end
    return bestIndex, bestName, bestPoints
end

local function HasWandEquipped()
    local link = GetInventoryItemLink("player", 18)
    if not link or not GetItemInfo then return false end
    local classID = select(12, GetItemInfo(link))
    local subClassID = select(13, GetItemInfo(link))
    return classID == 2 and subClassID == 19
end


HCOB_Hunter = HCOB_Hunter or {}

function HCOB_Hunter.ManaPct()
    local maxMana = UnitPowerMax("player", 0) or 0
    if maxMana <= 0 then return 100 end
    return ((UnitPower("player", 0) or 0) / maxMana) * 100
end

function HCOB_Hunter.PetAlive()
    return UnitExists("pet") and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("pet"))
end

function HCOB_Hunter.PetHP()
    if not HCOB_Hunter.PetAlive() then return nil end
    local maxHP = UnitHealthMax("pet") or 0
    if maxHP <= 0 then return nil end
    return ((UnitHealth("pet") or 0) / maxHP) * 100
end

function HCOB_Hunter.PetIsTanking()
    if not HCOB_Hunter.PetAlive() or not UnitExists("targettarget") or not UnitIsUnit then return false end
    local ok, same = pcall(UnitIsUnit, "targettarget", "pet")
    return ok and same and true or false
end

function HCOB_Hunter.TargetIsClose()
    if not HostileLiveTarget() then return false end
    if HCOB_Hunter.lastMeleeAt and (GetTime() - HCOB_Hunter.lastMeleeAt) <= 2.5 then return true end

    -- Wing Clip has true melee range, so it is the best dead-zone detector once learned.
    if IsKnown(S.WING_CLIP) and IsSpellInRange then
        local name = SpellName(S.WING_CLIP)
        if name then
            local ok, inRange = pcall(IsSpellInRange, name, "target")
            if ok and inRange == 1 then return true end
        end
    end

    if CheckInteractDistance then
        local ok, close = pcall(CheckInteractDistance, "target", 3)
        if ok and close then return true end
    end
    return false
end

function HCOB_Hunter.RangedSpeed()
    if not UnitRangedDamage then return 0 end
    local ok, speed = pcall(UnitRangedDamage, "player")
    if not ok then return 0 end
    return tonumber(speed) or 0
end

function HCOB_Hunter.AfterAutoWindow()
    if not HCOB_Hunter.lastAutoShotAt then return false end
    local elapsed = GetTime() - HCOB_Hunter.lastAutoShotAt
    local speed = HCOB_Hunter.RangedSpeed()
    local window = 0.75
    if speed > 0 then window = math.min(0.85, math.max(0.45, speed * 0.28)) end
    return elapsed >= 0 and elapsed <= window
end

function HCOB_Hunter.CanShootTarget()
    if not HostileLiveTarget() then return false end
    local probe
    if IsKnown(S.CONCUSSIVE_SHOT) then probe = S.CONCUSSIVE_SHOT
    elseif IsKnown(S.ARCANE_SHOT) then probe = S.ARCANE_SHOT
    elseif IsKnown(S.SERPENT_STING) then probe = S.SERPENT_STING end
    if not probe then return not HCOB_Hunter.TargetIsClose() end

    local name = SpellName(probe)
    if name and IsSpellInRange then
        local ok, inRange = pcall(IsSpellInRange, name, "target")
        if ok and inRange ~= nil then return inRange == 1 end
    end
    return not HCOB_Hunter.TargetIsClose()
end


-- -------------------------------------------------------------------------
-- Hunter pet feeding (Classic happiness system)
-- -------------------------------------------------------------------------
HCOB_Hunter.foodDirty = true
HCOB_Hunter.foodCandidate = nil
HCOB_Hunter.foodDataPending = false

HCOB_Hunter.dietAliases = {
    meat="Meat", carne="Meat", viande="Meat", fleisch="Meat",
    fish="Fish", pesce="Fish", poisson="Fish", fisch="Fish", pescado="Fish",
    bread="Bread", pane="Bread", pain="Bread", brot="Bread", pan="Bread",
    cheese="Cheese", formaggio="Cheese", fromage="Cheese", kaese="Cheese", queso="Cheese",
    fruit="Fruit", frutta="Fruit", obst="Fruit", fruta="Fruit",
    fungus="Fungus", fungo="Fungus", funghi="Fungus", champignon="Fungus", pilz="Fungus", hongo="Fungus",
}

function HCOB_Hunter.InvalidateFood()
    HCOB_Hunter.foodDirty = true
end

function HCOB_Hunter.Happiness()
    if not GetPetHappiness or not HCOB_Hunter.PetAlive() then return nil, nil, nil end
    local ok, happiness, damagePct, loyaltyRate = pcall(GetPetHappiness)
    if not ok then return nil, nil, nil end
    return tonumber(happiness), tonumber(damagePct), tonumber(loyaltyRate)
end

function HCOB_Hunter.PetIsEating()
    if not HCOB_Hunter.PetAlive() then return false, 0 end
    local effectName = SpellName(S.FEED_PET_EFFECT, "Feed Pet Effect")
    local has, remains = AuraByName("pet", effectName, "HELPFUL", false)
    return has and true or false, tonumber(remains) or 0
end

function HCOB_Hunter.CanonicalDietName(name)
    if type(name) ~= "string" or name == "" then return nil end
    if name == "Meat" or name == "Fish" or name == "Bread" or name == "Cheese" or name == "Fruit" or name == "Fungus" then return name end
    local lower = string.lower(name)
    local direct = HCOB_Hunter.dietAliases[lower]
    if direct then return direct end
    -- Small locale-safe fallback for labels such as "Funghi"/"Fungus".
    for token, canonical in pairs(HCOB_Hunter.dietAliases) do
        if string.find(lower, token, 1, true) then return canonical end
    end
    return nil
end

function HCOB_Hunter.PetDietSet()
    local result = {}
    if not GetPetFoodTypes or not HCOB_Hunter.PetAlive() then return result end
    local ok, foods = pcall(function() return { GetPetFoodTypes() } end)
    if not ok or type(foods) ~= "table" then return result end
    for _, foodType in ipairs(foods) do
        local canonical = HCOB_Hunter.CanonicalDietName(foodType)
        if canonical then result[canonical] = true end
    end
    return result
end

function HCOB_Hunter.PetDietText()
    local set = HCOB_Hunter.PetDietSet()
    local list = {}
    for _, name in ipairs({"Meat","Fish","Bread","Cheese","Fruit","Fungus"}) do
        if set[name] then list[#list+1] = name end
    end
    if #list == 0 then return "sconosciuta" end
    return table.concat(list, "/")
end

function HCOB_Hunter.BagSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
        if ok then return tonumber(n) or 0 end
    end
    if GetContainerNumSlots then
        local ok, n = pcall(GetContainerNumSlots, bag)
        if ok then return tonumber(n) or 0 end
    end
    return 0
end

function HCOB_Hunter.BagItemID(bag, slot)
    if C_Container and C_Container.GetContainerItemID then
        local ok, id = pcall(C_Container.GetContainerItemID, bag, slot)
        if ok then return tonumber(id) end
    end
    if GetContainerItemID then
        local ok, id = pcall(GetContainerItemID, bag, slot)
        if ok then return tonumber(id) end
    end
    return nil
end

function HCOB_Hunter.BagItemMeta(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" then
            return info.isLocked and true or false, tonumber(info.stackCount) or 1
        end
    end
    if GetContainerItemInfo then
        local ok, _, count, locked = pcall(GetContainerItemInfo, bag, slot)
        if ok then return locked and true or false, tonumber(count) or 1 end
    end
    return false, 1
end

function HCOB_Hunter.IsQuestBagItem(bag, slot)
    if C_Container and C_Container.GetContainerItemQuestInfo then
        local ok, a = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
        if ok then
            if type(a) == "table" then return a.isQuestItem == true or (tonumber(a.questID) or 0) > 0 end
            if a == true then return true end
        end
    elseif GetContainerItemQuestInfo then
        local ok, a, questID = pcall(GetContainerItemQuestInfo, bag, slot)
        if ok and (a == true or (tonumber(questID) or 0) > 0) then return true end
    end
    return false
end

function HCOB_Hunter.FoodTier(itemLevel)
    local petLevel = UnitLevel("pet") or PlayerLevel()
    itemLevel = tonumber(itemLevel) or 0
    local diff = math.max(0, petLevel - itemLevel)
    if diff <= 15 then return 3 end
    if diff <= 25 then return 2 end
    if diff <= 35 then return 1 end
    return 0
end

function HCOB_Hunter.RefreshFoodCandidate(force)
    if PLAYER_CLASS ~= "HUNTER" then return nil end
    if not force and not HCOB_Hunter.foodDirty then return HCOB_Hunter.foodCandidate end
    if InCombatLockdown and InCombatLockdown() then return HCOB_Hunter.foodCandidate end

    HCOB_Hunter.foodDirty = false
    HCOB_Hunter.foodDataPending = false
    HCOB_Hunter.foodCandidate = nil

    if not HCOB_Hunter.PetAlive() or type(HCOB_PetFoodDB) ~= "table" then return nil end
    local diet = HCOB_Hunter.PetDietSet()
    if not next(diet) then return nil end

    local playerLevel = PlayerLevel()
    local best
    for bag = 0, 4 do
        local slots = HCOB_Hunter.BagSlots(bag)
        for slot = 1, slots do
            local itemID = HCOB_Hunter.BagItemID(bag, slot)
            local food = itemID and HCOB_PetFoodDB[itemID]
            if food and diet[food.category] then
                local locked, count = HCOB_Hunter.BagItemMeta(bag, slot)
                if not locked and not HCOB_Hunter.IsQuestBagItem(bag, slot) then
                    local name, _, _, itemLevel, minLevel = GetItemInfo and GetItemInfo(itemID)
                    if not name then
                        HCOB_Hunter.foodDataPending = true
                        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
                    else
                        itemLevel = tonumber(itemLevel) or 0
                        minLevel = tonumber(minLevel) or 0
                        local tier = HCOB_Hunter.FoodTier(itemLevel)
                        if tier > 0 and minLevel <= playerLevel then
                            local candidate = {
                                itemID=itemID, name=name, bag=bag, slot=slot, count=count,
                                category=food.category, priority=tonumber(food.priority) or 4,
                                itemLevel=itemLevel, tier=tier,
                            }
                            local better = not best
                                or candidate.tier > best.tier
                                or (candidate.tier == best.tier and candidate.priority < best.priority)
                                or (candidate.tier == best.tier and candidate.priority == best.priority and candidate.itemLevel < best.itemLevel)
                                or (candidate.tier == best.tier and candidate.priority == best.priority and candidate.itemLevel == best.itemLevel and candidate.count < best.count)
                            if better then best = candidate end
                        end
                    end
                end
            end
        end
    end
    HCOB_Hunter.foodCandidate = best
    return best
end

function HCOB_Hunter.FoodCandidate()
    return HCOB_Hunter.RefreshFoodCandidate(false)
end

function HCOB_Hunter.FeedMacro()
    local mendName = IsKnown(S.MEND_PET) and SpellName(S.MEND_PET, "Mend Pet") or nil
    local feedName = IsKnown(S.FEED_PET) and SpellName(S.FEED_PET, "Feed Pet") or nil
    local eating = HCOB_Hunter.PetIsEating()
    local happiness = HCOB_Hunter.Happiness()
    local food = (not eating and happiness and happiness < 3 and feedName) and HCOB_Hunter.FoodCandidate() or nil
    local lines = {}

    if mendName and feedName and food then
        lines[#lines+1] = "/cast [combat,@pet] " .. mendName .. "; [nocombat] " .. feedName
    elseif mendName then
        lines[#lines+1] = "/cast [combat,@pet] " .. mendName
    elseif feedName and food then
        lines[#lines+1] = "/cast [nocombat] " .. feedName
    end

    if food then
        -- Feed Pet requires the pet nearby. Follow is harmless and prevents a
        -- distant pet from making the user wonder why the food did not fire.
        table.insert(lines, 1, "/petfollow [nocombat]")
        lines[#lines+1] = string.format("/use [nocombat] %d %d", food.bag, food.slot)
    end

    if #lines == 0 then return "/stopmacro" end
    local macro = table.concat(lines, "\n")
    if #macro > MACRO_LIMIT then return string.sub(macro, 1, MACRO_LIMIT) end
    return macro
end

function HCOB_Hunter.PrintFoodStatus()
    if PLAYER_CLASS ~= "HUNTER" then
        print("|cffffcc00HCOB:|r /hcob petfood e' disponibile solo su Hunter.")
        return
    end
    if not HCOB_Hunter.PetAlive() then
        print("|cffffcc00HCOB PET:|r nessun pet vivo evocato.")
        return
    end
    local happiness, damagePct, loyaltyRate = HCOB_Hunter.Happiness()
    local happyText = ({[1]="UNHAPPY", [2]="CONTENT", [3]="HAPPY"})[happiness] or "?"
    local eating, remains = HCOB_Hunter.PetIsEating()
    local food = HCOB_Hunter.RefreshFoodCandidate(not UnitAffectingCombat("player"))
    print(string.format("|cff00ff98HCOB PET:|r %s | damage=%s%% | loyalty=%s | diet=%s", happyText, tostring(damagePct or "?"), tostring(loyaltyRate or "?"), HCOB_Hunter.PetDietText()))
    if eating then
        print(string.format("|cff00ff98HCOB PET:|r sta mangiando (%.0fs rimasti): ALT+CTRL feed disarmato.", remains or 0))
    elseif food then
        print(string.format("|cff00ff98HCOB PET:|r scelto %s x%d (bag %d slot %d, %s, tier %d).", food.name, food.count or 1, food.bag, food.slot, food.category, food.tier or 0))
    else
        print("|cffffcc00HCOB PET:|r nessun cibo compatibile/utile trovato nelle borse.")
    end
end

local Mage = {}

function Mage.ManaPct()
    local maxMana = UnitPowerMax("player", 0) or 0
    if maxMana <= 0 then return 100 end
    return ((UnitPower("player", 0) or 0) / maxMana) * 100
end

function Mage.TargetIsClose()
    if not HostileLiveTarget() then return false end
    if Mage.lastMeleeAt and (GetTime() - Mage.lastMeleeAt) <= 2.5 then return true end
    -- Duel distance is roughly 7 yards and works on hostile units too.
    -- We use it only as a conservative melee-pressure hint.
    if CheckInteractDistance then
        local ok, close = pcall(CheckInteractDistance, "target", 3)
        if ok then return close and true or false end
    end
    return false
end

function Mage.PolymorphEligible()
    if not HostileLiveTarget() or not UnitCreatureType then return false end
    local ok, _, creatureTypeID = pcall(UnitCreatureType, "target")
    if not ok then return false end
    -- Classic Polymorph: Beast, Humanoid, Critter.
    return creatureTypeID == 1 or creatureTypeID == 7 or creatureTypeID == 8
end

function Mage.RankedName(id)
    if GetSpellInfo then
        local name, rank = GetSpellInfo(id)
        if name and rank and rank ~= "" then
            return name .. "(" .. rank .. ")"
        end
    end
    return SpellName(id)
end

function Mage.PrimarySpell()
    local spec = TalentSpec()
    local level = PlayerLevel()

    if spec == 3 and IsKnown(S.FROSTBOLT) then return S.FROSTBOLT end
    if spec == 2 and IsKnown(S.FIREBALL) then return S.FIREBALL end

    if spec == 1 then
        if level >= 47 and IsKnown(S.FROSTBOLT) then return S.FROSTBOLT end
        if IsKnown(S.FIREBALL) then return S.FIREBALL end
        if IsKnown(S.FROSTBOLT) then return S.FROSTBOLT end
        if IsKnown(S.ARCANE_MISSILES) then return S.ARCANE_MISSILES end
    end

    if IsKnown(S.FROSTBOLT) then return S.FROSTBOLT end
    if IsKnown(S.FIREBALL) then return S.FIREBALL end
    return S.ARCANE_MISSILES
end

function Mage.BestArmor()
    local spec = TalentSpec()
    if spec ~= 3 and IsKnown(S.MAGE_ARMOR) then return S.MAGE_ARMOR end
    if IsKnown(S.ICE_ARMOR) then return S.ICE_ARMOR end
    if IsKnown(S.FROST_ARMOR) then return S.FROST_ARMOR end
    if IsKnown(S.MAGE_ARMOR) then return S.MAGE_ARMOR end
    return nil
end

local function MainhandSpeed()
    local speed = UnitAttackSpeed("player")
    return speed or 0
end

local function BestPaladinSeal()
    if IsKnown(S.SEAL_COMMAND) and MainhandSpeed() >= 3.2 then return S.SEAL_COMMAND end
    if IsKnown(S.SEAL_RIGHTEOUSNESS) then return S.SEAL_RIGHTEOUSNESS end
    if IsKnown(S.SEAL_COMMAND) then return S.SEAL_COMMAND end
end

local function PetHasSpell(id)
    local wanted = SpellName(id)
    if not wanted or not UnitExists("pet") or not GetPetActionInfo then return false end
    for i = 1, 10 do
        local name = GetPetActionInfo(i)
        if name == wanted then return true end
    end
    return false
end

local function NewLines()
    return {}
end

local function AddLine(lines, text, priority)
    if text and text ~= "" then
        table.insert(lines, { text = text, priority = priority or 5 })
    end
end

local function FitMacro(lines)
    local function join()
        local out = {}
        for _, v in ipairs(lines) do table.insert(out, v.text) end
        return table.concat(out, "\n")
    end
    local text = join()
    while #text > MACRO_LIMIT and #lines > 1 do
        local worstIndex, worstPriority = nil, -1
        for i, v in ipairs(lines) do
            if v.priority > worstPriority then
                worstIndex, worstPriority = i, v.priority
            elseif v.priority == worstPriority and worstIndex then
                worstIndex = i
            end
        end
        if not worstIndex then break end
        table.remove(lines, worstIndex)
        text = join()
    end
    if #text > MACRO_LIMIT then
        return "/stopmacro"
    end
    return text
end

local function CastLine(id, condition, bang)
    if not id or not IsKnown(id) then return nil end
    local cond = condition and ("[" .. condition .. "] ") or ""
    return "/cast " .. cond .. (bang and "!" or "") .. SpellName(id)
end

local function RawCastLine(id, condition, bang)
    local name = SpellName(id)
    if not name then return nil end
    local cond = condition and ("[" .. condition .. "] ") or ""
    return "/cast " .. cond .. (bang and "!" or "") .. name
end

local function SequenceLine(condition, reset, ids)
    local names = {}
    for _, id in ipairs(ids or {}) do
        if id == 0 then
            table.insert(names, "null")
        elseif IsKnown(id) then
            table.insert(names, SpellName(id))
        end
    end
    if #names == 0 then return nil end
    local cond = condition and ("[" .. condition .. "] ") or ""
    return "/castsequence " .. cond .. "reset=" .. reset .. " " .. table.concat(names, ",")
end

local currentWarriorAutoRend = false

local function WarriorTargetWantsRend()
    if HCOB_DB.warriorAutoRend == false or not IsKnown(S.REND) then return false end
    if not HostileLiveTarget() then return false end
    local playerLevel = PlayerLevel()
    local targetLevel = tonumber(UnitLevel("target")) or -1
    local classification = UnitClassification("target") or "normal"
    local tough = classification == "elite" or classification == "rareelite" or classification == "worldboss"
    if tough then return true end
    -- At low level Rend is worth the GCD mainly when the target is expected to
    -- live for a while.  Skip it on trivial mobs two or more levels below us.
    return targetLevel <= 0 or targetLevel >= (playerLevel - 1)
end

local function BuildWarriorMain()
    HCOB_DB.warriorHeroicSpam = false
    -- SAFE BASE v1.11:
    --   * /startattack sempre;
    --   * Charge fuori combat;
    --   * Rend x1 solo sui target che vale la pena dot-tare;
    --   * Heroic Strike NON e' mai nello spam base.
    --
    -- Una secure macro non puo' leggere la rage e decidere se accodare HS.
    -- HS resta quindi una decisione dell'Advisor e si usa manualmente (ALT+SHIFT)
    -- solo quando la soglia rage adattiva e' realmente raggiunta.
    local lines = NewLines()
    AddLine(lines, "/startattack [harm]", 1)
    AddLine(lines, CastLine(S.CHARGE, "nocombat,harm", false), 1)

    local hasMajorSpender = IsKnown(S.MORTAL_STRIKE) or IsKnown(S.BLOODTHIRST)

    currentWarriorAutoRend = false
    if not hasMajorSpender and WarriorTargetWantsRend() then
        local rend = SpellName(S.REND)
        if rend then
            AddLine(lines, "/castsequence [combat,harm] reset=target/combat " .. rend .. ", null", 2)
            currentWarriorAutoRend = true
        end
    end

    return FitMacro(lines)
end


local function BuildPaladinMain()
    -- Base sicura: auto attack. Seal/Judgement vengono gestiti dall'Advisor.
    local lines = NewLines()
    AddLine(lines, "/startattack", 1)
    return FitMacro(lines)
end


local function BuildHunterMain()
    local lines = NewLines()
    AddLine(lines, "/petattack [harm]", 1)
    -- Hunter v1.17.1: Auto Shot is an auto-repeat, not a spam filler.
    -- Start it once per target/combat and then park the castsequence on `null`.
    -- This prevents repeated BASE presses from re-issuing !Auto Shot while still
    -- letting a failed first attempt (moving/out of range) retry until it succeeds.
    if IsKnown(S.AUTO_SHOT) then
        AddLine(lines, "/castsequence [harm] reset=target/combat !" .. SpellName(S.AUTO_SHOT) .. ", null", 1)
    end
    return FitMacro(lines)
end


local function BuildRogueMain()
    local lines = NewLines()
    local spec = TalentSpec()
    local builder = (spec == 3 and IsKnown(S.HEMORRHAGE)) and S.HEMORRHAGE or S.SINISTER_STRIKE
    AddLine(lines, "/startattack", 1)
    AddLine(lines, CastLine(builder, "combat,harm", false), 1)
    return FitMacro(lines)
end


local function BuildPriestMain()
    local lines = NewLines()
    local spec = TalentSpec()
    if HasWandEquipped() and IsKnown(S.SHOOT) then
        AddLine(lines, "/cast [harm] !" .. SpellName(S.SHOOT), 1)
    elseif spec == 3 and IsKnown(S.MIND_FLAY) then
        AddLine(lines, CastLine(S.MIND_FLAY, "harm", false), 1)
    else
        AddLine(lines, CastLine(S.SMITE, "harm", false), 1)
    end
    return FitMacro(lines)
end


local function BuildMageMain()
    local lines = NewLines()
    local primary = Mage.PrimarySpell()
    AddLine(lines, CastLine(primary, "harm", false), 1)
    return FitMacro(lines)
end

local function BuildWarlockMain()
    local lines = NewLines()
    AddLine(lines, "/petattack [harm]", 1)
    local spec = TalentSpec()
    if HasWandEquipped() and IsKnown(S.SHOOT) and spec ~= 3 then
        AddLine(lines, "/cast [harm] !" .. SpellName(S.SHOOT), 1)
    else
        AddLine(lines, CastLine(S.SHADOW_BOLT, "harm", false), 1)
    end
    return FitMacro(lines)
end


local function BuildDruidMain()
    local lines = NewLines()
    local spec = TalentSpec()
    if spec == 2 then
        if IsKnown(S.CAT_FORM) then AddLine(lines, CastLine(S.CAT_FORM, "noform", false), 2)
        elseif IsKnown(S.BEAR_FORM) then AddLine(lines, CastLine(S.BEAR_FORM, "noform", false), 2) end
    end
    AddLine(lines, "/startattack [form:1/3]", 1)
    if IsKnown(S.CAT_FORM) and IsKnown(S.CLAW) then AddLine(lines, CastLine(S.CLAW, "form:3,harm", false), 1) end
    -- In Bear lasciamo l'auto attack: Maul e' un rage spender situazionale.
    AddLine(lines, CastLine(S.WRATH, "noform,harm", false), 1)
    return FitMacro(lines)
end


local function BuildShamanMain()
    local lines = NewLines()
    local spec = TalentSpec()
    if spec == 2 then
        AddLine(lines, CastLine(S.LIGHTNING_BOLT, "nocombat,harm", false), 3)
        AddLine(lines, "/startattack", 1)
    else
        AddLine(lines, CastLine(S.LIGHTNING_BOLT, "harm", false), 1)
    end
    return FitMacro(lines)
end


local MAIN_BUILDERS = {
    WARRIOR=BuildWarriorMain, PALADIN=BuildPaladinMain, HUNTER=BuildHunterMain,
    ROGUE=BuildRogueMain, PRIEST=BuildPriestMain, MAGE=BuildMageMain,
    WARLOCK=BuildWarlockMain, DRUID=BuildDruidMain, SHAMAN=BuildShamanMain,
}

local function BuildSpellMacro(id, condition, startAttack, allowUnknown)
    if not id then return "/stopmacro" end
    if not allowUnknown and not IsKnown(id) then return "/stopmacro" end
    local line = allowUnknown and RawCastLine(id, condition, false) or CastLine(id, condition, false)
    if not line then return "/stopmacro" end
    if startAttack then return "/startattack\n" .. line end
    return line
end

local function BuildWarriorMods()
    local interrupt = NewLines()
    AddLine(interrupt, IsKnown(S.PUMMEL) and ("/cast [stance:3] " .. SpellName(S.PUMMEL)) or nil, 1)
    AddLine(interrupt, IsKnown(S.SHIELD_BASH) and ("/cast [stance:1/2] " .. SpellName(S.SHIELD_BASH)) or nil, 1)
    local panic = IsKnown(S.RETALIATION) and BuildSpellMacro(S.RETALIATION, "stance:1", false) or BuildSpellMacro(S.DEMO_SHOUT)
    return {
        shift=BuildSpellMacro(S.BATTLE_SHOUT), ctrl=BuildSpellMacro(S.THUNDER_CLAP, nil, true),
        alt=BuildSpellMacro(S.HAMSTRING, nil, true), ctrlshift=FitMacro(interrupt),
        altshift=BuildSpellMacro(S.HEROIC_STRIKE, nil, true), altctrl=BuildSpellMacro(S.BLOODRAGE, "combat"),
        all=panic,
        desc={shift="Battle Shout",ctrl="Thunder Clap",alt="Hamstring",ctrlshift="Interrupt",altshift="Heroic Strike",altctrl="Bloodrage",all="Retaliation / Demo Shout"}
    }
end

local function BuildPaladinMods()
    return {
        shift=BuildSpellMacro(S.BLESSING_MIGHT, "@player"), ctrl=BuildSpellMacro(S.CONSECRATION),
        alt=BuildSpellMacro(S.HAMMER_JUSTICE, "harm"), ctrlshift=BuildSpellMacro(S.HAMMER_JUSTICE, "harm"),
        altshift=BuildSpellMacro(S.HAMMER_WRATH, "harm"), altctrl=BuildSpellMacro(S.DIVINE_PROTECTION),
        all=BuildSpellMacro(S.LAY_ON_HANDS, "@player"),
        desc={shift="Blessing of Might",ctrl="Consecration",alt="Hammer of Justice",ctrlshift="Stop cast / stun",altshift="Hammer of Wrath",altctrl="Divine Protection",all="Lay on Hands"}
    }
end

local function BuildHunterMods()
    -- One modifier per job. ALT+CTRL is context-safe: in combat Mend Pet;
    -- out of combat it feeds the best compatible bag item selected by HCOB.
    local control = NewLines()
    if IsKnown(S.SCATTER_SHOT) then AddLine(control, BuildSpellMacro(S.SCATTER_SHOT, "harm"), 1) end
    if IsKnown(S.CONCUSSIVE_SHOT) then AddLine(control, BuildSpellMacro(S.CONCUSSIVE_SHOT, "harm"), 2) end
    if #control == 0 then AddLine(control, "/stopmacro", 1) end

    local burst = IsKnown(S.AIMED_SHOT) and BuildSpellMacro(S.AIMED_SHOT, "harm") or BuildSpellMacro(S.ARCANE_SHOT, "harm")

    local panic = NewLines()
    AddLine(panic, "/petpassive", 1)
    AddLine(panic, "/petfollow", 1)
    AddLine(panic, BuildSpellMacro(S.FEIGN_DEATH), 1)

    local eating = HCOB_Hunter.PetIsEating()
    local happiness = HCOB_Hunter.Happiness()
    local food = (not eating and happiness and happiness < 3) and HCOB_Hunter.FoodCandidate() or nil
    local petUtilityDesc = "Mend Pet"
    if not UnitAffectingCombat("player") then
        if eating then petUtilityDesc = "Pet eating (locked)"
        elseif food then petUtilityDesc = "Feed Pet: " .. tostring(food.name)
        else petUtilityDesc = "Feed Pet / Mend Pet" end
    end

    return {
        shift=BuildSpellMacro(S.ASPECT_HAWK), ctrl=BuildSpellMacro(S.MULTI_SHOT, "harm"),
        alt=BuildSpellMacro(S.WING_CLIP, "harm", true), ctrlshift=FitMacro(control),
        altshift=burst, altctrl=HCOB_Hunter.FeedMacro(),
        all=FitMacro(panic),
        desc={shift="Aspect of the Hawk",ctrl="Multi-Shot",alt="Wing Clip",ctrlshift="Scatter / Concussive",altshift=IsKnown(S.AIMED_SHOT) and "Aimed Shot" or "Arcane Shot",altctrl=petUtilityDesc,all="Pet passive + Feign Death"}
    }
end

local function BuildRogueMods()
    return {
        shift=BuildSpellMacro(S.STEALTH), ctrl=BuildSpellMacro(S.GOUGE, "harm", true),
        alt=BuildSpellMacro(S.SPRINT), ctrlshift=BuildSpellMacro(S.KICK, "harm", true),
        altshift=BuildSpellMacro(S.EVISCERATE, "harm", true), altctrl=BuildSpellMacro(S.EVASION),
        all=BuildSpellMacro(S.VANISH),
        desc={shift="Stealth",ctrl="Gouge",alt="Sprint",ctrlshift="Kick",altshift="Eviscerate",altctrl="Evasion",all="Vanish"}
    }
end

local function BuildPriestMods()
    return {
        shift=BuildSpellMacro(S.FORTITUDE, "@player"), ctrl=BuildSpellMacro(S.PSYCHIC_SCREAM),
        alt=BuildSpellMacro(S.POWER_WORD_SHIELD, "@player"), ctrlshift=BuildSpellMacro(S.SILENCE, "harm"),
        altshift=BuildSpellMacro(S.MIND_BLAST, "harm"), altctrl=BuildSpellMacro(S.RENEW, "@player"),
        all=BuildSpellMacro(S.PSYCHIC_SCREAM),
        desc={shift="Power Word: Fortitude",ctrl="Psychic Scream",alt="Power Word: Shield",ctrlshift="Silence",altshift="Mind Blast",altctrl="Renew",all="Psychic Scream"}
    }
end

local function BuildMageMods()
    -- SHIFT does double duty without any combat-state automation: with a hostile
    -- target it toggles the wand; otherwise it buffs Arcane Intellect.
    local shift = BuildSpellMacro(S.ARCANE_INTELLECT, "@player")
    if HasWandEquipped() and IsKnown(S.SHOOT) and IsKnown(S.ARCANE_INTELLECT) then
        shift = "/cast [harm] !" .. SpellName(S.SHOOT) .. "; [@player] " .. SpellName(S.ARCANE_INTELLECT)
    elseif HasWandEquipped() and IsKnown(S.SHOOT) then
        shift = "/cast [harm] !" .. SpellName(S.SHOOT)
    end

    -- Frost Nova rank 1 has the same root utility and is dramatically cheaper;
    -- use the localized rank string so non-English clients are safe.
    local nova = IsKnown(S.FROST_NOVA) and ("/cast " .. Mage.RankedName(S.FROST_NOVA)) or "/stopmacro"

    -- ALL MODS is a real HC panic chain. Failed/unavailable casts fall through
    -- to the next defensive; only one protected GCD action can succeed.
    local panicLines = NewLines()
    AddLine(panicLines, IsKnown(S.ICE_BLOCK) and ("/cast " .. SpellName(S.ICE_BLOCK)) or nil, 1)
    AddLine(panicLines, IsKnown(S.FROST_NOVA) and nova or nil, 2)
    AddLine(panicLines, IsKnown(S.MANA_SHIELD) and ("/cast " .. SpellName(S.MANA_SHIELD)) or nil, 3)
    local panic = FitMacro(panicLines)

    return {
        shift=shift, ctrl=nova,
        alt=BuildSpellMacro(S.BLINK), ctrlshift=BuildSpellMacro(S.COUNTERSPELL, "harm"),
        altshift=BuildSpellMacro(S.FIRE_BLAST, "harm"), altctrl=BuildSpellMacro(S.POLYMORPH, "harm"), all=panic,
        desc={shift="Wand / Arcane Intellect",ctrl="Frost Nova R1",alt="Blink",ctrlshift="Counterspell",altshift="Fire Blast",altctrl="Polymorph",all="Ice Block / Nova R1 / Mana Shield"}
    }
end

local function BuildWarlockMods()
    local armor = IsKnown(S.DEMON_ARMOR) and S.DEMON_ARMOR or S.DEMON_SKIN
    local burst = IsKnown(S.SHADOWBURN) and S.SHADOWBURN or S.DRAIN_LIFE
    local panic = IsKnown(S.DEATH_COIL) and BuildSpellMacro(S.DEATH_COIL, "harm") or BuildSpellMacro(S.FEAR, "harm")
    return {
        shift=BuildSpellMacro(armor), ctrl=BuildSpellMacro(S.FEAR, "harm"),
        alt=BuildSpellMacro(S.DRAIN_LIFE, "harm"), ctrlshift=BuildSpellMacro(S.SPELL_LOCK, "harm", false, true),
        altshift=BuildSpellMacro(burst, "harm"), altctrl=BuildSpellMacro(S.LIFE_TAP), all=panic,
        desc={shift="Demon Armor / Skin",ctrl="Fear",alt="Drain Life",ctrlshift="Spell Lock",altshift="Shadowburn / Drain Life",altctrl="Life Tap",all="Death Coil / Fear"}
    }
end

local function BuildDruidMods()
    local mobility = IsKnown(S.DASH) and BuildSpellMacro(S.DASH) or BuildSpellMacro(S.TRAVEL_FORM)
    local stopcast = IsKnown(S.FERAL_CHARGE) and BuildSpellMacro(S.FERAL_CHARGE, "form:1,harm") or BuildSpellMacro(S.BASH, "form:1,harm")
    local panic = IsKnown(S.NATURES_GRASP) and BuildSpellMacro(S.NATURES_GRASP) or BuildSpellMacro(S.BARKSKIN)
    return {
        shift=BuildSpellMacro(S.MARK_WILD, "@player"), ctrl=BuildSpellMacro(S.ENTANGLING_ROOTS, "harm"),
        alt=mobility, ctrlshift=stopcast, altshift=BuildSpellMacro(S.FEROCIOUS_BITE, "form:3,harm", true),
        altctrl=BuildSpellMacro(S.BARKSKIN), all=panic,
        desc={shift="Mark of the Wild",ctrl="Entangling Roots",alt="Dash / Travel Form",ctrlshift="Feral Charge / Bash",altshift="Ferocious Bite",altctrl="Barkskin",all="Nature's Grasp / Barkskin"}
    }
end

local function BuildShamanMods()
    return {
        shift=BuildSpellMacro(S.LIGHTNING_SHIELD), ctrl=BuildSpellMacro(S.EARTHBIND_TOTEM),
        alt=BuildSpellMacro(S.GHOST_WOLF), ctrlshift=BuildSpellMacro(S.EARTH_SHOCK, "harm"),
        altshift=BuildSpellMacro(S.STORMSTRIKE, "harm", true), altctrl=BuildSpellMacro(S.HEALING_WAVE, "@player"),
        all=BuildSpellMacro(S.STONECLAW_TOTEM),
        desc={shift="Lightning Shield",ctrl="Earthbind Totem",alt="Ghost Wolf",ctrlshift="Earth Shock interrupt",altshift="Stormstrike",altctrl="Healing Wave",all="Stoneclaw Totem"}
    }
end

local MOD_BUILDERS = {
    WARRIOR=BuildWarriorMods, PALADIN=BuildPaladinMods, HUNTER=BuildHunterMods,
    ROGUE=BuildRogueMods, PRIEST=BuildPriestMods, MAGE=BuildMageMods,
    WARLOCK=BuildWarlockMods, DRUID=BuildDruidMods, SHAMAN=BuildShamanMods,
}

-- -------------------------------------------------------------------------
-- v1.18 Secure Advisor Actions
--
-- Blizzard non permette a un singolo SecureActionButton di cambiare spell in
-- combattimento in base a una decisione Lua.  La soluzione legale e stabile e'
-- una palette di pulsanti FISSI: ogni icona ha una spell/macro assegnata fuori
-- combat; durante il fight l'Advisor cambia soltanto l'highlight grafico.
-- Il click del giocatore sulla specifica icona resta quindi l'unico input che
-- esegue l'azione protetta.
-- -------------------------------------------------------------------------
HCOB_ActionPanel = HCOB_ActionPanel or {}
HCOB_ActionPanel.buttons = HCOB_ActionPanel.buttons or {}
HCOB_ActionPanel.idToButton = HCOB_ActionPanel.idToButton or {}
HCOB_ActionPanel.idToSlot = HCOB_ActionPanel.idToSlot or {}
HCOB_ActionPanel.idToActionIndex = HCOB_ActionPanel.idToActionIndex or {}
HCOB_ActionPanel.maxButtons = 18

-- Diagnostic RGB protocol v3. Il reader esterno NON conosce classi o spell:
-- conosce soltanto il colore e lo traduce in uno SLOT fisso del pannello.
--   R = slot fisso (1..18) * 12
--   G = 96
--   B = 224
-- Nero = NONE. Bianco = raccomandazione non mappata nel pannello.
--
-- Fondamentale: gli slot del pannello sono deterministici per classe e NON
-- vengono mai compattati in base alle spell apprese. Es. Hunter:
-- SLOT 01 Hunter's Mark, SLOT 02 Serpent Sting, SLOT 03 Arcane Shot, ecc.

HCOB_ActionPanel.actions = {
    WARRIOR={S.REND,S.OVERPOWER,S.EXECUTE,S.HEROIC_STRIKE,S.SUNDER_ARMOR,S.THUNDER_CLAP,S.DEMO_SHOUT,S.BATTLE_SHOUT,S.BLOODRAGE,S.HAMSTRING,S.MORTAL_STRIKE,S.BLOODTHIRST,S.WHIRLWIND,S.PUMMEL,S.SHIELD_BASH,S.BERSERKER_RAGE,S.RETALIATION,S.SHIELD_WALL},
    PALADIN={S.SEAL_RIGHTEOUSNESS,S.SEAL_COMMAND,S.JUDGEMENT,S.BLESSING_MIGHT,S.CONSECRATION,S.HAMMER_JUSTICE,S.EXORCISM,S.HAMMER_WRATH,S.DIVINE_PROTECTION,S.LAY_ON_HANDS,S.HOLY_LIGHT,S.FLASH_LIGHT,S.DIVINE_SHIELD,S.SEAL_CRUSADER},
    HUNTER={S.HUNTERS_MARK,S.SERPENT_STING,S.ARCANE_SHOT,S.AIMED_SHOT,S.MULTI_SHOT,S.CONCUSSIVE_SHOT,S.SCATTER_SHOT,S.WING_CLIP,S.RAPTOR_STRIKE,S.MONGOOSE_BITE,S.MEND_PET,S.FEED_PET,S.FEIGN_DEATH,S.INTIMIDATION,S.BESTIAL_WRATH,S.RAPID_FIRE,S.FREEZING_TRAP,S.ASPECT_HAWK},
    ROGUE={S.SINISTER_STRIKE,S.HEMORRHAGE,S.EVISCERATE,S.GOUGE,S.KICK,S.STEALTH,S.SPRINT,S.EVASION,S.VANISH,S.BLADE_FLURRY,S.SLICE_DICE,S.GARROTE,S.CHEAP_SHOT,S.KIDNEY_SHOT,S.BLIND,S.ADRENALINE_RUSH},
    PRIEST={S.SHADOW_WORD_PAIN,S.MIND_BLAST,S.MIND_FLAY,S.POWER_WORD_SHIELD,S.RENEW,S.PSYCHIC_SCREAM,S.SILENCE,S.FADE,S.FORTITUDE,S.SHOOT,S.LESSER_HEAL,S.HEAL,S.FLASH_HEAL,S.INNER_FIRE,S.HOLY_FIRE,S.SMITE},
    MAGE={S.FROSTBOLT,S.FIREBALL,S.FIRE_BLAST,S.FROST_NOVA,S.BLINK,S.COUNTERSPELL,S.POLYMORPH,S.ICE_BARRIER,S.MANA_SHIELD,S.ICE_BLOCK,S.COLD_SNAP,S.EVOCATION,S.PYROBLAST,S.SCORCH,S.CONE_OF_COLD,S.ARCANE_EXPLOSION,S.BLIZZARD,S.SHOOT},
    WARLOCK={S.CORRUPTION,S.CURSE_AGONY,S.IMMOLATE,S.SHADOW_BOLT,S.FEAR,S.DRAIN_LIFE,S.LIFE_TAP,S.SHADOWBURN,S.DEATH_COIL,S.SPELL_LOCK,S.DEMON_ARMOR,S.DEMON_SKIN,S.SHOOT,S.DRAIN_SOUL,S.CURSE_WEAKNESS},
    DRUID={S.MOONFIRE,S.WRATH,S.RAKE,S.CLAW,S.FEROCIOUS_BITE,S.MAUL,S.ENTANGLING_ROOTS,S.FERAL_CHARGE,S.BASH,S.BARKSKIN,S.NATURES_GRASP,S.DASH,S.TRAVEL_FORM,S.MARK_WILD},
    SHAMAN={S.FLAME_SHOCK,S.EARTH_SHOCK,S.LIGHTNING_BOLT,S.STORMSTRIKE,S.LIGHTNING_SHIELD,S.EARTHBIND_TOTEM,S.STONECLAW_TOTEM,S.HEALING_WAVE,S.GHOST_WOLF,S.FROST_SHOCK,S.SEARING_TOTEM,S.FIRE_NOVA_TOTEM,S.CHAIN_LIGHTNING},
}


-- Fixed Action Panel bindings. The physical slot remains deterministic; only
-- the hardware binding can be customized. Defaults are preserved exactly from
-- v1.18.5. Custom values live in HCOB_DB.actionSlotKeys. A stored `false` means
-- that slot is intentionally unbound.
HCOB_ActionPanel.defaultSlotKeys = {
    "SHIFT-1", "SHIFT-2", "SHIFT-3", "SHIFT-4", "SHIFT-5",
    "SHIFT-6", "SHIFT-7", "SHIFT-8", "SHIFT-9", "SHIFT-0",
    "CTRL-SHIFT-1", "CTRL-SHIFT-2", "CTRL-SHIFT-3", "CTRL-SHIFT-4",
    "CTRL-SHIFT-5", "CTRL-SHIFT-6", "CTRL-SHIFT-7", "CTRL-SHIFT-8",
}
-- Compatibility alias for older code/tools that inspected this table.
HCOB_ActionPanel.slotKeys = HCOB_ActionPanel.defaultSlotKeys

function HCOB_ActionPanel.NormalizeSlotKey(key)
    if key == false then return false end
    key = tostring(key or ""):upper():gsub("%s+", ""):gsub("%+", "-")
    key = key:gsub("CONTROL", "CTRL")
    if key == "" or key == "NONE" or key == "UNBOUND" then return false end

    local ctrl, alt, shift, base = false, false, false, nil
    for part in key:gmatch("[^%-]+") do
        if part == "CTRL" then ctrl = true
        elseif part == "ALT" then alt = true
        elseif part == "SHIFT" then shift = true
        elseif part ~= "" then base = part end
    end
    if not base then return false end

    local parts = {}
    if ctrl then parts[#parts+1] = "CTRL" end
    if alt then parts[#parts+1] = "ALT" end
    if shift then parts[#parts+1] = "SHIFT" end
    parts[#parts+1] = base
    return table.concat(parts, "-")
end

function HCOB_ActionPanel.GetSlotKey(slot)
    slot = tonumber(slot)
    if not slot then return nil end
    local custom = HCOB_DB and HCOB_DB.actionSlotKeys
    if custom and custom[slot] ~= nil then
        if custom[slot] == false then return nil end
        return HCOB_ActionPanel.NormalizeSlotKey(custom[slot])
    end
    return HCOB_ActionPanel.defaultSlotKeys and HCOB_ActionPanel.defaultSlotKeys[slot] or nil
end

function HCOB_ActionPanel.GetSlotBindingCommand(slot)
    if not slot then return nil end
    return "CLICK HCOneButtonAdvisorAction" .. tostring(slot) .. ":LeftButton"
end

function HCOB_ActionPanel.GetSlotActionName(slot)
    slot = tonumber(slot)
    local list = HCOB_ActionPanel.actions[PLAYER_CLASS] or {}
    local id = slot and list[slot] or nil
    if not id then return "<slot non usato>" end
    return SpellName(id, "Spell " .. tostring(id))
end

function HCOB_ActionPanel.FindSlotUsingKey(key, exceptSlot)
    key = HCOB_ActionPanel.NormalizeSlotKey(key)
    if not key then return nil end
    for slot=1,(HCOB_ActionPanel.maxButtons or 18) do
        if slot ~= tonumber(exceptSlot) and HCOB_ActionPanel.GetSlotKey(slot) == key then
            return slot
        end
    end
    return nil
end

function HCOB_ActionPanel.ApplySlotBindings()
    if InCombatLockdown() then return false end
    if HCOB_DB and HCOB_DB.actionSlotAutoBind == false then return false end

    HCOB_DB.actionSlotAppliedKeys = HCOB_DB.actionSlotAppliedKeys or {}
    local visible = tonumber(HCOB_ActionPanel.visibleCount) or 0
    local changed = false
    for slot=1,math.min(visible, HCOB_ActionPanel.maxButtons or 18) do
        local key = HCOB_ActionPanel.GetSlotKey(slot)
        local button = HCOB_ActionPanel.buttons and HCOB_ActionPanel.buttons[slot]
        local expected = HCOB_ActionPanel.GetSlotBindingCommand(slot)
        local oldKey = HCOB_DB.actionSlotAppliedKeys[slot]

        -- On upgrade, the old default may already be saved in WoW bindings even
        -- before actionSlotAppliedKeys exists. Clear it only if it still points
        -- to this exact HCOB slot, never if the user reassigned it elsewhere.
        if not oldKey then oldKey = HCOB_ActionPanel.defaultSlotKeys[slot] end
        oldKey = HCOB_ActionPanel.NormalizeSlotKey(oldKey)
        if oldKey and oldKey ~= key and GetBindingAction and SetBinding then
            if GetBindingAction(oldKey) == expected then
                SetBinding(oldKey)
                changed = true
            end
        end

        if key and button then
            local current = GetBindingAction and GetBindingAction(key) or ""
            if current ~= expected and SetBindingClick then
                if SetBindingClick(key, "HCOneButtonAdvisorAction"..slot, "LeftButton") then
                    changed = true
                end
            end
            button.bindingKey = key
            HCOB_DB.actionSlotAppliedKeys[slot] = key
        else
            if button then button.bindingKey = nil end
            HCOB_DB.actionSlotAppliedKeys[slot] = false
        end
    end

    if changed and SaveBindings then
        local bindingSet = GetCurrentBindingSet and GetCurrentBindingSet() or 1
        SaveBindings(bindingSet)
    end
    return true
end

function HCOB_ActionPanel.SetSlotKey(slot, key)
    if InCombatLockdown() then return false, "Modifica i binding fuori combattimento." end
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > (HCOB_ActionPanel.maxButtons or 18) then
        return false, "Slot non valido."
    end

    key = HCOB_ActionPanel.NormalizeSlotKey(key)
    if key then
        local duplicate = HCOB_ActionPanel.FindSlotUsingKey(key, slot)
        if duplicate then
            return false, string.format("%s e' gia' usato dallo SLOT %02d.", key:gsub("%-", "+"), duplicate)
        end
    end

    HCOB_DB.actionSlotKeys = HCOB_DB.actionSlotKeys or {}
    local defaultKey = HCOB_ActionPanel.defaultSlotKeys[slot]
    if key and key == defaultKey then
        HCOB_DB.actionSlotKeys[slot] = nil
    elseif key then
        HCOB_DB.actionSlotKeys[slot] = key
    else
        HCOB_DB.actionSlotKeys[slot] = false
    end

    if HCOB_DB.actionSlotAutoBind ~= false then HCOB_ActionPanel.ApplySlotBindings() end
    return true
end

function HCOB_ActionPanel.ResetSlotKey(slot)
    if InCombatLockdown() then return false, "Modifica i binding fuori combattimento." end
    slot = tonumber(slot)
    if not slot then return false, "Slot non valido." end
    if HCOB_DB.actionSlotKeys then HCOB_DB.actionSlotKeys[slot] = nil end
    if HCOB_DB.actionSlotAutoBind ~= false then HCOB_ActionPanel.ApplySlotBindings() end
    return true
end

function HCOB_ActionPanel.ResetAllSlotKeys()
    if InCombatLockdown() then return false, "Modifica i binding fuori combattimento." end
    HCOB_DB.actionSlotKeys = nil
    if HCOB_DB.actionSlotAutoBind ~= false then HCOB_ActionPanel.ApplySlotBindings() end
    return true
end

function HCOB_ActionPanel.PrintSlotBindings()
    local visible = tonumber(HCOB_ActionPanel.visibleCount) or 0
    print("|cff00ff98HCOB ACTION BINDS:|r slot -> tasto -> azione")
    for slot=1,math.min(visible, HCOB_ActionPanel.maxButtons or 18) do
        local key = HCOB_ActionPanel.GetSlotKey(slot)
        local b = HCOB_ActionPanel.buttons and HCOB_ActionPanel.buttons[slot]
        local name = b and b.actionName or HCOB_ActionPanel.GetSlotActionName(slot)
        print(string.format("%02d -> %s -> %s", slot, key and key:gsub("%-", "+") or "<nessuno>", tostring(name)))
    end
end

function HCOB_ActionPanel.CapturedKey(base)
    base = tostring(base or ""):upper()
    local ignore = {LSHIFT=true,RSHIFT=true,LCTRL=true,RCTRL=true,LALT=true,RALT=true,SHIFT=true,CTRL=true,ALT=true}
    if ignore[base] then return nil end
    local mouseMap = {LEFTBUTTON="BUTTON1",RIGHTBUTTON="BUTTON2",MIDDLEBUTTON="BUTTON3",BUTTON4="BUTTON4",BUTTON5="BUTTON5"}
    base = mouseMap[base] or base
    local parts = {}
    if IsControlKeyDown and IsControlKeyDown() then parts[#parts+1] = "CTRL" end
    if IsAltKeyDown and IsAltKeyDown() then parts[#parts+1] = "ALT" end
    if IsShiftKeyDown and IsShiftKeyDown() then parts[#parts+1] = "SHIFT" end
    parts[#parts+1] = base
    return HCOB_ActionPanel.NormalizeSlotKey(table.concat(parts, "-"))
end

function HCOB_ActionPanel.RefreshBindingOptions()
    local panel = HCOB_ActionPanel.bindingOptions
    if not panel then return end
    local visible = tonumber(HCOB_ActionPanel.visibleCount) or #(HCOB_ActionPanel.actions[PLAYER_CLASS] or {})
    if panel.classText then
        panel.classText:SetText(string.format("Classe: %s | slot attivi: %d | layout fisso", tostring(PLAYER_CLASS), visible))
    end
    for slot,row in ipairs(panel.rows or {}) do
        local active = slot <= visible
        local key = HCOB_ActionPanel.GetSlotKey(slot)
        local name = HCOB_ActionPanel.GetSlotActionName(slot)
        row.slotText:SetText(string.format("%02d", slot))
        row.spellText:SetText(name)
        row.keyButton:SetText(key and key:gsub("%-", "+") or "<nessuno>")
        row.keyButton:SetEnabled(active)
        row.defaultButton:SetEnabled(active)
        row.clearButton:SetEnabled(active)
        if active then
            row.spellText:SetTextColor(0.92,0.92,0.94)
            row.slotText:SetTextColor(1,0.82,0.20)
        else
            row.spellText:SetTextColor(0.40,0.40,0.43)
            row.slotText:SetTextColor(0.38,0.38,0.40)
        end
    end
    if panel.autoText then
        panel.autoText:SetText(HCOB_DB.actionSlotAutoBind ~= false and "Auto-bind: ON" or "Auto-bind: OFF")
        panel.autoText:SetTextColor(HCOB_DB.actionSlotAutoBind ~= false and 0.35 or 1.0, HCOB_DB.actionSlotAutoBind ~= false and 1.0 or 0.72, 0.45)
    end
end

function HCOB_ActionPanel.BeginBindingCapture(slot)
    if InCombatLockdown() then
        print("|cffff5555HCOB:|r modifica i binding fuori combattimento.")
        return
    end
    local panel = HCOB_ActionPanel.bindingOptions
    if not panel or not panel.capture then return end
    panel.capture.slot = tonumber(slot)
    panel.captureText:SetText(string.format(
        "SLOT %02d - %s\n\nPremi la nuova combinazione.\nESC annulla | DEL/BACKSPACE rimuove il bind",
        tonumber(slot) or 0, HCOB_ActionPanel.GetSlotActionName(slot)))
    panel.capture:Show()
    panel.capture:EnableKeyboard(true)
    if panel.capture.SetPropagateKeyboardInput then panel.capture:SetPropagateKeyboardInput(false) end
end

function HCOB_ActionPanel.EndBindingCapture(message, isError)
    local panel = HCOB_ActionPanel.bindingOptions
    if not panel or not panel.capture then return end
    panel.capture:EnableKeyboard(false)
    panel.capture:Hide()
    panel.capture.slot = nil
    if panel.status then
        panel.status:SetText(message or "")
        if isError then panel.status:SetTextColor(1,0.35,0.30) else panel.status:SetTextColor(0.35,1,0.55) end
    end
    HCOB_ActionPanel.RefreshBindingOptions()
end

function HCOB_ActionPanel.AcceptCapturedBinding(base)
    local panel = HCOB_ActionPanel.bindingOptions
    local slot = panel and panel.capture and panel.capture.slot
    if not slot then return end
    base = tostring(base or ""):upper()
    if base == "ESCAPE" then
        HCOB_ActionPanel.EndBindingCapture("Modifica annullata.", false)
        return
    end
    if base == "DELETE" or base == "BACKSPACE" then
        local ok, err = HCOB_ActionPanel.SetSlotKey(slot, false)
        HCOB_ActionPanel.EndBindingCapture(ok and string.format("SLOT %02d senza binding.", slot) or err, not ok)
        return
    end
    local key = HCOB_ActionPanel.CapturedKey(base)
    if not key then return end
    local previous = GetBindingAction and GetBindingAction(key) or ""
    local ok, err = HCOB_ActionPanel.SetSlotKey(slot, key)
    if ok then
        local note = string.format("SLOT %02d -> %s", slot, key:gsub("%-", "+"))
        local own = HCOB_ActionPanel.GetSlotBindingCommand(slot)
        if previous and previous ~= "" and previous ~= own then
            note = note .. " (sostituito bind WoW: " .. tostring(previous) .. ")"
        end
        HCOB_ActionPanel.EndBindingCapture(note, false)
    else
        HCOB_ActionPanel.EndBindingCapture(err or "Binding non valido.", true)
    end
end

function HCOB_ActionPanel.CreateBindingOptions()
    if HCOB_ActionPanel.bindingOptions then return HCOB_ActionPanel.bindingOptions end

    local panel = CreateFrame("Frame", "HCOneButtonActionBindingOptions", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(690, 690)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    panel:Hide()
    if panel.TitleText then panel.TitleText:SetText("HC One Button - Fixed Action Panel bindings") end

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -36)
    title:SetText("Fixed Action Panel bindings")

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
    hint:SetWidth(640)
    hint:SetJustifyH("LEFT")
    hint:SetText("Gli slot restano fissi per classe. Clicca il binding e premi la combinazione desiderata. I default sono SHIFT+1...SHIFT+0 e CTRL+SHIFT+1...8.")

    panel.classText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    panel.classText:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)

    local hSlot = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hSlot:SetPoint("TOPLEFT", 26, -103)
    hSlot:SetText("SLOT")
    local hSpell = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hSpell:SetPoint("TOPLEFT", 76, -103)
    hSpell:SetText("AZIONE FISSA")
    local hBind = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hBind:SetPoint("TOPLEFT", 330, -103)
    hBind:SetText("BINDING")

    panel.rows = {}
    for slot=1,(HCOB_ActionPanel.maxButtons or 18) do
        local row = {}
        local y = -120 - (slot-1) * 27

        row.slotText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.slotText:SetPoint("TOPLEFT", 30, y-5)
        row.slotText:SetWidth(32)
        row.slotText:SetJustifyH("RIGHT")

        row.spellText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.spellText:SetPoint("TOPLEFT", 76, y-5)
        row.spellText:SetWidth(240)
        row.spellText:SetJustifyH("LEFT")

        row.keyButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        row.keyButton:SetSize(175, 23)
        row.keyButton:SetPoint("TOPLEFT", 326, y)
        row.keyButton:SetScript("OnClick", function() HCOB_ActionPanel.BeginBindingCapture(slot) end)

        row.defaultButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        row.defaultButton:SetSize(74, 23)
        row.defaultButton:SetPoint("LEFT", row.keyButton, "RIGHT", 7, 0)
        row.defaultButton:SetText("Default")
        row.defaultButton:SetScript("OnClick", function()
            local ok, err = HCOB_ActionPanel.ResetSlotKey(slot)
            if panel.status then
                panel.status:SetText(ok and string.format("SLOT %02d ripristinato al default.", slot) or tostring(err))
                panel.status:SetTextColor(ok and 0.35 or 1, ok and 1 or 0.35, ok and 0.55 or 0.30)
            end
            HCOB_ActionPanel.RefreshBindingOptions()
        end)

        row.clearButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        row.clearButton:SetSize(64, 23)
        row.clearButton:SetPoint("LEFT", row.defaultButton, "RIGHT", 5, 0)
        row.clearButton:SetText("Nessuno")
        row.clearButton:SetScript("OnClick", function()
            local ok, err = HCOB_ActionPanel.SetSlotKey(slot, false)
            if panel.status then
                panel.status:SetText(ok and string.format("SLOT %02d senza binding.", slot) or tostring(err))
                panel.status:SetTextColor(ok and 0.35 or 1, ok and 1 or 0.35, ok and 0.55 or 0.30)
            end
            HCOB_ActionPanel.RefreshBindingOptions()
        end)

        panel.rows[slot] = row
    end

    panel.autoText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.autoText:SetPoint("BOTTOMLEFT", 26, 48)

    panel.status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.status:SetPoint("BOTTOMLEFT", 160, 48)
    panel.status:SetWidth(350)
    panel.status:SetJustifyH("LEFT")
    panel.status:SetText("")

    local resetAll = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetAll:SetSize(145, 25)
    resetAll:SetPoint("BOTTOMRIGHT", -112, 17)
    resetAll:SetText("Ripristina tutti")
    resetAll:SetScript("OnClick", function()
        local ok, err = HCOB_ActionPanel.ResetAllSlotKeys()
        panel.status:SetText(ok and "Tutti i binding ripristinati ai default." or tostring(err))
        panel.status:SetTextColor(ok and 0.35 or 1, ok and 1 or 0.35, ok and 0.55 or 0.30)
        HCOB_ActionPanel.RefreshBindingOptions()
    end)

    local close = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    close:SetSize(90, 25)
    close:SetPoint("BOTTOMRIGHT", -16, 17)
    close:SetText("Chiudi")
    close:SetScript("OnClick", function() panel:Hide() end)

    panel.capture = CreateFrame("Frame", nil, panel)
    panel.capture:SetAllPoints(panel)
    panel.capture:SetFrameLevel(panel:GetFrameLevel() + 20)
    panel.capture:EnableMouse(true)
    panel.capture:EnableKeyboard(false)
    panel.capture:EnableMouseWheel(true)
    panel.capture:Hide()

    local captureBG = panel.capture:CreateTexture(nil, "BACKGROUND")
    captureBG:SetAllPoints()
    captureBG:SetColorTexture(0,0,0,0.88)
    panel.captureText = panel.capture:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.captureText:SetPoint("CENTER", 0, 10)
    panel.captureText:SetWidth(560)
    panel.captureText:SetJustifyH("CENTER")
    panel.captureText:SetTextColor(1,0.85,0.25)

    panel.capture:SetScript("OnKeyDown", function(_, key) HCOB_ActionPanel.AcceptCapturedBinding(key) end)
    panel.capture:SetScript("OnMouseDown", function(_, button)
        HCOB_ActionPanel.AcceptCapturedBinding(button)
    end)
    panel.capture:SetScript("OnMouseWheel", function(_, delta)
        HCOB_ActionPanel.AcceptCapturedBinding(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
    end)

    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:SetScript("OnEvent", function(self)
        if self.capture and self.capture:IsShown() then
            self.capture:EnableKeyboard(false)
            self.capture:Hide()
        end
        self:Hide()
        print("|cffffcc00HCOB:|r configurazione binding chiusa: sei entrato in combattimento.")
    end)
    panel:SetScript("OnShow", function() HCOB_ActionPanel.RefreshBindingOptions() end)
    HCOB_ActionPanel.bindingOptions = panel
    return panel
end

function HCOB_ActionPanel.OpenBindingOptions()
    if InCombatLockdown() then
        print("|cffffcc00HCOB:|r apri i binding del pannello fuori combattimento.")
        return
    end
    local panel = HCOB_ActionPanel.CreateBindingOptions()
    HCOB_ActionPanel.RefreshBindingOptions()
    panel:Show()
    panel:Raise()
end

function HCOB_ActionPanel.BuildMacro(id)
    if not id then return "/stopmacro" end

    if PLAYER_CLASS == "HUNTER" then
        if id == S.FEED_PET then return HCOB_Hunter.FeedMacro() end
        if id == S.MEND_PET then return BuildSpellMacro(id, "@pet,exists,nodead") end
        if id == S.FEIGN_DEATH then
            local lines = NewLines()
            AddLine(lines, "/petpassive", 1)
            AddLine(lines, "/petfollow", 1)
            AddLine(lines, BuildSpellMacro(S.FEIGN_DEATH), 1)
            return FitMacro(lines)
        end
    end

    if PLAYER_CLASS == "MAGE" and id == S.FROST_NOVA and IsKnown(id) then
        return "/cast " .. Mage.RankedName(S.FROST_NOVA)
    end

    if id == S.SHOOT then
        local name = SpellName(id)
        return name and ("/cast !" .. name) or "/stopmacro"
    end

    local selfTarget = {
        [S.BATTLE_SHOUT]=true,[S.BLOODRAGE]=true,[S.BERSERKER_RAGE]=true,[S.RETALIATION]=true,[S.SHIELD_WALL]=true,
        [S.BLESSING_MIGHT]=true,[S.DIVINE_PROTECTION]=true,[S.DIVINE_SHIELD]=true,[S.LAY_ON_HANDS]=true,[S.HOLY_LIGHT]=true,[S.FLASH_LIGHT]=true,[S.SEAL_RIGHTEOUSNESS]=true,[S.SEAL_COMMAND]=true,[S.SEAL_CRUSADER]=true,
        [S.STEALTH]=true,[S.SPRINT]=true,[S.EVASION]=true,[S.VANISH]=true,
        [S.POWER_WORD_SHIELD]=true,[S.RENEW]=true,[S.FORTITUDE]=true,[S.FADE]=true,[S.LESSER_HEAL]=true,[S.HEAL]=true,[S.FLASH_HEAL]=true,[S.INNER_FIRE]=true,
        [S.ICE_BARRIER]=true,[S.MANA_SHIELD]=true,[S.ICE_BLOCK]=true,[S.COLD_SNAP]=true,[S.EVOCATION]=true,
        [S.LIFE_TAP]=true,[S.DEMON_ARMOR]=true,[S.DEMON_SKIN]=true,
        [S.BARKSKIN]=true,[S.NATURES_GRASP]=true,[S.DASH]=true,[S.TRAVEL_FORM]=true,[S.MARK_WILD]=true,
        [S.LIGHTNING_SHIELD]=true,[S.HEALING_WAVE]=true,[S.GHOST_WOLF]=true,
        [S.ASPECT_HAWK]=true,[S.RAPID_FIRE]=true,
    }
    if selfTarget[id] then return BuildSpellMacro(id, "@player") end

    if id == S.SPELL_LOCK then return BuildSpellMacro(id, "harm", false, true) end
    return BuildSpellMacro(id, "harm")
end

function HCOB_ActionPanel.Configure()
    if InCombatLockdown() then return false end
    wipe(HCOB_ActionPanel.idToButton)
    wipe(HCOB_ActionPanel.idToSlot)
    wipe(HCOB_ActionPanel.idToActionIndex)

    local list = HCOB_ActionPanel.actions[PLAYER_CLASS] or {}
    -- v1.18.6: layout DETERMINISTICO. Lo slot coincide sempre con l'indice
    -- logico nella lista della classe, anche se la spell non e' ancora appresa.
    -- In questo modo livello/trainer non possono mai far slittare i binding.
    local visible = math.min(#list, HCOB_ActionPanel.maxButtons or 18)

    for slot=1,visible do
        local id = list[slot]
        local b = HCOB_ActionPanel.buttons[slot]
        if b and id then
            local known = IsKnown(id) or id == S.SPELL_LOCK
            local macro = known and HCOB_ActionPanel.BuildMacro(id) or "/stopmacro"

            b:SetAttribute("type1", "macro")
            b:SetAttribute("macrotext1", macro or "/stopmacro")
            b.actionId = id
            b.slotIndex = slot
            b.actionIndex = slot
            b.configured = true
            b.known = known and true or false
            b.actionName = SpellName(id, "Spell " .. tostring(id))
            b.icon:SetTexture(SpellIcon(id))
            b.recommended = false
            b.glow:Hide()
            if b.recommendedBG then b.recommendedBG:Hide() end
            if b.cooldown then b.cooldown:Hide() end
            if b.cdText then b.cdText:SetText("") end
            if b.rangeText then b.rangeText:SetText("") end

            if b.icon.SetDesaturated then b.icon:SetDesaturated(not b.known) end
            b.icon:SetAlpha(b.known and 1.0 or 0.18)
            b.border:SetVertexColor(b.known and 0.38 or 0.16, b.known and 0.38 or 0.16, b.known and 0.38 or 0.18, 0.95)
            b:Show()

            -- Mappatura sempre presente, anche per spell non ancora apprese.
            HCOB_ActionPanel.idToButton[id] = b
            HCOB_ActionPanel.idToSlot[id] = slot
            HCOB_ActionPanel.idToActionIndex[id] = slot
        end
    end

    -- Solo gli slot oltre la tabella fissa della classe vengono nascosti.
    for i=visible+1,HCOB_ActionPanel.maxButtons do
        local b = HCOB_ActionPanel.buttons[i]
        if b then
            b:SetAttribute("type1", "macro")
            b:SetAttribute("macrotext1", "/stopmacro")
            b.actionId = nil
            b.slotIndex = nil
            b.actionIndex = nil
            b.configured = false
            b.known = false
            b.actionName = nil
            b.recommended = false
            b.glow:Hide()
            if b.recommendedBG then b.recommendedBG:Hide() end
            if b.cooldown then b.cooldown:Hide() end
            if b.cdText then b.cdText:SetText("") end
            if b.rangeText then b.rangeText:SetText("") end
            b:Hide()
        end
    end

    HCOB_ActionPanel.visibleCount = visible
    if HCOB_ActionPanel.frame then
        local rows = math.max(1, math.ceil(visible / (HCOB_ActionPanel.columns or 6)))
        local size = HCOB_ActionPanel.buttonSize or 44
        local gap = HCOB_ActionPanel.gap or 5
        local top = HCOB_ActionPanel.topOffset or 8
        local bottom = 8
        HCOB_ActionPanel.frame:SetHeight(top + rows * size + math.max(0, rows - 1) * gap + bottom)
    end
    HCOB_ActionPanel.ApplySlotBindings()
    return true
end

function HCOB_ActionPanel.Has(id)
    local b = id and HCOB_ActionPanel.idToButton[id] or nil
    return b ~= nil and b.known == true
end

function HCOB_ActionPanel.GetCooldown(id)
    if not id then return 0,0,false,0 end
    local startTime, duration, enabled, modRate
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
        if ok and cd then
            startTime, duration, enabled, modRate = cd.startTime, cd.duration, cd.isEnabled, cd.modRate
        end
    elseif GetSpellCooldown then
        startTime, duration, enabled, modRate = GetSpellCooldown(id)
    end
    startTime = tonumber(startTime) or 0
    duration = tonumber(duration) or 0
    modRate = tonumber(modRate) or 1
    if enabled == false or enabled == 0 then return startTime,duration,false,0 end
    local remaining = 0
    if startTime > 0 and duration > 0 then
        remaining = math.max(0, startTime + (duration / math.max(0.01, modRate)) - GetTime())
    end
    return startTime,duration,true,remaining
end

function HCOB_ActionPanel.FormatCooldown(remaining)
    remaining = tonumber(remaining) or 0
    if remaining <= 1.6 then return "" end -- non sporcare tutte le icone col GCD
    if remaining >= 60 then return tostring(math.ceil(remaining / 60)) .. "m" end
    if remaining >= 10 then return tostring(math.ceil(remaining)) end
    return string.format("%.1f", remaining)
end

function HCOB_ActionPanel.InRange(id)
    if not id or not UnitExists("target") or not UnitCanAttack("player","target") then return nil end
    if C_Spell and C_Spell.IsSpellInRange then
        local ok, v = pcall(C_Spell.IsSpellInRange, id, "target")
        if ok and v ~= nil then return v and true or false end
    end
    if IsSpellInRange then
        local name = SpellName(id)
        if name then
            local ok, v = pcall(IsSpellInRange, name, "target")
            if ok and v ~= nil then return v == 1 or v == true end
        end
    end
    return nil
end

function HCOB_ActionPanel.Highlight(id)
    for _, b in ipairs(HCOB_ActionPanel.buttons) do
        if b then
            b.recommended = (id and b.actionId == id and b.known == true) and true or false
            if b.recommended then
                b.glow:SetVertexColor(1,0.82,0.10)
                b.glow:Show()
                if b.recommendedBG then b.recommendedBG:Show() end
            else
                b.glow:Hide()
                if b.recommendedBG then b.recommendedBG:Hide() end
            end
        end
    end
end

function HCOB_ActionPanel.UpdateStates()
    local now = GetTime()
    for _, b in ipairs(HCOB_ActionPanel.buttons) do
        if b and b.configured and b.actionId then
            local known = IsKnown(b.actionId) or b.actionId == S.SPELL_LOCK
            b.known = known and true or false
            local startTime, duration, enabled, remaining = HCOB_ActionPanel.GetCooldown(b.actionId)
            local usable = known and IsUsable(b.actionId) or false
            local inRange = known and HCOB_ActionPanel.InRange(b.actionId) or nil

            if b.cooldown then
                if enabled and startTime > 0 and duration > 0 and remaining > 0.05 then
                    b.cooldown:SetCooldown(startTime, duration)
                    b.cooldown:Show()
                else
                    b.cooldown:Hide()
                end
            end
            if b.cdText then b.cdText:SetText(HCOB_ActionPanel.FormatCooldown(remaining)) end
            if b.rangeText then b.rangeText:SetText(inRange == false and "R" or "") end

            if b.icon.SetDesaturated then b.icon:SetDesaturated(not usable) end
            if not known then
                b.icon:SetAlpha(0.18)
            else
                b.icon:SetAlpha(usable and 1.0 or 0.42)
            end

            if b.recommended and known then
                b.border:SetVertexColor(1,0.72,0.08,1)
                b.glow:SetAlpha(0.62 + 0.30 * math.abs(math.sin(now * 4.5)))
            elseif not known then
                b.border:SetVertexColor(0.16,0.16,0.18,0.72)
            elseif inRange == false then
                b.border:SetVertexColor(0.95,0.12,0.08,1)
            elseif not usable then
                b.border:SetVertexColor(0.28,0.28,0.30,0.82)
            elseif remaining > 1.6 then
                b.border:SetVertexColor(0.25,0.42,0.62,0.92)
            else
                b.border:SetVertexColor(0.42,0.48,0.52,0.95)
            end
        end
    end
end

function HCOB_ActionPanel.SyncVisibility()
    if InCombatLockdown() then return end
    if not HCOB_ActionPanel.frame then return end
    local show = HCOB_DB.visible and HCOB_DB.showAdvisor ~= false and HCOB_DB.secureActions ~= false
    if show then HCOB_ActionPanel.frame:Show() else HCOB_ActionPanel.frame:Hide() end
    for _, b in ipairs(HCOB_ActionPanel.buttons) do
        if b then
            if show and b.configured then b:Show() else b:Hide() end
        end
    end
end

local btn = CreateFrame("Button", "HCOneButtonFrame", UIParent, "SecureActionButtonTemplate")
btn:SetSize(82, 82)
btn:SetFrameStrata("HIGH")
btn:SetFrameLevel(5)
btn:SetClampedToScreen(true)
btn:EnableMouse(true)
btn:SetMovable(true)
btn:RegisterForDrag("LeftButton")
-- Secure click timing must match the client action-button mode.
-- Register both phases, then let SecureActionButtonTemplate select the phase
-- through useOnKeyDown. This fixes CLICK bindings (including BUTTON4) on
-- clients with ActionButtonUseKeyDown enabled.
btn:RegisterForClicks("AnyDown", "AnyUp")
local hcobUseKeyDown = true
if GetCVar then
    local v = GetCVar("ActionButtonUseKeyDown")
    if v ~= nil then hcobUseKeyDown = tostring(v) ~= "0" end
end
btn:SetAttribute("useOnKeyDown", hcobUseKeyDown)
btn:SetPoint("CENTER", UIParent, "CENTER", HCOB_DB.x or 0, HCOB_DB.y or -180)
btn:SetScale(HCOB_DB.scale or 1.0)

local bg = btn:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.025, 0.028, 0.034, 0.99)

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetPoint("TOPLEFT", 5, -5)
icon:SetPoint("BOTTOMRIGHT", -5, 5)
icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

local border = btn:CreateTexture(nil, "OVERLAY")
border:SetAllPoints()
border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

local glow = btn:CreateTexture(nil, "OVERLAY")
glow:SetPoint("TOPLEFT", -12, 12)
glow:SetPoint("BOTTOMRIGHT", 12, -12)
glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
glow:SetBlendMode("ADD")
glow:SetAlpha(0.75)
glow:Hide()

local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("TOP", btn, "BOTTOM", 0, -5)
label:SetText("HC ONE")

local hint = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetPoint("TOP", label, "BOTTOM", 0, -2)
hint:SetText("")

local reasonText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
reasonText:SetPoint("TOP", hint, "BOTTOM", 0, -1)
reasonText:SetWidth(220)
reasonText:SetText("")

-- v1.9 compact HUD: these legacy captions lived below the secure button and
-- collided with the Advisor/bars when the button was scaled down. The base
-- action is now communicated by the button itself + the Advisor status.
label:Hide()
hint:Hide()
reasonText:Hide()

local resourceText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
resourceText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -7, 7)
resourceText:SetText("")

local hpText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hpText:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 7, 7)
hpText:SetText("")

local enemyText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
enemyText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -7, -7)
enemyText:SetText("")

local classText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
classText:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -7)
classText:SetText(PLAYER_CLASS and PLAYER_CLASS:sub(1,3) or "HC")

-- Advisor non cliccabile: mostra la spell situazionale da castare manualmente.
-- v1.9: layout compatto e scalato insieme al pulsante. La vecchia UI aveva
-- un banner alto e testi sotto al BASE che diventavano sproporzionati a scale
-- come 0.7. Ora: icona + badge corto + titolo + tasto + motivo, tutto su 82px.

-- Rectangular panel borders. Do not stretch UI-Quickslot2 across wide frames:
-- that texture is made for square action buttons and creates a false inner rectangle.
function HCOB_MakeRectBorder(frame, r, g, b, a)
    if not frame then return end
    frame.HCOBRectBorder = frame.HCOBRectBorder or {}
    local e = frame.HCOBRectBorder
    if #e == 0 then
        e[1] = frame:CreateTexture(nil, "BORDER")
        e[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        e[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        e[1]:SetHeight(1)
        e[2] = frame:CreateTexture(nil, "BORDER")
        e[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        e[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        e[2]:SetHeight(1)
        e[3] = frame:CreateTexture(nil, "BORDER")
        e[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        e[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        e[3]:SetWidth(1)
        e[4] = frame:CreateTexture(nil, "BORDER")
        e[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        e[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        e[4]:SetWidth(1)
        for i=1,4 do e[i]:SetColorTexture(1,1,1,1) end
    end
    HCOB_SetRectBorderColor(frame, r, g, b, a)
end

function HCOB_SetRectBorderColor(frame, r, g, b, a)
    if not frame or not frame.HCOBRectBorder then return end
    for i=1,4 do
        local t = frame.HCOBRectBorder[i]
        if t then t:SetVertexColor(r or 1, g or 1, b or 1, a or 1) end
    end
end

-- v1.18.7 unified Core HUD. BASE + Advisor + telemetry footer are rendered
-- inside one visual shell so they read as a single addon component. The secure
-- BASE button itself remains independent; this frame is purely visual.
HCOB_CoreShell = CreateFrame("Frame", "HCOneButtonCoreShell", UIParent)
HCOB_CoreShell:SetSize(376, 118)
HCOB_CoreShell:SetPoint("TOPLEFT", btn, "TOPLEFT", -4, 4)
HCOB_CoreShell:SetFrameStrata("HIGH")
HCOB_CoreShell:SetFrameLevel(1)
HCOB_CoreShell:EnableMouse(false)
HCOB_CoreShell.bg = HCOB_CoreShell:CreateTexture(nil, "BACKGROUND")
HCOB_CoreShell.bg:SetAllPoints()
HCOB_CoreShell.bg:SetColorTexture(0.012, 0.014, 0.018, 0.96)
HCOB_MakeRectBorder(HCOB_CoreShell, 0.28, 0.38, 0.48, 0.88)

local advisor = CreateFrame("Frame", nil, UIParent)
advisor:SetSize(282, 82)
advisor:SetPoint("TOPLEFT", btn, "TOPRIGHT", 4, 0)
advisor:SetFrameStrata("HIGH")
advisor:SetFrameLevel(5)
advisor:EnableMouse(false)

local advisorBG = advisor:CreateTexture(nil, "BACKGROUND")
advisorBG:SetAllPoints()
advisorBG:SetColorTexture(0, 0, 0, 0)

-- Border is owned by HCOB_CoreShell in the unified HUD.

local advisorGlow = advisor:CreateTexture(nil, "OVERLAY")
advisorGlow:SetPoint("TOPLEFT", -6, 6)
advisorGlow:SetPoint("BOTTOMRIGHT", 6, -6)
advisorGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
advisorGlow:SetBlendMode("ADD")
advisorGlow:SetAlpha(0.72)
advisorGlow:Hide()

local advisorIcon = advisor:CreateTexture(nil, "ARTWORK")
advisorIcon:SetSize(58, 58)
advisorIcon:SetPoint("LEFT", advisor, "LEFT", 9, 0)
advisorIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
advisor.iconBorder = advisor:CreateTexture(nil, "OVERLAY")
advisor.iconBorder:SetPoint("TOPLEFT", advisorIcon, "TOPLEFT", -3, 3)
advisor.iconBorder:SetPoint("BOTTOMRIGHT", advisorIcon, "BOTTOMRIGHT", 3, -3)
advisor.iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
advisor.iconBorder:SetVertexColor(0.42, 0.48, 0.52, 0.95)

-- Badge piccolo: MANUALE / HCOB / BASE / DANGER / OK.
local advisorBanner = advisor:CreateTexture(nil, "ARTWORK")
advisorBanner:SetPoint("TOPLEFT", advisorIcon, "TOPRIGHT", 9, 0)
advisorBanner:SetSize(92, 17)
advisorBanner:SetColorTexture(0.18, 0.18, 0.18, 0.98)

local advisorMode = advisor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
advisorMode:SetPoint("CENTER", advisorBanner, "CENTER", 0, 0)
advisorMode:SetWidth(88)
advisorMode:SetJustifyH("CENTER")
advisorMode:SetText("OK")

local advisorTitle = advisor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
advisorTitle:SetPoint("TOPLEFT", advisorBanner, "BOTTOMLEFT", 0, -3)
advisorTitle:SetWidth(202)
advisorTitle:SetHeight(18)
advisorTitle:SetJustifyH("LEFT")
advisorTitle:SetText("ADVISOR")

local advisorKey = advisor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
advisorKey:SetPoint("TOPLEFT", advisorTitle, "BOTTOMLEFT", 0, -1)
advisorKey:SetWidth(202)
advisorKey:SetHeight(15)
advisorKey:SetJustifyH("LEFT")
advisorKey:SetText("SPAM BASE")

local advisorReason = advisor:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
advisorReason:SetPoint("TOPLEFT", advisorKey, "BOTTOMLEFT", 0, -1)
advisorReason:SetWidth(202)
advisorReason:SetHeight(13)
advisorReason:SetJustifyH("LEFT")
advisorReason:SetText("Nessuna priorita")

-- Mini DPS meter. Rimane volutamente una singola riga compatta.
local dpsMeter = CreateFrame("Frame", nil, UIParent)
dpsMeter:SetSize(282, 24)
dpsMeter:SetPoint("TOPLEFT", advisor, "BOTTOMLEFT", 0, -4)
dpsMeter:SetFrameStrata("HIGH")
dpsMeter:SetFrameLevel(5)
dpsMeter:EnableMouse(false)

local dpsBG = dpsMeter:CreateTexture(nil, "BACKGROUND")
dpsBG:SetAllPoints()
dpsBG:SetColorTexture(0.020, 0.023, 0.029, 0.88)

dpsMeter.topLine = dpsMeter:CreateTexture(nil, "BORDER")
dpsMeter.topLine:SetPoint("TOPLEFT", dpsMeter, "TOPLEFT", 0, 0)
dpsMeter.topLine:SetPoint("TOPRIGHT", dpsMeter, "TOPRIGHT", 0, 0)
dpsMeter.topLine:SetHeight(1)
dpsMeter.topLine:SetColorTexture(0.28, 0.38, 0.48, 0.65)

local dpsValue = dpsMeter:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dpsValue:SetPoint("LEFT", dpsMeter, "LEFT", 8, 0)
dpsValue:SetWidth(76)
dpsValue:SetJustifyH("LEFT")
dpsValue:SetText("DPS --")

local dpsMeta = dpsMeter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dpsMeta:SetPoint("LEFT", dpsValue, "RIGHT", 4, 0)
dpsMeta:SetPoint("RIGHT", dpsMeter, "RIGHT", -8, 0)
dpsMeta:SetJustifyH("RIGHT")
dpsMeta:SetText("AVG5 -- | DMG 0 | 0.0s")

-- Secure action palette: creata dentro una funzione separata per non
-- consumare registri/locali del chunk principale (Classic ha un limite stretto).
function HCOB_ActionPanel.CreateFrames()
    HCOB_ActionPanel.columns = 6
    HCOB_ActionPanel.buttonSize = 44
    HCOB_ActionPanel.gap = 5
    -- v1.18.2: niente header testuale; il pannello contiene solo le icone.
    HCOB_ActionPanel.topOffset = 8

    -- v1.18.8: il pannello Azioni ha esattamente la stessa larghezza del
    -- Core HUD. Le sei icone restano centrate nel pannello.
    local rowWidth = HCOB_ActionPanel.columns * HCOB_ActionPanel.buttonSize
        + (HCOB_ActionPanel.columns - 1) * HCOB_ActionPanel.gap
    local width = (HCOB_CoreShell and HCOB_CoreShell.GetWidth and HCOB_CoreShell:GetWidth()) or 376
    HCOB_ActionPanel.padding = math.max(8, (width - rowWidth) / 2)
    HCOB_ActionPanel.frame = CreateFrame("Frame", "HCOneButtonAdvisorActions", UIParent)
    HCOB_ActionPanel.frame:SetSize(width, 60)
    HCOB_ActionPanel.frame:SetPoint("TOP", HCOB_CoreShell, "BOTTOM", 0, -4)
    HCOB_ActionPanel.frame:SetFrameStrata("HIGH")
    HCOB_ActionPanel.frame:EnableMouse(false)

    HCOB_ActionPanel.bg = HCOB_ActionPanel.frame:CreateTexture(nil, "BACKGROUND")
    HCOB_ActionPanel.bg:SetAllPoints()
    HCOB_ActionPanel.bg:SetColorTexture(0.012,0.014,0.018,0.96)
    HCOB_MakeRectBorder(HCOB_ActionPanel.frame, 0.28,0.38,0.48,0.88)
    for i=1,HCOB_ActionPanel.maxButtons do
        local b = CreateFrame("Button", "HCOneButtonAdvisorAction"..i, UIParent, "SecureActionButtonTemplate")
        b:SetSize(HCOB_ActionPanel.buttonSize,HCOB_ActionPanel.buttonSize)
        local col = (i-1) % HCOB_ActionPanel.columns
        local row = math.floor((i-1) / HCOB_ActionPanel.columns)
        b:SetPoint("TOPLEFT", HCOB_ActionPanel.frame, "TOPLEFT",
            HCOB_ActionPanel.padding + col * (HCOB_ActionPanel.buttonSize + HCOB_ActionPanel.gap),
            -HCOB_ActionPanel.topOffset - row * (HCOB_ActionPanel.buttonSize + HCOB_ActionPanel.gap))
        b:SetFrameStrata("HIGH")
        b:RegisterForClicks("AnyDown", "AnyUp")
        b:SetAttribute("useOnKeyDown", hcobUseKeyDown)

        b.bg = b:CreateTexture(nil,"BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(0.025,0.028,0.034,0.99)
        b.icon = b:CreateTexture(nil,"ARTWORK")
        b.icon:SetPoint("TOPLEFT",3,-3)
        b.icon:SetPoint("BOTTOMRIGHT",-3,3)
        b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

        b.recommendedBG = b:CreateTexture(nil,"ARTWORK")
        b.recommendedBG:SetAllPoints(b.icon)
        b.recommendedBG:SetColorTexture(1,0.72,0.02,0.13)
        b.recommendedBG:Hide()

        b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        b.cooldown:SetAllPoints(b.icon)
        if b.cooldown.SetDrawEdge then b.cooldown:SetDrawEdge(true) end
        if b.cooldown.SetDrawSwipe then b.cooldown:SetDrawSwipe(true) end
        if b.cooldown.SetHideCountdownNumbers then b.cooldown:SetHideCountdownNumbers(true) end
        b.cooldown:Hide()

        b.cdText = b:CreateFontString(nil,"OVERLAY","GameFontNormal")
        b.cdText:SetPoint("CENTER",0,0)
        b.cdText:SetJustifyH("CENTER")
        b.cdText:SetTextColor(1,0.92,0.72)
        if b.cdText.SetShadowOffset then b.cdText:SetShadowOffset(1,-1) end
        b.cdText:SetText("")

        b.rangeText = b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        b.rangeText:SetPoint("BOTTOMRIGHT",-4,4)
        b.rangeText:SetTextColor(1,0.18,0.12)
        b.rangeText:SetText("")

        b.border = b:CreateTexture(nil,"OVERLAY")
        b.border:SetAllPoints()
        b.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        b.border:SetVertexColor(0.42,0.48,0.52,0.95)
        b.glow = b:CreateTexture(nil,"OVERLAY")
        b.glow:SetPoint("TOPLEFT",-7,7)
        b.glow:SetPoint("BOTTOMRIGHT",7,-7)
        b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        b.glow:SetBlendMode("ADD")
        b.glow:SetAlpha(0.90)
        b.glow:Hide()
        b:SetScript("OnEnter", function(self)
            if GameTooltip and self.actionName then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetText(self.actionName,1,0.82,0.15)
                if self.bindingKey then
                    GameTooltip:AddLine("Bind: " .. tostring(self.bindingKey):gsub("%-", "+"),0.45,0.85,1)
                end
                if self.actionId and not IsKnown(self.actionId) and self.actionId ~= S.SPELL_LOCK then
                    GameTooltip:AddLine("NON ANCORA APPRESA - slot riservato",0.65,0.65,0.68)
                else
                    GameTooltip:AddLine("Clicca per eseguire l'azione HCOB",0.75,0.85,1)
                end
                local _, _, _, remaining = HCOB_ActionPanel.GetCooldown(self.actionId)
                if remaining and remaining > 0.05 then
                    GameTooltip:AddLine("Cooldown: "..HCOB_ActionPanel.FormatCooldown(remaining),1,0.75,0.30)
                else
                    GameTooltip:AddLine("Cooldown: pronto",0.45,1,0.45)
                end
                local range = HCOB_ActionPanel.InRange(self.actionId)
                if range == false then GameTooltip:AddLine("Fuori portata",1,0.25,0.20) end
                if not IsUsable(self.actionId) then GameTooltip:AddLine("Non utilizzabile ora (risorsa/condizione)",0.70,0.70,0.70) end
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        HCOB_ActionPanel.buttons[i] = b
    end
end
HCOB_ActionPanel.CreateFrames()

-- Pixel diagnostico passivo per strumenti esterni di sola lettura.
-- Protocollo RGB v3: il colore codifica ESCLUSIVAMENTE lo slot fisso.
-- Il reader non conosce ne' classe ne' spell.
-- R = slot * 12, G = 96, B = 224.
-- Nero = nessuna azione consigliata; bianco = raccomandazione non mappata.
local diagPixel = CreateFrame("Frame", "HCOneButtonDiagPixel", UIParent)
diagPixel:SetSize(8, 8)
diagPixel:SetPoint("TOPLEFT", advisor, "TOPRIGHT", 4, 0)
diagPixel:SetFrameStrata("TOOLTIP")
diagPixel:EnableMouse(false)
local diagPixelTex = diagPixel:CreateTexture(nil, "OVERLAY")
diagPixelTex:SetAllPoints()
diagPixelTex:SetColorTexture(0, 0, 0, 1)

local function UpdateDiagnosticPixel(spellId)
    if not diagPixelTex then return end
    if not spellId then
        diagPixelTex:SetColorTexture(0, 0, 0, 1)
        return
    end

    local slot = HCOB_ActionPanel.idToSlot[spellId]
    if slot then
        diagPixelTex:SetColorTexture((slot * 12) / 255, 96 / 255, 224 / 255, 1)
    else
        diagPixelTex:SetColorTexture(1, 1, 1, 1)
    end
end

local swingBG = CreateFrame("Frame", nil, btn)
swingBG:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -4)
swingBG:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", 0, -4)
swingBG:SetHeight(4)
local swingBGTex = swingBG:CreateTexture(nil, "BACKGROUND")
swingBGTex:SetAllPoints()
swingBGTex:SetColorTexture(0.15, 0.15, 0.15, 0.9)
local swingFill = swingBG:CreateTexture(nil, "ARTWORK")
swingFill:SetPoint("TOPLEFT")
swingFill:SetPoint("BOTTOMLEFT")
swingFill:SetWidth(1)
swingFill:SetColorTexture(0.9, 0.75, 0.2, 0.95)

local hpBarBG = CreateFrame("Frame", nil, btn)
hpBarBG:SetPoint("TOPLEFT", swingBG, "BOTTOMLEFT", 0, -2)
hpBarBG:SetPoint("TOPRIGHT", swingBG, "BOTTOMRIGHT", 0, -2)
hpBarBG:SetHeight(5)
local hpBarBGTex = hpBarBG:CreateTexture(nil, "BACKGROUND")
hpBarBGTex:SetAllPoints()
hpBarBGTex:SetColorTexture(0.16, 0.04, 0.04, 0.9)
local hpBarFill = hpBarBG:CreateTexture(nil, "ARTWORK")
hpBarFill:SetPoint("TOPLEFT")
hpBarFill:SetPoint("BOTTOMLEFT")
hpBarFill:SetWidth(1)
hpBarFill:SetColorTexture(0.9, 0.15, 0.15, 0.95)

local powerBarBG = CreateFrame("Frame", nil, btn)
powerBarBG:SetPoint("TOPLEFT", hpBarBG, "BOTTOMLEFT", 0, -2)
powerBarBG:SetPoint("TOPRIGHT", hpBarBG, "BOTTOMRIGHT", 0, -2)
powerBarBG:SetHeight(5)
local powerBarBGTex = powerBarBG:CreateTexture(nil, "BACKGROUND")
powerBarBGTex:SetAllPoints()
powerBarBGTex:SetColorTexture(0.05, 0.05, 0.05, 0.9)
local powerBarFill = powerBarBG:CreateTexture(nil, "ARTWORK")
powerBarFill:SetPoint("TOPLEFT")
powerBarFill:SetPoint("BOTTOMLEFT")
powerBarFill:SetWidth(1)
powerBarFill:SetColorTexture(0.2, 0.55, 1.0, 0.95)

local panelShadow = btn:CreateTexture(nil, "BORDER")
panelShadow:SetPoint("TOPLEFT", -8, 8)
panelShadow:SetPoint("BOTTOMRIGHT", 8, -8)
panelShadow:SetColorTexture(0, 0, 0, 0.35)
panelShadow:Hide()

local optionsPanel
local settingsCategory
local settingsBridgePanel
local function GetClassColor()
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[PLAYER_CLASS]
    if c then return c.r, c.g, c.b end
    return 0.95, 0.82, 0.15
end

local function ApplyVisualTheme()
    local cr, cg, cb = GetClassColor()
    classText:SetTextColor(cr, cg, cb)
    border:SetVertexColor(0.42, 0.48, 0.52, 0.95)
    if advisor.iconBorder then advisor.iconBorder:SetVertexColor(0.42, 0.48, 0.52, 0.95) end
    HCOB_SetRectBorderColor(HCOB_CoreShell, 0.28, 0.38, 0.48, 0.88)
    dpsValue:SetTextColor(0.72, 0.90, 1.0)
    if HCOB_ActionPanel and HCOB_ActionPanel.title then HCOB_ActionPanel.title:SetTextColor(math.min(1,cr+0.18),math.min(1,cg+0.18),math.min(1,cb+0.18)) end
    label:SetTextColor(1, 0.97, 0.86)
    hint:SetTextColor(0.6, 0.84, 1)
    resourceText:SetTextColor(1, 1, 1)
    hpText:SetTextColor(1, 1, 1)
    panelShadow:Show()
end

local function RefreshButtonState()
    local hudScale = HCOB_DB.scale or 1.0
    btn:SetScale(hudScale)
    HCOB_CoreShell:SetScale(hudScale)
    advisor:SetScale(hudScale)
    dpsMeter:SetScale(hudScale)
    if HCOB_ActionPanel and HCOB_ActionPanel.frame then
        -- v1.18.1: scala indipendente. Con HUD 0.7 le vecchie icone da 28px
        -- diventavano circa 20px; le azioni restano leggibili senza ingrandire
        -- tutto il resto del pannello.
        local actionScale = HCOB_DB.actionScale or 1.0
        HCOB_ActionPanel.frame:SetScale(actionScale)
        if not InCombatLockdown() then
            for _, ab in ipairs(HCOB_ActionPanel.buttons) do if ab then ab:SetScale(actionScale) end end
        end
    end
    if HCOB_DB.visible then btn:Show() else btn:Hide() end
    if HCOB_DB.visible and HCOB_DB.showAdvisor ~= false then HCOB_CoreShell:Show() else HCOB_CoreShell:Hide() end
    -- Advisor/DPS non sono secure: possono essere mostrati/nascosti senza
    -- toccare gli attributi protetti del pulsante.
    if HCOB_DB.visible and HCOB_DB.showAdvisor ~= false then advisor:Show() else advisor:Hide() end
    if HCOB_DB.visible and HCOB_DB.showDPSMeter ~= false then dpsMeter:Show() else dpsMeter:Hide() end
    if HCOB_ActionPanel then HCOB_ActionPanel.SyncVisibility() end
    if HCOB_DB.visible and HCOB_DB.diagPixel ~= false then diagPixel:Show() else diagPixel:Hide() end
    if HCOB_DB.locked then
        label:SetTextColor(1, 0.97, 0.86)
    end
end

local pendingRebuild = false
local playerGUID
local activeEnemies = {}
local activeTargetCast
local lastAutoAttack
local lastRecommendationKey
local lastDangerSound = 0
local lastInterruptSound = 0
local currentMods = nil
local runtimeSmartDisabled = false
local runtimeCombatLogDisabled = false
local runtimeTelemetryDisabled = false
local runtimeErrors = {}
local lastErrorNotice = 0
local currentFight = nil

local function RecentDPSAverage(limit)
    local fights = HCOB_CombatLog and HCOB_CombatLog.fights or {}
    local need = tonumber(limit) or 5
    local damage, duration, count = 0, 0, 0
    -- Prefer fights from the current addon version so old experimental builds
    -- do not pollute the small meter. Fall back to any recent fights if needed.
    for pass=1,2 do
        damage, duration, count = 0, 0, 0
        for i=#fights,1,-1 do
            local f = fights[i]
            if pass == 2 or f.addonVersion == VERSION then
                local d = tonumber(f.totalDamage) or 0
                local t = tonumber(f.duration) or 0
                if t > 0 then
                    damage = damage + d
                    duration = duration + t
                    count = count + 1
                    if count >= need then break end
                end
            end
        end
        if count > 0 then break end
    end
    return duration > 0 and damage / duration or 0, count
end

local function UpdateDPSMeter()
    if HCOB_DB.showDPSMeter == false or not HCOB_DB.visible then
        dpsMeter:Hide()
        return
    end
    dpsMeter:Show()
    local avg5, avgCount = RecentDPSAverage(5)
    if currentFight then
        local elapsed = math.max(0.05, GetTime() - (currentFight.startClock or GetTime()))
        local damage = (tonumber(currentFight.damageDone) or 0) + (tonumber(currentFight.petDamage) or 0)
        local dps = damage / elapsed
        dpsValue:SetText(string.format("DPS %.1f", dps))
        dpsMeta:SetText(string.format("AVG%d %.1f | DMG %d | %.1fs", math.max(1, avgCount), avg5, damage, elapsed))
    else
        local fights = HCOB_CombatLog and HCOB_CombatLog.fights or {}
        local last = fights[#fights]
        if last then
            dpsValue:SetText(string.format("LAST %.1f", tonumber(last.dps) or 0))
            dpsMeta:SetText(string.format("AVG%d %.1f | DMG %d | %.1fs", math.max(1, avgCount), avg5, tonumber(last.totalDamage) or 0, tonumber(last.duration) or 0))
        else
            dpsValue:SetText("DPS --")
            dpsMeta:SetText("AVG5 -- | DMG 0 | 0.0s")
        end
    end
end

local function RecordRuntimeError(area, err)
    local message = tostring(err or "errore sconosciuto")
    runtimeErrors[#runtimeErrors + 1] = { area = area, message = message, at = GetTime and GetTime() or 0 }
    if #runtimeErrors > 8 then table.remove(runtimeErrors, 1) end
    local now = GetTime and GetTime() or 0
    if now - lastErrorNotice > 3 then
        lastErrorNotice = now
        print("|cffff5555HCOB:|r errore intercettato in " .. tostring(area) .. ". Fail-safe attivo; /hcob errors per i dettagli.")
    end
end

local function SafeRun(area, fn, ...)
    local args = { ... }
    local function runner() return fn(unpack(args)) end
    local ok, result = xpcall(runner, function(err) return tostring(err) end)
    if not ok then
        RecordRuntimeError(area, result)
        return false, result
    end
    return true, result
end

-- ---------------------------------------------------------------------------
-- Combat telemetry
-- ---------------------------------------------------------------------------
-- Gli addon WoW non possono scrivere direttamente file in tempo reale. Questi
-- dati vengono mantenuti in memoria e serializzati dal client in
-- WTF/.../SavedVariables/HCOneButton.lua durante /reload, logout o uscita.
local function InitCombatLogDB()
    HCOB_CombatLog.version = 9
    HCOB_CombatLog.fights = HCOB_CombatLog.fights or {}
    HCOB_CombatLog.totalFights = tonumber(HCOB_CombatLog.totalFights) or 0
    HCOB_CombatLog.session = HCOB_CombatLog.session or ("HCOneButton " .. VERSION)
    -- Aggiorna solo il nome sessione automatico; un nome personalizzato
    -- impostato con /hcob log session resta intatto.
    if type(HCOB_CombatLog.session) == "string" and HCOB_CombatLog.session:match("^HCOneButton %d+%.%d+%.%d+$") then
        HCOB_CombatLog.session = "HCOneButton " .. VERSION
    end
end

local function CurrentPowerSnapshot()
    local pType, pToken = UnitPowerType("player")
    pType = tonumber(pType) or 0
    local value = tonumber(UnitPower("player", pType)) or 0
    local maxValue = tonumber(UnitPowerMax("player", pType)) or 0
    return pType, pToken or "POWER", value, maxValue
end

local function EquipmentTelemetrySnapshot()
    local mh, oh, ranged
    if GetInventoryItemID then
        mh = GetInventoryItemID("player", 16)
        oh = GetInventoryItemID("player", 17)
        ranged = GetInventoryItemID("player", 18)
    end

    local ap = 0
    if UnitAttackPower then
        local base, pos, neg = UnitAttackPower("player")
        ap = (tonumber(base) or 0) + (tonumber(pos) or 0) + (tonumber(neg) or 0)
    end

    local minDamage, maxDamage = 0, 0
    if UnitDamage then
        local a, b = UnitDamage("player")
        minDamage, maxDamage = tonumber(a) or 0, tonumber(b) or 0
    end

    local mainSpeed, offSpeed = 0, 0
    if UnitAttackSpeed then
        local a, b = UnitAttackSpeed("player")
        mainSpeed, offSpeed = tonumber(a) or 0, tonumber(b) or 0
    end

    local rangedSpeed, rangedMin, rangedMax = 0, 0, 0
    if UnitRangedDamage then
        local a, b, c = UnitRangedDamage("player")
        rangedSpeed, rangedMin, rangedMax = tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
    end
    local rangedAP = 0
    if UnitRangedAttackPower then
        local base, pos, neg = UnitRangedAttackPower("player")
        rangedAP = (tonumber(base) or 0) + (tonumber(pos) or 0) + (tonumber(neg) or 0)
    end

    return {
        mainHandItem=mh, offHandItem=oh, rangedItem=ranged,
        attackPower=ap, damageMin=minDamage, damageMax=maxDamage,
        mainHandSpeed=mainSpeed, offHandSpeed=offSpeed,
        rangedAttackPower=rangedAP, rangedSpeed=rangedSpeed, rangedDamageMin=rangedMin, rangedDamageMax=rangedMax,
    }
end

local function TableCount(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function AddEnemyToFight(guid, name)
    if not currentFight or not guid or guid == playerGUID then return end
    currentFight._enemies = currentFight._enemies or {}
    if not currentFight._enemies[guid] then
        currentFight._enemies[guid] = name or "Unknown"
    elseif name and name ~= "" then
        currentFight._enemies[guid] = name
    end
    currentFight.maxEnemies = math.max(currentFight.maxEnemies or 1, TableCount(currentFight._enemies))
end

local function IsPlayerOrPetGUID(guid)
    if not guid then return false end
    if guid == playerGUID then return true end
    local petGUID = UnitGUID("pet")
    return petGUID and guid == petGUID or false
end

local function MarkFightKill(guid)
    if not currentFight or not guid then return end
    currentFight._killed = currentFight._killed or {}
    if currentFight._killed[guid] then return end
    currentFight._killed[guid] = true
    currentFight.kills = (tonumber(currentFight.kills) or 0) + 1
end

local function AbilityRecord(owner, spellId, spellName)
    if not currentFight then return nil end
    owner = owner or "player"
    currentFight.abilities = currentFight.abilities or {}
    currentFight.petAbilities = currentFight.petAbilities or {}
    local bucket = owner == "pet" and currentFight.petAbilities or currentFight.abilities
    local sid = tonumber(spellId) or 0
    local name = spellName or (sid > 0 and SpellName(sid)) or "Auto Attack"
    local key = tostring(sid) .. ":" .. tostring(name)
    local a = bucket[key]
    if not a then
        a = { id=sid, name=tostring(name), casts=0, hits=0, crits=0, misses=0, damage=0, overkill=0, absorbed=0, blocked=0, resisted=0, missTypes={} }
        bucket[key] = a
    end
    return a
end

local function StartCombatTelemetry()
    if HCOB_DB.combatLogging == false or runtimeTelemetryDisabled then return end
    InitCombatLogDB()
    local pType, pToken, power, powerMax = CurrentPowerSnapshot()
    local hp = tonumber(UnitHealth("player")) or 0
    local hpMax = tonumber(UnitHealthMax("player")) or 0
    local specIndex, specName, specPoints = TalentSpec()
    local targetName = UnitExists("target") and UnitName("target") or nil
    local targetLevel = UnitExists("target") and UnitLevel("target") or nil
    local classification = UnitExists("target") and UnitClassification("target") or nil
    local equip = EquipmentTelemetrySnapshot()
    currentFight = {
        schema=10, addonVersion=VERSION, session=HCOB_CombatLog.session,
        startedAt=(GetServerTime and GetServerTime()) or (time and time()) or 0,
        startClock=GetTime(), duration=0,
        class=PLAYER_CLASS, level=PlayerLevel(), spec=specName, specIndex=specIndex, specPoints=specPoints,
        mainHandItem=equip.mainHandItem, offHandItem=equip.offHandItem, rangedItem=equip.rangedItem,
        attackPowerStart=equip.attackPower, damageMinStart=equip.damageMin, damageMaxStart=equip.damageMax,
        mainHandSpeed=equip.mainHandSpeed, offHandSpeed=equip.offHandSpeed,
        rangedAttackPowerStart=equip.rangedAttackPower, rangedSpeed=equip.rangedSpeed,
        rangedDamageMinStart=equip.rangedDamageMin, rangedDamageMaxStart=equip.rangedDamageMax,
        zone=(GetZoneText and GetZoneText()) or "", subZone=(GetSubZoneText and GetSubZoneText()) or "",
        target=targetName, targetLevel=targetLevel, targetClassification=classification,
        targetGuid=UnitGUID("target"), targetHpPctStart=(UnitExists("target") and UnitHealthPct("target") or 100),
        hpStart=hp, hpMax=hpMax, hpMin=hp, hpEnd=hp,
        hpMinPct=(hpMax > 0 and hp / hpMax * 100) or 100,
        powerType=pToken, powerStart=power, powerMax=powerMax, powerMin=power, powerPeak=power,
        powerSamples=1, powerSum=power,
        powerHighSamples=(powerMax > 0 and power >= powerMax * 0.80) and 1 or 0,
        powerCapSamples=(powerMax > 0 and power >= powerMax * 0.99) and 1 or 0,
        damageDone=0, petDamage=0, damageTaken=0, healingDone=0,
        maxHitDone=0, maxHitTaken=0, outgoingHits=0, incomingHits=0,
        crits=0, misses=0, dodges=0, parries=0, blocks=0, resists=0,
        kills=0, died=false, maxEnemies=1,
        abilities={}, petAbilities={}, _enemies={}, _killed={},
        baseClicks=0, heroicQueuedSamples=0,
        advisorSamples=0, advisorDangerSamples=0, advisorCautionSamples=0,
        advisorInterruptSamples=0, advisorManualSamples=0,
        advisorDangerEvents=0, advisorCautionEvents=0,
        survivalReserveSum=0, survivalReserveSamples=0, survivalReserveMin=100,
    }
    local tg = UnitGUID("target")
    if tg and UnitCanAttack("player", "target") then AddEnemyToFight(tg, targetName) end
end

local function SampleCombatTelemetry()
    if not currentFight or runtimeTelemetryDisabled then return end
    local hp = tonumber(UnitHealth("player")) or 0
    local hpMax = tonumber(UnitHealthMax("player")) or tonumber(currentFight.hpMax) or 0
    currentFight.hpEnd = hp
    currentFight.hpMax = math.max(tonumber(currentFight.hpMax) or 0, hpMax)
    currentFight.hpMin = math.min(tonumber(currentFight.hpMin) or hp, hp)
    if hpMax > 0 then currentFight.hpMinPct = math.min(tonumber(currentFight.hpMinPct) or 100, hp / hpMax * 100) end
    local _, _, power, powerMax = CurrentPowerSnapshot()
    currentFight.powerMax = math.max(tonumber(currentFight.powerMax) or 0, powerMax)
    currentFight.powerMin = math.min(tonumber(currentFight.powerMin) or power, power)
    currentFight.powerPeak = math.max(tonumber(currentFight.powerPeak) or power, power)
    currentFight.powerSamples = (tonumber(currentFight.powerSamples) or 0) + 1
    currentFight.powerSum = (tonumber(currentFight.powerSum) or 0) + power
    if powerMax > 0 and power >= powerMax * 0.80 then currentFight.powerHighSamples = (tonumber(currentFight.powerHighSamples) or 0) + 1 end
    if powerMax > 0 and power >= powerMax * 0.99 then currentFight.powerCapSamples = (tonumber(currentFight.powerCapSamples) or 0) + 1 end
    if PLAYER_CLASS == "WARRIOR" and IsCurrentSpell and SpellName(S.HEROIC_STRIKE) then
        local ok, queued = pcall(IsCurrentSpell, SpellName(S.HEROIC_STRIKE))
        if ok and queued then currentFight.heroicQueuedSamples = (tonumber(currentFight.heroicQueuedSamples) or 0) + 1 end
    end
    currentFight.duration = math.max(0, GetTime() - (currentFight.startClock or GetTime()))
end

local function TrimCombatLog()
    InitCombatLogDB()
    local maxFights = Clamp(tonumber(HCOB_DB.combatLogMaxFights) or 60, 10, 200)
    while #HCOB_CombatLog.fights > maxFights do table.remove(HCOB_CombatLog.fights, 1) end
end

local function FinalizeCombatTelemetry(reason)
    if not currentFight then return end
    SampleCombatTelemetry()
    local f = currentFight
    currentFight = nil
    f.endedAt = (GetServerTime and GetServerTime()) or (time and time()) or 0
    f.endReason = reason or "combat_end"
    f.duration = math.max(0.05, tonumber(f.duration) or 0.05)
    f.hpEnd = tonumber(UnitHealth("player")) or f.hpEnd or 0
    local _, _, power = CurrentPowerSnapshot()
    f.powerEnd = power
    local equipEnd = EquipmentTelemetrySnapshot()
    f.attackPowerEnd = equipEnd.attackPower
    f.rangedAttackPowerEnd = equipEnd.rangedAttackPower
    f.powerAvg = ((tonumber(f.powerSamples) or 0) > 0) and ((tonumber(f.powerSum) or 0) / f.powerSamples) or power
    local samples = math.max(1, tonumber(f.powerSamples) or 1)
    f.powerHighPct = (tonumber(f.powerHighSamples) or 0) / samples * 100
    f.powerCapPct = (tonumber(f.powerCapSamples) or 0) / samples * 100
    f.heroicQueuedPct = (tonumber(f.heroicQueuedSamples) or 0) / samples * 100
    local advisorSamples = math.max(1, tonumber(f.advisorSamples) or 1)
    f.advisorDangerPct = (tonumber(f.advisorDangerSamples) or 0) / advisorSamples * 100
    f.advisorCautionPct = (tonumber(f.advisorCautionSamples) or 0) / advisorSamples * 100
    f.advisorInterruptPct = (tonumber(f.advisorInterruptSamples) or 0) / advisorSamples * 100
    f.advisorManualPct = (tonumber(f.advisorManualSamples) or 0) / advisorSamples * 100
    f.survivalReserveAvg = ((tonumber(f.survivalReserveSamples) or 0) > 0) and ((tonumber(f.survivalReserveSum) or 0) / f.survivalReserveSamples) or nil
    f.totalDamage = (tonumber(f.damageDone) or 0) + (tonumber(f.petDamage) or 0)
    f.dps = f.totalDamage / f.duration
    f.playerDps = (tonumber(f.damageDone) or 0) / f.duration
    f.dtps = (tonumber(f.damageTaken) or 0) / f.duration
    f.enemies = {}
    for _, name in pairs(f._enemies or {}) do f.enemies[#f.enemies+1] = name end
    table.sort(f.enemies)
    f._enemies = nil
    f._killed = nil
    f.targetGuid = nil
    f.startClock = nil
    InitCombatLogDB()
    HCOB_CombatLog.totalFights = HCOB_CombatLog.totalFights + 1
    f.id = HCOB_CombatLog.totalFights
    HCOB_CombatLog.fights[#HCOB_CombatLog.fights + 1] = f
    TrimCombatLog()
    if UpdateDPSMeter then pcall(UpdateDPSMeter) end
end

local function IsDamageEvent(subevent)
    return subevent == "SWING_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or
           subevent == "RANGE_DAMAGE" or subevent == "DAMAGE_SHIELD" or subevent == "DAMAGE_SPLIT"
end

local function IsMissEvent(subevent)
    return subevent == "SWING_MISSED" or subevent == "SPELL_MISSED" or subevent == "SPELL_PERIODIC_MISSED" or subevent == "RANGE_MISSED"
end

local function DamagePayload(args, subevent)
    if subevent == "SWING_DAMAGE" then
        return 6603, "Auto Attack", tonumber(args[12]) or 0, tonumber(args[13]) or 0,
               tonumber(args[15]) or 0, tonumber(args[16]) or 0, tonumber(args[17]) or 0, args[18] and true or false
    end
    return tonumber(args[12]) or 0, args[13] or "Spell", tonumber(args[15]) or 0, tonumber(args[16]) or 0,
           tonumber(args[18]) or 0, tonumber(args[19]) or 0, tonumber(args[20]) or 0, args[21] and true or false
end

local function MissPayload(args, subevent)
    if subevent == "SWING_MISSED" then return 6603, "Auto Attack", args[12] or "MISS" end
    return tonumber(args[12]) or 0, args[13] or "Spell", args[15] or "MISS"
end

local function CombatLogFlagIsHostile(flags)
    if not flags then return true end
    if bit and bit.band and COMBATLOG_OBJECT_REACTION_HOSTILE then
        return bit.band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0
    end
    return true
end

local function ProcessCombatTelemetry(args)
    if HCOB_DB.combatLogging == false or runtimeTelemetryDisabled then return end
    if not currentFight and UnitAffectingCombat("player") then StartCombatTelemetry() end
    if not currentFight then return end

    local subevent = args[2]
    local sourceGUID, sourceName = args[4], args[5]
    local destGUID, destName = args[8], args[9]
    local petGUID = UnitGUID("pet")
    local owner = sourceGUID == playerGUID and "player" or (petGUID and sourceGUID == petGUID and "pet" or nil)
    local destIsOurs = destGUID == playerGUID or (petGUID and destGUID == petGUID)
    local sourceIsOther = sourceGUID and not IsPlayerOrPetGUID(sourceGUID)
    local destIsOther = destGUID and not IsPlayerOrPetGUID(destGUID)

    -- v1.6: niente filtro HOSTILE/NEUTRAL. Un GUID diventa "nemico del fight"
    -- quando scambia realmente danno/miss con player o pet. Questo include i
    -- mob gialli/neutrali che in Classic non hanno il reaction flag HOSTILE.
    if IsDamageEvent(subevent) or IsMissEvent(subevent) then
        if owner and destIsOther then AddEnemyToFight(destGUID, destName) end
        if destIsOurs and sourceIsOther then AddEnemyToFight(sourceGUID, sourceName) end
    end

    if IsDamageEvent(subevent) then
        local spellId, name, amount, overkill, resisted, blocked, absorbed, critical = DamagePayload(args, subevent)
        if owner and destIsOther then
            local a = AbilityRecord(owner, spellId, name)
            a.hits = a.hits + 1; a.damage = a.damage + amount; a.overkill = a.overkill + math.max(0, overkill)
            a.resisted = a.resisted + resisted; a.blocked = a.blocked + blocked; a.absorbed = a.absorbed + absorbed
            if critical then a.crits = a.crits + 1 end
            if owner == "player" then
                currentFight.damageDone = currentFight.damageDone + amount
                currentFight.outgoingHits = currentFight.outgoingHits + 1
                currentFight.maxHitDone = math.max(currentFight.maxHitDone, amount)
                if critical then currentFight.crits = currentFight.crits + 1 end
            else
                currentFight.petDamage = currentFight.petDamage + amount
            end
        elseif destGUID == playerGUID and sourceIsOther then
            currentFight.damageTaken = currentFight.damageTaken + amount
            currentFight.incomingHits = currentFight.incomingHits + 1
            currentFight.maxHitTaken = math.max(currentFight.maxHitTaken, amount)
        end
    elseif IsMissEvent(subevent) then
        local spellId, name, missType = MissPayload(args, subevent)
        if owner and destIsOther then
            local a = AbilityRecord(owner, spellId, name)
            a.misses = a.misses + 1
            a.missTypes[missType] = (a.missTypes[missType] or 0) + 1
            if owner == "player" then
                currentFight.misses = currentFight.misses + 1
                if missType == "DODGE" then currentFight.dodges = currentFight.dodges + 1 end
                if missType == "PARRY" then currentFight.parries = currentFight.parries + 1 end
                if missType == "BLOCK" then currentFight.blocks = currentFight.blocks + 1 end
                if missType == "RESIST" then currentFight.resists = currentFight.resists + 1 end
            end
        end
    elseif subevent == "SPELL_CAST_SUCCESS" and owner then
        local spellId, spellName = tonumber(args[12]) or 0, args[13] or "Spell"
        local a = AbilityRecord(owner, spellId, spellName)
        a.casts = a.casts + 1
    elseif subevent == "SPELL_HEAL" and owner == "player" then
        local amount = tonumber(args[15]) or 0
        local overheal = tonumber(args[16]) or 0
        currentFight.healingDone = currentFight.healingDone + math.max(0, amount - overheal)
    elseif subevent == "PARTY_KILL" and owner and destIsOther then
        AddEnemyToFight(destGUID, destName)
        MarkFightKill(destGUID)
    elseif subevent == "UNIT_DIED" then
        if destGUID == playerGUID then
            currentFight.died = true
        elseif currentFight._enemies and currentFight._enemies[destGUID] then
            MarkFightKill(destGUID)
        end
    end
end

local function SortedAbilityList(f)
    local list = {}
    for _, a in pairs((f and f.abilities) or {}) do list[#list+1] = a end
    table.sort(list, function(a,b)
        local av = (a.damage or 0) + (a.casts or 0) * 0.01
        local bv = (b.damage or 0) + (b.casts or 0) * 0.01
        return av > bv
    end)
    return list
end

local function PrintLastCombatLog()
    InitCombatLogDB()
    local f = HCOB_CombatLog.fights[#HCOB_CombatLog.fights]
    if not f then print("|cffffcc00HCOB LOG:|r nessun combattimento registrato."); return end
    local enemies = (f.enemies and #f.enemies > 0) and table.concat(f.enemies, ", ") or (f.target or "?")
    print(string.format("|cff00ff98HCOB LOG #%d|r %s | %.1fs | %.1f DPS | dmg %d | presi %d", f.id or 0, enemies, f.duration or 0, f.dps or 0, f.totalDamage or 0, f.damageTaken or 0))
    print(string.format("HP minimo %.1f%% | %s medio %.1f | max hit fatto %d / preso %d | nemici max %d", f.hpMinPct or 100, f.powerType or "Power", f.powerAvg or 0, f.maxHitDone or 0, f.maxHitTaken or 0, f.maxEnemies or 1))
    if f.powerType == "RAGE" then
        print(string.format("Rage start/end %.0f/%.0f | >=80: %.1f%% del fight | CAP: %.1f%%", f.powerStart or 0, f.powerEnd or 0, f.powerHighPct or 0, f.powerCapPct or 0))
        if f.schema and f.schema >= 5 then
            print(string.format("BASE clicks %d | Heroic queued %.1f%% campioni", f.baseClicks or 0, f.heroicQueuedPct or 0))
        end
    end
    if f.schema and f.schema >= 7 then
        print(string.format("Advisor: DANGER %.1f%% | CAUTION %.1f%% | manuale %.1f%% | alert D/C %d/%d",
            f.advisorDangerPct or 0, f.advisorCautionPct or 0, f.advisorManualPct or 0,
            f.advisorDangerEvents or 0, f.advisorCautionEvents or 0))
    end
    if f.schema and f.schema >= 10 and f.survivalReserveAvg then
        print(string.format("Advisor 2.0 reserve: media %.1f | minima %.1f", f.survivalReserveAvg or 0, f.survivalReserveMin or 0))
    end
    local list = SortedAbilityList(f)
    for i=1, math.min(8, #list) do
        local a = list[i]
        local extra = ""
        if (a.casts or 0) > 0 then extra = extra .. " cast=" .. a.casts end
        if (a.hits or 0) > 0 then extra = extra .. " hit=" .. a.hits end
        if (a.crits or 0) > 0 then extra = extra .. " crit=" .. a.crits end
        if (a.misses or 0) > 0 then extra = extra .. " miss=" .. a.misses end
        print(string.format("  %s: %d dmg%s", a.name or "?", a.damage or 0, extra))
    end
end

local function PrintCombatLogStats()
    InitCombatLogDB()
    local fights = HCOB_CombatLog.fights
    if #fights == 0 then print("|cffffcc00HCOB LOG:|r nessun combattimento registrato."); return end
    local n = math.min(10, #fights)
    local td, tt, taken, minHp, rageHigh, rageCap, rageCount = 0,0,0,100,0,0,0
    local advDanger, advCaution, advCount = 0,0,0
    for i=#fights-n+1,#fights do
        local f=fights[i]
        td=td+(f.totalDamage or 0); tt=tt+(f.duration or 0); taken=taken+(f.damageTaken or 0); minHp=math.min(minHp,f.hpMinPct or 100)
        if f.powerType == "RAGE" and f.powerHighPct ~= nil then
            rageHigh = rageHigh + (f.powerHighPct or 0); rageCap = rageCap + (f.powerCapPct or 0); rageCount = rageCount + 1
        end
        if f.schema and f.schema >= 7 then
            advDanger = advDanger + (f.advisorDangerPct or 0)
            advCaution = advCaution + (f.advisorCautionPct or 0)
            advCount = advCount + 1
        end
    end
    print(string.format("|cff00ff98HCOB LOG:|r ultimi %d fight | DPS medio %.1f | durata media %.1fs | danni subiti/fight %.1f | HP minimo %.1f%%", n, tt>0 and td/tt or 0, tt/n, taken/n, minHp))
    if rageCount > 0 then print(string.format("Rage >=80 media %.1f%% | rage CAP media %.1f%%", rageHigh/rageCount, rageCap/rageCount)) end
    if advCount > 0 then print(string.format("Advisor medio: DANGER %.1f%% | CAUTION %.1f%%", advDanger/advCount, advCaution/advCount)) end
end

local function ClearCombatLog()
    HCOB_CombatLog = { version=9, fights={}, totalFights=0, session="HCOneButton "..VERSION }
    currentFight = nil
    print("|cff00ff98HCOB LOG:|r storico cancellato.")
end

local function ApplyAttributes(target, main, mods)
    if not target then return end
    target:SetAttribute("type1", "macro")
    target:SetAttribute("macrotext1", main or "/stopmacro")
    target:SetAttribute("shift-type1", "macro")
    target:SetAttribute("shift-macrotext1", mods.shift or "/stopmacro")
    target:SetAttribute("ctrl-type1", "macro")
    target:SetAttribute("ctrl-macrotext1", mods.ctrl or "/stopmacro")
    target:SetAttribute("alt-type1", "macro")
    target:SetAttribute("alt-macrotext1", mods.alt or "/stopmacro")
    target:SetAttribute("ctrl-shift-type1", "macro")
    target:SetAttribute("ctrl-shift-macrotext1", mods.ctrlshift or "/stopmacro")
    target:SetAttribute("alt-shift-type1", "macro")
    target:SetAttribute("alt-shift-macrotext1", mods.altshift or "/stopmacro")
    target:SetAttribute("alt-ctrl-type1", "macro")
    target:SetAttribute("alt-ctrl-macrotext1", mods.altctrl or "/stopmacro")
    target:SetAttribute("alt-ctrl-shift-type1", "macro")
    target:SetAttribute("alt-ctrl-shift-macrotext1", mods.all or "/stopmacro")
end

local function BaseActionInfo()
    local spec = TalentSpec()
    if PLAYER_CLASS == "WARRIOR" then
        local inCombat = UnitAffectingCombat("player") and true or false
        if not inCombat and IsKnown(S.CHARGE) then
            return S.CHARGE, currentWarriorAutoRend and "CHARGE -> REND x1" or "CHARGE -> AUTO"
        end
        return S.ATTACK, currentWarriorAutoRend and "AUTO + REND x1" or "AUTO ATTACK"
    elseif PLAYER_CLASS == "PALADIN" then
        return S.ATTACK, "AUTO ATTACK"
    elseif PLAYER_CLASS == "HUNTER" then
        return S.AUTO_SHOT, "PET + AUTO (1x)"
    elseif PLAYER_CLASS == "ROGUE" then
        local builder = (spec == 3 and IsKnown(S.HEMORRHAGE)) and S.HEMORRHAGE or S.SINISTER_STRIKE
        return builder, SpellName(builder, "Builder")
    elseif PLAYER_CLASS == "PRIEST" then
        if HasWandEquipped() and IsKnown(S.SHOOT) then return S.SHOOT, "WAND" end
        if spec == 3 and IsKnown(S.MIND_FLAY) then return S.MIND_FLAY, "MIND FLAY" end
        return S.SMITE, "SMITE"
    elseif PLAYER_CLASS == "MAGE" then
        local primary = Mage.PrimarySpell()
        return primary, SpellName(primary, "NUKE")
    elseif PLAYER_CLASS == "WARLOCK" then
        if HasWandEquipped() and IsKnown(S.SHOOT) and spec ~= 3 then return S.SHOOT, "PET + WAND" end
        return S.SHADOW_BOLT, "PET + SHADOW BOLT"
    elseif PLAYER_CLASS == "DRUID" then
        local form = GetShapeshiftForm and GetShapeshiftForm() or 0
        if form == 3 and IsKnown(S.CLAW) then return S.CLAW, "CLAW" end
        if form == 1 then return S.ATTACK, "BEAR AUTO" end
        return S.WRATH, "WRATH"
    elseif PLAYER_CLASS == "SHAMAN" then
        if spec == 2 then return S.ATTACK, "AUTO ATTACK" end
        return S.LIGHTNING_BOLT, "LIGHTNING BOLT"
    end
    return nil, "BASE SPAM"
end

local function UpdateBaseVisual()
    local id, desc = BaseActionInfo()
    icon:SetTexture(SpellIcon(id))
    label:SetText(PLAYER_CLASS == "HUNTER" and "PULL / AUTO" or "BASE SPAM")
    hint:SetText(desc or "Azione base")
    reasonText:SetText("Situazionale -> Advisor")
    glow:Hide()
end

local function BuildMacros()
    if InCombatLockdown() then pendingRebuild = true; return end
    local builder = MAIN_BUILDERS[PLAYER_CLASS]
    local modBuilder = MOD_BUILDERS[PLAYER_CLASS]
    local main = builder and builder() or "/stopmacro"
    local mods = modBuilder and modBuilder() or {desc={}}
    currentMods = mods
    ApplyAttributes(btn, main, mods)
    if HCOB_ActionPanel then HCOB_ActionPanel.Configure(); HCOB_ActionPanel.SyncVisibility() end
    pendingRebuild = false
end

local function CountActiveEnemies()
    local now, count = GetTime(), 0
    for guid, seen in pairs(activeEnemies) do
        if now - seen > (HCOB_DB.enemyWindow or 6) then activeEnemies[guid] = nil else count = count + 1 end
    end
    if HostileLiveTarget() then
        local tg = UnitGUID("target")
        if tg and not activeEnemies[tg] then count = count + 1 end
    end
    return count
end

local function MarkEnemy(guid)
    if guid and guid ~= playerGUID then activeEnemies[guid] = GetTime() end
end

-- -------------------------------------------------------------------------
-- Advisor Engine 2.0
-- Common prediction/stability layer. All classes except Druid currently propose scored candidates;
-- this engine ranks them, keeps short-lived recommendations stable and uses a
-- rolling combat window instead of the whole-fight average for HC trend checks.
-- -------------------------------------------------------------------------
HCOB_AdvisorEngine = HCOB_AdvisorEngine or {}
HCOB_AdvisorEngine.samples = HCOB_AdvisorEngine.samples or {}
HCOB_AdvisorEngine.lastCandidates = HCOB_AdvisorEngine.lastCandidates or {}
HCOB_AdvisorEngine.kindPriority = {
    idle=0, buff=20, action=40, caution=70, interrupt=90, danger=100,
}

function HCOB_AdvisorEngine.ResetDynamics()
    HCOB_AdvisorEngine.samples = {}
    HCOB_AdvisorEngine.dynamicsTargetGuid = nil
    HCOB_AdvisorEngine.trendState = nil
end

function HCOB_AdvisorEngine.RollingDynamics(targetHP)
    if not currentFight or CountActiveEnemies() > 1 or not HostileLiveTarget() then
        HCOB_AdvisorEngine.ResetDynamics()
        return nil
    end

    local guid = UnitGUID("target")
    if currentFight.targetGuid and currentFight.targetGuid ~= guid then
        HCOB_AdvisorEngine.ResetDynamics()
        return nil
    end
    if HCOB_AdvisorEngine.dynamicsTargetGuid ~= guid then
        HCOB_AdvisorEngine.ResetDynamics()
        HCOB_AdvisorEngine.dynamicsTargetGuid = guid
    end

    local now = GetTime()
    local samples = HCOB_AdvisorEngine.samples
    local last = samples[#samples]
    if not last or (now - last.t) >= 0.20 then
        samples[#samples + 1] = {
            t=now,
            targetHP=tonumber(targetHP) or UnitHealthPct("target") or 100,
            playerHP=UnitHealthPct("player"),
            damageTaken=tonumber(currentFight.damageTaken) or 0,
            hpMax=math.max(1, tonumber(UnitHealthMax("player")) or tonumber(currentFight.hpMax) or 1),
        }
    end

    local cutoff = now - 5.0
    while #samples > 2 and samples[2].t < cutoff do table.remove(samples, 1) end
    if #samples < 2 then return nil end

    local first = samples[1]
    local current = samples[#samples]
    local dt = math.max(0.05, current.t - first.t)
    if dt < 2.2 then return nil end

    local targetLost = math.max(0, (first.targetHP or 100) - (current.targetHP or 100))
    local targetRate = targetLost / dt
    local incomingDamage = math.max(0, (current.damageTaken or 0) - (first.damageTaken or 0))
    local hpMax = math.max(1, current.hpMax or first.hpMax or 1)
    local incomingPct = incomingDamage / hpMax * 100
    local incomingPctRate = incomingPct / dt
    local playerHP = current.playerHP or UnitHealthPct("player")
    local nowTarget = current.targetHP or targetHP or 100
    local ttk = targetRate > 0.05 and (nowTarget / targetRate) or math.huge
    local ttd = incomingPctRate > 0.03 and (playerHP / incomingPctRate) or math.huge

    local observation = Clamp(dt / 4.0, 0, 1)
    local outgoingEvidence = Clamp(targetLost / 15.0, 0, 1)
    local incomingEvidence = Clamp(incomingPct / 12.0, 0, 1)
    local confidence = Clamp(observation * 0.45 + outgoingEvidence * 0.35 + incomingEvidence * 0.20, 0, 1)

    local result = {
        window=dt, ttk=ttk, ttd=ttd,
        targetRate=targetRate, incomingPctRate=incomingPctRate,
        confidence=confidence, targetLost=targetLost, incomingPct=incomingPct,
    }
    HCOB_AdvisorEngine.lastDynamics = result
    return result
end

-- Shared class helpers for Advisor Engine 2.0. These are methods instead of
-- chunk-level locals so the Classic Lua 5.1 local-variable ceiling stays safe.
function HCOB_AdvisorEngine.ManaPct()
    local maxMana = UnitPowerMax("player", 0) or 0
    if maxMana <= 0 then return 100 end
    return ((UnitPower("player", 0) or 0) / maxMana) * 100
end

function HCOB_AdvisorEngine.TargetIsClose()
    if not HostileLiveTarget() then return false end
    if HCOB_AdvisorEngine.lastMeleeAt and (GetTime() - HCOB_AdvisorEngine.lastMeleeAt) <= 2.5 then return true end
    if CheckInteractDistance then
        local ok, close = pcall(CheckInteractDistance, "target", 3)
        if ok then return close and true or false end
    end
    return false
end

function HCOB_AdvisorEngine.PetAlive()
    return UnitExists("pet") and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("pet"))
end

function HCOB_AdvisorEngine.PetHP()
    if not HCOB_AdvisorEngine.PetAlive() then return 0 end
    local maxHP = UnitHealthMax("pet") or 0
    if maxHP <= 0 then return 0 end
    return ((UnitHealth("pet") or 0) / maxHP) * 100
end

function HCOB_AdvisorEngine.PlayerHasDebuff(id)
    return AuraByName("player", SpellName(id), "HARMFUL", false)
end

function HCOB_AdvisorEngine.TargetCreatureTypeID()
    if not HostileLiveTarget() or not UnitCreatureType then return nil end
    local ok, _, creatureTypeID = pcall(UnitCreatureType, "target")
    if not ok then return nil end
    return creatureTypeID
end

function HCOB_AdvisorEngine.TotemActive(id)
    if not id or not GetTotemInfo then return false end
    local wanted = SpellName(id)
    local wantedIcon = SpellIcon(id)
    for slot=1,4 do
        local ok, haveTotem, name, _, duration, icon = pcall(GetTotemInfo, slot)
        if ok and haveTotem then
            if (wanted and name == wanted) or (wantedIcon and icon == wantedIcon) then
                return (tonumber(duration) or 0) > 0
            end
        end
    end
    return false
end

function HCOB_AdvisorEngine.PriestHealSpell(emergency)
    if emergency and IsKnown(S.FLASH_HEAL) and IsUsable(S.FLASH_HEAL) then return S.FLASH_HEAL end
    if IsKnown(S.HEAL) and IsUsable(S.HEAL) then return S.HEAL end
    if IsKnown(S.LESSER_HEAL) and IsUsable(S.LESSER_HEAL) then return S.LESSER_HEAL end
    if IsKnown(S.FLASH_HEAL) and IsUsable(S.FLASH_HEAL) then return S.FLASH_HEAL end
    return nil
end

function HCOB_AdvisorEngine.PaladinHealSpell(emergency)
    if emergency and IsKnown(S.FLASH_LIGHT) and IsUsable(S.FLASH_LIGHT) then return S.FLASH_LIGHT end
    if IsKnown(S.HOLY_LIGHT) and IsUsable(S.HOLY_LIGHT) then return S.HOLY_LIGHT end
    if IsKnown(S.FLASH_LIGHT) and IsUsable(S.FLASH_LIGHT) then return S.FLASH_LIGHT end
    return nil
end

function HCOB_AdvisorEngine.SurvivalReserve()
    local hp = UnitHealthPct("player")
    local enemies = CountActiveEnemies()
    local pMax = UnitPowerMax("player", 0) or 0
    local mana = pMax > 0 and ((UnitPower("player", 0) or 0) / pMax * 100) or 100
    local score

    if PLAYER_CLASS == "HUNTER" then
        local petHP = HCOB_Hunter.PetHP() or 0
        score = hp * 0.48 + mana * 0.10 + petHP * 0.17
        if HCOB_Hunter.PetAlive() then score = score + 4 end
        if HCOB_Hunter.PetIsTanking() then score = score + 4 end
        if IsKnown(S.FEIGN_DEATH) and CooldownReady(S.FEIGN_DEATH) and IsUsable(S.FEIGN_DEATH) then score = score + 10 end
        if IsKnown(S.SCATTER_SHOT) and CooldownReady(S.SCATTER_SHOT) and IsUsable(S.SCATTER_SHOT) then score = score + 5 end
        if IsKnown(S.CONCUSSIVE_SHOT) and CooldownReady(S.CONCUSSIVE_SHOT) and IsUsable(S.CONCUSSIVE_SHOT) then score = score + 3 end
        if IsKnown(S.WING_CLIP) and IsUsable(S.WING_CLIP) then score = score + 3 end
        if HCOB_Hunter.TargetIsClose() then score = score - 8 end
    elseif PLAYER_CLASS == "WARRIOR" then
        local pType = UnitPowerType("player")
        local rage = UnitPower("player", pType) or 0
        score = hp * 0.68 + math.min(70, rage) * 0.11 + 8
        if IsKnown(S.SHIELD_WALL) and CooldownReady(S.SHIELD_WALL) and IsUsable(S.SHIELD_WALL) then score = score + 10 end
        if IsKnown(S.RETALIATION) and CooldownReady(S.RETALIATION) and IsUsable(S.RETALIATION) then score = score + 7 end
        if IsKnown(S.HAMSTRING) and IsUsable(S.HAMSTRING) then score = score + 4 end
        if IsKnown(S.THUNDER_CLAP) and CooldownReady(S.THUNDER_CLAP) and IsUsable(S.THUNDER_CLAP) then score = score + 3 end
        if IsKnown(S.DEMO_SHOUT) and IsUsable(S.DEMO_SHOUT) then score = score + 2 end
        if hp < 45 and rage < 10 then score = score - 5 end
    elseif PLAYER_CLASS == "MAGE" then
        score = hp * 0.50 + mana * 0.20
        if IsKnown(S.BLINK) and CooldownReady(S.BLINK) and IsUsable(S.BLINK) then score = score + 10 end
        if IsKnown(S.FROST_NOVA) and CooldownReady(S.FROST_NOVA) and IsUsable(S.FROST_NOVA) then score = score + 10 end
        if IsKnown(S.ICE_BLOCK) and CooldownReady(S.ICE_BLOCK) and IsUsable(S.ICE_BLOCK) then score = score + 12 end
        if IsKnown(S.COLD_SNAP) and CooldownReady(S.COLD_SNAP) and IsUsable(S.COLD_SNAP) then score = score + 6 end
        if IsKnown(S.ICE_BARRIER) then
            local hasBarrier = HasPlayerBuff(S.ICE_BARRIER)
            if hasBarrier then score = score + 7
            elseif CooldownReady(S.ICE_BARRIER) and IsUsable(S.ICE_BARRIER) and mana >= 25 then score = score + 3 end
        end
        if IsKnown(S.MANA_SHIELD) and IsUsable(S.MANA_SHIELD) and mana >= 45 then score = score + 2 end
        if Mage.TargetIsClose() then score = score - 10 end
    elseif PLAYER_CLASS == "WARLOCK" then
        local petHP = HCOB_AdvisorEngine.PetHP()
        score = hp * 0.47 + mana * 0.15 + petHP * 0.10 + 10
        if HCOB_AdvisorEngine.PetAlive() then score = score + 5 end
        if IsKnown(S.DEATH_COIL) and CooldownReady(S.DEATH_COIL) and IsUsable(S.DEATH_COIL) then score = score + 12 end
        if IsKnown(S.FEAR) and IsUsable(S.FEAR) then score = score + 7 end
        if IsKnown(S.DRAIN_LIFE) and IsUsable(S.DRAIN_LIFE) and mana >= 18 then score = score + 4 end
        if HCOB_AdvisorEngine.TargetIsClose() then score = score - 10 end
        if hp < 45 and mana < 20 then score = score - 5 end
    elseif PLAYER_CLASS == "PRIEST" then
        score = hp * 0.52 + mana * 0.18 + 8
        local shielded = HasPlayerBuff(S.POWER_WORD_SHIELD)
        if shielded then score = score + 10
        elseif IsKnown(S.POWER_WORD_SHIELD) and IsUsable(S.POWER_WORD_SHIELD) and not HCOB_AdvisorEngine.PlayerHasDebuff(S.WEAKENED_SOUL) then score = score + 5 end
        if IsKnown(S.PSYCHIC_SCREAM) and CooldownReady(S.PSYCHIC_SCREAM) and IsUsable(S.PSYCHIC_SCREAM) then score = score + 10 end
        if HCOB_AdvisorEngine.PriestHealSpell(false) then score = score + 6 end
        if IsKnown(S.RENEW) and IsUsable(S.RENEW) then score = score + 2 end
        if HCOB_AdvisorEngine.TargetIsClose() then score = score - 8 end
    elseif PLAYER_CLASS == "ROGUE" then
        local pType = UnitPowerType("player")
        local energy = UnitPower("player", pType) or 0
        score = hp * 0.70 + math.min(100, energy) * 0.07 + 5
        if IsKnown(S.VANISH) and CooldownReady(S.VANISH) and IsUsable(S.VANISH) then score = score + 14 end
        if IsKnown(S.EVASION) and CooldownReady(S.EVASION) and IsUsable(S.EVASION) then score = score + 10 end
        if IsKnown(S.GOUGE) and CooldownReady(S.GOUGE) and IsUsable(S.GOUGE) then score = score + 5 end
        if IsKnown(S.SPRINT) and CooldownReady(S.SPRINT) and IsUsable(S.SPRINT) then score = score + 4 end
    elseif PLAYER_CLASS == "PALADIN" then
        score = hp * 0.56 + mana * 0.14 + 8
        if IsKnown(S.DIVINE_SHIELD) and CooldownReady(S.DIVINE_SHIELD) and IsUsable(S.DIVINE_SHIELD) then score = score + 15
        elseif IsKnown(S.DIVINE_PROTECTION) and CooldownReady(S.DIVINE_PROTECTION) and IsUsable(S.DIVINE_PROTECTION) then score = score + 10 end
        if IsKnown(S.LAY_ON_HANDS) and CooldownReady(S.LAY_ON_HANDS) and IsUsable(S.LAY_ON_HANDS) then score = score + 12 end
        if HCOB_AdvisorEngine.PaladinHealSpell(false) and mana >= 15 then score = score + 7 end
        if IsKnown(S.HAMMER_JUSTICE) and CooldownReady(S.HAMMER_JUSTICE) and IsUsable(S.HAMMER_JUSTICE) then score = score + 5 end
        if HCOB_AdvisorEngine.TargetIsClose() and hp < 55 then score = score - 4 end
    elseif PLAYER_CLASS == "SHAMAN" then
        score = hp * 0.55 + mana * 0.18 + 8
        if IsKnown(S.STONECLAW_TOTEM) and IsUsable(S.STONECLAW_TOTEM) then score = score + 8 end
        if IsKnown(S.EARTHBIND_TOTEM) and IsUsable(S.EARTHBIND_TOTEM) then score = score + 5 end
        if IsKnown(S.HEALING_WAVE) and IsUsable(S.HEALING_WAVE) and mana >= 20 then score = score + 7 end
        if IsKnown(S.GHOST_WOLF) and IsUsable(S.GHOST_WOLF) then score = score + 4 end
        if HCOB_AdvisorEngine.TargetIsClose() then score = score - 6 end
    else
        -- Druid intentionally remains on the simpler/base advisor for now.
        score = hp * 0.76 + math.min(100, mana) * 0.08 + 12
    end

    score = score - math.max(0, enemies - 1) * 12
    score = Clamp(score, 0, 100)
    local label = score >= 72 and "HIGH" or (score >= 48 and "MED" or (score >= 30 and "LOW" or "CRITICAL"))
    HCOB_AdvisorEngine.lastReserve = score
    HCOB_AdvisorEngine.lastReserveLabel = label
    return score, label
end

function HCOB_AdvisorEngine.AddCandidate(list, id, title, key, reason, score, tag)
    if not list then return end
    list[#list + 1] = {
        id=id, title=title, key=key, reason=reason,
        score=tonumber(score) or 0, tag=tag or "action",
    }
end

function HCOB_AdvisorEngine.SelectCandidate(list)
    if not list or #list == 0 then
        HCOB_AdvisorEngine.lastCandidates = {}
        return nil
    end
    local now = GetTime()
    local best, bestScore
    for _, c in ipairs(list) do
        local effective = c.score or 0
        if HCOB_AdvisorEngine.lastClassActionId and c.id == HCOB_AdvisorEngine.lastClassActionId
           and (now - (HCOB_AdvisorEngine.lastClassActionAt or 0)) <= 1.25 then
            effective = effective + 7 -- hysteresis: avoid threshold flicker
        end
        c.effectiveScore = effective
        if not best or effective > bestScore then best, bestScore = c, effective end
    end
    table.sort(list, function(a,b) return (a.effectiveScore or a.score or 0) > (b.effectiveScore or b.score or 0) end)
    HCOB_AdvisorEngine.lastCandidates = list
    if best then
        if HCOB_AdvisorEngine.lastClassActionId ~= best.id then
            HCOB_AdvisorEngine.lastClassActionAt = now
        end
        HCOB_AdvisorEngine.lastClassActionId = best.id
        HCOB_AdvisorEngine.lastClassAction = best
        return best.id, best.title, best.key, best.reason
    end
end

function HCOB_AdvisorEngine.Stabilize(spellId, title, keyHint, reason, kind)
    local now = GetTime()
    local priority = HCOB_AdvisorEngine.kindPriority[kind or "idle"] or 0
    local state = HCOB_AdvisorEngine.displayState
    local signature = tostring(spellId) .. ":" .. tostring(kind) .. ":" .. tostring(title)

    if not state then
        HCOB_AdvisorEngine.displayState = {spellId=spellId,title=title,key=keyHint,reason=reason,kind=kind,priority=priority,signature=signature,since=now}
        return spellId, title, keyHint, reason, kind
    end
    if state.signature == signature then
        state.reason = reason
        state.key = keyHint
        return spellId, title, keyHint, reason, kind
    end

    -- Never delay a higher-priority safety/interrupt state.  For normal action
    -- swaps, keep the previous recommendation for a tiny window only when the
    -- old spell is still known/ready.  This removes 100-200 ms threshold flicker
    -- without hiding real emergency changes.
    local age = now - (state.since or 0)
    local hold = (state.kind == "action" or state.kind == "buff") and 0.28 or 0
    local oldStillPlausible = state.spellId and IsKnown(state.spellId) and CooldownReady(state.spellId)
    if priority <= (state.priority or 0) and hold > 0 and age < hold and oldStillPlausible then
        return state.spellId, state.title, state.key, state.reason, state.kind
    end

    HCOB_AdvisorEngine.displayState = {spellId=spellId,title=title,key=keyHint,reason=reason,kind=kind,priority=priority,signature=signature,since=now}
    return spellId, title, keyHint, reason, kind
end

function HCOB_AdvisorEngine.TrendState(dyn, hp)
    if not dyn or dyn.confidence < 0.38 or dyn.ttk == math.huge or dyn.ttd == math.huge then
        if not dyn then HCOB_AdvisorEngine.trendState = nil end
        return nil
    end
    local state = HCOB_AdvisorEngine.trendState
    local severe = (hp <= 45 and dyn.ttk >= 4) or (hp <= 65 and dyn.ttd <= (dyn.ttk * 1.05 + 0.5))
    local caution = hp <= 72 and dyn.ttk >= 4 and dyn.ttd <= (dyn.ttk * 1.35 + 2.0)

    if state == "danger" then
        if hp >= 54 and dyn.ttd > (dyn.ttk * 1.28 + 2.0) then state = caution and "caution" or nil end
    elseif state == "caution" then
        if severe then state = "danger"
        elseif hp >= 78 or dyn.ttd > (dyn.ttk * 1.58 + 3.0) then state = nil end
    else
        if severe and dyn.confidence >= 0.48 then state = "danger"
        elseif caution and dyn.confidence >= 0.45 then state = "caution" end
    end
    HCOB_AdvisorEngine.trendState = state
    return state
end

function HCOB_AdvisorEngine.HunterRecommendation(inCombat, hostile, targetHP, spec)
    local petAlive = HCOB_Hunter.PetAlive()
    local candidates = {}

    if not inCombat and petAlive and IsKnown(S.FEED_PET) then
        local happiness, petDamagePct = HCOB_Hunter.Happiness()
        local eating = HCOB_Hunter.PetIsEating()
        if happiness and happiness < 3 and not eating then
            local food = HCOB_Hunter.FoodCandidate()
            if food then
                local title = happiness == 1 and "PET AFFAMATO!" or "NUTRI PET"
                HCOB_AdvisorEngine.AddCandidate(candidates, S.FEED_PET, title, "ALT+CTRL",
                    string.format("%s -> %s (pet damage %s%%)", HCOB_Hunter.PetDietText(), food.name, tostring(petDamagePct or "?")), 96, "sustain")
            else
                HCOB_AdvisorEngine.AddCandidate(candidates, S.FEED_PET, "MANCA CIBO PET", "/HCOB PETFOOD",
                    "Dieta " .. HCOB_Hunter.PetDietText() .. ": nessun cibo compatibile/utile in borsa", 95, "sustain")
            end
        end
    end

    if not hostile then return HCOB_AdvisorEngine.SelectCandidate(candidates) end

    local manaPct = HCOB_Hunter.ManaPct()
    local petHP = HCOB_Hunter.PetHP()
    local close = HCOB_Hunter.TargetIsClose()
    local canShoot = HCOB_Hunter.CanShootTarget()
    local level = PlayerLevel()
    local targetLevel = tonumber(UnitLevel("target")) or level
    local classification = UnitClassification("target") or "normal"
    local tough = classification == "elite" or classification == "rareelite" or classification == "worldboss" or targetLevel >= level
    local elapsed = currentFight and math.max(0, GetTime() - (currentFight.startClock or GetTime())) or 0
    local afterAuto = HCOB_Hunter.AfterAutoWindow()
    local reserve, reserveLabel = HCOB_AdvisorEngine.SurvivalReserve()
    local dyn = inCombat and HCOB_AdvisorEngine.RollingDynamics(targetHP) or nil
    local estimatedTTK = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local riskPenalty = reserve < 55 and ((55 - reserve) * 0.75) or 0
    if reserve < 35 then riskPenalty = riskPenalty + 10 end
    local context = string.format("reserve %.0f %s", reserve, reserveLabel)
    if estimatedTTK and estimatedTTK < math.huge then context = context .. string.format(" | TTK ~%.0fs", estimatedTTK) end

    -- Survival / control candidates intentionally outrank damage candidates.
    if inCombat and petAlive and petHP and IsKnown(S.MEND_PET) and IsUsable(S.MEND_PET) then
        if petHP <= 32 and not close and not (UnitExists("targettarget") and UnitIsUnit and UnitIsUnit("targettarget", "player")) then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.MEND_PET, "MEND PET!", "ALT+CTRL", string.format("Pet %.0f%%: salva il tank | %s", petHP, context), 99, "survival")
        elseif petHP <= 52 and tough and targetHP >= 45 and HCOB_Hunter.PetIsTanking() and manaPct >= 25 then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.MEND_PET, "MEND PET", "ALT+CTRL", string.format("Pet %.0f%% su fight lungo | %s", petHP, context), 82, "survival")
        end
    end

    if inCombat and close then
        if IsKnown(S.WING_CLIP) and IsUsable(S.WING_CLIP) and not HasMyTargetDebuff(S.WING_CLIP) then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.WING_CLIP, "WING CLIP + ESCI", "ALT", "Dead zone: slow, crea distanza e riprendi Auto Shot", 100, "survival")
        end
        if IsKnown(S.SCATTER_SHOT) and CooldownReady(S.SCATTER_SHOT) and IsUsable(S.SCATTER_SHOT) and targetHP > 20 then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.SCATTER_SHOT, "SCATTER + DISTANZA", "CTRL+SHIFT", "Target addosso: interrompi pressione e torna a range", 94, "survival")
        end
        if IsKnown(S.RAPTOR_STRIKE) and CooldownReady(S.RAPTOR_STRIKE) and IsUsable(S.RAPTOR_STRIKE) and targetHP <= 25 then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.RAPTOR_STRIKE, "RAPTOR FINISH", "CAST MANUALE", "Target basso e sei gia' in melee", 72, "finisher")
        end
    end

    if inCombat and not close and petAlive and UnitExists("targettarget") and UnitIsUnit and UnitIsUnit("targettarget", "player") then
        if IsKnown(S.SCATTER_SHOT) and CooldownReady(S.SCATTER_SHOT) and IsUsable(S.SCATTER_SHOT) then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.SCATTER_SHOT, "PEEL: SCATTER", "CTRL+SHIFT", "Hai aggro: crea spazio e lascia riprendere il pet", 96, "survival")
        end
        if IsKnown(S.CONCUSSIVE_SHOT) and CooldownReady(S.CONCUSSIVE_SHOT) and IsUsable(S.CONCUSSIVE_SHOT) then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.CONCUSSIVE_SHOT, "PEEL: CONCUSSIVE", "CTRL+SHIFT", "Hai aggro: rallenta prima della dead zone", 89, "survival")
        end
    end

    if inCombat and spec == 1 and petAlive and targetHP >= 70 then
        if IsKnown(S.BESTIAL_WRATH) and CooldownReady(S.BESTIAL_WRATH) and IsUsable(S.BESTIAL_WRATH) and (tough or CountActiveEnemies() >= 2) then
            local longEnough = not estimatedTTK or estimatedTTK >= 10
            if longEnough then HCOB_AdvisorEngine.AddCandidate(candidates, S.BESTIAL_WRATH, "BESTIAL WRATH", "CAST MANUALE", "Fight importante: pet burst | " .. context, 75 - riskPenalty, "burst") end
        end
        if IsKnown(S.INTIMIDATION) and CooldownReady(S.INTIMIDATION) and IsUsable(S.INTIMIDATION) and tough then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.INTIMIDATION, "INTIMIDATION", "CAST MANUALE", "Stun/threat sul target resistente | " .. context, 73, "control")
        end
    end

    local markWorth = tough or targetLevel >= level - 3
    if estimatedTTK then markWorth = estimatedTTK >= 10 end
    if IsKnown(S.HUNTERS_MARK) and targetHP >= 60 and (not inCombat or elapsed <= 3.5) and markWorth then
        if not HasMyTargetDebuff(S.HUNTERS_MARK) then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.HUNTERS_MARK, "HUNTER'S MARK", "CAST MANUALE", "Target abbastanza lungo | " .. context, (inCombat and 54 or 64) - riskPenalty * 0.25, "setup")
        end
    end

    local stingWorth = tough or targetLevel >= level - 3
    if estimatedTTK then stingWorth = estimatedTTK >= 8.0 end
    if inCombat and IsKnown(S.SERPENT_STING) and manaPct >= 30 and targetHP >= 45 and elapsed <= 7.0 and stingWorth and not HasMyTargetDebuff(S.SERPENT_STING) then
        local score = 67 + math.min(8, math.max(0, (manaPct - 45) * 0.12)) - riskPenalty
        HCOB_AdvisorEngine.AddCandidate(candidates, S.SERPENT_STING, "SERPENT STING", "CAST MANUALE", "DoT early con tempo per tickare | " .. context, score, "dot")
    end

    if inCombat and canShoot and afterAuto then
        if IsKnown(S.AIMED_SHOT) and CooldownReady(S.AIMED_SHOT) and IsUsable(S.AIMED_SHOT) and manaPct >= 40 and targetHP >= 38 then
            local longEnough = not estimatedTTK or estimatedTTK >= math.max(3.5, SpellCastSeconds(S.AIMED_SHOT) + 0.5)
            if longEnough then
                HCOB_AdvisorEngine.AddCandidate(candidates, S.AIMED_SHOT, "AIMED WEAVE", "ALT+SHIFT", "Finestra subito dopo Auto Shot | " .. context, 81 - riskPenalty, "weave")
            end
        end
        if CountActiveEnemies() <= 1 and IsKnown(S.MULTI_SHOT) and CooldownReady(S.MULTI_SHOT) and IsUsable(S.MULTI_SHOT) and manaPct >= 53 and targetHP >= 30 then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.MULTI_SHOT, "MULTI WEAVE", "CTRL", "Dopo Auto Shot; mana sano | " .. context, 72 - riskPenalty, "weave")
        end
        if IsKnown(S.ARCANE_SHOT) and CooldownReady(S.ARCANE_SHOT) and IsUsable(S.ARCANE_SHOT) then
            local finisher = targetHP <= 28 and manaPct >= 32
            local filler = not IsKnown(S.AIMED_SHOT) and manaPct >= 48 and targetHP >= 25
            local hardBurst = tough and manaPct >= 70 and (not estimatedTTK or estimatedTTK >= 5)
            if finisher or filler or hardBurst then
                local key = IsKnown(S.AIMED_SHOT) and "CAST MANUALE" or "ALT+SHIFT"
                local score = finisher and 84 or (hardBurst and 66 or 61)
                score = score - (finisher and riskPenalty * 0.25 or riskPenalty)
                HCOB_AdvisorEngine.AddCandidate(candidates, S.ARCANE_SHOT, "ARCANE SHOT", key,
                    (finisher and "Finisher senza fermare Auto Shot" or "Burst tra gli Auto") .. " | " .. context, score, finisher and "finisher" or "burst")
            end
        end
    end

    if inCombat and canShoot and targetHP >= 68 and IsKnown(S.RAPID_FIRE) and CooldownReady(S.RAPID_FIRE) and IsUsable(S.RAPID_FIRE) and (tough or classification == "rare") then
        local longEnough = not estimatedTTK or estimatedTTK >= 12
        if longEnough then HCOB_AdvisorEngine.AddCandidate(candidates, S.RAPID_FIRE, "RAPID FIRE", "CAST MANUALE", "Target lungo: massimizza Auto Shot | " .. context, 69 - riskPenalty, "burst") end
    end

    return HCOB_AdvisorEngine.SelectCandidate(candidates)
end


function HCOB_AdvisorEngine.WarriorRecommendation(inCombat, hostile, targetHP, spec)
    local candidates = {}
    if not inCombat or not hostile then return HCOB_AdvisorEngine.SelectCandidate(candidates) end

    local pType = UnitPowerType("player")
    local rage = UnitPower("player", pType) or 0
    local hp = UnitHealthPct("player")
    local enemies = CountActiveEnemies()
    local level = PlayerLevel()
    local targetLevel = tonumber(UnitLevel("target")) or level
    local classification = UnitClassification("target") or "normal"
    local tough = classification == "elite" or classification == "rareelite" or classification == "worldboss" or targetLevel >= level
    local elapsed = currentFight and math.max(0, GetTime() - (currentFight.startClock or GetTime())) or 0
    local reserve, reserveLabel = HCOB_AdvisorEngine.SurvivalReserve()
    local dyn = HCOB_AdvisorEngine.RollingDynamics(targetHP)
    local estimatedTTK = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local riskPenalty = reserve < 55 and ((55 - reserve) * 0.55) or 0
    if reserve < 35 then riskPenalty = riskPenalty + 8 end
    local context = string.format("rage %d | reserve %.0f %s", rage, reserve, reserveLabel)
    if estimatedTTK and estimatedTTK < math.huge then context = context .. string.format(" | TTK ~%.0fs", estimatedTTK) end

    -- Proactive survival before the global HP panic threshold.  These actions
    -- only compete when the reserve is already poor; normal DPS never burns a
    -- major defensive just because it is off cooldown.
    if reserve <= 28 and hp <= 52 and IsKnown(S.SHIELD_WALL) and CooldownReady(S.SHIELD_WALL) and IsUsable(S.SHIELD_WALL) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.SHIELD_WALL, "SHIELD WALL", "CAST MANUALE", "Survival reserve critica | " .. context, 108, "survival")
    end
    if reserve <= 38 and targetHP > 25 and IsKnown(S.HAMSTRING) and IsUsable(S.HAMSTRING) and not HasMyTargetDebuff(S.HAMSTRING) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.HAMSTRING, "HAMSTRING + DISTANZA", "ALT", "Riserva bassa: prepara una via di fuga | " .. context, 94, "survival")
    end

    if IsKnown(S.EXECUTE) and targetHP <= 20 and IsUsable(S.EXECUTE) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.EXECUTE, "EXECUTE!", "CAST MANUALE", "Target <=20% | " .. context, 115, "finisher")
    end
    if IsKnown(S.OVERPOWER) and IsUsable(S.OVERPOWER) and CooldownReady(S.OVERPOWER) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.OVERPOWER, "OVERPOWER!", "CAST MANUALE", "Finestra reattiva disponibile | " .. context, 108, "proc")
    end

    -- Core strike: high priority, but still scored so an Execute/Overpower or
    -- genuine survival action can beat it cleanly.
    if IsKnown(S.MORTAL_STRIKE) and CooldownReady(S.MORTAL_STRIKE) and IsUsable(S.MORTAL_STRIKE) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.MORTAL_STRIKE, "MORTAL STRIKE", "CAST MANUALE", "Core single target | " .. context, 96 - riskPenalty * 0.15, "core")
    end
    if IsKnown(S.BLOODTHIRST) and CooldownReady(S.BLOODTHIRST) and IsUsable(S.BLOODTHIRST) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.BLOODTHIRST, "BLOODTHIRST", "CAST MANUALE", "Core single target | " .. context, 95 - riskPenalty * 0.15, "core")
    end
    if enemies >= 2 and IsKnown(S.WHIRLWIND) and CooldownReady(S.WHIRLWIND) and IsUsable(S.WHIRLWIND) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.WHIRLWIND, "WHIRLWIND", "CAST MANUALE", enemies .. " nemici | " .. context, 91 - riskPenalty * 0.2, "aoe")
    end

    -- Mitigation can be worth more than another rage dump on a hard/long mob.
    if tough and reserve < 58 and targetHP >= 45 and IsKnown(S.THUNDER_CLAP) and CooldownReady(S.THUNDER_CLAP) and IsUsable(S.THUNDER_CLAP) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.THUNDER_CLAP, "THUNDER CLAP", "CTRL", "Riduci pressione melee sul fight duro | " .. context, 79 + (55 - math.min(55, reserve)) * 0.25, "mitigation")
    end
    if tough and targetHP >= 50 and IsKnown(S.DEMO_SHOUT) and IsUsable(S.DEMO_SHOUT) and not HasMyTargetDebuff(S.DEMO_SHOUT) then
        local longEnough = not estimatedTTK or estimatedTTK >= 11
        if longEnough then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.DEMO_SHOUT, "DEMO SHOUT", "CAST MANUALE", "Fight lungo: riduci danno in ingresso | " .. context, 70 + (reserve < 50 and 8 or 0), "mitigation")
        end
    end

    -- Battle Shout only if there is enough fight left to repay rage/GCD.
    if IsKnown(S.BATTLE_SHOUT) and not HasPlayerBuff(S.BATTLE_SHOUT) and IsUsable(S.BATTLE_SHOUT) and rage >= 10 and targetHP >= 55 then
        local worth = estimatedTTK and estimatedTTK >= 10 or (not estimatedTTK and targetHP >= 68)
        if worth then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.BATTLE_SHOUT, "BATTLE SHOUT", "SHIFT", "Buff AP con fight ancora lungo | " .. context, 65 - riskPenalty * 0.25, "buff")
        end
    end

    if IsKnown(S.REND) and level <= 35 and not currentWarriorAutoRend and not HasMyTargetDebuff(S.REND) and IsUsable(S.REND) then
        local worthRend = tough or targetLevel <= 0 or targetLevel >= (level - 4)
        if estimatedTTK then worthRend = estimatedTTK >= 8.0 end
        if elapsed > 7.0 then worthRend = false end
        if targetHP >= 45 and worthRend then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.REND, "REND", "CAST MANUALE", "DoT early con tempo per tickare | " .. context, 69 - riskPenalty * 0.4, "dot")
        end
    end

    if HCOB_DB.warriorSunderBase ~= false and IsKnown(S.SUNDER_ARMOR) and IsUsable(S.SUNDER_ARMOR) and not HasMyTargetDebuff(S.SUNDER_ARMOR) then
        local levelWindow = level >= 22 and level <= 35 and targetLevel >= level
        local longEnough = estimatedTTK and estimatedTTK >= 13 or (not estimatedTTK and targetHP >= 72)
        if targetHP >= 60 and longEnough and (tough or levelWindow) then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.SUNDER_ARMOR, "SUNDER x1", "CAST MANUALE", "Armor debuff su target resistente/lungo | " .. context, 63 - riskPenalty * 0.35, "setup")
        end
    end

    if IsKnown(S.BLOODRAGE) and rage <= 10 and hp >= 85 and targetHP >= 50 and enemies <= 1 and CooldownReady(S.BLOODRAGE) and IsUsable(S.BLOODRAGE) and elapsed <= 9 then
        local longEnough = not estimatedTTK or estimatedTTK >= 7
        if longEnough and reserve >= 55 then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.BLOODRAGE, "BLOODRAGE", "ALT+CTRL", "Apertura: genera rage senza stressare la riserva | " .. context, 61, "resource")
        end
    end

    local hsThreshold = tonumber(HCOB_DB.warriorHeroicRage) or 35
    local levelDiff = targetLevel > 0 and (targetLevel - level) or 0
    if level < 20 then
        if levelDiff <= -3 then hsThreshold = math.max(25, hsThreshold - 5)
        elseif levelDiff <= -2 then hsThreshold = math.max(30, hsThreshold)
        else hsThreshold = math.max(35, hsThreshold) end
    elseif targetHP <= 35 then
        hsThreshold = math.max(25, hsThreshold - 5)
    end
    if targetHP <= 30 and not IsKnown(S.EXECUTE) then hsThreshold = math.max(20, hsThreshold - 10) end
    if reserve < 42 then hsThreshold = hsThreshold + 10 end
    if reserve >= 72 and targetHP <= 45 then hsThreshold = math.max(20, hsThreshold - 5) end

    local heroicKnown = IsKnown(S.HEROIC_STRIKE) or knownSpellNames[SpellName(S.HEROIC_STRIKE) or ""] == true
    if heroicKnown and rage >= hsThreshold and IsUsable(S.HEROIC_STRIKE) then
        local excess = math.max(0, rage - hsThreshold)
        local score = 64 + math.min(16, excess * 0.8) + (targetHP <= 30 and 8 or 0) - riskPenalty * 0.55
        HCOB_AdvisorEngine.AddCandidate(candidates, S.HEROIC_STRIKE, "HEROIC STRIKE", "ALT+SHIFT", "Rage dump: " .. rage .. " / soglia " .. hsThreshold .. " | " .. context, score, "dump")
    end

    return HCOB_AdvisorEngine.SelectCandidate(candidates)
end

function HCOB_AdvisorEngine.MageRecommendation(inCombat, hostile, targetHP, spec)
    local candidates = {}
    local manaPct = Mage.ManaPct()
    local hp = UnitHealthPct("player")
    local level = PlayerLevel()
    local targetLevel = hostile and (UnitLevel("target") or level) or level
    local classification = hostile and (UnitClassification("target") or "normal") or "normal"
    local tough = hostile and (classification == "elite" or classification == "rareelite" or classification == "worldboss" or targetLevel >= level + 1) or false

    -- Out-of-combat candidates are scored too: low mana should beat a fancy
    -- Pyro opener, while Pyro still appears on a real hard target when ready.
    if not inCombat and manaPct <= 40 and IsKnown(S.EVOCATION) and CooldownReady(S.EVOCATION) and IsUsable(S.EVOCATION) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.EVOCATION, "EVOCATION", "CAST MANUALE", string.format("Mana %.0f%%: recupera prima del pull", manaPct), 96, "sustain")
    end
    if not inCombat and hostile and spec == 2 and IsKnown(S.PYROBLAST) and IsUsable(S.PYROBLAST) and tough then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.PYROBLAST, "PYRO OPENER", "CAST MANUALE", "Target resistente: apri da massima distanza", 72, "opener")
    end
    if not inCombat or not hostile then return HCOB_AdvisorEngine.SelectCandidate(candidates) end

    local close = Mage.TargetIsClose()
    local rooted = HasMyTargetDebuff(S.FROST_NOVA)
    local reserve, reserveLabel = HCOB_AdvisorEngine.SurvivalReserve()
    local dyn = HCOB_AdvisorEngine.RollingDynamics(targetHP)
    local estimatedTTK = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local riskPenalty = reserve < 55 and ((55 - reserve) * 0.65) or 0
    if reserve < 35 then riskPenalty = riskPenalty + 9 end
    local context = string.format("mana %.0f%% | reserve %.0f %s", manaPct, reserve, reserveLabel)
    if estimatedTTK and estimatedTTK < math.huge then context = context .. string.format(" | TTK ~%.0fs", estimatedTTK) end

    -- Instant kill is better than spending a major control cooldown on a mob
    -- already one global from death.
    if close and targetHP <= 35 and IsKnown(S.FIRE_BLAST) and CooldownReady(S.FIRE_BLAST) and IsUsable(S.FIRE_BLAST) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.FIRE_BLAST, "FIRE BLAST", "ALT+SHIFT", "Mob vicino e basso: chiudilo senza cast | " .. context, 108, "finisher")
    end

    if close and targetHP > 20 and not rooted and IsKnown(S.FROST_NOVA) and CooldownReady(S.FROST_NOVA) and IsUsable(S.FROST_NOVA) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.FROST_NOVA, "NOVA + DISTANZA", "CTRL", "Frost Nova R1, esci dalla melee e riprendi BASE | " .. context, 106, "survival")
    end

    local novaUnavailable = not IsKnown(S.FROST_NOVA) or not CooldownReady(S.FROST_NOVA) or not IsUsable(S.FROST_NOVA)
    if close and not rooted and (hp <= 75 or reserve < 50) and novaUnavailable and IsKnown(S.BLINK) and CooldownReady(S.BLINK) and IsUsable(S.BLINK) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.BLINK, "BLINK OUT", "ALT", "Nova non disponibile: ricrea distanza | " .. context, 100, "survival")
    end

    if reserve <= 28 and close and hp <= 48 and IsKnown(S.ICE_BLOCK) and CooldownReady(S.ICE_BLOCK) and IsUsable(S.ICE_BLOCK) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.ICE_BLOCK, "ICE BLOCK", "ALL MODS", "Riserva critica: interrompi la spirale di danno | " .. context, 112, "survival")
    end

    local blockUnavailable = not IsKnown(S.ICE_BLOCK) or not CooldownReady(S.ICE_BLOCK) or not IsUsable(S.ICE_BLOCK)
    if reserve <= 34 and IsKnown(S.COLD_SNAP) and CooldownReady(S.COLD_SNAP) and IsUsable(S.COLD_SNAP)
       and ((IsKnown(S.FROST_NOVA) and novaUnavailable) or (IsKnown(S.ICE_BLOCK) and blockUnavailable)) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.COLD_SNAP, "COLD SNAP", "CAST MANUALE", "Resetta il controllo difensivo consumato | " .. context, 101, "survival")
    end

    if IsKnown(S.ICE_BARRIER) and CooldownReady(S.ICE_BARRIER) and IsUsable(S.ICE_BARRIER) and manaPct >= 30 and targetHP >= 35 then
        local hasBarrier = HasPlayerBuff(S.ICE_BARRIER)
        if not hasBarrier then
            local score = (close or reserve < 55 or tough) and 88 or 64
            score = score - riskPenalty * 0.10
            HCOB_AdvisorEngine.AddCandidate(candidates, S.ICE_BARRIER, "ICE BARRIER", "CAST MANUALE", "Barrier assente: compra tempo e stabilita' | " .. context, score, "survival")
        end
    end

    -- Cone of Cold is a useful bridge when Nova is down: damage plus slow can
    -- buy the space needed for Blink/kiting without immediately reaching panic.
    if close and not rooted and novaUnavailable and targetHP > 28 and IsKnown(S.CONE_OF_COLD) and CooldownReady(S.CONE_OF_COLD) and IsUsable(S.CONE_OF_COLD) and manaPct >= 25 then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.CONE_OF_COLD, "CONE + KITE", "CAST MANUALE", "Nova down: slow + danno, poi crea distanza | " .. context, 91 - riskPenalty * 0.15, "control")
    end

    if close and hp <= 58 and manaPct >= 45 and IsKnown(S.MANA_SHIELD) and IsUsable(S.MANA_SHIELD)
       and novaUnavailable and (not IsKnown(S.BLINK) or not CooldownReady(S.BLINK)) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.MANA_SHIELD, "MANA SHIELD", "CAST MANUALE", "Nova/Blink non pronti: buffer temporaneo | " .. context, 93, "survival")
    end

    -- Wand is selected using mana + fight state rather than a single HP gate.
    if HasWandEquipped() and IsKnown(S.SHOOT) and not close then
        if targetHP <= 22 then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.SHOOT, "WAND FINISH", "SHIFT", "Conserva mana e avvia rigenerazione | " .. context, 82 + (manaPct <= 40 and 6 or 0), "efficiency")
        elseif manaPct <= 35 and targetHP <= 42 then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.SHOOT, "WAND / CONSERVA", "SHIFT", "Mana bassa: termina senza un altro nuke | " .. context, 79, "efficiency")
        end
    end

    if targetHP <= 18 and IsKnown(S.FIRE_BLAST) and CooldownReady(S.FIRE_BLAST) and IsUsable(S.FIRE_BLAST) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.FIRE_BLAST, "FIRE BLAST", "ALT+SHIFT", "Finisher istantaneo | " .. context, 88 - riskPenalty * 0.1, "finisher")
    end

    return HCOB_AdvisorEngine.SelectCandidate(candidates)
end

function HCOB_AdvisorEngine.WarlockRecommendation(inCombat, hostile, targetHP, spec)
    local candidates = {}
    local manaPct = HCOB_AdvisorEngine.ManaPct()
    local hp = UnitHealthPct("player")
    local close = HCOB_AdvisorEngine.TargetIsClose()

    if not inCombat or not hostile then return HCOB_AdvisorEngine.SelectCandidate(candidates) end

    local reserve, reserveLabel = HCOB_AdvisorEngine.SurvivalReserve()
    local dyn = HCOB_AdvisorEngine.RollingDynamics(targetHP)
    local ttk = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local context = string.format("HP %.0f%% | mana %.0f%% | reserve %.0f %s", hp, manaPct, reserve, reserveLabel)
    if ttk and ttk < math.huge then context = context .. string.format(" | TTK ~%.0fs", ttk) end

    if close and hp <= 62 and IsKnown(S.DEATH_COIL) and CooldownReady(S.DEATH_COIL) and IsUsable(S.DEATH_COIL) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.DEATH_COIL, "DEATH COIL", "ALL MODS", "Fear istantaneo + cura: recupera spazio | " .. context, 112, "survival")
    end

    if close and targetHP > 28 and reserve <= 43 and IsKnown(S.FEAR) and IsUsable(S.FEAR) and not HasMyTargetDebuff(S.FEAR) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.FEAR, "FEAR + DISTANZA", "CTRL", "Pressione alta: controlla solo con via di fuga libera | " .. context, 101, "survival")
    end

    if hp <= 62 and targetHP > 18 and manaPct >= 18 and IsKnown(S.DRAIN_LIFE) and IsUsable(S.DRAIN_LIFE) then
        local score = 82 + math.max(0, 62 - hp) * 0.45 + (reserve < 45 and 7 or 0)
        HCOB_AdvisorEngine.AddCandidate(candidates, S.DRAIN_LIFE, "DRAIN LIFE", "ALT", "Converti mana in stabilita' senza fermare il danno | " .. context, score, "sustain")
    end

    if targetHP <= 24 and IsKnown(S.SHADOWBURN) and CooldownReady(S.SHADOWBURN) and IsUsable(S.SHADOWBURN) then
        local score = 91 + (targetHP <= 14 and 8 or 0) - (reserve < 38 and 8 or 0)
        HCOB_AdvisorEngine.AddCandidate(candidates, S.SHADOWBURN, "SHADOWBURN", "ALT+SHIFT", "Finisher rapido se la shard e' disponibile | " .. context, score, "finisher")
    end

    local corruption = HasMyTargetDebuff(S.CORRUPTION)
    if IsKnown(S.CORRUPTION) and not corruption and manaPct >= 28 and targetHP >= 42 then
        local longEnough = not ttk or ttk >= 9
        if longEnough then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.CORRUPTION, "CORRUPTION", "CAST MANUALE", "DoT efficiente se il target vive abbastanza | " .. context, 70, "dot")
        end
    end

    local agony = HasMyTargetDebuff(S.CURSE_AGONY)
    if IsKnown(S.CURSE_AGONY) and not agony and manaPct >= 38 and targetHP >= 62 then
        local longEnough = not ttk or ttk >= 16
        if longEnough and reserve >= 44 then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.CURSE_AGONY, "CURSE OF AGONY", "CAST MANUALE", "Curse lunga: vale solo su fight abbastanza lunghi | " .. context, 64, "dot")
        end
    end

    local immolate = HasMyTargetDebuff(S.IMMOLATE)
    if IsKnown(S.IMMOLATE) and not immolate and manaPct >= 48 and targetHP >= 58 then
        local longEnough = not ttk or ttk >= 11
        if longEnough and reserve >= 48 then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.IMMOLATE, "IMMOLATE", "CAST MANUALE", "Aggiungi DoT solo con mana e tempo sufficienti | " .. context, spec == 3 and 70 or 61, "dot")
        end
    end

    if manaPct <= 24 and hp >= 72 and reserve >= 58 and IsKnown(S.LIFE_TAP) and IsUsable(S.LIFE_TAP) then
        local ttdSafe = not dyn or dyn.ttd == math.huge or dyn.ttd >= 12
        if ttdSafe then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.LIFE_TAP, "LIFE TAP", "ALT+CTRL", "Mana bassa ma HP/reserve sicuri | " .. context, 67, "resource")
        end
    end

    if HasWandEquipped() and IsKnown(S.SHOOT) and not close then
        if targetHP <= 30 or manaPct <= 30 then
            local score = targetHP <= 20 and 82 or 73
            HCOB_AdvisorEngine.AddCandidate(candidates, S.SHOOT, "WAND / CONSERVA", "CAST MANUALE", "Chiudi senza altra spesa mana | " .. context, score, "efficiency")
        end
    end

    if IsKnown(S.DRAIN_SOUL) and IsUsable(S.DRAIN_SOUL) and targetHP <= 12 and reserve >= 48 then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.DRAIN_SOUL, "DRAIN SOUL", "CAST MANUALE", "Finisher per shard se il target concede esperienza | " .. context, 74, "resource")
    end

    if spec == 3 and IsKnown(S.SHADOW_BOLT) and IsUsable(S.SHADOW_BOLT) and manaPct >= 62 and reserve >= 55 and targetHP >= 35 then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.SHADOW_BOLT, "SHADOW BOLT", "CAST MANUALE", "Burst Destruction con risorse sane | " .. context, 59, "damage")
    end

    return HCOB_AdvisorEngine.SelectCandidate(candidates)
end

function HCOB_AdvisorEngine.PriestRecommendation(inCombat, hostile, targetHP, spec)
    local candidates = {}
    local manaPct = HCOB_AdvisorEngine.ManaPct()
    local hp = UnitHealthPct("player")
    local close = HCOB_AdvisorEngine.TargetIsClose()
    local shielded = HasPlayerBuff(S.POWER_WORD_SHIELD)
    local weakened = HCOB_AdvisorEngine.PlayerHasDebuff(S.WEAKENED_SOUL)

    if not inCombat and hostile and IsKnown(S.POWER_WORD_SHIELD) and not shielded and not weakened and manaPct >= 55 and IsUsable(S.POWER_WORD_SHIELD) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.POWER_WORD_SHIELD, "PRE-SHIELD", "ALT", "Assorbimento pre-pull contro target impegnativo", 72, "opener")
    end
    if not inCombat or not hostile then return HCOB_AdvisorEngine.SelectCandidate(candidates) end

    local reserve, reserveLabel = HCOB_AdvisorEngine.SurvivalReserve()
    local dyn = HCOB_AdvisorEngine.RollingDynamics(targetHP)
    local ttk = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local context = string.format("HP %.0f%% | mana %.0f%% | reserve %.0f %s", hp, manaPct, reserve, reserveLabel)
    if ttk and ttk < math.huge then context = context .. string.format(" | TTK ~%.0fs", ttk) end

    if not shielded and not weakened and IsKnown(S.POWER_WORD_SHIELD) and IsUsable(S.POWER_WORD_SHIELD) and manaPct >= 18 and (hp <= 68 or close or reserve < 48) then
        local score = 88 + (close and 9 or 0) + math.max(0, 60 - hp) * 0.35
        HCOB_AdvisorEngine.AddCandidate(candidates, S.POWER_WORD_SHIELD, "POWER WORD: SHIELD", "ALT", "Ferma pushback e compra tempo | " .. context, score, "survival")
    end

    local heal = HCOB_AdvisorEngine.PriestHealSpell(hp <= 42 or close)
    if heal and hp <= 58 and manaPct >= 18 then
        local cast = SpellCastSeconds(heal)
        local ttdSafe = not dyn or dyn.ttd == math.huge or dyn.ttd >= cast + 1.0 or shielded
        if ttdSafe then
            local score = 91 + math.max(0, 58 - hp) * 0.55 + (heal == S.FLASH_HEAL and hp <= 42 and 7 or 0)
            HCOB_AdvisorEngine.AddCandidate(candidates, heal, SpellName(heal, "HEAL"), "CAST MANUALE", "Recupera HP prima che il trend diventi critico | " .. context, score, "survival")
        end
    end

    local renew = HasPlayerBuff(S.RENEW)
    if IsKnown(S.RENEW) and not renew and IsUsable(S.RENEW) and hp <= 76 and manaPct >= 30 and targetHP >= 30 then
        local longEnough = not ttk or ttk >= 8
        if longEnough then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.RENEW, "RENEW", "ALT+CTRL", "Healing efficiente mentre continui wand/cast | " .. context, 72 + (hp <= 60 and 8 or 0), "sustain")
        end
    end

    local pain = HasMyTargetDebuff(S.SHADOW_WORD_PAIN)
    if IsKnown(S.SHADOW_WORD_PAIN) and not pain and manaPct >= 32 and targetHP >= 48 then
        local longEnough = not ttk or ttk >= 10
        if longEnough and reserve >= 42 then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.SHADOW_WORD_PAIN, "SHADOW WORD: PAIN", "CAST MANUALE", "DoT mana-efficient su target che vivra' abbastanza | " .. context, 70, "dot")
        end
    end

    if IsKnown(S.MIND_BLAST) and CooldownReady(S.MIND_BLAST) and IsUsable(S.MIND_BLAST) and manaPct >= 48 and targetHP >= 24 and reserve >= 45 then
        local score = targetHP <= 35 and 82 or (spec == 3 and 72 or 64)
        if ttk and ttk < 5 then score = score - 12 end
        HCOB_AdvisorEngine.AddCandidate(candidates, S.MIND_BLAST, "MIND BLAST", "ALT+SHIFT", "Burst solo se non rovina l'efficienza mana | " .. context, score, "damage")
    end

    if spec == 3 and IsKnown(S.MIND_FLAY) and IsUsable(S.MIND_FLAY) and not close and manaPct >= 40 and targetHP >= 32 and reserve >= 48 then
        local longEnough = not ttk or ttk >= 5
        if longEnough then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.MIND_FLAY, "MIND FLAY", "CAST MANUALE", "Shadow filler con slow, senza overcastare | " .. context, 62, "damage")
        end
    end

    if HasWandEquipped() and IsKnown(S.SHOOT) and not close then
        if targetHP <= 48 or manaPct <= 48 then
            local score = 76 + (targetHP <= 30 and 9 or 0) + (manaPct <= 35 and 6 or 0)
            HCOB_AdvisorEngine.AddCandidate(candidates, S.SHOOT, "WAND / SPIRIT TAP", "CAST MANUALE", "Conserva mana e prepara il prossimo pull | " .. context, score, "efficiency")
        end
    end

    return HCOB_AdvisorEngine.SelectCandidate(candidates)
end

function HCOB_AdvisorEngine.RogueRecommendation(inCombat, hostile, targetHP, spec)
    local candidates = {}
    local hp = UnitHealthPct("player")
    local pType = UnitPowerType("player")
    local energy = UnitPower("player", pType) or 0
    local cp = GetComboPoints and GetComboPoints("player", "target") or 0
    local stealthed = HasPlayerBuff(S.STEALTH)

    if not inCombat and hostile then
        if not stealthed and IsKnown(S.STEALTH) and IsUsable(S.STEALTH) then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.STEALTH, "STEALTH", "SHIFT", "Pre-pull: apri con controllo e iniziativa", 84, "opener")
        elseif stealthed then
            local level = PlayerLevel()
            local targetLevel = UnitLevel("target") or level
            local classification = UnitClassification("target") or "normal"
            local tough = classification == "elite" or classification == "rareelite" or targetLevel >= level + 1
            if tough and IsKnown(S.CHEAP_SHOT) and IsUsable(S.CHEAP_SHOT) then
                HCOB_AdvisorEngine.AddCandidate(candidates, S.CHEAP_SHOT, "CHEAP SHOT", "CAST MANUALE", "Target difficile: compra tempo prima del damage race", 82, "opener")
            end
            if IsKnown(S.GARROTE) and IsUsable(S.GARROTE) then
                HCOB_AdvisorEngine.AddCandidate(candidates, S.GARROTE, "GARROTE", "CAST MANUALE", "Opener efficiente se il bleed puo' tickare", tough and 76 or 84, "opener")
            end
        end
        return HCOB_AdvisorEngine.SelectCandidate(candidates)
    end
    if not inCombat or not hostile then return HCOB_AdvisorEngine.SelectCandidate(candidates) end

    local reserve, reserveLabel = HCOB_AdvisorEngine.SurvivalReserve()
    local dyn = HCOB_AdvisorEngine.RollingDynamics(targetHP)
    local ttk = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local context = string.format("HP %.0f%% | energy %d | CP %d | reserve %.0f %s", hp, energy, cp, reserve, reserveLabel)
    if ttk and ttk < math.huge then context = context .. string.format(" | TTK ~%.0fs", ttk) end

    if hp <= 58 and targetHP > 28 and IsKnown(S.EVASION) and CooldownReady(S.EVASION) and IsUsable(S.EVASION) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.EVASION, "EVASION", "ALT+CTRL", "Riduci subito pressione melee | " .. context, 101 + math.max(0, 50-hp)*0.3, "survival")
    end

    if reserve <= 40 and targetHP > 22 and IsKnown(S.GOUGE) and CooldownReady(S.GOUGE) and IsUsable(S.GOUGE) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.GOUGE, "GOUGE + RESET", "CTRL", "Crea finestra per bandage/distanza/energia | " .. context, 96, "survival")
    end

    if cp >= 4 and reserve < 52 and IsKnown(S.KIDNEY_SHOT) and IsUsable(S.KIDNEY_SHOT) and targetHP > 28 then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.KIDNEY_SHOT, "KIDNEY SHOT", "CAST MANUALE", "Converti combo point in controllo quando il fight gira male | " .. context, 94, "control")
    end

    if IsKnown(S.EVISCERATE) and IsUsable(S.EVISCERATE) then
        if cp >= 4 then
            local score = 82 + (targetHP <= 35 and 10 or 0)
            HCOB_AdvisorEngine.AddCandidate(candidates, S.EVISCERATE, "EVISCERATE", "ALT+SHIFT", "Finisher a " .. cp .. " combo point | " .. context, score, "finisher")
        elseif cp >= 2 and targetHP <= 22 then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.EVISCERATE, "EVISCERATE", "ALT+SHIFT", "Chiudi il mob senza sprecare builder | " .. context, 88, "finisher")
        end
    end

    local snd = HasPlayerBuff(S.SLICE_DICE)
    if IsKnown(S.SLICE_DICE) and not snd and cp >= 1 and targetHP >= 45 and reserve >= 48 and IsUsable(S.SLICE_DICE) then
        local longEnough = not ttk or ttk >= 11
        if longEnough then
            local score = cp <= 2 and 75 or 68
            HCOB_AdvisorEngine.AddCandidate(candidates, S.SLICE_DICE, "SLICE AND DICE", "CAST MANUALE", "Spend 1-2 CP se l'uptime ripaga sul fight | " .. context, score, "efficiency")
        end
    end

    if spec == 2 and IsKnown(S.ADRENALINE_RUSH) and CooldownReady(S.ADRENALINE_RUSH) and IsUsable(S.ADRENALINE_RUSH) and reserve >= 60 and targetHP >= 70 then
        local longEnough = ttk and ttk >= 16
        if longEnough then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.ADRENALINE_RUSH, "ADRENALINE RUSH", "CAST MANUALE", "Cooldown DPS solo su fight abbastanza lungo | " .. context, 72, "burst")
        end
    end

    return HCOB_AdvisorEngine.SelectCandidate(candidates)
end

function HCOB_AdvisorEngine.PaladinRecommendation(inCombat, hostile, targetHP, spec)
    local candidates = {}
    local manaPct = HCOB_AdvisorEngine.ManaPct()
    local hp = UnitHealthPct("player")
    local reserve, reserveLabel = HCOB_AdvisorEngine.SurvivalReserve()
    local seal = BestPaladinSeal()

    if not inCombat then
        if IsKnown(S.BLESSING_MIGHT) and not HasPlayerBuff(S.BLESSING_MIGHT) and IsUsable(S.BLESSING_MIGHT) then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.BLESSING_MIGHT, "BLESSING OF MIGHT", "SHIFT", "Mantieni il buff prima del pull", 86, "buff")
        end
        if hostile and seal and not HasPlayerBuff(seal) and IsUsable(seal) then
            HCOB_AdvisorEngine.AddCandidate(candidates, seal, "SEAL", "CAST MANUALE", SpellName(seal) .. " coerente con la velocita' arma", 80, "buff")
        end
        return HCOB_AdvisorEngine.SelectCandidate(candidates)
    end
    if not hostile then return HCOB_AdvisorEngine.SelectCandidate(candidates) end

    local dyn = HCOB_AdvisorEngine.RollingDynamics(targetHP)
    local ttk = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local context = string.format("HP %.0f%% | mana %.0f%% | reserve %.0f %s", hp, manaPct, reserve, reserveLabel)
    if ttk and ttk < math.huge then context = context .. string.format(" | TTK ~%.0fs", ttk) end

    if reserve <= 28 and IsKnown(S.DIVINE_SHIELD) and CooldownReady(S.DIVINE_SHIELD) and IsUsable(S.DIVINE_SHIELD) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.DIVINE_SHIELD, "DIVINE SHIELD", "CAST MANUALE", "Riserva critica: immunita' e tempo per recuperare | " .. context, 114, "survival")
    elseif reserve <= 34 and IsKnown(S.DIVINE_PROTECTION) and CooldownReady(S.DIVINE_PROTECTION) and IsUsable(S.DIVINE_PROTECTION) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.DIVINE_PROTECTION, "DIVINE PROTECTION", "ALT+CTRL", "Riduci la pressione prima che sia troppo tardi | " .. context, 106, "survival")
    end

    local heal = HCOB_AdvisorEngine.PaladinHealSpell(hp <= 42)
    if heal and hp <= 62 and manaPct >= 18 then
        local cast = SpellCastSeconds(heal)
        local ttdSafe = not dyn or dyn.ttd == math.huge or dyn.ttd >= cast + 1.0
        if ttdSafe then
            local score = 92 + math.max(0, 60-hp)*0.5 + (heal == S.FLASH_LIGHT and hp <= 42 and 6 or 0)
            HCOB_AdvisorEngine.AddCandidate(candidates, heal, SpellName(heal, "HEAL"), "CAST MANUALE", "Heal prima di entrare nella fascia panic | " .. context, score, "survival")
        end
    end

    if hp <= 58 and targetHP > 28 and IsKnown(S.HAMMER_JUSTICE) and CooldownReady(S.HAMMER_JUSTICE) and IsUsable(S.HAMMER_JUSTICE) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.HAMMER_JUSTICE, "HAMMER OF JUSTICE", "ALT", "Stun per creare una finestra di heal/auto attack | " .. context, 91, "control")
    end

    if seal and not HasPlayerBuff(seal) and IsUsable(seal) then
        HCOB_AdvisorEngine.AddCandidate(candidates, seal, "SEAL", "CAST MANUALE", SpellName(seal) .. " assente | " .. context, 78, "buff")
    end

    if IsKnown(S.JUDGEMENT) and CooldownReady(S.JUDGEMENT) and IsUsable(S.JUDGEMENT) and manaPct >= 45 and reserve >= 48 then
        local longEnough = not ttk or ttk >= 6
        if longEnough then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.JUDGEMENT, "JUDGEMENT", "CAST MANUALE", "Spendi mana solo se il fight lo ripaga | " .. context, 67, "damage")
        end
    end

    local creatureTypeID = HCOB_AdvisorEngine.TargetCreatureTypeID()
    if (creatureTypeID == 3 or creatureTypeID == 6) and IsKnown(S.EXORCISM) and CooldownReady(S.EXORCISM) and IsUsable(S.EXORCISM) and manaPct >= 58 and reserve >= 52 then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.EXORCISM, "EXORCISM", "CAST MANUALE", "Undead/Demon: burst efficiente solo con mana sano | " .. context, 76, "damage")
    end

    if targetHP <= 20 and IsKnown(S.HAMMER_WRATH) and CooldownReady(S.HAMMER_WRATH) and IsUsable(S.HAMMER_WRATH) and manaPct >= 38 then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.HAMMER_WRATH, "HAMMER OF WRATH", "ALT+SHIFT", "Finisher se serve chiudere rapidamente | " .. context, 84, "finisher")
    end

    return HCOB_AdvisorEngine.SelectCandidate(candidates)
end

function HCOB_AdvisorEngine.ShamanRecommendation(inCombat, hostile, targetHP, spec)
    local candidates = {}
    local manaPct = HCOB_AdvisorEngine.ManaPct()
    local hp = UnitHealthPct("player")

    if not HasPlayerBuff(S.LIGHTNING_SHIELD) and IsKnown(S.LIGHTNING_SHIELD) and IsUsable(S.LIGHTNING_SHIELD) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.LIGHTNING_SHIELD, "LIGHTNING SHIELD", "SHIFT", "Mantieni il buff prima di spendere mana in danno", inCombat and 72 or 88, "buff")
    end
    if not inCombat or not hostile then return HCOB_AdvisorEngine.SelectCandidate(candidates) end

    local close = HCOB_AdvisorEngine.TargetIsClose()
    local reserve, reserveLabel = HCOB_AdvisorEngine.SurvivalReserve()
    local dyn = HCOB_AdvisorEngine.RollingDynamics(targetHP)
    local ttk = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local context = string.format("HP %.0f%% | mana %.0f%% | reserve %.0f %s", hp, manaPct, reserve, reserveLabel)
    if ttk and ttk < math.huge then context = context .. string.format(" | TTK ~%.0fs", ttk) end

    if hp <= 58 and IsKnown(S.HEALING_WAVE) and IsUsable(S.HEALING_WAVE) and manaPct >= 22 then
        local cast = SpellCastSeconds(S.HEALING_WAVE)
        local ttdSafe = not dyn or dyn.ttd == math.huge or dyn.ttd >= cast + 1.0 or HCOB_AdvisorEngine.TotemActive(S.STONECLAW_TOTEM)
        if ttdSafe then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.HEALING_WAVE, "HEALING WAVE", "ALT+CTRL", "Stabilizza HP prima del burst | " .. context, 94 + math.max(0,55-hp)*0.45, "survival")
        end
    end

    if reserve <= 38 and IsKnown(S.STONECLAW_TOTEM) and IsUsable(S.STONECLAW_TOTEM) and not HCOB_AdvisorEngine.TotemActive(S.STONECLAW_TOTEM) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.STONECLAW_TOTEM, "STONECLAW", "ALL MODS", "Compra tempo per heal/fuga | " .. context, 108, "survival")
    end

    if close and targetHP > 25 and reserve <= 52 and IsKnown(S.EARTHBIND_TOTEM) and IsUsable(S.EARTHBIND_TOTEM) and not HCOB_AdvisorEngine.TotemActive(S.EARTHBIND_TOTEM) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.EARTHBIND_TOTEM, "EARTHBIND + KITE", "CTRL", "Slow persistente per ricreare spazio | " .. context, 94, "control")
    end

    if close and targetHP > 20 and IsKnown(S.FROST_SHOCK) and CooldownReady(S.FROST_SHOCK) and IsUsable(S.FROST_SHOCK) and manaPct >= 28 and reserve < 55 then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.FROST_SHOCK, "FROST SHOCK + KITE", "CAST MANUALE", "Shock difensivo: slow e crea distanza | " .. context, 91, "control")
    end

    local flame = HasMyTargetDebuff(S.FLAME_SHOCK)
    if IsKnown(S.FLAME_SHOCK) and not flame and manaPct >= 42 and targetHP >= 50 and reserve >= 45 then
        local longEnough = not ttk or ttk >= 10
        if longEnough then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.FLAME_SHOCK, "FLAME SHOCK", "CAST MANUALE", "DoT solo se puo' tickare abbastanza | " .. context, 68, "dot")
        end
    end

    if spec == 2 and IsKnown(S.STORMSTRIKE) and CooldownReady(S.STORMSTRIKE) and IsUsable(S.STORMSTRIKE) and reserve >= 45 then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.STORMSTRIKE, "STORMSTRIKE", "ALT+SHIFT", "Core Enhancement quando la riserva e' sana | " .. context, 82, "damage")
    end

    if targetHP <= 24 and IsKnown(S.EARTH_SHOCK) and CooldownReady(S.EARTH_SHOCK) and IsUsable(S.EARTH_SHOCK) and manaPct >= 28 then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.EARTH_SHOCK, "EARTH SHOCK", "CTRL+SHIFT", "Finisher istantaneo | " .. context, 88, "finisher")
    elseif IsKnown(S.EARTH_SHOCK) and CooldownReady(S.EARTH_SHOCK) and IsUsable(S.EARTH_SHOCK) and manaPct >= 68 and reserve >= 62 and targetHP >= 35 then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.EARTH_SHOCK, "EARTH SHOCK", "CAST MANUALE", "Burst solo con mana abbondante; conserva lo shock se il mob casta | " .. context, 60, "damage")
    end

    if IsKnown(S.SEARING_TOTEM) and IsUsable(S.SEARING_TOTEM) and not HCOB_AdvisorEngine.TotemActive(S.SEARING_TOTEM) and manaPct >= 52 and reserve >= 52 and targetHP >= 62 then
        local longEnough = not ttk or ttk >= 14
        if longEnough then
            HCOB_AdvisorEngine.AddCandidate(candidates, S.SEARING_TOTEM, "SEARING TOTEM", "CAST MANUALE", "Totem efficiente solo se resta attivo abbastanza | " .. context, 61, "efficiency")
        end
    end

    if reserve <= 30 and not close and HCOB_AdvisorEngine.TotemActive(S.STONECLAW_TOTEM) and IsKnown(S.GHOST_WOLF) and IsUsable(S.GHOST_WOLF) then
        HCOB_AdvisorEngine.AddCandidate(candidates, S.GHOST_WOLF, "GHOST WOLF + RUN", "ALT", "Stoneclaw ti ha comprato spazio: allunga il leash | " .. context, 96, "survival")
    end

    return HCOB_AdvisorEngine.SelectCandidate(candidates)
end

function HCOB_AdvisorEngine.DebugPrint()
    local reserve, label = HCOB_AdvisorEngine.SurvivalReserve()
    local dyn = HCOB_AdvisorEngine.lastDynamics
    print(string.format("|cff00ff98HCOB ADVISOR 2.0:|r reserve %.0f (%s) | trend=%s", reserve or 0, tostring(label), tostring(HCOB_AdvisorEngine.trendState or "none")))
    if dyn then
        local ttk = dyn.ttk == math.huge and "inf" or string.format("%.1f", dyn.ttk)
        local ttd = dyn.ttd == math.huge and "inf" or string.format("%.1f", dyn.ttd)
        print(string.format("Rolling %.1fs | TTK %s | TTD %s | confidence %.0f%% | out %.2f%%/s | in %.2f%%/s", dyn.window or 0, ttk, ttd, (dyn.confidence or 0)*100, dyn.targetRate or 0, dyn.incomingPctRate or 0))
    else
        print("Rolling dynamics: dati insufficienti / fuori single-target combat")
    end
    local list = HCOB_AdvisorEngine.lastCandidates or {}
    for i=1, math.min(5, #list) do
        local c = list[i]
        print(string.format("  #%d %.1f | %s | %s", i, c.effectiveScore or c.score or 0, tostring(c.title or SpellName(c.id,"?")), tostring(c.tag or "action")))
    end
end

local function ActiveTargetCast()
    if not activeTargetCast then return nil end
    if activeTargetCast.guid ~= UnitGUID("target") or GetTime() > activeTargetCast.expires then
        activeTargetCast = nil
        return nil
    end
    return activeTargetCast
end

local function PlayAlert(kind)
    if not HCOB_DB.soundAlerts or not PlaySound then return end
    local now = GetTime()
    if kind == "danger" then
        if now - lastDangerSound < 8 then return end
        lastDangerSound = now
    elseif kind == "interrupt" then
        if now - lastInterruptSound < 2 then return end
        lastInterruptSound = now
    end
    local kit = SOUNDKIT and (SOUNDKIT.RAID_WARNING or SOUNDKIT.ALARM_CLOCK_WARNING_3)
    if kit then pcall(PlaySound, kit, "Master") end
end

local function InterruptRecommendation()
    if PLAYER_CLASS == "WARRIOR" then
        if IsKnown(S.PUMMEL) and CooldownReady(S.PUMMEL) then return S.PUMMEL, "INTERRUPT!", "CTRL+SHIFT", "Pummel" end
        if IsKnown(S.SHIELD_BASH) and CooldownReady(S.SHIELD_BASH) then return S.SHIELD_BASH, "INTERRUPT!", "CTRL+SHIFT", "Shield Bash" end
    elseif PLAYER_CLASS == "PALADIN" then
        if IsKnown(S.HAMMER_JUSTICE) and CooldownReady(S.HAMMER_JUSTICE) then return S.HAMMER_JUSTICE, "STOP CAST", "CTRL+SHIFT", "Stun (se possibile)" end
    elseif PLAYER_CLASS == "HUNTER" then
        if IsKnown(S.INTIMIDATION) and HCOB_Hunter.PetAlive() and CooldownReady(S.INTIMIDATION) and IsUsable(S.INTIMIDATION) then
            return S.INTIMIDATION, "INTERRUPT!", "CAST MANUALE", "Intimidation: pet stun"
        end
        if IsKnown(S.SCATTER_SHOT) and CooldownReady(S.SCATTER_SHOT) and IsUsable(S.SCATTER_SHOT) then return S.SCATTER_SHOT, "INTERRUPT!", "CTRL+SHIFT", "Scatter Shot" end
    elseif PLAYER_CLASS == "ROGUE" then
        if IsKnown(S.KICK) and CooldownReady(S.KICK) then return S.KICK, "INTERRUPT!", "CTRL+SHIFT", "Kick" end
    elseif PLAYER_CLASS == "PRIEST" then
        if IsKnown(S.SILENCE) and CooldownReady(S.SILENCE) then return S.SILENCE, "SILENCE!", "CTRL+SHIFT", "Silence" end
    elseif PLAYER_CLASS == "MAGE" then
        if IsKnown(S.COUNTERSPELL) and CooldownReady(S.COUNTERSPELL) then return S.COUNTERSPELL, "INTERRUPT!", "CTRL+SHIFT", "Counterspell" end
    elseif PLAYER_CLASS == "WARLOCK" then
        if PetHasSpell(S.SPELL_LOCK) then return S.SPELL_LOCK, "SPELL LOCK!", "CTRL+SHIFT", "Felhunter" end
    elseif PLAYER_CLASS == "DRUID" then
        if IsKnown(S.FERAL_CHARGE) and CooldownReady(S.FERAL_CHARGE) then return S.FERAL_CHARGE, "STOP CAST", "CTRL+SHIFT", "Feral Charge" end
        if IsKnown(S.BASH) and CooldownReady(S.BASH) then return S.BASH, "STOP CAST", "CTRL+SHIFT", "Bash" end
    elseif PLAYER_CLASS == "SHAMAN" then
        if IsKnown(S.EARTH_SHOCK) and CooldownReady(S.EARTH_SHOCK) then return S.EARTH_SHOCK, "INTERRUPT!", "CTRL+SHIFT", "Earth Shock" end
    end
end

local function PanicRecommendation()
    if PLAYER_CLASS == "WARRIOR" then
        if IsKnown(S.SHIELD_WALL) and CooldownReady(S.SHIELD_WALL) and IsUsable(S.SHIELD_WALL) then return S.SHIELD_WALL, "SHIELD WALL", "CAST MANUALE", "Riduci subito il danno in ingresso" end
        if IsKnown(S.RETALIATION) and CooldownReady(S.RETALIATION) and IsUsable(S.RETALIATION) then return S.RETALIATION, "PANIC", "ALL MODS", "Retaliation" end
        if IsKnown(S.HAMSTRING) and IsUsable(S.HAMSTRING) and not HasMyTargetDebuff(S.HAMSTRING) then return S.HAMSTRING, "RUN!", "ALT", "Hamstring e crea distanza" end
        return nil, "RUN!", "PREPARA FUGA", "Nessun difensivo Warrior immediato disponibile"
    elseif PLAYER_CLASS == "PALADIN" then
        local hp = UnitHealthPct("player")
        if hp <= 18 and IsKnown(S.LAY_ON_HANDS) and CooldownReady(S.LAY_ON_HANDS) and IsUsable(S.LAY_ON_HANDS) then return S.LAY_ON_HANDS, "LAY ON HANDS", "ALL MODS", "Emergenza estrema: recupera subito HP" end
        if IsKnown(S.DIVINE_SHIELD) and CooldownReady(S.DIVINE_SHIELD) and IsUsable(S.DIVINE_SHIELD) then return S.DIVINE_SHIELD, "DIVINE SHIELD", "CAST MANUALE", "Immunita': crea tempo per heal/fuga" end
        if IsKnown(S.DIVINE_PROTECTION) and CooldownReady(S.DIVINE_PROTECTION) and IsUsable(S.DIVINE_PROTECTION) then return S.DIVINE_PROTECTION, "DIVINE PROTECTION", "ALT+CTRL", "Riduci pressione e prepara heal/fuga" end
        if IsKnown(S.LAY_ON_HANDS) and CooldownReady(S.LAY_ON_HANDS) and IsUsable(S.LAY_ON_HANDS) then return S.LAY_ON_HANDS, "LAY ON HANDS", "ALL MODS", "Ultima risorsa immediata" end
        local heal = HCOB_AdvisorEngine.PaladinHealSpell(true)
        if heal then return heal, SpellName(heal,"HEAL"), "CAST MANUALE", "Nessun immunita' pronta: prova a stabilizzare" end
        return nil, "RUN!", "PREPARA FUGA", "Nessun difensivo Paladin immediato disponibile"
    elseif PLAYER_CLASS == "HUNTER" then
        if IsKnown(S.FEIGN_DEATH) and CooldownReady(S.FEIGN_DEATH) and IsUsable(S.FEIGN_DEATH) then
            return S.FEIGN_DEATH, "FEIGN DEATH", "CTRL+ALT+SHIFT", "Pet passive+follow, poi Feign: non lasciare il pet a tenerti in combat"
        end
        if HCOB_Hunter.TargetIsClose() and IsKnown(S.WING_CLIP) and IsUsable(S.WING_CLIP) and not HasMyTargetDebuff(S.WING_CLIP) then
            return S.WING_CLIP, "WING CLIP + RUN", "ALT", "Feign non disponibile: slow e crea distanza"
        end
        if IsKnown(S.SCATTER_SHOT) and CooldownReady(S.SCATTER_SHOT) and IsUsable(S.SCATTER_SHOT) then
            return S.SCATTER_SHOT, "SCATTER + RUN", "CTRL+SHIFT", "Controlla il target e crea distanza"
        end
        if IsKnown(S.CONCUSSIVE_SHOT) and CooldownReady(S.CONCUSSIVE_SHOT) and IsUsable(S.CONCUSSIVE_SHOT) then
            return S.CONCUSSIVE_SHOT, "CONCUSSIVE + RUN", "CTRL+SHIFT", "Rallenta e allunga il leash"
        end
        return nil, "RUN!", "PREPARA FUGA", "Nessun reset Hunter immediato disponibile"
    elseif PLAYER_CLASS == "ROGUE" then
        if IsKnown(S.VANISH) and CooldownReady(S.VANISH) and IsUsable(S.VANISH) then return S.VANISH, "VANISH", "ALL MODS", "Reset / fuga: usalo dopo uno swing o con un minimo di spazio" end
        if IsKnown(S.EVASION) and CooldownReady(S.EVASION) and IsUsable(S.EVASION) then return S.EVASION, "EVASION", "ALT+CTRL", "Riduci pressione melee mentre prepari uscita" end
        if IsKnown(S.GOUGE) and CooldownReady(S.GOUGE) and IsUsable(S.GOUGE) then return S.GOUGE, "GOUGE + RUN", "CTRL", "Crea finestra per bandage/distanza" end
        if IsKnown(S.SPRINT) and CooldownReady(S.SPRINT) and IsUsable(S.SPRINT) then return S.SPRINT, "SPRINT + RUN", "ALT", "Allunga il leash" end
        return nil, "RUN!", "PREPARA FUGA", "Vanish/Evasion non disponibili"
    elseif PLAYER_CLASS == "PRIEST" then
        if IsKnown(S.PSYCHIC_SCREAM) and CooldownReady(S.PSYCHIC_SCREAM) and IsUsable(S.PSYCHIC_SCREAM) then return S.PSYCHIC_SCREAM, "PSYCHIC SCREAM", "ALL MODS", "Crea distanza; attenzione a non fearare verso altri pack" end
        if IsKnown(S.POWER_WORD_SHIELD) and IsUsable(S.POWER_WORD_SHIELD) and not HCOB_AdvisorEngine.PlayerHasDebuff(S.WEAKENED_SOUL) then return S.POWER_WORD_SHIELD, "POWER WORD: SHIELD", "ALT", "Compra tempo per heal/fuga" end
        local heal = HCOB_AdvisorEngine.PriestHealSpell(true)
        if heal then return heal, SpellName(heal,"HEAL"), "CAST MANUALE", "Nessun controllo pronto: stabilizza HP" end
        return nil, "RUN!", "PREPARA FUGA", "Scream/Shield/heal non disponibili"
    elseif PLAYER_CLASS == "MAGE" then
        if IsKnown(S.ICE_BLOCK) and CooldownReady(S.ICE_BLOCK) and IsUsable(S.ICE_BLOCK) then
            return S.ICE_BLOCK, "ICE BLOCK", "ALL MODS", "Emergenza: immunita' e reset mentale"
        end
        if IsKnown(S.FROST_NOVA) and CooldownReady(S.FROST_NOVA) and IsUsable(S.FROST_NOVA) then
            return S.FROST_NOVA, "NOVA + RUN", "CTRL", "Root rank 1 e crea subito distanza"
        end
        if IsKnown(S.COLD_SNAP) and CooldownReady(S.COLD_SNAP) and IsUsable(S.COLD_SNAP)
           and (IsKnown(S.FROST_NOVA) or IsKnown(S.ICE_BLOCK)) then
            return S.COLD_SNAP, "COLD SNAP", "CAST MANUALE", "Resetta Nova/Block, poi usa subito il controllo necessario"
        end
        if IsKnown(S.BLINK) and CooldownReady(S.BLINK) and IsUsable(S.BLINK) then
            return S.BLINK, "BLINK OUT", "ALT", "Nova non pronta: crea distanza ora"
        end
        if IsKnown(S.MANA_SHIELD) and IsUsable(S.MANA_SHIELD) and Mage.ManaPct() >= 25 then
            return S.MANA_SHIELD, "MANA SHIELD", "ALL MODS", "Ultimo buffer prima della fuga"
        end
        return nil, "RUN!", "PREPARA FUGA", "Nessun cooldown Mage immediato disponibile"
    elseif PLAYER_CLASS == "WARLOCK" then
        if IsKnown(S.DEATH_COIL) and CooldownReady(S.DEATH_COIL) and IsUsable(S.DEATH_COIL) then return S.DEATH_COIL, "DEATH COIL", "ALL MODS", "Fear istantaneo + cura: crea distanza" end
        if IsKnown(S.FEAR) and IsUsable(S.FEAR) then return S.FEAR, "FEAR + RUN", "CTRL", "Crea distanza solo con via di fuga libera" end
        if IsKnown(S.DRAIN_LIFE) and IsUsable(S.DRAIN_LIFE) then return S.DRAIN_LIFE, "DRAIN LIFE", "ALT", "Nessun CC pronto: recupera HP mentre fai danno" end
        return nil, "RUN!", "PREPARA FUGA", "Death Coil/Fear non disponibili"
    elseif PLAYER_CLASS == "DRUID" then
        if IsKnown(S.NATURES_GRASP) then return S.NATURES_GRASP, "GRASP", "ALL MODS", "Root difensivo" end
        return S.BARKSKIN, "BARKSKIN", "ALT+CTRL", "Riduci danno"
    elseif PLAYER_CLASS == "SHAMAN" then
        if IsKnown(S.STONECLAW_TOTEM) and IsUsable(S.STONECLAW_TOTEM) and not HCOB_AdvisorEngine.TotemActive(S.STONECLAW_TOTEM) then return S.STONECLAW_TOTEM, "STONECLAW", "ALL MODS", "Crea spazio per heal/fuga" end
        if IsKnown(S.EARTHBIND_TOTEM) and IsUsable(S.EARTHBIND_TOTEM) and not HCOB_AdvisorEngine.TotemActive(S.EARTHBIND_TOTEM) then return S.EARTHBIND_TOTEM, "EARTHBIND", "CTRL", "Slow e allunga il leash" end
        if IsKnown(S.HEALING_WAVE) and IsUsable(S.HEALING_WAVE) then return S.HEALING_WAVE, "HEALING WAVE", "ALT+CTRL", "Stabilizza se hai abbastanza spazio per castare" end
        if IsKnown(S.GHOST_WOLF) and IsUsable(S.GHOST_WOLF) then return S.GHOST_WOLF, "GHOST WOLF + RUN", "ALT", "Allunga il leash se non sei indoor" end
        return nil, "RUN!", "PREPARA FUGA", "Totem/heal non disponibili"
    end
end

local function BuffRecommendation(inCombat)
    if PLAYER_CLASS == "MAGE" then
        if inCombat then return nil end

        if IsKnown(S.ICE_BARRIER) and CooldownReady(S.ICE_BARRIER) and IsUsable(S.ICE_BARRIER) then
            local hasBarrier, barrierRemain = HasPlayerBuff(S.ICE_BARRIER)
            if not hasBarrier then
                return S.ICE_BARRIER, "ICE BARRIER", "CAST MANUALE", "Pre-pull: assorbimento gratuito prima del rischio"
            end
            if barrierRemain < 10 then
                return S.ICE_BARRIER, "BARRIER SOON", "CAST MANUALE", "Scade tra " .. math.floor(barrierRemain) .. "s"
            end
        end

        local armor = Mage.BestArmor()
        if armor and IsKnown(armor) then
            local hasArmor, armorRemain = HasPlayerBuff(armor)
            if not hasArmor then
                return armor, "MAGE ARMOR", "CAST MANUALE", SpellName(armor) .. " manca"
            end
            if armorRemain < 20 then
                return armor, "ARMOR SOON", "CAST MANUALE", "Scade tra " .. math.floor(armorRemain) .. "s"
            end
        end

        if IsKnown(S.ARCANE_INTELLECT) then
            local hasInt, intRemain = HasPlayerBuff(S.ARCANE_INTELLECT)
            local intKey = HostileLiveTarget() and "CAST MANUALE" or "SHIFT"
            if not hasInt then
                return S.ARCANE_INTELLECT, "ARCANE INT", intKey, "Buff intellect mancante"
            end
            if intRemain < 20 then
                return S.ARCANE_INTELLECT, "INT SOON", intKey, "Scade tra " .. math.floor(intRemain) .. "s"
            end
        end
        return nil
    end

    local id
    if PLAYER_CLASS == "WARRIOR" then id = S.BATTLE_SHOUT
    elseif PLAYER_CLASS == "PALADIN" then id = S.BLESSING_MIGHT
    elseif PLAYER_CLASS == "HUNTER" then id = S.ASPECT_HAWK
    elseif PLAYER_CLASS == "PRIEST" then id = S.FORTITUDE
    elseif PLAYER_CLASS == "WARLOCK" then id = IsKnown(S.DEMON_ARMOR) and S.DEMON_ARMOR or S.DEMON_SKIN
    elseif PLAYER_CLASS == "DRUID" then id = S.MARK_WILD
    elseif PLAYER_CLASS == "SHAMAN" then id = S.LIGHTNING_SHIELD end
    if not id or not IsKnown(id) then return nil end
    local has, remain = HasPlayerBuff(id)
    -- Warrior in combat e' gestito da ClassRecommendation, che valuta se il
    -- target vivra' abbastanza da ripagare Battle Shout. Qui evitiamo il
    -- fallback cieco che lo avrebbe comunque consigliato a fine fight.
    local allowInCombat = (PLAYER_CLASS == "SHAMAN")
    if not has and (not inCombat or allowInCombat) then
        return id, "BUFF", "SHIFT", SpellName(id) .. " manca"
    end
    if has and remain < 12 and not inCombat then
        return id, "BUFF SOON", "SHIFT", "Scade tra " .. math.floor(remain) .. "s"
    end
end

local function ClassRecommendation(inCombat, hostile, targetHP)
    local spec = TalentSpec()

    if PLAYER_CLASS == "WARRIOR" then
        return HCOB_AdvisorEngine.WarriorRecommendation(inCombat, hostile, targetHP, spec)

    elseif PLAYER_CLASS == "PALADIN" then
        return HCOB_AdvisorEngine.PaladinRecommendation(inCombat, hostile, targetHP, spec)

    elseif PLAYER_CLASS == "HUNTER" then
        return HCOB_AdvisorEngine.HunterRecommendation(inCombat, hostile, targetHP, spec)

    elseif PLAYER_CLASS == "ROGUE" then
        return HCOB_AdvisorEngine.RogueRecommendation(inCombat, hostile, targetHP, spec)

    elseif PLAYER_CLASS == "PRIEST" then
        return HCOB_AdvisorEngine.PriestRecommendation(inCombat, hostile, targetHP, spec)

    elseif PLAYER_CLASS == "MAGE" then
        return HCOB_AdvisorEngine.MageRecommendation(inCombat, hostile, targetHP, spec)

    elseif PLAYER_CLASS == "WARLOCK" then
        return HCOB_AdvisorEngine.WarlockRecommendation(inCombat, hostile, targetHP, spec)

    elseif PLAYER_CLASS == "DRUID" then
        local form = GetShapeshiftForm and GetShapeshiftForm() or 0
        if spec == 2 and form == 0 then
            if IsKnown(S.CAT_FORM) then return S.CAT_FORM,"CAT FORM","CAST MANUALE","Feral leveling" end
            if IsKnown(S.BEAR_FORM) then return S.BEAR_FORM,"BEAR FORM","CAST MANUALE","Feral leveling" end
        end
        if form == 3 then
            local cp = GetComboPoints and GetComboPoints("player", "target") or 0
            if cp >= 4 and IsKnown(S.FEROCIOUS_BITE) and IsUsable(S.FEROCIOUS_BITE) then return S.FEROCIOUS_BITE,"FEROCIOUS BITE","ALT+SHIFT",cp .. " combo points" end
            if hostile and IsKnown(S.RAKE) and targetHP >= 50 then local has=HasMyTargetDebuff(S.RAKE); if not has then return S.RAKE,"RAKE","CAST MANUALE","Bleed assente" end end
        elseif form == 1 and IsKnown(S.MAUL) then
            local pType = UnitPowerType("player")
            local rage = UnitPower("player", pType) or 0
            if rage >= 35 then return S.MAUL,"MAUL","CAST MANUALE","Rage alta: " .. rage end
        elseif form == 0 and hostile and IsKnown(S.MOONFIRE) and targetHP >= 45 then
            local has=HasMyTargetDebuff(S.MOONFIRE); if not has then return S.MOONFIRE,"MOONFIRE","CAST MANUALE","DoT assente" end
        end
        return nil

    elseif PLAYER_CLASS == "SHAMAN" then
        return HCOB_AdvisorEngine.ShamanRecommendation(inCombat, hostile, targetHP, spec)
    end
    return nil
end


-- Multi-pull Hardcore: non aspetta che gli HP arrivino alla soglia critica.
-- Con 2 mob segnala CAUTION e privilegia mitigazione/controllo; con 3+ passa
-- subito a DANGER. Le azioni restano suggerimenti: nessuna decisione protetta
-- viene presa automaticamente dall'addon.
local function MultiPullRecommendation(enemies, hp, targetHP)
    if HCOB_DB.hcDangerAdvisor == false or enemies < 2 then return nil end

    if PLAYER_CLASS == "WARRIOR" then
        if enemies >= 3 then
            if IsKnown(S.RETALIATION) and CooldownReady(S.RETALIATION) then
                return S.RETALIATION, "3+ MOBS - PANIC", "ALL MODS", "Retaliation ora; poi riduci il pull", "danger"
            end
            if IsKnown(S.THUNDER_CLAP) and CooldownReady(S.THUNDER_CLAP) and IsUsable(S.THUNDER_CLAP) then
                return S.THUNDER_CLAP, "3+ MOBS - CONTROL", "CTRL", "Thunder Clap ora; poi crea distanza", "danger"
            end
            if IsKnown(S.DEMO_SHOUT) and IsUsable(S.DEMO_SHOUT) then
                return S.DEMO_SHOUT, "3+ MOBS - DEBUFF", "CAST MANUALE", "Demoralizing Shout, poi prepara la fuga", "danger"
            end
            local id, _, key, reason = PanicRecommendation()
            return id, "3+ MOBS - ESCI", key or "ALL MODS", reason or "Crea distanza", "danger"
        end

        if hp <= 50 then
            local id, _, key, reason = PanicRecommendation()
            return id, "2 MOBS - ESCI", key or "ALL MODS", reason or "Riduci pressione", "danger"
        end

        if IsKnown(S.THUNDER_CLAP) and CooldownReady(S.THUNDER_CLAP) and IsUsable(S.THUNDER_CLAP) then
            return S.THUNDER_CLAP, "MULTI x2 - CONTROL", "CTRL", "Riduci attack speed e pressione", "caution"
        end

        if IsKnown(S.DEMO_SHOUT) and IsUsable(S.DEMO_SHOUT) then
            local hasDemo = HasMyTargetDebuff(S.DEMO_SHOUT)
            if not hasDemo then
                return S.DEMO_SHOUT, "MULTI x2 - DEBUFF", "CAST MANUALE", "Demoralizing Shout riduce il danno melee", "caution"
            end
        end

        if hp <= 68 then
            if IsKnown(S.HAMSTRING) and IsUsable(S.HAMSTRING) and not HasMyTargetDebuff(S.HAMSTRING) then
                return S.HAMSTRING, "MULTI x2 - RISCHIO", "ALT", "Hamstring e prepara una via di fuga", "danger"
            end
            return nil, "MULTI x2 - RISCHIO", "PREPARA FUGA", "Pressione alta: crea distanza", "danger"
        end
        return nil, "MULTI x2", "PREPARA FUGA", "Non aggiungere mob; controlla HP e vie di uscita", "caution"
    end

    if PLAYER_CLASS == "HUNTER" then
        local close = HCOB_Hunter.TargetIsClose()
        local manaPct = HCOB_Hunter.ManaPct()
        local petHP = HCOB_Hunter.PetHP()

        if enemies >= 3 then
            if IsKnown(S.FEIGN_DEATH) and CooldownReady(S.FEIGN_DEATH) and IsUsable(S.FEIGN_DEATH) then
                return S.FEIGN_DEATH, "3+ MOBS - FEIGN", "CTRL+ALT+SHIFT", "Pet passive+follow e resetta il pull", "danger"
            end
            if close and IsKnown(S.WING_CLIP) and IsUsable(S.WING_CLIP) and not HasMyTargetDebuff(S.WING_CLIP) then
                return S.WING_CLIP, "3+ MOBS - WING CLIP", "ALT", "Slow il target addosso e crea una via di fuga", "danger"
            end
            if IsKnown(S.SCATTER_SHOT) and CooldownReady(S.SCATTER_SHOT) and IsUsable(S.SCATTER_SHOT) then
                return S.SCATTER_SHOT, "3+ MOBS - SCATTER", "CTRL+SHIFT", "Controlla uno, allontanati, non tunnelare DPS", "danger"
            end
            return nil, "3+ MOBS - ESCI", "PREPARA FUGA", "Troppi target per un pull HC pulito", "danger"
        end

        if hp <= 50 or (petHP and petHP <= 28) then
            local id, _, key, reason = PanicRecommendation()
            return id, "2 MOBS - ESCI", key or "CTRL+ALT+SHIFT", reason or "Resetta il pull", "danger"
        end

        if close and IsKnown(S.WING_CLIP) and IsUsable(S.WING_CLIP) and not HasMyTargetDebuff(S.WING_CLIP) then
            return S.WING_CLIP, "MULTI x2 - DEAD ZONE", "ALT", "Slow, esci dalla melee e rimetti il pet davanti", "caution"
        end

        if IsKnown(S.MULTI_SHOT) and CooldownReady(S.MULTI_SHOT) and IsUsable(S.MULTI_SHOT) and manaPct >= 48 and (not petHP or petHP >= 50) and HCOB_Hunter.AfterAutoWindow() then
            return S.MULTI_SHOT, "MULTI x2 - WEAVE", "CTRL", "Solo mob gia' ingaggiati: dopo Auto Shot", "caution"
        end

        if petHP and petHP <= 45 and IsKnown(S.MEND_PET) and IsUsable(S.MEND_PET) and HCOB_Hunter.PetIsTanking() then
            return S.MEND_PET, "MULTI x2 - PET", "ALT+CTRL", string.format("Pet %.0f%%: stabilizza prima di spingere DPS", petHP), "caution"
        end

        return nil, "MULTI x2", "KITE / PET", "Mantieni entrambi davanti al pet; evita nuovi add", "caution"
    end

    if PLAYER_CLASS == "MAGE" then
        local close = Mage.TargetIsClose()
        local manaPct = Mage.ManaPct()

        if enemies >= 3 then
            if IsKnown(S.FROST_NOVA) and CooldownReady(S.FROST_NOVA) and IsUsable(S.FROST_NOVA) then
                return S.FROST_NOVA, "3+ MOBS - NOVA", "CTRL", "Frost Nova R1, gira e crea distanza", "danger"
            end
            if IsKnown(S.BLINK) and CooldownReady(S.BLINK) and IsUsable(S.BLINK) then
                return S.BLINK, "3+ MOBS - BLINK", "ALT", "Nova non pronta: esci dalla mischia", "danger"
            end
            local id, _, key, reason = PanicRecommendation()
            return id, "3+ MOBS - PANIC", key or "ALL MODS", reason or "Reset / fuga", "danger"
        end

        if hp <= 50 then
            local id, _, key, reason = PanicRecommendation()
            return id, "2 MOBS - ESCI", key or "ALL MODS", reason or "Crea distanza", "danger"
        end

        if close and IsKnown(S.FROST_NOVA) and CooldownReady(S.FROST_NOVA) and IsUsable(S.FROST_NOVA) then
            return S.FROST_NOVA, "MULTI x2 - NOVA", "CTRL", "Root R1, allontanati e separa il pull", "caution"
        end

        -- Polymorph is the preferred 2-mob reset when you still have space.
        -- Creature eligibility varies, so the Advisor explicitly says "se valido";
        -- a failed Polymorph does not trigger any automation or retargeting.
        if IsKnown(S.POLYMORPH) and Mage.PolymorphEligible() and not HasMyTargetDebuff(S.POLYMORPH) then
            return S.POLYMORPH, "MULTI x2 - POLY", "ALT+CTRL", "Polymorph questo target, poi passa all'altro mob", "caution"
        end

        if hp <= 68 and IsKnown(S.BLINK) and CooldownReady(S.BLINK) and IsUsable(S.BLINK) then
            return S.BLINK, "MULTI x2 - SPAZIO", "ALT", "Pressione alta: crea distanza prima di perdere controllo", "danger"
        end

        if manaPct <= 30 then
            return nil, "MULTI x2 - MANA", "PREPARA FUGA", string.format("Solo %.0f%% mana: non trasformare il pull in una gara DPS", manaPct), "caution"
        end

        return nil, "MULTI x2", "KITE / POLY", "Mantieni distanza; non aggiungere un terzo mob", "caution"
    end

    if PLAYER_CLASS == "ROGUE" then
        if enemies >= 3 or hp <= 48 then
            local id, _, key, reason = PanicRecommendation()
            return id, enemies >= 3 and "3+ MOBS - VANISH" or "MULTI - ESCI", key or "ALL MODS", reason or "Resetta il pull", "danger"
        end
        if IsKnown(S.BLADE_FLURRY) and CooldownReady(S.BLADE_FLURRY) and IsUsable(S.BLADE_FLURRY) and hp >= 68 then
            return S.BLADE_FLURRY, "MULTI x2 - BLADE FLURRY", "CAST MANUALE", "Solo se il pull e' gia' stabile; non aggiungere altri mob", "caution"
        end
        if IsKnown(S.EVASION) and CooldownReady(S.EVASION) and IsUsable(S.EVASION) and hp <= 65 then
            return S.EVASION, "MULTI x2 - EVASION", "ALT+CTRL", "Riduci pressione e prepara Vanish se peggiora", "caution"
        end
        return nil, "MULTI x2", "CONTROL / EXIT", "Non greedare DPS senza Vanish disponibile", "caution"
    end

    if PLAYER_CLASS == "PALADIN" then
        local manaPct = HCOB_AdvisorEngine.ManaPct()
        if enemies >= 3 or hp <= 45 then
            local id, _, key, reason = PanicRecommendation()
            return id, enemies >= 3 and "3+ MOBS - BUBBLE" or "MULTI - STABILIZZA", key or "ALL MODS", reason or "Bubble/heal/fuga", "danger"
        end
        if IsKnown(S.CONSECRATION) and CooldownReady(S.CONSECRATION) and IsUsable(S.CONSECRATION) and manaPct >= 58 and hp >= 70 then
            return S.CONSECRATION, "MULTI x2 - CONSECRATION", "CTRL", "Solo pull stabile: spendi mana per chiudere entrambi", "caution"
        end
        if IsKnown(S.HAMMER_JUSTICE) and CooldownReady(S.HAMMER_JUSTICE) and IsUsable(S.HAMMER_JUSTICE) and hp <= 68 then
            return S.HAMMER_JUSTICE, "MULTI x2 - STUN", "ALT", "Stunna uno e riduci il danno in ingresso", "caution"
        end
        return nil, "MULTI x2", "AUTO / CONSERVA", "Mantieni seal e mana per heal/bubble", "caution"
    end

    if PLAYER_CLASS == "PRIEST" then
        if enemies >= 3 or hp <= 48 then
            local id, _, key, reason = PanicRecommendation()
            return id, enemies >= 3 and "3+ MOBS - ESCI" or "MULTI - STABILIZZA", key or "ALL MODS", reason or "Shield/Scream/fuga", "danger"
        end
        if IsKnown(S.POWER_WORD_SHIELD) and IsUsable(S.POWER_WORD_SHIELD) and not HasPlayerBuff(S.POWER_WORD_SHIELD) and not HCOB_AdvisorEngine.PlayerHasDebuff(S.WEAKENED_SOUL) then
            return S.POWER_WORD_SHIELD, "MULTI x2 - SHIELD", "ALT", "Compra tempo; evita di trasformare il pull in spam mana", "caution"
        end
        if IsKnown(S.PSYCHIC_SCREAM) and CooldownReady(S.PSYCHIC_SCREAM) and IsUsable(S.PSYCHIC_SCREAM) and hp <= 62 then
            return S.PSYCHIC_SCREAM, "MULTI x2 - SCREAM", "ALL MODS", "Usalo solo se il fear non puo' trascinare altri pack", "caution"
        end
        return nil, "MULTI x2", "WAND / CONTROL", "Conserva mana e una via di fuga", "caution"
    end

    if PLAYER_CLASS == "WARLOCK" then
        local petHP = HCOB_AdvisorEngine.PetHP()
        if enemies >= 3 or hp <= 46 or (petHP > 0 and petHP <= 25) then
            local id, _, key, reason = PanicRecommendation()
            return id, enemies >= 3 and "3+ MOBS - ESCI" or "MULTI - RESET", key or "ALL MODS", reason or "Controlla e crea distanza", "danger"
        end
        if HCOB_AdvisorEngine.TargetIsClose() and IsKnown(S.DEATH_COIL) and CooldownReady(S.DEATH_COIL) and IsUsable(S.DEATH_COIL) then
            return S.DEATH_COIL, "MULTI x2 - DEATH COIL", "ALL MODS", "Togliti un mob di dosso e recupera HP", "caution"
        end
        return nil, "MULTI x2", "PET / DOT / EXIT", "Lascia tankare il pet; non usare Fear verso altri pack", "caution"
    end

    if PLAYER_CLASS == "SHAMAN" then
        if enemies >= 3 or hp <= 48 then
            local id, _, key, reason = PanicRecommendation()
            return id, enemies >= 3 and "3+ MOBS - STONECLAW" or "MULTI - ESCI", key or "ALL MODS", reason or "Totem + fuga", "danger"
        end
        if IsKnown(S.STONECLAW_TOTEM) and IsUsable(S.STONECLAW_TOTEM) and not HCOB_AdvisorEngine.TotemActive(S.STONECLAW_TOTEM) then
            return S.STONECLAW_TOTEM, "MULTI x2 - STONECLAW", "ALL MODS", "Scarica pressione prima di fare danno", "caution"
        end
        if IsKnown(S.EARTHBIND_TOTEM) and IsUsable(S.EARTHBIND_TOTEM) and not HCOB_AdvisorEngine.TotemActive(S.EARTHBIND_TOTEM) then
            return S.EARTHBIND_TOTEM, "MULTI x2 - EARTHBIND", "CTRL", "Kite e separa il pull", "caution"
        end
        return nil, "MULTI x2", "TOTEM / CONSERVA", "Mantieni mana per heal e Earth Shock interrupt", "caution"
    end

    if enemies >= 3 or hp <= 50 then
        local id, _, key, reason = PanicRecommendation()
        return id, enemies >= 3 and "3+ MOBS - PANIC" or "MULTI - ESCI",
            key or "ALL MODS", reason or "Crea distanza", "danger"
    end
    return nil, "MULTI x2", "PREPARA CONTROL", "Pull multiplo: conserva cooldown difensivi", "caution"
end

-- Stima situazionale HC usando percentuali, quindi non dipende dal fatto che
-- Classic esponga HP assoluti o normalizzati per i mob. Viene usata solo su
-- single target e dopo alcuni secondi, per evitare falsi allarmi all'apertura.
local function FightDynamics(targetHP)
    return HCOB_AdvisorEngine.RollingDynamics(targetHP)
end

local function Recommend()
    local inCombat = UnitAffectingCombat("player") and true or false
    local hostile = HostileLiveTarget()
    local hp = UnitHealthPct("player")
    local targetHP = hostile and UnitHealthPct("target") or 100
    local playerLevel = PlayerLevel()
    local targetLevel = hostile and (UnitLevel("target") or playerLevel) or playerLevel
    local classification = hostile and UnitClassification("target") or "normal"

    if inCombat and hp <= (HCOB_DB.criticalHP or 20) then
        local id, title, key, reason = PanicRecommendation()
        return id, title or "CRITICAL", key or "ALL MODS", reason or "Fuga / pozione", "danger"
    end
    if inCombat and hp <= (HCOB_DB.dangerHP or 35) then
        local id, title, key, reason = PanicRecommendation()
        return id, title or "DANGER", key or "ALL MODS", reason or "Valuta fuga", "danger"
    end

    -- Un cast interrompibile resta prioritario sui warning CAUTION: il rischio
    -- multi-pull non deve nascondere un interrupt immediato. Le soglie HP
    -- critiche sopra, invece, mantengono la precedenza assoluta.
    local cast = hostile and ActiveTargetCast() or nil
    if inCombat and cast then
        local id, title, key, reason = InterruptRecommendation()
        if id then return id, title, key, (cast.name or "Cast nemico") .. " - " .. reason, "interrupt" end
    end

    local enemies = CountActiveEnemies()
    if inCombat and enemies >= 2 and HCOB_DB.hcDangerAdvisor ~= false then
        local mid, mtitle, mkey, mreason, mkind = MultiPullRecommendation(enemies, hp, targetHP)
        if mtitle then return mid, mtitle, mkey, mreason, mkind end
    end

    -- HC fight trend single-target: CAUTION entra prima del vecchio DANGER,
    -- cosi' hai il tempo di preparare Hamstring/uscita invece di reagire a 35% HP.
    if inCombat and hostile and HCOB_DB.hcDangerAdvisor ~= false and targetHP > 20 then
        local dyn = FightDynamics(targetHP)
        if dyn and dyn.ttk < math.huge and dyn.ttd < math.huge then
            local trend = HCOB_AdvisorEngine.TrendState(dyn, hp)
            local reserve, reserveLabel = HCOB_AdvisorEngine.SurvivalReserve()
            local trendText = string.format("Tu ~%.0fs / mob ~%.0fs | conf %.0f%% | reserve %.0f %s", dyn.ttd, dyn.ttk, (dyn.confidence or 0)*100, reserve or 0, reserveLabel or "?")
            if trend == "danger" then
                local id, _, key, reason = PanicRecommendation()
                return id, "FIGHT PEGGIORA", key or "ALL MODS", trendText .. ": " .. (reason or "crea distanza"), "danger"
            elseif trend == "caution" then
                if PLAYER_CLASS == "WARRIOR" and IsKnown(S.HAMSTRING) and IsUsable(S.HAMSTRING) and not HasMyTargetDebuff(S.HAMSTRING) then
                    return S.HAMSTRING, "FIGHT SFAVOREVOLE", "ALT", trendText .. ": prepara Hamstring + distanza", "caution"
                end
                if PLAYER_CLASS == "HUNTER" then
                    if HCOB_Hunter.TargetIsClose() and IsKnown(S.WING_CLIP) and IsUsable(S.WING_CLIP) and not HasMyTargetDebuff(S.WING_CLIP) then
                        return S.WING_CLIP, "FIGHT SFAVOREVOLE", "ALT", trendText .. ": Wing Clip e torna a range", "caution"
                    end
                    if IsKnown(S.CONCUSSIVE_SHOT) and CooldownReady(S.CONCUSSIVE_SHOT) and IsUsable(S.CONCUSSIVE_SHOT) then
                        return S.CONCUSSIVE_SHOT, "FIGHT SFAVOREVOLE", "CTRL+SHIFT", trendText .. ": rallenta e lascia tankare il pet", "caution"
                    end
                elseif PLAYER_CLASS == "WARLOCK" then
                    if HCOB_AdvisorEngine.TargetIsClose() and IsKnown(S.DEATH_COIL) and CooldownReady(S.DEATH_COIL) and IsUsable(S.DEATH_COIL) then
                        return S.DEATH_COIL, "FIGHT SFAVOREVOLE", "ALL MODS", trendText .. ": Death Coil e ricrea distanza", "caution"
                    end
                    if UnitHealthPct("player") <= 62 and IsKnown(S.DRAIN_LIFE) and IsUsable(S.DRAIN_LIFE) then
                        return S.DRAIN_LIFE, "FIGHT SFAVOREVOLE", "ALT", trendText .. ": recupera HP mentre continui il fight", "caution"
                    end
                elseif PLAYER_CLASS == "PRIEST" then
                    if IsKnown(S.POWER_WORD_SHIELD) and IsUsable(S.POWER_WORD_SHIELD) and not HasPlayerBuff(S.POWER_WORD_SHIELD) and not HCOB_AdvisorEngine.PlayerHasDebuff(S.WEAKENED_SOUL) then
                        return S.POWER_WORD_SHIELD, "FIGHT SFAVOREVOLE", "ALT", trendText .. ": Shield prima che il danno acceleri", "caution"
                    end
                    local heal = HCOB_AdvisorEngine.PriestHealSpell(UnitHealthPct("player") <= 45)
                    if heal and UnitHealthPct("player") <= 58 then return heal, "FIGHT SFAVOREVOLE", "CAST MANUALE", trendText .. ": stabilizza HP", "caution" end
                elseif PLAYER_CLASS == "ROGUE" then
                    if IsKnown(S.EVASION) and CooldownReady(S.EVASION) and IsUsable(S.EVASION) then return S.EVASION, "FIGHT SFAVOREVOLE", "ALT+CTRL", trendText .. ": Evasion e prepara Vanish", "caution" end
                    if IsKnown(S.GOUGE) and CooldownReady(S.GOUGE) and IsUsable(S.GOUGE) then return S.GOUGE, "FIGHT SFAVOREVOLE", "CTRL", trendText .. ": Gouge per creare una finestra", "caution" end
                elseif PLAYER_CLASS == "PALADIN" then
                    local heal = HCOB_AdvisorEngine.PaladinHealSpell(UnitHealthPct("player") <= 45)
                    if heal and UnitHealthPct("player") <= 62 then return heal, "FIGHT SFAVOREVOLE", "CAST MANUALE", trendText .. ": heal prima del panic", "caution" end
                    if IsKnown(S.HAMMER_JUSTICE) and CooldownReady(S.HAMMER_JUSTICE) and IsUsable(S.HAMMER_JUSTICE) then return S.HAMMER_JUSTICE, "FIGHT SFAVOREVOLE", "ALT", trendText .. ": stun e recupera tempo", "caution" end
                elseif PLAYER_CLASS == "SHAMAN" then
                    if IsKnown(S.STONECLAW_TOTEM) and IsUsable(S.STONECLAW_TOTEM) and not HCOB_AdvisorEngine.TotemActive(S.STONECLAW_TOTEM) then return S.STONECLAW_TOTEM, "FIGHT SFAVOREVOLE", "ALL MODS", trendText .. ": Stoneclaw e crea spazio", "caution" end
                    if IsKnown(S.HEALING_WAVE) and IsUsable(S.HEALING_WAVE) and UnitHealthPct("player") <= 58 then return S.HEALING_WAVE, "FIGHT SFAVOREVOLE", "ALT+CTRL", trendText .. ": heal se hai spazio", "caution" end
                end
                return nil, "FIGHT SFAVOREVOLE", "PREPARA FUGA", trendText .. ": conserva controllo/difensivi", "caution"
            end
        end
    end

    if not inCombat and hostile then
        local diff = targetLevel - playerLevel
        if classification == "elite" or classification == "rareelite" or classification == "worldboss" then
            return nil, "ELITE!", "VALUTA PULL", "Hardcore: " .. classification, "danger"
        elseif diff >= 3 then
            return nil, "+" .. diff .. " LEVEL", "VALUTA PULL", "Bersaglio sopra il tuo livello", "danger"
        end
    end

    -- Prima le finestre di combattimento che possono scadere (proc/execute/cooldown),
    -- poi i buff. ClassRecommendation ritorna NIL se non c'e' nulla da fare a mano.
    local id, title, key, reason = ClassRecommendation(inCombat, hostile, targetHP)
    if id then return id, title, key, reason, "action" end

    id, title, key, reason = BuffRecommendation(inCombat)
    if id then return id, title, key, reason, "buff" end

    if PLAYER_CLASS == "HUNTER" then
        if inCombat and hostile then
            return nil, "AUTO SHOT OK", "LASCIA CORRERE", "Auto Shot e' auto-repeat: non spammare BASE; premi solo quando cambi target/pull", "idle"
        elseif hostile then
            return S.AUTO_SHOT, "AVVIA PULL", "PREMI BASE", "Un click avvia pet + Auto Shot; poi lascialo correre", "idle"
        end
    end

    return nil, "BASE OK", "CONTINUA SPAM", "Nessuna spell manuale urgente", "idle"
end


local function SetDisplay(spellId, title, keyHint, reason, kind)
    UpdateDiagnosticPixel(spellId)
    if HCOB_ActionPanel then
        HCOB_ActionPanel.Highlight(spellId)
        HCOB_ActionPanel.UpdateStates()
    end
    if HCOB_DB.showAdvisor == false then return end

    -- Non mostrare un '?' quando semplicemente non c'e' una priorita manuale.
    -- In idle usiamo l'icona dell'azione base; per warning senza spell usiamo
    -- texture UI esplicite. Il question mark resta un vero fallback di errore.
    local displayId = spellId
    local fallbackTexture
    if not displayId then
        if kind == "idle" then
            displayId = select(1, BaseActionInfo())
            fallbackTexture = "Interface\\RaidFrame\\ReadyCheck-Ready"
        elseif kind == "danger" then
            fallbackTexture = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
        elseif kind == "interrupt" then
            fallbackTexture = "Interface\\Icons\\Ability_Kick"
        else
            fallbackTexture = "Interface\\RaidFrame\\ReadyCheck-Ready"
        end
    end
    advisorIcon:SetTexture(SpellIcon(displayId, fallbackTexture))
    advisorTitle:SetText(title or "ADVISOR")
    advisorReason:SetText(reason or "")

    local actionHint = keyHint or "CAST MANUALE"
    local baseKey = nil
    if GetBindingKey then baseKey = GetBindingKey("CLICK HCOneButtonFrame:LeftButton") end
    baseKey = baseKey or "TASTO HCOB"
    local manual = (actionHint == "CAST MANUALE")
    local clickable = HCOB_DB.secureActions ~= false and HCOB_ActionPanel and HCOB_ActionPanel.Has(spellId)
    local holdAction = (actionHint == "LASCIA CORRERE")
    local baseAction = (actionHint == "PREMI BASE" or actionHint == "CONTINUA SPAM" or actionHint == "BASE SPAM OK")
    local modifier = (actionHint == "SHIFT" or actionHint == "CTRL" or actionHint == "ALT" or actionHint == "CTRL+SHIFT" or actionHint == "ALT+SHIFT" or actionHint == "ALT+CTRL" or actionHint == "CTRL+ALT+SHIFT")

    -- DANGER/CAUTION hanno precedenza sul tipo di input. In v1.9 un warning
    -- Hamstring con ALT poteva apparire blu come un normale "HCOB ORA":
    -- graficamente era ambiguo proprio quando serviva chiarezza.
    if kind == "danger" then
        advisorMode:SetText("HC DANGER")
        advisorMode:SetTextColor(1, 0.88, 0.88)
        advisorBanner:SetColorTexture(0.72, 0.015, 0.015, 1.0)
        advisorBG:SetColorTexture(0.13, 0.008, 0.008, 0.98)
        HCOB_SetRectBorderColor(HCOB_CoreShell, 1, 0.12, 0.08, 1)
        HCOB_SetRectBorderColor(dpsMeter, 1, 0.12, 0.08, 0.95)
        if clickable then
            advisorKey:SetText("CLICCA ICONA ILLUMINATA")
        elseif manual then
            advisorKey:SetText("PREMI DALLA BARRA")
        elseif modifier then
            advisorKey:SetText(actionHint .. " + " .. baseKey)
        else
            advisorKey:SetText(actionHint)
        end
        advisorKey:SetTextColor(1, 0.46, 0.38)
        advisorTitle:SetTextColor(1, 0.38, 0.24)
        advisor:SetAlpha(1.0)
        if advisorIcon.SetDesaturated then advisorIcon:SetDesaturated(false) end
    elseif kind == "caution" then
        advisorMode:SetText("HC CAUTION")
        advisorMode:SetTextColor(1, 0.92, 0.65)
        advisorBanner:SetColorTexture(0.62, 0.30, 0.015, 1.0)
        advisorBG:SetColorTexture(0.075, 0.045, 0.008, 0.97)
        HCOB_SetRectBorderColor(HCOB_CoreShell, 1, 0.62, 0.10, 0.98)
        HCOB_SetRectBorderColor(dpsMeter, 1, 0.62, 0.10, 0.90)
        if clickable then
            advisorKey:SetText("CLICCA ICONA ILLUMINATA")
        elseif manual then
            advisorKey:SetText("PREMI DALLA BARRA")
        elseif modifier then
            advisorKey:SetText(actionHint .. " + " .. baseKey)
        else
            advisorKey:SetText(actionHint)
        end
        advisorKey:SetTextColor(1, 0.78, 0.30)
        advisorTitle:SetTextColor(1, 0.78, 0.22)
        advisor:SetAlpha(1.0)
        if advisorIcon.SetDesaturated then advisorIcon:SetDesaturated(false) end
    elseif manual then
        advisorMode:SetText(clickable and "CLICCA ORA" or "MANUALE ORA")
        advisorMode:SetTextColor(1, 0.90, 0.20)
        advisorBanner:SetColorTexture(0.62, 0.07, 0.02, 0.98)
        advisorBG:SetColorTexture(0.018, 0.018, 0.022, 0.95)
        HCOB_SetRectBorderColor(HCOB_CoreShell, 0.55, 0.42, 0.10, 0.95)
        HCOB_SetRectBorderColor(dpsMeter, 0.35, 0.35, 0.35, 0.85)
        advisorKey:SetText(clickable and "CLICCA ICONA ILLUMINATA" or "PREMI DALLA BARRA")
        advisorKey:SetTextColor(1, 0.92, 0.25)
        advisorTitle:SetTextColor(1, 0.82, 0)
        advisor:SetAlpha(1.0)
        if advisorIcon.SetDesaturated then advisorIcon:SetDesaturated(false) end
    elseif modifier then
        advisorMode:SetText("HCOB ORA")
        advisorMode:SetTextColor(0.85, 0.95, 1)
        advisorBanner:SetColorTexture(0.04, 0.28, 0.52, 0.98)
        advisorBG:SetColorTexture(0.018, 0.018, 0.022, 0.95)
        HCOB_SetRectBorderColor(HCOB_CoreShell, 0.20, 0.55, 0.90, 0.95)
        HCOB_SetRectBorderColor(dpsMeter, 0.35, 0.35, 0.35, 0.85)
        advisorKey:SetText(clickable and "CLICCA ICONA ILLUMINATA" or (actionHint .. " + " .. baseKey))
        advisorKey:SetTextColor(0.65, 0.90, 1)
        advisorTitle:SetTextColor(1, 0.82, 0)
        advisor:SetAlpha(1.0)
        if advisorIcon.SetDesaturated then advisorIcon:SetDesaturated(false) end
    elseif holdAction then
        advisorMode:SetText("AUTO ACTIVE")
        advisorMode:SetTextColor(0.72, 0.92, 1)
        advisorBanner:SetColorTexture(0.04, 0.24, 0.38, 0.96)
        advisorBG:SetColorTexture(0.018, 0.018, 0.022, 0.95)
        HCOB_SetRectBorderColor(HCOB_CoreShell, 0.20, 0.48, 0.70, 0.90)
        HCOB_SetRectBorderColor(dpsMeter, 0.35, 0.35, 0.35, 0.85)
        advisorKey:SetText("LASCIA CORRERE")
        advisorKey:SetTextColor(0.70, 0.90, 1)
        advisorTitle:SetTextColor(0.80, 0.90, 1)
        advisor:SetAlpha(0.86)
        if advisorIcon.SetDesaturated then advisorIcon:SetDesaturated(false) end
    elseif baseAction then
        advisorMode:SetText(PLAYER_CLASS == "HUNTER" and "PULL" or "BASE SPAM")
        advisorMode:SetTextColor(0.75, 1, 0.75)
        advisorBanner:SetColorTexture(0.04, 0.35, 0.10, 0.96)
        advisorBG:SetColorTexture(0.018, 0.018, 0.022, 0.95)
        HCOB_SetRectBorderColor(HCOB_CoreShell, 0.25, 0.55, 0.28, 0.90)
        HCOB_SetRectBorderColor(dpsMeter, 0.35, 0.35, 0.35, 0.85)
        advisorKey:SetText((PLAYER_CLASS == "HUNTER" and "PREMI " or "SPAMMA ") .. baseKey)
        advisorKey:SetTextColor(0.65, 1, 0.65)
        advisorTitle:SetTextColor(1, 0.82, 0)
        advisor:SetAlpha(0.92)
        if advisorIcon.SetDesaturated then advisorIcon:SetDesaturated(false) end
    else
        advisorMode:SetText("OK")
        advisorMode:SetTextColor(0.65, 0.75, 0.80)
        advisorBanner:SetColorTexture(0.12, 0.14, 0.16, 0.94)
        advisorBG:SetColorTexture(0.018, 0.018, 0.022, 0.95)
        HCOB_SetRectBorderColor(HCOB_CoreShell, 0.38, 0.38, 0.38, 0.95)
        HCOB_SetRectBorderColor(dpsMeter, 0.35, 0.35, 0.35, 0.85)
        advisorKey:SetText("SPAM " .. baseKey)
        advisorKey:SetTextColor(0.65, 0.75, 0.8)
        advisorTitle:SetTextColor(0.75, 0.75, 0.75)
        advisor:SetAlpha(0.66)
        if advisorIcon.SetDesaturated then advisorIcon:SetDesaturated(true) end
    end

    if kind == "danger" then
        advisorGlow:SetVertexColor(1,0.1,0.1); advisorGlow:Show()
        advisorReason:SetTextColor(1, 0.8, 0.8)
    elseif kind == "caution" then
        advisorGlow:SetVertexColor(1,0.55,0.05); advisorGlow:Show()
        advisorReason:SetTextColor(1, 0.86, 0.55)
    elseif kind == "interrupt" then
        advisorGlow:SetVertexColor(1,0.45,0.05); advisorGlow:Show()
        advisorReason:SetTextColor(1, 0.88, 0.72)
    elseif kind == "buff" then
        advisorGlow:SetVertexColor(0.2,0.65,1); advisorGlow:Show()
        advisorReason:SetTextColor(0.82, 0.92, 1)
    elseif kind == "action" then
        advisorGlow:SetVertexColor(0.95,0.8,0.15); advisorGlow:Show()
        advisorReason:SetTextColor(1, 0.95, 0.8)
    else
        advisorGlow:Hide()
        advisorReason:SetTextColor(0.75,0.75,0.75)
    end
end

local function ResourceDisplay()
    if PLAYER_CLASS == "ROGUE" then return tostring(UnitPower("player", 3) or 0) .. "E" end
    local pType, pToken = UnitPowerType("player")
    local value = UnitPower("player", pType) or 0
    local maxv = UnitPowerMax("player", pType) or 0
    if pToken == "RAGE" then return tostring(value) .. "R" end
    if pToken == "ENERGY" then return tostring(value) .. "E" end
    if pToken == "MANA" then return maxv > 0 and (tostring(math.floor(value/maxv*100)) .. "%M") or "0M" end
    return tostring(value)
end

local function UpdateStatusBars(hp)
    local hpPct = Clamp((hp or 0) / 100, 0, 1)
    local width = hpBarBG:GetWidth(); if not width or width <= 1 then width = 82 end
    hpBarFill:SetWidth(math.max(1, width * hpPct))
    if hp > (HCOB_DB.dangerHP or 35) then
        hpBarFill:SetColorTexture(0.18, 0.82, 0.22, 0.96)
    elseif hp > (HCOB_DB.criticalHP or 20) then
        hpBarFill:SetColorTexture(0.95, 0.72, 0.12, 0.96)
    else
        hpBarFill:SetColorTexture(0.92, 0.14, 0.14, 0.96)
    end

    local pType, pToken = UnitPowerType("player")
    local value = UnitPower("player", pType) or 0
    local maxv = UnitPowerMax("player", pType) or 1
    local pPct = Clamp(value / math.max(1, maxv), 0, 1)
    powerBarFill:SetWidth(math.max(1, width * pPct))
    if pToken == "RAGE" then
        powerBarFill:SetColorTexture(0.82, 0.18, 0.18, 0.96)
    elseif pToken == "ENERGY" then
        powerBarFill:SetColorTexture(0.96, 0.84, 0.12, 0.96)
    elseif pToken == "MANA" then
        powerBarFill:SetColorTexture(0.2, 0.55, 1, 0.96)
    else
        powerBarFill:SetColorTexture(0.75, 0.35, 1, 0.96)
    end
end

local function AutoAttackSpeed()
    if PLAYER_CLASS == "HUNTER" or HasWandEquipped() then
        if UnitRangedDamage then
            local speed = UnitRangedDamage("player")
            if speed and speed > 0 then return speed end
        end
    end
    local speed = UnitAttackSpeed("player")
    return speed
end

local function UpdateSwingBar()
    if not HCOB_DB.showSwing then swingBG:Hide(); return end
    local speed = AutoAttackSpeed()
    if not speed or speed <= 0 or not lastAutoAttack then swingBG:Hide(); return end
    swingBG:Show()
    local elapsed = GetTime() - lastAutoAttack
    local pct = Clamp(elapsed / speed, 0, 1)
    local width = swingBG:GetWidth(); if not width or width <= 1 then width = 82 end
    swingFill:SetWidth(math.max(1, width * pct))
end

local function UpdateDisplayMinimal(reason)
    if not UnitExists("player") then return end
    local hp = UnitHealthPct("player")
    hpText:SetText(tostring(math.floor(hp)) .. "%")
    local pType = UnitPowerType("player")
    local value = UnitPower("player", pType) or 0
    resourceText:SetText(tostring(value))
    enemyText:SetText("")
    UpdateStatusBars(hp)
    UpdateBaseVisual()
    SetDisplay(nil, "ADVISOR OFF", "BASE SPAM OK", reason or "Smart HUD disattivato", "idle")
    if HCOB_DB.showSwing then UpdateSwingBar() else swingBG:Hide() end
    UpdateDPSMeter()
end


local function UpdateDisplayCore()
    if not UnitExists("player") then return end
    UpdateBaseVisual()
    if HCOB_DB.smartDisplay == false or runtimeSmartDisabled then
        return UpdateDisplayMinimal(runtimeSmartDisabled and "SAFE MODE: /hcob errors" or "Smart HUD disattivato")
    end
    local hp = UnitHealthPct("player")
    local enemies = CountActiveEnemies()
    hpText:SetText(tostring(math.floor(hp)) .. "%")
    resourceText:SetText(ResourceDisplay())
    enemyText:SetText(enemies >= 2 and ("x" .. enemies) or "")
    UpdateStatusBars(hp)
    local spellId, title, keyHint, reason, kind = Recommend()
    spellId, title, keyHint, reason, kind = HCOB_AdvisorEngine.Stabilize(spellId, title, keyHint, reason, kind)
    SetDisplay(spellId, title, keyHint, reason, kind)

    if currentFight and HCOB_DB.combatLogging ~= false and not runtimeTelemetryDisabled then
        local reserve = HCOB_AdvisorEngine.SurvivalReserve()
        currentFight.survivalReserveSamples = (tonumber(currentFight.survivalReserveSamples) or 0) + 1
        currentFight.survivalReserveSum = (tonumber(currentFight.survivalReserveSum) or 0) + (tonumber(reserve) or 0)
        currentFight.survivalReserveMin = math.min(tonumber(currentFight.survivalReserveMin) or 100, tonumber(reserve) or 100)
        currentFight.advisorSamples = (tonumber(currentFight.advisorSamples) or 0) + 1
        if kind == "danger" then
            currentFight.advisorDangerSamples = (tonumber(currentFight.advisorDangerSamples) or 0) + 1
        elseif kind == "caution" then
            currentFight.advisorCautionSamples = (tonumber(currentFight.advisorCautionSamples) or 0) + 1
        elseif kind == "interrupt" then
            currentFight.advisorInterruptSamples = (tonumber(currentFight.advisorInterruptSamples) or 0) + 1
        end
        if keyHint == "CAST MANUALE" then
            currentFight.advisorManualSamples = (tonumber(currentFight.advisorManualSamples) or 0) + 1
        end
    end

    local recKey = tostring(spellId) .. ":" .. tostring(kind) .. ":" .. tostring(title)
    if recKey ~= lastRecommendationKey then
        if currentFight then
            if kind == "danger" then
                currentFight.advisorDangerEvents = (tonumber(currentFight.advisorDangerEvents) or 0) + 1
            elseif kind == "caution" then
                currentFight.advisorCautionEvents = (tonumber(currentFight.advisorCautionEvents) or 0) + 1
            end
        end
        if kind == "danger" then
            PlayAlert("danger")
        elseif kind == "interrupt" then
            PlayAlert("interrupt")
        end
        lastRecommendationKey = recKey
    end
    UpdateSwingBar()
    UpdateDPSMeter()
end


local function UpdateDisplay()
    local ok = SafeRun("SmartHUD", UpdateDisplayCore)
    if not ok then
        -- Un solo errore nell'HUD smart basta per metterlo in safe mode.
        -- Il SecureActionButton e la macro restano indipendenti e continuano a funzionare.
        runtimeSmartDisabled = true
        pcall(UpdateDisplayMinimal, "SAFE MODE: errore HUD intercettato")
    end
end

local function CombatLogHandler()
    local args = { CombatLogGetCurrentEventInfo() }
    local subevent = args[2]
    local sourceGUID, sourceFlags = args[4], args[6]
    local destGUID, destFlags = args[8], args[10]
    local spellId, spellName = args[12], args[13]
    if not playerGUID then playerGUID = UnitGUID("player") end
    if not playerGUID then return end
    local now = GetTime()

    local petGUID = UnitGUID("pet")
    local exchangeEvent = subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "SPELL_PERIODIC_MISSED" or subevent == "RANGE_DAMAGE" or subevent == "RANGE_MISSED"
    if exchangeEvent then
        local sourceOurs = sourceGUID == playerGUID or (petGUID and sourceGUID == petGUID)
        local destOurs = destGUID == playerGUID or (petGUID and destGUID == petGUID)
        if destOurs and sourceGUID and not IsPlayerOrPetGUID(sourceGUID) then
            MarkEnemy(sourceGUID)
        elseif sourceOurs and destGUID and not IsPlayerOrPetGUID(destGUID) then
            MarkEnemy(destGUID)
        end
    end

    if sourceGUID == playerGUID and (subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" or subevent == "RANGE_DAMAGE" or subevent == "RANGE_MISSED") then
        lastAutoAttack = now
    end
    if destGUID == playerGUID and sourceGUID ~= playerGUID
       and (subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED") then
        HCOB_AdvisorEngine.lastMeleeAt = now
        if PLAYER_CLASS == "MAGE" then Mage.lastMeleeAt = now end
    end
    if PLAYER_CLASS == "HUNTER" then
        if destGUID == playerGUID and sourceGUID ~= playerGUID and (subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED") then
            HCOB_Hunter.lastMeleeAt = now
        end
        if sourceGUID == playerGUID and (subevent == "RANGE_DAMAGE" or subevent == "RANGE_MISSED") and tonumber(spellId) == S.AUTO_SHOT then
            HCOB_Hunter.lastAutoShotAt = now
        end
    end

    local targetGUID = UnitGUID("target")
    if targetGUID and sourceGUID == targetGUID and subevent == "SPELL_CAST_START" then
        activeTargetCast = {guid=sourceGUID, spellId=tonumber(spellId), name=spellName or SpellName(tonumber(spellId),"Cast"), expires=now + SpellCastSeconds(tonumber(spellId)) + 0.35}
    elseif activeTargetCast and sourceGUID == activeTargetCast.guid then
        if subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_CAST_FAILED" or subevent == "UNIT_DIED" then activeTargetCast = nil end
    elseif activeTargetCast and destGUID == activeTargetCast.guid and (subevent == "UNIT_DIED" or subevent == "SPELL_INTERRUPT") then
        activeTargetCast = nil
    end

    if HCOB_DB.combatLogging ~= false and not runtimeTelemetryDisabled then
        local ok = SafeRun("CombatTelemetry", ProcessCombatTelemetry, args)
        if not ok then runtimeTelemetryDisabled = true end
    end
end

local function SafeCombatLogHandler()
    if runtimeCombatLogDisabled then return end
    local ok = SafeRun("CombatLog", CombatLogHandler)
    if not ok then
        runtimeCombatLogDisabled = true
        activeTargetCast = nil
        activeEnemies = {}
    end
end

btn:SetScript("OnDragStart", function(self) if not InCombatLockdown() and not HCOB_DB.locked then self:StartMoving() end end)
btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, px, py = self:GetPoint(1)
    HCOB_DB.x, HCOB_DB.y = px, py
end)

local function ModifierLine(key, value)
    if value and value ~= "" then return key .. ": " .. value end
end

btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local localizedClass = UnitClass("player") or PLAYER_CLASS
    local specIndex, specName = TalentSpec()
    GameTooltip:AddLine("HC One Button v" .. VERSION)
    GameTooltip:AddLine(localizedClass .. " L" .. PlayerLevel() .. " - " .. tostring(specName) .. " (tree " .. specIndex .. ")", 1, 1, 1)
    GameTooltip:AddLine("SPAM: azione base sicura. Advisor: spell situazionale da castare a mano.", 0.3, 1, 0.3, true)
    if currentMods and currentMods.desc then
        local d = currentMods.desc
        GameTooltip:AddLine(ModifierLine("SHIFT", d.shift) or "", 0.8,0.8,0.8, true)
        GameTooltip:AddLine(ModifierLine("CTRL", d.ctrl) or "", 0.8,0.8,0.8, true)
        GameTooltip:AddLine(ModifierLine("ALT", d.alt) or "", 0.8,0.8,0.8, true)
        GameTooltip:AddLine(ModifierLine("CTRL+SHIFT", d.ctrlshift) or "", 0.8,0.8,0.8, true)
        GameTooltip:AddLine(ModifierLine("ALT+SHIFT", d.altshift) or "", 0.8,0.8,0.8, true)
        GameTooltip:AddLine(ModifierLine("ALT+CTRL", d.altctrl) or "", 0.8,0.8,0.8, true)
        GameTooltip:AddLine(ModifierLine("ALL MODS", d.all) or "", 0.8,0.8,0.8, true)
    end
    GameTooltip:AddLine("/hcob help", 0.7,0.7,0.7)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
btn:HookScript("PostClick", function(self, mouseButton, down)
    if currentFight and mouseButton == "LeftButton" then
        currentFight.baseClicks = (tonumber(currentFight.baseClicks) or 0) + 1
    end
end)

local function PrintPlan()
    local localizedClass = UnitClass("player")
    local specIndex, specName = TalentSpec()
    print("|cff00ff98HCOB:|r " .. (localizedClass or PLAYER_CLASS) .. " L" .. PlayerLevel() .. " - " .. tostring(specName) .. " (tree " .. specIndex .. ")")
    print("|cffffcc00BASE SPAM macro:|r")
    print(btn:GetAttribute("macrotext1") or "")
    if currentMods and currentMods.desc then
        local d=currentMods.desc
        print("SHIFT="..tostring(d.shift).." | CTRL="..tostring(d.ctrl).." | ALT="..tostring(d.alt))
        print("CTRL+SHIFT="..tostring(d.ctrlshift).." | ALT+SHIFT="..tostring(d.altshift).." | ALT+CTRL="..tostring(d.altctrl).." | ALL="..tostring(d.all))
    end
end

local BIND_COMMAND = "CLICK HCOneButtonFrame:LeftButton"
local OLD_BIND_COMMAND = "CLICK HCWarriorOneButtonFrame:LeftButton"

local function NormalizeBindingKey(key)
    key = (key or ""):upper():gsub("%s+", "")
    key = key:gsub("MOUSEBUTTON", "BUTTON"):gsub("MOUSE", "BUTTON"):gsub("MB", "BUTTON")
    return key
end

local function SaveCurrentBindings()
    local bindingSet = GetCurrentBindingSet and GetCurrentBindingSet() or 1
    if SaveBindings then SaveBindings(bindingSet) end
end

local function MigrateOldBindings()
    if HCOB_DB.bindingMigrationDone then return end
    if InCombatLockdown() then return end
    local keys = { GetBindingKey(OLD_BIND_COMMAND) }
    local migrated = 0
    for _, key in ipairs(keys) do
        if key and key ~= "" then
            SetBindingClick(key, "HCOneButtonFrame", "LeftButton")
            migrated = migrated + 1
        end
    end
    if migrated > 0 then
        SaveCurrentBindings()
        print("|cff00ff98HCOB:|r migrato automaticamente il vecchio bind HCWarriorOneButton.")
    end
    HCOB_DB.bindingMigrationDone = true
end

local function BindKey(key)
    if InCombatLockdown() then print("|cffff5555HCOB:|r cambia bind fuori combattimento."); return end
    key = NormalizeBindingKey(key)
    if key == "" then print("|cffffcc00HCOB:|r esempio: /hcob bind BUTTON4 oppure /hcob bind Q"); return end
    local old = GetBindingAction(key)
    if SetBindingClick(key, "HCOneButtonFrame", "LeftButton") then
        SaveCurrentBindings()
        if old and old ~= "" and old ~= BIND_COMMAND then print("|cffffcc00HCOB:|r " .. key .. " prima era: " .. old) end
        print("|cff00ff98HCOB:|r " .. key .. " assegnato e salvato.")
    end
end

local function UnbindKey(key)
    if InCombatLockdown() then print("|cffff5555HCOB:|r cambia bind fuori combattimento."); return end
    key = NormalizeBindingKey(key)
    if GetBindingAction(key) == BIND_COMMAND then SetBinding(key); SaveCurrentBindings(); print("|cff00ff98HCOB:|r bind rimosso da " .. key)
    else print("|cffffcc00HCOB:|r " .. key .. " non e' assegnato a HC One Button.") end
end

local function PrintKeys()
    local keys = { GetBindingKey(BIND_COMMAND) }
    if #keys == 0 then print("|cffffcc00HCOB:|r nessun bind.") else print("|cff00ff98HCOB:|r bind: " .. table.concat(keys, ", ")) end
end

local function BindTest(key)
    key = NormalizeBindingKey(key or "BUTTON4")
    local action = GetBindingAction and GetBindingAction(key) or ""
    local keys = { GetBindingKey(BIND_COMMAND) }
    local cvar = GetCVar and GetCVar("ActionButtonUseKeyDown") or "?"
    local useDown = btn:GetAttribute("useOnKeyDown")
    print("|cff00ff98HCOB BINDTEST:|r key=" .. tostring(key))
    print("azione=" .. tostring(action ~= "" and action or "<nessuna>"))
    print("bind HCOB=" .. (#keys > 0 and table.concat(keys, ", ") or "<nessuno>"))
    print("ActionButtonUseKeyDown=" .. tostring(cvar) .. " | HCOB useOnKeyDown=" .. tostring(useDown))
    local macro = btn:GetAttribute("macrotext1") or ""
    print("macro BASE=" .. (macro ~= "" and macro:gsub("\n", " | ") or "<vuota>"))
    if action == BIND_COMMAND then
        print("|cff00ff98HCOB BINDTEST: OK|r " .. key .. " punta a HCOneButtonFrame:LeftButton")
    else
        print("|cffff5555HCOB BINDTEST: FAIL|r usa /hcob bind " .. key .. " fuori combattimento")
    end
end

local function Center()
    if InCombatLockdown() then print("|cffff5555HCOB:|r fallo fuori combattimento."); return end
    btn:ClearAllPoints(); btn:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    HCOB_DB.x, HCOB_DB.y = 0, -180; HCOB_DB.visible = true; btn:Show()
end

local function Toggle(key, arg)
    if arg ~= "on" and arg ~= "off" then print("|cffffcc00HCOB:|r usa on oppure off."); return end
    HCOB_DB[key] = arg == "on"
    print("|cff00ff98HCOB:|r " .. key .. " = " .. arg)
end

local function OpenOptionsPanel()
    if not optionsPanel then
        print("|cffff5555HCOB:|r pannello opzioni non ancora disponibile. Prova /reload.")
        return
    end
    if InCombatLockdown() then
        print("|cffffcc00HCOB:|r apri le opzioni fuori combattimento.")
        return
    end
    optionsPanel:Show()
    optionsPanel:Raise()
end

local function OpenBlizzardSettingsPanel()
    if InCombatLockdown() then
        print("|cffffcc00HCOB:|r apri le impostazioni fuori combattimento.")
        return
    end
    if Settings and Settings.OpenToCategory and settingsCategory then
        local categoryID = settingsCategory.GetID and settingsCategory:GetID() or settingsCategory.ID
        if categoryID then
            local ok = pcall(Settings.OpenToCategory, categoryID)
            if ok then return end
        end
    end
    OpenOptionsPanel()
end

local sliderSerial = 0

local function CreateCheckBox(parent, labelText, tooltipText, getValue, setValue, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(labelText)
    cb.tooltipText = tooltipText
    cb:SetChecked(getValue())
    cb:SetScript("OnClick", function(self) setValue(self:GetChecked() and true or false) end)
    cb.Refresh = function(self) self:SetChecked(getValue()) end
    return cb
end

local function CreateSlider(parent, labelText, minv, maxv, step, getValue, setValue, x, y, lowText, highText, fmt)
    sliderSerial = sliderSerial + 1
    local name = "HCOneButtonSlider" .. sliderSerial
    local sl = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    sl:SetPoint("TOPLEFT", x, y)
    sl:SetWidth(220)
    sl:SetMinMaxValues(minv, maxv)
    sl:SetValueStep(step)
    if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
    local text = _G[name .. "Text"]
    local low = _G[name .. "Low"]
    local high = _G[name .. "High"]
    if text then text:SetText(labelText) end
    if low then low:SetText(lowText or tostring(minv)) end
    if high then high:SetText(highText or tostring(maxv)) end
    sl:SetScript("OnValueChanged", function(self, value)
        value = math.floor((value / step) + 0.5) * step
        if step < 1 then value = math.floor(value * 100 + 0.5) / 100 end
        setValue(value)
        if self.ValueText then self.ValueText:SetText(fmt and fmt:format(value) or tostring(value)) end
    end)
    local val = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    val:SetPoint("TOP", sl, "BOTTOM", 0, 0)
    sl.ValueText = val
    sl.Refresh = function(self)
        self:SetValue(getValue())
        if self.ValueText then self.ValueText:SetText(fmt and fmt:format(getValue()) or tostring(getValue())) end
    end
    sl:Refresh()
    return sl
end

local function CreateOptionsPanel()
    if optionsPanel then return end

    -- Finestra autonoma: /hcob options apre sempre questa, indipendentemente
    -- dalle modifiche future all'API Settings di Blizzard.
    local panel = CreateFrame("Frame", "HCOneButtonOptionsPanel", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(700, 670)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    panel:Hide()

    if panel.TitleText then
        panel.TitleText:SetText("HC One Button - Opzioni")
    end

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -36)
    title:SetText("HC One Button")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
    subtitle:SetWidth(650)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Pannello locale dell'addon. Le modifiche vengono salvate automaticamente nelle SavedVariables.")

    local info = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    info:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -18)
    info:SetText("Aspetto e comportamento")

    local controls = {}
    local function add(control) table.insert(controls, control); return control end

    add(CreateCheckBox(panel, "Mostra pulsante", "Mostra o nasconde HC One Button.", function() return HCOB_DB.visible end, function(v) HCOB_DB.visible = v; RefreshButtonState() end, 24, -118))
    add(CreateCheckBox(panel, "Blocca posizione", "Disattiva il trascinamento del pulsante.", function() return HCOB_DB.locked end, function(v) HCOB_DB.locked = v end, 24, -148))
    add(CreateCheckBox(panel, "Suoni di avviso", "Riproduce suoni per danger e interrupt.", function() return HCOB_DB.soundAlerts end, function(v) HCOB_DB.soundAlerts = v end, 24, -178))
    add(CreateCheckBox(panel, "Mostra swing timer", "Mostra la barra del prossimo attacco automatico.", function() return HCOB_DB.showSwing end, function(v) HCOB_DB.showSwing = v; UpdateDisplay() end, 24, -208))
    add(CreateCheckBox(panel, "Smart HUD", "Analizza buff, target, cooldown e pericolo. Se una API genera errore, viene disattivato automaticamente per la sessione senza fermare il pulsante.", function() return HCOB_DB.smartDisplay ~= false end, function(v) HCOB_DB.smartDisplay = v; if v then runtimeSmartDisabled = false end; UpdateDisplay() end, 24, -238))
    add(CreateCheckBox(panel, "Mostra Advisor", "Mostra il pannello a destra con la spell situazionale da castare manualmente.", function() return HCOB_DB.showAdvisor ~= false end, function(v) HCOB_DB.showAdvisor = v; RefreshButtonState(); UpdateDisplay() end, 24, -268))
    add(CreateCheckBox(panel, "HC danger advisor", "Multi-pull e fight trend: passa a CAUTION/DANGER prima della sola soglia HP.", function() return HCOB_DB.hcDangerAdvisor ~= false end, function(v) HCOB_DB.hcDangerAdvisor = v; UpdateDisplay() end, 350, -82))
    if PLAYER_CLASS == "WARRIOR" then
        add(CreateCheckBox(panel, "Warrior: Rend intelligente pre-pull", "Fuori combat, se il target e' pari/quasi pari livello o elite, prepara Rend x1 in apertura. Lo salta sui mob triviali.", function() return HCOB_DB.warriorAutoRend ~= false end, function(v) HCOB_DB.warriorAutoRend = v; BuildMacros(); UpdateDisplay() end, 24, -328))
        add(CreateCheckBox(panel, "Warrior: Sunder situazionale", "Sunder resta nell Advisor contro target resistenti; non viene spammato ai livelli bassi.", function() return HCOB_DB.warriorSunderBase ~= false end, function(v) HCOB_DB.warriorSunderBase = v; BuildMacros(); UpdateDisplay() end, 24, -358))
    end
    add(CreateCheckBox(panel, "Combat logger", "Registra statistiche compatte degli ultimi combattimenti nelle SavedVariables. Usa /hcob log last per il riepilogo.", function() return HCOB_DB.combatLogging ~= false end, function(v) HCOB_DB.combatLogging = v; if not v and currentFight then FinalizeCombatTelemetry("logging_off") end end, 24, -388))

    add(CreateCheckBox(panel, "Mini DPS meter", "Mostra DPS corrente e media recente sotto l Advisor. Richiede il Combat logger attivo.", function() return HCOB_DB.showDPSMeter ~= false end, function(v) HCOB_DB.showDPSMeter = v; RefreshButtonState(); UpdateDPSMeter() end, 350, -455))

    local actionBindTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    actionBindTitle:SetPoint("TOPLEFT", 350, -500)
    actionBindTitle:SetText("Fixed Action Panel bindings")
    add(CreateCheckBox(panel, "Auto-applica binding slot", "Applica e salva automaticamente i binding configurati agli slot secure del pannello Azioni. Le modifiche sono consentite solo fuori combattimento.", function() return HCOB_DB.actionSlotAutoBind ~= false end, function(v)
        HCOB_DB.actionSlotAutoBind = v
        if v and HCOB_ActionPanel then HCOB_ActionPanel.ApplySlotBindings() end
    end, 350, -520))

    local actionBindBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    actionBindBtn:SetSize(190, 27)
    actionBindBtn:SetPoint("TOPLEFT", 350, -556)
    actionBindBtn:SetText("Configura binding slot...")
    actionBindBtn:SetScript("OnClick", function()
        if HCOB_ActionPanel and HCOB_ActionPanel.OpenBindingOptions then HCOB_ActionPanel.OpenBindingOptions() end
    end)

    add(CreateSlider(panel, "Scala pulsante", 0.70, 1.60, 0.05, function() return HCOB_DB.scale or 1 end, function(v) HCOB_DB.scale = v; RefreshButtonState() end, 350, -120, "0.7", "1.6", "%.2f"))
    add(CreateSlider(panel, "Danger HP", 20, 70, 1, function() return HCOB_DB.dangerHP or 35 end, function(v) HCOB_DB.dangerHP = v; UpdateDisplay() end, 350, -183, "20", "70", "%d%%"))
    add(CreateSlider(panel, "Critical HP", 10, 40, 1, function() return HCOB_DB.criticalHP or 20 end, function(v) HCOB_DB.criticalHP = v; UpdateDisplay() end, 350, -246, "10", "40", "%d%%"))
    add(CreateSlider(panel, "Finestra nemici", 3, 12, 1, function() return HCOB_DB.enemyWindow or 6 end, function(v) HCOB_DB.enemyWindow = v end, 350, -309, "3", "12", "%ds"))
    if PLAYER_CLASS == "WARRIOR" then
        add(CreateSlider(panel, "Heroic Strike da rage", 20, 70, 1, function() return HCOB_DB.warriorHeroicRage or 35 end, function(v) HCOB_DB.warriorHeroicRage = v; UpdateDisplay() end, 350, -402, "20", "70", "%d rage"))
    end

    local centerBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    centerBtn:SetSize(125, 25)
    centerBtn:SetPoint("TOPLEFT", 24, -445)
    centerBtn:SetText("Centra pulsante")
    centerBtn:SetScript("OnClick", Center)

    local planBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    planBtn:SetSize(125, 25)
    planBtn:SetPoint("LEFT", centerBtn, "RIGHT", 10, 0)
    planBtn:SetText("Stampa piano")
    planBtn:SetScript("OnClick", PrintPlan)

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(125, 25)
    resetBtn:SetPoint("TOPLEFT", centerBtn, "BOTTOMLEFT", 0, -12)
    resetBtn:SetText("Reset default")
    resetBtn:SetScript("OnClick", function()
        HCOB_DB.visible = true
        HCOB_DB.locked = false
        HCOB_DB.scale = 1.0
        HCOB_DB.dangerHP = 35
        HCOB_DB.criticalHP = 20
        HCOB_DB.soundAlerts = true
        HCOB_DB.enemyWindow = 6
        HCOB_DB.showSwing = true
        HCOB_DB.smartDisplay = true
        HCOB_DB.showAdvisor = true
        HCOB_DB.showDPSMeter = true
        HCOB_DB.hcDangerAdvisor = true
        HCOB_DB.warriorSunderBase = true
        HCOB_DB.warriorHeroicSpam = false
        HCOB_DB.warriorHeroicSafeBaseV111 = true
        HCOB_DB.warriorAutoRend = true
        HCOB_DB.warriorHeroicRage = 35
        HCOB_DB.combatLogging = true
        HCOB_DB.combatLogMaxFights = 60
        HCOB_DB.actionSlotAutoBind = true
        HCOB_DB.actionSlotKeys = nil
        runtimeSmartDisabled = false
        runtimeCombatLogDisabled = false
        runtimeErrors = {}
        RefreshButtonState()
        if HCOB_ActionPanel then HCOB_ActionPanel.ApplySlotBindings(); HCOB_ActionPanel.RefreshBindingOptions() end
        if panel.Refresh then panel:Refresh() end
        UpdateDisplay()
    end)

    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    closeBtn:SetSize(125, 25)
    closeBtn:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    closeBtn:SetText("Chiudi")
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    local tip = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tip:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -78)
    tip:SetWidth(620)
    tip:SetJustifyH("LEFT")
    tip:SetText("Comandi rapidi: /hcob bind BUTTON4, /hcob plan, /hcob actions binds, /hcob log last. I binding Fixed Action Panel possono essere modificati qui sopra e vengono applicati solo fuori combattimento.")

    panel.controls = controls
    panel.Refresh = function(self)
        for _, c in ipairs(self.controls or {}) do
            if c.Refresh then c:Refresh() end
        end
    end
    panel:SetScript("OnShow", function(self) self:Refresh() end)
    optionsPanel = panel

    -- Integrazione opzionale con ESC > Options > AddOns.
    -- Manteniamo un canvas separato per non dipendere dal comportamento
    -- del frame popup usato da /hcob options.
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local bridge = CreateFrame("Frame", "HCOneButtonSettingsBridge")
        bridge.name = "HC One Button"

        local bTitle = bridge:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        bTitle:SetPoint("TOPLEFT", 16, -16)
        bTitle:SetText("HC One Button")

        local bText = bridge:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        bText:SetPoint("TOPLEFT", bTitle, "BOTTOMLEFT", 0, -14)
        bText:SetWidth(560)
        bText:SetJustifyH("LEFT")
        bText:SetText("Le opzioni complete sono disponibili nel pannello dedicato dell'addon.")

        local openBtn = CreateFrame("Button", nil, bridge, "UIPanelButtonTemplate")
        openBtn:SetSize(190, 28)
        openBtn:SetPoint("TOPLEFT", bText, "BOTTOMLEFT", 0, -18)
        openBtn:SetText("Apri HC One Button")
        openBtn:SetScript("OnClick", OpenOptionsPanel)

        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, bridge, bridge.name)
        if ok and category then
            pcall(Settings.RegisterAddOnCategory, category)
            settingsCategory = category
            settingsBridgePanel = bridge
        end
    elseif InterfaceOptions_AddCategory then
        -- Client più vecchi: registra direttamente un piccolo bridge legacy.
        local bridge = CreateFrame("Frame", "HCOneButtonSettingsBridge", UIParent)
        bridge.name = "HC One Button"
        local bTitle = bridge:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        bTitle:SetPoint("TOPLEFT", 16, -16)
        bTitle:SetText("HC One Button")
        local openBtn = CreateFrame("Button", nil, bridge, "UIPanelButtonTemplate")
        openBtn:SetSize(190, 28)
        openBtn:SetPoint("TOPLEFT", 16, -58)
        openBtn:SetText("Apri HC One Button")
        openBtn:SetScript("OnClick", OpenOptionsPanel)
        pcall(InterfaceOptions_AddCategory, bridge)
        settingsBridgePanel = bridge
    end
end

SLASH_HCOB1 = "/hcob"
SLASH_HCOB2 = "/hconebutton"
SlashCmdList.HCOB = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local cmd, arg = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd or "help"
    if cmd == "bind" then BindKey(arg)
    elseif cmd == "unbind" then UnbindKey(arg)
    elseif cmd == "petfood" then HCOB_Hunter.PrintFoodStatus()
    elseif cmd == "keys" then PrintKeys()
    elseif cmd == "bindtest" then BindTest(arg ~= "" and arg or "BUTTON4")
    elseif cmd == "center" then Center()
    elseif cmd == "options" or cmd == "config" then OpenOptionsPanel()
    elseif cmd == "settings" then OpenBlizzardSettingsPanel()
    elseif cmd == "show" then if not InCombatLockdown() then HCOB_DB.visible=true; RefreshButtonState() end
    elseif cmd == "hide" then if not InCombatLockdown() then HCOB_DB.visible=false; RefreshButtonState() end
    elseif cmd == "lock" then HCOB_DB.locked=true; print("|cff00ff98HCOB:|r posizione bloccata.")
    elseif cmd == "unlock" then HCOB_DB.locked=false; print("|cff00ff98HCOB:|r posizione sbloccata.")
    elseif cmd == "plan" or cmd == "rotation" or cmd == "rotazione" or cmd == "macro" then PrintPlan()
    elseif cmd == "mods" then if currentMods and currentMods.desc then local d=currentMods.desc; print("SHIFT="..tostring(d.shift).." | CTRL="..tostring(d.ctrl).." | ALT="..tostring(d.alt)); print("CTRL+SHIFT="..tostring(d.ctrlshift).." | ALT+SHIFT="..tostring(d.altshift).." | ALT+CTRL="..tostring(d.altctrl).." | ALL="..tostring(d.all)) end
    elseif cmd == "smart" then
        if arg == "on" then HCOB_DB.smartDisplay=true; runtimeSmartDisabled=false; print("|cff00ff98HCOB:|r Smart HUD ON."); UpdateDisplay()
        elseif arg == "off" then HCOB_DB.smartDisplay=false; print("|cff00ff98HCOB:|r Smart HUD OFF; il pulsante sicuro resta attivo."); UpdateDisplay()
        else print("|cffffcc00HCOB:|r /hcob smart on|off") end
    elseif cmd == "advisor" then
        if arg == "on" or arg == "off" then
            HCOB_DB.showAdvisor = (arg == "on")
            RefreshButtonState(); UpdateDisplay()
            print("|cff00ff98HCOB:|r Advisor " .. string.upper(arg) .. ".")
        elseif arg == "debug" then
            HCOB_AdvisorEngine.DebugPrint()
        else print("|cffffcc00HCOB:|r /hcob advisor on|off|debug") end
    elseif cmd == "diagpixel" then
        if arg == "on" or arg == "off" then
            HCOB_DB.diagPixel = (arg == "on")
            RefreshButtonState(); UpdateDisplay()
            print("|cff00ff98HCOB:|r Diagnostic pixel " .. string.upper(arg) .. ".")
        else print("|cffffcc00HCOB:|r /hcob diagpixel on|off") end
    elseif cmd == "hsspam" then
        HCOB_DB.warriorHeroicSpam = false
        print("|cffffcc00HCOB:|r Heroic Strike nello spam BASE e' stato rimosso in v1.11: usa l'Advisor (ALT+SHIFT) quando raggiungi la soglia rage.")
    elseif cmd == "rendspam" then
        if arg == "on" or arg == "off" then
            HCOB_DB.warriorAutoRend = (arg == "on")
            BuildMacros(); UpdateDisplay()
            print("|cff00ff98HCOB:|r Rend intelligente pre-pull " .. string.upper(arg) .. ".")
        else print("|cffffcc00HCOB:|r /hcob rendspam on|off") end
    elseif cmd == "sunder" then
        if PLAYER_CLASS ~= "WARRIOR" then
            print("|cffffcc00HCOB:|r questa opzione e' solo Warrior.")
        elseif arg == "on" or arg == "off" then
            HCOB_DB.warriorSunderBase = (arg == "on")
            BuildMacros(); UpdateDisplay()
            print("|cff00ff98HCOB:|r Sunder base " .. string.upper(arg) .. ".")
        else
            print("|cffffcc00HCOB:|r /hcob sunder on|off")
        end
    elseif cmd == "hsrage" then
        local v = tonumber(arg)
        if v then
            HCOB_DB.warriorHeroicRage = Clamp(v, 20, 70)
            print("|cff00ff98HCOB:|r Heroic Strike consigliato da " .. HCOB_DB.warriorHeroicRage .. " rage.")
            UpdateDisplay()
        else print("|cffffcc00HCOB:|r /hcob hsrage 20-70") end
    elseif cmd == "errors" then
        if #runtimeErrors == 0 then print("|cff00ff98HCOB:|r nessun errore intercettato in questa sessione.")
        else
            print("|cffffcc00HCOB: ultimi errori intercettati|r")
            for i, e in ipairs(runtimeErrors) do print(i .. ") [" .. tostring(e.area) .. "] " .. tostring(e.message)) end
        end
        print("SmartSafe="..tostring(runtimeSmartDisabled).." CombatLogSafe="..tostring(runtimeCombatLogDisabled).." TelemetrySafe="..tostring(runtimeTelemetryDisabled))
    elseif cmd == "reseterrors" then runtimeErrors={}; runtimeSmartDisabled=false; runtimeCombatLogDisabled=false; runtimeTelemetryDisabled=false; print("|cff00ff98HCOB:|r fail-safe resettato."); UpdateDisplay()
    elseif cmd == "log" then
        local sub, rest = (arg or ""):match("^(%S+)%s*(.-)$")
        sub = sub or "status"
        if sub == "on" then HCOB_DB.combatLogging=true; runtimeTelemetryDisabled=false; print("|cff00ff98HCOB LOG:|r ON")
        elseif sub == "off" then if currentFight then SafeRun("TelemetryFinalize", FinalizeCombatTelemetry, "logging_off") end; HCOB_DB.combatLogging=false; print("|cff00ff98HCOB LOG:|r OFF")
        elseif sub == "last" then PrintLastCombatLog()
        elseif sub == "stats" then PrintCombatLogStats()
        elseif sub == "clear" then ClearCombatLog()
        elseif sub == "max" then
            local v=tonumber(rest); if v then HCOB_DB.combatLogMaxFights=Clamp(math.floor(v),10,200); TrimCombatLog(); print("|cff00ff98HCOB LOG:|r max fight salvati="..HCOB_DB.combatLogMaxFights) else print("/hcob log max 10-200") end
        elseif sub == "session" then
            InitCombatLogDB(); if rest and rest ~= "" then HCOB_CombatLog.session=rest; print("|cff00ff98HCOB LOG:|r session="..rest) else print("|cff00ff98HCOB LOG:|r session="..tostring(HCOB_CombatLog.session)) end
        elseif sub == "export" then
            InitCombatLogDB(); print("|cff00ff98HCOB LOG EXPORT:|r fai /reload per forzare il salvataggio, poi prendi WTF/Account/<account>/SavedVariables/HCOneButton.lua. Tabella: HCOB_CombatLog")
        else
            InitCombatLogDB(); print("|cff00ff98HCOB LOG:|r "..(HCOB_DB.combatLogging~=false and "ON" or "OFF").." | fight salvati="..#HCOB_CombatLog.fights.."/"..tostring(HCOB_DB.combatLogMaxFights).." | totale="..tostring(HCOB_CombatLog.totalFights).." | telemetrySafe="..tostring(runtimeTelemetryDisabled))
            print("/hcob log on|off | last | stats | export | clear | max 60 | session nome")
        end
    elseif cmd == "prof" then
        if HCOB_Professions and HCOB_Professions.HandleSlash then HCOB_Professions.HandleSlash(arg) else print("|cffff5555HCOB PROF:|r modulo non disponibile") end
    elseif cmd == "actions" then
        if InCombatLockdown() then print("|cffff5555HCOB:|r cambia il pannello azioni fuori combattimento."); return end
        local sub, value = (arg or ""):match("^(%S+)%s*(.-)$")
        sub = sub or "on"
        if sub == "scale" then
            local v = tonumber(value)
            if v then
                HCOB_DB.actionScale = Clamp(v,0.8,1.5)
                RefreshButtonState()
                print("|cff00ff98HCOB:|r actionScale="..tostring(HCOB_DB.actionScale))
            else
                print("|cffffcc00HCOB:|r /hcob actions scale 0.8-1.5")
            end
            return
        elseif sub == "binds" then
            if HCOB_ActionPanel then HCOB_ActionPanel.PrintSlotBindings() end
            return
        elseif sub == "bind" then
            local v = (value or ""):lower()
            if v == "off" then
                HCOB_DB.actionSlotAutoBind = false
                print("|cffffcc00HCOB:|r auto-bind slot azioni OFF (i bind gia' salvati restano invariati).")
            else
                HCOB_DB.actionSlotAutoBind = true
                if HCOB_ActionPanel then HCOB_ActionPanel.ApplySlotBindings(); HCOB_ActionPanel.PrintSlotBindings() end
                print("|cff00ff98HCOB:|r auto-bind slot azioni ON.")
            end
            return
        elseif sub == "off" then
            HCOB_DB.secureActions=false
        else
            HCOB_DB.secureActions=true
        end
        if HCOB_ActionPanel then HCOB_ActionPanel.Configure(); HCOB_ActionPanel.SyncVisibility(); HCOB_ActionPanel.UpdateStates() end
        print("|cff00ff98HCOB:|r azioni cliccabili="..tostring(HCOB_DB.secureActions ~= false).." scale="..tostring(HCOB_DB.actionScale or 1.0))
    elseif cmd == "dps" then
        Toggle("showDPSMeter", arg)
        -- Non toccare il SecureActionButton durante il combat per un semplice
        -- toggle del meter: il pannello DPS e' non-secure e puo' aggiornarsi da solo.
        UpdateDPSMeter()
    elseif cmd == "sound" then Toggle("soundAlerts", arg)
    elseif cmd == "swing" then Toggle("showSwing", arg)
    elseif cmd == "scale" then
        if InCombatLockdown() then print("|cffff5555HCOB:|r cambia scala fuori combattimento."); return end
        local v=tonumber(arg); if v then v=Clamp(v,0.7,1.6); HCOB_DB.scale=v; RefreshButtonState(); print("|cff00ff98HCOB:|r scale="..v) else print("/hcob scale 0.7-1.6") end
    elseif cmd == "danger" then
        local v=tonumber(arg); if v then HCOB_DB.dangerHP=Clamp(v,20,70); print("|cff00ff98HCOB:|r dangerHP="..HCOB_DB.dangerHP) end
    elseif cmd == "critical" then
        local v=tonumber(arg); if v then HCOB_DB.criticalHP=Clamp(v,10,40); print("|cff00ff98HCOB:|r criticalHP="..HCOB_DB.criticalHP) end
    elseif cmd == "status" or cmd == "test" then
        local _, localizedClass = UnitClass("player"); local si,sn=TalentSpec()
        local macro=btn:GetAttribute("macrotext1") or ""
        print("|cff00ff98HCOB v"..VERSION..":|r "..tostring(localizedClass).." L"..PlayerLevel().." spec="..tostring(sn).."("..si..") macro="..#macro.."/"..MACRO_LIMIT)
        print("SmartHUD="..tostring(HCOB_DB.smartDisplay ~= false).." safeMode="..tostring(runtimeSmartDisabled).." combatLogSafe="..tostring(runtimeCombatLogDisabled).." telemetrySafe="..tostring(runtimeTelemetryDisabled).." errors="..#runtimeErrors.." heroicBase=false heroicKnown="..tostring(IsKnown(S.HEROIC_STRIKE)).." hsRage="..tostring(HCOB_DB.warriorHeroicRage or 35).." autoRend="..tostring(currentWarriorAutoRend).." sunderAdaptive="..tostring(HCOB_DB.warriorSunderBase ~= false).." dpsMeter="..tostring(HCOB_DB.showDPSMeter ~= false).." hcDanger="..tostring(HCOB_DB.hcDangerAdvisor ~= false))
        PrintKeys()
    else
        print("|cff00ff98HC One Button v"..VERSION.."|r - tutte le classi Classic Era")
        print("/hcob bind BUTTON4 | Q   /hcob keys   /hcob bindtest [BUTTON4]   /hcob unbind BUTTON4")
        print("/hcob plan   /hcob mods   /hcob status   /hcob petfood   /hcob prof [on|off|refresh]   /hcob actions on|off|scale 1.0|bind on|off|binds")
        print("/hcob center   /hcob show|hide   /hcob lock|unlock   /hcob options   /hcob settings")
        print("/hcob scale 1.1")
        print("/hcob danger 35   /hcob critical 20   /hcob sound on|off   /hcob swing on|off   /hcob dps on|off")
        print("/hcob smart on|off   /hcob advisor on|off|debug   /hcob diagpixel on|off   /hcob rendspam on|off   /hcob sunder on|off   /hcob hsrage 35")
        print("/hcob errors   /hcob reseterrors")
        print("/hcob log last   /hcob log stats   /hcob log export   /hcob log on|off")
        print("Si aggiorna da solo con livello, trainer, talenti, equip e forme.")
    end
end

local eventFrame = CreateFrame("Frame")
local events = {
    "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED",
    "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_TALENT_UPDATE",
    "UNIT_POWER_UPDATE", "UNIT_HEALTH", "UNIT_AURA", "SPELL_UPDATE_COOLDOWN", "UPDATE_SHAPESHIFT_FORM",
    "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_PET", "PET_BAR_UPDATE", "UNIT_HAPPINESS",
    "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED",
    "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
}
for _, e in ipairs(events) do pcall(eventFrame.RegisterEvent, eventFrame, e) end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local eventArg1, eventArg2 = ...
    local function HandleEvent()
        if event == "PLAYER_LOGIN" then
            playerGUID = UnitGUID("player")
            RebuildKnownSpellNames()
            InitCombatLogDB()
            ApplyVisualTheme()
            CreateOptionsPanel()
            if PLAYER_CLASS == "HUNTER" then HCOB_Hunter.InvalidateFood() end
            BuildMacros()
            MigrateOldBindings()
            RefreshButtonState()
            UpdateDisplay()
            print("|cff00ff98HC One Button v"..VERSION.." caricato:|r " .. (UnitClass("player") or PLAYER_CLASS) .. " L" .. PlayerLevel() .. ". /hcob help")
        elseif event == "PLAYER_REGEN_DISABLED" then
            activeEnemies = {}; local tg=UnitGUID("target"); if tg then MarkEnemy(tg) end
            if HCOB_DB.combatLogging ~= false and not runtimeTelemetryDisabled then SafeRun("TelemetryStart", StartCombatTelemetry) end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if currentFight and HCOB_DB.combatLogging ~= false and not runtimeTelemetryDisabled then SafeRun("TelemetryFinalize", FinalizeCombatTelemetry, "combat_end") end
            activeEnemies = {}; activeTargetCast=nil
            if pendingRebuild then BuildMacros() end
            if HCOB_ActionPanel then HCOB_ActionPanel.SyncVisibility() end
            MigrateOldBindings()
        elseif event == "PLAYER_TARGET_CHANGED" then
            activeTargetCast=nil
            -- Legal smartness: out of combat we may rebuild the secure macro for
            -- the selected target (e.g. decide whether Rend is worth one GCD).
            if not InCombatLockdown() then BuildMacros() end
        elseif event == "PLAYER_LEVEL_UP" or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "UPDATE_SHAPESHIFT_FORM" or event == "UNIT_PET" or event == "PET_BAR_UPDATE" then
            if event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" then RebuildKnownSpellNames() end
            if PLAYER_CLASS == "HUNTER" and (event == "PLAYER_LEVEL_UP" or event == "UNIT_PET" or event == "PET_BAR_UPDATE") then HCOB_Hunter.InvalidateFood() end
            BuildMacros()
            if event == "PLAYER_LEVEL_UP" and C_Timer and C_Timer.After then
                C_Timer.After(1.0, function()
                    SafeRun("LevelUpRebuild", BuildMacros)
                    SafeRun("LevelUpPlan", PrintPlan)
                end)
            end
        elseif PLAYER_CLASS == "HUNTER" and (event == "BAG_UPDATE_DELAYED" or event == "UNIT_HAPPINESS" or event == "GET_ITEM_INFO_RECEIVED" or (event == "UNIT_AURA" and eventArg1 == "pet")) then
            local relevant = event ~= "GET_ITEM_INFO_RECEIVED" or HCOB_Hunter.foodDataPending
            if relevant then
                if event ~= "UNIT_AURA" then HCOB_Hunter.InvalidateFood() end
                if not InCombatLockdown() then BuildMacros() else pendingRebuild = true end
            end
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            SafeCombatLogHandler()
        elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
            local taintedBy, protectedFunction = eventArg1, eventArg2
            if taintedBy == addonName or taintedBy == "HCOneButton" then
                RecordRuntimeError(event, tostring(protectedFunction or "azione protetta"))
                runtimeSmartDisabled = true
            end
        end
    end

    local ok = SafeRun("Event:" .. tostring(event), HandleEvent)
    if not ok and event == "PLAYER_LOGIN" then
        print("|cffff5555HCOB:|r inizializzazione parziale. Il bind sicuro potrebbe richiedere /reload dopo /hcob errors.")
    end
end)

-- Niente più NewTicker a 0.12s: era il principale moltiplicatore degli errori.
-- Un singolo OnUpdate throttled mantiene l'HUD fluido ma limita drasticamente
-- il numero di chiamate e mette ogni aggiornamento dietro al fail-safe.
local updateDriver = CreateFrame("Frame")
local updateElapsed = 0
updateDriver:SetScript("OnUpdate", function(_, elapsed)
    updateElapsed = updateElapsed + (elapsed or 0)
    local interval = UnitAffectingCombat("player") and 0.20 or 0.50
    if updateElapsed < interval then return end
    updateElapsed = 0
    if currentFight and HCOB_DB.combatLogging ~= false and not runtimeTelemetryDisabled then
        local ok = SafeRun("TelemetrySample", SampleCombatTelemetry)
        if not ok then runtimeTelemetryDisabled = true end
    end
    UpdateDisplay()
end)
