local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Class = HCOB.Classes.MAGE or {}
HCOB.Classes.MAGE = Class
Class.classToken = "MAGE"
Class.fallbackSpec = 3

local Mage = Class

function Mage.ManaPct()
    local pct, readable = UnitPowerPct("player", 0)
    return readable and pct or 0
end

function Mage.TargetIsClose()
    if not HostileLiveTarget() then return false end
    if Mage.lastMeleeAt and (GetTime() - Mage.lastMeleeAt) <= 2.5 then return true end
    -- Duel distance is roughly 7 yards and works on hostile units too.
    -- We use it only as a conservative melee-pressure hint.
    if CheckInteractDistance then
        local ok, close = pcall(CheckInteractDistance, "target", 3)
        if ok and CanAccessValue(close) then return SafeBoolean(close, false) end
    end
    return false
end

function Mage.PolymorphEligible()
    if not HostileLiveTarget() or not UnitCreatureType then return false end
    local ok, _, creatureTypeID = pcall(UnitCreatureType, "target")
    if not ok then return false end
    -- Classic Polymorph: Beast, Humanoid, Critter.
    return creatureTypeID == 1 or creatureTypeID == 7 or creatureTypeID == 8
end

function Mage.RankedName(id)
    if GetSpellInfo then
        local name, rank = GetSpellInfo(id)
        if name and rank and rank ~= "" then
            return name .. "(" .. rank .. ")"
        end
    end
    return SpellName(id)
end

function Mage.PrimarySpell()
    local spec = TalentSpec()
    local level = PlayerLevel()

    if spec == 3 and IsKnown(S.FROSTBOLT) then return S.FROSTBOLT end
    if spec == 2 and IsKnown(S.FIREBALL) then return S.FIREBALL end

    if spec == 1 then
        if level >= 47 and IsKnown(S.FROSTBOLT) then return S.FROSTBOLT end
        if IsKnown(S.FIREBALL) then return S.FIREBALL end
        if IsKnown(S.FROSTBOLT) then return S.FROSTBOLT end
        if IsKnown(S.ARCANE_MISSILES) then return S.ARCANE_MISSILES end
    end

    if IsKnown(S.FROSTBOLT) then return S.FROSTBOLT end
    if IsKnown(S.FIREBALL) then return S.FIREBALL end
    return S.ARCANE_MISSILES
end

function Mage.BestArmor()
    local spec = TalentSpec()
    if spec ~= 3 and IsKnown(S.MAGE_ARMOR) then return S.MAGE_ARMOR end
    if IsKnown(S.ICE_ARMOR) then return S.ICE_ARMOR end
    if IsKnown(S.FROST_ARMOR) then return S.FROST_ARMOR end
    if IsKnown(S.MAGE_ARMOR) then return S.MAGE_ARMOR end
    return nil
end


