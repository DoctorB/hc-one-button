-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)


HCOB.Core.ClassAPI = HCOB.Core.ClassAPI or {
    IsKnown = IsKnown, IsUsable = IsUsable, CooldownReady = CooldownReady,
    HasPlayerBuff = HasPlayerBuff, HasMyTargetDebuff = HasMyTargetDebuff,
    SpellCastSeconds = SpellCastSeconds, HasWandEquipped = HasWandEquipped,
    SpellName = SpellName, AuraByName = AuraByName, Clamp = Clamp,
}
function HCOB.Advisor.Engine.AddCandidate(list, id, title, key, reason, score, tag, displayKind)
    if not list then return end
    list[#list + 1] = {
        id=id, title=title, key=key, reason=reason,
        score=tonumber(score) or 0, tag=tag or "action", displayKind=displayKind,
    }
end

function HCOB.Advisor.Engine.SelectCandidate(list)
    if not list or #list == 0 then
        HCOB.Advisor.Engine.lastCandidates = {}
        return nil
    end
    local now = GetTime()
    local best, bestScore
    for _, c in ipairs(list) do
        local effective = c.score or 0
        if HCOB.Advisor.Engine.lastClassActionId and c.id == HCOB.Advisor.Engine.lastClassActionId
           and (now - (HCOB.Advisor.Engine.lastClassActionAt or 0)) <= 0.65 then
            effective = effective + 4 -- short hysteresis: preserve stability without masking a fresh state change
        end
        c.effectiveScore = effective
        if not best or effective > bestScore then best, bestScore = c, effective end
    end
    table.sort(list, function(a,b) return (a.effectiveScore or a.score or 0) > (b.effectiveScore or b.score or 0) end)
    HCOB.Advisor.Engine.lastCandidates = list
    HCOB.Advisor.Engine.lastCandidateSelectionAt = now
    if best then
        if HCOB.Advisor.Engine.lastClassActionId ~= best.id then
            HCOB.Advisor.Engine.lastClassActionAt = now
        end
        HCOB.Advisor.Engine.lastClassActionId = best.id
        HCOB.Advisor.Engine.lastClassAction = best
        return best.id, best.title, best.key, best.reason, best.displayKind
    end
end

function HCOB.Advisor.Engine.Stabilize(spellId, title, keyHint, reason, kind)
    local now = GetTime()
    local priority = HCOB.Advisor.Engine.kindPriority[kind or "idle"] or 0
    local state = HCOB.Advisor.Engine.displayState
    local signature = tostring(spellId) .. ":" .. tostring(kind) .. ":" .. tostring(title)

    if not state then
        HCOB.Advisor.Engine.displayState = {spellId=spellId,title=title,key=keyHint,reason=reason,kind=kind,priority=priority,signature=signature,since=now}
        HCOB.Advisor.Engine.pendingDisplayState = nil
        return spellId, title, keyHint, reason, kind
    end
    if state.signature == signature then
        state.reason = reason
        state.key = keyHint
        HCOB.Advisor.Engine.pendingDisplayState = nil
        return spellId, title, keyHint, reason, kind
    end

    -- Safety/interrupt escalation is immediate. A normal equal/lower-priority
    -- swap must instead survive several refreshes before it is shown. The old
    -- implementation held only the first 0.12s of the *current* state, so one
    -- transient sample could still flash a second spell at any later time.
    -- A short remaining cooldown is normally the global cooldown. Treat it as
    -- plausible during confirmation; a real spent cooldown still replaces the
    -- old recommendation immediately.
    local oldCooldownPlausible = state.spellId == nil or CooldownReady(state.spellId)
        or CooldownRemaining(state.spellId) <= 1.60
    local oldStillPlausible = state.spellId == nil or (IsKnown(state.spellId)
        and IsUsable(state.spellId) and oldCooldownPlausible)
    if state.spellId and oldStillPlausible and HCOB.Advisor.Engine.IsRangedHostileSpell(state.spellId)
       and HCOB.Advisor.Engine.SpellRange(state.spellId, "target") == false then
        oldStillPlausible = false
    end

    local normalSwap = priority < 70 and (state.priority or 0) < 70
    if normalSwap and oldStillPlausible then
        local pending = HCOB.Advisor.Engine.pendingDisplayState
        if not pending or pending.signature ~= signature then
            HCOB.Advisor.Engine.pendingDisplayState = {signature=signature, since=now}
            return state.spellId, state.title, state.key, state.reason, state.kind
        end
        if (now - (pending.since or now)) < 0.20 then
            return state.spellId, state.title, state.key, state.reason, state.kind
        end
    end

    HCOB.Advisor.Engine.displayState = {spellId=spellId,title=title,key=keyHint,reason=reason,kind=kind,priority=priority,signature=signature,since=now}
    HCOB.Advisor.Engine.pendingDisplayState = nil
    return spellId, title, keyHint, reason, kind
