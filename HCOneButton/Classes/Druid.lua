local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Class = HCOB.Classes.DRUID or {}
HCOB.Classes.DRUID = Class
Class.classToken = "DRUID"
Class.fallbackSpec = 2

-- Internal form tokens are deliberately independent from stance-bar indexes.
-- Classic characters can expose different stance indexes as forms are learned,
-- while GetShapeshiftFormID() provides stable DBC form IDs. Dire Bear has its
-- own Classic ID, so treat both Bear IDs as the same logical combat form.
local FORM_CASTER, FORM_BEAR, FORM_CAT, FORM_OTHER = 0, 1, 3, 9
local CAT_FORM_ID, BEAR_FORM_ID, DIRE_BEAR_FORM_ID = 1, 5, 8

local function DruidForm()
    if GetShapeshiftFormID then
        local ok, value = pcall(GetShapeshiftFormID)
        if ok and CanAccessValue(value) then
            value = SafeNumber(value, nil)
            if value == CAT_FORM_ID then return FORM_CAT end
            if value == BEAR_FORM_ID or value == DIRE_BEAR_FORM_ID then return FORM_BEAR end
            if value == nil or value == 0 then return FORM_CASTER end
            return FORM_OTHER
        end
    end

    -- Fallback without stance indexes: Cat uses Energy and Bear/Dire Bear Rage.
    -- Other Druid forms use mana and can safely follow the caster/other branch.
    if UnitPowerType then
        local ok, powerType = pcall(UnitPowerType, "player")
        powerType = ok and SafeNumber(powerType, nil) or nil
        if powerType == 3 then return FORM_CAT end
        if powerType == 1 then return FORM_BEAR end
    end
    return FORM_CASTER
end

local function StanceIndexForSpell(id)
    if not id or not GetNumShapeshiftForms or not GetShapeshiftFormInfo then return nil end
    local ok, count = pcall(GetNumShapeshiftForms)
    count = ok and SafeNumber(count, 0) or 0
    local wantedName = SpellName(id)
    for i = 1, count do
        local infoOK, _, _, _, spellID = pcall(GetShapeshiftFormInfo, i)
        if infoOK then
            spellID = SafeNumber(spellID, nil)
            if spellID == id then return i end
            if spellID and wantedName and SpellName(spellID) == wantedName then return i end
        end
    end
    return nil
end

local function ComboPoints()
    if not GetComboPoints then return 0 end
    local ok, value = pcall(GetComboPoints, "player", "target")
    if not ok then return 0 end
    return SafeNumber(value, 0) or 0
end

local function CurrentResource()
    local pType = UnitPowerType("player")
    return SafeUnitPower("player", pType, 0) or 0, pType
end

local function TargetTough()
    local level = PlayerLevel()
    local targetLevel = SafeUnitLevel("target", level) or level
    local classification = SafeUnitClassification("target", "normal") or "normal"
    return classification == "elite" or classification == "rareelite" or classification == "worldboss" or targetLevel >= level + 1
end

local function HasFeralFire()
    if not IsKnown(S.FAERIE_FIRE_FERAL) then return false end
    return HasMyTargetDebuff(S.FAERIE_FIRE_FERAL)
end

