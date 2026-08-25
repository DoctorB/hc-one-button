local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Class = HCOB.Classes.ROGUE or {}
HCOB.Classes.ROGUE = Class
Class.classToken = "ROGUE"
Class.fallbackSpec = 2

function Class:GetRecommendation(inCombat, hostile, targetHP, spec)
    local candidates = {}
    local hp = UnitHealthPct("player")
    local pType = UnitPowerType("player")
    local energy = SafeUnitPower("player", pType, 0) or 0
    local cp = 0
    if GetComboPoints then
        local ok, value = pcall(GetComboPoints, "player", "target")
        if ok then cp = SafeNumber(value, 0) or 0 end
    end
    local stealthed = HasPlayerBuff(S.STEALTH)

    if not inCombat and hostile then
        if not stealthed and IsKnown(S.STEALTH) and IsUsable(S.STEALTH) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.STEALTH, "STEALTH", "SHIFT", "Pre-pull: open with control and initiative", 84, "opener")
        elseif stealthed then
            local level = PlayerLevel()
            local targetLevel = SafeUnitLevel("target", level) or level
            local classification = SafeUnitClassification("target", "normal") or "normal"
            local tough = classification == "elite" or classification == "rareelite" or targetLevel >= level + 1
            if tough and IsKnown(S.CHEAP_SHOT) and IsUsable(S.CHEAP_SHOT) then
                HCOB.Advisor.Engine.AddCandidate(candidates, S.CHEAP_SHOT, "CHEAP SHOT", "CAST MANUALLY", "Difficult target: buy time before the damage race", 82, "opener")
            end
            if IsKnown(S.GARROTE) and IsUsable(S.GARROTE) then
                HCOB.Advisor.Engine.AddCandidate(candidates, S.GARROTE, "GARROTE", "CAST MANUALLY", "Efficient opener if the bleed can tick", tough and 76 or 84, "opener")
            end
        end
        return HCOB.Advisor.Engine.SelectCandidate(candidates)
    end
    if not inCombat or not hostile then return HCOB.Advisor.Engine.SelectCandidate(candidates) end

    local reserve, reserveLabel = HCOB.Advisor.Engine.SurvivalReserve()
    local dyn = HCOB.Advisor.Engine.RollingDynamics(targetHP)
    local close = HCOB.Advisor.Engine.TargetIsClose()
    local enemies = CountActiveEnemies()
    local ttk = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local context = string.format("HP %.0f%% | energy %d | CP %d | reserve %.0f %s", hp, energy, cp, reserve, reserveLabel)
    if ttk and ttk < math.huge then context = context .. string.format(" | TTK ~%.0fs", ttk) end

    if IsKnown(S.RIPOSTE) and CooldownReady(S.RIPOSTE) and IsUsable(S.RIPOSTE) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.RIPOSTE, "RIPOSTE", "CAST MANUALLY", "Reactive 10-energy strike: high damage plus disarm when the parry window is active | " .. context, 109, "proc")
    end

    if hp <= 58 and close and targetHP > 28 and IsKnown(S.EVASION) and CooldownReady(S.EVASION) and IsUsable(S.EVASION) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.EVASION, "EVASION", "ALT+CTRL", "Immediately reduce melee pressure | " .. context, 101 + math.max(0, 50-hp)*0.3, "survival")
    end

    if reserve <= 40 and targetHP > 22 and IsKnown(S.GOUGE) and CooldownReady(S.GOUGE) and IsUsable(S.GOUGE) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.GOUGE, "GOUGE + RESET", "CTRL", "Create a window for bandage/distance/energy | " .. context, 96, "survival")
    elseif energy <= 25 and targetHP >= 45 and reserve >= 48 and IsKnown(S.GOUGE) and CooldownReady(S.GOUGE) and IsUsable(S.GOUGE) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.GOUGE, "GOUGE + POOL", "CTRL", "Low energy: buy a short regeneration window instead of starving the next control/finisher | " .. context, 68, "resource")
    end

    if reserve <= 34 and targetHP > 20 and IsKnown(S.BLIND) and CooldownReady(S.BLIND) and IsUsable(S.BLIND) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.BLIND, "BLIND + RESET", "CAST MANUALLY", "Emergency control before committing Vanish; create distance and reset the fight | " .. context, 103, "survival")
    end
    if reserve <= 30 and IsKnown(S.SPRINT) and CooldownReady(S.SPRINT) and IsUsable(S.SPRINT) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.SPRINT, "SPRINT + EXIT", "ALT", "Control window is weak: extend the leash before Vanish is compromised | " .. context, 99, "survival")
    end

    if cp >= 4 and reserve < 52 and IsKnown(S.KIDNEY_SHOT) and IsUsable(S.KIDNEY_SHOT) and targetHP > 28 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.KIDNEY_SHOT, "KIDNEY SHOT", "CAST MANUALLY", "Convert combo points into control when the fight turns bad | " .. context, 94, "control")
    end

    if IsKnown(S.EVISCERATE) and IsUsable(S.EVISCERATE) then
        if cp >= 4 then
            local score = 82 + (targetHP <= 35 and 10 or 0)
            HCOB.Advisor.Engine.AddCandidate(candidates, S.EVISCERATE, "EVISCERATE", "ALT+SHIFT", "Finisher a " .. cp .. " combo point | " .. context, score, "finisher")
        elseif cp >= 2 and targetHP <= 22 then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.EVISCERATE, "EVISCERATE", "ALT+SHIFT", "Finish the mob without wasting builders | " .. context, 88, "finisher")
        end
    end

    local snd = HasPlayerBuff(S.SLICE_DICE)
    if IsKnown(S.SLICE_DICE) and not snd and cp >= 1 and targetHP >= 45 and reserve >= 48 and IsUsable(S.SLICE_DICE) then
        local longEnough = not ttk or ttk >= 11
        if longEnough then
            local score = cp <= 2 and 75 or 68
            HCOB.Advisor.Engine.AddCandidate(candidates, S.SLICE_DICE, "SLICE AND DICE", "CAST MANUALLY", "Spend 1-2 CP if the uptime pays off in this fight | " .. context, score, "efficiency")
        end
    end

    if enemies >= 2 and spec == 2 and IsKnown(S.BLADE_FLURRY) and CooldownReady(S.BLADE_FLURRY) and IsUsable(S.BLADE_FLURRY) and reserve >= 65 and hp >= 72 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.BLADE_FLURRY, "BLADE FLURRY", "CAST MANUALLY", "Stable two-target pull: convert uptime into cleave without sacrificing the escape reserve | " .. context, 78, "aoe")
    end
    if spec == 2 and IsKnown(S.ADRENALINE_RUSH) and CooldownReady(S.ADRENALINE_RUSH) and IsUsable(S.ADRENALINE_RUSH) and reserve >= 60 and targetHP >= 70 then
        local longEnough = ttk and ttk >= 16
        if longEnough then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.ADRENALINE_RUSH, "ADRENALINE RUSH", "CAST MANUALLY", "Use DPS cooldown only on a sufficiently long fight | " .. context, 72, "burst")
        end
    end

    local builder = (spec == 3 and IsKnown(S.HEMORRHAGE)) and S.HEMORRHAGE or S.SINISTER_STRIKE
    if IsKnown(builder) and IsUsable(builder) and energy >= 40 and cp < 5 and targetHP > 20 and reserve >= 42 then
        local score = 61 + (cp <= 2 and 4 or 0) + (targetHP >= 55 and 3 or 0)
        if cp >= 4 then score = score - 8 end
        HCOB.Advisor.Engine.AddCandidate(candidates, builder, SpellName(builder, "BUILDER"), "BASE", "Spec-aware builder while energy, combo-point headroom and survival reserve are healthy | " .. context, score, "damage")
    end

    return HCOB.Advisor.Engine.SelectCandidate(candidates)
