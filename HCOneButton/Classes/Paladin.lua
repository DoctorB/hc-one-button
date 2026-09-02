local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Class = HCOB.Classes.PALADIN or {}
HCOB.Classes.PALADIN = Class
Class.classToken = "PALADIN"
Class.fallbackSpec = 3

local DIVINE_SHIELD_IMMEDIATE_HP = 25
local DIVINE_SHIELD_PRESSURE_HP = 35
local DIVINE_SHIELD_FORECAST_SECONDS = 6
local DIVINE_SHIELD_CRITICAL_RESERVE = 28

local function BestSeal()
    if IsKnown(S.SEAL_COMMAND) and MainhandSpeed() >= 3.2 then return S.SEAL_COMMAND end
    if IsKnown(S.SEAL_RIGHTEOUSNESS) then return S.SEAL_RIGHTEOUSNESS end
    if IsKnown(S.SEAL_COMMAND) then return S.SEAL_COMMAND end
end

function Class:GetRecommendation(inCombat, hostile, targetHP, spec)
    local candidates = {}
    local manaPct = HCOB.Advisor.Engine.ManaPct()
    local hp = UnitHealthPct("player")
    local reserve, reserveLabel = HCOB.Advisor.Engine.SurvivalReserve()
    local seal = BestSeal()
    local level = PlayerLevel()
    local targetLevel = hostile and SafeUnitLevel("target", level) or level
    local classification = hostile and SafeUnitClassification("target", "normal") or "normal"
    local tough = hostile and (classification == "elite" or classification == "rareelite" or classification == "worldboss" or targetLevel >= level + 1) or false

    if not inCombat or not hostile then return HCOB.Advisor.Engine.SelectCandidate(candidates) end

    local dyn = HCOB.Advisor.Engine.RollingDynamics(targetHP)
    local ttk = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local context = string.format("HP %.0f%% | mana %.0f%% | reserve %.0f %s", hp, manaPct, reserve, reserveLabel)
    if ttk and ttk < math.huge then context = context .. string.format(" | TTK ~%.0fs", ttk) end

    local hasMight, mightRemaining = StablePlayerBuff(S.BLESSING_MIGHT)
    if IsKnown(S.BLESSING_MIGHT) and IsUsable(S.BLESSING_MIGHT)
       and (not hasMight or mightRemaining <= 10) then
        local reason = hasMight and ("Refresh before expiry (" .. math.floor(mightRemaining) .. "s)") or "Blessing missing in combat"
        HCOB.Advisor.Engine.AddCandidate(candidates, S.BLESSING_MIGHT, "BLESSING OF MIGHT", "SHIFT", reason .. " | " .. context, hasMight and 66 or 86, "buff")
    end

    if reserve <= 28 and IsKnown(S.DIVINE_SHIELD) and CooldownReady(S.DIVINE_SHIELD) and IsUsable(S.DIVINE_SHIELD) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.DIVINE_SHIELD, "DIVINE SHIELD", "CAST MANUALLY", "Critical reserve: immunity and time to recover | " .. context, 114, "survival")
    elseif reserve <= 34 and IsKnown(S.DIVINE_PROTECTION) and CooldownReady(S.DIVINE_PROTECTION) and IsUsable(S.DIVINE_PROTECTION) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.DIVINE_PROTECTION, "DIVINE PROTECTION", "ALT+CTRL", "Reduce pressure before it is too late | " .. context, 106, "survival")
    end

    local heal = HCOB.Advisor.Engine.PaladinHealSpell(hp <= 42)
    if heal and hp <= 62 and manaPct >= 18 then
        local cast = SpellCastSeconds(heal)
        local ttdSafe = not dyn or dyn.ttd == math.huge or dyn.ttd >= cast + 1.0
        if ttdSafe then
            local score = 92 + math.max(0, 60-hp)*0.5 + (heal == S.FLASH_LIGHT and hp <= 42 and 6 or 0)
            HCOB.Advisor.Engine.AddCandidate(candidates, heal, SpellName(heal, "HEAL"), "CAST MANUALLY", "Heal before entering the panic range | " .. context, score, "survival")
        end
    end

    if hp <= 58 and targetHP > 28 and IsKnown(S.HAMMER_JUSTICE) and CooldownReady(S.HAMMER_JUSTICE) and IsUsable(S.HAMMER_JUSTICE) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.HAMMER_JUSTICE, "HAMMER OF JUSTICE", "ALT", "Stun to create a healing/auto-attack window | " .. context, 91, "control")
    end

    local crusaderActive = StablePlayerBuff(S.SEAL_CRUSADER)
    local normalSealActive = seal and StablePlayerBuff(seal) or false
    local crusaderSetup = IsKnown(S.SEAL_CRUSADER) and IsUsable(S.SEAL_CRUSADER)
        and (tough or targetLevel >= 44) and targetHP >= 75
    if crusaderActive and IsKnown(S.JUDGEMENT) and CooldownReady(S.JUDGEMENT) and IsUsable(S.JUDGEMENT) and manaPct >= 38 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.JUDGEMENT, "JUDGE CRUSADER", "CAST MANUALLY", "Convert the staged Crusader seal into the durable-target debuff, then return to the normal weapon-speed seal | " .. context, 89, "setup")
    elseif crusaderSetup and not crusaderActive then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.SEAL_CRUSADER, "SEAL OF THE CRUSADER", "CAST MANUALLY", "Durable/high-level target: stage Judgement of the Crusader in combat | " .. context, 84, "setup")
    elseif seal and not normalSealActive and IsUsable(seal) then
        HCOB.Advisor.Engine.AddCandidate(candidates, seal, "SEAL", "CAST MANUALLY", SpellName(seal) .. " missing | " .. context, 78, "buff")
    end

    if not crusaderActive and IsKnown(S.JUDGEMENT) and CooldownReady(S.JUDGEMENT) and IsUsable(S.JUDGEMENT) and manaPct >= 45 and reserve >= 48 then
        local longEnough = not ttk or ttk >= 6
        if longEnough then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.JUDGEMENT, "JUDGEMENT", "CAST MANUALLY", "Spend mana only if the fight pays it back | " .. context, 67, "damage")
        end
    end

    local creatureTypeID = HCOB.Advisor.Engine.TargetCreatureTypeID()
    if (creatureTypeID == 3 or creatureTypeID == 6) and IsKnown(S.EXORCISM) and CooldownReady(S.EXORCISM) and IsUsable(S.EXORCISM) and manaPct >= 58 and reserve >= 52 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.EXORCISM, "EXORCISM", "CAST MANUALLY", "Undead/Demon: efficient burst only with healthy mana | " .. context, 76, "damage")
    end

    if targetHP <= 20 and IsKnown(S.HAMMER_WRATH) and CooldownReady(S.HAMMER_WRATH) and IsUsable(S.HAMMER_WRATH) and manaPct >= 38 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.HAMMER_WRATH, "HAMMER OF WRATH", "ALT+SHIFT", "Finisher when you need to close quickly | " .. context, 84, "finisher")
    end

    if tough and targetHP >= 55 and manaPct >= 68 and reserve >= 62 and IsKnown(S.CONSECRATION) and CooldownReady(S.CONSECRATION) and IsUsable(S.CONSECRATION) then
        local longEnough = not ttk or ttk >= 14
        if longEnough then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.CONSECRATION, "CONSECRATION", "CTRL", "Long durable fight: spend mana only while healing reserve remains comfortable | " .. context, 58, "damage")
        end
    end

    return HCOB.Advisor.Engine.SelectCandidate(candidates)
