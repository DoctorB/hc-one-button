-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local H = HCOB.Hunter

function HCOB.Hunter.SpellRange(id)
    if not id or not HostileLiveTarget() then return nil end
    -- Name-first is rank safe on Classic: S.* may contain the rank-1 ID while
    -- the spellbook contains a higher rank.
    if IsSpellInRange then
        local name = SpellName(id)
        if name then
            local ok, inRange = pcall(IsSpellInRange, name, "target")
            if ok and inRange ~= nil and CanAccessValue(inRange) then return (inRange == 1 or inRange == true) and true or false end
        end
    end
    if C_Spell and C_Spell.IsSpellInRange then
        local ok, inRange = pcall(C_Spell.IsSpellInRange, id, "target")
        if ok and inRange ~= nil and CanAccessValue(inRange) then return SafeBoolean(inRange, false) end
    end
    return nil
end

function HCOB.Hunter.RangedProbe()
    if IsKnown(S.SERPENT_STING) then return S.SERPENT_STING end
    if IsKnown(S.ARCANE_SHOT) then return S.ARCANE_SHOT end
    if IsKnown(S.CONCUSSIVE_SHOT) then return S.CONCUSSIVE_SHOT end
    return nil
end

function HCOB.Hunter.TargetIsClose()
    if not HostileLiveTarget() then return false end

    -- Current range APIs are authoritative and must beat stale combat-log
    -- evidence. This prevents a melee hit from keeping the target "close"
    -- for seconds after it has already run back into ranged distance.
    if IsKnown(S.WING_CLIP) then
        local meleeRange = HCOB.Hunter.SpellRange(S.WING_CLIP)
        if meleeRange == true then return true end
    end

    local probe = HCOB.Hunter.RangedProbe()
    if probe then
        local ranged = HCOB.Hunter.SpellRange(probe)
        if ranged == true then return false end
    end

    if CheckInteractDistance then
        local ok, close = pcall(CheckInteractDistance, "target", 3)
        if ok and close then return true end
    end

    -- Combat-log fallback only. Keep it short: it is useful during API gaps,
    -- but must never override a fresh ranged result above.
    if HCOB.Hunter.lastMeleeAt and (GetTime() - HCOB.Hunter.lastMeleeAt) <= 1.15 then return true end
    return false
end

function HCOB.Hunter.RangedSpeed()
    if not UnitRangedDamage then return 0 end
    local ok, speed = pcall(UnitRangedDamage, "player")
    if not ok then return 0 end
    return tonumber(speed) or 0
end

function HCOB.Hunter.AfterAutoWindow()
    if not HCOB.Hunter.lastAutoShotAt then return false end
    local elapsed = GetTime() - HCOB.Hunter.lastAutoShotAt
    local speed = HCOB.Hunter.RangedSpeed()
    local window = 0.75
    if speed > 0 then window = math.min(0.85, math.max(0.45, speed * 0.28)) end
    return elapsed >= 0 and elapsed <= window
end

function HCOB.Hunter.AutoShotRange()
    if not HostileLiveTarget() then return nil end

    -- Auto Shot itself is the authoritative pull probe when Classic exposes a
    -- range result for it.  This fixes the old UI state where BASE looked ready
    -- even with the target well beyond bow/gun range.
    local autoRange = HCOB.Hunter.SpellRange(S.AUTO_SHOT)
    if autoRange ~= nil then return autoRange end

    -- Some Classic branches return nil for auto-repeat spells. Fall back to an
    -- actual ranged attack with a comparable maximum range, never Hunter's Mark
    -- (its long range would make the pull button look ready too early).
    local probe = HCOB.Hunter.RangedProbe()
    if probe then
        local ranged = HCOB.Hunter.SpellRange(probe)
        if ranged ~= nil then return ranged end
    end
    return nil
end

function HCOB.Hunter.CanShootTarget()
    if not HostileLiveTarget() then return false end
    if HCOB.Hunter.TargetIsClose() then return false end
    local ranged = HCOB.Hunter.AutoShotRange()
    if ranged ~= nil then return ranged end
    return true
end

