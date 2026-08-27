local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Class = HCOB.Classes.SHAMAN or {}
HCOB.Classes.SHAMAN = Class
Class.classToken = "SHAMAN"
Class.fallbackSpec = 2

local function MainhandEnchanted()
    if not GetWeaponEnchantInfo then return false end
    local ok, has = pcall(GetWeaponEnchantInfo)
    return ok and SafeBoolean(has, false) or false
end

local function PreferredWeaponImbue(spec)
    -- Hardcore solo leveling favors Rockbiter's consistent output. In a group,
    -- avoid its extra threat when Windfury is available; any manually applied
    -- enchant is still respected because MainhandEnchanted() suppresses refresh.
    local grouped = false
    if IsInGroup then
        local ok, value = pcall(IsInGroup)
        grouped = ok and SafeBoolean(value, false) or false
    end
    if grouped and IsKnown(S.WINDFURY_WEAPON) then return S.WINDFURY_WEAPON end
    if IsKnown(S.ROCKBITER_WEAPON) then return S.ROCKBITER_WEAPON end
    if spec == 2 and IsKnown(S.WINDFURY_WEAPON) then return S.WINDFURY_WEAPON end
    return nil
end

function Class:GetRecommendation(inCombat, hostile, targetHP, spec)
    local candidates = {}
    local manaPct = HCOB.Advisor.Engine.ManaPct()
    local hp = UnitHealthPct("player")

    if not HasPlayerBuff(S.LIGHTNING_SHIELD) and IsKnown(S.LIGHTNING_SHIELD) and IsUsable(S.LIGHTNING_SHIELD) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.LIGHTNING_SHIELD, "LIGHTNING SHIELD", "SHIFT", "Maintain the buff before spending mana on damage", inCombat and 72 or 88, "buff")
    end
    local imbue = PreferredWeaponImbue(spec)
    if not inCombat and imbue and not MainhandEnchanted() and IsUsable(imbue) then
        HCOB.Advisor.Engine.AddCandidate(candidates, imbue, "WEAPON IMBUE", "CAST MANUALLY", SpellName(imbue) .. " missing on the main-hand weapon", 90, "buff")
    end
    if not inCombat and hostile and IsKnown(S.LIGHTNING_BOLT) and IsUsable(S.LIGHTNING_BOLT) and manaPct >= 25 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.LIGHTNING_BOLT, "LIGHTNING BOLT OPENER", "BASE", "Open from range before switching to the spec resource plan", 76, "opener")
    end
    if not inCombat or not hostile then return HCOB.Advisor.Engine.SelectCandidate(candidates) end

    local close = HCOB.Advisor.Engine.TargetIsClose()
    local reserve, reserveLabel = HCOB.Advisor.Engine.SurvivalReserve()
    local dyn = HCOB.Advisor.Engine.RollingDynamics(targetHP)
    local ttk = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local context = string.format("HP %.0f%% | mana %.0f%% | reserve %.0f %s", hp, manaPct, reserve, reserveLabel)
    if ttk and ttk < math.huge then context = context .. string.format(" | TTK ~%.0fs", ttk) end
    local enemies = CountActiveEnemies()
    local enemyCasting = ActiveTargetCast() ~= nil

    if hp <= 58 and IsKnown(S.HEALING_WAVE) and IsUsable(S.HEALING_WAVE) and manaPct >= 22 then
        local cast = SpellCastSeconds(S.HEALING_WAVE)
        local ttdSafe = not dyn or dyn.ttd == math.huge or dyn.ttd >= cast + 1.0 or HCOB.Advisor.Engine.TotemActive(S.STONECLAW_TOTEM)
        if ttdSafe then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.HEALING_WAVE, "HEALING WAVE", "ALT+CTRL", "Stabilize HP before burst | " .. context, 94 + math.max(0,55-hp)*0.45, "survival")
        end
    end

    if reserve <= 38 and IsKnown(S.STONECLAW_TOTEM) and IsUsable(S.STONECLAW_TOTEM) and not HCOB.Advisor.Engine.TotemActive(S.STONECLAW_TOTEM) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.STONECLAW_TOTEM, "STONECLAW", "ALL MODS", "Buy time for healing/escape | " .. context, 108, "survival")
    end

    if close and targetHP > 25 and reserve <= 52 and IsKnown(S.EARTHBIND_TOTEM) and IsUsable(S.EARTHBIND_TOTEM) and not HCOB.Advisor.Engine.TotemActive(S.EARTHBIND_TOTEM) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.EARTHBIND_TOTEM, "EARTHBIND + KITE", "CTRL", "Persistent slow to recreate space | " .. context, 94, "control")
    end

    if close and targetHP > 20 and IsKnown(S.FROST_SHOCK) and CooldownReady(S.FROST_SHOCK) and IsUsable(S.FROST_SHOCK) and manaPct >= 28 and reserve < 55 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.FROST_SHOCK, "FROST SHOCK + KITE", "CAST MANUALLY", "Defensive shock: slow and create distance | " .. context, 91, "control")
    end

    local flame = HasMyTargetDebuff(S.FLAME_SHOCK)
    if IsKnown(S.FLAME_SHOCK) and not flame and manaPct >= 42 and targetHP >= 50 and reserve >= 45 then
        local longEnough = not ttk or ttk >= 10
        if longEnough then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.FLAME_SHOCK, "FLAME SHOCK", "CAST MANUALLY", "Use the DoT only if it can tick long enough | " .. context, 68, "dot")
        end
    end

    if spec == 2 and IsKnown(S.STORMSTRIKE) and CooldownReady(S.STORMSTRIKE) and IsUsable(S.STORMSTRIKE) and reserve >= 45 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.STORMSTRIKE, "STORMSTRIKE", "ALT+SHIFT", "Core Enhancement action when reserve is healthy | " .. context, 82, "damage")
    end

    if targetHP <= 24 and IsKnown(S.EARTH_SHOCK) and CooldownReady(S.EARTH_SHOCK) and IsUsable(S.EARTH_SHOCK) and manaPct >= 28 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.EARTH_SHOCK, "EARTH SHOCK", "CTRL+SHIFT", "Instant finisher | " .. context, 88, "finisher")
    elseif not enemyCasting and IsKnown(S.EARTH_SHOCK) and CooldownReady(S.EARTH_SHOCK) and IsUsable(S.EARTH_SHOCK) and manaPct >= 72 and reserve >= 65 and targetHP >= 35 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.EARTH_SHOCK, "EARTH SHOCK", "CAST MANUALLY", "Burst only with abundant mana and no active cast to reserve the shared Shock cooldown for | " .. context, 60, "damage")
    end

    if IsKnown(S.SEARING_TOTEM) and IsUsable(S.SEARING_TOTEM) and not HCOB.Advisor.Engine.TotemActive(S.SEARING_TOTEM) and manaPct >= 52 and reserve >= 52 and targetHP >= 62 then
        local longEnough = not ttk or ttk >= 14
        if longEnough then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.SEARING_TOTEM, "SEARING TOTEM", "CAST MANUALLY", "Totem is efficient only if it stays active long enough | " .. context, 61, "efficiency")
        end
    end

    if reserve <= 30 and not close and HCOB.Advisor.Engine.TotemActive(S.STONECLAW_TOTEM) and IsKnown(S.GHOST_WOLF) and IsUsable(S.GHOST_WOLF) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.GHOST_WOLF, "GHOST WOLF + RUN", "ALT", "Stoneclaw bought you space: extend the leash | " .. context, 96, "survival")
    end

    if spec ~= 2 and IsKnown(S.CHAIN_LIGHTNING) and IsUsable(S.CHAIN_LIGHTNING) and not close and manaPct >= 70 and reserve >= 62 and targetHP >= 50 then
        local score = enemies >= 2 and 78 or 65
        HCOB.Advisor.Engine.AddCandidate(candidates, S.CHAIN_LIGHTNING, "CHAIN LIGHTNING", "CAST MANUALLY", "Elemental burst only while mana and survival reserve are comfortably high | " .. context, score, enemies >= 2 and "aoe" or "damage")
    end
    if IsKnown(S.LIGHTNING_BOLT) and IsUsable(S.LIGHTNING_BOLT) and not close and manaPct >= 28 and targetHP >= 28 then
        local score = spec == 1 and 72 or (spec == 3 and 66 or 56)
        if manaPct <= 40 then score = score - 6 end
        HCOB.Advisor.Engine.AddCandidate(candidates, S.LIGHTNING_BOLT, "LIGHTNING BOLT", "BASE", "Spec-aware ranged filler; stop spending once the mana reserve approaches healing territory | " .. context, score, "damage")
    end

    return HCOB.Advisor.Engine.SelectCandidate(candidates)
