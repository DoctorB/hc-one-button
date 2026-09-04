-- Exercise the real shared API guards, threat reader and DPS/Advisor widgets.
local env = setmetatable({}, {__index=_G})
env._G = env
env.HCOneButton = {Internal=env, UI={}, Systems={}}
env.HCOB_DB = {visible=true,showDPSMeter=true,showAdvisor=true,scale=1,actionScale=1,combatLogging=false}
env.GetTime = function() return 20 end
env.InCombatLockdown = function() return false end

local methods = {}
local function widget(kind, parent)
    return setmetatable({kind=kind,parent=parent,points={},scripts={},shown=true}, {__index=methods})
end
for _, name in ipairs({"SetFrameStrata","SetFrameLevel","SetClampedToScreen","SetMovable",
    "RegisterForDrag","RegisterForClicks","SetAllPoints","SetTexture","SetBlendMode","SetAlpha",
    "SetJustifyH","StartMoving","StopMovingOrSizing","SetVertexColor"}) do
    methods[name] = function() end
end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
function methods:ClearAllPoints() self.points={} end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width end
function methods:SetText(v) self.text=v end
function methods:SetTextColor(...) self.color={...} end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetScale(s) self.scale=s end
function methods:SetAttribute(k,v) self[k]=v end
function methods:EnableMouse(v) self.mouse=v end
function methods:SetScript(k,fn) self.scripts[k]=fn end
function methods:HookScript(k,fn) self.scripts[k]=fn end
function methods:CreateTexture() return widget("Texture", self) end
function methods:CreateFontString() return widget("FontString", self) end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
env.UIParent = widget("Frame")
env.CreateFrame = function(kind,name,parent) return widget(kind,parent) end

for _, path in ipairs({"Core/Utils.lua","UI/CoreHUD.lua","UI/ThreatMeter.lua","UI/Advisor.lua"}) do
    local chunk = assert(loadfile("HCOneButton/"..path)); setfenv(chunk,env); chunk()
end
local meter = env.HCOneButton.UI.ThreatMeter
env.diagPixel = widget("Frame")
local units, detail, simple, calls
local function reset()
    units = {target=true, hostile=true, combat=true, player=false, dead=false, pet=false}
    detail, simple, calls = {player={false,0,25,999,12345}}, {}, 0
    env.canaccessvalue = nil
    env.UnitExists = function(unit) return units[unit] end
    env.UnitIsPlayer = function() return units.player end
    env.UnitCanAttack = function() return units.hostile end
    env.UnitIsDeadOrGhost = function() return units.dead end
    env.UnitAffectingCombat = function(unit) return units[unit.."Combat"] or (unit=="player" and units.combat) end
    env.UnitDetailedThreatSituation = function(unit,target)
        assert(target=="target"); calls=calls+1
        return unpack(detail[unit] or {})
    end
    env.UnitThreatSituation = function(unit,target) assert(target=="target"); return simple[unit] end
end
local checks=0
local function expect(state, percent, label)
    local snap=meter.Snapshot()
    assert(snap.state==state and snap.percent==percent and snap.label==label,
        string.format("got %s/%s/%s; wanted %s/%s/%s",snap.state,tostring(snap.percent),snap.label,state,tostring(percent),label))
    checks=checks+1
    return snap
end

reset(); expect("low",25,"LOW") -- raw threat percentage must not be used
detail.player={false,0,0}; expect("low",0,"LOW") -- real zero is not missing
detail.player={false,0,84.9}; expect("low",84.9,"LOW")
detail.player={false,0,85}; expect("high",85,"HIGH")
detail.player={false,1,70}; expect("high",70,"HIGH")
detail.player={true,0,100}; expect("aggro",100,"AGGRO") -- social aggro can have status zero
for _,status in ipairs({2,3}) do
    detail.player={false,status,100}; expect("aggro",100,"AGGRO")
end
detail.player={false,0,120}; expect("high",100,"HIGH") -- bounded bar
detail.player={}; expect("unknown",nil,"NO DATA")
for _,value in ipairs({-1,math.huge,-math.huge,0/0,"invalid"}) do
    detail.player={false,value,value}; expect("unknown",nil,"NO DATA")
end
local restricted={}
detail.player={restricted,restricted,restricted}
env.canaccessvalue=function(value) return value~=restricted end
expect("unknown",nil,"NO DATA")
env.canaccessvalue=function() return false end
expect("idle",nil,"NO TARGET")

reset(); env.UnitDetailedThreatSituation=nil
expect("unknown",nil,"NO DATA")
simple.player=3; expect("aggro",nil,"AGGRO") -- status-only must not invent a percentage
simple.player=1; expect("high",nil,"HIGH")
simple.player=0; expect("low",nil,"LOW")
env.UnitDetailedThreatSituation=function() error("API unavailable") end
expect("low",nil,"LOW")
env.UnitThreatSituation=function() error("API unavailable") end
expect("unknown",nil,"NO DATA")
env.UnitThreatSituation=nil
expect("unknown",nil,"NO DATA")