end



-- Advisor class contract extensions.
function Class:GetCautionRecommendation(ctx)
    if IsKnown(S.EVASION) and CooldownReady(S.EVASION) and IsUsable(S.EVASION) then
        return S.EVASION, "UNFAVORABLE FIGHT", "ALT+CTRL", ctx.text .. ": Evasion and prepare Vanish", "caution"
    end
    if IsKnown(S.GOUGE) and CooldownReady(S.GOUGE) and IsUsable(S.GOUGE) then
        return S.GOUGE, "UNFAVORABLE FIGHT", "CTRL", ctx.text .. ": Gouge to create a window", "caution"
    end
end

-- Hardcore safety class contract. Advisor/Survival owns policy orchestration;
-- this class owns its spells and class-specific escape/resource model.
function Class:GetSurvivalReserve(ctx)
    local hp, mana = ctx.hp, ctx.mana
    local score
        local pType = UnitPowerType("player")
        local energy = SafeUnitPower("player", pType, 0) or 0
        score = hp * 0.70 + math.min(100, energy) * 0.07 + 5
        if IsKnown(S.VANISH) and CooldownReady(S.VANISH) and IsUsable(S.VANISH) then score = score + 14 end
        if IsKnown(S.EVASION) and CooldownReady(S.EVASION) and IsUsable(S.EVASION) then score = score + 10 end
        if IsKnown(S.GOUGE) and CooldownReady(S.GOUGE) and IsUsable(S.GOUGE) then score = score + 5 end
        if IsKnown(S.SPRINT) and CooldownReady(S.SPRINT) and IsUsable(S.SPRINT) then score = score + 4 end
    return score
