-- Real Rogue scorer, spell-name rank resolution, macro builder and engine.
-- API mocks describe client state; no saved combat log is executed as code.
local env = setmetatable({}, {__index=_G})
env._G = env
local function loadInto(path)
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk("HCOneButton")
end
loadInto("HCOneButton/Core/Init.lua")
loadInto("HCOneButton/Data/Spells.lua")
local H, E = env.HCOneButton, env.HCOneButton.Internal
local S = H.Data.Spells
E.S, E.PLAYER_CLASS, E.MACRO_LIMIT = S, "ROGUE", 255
local now, energy, cp, hp, targetHP, reserve, enemies, level, spec
local known, buffs, debuffs, talents, cooldowns, blocked
local grouped, targetOnPlayer, targetPlayer, hostile, combat, guid, dynamics
local classification, enemyLevel, targetCombat
local names = {}
for key, id in pairs(S) do names[id] = key end
names[1752], names[1758] = "Attaque pernicieuse", "Attaque pernicieuse"
names[2098], names[6760] = "Evisceration", "Evisceration"
names[6761] = names[2098]
names[1776], names[1777] = "Suriner", "Suriner"
for _, id in ipairs({13732,13741,14165,14162,1943,2818,6770}) do names[id] = "Localized" .. id end
env.GetTime = function() return now end
env.SafeNumber = function(v, fallback)
    v = tonumber(v)
    if not v or v ~= v or math.abs(v) == math.huge then return fallback end
    return v
