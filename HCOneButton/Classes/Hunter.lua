local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Class = HCOB.Classes.HUNTER or {}
HCOB.Classes.HUNTER = Class
Class.classToken = "HUNTER"
Class.fallbackSpec = 1

function Class:GetRecommendation(inCombat, hostile, targetHP, spec)
    local petAlive = HCOB.Hunter.PetAlive()
    local candidates = {}

    if HCOB.Hunter.ManagementCandidates then
        for _, m in ipairs(HCOB.Hunter.ManagementCandidates(inCombat, hostile) or {}) do
            HCOB.Advisor.Engine.AddCandidate(candidates, nil, m.title, m.key, m.reason, m.score, m.tag, m.displayKind)
        end
    end

    if not inCombat and petAlive and IsKnown(S.FEED_PET) then
        local happiness, petDamagePct = HCOB.Hunter.Happiness()
        local eating = HCOB.Hunter.PetIsEating()
        if happiness and happiness < 3 and not eating then
            local food = HCOB.Hunter.FoodCandidate()
            if food then
                local title = happiness == 1 and "PET HUNGRY!" or "FEED PET"
                HCOB.Advisor.Engine.AddCandidate(candidates, S.FEED_PET, title, "ALT+CTRL",
                    string.format("%s -> %s (pet damage %s%%)", HCOB.Hunter.PetDietText(), food.name, tostring(petDamagePct or "?")), 96, "sustain")
            else
                HCOB.Advisor.Engine.AddCandidate(candidates, S.FEED_PET, "NO PET FOOD", "/HCOB PETFOOD",
                    "Diet " .. HCOB.Hunter.PetDietText() .. ": no compatible/useful food in bags", 95, "sustain")
            end
        end
    end

    if not hostile then
        local activeAspect = HCOB.Hunter.ActiveAspect()
        local travelSeconds = HCOB.Hunter.TravelStableSeconds(inCombat, hostile)
        if not inCombat and travelSeconds >= 2.0 and IsKnown(S.ASPECT_CHEETAH) and CooldownReady(S.ASPECT_CHEETAH) and IsUsable(S.ASPECT_CHEETAH) and activeAspect ~= S.ASPECT_CHEETAH then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.ASPECT_CHEETAH, "ASPECT OF THE CHEETAH", "CAST MANUALLY", "Traveling out of combat: increase movement speed", 58, "travel")
        end
        return HCOB.Advisor.Engine.SelectCandidate(candidates)
    end

    HCOB.Hunter.TravelStableSeconds(inCombat, hostile)
    local manaPct = HCOB.Hunter.ManaPct()
    local petHP = HCOB.Hunter.PetHP()
    local close = HCOB.Hunter.TargetIsClose()
    local canShoot = HCOB.Hunter.CanShootTarget()
    local level = PlayerLevel()
    local targetLevel = SafeUnitLevel("target", level) or level
    local classification = SafeUnitClassification("target", "normal") or "normal"
    local tough = classification == "elite" or classification == "rareelite" or classification == "worldboss" or targetLevel >= level
    local elapsed = HCOB.Hunter.TargetElapsed(inCombat)
    local afterAuto = HCOB.Hunter.AfterAutoWindow()
    local reserve, reserveLabel = HCOB.Advisor.Engine.SurvivalReserve()
    local dyn = inCombat and HCOB.Advisor.Engine.RollingDynamics(targetHP) or nil
    local estimatedTTK = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    local riskPenalty = reserve < 55 and ((55 - reserve) * 0.75) or 0
    if reserve < 35 then riskPenalty = riskPenalty + 10 end
    local context = string.format("reserve %.0f %s", reserve, reserveLabel)
    if estimatedTTK and estimatedTTK < math.huge then context = context .. string.format(" | TTK ~%.0fs", estimatedTTK) end

    local activeAspect = HCOB.Hunter.ActiveAspect()
    local rangedStable = HCOB.Hunter.RangedStableSeconds(close, canShoot)
    local threat = HCOB.Hunter.ThreatSnapshot and HCOB.Hunter.ThreatSnapshot() or {state="unknown"}
    local threatPenalty = HCOB.Hunter.ThreatPenalty and HCOB.Hunter.ThreatPenalty(threat) or 0
    if threat.state and threat.state ~= "unknown" then context = context .. " | threat " .. string.upper(threat.state) end

    -- Aspect management. Cheetah is never allowed to remain active in combat,
    -- because taking a hit can daze the Hunter. Hawk is the normal ranged
    -- combat aspect; Monkey is a temporary defensive stance for sustained melee.
    if not inCombat and IsKnown(S.ASPECT_HAWK) and CooldownReady(S.ASPECT_HAWK) and IsUsable(S.ASPECT_HAWK) and activeAspect ~= S.ASPECT_HAWK then
        local aspectReason = activeAspect == S.ASPECT_CHEETAH and "Drop Cheetah before the pull to avoid a daze" or "Prepare the normal ranged combat aspect"
        HCOB.Advisor.Engine.AddCandidate(candidates, S.ASPECT_HAWK, "ASPECT OF THE HAWK", "CAST MANUALLY", aspectReason, 110, "aspect")
    elseif inCombat and activeAspect == S.ASPECT_CHEETAH then
        local emergencyAspect = (close and IsKnown(S.ASPECT_MONKEY)) and S.ASPECT_MONKEY or (IsKnown(S.ASPECT_HAWK) and S.ASPECT_HAWK or nil)
        if emergencyAspect and CooldownReady(emergencyAspect) and IsUsable(emergencyAspect) then
            HCOB.Advisor.Engine.AddCandidate(candidates, emergencyAspect, emergencyAspect == S.ASPECT_MONKEY and "DROP CHEETAH -> MONKEY" or "DROP CHEETAH -> HAWK", "CAST MANUALLY", "Cheetah is unsafe in combat: remove the daze risk immediately", 125, "survival")
        end
    elseif inCombat and canShoot and rangedStable >= 2.0 and IsKnown(S.ASPECT_HAWK) and CooldownReady(S.ASPECT_HAWK) and IsUsable(S.ASPECT_HAWK) and activeAspect ~= S.ASPECT_HAWK then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.ASPECT_HAWK, "ASPECT OF THE HAWK", "CAST MANUALLY", "Ranged position has been stable for 2s: return to the damage aspect", 74, "aspect")
    end

    -- Attack-mode recovery.  Do not assume Classic will seamlessly swap ranged
    -- <-> melee through the dead zone.  BASE is the secure synchronizer for both
    -- modes and can be pressed again whenever this candidate appears.
    if inCombat and close and not HCOB.Hunter.MeleeAutoActive() then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.ATTACK, "ENABLE MELEE", "PRESS BASE", "Target is in melee but Auto Attack is not active", 98, "attackmode")
    elseif inCombat and canShoot and HCOB.Hunter.AutoShotNeedsRestart() then
        HCOB.Advisor.Engine.AddCandidate(candidates, S.AUTO_SHOT, "RESUME AUTO SHOT", "PRESS BASE", "Target is back at range: restart the ranged cycle", 102, "attackmode")
    end

    -- Predictive threat management. Do not wait for the mob to physically turn
    -- before reducing Hunter burst. A high-threat state intentionally produces
    -- a no-button recommendation: keep Auto Shot running and let the pet catch up.
    if inCombat and petAlive and not close and canShoot then
        if threat.state == "unstable" and targetHP > 28 then
            HCOB.Advisor.Engine.AddCandidate(candidates, nil, "THREAT HIGH", "LET IT RUN", "Hold burst for a moment and let the pet rebuild its threat lead", 79, "threat", "caution")
        elseif threat.state == "lost" and targetHP > 20 then
            HCOB.Advisor.Engine.AddCandidate(candidates, nil, "AGGRO LOST", "CREATE DISTANCE", "The target is on you: prioritize a peel and let the pet regain threat", 87, "threat", "caution")
        end
    end

    -- Survival / control candidates intentionally outrank damage candidates.
    if inCombat and petAlive and petHP and IsKnown(S.MEND_PET) and IsUsable(S.MEND_PET) then
        if petHP <= 32 and not close and not HCOB.Advisor.Engine.TargetOnPlayer() then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.MEND_PET, "MEND PET!", "ALT+CTRL", string.format("Pet %.0f%%: save your tank | %s", petHP, context), 99, "survival")
        elseif petHP <= 52 and tough and targetHP >= 45 and HCOB.Hunter.PetIsTanking() and manaPct >= 25 then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.MEND_PET, "MEND PET", "ALT+CTRL", string.format("Pet %.0f%% on a long fight | %s", petHP, context), 82, "survival")
        end
    end

    if inCombat and close then
        local dyingSoon = targetHP <= 18 or (estimatedTTK and estimatedTTK <= 2.8)
        local lowTarget = targetHP <= 28 or (estimatedTTK and estimatedTTK <= 4.0)

        if not dyingSoon and IsKnown(S.ASPECT_MONKEY) and CooldownReady(S.ASPECT_MONKEY) and IsUsable(S.ASPECT_MONKEY) and activeAspect ~= S.ASPECT_MONKEY then
            local monkeyScore = reserve < 50 and 98 or 91
            HCOB.Advisor.Engine.AddCandidate(candidates, S.ASPECT_MONKEY, "ASPECT OF THE MONKEY", "CAST MANUALLY", "Sustained melee pressure: trade ranged damage for dodge until you create distance", monkeyScore, "survival")
        end

        -- Reactive melee skills should be consumed when their proc is actually
        -- available. Mongoose Bite is intentionally above normal kiting damage,
        -- but below true panic control.
        if IsKnown(S.MONGOOSE_BITE) and CooldownReady(S.MONGOOSE_BITE) and IsUsable(S.MONGOOSE_BITE) then
            local mongooseScore = dyingSoon and 111 or 92
            HCOB.Advisor.Engine.AddCandidate(candidates, S.MONGOOSE_BITE, "MONGOOSE BITE", "CAST MANUALLY", "Reactive dodge proc: use it before the window expires", mongooseScore, "proc")
        end

        if IsKnown(S.RAPTOR_STRIKE) and CooldownReady(S.RAPTOR_STRIKE) and IsUsable(S.RAPTOR_STRIKE) and lowTarget then
            local raptorScore = dyingSoon and 109 or 97
            HCOB.Advisor.Engine.AddCandidate(candidates, S.RAPTOR_STRIKE, "RAPTOR FINISH", "CAST MANUALLY", "Target is low: finish it instead of spending a GCD only to create range", raptorScore, "finisher")
        end

        if IsKnown(S.WING_CLIP) and IsUsable(S.WING_CLIP) and not HasMyTargetDebuff(S.WING_CLIP) then
            local wingScore = dyingSoon and 76 or (lowTarget and 90 or 100)
            HCOB.Advisor.Engine.AddCandidate(candidates, S.WING_CLIP, "WING CLIP + EXIT", "ALT", "Dead zone: slow, create distance and resume Auto Shot", wingScore, "survival")
        end
        if IsKnown(S.SCATTER_SHOT) and CooldownReady(S.SCATTER_SHOT) and HCOB.Hunter.CanCastRanged(S.SCATTER_SHOT) and targetHP > 20 then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.SCATTER_SHOT, "SCATTER + DISTANCE", "CTRL+SHIFT", "Target is on you: break pressure and return to range", 94, "survival")
        end
    end

    if inCombat and not close and petAlive and (threat.state == "lost" or HCOB.Advisor.Engine.TargetOnPlayer()) then
        if IsKnown(S.SCATTER_SHOT) and CooldownReady(S.SCATTER_SHOT) and HCOB.Hunter.CanCastRanged(S.SCATTER_SHOT) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.SCATTER_SHOT, "PEEL: SCATTER", "CTRL+SHIFT", "You have aggro: create space and let the pet regain threat", 96, "survival")
        end
        if IsKnown(S.CONCUSSIVE_SHOT) and CooldownReady(S.CONCUSSIVE_SHOT) and HCOB.Hunter.CanCastRanged(S.CONCUSSIVE_SHOT) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.CONCUSSIVE_SHOT, "PEEL: CONCUSSIVE", "CTRL+SHIFT", "You have aggro: slow before the dead zone", 89, "survival")
        end
    end

    -- Classic traps are primarily pre-pull tools. Recommend Freezing Trap only
    -- when the target is meaningfully dangerous; do not slow normal grinding
    -- by asking for a trap on every ordinary mob.
    if not inCombat and IsKnown(S.FREEZING_TRAP) and CooldownReady(S.FREEZING_TRAP) and IsUsable(S.FREEZING_TRAP) then
        local trapWorth = classification == "elite" or classification == "rareelite" or classification == "worldboss" or targetLevel >= level + 2
        if trapWorth then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.FREEZING_TRAP, "FREEZING TRAP PREP", "CAST MANUALLY", "Dangerous pull: place a control trap before sending the pet or starting Auto Shot", 78, "setup")
        end
    end

    if inCombat and spec == 1 and petAlive and targetHP >= 70 then
        if IsKnown(S.BESTIAL_WRATH) and CooldownReady(S.BESTIAL_WRATH) and IsUsable(S.BESTIAL_WRATH) and (tough or CountActiveEnemies() >= 2) then
            local longEnough = not estimatedTTK or estimatedTTK >= 10
            if longEnough then HCOB.Advisor.Engine.AddCandidate(candidates, S.BESTIAL_WRATH, "BESTIAL WRATH", "CAST MANUALLY", "Important fight: pet burst | " .. context, 75 - riskPenalty, "burst") end
        end
        if IsKnown(S.INTIMIDATION) and CooldownReady(S.INTIMIDATION) and IsUsable(S.INTIMIDATION) and tough then
            local intimidationScore = (threat.state == "unstable" or threat.state == "lost") and 82 or 73
            HCOB.Advisor.Engine.AddCandidate(candidates, S.INTIMIDATION, "INTIMIDATION", "CAST MANUALLY", "Stun/threat on a durable target | " .. context, intimidationScore, "control")
        end
    end

    local markWorth = tough or targetLevel >= level - 3
    if estimatedTTK then markWorth = estimatedTTK >= 10 end
    if IsKnown(S.HUNTERS_MARK) and targetHP >= 60 and (not inCombat or elapsed <= 3.5) and markWorth then
        if not HasMyTargetDebuff(S.HUNTERS_MARK) then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.HUNTERS_MARK, "HUNTER'S MARK", "CAST MANUALLY", "Target will live long enough | " .. context, (inCombat and 54 or 64) - riskPenalty * 0.25, "setup")
        end
    end

    local stingWorth = tough or targetLevel >= level - 3
    if estimatedTTK then stingWorth = estimatedTTK >= 8.0 end
    -- Serpent Sting is a ranged action: never let it enter the score while the
    -- target is in melee/dead zone or outside its actual spell range. Also
    -- suppress it immediately after a successful cast while the aura API is
    -- still catching up.
    if inCombat and manaPct >= 30 and targetHP >= 45 and elapsed <= 7.0 and stingWorth
       and CooldownReady(S.SERPENT_STING) and not close and canShoot and HCOB.Hunter.CanCastRanged(S.SERPENT_STING)
       and not HCOB.Hunter.HasSerpentSting() then
        local score = 67 + math.min(8, math.max(0, (manaPct - 45) * 0.12)) - riskPenalty - threatPenalty * 0.35
        HCOB.Advisor.Engine.AddCandidate(candidates, S.SERPENT_STING, "SERPENT STING", "CAST MANUALLY", "Early DoT, valid range and enough time to tick | " .. context, score, "dot")
    end

    if inCombat and canShoot and afterAuto then
        if IsKnown(S.AIMED_SHOT) and CooldownReady(S.AIMED_SHOT) and HCOB.Hunter.CanCastRanged(S.AIMED_SHOT) and manaPct >= 40 and targetHP >= 38 then
            local longEnough = not estimatedTTK or estimatedTTK >= math.max(3.5, SpellCastSeconds(S.AIMED_SHOT) + 0.5)
            if longEnough then
                HCOB.Advisor.Engine.AddCandidate(candidates, S.AIMED_SHOT, "AIMED WEAVE", "ALT+SHIFT", "Window immediately after Auto Shot | " .. context, 81 - riskPenalty - threatPenalty, "weave")
            end
        end
        if CountActiveEnemies() <= 1 and IsKnown(S.MULTI_SHOT) and CooldownReady(S.MULTI_SHOT) and HCOB.Hunter.CanCastRanged(S.MULTI_SHOT) and manaPct >= 53 and targetHP >= 30 then
            HCOB.Advisor.Engine.AddCandidate(candidates, S.MULTI_SHOT, "MULTI WEAVE", "CTRL", "After Auto Shot; healthy mana | " .. context, 72 - riskPenalty - threatPenalty * 1.15, "weave")
        end
        if IsKnown(S.ARCANE_SHOT) and CooldownReady(S.ARCANE_SHOT) and HCOB.Hunter.CanCastRanged(S.ARCANE_SHOT) then
            local finisher = targetHP <= 28 and manaPct >= 32
            local filler = not IsKnown(S.AIMED_SHOT) and manaPct >= 48 and targetHP >= 25
            local hardBurst = tough and manaPct >= 70 and (not estimatedTTK or estimatedTTK >= 5)
            if finisher or filler or hardBurst then
                local key = IsKnown(S.AIMED_SHOT) and "CAST MANUALLY" or "ALT+SHIFT"
                local score = finisher and 84 or (hardBurst and 66 or 61)
                score = score - (finisher and riskPenalty * 0.25 or riskPenalty) - (finisher and threatPenalty * 0.20 or threatPenalty)
                HCOB.Advisor.Engine.AddCandidate(candidates, S.ARCANE_SHOT, "ARCANE SHOT", key,
                    (finisher and "Finisher without stopping Auto Shot" or "Burst between Auto Shots") .. " | " .. context, score, finisher and "finisher" or "burst")
            end
        end
    end

    if inCombat and canShoot and targetHP >= 68 and IsKnown(S.RAPID_FIRE) and CooldownReady(S.RAPID_FIRE) and IsUsable(S.RAPID_FIRE) and (tough or classification == "rare") then
        local longEnough = not estimatedTTK or estimatedTTK >= 12
        if longEnough then HCOB.Advisor.Engine.AddCandidate(candidates, S.RAPID_FIRE, "RAPID FIRE", "CAST MANUALLY", "Long target: maximize Auto Shot | " .. context, 69 - riskPenalty - threatPenalty, "burst") end
    end

    return HCOB.Advisor.Engine.SelectCandidate(candidates)
