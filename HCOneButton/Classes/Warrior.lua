local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Class = HCOB.Classes.WARRIOR or {}
HCOB.Classes.WARRIOR = Class
Class.classToken = "WARRIOR"
Class.fallbackSpec = 1

local BATTLE_SHOUT_REFRESH_SECONDS = 10

local function BattleShoutState()
    local active, remaining = StablePlayerBuff(S.BATTLE_SHOUT)
    remaining = SafeNumber(remaining, 999) or 999
    return active and true or false, remaining
end

local function CurrentRage()
    local pType = UnitPowerType("player")
    return SafeUnitPower("player", pType, 0) or 0
end

-- A caution/escape plan must not leave the Warrior sitting near the Rage cap.
-- Keep enough Rage for Hamstring/control, but let a high-value spender pass
-- through before returning to the escape recommendation.
local function EscapeRageSpendRecommendation(ctx)
    ctx = type(ctx) == "table" and ctx or {}
    local rage = CurrentRage()
    local targetHP = SafeNumber(ctx.targetHP, 100) or 100
    local reserve = SafeNumber(ctx.reserve, 100) or 100
    local enemies = SafeNumber(ctx.enemies, 1) or 1
    local configured = tonumber(HCOB_DB.warriorHeroicRage) or 35
    local threshold = math.max(40, configured + 5)
    if reserve < 35 then threshold = threshold + 5 end
    if targetHP <= 35 then threshold = math.max(35, threshold - 5) end
    if rage < threshold then return nil end

    local reason = string.format(
        "Spend excess Rage (%d / %d) before continuing the escape plan",
        rage, threshold
    )
    if IsKnown(S.EXECUTE) and targetHP <= 20 and IsUsable(S.EXECUTE) then
        return S.EXECUTE, "EXECUTE - THEN EXIT", "CAST MANUALLY", reason, "caution"
    end
    if IsKnown(S.OVERPOWER) and CooldownReady(S.OVERPOWER) and IsUsable(S.OVERPOWER) then
        return S.OVERPOWER, "OVERPOWER - THEN EXIT", "CAST MANUALLY", reason, "caution"
    end
    if IsKnown(S.MORTAL_STRIKE) and CooldownReady(S.MORTAL_STRIKE) and IsUsable(S.MORTAL_STRIKE) then
        return S.MORTAL_STRIKE, "MORTAL STRIKE - EXIT", "CAST MANUALLY", reason, "caution"
    end
    if IsKnown(S.BLOODTHIRST) and CooldownReady(S.BLOODTHIRST) and IsUsable(S.BLOODTHIRST) then
        return S.BLOODTHIRST, "BLOODTHIRST - EXIT", "CAST MANUALLY", reason, "caution"
    end
    if IsKnown(S.WHIRLWIND) and CooldownReady(S.WHIRLWIND) and IsUsable(S.WHIRLWIND) then
        return S.WHIRLWIND, "WHIRLWIND - THEN EXIT", "CAST MANUALLY", reason, "caution"
    end
    local heroicKnown = IsKnown(S.HEROIC_STRIKE) or knownSpellNames[SpellName(S.HEROIC_STRIKE) or ""] == true
    if heroicKnown and IsUsable(S.HEROIC_STRIKE) then
        return S.HEROIC_STRIKE, "HEROIC STRIKE - EXIT", "ALT+SHIFT", reason, "caution"
    end
    return nil
end

