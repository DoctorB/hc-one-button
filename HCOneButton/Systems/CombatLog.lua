-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local COMBAT_LOG_VERSION = 12
local FIGHT_SCHEMA_VERSION = 13
local GLOBAL_FIGHT_HARD_CAP = 600

function InitCombatLogDB()
    HCOB_CombatLog.version = COMBAT_LOG_VERSION
    if type(HCOB_CombatLog.fights) ~= "table" then
        HCOB_CombatLog.fights = {}
        HCOB.RecordSavedVariableRepair("HCOB_CombatLog.fights")
    else
        for i = #HCOB_CombatLog.fights, 1, -1 do
            if type(HCOB_CombatLog.fights[i]) ~= "table" then
                table.remove(HCOB_CombatLog.fights, i)
                HCOB.RecordSavedVariableRepair("HCOB_CombatLog.fights[]")
            end
        end
    end

    local totalFights = tonumber(HCOB_CombatLog.totalFights)
    if HCOB_CombatLog.totalFights ~= nil and type(HCOB_CombatLog.totalFights) ~= "number" then
        HCOB.RecordSavedVariableRepair("HCOB_CombatLog.totalFights")
    end
    HCOB_CombatLog.totalFights = math.max(0, math.floor(totalFights or 0))

    if type(HCOB_CombatLog.session) ~= "string" or HCOB_CombatLog.session == "" then
        if HCOB_CombatLog.session ~= nil then HCOB.RecordSavedVariableRepair("HCOB_CombatLog.session") end
        HCOB_CombatLog.session = "HCOneButton " .. VERSION
    end
    -- Only update the automatic session name; a custom name
    -- set with /hcob log session remains untouched.
    if HCOB_CombatLog.session:match("^HCOneButton %d+%.%d+%.%d+$") then
        HCOB_CombatLog.session = "HCOneButton " .. VERSION
    end
end

function CurrentCombatLogProfileId()
    local id = type(HCOB_CharacterDB) == "table" and HCOB_CharacterDB.logProfileId or nil
    if type(id) == "string" and id ~= "" then return id end
    return nil
end

function CurrentCombatLogSession()
    local session = type(HCOB_CharacterDB) == "table" and HCOB_CharacterDB.logSession or nil
    if type(session) == "string" and session ~= "" then return session end
    session = type(HCOB_CombatLog) == "table" and HCOB_CombatLog.session or nil
    if type(session) == "string" and session ~= "" then return session end
    return "HCOneButton " .. VERSION
end

-- New records use an anonymous per-character profile. Pre-1.28.6 records do
-- not have one, so retain a class-only fallback for historical continuity.
-- A legacy same-class record cannot be disambiguated retroactively, but every
-- fight recorded from this version onward is isolated even across two
-- characters of the same class.
function FightBelongsToCurrentCharacter(f)
    if type(f) ~= "table" or f.class ~= PLAYER_CLASS then return false end
    local fightProfile = f.profileId
    if type(fightProfile) == "string" and fightProfile ~= "" then
        local currentProfile = CurrentCombatLogProfileId()
        return currentProfile ~= nil and fightProfile == currentProfile
    end
    if fightProfile ~= nil then return false end
    return true
end

