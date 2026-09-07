local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Class = HCOB.Classes.ROGUE or {}
HCOB.Classes.ROGUE = Class
Class.classToken = "ROGUE"
Class.fallbackSpec = 2

-- Read invested ranks, not the winning talent tab: even one point at level 10
-- matters, and a mixed leveling build can learn an active from another tree.
local TALENT = {SINISTER=13732, GOUGE=13741, SLICE=14165, EVISCERATE=14162}
local talentRanks
local controlWindow
local targetTrend

function Class:GetTalentRank(id)
    if not talentRanks then
        talentRanks = {}
        if GetNumTalents and GetTalentInfo then
            for tab = 1, 3 do
                local ok, count = pcall(GetNumTalents, tab)
                count = ok and SafeNumber(count, 0) or 0
                for index = 1, math.min(40, count) do
                    local read, name, _, _, _, rank = pcall(GetTalentInfo, tab, index)
                    if read and type(name) == "string" then
                        talentRanks[name] = math.max(0, SafeNumber(rank, 0) or 0)
                    end
                end
            end
        end
    end
    return talentRanks[SpellName(id) or ""] or 0
end

function Class:EnergyCost(id)
    -- Localized name resolves the learned rank; the client also applies talents
    -- and temporary cost modifiers. Never infer affordability from spec/level.
    local name = SpellName(id)
    local function ReadCost(api)
        if not api or not name then return nil end
        local ok, costs = pcall(api, name)
        if ok and type(costs) == "table" then
            for _, entry in ipairs(costs) do
                if type(entry) == "table" and entry.type == 3 then
                    local cost = SafeNumber(entry.cost, nil)
                    if cost and cost >= 0 then return cost end
                end
            end
        end
    end
    local cost = ReadCost(GetSpellPowerCost)
    if cost == nil then cost = ReadCost(C_Spell and C_Spell.GetSpellPowerCost) end
    if cost ~= nil then return cost end
    if id == S.SINISTER_STRIKE then
        local rank = math.min(2, self:GetTalentRank(TALENT.SINISTER))
        return 45 - (rank == 2 and 5 or (rank == 1 and 3 or 0))
    end
    if id == S.HEMORRHAGE or id == S.EVISCERATE then return 35 end
    if id == S.SLICE_DICE then return 25 end
    return 45 -- Gouge
end

local function Builder()
    return IsKnown(S.HEMORRHAGE) and S.HEMORRHAGE or S.SINISTER_STRIKE
end

local function SoloControlTarget()
    local engine = HCOB.Advisor.Engine
    return CountActiveEnemies() <= 1 and engine.PlayerIsGrouped and not engine.PlayerIsGrouped()
        and engine.TargetOnPlayer and engine.TargetOnPlayer()
        and (not UnitIsPlayer or not UnitIsPlayer("target"))
end

local function GougeInReach()
    local engine = HCOB.Advisor.Engine
    return engine.TargetIsClose()
        and (not engine.SpellRange or engine.SpellRange(S.GOUGE, "target") ~= false)
end

local function HasRoguePeriodicDamage()
    -- Any source/rank of these bleeds/poisons breaks an intended energy pause.
    if not AuraByName then return true end
    for _, id in ipairs({S.GARROTE, 1943, 2818}) do -- Garrote, Rupture, Deadly Poison
        if AuraByName("target", SpellName(id), "HARMFUL", false) then return true end
    end
    return false
end

function Class:LevelingTTK(targetHP, dynamics)
    -- Logging can be disabled. Keep one ephemeral health trend so that doing
    -- so does not permanently remove Slice and Dice from leveling decisions.
    local guid = SafeUnitGUID and SafeUnitGUID("target")
    local now = GetTime()
    if guid then
        if not targetTrend or targetTrend.guid ~= guid or targetHP > targetTrend.lastHP + 0.1 then
            targetTrend = {guid=guid, since=now, startHP=targetHP, lastHP=targetHP}
        end
        targetTrend.lastHP = targetHP
    else
        targetTrend = nil
    end
    if dynamics and (dynamics.confidence or 0) >= 0.38 then
        local ttk = SafeNumber(dynamics.ttk, nil)
        if ttk and ttk > 0 then return ttk end
    end
    if targetTrend then
        local elapsed, lost = now - targetTrend.since, targetTrend.startHP - targetHP
        if elapsed >= 2 and lost >= 10 then return targetHP * elapsed / lost end
    end
    return nil
end

