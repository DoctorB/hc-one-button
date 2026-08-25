local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Class = HCOB.Classes.PRIEST or {}
HCOB.Classes.PRIEST = Class
Class.classToken = "PRIEST"
Class.fallbackSpec = 3

local Engine = HCOB.Advisor.Engine
local API = HCOB.Core.ClassAPI
local S = HCOB.Data.Spells

local function CoreBuffsReady()
    if API.IsKnown(S.INNER_FIRE) and not API.HasPlayerBuff(S.INNER_FIRE) then return false end
    if API.IsKnown(S.FORTITUDE) and not API.HasPlayerBuff(S.FORTITUDE) then return false end
    return true
end

local function ContextText(ctx, spiritTap)
    local text = string.format(
        "HP %.0f%% | mana %.0f%% | reserve %.0f %s",
        ctx.player.hp, ctx.player.mana, ctx.combat.reserve, ctx.combat.reserveLabel or "?"
    )
    local ttk = ctx.combat.ttk
    if ttk and ttk < math.huge then text = text .. string.format(" | TTK ~%.0fs", ttk) end
    if spiritTap then text = text .. " | Spirit Tap" end
    return text
end

function Class:GetCandidates(ctx)
    local candidates = {}
    local mana = ctx.player.mana
    local targetHP = ctx.target.hp
    local shielded = API.HasPlayerBuff(S.POWER_WORD_SHIELD)
    local weakened = Engine.PlayerHasDebuff(S.WEAKENED_SOUL)

    -- Out of combat, missing long buffs are intentionally left to
    -- BuffRecommendation first. Once prepared, Advisor can stage a safe opener.
    if not ctx.inCombat and ctx.hostile then
        if not CoreBuffsReady() then return candidates end

        if API.IsKnown(S.POWER_WORD_SHIELD) and API.IsUsable(S.POWER_WORD_SHIELD)
           and not shielded and not weakened and mana >= 55 then
            local score = ctx.target.tough and 95 or 88
            Engine.AddCandidate(candidates, S.POWER_WORD_SHIELD, "PRE-SHIELD", "ALT",
                ctx.target.tough and "Pre-pull absorption before a difficult target" or "Pre-pull absorption prevents pushback and preserves control",
                score, "opener")
        end

        if ctx.spec == 3 and API.IsKnown(S.MIND_BLAST) and API.CooldownReady(S.MIND_BLAST)
           and API.IsUsable(S.MIND_BLAST) and mana >= 45 then
            Engine.AddCandidate(candidates, S.MIND_BLAST, "MIND BLAST OPENER", "ALT+SHIFT",
                "Open from maximum range before the target reaches you", 79, "opener")
        elseif ctx.spec ~= 3 and API.IsKnown(S.HOLY_FIRE) and API.IsUsable(S.HOLY_FIRE) and mana >= 48 then
            Engine.AddCandidate(candidates, S.HOLY_FIRE, "HOLY FIRE OPENER", "CAST MANUALLY",
                "Efficient long-range opener for Discipline/Holy leveling", 77, "opener")
        elseif API.IsKnown(S.SHADOW_WORD_PAIN) and API.IsUsable(S.SHADOW_WORD_PAIN) and mana >= 35 then
            Engine.AddCandidate(candidates, S.SHADOW_WORD_PAIN, "SHADOW WORD: PAIN", "CAST MANUALLY",
                "Fallback opener: establish the efficient DoT before wanding", 68, "opener")
        end
        return candidates
    end

    if not ctx.inCombat or not ctx.hostile then return candidates end

    local hp = ctx.player.hp
    local close = ctx.target.close
    local reserve = ctx.combat.reserve
    local dyn = ctx.combat.dynamics
    local ttk = ctx.combat.ttk
    local spiritTap = API.HasPlayerBuff(S.SPIRIT_TAP)
    local context = ContextText(ctx, spiritTap)

    if ctx.player.grouped and ctx.target.onPlayer and reserve <= 58 and API.IsKnown(S.FADE)
       and API.CooldownReady(S.FADE) and API.IsUsable(S.FADE) then
        Engine.AddCandidate(candidates, S.FADE, "FADE", "CAST MANUALLY",
            "Group threat is on you: reduce threat while the tank/party regains control | " .. context,
            98, "survival")
    end

    if close and targetHP > 25 and (reserve <= 40 or hp <= 50)
       and API.IsKnown(S.PSYCHIC_SCREAM) and API.CooldownReady(S.PSYCHIC_SCREAM)
       and API.IsUsable(S.PSYCHIC_SCREAM) then
        Engine.AddCandidate(candidates, S.PSYCHIC_SCREAM, "PSYCHIC SCREAM + DISTANCE", "ALL MODS",
            "Create a healing/escape window only if the fear path cannot reach another pack | " .. context,
            107, "survival", "caution")
    end

    if not shielded and not weakened and API.IsKnown(S.POWER_WORD_SHIELD) and API.IsUsable(S.POWER_WORD_SHIELD)
       and mana >= 18 and (hp <= 72 or close or reserve < 52) then
        local score = 90 + (close and 8 or 0) + math.max(0, 62 - hp) * 0.35
        Engine.AddCandidate(candidates, S.POWER_WORD_SHIELD, "POWER WORD: SHIELD", "ALT",
            "Prevent pushback and buy time for the next heal/control decision | " .. context, score, "survival")
    end

    local heal = Engine.PriestHealSpell(hp <= 42 or (close and hp <= 50))
    if heal and hp <= 60 and mana >= 18 then
        local cast = API.SpellCastSeconds(heal)
        local ttdSafe = not dyn or dyn.ttd == math.huge or dyn.ttd >= cast + 1.0 or shielded
        if ttdSafe then
            local score = 91 + math.max(0, 60 - hp) * 0.55
            if heal == S.FLASH_HEAL and hp <= 42 then score = score + 8 end
            if close and not shielded then score = score - 5 end
            Engine.AddCandidate(candidates, heal, API.SpellName(heal, "HEAL"), "CAST MANUALLY",
                "Stabilize before the rolling fight trend becomes critical | " .. context, score, "survival")
        end
    end

    local renew = API.HasPlayerBuff(S.RENEW)
    if API.IsKnown(S.RENEW) and API.IsUsable(S.RENEW) and not renew
       and hp <= 78 and mana >= 30 and targetHP >= 32 then
        local longEnough = not ttk or ttk >= 8
        if longEnough then
            local score = 71 + (hp <= 62 and 9 or 0) + (close and 3 or 0)
            Engine.AddCandidate(candidates, S.RENEW, "RENEW", "ALT+CTRL",
                "Sustain HP while continuing wand or damage actions | " .. context, score, "sustain")
        end
    end

    local pain = API.HasMyTargetDebuff(S.SHADOW_WORD_PAIN)
    if API.IsKnown(S.SHADOW_WORD_PAIN) and API.IsUsable(S.SHADOW_WORD_PAIN) and not pain
       and mana >= 30 and targetHP >= 45 and reserve >= 43 then
        local longEnough = not ttk or ttk >= 10
        if longEnough then
            Engine.AddCandidate(candidates, S.SHADOW_WORD_PAIN, "SHADOW WORD: PAIN", "CAST MANUALLY",
                "Efficient DoT only while enough target lifetime remains | " .. context,
                ctx.spec == 3 and 75 or 70, "dot")
        end
    end

    if API.IsKnown(S.MIND_BLAST) and API.CooldownReady(S.MIND_BLAST) and API.IsUsable(S.MIND_BLAST)
       and mana >= 46 and targetHP >= 24 and reserve >= 46 then
        local score = targetHP <= 34 and 82 or (ctx.spec == 3 and 73 or 64)
        if ttk and ttk < 5 then score = score - 12 end
        if close and not shielded then score = score - 10 end
        if spiritTap and mana <= 55 then score = score - 4 end
        Engine.AddCandidate(candidates, S.MIND_BLAST, "MIND BLAST", "ALT+SHIFT",
            "Use burst only when it does not compromise mana or casting safety | " .. context, score, "damage")
    end

    if ctx.spec == 3 and API.IsKnown(S.MIND_FLAY) and API.IsUsable(S.MIND_FLAY)
       and not close and mana >= 38 and targetHP >= 32 and reserve >= 49 then
        local longEnough = not ttk or ttk >= 5
        if longEnough then
            Engine.AddCandidate(candidates, S.MIND_FLAY, "MIND FLAY", "CAST MANUALLY",
                "Shadow filler adds damage and slow without overspending | " .. context, 63, "damage")
        end
    elseif ctx.spec ~= 3 and API.IsKnown(S.HOLY_FIRE) and API.IsUsable(S.HOLY_FIRE)
       and not close and mana >= 52 and targetHP >= 58 and reserve >= 52 then
        local longEnough = not ttk or ttk >= 8
        if longEnough then
            Engine.AddCandidate(candidates, S.HOLY_FIRE, "HOLY FIRE", "CAST MANUALLY",
                "Discipline/Holy damage is worthwhile early in a safe, long fight | " .. context, 64, "damage")
        end
    end

    if ctx.spec ~= 3 and API.IsKnown(S.SMITE) and API.IsUsable(S.SMITE) and not close
       and mana >= 28 and targetHP >= 26 and reserve >= 50 then
        local score = 62 + (ctx.spec == 2 and 5 or 0)
        if mana <= 40 then score = score - 5 end
        Engine.AddCandidate(candidates, S.SMITE, "SMITE", "BASE", "Mana-aware Holy/Discipline filler once setup spells are established | " .. context, score, "damage")
    end

    if API.HasWandEquipped() and API.IsKnown(S.SHOOT) and not close then
        if targetHP <= 55 or mana <= 52 or spiritTap then
            local score = 77 + (targetHP <= 32 and 10 or 0) + (mana <= 34 and 7 or 0) + (spiritTap and 8 or 0)
            if targetHP <= 20 then score = score + 4 end
            Engine.AddCandidate(candidates, S.SHOOT, "WAND / SPIRIT TAP", "CAST MANUALLY",
                "Finish efficiently to preserve mana, enter the five-second rule and maximize Spirit Tap cadence | " .. context,
                score, "efficiency")
        end
    end

    return candidates
