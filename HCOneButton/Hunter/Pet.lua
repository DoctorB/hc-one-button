-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local H = HCOB.Hunter


function HCOB.Hunter.ManaPct()
    local pct, readable = UnitPowerPct("player", 0)
    return readable and pct or 0
end

function HCOB.Hunter.PetAlive()
    return UnitExists("pet") and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("pet"))
end

function HCOB.Hunter.PetHP()
    if not HCOB.Hunter.PetAlive() then return nil end
    local hp, readable = UnitHealthPct("pet")
    if not readable then return nil end
    return hp
end

function HCOB.Hunter.PetIsTanking()
    if not HCOB.Hunter.PetAlive() or not UnitExists("targettarget") or not UnitIsUnit then return false end
    local ok, same = pcall(UnitIsUnit, "targettarget", "pet")
    return ok and SafeBoolean(same, false) or false
end


function HCOB.Hunter.TargetElapsed(inCombat)
    if not HostileLiveTarget() then return 0 end
    local guid = SafeUnitGUID("target")
    if not guid then return 0 end
    local now = GetTime()
    if HCOB.Hunter.engagedTargetGUID ~= guid then
        HCOB.Hunter.engagedTargetGUID = guid
        HCOB.Hunter.targetEngagedAt = inCombat and now or nil
    elseif inCombat and not HCOB.Hunter.targetEngagedAt then
        HCOB.Hunter.targetEngagedAt = now
    elseif not inCombat then
        HCOB.Hunter.targetEngagedAt = nil
    end
    return HCOB.Hunter.targetEngagedAt and math.max(0, now - HCOB.Hunter.targetEngagedAt) or 0
end

function HCOB.Hunter.ResetTargetState(inCombat)
    HCOB.Hunter.engagedTargetGUID = HostileLiveTarget() and SafeUnitGUID("target") or nil
    HCOB.Hunter.targetEngagedAt = (inCombat and HCOB.Hunter.engagedTargetGUID) and GetTime() or nil
    HCOB.Hunter.serpentGUID = nil
    HCOB.Hunter.serpentActive = false
    HCOB.Hunter.serpentPendingUntil = 0
    HCOB.Hunter.rangedStableSince = nil
end

-- Hunter attack-mode state. Classic has separate melee Auto Attack and ranged
-- Auto Shot states, plus a dead zone where either can be interrupted.  These
-- helpers are advisory only: protected attack changes still happen through the
-- secure BASE button.
function HCOB.Hunter.MeleeAutoActive()
    if not HostileLiveTarget() or not IsPlayerAttacking then return false end
    local ok, active = pcall(IsPlayerAttacking, "target")
    return ok and SafeBoolean(active, false) or false
end

function HCOB.Hunter.AutoShotActive()
    if not IsKnown(S.AUTO_SHOT) then return false end
    if HCOB.Hunter.autoRepeatActive == true then return true end
    if IsCurrentSpell then
        local ok, active = pcall(IsCurrentSpell, S.AUTO_SHOT)
        if ok and SafeBoolean(active, false) then return true end
    end
    if C_Spell and C_Spell.IsCurrentSpell then
        local ok, active = pcall(C_Spell.IsCurrentSpell, S.AUTO_SHOT)
        if ok and SafeBoolean(active, false) then return true end
    end
    return false
end

function HCOB.Hunter.AutoShotNeedsRestart()
    if not UnitAffectingCombat("player") or not HostileLiveTarget() then return false end
    if HCOB.Hunter.TargetIsClose() or not HCOB.Hunter.CanShootTarget() then return false end
    if HCOB.Hunter.AutoShotActive() then return false end
    if UnitCastingInfo then local ok, cast = pcall(UnitCastingInfo, "player"); if ok and cast ~= nil and (not CanAccessValue(cast) or cast) then return false end end
    if UnitChannelInfo then local ok, cast = pcall(UnitChannelInfo, "player"); if ok and cast ~= nil and (not CanAccessValue(cast) or cast) then return false end end

    local now = GetTime()
    local speed = HCOB.Hunter.RangedSpeed()
    local grace = speed > 0 and math.max(1.5, speed * 1.45) or 3.5
    if HCOB.Hunter.lastAutoShotAt and (now - HCOB.Hunter.lastAutoShotAt) <= grace then return false end
    if HCOB.Hunter.combatEnteredAt and (now - HCOB.Hunter.combatEnteredAt) <= 1.5 then return false end
    return true