function Class:HandleEvent(event, unit, _, spellID)
    if event == "PLAYER_LOGIN" or event == "PLAYER_TALENT_UPDATE" or event == "SPELLS_CHANGED" then
        talentRanks = nil
    end
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_LOGIN" then
        controlWindow, targetTrend = nil, nil
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player"
        and SpellName(spellID) and SpellName(spellID) == SpellName(S.GOUGE) then
        -- Only bridge the aura delivery race, not the whole theoretical stun.
        -- A resisted/missed Gouge must release this hold promptly.
        controlWindow = {guid=SafeUnitGUID("target"), pendingUntil=GetTime() + 0.20}
    end
end

function Class:GetActionHold(inCombat, hostile)
    if not inCombat or not hostile or not HasMyTargetDebuff or not SafeUnitGUID then return nil end
    if CountActiveEnemies() > 1 then return nil end -- another attacker still needs a response
    local guid, now = SafeUnitGUID("target"), GetTime()
    if not guid then return nil end
    if controlWindow and controlWindow.guid ~= guid then controlWindow = nil end
    local active, remaining = HasMyTargetDebuff(S.GOUGE)
    if active then
        controlWindow = controlWindow or {guid=guid}
        local duration = SafeNumber(remaining, nil)
        if not duration or duration > 5.5 then
            duration = 4 + 0.5 * math.min(3, self:GetTalentRank(TALENT.GOUGE))
        end
        controlWindow.expires = controlWindow.expires or (now + duration)
        controlWindow.expires = math.min(controlWindow.expires, now + math.max(0, SafeNumber(remaining, duration)))
        controlWindow.pendingUntil = nil
    elseif not controlWindow or now >= (controlWindow.pendingUntil or 0) then
        controlWindow = nil
        return nil
    end
    local energy = SafeUnitPower("player", 3, 0) or 0
    if active and (now >= controlWindow.expires or energy >= 80) then return nil end
    return nil, "GOUGE - RECOVER", "LET IT FINISH",
        "Target controlled: pause attacks to recover energy; resume on break, expiry or 80 energy", "caution"
end

function Class:NeedsAutoAttackRestart(inCombat, hostile)
    local engine = HCOB.Advisor.Engine
    if not inCombat or not hostile or HasPlayerBuff(S.STEALTH) then return false end
    -- Do not turn combat with one mob into an instruction to pull a fresh one.
    if not UnitAffectingCombat or not UnitAffectingCombat("target") then return false end
    if engine.PlayerRecoveryHold and engine.PlayerRecoveryHold() then return false end
    if select(2, self:GetActionHold(inCombat, hostile)) then return false end
    -- Preserve breakable Rogue control from any source, including after the
    -- own-Gouge hold has yielded to an emergency or its energy cap.
    if not AuraByName then return false end
    for _, id in ipairs({S.GOUGE, S.BLIND, 6770}) do -- Sap
        if AuraByName("target", SpellName(id), "HARMFUL", false) then return false end
    end
    if not engine.SpellRange or engine.SpellRange(Builder(), "target") ~= true then return false end

    -- Query the client's attack toggle, never infer a stop from a long swing.
    -- Missing/failed/unreadable data is unknown, not a request for another key.
    local function ReadAttack(api)
        if type(api) ~= "function" then return nil end
        local ok, active = pcall(api, S.ATTACK)
        if ok and CanAccessValue(active) and type(active) == "boolean" then return active end
    end
    local active = ReadAttack(IsCurrentSpell)
    if active == nil then active = ReadAttack(C_Spell and C_Spell.IsCurrentSpell) end
    return active == false