end
env.SafeBoolean = function(v) return v == true end
env.SafeString = function(v, fallback) return type(v) == "string" and v or fallback end
env.CanAccessValue = function(v) return v ~= nil end
env.GetSpellInfo = function(id) return names[id], nil, nil, 0 end
env.IsSpellKnown = function(id) return known[id] == true end
env.GetSpellBookItemName = function(index)
    local book = {}
    for id in pairs(known) do book[#book+1] = names[id] end
    table.sort(book)
    return book[index]
end
local talentIDs = {{14165,14162},{13732,13741},{}}
env.GetNumTalents = function(tab) return #talentIDs[tab] end
env.GetTalentInfo = function(tab, index)
    local id = talentIDs[tab][index]
    return names[id], nil, 1, index, talents[id] or 0
end
env.UnitPowerType = function() return 3 end
env.SafeUnitPower = function() return energy end
env.GetComboPoints = function() return cp end
env.UnitHealthPct = function(unit) return unit == "target" and targetHP or hp, true end
env.UnitPowerPct = function() return energy, true end
env.PlayerLevel = function() return level end
env.SafeUnitLevel = function() return enemyLevel or level end
env.SafeUnitClassification = function() return classification end
env.SafeUnitGUID = function() return guid end
env.UnitIsPlayer = function() return targetPlayer end
env.UnitExists = function() return true end
env.HostileLiveTarget = function() return hostile end
env.UnitAffectingCombat = function(unit)
    if unit == "target" then return targetCombat end
    return combat
end
env.CountActiveEnemies = function() return enemies end
env.TalentSpec = function() return spec end
env.HasPlayerBuff = function(id) return buffs[id] ~= nil, buffs[id] or 0 end
env.StablePlayerBuff = env.HasPlayerBuff
env.HasMyTargetDebuff = function(id) return debuffs[id] ~= nil, debuffs[id] or 0 end
env.AuraByName = function(_, name)
    for id, remaining in pairs(debuffs) do if names[id] == name then return true, remaining end end
    return false, 0
end
env.Clamp = function(v, lo, hi) return math.min(hi, math.max(lo, v)) end
env.HasWandEquipped = function() return false end
env.ActiveTargetCast = function() return nil end
env.MultiPullRecommendation = function() return S.EVASION,"MULTI DANGER",nil,nil,"danger" end
env.PanicRecommendation = function() return S.EVASION,"PANIC" end
loadInto("HCOneButton/Core/SpellUtils.lua")
E.CooldownReady = function(id) return not cooldowns[id] end
E.CooldownRemaining = function(id) return cooldowns[id] and 10 or 0 end
loadInto("HCOneButton/Core/Macros.lua")
loadInto("HCOneButton/Advisor/Engine.lua")
loadInto("HCOneButton/Classes/Rogue.lua")
local Rogue, Engine = H.Classes.ROGUE, H.Advisor.Engine
Engine.kindPriority = {idle=0,buff=20,action=40,caution=70,interrupt=90,danger=100}
Engine.SurvivalReserve = function() return reserve, "TEST" end
Engine.RollingDynamics = function() return dynamics end
Engine.TargetIsClose = function() return true end
Engine.PlayerIsGrouped = function() return grouped end
Engine.TargetOnPlayer = function() return targetOnPlayer end
env.FightDynamics = function() return nil end
env.IsUsableSpell = function(name)
    if name == names[S.KICK] then return energy >= 25 and not blocked[S.KICK], energy < 25 end
    for id, spellName in pairs(names) do
        if spellName == name and (id == S.SINISTER_STRIKE or id == S.HEMORRHAGE or id == S.GOUGE
            or id == S.EVISCERATE or id == S.SLICE_DICE) then
            return not blocked[id] and energy >= Rogue:EnergyCost(id), energy < Rogue:EnergyCost(id)
        end
    end
    return true, false
end
local checks = 0
local function expect(actual, expected, why)
    checks = checks + 1
    assert(actual == expected, why .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function learn(id)
    known[id] = true
    E.RebuildKnownSpellNames()
end
local function reset()
    now, energy, cp, hp, targetHP, reserve, enemies, level, spec = 100,100,0,100,80,80,1,15,2
    known,buffs,debuffs,talents,cooldowns,blocked = {},{},{},{},{},{}
    classification,enemyLevel = "normal",nil
    targetCombat = true
    grouped,targetOnPlayer,targetPlayer,hostile,combat,guid,dynamics = false,true,false,true,true,"mob1",nil
    env.GetSpellPowerCost, env.C_Spell = nil, nil
    env.IsCurrentSpell, env.UnitCastingInfo, env.UnitChannelInfo = nil, nil, nil
    env.CanAccessValue = function(v) return v ~= nil end
    Engine.SpellRange = nil
    E.HCOB_DB.hcDangerAdvisor = true
    Rogue:HandleEvent("PLAYER_LOGIN")
    Engine.ResetStabilization()
    learn(1758)
    learn(6760)
end
local function recommend() return Rogue:GetRecommendation(combat,hostile,targetHP,spec) end
local function invest(id, rank)
    talents[id] = rank
    Rogue:HandleEvent("PLAYER_TALENT_UPDATE")
end

reset()
expect(E.IsKnown(S.SINISTER_STRIKE), true, "higher learned rank recognized by localized name")
expect(Rogue:EnergyCost(S.SINISTER_STRIKE),45,"untalented SS cost")
level,energy = 10,42
invest(13732,1)
expect(Rogue:EnergyCost(S.SINISTER_STRIKE),42,"first talent point changes SS cost")
expect(recommend(),S.SINISTER_STRIKE,"level-10 first-point builder is affordable")
invest(13732,2)
energy = 40
expect(Rogue:EnergyCost(S.SINISTER_STRIKE),40,"second point changes cost")
expect(recommend(),S.SINISTER_STRIKE,"two-point affordable builder")
invest(13732,0)
expect(recommend(),nil,"respec clears cached cost")
env.GetSpellPowerCost = function(name)
    expect(name,names[S.SINISTER_STRIKE],"cost lookup uses localized learned name")
    return {{type=3,cost=39}}
end
expect(Rogue:EnergyCost(S.SINISTER_STRIKE),39,"client cost overrides fallback")
env.GetSpellPowerCost = function() error("unavailable API") end
env.C_Spell = {GetSpellPowerCost=function() return {{type=0,cost=999},{type=3,cost=37}} end}
expect(Rogue:EnergyCost(S.SINISTER_STRIKE),37,"modern API fallback selects energy")
env.C_Spell.GetSpellPowerCost = function() return {{type=3,cost=0/0}} end
expect(Rogue:EnergyCost(S.SINISTER_STRIKE),45,"invalid API cost cannot advertise free cast")

reset()
local priorMacro = E.BuildSpellMacro(S.EVISCERATE,"harm")
level = 16
known[6760] = nil
learn(6761)
Rogue:HandleEvent("SPELLS_CHANGED")
expect(E.BuildSpellMacro(S.EVISCERATE,"harm"),priorMacro,"new trainer rank needs no pinned-rank macro")
for _, playerLevel in ipairs({1,9,10,15,16,30,60}) do
    reset()
    level,energy = playerLevel,45
    expect(recommend(),S.SINISTER_STRIKE,"level " .. playerLevel .. " has no artificial endgame gate")
end

reset()
learn(S.SLICE_DICE)
cp = 1
expect(recommend(),S.SINISTER_STRIKE,"unknown TTK does not buy preparation")
dynamics = {confidence=1,ttk=5}
expect(recommend(),S.SINISTER_STRIKE,"short mob does not buy preparation")
dynamics = {confidence=1,ttk=15}
expect(recommend(),S.SINISTER_STRIKE,"nine-second buff below payoff floor")
invest(14165,1)
expect(recommend(),S.SLICE_DICE,"one duration talent point makes small buff worthwhile")
buffs[S.SLICE_DICE] = 1
expect(recommend(),S.SINISTER_STRIKE,"active buff never refreshed early")
buffs[S.SLICE_DICE],energy = nil,60
expect(recommend(),S.SINISTER_STRIKE,"buff must leave energy for a builder")
energy,cp = 100,4
expect(recommend(),S.EVISCERATE,"never consume full finisher CP in preparation")

reset()
learn(S.SLICE_DICE)
cp = 2
expect(recommend(),S.SINISTER_STRIKE,"logger-independent trend starts unknown")
now,targetHP = 102,70
expect(recommend(),S.SLICE_DICE,"measured health trend permits buff with logger off")
expect(Rogue:LevelingTTK(90,nil),nil,"target healing resets fallback trend")
guid = "other"
expect(Rogue:LevelingTTK(70,nil),nil,"other target never inherits trend")
Rogue:HandleEvent("PLAYER_REGEN_ENABLED")
expect(Rogue:LevelingTTK(70,nil),nil,"combat end clears ephemeral trend")

reset()
cp,targetHP = 3,40
expect(recommend(),S.EVISCERATE,"leveling finisher at three CP")
cp,targetHP = 2,28
expect(recommend(),S.EVISCERATE,"leveling finisher at two CP")
cp,targetHP = 1,10
expect(recommend(),S.EVISCERATE,"last-sliver finisher at one CP")
cp,targetHP = 3,47
Engine.ResetStabilization()
expect(recommend(),S.SINISTER_STRIKE,"untalented finisher outside window")
invest(14162,1)
expect(recommend(),S.EVISCERATE,"first Eviscerate point expands finishing window")
classification = "elite"
expect(recommend(),S.SINISTER_STRIKE,"new percentage shortcuts are not applied to elites")
dynamics = {confidence=1,ttk=5}
expect(recommend(),S.EVISCERATE,"credible short remaining lifetime still closes an elite")
classification,dynamics,enemyLevel = "normal",nil,level+3
expect(recommend(),S.SINISTER_STRIKE,"higher-level target needs actual finishing evidence")
enemyLevel,targetPlayer = nil,true
expect(recommend(),S.SINISTER_STRIKE,"normal-mob shortcut is not a PvP assumption")
targetPlayer = false
cp,targetHP,energy = 4,60,34
local id,title = recommend()
expect(id,nil,"pool below finisher cost")
expect(title,"ENERGY FOR EVISCERATE","explicit finisher wait")
energy = 35
expect(recommend(),S.EVISCERATE,"resume immediately when affordable")
cp,targetHP,energy,reserve = 0,10,45,40
expect(recommend(),S.SINISTER_STRIKE,"no dead-zone at low target HP or moderate reserve")
cp,targetHP,energy = 5,60,100
blocked[S.EVISCERATE] = true
expect(select(2,recommend()),"NO USABLE ABILITY","requirements failure is not described as low energy")

reset()
learn(S.HEMORRHAGE)
spec,energy = 1,35
expect(recommend(),S.HEMORRHAGE,"learned talent active is usable outside dominant tree")
expect(Rogue:GetBaseActionInfo(1),S.HEMORRHAGE,"BASE and Advisor agree on mixed-build builder")
learn(S.BLADE_FLURRY)
enemies,energy = 2,100
expect(recommend(),S.BLADE_FLURRY,"learned BF is not gated by dominant tree")
enemies,cooldowns[S.BLADE_FLURRY] = 1,true
learn(S.ADRENALINE_RUSH)
dynamics = {confidence=1,ttk=20}
expect(recommend(),S.ADRENALINE_RUSH,"learned AR is not gated by dominant tree")

reset()
learn(S.GOUGE)
hp,energy,targetHP = 75,50,80
expect(recommend(),S.SINISTER_STRIKE,"no needless healthy control without duration investment")
invest(13741,1)
expect(recommend(),S.GOUGE,"affordable control with one duration talent point")
Engine.SpellRange = function() return false end
expect(recommend(),S.SINISTER_STRIKE,"coarse close estimate cannot override known Gouge range")
Engine.SpellRange = nil
energy = 25
expect(recommend(),nil,"never request 45-energy Gouge with 25 energy")
energy,grouped = 50,true
expect(recommend(),S.SINISTER_STRIKE,"no energy-pause plan in group combat")
grouped,targetOnPlayer = false,false
expect(recommend(),S.SINISTER_STRIKE,"no energy-pause plan when target attacks someone else")
targetOnPlayer,debuffs[1943] = true,8
expect(recommend(),S.SINISTER_STRIKE,"bleed excludes proactive pause")
debuffs[1943],hp = nil,100
expect(recommend(),S.SINISTER_STRIKE,"full-health DPS does not waste time on Gouge")

reset()
learn(S.GOUGE)
energy = 10
Rogue:HandleEvent("UNIT_SPELLCAST_SUCCEEDED","player","cast",1777)
expect(select(2,recommend()),"GOUGE - RECOVER","rank-safe cast-to-aura bridge")
now = 100.21
expect(select(2,recommend()),"ENERGY RECOVERY","missed Gouge cannot cause full-duration hold")
debuffs[S.GOUGE] = 4
expect(select(2,E.Recommend()),"GOUGE - RECOVER","engine holds before trend/multi routing")
Engine.Stabilize(S.SINISTER_STRIKE,"OLD","BASE","", "action")
local holdId, holdTitle, holdKey, holdReason, holdKind = E.Recommend()
expect(Engine.Stabilize(holdId,holdTitle,holdKey,holdReason,holdKind),nil,"hold clears old action immediately")
energy = 80
expect(recommend(),S.SINISTER_STRIKE,"control yields before energy capping")
energy,hp = 10,20
expect(E.Recommend(),S.EVASION,"HP emergency overrides control hold")
hp,enemies = 90,3
expect(E.Recommend(),S.EVASION,"multi danger overrides single-target hold")
enemies,energy = 1,45
debuffs[S.GOUGE] = nil
expect(recommend(),S.SINISTER_STRIKE,"broken aura resumes action without phantom wait")
energy = 10
Rogue:HandleEvent("UNIT_SPELLCAST_SUCCEEDED","player","cast",1776)
guid = "mob2"
expect(select(2,recommend()),"ENERGY RECOVERY","target change invalidates pending hold")
debuffs[S.GOUGE] = 999
expect(select(2,recommend()),"GOUGE - RECOVER","unknown aura expiry has bounded fallback")
now = now + 6
expect(select(2,recommend()),"ENERGY RECOVERY","bad duration cannot hold indefinitely")

reset()
learn(S.KICK)
learn(S.GOUGE)
cooldowns[S.KICK] = true
expect(Rogue:GetInterruptRecommendation(),S.GOUGE,"Gouge interrupts when Kick is on cooldown")
targetOnPlayer = false
expect(Rogue:GetInterruptRecommendation(),nil,"do not assume facing on another player's caster")
targetOnPlayer = true
energy = 10
expect(Rogue:GetInterruptRecommendation(),nil,"no unaffordable fallback interrupt")
energy = 100
cooldowns[S.KICK] = nil
expect(Rogue:GetInterruptRecommendation(),S.KICK,"Kick remains preferred")
learn(S.EVASION)
expect(select(2,Rogue:GetMultiPullRecommendation(2,90,80)),nil,"healthy pair resumes rotation")
expect(Rogue:GetMultiPullRecommendation(3,90,80),S.EVASION,"three-mob escape retained")

reset()
learn(S.GOUGE)
local macro = Rogue:BuildMainMacro()
assert(macro:find(names[1758],1,true) and not macro:find("Rank",1,true),"BASE casts localized highest learned name")
local gougeMacro = Rogue:BuildActionPanelMacro(S.GOUGE)
assert(gougeMacro:find("/stopattack",1,true) and not gougeMacro:find("/startattack",1,true),"Gouge never restarts attacks")
expect(Rogue:BuildModifierMacros().ctrl,gougeMacro,"modifier and fixed slot share control macro")
expect(Rogue:GetRecommendation(false,true,100,2),nil,"no combat maintenance outside combat")

-- Manual restart is a fallback, never a spell or an inferred swing timeout.
reset()
energy = 10
Engine.SpellRange = function() return true end
local attacking = false
env.IsCurrentSpell = function(spellID)
    assert(spellID == S.ATTACK, "restart uses the actual melee auto-attack toggle")
    return attacking
end
local restartId, restartTitle, restartKey, restartReason, restartKind = E.Recommend()
expect(restartId,nil,"manual restart emits no spell to the reader")
expect(restartTitle,"ATTACK STOPPED","stopped auto-attack is visible")
expect(restartKey,"PRESS BASE ONCE","one press, not a loop")
Engine.Stabilize(restartId,restartTitle,restartKey,restartReason,restartKind)
attacking = true
expect(select(2,Engine.Stabilize(E.Recommend())),"ENERGY RECOVERY","withdraw restart immediately after attack resumes")
E.lastAutoAttack = now - 30
expect(select(2,E.Recommend()),"ENERGY RECOVERY","long swing gap is not evidence of stopped attack")
attacking, energy = false,45
expect(E.Recommend(),S.SINISTER_STRIKE,"affordable builder takes precedence over manual restart")
cp,energy = 4,35
expect(E.Recommend(),S.EVISCERATE,"affordable finisher takes precedence over manual restart")
energy = 10
expect(select(3,E.Recommend()),"PRESS BASE ONCE","restart is allowed while pooling finisher energy")
cp = 0
for _, range in ipairs({false,"unknown"}) do
    Engine.SpellRange = function() if range ~= "unknown" then return range end end
    expect(select(2,E.Recommend()),"ENERGY RECOVERY","no restart prompt without confirmed melee range")
end
Engine.SpellRange = function() return true end
buffs[S.STEALTH] = 10
expect(select(2,E.Recommend()),"ENERGY RECOVERY","never invite breaking stealth")
buffs[S.STEALTH],targetCombat = nil,false
expect(select(2,E.Recommend()),"ENERGY RECOVERY","do not invite pulling an unengaged target")
targetCombat = true
local combatAPI = env.UnitAffectingCombat
env.UnitAffectingCombat = nil
expect(Rogue:NeedsAutoAttackRestart(true,true),false,"missing target combat API suppresses restart")
env.UnitAffectingCombat = combatAPI
for _, control in ipairs({S.GOUGE,S.BLIND,6770}) do
    debuffs[control] = 4
    expect(Rogue:NeedsAutoAttackRestart(true,true),false,"breakable control suppresses restart")
    debuffs[control] = nil
end
local ownDebuffAPI = env.HasMyTargetDebuff
env.HasMyTargetDebuff = function() return false end
debuffs[S.GOUGE] = 4
expect(Rogue:NeedsAutoAttackRestart(true,true),false,"another Rogue's control also suppresses restart")
debuffs[S.GOUGE],env.HasMyTargetDebuff = nil,ownDebuffAPI
learn(S.GOUGE)
Rogue:HandleEvent("UNIT_SPELLCAST_SUCCEEDED","player","cast",1777)
expect(select(2,E.Recommend()),"GOUGE - RECOVER","cast-to-aura grace suppresses restart")
now = now + 0.21
expect(select(3,E.Recommend()),"PRESS BASE ONCE","missed or expired Gouge permits manual restart")
env.UnitChannelInfo = function() return "First Aid",nil,nil,now*1000,(now+3)*1000 end
expect(select(3,E.Recommend()),"LET IT FINISH","bandage channel takes precedence over restart")
env.UnitChannelInfo = nil
env.UnitCastingInfo = function() return "Heal",nil,nil,now*1000,(now+3)*1000 end
expect(select(3,E.Recommend()),"LET IT FINISH","active cast takes precedence over restart")
env.UnitCastingInfo = nil
hp = 20
expect(E.Recommend(),S.EVASION,"danger never becomes a restart prompt")
hp,hostile = 100,false
expect(Rogue:NeedsAutoAttackRestart(true,false),false,"no target or dead/friendly target cannot request restart")
hostile,combat = true,false
expect(Rogue:NeedsAutoAttackRestart(false,true),false,"no out-of-combat restart nag")
combat = true
for _, api in ipairs({function() return nil end,function() error("unavailable") end,
    function() return {} end,function() return 0 end}) do
    env.IsCurrentSpell = api
    expect(Rogue:NeedsAutoAttackRestart(true,true),false,"unknown attack state is not stopped")
end
env.IsCurrentSpell = nil
expect(Rogue:NeedsAutoAttackRestart(true,true),false,"missing API suppresses restart")
env.C_Spell = {IsCurrentSpell=function() return false end}
expect(Rogue:NeedsAutoAttackRestart(true,true),true,"modern attack-state API fallback")
env.CanAccessValue = function() return false end
expect(Rogue:NeedsAutoAttackRestart(true,true),false,"unreadable attack state is not stopped")

-- The local learner cannot override a required finishing window.
reset()
loadInto("HCOneButton/Systems/AdaptiveTuner.lua")
H.Systems.AdaptiveTuner.GetCandidateBias = function(c) return c.id == S.SINISTER_STRIKE and 12 or -12 end
cp,targetHP = 3,30
expect(recommend(),S.EVISCERATE,"required finishing window survives adversarial tuning bias")
for _, candidate in ipairs(Engine.lastCandidates) do
    expect(candidate.adaptiveBias,0,"required baseline disables alternative tuning")
end
print("Rogue leveling/talents/control regression: " .. checks .. " checks PASS")
