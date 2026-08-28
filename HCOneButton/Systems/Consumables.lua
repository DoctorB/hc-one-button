-- HCOneButton survival consumable inventory model.
-- Item choice is read-only here. Secure button attributes are owned by
-- UI/SurvivalStrip.lua and are changed only outside combat lockdown.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local C = HCOB.Systems.Consumables

C.roleOrder = {"healingPotion", "healthstone", "manaPotion", "bandage"}
C.roleLabels = {
    healingPotion = "HEAL",
    healthstone = "STONE",
    manaPotion = "MANA",
    bandage = "BANDAGE",
}
C.roleDescriptions = {
    healingPotion = "Best healing potion in your bags",
    healthstone = "Best Healthstone in your bags",
    manaPotion = "Best mana potion in your bags",
    bandage = "Best bandage in your bags",
}

-- Strongest first. `level` is the fallback item-use requirement when the
-- client cache cannot expose it; `tier` is used only for the empty-slot icon.
C.catalog = {
    healingPotion = {
        {id=13446, name="Major Healing Potion", level=45},
        {id=3928,  name="Superior Healing Potion", level=35},
        {id=1710,  name="Greater Healing Potion", level=21},
        {id=929,   name="Healing Potion", level=12},
        {id=858,   name="Lesser Healing Potion", level=3},
        {id=118,   name="Minor Healing Potion", level=1},
    },
    healthstone = {
        {id=19013, name="Major Healthstone", tier=48}, {id=19012, name="Major Healthstone", tier=48}, {id=9421, name="Major Healthstone", tier=48},
        {id=19011, name="Greater Healthstone", tier=36}, {id=19010, name="Greater Healthstone", tier=36}, {id=5510, name="Greater Healthstone", tier=36},
        {id=19009, name="Healthstone", tier=24}, {id=19008, name="Healthstone", tier=24}, {id=5509, name="Healthstone", tier=24},
        {id=19007, name="Lesser Healthstone", tier=12}, {id=19006, name="Lesser Healthstone", tier=12}, {id=5511, name="Lesser Healthstone", tier=12},
        {id=19005, name="Minor Healthstone", tier=1}, {id=19004, name="Minor Healthstone", tier=1}, {id=5512, name="Minor Healthstone", tier=1},
    },
    manaPotion = {
        {id=13444, name="Major Mana Potion", level=49},
        {id=13443, name="Superior Mana Potion", level=41},
        {id=6149,  name="Greater Mana Potion", level=31},
        {id=3827,  name="Mana Potion", level=22},
        {id=3385,  name="Lesser Mana Potion", level=14},
        {id=2455,  name="Minor Mana Potion", level=5},
    },
    bandage = {
        {id=14530, name="Heavy Runecloth Bandage", tier=50},
        {id=14529, name="Runecloth Bandage", tier=45},
        {id=8545,  name="Heavy Mageweave Bandage", tier=40},
        {id=8544,  name="Mageweave Bandage", tier=35},
        {id=6451,  name="Heavy Silk Bandage", tier=30},
        {id=6450,  name="Silk Bandage", tier=25},
        {id=3531,  name="Heavy Wool Bandage", tier=20},
        {id=3530,  name="Wool Bandage", tier=15},
        {id=2581,  name="Heavy Linen Bandage", tier=10},
        {id=1251,  name="Linen Bandage", tier=1},
    },
}

local function ItemCount(itemID)
    if not GetItemCount then return 0 end
    local ok, count = pcall(GetItemCount, itemID, false, false)
    return ok and math.max(0, tonumber(count) or 0) or 0
end

C.GetItemCount = ItemCount

local function CachedItemInfo(entry)
    local name, minLevel, icon
    if C_Item and C_Item.GetItemNameByID then
        local ok, value = pcall(C_Item.GetItemNameByID, entry.id)
        if ok then name = value end
    end
    if C_Item and C_Item.GetItemIconByID then
        local ok, value = pcall(C_Item.GetItemIconByID, entry.id)
        if ok then icon = value end
    end
    if GetItemInfo then
        local ok, infoName, _, _, _, infoMinLevel, _, _, _, _, infoIcon = pcall(GetItemInfo, entry.id)
        if ok then
            name = infoName or name
            minLevel = tonumber(infoMinLevel)
            icon = infoIcon or icon
        end
    end
    return name or entry.name, minLevel, icon
end

local function PlayerItemLevel()
    if PlayerLevel then return math.max(1, tonumber(PlayerLevel()) or 1) end
    if UnitLevel then
        local ok, level = pcall(UnitLevel, "player")
        if ok then return math.max(1, tonumber(level) or 1) end
    end
    return 1
end

local function ItemRecord(role, entry, count, expected)
    local name, minLevel, icon = CachedItemInfo(entry)
    return {
        role=role, id=entry.id, name=name, icon=icon,
        count=tonumber(count) or 0, minLevel=tonumber(minLevel) or tonumber(entry.level) or 0,
        available=(tonumber(count) or 0) > 0, expected=expected and true or false,
    }
end

function C.RequestItemData()
    if not C_Item or not C_Item.RequestLoadItemDataByID then return end
    for _, role in ipairs(C.roleOrder) do
        for _, entry in ipairs(C.catalog[role] or {}) do
            pcall(C_Item.RequestLoadItemDataByID, entry.id)
        end
    end
end

function C.FindBest(role)
    local level = PlayerItemLevel()
    for _, entry in ipairs(C.catalog[role] or {}) do
        local count = ItemCount(entry.id)
        if count > 0 then
            local record = ItemRecord(role, entry, count, false)
            if record.minLevel <= level then return record end
        end
    end
    return nil
end