function CurrentCharacterFights(limit)
    local fights = type(HCOB_CombatLog) == "table" and type(HCOB_CombatLog.fights) == "table" and HCOB_CombatLog.fights or {}
    local reverse = {}
    local wanted = tonumber(limit)
    if wanted then wanted = math.max(0, math.floor(wanted)) end
    if wanted == 0 then return {} end
    for i=#fights,1,-1 do
        local f = fights[i]
        if FightBelongsToCurrentCharacter(f) then
            reverse[#reverse + 1] = f
            if wanted and #reverse >= wanted then break end
        end
    end
    local result = {}
    for i=#reverse,1,-1 do result[#result + 1] = reverse[i] end
    return result
end

function LastCurrentCharacterFight()
    local fights = type(HCOB_CombatLog) == "table" and type(HCOB_CombatLog.fights) == "table" and HCOB_CombatLog.fights or {}
    for i=#fights,1,-1 do
        if FightBelongsToCurrentCharacter(fights[i]) then return fights[i] end
    end
    return nil
end

function RecentCharacterDPSAverage(limit)
    local fights = type(HCOB_CombatLog) == "table" and type(HCOB_CombatLog.fights) == "table" and HCOB_CombatLog.fights or {}
    local need = math.max(1, math.floor(tonumber(limit) or 5))
    for pass=1,2 do
        local damage, duration, count = 0, 0, 0
        for i=#fights,1,-1 do
            local f = fights[i]
            if FightBelongsToCurrentCharacter(f) and (pass == 2 or f.addonVersion == VERSION) then
                local d = tonumber(f.totalDamage) or 0
                local t = tonumber(f.duration) or 0
                if t > 0 then
                    damage = damage + d
                    duration = duration + t
                    count = count + 1
                    if count >= need then break end
                end
            end
        end
        if count > 0 then return duration > 0 and damage / duration or 0, count end
    end
    return 0, 0
end

function CurrentPowerSnapshot()
    local pType, pToken = UnitPowerType("player")
    pType = SafeNumber(pType, 0) or 0
    local value = SafeUnitPower("player", pType, 0) or 0
    local maxValue = SafeUnitPowerMax("player", pType, 0) or 0
    return pType, pToken or "POWER", value, maxValue
end

function EquipmentTelemetrySnapshot()
    local mh, oh, ranged
    if GetInventoryItemID then
        mh = GetInventoryItemID("player", 16)
        oh = GetInventoryItemID("player", 17)
        ranged = GetInventoryItemID("player", 18)
    end

    local ap = 0
    if UnitAttackPower then
        local base, pos, neg = UnitAttackPower("player")
        ap = (SafeNumber(base, 0) or 0) + (SafeNumber(pos, 0) or 0) + (SafeNumber(neg, 0) or 0)
    end

    local minDamage, maxDamage = 0, 0
    if UnitDamage then
        local a, b = UnitDamage("player")
        minDamage, maxDamage = SafeNumber(a, 0) or 0, SafeNumber(b, 0) or 0
    end

    local mainSpeed, offSpeed = 0, 0
    if UnitAttackSpeed then
        local a, b = UnitAttackSpeed("player")
        mainSpeed, offSpeed = SafeNumber(a, 0) or 0, SafeNumber(b, 0) or 0
    end

    local rangedSpeed, rangedMin, rangedMax = 0, 0, 0
    if UnitRangedDamage then
        local a, b, c = UnitRangedDamage("player")
        rangedSpeed, rangedMin, rangedMax = SafeNumber(a, 0) or 0, SafeNumber(b, 0) or 0, SafeNumber(c, 0) or 0
    end
    local rangedAP = 0
    if UnitRangedAttackPower then
        local base, pos, neg = UnitRangedAttackPower("player")
        rangedAP = (SafeNumber(base, 0) or 0) + (SafeNumber(pos, 0) or 0) + (SafeNumber(neg, 0) or 0)
    end

    return {
        mainHandItem=mh, offHandItem=oh, rangedItem=ranged,
        attackPower=ap, damageMin=minDamage, damageMax=maxDamage,
        mainHandSpeed=mainSpeed, offHandSpeed=offSpeed,
        rangedAttackPower=rangedAP, rangedSpeed=rangedSpeed, rangedDamageMin=rangedMin, rangedDamageMax=rangedMax,
    }
end

function TableCount(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

function AddEnemyToFight(guid, name)
    if not currentFight or not guid or guid == playerGUID then return end
    currentFight._enemies = currentFight._enemies or {}
    if not currentFight._enemies[guid] then
        currentFight._enemies[guid] = name or "Unknown"
    elseif name and name ~= "" then
        currentFight._enemies[guid] = name
    end
    currentFight.maxEnemies = math.max(currentFight.maxEnemies or 1, TableCount(currentFight._enemies))
end

function IsPlayerOrPetGUID(guid)
    if not guid then return false end
    if guid == playerGUID then return true end
    local petGUID = SafeUnitGUID("pet")
    return petGUID and guid == petGUID or false
end

function MarkFightKill(guid)
    if not currentFight or not guid then return end
    currentFight._killed = currentFight._killed or {}
    if currentFight._killed[guid] then return end
    currentFight._killed[guid] = true
    currentFight.kills = (tonumber(currentFight.kills) or 0) + 1
end

function AbilityRecord(owner, spellId, spellName)
    if not currentFight then return nil end
    owner = owner or "player"
    currentFight.abilities = currentFight.abilities or {}
    currentFight.petAbilities = currentFight.petAbilities or {}
    local bucket = owner == "pet" and currentFight.petAbilities or currentFight.abilities
    local sid = tonumber(spellId) or 0
    local name = spellName or (sid > 0 and SpellName(sid)) or "Auto Attack"
    local key = tostring(sid) .. ":" .. tostring(name)
    local a = bucket[key]
    if not a then
        a = { id=sid, name=tostring(name), casts=0, hits=0, crits=0, misses=0, damage=0, overkill=0, absorbed=0, blocked=0, resisted=0, missTypes={} }
        bucket[key] = a
    end
    return a
end

function StartCombatTelemetry()
    if HCOB_DB.combatLogging == false or runtimeTelemetryDisabled then return end
    InitCombatLogDB()
    local pType, pToken, power, powerMax = CurrentPowerSnapshot()
    local hp = SafeUnitHealth("player", 0) or 0
    local hpMax = SafeUnitHealthMax("player", 0) or 0
    local specIndex, specName, specPoints = TalentSpec()
    local targetName = UnitExists("target") and SafeUnitName("target", nil) or nil
    local targetLevel = UnitExists("target") and SafeUnitLevel("target", nil) or nil
    local classification = UnitExists("target") and SafeUnitClassification("target", nil) or nil
    local targetHpPctStart = nil
    if UnitExists("target") then
        local pct, readable = UnitHealthPct("target")
        if readable then targetHpPctStart = pct end
    end
    local equip = EquipmentTelemetrySnapshot()
    currentFight = {
        schema=FIGHT_SCHEMA_VERSION, addonVersion=VERSION, session=CurrentCombatLogSession(), profileId=CurrentCombatLogProfileId(),
        startedAt=(GetServerTime and GetServerTime()) or (time and time()) or 0,
        startClock=GetTime(), duration=0,
        class=PLAYER_CLASS, level=PlayerLevel(), spec=specName, specIndex=specIndex, specPoints=specPoints,
        mainHandItem=equip.mainHandItem, offHandItem=equip.offHandItem, rangedItem=equip.rangedItem,
        attackPowerStart=equip.attackPower, damageMinStart=equip.damageMin, damageMaxStart=equip.damageMax,
        mainHandSpeed=equip.mainHandSpeed, offHandSpeed=equip.offHandSpeed,
        rangedAttackPowerStart=equip.rangedAttackPower, rangedSpeed=equip.rangedSpeed,
        rangedDamageMinStart=equip.rangedDamageMin, rangedDamageMaxStart=equip.rangedDamageMax,
        zone=(GetZoneText and GetZoneText()) or "", subZone=(GetSubZoneText and GetSubZoneText()) or "",
        target=targetName, targetLevel=targetLevel, targetClassification=classification,
        targetGuid=SafeUnitGUID("target"), targetHpPctStart=targetHpPctStart,
        hpStart=hp, hpMax=hpMax, hpMin=hp, hpEnd=hp,
        hpMinPct=(hpMax > 0 and hp / hpMax * 100) or 100,
        powerType=pToken, powerStart=power, powerMax=powerMax, powerMin=power, powerPeak=power,
        powerSamples=1, powerSum=power,
        powerHighSamples=(powerMax > 0 and power >= powerMax * 0.80) and 1 or 0,
        powerCapSamples=(powerMax > 0 and power >= powerMax * 0.99) and 1 or 0,
        damageDone=0, petDamage=0, damageTaken=0, healingDone=0,
        maxHitDone=0, maxHitTaken=0, outgoingHits=0, incomingHits=0,
        crits=0, misses=0, dodges=0, parries=0, blocks=0, resists=0,
        kills=0, died=false, maxEnemies=1,
        abilities={}, petAbilities={}, _enemies={}, _killed={},
        baseClicks=0, heroicQueuedSamples=0,
        advisorSamples=0, advisorDangerSamples=0, advisorCautionSamples=0,
        advisorInterruptSamples=0, advisorManualSamples=0,
        advisorDangerEvents=0, advisorCautionEvents=0,
        survivalReserveSum=0, survivalReserveSamples=0, survivalReserveMin=100,
        advisorTrace={}, advisorTraceDropped=0,
    }
    if InitFightTuningTelemetry then InitFightTuningTelemetry(currentFight) end
    local tg = SafeUnitGUID("target")
    if tg and UnitCanAttack("player", "target") then AddEnemyToFight(tg, targetName) end
end

function SampleCombatTelemetry()
    if not currentFight or runtimeTelemetryDisabled then return end
    local hp = SafeUnitHealth("player", 0) or 0
    local hpMax = SafeUnitHealthMax("player", SafeNumber(currentFight.hpMax, 0)) or 0
    currentFight.hpEnd = hp
    currentFight.hpMax = math.max(tonumber(currentFight.hpMax) or 0, hpMax)
    currentFight.hpMin = math.min(tonumber(currentFight.hpMin) or hp, hp)
    if hpMax > 0 then currentFight.hpMinPct = math.min(tonumber(currentFight.hpMinPct) or 100, hp / hpMax * 100) end
    local _, _, power, powerMax = CurrentPowerSnapshot()
    currentFight.powerMax = math.max(tonumber(currentFight.powerMax) or 0, powerMax)
    currentFight.powerMin = math.min(tonumber(currentFight.powerMin) or power, power)
    currentFight.powerPeak = math.max(tonumber(currentFight.powerPeak) or power, power)
    currentFight.powerSamples = (tonumber(currentFight.powerSamples) or 0) + 1
    currentFight.powerSum = (tonumber(currentFight.powerSum) or 0) + power
    if powerMax > 0 and power >= powerMax * 0.80 then currentFight.powerHighSamples = (tonumber(currentFight.powerHighSamples) or 0) + 1 end
    if powerMax > 0 and power >= powerMax * 0.99 then currentFight.powerCapSamples = (tonumber(currentFight.powerCapSamples) or 0) + 1 end
    if PLAYER_CLASS == "WARRIOR" and IsCurrentSpell and SpellName(S.HEROIC_STRIKE) then
        local ok, queued = pcall(IsCurrentSpell, SpellName(S.HEROIC_STRIKE))
        if ok and SafeBoolean(queued, false) then currentFight.heroicQueuedSamples = (tonumber(currentFight.heroicQueuedSamples) or 0) + 1 end
    end
    currentFight.duration = math.max(0, GetTime() - (currentFight.startClock or GetTime()))
    if SampleTuningResources then SampleTuningResources(currentFight) end
end

function TrimCombatLog()
    InitCombatLogDB()
    local maxFights = Clamp(tonumber(HCOB_DB.combatLogMaxFights) or 60, 10, 200)
    local retained = 0
    for i=#HCOB_CombatLog.fights,1,-1 do
        if FightBelongsToCurrentCharacter(HCOB_CombatLog.fights[i]) then
            retained = retained + 1
            if retained > maxFights then table.remove(HCOB_CombatLog.fights, i) end
        end
    end

    -- Per-character quotas prevent one class from immediately evicting every
    -- other character. Keep an absolute account-wide ceiling as a final guard
    -- against unbounded SavedVariables growth on accounts with many alts.
    local globalLimit = math.max(maxFights, math.min(GLOBAL_FIGHT_HARD_CAP, maxFights * 10))
    while #HCOB_CombatLog.fights > globalLimit do table.remove(HCOB_CombatLog.fights, 1) end
end

function FinalizeCombatTelemetry(reason)
    if not currentFight then return end
    SampleCombatTelemetry()
    local f = currentFight
    f.endedAt = (GetServerTime and GetServerTime()) or (time and time()) or 0
    f.endReason = reason or "combat_end"
    f.duration = math.max(0.05, tonumber(f.duration) or 0.05)
    f.hpEnd = SafeUnitHealth("player", SafeNumber(f.hpEnd, 0)) or 0
    local _, _, power = CurrentPowerSnapshot()
    f.powerEnd = power
    local equipEnd = EquipmentTelemetrySnapshot()
    f.attackPowerEnd = equipEnd.attackPower
    f.rangedAttackPowerEnd = equipEnd.rangedAttackPower
    f.powerAvg = ((tonumber(f.powerSamples) or 0) > 0) and ((tonumber(f.powerSum) or 0) / f.powerSamples) or power
    local samples = math.max(1, tonumber(f.powerSamples) or 1)
    f.powerHighPct = (tonumber(f.powerHighSamples) or 0) / samples * 100
    f.powerCapPct = (tonumber(f.powerCapSamples) or 0) / samples * 100
    f.heroicQueuedPct = (tonumber(f.heroicQueuedSamples) or 0) / samples * 100
    local advisorSamples = math.max(1, tonumber(f.advisorSamples) or 1)
    f.advisorDangerPct = (tonumber(f.advisorDangerSamples) or 0) / advisorSamples * 100
    f.advisorCautionPct = (tonumber(f.advisorCautionSamples) or 0) / advisorSamples * 100
    f.advisorInterruptPct = (tonumber(f.advisorInterruptSamples) or 0) / advisorSamples * 100
    f.advisorManualPct = (tonumber(f.advisorManualSamples) or 0) / advisorSamples * 100
    f.survivalReserveAvg = ((tonumber(f.survivalReserveSamples) or 0) > 0) and ((tonumber(f.survivalReserveSum) or 0) / f.survivalReserveSamples) or nil
    f.totalDamage = (tonumber(f.damageDone) or 0) + (tonumber(f.petDamage) or 0)
    f.dps = f.totalDamage / f.duration
    f.playerDps = (tonumber(f.damageDone) or 0) / f.duration
    f.dtps = (tonumber(f.damageTaken) or 0) / f.duration
    if FinalizeFightTuningTelemetry then FinalizeFightTuningTelemetry(f) end
    currentFight = nil
    f.enemies = {}
    for _, name in pairs(f._enemies or {}) do f.enemies[#f.enemies+1] = name end
    table.sort(f.enemies)
    f._enemies = nil
    f._killed = nil
    f._feedbackLastKey = nil
    f.targetGuid = nil
    f.startClock = nil
    InitCombatLogDB()
    HCOB_CombatLog.totalFights = HCOB_CombatLog.totalFights + 1
    f.id = HCOB_CombatLog.totalFights
    HCOB_CombatLog.fights[#HCOB_CombatLog.fights + 1] = f
    TrimCombatLog()
    if UpdateDPSMeter then pcall(UpdateDPSMeter) end
end

function IsDamageEvent(subevent)
    return subevent == "SWING_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or
           subevent == "RANGE_DAMAGE" or subevent == "DAMAGE_SHIELD" or subevent == "DAMAGE_SPLIT"
end

function IsMissEvent(subevent)
    return subevent == "SWING_MISSED" or subevent == "SPELL_MISSED" or subevent == "SPELL_PERIODIC_MISSED" or subevent == "RANGE_MISSED"
end

function DamagePayload(args, subevent)
    if subevent == "SWING_DAMAGE" then
        return 6603, "Auto Attack", SafeNumber(args[12], 0) or 0, SafeNumber(args[13], 0) or 0,
               SafeNumber(args[15], 0) or 0, SafeNumber(args[16], 0) or 0, SafeNumber(args[17], 0) or 0, SafeBoolean(args[18], false)
    end
    return SafeNumber(args[12], 0) or 0, SafeString(args[13], "Spell"), SafeNumber(args[15], 0) or 0, SafeNumber(args[16], 0) or 0,
           SafeNumber(args[18], 0) or 0, SafeNumber(args[19], 0) or 0, SafeNumber(args[20], 0) or 0, SafeBoolean(args[21], false)
end

function MissPayload(args, subevent)
    if subevent == "SWING_MISSED" then return 6603, "Auto Attack", SafeString(args[12], "MISS") end
    return SafeNumber(args[12], 0) or 0, SafeString(args[13], "Spell"), SafeString(args[15], "MISS")
end

function CombatLogFlagIsHostile(flags)
    if not flags then return true end
    if bit and bit.band and COMBATLOG_OBJECT_REACTION_HOSTILE then
        return bit.band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0
    end
    return true
end

function CombatLogFlagIsPlayer(flags)
    if not flags or not bit or not bit.band or not COMBATLOG_OBJECT_TYPE_PLAYER then return false end
    return bit.band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0
end

local function PlayerControlled(flags)
    if CombatLogFlagIsPlayer(flags) then return true end
    return flags and bit and bit.band and COMBATLOG_OBJECT_CONTROL_PLAYER
        and bit.band(flags, COMBATLOG_OBJECT_CONTROL_PLAYER) ~= 0
end

function ProcessCombatTelemetry(args)
    if HCOB_DB.combatLogging == false or runtimeTelemetryDisabled then return end
    if not currentFight and UnitAffectingCombat("player") then StartCombatTelemetry() end
    if not currentFight then return end

    local subevent = SafeString(args[2], nil)
    if not subevent then return end
    local sourceGUID, sourceName = SafeString(args[4], nil), SafeString(args[5], "Unknown")
    local destGUID, destName = SafeString(args[8], nil), SafeString(args[9], "Unknown")
    local sourceFlags, destFlags = SafeNumber(args[6], nil), SafeNumber(args[10], nil)
    local petGUID = SafeUnitGUID("pet")
    local owner = sourceGUID == playerGUID and "player" or (petGUID and sourceGUID == petGUID and "pet" or nil)
    local destIsOurs = destGUID == playerGUID or (petGUID and destGUID == petGUID)
    local sourceIsOther = sourceGUID and not IsPlayerOrPetGUID(sourceGUID)
    local destIsOther = destGUID and not IsPlayerOrPetGUID(destGUID)

    local damageExchange = IsDamageEvent(subevent) or IsMissEvent(subevent)
    local controlExchange = subevent == "SPELL_INTERRUPT" or subevent == "SPELL_STOLEN"
        or ((subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH") and args[15] == "DEBUFF")
    -- Damage/misses are direct evidence even for neutral duels. For control,
    -- require a hostile reaction too: friendly spells can apply debuffs such as
    -- Weakened Soul and must not contaminate PvE learning.
    if currentFight.tuning and currentFight.tuning.context
       and ((destIsOurs and sourceIsOther and PlayerControlled(sourceFlags)
                and (damageExchange or (controlExchange and CombatLogFlagIsHostile(sourceFlags))))
         or (owner and destIsOther and PlayerControlled(destFlags)
                and (damageExchange or (controlExchange and CombatLogFlagIsHostile(destFlags))))) then
        currentFight.tuning.context.pvp = true
        currentFight.tuning.context.mode = "pvp"
        currentFight.tuning.adaptiveContextKey = nil
    end

    -- v1.6: no HOSTILE/NEUTRAL filter. A GUID becomes a "fight enemy"
    -- when it actually exchanges damage/misses with the player or pet. This includes
    -- yellow/neutral mobs that do not have the HOSTILE reaction flag in Classic.
    if IsDamageEvent(subevent) or IsMissEvent(subevent) then
        if owner and destIsOther then AddEnemyToFight(destGUID, destName) end
        if destIsOurs and sourceIsOther then AddEnemyToFight(sourceGUID, sourceName) end
    end

    if IsDamageEvent(subevent) then
        local spellId, name, amount, overkill, resisted, blocked, absorbed, critical = DamagePayload(args, subevent)
        if owner and destIsOther then
            local a = AbilityRecord(owner, spellId, name)
            a.hits = a.hits + 1; a.damage = a.damage + amount; a.overkill = a.overkill + math.max(0, overkill)
            a.resisted = a.resisted + resisted; a.blocked = a.blocked + blocked; a.absorbed = a.absorbed + absorbed
            if critical then a.crits = a.crits + 1 end
            if owner == "player" then
                currentFight.damageDone = currentFight.damageDone + amount
                currentFight.outgoingHits = currentFight.outgoingHits + 1
                currentFight.maxHitDone = math.max(currentFight.maxHitDone, amount)
                if critical then currentFight.crits = currentFight.crits + 1 end
                if RecordTuningQueueOutcome then
                    RecordTuningQueueOutcome(spellId, "consumed")
                end
            else
                currentFight.petDamage = currentFight.petDamage + amount
            end
        elseif destGUID == playerGUID and sourceIsOther then
            currentFight.damageTaken = currentFight.damageTaken + amount
            currentFight.incomingHits = currentFight.incomingHits + 1
            currentFight.maxHitTaken = math.max(currentFight.maxHitTaken, amount)
        end
    elseif IsMissEvent(subevent) then
        local spellId, name, missType = MissPayload(args, subevent)
        if owner and destIsOther then
            local a = AbilityRecord(owner, spellId, name)
            a.misses = a.misses + 1
            a.missTypes[missType] = (a.missTypes[missType] or 0) + 1
            if owner == "player" then
                currentFight.misses = currentFight.misses + 1
                if missType == "DODGE" then currentFight.dodges = currentFight.dodges + 1 end
                if missType == "PARRY" then currentFight.parries = currentFight.parries + 1 end
                if missType == "BLOCK" then currentFight.blocks = currentFight.blocks + 1 end
                if missType == "RESIST" then currentFight.resists = currentFight.resists + 1 end
                if RecordTuningQueueOutcome then
                    RecordTuningQueueOutcome(spellId, "missed")
                end
            end
        end
    elseif subevent == "SPELL_CAST_SUCCESS" and owner then
        local spellId, spellName = SafeNumber(args[12], 0) or 0, SafeString(args[13], "Spell")
        local a = AbilityRecord(owner, spellId, spellName)
        a.casts = a.casts + 1
        if owner == "player" and RecordTuningAction then RecordTuningAction(spellId, "combat_success") end
    elseif subevent == "SPELL_HEAL" and owner == "player" then
        local amount = SafeNumber(args[15], 0) or 0
        local overheal = SafeNumber(args[16], 0) or 0
        currentFight.healingDone = currentFight.healingDone + math.max(0, amount - overheal)
    elseif subevent == "PARTY_KILL" and owner and destIsOther then
        AddEnemyToFight(destGUID, destName)
        MarkFightKill(destGUID)
    elseif subevent == "UNIT_DIED" then
        if destGUID == playerGUID then
            currentFight.died = true
        elseif currentFight._enemies and currentFight._enemies[destGUID] then
            MarkFightKill(destGUID)
        end
    end
end

function SortedAbilityList(f)
    local list = {}
    for _, a in pairs((f and f.abilities) or {}) do list[#list+1] = a end
    table.sort(list, function(a,b)
        local av = (a.damage or 0) + (a.casts or 0) * 0.01
        local bv = (b.damage or 0) + (b.casts or 0) * 0.01
        return av > bv
    end)
    return list
end

function PrintLastCombatLog()
    InitCombatLogDB()
    local f = LastCurrentCharacterFight()
    if not f then print("|cffffcc00HCOB LOG:|r no fights recorded."); return end
    local enemies = (f.enemies and #f.enemies > 0) and table.concat(f.enemies, ", ") or (f.target or "?")
    print(string.format("|cff00ff98HCOB LOG #%d|r %s | %.1fs | %.1f DPS | dmg %d | taken %d", f.id or 0, enemies, f.duration or 0, f.dps or 0, f.totalDamage or 0, f.damageTaken or 0))
    print(string.format("Min HP %.1f%% | avg %s %.1f | max hit dealt %d / taken %d | max enemies %d", f.hpMinPct or 100, f.powerType or "Power", f.powerAvg or 0, f.maxHitDone or 0, f.maxHitTaken or 0, f.maxEnemies or 1))
    if f.powerType == "RAGE" then
        print(string.format("Rage start/end %.0f/%.0f | >=80: %.1f%% of fight | CAP: %.1f%%", f.powerStart or 0, f.powerEnd or 0, f.powerHighPct or 0, f.powerCapPct or 0))
        if f.schema and f.schema >= 5 then
            print(string.format("BASE clicks %d | Heroic queued %.1f%% of samples", f.baseClicks or 0, f.heroicQueuedPct or 0))
        end
    end
    if f.schema and f.schema >= 7 then
        print(string.format("Advisor: DANGER %.1f%% | CAUTION %.1f%% | manual %.1f%% | alert D/C %d/%d",
            f.advisorDangerPct or 0, f.advisorCautionPct or 0, f.advisorManualPct or 0,
            f.advisorDangerEvents or 0, f.advisorCautionEvents or 0))
    end
    if f.schema and f.schema >= 10 and f.survivalReserveAvg then
        print(string.format("Advisor 2.0 reserve: avg %.1f | min %.1f", f.survivalReserveAvg or 0, f.survivalReserveMin or 0))
    end
    local list = SortedAbilityList(f)
    for i=1, math.min(8, #list) do
        local a = list[i]
        local extra = ""
        if (a.casts or 0) > 0 then extra = extra .. " cast=" .. a.casts end
        if (a.hits or 0) > 0 then extra = extra .. " hit=" .. a.hits end
        if (a.crits or 0) > 0 then extra = extra .. " crit=" .. a.crits end
        if (a.misses or 0) > 0 then extra = extra .. " miss=" .. a.misses end
        print(string.format("  %s: %d dmg%s", a.name or "?", a.damage or 0, extra))
    end
end

function PrintCombatLogStats()
    InitCombatLogDB()
    local fights = CurrentCharacterFights(10)
    if #fights == 0 then print("|cffffcc00HCOB LOG:|r no fights recorded."); return end
    local n = #fights
    local td, tt, taken, minHp, rageHigh, rageCap, rageCount = 0,0,0,100,0,0,0
    local advDanger, advCaution, advCount = 0,0,0
    for i=1,#fights do
        local f=fights[i]
        td=td+(f.totalDamage or 0); tt=tt+(f.duration or 0); taken=taken+(f.damageTaken or 0); minHp=math.min(minHp,f.hpMinPct or 100)
        if f.powerType == "RAGE" and f.powerHighPct ~= nil then
            rageHigh = rageHigh + (f.powerHighPct or 0); rageCap = rageCap + (f.powerCapPct or 0); rageCount = rageCount + 1
        end
        if f.schema and f.schema >= 7 then
            advDanger = advDanger + (f.advisorDangerPct or 0)
            advCaution = advCaution + (f.advisorCautionPct or 0)
            advCount = advCount + 1
        end
    end
    print(string.format("|cff00ff98HCOB LOG:|r last %d fights | avg DPS %.1f | avg duration %.1fs | damage taken/fight %.1f | min HP %.1f%%", n, tt>0 and td/tt or 0, tt/n, taken/n, minHp))
    if rageCount > 0 then print(string.format("Avg Rage >=80 %.1f%% | avg rage CAP %.1f%%", rageHigh/rageCount, rageCap/rageCount)) end
    if advCount > 0 then print(string.format("Advisor average: DANGER %.1f%% | CAUTION %.1f%%", advDanger/advCount, advCaution/advCount)) end
end

function ClearCombatLog(clearAll)
    -- Never replace the SavedVariable table inside the private environment:
    -- Core/Init.lua, HCOneButton.CombatLog and WoW persistence all reference
    -- this exact object. Mutate it in place so /reload persists the clear.
    InitCombatLogDB()
    local removed = 0
    if clearAll then
        removed = #HCOB_CombatLog.fights
        for key in pairs(HCOB_CombatLog) do HCOB_CombatLog[key] = nil end
        HCOB_CombatLog.version = COMBAT_LOG_VERSION
        HCOB_CombatLog.fights = {}
        HCOB_CombatLog.totalFights = 0
        HCOB_CombatLog.session = "HCOneButton " .. VERSION
        HCOB.CombatLog = HCOB_CombatLog
    else
        for i=#HCOB_CombatLog.fights,1,-1 do
            if FightBelongsToCurrentCharacter(HCOB_CombatLog.fights[i]) then
                table.remove(HCOB_CombatLog.fights, i)
                removed = removed + 1
            end
        end
    end
    currentFight = nil
    print(string.format("|cff00ff98HCOB LOG:|r %s history cleared (%d fights).", clearAll and "account-wide" or "current-character", removed))
end


function CombatLogHandler()
    local args = { CombatLogGetCurrentEventInfo() }
    local subevent = SafeString(args[2], nil)
    if not subevent then return end
    local sourceGUID, sourceFlags = SafeString(args[4], nil), SafeNumber(args[6], nil)
    local destGUID, destFlags = SafeString(args[8], nil), SafeNumber(args[10], nil)
    local spellId, spellName = SafeNumber(args[12], nil), SafeString(args[13], nil)
    if not playerGUID then playerGUID = SafeUnitGUID("player") end
    if not playerGUID then return end
    local now = GetTime()

    local petGUID = SafeUnitGUID("pet")
    local exchangeEvent = subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "SPELL_PERIODIC_MISSED" or subevent == "RANGE_DAMAGE" or subevent == "RANGE_MISSED"
    if exchangeEvent then
        local sourceOurs = sourceGUID == playerGUID or (petGUID and sourceGUID == petGUID)
        local destOurs = destGUID == playerGUID or (petGUID and destGUID == petGUID)
        if destOurs and sourceGUID and not IsPlayerOrPetGUID(sourceGUID) then
            MarkEnemy(sourceGUID)
        elseif sourceOurs and destGUID and not IsPlayerOrPetGUID(destGUID) then
            MarkEnemy(destGUID)
        end
    elseif subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" or subevent == "PARTY_KILL" then
        -- A dead mob must disappear from the live multi-pull count immediately.
        -- Keeping it for enemyWindow seconds was a common source of false x2
        -- warnings during fast Hunter chain pulls.
        RemoveEnemy(destGUID)
    end

    if sourceGUID == playerGUID and (IsMainhandSwingCombatEvent(subevent, spellId)
       or subevent == "RANGE_DAMAGE" or subevent == "RANGE_MISSED") then
        lastAutoAttack = now
    end
    if destGUID == playerGUID and sourceGUID ~= playerGUID
       and (subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED") then
        HCOB.Advisor.Engine.lastMeleeAt = now
        if PLAYER_CLASS == "MAGE" and HCOB.Classes and HCOB.Classes.MAGE then HCOB.Classes.MAGE.lastMeleeAt = now end
    end
    if PLAYER_CLASS == "HUNTER" then
        if destGUID == playerGUID and sourceGUID ~= playerGUID and (subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED") then
            HCOB.Hunter.lastMeleeAt = now
        end
        if sourceGUID == playerGUID and (subevent == "RANGE_DAMAGE" or subevent == "RANGE_MISSED") and spellId == S.AUTO_SHOT then
            HCOB.Hunter.lastAutoShotAt = now
            HCOB.Hunter.autoRepeatActive = true
        end

        local serpentName = SpellName(S.SERPENT_STING)
        if sourceGUID == playerGUID and serpentName and spellName == serpentName then
            if subevent == "SPELL_CAST_SUCCESS" then
                HCOB.Hunter.serpentGUID = destGUID or SafeUnitGUID("target")
                HCOB.Hunter.serpentPendingUntil = now + 1.0
            elseif subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
                HCOB.Hunter.serpentGUID = destGUID
                HCOB.Hunter.serpentActive = true
                HCOB.Hunter.serpentPendingUntil = 0
            elseif subevent == "SPELL_AURA_REMOVED" and destGUID == HCOB.Hunter.serpentGUID then
                HCOB.Hunter.serpentActive = false
                HCOB.Hunter.serpentPendingUntil = 0
            end
        end
    end

    local targetGUID = SafeUnitGUID("target")
    if targetGUID and sourceGUID == targetGUID and subevent == "SPELL_CAST_START" then
        activeTargetCast = {guid=sourceGUID, spellId=spellId, name=spellName or SpellName(spellId,"Cast"), expires=now + SpellCastSeconds(spellId) + 0.35}
    elseif activeTargetCast and sourceGUID == activeTargetCast.guid then
        if subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_CAST_FAILED" or subevent == "UNIT_DIED" then activeTargetCast = nil end
    elseif activeTargetCast and destGUID == activeTargetCast.guid and (subevent == "UNIT_DIED" or subevent == "SPELL_INTERRUPT") then
        activeTargetCast = nil
    end

    if HCOB_DB.combatLogging ~= false and not runtimeTelemetryDisabled then
        local ok = SafeRun("CombatTelemetry", ProcessCombatTelemetry, args)
        if not ok then runtimeTelemetryDisabled = true end
    end
end

function SafeCombatLogHandler()
    if runtimeCombatLogDisabled then return end
    local ok = SafeRun("CombatLog", CombatLogHandler)
    if not ok then
        runtimeCombatLogDisabled = true
        activeTargetCast = nil
        activeEnemies = {}
    end
end
