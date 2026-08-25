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

function HasMyTargetDebuff(id)
    return AuraByName("target", SpellName(id), "HARMFUL", true)
end