function Class:GetRecommendation(inCombat, hostile, targetHP, spec)
    local candidates = {}
    local manaPct = Mage.ManaPct()
    local hp = UnitHealthPct("player")
    local level = PlayerLevel()
    local targetLevel = hostile and SafeUnitLevel("target", level) or level
    local classification = hostile and SafeUnitClassification("target", "normal") or "normal"
    local tough = hostile and (classification == "elite" or classification == "rareelite" or classification == "worldboss" or targetLevel >= level + 1) or false

    -- Out-of-combat candidates are scored too: low mana should beat a fancy
    -- Pyro opener, while Pyro still appears on a real hard target when ready.
    if not inCombat and manaPct <= 40 and IsKnown(S.EVOCATION) and CooldownReady(S.EVOCATION) and IsUsable(S.EVOCATION) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.EVOCATION, "EVOCATION", "CAST MANUALLY", string.format("Mana %.0f%%: recover before the pull", manaPct), 96, "sustain")
    end
    if not inCombat and hostile and spec == 2 and IsKnown(S.PYROBLAST) and IsUsable(S.PYROBLAST) and tough then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.PYROBLAST, "PYRO OPENER", "CAST MANUALLY", "Durable target: open from maximum range", 72, "opener")
    end
    if not inCombat or not hostile then return HCOB.Advisor.Engine.SelectCandidate(candidates) end

    local close = Mage.TargetIsClose()
    local rooted = HasMyTargetDebuff(S.FROST_NOVA)
    local reserve, reserveLabel = HCOB.Advisor.Engine.SurvivalReserve()
    local dyn = HCOB.Advisor.Engine.RollingDynamics(targetHP)
    local estimatedTTK = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local riskPenalty = reserve < 55 and ((55 - reserve) * 0.65) or 0
    if reserve < 35 then riskPenalty = riskPenalty + 9 end
    local context = string.format("mana %.0f%% | reserve %.0f %s", manaPct, reserve, reserveLabel)
    if estimatedTTK and estimatedTTK < math.huge then context = context .. string.format(" | TTK ~%.0fs", estimatedTTK) end
    local clearcasting = HasPlayerBuff(S.CLEARCASTING)
    local primary = Mage.PrimarySpell()

    if clearcasting and not close then
        local freeSpell = (spec == 1 and IsKnown(S.ARCANE_MISSILES) and IsUsable(S.ARCANE_MISSILES)) and S.ARCANE_MISSILES or primary
        if freeSpell and IsKnown(freeSpell) and IsUsable(freeSpell) then
            HCOB.Advisor.Engine.AddCandidate(candidates, freeSpell, "CLEARCASTING", "CAST MANUALLY", "Arcane Concentration proc: spend the free cast before returning to the mana plan | " .. context, 104, "proc")
        end
    end

    -- Instant kill is better than spending a major control cooldown on a mob
    -- already one global from death.
    if close and targetHP <= 35 and IsKnown(S.FIRE_BLAST) and CooldownReady(S.FIRE_BLAST) and IsUsable(S.FIRE_BLAST) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.FIRE_BLAST, "FIRE BLAST", "ALT+SHIFT", "Mob is close and low: finish it without a cast | " .. context, 108, "finisher")
    end

    if close and targetHP > 20 and not rooted and IsKnown(S.FROST_NOVA) and CooldownReady(S.FROST_NOVA) and IsUsable(S.FROST_NOVA) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.FROST_NOVA, "NOVA + DISTANCE", "CTRL", "Frost Nova R1, leave melee and resume BASE | " .. context, 106, "survival")
    end

    local novaUnavailable = not IsKnown(S.FROST_NOVA) or not CooldownReady(S.FROST_NOVA) or not IsUsable(S.FROST_NOVA)
    if close and not rooted and (hp <= 75 or reserve < 50) and novaUnavailable and IsKnown(S.BLINK) and CooldownReady(S.BLINK) and IsUsable(S.BLINK) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.BLINK, "BLINK OUT", "ALT", "Nova unavailable: create distance | " .. context, 100, "survival")
    end

    if reserve <= 28 and close and hp <= 48 and IsKnown(S.ICE_BLOCK) and CooldownReady(S.ICE_BLOCK) and IsUsable(S.ICE_BLOCK) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.ICE_BLOCK, "ICE BLOCK", "ALL MODS", "Critical reserve: stop the incoming-damage spiral | " .. context, 112, "survival")
    end

    local blockUnavailable = not IsKnown(S.ICE_BLOCK) or not CooldownReady(S.ICE_BLOCK) or not IsUsable(S.ICE_BLOCK)
    if reserve <= 34 and IsKnown(S.COLD_SNAP) and CooldownReady(S.COLD_SNAP) and IsUsable(S.COLD_SNAP)
       and ((IsKnown(S.FROST_NOVA) and novaUnavailable) or (IsKnown(S.ICE_BLOCK) and blockUnavailable)) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.COLD_SNAP, "COLD SNAP", "CAST MANUALLY", "Reset spent defensive control | " .. context, 101, "survival")
    end

    if IsKnown(S.ICE_BARRIER) and CooldownReady(S.ICE_BARRIER) and IsUsable(S.ICE_BARRIER) and manaPct >= 30 and targetHP >= 35 then
        local hasBarrier = HasPlayerBuff(S.ICE_BARRIER)
        if not hasBarrier then
            local score = (close or reserve < 55 or tough) and 88 or 64
            score = score - riskPenalty * 0.10
            HCOB.Advisor.Engine.AddCandidate(candidates, S.ICE_BARRIER, "ICE BARRIER", "CAST MANUALLY", "Barrier missing: buy time and stability | " .. context, score, "survival")
        end
    end

    -- Cone of Cold is a useful bridge when Nova is down: damage plus slow can
    -- buy the space needed for Blink/kiting without immediately reaching panic.
    if close and not rooted and novaUnavailable and targetHP > 28 and IsKnown(S.CONE_OF_COLD) and CooldownReady(S.CONE_OF_COLD) and IsUsable(S.CONE_OF_COLD) and manaPct >= 25 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.CONE_OF_COLD, "CONE + KITE", "CAST MANUALLY", "Nova unavailable: slow + damage, then create distance | " .. context, 91 - riskPenalty * 0.15, "control")
    end

    if close and hp <= 58 and manaPct >= 45 and IsKnown(S.MANA_SHIELD) and IsUsable(S.MANA_SHIELD)
       and novaUnavailable and (not IsKnown(S.BLINK) or not CooldownReady(S.BLINK)) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.MANA_SHIELD, "MANA SHIELD", "CAST MANUALLY", "Nova/Blink unavailable: temporary buffer | " .. context, 93, "survival")
    end

    if manaPct <= 18 and not close and not HCOB.Advisor.Engine.TargetOnPlayer() and targetHP >= 45
       and reserve >= 48 and IsKnown(S.EVOCATION) and CooldownReady(S.EVOCATION) and IsUsable(S.EVOCATION) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.EVOCATION, "EVOCATION", "CAST MANUALLY", "Very low mana with no direct pressure: recover before control options collapse | " .. context, 95, "sustain")
    end

    -- Wand is selected using mana + fight state rather than a single HP gate.
    if HasWandEquipped() and IsKnown(S.SHOOT) and not close then
        if targetHP <= 22 then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.SHOOT, "WAND FINISH", "SHIFT", "Conserve mana and start regeneration | " .. context, 82 + (manaPct <= 40 and 6 or 0), "efficiency")
        elseif manaPct <= 35 and targetHP <= 42 then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.SHOOT, "WAND / CONSERVE", "SHIFT", "Low mana: finish without another nuke | " .. context, 79, "efficiency")
        end
    end

    if targetHP <= 18 and IsKnown(S.FIRE_BLAST) and CooldownReady(S.FIRE_BLAST) and IsUsable(S.FIRE_BLAST) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.FIRE_BLAST, "FIRE BLAST", "ALT+SHIFT", "Instant finisher | " .. context, 88 - riskPenalty * 0.1, "finisher")
    end

    if spec == 1 and IsKnown(S.ARCANE_MISSILES) and IsUsable(S.ARCANE_MISSILES) and not close and manaPct >= 42 and reserve >= 52 and targetHP >= 32 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.ARCANE_MISSILES, "ARCANE MISSILES", "CAST MANUALLY", "Arcane filler while the channel is safe and mana is healthy | " .. context, clearcasting and 100 or 70, "damage")
    end
    if spec == 2 and IsKnown(S.SCORCH) and IsUsable(S.SCORCH) and not close and manaPct >= 28 and manaPct <= 55 and targetHP >= 28 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.SCORCH, "SCORCH", "CAST MANUALLY", "Shorter Fire filler to control mana expenditure late in the pull | " .. context, 66, "efficiency")
    end
    if primary and IsKnown(primary) and IsUsable(primary) and not close and manaPct >= 20 and targetHP >= 20 then
        local score = 63 + (spec == 3 and primary == S.FROSTBOLT and 8 or 0) + (spec == 2 and primary == S.FIREBALL and 7 or 0)
        if rooted and primary == S.FROSTBOLT then score = score + 6 end
        if manaPct <= 30 then score = score - 8 end
        HCOB.Advisor.Engine.AddCandidate(candidates, primary, SpellName(primary, "NUKE"), "BASE", "Primary spec-aware filler while distance and mana remain safe | " .. context, score, "damage")
    end

    return HCOB.Advisor.Engine.SelectCandidate(candidates)