end


function HCOB.Advisor.Engine.ResetStabilization()
    HCOB.Advisor.Engine.displayState = nil
    HCOB.Advisor.Engine.pendingDisplayState = nil
    HCOB.Advisor.Engine.lastClassActionId = nil
    HCOB.Advisor.Engine.lastClassActionAt = nil
end


function HCOB.Advisor.Engine.BuildClassContext(inCombat, hostile, targetHP, spec)
    local hp = UnitHealthPct("player")
    local mana = HCOB.Advisor.Engine.ManaPct()
    local close = hostile and HCOB.Advisor.Engine.TargetIsClose() or false
    local reserve, reserveLabel = 100, "SAFE"
    local dyn, ttk
    if inCombat and hostile then
        reserve, reserveLabel = HCOB.Advisor.Engine.SurvivalReserve()
        dyn = HCOB.Advisor.Engine.RollingDynamics(targetHP)
        ttk = dyn and dyn.confidence >= 0.38 and dyn.ttk or nil
    end
    local level = PlayerLevel()
    local targetLevel = hostile and SafeUnitLevel("target", level) or level
    local classification = hostile and SafeUnitClassification("target", "normal") or "normal"
    local tough = classification == "elite" or classification == "rareelite" or classification == "worldboss" or targetLevel >= level + 1
    return {
        inCombat = inCombat and true or false,
        hostile = hostile and true or false,
        spec = spec,
        player = { hp = hp, mana = mana, level = level, grouped = HCOB.Advisor.Engine.PlayerIsGrouped() },
        target = {
            hp = tonumber(targetHP) or 100, level = targetLevel, classification = classification,
            close = close, tough = tough, guid = hostile and SafeUnitGUID("target") or nil,
            onPlayer = hostile and HCOB.Advisor.Engine.TargetOnPlayer() or false,
            onPet = hostile and HCOB.Advisor.Engine.TargetOnPet() or false,
        },
        combat = { reserve = reserve, reserveLabel = reserveLabel, dynamics = dyn, ttk = ttk },
        pet = { alive = HCOB.Advisor.Engine.PetAlive(), hp = HCOB.Advisor.Engine.PetHP(), tanking = hostile and HCOB.Advisor.Engine.TargetOnPet() or false },
    }
end



