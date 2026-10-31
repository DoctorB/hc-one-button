-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

function AuraByName(unit, wantedName, filter, onlyMine)
    if not wantedName or not UnitExists(unit) then return false, 0 end

    -- Classic Era 1.15.x exposes C_UnitAuras. Prefer the structured API:
    -- avoid depending on the legacy UnitAura return order, which changed
    -- multiple times across Classic patches.
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local auraFilter = filter or "HELPFUL"
        if onlyMine then auraFilter = auraFilter .. "|PLAYER" end
        for i = 1, 40 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, auraFilter)
            if not ok then break end
            if not aura then break end
            if CanAccessTable(aura) then
                local name = SafeString(aura.name, nil)
                if name and name == wantedName then
                    local remains = 999
                    local duration = SafeNumber(aura.duration, 0) or 0
                    local expirationTime = SafeNumber(aura.expirationTime, 0) or 0
                    if duration > 0 and expirationTime > 0 then
                        remains = math.max(0, expirationTime - GetTime())
                    end
                    return true, remains
                end
            end
        end
        return false, 0
    end

    -- Legacy fallback, always protected: an incompatible API must never
    -- turn into an error flood while the button is being used.
    if UnitAura then
        for i = 1, 40 do
            local ok, name, _, _, _, duration, expirationTime, source = pcall(UnitAura, unit, i, filter)
            if not ok or not name then break end
            name = SafeString(name, nil)
            source = SafeString(source, nil)
            duration = SafeNumber(duration, 0) or 0
            expirationTime = SafeNumber(expirationTime, 0) or 0
            if name and name == wantedName and (not onlyMine or source == "player") then
                local remains = 999
                if duration > 0 and expirationTime > 0 then
                    remains = math.max(0, expirationTime - GetTime())
                end
                return true, remains
            end
        end
    end
    return false, 0
end

function HasPlayerBuff(id)
    return AuraByName("player", SpellName(id), "HELPFUL", false)
end

-- Classic can briefly report an empty aura list immediately after a cast or
-- during a UNIT_AURA burst. Keep a small, per-spell observation cache so a
-- transient miss cannot turn a maintained self aura into repeated Advisor
-- requests. A genuinely removed aura becomes eligible again after the grace
-- window; finite auras also become eligible as soon as their observed expiry
-- is reached.
local PLAYER_BUFF_MISSING_GRACE = 0.75
local PLAYER_BUFF_CAST_GRACE = 1.00
local playerBuffObservations = {}
local playerSpellcastGrace = {}
-- A target debuff reaches the client after UNIT_SPELLCAST_SUCCEEDED. Without
-- this window the same DoT stays recommended for that gap and a reader that
-- re-sends the shown slot casts it twice.
local TARGET_DEBUFF_CAST_GRACE = 1.50
local targetDebuffGrace = {}

function NotePlayerSpellcastSucceeded(spellID)
    local groupHealing = HCOB.Advisor and HCOB.Advisor.GroupHealing
    if groupHealing and groupHealing.IsOtherUnitCast(spellID) then return end
    local name = SpellName(spellID)
    if not name then return end
    local now = GetTime()
    playerSpellcastGrace[name] = now + PLAYER_BUFF_CAST_GRACE
    local guid = SafeUnitGUID and SafeUnitGUID("target")
    if guid then targetDebuffGrace[name] = {guid=guid, untilTime=now + TARGET_DEBUFF_CAST_GRACE} end
end

-- A cast-time DoT (Corruption/Immolate rank 1, Polymorph) leaves the cast bar
-- before UNIT_SPELLCAST_SUCCEEDED arrives. Start the window at cast start so
-- that gap cannot show the same slot again; only a failure of this very cast
-- (matched by castGUID) withdraws it.
function NotePlayerSpellcastStart(spellID, castGUID)
    local name = SpellName(spellID)
    local guid = SafeUnitGUID and SafeUnitGUID("target")
    if not name or not guid then return end
    local castSeconds = SpellCastSeconds and SpellCastSeconds(spellID) or 0
    targetDebuffGrace[name] = {guid=guid, castGUID=castGUID,
        untilTime=GetTime() + castSeconds + TARGET_DEBUFF_CAST_GRACE}
end

function NotePlayerSpellcastFailed(castGUID)
    if castGUID == nil then return end
    for name, grace in pairs(targetDebuffGrace) do
        if grace.castGUID == castGUID then targetDebuffGrace[name] = nil end
    end
end

local function StableUnitBuff(unit, id)
    local name = SpellName(id)
    if not name then return false, 0 end

    local now = GetTime()
    local cacheKey = tostring(unit) .. ":" .. name
    local state = playerBuffObservations[cacheKey]

    local castGraceUntil = playerSpellcastGrace[name] or 0
    if castGraceUntil > now then
        -- The old aura can remain visible for a frame after a successful
        -- refresh. Let the cast acknowledgement win so that old near-expiry
        -- metadata cannot immediately request the same spell again.
        return true, 999
    end
    playerSpellcastGrace[name] = nil

    local active, remaining = AuraByName(unit, name, "HELPFUL", false)
    remaining = SafeNumber(remaining, 0) or 0

    if active then
        state = state or {}
        state.expectedUntil = remaining >= 999 and math.huge or (now + math.max(0, remaining))
        state.missingSince = nil
        playerBuffObservations[cacheKey] = state
        playerSpellcastGrace[name] = nil
        return true, remaining
    end

    if state and (state.expectedUntil or 0) > now then
        state.missingSince = state.missingSince or now
        if (now - state.missingSince) < PLAYER_BUFF_MISSING_GRACE then
            local expected = state.expectedUntil == math.huge and 999 or math.max(0, state.expectedUntil - now)
            return true, expected
        end
    end

    if state then
        state.expectedUntil = 0
        state.missingSince = nil
    end
    return false, 0
end

function StablePlayerBuff(id)
    return StableUnitBuff("player", id)
end

function StablePetBuff(id)
    return StableUnitBuff("pet", id)
end

function HasMyTargetDebuff(id)
    return AuraByName("target", SpellName(id), "HARMFUL", true)
end

-- HasMyTargetDebuff plus the post-cast window, bound to the target the spell
-- was cast on. A resist leaves the debuff missing and it is offered again
-- once the window ends.
function StableMyTargetDebuff(id)
    local name = SpellName(id)
    if not name then return false, 0 end
    local active, remaining = AuraByName("target", name, "HARMFUL", true)
    local grace = targetDebuffGrace[name]
    if active then
        targetDebuffGrace[name] = nil
        return true, remaining
    end
    if grace and grace.untilTime > GetTime() and grace.guid == (SafeUnitGUID and SafeUnitGUID("target")) then
        return true, 999
    end
    return false, 0
end