end



-- Advisor class contract extensions.
function Class:GetBuffRecommendation(inCombat)
    if not inCombat then
        local imbue = PreferredWeaponImbue(TalentSpec())
        if imbue and not MainhandEnchanted() and IsUsable(imbue) then return imbue, "WEAPON IMBUE", "CAST MANUALLY", SpellName(imbue) .. " missing" end
    end
    if not IsKnown(S.LIGHTNING_SHIELD) then return nil end
    local has, remain = HasPlayerBuff(S.LIGHTNING_SHIELD)
    if not has then return S.LIGHTNING_SHIELD, "BUFF", "SHIFT", SpellName(S.LIGHTNING_SHIELD) .. " missing" end
    if remain < 12 and not inCombat then return S.LIGHTNING_SHIELD, "BUFF SOON", "SHIFT", "Expires in " .. math.floor(remain) .. "s" end
end

function Class:GetCautionRecommendation(ctx)
    if IsKnown(S.STONECLAW_TOTEM) and IsUsable(S.STONECLAW_TOTEM) and not HCOB.Advisor.Engine.TotemActive(S.STONECLAW_TOTEM) then
        return S.STONECLAW_TOTEM, "UNFAVORABLE FIGHT", "ALL MODS", ctx.text .. ": Stoneclaw and create space", "caution"
    end
    if IsKnown(S.HEALING_WAVE) and IsUsable(S.HEALING_WAVE) and ctx.hp <= 58 then
        return S.HEALING_WAVE, "UNFAVORABLE FIGHT", "ALT+CTRL", ctx.text .. ": heal if you have room", "caution"
    end
