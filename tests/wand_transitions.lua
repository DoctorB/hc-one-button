-- Real shared wand state, class policies, recommendation/range and display
-- stabilization. Game API fixtures only; no protected action is executed.
local e = setmetatable({}, {__index=_G})
e._G = e
e.HCOneButton = {Internal=e,Core={},Data={},Systems={},UI={},Classes={},Advisor={Engine={
    kindPriority={idle=0,buff=20,action=40,caution=70,interrupt=90,danger=100},
}}}
e.HCOB_DB = {criticalHP=10,dangerHP=20,hcDangerAdvisor=false}
e.MACRO_LIMIT = 255
local now, wand, active, range, ready = 100, true, false, true, true
local hostile, casting, channeling, helpful, heal, proc = true, nil, nil, false, nil, false
local shielded = true
local ctx = {inCombat=true,hostile=true,spec=3,
    player={hp=100,mana=30,level=10,grouped=false},target={hp=20,close=false,onPlayer=false},
    combat={reserve=75,reserveLabel="SAFE"},pet={alive=true,hp=100,tanking=true}}
local names, known = {}, {}
e.GetTime = function() return now end
e.HasWandEquipped = function() return wand end
local queried
e.IsAutoRepeatSpell = function(identifier) queried=identifier; return active end
e.CanAccessValue = function(value) return value ~= "secret" end
e.SafeBoolean = function(value, fallback) if value == nil then return fallback end return value == true or value == 1 end
e.SafeNumber = function(value, fallback) return tonumber(value) or fallback end
e.SafeString = function(value, fallback) return type(value) == "string" and value or fallback end
e.GetSpellInfo = function(id) return names[id] or ("Spell"..tostring(id)), nil, "icon", 1500 end
e.UnitExists = function(unit) return unit ~= "target" or hostile end
e.UnitCanAttack = function() return hostile end
e.UnitIsDead = function() return false end
e.UnitAffectingCombat = function() return ctx.inCombat end
e.UnitHealthPct = function(unit) return unit == "player" and ctx.player.hp or ctx.target.hp, true end
e.UnitPowerType = function() return 0 end
e.UnitPowerPct = function() return ctx.player.mana, true end
e.PlayerLevel = function() return 10 end
e.SafeUnitLevel = function() return 10 end
e.SafeUnitClassification = function() return "normal" end
e.CheckInteractDistance = function() return ctx.target.close end
e.CountActiveEnemies = function() return 1 end
e.ActiveTargetCast = function() return nil end
e.TalentSpec = function() return ctx.spec, "Shadow", 1 end
e.Clamp = function(value, low, high) return math.max(low, math.min(high,value)) end
e.UnitCastingInfo = function() if casting then return names[casting],nil,nil,100000,102000,nil,nil,false,casting end end
e.UnitChannelInfo = function() if channeling then return names[channeling],nil,nil,100000,103000,nil,false,channeling end end
e.IsHelpfulSpell = function() return helpful end
e.HasPlayerBuff = function(id) return proc and (id == e.S.SHADOW_TRANCE or id == e.S.CLEARCASTING) end
e.StablePlayerBuff = function(id) if id == e.S.POWER_WORD_SHIELD then return shielded,100 end return true,100 end
e.HasMyTargetDebuff = function() return true,100 end
local function load(path)
    local chunk = assert(loadfile("HCOneButton/"..path)); setfenv(chunk,e); chunk()
end
load("Data/Spells.lua"); e.S = e.HCOneButton.Data.Spells
load("Core/SpellUtils.lua")
local s = e.S
names[s.SHOOT], names[s.MIND_BLAST], names[s.POWER_WORD_SHIELD] = "Tiro", "Detonazione Mentale", "Parola del Potere: Scudo"
names[s.LESSER_HEAL], names[s.MIND_FLAY], names[s.DRAIN_LIFE] = "Lesser Heal", "Mind Flay", "Drain Life"
names[s.EVOCATION], names[746], names[s.SMITE] = "Evocation", "First Aid", "Smite"
for _, id in ipairs({s.SHOOT,s.MIND_BLAST,s.POWER_WORD_SHIELD,s.SHADOW_WORD_PAIN,s.SMITE,s.FROSTBOLT,s.SHADOW_BOLT}) do known[id]=true end
e.IsKnown = function(id) return known[id] == true end
e.IsUsable = function(id) return known[id] == true end
e.CooldownReady = function() return ready end
e.CooldownRemaining = function() return ready and 0 or 1.4 end
load("Core/Macros.lua"); load("Core/Range.lua"); load("Advisor/Engine.lua")
load("Classes/Priest.lua"); load("Classes/Mage.lua"); load("Classes/Warlock.lua")
local engine = e.HCOneButton.Advisor.Engine
engine.SpellRange = function() return range end
engine.BuildClassContext = function() return ctx end
engine.PlayerHasDebuff = function() return false end
engine.PriestHealSpell = function() return heal end
engine.SurvivalReserve = function() return ctx.combat.reserve, "SAFE" end
engine.RollingDynamics = function() return nil end
engine.TargetOnPlayer = function() return false end
e.PanicRecommendation = function() return s.POWER_WORD_SHIELD,"SHIELD","ALT","Emergency" end
local checks=0
local function expect(actual,wanted,label)
    checks=checks+1
    assert(actual==wanted,label..": got "..tostring(actual)..", wanted "..tostring(wanted))
