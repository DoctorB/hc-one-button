local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Class = HCOB.Classes.WARRIOR or {}
HCOB.Classes.WARRIOR = Class
Class.classToken = "WARRIOR"
Class.fallbackSpec = 1
-- Risk warnings inform the player; only critical HP overrides offense.
Class.riskWarningsOnly = true

local BATTLE_SHOUT_REFRESH_SECONDS = 10
local DEFENSIVE_DEBUFF_REFRESH_SECONDS = 3
local EXECUTE_POOL_START_HP = 30
local EXECUTE_POOL_RELEASE_RAGE = 85

local function BattleShoutState()
    local active, remaining = StablePlayerBuff(S.BATTLE_SHOUT)
    remaining = SafeNumber(remaining, 999) or 999
    return active and true or false, remaining
end

local function CurrentRage()
    local pType = UnitPowerType("player")
    return SafeUnitPower("player", pType, 0) or 0
end

local function DefensiveDebuffNeedsRefresh(id)
    local active, remaining = HasMyTargetDebuff(id)
    if not active then return true end
    remaining = SafeNumber(remaining, 999) or 999
    return remaining <= DEFENSIVE_DEBUFF_REFRESH_SECONDS
end

local function NextSwingQueueReady()
    if IsQueuedMeleeSwingSpell then
        -- The two on-next-swing abilities share one main-hand queue. Once
        -- either is armed, no further key request should be emitted.
        if IsQueuedMeleeSwingSpell(S.HEROIC_STRIKE)
           or (S.CLEAVE and IsQueuedMeleeSwingSpell(S.CLEAVE)) then
            return false, nil
        end
    end
    if MainhandSwingQueueOpen then return MainhandSwingQueueOpen() end
    return true, nil
end

local function ShouldPoolForExecute(targetHP, rage)
    return S.EXECUTE and IsKnown(S.EXECUTE)
        and targetHP > 20 and targetHP <= EXECUTE_POOL_START_HP
        and rage < EXECUTE_POOL_RELEASE_RAGE
end