function Class:GetRecommendation(inCombat, hostile, targetHP, spec)
    local candidates = {}
    if not inCombat and hostile and IsKnown(S.CHARGE) and CooldownReady(S.CHARGE) and IsUsable(S.CHARGE) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.CHARGE, "CHARGE", "BASE", "Open with Charge to enter with rage and initiative", 86, "opener")
    end
    if not inCombat or not hostile then return HCOB.Advisor.Engine.SelectCandidate(candidates) end

    local rage = CurrentRage()
    local hp = UnitHealthPct("player")
    local enemies = CountActiveEnemies()
    local level = PlayerLevel()
    local targetLevel = SafeUnitLevel("target", level) or level
    local classification = SafeUnitClassification("target", "normal") or "normal"
    local tough = classification == "elite" or classification == "rareelite" or classification == "worldboss" or targetLevel >= level
    local elapsed = currentFight and math.max(0, GetTime() - (currentFight.startClock or GetTime())) or 0
    local reserve, reserveLabel = HCOB.Advisor.Engine.SurvivalReserve()
    local dyn = HCOB.Advisor.Engine.RollingDynamics(targetHP)
    local estimatedTTK = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local riskPenalty = reserve < 55 and ((55 - reserve) * 0.55) or 0
    if reserve < 35 then riskPenalty = riskPenalty + 8 end
    local context = string.format("rage %d | reserve %.0f %s", rage, reserve, reserveLabel)
    if estimatedTTK and estimatedTTK < math.huge then context = context .. string.format(" | TTK ~%.0fs", estimatedTTK) end

    -- Proactive survival before the global HP panic threshold.  These actions
    -- only compete when the reserve is already poor; normal DPS never burns a
    -- major defensive just because it is off cooldown.
    if reserve <= 28 and hp <= 52 and IsKnown(S.SHIELD_WALL) and CooldownReady(S.SHIELD_WALL) and IsUsable(S.SHIELD_WALL) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.SHIELD_WALL, "SHIELD WALL", "CAST MANUALLY", "Critical survival reserve | " .. context, 108, "survival")
    end
    if reserve <= 38 and targetHP > 25 and IsKnown(S.HAMSTRING) and IsUsable(S.HAMSTRING) and not HasMyTargetDebuff(S.HAMSTRING) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.HAMSTRING, "HAMSTRING + DISTANCE", "ALT", "Low reserve: prepare an escape route | " .. context, 94, "survival")
    end
    if tough and reserve <= 46 and hp <= 68 and IsKnown(S.RETALIATION) and CooldownReady(S.RETALIATION) and IsUsable(S.RETALIATION) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.RETALIATION, "RETALIATION", "ALL MODS", "Hard melee fight is trending badly: convert pressure into a short counterattack window | " .. context, 99, "survival")
    end

    if IsKnown(S.EXECUTE) and targetHP <= 20 and IsUsable(S.EXECUTE) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.EXECUTE, "EXECUTE!", "CAST MANUALLY", "Target <=20% | " .. context, 115, "finisher")
    end
    if IsKnown(S.OVERPOWER) and IsUsable(S.OVERPOWER) and CooldownReady(S.OVERPOWER) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.OVERPOWER, "OVERPOWER!", "CAST MANUALLY", "Reactive window available | " .. context, 108, "proc")
    end

    -- Core strike: high priority, but still scored so an Execute/Overpower or
    -- genuine survival action can beat it cleanly.
    if IsKnown(S.MORTAL_STRIKE) and CooldownReady(S.MORTAL_STRIKE) and IsUsable(S.MORTAL_STRIKE) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.MORTAL_STRIKE, "MORTAL STRIKE", "CAST MANUALLY", "Core single-target | " .. context, 96 - riskPenalty * 0.15, "core")
    end
    if IsKnown(S.BLOODTHIRST) and CooldownReady(S.BLOODTHIRST) and IsUsable(S.BLOODTHIRST) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.BLOODTHIRST, "BLOODTHIRST", "CAST MANUALLY", "Core single-target | " .. context, 95 - riskPenalty * 0.15, "core")
    end
    if enemies >= 2 and IsKnown(S.WHIRLWIND) and CooldownReady(S.WHIRLWIND) and IsUsable(S.WHIRLWIND) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.WHIRLWIND, "WHIRLWIND", "CAST MANUALLY", enemies .. " enemies | " .. context, 91 - riskPenalty * 0.2, "aoe")
    elseif enemies <= 1 and IsKnown(S.WHIRLWIND) and CooldownReady(S.WHIRLWIND) and IsUsable(S.WHIRLWIND) and reserve >= 48 and targetHP >= 30 then
        local majorReady = (IsKnown(S.MORTAL_STRIKE) and CooldownReady(S.MORTAL_STRIKE) and IsUsable(S.MORTAL_STRIKE))
            or (IsKnown(S.BLOODTHIRST) and CooldownReady(S.BLOODTHIRST) and IsUsable(S.BLOODTHIRST))
        if not majorReady and (not estimatedTTK or estimatedTTK >= 5) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.WHIRLWIND, "WHIRLWIND", "CAST MANUALLY", "Single-target rage spender while the major strike is unavailable | " .. context, 84 - riskPenalty * 0.2, "damage")
        end
    end

    -- Mitigation can be worth more than another rage dump on a hard/long mob.
    if tough and reserve < 58 and targetHP >= 45 and IsKnown(S.THUNDER_CLAP) and CooldownReady(S.THUNDER_CLAP) and IsUsable(S.THUNDER_CLAP) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.THUNDER_CLAP, "THUNDER CLAP", "CTRL", "Reduce melee pressure on a difficult fight | " .. context, 79 + (55 - math.min(55, reserve)) * 0.25, "mitigation")
    end
    if tough and targetHP >= 50 and IsKnown(S.DEMO_SHOUT) and IsUsable(S.DEMO_SHOUT) and not HasMyTargetDebuff(S.DEMO_SHOUT) then
        local longEnough = not estimatedTTK or estimatedTTK >= 11
        if longEnough then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.DEMO_SHOUT, "DEMO SHOUT", "CAST MANUALLY", "Long fight: reduce incoming damage | " .. context, 70 + (reserve < 50 and 8 or 0), "mitigation")
        end
    end

    -- Battle Shout is combat-only maintenance. Apply it when genuinely missing
    -- and refresh only in its final ten seconds; out-of-combat Advisor paths
    -- never request it.
    local hasBattleShout, battleShoutRemaining = BattleShoutState()
    if IsKnown(S.BATTLE_SHOUT)
       and (not hasBattleShout or battleShoutRemaining <= BATTLE_SHOUT_REFRESH_SECONDS)
       and IsUsable(S.BATTLE_SHOUT) and rage >= 10 then
        local worth = not hasBattleShout
            or (estimatedTTK and estimatedTTK >= 10)
            or (not estimatedTTK and targetHP >= 68)
        if worth then
            local shoutReason = hasBattleShout
                and ("Refresh before expiry (" .. math.floor(battleShoutRemaining) .. "s)")
                or "Battle Shout missing in combat"
            local shoutScore = hasBattleShout and 65 or 84
            HCOB.Advisor.Engine.AddCandidate(candidates, S.BATTLE_SHOUT, "BATTLE SHOUT", "SHIFT", shoutReason .. " | " .. context, shoutScore - riskPenalty * 0.25, "buff")
        end
    end

    if IsKnown(S.REND) and level <= 45 and not currentWarriorAutoRend and not HasMyTargetDebuff(S.REND) and IsUsable(S.REND) then
        local worthRend = tough or targetLevel <= 0 or targetLevel >= (level - 4)
        if level >= 36 then worthRend = tough and (not estimatedTTK or estimatedTTK >= 12) end
        if estimatedTTK and level <= 35 then worthRend = estimatedTTK >= 8.0 end
        if elapsed > 7.0 then worthRend = false end
        if targetHP >= 45 and worthRend then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.REND, "REND", "CAST MANUALLY", "Early DoT with enough time to tick | " .. context, 69 - riskPenalty * 0.4, "dot")
        end
    end

    if HCOB_DB.warriorSunderBase ~= false and IsKnown(S.SUNDER_ARMOR) and IsUsable(S.SUNDER_ARMOR) and not HasMyTargetDebuff(S.SUNDER_ARMOR) then
        local levelWindow = level >= 22 and level <= 35 and targetLevel >= level
        local longEnough = estimatedTTK and estimatedTTK >= 13 or (not estimatedTTK and targetHP >= 72)
        if targetHP >= 60 and longEnough and (tough or levelWindow) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.SUNDER_ARMOR, "SUNDER x1", "CAST MANUALLY", "Armor debuff on a durable/long target | " .. context, 63 - riskPenalty * 0.35, "setup")
        end
    end

    if IsKnown(S.BLOODRAGE) and rage <= 10 and hp >= 85 and targetHP >= 50 and enemies <= 1 and CooldownReady(S.BLOODRAGE) and IsUsable(S.BLOODRAGE) and elapsed <= 9 then
        local longEnough = not estimatedTTK or estimatedTTK >= 7
        if longEnough and reserve >= 55 then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.BLOODRAGE, "BLOODRAGE", "ALT+CTRL", "Opener: generate rage without stressing reserve | " .. context, 61, "resource")
        end
    end

    local hsThreshold = tonumber(HCOB_DB.warriorHeroicRage) or 35
    local levelDiff = targetLevel > 0 and (targetLevel - level) or 0
    if level < 20 then
        if levelDiff <= -3 then hsThreshold = math.max(25, hsThreshold - 5)
        elseif levelDiff <= -2 then hsThreshold = math.max(30, hsThreshold)
        else hsThreshold = math.max(35, hsThreshold) end
    elseif targetHP <= 35 then
        hsThreshold = math.max(25, hsThreshold - 5)
    end
    if targetHP <= 30 and not IsKnown(S.EXECUTE) then hsThreshold = math.max(20, hsThreshold - 10) end
    if reserve < 42 then hsThreshold = hsThreshold + 10 end
    if reserve >= 72 and targetHP <= 45 then hsThreshold = math.max(20, hsThreshold - 5) end

    local heroicKnown = IsKnown(S.HEROIC_STRIKE) or knownSpellNames[SpellName(S.HEROIC_STRIKE) or ""] == true
    if heroicKnown and rage >= hsThreshold and IsUsable(S.HEROIC_STRIKE) then
        local excess = math.max(0, rage - hsThreshold)
        local score = 64 + math.min(16, excess * 0.8) + (targetHP <= 30 and 8 or 0) - riskPenalty * 0.55
        HCOB.Advisor.Engine.AddCandidate(candidates, S.HEROIC_STRIKE, "HEROIC STRIKE", "ALT+SHIFT", "Rage dump: " .. rage .. " / threshold " .. hsThreshold .. " | " .. context, score, "dump")
    end

    return HCOB.Advisor.Engine.SelectCandidate(candidates)