end

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

    local _, holdTitle, holdKey, holdReason, holdKind = self:GetActionHold(inCombat, hostile)
    if holdTitle then
        HCOB.Advisor.Engine.SelectCandidate(candidates)
        return nil, holdTitle, holdKey, holdReason, holdKind
    end

    local reserve, reserveLabel = HCOB.Advisor.Engine.SurvivalReserve()
    local dyn = HCOB.Advisor.Engine.RollingDynamics(targetHP)
    local close = HCOB.Advisor.Engine.TargetIsClose()
    local enemies = CountActiveEnemies()
    local ttk = self:LevelingTTK(targetHP, dyn)
    local builder = Builder()
    local builderCost = self:EnergyCost(builder)
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
    elseif hp <= 80 and GougeInReach() and cp < 4 and targetHP >= 45 and reserve >= 48
        and SoloControlTarget() and not HasRoguePeriodicDamage()
        and (hp <= 65 or self:GetTalentRank(TALENT.GOUGE) > 0)
        and (not ttk or ttk >= 8) and IsKnown(S.GOUGE) and CooldownReady(S.GOUGE) and IsUsable(S.GOUGE)
        and energy >= self:EnergyCost(S.GOUGE) and energy <= self:EnergyCost(S.GOUGE) + 15 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.GOUGE, "GOUGE + POOL", "CTRL", "Solo melee pressure: spend affordable control before energy runs out, then let it last | " .. context, 76, "resource")
    end

    if reserve <= 34 and targetHP > 20 and IsKnown(S.BLIND) and CooldownReady(S.BLIND) and IsUsable(S.BLIND) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.BLIND, "BLIND + RESET", "CAST MANUALLY", "Emergency control before committing Vanish; create distance and reset the fight | " .. context, 103, "survival")
    end
    if reserve <= 30 and IsKnown(S.SPRINT) and CooldownReady(S.SPRINT) and IsUsable(S.SPRINT) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.SPRINT, "SPRINT + EXIT", "ALT", "Control window is weak: extend the leash before Vanish is compromised | " .. context, 99, "survival")
    end

    if cp >= 4 and reserve < 52 and IsKnown(S.KIDNEY_SHOT) and CooldownReady(S.KIDNEY_SHOT) and IsUsable(S.KIDNEY_SHOT) and targetHP > 28 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.KIDNEY_SHOT, "KIDNEY SHOT", "CAST MANUALLY", "Convert combo points into control when the fight turns bad | " .. context, 94, "control")
    end

    -- A leveling mob often dies before four CP. These are conservative spend
    -- windows, not a claim that percentage health predicts an exact lethal hit.
    local evisBonus = 1 + 0.05 * math.min(3, self:GetTalentRank(TALENT.EVISCERATE))
    local level = PlayerLevel()
    local ordinaryMob = SafeUnitClassification("target", "normal") == "normal"
        and (SafeUnitLevel("target", level) or level) <= level + 1
        and (not UnitIsPlayer or not UnitIsPlayer("target"))
    local finishSoon = (cp >= 3 and ((ordinaryMob and targetHP <= 45 * evisBonus) or (ttk and ttk <= 6)))
        or (cp >= 2 and ((ordinaryMob and targetHP <= 30 * evisBonus) or (ttk and ttk <= 3) or targetHP <= 22))
        or (cp >= 1 and ordinaryMob and targetHP <= 12)
    local wantsFinisher = cp >= 4 or finishSoon
    local poolingFinisher = wantsFinisher and IsKnown(S.EVISCERATE)
        and energy < self:EnergyCost(S.EVISCERATE)
    if wantsFinisher and IsKnown(S.EVISCERATE) and IsUsable(S.EVISCERATE)
        and energy >= self:EnergyCost(S.EVISCERATE) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.EVISCERATE, "EVISCERATE", "ALT+SHIFT",
            "Spend " .. cp .. " CP before the target dies; avoid another builder | " .. context,
            finishSoon and 98 or 90, "finisher", nil, {required=finishSoon or cp >= 5})
    end

    local snd = StablePlayerBuff(S.SLICE_DICE)
    if IsKnown(S.SLICE_DICE) and not snd and cp >= 1 and cp <= 2 and targetHP >= 45
        and reserve >= 48 and not wantsFinisher and IsUsable(S.SLICE_DICE)
        and energy >= self:EnergyCost(S.SLICE_DICE) + builderCost then
        local duration = (6 + 3 * cp) * (1 + 0.15 * math.min(3, self:GetTalentRank(TALENT.SLICE)))
        local longEnough = ttk and ttk >= 11 and math.min(ttk - 1, duration) >= 10
        if longEnough then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.SLICE_DICE, "SLICE AND DICE", "CAST MANUALLY", "Small CP investment with sufficient observed lifetime and energy for the next builder | " .. context, 75, "efficiency")
        end
    end

    if enemies >= 2 and IsKnown(S.BLADE_FLURRY) and CooldownReady(S.BLADE_FLURRY) and IsUsable(S.BLADE_FLURRY) and reserve >= 65 and hp >= 72 then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.BLADE_FLURRY, "BLADE FLURRY", "CAST MANUALLY", "Stable two-target pull: convert uptime into cleave without sacrificing the escape reserve | " .. context, 78, "aoe")
    end
    if IsKnown(S.ADRENALINE_RUSH) and CooldownReady(S.ADRENALINE_RUSH) and IsUsable(S.ADRENALINE_RUSH) and reserve >= 60 and targetHP >= 70 then
        local longEnough = ttk and ttk >= 16
        if longEnough then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.ADRENALINE_RUSH, "ADRENALINE RUSH", "CAST MANUALLY", "Use DPS cooldown only on a sufficiently long fight | " .. context, 72, "burst")
        end
    end

    if IsKnown(builder) and IsUsable(builder) and energy >= builderCost and cp < 5 and not poolingFinisher then
        local score = 61 + (cp <= 2 and 4 or 0) + (targetHP >= 55 and 3 or 0)
        if cp >= 4 then score = score - 8 end
        HCOB.Advisor.Engine.AddCandidate(candidates, builder, SpellName(builder, "BUILDER"), "BASE", "Learned builder at its current energy cost; keep dealing damage while no higher priority applies | " .. context, score, "damage")
    end

    local id, title, key, reason, kind = HCOB.Advisor.Engine.SelectCandidate(candidates)
    if id or title then return id, title, key, reason, kind end
    if self:NeedsAutoAttackRestart(inCombat, hostile) then
        return nil, "ATTACK STOPPED", "PRESS BASE ONCE",
            "Restart auto-attack once; then wait for the next ability", "action"
    end
    if not poolingFinisher and energy >= builderCost then
        return nil, "NO USABLE ABILITY", "CHECK TARGET",
            "Check target, range and ability requirements; no valid spell is ready", "idle"
    end
    return nil, poolingFinisher and "ENERGY FOR EVISCERATE" or "ENERGY RECOVERY", "WAIT FOR ENERGY",
        "Let auto-attacks continue; wait for the next affordable ability", "idle"