function C.FindExpected(role)
    local level = PlayerItemLevel()
    local list = C.catalog[role] or {}
    for _, entry in ipairs(list) do
        local tier = tonumber(entry.tier) or tonumber(entry.level) or 1
        if tier <= level then return ItemRecord(role, entry, 0, true) end
    end
    local last = list[#list]
    return last and ItemRecord(role, last, 0, true) or nil
end

function C.Refresh()
    local snapshot = {roles={}, refreshedAt=GetTime and GetTime() or 0}
    for _, role in ipairs(C.roleOrder) do
        local selected = C.FindBest(role)
        snapshot.roles[role] = selected or C.FindExpected(role)
    end
    C.snapshot = snapshot
    return snapshot
end

function C.GetSnapshot(refresh)
    if refresh or not C.snapshot then return C.Refresh() end
    return C.snapshot
end

function C.RefreshCountsOnly()
    local snapshot = C.GetSnapshot(false)
    for _, role in ipairs(C.roleOrder) do
        local item = snapshot and snapshot.roles and snapshot.roles[role]
        if item then
            item.count = ItemCount(item.id)
            item.available = item.count > 0
        end
    end
    return snapshot
end

function C.GetRole(role, refresh)
    local snapshot = C.GetSnapshot(refresh)
    return snapshot and snapshot.roles and snapshot.roles[role] or nil
end

function C.GetCooldown(itemID)
    if not itemID then return 0, 0, false, 0 end
    local startTime, duration, enabled
    if C_Container and C_Container.GetItemCooldown then
        local ok, a, b, c = pcall(C_Container.GetItemCooldown, itemID)
        if ok then startTime, duration, enabled = a, b, c end
    end
    if startTime == nil and C_Item and C_Item.GetItemCooldown then
        local ok, info = pcall(C_Item.GetItemCooldown, itemID)
        if ok and type(info) == "table" then
            startTime, duration, enabled = info.startTime, info.duration, info.isEnabled
        end
    end
    if startTime == nil and GetItemCooldown then
        local ok, a, b, c = pcall(GetItemCooldown, itemID)
        if ok then startTime, duration, enabled = a, b, c end
    end
    startTime, duration = tonumber(startTime) or 0, tonumber(duration) or 0
    if enabled == false or enabled == 0 then return startTime, duration, false, 0 end
    local remaining = 0
    if startTime > 0 and duration > 0 then
        remaining = math.max(0, startTime + duration - ((GetTime and GetTime()) or 0))
    end
    return startTime, duration, true, remaining
end

function C.IsImmediatelyUsable(item)
    if not item or not item.available or (tonumber(item.count) or 0) <= 0 then return false end
    local _, _, enabled, remaining = C.GetCooldown(item.id)
    if not enabled or remaining > 0.05 then return false end
    if IsUsableItem then
        local ok, usable = pcall(IsUsableItem, item.id)
        if ok and usable ~= nil then return usable == true or usable == 1 end
    end
    return true
end

function C.HasHealingStock()
    for _, role in ipairs({"healthstone", "healingPotion", "bandage"}) do
        local item = C.GetRole(role)
        if item and item.available then return true end
    end
    return false
end

function C.IsRecentlyBandaged()
    if not AuraByName then return false end
    local name = SpellName and SpellName(11196, "Recently Bandaged") or "Recently Bandaged"
    local active = AuraByName("player", name, "HARMFUL", false)
    return active == true
end

function C.HealingCooldownState()
    local stocked, ready, shortest = false, false, nil
    for _, role in ipairs({"healthstone", "healingPotion", "bandage"}) do
        local item = C.GetRole(role)
        if item and item.available then
            stocked = true
            local _, _, enabled, remaining = C.GetCooldown(item.id)
            local locked = role == "bandage" and C.IsRecentlyBandaged()
            if enabled and remaining <= 0.05 and not locked then ready = true end
            if remaining and (shortest == nil or remaining < shortest) then shortest = remaining end
        end
    end
    return stocked, ready, shortest or 0
end

function C.SelectHealingRole(inCombat)
    local order = inCombat and {"healthstone", "healingPotion"}
        or {"bandage", "healthstone", "healingPotion"}
    for _, role in ipairs(order) do
        local item = C.GetRole(role)
        if item and item.available then
            if C.IsImmediatelyUsable(item) and not (role == "bandage" and C.IsRecentlyBandaged()) then
                return role
            end
        end
    end
    return nil
end

function C.RecommendForState(hp, inCombat)
    hp = tonumber(hp) or 100
    local threshold = inCombat and ((HCOB_DB and tonumber(HCOB_DB.dangerHP)) or 35) or 85
    if hp <= threshold then
        return C.SelectHealingRole(inCombat)
    end
    if inCombat and UnitPowerType and UnitPowerPct then
        local powerType, token = UnitPowerType("player")
        if token == "MANA" then
            local mana, readable = UnitPowerPct("player", powerType)
            local item = C.GetRole("manaPotion")
            if readable and (tonumber(mana) or 100) <= 20 and C.IsImmediatelyUsable(item) then
                return "manaPotion"
            end
        end
    end
    return nil
end

function C.PrintStatus()
    if InCombatLockdown and InCombatLockdown() then C.RefreshCountsOnly() else C.Refresh() end
    print("|cff00ff98HCOB SURVIVAL:|r secure assignments update out of combat")
    for _, role in ipairs(C.roleOrder) do
        local item = C.GetRole(role)
        local remaining = 0
        if item then
            local _, _, _, value = C.GetCooldown(item.id)
            remaining = value
        end
        print(string.format("  %-7s %s x%d%s", C.roleLabels[role] or role,
            item and item.name or "unavailable", item and item.count or 0,
            remaining and remaining > 0.05 and (" | cooldown " .. math.ceil(remaining) .. "s") or ""))
    end
end
