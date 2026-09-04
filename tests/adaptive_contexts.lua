-- Integration coverage: use the real telemetry hashes and learner, not a
-- hand-written ContextSnapshot stub (which concealed the 1.29.0 mismatch).
local function loadInto(env, path)
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk()
end

local function runtime(saved)
    local env = setmetatable({}, {__index=_G})
    env._G = env
    env.PLAYER_CLASS = "WARRIOR"
    env.VERSION = "1.29.0"
    env.HCOB_CharacterDB = saved or {}
    env.HCOB_DB = {}
    env.level, env.rank, env.groupSize, env.now = 12, 2, 1, 100
    env.playerTarget, env.instanceType = false, "none"
    env.extraSpell = false
    env.PlayerLevel = function() return env.level end
    env.TalentSpec = function() return 1, "Arms", env.rank end
    env.TalentTabCompat = function(tab) return "Tab", tab == 1 and env.rank or 0 end
    env.GetNumTalents = function() return 1 end
    env.GetTalentInfo = function(tab) return "Talent", "icon", 1, 1, tab == 1 and env.rank or 0 end
    env.GetNumGroupMembers = function() return env.groupSize end
    env.UnitIsPlayer = function(unit) return unit == "target" and env.playerTarget end
    env.IsInInstance = function() return env.instanceType ~= "none", env.instanceType end
    env.IsKnown = function(id) return id ~= 845 or env.extraSpell end
    env.GetTime = function() return env.now end
    env.GetServerTime = function() return env.now end
    env.output = {}
    env.print = function(value) env.output[#env.output + 1] = value end
    env.HCOneButton = {Internal=env, Systems={}, UI={ActionPanel={actions={WARRIOR={772,78,845}}}}}
    loadInto(env, "HCOneButton/Systems/TuningTelemetry.lua")
    loadInto(env, "HCOneButton/Systems/AdaptiveTuner.lua")
    return env, env.HCOneButton.Systems.AdaptiveTuner, env.HCOneButton.Systems.TuningTelemetry
end

local env, a, t = runtime()
local function snapshot() return t.ContextSnapshot() end
local function fight(context)
    return {dps=45, hpMinPct=80, tuning={context=context or snapshot(), eligibility={adaptive=true},
        candidates={
            ["772:dot"]={spellId=772, title="Rend", tag="dot", samples=8},
            ["78:dump"]={spellId=78, title="Heroic Strike", tag="dump", samples=8},
        }, decisions={
            ["772:dot"]={spellId=772, title="Rend", tag="dot", accepted=1, offers=1},
            ["78:dump"]={spellId=78, title="Heroic Strike", tag="dump", accepted=1, offers=1},
        }}}
end
for _=1,8 do a.LearnFight(fight()) end
local store = env.HCOB_CharacterDB.adaptive
local originalKey = store.lastContextKey
local learned = store.contexts[originalKey]
-- Isolate lookup/display from the learner's statistical reward calculations.
learned.arms["772:dot"].situations = {["single:normal:main"]={bias=-1, chosen={n=8}, other={n=8}}}

local function expect(rows, corrections, label)
    local model, status = a.GetDisplayModel(), a.Status()
    assert(#model.arms == rows, label .. ": wrong displayed rows")
    assert(model.activeAdjustments == corrections, label .. ": wrong corrections")
    assert(status.activeAdjustments == model.activeAdjustments and status.contextFights == model.fights
        and status.learnedActions == model.learnedActions and status.contextKey == model.contextKey
        and status.viewProfile == model.viewProfile, label .. ": slash and inspector disagree")
    return model
end

expect(2, 1, "initial warrior")
local stable = snapshot().talentSignature
for _, target in ipairs({true, false, true, false}) do
    env.playerTarget = target
    assert(snapshot().mode == "solo", "target selection inferred PvP")
    expect(2, 1, "self/friendly/other player target")
end
env.level = 13
assert(snapshot().talentSignature == stable, "level polluted talent signature")
expect(2, 1, "level 13 / same talents and spells")
env.currentFight = fight()
assert(a.GetCandidateBias({id=772,tag="dot"}) == -1, "same-band learned bias disappeared")

-- Viewing PvP is a persisted inspection preference, not a gameplay switch.
assert(a.SetViewProfile("pvp"))
local pvpView = expect(0, 0, "explicit PvP view")
assert(pvpView.learningSupported == false and not pvpView.ready, "PvP falsely reported calibration")
assert(a.GetCandidateBias({id=772,tag="dot"}) == -1, "view switch changed normal gameplay")
local reloadEnv, reloadA = runtime(env.HCOB_CharacterDB)
assert(reloadA.GetDisplayModel().viewProfile == "pvp", "view choice did not survive reload")
assert(reloadA.SetViewProfile("pve"))
assert(#reloadA.GetDisplayModel().arms == 2, "returning from PvP lost saved evidence")
assert(not a.SetViewProfile("invalid"), "invalid view preference accepted")
expect(2, 1, "normal view restored")

-- Explicit PvP instances never change the chosen inspection tab.
env.instanceType = "pvp"
expect(2, 1, "normal inspection inside battleground")
env.currentFight = fight()
assert(a.GetCandidateBias({id=772,tag="dot"}) == 0, "PvE correction used in PvP")
local eligibleBefore = store.totalEligible
a.LearnFight(env.currentFight)
assert(store.totalEligible == eligibleBefore, "PvP accepted with an incorrect eligibility flag")
env.instanceType = "none"

-- Confirmed PvP must invalidate even an already-cached PvE lookup.
env.currentFight = fight()
assert(a.GetCandidateBias({id=772,tag="dot"}) == -1)
env.currentFight.tuning.context.pvp = true
env.currentFight.tuning.context.mode = "pvp"
assert(a.GetCandidateBias({id=772,tag="dot"}) == 0, "cached bias survived a real PvP transition")
env.currentFight = nil

env.rank = 3
expect(0, 0, "actual talent change")
a.PrintStatus()
assert(table.concat(env.output, "\n"):find("Other saved contexts are preserved", 1, true), "new build had no explanation")
env.rank = 2
env.extraSpell = true
expect(0, 0, "actual learned spell change")
env.extraSpell = false
env.groupSize = 2
expect(0, 0, "group context isolation")
env.groupSize = 1
env.level = 16
expect(0, 0, "next five-level band")
env.level = 12
expect(2, 1, "original build restored")
a.SetEnabled(false)
expect(2, 1, "disabled data remain inspectable")
a.SetEnabled(true)

-- A later completed fight updates the display without requiring notification.
learned.readyAnnounced, learned.adjustmentsAnnounced = true, true
env.output = {}
a.LearnFight(fight())
assert(#env.output == 0, "already announced context was announced again")
local updated = a.GetDisplayModel()
assert(#updated.arms == 2 and updated.fights == 9, "silent learning update hid rows or left stale counters")
local missing = t.ContextSnapshot
t.ContextSnapshot = function() error("API unavailable") end
local unavailable = a.GetDisplayModel()
assert(not unavailable.contextAvailable and #unavailable.arms == 0 and a.Status().activeAdjustments == 0,
    "snapshot failure reused the last learned context")
t.ContextSnapshot = missing

-- Malformed saved action collections must not crash status, inspection or
-- candidate evaluation before a later eligible fight can repair the store.
local savedArms = learned.arms
env.currentFight = fight()
for _, malformed in ipairs({false, true, 17, "invalid"}) do
    learned.arms = malformed
    expect(0, 0, "malformed saved action collection")
    assert(a.GetCandidateBias({id=772,tag="dot"}) == 0, "malformed saved actions affected gameplay")
end
learned.arms = savedArms
env.currentFight = nil

-- Recover exact 1.29.0 keys for a compatible old level, without mixing builds.
env, a, t = runtime()
store = env.HCOB_CharacterDB.adaptive
a.GetDisplayModel() -- initialize the store
store = env.HCOB_CharacterDB.adaptive
local current = snapshot()
local function oldKey(level, rank)
    local parts = {"WARRIOR", level, "tab1=" .. rank, tostring(rank), "tab2=0", "0", "tab3=0", "0"}
    local talentHash = t.HashParts(parts)
    return t.HashParts({"adaptive1", "WARRIOR", 1, "solo", 11, talentHash, current.spellbookSignature})
end
local legacyKey = oldKey(12, 2)
local olderKey = oldKey(11, 2)
local foreignKey = oldKey(12, 3)
local function legacyContext(seen, bias)
    return {class="WARRIOR", specIndex=1, mode="solo", levelBand=11, fights=8, lastSeenAt=seen,
        rewardAverage=0.5, survivalAverage=0.8, readyAnnounced=true, adjustmentsAnnounced=true,
        arms={
            ["772:dot"]={spellId=772, title="Rend", tag="dot", fights=8, bias=bias},
            ["78:dump"]={spellId=78, title="Heroic Strike", tag="dump", fights=8, bias=0},
        }, baselines={}}
end
local retained = legacyContext(100, -1)
store.contexts[legacyKey] = retained
store.contexts[olderKey] = legacyContext(90, -2)
store.contexts[foreignKey] = legacyContext(200, 3)
for index=1,21 do store.contexts["unrelated-" .. index] = {lastSeenAt=index} end
store.lastContextKey, store.totalEligible = foreignKey, 24
env.level = 13
expect(2, 0, "legacy same-band recovery")
assert(a.GetDisplayModel().arms[1].bias == 0, "legacy coefficient was promoted without comparative evidence")
assert(store.contexts[legacyKey] == retained, "inspection mutated legacy context")
env.currentFight = fight()
assert(a.GetCandidateBias({id=772,tag="dot"}) == 0, "legacy coefficient applied without comparative evidence")
a.LearnFight(env.currentFight)
assert(store.contexts[store.lastContextKey] == retained and not store.contexts[legacyKey], "legacy evidence was reset instead of re-keyed")
assert(retained.fights == 9 and store.totalEligible == 25, "migration double counted or merged evidence")
assert(retained.readyAnnounced and retained.adjustmentsAnnounced and #env.output == 0, "migration lost notification state")
assert(store.contexts[olderKey] and store.contexts[foreignKey], "unrelated legacy histories deleted")
assert(a.Status().contexts == 24 and store.contexts["unrelated-1"], "migration evicted a context at the store limit")
local _, afterReload = runtime(env.HCOB_CharacterDB)
assert(afterReload.GetDisplayModel().fights == 9, "migrated state did not survive reload")

-- Context stability is shared by every supported class, not Warrior-specific.
for _, class in ipairs({"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","MAGE","WARLOCK","DRUID","SHAMAN"}) do
    env, a, t = runtime()
    env.PLAYER_CLASS = class
    a.LearnFight(fight())
    env.playerTarget, env.level = true, 13
    assert(#a.GetDisplayModel().arms == 2 and a.Status().contextFights == 1, class .. ": target/level hid evidence")
end

print("adaptive context/profile/migration integration: PASS")