end

-- Hardcore safety class contract. Advisor/Survival owns policy orchestration;
-- this class owns its spells and class-specific escape/resource model.
function Class:GetSurvivalReserve(ctx)
    local hp, mana = ctx.hp, ctx.mana
    local score
        score = hp * 0.55 + mana * 0.18 + 8
        if IsKnown(S.STONECLAW_TOTEM) and IsUsable(S.STONECLAW_TOTEM) then score = score + 8 end
        if IsKnown(S.EARTHBIND_TOTEM) and IsUsable(S.EARTHBIND_TOTEM) then score = score + 5 end
        if IsKnown(S.HEALING_WAVE) and IsUsable(S.HEALING_WAVE) and mana >= 20 then score = score + 7 end
        if IsKnown(S.GHOST_WOLF) and IsUsable(S.GHOST_WOLF) then score = score + 4 end
        if HCOB.Advisor.Engine.TargetIsClose() then score = score - 6 end
    return score
end

function Class:GetPanicRecommendation()
        if IsKnown(S.STONECLAW_TOTEM) and IsUsable(S.STONECLAW_TOTEM) and not HCOB.Advisor.Engine.TotemActive(S.STONECLAW_TOTEM) then return S.STONECLAW_TOTEM, "STONECLAW", "ALL MODS", "Create space for healing/escape" end
        if IsKnown(S.EARTHBIND_TOTEM) and IsUsable(S.EARTHBIND_TOTEM) and not HCOB.Advisor.Engine.TotemActive(S.EARTHBIND_TOTEM) then return S.EARTHBIND_TOTEM, "EARTHBIND", "CTRL", "Slow and extend the leash" end
        if IsKnown(S.HEALING_WAVE) and IsUsable(S.HEALING_WAVE) then return S.HEALING_WAVE, "HEALING WAVE", "ALT+CTRL", "Stabilize if you have enough room to cast" end
        if IsKnown(S.GHOST_WOLF) and IsUsable(S.GHOST_WOLF) then return S.GHOST_WOLF, "GHOST WOLF + RUN", "ALT", "Extend the leash if you are outdoors" end
        return nil, "RUN!", "PREPARE ESCAPE", "Totem/heal unavailable"