end




-- Advisor class contract extensions.
function Class:GetBuffRecommendation(inCombat)
    return nil -- Aspect management is handled by Hunter/Aspects.lua.
end

function Class:GetCautionRecommendation(ctx)
    if HCOB.Hunter.TargetIsClose() and IsKnown(S.WING_CLIP) and IsUsable(S.WING_CLIP) and not HasMyTargetDebuff(S.WING_CLIP) then
        return S.WING_CLIP, "UNFAVORABLE FIGHT", "ALT", ctx.text .. ": Wing Clip and return to range", "caution"
    end
    if IsKnown(S.CONCUSSIVE_SHOT) and CooldownReady(S.CONCUSSIVE_SHOT) and HCOB.Hunter.CanCastRanged(S.CONCUSSIVE_SHOT) then
        return S.CONCUSSIVE_SHOT, "UNFAVORABLE FIGHT", "CTRL+SHIFT", ctx.text .. ": slow the target and let the pet tank", "caution"
    end
end

function Class:GetIdleRecommendation(inCombat, hostile)
    if inCombat and hostile then
        return nil, "ATTACK OK", "LET IT RUN", "Do not spam BASE: use it only when the Advisor shows ENABLE MELEE / RESUME AUTO SHOT", "idle"
    elseif hostile then
        local pullState = HCOB.Hunter.PullRangeState()
        if pullState == "ready" then
            return S.AUTO_SHOT, "PULL READY", "PRESS BASE", "Target is inside actual Auto Shot range", "idle"
        elseif pullState == "close" then
            return nil, "TOO CLOSE", "CREATE DISTANCE", "You are below useful ranged distance: back up until BASE turns green", "caution"
        elseif pullState == "out" then
            return nil, "OUT OF RANGE", "MOVE CLOSER", "Auto Shot cannot reach the target yet: move closer until BASE turns green", "idle"
        else
            return nil, "RANGE UNKNOWN", "ADJUST DISTANCE", "The client does not expose a reliable range: adjust distance until a shot is in range", "idle"
        end
    end