function Class:HeroicRageThreshold(targetHP)
    local base = tonumber(HCOB_DB.warriorHeroicRage) or 35
    if base ~= base or base == math.huge or base == -math.huge then base = 35 end
    base = math.max(20, math.min(70, base))
    -- Reserve the developed kit's budget only after its repeatable offensive
    -- spenders are learned. Saved custom values remain unchanged.
    local developed = IsKnown(S.MORTAL_STRIKE) or IsKnown(S.BLOODTHIRST) or IsKnown(S.WHIRLWIND)
    local threshold = developed and base or math.max(20, base - 10)
    if targetHP and targetHP <= 30 and not IsKnown(S.EXECUTE) then
        threshold = math.max(20, threshold - 5)
    end
    return threshold, base
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
    local context = string.format("rage %d | reserve %.0f %s", rage, reserve, reserveLabel)
    if estimatedTTK and estimatedTTK < math.huge then context = context .. string.format(" | TTK ~%.0fs", estimatedTTK) end

    -- Escape tools remain manually available; the engine owns critical HP.

    if IsKnown(S.EXECUTE) and targetHP <= 20 and IsUsable(S.EXECUTE) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.EXECUTE, "EXECUTE!", "CAST MANUALLY", "Target <=20% | " .. context, 115, "finisher")
    end
    if IsKnown(S.OVERPOWER) and IsUsable(S.OVERPOWER) and CooldownReady(S.OVERPOWER) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.OVERPOWER, "OVERPOWER!", "CAST MANUALLY", "Reactive window available | " .. context, 108, "proc")
    end

    -- Core strike: high priority, but still scored so an Execute/Overpower or
    -- genuine survival action can beat it cleanly.
    if IsKnown(S.MORTAL_STRIKE) and CooldownReady(S.MORTAL_STRIKE) and IsUsable(S.MORTAL_STRIKE) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.MORTAL_STRIKE, "MORTAL STRIKE", "CAST MANUALLY", "Core single-target | " .. context, 96, "core")
    end
    if IsKnown(S.BLOODTHIRST) and CooldownReady(S.BLOODTHIRST) and IsUsable(S.BLOODTHIRST) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.BLOODTHIRST, "BLOODTHIRST", "CAST MANUALLY", "Core single-target | " .. context, 95, "core")
    end
    if enemies >= 2 and IsKnown(S.WHIRLWIND) and CooldownReady(S.WHIRLWIND) and IsUsable(S.WHIRLWIND) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.WHIRLWIND, "WHIRLWIND", "CAST MANUALLY", enemies .. " enemies | " .. context, 91, "aoe")
    elseif enemies <= 1 and IsKnown(S.WHIRLWIND) and CooldownReady(S.WHIRLWIND) and IsUsable(S.WHIRLWIND) and targetHP >= 30 then
        local majorReady = (IsKnown(S.MORTAL_STRIKE) and CooldownReady(S.MORTAL_STRIKE) and IsUsable(S.MORTAL_STRIKE))
            or (IsKnown(S.BLOODTHIRST) and CooldownReady(S.BLOODTHIRST) and IsUsable(S.BLOODTHIRST))
        if not majorReady and (not estimatedTTK or estimatedTTK >= 5) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.WHIRLWIND, "WHIRLWIND", "CAST MANUALLY", "Single-target rage spender while the major strike is unavailable | " .. context, 84, "damage")
        end
    end

    -- Mitigation can be worth more than another rage dump on a hard/long mob.
    if (enemies >= 2 or (tough and reserve < 58)) and targetHP >= 45 and IsKnown(S.THUNDER_CLAP) and CooldownReady(S.THUNDER_CLAP)
       and IsUsable(S.THUNDER_CLAP) and DefensiveDebuffNeedsRefresh(S.THUNDER_CLAP) then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.THUNDER_CLAP, "THUNDER CLAP", "CTRL", "Reduce melee pressure on a difficult fight | " .. context, 79 + (55 - math.min(55, reserve)) * 0.25, "mitigation")
    end
    if tough and targetHP >= 50 and IsKnown(S.DEMO_SHOUT) and IsUsable(S.DEMO_SHOUT)
       and DefensiveDebuffNeedsRefresh(S.DEMO_SHOUT) then
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
            HCOB.Advisor.Engine.AddCandidate(candidates, S.BATTLE_SHOUT, "BATTLE SHOUT", "SHIFT", shoutReason .. " | " .. context, shoutScore, "buff")
        end
    end

    if IsKnown(S.REND) and level <= 45 and not currentWarriorAutoRend and not HasMyTargetDebuff(S.REND) and IsUsable(S.REND) then
        local worthRend = tough or targetLevel <= 0 or targetLevel >= (level - 4)
        if level >= 36 then worthRend = tough and (not estimatedTTK or estimatedTTK >= 12) end
        if estimatedTTK and level <= 35 then worthRend = estimatedTTK >= 8.0 end
        if elapsed > 7.0 then worthRend = false end
        if targetHP >= 45 and worthRend then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.REND, "REND", "CAST MANUALLY", "Early DoT with enough time to tick | " .. context, 69, "dot")
        end
    end

    if HCOB_DB.warriorSunderBase ~= false and IsKnown(S.SUNDER_ARMOR) and IsUsable(S.SUNDER_ARMOR) and not HasMyTargetDebuff(S.SUNDER_ARMOR) then
        local levelWindow = level >= 22 and level <= 35 and targetLevel >= level
        local longEnough = estimatedTTK and estimatedTTK >= 13 or (not estimatedTTK and targetHP >= 72)
        if targetHP >= 60 and longEnough and (tough or levelWindow) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.SUNDER_ARMOR, "SUNDER x1", "CAST MANUALLY", "Armor debuff on a durable/long target | " .. context, 63, "setup")
        end
    end

    if IsKnown(S.BLOODRAGE) and rage <= 10 and hp >= 85 and targetHP >= 50 and enemies <= 1 and CooldownReady(S.BLOODRAGE) and IsUsable(S.BLOODRAGE) and elapsed <= 9 then
        local longEnough = not estimatedTTK or estimatedTTK >= 7
        if longEnough and reserve >= 55 then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.BLOODRAGE, "BLOODRAGE", "ALT+CTRL", "Opener: generate rage without stressing reserve | " .. context, 61, "resource")
        end
    end

    local hsThreshold, hsBase = self:HeroicRageThreshold(targetHP)

    local executePooling = ShouldPoolForExecute(targetHP, rage)
    local heroicKnown = IsKnown(S.HEROIC_STRIKE) or knownSpellNames[SpellName(S.HEROIC_STRIKE) or ""] == true
    local cleaveKnown = S.CLEAVE and (IsKnown(S.CLEAVE)
        or knownSpellNames[SpellName(S.CLEAVE) or ""] == true)
    local swingReady, swingRemaining = NextSwingQueueReady()
    local swingText = swingRemaining and string.format(" | next swing %.1fs", swingRemaining) or ""
    local cleaveThreshold = hsThreshold + 5
    if not executePooling and enemies >= 2 and cleaveKnown and swingReady
       and rage >= cleaveThreshold and IsUsable(S.CLEAVE) then
        local excess = math.max(0, rage - cleaveThreshold)
        local score = 71 + math.min(18, excess * 0.8) + math.min(6, (enemies - 1) * 3)
        HCOB.Advisor.Engine.AddCandidate(candidates, S.CLEAVE, "CLEAVE", "CAST MANUALLY", "Multi-target swing dump: " .. rage .. " / threshold " .. cleaveThreshold .. swingText .. " | " .. context, score, "aoe", nil, {
            baseThreshold=hsBase, effectiveThreshold=cleaveThreshold,
            rage=rage, enemies=enemies, reserve=reserve, executePooling=executePooling,
            swingRemaining=swingRemaining,
        })
    end
    if not executePooling and heroicKnown and swingReady and rage >= hsThreshold and IsUsable(S.HEROIC_STRIKE) then
        local excess = math.max(0, rage - hsThreshold)
        local noExecuteFinisher = not IsKnown(S.EXECUTE)
        local score = 64 + math.min(16, excess * 0.8) + (targetHP <= 30 and noExecuteFinisher and 8 or 0)
        HCOB.Advisor.Engine.AddCandidate(candidates, S.HEROIC_STRIKE, "HEROIC STRIKE", "ALT+SHIFT", "Rage dump: " .. rage .. " / threshold " .. hsThreshold .. swingText .. " | " .. context, score, "dump", nil, {
            baseThreshold=hsBase, effectiveThreshold=hsThreshold,
            rage=rage, enemies=enemies, reserve=reserve, executePooling=executePooling,
            swingRemaining=swingRemaining,
        })
    end

    local id, title, key, reason, kind = HCOB.Advisor.Engine.SelectCandidate(candidates)
    if id or title then return id, title, key, reason, kind end
    if executePooling then
        return nil, "POOL FOR EXECUTE", "KEEP AUTO ATTACKING",
            "Target approaching Execute range: preserve Rage below " .. EXECUTE_POOL_RELEASE_RAGE, "idle"
    end
    return nil
