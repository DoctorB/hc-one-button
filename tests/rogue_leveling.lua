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
-- 1.29.6 openers and optional read-only preparation.
loadInto("HCOneButton/Classes/RoguePreparation.lua")
for _, id in ipairs({14079,14057,14082,2842}) do names[id]="Localized"..id end
talentIDs[3]={14079,14057,14082}
local mainWeapon,offWeapon=1,2
local weaponTypes={[1]=15,[2]=7,[3]=15}
env.GetInventoryItemID=function(_,slot) if slot==16 then return mainWeapon else return offWeapon end end
env.GetItemInfoInstant=function(id)
    return id,"Weapon",weaponTypes[id]==15 and "Daggers" or "Swords","INVTYPE_WEAPON",1,2,weaponTypes[id]
end
reset(); combat=false; level=18; buffs[S.STEALTH]=30
learn(S.AMBUSH); learn(S.GARROTE)
expect(recommend(),S.AMBUSH,"dagger burst opener")
mainWeapon=2
expect(recommend(),S.GARROTE,"sword never suggests Ambush")
mainWeapon=nil; offWeapon=3
expect(recommend(),S.GARROTE,"offhand dagger cannot qualify Ambush")
mainWeapon=1; offWeapon=2
enemyLevel=level+1; learn(S.CHEAP_SHOT)
expect(recommend(),S.CHEAP_SHOT,"difficult target retains control opener")
enemyLevel=level
energy=59
expect(recommend(),S.GARROTE,"unaffordable Ambush falls back")
energy=49
local openerID,openerTitle,openerKey=recommend()
expect(openerID,nil,"no unaffordable opener")
expect(openerKey,"CHECK OPENER","Stealth wait never requests BASE spam")
invest(14082,1)
expect(Rogue:EnergyCost(S.GARROTE),40,"first Dirty Deeds point changes Garrote cost")
expect(recommend(),S.GARROTE,"talented Garrote becomes affordable")
invest(14082,2)
expect(Rogue:EnergyCost(S.CHEAP_SHOT),40,"full Dirty Deeds Cheap Shot cost")
energy=100
invest(14079,2); invest(14057,3)
expect(recommend(),S.AMBUSH,"invested opener talents recognized")
expect(Engine.lastCandidates[1].score,91.5,"opener talent ranks inform bounded score")
Engine.SpellRange=function() return false end
expect(recommend(),nil,"known bad opener range suppresses all slots")
Engine.SpellRange=nil
local getItem=env.GetItemInfoInstant
env.GetItemInfoInstant=function() error("uncached item") end
expect(recommend(),S.GARROTE,"unknown equipment never assumes dagger")
env.GetItemInfoInstant=nil
env.C_Item={GetItemInfoInstant=getItem}
expect(recommend(),S.AMBUSH,"modern item API fallback")
env.GetItemInfoInstant=getItem; env.C_Item=nil
local ambushMacro=Rogue:BuildActionPanelMacro(S.AMBUSH)
expect(ambushMacro,"/cast [stealth,harm] "..names[S.AMBUSH],"rank-free secure Ambush")
expect(ambushMacro:find("/startattack",1,true),nil,"opener cannot break Stealth first")
expect(Rogue:BuildActionPanelMacro(S.CHEAP_SHOT):find("[stealth,harm]",1,true)~=nil,true,"Cheap Shot remains stealth-gated")
reset(); energy=100; learn(S.KICK); learn(S.GOUGE)
Engine.SpellRange=function(id) return id~=S.KICK end
expect(Rogue:GetInterruptRecommendation({remaining=2}),S.GOUGE,"known Kick range failure permits valid control fallback")
expect(Rogue:GetInterruptRecommendation({remaining=0.15}),nil,"no late Kick/Gouge")
Engine.SpellRange=function() return true end
expect(Rogue:GetInterruptRecommendation({remaining=2,interruptible=false}),S.GOUGE,"interrupt immunity still permits class control")
cooldowns[S.GOUGE]=true
expect(Rogue:GetInterruptRecommendation({remaining=2,interruptible=false}),nil,"never Kick a known immune cast")
expect(Rogue:GetInterruptRecommendation({remaining=2}),S.KICK,"Era unknown flag preserves viable Kick")