function Class:GetRecommendation(inCombat, hostile, targetHP, spec)
    local candidates = {}
    local form = DruidForm()
    local hp = UnitHealthPct("player")
    local manaPct = HCOB.Advisor.Engine.ManaPct()
    local resource, powerType = CurrentResource()
    local cp = ComboPoints()
    local close = hostile and HCOB.Advisor.Engine.TargetIsClose() or false
    local tough = hostile and TargetTough() or false

    -- Feral leveling should spend as little mana as possible on ordinary pulls.
    -- Shift only when there is a real target; otherwise leave travel/buff state alone.
    if not inCombat and hostile and spec == 2 then
        if form ~= FORM_CAT and form ~= FORM_BEAR and IsKnown(S.CAT_FORM) and IsUsable(S.CAT_FORM) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.CAT_FORM, "CAT FORM", "CAST MANUALLY", "Feral solo opener: enter the efficient leveling form before engaging", 94, "form")
        elseif form ~= FORM_CAT and form ~= FORM_BEAR and not IsKnown(S.CAT_FORM) and IsKnown(S.BEAR_FORM) and IsUsable(S.BEAR_FORM) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.BEAR_FORM, "BEAR FORM", "CAST MANUALLY", "Pre-Cat Feral leveling: use Bear Form for efficient melee combat", 88, "form")
        end
    end

    if not inCombat and hostile and form ~= FORM_CAT and form ~= FORM_BEAR and spec ~= 2 then
        if IsKnown(S.MOONFIRE) and IsUsable(S.MOONFIRE) and targetHP >= 45 and manaPct >= 35 and not HasMyTargetDebuff(S.MOONFIRE) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.MOONFIRE, "MOONFIRE OPENER", "CAST MANUALLY", "Apply the instant DoT while the target is still at range", 72, "opener")
        elseif IsKnown(S.WRATH) and IsUsable(S.WRATH) and manaPct >= 25 then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.WRATH, "WRATH OPENER", "BASE", "Open from range before the target reaches melee", 66, "opener")
        end
    end

    if not inCombat or not hostile then
        return HCOB.Advisor.Engine.SelectCandidate(candidates)
    end

    local reserve, reserveLabel = HCOB.Advisor.Engine.SurvivalReserve()
    local dyn = HCOB.Advisor.Engine.RollingDynamics(targetHP)
    local ttk = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local ttd = dyn and dyn.confidence >= 0.38 and dyn.ttd or nil
    local context = string.format("HP %.0f%% | mana %.0f%% | reserve %.0f %s", hp, manaPct, reserve, reserveLabel)
    if ttk and ttk < math.huge then context = context .. string.format(" | TTK ~%.0fs", ttk) end

    local hasMark, markRemaining = StablePlayerBuff(S.MARK_WILD)
    if IsKnown(S.MARK_WILD) and IsUsable(S.MARK_WILD)
       and (not hasMark or markRemaining <= 10) then
        local reason = hasMark and ("Refresh before expiry (" .. math.floor(markRemaining) .. "s)") or "Mark of the Wild missing in combat"
        HCOB.Advisor.Engine.AddCandidate(candidates, S.MARK_WILD, "MARK OF THE WILD", "SHIFT", reason .. " | " .. context, hasMark and 63 or 84, "buff")
    end

    -- A safe direct-heal window is valuable even from a form: the fixed Healing
    -- Touch action cancels form before casting. Never suggest this into immediate
    -- melee pressure; Bear/Dash/Roots remain the safer answer there.
    local directPressure = close and HCOB.Advisor.Engine.TargetOnPlayer()
    if hp <= 50 and manaPct >= 18 and IsKnown(S.HEALING_TOUCH) and CooldownReady(S.HEALING_TOUCH) then
        local cast = SpellCastSeconds(S.HEALING_TOUCH)
        local safeCast = not directPressure and (not ttd or ttd == math.huge or ttd >= cast + 1.0)
        if safeCast then
            local score = 94 + math.max(0, 48 - hp) * 0.45
            HCOB.Advisor.Engine.AddCandidate(candidates, S.HEALING_TOUCH, "HEALING TOUCH", "CAST MANUALLY", "Safe reset window: leave form, heal, then resume the resource-efficient plan | " .. context, score, "survival")
        end
    end

    -- Emergency form transition: Bear is the Druid's universal physical safety
    -- buffer. It intentionally outranks damage when the reserve starts collapsing.
    if form ~= FORM_BEAR and IsKnown(S.BEAR_FORM) and IsUsable(S.BEAR_FORM) and (hp <= 42 or reserve <= 30) and targetHP > 12 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.BEAR_FORM, "BEAR FORM NOW", "CAST MANUALLY", "Reserve is collapsing: trade damage for armor and a safer escape/heal setup | " .. context, 111, "survival")
    end

    if IsKnown(S.BARKSKIN) and CooldownReady(S.BARKSKIN) and IsUsable(S.BARKSKIN) and reserve <= 38 and targetHP > 15 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.BARKSKIN, "BARKSKIN", "ALT+CTRL", "Reduce incoming damage before the fight enters the panic range | " .. context, 104, "survival")
    end

    if form == FORM_BEAR then
        local rage = powerType == 1 and resource or 0
        if hp <= 48 and rage >= 10 and IsKnown(S.FRENZIED_REGENERATION) and CooldownReady(S.FRENZIED_REGENERATION) and IsUsable(S.FRENZIED_REGENERATION) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.FRENZIED_REGENERATION, "FRENZIED REGEN", "CAST MANUALLY", "Bear emergency: convert Rage into health while staying armored | " .. context, 108, "survival")
        end
        if IsKnown(S.FAERIE_FIRE_FERAL) and CooldownReady(S.FAERIE_FIRE_FERAL) and IsUsable(S.FAERIE_FIRE_FERAL) and targetHP >= 45 and not HasFeralFire() then
            local score = tough and 75 or 64
            HCOB.Advisor.Engine.AddCandidate(candidates, S.FAERIE_FIRE_FERAL, "FAERIE FIRE", "CAST MANUALLY", "Free armor debuff in Bear Form; valuable on a target that will live | " .. context, score, "setup")
        end
        if IsKnown(S.MAUL) and IsUsable(S.MAUL) and rage >= 35 and reserve >= 40 then
            local score = targetHP <= 22 and 83 or (rage >= 55 and 72 or 64)
            HCOB.Advisor.Engine.AddCandidate(candidates, S.MAUL, targetHP <= 22 and "MAUL FINISH" or "MAUL", "CAST MANUALLY", "Spend excess Rage without compromising the defensive reserve | " .. context, score, targetHP <= 22 and "finisher" or "damage")
        end
        if spec == 2 and hp >= 72 and reserve >= 65 and targetHP >= 35 and CountActiveEnemies() <= 1 and IsKnown(S.CAT_FORM) and IsUsable(S.CAT_FORM) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.CAT_FORM, "RETURN TO CAT", "CAST MANUALLY", "Pressure is stable again: return to the efficient solo damage form | " .. context, 52, "form")
        end
    elseif form == FORM_CAT then
        local energy = powerType == 3 and resource or 0

        if IsKnown(S.FAERIE_FIRE_FERAL) and CooldownReady(S.FAERIE_FIRE_FERAL) and IsUsable(S.FAERIE_FIRE_FERAL) and targetHP >= 50 and not HasFeralFire() then
            local longEnough = not ttk or ttk >= 9
            if longEnough then
                HCOB.Advisor.Engine.AddCandidate(candidates, S.FAERIE_FIRE_FERAL, "FAERIE FIRE", "CAST MANUALLY", "Free armor debuff before spending Energy | " .. context, tough and 76 or 66, "setup")
            end
        end

        if cp >= 4 and targetHP >= 42 and IsKnown(S.RIP) and IsUsable(S.RIP) and not HasMyTargetDebuff(S.RIP) then
            local longEnough = not ttk or ttk >= 10
            if longEnough then
                HCOB.Advisor.Engine.AddCandidate(candidates, S.RIP, "RIP", "CAST MANUALLY", tostring(cp) .. " combo points and enough expected lifetime for the bleed | " .. context, 84, "dot")
            end
        end

        if cp >= 4 and IsKnown(S.FEROCIOUS_BITE) and IsUsable(S.FEROCIOUS_BITE) then
            local ripActive = HasMyTargetDebuff(S.RIP)
            local biteNow = targetHP <= 38 or (ttk and ttk <= 8) or (cp >= 5 and (ripActive or targetHP <= 55))
            if biteNow then
                local score = targetHP <= 24 and 101 or 88
                HCOB.Advisor.Engine.AddCandidate(candidates, S.FEROCIOUS_BITE, targetHP <= 24 and "BITE FINISH" or "FEROCIOUS BITE", "ALT+SHIFT", tostring(cp) .. " combo points: cash out before the target dies | " .. context, score, "finisher")
            end
        end

        if IsKnown(S.RAKE) and IsUsable(S.RAKE) and targetHP >= 52 and not HasMyTargetDebuff(S.RAKE) and reserve >= 42 then
            local longEnough = not ttk or ttk >= 8
            if longEnough then
                HCOB.Advisor.Engine.AddCandidate(candidates, S.RAKE, "RAKE", "CAST MANUALLY", "Early bleed with enough target lifetime remaining | " .. context, 69, "dot")
            end
        end

        if IsKnown(S.CLAW) and IsUsable(S.CLAW) and cp < 5 and energy >= 45 and reserve >= 38 and targetHP > 18 then
            local score = cp >= 3 and 73 or 68
            if energy >= 80 then score = score + 6 end
            HCOB.Advisor.Engine.AddCandidate(candidates, S.CLAW, "CLAW", "BASE", "Build combo points without Energy capping | " .. context, score, "damage")
        end

        if reserve <= 42 and targetHP > 18 and IsKnown(S.DASH) and CooldownReady(S.DASH) and IsUsable(S.DASH) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.DASH, "DASH + EXIT", "ALT", "Cat escape window: create distance before HP becomes critical | " .. context, 93, "survival")
        end
    else
        -- Caster form: control first, then spend mana according to spec.
        if close and targetHP > 22 and IsKnown(S.ENTANGLING_ROOTS) and IsUsable(S.ENTANGLING_ROOTS) and not HasMyTargetDebuff(S.ENTANGLING_ROOTS) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.ENTANGLING_ROOTS, "ROOT + DISTANCE", "CTRL", "Control the target, create range, then heal or resume ranged damage | " .. context, reserve < 55 and 98 or 86, "control")
        end

        if close and reserve <= 50 and IsKnown(S.NATURES_GRASP) and CooldownReady(S.NATURES_GRASP) and IsUsable(S.NATURES_GRASP) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.NATURES_GRASP, "NATURE'S GRASP", "ALL MODS", "Emergency root safety net while leaving melee | " .. context, 101, "survival")
        end

        if spec == 2 and hp >= 58 and reserve >= 48 then
            if IsKnown(S.CAT_FORM) and IsUsable(S.CAT_FORM) then
                HCOB.Advisor.Engine.AddCandidate(candidates, S.CAT_FORM, "CAT FORM", "CAST MANUALLY", "HP is stable: stop spending mana and return to Feral efficiency | " .. context, 82, "form")
            elseif IsKnown(S.BEAR_FORM) and IsUsable(S.BEAR_FORM) then
                HCOB.Advisor.Engine.AddCandidate(candidates, S.BEAR_FORM, "BEAR FORM", "CAST MANUALLY", "Return to the efficient melee form | " .. context, 76, "form")
            end
        end

        if spec ~= 2 and IsKnown(S.MOONFIRE) and IsUsable(S.MOONFIRE) and manaPct >= 32 and targetHP >= 45 and reserve >= 42 and not HasMyTargetDebuff(S.MOONFIRE) then
            local longEnough = not ttk or ttk >= 8
            if longEnough then
                HCOB.Advisor.Engine.AddCandidate(candidates, S.MOONFIRE, "MOONFIRE", "CAST MANUALLY", "DoT only when target lifetime and mana reserve justify it | " .. context, spec == 1 and 72 or 61, "dot")
            end
        end

        if spec ~= 2 and not close and IsKnown(S.WRATH) and IsUsable(S.WRATH) and manaPct >= (spec == 3 and 42 or 24) and targetHP > 18 then
            local score = spec == 1 and 70 or 56
            if manaPct <= 35 then score = score - 8 end
            HCOB.Advisor.Engine.AddCandidate(candidates, S.WRATH, "WRATH", "BASE", "Ranged filler while preserving enough mana for roots and emergency healing | " .. context, score, "damage")
        end
    end

    return HCOB.Advisor.Engine.SelectCandidate(candidates)