end



-- Advisor class contract extensions.
function Class:GetBuffRecommendation(inCombat)
    return nil
end

function Class:GetCautionRecommendation(ctx)
    local heal = HCOB.Advisor.Engine.PaladinHealSpell(ctx.hp <= 45)
    if heal and ctx.hp <= 62 then return heal, "UNFAVORABLE FIGHT", "CAST MANUALLY", ctx.text .. ": heal before panic", "caution" end
    if IsKnown(S.HAMMER_JUSTICE) and CooldownReady(S.HAMMER_JUSTICE) and IsUsable(S.HAMMER_JUSTICE) then
        return S.HAMMER_JUSTICE, "UNFAVORABLE FIGHT", "ALT", ctx.text .. ": stun and buy time", "caution"
    end
end

-- Hardcore safety class contract. Advisor/Survival owns policy orchestration;
-- this class owns its spells and class-specific escape/resource model.
function Class:GetSurvivalReserve(ctx)
    local hp, mana = ctx.hp, ctx.mana
    local score
        score = hp * 0.56 + mana * 0.14 + 8
        if IsKnown(S.DIVINE_SHIELD) and CooldownReady(S.DIVINE_SHIELD) and IsUsable(S.DIVINE_SHIELD) then score = score + 15
        elseif IsKnown(S.DIVINE_PROTECTION) and CooldownReady(S.DIVINE_PROTECTION) and IsUsable(S.DIVINE_PROTECTION) then score = score + 10 end
        if IsKnown(S.LAY_ON_HANDS) and CooldownReady(S.LAY_ON_HANDS) and IsUsable(S.LAY_ON_HANDS) then score = score + 12 end
        if HCOB.Advisor.Engine.PaladinHealSpell(false) and mana >= 15 then score = score + 7 end
        if IsKnown(S.HAMMER_JUSTICE) and CooldownReady(S.HAMMER_JUSTICE) and IsUsable(S.HAMMER_JUSTICE) then score = score + 5 end
        if HCOB.Advisor.Engine.TargetIsClose() and hp < 55 then score = score - 4 end
    return score