end



-- Advisor class contract extensions.
function Class:GetCautionRecommendation(ctx)
    if ctx.hp <= 58 and IsKnown(S.EVASION) and CooldownReady(S.EVASION) and IsUsable(S.EVASION) then
        return S.EVASION, "UNFAVORABLE FIGHT", "ALT+CTRL", ctx.text .. ": Evasion and prepare Vanish", "caution"
    end
    if (ctx.hp <= 65 or ctx.reserve <= 40) and IsKnown(S.GOUGE) and CooldownReady(S.GOUGE) and IsUsable(S.GOUGE) then
        return S.GOUGE, "UNFAVORABLE FIGHT", "CTRL", ctx.text .. ": Gouge to create a window", "caution"
    end
    local id, title, key, reason, kind = self:GetRecommendation(true, true, ctx.targetHP, TalentSpec())
    if id or title then return id, title, key, ctx.text .. ": " .. (reason or "Watch the fight trend"), "caution" end
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
        local reserve = HCOB.Advisor.Engine.SurvivalReserve()
        if enemies == 2 and hp > 65 and reserve >= 48 then return nil end
        return nil, "MULTI x2", "CONTROL / EXIT", "Do not greed DPS without Vanish available", "caution"
end

-- Class interrupt contract. Advisor/Threat only detects the cast;
-- the class decides which control/interrupt spell is valid.
function Class:GetInterruptRecommendation()
        if IsKnown(S.KICK) and CooldownReady(S.KICK) and IsUsable(S.KICK) then return S.KICK, "INTERRUPT!", "CTRL+SHIFT", "Kick" end
        if IsKnown(S.GOUGE) and CooldownReady(S.GOUGE) and IsUsable(S.GOUGE)
            and GougeInReach() and HCOB.Advisor.Engine.TargetOnPlayer() then
            return S.GOUGE, "INTERRUPT!", "CTRL", "Gouge while Kick is unavailable"
        end
end

-- Secure macro class contract. Core/Macros owns only secure attribute orchestration;
-- the class owns its base action and modifier spell choices.
function Class:BuildMainMacro()
        local lines = NewLines()
        local builder = Builder()
        AddLine(lines, "/startattack [nostealth,harm]", 1)
        AddLine(lines, CastLine(builder, "combat,harm", false), 1)
        return FitMacro(lines)
end

function Class:BuildModifierMacros()
        return {
            shift=BuildSpellMacro(S.STEALTH), ctrl=self:BuildActionPanelMacro(S.GOUGE),
            alt=BuildSpellMacro(S.SPRINT), ctrlshift=BuildSpellMacro(S.KICK, "harm", true),
            altshift=BuildSpellMacro(S.EVISCERATE, "harm", true), altctrl=BuildSpellMacro(S.EVASION),
            all=BuildSpellMacro(S.VANISH),
            desc={shift="Stealth",ctrl="Gouge",alt="Sprint",ctrlshift="Kick",altshift="Eviscerate",altctrl="Evasion",all="Vanish"}
        }
end

function Class:BuildActionPanelMacro(id)
    if id == S.GOUGE then return "/stopattack\n" .. BuildSpellMacro(id, "harm") end
end

function Class:GetBaseActionInfo(spec)
    local builder = Builder()
    return builder, SpellName(builder, "Builder")
end