end

function Class:GetBuffRecommendation(inCombat)
    return nil
end

function Class:GetCautionRecommendation(ctx)
    local form = DruidForm()
    if form == FORM_CAT and IsKnown(S.DASH) and CooldownReady(S.DASH) and IsUsable(S.DASH) then
        return S.DASH, "UNFAVORABLE FIGHT", "ALT", ctx.text .. ": Dash and reset the pull", "caution"
    end
    if form ~= FORM_BEAR and IsKnown(S.BEAR_FORM) and IsUsable(S.BEAR_FORM) then
        return S.BEAR_FORM, "UNFAVORABLE FIGHT", "CAST MANUALLY", ctx.text .. ": Bear Form buys armor and time", "caution"
    end
    if IsKnown(S.BARKSKIN) and CooldownReady(S.BARKSKIN) and IsUsable(S.BARKSKIN) then
        return S.BARKSKIN, "UNFAVORABLE FIGHT", "ALT+CTRL", ctx.text .. ": Barkskin before the reserve collapses", "caution"
    end
end

function Class:GetSurvivalReserve(ctx)
    local hp, mana = ctx.hp or 0, ctx.mana or 0
    local form = DruidForm()
    local formBonus = form == FORM_BEAR and 12 or (form == FORM_CAT and 4 or 0)
    local controlBonus = 0
    if IsKnown(S.NATURES_GRASP) and CooldownReady(S.NATURES_GRASP) then controlBonus = controlBonus + 5 end
    if IsKnown(S.BARKSKIN) and CooldownReady(S.BARKSKIN) then controlBonus = controlBonus + 4 end
    if form == FORM_CAT and IsKnown(S.DASH) and CooldownReady(S.DASH) then controlBonus = controlBonus + 3 end
    if form == FORM_BEAR and IsKnown(S.FRENZIED_REGENERATION) and CooldownReady(S.FRENZIED_REGENERATION) then controlBonus = controlBonus + 4 end
    return hp * 0.70 + math.min(100, mana) * 0.10 + formBonus + controlBonus + 7