end



-- Advisor class contract extensions.
function Class:GetBuffRecommendation(inCombat)
    return nil
end

function Class:GetCautionRecommendation(ctx)
    local id, title, key, reason, kind = EscapeRageSpendRecommendation({
        targetHP=ctx.targetHP, reserve=ctx.reserve, enemies=1,
    })
    if id then return id, title, key, ctx.text .. ": " .. reason, kind end
    if IsKnown(S.HAMSTRING) and IsUsable(S.HAMSTRING) and not HasMyTargetDebuff(S.HAMSTRING) then
        return S.HAMSTRING, "UNFAVORABLE FIGHT", "ALT", ctx.text .. ": prepare Hamstring + distance", "caution"
    end
end

-- Hardcore safety class contract. Advisor/Survival owns policy orchestration;
-- this class owns its spells and class-specific escape/resource model.
function Class:GetSurvivalReserve(ctx)
    local hp, mana = ctx.hp, ctx.mana
    local score
        local pType = UnitPowerType("player")
        local rage = SafeUnitPower("player", pType, 0) or 0
        score = hp * 0.68 + math.min(70, rage) * 0.11 + 8
        if IsKnown(S.SHIELD_WALL) and CooldownReady(S.SHIELD_WALL) and IsUsable(S.SHIELD_WALL) then score = score + 10 end
        if IsKnown(S.RETALIATION) and CooldownReady(S.RETALIATION) and IsUsable(S.RETALIATION) then score = score + 7 end
        if IsKnown(S.HAMSTRING) and IsUsable(S.HAMSTRING) then score = score + 4 end
        if IsKnown(S.THUNDER_CLAP) and CooldownReady(S.THUNDER_CLAP) and IsUsable(S.THUNDER_CLAP) then score = score + 3 end
        if IsKnown(S.DEMO_SHOUT) and IsUsable(S.DEMO_SHOUT) then score = score + 2 end
        if hp < 45 and rage < 10 then score = score - 5 end
    return score