end

-- Hardcore safety class contract. Advisor/Survival owns policy orchestration;
-- this class owns its spells and class-specific escape/resource model.
function Class:GetSurvivalReserve(ctx)
    local hp, mana = ctx.hp, ctx.mana
    local score
        local petHP = HCOB.Hunter.PetHP() or 0
        score = hp * 0.48 + mana * 0.10 + petHP * 0.17
        if HCOB.Hunter.PetAlive() then score = score + 4 end
        if HCOB.Hunter.PetIsTanking() then score = score + 4 end
        if IsKnown(S.FEIGN_DEATH) and CooldownReady(S.FEIGN_DEATH) and IsUsable(S.FEIGN_DEATH) then score = score + 10 end
        if IsKnown(S.SCATTER_SHOT) and CooldownReady(S.SCATTER_SHOT) and IsUsable(S.SCATTER_SHOT) then score = score + 5 end
        if IsKnown(S.CONCUSSIVE_SHOT) and CooldownReady(S.CONCUSSIVE_SHOT) and IsUsable(S.CONCUSSIVE_SHOT) then score = score + 3 end
        if IsKnown(S.WING_CLIP) and IsUsable(S.WING_CLIP) then score = score + 3 end
        if HCOB.Hunter.TargetIsClose() then score = score - 8 end
        if HCOB.Hunter.ThreatSnapshot then
            local threat = HCOB.Hunter.ThreatSnapshot()
            if threat.state == "stable" then score = score + 3
            elseif threat.state == "unstable" then score = score - 6
            elseif threat.state == "lost" then score = score - 12 end
        end
    return score
