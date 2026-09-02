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

function NotePlayerSpellcastSucceeded(spellID)
    local name = SpellName(spellID)
    if not name then return end
    playerSpellcastGrace[name] = GetTime() + PLAYER_BUFF_CAST_GRACE
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