function HCOB.Hunter.PullRangeState()
    if not HostileLiveTarget() then return "none" end
    if HCOB.Hunter.TargetIsClose() then return "close" end
    local ranged = HCOB.Hunter.AutoShotRange()
    if ranged == true then return "ready" end
    if ranged == false then return "out" end
    return "unknown"
end


-- Hunter management: ammunition logistics.
function BagFamilyHas(family, wanted)
    family = tonumber(family) or 0
    if wanted == "arrows" then return (family % 2) >= 1 end
    if wanted == "bullets" then return (math.floor(family / 2) % 2) >= 1 end
    return false
end


function H.RangedAmmoType()
    if not GetInventorySlotInfo or not GetInventoryItemLink or not GetItemInfo then return nil end
    local slot = GetInventorySlotInfo("RangedSlot")
    if not slot then return nil end
    local link = GetInventoryItemLink("player", slot)
    if not link then return nil end
    local classID = select(12, GetItemInfo(link))
    local subClassID = select(13, GetItemInfo(link))
    if classID ~= 2 then return nil end
    if subClassID == 3 then return "bullets" end
    if subClassID == 2 or subClassID == 18 then return "arrows" end
    return nil
end

function H.AmmoStatus(force)
    local cache = H.managementCache
    local now = GetTime and GetTime() or 0
    if not force and not cache.ammoDirty and cache.ammo and (now - (cache.ammoAt or 0)) < 2.0 then
        return cache.ammo
    end

    local ammoType = H.RangedAmmoType()
    local result = {required = ammoType ~= nil, ammoType = ammoType, total = 0, minutes = math.huge, level = "none", selectedName = nil}
    if not ammoType then
        cache.ammo, cache.ammoAt, cache.ammoDirty = result, now, false
        return result
    end

    local total = 0
    if GetInventorySlotInfo and GetInventoryItemCount then
        local ammoSlot = GetInventorySlotInfo("AmmoSlot")
        if ammoSlot then
            local count = tonumber(GetInventoryItemCount("player", ammoSlot)) or 0
            local link = GetInventoryItemLink and GetInventoryItemLink("player", ammoSlot) or nil
            local texture = GetInventoryItemTexture and GetInventoryItemTexture("player", ammoSlot) or nil
            if count == 1 and not link and not texture then count = 0 end
            total = total + math.max(0, count)
            if link and GetItemInfo then result.selectedName = GetItemInfo(link) end
        end
    end

    if GetItemFamily and H.BagSlots and H.BagItemID and H.BagItemMeta then
        for bag = 0, 4 do
            local slots = H.BagSlots(bag) or 0
            for slot = 1, slots do
                local itemID = H.BagItemID(bag, slot)
                if itemID then
                    local ok, family = pcall(GetItemFamily, itemID)
                    if ok and BagFamilyHas(family, ammoType) then
                        local _, count = H.BagItemMeta(bag, slot)
                        total = total + math.max(0, tonumber(count) or 0)
                    end
                end
            end
        end
    end

    local speed = H.RangedSpeed and H.RangedSpeed() or 2.8
    if not speed or speed <= 0 then speed = 2.8 end
    -- Auto Shot is the baseline drain. The 12% margin approximates additional
    -- shot abilities without pretending to know the exact future rotation.
    local estimatedShotsPerMinute = math.max(10, (60 / speed) * 1.12)
    local minutes = total > 0 and (total / estimatedShotsPerMinute) or 0
    local criticalMinutes = tonumber(HCOB_DB and HCOB_DB.hunterAmmoCriticalMinutes) or 8
    local lowMinutes = tonumber(HCOB_DB and HCOB_DB.hunterAmmoLowMinutes) or 20
    local level
    if total <= 0 then level = "empty"
    elseif total < 100 or minutes < criticalMinutes then level = "critical"
    elseif total < 300 or minutes < lowMinutes then level = "low"
    else level = "ok" end

    result.total = total
    result.minutes = minutes
    result.level = level
    result.shotsPerMinute = estimatedShotsPerMinute
    cache.ammo, cache.ammoAt, cache.ammoDirty = result, now, false
    return result
end

