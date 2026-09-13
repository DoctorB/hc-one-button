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

function Class:SpellManaCost(id)
    -- A localized name resolves the learned rank and the client's current
    -- cost modifiers. Missing data is not a zero-cost spell.
    local name = API.SpellName(id)
    local function ReadCost(api)
        if not api or not name then return nil end
        local ok, costs = pcall(api, name)
        if not ok or type(costs) ~= "table" then return nil end
        for _, entry in ipairs(costs) do
            if type(entry) == "table" and SafeNumber(entry.type, nil) == 0 then
                local cost = SafeNumber(entry.cost, nil)
                if cost and cost == cost and cost >= 0 and cost < math.huge then return cost end
            end
        end
    end
    local cost = ReadCost(GetSpellPowerCost)
    if cost == nil then cost = ReadCost(C_Spell and C_Spell.GetSpellPowerCost) end
    return cost
end

local function DamageBudget(ctx)
    local mana = ctx.player.mana
    local maxMana = SafeUnitPowerMax and SafeUnitPowerMax("player", 0, nil)
    if not maxMana or maxMana ~= maxMana or maxMana <= 0 or maxMana == math.huge then maxMana = nil end
    local floorPct = (ctx.player.hp <= 72 or ctx.combat.reserve < 52) and 25 or 15
    local reserveMana = maxMana and maxMana * floorPct / 100 or nil
    if reserveMana then
        -- Bank at least one currently available Shield/heal when its real
        -- cost is known, as well as the percentage floor. Never lower the
        -- floor because one emergency spell has an unknown cost.
        local recoveryCost
        local heal = Engine.PriestHealSpell(true)
        for _, id in pairs({shield=S.POWER_WORD_SHIELD, heal=heal}) do
            if API.IsKnown(id) and API.IsUsable(id)
               and (id ~= S.POWER_WORD_SHIELD or not Engine.PlayerHasDebuff(S.WEAKENED_SOUL)) then
                local cost = Class:SpellManaCost(id)
                if cost then recoveryCost = math.min(recoveryCost or cost, cost) end
            end
        end
        reserveMana = math.max(reserveMana, recoveryCost or 0)
    end
    return function(id, fallbackPct)
        if not API.IsKnown(id) or not API.IsUsable(id) or not API.CooldownReady(id) then return false end
        local cost = maxMana and Class:SpellManaCost(id)
        if cost then return maxMana * mana / 100 - cost >= reserveMana end
        return mana >= math.max(fallbackPct, floorPct + 10)
    end
end

