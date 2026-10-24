-- Warrior BASE is a single press. Real Warrior/engine/macro code: BASE starts
-- the attack, the Advisor owns Rend, and a stopped attack asks for one press.
local rt = assert(loadfile("tests/helpers/warrior_runtime.lua"))()()
local e, I, S, W, Engine = rt.env, rt.internal, rt.S, rt.Warrior, rt.Engine
local checks, state = 0, rt.reset()
local function expect(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function reset()
    state = rt.reset()
    -- No funded spell: Rage 0, Shout up, Rend/Clap already on the target.
    state.rage = 0
    e.HostileLiveTarget = function() return true end
    e.UnitAffectingCombat = function() return state.inCombat end
    Engine.PlayerRecoveryHold = function() return nil end
    return state
end
local function recommend()
    local id, title, key, reason, kind = I.Recommend()
    return {id=id, title=title, key=key, reason=reason, kind=kind}
end
local function hasCandidate(id)
    I.Recommend()
    for _, c in ipairs(Engine.lastCandidates or {}) do
        if c.id == id then return true end
    end
    return false
end

-- BASE: start attacking and Charge out of combat; never a Rend sequence.
reset(); e.MACRO_LIMIT = 255
e.InCombatLockdown = function() return false end
local macros = assert(loadfile("HCOneButton/Core/Macros.lua")); setfenv(macros, e); macros()
for _, classification in ipairs({"normal", "elite"}) do
    for _, optionRend in ipairs({true, false}) do
        state.classification, e.HCOB_DB.warriorAutoRend = classification, optionRend
        local main = W:BuildMainMacro()
        expect(main:find("/startattack [harm]", 1, true) ~= nil, true, "BASE starts the attack")
        expect(main:find("/cast [nocombat,harm] CHARGE", 1, true) ~= nil, true, "BASE opens with Charge")
        expect(main:find("castsequence", 1, true), nil, "BASE has no castsequence")
        expect(main:find("REND", 1, true), nil, "BASE never casts Rend")
    end
end
state.inCombat = false
expect(select(2, W:GetBaseActionInfo()), "CHARGE -> AUTO", "pull BASE description")
state.inCombat = true
expect(select(2, W:GetBaseActionInfo()), "AUTO ATTACK", "combat BASE description")
expect(W:GetBaseLabel(), "BASE", "Warrior BASE is not labeled spam")

-- Nothing funded and attacks running: let auto-attack build Rage.
reset()
local r = recommend()
expect(r.id, nil, "idle combat highlights nothing")
expect(r.title, "AUTO ATTACK", "idle combat title")
expect(r.key, "LET IT RUN", "idle combat asks for no input")

-- Client reports auto-attack off against an engaged target in reach.
reset(); state.attacking = false
r = recommend()
expect(r.id, nil, "restart highlights no slot")
expect(r.title, "ATTACK STOPPED", "restart title")
expect(r.key, "PRESS BASE ONCE", "restart asks for one press")
expect(W:NeedsAutoAttackRestart(true, true), true, "stopped engaged target in reach")
state.attacking = nil
expect(W:NeedsAutoAttackRestart(true, true), false, "unreadable attack state is not stopped")
expect(recommend().key, "LET IT RUN", "unknown attack state never nags")
state.attacking = false
expect(W:NeedsAutoAttackRestart(false, true), false, "no restart out of combat")
expect(W:NeedsAutoAttackRestart(true, false), false, "no restart without a hostile target")
state.inRange = nil
expect(W:NeedsAutoAttackRestart(true, true), false, "unknown reach is not a restart request")
state.inRange = false
r = recommend()
expect(r.title, "OUT OF MELEE RANGE", "known out-of-reach target")
expect(r.key, "ADJUST DISTANCE", "out of reach asks to move, not press")
state.inRange = true
e.UnitAffectingCombat = function(unit) return unit == "player" end
expect(W:NeedsAutoAttackRestart(true, true), false, "fresh unengaged mob is not a restart request")
e.UnitAffectingCombat = function() return state.inCombat end
Engine.PlayerRecoveryHold = function() return {channel=true} end
expect(W:NeedsAutoAttackRestart(true, true), false, "cast/channel hold suppresses restart")
Engine.PlayerRecoveryHold = function() return nil end
e.IsCurrentSpell, e.C_Spell = nil, {IsCurrentSpell=function(id) return id == S.ATTACK and false end}
expect(W:NeedsAutoAttackRestart(true, true), true, "modern attack-state API fallback")
e.C_Spell = nil
expect(W:NeedsAutoAttackRestart(true, true), false, "missing API suppresses restart")

-- A funded strike beats the restart hint: melee abilities start attacking.
reset(); state.attacking = false; state.rage = 60
expect(recommend().id, S.HEROIC_STRIKE, "funded Heroic Strike wins over restart")

-- No target in combat: select one instead of pressing BASE.
reset(); e.HostileLiveTarget = function() return false end
r = recommend()
expect(r.title, "NO ACTIVE TARGET", "missing target title")
expect(r.key, "SELECT TARGET", "missing target asks for a target")

-- Execute pooling waits without spam.
reset(); state.known[S.EXECUTE] = true; state.targetHP = 25; state.rage = 30
r = recommend()
expect(r.title, "POOL FOR EXECUTE", "Execute pooling title")
expect(r.key, "LET IT RUN", "Execute pooling asks for no input")

-- Risk warnings still decorate the idle state.
reset(); state.hp = 30
r = recommend()
expect(r.title, "LOW HEALTH", "risk warning replaces the idle title")
expect(r.key, "LET IT RUN", "risk warning keeps the idle input")
expect(r.kind, "danger", "risk warning keeps its color")

-- Rend is an Advisor decision on its slot, governed by the opener option.
reset(); state.rage = 25; state.debuffs[S.REND] = nil
I.currentFight.startClock = state.now
e.HCOB_DB.warriorAutoRend = true
expect(hasCandidate(S.REND), true, "opener Rend suggested by the Advisor")
e.HCOB_DB.warriorAutoRend = nil
expect(hasCandidate(S.REND), true, "opener Rend defaults on")
e.HCOB_DB.warriorAutoRend = false
expect(hasCandidate(S.REND), false, "opener Rend option off removes the suggestion")
e.HCOB_DB.warriorAutoRend = true
state.known[S.MORTAL_STRIKE] = true
expect(hasCandidate(S.REND), true, "learned Mortal Strike no longer hides the Advisor Rend")
state.known[S.MORTAL_STRIKE] = nil
I.currentFight.startClock = state.now - 8
expect(hasCandidate(S.REND), false, "Rend keeps its bounded opener window")

print(string.format("Warrior single-press BASE: %d checks PASS", checks))
