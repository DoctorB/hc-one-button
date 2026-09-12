-- Real Advisor renderer and pixel output: manual restart must be visible,
-- binding-aware and non-executable; waits must never turn into BASE spam.
local env = setmetatable({}, {__index=_G})
env._G = env
env.HCOneButton = {Internal=env, UI={}, Core={}, Advisor={Engine={}}}
env.HCOB_DB = {showAdvisor=true,secureActions=true,visible=true,soundAlerts=true}
env.PLAYER_CLASS = "ROGUE"
local now, sounds = 0, {}
env.GetTime = function() return now end
env.SOUNDKIT = {READY_CHECK=1,RAID_WARNING=2,ALARM_CLOCK_WARNING_3=3}
env.PlaySound = function(kit, channel) sounds[#sounds+1] = {kit=kit,channel=channel} end
env.lastDangerSound, env.lastInterruptSound = 0, 0
env.SafeNumber = function(value, fallback) return tonumber(value) or fallback end

local methods = {}
local function widget(_, _, parent)
    return setmetatable({parent=parent,shown=true,scripts={},points={}}, {__index=methods})
end
for _, name in ipairs({"SetFrameStrata","SetBlendMode","SetJustifyH",
    "SetTextColor","SetTexture","SetVertexColor","SetDesaturated"}) do
    methods[name] = function() end
end
function methods:SetSize(w,h) self.width,self.height = w,h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:SetPoint(...) self.points[#self.points+1] = {...} end
function methods:SetAllPoints(frame) self.allPoints = frame or self.parent end
function methods:SetFrameLevel(level) self.level = level end
function methods:EnableMouse(enabled) self.mouse = enabled end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:SetFont(_, size) self.fontSize = size end
function methods:GetStringWidth() return #(self.text or "") * (self.fontSize or 12) * 0.55 end
function methods:SetScript(event,fn) self.scripts[event] = fn end
function methods:Show() self.shown = true end
function methods:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetText(value) self.text = value end
function methods:SetColorTexture(...) self.color = {...} end
function methods:CreateTexture() return widget() end
function methods:CreateFontString() return widget() end
env.CreateFrame = widget
env.UIParent,env.btn,env.HCOB_CoreShell = widget(),widget(),widget()
env.HCOB_SetRectBorderColor = function() end
env.BaseActionInfo = function() return 1752 end
env.SpellIcon = function() return "icon" end
local binding = "BUTTON4"
env.GetBindingKey = function(action)
    assert(action == "CLICK HCOneButtonFrame:LeftButton")
    return binding
end
local highlight
env.HCOneButton.UI.ActionPanel = {
    idToSlot = {[1752]=1,[16511]=2},
    Has = function(id) return id == 1752 or id == 16511 end,
    Highlight = function(id) highlight = id end,
    UpdateStates = function() end,
}
env.HCOneButton.UI.ThreatMeter = {Init=function() end}
for _, path in ipairs({"Advisor/Engine.lua","UI/Advisor.lua","UI/DiagnosticPixel.lua"}) do
    local chunk = assert(loadfile("HCOneButton/"..path))
    setfenv(chunk,env); chunk()
end

local checks = 0
local function expect(actual, wanted, label)
    checks = checks + 1
    assert(actual == wanted,label .. ": got " .. tostring(actual) .. ", wanted " .. tostring(wanted))
end
local function showRestart(kind)
    env.SetDisplay(nil,"ATTACK STOPPED","PRESS BASE ONCE","Restart once",kind or "action")
end
expect(env.advisorKey.text,"SELECT TARGET","initial Rogue display never asks for spam")
showRestart()
expect(#sounds,1,"first restart sounds immediately, even at session time zero")
expect(sounds[1].kit,env.SOUNDKIT.READY_CHECK,"dedicated restart sound")
expect(sounds[1].channel,"Master","same sound channel as existing alerts")
expect(env.advisorMode.text,"RESUME","dedicated restart badge")
expect(env.advisorTitle.text,"ATTACK STOPPED","visible stopped state")
expect(env.advisorKey.text,"PRESS BUTTON4 ONCE","actual bound button, single press")
expect(highlight,nil,"no executable slot highlighted")
local notice = env.advisor.restartNotice
expect(notice.shown,true,"large human-facing restart cue is visible")
expect(notice.key.text,"PRESS BUTTON4","large instruction names the input")
expect(notice.key.fontSize,26,"instruction uses large outlined text")
expect(notice.footer.text,"ONCE TO RESUME ATTACK","one-press meaning is explicit")
expect(notice.parent,env.advisor,"notice inherits Advisor position, visibility and scale")
expect(notice.allPoints,env.advisor,"notice occupies the whole Advisor, not the diagnostic pixel")
expect(env.advisor.width,282,"unchanged full-size Advisor width")
expect(env.advisor.height,82,"unchanged full-size Advisor height")
expect(notice.mouse,false,"notice cannot intercept combat input")
expect(notice.level > env.advisor.level,true,"notice draws above the small Advisor labels")
expect(env.advisor.alpha,1,"large restart cue is fully opaque")
local titleBottom = -notice.title.points[1][3] + notice.title.height
local keyTop = -notice.key.points[1][3]
local footerTop = env.advisor.height - notice.footer.points[1][3] - notice.footer.height
expect(titleBottom < keyTop,true,"title clears the large instruction")
expect(keyTop + notice.key.height < footerTop,true,"large instruction clears its footer")
expect(notice.key.width <= env.advisor.width - 6,true,"long-key fit stays inside the border")
notice.scripts.OnUpdate(notice,0.7)
expect(math.abs(notice.edge.alpha - 0.56) < 0.001,true,"slow border pulse is visible")
expect(notice.key.alpha,nil,"instruction itself never fades")
-- The display-only base icon must not accidentally emit SS or UNMAPPED white.
local color = env.diagPixelTex.color
expect(color[1] + color[2] + color[3],0,"restart stays black")
binding = "F8"
showRestart()
expect(env.advisorKey.text,"PRESS F8 ONCE","binding change reflected without hardcoded BUTTON4")
expect(notice.key.text,"PRESS F8","large instruction follows binding changes too")
binding = "CTRL-ALT-SHIFT-MOUSEWHEELDOWN"
showRestart()
expect(notice.key:GetStringWidth() <= 258.01,true,"long binding fits inside the notice")
binding = nil
showRestart()
expect(env.advisorKey.text,"CLICK BASE ONCE","unbound button has a usable click hint")
expect(notice.key.text,"CLICK BASE","large unbound instruction is clickable BASE")
expect(notice.key.fontSize,26,"short label regains large size after long binding")
binding = "BUTTON4"
showRestart("caution")
expect(env.advisorMode.text,"HC CAUTION","existing caution styling retained")
expect(env.advisorKey.text,"PRESS BUTTON4 ONCE","caution resolves the one-press binding too")
expect(notice.title.text,"CAUTION - ATTACK STOPPED","large cue preserves caution context")

env.SetDisplay(nil,"GOUGE - RECOVER","LET IT FINISH","Wait for control","caution")
expect(env.advisorKey.text,"LET IT FINISH","Gouge does not invite another key")
expect(notice.shown,false,"Gouge hides the restart notice")
expect(notice.elapsed,0,"hiding resets the pulse")
expect(notice.edge.alpha,1,"next notice starts at full contrast")
env.SetDisplay(nil,"ENERGY RECOVERY","WAIT FOR ENERGY","Wait","idle")
expect(env.advisorMode.text,"ENERGY WAIT","energy state is not falsely AUTO ACTIVE")
expect(env.advisorKey.text,"WAIT FOR ENERGY","energy wait does not render SPAM BUTTON4")
expect(notice.shown,false,"energy wait is not an attention-grabbing restart")
env.SetDisplay(nil,"NO USABLE ABILITY","CHECK TARGET","Check requirements","idle")
expect(env.advisorKey.text,"CHECK TARGET","unusable fallback does not render spam")
showRestart()
env.SetDisplay(1752,"SINISTER STRIKE","BASE","Builder","action")
expect(highlight,1752,"builder still has its executable fixed slot")
expect(notice.shown,false,"normal spell recommendations remain unobscured")
color = env.diagPixelTex.color
expect(color[1],12/255,"SS still emitted at slot one")
expect(color[2],96/255,"unchanged V3 green")
expect(color[3],224/255,"unchanged V3 blue")
env.SetDisplay(16511,"HEMORRHAGE","BASE","Builder","action")
expect(env.diagPixelTex.color[1],24/255,"Hemorrhage still emitted at slot two")

env.PLAYER_CLASS = "HUNTER"
env.SetDisplay(nil,"ATTACK OK","LET IT RUN","Auto active","idle")
expect(env.advisorMode.text,"AUTO ACTIVE","Hunter automatic state unchanged")
expect(env.advisorKey.text,"LET IT RUN","Hunter hold unchanged")
env.SetDisplay(nil,"PULL READY","PRESS BASE","Pull","idle")
expect(env.advisorKey.text,"PRESS BUTTON4","Hunter pull unchanged")
env.PLAYER_CLASS = "WARRIOR"
env.SetDisplay(nil,"BASE OK","KEEP SPAMMING","No priority","idle")
expect(env.advisorKey.text,"SPAM BUTTON4","other classes' explicit BASE mode unchanged")

env.HCOB_DB.showAdvisor = false
showRestart()
expect(env.diagPixelTex.color[1],0,"hidden Advisor still clears pixel for restart")
expect(notice.shown,false,"Advisor OFF cannot leave a stale notice")
env.HCOB_DB.showAdvisor,env.HCOB_DB.visible = true,false
showRestart()
expect(notice.shown,false,"hidden HUD never shows the notice")
env.HCOB_DB.visible = true
showRestart("danger")
expect(notice.shown,false,"notice never covers a danger state")
showRestart("interrupt")
expect(notice.shown,false,"notice never covers an interrupt")
showRestart()
env.SetDisplay(nil,"RECOVERY ACTIVE","LET IT FINISH","Bandage","caution")
expect(notice.shown,false,"recovery immediately clears visible restart notice")
expect(#sounds,1,"refreshes, binding/style changes and rapid re-entry never chatter")

local function clearRestart()
    env.SetDisplay(nil,"ENERGY RECOVERY","WAIT FOR ENERGY","Wait","idle")
end
now = 4.99
showRestart()
expect(#sounds,1,"new stop before five seconds is silent")
now = 5
clearRestart(); showRestart()
expect(#sounds,2,"new stop at five seconds sounds again")
now = 50
showRestart()
expect(#sounds,2,"persistent notice never loops its sound")
env.HCOB_DB.soundAlerts = false
clearRestart(); showRestart()
expect(notice.shown,true,"muting sounds does not hide the visual cue")
expect(#sounds,2,"Alert sounds OFF suppresses restart sound")
env.HCOB_DB.soundAlerts = true
showRestart()
expect(#sounds,2,"enabling sounds does not replay an already-visible notice")
clearRestart(); showRestart()
expect(#sounds,3,"next distinct notice respects re-enabled sounds")
env.PlayAlert("danger")
env.PlayAlert("interrupt")
expect(#sounds,5,"restart throttle does not suppress urgent sound categories")
expect(sounds[4].kit,env.SOUNDKIT.RAID_WARNING,"danger retains its original sound")
expect(sounds[5].kit,env.SOUNDKIT.RAID_WARNING,"interrupt retains its original sound")
env.PlayAlert("danger"); env.PlayAlert("interrupt")
expect(#sounds,5,"urgent sound throttles remain unchanged")
now = 100
env.HCOB_DB.showAdvisor = false
showRestart()
expect(#sounds,5,"hidden Advisor cannot emit a restart cue")
env.HCOB_DB.showAdvisor,env.HCOB_DB.visible = true,false
showRestart()
expect(#sounds,5,"hidden HUD cannot emit a restart cue")
env.HCOB_DB.visible = true
env.SetDisplay(nil,"GOUGE - RECOVER","LET IT FINISH","Control","caution")
env.SetDisplay(nil,"RECOVERY ACTIVE","LET IT FINISH","Bandage","caution")
expect(#sounds,5,"control and recovery have no restart sound")
local soundAPI, soundKits = env.PlaySound, env.SOUNDKIT
env.PlaySound = nil
showRestart()
expect(notice.shown,true,"missing sound API leaves visual restart functional")
env.PlaySound,env.SOUNDKIT = soundAPI,nil
clearRestart(); showRestart()
expect(#sounds,5,"missing sound kit is harmless")
env.SOUNDKIT = {ALARM_CLOCK_WARNING_3=3}
clearRestart(); showRestart()
expect(#sounds,6,"alarm cue is available when READY_CHECK is absent")
expect(sounds[6].kit,3,"restart fallback is not the danger cue")
env.SOUNDKIT = soundKits
now = 105
env.PlaySound = function() error("audio API failure") end
clearRestart(); showRestart()
expect(notice.shown,true,"audio failure cannot disable the HUD")
env.PlaySound = soundAPI
now = 110
clearRestart(); showRestart()
expect(#sounds,7,"sound resumes on a later valid notice after API failure")
local preparation="MH coating missing"
env.PLAYER_CLASS="ROGUE"
env.HCOB_DB.showAdvisor,env.HCOB_DB.visible=true,true
env.HCOneButton.Classes={ROGUE={GetPreparationNotice=function() return preparation end}}
env.SetDisplay(1752,"SPELL","CAST MANUALLY","Original reason","action")
expect(env.advisor.preparationHint.text,"CHECK GEAR","optional equipment badge")
expect(env.advisorReason.text,"Original reason","preparation never replaces action explanation")
expect(highlight,1752,"preparation cannot replace the suggested spell")
expect(env.advisor.preparationHint.width,100,"badge fits unused banner space")
preparation=nil
env.SetDisplay(nil,"STEALTH - POSITION","CHECK OPENER","Check positioning","idle")
expect(env.advisor.preparationHint.text,"","no stale equipment warning")
expect(env.advisorKey.text,"CHECK OPENER","Stealth requirement wait does not request BASE spam")
preparation="MH coating missing"; env.HCOB_DB.showAdvisor=false
env.SetDisplay(nil,"IDLE","CHECK OPENER","","idle")
expect(env.advisor.preparationHint.text,"","hidden Advisor clears equipment badge")
env.HCOB_DB.showAdvisor=true
binding="BUTTON4"
env.SetDisplay(nil,"NO ACTIVE TARGET","SELECT TARGET","No input needed","idle")
expect(env.advisorKey.text,"SELECT TARGET","absent target has no spam instruction")
expect(highlight,nil,"absent target has no highlight")
expect(notice.shown,false,"select target never asks to restart attacks")
env.SetDisplay(nil,"PULL READY","PRESS BASE","","idle")
expect(env.advisorKey.text,"PRESS BUTTON4 ONCE","Rogue pull is one press")
expect(notice.shown,false,"pull is not a false stopped-attack warning")
env.SetDisplay(1752,"Sinister Strike","BASE","","action")
expect(env.advisorKey.text,"PRESS BUTTON4","builder fallback requests manual input, not spam")
env.SetDisplay(nil,"BASE OK","KEEP SPAMMING","","idle")
expect(env.advisorKey.text:find("SPAM"),nil,"legacy fallback cannot display Rogue spam")
env.UnitExists=function() return true end
env.UnitHealthPct=function() return 100,true end
env.UnitPowerType=function() return 3 end
env.SafeUnitPower=function() return 100 end
env.hpText,env.resourceText,env.enemyText=widget(),widget(),widget()
env.swingBG=widget()
env.UpdateStatusBars,env.UpdateBaseVisual,env.UpdateDPSMeter=function() end,function() end,function() end
env.UpdateDisplayMinimal("Smart HUD disabled")
expect(env.advisorTitle.text,"ADVISOR OFF","disabled Advisor is identified")
expect(env.advisorKey.text,"MANUAL CONTROL","disabled Rogue Advisor cannot infer input readiness")
expect(notice.shown,false,"disabled Advisor has no restart alarm")
env.PLAYER_CLASS="WARRIOR"
env.SetDisplay(nil,"BASE OK","KEEP SPAMMING","","idle")
expect(env.advisorKey.text,"SPAM BUTTON4","other class BASE contract unchanged")
-- Wand starts are single inputs; active/wait states are not BASE spam.
env.S={SHOOT=5019}
env.IsWandUser=function() return env.PLAYER_CLASS == "PRIEST" or env.PLAYER_CLASS == "MAGE" or env.PLAYER_CLASS == "WARLOCK" end
env.HasWandEquipped=function() return true end
local panel=env.HCOneButton.UI.ActionPanel
local oldHas=panel.Has
panel.Has=function(id) return id == 5019 or oldHas(id) end
panel.idToSlot[5019]=3
for _, class in ipairs({"PRIEST","MAGE","WARLOCK"}) do
    env.PLAYER_CLASS=class
    env.SetDisplay(5019,"WAND","CAST MANUALLY","Start once","action")
    expect(env.advisorKey.text,"CLICK WAND ONCE",class.." clickable wand start is one press")
    expect(highlight,5019,class.." Shoot is highlighted only for a start")
    env.SetDisplay(nil,"WAND ACTIVE","LET IT RUN","Already active","idle")
    expect(env.advisorKey.text,"LET IT RUN",class.." active wand has no repeated input")
    expect(env.advisorMode.text,"AUTO ACTIVE",class.." active badge")
    expect(highlight,nil,class.." active wand has no executable highlight")
    expect(env.diagPixelTex.color[1],0,class.." active state has no action output")
    expect(notice.shown,false,class.." active wand has no restart overlay")
    env.SetDisplay(nil,"WAND NOT READY","WAIT / RECOVER","Wait","idle")
    expect(env.advisorKey.text,"WAIT / RECOVER",class.." cooldown wait never becomes spam")
    env.SetDisplay(nil,"RANGE UNKNOWN","ADJUST DISTANCE","Unknown","idle")
    expect(env.advisorKey.text,"ADJUST DISTANCE",class.." range wait never becomes spam")
    env.HCOB_DB.secureActions=false
    env.SetDisplay(5019,"WAND","PRESS BASE","Start once","idle")
    expect(env.advisorKey.text,"PRESS BUTTON4 ONCE",class.." BASE wand is one press")
    expect(notice.shown,false,class.." start is not a false stopped-attack alarm")
    env.SetDisplay(5019,"WAND","SHIFT","Start once","action")
    expect(env.advisorKey.text,"SHIFT + BUTTON4 ONCE",class.." modifier wand is one press")
    env.HCOB_DB.secureActions=true
    env.UpdateDisplayMinimal("Smart HUD disabled")
    expect(env.advisorKey.text,"MANUAL CONTROL",class.." disabled smart HUD never requests wand spam")
end
print("Advisor one-press/wait hints regression: " .. checks .. " checks PASS")