end
local function render(...)
    return engine.Stabilize(engine.ApplyTargetCastability(...))
end
local function recommend()
    return render(e.Recommend())
end

for _, class in ipairs({"PRIEST","MAGE","WARLOCK"}) do
    e.PLAYER_CLASS=class; active=false; ready=true; range=true; hostile=true
    ctx.player.hp,ctx.player.mana,ctx.target.hp,ctx.target.close,ctx.spec=100,30,20,false,3
    shielded=true; proc=false
    engine.ResetStabilization()
    expect(e.IsWandAutoRepeatActive(),false,class.." initially inactive")
    local id= recommend()
    expect(id,s.SHOOT,class.." requests one start in efficiency window")
    active=true
    e.HandleWandEvent("START_AUTOREPEAT_SPELL")
    now=now+0.01
    local title,key
    id,title,key=recommend()
    expect(id,nil,class.." removes stale Shoot immediately after start")
    expect(title,"WAND ACTIVE",class.." active title")
    expect(key,"LET IT RUN",class.." no repeated input")
    expect(queried,"Tiro",class.." localized auto-repeat query")
    expect(engine.lastBaseline.id,s.SHOOT,class.." efficiency baseline retained")
    expect(engine.lastChosenId,s.SHOOT,class.." scoring choice retained")
    for _, phase in ipairs({false,true,false,true}) do
        ready=phase; now=now+0.12
        id,title= recommend()
        expect(id,nil,class.." no repeated Shoot across cooldown phases")
        expect(title,"WAND ACTIVE",class.." stable active display across cooldown phases")
        expect(engine.RangedActionState(s.SHOOT,true),"active",class.." live BASE state agrees")
    end
    -- No class candidate: active wand is the fallback even for Mage nuke BASE
    -- and Destruction Warlock, without changing their actual BASE macro.
    ctx.player.mana,ctx.target.hp,ctx.target.close=0,90,true
    id,title,key=recommend()
    expect(id,nil,class.." empty candidate fallback has no action")
    expect(title,"WAND ACTIVE",class.." fallback recognizes active wand")
    expect(key,"LET IT RUN",class.." fallback never requests BASE spam")
    range=false
    id,title,key=recommend()
    expect(id,nil,class.." out of range has no action")
    expect(title,"OUT OF RANGE",class.." range wins over active wand")
    expect(key,"MOVE CLOSER",class.." movement hint")
    range=nil
    id,title=recommend()
    expect(title,"RANGE UNKNOWN",class.." updated range state clears the old warning")
    now=now+0.21; id,title=recommend()
    expect(title,"RANGE UNKNOWN",class.." unknown range not claimed ready")
    range=true; hostile=false
    id,title,key=recommend(); now=now+0.21; id,title,key=recommend()
    expect(id,nil,class.." absent target not executable")
    expect(key,"SELECT TARGET",class.." absent target no spam")
    hostile=true; ctx.target.close=false; ctx.player.mana=30; ctx.target.hp=20
    range=true; active=true; recommend(); now=now+0.21; recommend()
    active=false; e.HandleWandEvent("STOP_AUTOREPEAT_SPELL")
    id,title=recommend()
    expect(id,s.SHOOT,class.." stop immediately allows a new start")
    ready=false
    id,title,key=recommend()
    expect(id,nil,class.." cannot request an unready start")
    expect(title,"WAND NOT READY",class.." cooldown start wait")
    expect(key,"WAIT / RECOVER",class.." waiting has no spam instruction")
end

