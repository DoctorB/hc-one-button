-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

function SpellInfo(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if info then return info.name, info.iconID, info.castTime or 0 end
    end
    if GetSpellInfo then
        local name, _, icon, castTime = GetSpellInfo(id)
        return name, icon, castTime or 0
    end
end

function SpellName(id, fallback)
    local name = SpellInfo(id)
    return name or fallback
end

function SpellIcon(id, fallbackTexture)
    if id then
        local _, icon = SpellInfo(id)
        if icon then return icon end
        if C_Spell and C_Spell.GetSpellTexture then
            local ok, texture = pcall(C_Spell.GetSpellTexture, id)
            if ok and texture then return texture end
        end
        if GetSpellTexture then
            local ok, texture = pcall(GetSpellTexture, id)
            if ok and texture then return texture end
        end
    end
    return fallbackTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function SpellCastSeconds(id)
    local _, _, ms = SpellInfo(id)
    if not ms or ms <= 0 then return 3 end
    return Clamp(ms / 1000, 0.5, 8)
end

knownSpellNames = {}

function RebuildKnownSpellNames()
    local cache = {}
    -- Classic abilities have separate spellIDs per rank.  Checking only the
    -- rank-1 ID can therefore return false even though a higher rank is in the
    -- spellbook.  Cache localized spell names from the actual player spellbook.
    if C_SpellBook and C_SpellBook.GetSpellBookItemName and Enum and Enum.SpellBookSpellBank then
        for i = 1, 600 do
            local ok, name = pcall(C_SpellBook.GetSpellBookItemName, i, Enum.SpellBookSpellBank.Player)
            if not ok or not name then break end
            cache[name] = true
        end
    elseif GetSpellBookItemName then
        local book = BOOKTYPE_SPELL or "spell"
        for i = 1, 600 do
            local ok, name = pcall(GetSpellBookItemName, i, book)
            if not ok or not name then break end
            cache[name] = true
        end
    end
    knownSpellNames = cache
end

function IsKnown(id)
    if not id then return false end
    -- A true exact-ID answer is authoritative. A false answer is NOT: on
    -- Classic it may simply mean the player knows a higher rank of the spell.
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and known == true then return true end
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, id)
        if ok and known == true then return true end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, id)
        if ok and known == true then return true end
    end
    local name = SpellName(id)
    return name and knownSpellNames[name] == true or false
end

function IsUsable(id)
    if not IsKnown(id) then return false end
    -- Prefer the localized spell name on Classic. The constants in S often
    -- point at rank-1 spellIDs while the player may only have a higher rank
    -- in the spellbook; exact-ID usability can therefore return a false
    -- negative even though /cast SpellName is perfectly valid.
    if IsUsableSpell then
        local name = SpellName(id)
        if name then
            local ok, usable = pcall(IsUsableSpell, name)
            if ok and usable ~= nil and CanAccessValue(usable) then return SafeBoolean(usable, false) end
        end
    end
    if C_Spell and C_Spell.IsSpellUsable then
        local ok, usable = pcall(C_Spell.IsSpellUsable, id)
        if ok and usable ~= nil and CanAccessValue(usable) then return SafeBoolean(usable, false) end
    end
    return false
end

function CooldownRemaining(id)
    if not id then return 999 end
    local startTime, duration, enabled
    if C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(id)
        if cd then
            startTime, duration, enabled = cd.startTime, cd.duration, cd.isEnabled
        end
    elseif GetSpellCooldown then
        startTime, duration, enabled = GetSpellCooldown(id)
    end
    startTime = SafeNumber(startTime, nil)
    duration = SafeNumber(duration, nil)
    if enabled ~= nil and not CanAccessValue(enabled) then return 999 end
    if enabled == false or enabled == 0 then return 999 end
    if startTime == nil or duration == nil then return 999 end
    if startTime == 0 or duration == 0 then return 0 end
    return math.max(0, startTime + duration - GetTime())
end

function CooldownReady(id)
    return CooldownRemaining(id) <= 0.05
end

-- Heroic Strike and Cleave are not ordinary instant casts: they are queued
-- and replace the next main-hand auto attack. Keep their client queue state
-- and swing timing in one shared place so class policy, display stabilization
-- and combat-log tracking agree on the same mechanic.
function IsQueuedMeleeSwingSpell(id)
    if id ~= S.HEROIC_STRIKE and id ~= S.CLEAVE then return false end
    if not IsCurrentSpell then return false end
    local name = SpellName(id)
    if not name then return false end
    local ok, queued = pcall(IsCurrentSpell, name)
    return ok and SafeBoolean(queued, false) or false
end

function MainhandSwingQueueOpen()
    if not GetTime or not MainhandSpeed then return true, nil, nil end
    local speed = MainhandSpeed()
    if not speed or speed <= 0 or lastAutoAttack == nil then
        -- Before the first measurable swing, keep the old safe fallback: the
        -- Advisor may recommend the dump instead of hiding it indefinitely.
        return true, nil, nil
    end
    local remaining = math.max(0, speed - math.max(0, GetTime() - lastAutoAttack))
    -- Stabilization confirms a normal recommendation for 0.20s. This window
    -- leaves roughly 0.25-0.45s of visible time afterwards, enough for a 50Hz
    -- reader without occupying the full duration of a slow weapon swing.
    local queueWindow = Clamp(speed * 0.17, 0.45, 0.65)
    return remaining <= queueWindow, remaining, queueWindow
end

function IsMainhandSwingCombatEvent(subevent, spellId)
    if subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" then return true end
    if subevent ~= "SPELL_DAMAGE" and subevent ~= "SPELL_MISSED" then return false end
    return spellId == S.HEROIC_STRIKE or spellId == S.CLEAVE
end

