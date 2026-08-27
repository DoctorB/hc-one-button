-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

function HostileLiveTarget()
    return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
end


-- One rank-safe range query shared by the Advisor, BASE button, Action Panel
-- and Hunter logic. S.* constants frequently point at rank 1, while Classic's
-- spellbook may expose a higher rank as the castable spell.
function HCOB.Advisor.Engine.SpellRange(id, unit)
    unit = unit or "target"
    if not id or not UnitExists(unit) then return nil end
    if IsSpellInRange then
        local name = SpellName(id)
        if name then
            local ok, inRange = pcall(IsSpellInRange, name, unit)
            if ok and inRange ~= nil and CanAccessValue(inRange) then
                return (inRange == 1 or inRange == true) and true or false
            end
        end
    end
    if C_Spell and C_Spell.IsSpellInRange then
        local ok, inRange = pcall(C_Spell.IsSpellInRange, id, unit)
        if ok and inRange ~= nil and CanAccessValue(inRange) then
            return SafeBoolean(inRange, false)
        end
    end
    return nil
end


function HCOB.Advisor.Engine.SpellRangeBounds(id)
    if not id then return nil, nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok and type(info) == "table" then
            local minRange, maxRange = tonumber(info.minRange), tonumber(info.maxRange)
            if minRange or maxRange then return minRange, maxRange end
        end
    end
    if GetSpellInfo then
        local ok, _, _, _, _, minRange, maxRange = pcall(GetSpellInfo, id)
        if ok then
            minRange, maxRange = tonumber(minRange), tonumber(maxRange)
            if minRange or maxRange then return minRange, maxRange end
        end
        local name = SpellName(id)
        if name then
            local byName, _, _, _, nameMin, nameMax = GetSpellInfo(name)
            if byName then return tonumber(nameMin), tonumber(nameMax) end
        end
    end
    return nil, nil
end


-- Range feedback is limited to hostile ranged actions. Self buffs/heals and
-- melee skills must not turn into a misleading OUT OF RANGE warning merely
-- because the current target cannot receive them.
function HCOB.Advisor.Engine.IsRangedHostileSpell(id)
    if not id then return false end
    local name = SpellName(id)
    local harmful
    if C_Spell and C_Spell.IsSpellHarmful then
        local ok, value = pcall(C_Spell.IsSpellHarmful, id)
        if ok and value ~= nil and CanAccessValue(value) then harmful = SafeBoolean(value, false) end
    end
    if harmful == nil and IsHarmfulSpell and name then
        local ok, value = pcall(IsHarmfulSpell, name)
        if ok and value ~= nil and CanAccessValue(value) then harmful = SafeBoolean(value, false) end
    end
    if harmful ~= true then return false end
    local _, maxRange = HCOB.Advisor.Engine.SpellRangeBounds(id)
    return maxRange ~= nil and maxRange > 5
end


-- Visual state for the BASE action of caster/ranged classes. "ready" means
-- both actual target range and the immediate usable/cooldown state agree.
function HCOB.Advisor.Engine.RangedActionState(id)
    if not HostileLiveTarget() or not HCOB.Advisor.Engine.IsRangedHostileSpell(id) then return nil end
    local inRange = HCOB.Advisor.Engine.SpellRange(id, "target")
    if inRange == false then return "out" end
    if inRange == nil then return "unknown" end
    if not IsKnown(id) or not IsUsable(id) or not CooldownReady(id) then return "unavailable" end
    return "ready"
end


-- A ranged spell that cannot reach the target must never be presented as an
-- immediately executable Advisor action. Preserve safety severity, but turn
-- ordinary actions into an explicit caution with movement instructions.
function HCOB.Advisor.Engine.ApplyTargetCastability(spellId, title, keyHint, reason, kind)
    if not spellId or not HostileLiveTarget() or not HCOB.Advisor.Engine.IsRangedHostileSpell(spellId) then
        return spellId, title, keyHint, reason, kind
    end
    if HCOB.Advisor.Engine.SpellRange(spellId, "target") ~= false then
        return spellId, title, keyHint, reason, kind
    end
    local alertKind = (kind == "danger" or kind == "interrupt") and kind or "caution"
    local spellName = SpellName(spellId, title or "The recommended spell")
    return nil, "OUT OF RANGE", "MOVE CLOSER",
        spellName .. " cannot reach the current target. Move closer until the BASE/action border turns green.",
        alertKind
end


function HCOB.Advisor.Engine.TargetIsClose()
    if not HostileLiveTarget() then return false end
    if HCOB.Advisor.Engine.lastMeleeAt and (GetTime() - HCOB.Advisor.Engine.lastMeleeAt) <= 2.5 then return true end
    if CheckInteractDistance then
        local ok, close = pcall(CheckInteractDistance, "target", 3)
        if ok and CanAccessValue(close) then return SafeBoolean(close, false) end
    end
    return false
end