for _,class in ipairs({"WARRIOR","PALADIN","HUNTER","WARLOCK","PRIEST","MAGE","ROGUE","SHAMAN","DRUID"}) do
    reset(); env.PLAYER_CLASS=class
    expect("low",25,"LOW")
end
for _,class in ipairs({"HUNTER","WARLOCK"}) do
    reset(); env.PLAYER_CLASS=class; units.pet=true; units.combat=false; units.petCombat=true
    detail.player={}; detail.pet={true,3,100}
    assert(expect("unknown",nil,"PET").petTanking) -- pet pulls before owner is in combat
    detail.player={false,0,45}; expect("low",45,"PET")
    detail.player={false,0,90}; expect("high",90,"HIGH / PET")
    detail.player={true,3,100}; expect("aggro",100,"AGGRO") -- player wins conflicting owner reads
end
reset(); units.combat=false; units.targetCombat=true
expect("low",25,"LOW") -- current target fighting party, not yet attacking player
for _,case in ipairs({{"target",false,"NO TARGET"},{"hostile",false,"N/A"},
    {"player",true,"N/A"},{"dead",true,"N/A"},{"combat",false,"IDLE"}}) do
    reset(); units[case[1]]=case[2]
    expect("idle",nil,case[3]); assert(calls==0,"queried threat for an ineligible target")
end
reset(); env.UnitExists=function() error("unavailable") end
expect("idle",nil,"NO TARGET")

-- Real HUD integration: no logger/current fight required for live threat.
reset(); env.UpdateDPSMeter()
assert(meter.row.value.text=="THREAT 25%" and meter.row.status.text=="LOW")
assert(meter.row.fill.shown and meter.row.fill.width==24.5)
assert(env.dpsValue.text=="DPS --")
env.currentFight={startClock=10,damageDone=200,petDamage=100}
env.RecentCharacterDPSAverage=function() return 12,3 end
env.UpdateDPSMeter()
assert(env.dpsValue.text=="DPS 30.0" and env.dpsMeta.text=="AVG3 12.0 | DMG 300 | 10.0s")
assert(meter.row.value.text=="THREAT 25%")
env.currentFight=nil
env.LastCurrentCharacterFight=function() return {dps=9,totalDamage=90,duration=10} end
detail.player={true,3,100}; env.UpdateDPSMeter()
assert(env.dpsValue.text=="LAST 9.0" and meter.row.status.text=="AGGRO")
assert(meter.row.fill.width==98 and meter.row.fill.color[1]==1)
detail.player={}; env.UpdateDPSMeter()
assert(meter.row.value.text=="THREAT --" and not meter.row.fill.shown,"stale percentage remained")
detail.player={false,0,0}; env.UpdateDPSMeter()
assert(meter.row.value.text=="THREAT 0%" and not meter.row.fill.shown)
units.target=false; env.UpdateDPSMeter()
assert(meter.row.status.text=="NO TARGET" and meter.row.value.text=="THREAT --")
units.target=true; units.combat=false; env.UpdateDPSMeter()
assert(meter.row.status.text=="IDLE" and not meter.row.fill.shown)

-- Same persisted toggle, visibility and shared HUD scale; no pixel resize.
env.HCOB_DB.showDPSMeter=false; calls=0; env.UpdateDPSMeter()
assert(not env.dpsMeter.shown and calls==0)
env.HCOB_DB.showDPSMeter=true; env.HCOB_DB.visible=false; env.UpdateDPSMeter()
assert(not env.dpsMeter.shown and calls==0)
env.HCOB_DB.visible=true; env.HCOB_DB.showAdvisor=false; env.RefreshButtonState(); env.UpdateDPSMeter()
assert(env.dpsMeter.shown and not env.advisor.shown)
for _,scale in ipairs({0.7,1,1.6}) do
    env.HCOB_DB.scale=scale; env.ApplyHUDScale()
    assert(env.dpsMeter.scale==scale and env.HCOB_CoreShell.scale==scale)
    assert(meter.row.parent==env.dpsMeter and meter.row.scale==nil,"threat row should inherit scale")
    assert(env.diagPixel.scale==nil)
end
assert(not meter.row.mouse and not env.dpsMeter.mouse,"threat display must not intercept gameplay clicks")

-- Layout in local pixels: DPS row, threat row and shell/action anchor clearance.
assert(env.dpsMeter.width==282 and env.dpsMeter.height==44)
assert(env.dpsValue.points[1][5]==-5 and env.dpsValue.height==14)
local threatTop=env.dpsMeter.height-meter.row.points[1][5]-meter.row.height
assert(threatTop>=5+env.dpsValue.height+4,"threat overlaps DPS text")
assert(env.HCOB_CoreShell.height>=4+env.advisor.height+4+env.dpsMeter.height+4,
    "footer extends below shell into Action Panel")
assert(96<98 and 98+98<266-66,"threat label/bar/status lack clearance")
print(string.format("Threat/DPS meter regression: PASS (%d threat states plus live HUD/layout checks)", checks))