end

function Class:GetPanicRecommendation()
    local form = DruidForm()
    local hp = UnitHealthPct("player")
    local resource, powerType = CurrentResource()
    if form == FORM_BEAR and hp <= 55 and powerType == 1 and resource >= 10 and IsKnown(S.FRENZIED_REGENERATION) and CooldownReady(S.FRENZIED_REGENERATION) and IsUsable(S.FRENZIED_REGENERATION) then
        return S.FRENZIED_REGENERATION, "FRENZIED REGEN", "CAST MANUALLY", "Convert Rage into health while staying in Bear Form"
    end
    if IsKnown(S.NATURES_GRASP) and CooldownReady(S.NATURES_GRASP) and IsUsable(S.NATURES_GRASP) then
        return S.NATURES_GRASP, "GRASP + RUN", "ALL MODS", "Root the attacker and create distance"
    end
    if form ~= FORM_BEAR and IsKnown(S.BEAR_FORM) and IsUsable(S.BEAR_FORM) then
        return S.BEAR_FORM, "BEAR FORM", "CAST MANUALLY", "Emergency armor and access to Bear survival tools"
    end
    if IsKnown(S.BARKSKIN) and CooldownReady(S.BARKSKIN) and IsUsable(S.BARKSKIN) then
        return S.BARKSKIN, "BARKSKIN", "ALT+CTRL", "Reduce incoming damage"
    end
    if form == FORM_CAT and IsKnown(S.DASH) and CooldownReady(S.DASH) and IsUsable(S.DASH) then
        return S.DASH, "DASH + RUN", "ALT", "Create distance immediately"
    end
    if IsKnown(S.TRAVEL_FORM) and IsUsable(S.TRAVEL_FORM) then
        return S.TRAVEL_FORM, "TRAVEL + RUN", "ALT", "Use movement speed to extend the leash"
    end
    return nil, "RUN!", "PREPARE ESCAPE", "No immediate Druid defensive is usable"