end

function Class:GetPanicRecommendation()
        if IsKnown(S.SHIELD_WALL) and CooldownReady(S.SHIELD_WALL) and IsUsable(S.SHIELD_WALL) then return S.SHIELD_WALL, "SHIELD WALL", "CAST MANUALLY", "Immediately reduce incoming damage" end
        if IsKnown(S.RETALIATION) and CooldownReady(S.RETALIATION) and IsUsable(S.RETALIATION) then return S.RETALIATION, "PANIC", "ALL MODS", "Retaliation" end
        if IsKnown(S.HAMSTRING) and IsUsable(S.HAMSTRING) and not HasMyTargetDebuff(S.HAMSTRING) then return S.HAMSTRING, "RUN!", "ALT", "Hamstring and create distance" end
        return nil, "RUN!", "PREPARE ESCAPE", "No immediate Warrior defensive available"
end

function Class:GetMultiPullRecommendation(enemies, hp, targetHP)
        if enemies >= 3 then
            if IsKnown(S.RETALIATION) and CooldownReady(S.RETALIATION) then
                return S.RETALIATION, "3+ MOBS - PANIC", "ALL MODS", "Use Retaliation now; then reduce the pull", "danger"
            end
            if IsKnown(S.THUNDER_CLAP) and CooldownReady(S.THUNDER_CLAP) and IsUsable(S.THUNDER_CLAP) then
                return S.THUNDER_CLAP, "3+ MOBS - CONTROL", "CTRL", "Use Thunder Clap now; then create distance", "danger"
            end
            if IsKnown(S.DEMO_SHOUT) and IsUsable(S.DEMO_SHOUT) then
                return S.DEMO_SHOUT, "3+ MOBS - DEBUFF", "CAST MANUALLY", "Demoralizing Shout, then prepare to escape", "danger"
            end
            local id, _, key, reason = self:GetPanicRecommendation()
            return id, "3+ MOBS - GET OUT", key or "ALL MODS", reason or "Create distance", "danger"
        end

        if hp <= 50 then
            local id, _, key, reason = self:GetPanicRecommendation()
            return id, "2 MOBS - GET OUT", key or "ALL MODS", reason or "Reduce pressure", "danger"
        end

        if IsKnown(S.THUNDER_CLAP) and CooldownReady(S.THUNDER_CLAP) and IsUsable(S.THUNDER_CLAP) then
            return S.THUNDER_CLAP, "MULTI x2 - CONTROL", "CTRL", "Reduce attack speed and pressure", "caution"
        end

        if IsKnown(S.DEMO_SHOUT) and IsUsable(S.DEMO_SHOUT) then
            local hasDemo = HasMyTargetDebuff(S.DEMO_SHOUT)
            if not hasDemo then
                return S.DEMO_SHOUT, "MULTI x2 - DEBUFF", "CAST MANUALLY", "Demoralizing Shout reduces melee damage", "caution"
            end
        end

        local reserve = select(1, HCOB.Advisor.Engine.SurvivalReserve())
        local spendID, _, spendKey, spendReason = EscapeRageSpendRecommendation({
            targetHP=targetHP, reserve=reserve, enemies=enemies,
        })
        if spendID then
            local kind = hp <= 68 and "danger" or "caution"
            return spendID, "MULTI x2 - SPEND RAGE", spendKey, spendReason .. "; then create distance", kind
        end

        if hp <= 68 then
            if IsKnown(S.HAMSTRING) and IsUsable(S.HAMSTRING) and not HasMyTargetDebuff(S.HAMSTRING) then
                return S.HAMSTRING, "MULTI x2 - RISK", "ALT", "Hamstring and prepare an escape route", "danger"
            end
            return nil, "MULTI x2 - RISK", "PREPARE ESCAPE", "High pressure: create distance", "danger"
        end
        return nil, "MULTI x2", "PREPARE ESCAPE", "Do not add mobs; watch HP and escape routes", "caution"
