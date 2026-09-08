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


local liveTargetCast, stoppedTargetCast

local function ReadTargetCast(api, channel, guid, now)
    if type(api) ~= "function" then return nil, false end
    local ok, name, _, _, startMS, endMS, _, seventh, eighth, ninth = pcall(api, "target")
    if not ok then return nil, false end
    if name == nil then return nil, true end
    if not CanAccessValue(name) or type(name) ~= "string" then return nil, false end
    local startAt, endAt = SafeNumber(startMS, nil), SafeNumber(endMS, nil)
    if not startAt or not endAt or endAt <= startAt then return nil, false end
    startAt, endAt = startAt / 1000, endAt / 1000
    if endAt <= now or startAt > now + 0.15 then return nil, true end
    -- Classic signatures may omit notInterruptible, shifting spellID left.
    -- A numeric spellID must never be treated as a true immunity flag.
    local flag, id
    if channel then flag, id = seventh, eighth else flag, id = eighth, ninth end
    if type(flag) == "number" and id == nil then id, flag = flag, nil end
    local interruptible
    if CanAccessValue(flag) and type(flag) == "boolean" then interruptible = not flag end
    return {guid=guid, name=name, spellId=SafeNumber(id, nil), startedAt=startAt,
        expires=endAt, remaining=endAt-now, channel=channel, source="unit",
        interruptible=interruptible}, true
end

function ActiveTargetCast()
    local guid, now = SafeUnitGUID("target"), GetTime()
    if not guid then activeTargetCast, liveTargetCast, stoppedTargetCast = nil, nil, nil; return nil end
    local cast, castReadable = ReadTargetCast(UnitCastingInfo, false, guid, now)
    local channel, channelReadable = ReadTargetCast(UnitChannelInfo, true, guid, now)
    if cast or channel then
        local current = cast or channel
        if stoppedTargetCast and stoppedTargetCast.guid == guid
           and stoppedTargetCast.spellId == current.spellId
           and current.startedAt <= stoppedTargetCast.at
           and (not stoppedTargetCast.startedAt or current.startedAt == stoppedTargetCast.startedAt) then return nil end
        if liveTargetCast and liveTargetCast.guid == guid and liveTargetCast.spellId == current.spellId
           and liveTargetCast.startedAt == current.startedAt then current.castGUID = liveTargetCast.castGUID end
        liveTargetCast, stoppedTargetCast = current, nil
        return liveTargetCast
    end
    if liveTargetCast then
        if liveTargetCast.guid == guid and castReadable and channelReadable then
            -- A previously visible cast has ended. Never resurrect its CLEU estimate.
            activeTargetCast, liveTargetCast = nil, nil
            return nil
        end
        liveTargetCast = nil
    end
    -- Era may expose no unit data for NPCs (notably channels). Preserve the
    -- bounded combat-event estimate, explicitly unknown rather than immune.
    if not activeTargetCast then return nil end
    if activeTargetCast.guid ~= guid or now >= activeTargetCast.expires then
        activeTargetCast = nil
        return nil
    end
    activeTargetCast.remaining = activeTargetCast.expires - now
    activeTargetCast.source = "combat_event"
    return activeTargetCast
end

function HandleTargetCastEvent(event, unit, castGUID, spellID)
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        activeTargetCast, liveTargetCast, stoppedTargetCast = nil, nil, nil
        return
    end
    if unit ~= "target" then return end
    if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
       or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
       or event == "UNIT_SPELLCAST_CHANNEL_INTERRUPTED" then
        -- Ignore a delayed stop from a different known spell/cast instance.
        local current = liveTargetCast or activeTargetCast
        if current and current.castGUID and castGUID and current.castGUID ~= castGUID then return end
        if current and current.spellId and spellID and current.spellId ~= spellID then return end
        stoppedTargetCast = {guid=SafeUnitGUID("target"), spellId=spellID or (current and current.spellId),
            startedAt=current and current.startedAt, at=GetTime()}
        activeTargetCast, liveTargetCast = nil, nil
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local current = ActiveTargetCast()
        if current then current.castGUID = castGUID end
    end
end


function InterruptRecommendation(cast)
    if cast and cast.remaining and cast.remaining <= 0.15 then return nil end
    local class = HCOB.Classes and HCOB.Classes[PLAYER_CLASS]
    if class and class.GetInterruptRecommendation then
        local id, title, key, reason = class:GetInterruptRecommendation(cast)
        -- Immunity to interrupts is not immunity to stun/incapacitate. Preserve
        -- existing class-owned control fallbacks, without claiming they will land.
        if id and cast and cast.interruptible == false then
            local control = id == S.GOUGE or id == S.HAMMER_JUSTICE or id == S.BASH
                or id == S.SCATTER_SHOT or id == S.INTIMIDATION
            if not control then return nil end
        end
        return id, title, key, reason
    end
    return nil
end