end

function Class:GetPanicRecommendation()
        if IsKnown(S.FEIGN_DEATH) and CooldownReady(S.FEIGN_DEATH) and IsUsable(S.FEIGN_DEATH) then
            return S.FEIGN_DEATH, "FEIGN DEATH", "CTRL+ALT+SHIFT", "Pet passive + follow, then Feign: do not let the pet keep you in combat"
        end
        if HCOB.Hunter.TargetIsClose() and IsKnown(S.WING_CLIP) and IsUsable(S.WING_CLIP) and not HasMyTargetDebuff(S.WING_CLIP) then
            return S.WING_CLIP, "WING CLIP + RUN", "ALT", "Feign unavailable: slow and create distance"
        end
        if IsKnown(S.SCATTER_SHOT) and CooldownReady(S.SCATTER_SHOT) and HCOB.Hunter.CanCastRanged(S.SCATTER_SHOT) then
            return S.SCATTER_SHOT, "SCATTER + RUN", "CTRL+SHIFT", "Control the target and create distance"
        end
        if IsKnown(S.CONCUSSIVE_SHOT) and CooldownReady(S.CONCUSSIVE_SHOT) and HCOB.Hunter.CanCastRanged(S.CONCUSSIVE_SHOT) then
            return S.CONCUSSIVE_SHOT, "CONCUSSIVE + RUN", "CTRL+SHIFT", "Slow the target and extend the leash"
        end
        return nil, "RUN!", "PREPARE ESCAPE", "No immediate Hunter reset available"