end

-- Class interrupt contract. Advisor/Threat only detects the cast;
-- the class decides which control/interrupt spell is valid.
function Class:GetInterruptRecommendation()
        if IsKnown(S.PUMMEL) and CooldownReady(S.PUMMEL) then return S.PUMMEL, "INTERRUPT!", "CTRL+SHIFT", "Pummel" end
        if IsKnown(S.SHIELD_BASH) and CooldownReady(S.SHIELD_BASH) then return S.SHIELD_BASH, "INTERRUPT!", "CTRL+SHIFT", "Shield Bash" end
end

-- Secure macro class contract. Core/Macros owns only secure attribute orchestration;
-- the class owns its base action and modifier spell choices.
function Class:BuildMainMacro()
        HCOB_DB.warriorHeroicSpam = false
        -- SAFE BASE v1.11:
        --   * /startattack always;
        --   * Charge out of combat;
        --   * Rend x1 only on targets worth applying a DoT to;
        --   * Heroic Strike is NEVER part of BASE spam.
        --
        -- A secure macro cannot read rage and decide whether to queue HS.
        -- HS therefore remains an Advisor decision and is used manually (ALT+SHIFT)
        -- only when the adaptive rage threshold is actually reached.
        local lines = NewLines()
        AddLine(lines, "/startattack [harm]", 1)
        AddLine(lines, CastLine(S.CHARGE, "nocombat,harm", false), 1)

        local hasMajorSpender = IsKnown(S.MORTAL_STRIKE) or IsKnown(S.BLOODTHIRST)

        currentWarriorAutoRend = false
        if not hasMajorSpender and WarriorTargetWantsRend() then
            local rend = SpellName(S.REND)
            if rend then
                AddLine(lines, "/castsequence [combat,harm] reset=target/combat " .. rend .. ", null", 2)
                currentWarriorAutoRend = true
            end
        end

        return FitMacro(lines)