end

function Class:GetMultiPullRecommendation(enemies, hp, targetHP)
        if enemies >= 3 or hp <= 48 then
            local id, _, key, reason = self:GetPanicRecommendation()
            return id, enemies >= 3 and "3+ MOBS - STONECLAW" or "MULTI - GET OUT", key or "ALL MODS", reason or "Totem + escape", "danger"
        end
        if IsKnown(S.STONECLAW_TOTEM) and IsUsable(S.STONECLAW_TOTEM) and not HCOB.Advisor.Engine.TotemActive(S.STONECLAW_TOTEM) then
            return S.STONECLAW_TOTEM, "MULTI x2 - STONECLAW", "ALL MODS", "Relieve pressure before dealing damage", "caution"
        end
        if IsKnown(S.EARTHBIND_TOTEM) and IsUsable(S.EARTHBIND_TOTEM) and not HCOB.Advisor.Engine.TotemActive(S.EARTHBIND_TOTEM) then
            return S.EARTHBIND_TOTEM, "MULTI x2 - EARTHBIND", "CTRL", "Kite and separate the pull", "caution"
        end
        return nil, "MULTI x2", "TOTEM / CONSERVE", "Preserve mana for healing and Earth Shock interrupt", "caution"
end

-- Class interrupt contract. Advisor/Threat only detects the cast;
-- the class decides which control/interrupt spell is valid.
function Class:GetInterruptRecommendation()
    if IsKnown(S.EARTH_SHOCK) and CooldownReady(S.EARTH_SHOCK) then
        return S.EARTH_SHOCK, "INTERRUPT!", "CTRL+SHIFT", "Earth Shock"
    end
end

-- Secure macro class contract. Core/Macros owns only secure attribute orchestration;
-- the class owns its base action and modifier spell choices.
function Class:BuildMainMacro()
        local lines = NewLines()
        local spec = TalentSpec()
        if spec == 2 then
            AddLine(lines, CastLine(S.LIGHTNING_BOLT, "nocombat,harm", false), 3)
            AddLine(lines, "/startattack", 1)
        else
            AddLine(lines, CastLine(S.LIGHTNING_BOLT, "harm", false), 1)
        end
        return FitMacro(lines)
end

function Class:BuildModifierMacros()
        return {
            shift=BuildSpellMacro(S.LIGHTNING_SHIELD), ctrl=BuildSpellMacro(S.EARTHBIND_TOTEM),
            alt=BuildSpellMacro(S.GHOST_WOLF), ctrlshift=BuildSpellMacro(S.EARTH_SHOCK, "harm"),
            altshift=BuildSpellMacro(S.STORMSTRIKE, "harm", true), altctrl=BuildSpellMacro(S.HEALING_WAVE, "@player"),
            all=BuildSpellMacro(S.STONECLAW_TOTEM),
            desc={shift="Lightning Shield",ctrl="Earthbind Totem",alt="Ghost Wolf",ctrlshift="Earth Shock interrupt",altshift="Stormstrike",altctrl="Healing Wave",all="Stoneclaw Totem"}
        }
end

function Class:GetBaseActionInfo(spec)
    if spec == 2 then return S.ATTACK, "AUTO ATTACK" end
    return S.LIGHTNING_BOLT, "LIGHTNING BOLT"
end

function Class:IsRangedBaseAction(id)
    local baseId = self:GetBaseActionInfo(TalentSpec())
    return id == S.LIGHTNING_BOLT and id == baseId
end

function Class:BuildActionPanelMacro(id)
    if id == S.ROCKBITER_WEAPON or id == S.WINDFURY_WEAPON then return BuildSpellMacro(id) end
    return nil
end