end

function Class:GetPanicRecommendation(ctx)
        ctx = type(ctx) == "table" and ctx or {}
        local hp = SafeNumber(ctx.hp, nil) or UnitHealthPct("player")
        local enemies = SafeNumber(ctx.enemies, nil) or CountActiveEnemies()
        local reserve = SafeNumber(ctx.reserve, nil)
        if reserve == nil then reserve = select(1, HCOB.Advisor.Engine.SurvivalReserve()) end
        local dyn = ctx.dynamics or HCOB.Advisor.Engine.lastDynamics
        local forecastEmergency = dyn and (dyn.confidence or 0) >= 0.48
            and dyn.ttd and dyn.ttd < math.huge and dyn.ttd <= DIVINE_SHIELD_FORECAST_SECONDS
        local pressureEmergency = enemies >= 2 or reserve <= DIVINE_SHIELD_CRITICAL_RESERVE or forecastEmergency
        local shieldEmergency = hp <= DIVINE_SHIELD_IMMEDIATE_HP
            or (hp <= DIVINE_SHIELD_PRESSURE_HP and pressureEmergency)

        if hp <= 18 and IsKnown(S.LAY_ON_HANDS) and CooldownReady(S.LAY_ON_HANDS) and IsUsable(S.LAY_ON_HANDS) then
            return S.LAY_ON_HANDS, "LAY ON HANDS", "ALL MODS", "Extreme emergency: immediately recover HP"
        end
        if shieldEmergency and IsKnown(S.DIVINE_SHIELD) and CooldownReady(S.DIVINE_SHIELD) and IsUsable(S.DIVINE_SHIELD) then
            return S.DIVINE_SHIELD, "DIVINE SHIELD", "CAST MANUALLY", "Immediate lethal pressure: use immunity to recover or escape"
        end
        local protectionNeeded = hp <= DIVINE_SHIELD_PRESSURE_HP or enemies >= 3 or forecastEmergency
        if protectionNeeded and IsKnown(S.DIVINE_PROTECTION) and CooldownReady(S.DIVINE_PROTECTION) and IsUsable(S.DIVINE_PROTECTION) then
            return S.DIVINE_PROTECTION, "DIVINE PROTECTION", "ALT+CTRL", "Reduce pressure while preserving Divine Shield for a lethal emergency"
        end
        if hp <= DIVINE_SHIELD_IMMEDIATE_HP and IsKnown(S.LAY_ON_HANDS) and CooldownReady(S.LAY_ON_HANDS) and IsUsable(S.LAY_ON_HANDS) then
            return S.LAY_ON_HANDS, "LAY ON HANDS", "ALL MODS", "Immediate last resort with no immunity ready"
        end
        if IsKnown(S.HAMMER_JUSTICE) and CooldownReady(S.HAMMER_JUSTICE) and IsUsable(S.HAMMER_JUSTICE) then
            return S.HAMMER_JUSTICE, "HAMMER OF JUSTICE", "ALT", "Stun the target and create a safe healing or escape window"
        end
        local heal = HCOB.Advisor.Engine.PaladinHealSpell(true)
        if heal then return heal, SpellName(heal,"HEAL"), "CAST MANUALLY", "Stabilize HP while preserving major emergency cooldowns" end
        return nil, "RUN!", "PREPARE ESCAPE", "No immediate Paladin defensive available"