end

function Class:BuildModifierMacros()
        local interrupt = NewLines()
        AddLine(interrupt, IsKnown(S.PUMMEL) and ("/cast [stance:3] " .. SpellName(S.PUMMEL)) or nil, 1)
        AddLine(interrupt, IsKnown(S.SHIELD_BASH) and ("/cast [stance:1/2] " .. SpellName(S.SHIELD_BASH)) or nil, 1)
        local panic = IsKnown(S.RETALIATION) and BuildSpellMacro(S.RETALIATION, "stance:1", false) or BuildSpellMacro(S.DEMO_SHOUT)
        return {
            shift=BuildSpellMacro(S.BATTLE_SHOUT), ctrl=BuildSpellMacro(S.THUNDER_CLAP, nil, true),
            alt=BuildSpellMacro(S.HAMSTRING, nil, true), ctrlshift=FitMacro(interrupt),
            altshift=BuildSpellMacro(S.HEROIC_STRIKE, nil, true), altctrl=BuildSpellMacro(S.BLOODRAGE, "combat"),
            all=panic,
            desc={shift="Battle Shout",ctrl="Thunder Clap",alt="Hamstring",ctrlshift="Interrupt",altshift="Heroic Strike",altctrl="Bloodrage",all="Retaliation / Demo Shout"}
        }
end

function Class:GetBaseActionInfo(spec)
    local inCombat = UnitAffectingCombat("player") and true or false
    if not inCombat and IsKnown(S.CHARGE) then
        return S.CHARGE, currentWarriorAutoRend and "CHARGE -> REND x1" or "CHARGE -> AUTO"
    end
    return S.ATTACK, currentWarriorAutoRend and "AUTO + REND x1" or "AUTO ATTACK"
end