end

function Class:GetMultiPullRecommendation(enemies, hp, targetHP)
        local close = HCOB.Hunter.TargetIsClose()
        local manaPct = HCOB.Hunter.ManaPct()
        local petHP = HCOB.Hunter.PetHP()

        if enemies >= 3 then
            if IsKnown(S.FEIGN_DEATH) and CooldownReady(S.FEIGN_DEATH) and IsUsable(S.FEIGN_DEATH) then
                return S.FEIGN_DEATH, "3+ MOBS - FEIGN", "CTRL+ALT+SHIFT", "Pet passive + follow and reset the pull", "danger"
            end
            if close and IsKnown(S.WING_CLIP) and IsUsable(S.WING_CLIP) and not HasMyTargetDebuff(S.WING_CLIP) then
                return S.WING_CLIP, "3+ MOBS - WING CLIP", "ALT", "Slow the target on you and create an escape route", "danger"
            end
            if IsKnown(S.SCATTER_SHOT) and CooldownReady(S.SCATTER_SHOT) and HCOB.Hunter.CanCastRanged(S.SCATTER_SHOT) then
                return S.SCATTER_SHOT, "3+ MOBS - SCATTER", "CTRL+SHIFT", "Control one, move away, do not tunnel DPS", "danger"
            end
            return nil, "3+ MOBS - GET OUT", "PREPARE ESCAPE", "Too many targets for a clean Hardcore pull", "danger"
        end

        if hp <= 50 or (petHP and petHP <= 28) then
            local id, _, key, reason = self:GetPanicRecommendation()
            return id, "2 MOBS - GET OUT", key or "CTRL+ALT+SHIFT", reason or "Reset the pull", "danger"
        end

        if close and IsKnown(S.WING_CLIP) and IsUsable(S.WING_CLIP) and not HasMyTargetDebuff(S.WING_CLIP) then
            return S.WING_CLIP, "MULTI x2 - DEAD ZONE", "ALT", "Slow, leave melee and put the pet back in front", "caution"
        end

        if IsKnown(S.MULTI_SHOT) and CooldownReady(S.MULTI_SHOT) and HCOB.Hunter.CanCastRanged(S.MULTI_SHOT) and manaPct >= 48 and (not petHP or petHP >= 50) and HCOB.Hunter.AfterAutoWindow() then
            return S.MULTI_SHOT, "MULTI x2 - WEAVE", "CTRL", "Only already engaged mobs: after Auto Shot", "caution"
        end

        if petHP and petHP <= 45 and IsKnown(S.MEND_PET) and IsUsable(S.MEND_PET) and HCOB.Hunter.PetIsTanking() then
            return S.MEND_PET, "MULTI x2 - PET", "ALT+CTRL", string.format("Pet %.0f%%: stabilize before pushing DPS", petHP), "caution"
        end

        return nil, "MULTI x2", "KITE / PET", "Keep both in front of the pet; avoid new adds", "caution"