-- Active wand never disables urgent actions, procs or cast-time spells.
e.PLAYER_CLASS="PRIEST"; active=true; ready=true; ctx.player.mana=65; ctx.target.hp=75
ctx.player.hp=100; engine.ResetStabilization()
local id,title= recommend()
expect(id,s.MIND_BLAST,"Mind Blast eligible while wanding")
ctx.player.hp=65; shielded=false; now=now+1
id= recommend(); now=now+0.21; id=recommend()
expect(id,s.POWER_WORD_SHIELD,"Shield wins while wanding")
ctx.player.hp=45; shielded=true; heal=s.LESSER_HEAL; known[heal]=true
engine.ResetStabilization(); id=recommend()
expect(id,heal,"cast-time healing wins while wanding")
ctx.player.hp=9; id=recommend()
expect(id,s.POWER_WORD_SHIELD,"global HP emergency wins immediately")
ctx.player.hp=100; heal=nil; proc=true; ctx.player.mana=30;ctx.target.hp=20
e.PLAYER_CLASS="WARLOCK"; engine.ResetStabilization(); id=recommend()
expect(id,s.SHADOW_BOLT,"Nightfall proc wins over active wand")
e.PLAYER_CLASS="MAGE"; engine.ResetStabilization(); id=recommend()
expect(id,s.FROSTBOLT,"Clearcasting wins over active wand")
proc=false; e.PLAYER_CLASS="PRIEST"
expect(engine.PlayerRecoveryHold(),nil,"auto-repeat is not a global cast hold")
for _, entry in ipairs({{s.MIND_BLAST,false,false},{s.SMITE,false,false},{s.LESSER_HEAL,false,true},
    {s.MIND_FLAY,true,false},{s.DRAIN_LIFE,true,false},{s.EVOCATION,true,true},{746,true,true}}) do
    casting=not entry[2] and entry[1] or nil; channeling=entry[2] and entry[1] or nil; helpful=entry[3]
    local hold=engine.PlayerRecoveryHold()
    expect(hold.spellID,entry[1],"real cast/channel retains identity")
    expect(hold.channel,entry[2],"real cast/channel retains mode")
    expect(hold.recovery and true or false,entry[3],"real healing protection retained")
    id,title=recommend()
    expect(id,nil,"real cast/channel never advertises another action")
    expect(title,entry[3] and "RECOVERY ACTIVE" or (entry[2] and "CHANNEL ACTIVE" or "CAST ACTIVE"),"real cast/channel display retained")
end
casting,channeling,helpful=nil,nil,false
expect(engine.PlayerRecoveryHold(),nil,"cast completion releases hold")

-- API/event fallback: stale starts, reload, equipment, unsupported clients.
local autoAPI=e.IsAutoRepeatSpell
e.IsAutoRepeatSpell=nil
for _, class in ipairs({"PRIEST","MAGE","WARLOCK"}) do
    e.PLAYER_CLASS=class
    e.HandleWandEvent("START_AUTOREPEAT_SPELL")
    expect(e.IsWandAutoRepeatActive(),true,class.." start event fallback")
    e.HandleWandEvent("STOP_AUTOREPEAT_SPELL")
    expect(e.IsWandAutoRepeatActive(),false,class.." stop event fallback")
    for _, event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_DEAD"}) do
        e.HandleWandEvent("START_AUTOREPEAT_SPELL"); e.HandleWandEvent(event)
        expect(e.IsWandAutoRepeatActive(),false,class.." resets on "..event)
    end
    e.HandleWandEvent("START_AUTOREPEAT_SPELL"); e.HandleWandEvent("PLAYER_EQUIPMENT_CHANGED",1)
    expect(e.IsWandAutoRepeatActive(),true,class.." unrelated equipment unaffected")
    e.HandleWandEvent("PLAYER_EQUIPMENT_CHANGED",18)
    expect(e.IsWandAutoRepeatActive(),false,class.." wand slot resets state")
    wand=false; e.HandleWandEvent("START_AUTOREPEAT_SPELL")
    expect(e.IsWandAutoRepeatActive(),false,class.." no wand cannot start fallback")
    wand=true
end
e.PLAYER_CLASS="PRIEST"; e.IsAutoRepeatSpell=autoAPI; active=false
e.HandleWandEvent("START_AUTOREPEAT_SPELL")
expect(e.IsWandAutoRepeatActive(),false,"readable false overrides stale start event")
e.IsAutoRepeatSpell=function(identifier) if type(identifier)=="number" then return true end end
expect(e.IsWandAutoRepeatActive(),true,"numeric query fallback when localized query unavailable")
e.IsAutoRepeatSpell=function() error("unavailable") end
e.HandleWandEvent("STOP_AUTOREPEAT_SPELL")
expect(e.IsWandAutoRepeatActive(),false,"query errors do not create activity")
e.HandleWandEvent("START_AUTOREPEAT_SPELL")
expect(e.IsWandAutoRepeatActive(),true,"query errors permit known event fallback")
e.IsAutoRepeatSpell=function() return "secret" end
e.HandleWandEvent("STOP_AUTOREPEAT_SPELL")
expect(e.IsWandAutoRepeatActive(),false,"inaccessible query never fabricates active state")
e.IsAutoRepeatSpell=autoAPI; active=true
for _, class in ipairs({"HUNTER","WARRIOR","ROGUE","PALADIN","DRUID","SHAMAN"}) do
    e.PLAYER_CLASS=class
    expect(e.IsWandAutoRepeatActive(),false,class.." unaffected by wand logic")