end

function Class:GetPanicRecommendation()
        if IsKnown(S.BLIND) and CooldownReady(S.BLIND) and IsUsable(S.BLIND) then return S.BLIND, "BLIND + RESET", "CAST MANUALLY", "Create a clean reset window before Vanish if possible" end
        if IsKnown(S.VANISH) and CooldownReady(S.VANISH) and IsUsable(S.VANISH) then return S.VANISH, "VANISH", "ALL MODS", "Reset / escape: use it after a swing or with a little space" end
        if IsKnown(S.EVASION) and CooldownReady(S.EVASION) and IsUsable(S.EVASION) then return S.EVASION, "EVASION", "ALT+CTRL", "Reduce melee pressure while preparing to exit" end
        if IsKnown(S.GOUGE) and CooldownReady(S.GOUGE) and IsUsable(S.GOUGE) then return S.GOUGE, "GOUGE + RUN", "CTRL", "Create a window for bandage/distance" end
        if IsKnown(S.SPRINT) and CooldownReady(S.SPRINT) and IsUsable(S.SPRINT) then return S.SPRINT, "SPRINT + RUN", "ALT", "Extend the leash" end
        return nil, "RUN!", "PREPARE ESCAPE", "Vanish/Evasion unavailable"
end

function Class:GetMultiPullRecommendation(enemies, hp, targetHP)
        if enemies >= 3 or hp <= 48 then
            local id, _, key, reason = self:GetPanicRecommendation()
            return id, enemies >= 3 and "3+ MOBS - VANISH" or "MULTI - GET OUT", key or "ALL MODS", reason or "Reset the pull", "danger"
        end
        if IsKnown(S.BLADE_FLURRY) and CooldownReady(S.BLADE_FLURRY) and IsUsable(S.BLADE_FLURRY) and hp >= 68 then
            return S.BLADE_FLURRY, "MULTI x2 - BLADE FLURRY", "CAST MANUALLY", "Only if the pull is already stable; do not add more mobs", "caution"
        end
        if IsKnown(S.EVASION) and CooldownReady(S.EVASION) and IsUsable(S.EVASION) and hp <= 65 then
            return S.EVASION, "MULTI x2 - EVASION", "ALT+CTRL", "Reduce pressure and prepare Vanish if it worsens", "caution"
        end
        return nil, "MULTI x2", "CONTROL / EXIT", "Do not greed DPS without Vanish available", "caution"
end

-- Class interrupt contract. Advisor/Threat only detects the cast;
-- the class decides which control/interrupt spell is valid.
function Class:GetInterruptRecommendation()
        if IsKnown(S.KICK) and CooldownReady(S.KICK) then return S.KICK, "INTERRUPT!", "CTRL+SHIFT", "Kick" end
end

-- Secure macro class contract. Core/Macros owns only secure attribute orchestration;
-- the class owns its base action and modifier spell choices.
function Class:BuildMainMacro()
        local lines = NewLines()
        local spec = TalentSpec()
        local builder = (spec == 3 and IsKnown(S.HEMORRHAGE)) and S.HEMORRHAGE or S.SINISTER_STRIKE
        AddLine(lines, "/startattack", 1)
        AddLine(lines, CastLine(builder, "combat,harm", false), 1)
        return FitMacro(lines)
end

function Class:BuildModifierMacros()
        return {
            shift=BuildSpellMacro(S.STEALTH), ctrl=BuildSpellMacro(S.GOUGE, "harm", true),
            alt=BuildSpellMacro(S.SPRINT), ctrlshift=BuildSpellMacro(S.KICK, "harm", true),
            altshift=BuildSpellMacro(S.EVISCERATE, "harm", true), altctrl=BuildSpellMacro(S.EVASION),
            all=BuildSpellMacro(S.VANISH),
            desc={shift="Stealth",ctrl="Gouge",alt="Sprint",ctrlshift="Kick",altshift="Eviscerate",altctrl="Evasion",all="Vanish"}
        }
end

function Class:GetBaseActionInfo(spec)
    local builder = (spec == 3 and IsKnown(S.HEMORRHAGE)) and S.HEMORRHAGE or S.SINISTER_STRIKE
    return builder, SpellName(builder, "Builder")
end

