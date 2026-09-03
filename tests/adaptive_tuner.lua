local hostGlobal = _G
local environment = setmetatable({}, {__index = hostGlobal})
environment._G = environment
environment.PLAYER_CLASS = "MAGE"
environment.HCOB_CharacterDB = {adaptive={version=2, enabled=true, contexts={}, totalEligible=0}}
environment.GetServerTime = function() return 1788400000 end
environment.GetTime = function() return 10 end
environment.print = function() end

local function hash(parts)
    return "h:" .. table.concat(parts, "|")
end

environment.HCOneButton = {
    Internal=environment,
    Core={}, Advisor={Engine={}},
    Systems={TuningTelemetry={
        HashParts=hash,
        CandidateKey=function(id, tag) return tostring(id or "none") .. ":" .. tostring(tag or "action") end,
    }},
}

local chunk = assert(loadfile("HCOneButton/Systems/AdaptiveTuner.lua"))
setfenv(chunk, environment)
chunk()

local tuner = assert(environment.HCOneButton.Systems.AdaptiveTuner)
local context = {
    class="MAGE", specIndex=2, mode="solo", level=40,
    talentSignature="talent-fire", spellbookSignature="spellbook-40",
    targetLevel=40, targetClassification="normal",
}

local function fight(spellId, dps, hp, eligible)
    local key = tostring(spellId) .. ":damage"
    return {
        dps=dps, hpMinPct=hp,
        tuning={
            context=context,
            eligibility={adaptive=eligible ~= false, reasons=eligible == false and {"pvp"} or {}},
            candidates={[key]={spellId=spellId, tag="damage", title="Action " .. spellId, samples=8}},
            decisions={[key]={spellId=spellId, tag="damage", title="Action " .. spellId, accepted=1, offers=1}},
        },
    }
end

-- No adjustment is allowed during calibration.
for _=1,4 do tuner.LearnFight(fight(101, 50, 50, true)) end
environment.currentFight = {tuning={context=context}}
assert(tuner.GetCandidateBias({id=101, tag="damage"}) == 0, "bias activated before context calibration")

-- A second action consistently associated with better normalized DPS and a
-- healthier floor receives a small positive bias; the weaker arm moves down.
for _=1,8 do tuner.LearnFight(fight(102, 110, 92, true)) end
local weakBias = tuner.GetCandidateBias({id=101, tag="damage"})
local strongBias = tuner.GetCandidateBias({id=102, tag="damage"})
assert(weakBias < 0, "weaker learned action did not receive a negative correction")
assert(strongBias > 0, "stronger learned action did not receive a positive correction")
assert(math.abs(weakBias) <= tuner.MAX_SCORE_BIAS and math.abs(strongBias) <= tuner.MAX_SCORE_BIAS,
    "learned correction exceeded hard bounds")
environment.currentFight = nil
assert(tuner.GetCandidateBias({id=102, tag="damage"}) == 0,
    "learner reused a stale context while current fight telemetry was unavailable")
environment.currentFight = {tuning={context=context}}

local store = environment.HCOB_CharacterDB.adaptive
local learnedContext = assert(store.contexts[store.lastContextKey])
assert(learnedContext.fights == 12 and store.totalEligible == 12, "eligible fight counters are incorrect")
assert(learnedContext.baselines.even and learnedContext.baselines.even.fights == 12,
    "target-difficulty baseline missing")
assert(fight(102, 100, 90, true).tuning.context.buildSignature == nil,
    "test context unexpectedly depends on equipment identity")

for _=1,3 do tuner.LearnFight(fight(103, 120, 95, true)) end
assert(tuner.GetCandidateBias({id=103, tag="damage"}) == 0,
    "action bias activated before the four-observation evidence gate")

local biasBeforeRevision = tuner.GetCandidateBias({id=102, tag="damage"})
for _=1,12 do tuner.LearnFight(fight(102, 40, 32, true)) end
local revisedBias = tuner.GetCandidateBias({id=102, tag="damage"})
assert(revisedBias < biasBeforeRevision, "later negative evidence did not roll the learned correction back")

-- Safety/control categories can never be changed, even if SavedVariables are
-- manually corrupted with a large bias.
learnedContext.arms["999:survival"] = {tag="survival", fights=99, bias=99}
assert(tuner.GetCandidateBias({id=999, tag="survival"}) == 0, "survival priority became tunable")
learnedContext.arms["102:damage"].bias = 99
assert(tuner.GetCandidateBias({id=102, tag="damage"}) == tuner.MAX_SCORE_BIAS,
    "runtime bias did not clamp corrupted SavedVariables")

