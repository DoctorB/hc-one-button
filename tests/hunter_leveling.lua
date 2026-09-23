local runtime = dofile("tests/helpers/hunter_runtime.lua")()
local S, H, Class, Engine = runtime.S, runtime.H, runtime.Class, runtime.Engine
local checks, failures = 0, {}
local function check(value, message)
    checks = checks + 1
    if not value then failures[#failures+1] = message end
end
local function melee(s)
    s.ranges[S.AUTO_SHOT], s.ranges[S.ARCANE_SHOT], s.ranges[S.RAPTOR_STRIKE] = false, false, true
end
local s = runtime.reset()
melee(s)
check(runtime.candidate(S.RAPTOR_STRIKE) ~= nil, "level 6 uses Raptor Strike before finisher range")
s.queued = S.RAPTOR_STRIKE
check(runtime.candidate(S.RAPTOR_STRIKE) == nil, "queued Raptor Strike is not requested again")
check(runtime.I.IsQueuedMeleeSwingSpell(S.RAPTOR_STRIKE), "shared queue detector recognizes Raptor")
local macro = Class:BuildActionPanelMacro(S.RAPTOR_STRIKE)
check(macro and macro:find("!RAPTOR_STRIKE", 1, true), "Raptor secure macro cannot cancel its queue")

s = runtime.reset()
s.interact, H.lastMeleeAt = true, s.now
s.ranges[S.AUTO_SHOT], s.ranges[S.ARCANE_SHOT] = false, false
check(not H.TargetIsClose(), "negative melee spell range beats broad interaction/stale hit")
s.ranges = {}
s.interact, H.lastMeleeAt = false, nil
check(not H.CanShootTarget(), "unknown range is not permission to shoot")
check(not H.CanCastRanged(S.ARCANE_SHOT), "unknown range cannot admit an Arcane candidate")
local _, title = Class:GetIdleRecommendation(true, true)
check(title ~= "ATTACK OK", "unknown combat range must not claim attack is OK")
s.ranges[S.AUTO_SHOT] = false
_, title = Class:GetIdleRecommendation(true, true)
check(title ~= "ATTACK OK", "invalid combat range must not claim attack is OK")

s = runtime.reset()
check(runtime.candidate(S.ARCANE_SHOT) ~= nil, "Arcane is usable without a recent Auto Shot")
s.moving, s.targetHP = true, 20
check(runtime.candidate(S.ARCANE_SHOT) ~= nil, "moving Hunter can use an instant ranged finisher")
s.known[S.AIMED_SHOT], s.ranges[S.AIMED_SHOT], s.targetHP = true, true, 80
H.lastAutoShotAt = s.now
check(runtime.candidate(S.AIMED_SHOT) == nil, "do not request Aimed Shot while moving")
s.moving = false
check(runtime.candidate(S.AIMED_SHOT) ~= nil, "stationary Aimed Shot still weaves after Auto Shot")
s.mana = 10
check(runtime.candidate(S.ARCANE_SHOT) == nil, "low mana still conserves Arcane")

s = runtime.reset()
s.autoActive, H.autoRepeatActive = false, true
check(not H.AutoShotActive(), "native auto-repeat false overrides stale event state")
Class:HandleEvent("STOP_AUTOREPEAT_SPELL")
runtime.event("RANGE_DAMAGE", S.AUTO_SHOT)
runtime.env.IsAutoRepeatSpell = nil
check(not H.AutoShotActive(), "late projectile after STOP cannot restart event state")
s.now = s.now + 6
s.moving = true
check(not H.AutoShotNeedsRestart(), "movement should request stopping, not repeated BASE")
s.moving = false
check(H.AutoShotNeedsRestart(), "stationary stopped Auto Shot can be restarted")

s = runtime.reset()
s.known[S.HUNTERS_MARK] = true
s.usable[S.HUNTERS_MARK] = false
s.ranges[S.HUNTERS_MARK] = true
check(runtime.candidate(S.HUNTERS_MARK) == nil, "unusable Mark is not requested")
s.usable[S.HUNTERS_MARK], s.ranges[S.HUNTERS_MARK] = true, false
check(runtime.candidate(S.HUNTERS_MARK) == nil, "out-of-range Mark is not requested")
s.ranges[S.HUNTERS_MARK] = true
check(runtime.candidate(S.HUNTERS_MARK) ~= nil, "usable missing Mark remains available")

s = runtime.reset()
s.spec, s.pet, s.targetOfTarget = 2, true, "pet"
s.known[S.BESTIAL_WRATH], s.known[S.INTIMIDATION] = true, true
check(runtime.candidate(S.BESTIAL_WRATH) ~= nil, "learned Bestial Wrath is not hidden by dominant talent tree")
check(runtime.candidate(S.INTIMIDATION) ~= nil, "learned Intimidation is not hidden by dominant talent tree")
s = runtime.reset()
s.targetOfTarget = "player"
check(H.ThreatSnapshot().state ~= "lost", "pre-pet leveling is not classified as lost pet aggro")

s = runtime.reset()
s.known[S.SERPENT_STING], s.ranges[S.SERPENT_STING] = true, true
runtime.event("SPELL_AURA_APPLIED", S.SERPENT_STING)
check(H.HasSerpentSting(), "confirmed Serpent aura bridges an API delay")
s.now = s.now + 16
check(not H.HasSerpentSting(), "missed aura-removal event cannot suppress Serpent forever")
runtime.event("SPELL_AURA_APPLIED", S.SERPENT_STING)
s.guid = "target-b"
runtime.event("SPELL_CAST_SUCCESS", S.SERPENT_STING)
s.now = s.now + 2
check(not H.HasSerpentSting(), "old target aura cannot leak into new target cast acknowledgement")

-- Secure macro order is a structural contract; the client owns execution.
s = runtime.reset()
macro = Class:BuildMainMacro()
local meleeAt = macro:find("/startattack", 1, true)
local shotAt = macro:find("/cast [harm] !AUTO_SHOT", 1, true)
check(meleeAt and shotAt and meleeAt < shotAt, "BASE must not switch to melee after enabling Auto Shot")
check(not macro:find("/stopattack", 1, true), "BASE must not stop attacks on every recovery press")
check(#macro <= 255, "BASE fits secure macro limit")
for _, level in ipairs({1, 6, 9, 10, 20, 40, 60}) do
    s = runtime.reset()
    s.level = level
    melee(s)
    local id = runtime.recommend()
    check(id == S.RAPTOR_STRIKE, "available melee damage at level " .. level)
    Engine.Stabilize(id, "RAPTOR", "CAST", "test", "action")
    s.queued = S.RAPTOR_STRIKE
    id = Engine.Stabilize(nil, "WAIT", "WAIT", "test", "idle")
    check(id == nil, "queued request clears display immediately at level " .. level)
end
s = runtime.reset()
s.known[S.RAPTOR_STRIKE] = nil
runtime.I.knownSpellNames[runtime.names[S.RAPTOR_STRIKE]] = true
melee(s)
check(runtime.candidate(S.RAPTOR_STRIKE) ~= nil, "higher learned Raptor rank resolves by name")
s.queued = S.RAPTOR_STRIKE
check(runtime.candidate(S.RAPTOR_STRIKE) == nil, "higher rank queue resolves by name")
s = runtime.reset()
s.known[S.MULTI_SHOT], s.ranges[S.MULTI_SHOT], s.moving = true, true, true
H.lastAutoShotAt = s.now
check(runtime.candidate(S.MULTI_SHOT) == nil, "moving single-target Hunter cannot cast Multi-Shot")
check(Class:GetMultiPullRecommendation(2, 100, 80) ~= S.MULTI_SHOT, "multi-pull route also respects movement")
s = runtime.reset()
s.autoActive = false
s.usable[S.AUTO_SHOT] = false
check(not H.AutoShotNeedsRestart(), "unusable Auto Shot does not invite repeated BASE")
s.usable[S.AUTO_SHOT] = true
s.casting = "Aimed Shot"
check(not H.AutoShotNeedsRestart(), "active cast prevents restart hint")
s.casting, s.channeling = nil, "Mend Pet"
check(not H.AutoShotNeedsRestart(), "active channel prevents restart hint")
s = runtime.reset()
runtime.env.IsAutoRepeatSpell = nil
Class:HandleEvent("START_AUTOREPEAT_SPELL")
check(H.AutoShotActive(), "START event fallback works without native query")
Class:HandleEvent("STOP_AUTOREPEAT_SPELL")
check(not H.AutoShotActive(), "STOP event clears fallback")
s = runtime.reset()
s.pet, s.targetOfTarget = true, "player"
check(H.ThreatSnapshot().state == "lost", "real pet aggro loss remains protected")
s.targetOfTarget = "pet"
check(H.ThreatSnapshot().state == "stable", "pet tank state remains recognized")
s = runtime.reset()
runtime.event("SPELL_AURA_APPLIED", S.SERPENT_STING)
s.now = s.now + 14
runtime.event("SPELL_AURA_REFRESH", S.SERPENT_STING)
s.now = s.now + 2
check(H.HasSerpentSting(), "Serpent refresh extends bounded observation")
runtime.event("SPELL_AURA_REMOVED", S.SERPENT_STING)
check(not H.HasSerpentSting(), "actual removal clears immediately")
s.debuffs[S.SERPENT_STING] = true
s.now = s.now + 30
check(H.HasSerpentSting(), "live aura remains authoritative beyond cached expiry")
for _, message in ipairs(failures) do print("FAIL: " .. message) end
assert(#failures == 0, string.format("hunter_leveling: %d/%d failed", #failures, checks))
print(string.format("hunter_leveling: %d checks passed", checks))