end

function Class:GetMultiPullRecommendation(enemies, hp, targetHP)
        local manaPct = HCOB.Advisor.Engine.ManaPct()
        if enemies >= 3 or hp <= 45 then
            local reserve = select(1, HCOB.Advisor.Engine.SurvivalReserve())
            local id, _, key, reason = self:GetPanicRecommendation({
                source="multi", enemies=enemies, hp=hp, targetHP=targetHP,
                reserve=reserve, dynamics=HCOB.Advisor.Engine.lastDynamics,
            })
            return id, enemies >= 3 and "3+ MOBS - STABILIZE" or "MULTI - STABILIZE", key or "ALL MODS", reason or "Control/heal/escape", "danger"
        end
        if IsKnown(S.CONSECRATION) and CooldownReady(S.CONSECRATION) and IsUsable(S.CONSECRATION) and manaPct >= 58 and hp >= 70 then
            return S.CONSECRATION, "MULTI x2 - CONSECRATION", "CTRL", "Only on a stable pull: spend mana to finish both", "caution"
        end
        if IsKnown(S.HAMMER_JUSTICE) and CooldownReady(S.HAMMER_JUSTICE) and IsUsable(S.HAMMER_JUSTICE) and hp <= 68 then
            return S.HAMMER_JUSTICE, "MULTI x2 - STUN", "ALT", "Stun one and reduce incoming damage", "caution"
        end
        return nil, "MULTI x2", "AUTO / CONSERVE", "Maintain seal and mana for heal/bubble", "caution"
end

-- Class interrupt contract. Advisor/Threat only detects the cast;
-- the class decides which control/interrupt spell is valid.
function Class:GetInterruptRecommendation()
        if IsKnown(S.HAMMER_JUSTICE) and CooldownReady(S.HAMMER_JUSTICE) then return S.HAMMER_JUSTICE, "STOP CAST", "CTRL+SHIFT", "Stun (if possible)" end
end

-- Secure macro class contract. Core/Macros owns only secure attribute orchestration;
-- the class owns its base action and modifier spell choices.
function Class:BuildMainMacro()
        -- Safe base: auto attack. Seal/Judgement are handled by the Advisor.
        local lines = NewLines()
        AddLine(lines, "/startattack", 1)
        return FitMacro(lines)
end

function Class:BuildModifierMacros()
        return {
            shift=BuildSpellMacro(S.BLESSING_MIGHT, "@player"), ctrl=BuildSpellMacro(S.CONSECRATION),
            alt=BuildSpellMacro(S.HAMMER_JUSTICE, "harm"), ctrlshift=BuildSpellMacro(S.HAMMER_JUSTICE, "harm"),
            altshift=BuildSpellMacro(S.HAMMER_WRATH, "harm"), altctrl=BuildSpellMacro(S.DIVINE_PROTECTION),
            all=BuildSpellMacro(S.LAY_ON_HANDS, "@player"),
            desc={shift="Blessing of Might",ctrl="Consecration",alt="Hammer of Justice",ctrlshift="Stop cast / stun",altshift="Hammer of Wrath",altctrl="Divine Protection",all="Lay on Hands"}
        }
end

function Class:GetBaseActionInfo(spec)
    return S.ATTACK, "AUTO ATTACK"
end

