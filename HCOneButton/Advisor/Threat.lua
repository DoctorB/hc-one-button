-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

function CountActiveEnemies()
    local now, count = GetTime(), 0
    for guid, seen in pairs(activeEnemies) do
        if now - seen > (HCOB_DB.enemyWindow or 6) then
            activeEnemies[guid] = nil
        else
            count = count + 1
        end
    end
    -- Do NOT add the selected target implicitly. A selected hostile is not
    -- necessarily part of the current fight. Only real combat-log exchanges
    -- qualify a GUID for multi-aggro warnings.
    return count
end

function MarkEnemy(guid)
    if guid and guid ~= playerGUID then activeEnemies[guid] = GetTime() end
end

function RemoveEnemy(guid)
    if guid then activeEnemies[guid] = nil end
end

-- -------------------------------------------------------------------------
-- Advisor Engine 2.0
-- Common prediction/stability layer. All classes except Druid currently propose scored candidates;

function HCOB.Advisor.Engine.PetAlive()
    return UnitExists("pet") and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("pet"))
end

function HCOB.Advisor.Engine.PetHP()
    if not HCOB.Advisor.Engine.PetAlive() then return 0 end
    local hp, readable = UnitHealthPct("pet")
    return readable and hp or 0
end

function HCOB.Advisor.Engine.TargetOnPlayer()
    if not UnitExists("targettarget") or not UnitIsUnit then return false end
    local ok, same = pcall(UnitIsUnit, "targettarget", "player")
    return ok and SafeBoolean(same, false) or false
end

function HCOB.Advisor.Engine.TargetOnPet()
    if not HCOB.Advisor.Engine.PetAlive() or not UnitExists("targettarget") or not UnitIsUnit then return false end
    local ok, same = pcall(UnitIsUnit, "targettarget", "pet")
    return ok and SafeBoolean(same, false) or false
end

function HCOB.Advisor.Engine.PlayerIsGrouped()
    if IsInGroup then
        local ok, grouped = pcall(IsInGroup)
        if ok and grouped ~= nil then return grouped and true or false end
    end
    return UnitExists("party1") or UnitExists("raid1") or false
end

function HCOB.Advisor.Engine.PlayerHasDebuff(id)
    return AuraByName("player", SpellName(id), "HARMFUL", false)
end

function HCOB.Advisor.Engine.TargetCreatureTypeID()
    if not HostileLiveTarget() or not UnitCreatureType then return nil end
    local ok, _, creatureTypeID = pcall(UnitCreatureType, "target")
    if not ok then return nil end
    return creatureTypeID
end

function HCOB.Advisor.Engine.TotemActive(id)
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


function ActiveTargetCast()
    if not activeTargetCast then return nil end
    if activeTargetCast.guid ~= SafeUnitGUID("target") or GetTime() > activeTargetCast.expires then
        activeTargetCast = nil
        return nil
    end
    return activeTargetCast
end


function InterruptRecommendation()
    local class = HCOB.Classes and HCOB.Classes[PLAYER_CLASS]
    if class and class.GetInterruptRecommendation then
        return class:GetInterruptRecommendation()
    end
    return nil
end