function HCOB.Advisor.Engine.DebugPrint()
    local reserve, label = HCOB.Advisor.Engine.SurvivalReserve()
    local dyn = HCOB.Advisor.Engine.lastDynamics
    print(string.format("|cff00ff98HCOB ADVISOR 2.0:|r reserve %.0f (%s) | trend=%s", reserve or 0, tostring(label), tostring(HCOB.Advisor.Engine.trendState or "none")))
    if dyn then
        local ttk = dyn.ttk == math.huge and "inf" or string.format("%.1f", dyn.ttk)
        local ttd = dyn.ttd == math.huge and "inf" or string.format("%.1f", dyn.ttd)
        print(string.format("Rolling %.1fs | TTK %s | TTD %s | confidence %.0f%% | out %.2f%%/s | in %.2f%%/s", dyn.window or 0, ttk, ttd, (dyn.confidence or 0)*100, dyn.targetRate or 0, dyn.incomingPctRate or 0))
    else
        print("Rolling dynamics: insufficient data / outside single-target combat")
    end
    local list = HCOB.Advisor.Engine.lastCandidates or {}
    for i=1, math.min(5, #list) do
        local c = list[i]
        print(string.format("  #%d %.1f | %s | %s", i, c.effectiveScore or c.score or 0, tostring(c.title or SpellName(c.id,"?")), tostring(c.tag or "action")))
    end
end


function PlayAlert(kind)
    if not HCOB_DB.soundAlerts or not PlaySound then return end
    local now = GetTime()
    if kind == "danger" then
        if now - lastDangerSound < 8 then return end
        lastDangerSound = now
    elseif kind == "interrupt" then
        if now - lastInterruptSound < 2 then return end
        lastInterruptSound = now
    end
    local kit = SOUNDKIT and (SOUNDKIT.RAID_WARNING or SOUNDKIT.ALARM_CLOCK_WARNING_3)
    if kit then pcall(PlaySound, kit, "Master") end
end


function ActiveClassModule()
    return HCOB.Classes and HCOB.Classes[PLAYER_CLASS] or nil
end

function BuffRecommendation(inCombat)
    local class = ActiveClassModule()
    if class and class.GetBuffRecommendation then
        return class:GetBuffRecommendation(inCombat)
    end
    return nil
end


-- Class-agnostic dispatch: the engine knows only the class contract.
function ClassRecommendation(inCombat, hostile, targetHP)
    local spec = TalentSpec()
    local class = ActiveClassModule()
    if class and class.GetRecommendation then
        return class:GetRecommendation(inCombat, hostile, targetHP, spec)
    end
    return nil
end

function Recommend()
    -- Recommendation-local candidate snapshots must never leak across an early
    -- safety/interrupt return. SelectCandidate repopulates these when class
    -- scoring is actually reached during this Recommend() call.
    HCOB.Advisor.Engine.lastCandidates = {}
    HCOB.Advisor.Engine.lastCandidateSelectionAt = nil
    local inCombat = UnitAffectingCombat("player") and true or false
    local hostile = HostileLiveTarget()
    local hp, hpReadable = UnitHealthPct("player")
    local targetHP, targetReadable = 100, true
    if hostile then targetHP, targetReadable = UnitHealthPct("target") end
    local pType = UnitPowerType("player")
    local _, powerReadable = UnitPowerPct("player", pType)
    if inCombat and (not hpReadable or not powerReadable or (hostile and not targetReadable)) then
        return nil, "DATA LIMITED", "BASE SPAM ONLY",
            "Protected combat data is unavailable; smart recommendations are paused", "caution"
    end
    local playerLevel = PlayerLevel()
    local targetLevel = hostile and SafeUnitLevel("target", playerLevel) or playerLevel
    local classification = hostile and SafeUnitClassification("target", "normal") or "normal"
    if inCombat or not hostile then HCOB.Advisor.Engine.lastPrePullReadiness = nil end

    if inCombat and hp <= (HCOB_DB.criticalHP or 20) then
        local id, title, key, reason = PanicRecommendation()
        return id, title or "CRITICAL", key or "ALL MODS", reason or "Escape / potion", "danger"
    end
    if inCombat and hp <= (HCOB_DB.dangerHP or 35) then
        local id, title, key, reason = PanicRecommendation()
        return id, title or "DANGER", key or "ALL MODS", reason or "Consider escaping", "danger"
    end

    -- An interruptible cast remains higher priority than CAUTION warnings: risk
    -- multi-pull must not hide an immediate interrupt. HP thresholds
    -- critical states above still keep absolute priority.
    local cast = hostile and ActiveTargetCast() or nil
    if inCombat and cast then
        local id, title, key, reason = InterruptRecommendation()
        if id then return id, title, key, (cast.name or "Enemy cast") .. " - " .. reason, "interrupt" end
    end

    local enemies = CountActiveEnemies()
    if inCombat and enemies >= 2 and HCOB_DB.hcDangerAdvisor ~= false then
        local mid, mtitle, mkey, mreason, mkind = MultiPullRecommendation(enemies, hp, targetHP)
        if mtitle then return mid, mtitle, mkey, mreason, mkind end
    end

    -- HC single-target fight trend: CAUTION enters before the old DANGER,
    -- so you have time to prepare Hamstring/escape instead of reacting at 35% HP.
    if inCombat and hostile and HCOB_DB.hcDangerAdvisor ~= false and targetHP > 20 then
        local dyn = FightDynamics(targetHP)
        if dyn and dyn.ttk < math.huge and dyn.ttd < math.huge then
            local trend = HCOB.Advisor.Engine.TrendState(dyn, hp)
            local reserve, reserveLabel = HCOB.Advisor.Engine.SurvivalReserve()
            local trendText = string.format("You ~%.0fs / mob ~%.0fs | conf %.0f%% | reserve %.0f %s", dyn.ttd, dyn.ttk, (dyn.confidence or 0)*100, reserve or 0, reserveLabel or "?")
            if trend == "danger" then
                local id, _, key, reason = PanicRecommendation()
                return id, "FIGHT WORSENING", key or "ALL MODS", trendText .. ": " .. (reason or "create distance"), "danger"
            elseif trend == "caution" then
                local class = ActiveClassModule()
                if class and class.GetCautionRecommendation then
                    local cid, ctitle, ckey, creason, ckind = class:GetCautionRecommendation({
                        inCombat=inCombat, hostile=hostile, hp=hp, targetHP=targetHP,
                        dynamics=dyn, reserve=reserve, reserveLabel=reserveLabel, text=trendText,
                    })
                    if cid or ctitle then return cid, ctitle, ckey, creason, ckind or "caution" end
                end
                return nil, "UNFAVORABLE FIGHT", "PREPARE ESCAPE", trendText .. ": preserve control/defensives", "caution"
            end
        end
    end

    if not inCombat and hostile then
        local diff = targetLevel - playerLevel
        if classification == "elite" or classification == "rareelite" or classification == "worldboss" then
            return nil, "HIGH RISK", "EVALUATE PULL", "Hardcore target: " .. classification, "danger"
        elseif diff >= 3 then
            return nil, "HIGH RISK", "EVALUATE PULL", "Target is +" .. diff .. " levels above you", "danger"
        end

        local _, prepTitle, prepKey, prepReason, prepKind = HCOB.Advisor.Engine.PrePullRecommendation({
            playerLevel=playerLevel, targetLevel=targetLevel, classification=classification,
            targetTough=classification == "elite" or classification == "rareelite" or classification == "worldboss" or targetLevel >= playerLevel + 1,
        })
        if prepTitle then
            return nil, prepTitle, prepKey, prepReason, prepKind
        end
    end

    -- First handle combat windows that can expire (proc/execute/cooldown),
    -- then buffs. ClassRecommendation returns NIL if there is nothing manual to do.
    local id, title, key, reason, classKind = ClassRecommendation(inCombat, hostile, targetHP)
    if id or title then return id, title, key, reason, classKind or "action" end

    id, title, key, reason = BuffRecommendation(inCombat)
    if id then return id, title, key, reason, "buff" end

    local class = ActiveClassModule()
    if class and class.GetIdleRecommendation then
        local iid, ititle, ikey, ireason, ikind = class:GetIdleRecommendation(inCombat, hostile)
        if iid or ititle then return iid, ititle, ikey, ireason, ikind or "idle" end
    end

    local rid, rtitle, rkey, rreason, rkind = HCOB.Advisor.Engine.RangedBaseRecommendation(inCombat, hostile)
    if rid or rtitle then return rid, rtitle, rkey, rreason, rkind or "idle" end

    if not inCombat and hostile then
        local readiness = HCOB.Advisor.Engine.lastPrePullReadiness
        return nil, "PULL READY", "PRESS BASE",
            readiness and readiness.summary or "Recovery checks passed", "idle"
    end

    return nil, "BASE OK", "KEEP SPAMMING", "No urgent manual spell", "idle"
end