end

function Class:GetMultiPullRecommendation(enemies, hp, targetHP)
    local form = DruidForm()
    if enemies >= 3 then
        if IsKnown(S.NATURES_GRASP) and CooldownReady(S.NATURES_GRASP) and IsUsable(S.NATURES_GRASP) then
            return S.NATURES_GRASP, "3+ MOBS - GRASP", "ALL MODS", "Root one attacker and immediately reduce the pull", "danger"
        end
        if form ~= FORM_BEAR and IsKnown(S.BEAR_FORM) and IsUsable(S.BEAR_FORM) then
            return S.BEAR_FORM, "3+ MOBS - BEAR", "CAST MANUALLY", "Shift for armor before choosing an escape line", "danger"
        end
        if IsKnown(S.BARKSKIN) and CooldownReady(S.BARKSKIN) and IsUsable(S.BARKSKIN) then
            return S.BARKSKIN, "3+ MOBS - BARKSKIN", "ALT+CTRL", "Reduce burst while moving toward an escape", "danger"
        end
        return nil, "3+ MOBS - GET OUT", "PREPARE ESCAPE", "Druid single-target leveling is weak into large accidental pulls", "danger"
    end

    if hp <= 52 then
        local id, _, key, reason = self:GetPanicRecommendation()
        return id, "2 MOBS - GET OUT", key or "ALL MODS", reason or "Reduce pressure", "danger"
    end

    if form == FORM_CASTER and IsKnown(S.ENTANGLING_ROOTS) and IsUsable(S.ENTANGLING_ROOTS) and not HasMyTargetDebuff(S.ENTANGLING_ROOTS) then
        return S.ENTANGLING_ROOTS, "MULTI x2 - ROOT", "CTRL", "Root one target and fight only one mob at a time", "caution"
    end
    if form ~= FORM_BEAR and IsKnown(S.BEAR_FORM) and IsUsable(S.BEAR_FORM) then
        return S.BEAR_FORM, "MULTI x2 - BEAR", "CAST MANUALLY", "Extra armor is safer than racing two mobs in Cat/Caster Form", "caution"
    end
    return nil, "MULTI x2", "PREPARE CONTROL", "Do not race the pull: preserve Barkskin/Grasp and an escape route", "caution"
end