end

-- Class interrupt contract. Advisor/Threat only detects the cast;
-- the class decides which control/interrupt spell is valid.
function Class:GetInterruptRecommendation()
        -- Scatter is immediate when the target is in valid range. Intimidation
        -- depends on the pet reaching and attacking the target, so keep it as the
        -- fallback rather than the first interrupt recommendation.
        if IsKnown(S.SCATTER_SHOT) and CooldownReady(S.SCATTER_SHOT) and HCOB.Hunter.CanCastRanged(S.SCATTER_SHOT) then return S.SCATTER_SHOT, "INTERRUPT!", "CTRL+SHIFT", "Scatter Shot" end
        if IsKnown(S.INTIMIDATION) and HCOB.Hunter.PetAlive() and CooldownReady(S.INTIMIDATION) and IsUsable(S.INTIMIDATION) then
            return S.INTIMIDATION, "INTERRUPT!", "CAST MANUALLY", "Intimidation: pet stun"
        end
end

-- Secure macro class contract. Core/Macros owns only secure attribute orchestration;
-- the class owns its base action and modifier spell choices.
function Class:BuildMainMacro()
        local lines = NewLines()
        AddLine(lines, "/petattack [harm]", 1)
        -- Hunter v1.21.2: BASE is a hybrid attack-mode synchronizer. Auto Shot must
        -- remain re-armable in the SAME fight after a melee/dead-zone transition, so
        -- the old castsequence(..., null) is intentionally gone.  /startattack gives
        -- us the melee side; !Auto Shot gives us the ranged side without toggling it
        -- off on a repeated recovery press. BASE is still not intended as a spam key.
        if IsKnown(S.AUTO_SHOT) then
            AddLine(lines, "/cast [harm] !" .. SpellName(S.AUTO_SHOT), 1)
        end
        AddLine(lines, "/startattack [harm]", 1)
        return FitMacro(lines)