local daggerRank,swordRank,mhEnchant,ohEnchant=65,75,true,true
local mhMS,ohMS=60000,60000
env.GetNumSkillLines=function() return 2 end
env.GetSkillLineInfo=function(i) return i==1 and "Daggers" or "Swords",false,false,i==1 and daggerRank or swordRank,0,0,75 end
env.GetWeaponEnchantInfo=function() return mhEnchant,mhMS,0,1,ohEnchant,ohMS,0,2 end
local function prep() Rogue:InvalidatePreparation("SKILL_LINES_CHANGED"); return Rogue:GetPreparationNotice() end
local function has(text,needle) return text and text:find(needle,1,true)~=nil or false end
reset(); combat=false; mainWeapon=1; offWeapon=2
expect(has(prep(),"Daggers skill 65/75"),true,"two-level weapon deficit is visible")
daggerRank=66
expect(prep(),nil,"small post-level deficit stays quiet")
daggerRank=20; offWeapon=3
expect(select(2,prep():gsub("Daggers","")),1,"same weapon skill is not duplicated")
offWeapon=2; daggerRank=75; level=19
learn(2842); mhEnchant=false; ohEnchant=false
expect(prep(),nil,"no poison nag before level 20")
level=20
expect(has(prep(),"MH coating missing"),true,"main hand missing coating")
expect(has(prep(),"OH coating missing"),true,"off hand missing coating")
mhEnchant=true
expect(has(prep(),"MH coating missing"),false,"valid alternate coating is respected, even with zero charges")
mhMS=0
expect(has(prep(),"MH coating missing"),true,"expired coating reported")
mhMS=60000; mhEnchant=nil; ohEnchant=nil
expect(has(prep(),"OH coating missing"),true,"Classic nil absence convention")
offWeapon=nil
expect(has(prep(),"OH coating missing"),false,"empty off hand is not a missing poison")
local enchantAPI=env.GetWeaponEnchantInfo
env.GetWeaponEnchantInfo=function() error("API unavailable") end
expect(prep(),nil,"failed enchant API is not a missing coating")
env.GetWeaponEnchantInfo=enchantAPI
combat=true
expect(prep(),nil,"preparation disappears in combat")
combat=false; E.HCOB_DB.prePullSafety=false
expect(prep(),nil,"existing preparation preference disables badge")
E.HCOB_DB.prePullSafety=true
env.UnitIsDeadOrGhost=function() return true end
expect(prep(),nil,"no corpse preparation warning")
env.UnitIsDeadOrGhost=nil
known[2842]=nil; E.RebuildKnownSpellNames()
expect(prep(),nil,"unlearned poison skill does not nag")
learn(2842)
expect(has(prep(),"MH coating missing"),true,"learning poison enables advice without reset")
mhEnchant=true
expect(has(Rogue:GetPreparationNotice(),"MH coating missing"),true,"preparation scan is cached within one second")
now=now+1
expect(Rogue:GetPreparationNotice(),nil,"enchant change appears on bounded refresh")
-- Optional opener macros are player input only, never a blocking castsequence.
reset()
for _, id in ipairs({S.AMBUSH,S.GARROTE,S.CHEAP_SHOT,921}) do learn(id) end
names[921] = "Vol a la tire"
for _, id in ipairs({S.AMBUSH,S.GARROTE,S.CHEAP_SHOT}) do
    E.HCOB_DB.roguePickPocket = nil
    local original = Rogue:BuildActionPanelMacro(id)
    expect(has(original,names[921]),false,"Pick Pocket defaults off")
    E.HCOB_DB.roguePickPocket = true
    local macro = Rogue:BuildActionPanelMacro(id)
    expect(macro,"/cast [nocombat,stealth,harm,nodead] " .. names[921] .. "\n" .. original,"localized optional Pick Pocket before opener")
    expect(#macro <= 255,true,"combined macro respects secure limit")
    expect(has(macro,"/castsequence"),false,"no pockets cannot block a sequence")
    expect(has(macro,"/startattack"),false,"no premature auto-attack")
    expect(has(macro,"SetCVar"),false,"no global autoloot changes")
    expect(has(macro,"/stopcasting"),false,"no unnecessary cast interruption")
    E.HCOB_DB.roguePickPocket = false
    expect(Rogue:BuildActionPanelMacro(id),original,"disabling restores the original opener")
    E.HCOB_DB.roguePickPocket = "true"
    expect(Rogue:BuildActionPanelMacro(id),original,"malformed preference cannot opt in")
end
E.HCOB_DB.roguePickPocket = true
known[921]=nil; E.RebuildKnownSpellNames()
expect(has(Rogue:BuildActionPanelMacro(S.AMBUSH),names[921]),false,"unlearned Pick Pocket is not included")
learn(921); known[S.AMBUSH]=nil; E.RebuildKnownSpellNames()
expect(Rogue:BuildActionPanelMacro(S.AMBUSH),"/stopmacro","unlearned opener cannot pick pockets alone")
learn(S.AMBUSH)
names[921]=string.rep("x",250)
expect(has(Rogue:BuildActionPanelMacro(S.AMBUSH),names[921]),false,"oversized optional line never truncates the opener")
expect(has(Rogue:BuildMainMacro(),"/cast [nocombat,stealth,harm,nodead]"),false,"BASE is not a Pick Pocket macro")
print("Rogue leveling/talents/control regression: " .. checks .. " checks PASS")