end

function Class:GetRecommendation(inCombat, hostile, targetHP, spec)
    local ctx = Engine.BuildClassContext(inCombat, hostile, targetHP, spec)
    return Engine.SelectCandidate(self:GetCandidates(ctx))
end


-- Advisor class contract extensions.
function Class:GetBuffRecommendation(inCombat)
    if inCombat then return nil end
    if API.IsKnown(S.INNER_FIRE) then
        local hasInner, innerRemain = API.HasPlayerBuff(S.INNER_FIRE)
        if not hasInner then return S.INNER_FIRE, "INNER FIRE", "CAST MANUALLY", "Armor buff missing" end
        if innerRemain < 20 then return S.INNER_FIRE, "INNER FIRE SOON", "CAST MANUALLY", "Expires in " .. math.floor(innerRemain) .. "s" end
    end
    if API.IsKnown(S.FORTITUDE) then
        local hasFort, fortRemain = API.HasPlayerBuff(S.FORTITUDE)
        if not hasFort then return S.FORTITUDE, "FORTITUDE", "CAST MANUALLY", "Health buff missing" end
        if fortRemain < 20 then return S.FORTITUDE, "FORTITUDE SOON", "CAST MANUALLY", "Expires in " .. math.floor(fortRemain) .. "s" end
    end