end


-- -------------------------------------------------------------------------
-- Hunter pet feeding (Classic happiness system)
-- -------------------------------------------------------------------------
HCOB.Hunter.foodDirty = true
HCOB.Hunter.foodCandidate = nil
HCOB.Hunter.foodDataPending = false

HCOB.Hunter.dietAliases = {
    meat="Meat", fish="Fish", bread="Bread", cheese="Cheese", fruit="Fruit", fungus="Fungus",
}


-- Hunter management: threat and pet skill supervision.
function SpellNameByID(id, fallback)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok and info and info.name then return info.name end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, id)
        if ok and name then return name end
    end
    return fallback
end

function SafeUnitIsUnit(a, b)
    if not UnitIsUnit then return false end
    local ok, same = pcall(UnitIsUnit, a, b)
    return ok and SafeBoolean(same, false) or false
end


function H.ThreatSnapshot()
    local out = {
        state = "unknown",
        playerPct = nil,
        petPct = nil,
        playerTanking = false,
        petTanking = false,
    }
    if not UnitExists("target") or not UnitCanAttack("player", "target") then return out end

    if UnitDetailedThreatSituation then
        local okP, pTank, pStatus, pScaled = pcall(UnitDetailedThreatSituation, "player", "target")
        if okP then
            out.playerTanking = SafeBoolean(pTank, false)
            out.playerStatus = SafeNumber(pStatus, nil)
            out.playerPct = SafeNumber(pScaled, nil)
        end
        if UnitExists("pet") then
            local okPet, petTank, petStatus, petScaled = pcall(UnitDetailedThreatSituation, "pet", "target")
            if okPet then
                out.petTanking = SafeBoolean(petTank, false)
                out.petStatus = SafeNumber(petStatus, nil)
                out.petPct = SafeNumber(petScaled, nil)
            end
        end
    end

    local targetOnPlayer = UnitExists("targettarget") and SafeUnitIsUnit("targettarget", "player")
    local targetOnPet = UnitExists("targettarget") and UnitExists("pet") and SafeUnitIsUnit("targettarget", "pet")

    if targetOnPlayer or out.playerTanking or (out.playerStatus and out.playerStatus >= 3) then
        out.state = "lost"
    elseif out.petTanking or targetOnPet then
        local p = tonumber(out.playerPct) or 0
        if p >= 85 then out.state = "unstable"
        elseif p >= 65 then out.state = "rising"
        else out.state = "stable" end
    elseif out.playerPct and out.playerPct >= 85 then
        out.state = "unstable"
    elseif out.playerPct and out.playerPct >= 65 then
        out.state = "rising"
    end
    return out
end

function H.ThreatPenalty(snapshot)
    snapshot = snapshot or H.ThreatSnapshot()
    if snapshot.state == "lost" then return 28 end
    if snapshot.state == "unstable" then return 18 end
    if snapshot.state == "rising" then return 7 end
    return 0
end


function PetBookCount()
    if not HasPetSpells then return 0 end
    local ok, count = pcall(HasPetSpells)
    return ok and tonumber(count) or 0
end

function PetBookName(index)
    if C_SpellBook and C_SpellBook.GetSpellBookItemName and Enum and Enum.SpellBookSpellBank then
        local ok, name, subName = pcall(C_SpellBook.GetSpellBookItemName, index, Enum.SpellBookSpellBank.Pet)
        if ok then return name, subName end
    end
    if GetSpellBookItemName then
        local ok, name, subName, spellID = pcall(GetSpellBookItemName, index, BOOKTYPE_PET or "pet")
        if ok then return name, subName, spellID end
    end
end

