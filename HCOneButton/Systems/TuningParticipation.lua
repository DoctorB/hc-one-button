-- Evidence quality for new fights. Keep raw history/DPS intact; do not teach
-- the learner that an unknown opponent or a late group tag is poor rotation.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)
local P = {}
HCOB.Systems.TuningParticipation = P

local function Number(value)
    local ok, number = pcall(tonumber, value)
    value = ok and number or nil
    if value and value == value and math.abs(value) < math.huge then return value end
end

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end

function P.Begin(fight)
    local tuning = fight and fight.tuning
    if not tuning then return end
    tuning.sampleQuality = {version=1, events=0, knownTarget=false}
    -- The selection at PLAYER_REGEN_DISABLED may be absent, friendly or not
    -- the opponent actually fought. Recover metadata only from an observed foe.
    tuning.context.targetLevel = nil
    tuning.context.targetClassification = nil
    tuning.context.targetHealthMax = nil
end

function P.Sample(fight, observedGUID)
    local tuning = fight and fight.tuning
    local quality = tuning and tuning.sampleQuality
    local guid = observedGUID or (tuning and tuning._qualityTarget)
    if not quality or quality.knownTarget or not guid then return end
    for _, unit in ipairs({"target", "targettarget", "pettarget"}) do
        if Read(SafeUnitGUID, unit) == guid and Read(UnitIsPlayer, unit) ~= true then
            local level = Number(Read(SafeUnitLevel, unit, nil))
            local classification = Read(SafeUnitClassification, unit, nil)
            local maximum = Number(Read(SafeUnitHealthMax, unit, nil))
            local elite = classification == "elite" or classification == "rareelite" or classification == "worldboss"
            if maximum and maximum > 0 and ((level and level > 0) or elite) then
                tuning.context.targetLevel = level and level > 0 and level or nil
                tuning.context.targetClassification = type(classification) == "string" and classification or nil
                tuning.context.targetHealthMax = maximum
                quality.knownTarget = true
                -- Fill missing root metadata for reports too; never rewrite the
                -- fight's original target with an unrelated later selection.
                if not fight.target then
                    fight.target = Read(SafeUnitName, unit, nil)
                    fight.targetLevel = tuning.context.targetLevel
                    fight.targetClassification = tuning.context.targetClassification
                end
                return
            end
        end
    end
end

function P.Observe(fight, opponentGUID)
    local tuning = fight and fight.tuning
    local quality = tuning and tuning.sampleQuality
    if not quality then return end
    local elapsed = math.max(0, GetTime() - (fight.startClock or GetTime()))
    quality.firstEvent = quality.firstEvent or elapsed
    quality.lastEvent = elapsed
    quality.events = quality.events + 1
    if opponentGUID and not tuning._qualityTarget then tuning._qualityTarget = opponentGUID end
    P.Sample(fight)
end

function P.Finalize(fight)
    local tuning = fight and fight.tuning
    local quality = tuning and tuning.sampleQuality
    if not quality then return {} end -- historical/direct contract consumers
    local guid = tuning._qualityTarget
    tuning._qualityTarget = nil -- clear before sampling/finalization could fail
    P.Sample(fight, guid)
    local duration = math.max(0, Number(fight.duration) or 0)
    local first = Number(quality.firstEvent)
    local reasons = {}
    if not quality.knownTarget then reasons[#reasons+1] = "unknown_target" end
    if not first then
        reasons[#reasons+1] = "no_participation"
    else
        quality.entryDelay = first
        -- Allow normal pull/cast latency. Long energy waits after engagement
        -- are not inactivity; only the initial delay before real participation
        -- is tested, for every class and for pet/healing participation too.
        if first > 4 and first > duration * 0.25 then reasons[#reasons+1] = "late_participation" end
    end
    quality.eligible = #reasons == 0
    quality.reasons = reasons
    return reasons
end