end



-- Advisor class contract extensions.
function Class:GetBuffRecommendation(inCombat)
    return nil
end

function Class:GetCautionRecommendation(ctx)
    return nil -- continue normal scoring; Engine decorates it with the warning
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
    return nil -- mitigation now competes with damage in the normal scorer
end

-- Class interrupt contract. Advisor/Threat only detects the cast;
-- the class decides which control/interrupt spell is valid.
function Class:GetInterruptRecommendation()
        if IsKnown(S.PUMMEL) and CooldownReady(S.PUMMEL) and IsUsable(S.PUMMEL) then return S.PUMMEL, "INTERRUPT!", "CTRL+SHIFT", "Pummel" end
        if IsKnown(S.SHIELD_BASH) and CooldownReady(S.SHIELD_BASH) and IsUsable(S.SHIELD_BASH) then return S.SHIELD_BASH, "INTERRUPT!", "CTRL+SHIFT", "Shield Bash" end
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
        local heroicStrike = CastLine(S.HEROIC_STRIKE, nil, true)
        heroicStrike = heroicStrike and ("/startattack\n" .. heroicStrike) or "/stopmacro"
        return {
            shift=BuildSpellMacro(S.BATTLE_SHOUT), ctrl=BuildSpellMacro(S.THUNDER_CLAP, nil, true),
            alt=BuildSpellMacro(S.HAMSTRING, nil, true), ctrlshift=FitMacro(interrupt),
            -- The bang form prevents repeated hardware/key samples from
            -- toggling an already queued Heroic Strike back off.
            altshift=heroicStrike, altctrl=BuildSpellMacro(S.BLOODRAGE, "combat"),
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

