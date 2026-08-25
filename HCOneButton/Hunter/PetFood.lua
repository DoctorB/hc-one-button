-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

function HCOB.Hunter.InvalidateFood()
    HCOB.Hunter.foodDirty = true
end

function HCOB.Hunter.Happiness()
    if not GetPetHappiness or not HCOB.Hunter.PetAlive() then return nil, nil, nil end
    local ok, happiness, damagePct, loyaltyRate = pcall(GetPetHappiness)
    if not ok then return nil, nil, nil end
    return tonumber(happiness), tonumber(damagePct), tonumber(loyaltyRate)
end

function HCOB.Hunter.PetIsEating()
    if not HCOB.Hunter.PetAlive() then return false, 0 end
    local effectName = SpellName(S.FEED_PET_EFFECT, "Feed Pet Effect")
    local has, remains = AuraByName("pet", effectName, "HELPFUL", false)
    return has and true or false, tonumber(remains) or 0
end

function HCOB.Hunter.CanonicalDietName(name)
    if type(name) ~= "string" or name == "" then return nil end
    if name == "Meat" or name == "Fish" or name == "Bread" or name == "Cheese" or name == "Fruit" or name == "Fungus" then return name end
    local lower = string.lower(name)
    local direct = HCOB.Hunter.dietAliases[lower]
    if direct then return direct end
    -- Conservative fallback for minor label variations.
    for token, canonical in pairs(HCOB.Hunter.dietAliases) do
        if string.find(lower, token, 1, true) then return canonical end
    end
    return nil
end

function HCOB.Hunter.PetDietSet()
    local result = {}
    if not GetPetFoodTypes or not HCOB.Hunter.PetAlive() then return result end
    local ok, foods = pcall(function() return { GetPetFoodTypes() } end)
    if not ok or type(foods) ~= "table" then return result end
    for _, foodType in ipairs(foods) do
        local canonical = HCOB.Hunter.CanonicalDietName(foodType)
        if canonical then result[canonical] = true end
    end
    return result
end

function HCOB.Hunter.PetDietText()
    local set = HCOB.Hunter.PetDietSet()
    local list = {}
    for _, name in ipairs({"Meat","Fish","Bread","Cheese","Fruit","Fungus"}) do
        if set[name] then list[#list+1] = name end
    end
    if #list == 0 then return "unknown" end
    return table.concat(list, "/")
end

function HCOB.Hunter.BagSlots(bag)
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

function HCOB.Hunter.BagItemID(bag, slot)
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

function HCOB.Hunter.BagItemMeta(bag, slot)
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

function HCOB.Hunter.IsQuestBagItem(bag, slot)
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

function HCOB.Hunter.FoodTier(itemLevel)
    local petLevel = SafeUnitLevel("pet", PlayerLevel()) or PlayerLevel()
    itemLevel = tonumber(itemLevel) or 0
    local diff = math.max(0, petLevel - itemLevel)
    if diff <= 15 then return 3 end
    if diff <= 25 then return 2 end
    if diff <= 35 then return 1 end
    return 0
end

function HCOB.Hunter.RefreshFoodCandidate(force)
    if PLAYER_CLASS ~= "HUNTER" then return nil end
    if not force and not HCOB.Hunter.foodDirty then return HCOB.Hunter.foodCandidate end
    if InCombatLockdown and InCombatLockdown() then return HCOB.Hunter.foodCandidate end

    HCOB.Hunter.foodDirty = false
    HCOB.Hunter.foodDataPending = false
    HCOB.Hunter.foodCandidate = nil

    if not HCOB.Hunter.PetAlive() or type(HCOB.Data.PetFoodDB) ~= "table" then return nil end
    local diet = HCOB.Hunter.PetDietSet()
    if not next(diet) then return nil end

    local playerLevel = PlayerLevel()
    local best
    for bag = 0, 4 do
        local slots = HCOB.Hunter.BagSlots(bag)
        for slot = 1, slots do
            local itemID = HCOB.Hunter.BagItemID(bag, slot)
            local food = itemID and HCOB.Data.PetFoodDB[itemID]
            if food and diet[food.category] then
                local locked, count = HCOB.Hunter.BagItemMeta(bag, slot)
                if not locked and not HCOB.Hunter.IsQuestBagItem(bag, slot) then
                    local name, _, _, itemLevel, minLevel = GetItemInfo and GetItemInfo(itemID)
                    if not name then
                        HCOB.Hunter.foodDataPending = true
                        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
                    else
                        itemLevel = tonumber(itemLevel) or 0
                        minLevel = tonumber(minLevel) or 0
                        local tier = HCOB.Hunter.FoodTier(itemLevel)
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
    HCOB.Hunter.foodCandidate = best
    return best
end

function HCOB.Hunter.FoodCandidate()
    return HCOB.Hunter.RefreshFoodCandidate(false)
end

function HCOB.Hunter.FeedMacro()
    local mendName = IsKnown(S.MEND_PET) and SpellName(S.MEND_PET, "Mend Pet") or nil
    local feedName = IsKnown(S.FEED_PET) and SpellName(S.FEED_PET, "Feed Pet") or nil
    local eating = HCOB.Hunter.PetIsEating()
    local happiness = HCOB.Hunter.Happiness()
    local food = (not eating and happiness and happiness < 3 and feedName) and HCOB.Hunter.FoodCandidate() or nil
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

function HCOB.Hunter.PrintFoodStatus()
    if PLAYER_CLASS ~= "HUNTER" then
        print("|cffffcc00HCOB:|r /hcob petfood is available only for Hunters.")
        return
    end
    if not HCOB.Hunter.PetAlive() then
        print("|cffffcc00HCOB PET:|r no living pet is currently summoned.")
        return
    end
    local happiness, damagePct, loyaltyRate = HCOB.Hunter.Happiness()
    local happyText = ({[1]="UNHAPPY", [2]="CONTENT", [3]="HAPPY"})[happiness] or "?"
    local eating, remains = HCOB.Hunter.PetIsEating()
    local food = HCOB.Hunter.RefreshFoodCandidate(not UnitAffectingCombat("player"))
    print(string.format("|cff00ff98HCOB PET:|r %s | damage=%s%% | loyalty=%s | diet=%s", happyText, tostring(damagePct or "?"), tostring(loyaltyRate or "?"), HCOB.Hunter.PetDietText()))
    if eating then
        print(string.format("|cff00ff98HCOB PET:|r is eating (%.0fs remaining): ALT+CTRL feeding is locked.", remains or 0))
    elseif food then
        print(string.format("|cff00ff98HCOB PET:|r selected %s x%d (bag %d slot %d, %s, tier %d).", food.name, food.count or 1, food.bag, food.slot, food.category, food.tier or 0))
    else
        print("|cffffcc00HCOB PET:|r no compatible/useful pet food found in the bags.")
    end
end