end

-- Native macros stay rankless/localized and never acquire indiscriminate
-- /stopcasting that would cancel heals/casts on repeated player input.
e.PLAYER_CLASS="PRIEST"
expect(e.BuildSpellMacro(s.POWER_WORD_SHIELD,"@player"),"/cast [@player] Parola del Potere: Scudo","localized shield macro preserved")
expect(e.BuildSpellMacro(s.MIND_BLAST,"harm"),"/cast [harm] Detonazione Mentale","rank-safe spell macro preserved")
for _, class in ipairs({"PRIEST","MAGE","WARLOCK"}) do
    e.PLAYER_CLASS=class
    local mod=e.HCOneButton.Classes[class]
    local main=mod:BuildMainMacro()
    expect(main:find("/stopcasting",1,true),nil,class.." no unconditional cast cancellation")
    expect(#main <= 255,true,class.." BASE within native macro size")
    for key, macro in pairs(mod:BuildModifierMacros()) do
        if key ~= "desc" then
            expect(macro:find("/stopcasting",1,true),nil,class.." safe modifier "..key)
            expect(#macro <= 255,true,class.." native modifier size "..key)
        end
    end
end
-- Real BASE visuals must not contradict LET IT RUN, including Mage's nuke
-- BASE and Destruction Warlock. Range warnings still have precedence.
local function visual()
    return {SetTexture=function() end,SetDesaturated=function() end,SetAlpha=function() end,
        SetText=function(self,value) self.text=value end,
        SetVertexColor=function(self,...) self.color={...} end,
        Hide=function(self) self.shown=false end,Show=function(self) self.shown=true end}
end
e.icon,e.label,e.hint,e.reasonText,e.border,e.glow=visual(),visual(),visual(),visual(),visual(),visual()
for _, class in ipairs({"PRIEST","MAGE","WARLOCK"}) do
    e.PLAYER_CLASS=class; active=true; range=true; ready=true
    e.UpdateBaseVisual()
    expect(e.glow.shown,false,class.." active wand BASE has no press glow")
    expect(e.reasonText.text,"Wand active -> let it run",class.." BASE agrees with active wand")
    expect(e.label.text:find("SPAM",1,true),nil,class.." active wand BASE does not request spam")
    range=false; e.UpdateBaseVisual()
    expect(e.reasonText.text,"Out of range -> move closer",class.." BASE keeps actual range warning")
end
-- Exercise the actual registered event handler as well as the state helper.
local frames={}
e.CreateFrame=function()
    local frame={events={},scripts={}}
    function frame:RegisterEvent(event) self.events[event]=true end
    function frame:SetScript(event,fn) self.scripts[event]=fn end
    frames[#frames+1]=frame
    return frame
end
e.SafeRun=function(_,fn,...) fn(...); return true end
e.PLAYER_CLASS="PRIEST"; e.IsAutoRepeatSpell=nil; wand=true
load("Core/Events.lua")
local events=frames[1]
for _, event in ipairs({"START_AUTOREPEAT_SPELL","STOP_AUTOREPEAT_SPELL","PLAYER_DEAD","PLAYER_ENTERING_WORLD"}) do
    expect(events.events[event],true,event.." registered on real dispatcher")
end
events.scripts.OnEvent(events,"START_AUTOREPEAT_SPELL")
expect(e.IsWandAutoRepeatActive(),true,"real start event reaches wand state")
events.scripts.OnEvent(events,"STOP_AUTOREPEAT_SPELL")
expect(e.IsWandAutoRepeatActive(),false,"real stop event reaches wand state")
events.scripts.OnEvent(events,"START_AUTOREPEAT_SPELL")
events.scripts.OnEvent(events,"PLAYER_DEAD")
expect(e.IsWandAutoRepeatActive(),false,"real death event clears wand state")
events.scripts.OnEvent(events,"START_AUTOREPEAT_SPELL")
events.scripts.OnEvent(events,"PLAYER_ENTERING_WORLD")
expect(e.IsWandAutoRepeatActive(),false,"real world transition clears fallback")
print("Wand state and spell transitions regression: "..checks.." checks PASS")
