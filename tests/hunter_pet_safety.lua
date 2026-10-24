local runtime = dofile("tests/helpers/hunter_runtime.lua")()
local S, H, Class, Engine = runtime.S, runtime.H, runtime.Class, runtime.Engine
local checks, failures = 0, {}
local function check(value, message)
    checks = checks + 1
    if not value then failures[#failures+1] = message end
end
local function titled(title)
    runtime.recommend()
    for _, c in ipairs(Engine.lastCandidates or {}) do if c.title == title then return c end end
end
local function resting(s)
    s.inCombat, s.hostile, s.pet = false, false, true
    return s
end

-- Feign Death leaves the pet passive; the next pull must not start that way.
local s = resting(runtime.reset())
s.petMode = "passive"
check(titled("PET PASSIVE") ~= nil, "passive pet is reported out of combat")
s.hostile = true
check(titled("PET PASSIVE") ~= nil, "passive pet is reported while choosing a pull")
s.petMode = "defensive"
check(titled("PET PASSIVE") == nil, "defensive pet is not reported")
s.petMode, s.inCombat = "passive", true
check(titled("PET PASSIVE") == nil, "passive warning stays out of combat")

-- A dead pet stays a Revive Pet case even after its unit disappears.
s = resting(runtime.reset())
s.known[S.REVIVE_PET], s.known[S.CALL_PET] = true, true
s.petDead = true
check(runtime.recommend() == S.REVIVE_PET, "dead pet asks for Revive Pet")
s.pet, s.petDead = false, false
check(runtime.candidate(S.REVIVE_PET) ~= nil, "vanished dead pet still asks for Revive Pet")
check(runtime.candidate(S.CALL_PET) == nil, "vanished dead pet does not ask for Call Pet")
s.pet = true
runtime.recommend()
s.pet = false
check(runtime.candidate(S.CALL_PET) ~= nil, "dismissed living pet asks for Call Pet")
s.known[S.CALL_PET] = nil
check(runtime.candidate(S.CALL_PET) == nil, "Call Pet requires the learned spell")
s.known[S.CALL_PET], s.inCombat = true, true
check(runtime.candidate(S.CALL_PET) == nil, "Call Pet is not requested in combat")

-- Pet health between pulls, with or without a selected target.
s = resting(runtime.reset())
s.known[S.MEND_PET], s.petHP = true, 50
check(runtime.recommend() == S.MEND_PET, "hurt pet asks for Mend Pet before the next pull")
s.petBuffs[S.MEND_PET] = true
check(runtime.candidate(S.MEND_PET) == nil, "active Mend Pet is not requested again")
s.petBuffs[S.MEND_PET], s.petHP = nil, 80
check(runtime.candidate(S.MEND_PET) == nil, "lightly hurt pet does not cost mana")

-- Pet death in combat: slow the target, or warn when no slow is available.
s = runtime.reset()
s.pet, s.petDead = true, true
s.known[S.CONCUSSIVE_SHOT], s.ranges[S.CONCUSSIVE_SHOT] = true, true
local c = runtime.candidate(S.CONCUSSIVE_SHOT)
check(c and c.title == "PET DEAD: CONCUSSIVE", "dead pet in combat asks for Concussive Shot")
s.debuffs[S.CONCUSSIVE_SHOT] = true
check(titled("PET DEAD") ~= nil, "slowed target without a pet keeps the warning")
s.targetHP = 20
check(titled("PET DEAD") == nil, "nearly dead target does not raise the pet warning")

-- Fleeing target: Concussive first, then a ranged finisher.
s = runtime.reset()
s.known[S.CONCUSSIVE_SHOT], s.ranges[S.CONCUSSIVE_SHOT], s.targetHP = true, true, 18
H.NoteMonsterEmote("%s attempts to run away in fear!", "Defias Thug")
check(H.TargetFleeing(), "English flee emote marks the target")
check(runtime.recommend() == S.CONCUSSIVE_SHOT, "fleeing target is slowed first")
s.debuffs[S.CONCUSSIVE_SHOT] = true
c = runtime.candidate(S.ARCANE_SHOT)
check(c and c.title == "FLEEING: ARCANE", "slowed fleeing target is finished")
s.now = s.now + 9
check(not H.TargetFleeing(), "flee window expires")

s = runtime.reset()
s.targetHP = 20
H.NoteMonsterEmote("%s versucht, voller Angst wegzulaufen!", "Defias Thug")
check(H.TargetFleeing(), "localized emote at low health marks the target")
s = runtime.reset()
s.targetHP = 80
H.NoteMonsterEmote("%s roars!", "Defias Thug")
check(not H.TargetFleeing(), "localized emote at high health is ignored")
H.NoteMonsterEmote("%s attempts to run away in fear!", "Other Mob")
check(not H.TargetFleeing(), "emote from another unit is ignored")
s.targetHP = 18
H.NoteMonsterEmote("%s attempts to run away in fear!", "Defias Thug")
s.guid = "target-b"
check(not H.TargetFleeing(), "flee state does not leak to a new target")

-- Pet off target during chain pulls.
s = runtime.reset()
s.pet, s.petTarget = true, nil
s.now = s.now + 2
check(titled("PET OFF TARGET") ~= nil, "idle pet is sent in with BASE")
s.petTarget = "other"
check(titled("PET OFF TARGET") ~= nil, "pet on another unit is reported")
s.petTarget = "target"
check(titled("PET OFF TARGET") == nil, "pet on the target is fine")
s.petTarget, s.enemies = nil, 2
check(titled("PET OFF TARGET") == nil, "multi-pull leaves pet targeting to the player")
s.enemies, s.autoActive, s.meleeActive = 1, false, false
check(titled("PET OFF TARGET") == nil, "no warning before the Hunter attacks")
s = runtime.reset()
s.pet, s.petTarget = true, nil
check(titled("PET OFF TARGET") == nil, "pet gets time to engage after a target change")

-- Combat aspect before the pull; Hawk once learned, Monkey before that.
s = runtime.reset()
s.inCombat = false
s.known[S.ASPECT_MONKEY] = true
check(runtime.candidate(S.ASPECT_MONKEY) ~= nil, "pre-Hawk levels ask for Monkey")
s.known[S.ASPECT_HAWK] = true
c = runtime.candidate(S.ASPECT_HAWK)
check(c and c.key == "SHIFT", "Hawk is the pre-pull aspect once learned")
check(runtime.candidate(S.ASPECT_MONKEY) == nil, "Monkey is not requested once Hawk is learned")
s.buffs[S.ASPECT_HAWK] = true
check(runtime.candidate(S.ASPECT_HAWK) == nil, "active Hawk is not requested")
s.hostile = false
s.buffs[S.ASPECT_HAWK] = nil
check(runtime.candidate(S.ASPECT_HAWK) == nil, "no pre-pull aspect without a hostile target")

-- Cheetah travel reminder.
s = resting(runtime.reset())
s.known[S.ASPECT_CHEETAH], s.moving = true, true
check(runtime.candidate(S.ASPECT_CHEETAH) == nil, "short movement is not travel")
s.now = s.now + 9
c = runtime.candidate(S.ASPECT_CHEETAH)
check(c and c.displayKind == "idle", "long run on foot suggests Cheetah as a reminder")
runtime.env.HCOB_DB.hunterCheetahReminder = false
check(runtime.candidate(S.ASPECT_CHEETAH) == nil, "Cheetah reminder can be disabled")
runtime.env.HCOB_DB.hunterCheetahReminder = nil
s.buffs[S.ASPECT_CHEETAH] = true
check(runtime.candidate(S.ASPECT_CHEETAH) == nil, "active Cheetah is not requested")
s.buffs[S.ASPECT_CHEETAH], s.hostile = nil, true
check(runtime.candidate(S.ASPECT_CHEETAH) == nil, "hostile target replaces the travel reminder")
s.hostile, s.moving = false, false
check(runtime.candidate(S.ASPECT_CHEETAH) == nil, "stopping resets the travel timer")

for _, message in ipairs(failures) do print("FAIL: " .. message) end
assert(#failures == 0, string.format("hunter_pet_safety: %d/%d failed", #failures, checks))
print(string.format("hunter_pet_safety: %d checks passed", checks))