local function DamageCastSeconds(id)
    local name = API.SpellName(id)
    local ms
    if name and GetSpellInfo then
        local ok, _, _, _, castTime = pcall(GetSpellInfo, name)
        if ok then ms = SafeNumber(castTime, nil) end
    end
    if not ms and name and C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        if ok and type(info) == "table" then ms = SafeNumber(info.castTime, nil) end
    end
    if ms and ms == ms and ms > 0 and ms < math.huge then return ms / 1000 end
    -- Channels commonly expose zero castTime; retain their duration fallback.
    return API.SpellCastSeconds(id)
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
    local shielded = API.StablePlayerBuff(S.POWER_WORD_SHIELD)
    local weakened = Engine.PlayerHasDebuff(S.WEAKENED_SOUL)
    local hasWand = API.HasWandEquipped() and API.IsKnown(S.SHOOT)
    local canSpend = DamageBudget(ctx)

    -- Openers remain available out of combat, but self auras are never part of
    -- the idle/pre-pull recommendation stream.
    if not ctx.inCombat and ctx.hostile then
        if ctx.spec ~= 3 and canSpend(S.HOLY_FIRE, 45) then
            Engine.AddCandidate(candidates, S.HOLY_FIRE, "HOLY FIRE OPENER", "CAST MANUALLY",
                "Open at range with a learned Holy spell while preserving recovery mana", 85, "opener")
        elseif canSpend(S.MIND_BLAST, 35) then
            Engine.AddCandidate(candidates, S.MIND_BLAST, "MIND BLAST OPENER", "ALT+SHIFT",
                "Open with burst from maximum range before the target reaches you", 85, "opener")
        elseif canSpend(S.SMITE, 30) then
            Engine.AddCandidate(candidates, S.SMITE, "SMITE OPENER", "CAST MANUALLY",
                "Use the learned cast-time opener even before Shadow talent spells are available", 76, "opener")
        elseif canSpend(S.SHADOW_WORD_PAIN, 30) then
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
    local function CastFits(id, minimumLifetime, channel)
        local cast = DamageCastSeconds(id)
        if close and not shielded and (channel or hp < 80 or reserve < 65) then return false end
        if dyn and (dyn.confidence or 0) >= 0.38 and dyn.ttd and dyn.ttd < cast + 1 then return false end
        return not ttk or ttk >= math.max(minimumLifetime or 0, cast + 0.35)
    end

    local hasInner, innerRemaining = API.StablePlayerBuff(S.INNER_FIRE)
    if API.IsKnown(S.INNER_FIRE) and API.IsUsable(S.INNER_FIRE)
       and (not hasInner or innerRemaining <= 10) then
        local reason = hasInner and ("Refresh before expiry (" .. math.floor(innerRemaining) .. "s)") or "Inner Fire missing in combat"
        Engine.AddCandidate(candidates, S.INNER_FIRE, "INNER FIRE", "CAST MANUALLY", reason .. " | " .. context, hasInner and 65 or 86, "buff")
    end
    local hasFortitude, fortitudeRemaining = API.StablePlayerBuff(S.FORTITUDE)
    if API.IsKnown(S.FORTITUDE) and API.IsUsable(S.FORTITUDE)
       and (not hasFortitude or fortitudeRemaining <= 10) then
        local reason = hasFortitude and ("Refresh before expiry (" .. math.floor(fortitudeRemaining) .. "s)") or "Fortitude missing in combat"
        Engine.AddCandidate(candidates, S.FORTITUDE, "FORTITUDE", "CAST MANUALLY", reason .. " | " .. context, hasFortitude and 63 or 84, "buff")
    end

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

    local renew = API.StablePlayerBuff(S.RENEW)
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
    if not pain and canSpend(S.SHADOW_WORD_PAIN, 30) and targetHP >= 40 and reserve >= 43 then
        local longEnough = not ttk or ttk >= 9
        if longEnough then
            Engine.AddCandidate(candidates, S.SHADOW_WORD_PAIN, "SHADOW WORD: PAIN", "CAST MANUALLY",
                "Efficient DoT only while enough target lifetime remains | " .. context,
                ctx.spec == 3 and 88 or 85, "dot")
        end
    end

    if canSpend(S.MIND_BLAST, 35) and (targetHP >= 18 or not hasWand) and reserve >= 46 and CastFits(S.MIND_BLAST) then
        local score = ctx.spec == 3 and 84 or 82
        Engine.AddCandidate(candidates, S.MIND_BLAST, "MIND BLAST", "ALT+SHIFT",
            "Prioritize burst while banking recovery mana and allowing the cast to land | " .. context, score, "damage")
    end

    -- Learned/usable actives, not the winning talent tab, determine access.
    -- One point in Spirit Tap must not remove Smite before Mind Flay is learned.
    if canSpend(S.MIND_FLAY, 30) and (targetHP >= 24 or not hasWand) and reserve >= 49 and CastFits(S.MIND_FLAY, 3.35, true) then
        Engine.AddCandidate(candidates, S.MIND_FLAY, "MIND FLAY", "CAST MANUALLY",
            "Use learned Shadow filler, including mixed builds, while keeping recovery mana | " .. context,
            ctx.spec == 3 and 80 or 78, "damage")
    end
    if canSpend(S.HOLY_FIRE, 45) and not API.HasMyTargetDebuff(S.HOLY_FIRE)
       and targetHP >= 50 and reserve >= 52 and CastFits(S.HOLY_FIRE, DamageCastSeconds(S.HOLY_FIRE) + 6) then
        Engine.AddCandidate(candidates, S.HOLY_FIRE, "HOLY FIRE", "CAST MANUALLY",
            "Add learned Holy damage when there is time for the cast and useful DoT ticks | " .. context, 81, "damage")
    end

    if canSpend(S.SMITE, 30) and (targetHP >= 24 or not hasWand) and reserve >= 50 and CastFits(S.SMITE) then
        local score = ctx.spec == 2 and 77 or 74
        Engine.AddCandidate(candidates, S.SMITE, "SMITE", "CAST MANUALLY",
            "Keep casting between burst windows; do not idle just because the first talent point is Shadow | " .. context, score, "damage")
    end

    if hasWand and not close then
        -- Always retain a usable no-mana fallback, but it must not beat
        -- burst/filler merely because HP or mana passed the halfway mark.
        local finishing = targetHP <= 20 and (not ttk or ttk <= 4)
        local conserve = mana <= 25
        -- The ordinary fallback stays below funded filler even across the
        -- learner's +/-12 bias and the four-point display hysteresis.
        local score = finishing and 90 or (conserve and 87 or 45)
        Engine.AddCandidate(candidates, S.SHOOT, "WAND / SPIRIT TAP", "CAST MANUALLY",
            "Conserve low mana or finish a nearly defeated target; Spirit Tap alone does not stop offensive casting | " .. context,
            score, "efficiency")
    end

    return candidates
end

function Class:GetRecommendation(inCombat, hostile, targetHP, spec)
    local ctx = Engine.BuildClassContext(inCombat, hostile, targetHP, spec)
    return Engine.SelectCandidate(self:GetCandidates(ctx))
end


-- Advisor class contract extensions.
function Class:GetBuffRecommendation(inCombat)
    return nil
end

function Class:GetIdleRecommendation(inCombat, hostile)
    -- Without a wand, generic BASE fallback would otherwise immediately offer
    -- Smite again after the class declined it for mana/casting safety.
    if hostile and (not API.HasWandEquipped() or not API.IsKnown(S.SHOOT)) then
        return nil, "NO SPELL READY", "WAIT / RECOVER",
            "Wait for recovery mana, cooldowns or a safe casting window", "idle"
    end
end

function Class:GetCautionRecommendation(ctx)
    if API.IsKnown(S.POWER_WORD_SHIELD) and API.IsUsable(S.POWER_WORD_SHIELD) and not API.StablePlayerBuff(S.POWER_WORD_SHIELD) and not Engine.PlayerHasDebuff(S.WEAKENED_SOUL) then
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
        local shielded = StablePlayerBuff(S.POWER_WORD_SHIELD)
        local weakened = HCOB.Advisor.Engine.PlayerHasDebuff(S.WEAKENED_SOUL)
        if shielded then score = score + 10
        elseif IsKnown(S.POWER_WORD_SHIELD) and IsUsable(S.POWER_WORD_SHIELD) and not weakened then score = score + 5
        elseif weakened then score = score - 3 end
        if StablePlayerBuff(S.INNER_FIRE) then score = score + 3 end
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
        if IsKnown(S.POWER_WORD_SHIELD) and IsUsable(S.POWER_WORD_SHIELD) and not StablePlayerBuff(S.POWER_WORD_SHIELD) and not HCOB.Advisor.Engine.PlayerHasDebuff(S.WEAKENED_SOUL) then
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

function Class:IsRangedBaseAction(id)
    local baseId = self:GetBaseActionInfo(TalentSpec())
    return id == baseId
end