local engineChunk = assert(loadfile("HCOneButton/Advisor/Engine.lua"))
setfenv(engineChunk, environment)
engineChunk()
local candidates = {
    {id=101, title="WEAK", key="BASE", reason="Weak standard score", score=70, tag="damage"},
    {id=102, title="STRONG", key="SHIFT", reason="Strong learned result", score=68, tag="damage"},
}
local selected, _, _, reason = environment.HCOneButton.Advisor.Engine.SelectCandidate(candidates)
assert(selected == 102, "bounded learned bias was not integrated into candidate selection")
assert(reason:find("Local tuning +4.00", 1, true), "visible adaptive explanation missing")

environment.HCOneButton.Advisor.Engine.ResetStabilization()
local protected, _, _, protectedReason = environment.HCOneButton.Advisor.Engine.SelectCandidate({
    {id=102, title="OFFENSE", key="SHIFT", reason="Learned offense", score=68, tag="damage"},
    {id=999, title="EMERGENCY", key="ALT", reason="Base safety winner", score=70, tag="survival"},
})
assert(protected == 999, "adaptive offense displaced a protected base-policy winner")
assert(not protectedReason:find("Local tuning", 1, true), "protected winner reported an adaptive adjustment")
learnedContext.arms["777:damage"] = false
assert(tuner.GetCandidateBias({id=777, tag="damage"}) == 0, "malformed learned action did not fail closed")

local before = store.totalEligible
tuner.LearnFight(fight(102, 500, 100, false))
assert(store.totalEligible == before, "ineligible fight entered the learner")

tuner.SetEnabled(false)
assert(tuner.GetCandidateBias({id=102, tag="damage"}) == 0, "disabled learner still changed priorities")
tuner.SetEnabled(true)
local status = tuner.Status()
assert(status.enabled and status.ready and status.contextFights == 27 and status.contexts == 1,
    "adaptive status summary is incorrect")

assert(tuner.Reset(), "adaptive reset failed")
assert(next(store.contexts) == nil and store.totalEligible == 0 and tuner.IsEnabled(),
    "adaptive reset did not preserve enabled state or clear learned data")

-- A real player action that differed from the recommendation may still be
-- useful evidence when it was an eligible candidate. Learn it conservatively:
-- one outcome per arm and fight, regardless of repeated deviations.
context = {
    class="MAGE", specIndex=2, mode="solo", level=40,
    talentSignature="talent-override", spellbookSignature="spellbook-override",
    targetLevel=40, targetClassification="normal",
}
for _=1,4 do
    tuner.LearnFight({
        dps=100, hpMinPct=90,
        tuning={
            context=context,
            eligibility={adaptive=true, reasons={}},
            candidates={
                ["201:damage"]={spellId=201, tag="damage", title="Recommended", samples=8},
                ["202:damage"]={spellId=202, tag="damage", title="Player choice", samples=8},
            },
            decisions={
                ["201:damage"]={spellId=201, tag="damage", title="Recommended", accepted=0, offers=1},
            },
            actionStats={
                ["202"]={spellId=202, count=3, matched=0, deviations=3},
            },
        },
    })
end
local overrideContext = assert(store.contexts[store.lastContextKey])
local overrideArm = assert(overrideContext.arms["202:damage"])
assert(overrideArm.fights == 4, "player override was counted more than once per fight")
assert(overrideArm.userOverrides == 12, "valid player override evidence was not recorded")
tuner.Reset()

local classes = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "MAGE", "WARLOCK", "DRUID", "SHAMAN"}
for index, class in ipairs(classes) do
    context = {
        class=class, specIndex=1, mode="solo", level=40,
        talentSignature="talent-" .. class, spellbookSignature="spellbook-" .. class,
        targetLevel=40, targetClassification="normal",
    }
    tuner.LearnFight(fight(200 + index, 70, 80, true))
end
local contextCount = 0
for _ in pairs(store.contexts) do contextCount = contextCount + 1 end
assert(contextCount == 9 and store.totalEligible == 9, "all nine class contexts were not learned independently")
tuner.Reset()

print("local adaptive tuner regression: PASS")