end

-- Warlock and Priest recommendation logic lives in Classes/Warlock.lua and
-- Classes/Priest.lua. Runtime keeps only shared Advisor primitives/context.


-- Advisor class contract extensions.
function Class:GetBuffRecommendation(inCombat)
    if inCombat then return nil end
    if IsKnown(S.ICE_BARRIER) and CooldownReady(S.ICE_BARRIER) and IsUsable(S.ICE_BARRIER) then
        local hasBarrier, barrierRemain = HasPlayerBuff(S.ICE_BARRIER)
        if not hasBarrier then return S.ICE_BARRIER, "ICE BARRIER", "CAST MANUALLY", "Pre-pull: free absorption before risk" end
        if barrierRemain < 10 then return S.ICE_BARRIER, "BARRIER SOON", "CAST MANUALLY", "Expires in " .. math.floor(barrierRemain) .. "s" end
    end
    local armor = Mage.BestArmor()
    if armor and IsKnown(armor) then
        local hasArmor, armorRemain = HasPlayerBuff(armor)
        if not hasArmor then return armor, "MAGE ARMOR", "CAST MANUALLY", SpellName(armor) .. " missing" end
        if armorRemain < 20 then return armor, "ARMOR SOON", "CAST MANUALLY", "Expires in " .. math.floor(armorRemain) .. "s" end
    end
    if IsKnown(S.ARCANE_INTELLECT) then
        local hasInt, intRemain = HasPlayerBuff(S.ARCANE_INTELLECT)
        local intKey = HostileLiveTarget() and "CAST MANUALLY" or "SHIFT"
        if not hasInt then return S.ARCANE_INTELLECT, "ARCANE INT", intKey, "Intellect buff missing" end
        if intRemain < 20 then return S.ARCANE_INTELLECT, "INT SOON", intKey, "Expires in " .. math.floor(intRemain) .. "s" end
    end