end

function Class:BuildModifierMacros()
        -- One modifier per job. ALT+CTRL is context-safe: in combat Mend Pet;
        -- out of combat it feeds the best compatible bag item selected by HCOB.
        local control = NewLines()
        if IsKnown(S.SCATTER_SHOT) then AddLine(control, BuildSpellMacro(S.SCATTER_SHOT, "harm"), 1) end
        if IsKnown(S.CONCUSSIVE_SHOT) then AddLine(control, BuildSpellMacro(S.CONCUSSIVE_SHOT, "harm"), 2) end
        if #control == 0 then AddLine(control, "/stopmacro", 1) end

        local burst = IsKnown(S.AIMED_SHOT) and BuildSpellMacro(S.AIMED_SHOT, "harm") or BuildSpellMacro(S.ARCANE_SHOT, "harm")

        local panic = NewLines()
        AddLine(panic, "/petpassive", 1)
        AddLine(panic, "/petfollow", 1)
        AddLine(panic, BuildSpellMacro(S.FEIGN_DEATH), 1)

        local eating = HCOB.Hunter.PetIsEating()
        local happiness = HCOB.Hunter.Happiness()
        local food = (not eating and happiness and happiness < 3) and HCOB.Hunter.FoodCandidate() or nil
        local petUtilityDesc = "Mend Pet"
        if not UnitAffectingCombat("player") then
            if eating then petUtilityDesc = "Pet eating (locked)"
            elseif food then petUtilityDesc = "Feed Pet: " .. tostring(food.name)
            else petUtilityDesc = "Feed Pet / Mend Pet" end
        end

        return {
            shift=BuildSpellMacro(S.ASPECT_HAWK), ctrl=BuildSpellMacro(S.MULTI_SHOT, "harm"),
            alt=BuildSpellMacro(S.WING_CLIP, "harm", true), ctrlshift=FitMacro(control),
            altshift=burst, altctrl=HCOB.Hunter.FeedMacro(),
            all=FitMacro(panic),
            desc={shift="Aspect of the Hawk",ctrl="Multi-Shot",alt="Wing Clip",ctrlshift="Scatter / Concussive",altshift=IsKnown(S.AIMED_SHOT) and "Aimed Shot" or "Arcane Shot",altctrl=petUtilityDesc,all="Pet passive + Feign Death"}
        }
