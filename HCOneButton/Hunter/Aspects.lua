-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

-- Hunter aspect state is managed independently from the generic buff advisor.
-- This prevents Hawk/Monkey/Cheetah from fighting each other as ordinary buffs.
function HCOB.Hunter.ActiveAspect()
    if IsKnown(S.ASPECT_HAWK) and HasPlayerBuff(S.ASPECT_HAWK) then return S.ASPECT_HAWK end
    if IsKnown(S.ASPECT_MONKEY) and HasPlayerBuff(S.ASPECT_MONKEY) then return S.ASPECT_MONKEY end
    if IsKnown(S.ASPECT_CHEETAH) and HasPlayerBuff(S.ASPECT_CHEETAH) then return S.ASPECT_CHEETAH end
    return nil
end

function HCOB.Hunter.RangedStableSeconds(close, canShoot)
    local now = GetTime()
    if canShoot and not close then
        if not HCOB.Hunter.rangedStableSince then HCOB.Hunter.rangedStableSince = now end
        return math.max(0, now - HCOB.Hunter.rangedStableSince)
    end
    HCOB.Hunter.rangedStableSince = nil
    return 0
end

function HCOB.Hunter.TravelStableSeconds(inCombat, hostile)
    local moving = GetUnitSpeed and (tonumber(GetUnitSpeed("player")) or 0) > 0
    local mounted = IsMounted and IsMounted() or false
    local outdoors = true
    if IsOutdoors then
        local ok, value = pcall(IsOutdoors)
        if ok and value ~= nil then outdoors = value and true or false end
    end

    local travel = not inCombat and not hostile and moving and not mounted and outdoors
    local now = GetTime()
    if travel then
        if not HCOB.Hunter.travelStableSince then HCOB.Hunter.travelStableSince = now end
        return math.max(0, now - HCOB.Hunter.travelStableSince)
    end
    HCOB.Hunter.travelStableSince = nil
    return 0
end

function HCOB.Hunter.HasSerpentSting()
    if not HostileLiveTarget() then return false end
    if HasMyTargetDebuff(S.SERPENT_STING) then return true end
    local guid = SafeUnitGUID("target")
    if not guid or HCOB.Hunter.serpentGUID ~= guid then return false end
    if HCOB.Hunter.serpentActive then return true end
    return (HCOB.Hunter.serpentPendingUntil or 0) > GetTime()
end

function HCOB.Hunter.CanCastRanged(id)
    if not id or not IsKnown(id) or not HostileLiveTarget() then return false end
    if not IsUsable(id) then return false end
    local inRange = HCOB.Hunter.SpellRange(id)
    if inRange ~= nil then return inRange end
    return HCOB.Hunter.CanShootTarget() and not HCOB.Hunter.TargetIsClose()
end

-- Per-target timing is independent from the overall combat session. This is
-- critical for chain pulls: a fresh target selected while still in combat must
-- get a fresh setup window for Hunter's Mark, Serpent Sting and rolling TTK.