function Class:GetInterruptRecommendation()
    local form = DruidForm()
    if form == FORM_BEAR and IsKnown(S.FERAL_CHARGE) and CooldownReady(S.FERAL_CHARGE) and IsUsable(S.FERAL_CHARGE) then
        return S.FERAL_CHARGE, "STOP CAST", "CTRL+SHIFT", "Feral Charge"
    end
    if form == FORM_BEAR and IsKnown(S.BASH) and CooldownReady(S.BASH) and IsUsable(S.BASH) then
        return S.BASH, "STOP CAST", "CTRL+SHIFT", "Bash"
    end
end

function Class:BuildMainMacro()
    local lines = NewLines()
    local spec = TalentSpec()
    if spec == 2 then
        if IsKnown(S.CAT_FORM) then AddLine(lines, CastLine(S.CAT_FORM, "noform", false), 2)
        elseif IsKnown(S.BEAR_FORM) then AddLine(lines, CastLine(S.BEAR_FORM, "noform", false), 2) end
    end
    if spec == 2 then AddLine(lines, "/startattack [harm]", 1) end
    if IsKnown(S.CAT_FORM) and IsKnown(S.CLAW) then AddLine(lines, CastLine(S.CLAW, "harm", false), 1) end
    -- Wrath is valid in caster/Moonkin form; in Feral forms it simply remains unusable.
    AddLine(lines, CastLine(S.WRATH, "harm", false), 1)
    return FitMacro(lines)
end

function Class:BuildModifierMacros()
    local mobility = BuildSpellMacro(S.TRAVEL_FORM)
    if IsKnown(S.DASH) then
        local dashName = SpellName(S.DASH)
        local travelName = IsKnown(S.TRAVEL_FORM) and SpellName(S.TRAVEL_FORM) or nil
        local catIndex = StanceIndexForSpell(S.CAT_FORM)
        if dashName and travelName and catIndex then
            mobility = "/cast [form:" .. catIndex .. "] " .. dashName .. "; " .. travelName
        elseif dashName and not travelName then
            mobility = BuildSpellMacro(S.DASH)
        end
    end

    local stopLines = NewLines()
    if IsKnown(S.FERAL_CHARGE) then AddLine(stopLines, BuildSpellMacro(S.FERAL_CHARGE, "harm"), 1) end
    if IsKnown(S.BASH) then AddLine(stopLines, BuildSpellMacro(S.BASH, "harm"), 2) end
    local stopcast = #stopLines > 0 and FitMacro(stopLines) or "/stopmacro"
    local panic = IsKnown(S.NATURES_GRASP) and BuildSpellMacro(S.NATURES_GRASP) or BuildSpellMacro(S.BARKSKIN)
    return {
        shift=BuildSpellMacro(S.MARK_WILD, "@player"), ctrl=BuildSpellMacro(S.ENTANGLING_ROOTS, "harm"),
        alt=mobility, ctrlshift=stopcast, altshift=BuildSpellMacro(S.FEROCIOUS_BITE, "harm", true),
        altctrl=BuildSpellMacro(S.BARKSKIN), all=panic,
        desc={shift="Mark of the Wild",ctrl="Entangling Roots",alt="Dash / Travel Form",ctrlshift="Feral Charge / Bash",altshift="Ferocious Bite",altctrl="Barkskin",all="Nature's Grasp / Barkskin"}
    }
end


function Class:BuildActionPanelMacro(id)
    if id == S.CAT_FORM or id == S.BEAR_FORM or id == S.FRENZIED_REGENERATION then
        return BuildSpellMacro(id)
    end
    if id == S.HEALING_TOUCH then
        local lines = NewLines()
        AddLine(lines, "/cancelform", 1)
        AddLine(lines, BuildSpellMacro(id, "@player"), 1)
        return FitMacro(lines)
    end
    if id == S.ENTANGLING_ROOTS or id == S.NATURES_GRASP then
        local lines = NewLines()
        AddLine(lines, "/cancelform", 1)
        AddLine(lines, BuildSpellMacro(id, id == S.ENTANGLING_ROOTS and "harm" or nil), 1)
        return FitMacro(lines)
    end
    return nil
end

function Class:GetBaseActionInfo(spec)
    local form = DruidForm()
    if form == FORM_CAT and IsKnown(S.CLAW) then return S.CLAW, "CLAW" end
    if form == FORM_BEAR then return S.ATTACK, "BEAR AUTO" end
    return S.WRATH, "WRATH"
end

function Class:IsRangedBaseAction(id)
    local baseId = self:GetBaseActionInfo(TalentSpec())
    return id == S.WRATH and id == baseId
end