end

-- Hardcore safety class contract. Advisor/Survival owns policy orchestration;
-- this class owns its spells and class-specific escape/resource model.
function Class:GetSurvivalReserve(ctx)
    local hp, mana = ctx.hp, ctx.mana
    local score
        score = hp * 0.50 + mana * 0.20
        if IsKnown(S.BLINK) and CooldownReady(S.BLINK) and IsUsable(S.BLINK) then score = score + 10 end
        if IsKnown(S.FROST_NOVA) and CooldownReady(S.FROST_NOVA) and IsUsable(S.FROST_NOVA) then score = score + 10 end
        if IsKnown(S.ICE_BLOCK) and CooldownReady(S.ICE_BLOCK) and IsUsable(S.ICE_BLOCK) then score = score + 12 end
        if IsKnown(S.COLD_SNAP) and CooldownReady(S.COLD_SNAP) and IsUsable(S.COLD_SNAP) then score = score + 6 end
        if IsKnown(S.ICE_BARRIER) then
            local hasBarrier = HasPlayerBuff(S.ICE_BARRIER)
            if hasBarrier then score = score + 7
            elseif CooldownReady(S.ICE_BARRIER) and IsUsable(S.ICE_BARRIER) and mana >= 25 then score = score + 3 end
        end
        if IsKnown(S.MANA_SHIELD) and IsUsable(S.MANA_SHIELD) and mana >= 45 then score = score + 2 end
        if Mage.TargetIsClose() then score = score - 10 end
    return score