end

function Class:GetCautionRecommendation(ctx)
    if API.IsKnown(S.POWER_WORD_SHIELD) and API.IsUsable(S.POWER_WORD_SHIELD) and not API.HasPlayerBuff(S.POWER_WORD_SHIELD) and not Engine.PlayerHasDebuff(S.WEAKENED_SOUL) then
        return S.POWER_WORD_SHIELD, "UNFAVORABLE FIGHT", "ALT", ctx.text .. ": Shield before incoming damage accelerates", "caution"
    end
    local heal = Engine.PriestHealSpell(ctx.hp <= 45)
    if heal and ctx.hp <= 58 then return heal, "UNFAVORABLE FIGHT", "CAST MANUALLY", ctx.text .. ": stabilize HP", "caution" end
end

-- Hardcore safety class contract. Advisor/Survival owns policy orchestration;
-- this class owns its spells and class-specific escape/resource model.
function Class:GetSurvivalReserve(ctx)
    local hp, mana = ctx.hp, ctx.mana
    local score
        score = hp * 0.52 + mana * 0.18 + 8
        local shielded = HasPlayerBuff(S.POWER_WORD_SHIELD)
        local weakened = HCOB.Advisor.Engine.PlayerHasDebuff(S.WEAKENED_SOUL)
        if shielded then score = score + 10
        elseif IsKnown(S.POWER_WORD_SHIELD) and IsUsable(S.POWER_WORD_SHIELD) and not weakened then score = score + 5
        elseif weakened then score = score - 3 end
        if HasPlayerBuff(S.INNER_FIRE) then score = score + 3 end
        if IsKnown(S.PSYCHIC_SCREAM) and CooldownReady(S.PSYCHIC_SCREAM) and IsUsable(S.PSYCHIC_SCREAM) then score = score + 10 end
        if HCOB.Advisor.Engine.PriestHealSpell(false) then score = score + 6 end
        if IsKnown(S.RENEW) and IsUsable(S.RENEW) then score = score + 2 end
        if HCOB.Advisor.Engine.TargetOnPlayer() then score = score - 4 end
        if HCOB.Advisor.Engine.TargetIsClose() then score = score - 8 end
    return score
