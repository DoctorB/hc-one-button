-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

-- this engine ranks them, keeps short-lived recommendations stable and uses a
-- rolling combat window instead of the whole-fight average for HC trend checks.
-- -------------------------------------------------------------------------
HCOB.Advisor.Engine = HCOB.Advisor.Engine
HCOB.Advisor.Engine.samples = HCOB.Advisor.Engine.samples or {}
HCOB.Advisor.Engine.lastCandidates = HCOB.Advisor.Engine.lastCandidates or {}
HCOB.Advisor.Engine.kindPriority = {
    idle=0, buff=20, action=40, caution=70, interrupt=90, danger=100,
}

function HCOB.Advisor.Engine.ResetDynamics()
    HCOB.Advisor.Engine.samples = {}
    HCOB.Advisor.Engine.dynamicsTargetGuid = nil
    HCOB.Advisor.Engine.trendState = nil
    HCOB.Advisor.Engine.lastDynamics = nil
end

function HCOB.Advisor.Engine.RollingDynamics(targetHP)
    if not currentFight or CountActiveEnemies() > 1 or not HostileLiveTarget() then
        HCOB.Advisor.Engine.ResetDynamics()
        return nil
    end

    local guid = SafeUnitGUID("target")
    -- The combat session can contain several sequential targets. The rolling
    -- window follows the current GUID instead of being pinned to the first
    -- target recorded when combat started.
    if HCOB.Advisor.Engine.dynamicsTargetGuid ~= guid then
        HCOB.Advisor.Engine.ResetDynamics()
        HCOB.Advisor.Engine.dynamicsTargetGuid = guid
    end

    local now = GetTime()
    local samples = HCOB.Advisor.Engine.samples
    local last = samples[#samples]
    if not last or (now - last.t) >= 0.20 then
        samples[#samples + 1] = {
            t=now,
            targetHP=tonumber(targetHP) or UnitHealthPct("target") or 100,
            playerHP=UnitHealthPct("player"),
            damageTaken=tonumber(currentFight.damageTaken) or 0,
            hpMax=math.max(1, SafeUnitHealthMax("player", SafeNumber(currentFight.hpMax, 1)) or 1),
        }
    end

    local cutoff = now - 5.0
    while #samples > 2 and samples[2].t < cutoff do table.remove(samples, 1) end
    if #samples < 2 then return nil end

    local first = samples[1]
    local current = samples[#samples]
    local dt = math.max(0.05, current.t - first.t)
    if dt < 2.2 then return nil end

    local targetLost = math.max(0, (first.targetHP or 100) - (current.targetHP or 100))
    local targetRate = targetLost / dt
    local incomingDamage = math.max(0, (current.damageTaken or 0) - (first.damageTaken or 0))
    local hpMax = math.max(1, current.hpMax or first.hpMax or 1)
    local incomingPct = incomingDamage / hpMax * 100
    local incomingPctRate = incomingPct / dt
    local playerHP = current.playerHP or UnitHealthPct("player")
    local nowTarget = current.targetHP or targetHP or 100
    local ttk = targetRate > 0.05 and (nowTarget / targetRate) or math.huge
    local ttd = incomingPctRate > 0.03 and (playerHP / incomingPctRate) or math.huge

    local observation = Clamp(dt / 4.0, 0, 1)
    local outgoingEvidence = Clamp(targetLost / 15.0, 0, 1)
    local incomingEvidence = Clamp(incomingPct / 12.0, 0, 1)
    local confidence = Clamp(observation * 0.45 + outgoingEvidence * 0.35 + incomingEvidence * 0.20, 0, 1)

    local result = {
        window=dt, ttk=ttk, ttd=ttd,
        targetRate=targetRate, incomingPctRate=incomingPctRate,
        confidence=confidence, targetLost=targetLost, incomingPct=incomingPct,
    }
    HCOB.Advisor.Engine.lastDynamics = result
    return result
end

-- Shared class helpers for Advisor Engine 2.0. These are methods instead of
-- chunk-level locals so the Classic Lua 5.1 local-variable ceiling stays safe.

function HCOB.Advisor.Engine.TrendState(dyn, hp)
    if not dyn or dyn.confidence < 0.38 or dyn.ttk == math.huge or dyn.ttd == math.huge then
        if not dyn then HCOB.Advisor.Engine.trendState = nil end
        return nil
    end
    local state = HCOB.Advisor.Engine.trendState
    local severe = (hp <= 45 and dyn.ttk >= 4) or (hp <= 65 and dyn.ttd <= (dyn.ttk * 1.05 + 0.5))
    local caution = hp <= 72 and dyn.ttk >= 4 and dyn.ttd <= (dyn.ttk * 1.35 + 2.0)

    if state == "danger" then
        if hp >= 54 and dyn.ttd > (dyn.ttk * 1.28 + 2.0) then state = caution and "caution" or nil end
    elseif state == "caution" then
        if severe then state = "danger"
        elseif hp >= 78 or dyn.ttd > (dyn.ttk * 1.58 + 3.0) then state = nil end
    else
        if severe and dyn.confidence >= 0.48 then state = "danger"
        elseif caution and dyn.confidence >= 0.45 then state = "caution" end
    end
    HCOB.Advisor.Engine.trendState = state
    return state
end


function FightDynamics(targetHP)
    return HCOB.Advisor.Engine.RollingDynamics(targetHP)
end