end

function Class:GetPanicRecommendation()
        if IsKnown(S.ICE_BLOCK) and CooldownReady(S.ICE_BLOCK) and IsUsable(S.ICE_BLOCK) then
            return S.ICE_BLOCK, "ICE BLOCK", "ALL MODS", "Emergency: immunity and a mental reset"
        end
        if IsKnown(S.FROST_NOVA) and CooldownReady(S.FROST_NOVA) and IsUsable(S.FROST_NOVA) then
            return S.FROST_NOVA, "NOVA + RUN", "CTRL", "Root with rank 1 and immediately create distance"
        end
        if IsKnown(S.COLD_SNAP) and CooldownReady(S.COLD_SNAP) and IsUsable(S.COLD_SNAP)
           and (IsKnown(S.FROST_NOVA) or IsKnown(S.ICE_BLOCK)) then
            return S.COLD_SNAP, "COLD SNAP", "CAST MANUALLY", "Reset Nova/Block, then immediately use the needed control"
        end
        if IsKnown(S.BLINK) and CooldownReady(S.BLINK) and IsUsable(S.BLINK) then
            return S.BLINK, "BLINK OUT", "ALT", "Nova unavailable: create distance now"
        end
        if IsKnown(S.MANA_SHIELD) and IsUsable(S.MANA_SHIELD) and Mage.ManaPct() >= 25 then
            return S.MANA_SHIELD, "MANA SHIELD", "ALL MODS", "Last buffer before escaping"
        end
        return nil, "RUN!", "PREPARE ESCAPE", "No immediate Mage cooldown available"
end

function Class:GetMultiPullRecommendation(enemies, hp, targetHP)
        local close = Mage.TargetIsClose()
        local manaPct = Mage.ManaPct()

        if enemies >= 3 then
            if IsKnown(S.FROST_NOVA) and CooldownReady(S.FROST_NOVA) and IsUsable(S.FROST_NOVA) then
                return S.FROST_NOVA, "3+ MOBS - NOVA", "CTRL", "Frost Nova R1, turn and create distance", "danger"
            end
            if IsKnown(S.BLINK) and CooldownReady(S.BLINK) and IsUsable(S.BLINK) then
                return S.BLINK, "3+ MOBS - BLINK", "ALT", "Nova unavailable: leave the melee cluster", "danger"
            end
            local id, _, key, reason = self:GetPanicRecommendation()
            return id, "3+ MOBS - PANIC", key or "ALL MODS", reason or "Reset / escape", "danger"
        end

        if hp <= 50 then
            local id, _, key, reason = self:GetPanicRecommendation()
            return id, "2 MOBS - GET OUT", key or "ALL MODS", reason or "Create distance", "danger"
        end

        if close and IsKnown(S.FROST_NOVA) and CooldownReady(S.FROST_NOVA) and IsUsable(S.FROST_NOVA) then
            return S.FROST_NOVA, "MULTI x2 - NOVA", "CTRL", "Root R1, move away and separate the pull", "caution"
        end

        -- Polymorph is the preferred 2-mob reset when you still have space.
        -- Creature eligibility varies, so the Advisor explicitly says "if valid";
        -- a failed Polymorph does not trigger any automation or retargeting.
        if IsKnown(S.POLYMORPH) and Mage.PolymorphEligible() and not HasMyTargetDebuff(S.POLYMORPH) then
            return S.POLYMORPH, "MULTI x2 - POLY", "ALT+CTRL", "Polymorph this target, then switch to the other mob", "caution"
        end

        if hp <= 68 and IsKnown(S.BLINK) and CooldownReady(S.BLINK) and IsUsable(S.BLINK) then
            return S.BLINK, "MULTI x2 - SPACE", "ALT", "High pressure: create distance before losing control", "danger"
        end

        if manaPct <= 30 then
            return nil, "MULTI x2 - MANA", "PREPARE ESCAPE", string.format("Only %.0f%% mana: do not turn the pull into a DPS race", manaPct), "caution"
        end

        return nil, "MULTI x2", "KITE / POLY", "Maintain distance; do not add a third mob", "caution"