end

function Class:GetBaseActionInfo(spec)
    return S.AUTO_SHOT, "PET + HYBRID ATTACK"
end

function Class:IsRangedBaseAction(id)
    return id == S.AUTO_SHOT
end

function Class:GetBaseLabel()
    return "PULL / AUTO"
end

function Class:GetBaseVisualState()
    if UnitAffectingCombat("player") or not HostileLiveTarget() then return nil end
    return HCOB.Hunter.PullRangeState()
end

-- Class event contract. Core/Events dispatches lifecycle events generically;
-- Hunter owns its pet/food/auto-shot state transitions.
function Class:HandleEvent(event, arg1, arg2)
    if event == "PLAYER_LOGIN" then
        HCOB.Hunter.InvalidateFood()
    elseif event == "PLAYER_REGEN_DISABLED" then
        HCOB.Hunter.combatEnteredAt = GetTime()
        HCOB.Hunter.ResetTargetState(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        HCOB.Hunter.combatEnteredAt = nil
        HCOB.Hunter.targetEngagedAt = nil
        HCOB.Hunter.engagedTargetGUID = nil
        HCOB.Hunter.autoRepeatActive = false
    elseif event == "PLAYER_TARGET_CHANGED" then
        HCOB.Hunter.lastMeleeAt = nil
        HCOB.Hunter.lastAutoShotAt = nil
        HCOB.Hunter.ResetTargetState(UnitAffectingCombat("player"))
    elseif event == "PLAYER_LEVEL_UP" or event == "UNIT_PET" or event == "PET_BAR_UPDATE" then
        HCOB.Hunter.InvalidateFood()
    elseif event == "START_AUTOREPEAT_SPELL" then
        HCOB.Hunter.autoRepeatActive = true
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        HCOB.Hunter.autoRepeatActive = false
    elseif event == "BAG_UPDATE_DELAYED" or event == "UNIT_HAPPINESS" or event == "GET_ITEM_INFO_RECEIVED"
        or (event == "UNIT_AURA" and arg1 == "pet") then
        local relevant = event ~= "GET_ITEM_INFO_RECEIVED" or HCOB.Hunter.foodDataPending
        if relevant then
            if event ~= "UNIT_AURA" then HCOB.Hunter.InvalidateFood() end
            if not InCombatLockdown() then BuildMacros() else pendingRebuild = true end
        end
    end
end

-- Fixed Action Panel macro contract. UI/ActionPanel owns slots and rendering;
-- Hunter owns pet-specific secure macro text.
function Class:BuildActionPanelMacro(id)
    if id == S.FEED_PET then return HCOB.Hunter.FeedMacro() end
    if id == S.MEND_PET then return BuildSpellMacro(id, "@pet,exists,nodead") end
    if id == S.FEIGN_DEATH then
        local lines = NewLines()
        AddLine(lines, "/petpassive", 1)
        AddLine(lines, "/petfollow", 1)
        AddLine(lines, BuildSpellMacro(S.FEIGN_DEATH), 1)
        return FitMacro(lines)
    end
    return nil
end