end

function Class:GetPanicRecommendation()
        if IsKnown(S.PSYCHIC_SCREAM) and CooldownReady(S.PSYCHIC_SCREAM) and IsUsable(S.PSYCHIC_SCREAM) then return S.PSYCHIC_SCREAM, "PSYCHIC SCREAM", "ALL MODS", "Create distance; avoid fearing toward other packs" end
        if IsKnown(S.POWER_WORD_SHIELD) and IsUsable(S.POWER_WORD_SHIELD) and not HCOB.Advisor.Engine.PlayerHasDebuff(S.WEAKENED_SOUL) then return S.POWER_WORD_SHIELD, "POWER WORD: SHIELD", "ALT", "Buy time for healing/escape" end
        local heal = HCOB.Advisor.Engine.PriestHealSpell(true)
        if heal then return heal, SpellName(heal,"HEAL"), "CAST MANUALLY", "No control ready: stabilize HP" end
        return nil, "RUN!", "PREPARE ESCAPE", "Scream/Shield/heal unavailable"
end

function Class:GetMultiPullRecommendation(enemies, hp, targetHP)
        if enemies >= 3 or hp <= 48 then
            local id, _, key, reason = self:GetPanicRecommendation()
            return id, enemies >= 3 and "3+ MOBS - GET OUT" or "MULTI - STABILIZE", key or "ALL MODS", reason or "Shield/Scream/escape", "danger"
        end
        if IsKnown(S.POWER_WORD_SHIELD) and IsUsable(S.POWER_WORD_SHIELD) and not HasPlayerBuff(S.POWER_WORD_SHIELD) and not HCOB.Advisor.Engine.PlayerHasDebuff(S.WEAKENED_SOUL) then
            return S.POWER_WORD_SHIELD, "MULTI x2 - SHIELD", "ALT", "Buy time; avoid turning the pull into mana spam", "caution"
        end
        if IsKnown(S.PSYCHIC_SCREAM) and CooldownReady(S.PSYCHIC_SCREAM) and IsUsable(S.PSYCHIC_SCREAM) and hp <= 62 then
            return S.PSYCHIC_SCREAM, "MULTI x2 - SCREAM", "ALL MODS", "Use it only if Fear cannot pull other packs", "caution"
        end
        return nil, "MULTI x2", "WAND / CONTROL", "Conserve mana and an escape route", "caution"
end

-- Class interrupt contract. Advisor/Threat only detects the cast;
-- the class decides which control/interrupt spell is valid.
function Class:GetInterruptRecommendation()
        if IsKnown(S.SILENCE) and CooldownReady(S.SILENCE) then return S.SILENCE, "SILENCE!", "CTRL+SHIFT", "Silence" end
end

-- Secure macro class contract. Core/Macros owns only secure attribute orchestration;
-- the class owns its base action and modifier spell choices.
function Class:BuildMainMacro()
        local lines = NewLines()
        local spec = TalentSpec()
        if HasWandEquipped() and IsKnown(S.SHOOT) then
            AddLine(lines, "/cast [harm] !" .. SpellName(S.SHOOT), 1)
        elseif spec == 3 and IsKnown(S.MIND_FLAY) then
            AddLine(lines, CastLine(S.MIND_FLAY, "harm", false), 1)
        else
            AddLine(lines, CastLine(S.SMITE, "harm", false), 1)
        end
        return FitMacro(lines)
end

function Class:BuildModifierMacros()
        return {
            shift=BuildSpellMacro(S.FORTITUDE, "@player"), ctrl=BuildSpellMacro(S.PSYCHIC_SCREAM),
            alt=BuildSpellMacro(S.POWER_WORD_SHIELD, "@player"), ctrlshift=BuildSpellMacro(S.SILENCE, "harm"),
            altshift=BuildSpellMacro(S.MIND_BLAST, "harm"), altctrl=BuildSpellMacro(S.RENEW, "@player"),
            all=BuildSpellMacro(S.PSYCHIC_SCREAM),
            desc={shift="Power Word: Fortitude",ctrl="Psychic Scream",alt="Power Word: Shield",ctrlshift="Silence",altshift="Mind Blast",altctrl="Renew",all="Psychic Scream"}
        }
end

function Class:GetBaseActionInfo(spec)
    if HasWandEquipped() and IsKnown(S.SHOOT) then return S.SHOOT, "WAND" end
    if spec == 3 and IsKnown(S.MIND_FLAY) then return S.MIND_FLAY, "MIND FLAY" end
    return S.SMITE, "SMITE"
end