end

-- Class interrupt contract. Advisor/Threat only detects the cast;
-- the class decides which control/interrupt spell is valid.
function Class:GetInterruptRecommendation()
        if IsKnown(S.COUNTERSPELL) and CooldownReady(S.COUNTERSPELL) then return S.COUNTERSPELL, "INTERRUPT!", "CTRL+SHIFT", "Counterspell" end
end

-- Secure macro class contract. Core/Macros owns only secure attribute orchestration;
-- the class owns its base action and modifier spell choices.
function Class:BuildMainMacro()
        local lines = NewLines()
        local primary = Mage.PrimarySpell()
        AddLine(lines, CastLine(primary, "harm", false), 1)
        return FitMacro(lines)
end

function Class:BuildModifierMacros()
        -- SHIFT does double duty without any combat-state automation: with a hostile
        -- target it toggles the wand; otherwise it buffs Arcane Intellect.
        local shift = BuildSpellMacro(S.ARCANE_INTELLECT, "@player")
        if HasWandEquipped() and IsKnown(S.SHOOT) and IsKnown(S.ARCANE_INTELLECT) then
            shift = "/cast [harm] !" .. SpellName(S.SHOOT) .. "; [@player] " .. SpellName(S.ARCANE_INTELLECT)
        elseif HasWandEquipped() and IsKnown(S.SHOOT) then
            shift = "/cast [harm] !" .. SpellName(S.SHOOT)
        end

        -- Frost Nova rank 1 has the same root utility and is dramatically cheaper;
        -- use the localized rank string so non-English clients are safe.
        local nova = IsKnown(S.FROST_NOVA) and ("/cast " .. Mage.RankedName(S.FROST_NOVA)) or "/stopmacro"

        -- ALL MODS is a real HC panic chain. Failed/unavailable casts fall through
        -- to the next defensive; only one protected GCD action can succeed.
        local panicLines = NewLines()
        AddLine(panicLines, IsKnown(S.ICE_BLOCK) and ("/cast " .. SpellName(S.ICE_BLOCK)) or nil, 1)
        AddLine(panicLines, IsKnown(S.FROST_NOVA) and nova or nil, 2)
        AddLine(panicLines, IsKnown(S.MANA_SHIELD) and ("/cast " .. SpellName(S.MANA_SHIELD)) or nil, 3)
        local panic = FitMacro(panicLines)

        return {
            shift=shift, ctrl=nova,
            alt=BuildSpellMacro(S.BLINK), ctrlshift=BuildSpellMacro(S.COUNTERSPELL, "harm"),
            altshift=BuildSpellMacro(S.FIRE_BLAST, "harm"), altctrl=BuildSpellMacro(S.POLYMORPH, "harm"), all=panic,
            desc={shift="Wand / Arcane Intellect",ctrl="Frost Nova R1",alt="Blink",ctrlshift="Counterspell",altshift="Fire Blast",altctrl="Polymorph",all="Ice Block / Nova R1 / Mana Shield"}
        }
end

function Class:GetBaseActionInfo(spec)
    local primary = Mage.PrimarySpell()
    return primary, SpellName(primary, "NUKE")
end

function Class:IsRangedBaseAction(id)
    return id == Mage.PrimarySpell()
end

-- Fixed Action Panel macro contract.
function Class:BuildActionPanelMacro(id)
    if id == S.FROST_NOVA and IsKnown(id) then
        return "/cast " .. Mage.RankedName(S.FROST_NOVA)
    end
    return nil
end