function PetBookSpellID(index)
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank then
        local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, index, Enum.SpellBookSpellBank.Pet)
        if ok and info then return tonumber(info.spellID) or tonumber(info.actionID) end
    end
    if GetSpellBookItemInfo then
        local ok, _, id = pcall(GetSpellBookItemInfo, index, BOOKTYPE_PET or "pet")
        if ok and id then
            id = tonumber(id)
            if id and bit and bit.band then return bit.band(0xFFFFFF, id) end
            if id and bit32 and bit32.band then return bit32.band(0xFFFFFF, id) end
            return id
        end
    end
end

function H.PetSpellbook(force)
    local cache = H.managementCache
    local guid = UnitExists("pet") and SafeUnitGUID("pet") or nil
    if not force and not cache.petDirty and cache.petBook and cache.petGUID == guid then return cache.petBook end

    local entries = {}
    if guid then
        local count = PetBookCount()
        for i = 1, count do
            local name, subName, legacyID = PetBookName(i)
            if name then
                local spellID = PetBookSpellID(i) or tonumber(legacyID)
                local autocastable, autocast
                if GetSpellAutocast then
                    local ok, a, b = pcall(GetSpellAutocast, i, BOOKTYPE_PET or "pet")
                    if ok then autocastable, autocast = a and true or false, b and true or false end
                end
                entries[#entries + 1] = {index=i, name=name, subName=subName, spellID=spellID, autocastable=autocastable, autocast=autocast}
            end
        end
    end
    cache.petBook, cache.petGUID, cache.petDirty = entries, guid, false
    return entries
end

function H.PetSkillStatus(force)
    local status = {
        petExists = UnitExists("pet") and true or false,
        family = UnitExists("pet") and UnitCreatureFamily and UnitCreatureFamily("pet") or nil,
        level = UnitExists("pet") and SafeUnitLevel("pet", nil) or nil,
        totalPoints = nil, spentPoints = nil, availablePoints = nil,
        growlKnown = false, growlAutocastable = false, growlAutocast = false,
        bite = false, claw = false, dash = false, dive = false,
    }
    if not status.petExists then return status end

    if GetPetTrainingPoints then
        local ok, total, spent = pcall(GetPetTrainingPoints)
        if ok then
            status.totalPoints = tonumber(total)
            status.spentPoints = tonumber(spent)
            if status.totalPoints and status.spentPoints then status.availablePoints = math.max(0, status.totalPoints - status.spentPoints) end
        end
    end

    local names = {
        growl = SpellNameByID(HCOB.Hunter.PET_SKILL_IDS.growl, "Growl"),
        bite = SpellNameByID(HCOB.Hunter.PET_SKILL_IDS.bite, "Bite"),
        claw = SpellNameByID(HCOB.Hunter.PET_SKILL_IDS.claw, "Claw"),
        dash = SpellNameByID(HCOB.Hunter.PET_SKILL_IDS.dash, "Dash"),
        dive = SpellNameByID(HCOB.Hunter.PET_SKILL_IDS.dive, "Dive"),
    }
    for _, entry in ipairs(H.PetSpellbook(force)) do
        if entry.name == names.growl then
            status.growlKnown = true
            status.growlAutocastable = entry.autocastable and true or false
            status.growlAutocast = entry.autocast and true or false
        elseif entry.name == names.bite then status.bite = true
        elseif entry.name == names.claw then status.claw = true
        elseif entry.name == names.dash then status.dash = true
        elseif entry.name == names.dive then status.dive = true end
    end

    -- The pet bar can expose Growl autocast even if spellbook metadata is not
    -- ready yet. Use it as a second source, never as the only skill inventory.
    if GetPetActionInfo then
        for i = 1, 10 do
            local ok, name, _, _, _, autoAllowed, autoEnabled = pcall(GetPetActionInfo, i)
            if ok and name == names.growl then
                status.growlKnown = true
                status.growlAutocastable = autoAllowed and true or false
                status.growlAutocast = autoEnabled and true or false
                break
            end
        end
    end
    return status
end

