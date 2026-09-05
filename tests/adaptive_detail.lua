local hostGlobal = _G
local environment = setmetatable({}, {__index=hostGlobal})
environment._G = environment
environment.print = function() end
environment.InCombatLockdown = function() return false end

local calls = {}
local windows = {
    OpenChild=function(name, parent) calls[#calls + 1] = {"child", name, parent}; return true end,
    Open=function(name) calls[#calls + 1] = {"open", name}; return true end,
}
environment.HCOneButton = {
    Internal=environment,
    Systems={AdaptiveTuner={}},
    UI={WindowManager=windows},
}

local chunk = assert(loadfile("HCOneButton/UI/AdaptiveTuning.lua"))
setfenv(chunk, environment)
chunk()

local ui = assert(environment.HCOneButton.UI.AdaptiveTuning)
local createActual, refreshActual = ui.Create, ui.Refresh
local model = {arms={
    {title="Zero", bias=0, active=false},
    {title="Positive", bias=1.25, active=true},
    {title="Negative", bias=-0.5, active=true},
}}
assert(#ui.FilterArms(model, false) == 3, "detail view hid calibration rows without a filter")
assert(#ui.FilterArms(model, true) == 2, "detail view active-only filter is incorrect")

local closeText
local fakeFrame = {
    closeButton={SetText=function(_, value) closeText = value end},
    IsShown=function() return false end,
    Show=function() end,
    Raise=function() end,
}
ui.Create = function() return fakeFrame end
ui.Refresh = function() calls[#calls + 1] = {"refresh"} end

assert(ui.Open(true), "detail view did not open from Options")
assert(closeText == "Back to Options", "detail view did not expose parent navigation")
assert(calls[1][1] == "child" and calls[1][2] == "adaptive_tuning" and calls[1][3] == "options",
    "detail view did not use WindowManager.OpenChild with Options parent")

calls = {}
assert(ui.Open(false), "standalone detail view did not open")
assert(closeText == "Close", "standalone detail view kept the parent-navigation label")
assert(calls[1][1] == "open" and calls[1][2] == "adaptive_tuning",
    "standalone detail view did not use WindowManager.Open")

calls = {}
environment.InCombatLockdown = function() return true end
assert(ui.Open(true) == false and #calls == 0, "detail view opened during combat lockdown")

-- Instantiate the real panel with a small frame mock: exercise tab callbacks,
-- periodic refresh, row reuse, scroll isolation and reset confirmation together.
local widgetMethods = {}
local function widget()
    return setmetatable({scripts={}, shown=true, points={}}, {__index=widgetMethods})
end
for _, method in ipairs({"SetFrameStrata","SetClampedToScreen","SetMovable","EnableMouse","RegisterForDrag",
    "StartMoving","StopMovingOrSizing","SetAllPoints","SetTexCoord","SetJustifyH","SetTextColor",
    "SetColorTexture","SetTexture","SetStatusBarTexture","SetStatusBarColor","UpdateScrollChildRect"}) do
    widgetMethods[method] = function() end
end
function widgetMethods:SetSize(w,h) self.width,self.height=w,h end
function widgetMethods:SetWidth(w) self.width=w end
function widgetMethods:SetHeight(h) self.height=h end
function widgetMethods:SetPoint(...) self.points[#self.points + 1]={...} end
function widgetMethods:ClearAllPoints() self.points={} end
function widgetMethods:SetText(text) self.text=text end
function widgetMethods:SetScript(event,callback) self.scripts[event]=callback end
function widgetMethods:RegisterEvent(event) self.event=event end
function widgetMethods:CreateFontString() return widget() end
function widgetMethods:CreateTexture() return widget() end
function widgetMethods:SetChecked(checked) self.checked=checked end
function widgetMethods:GetChecked() return self.checked end
function widgetMethods:Disable() self.disabled=true end
function widgetMethods:Enable() self.disabled=false end
function widgetMethods:SetMinMaxValues(low,high) self.low,self.high=low,high end
function widgetMethods:SetValue(value) self.value=value end
function widgetMethods:SetVerticalScroll(value) self.scroll=value end
function widgetMethods:SetScrollChild(child) self.child=child end
function widgetMethods:IsShown() return self.shown end
function widgetMethods:Show()
    local wasShown=self.shown; self.shown=true
    if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function widgetMethods:Hide()
    local wasShown=self.shown; self.shown=false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
environment.CreateFrame = function(_, _, _, template)
    local frame=widget()
    if template == "BasicFrameTemplateWithInset" then frame.TitleText=widget() end
    if template == "InterfaceOptionsCheckButtonTemplate" then frame.Text=widget() end
    return frame
end
environment.UIParent=widget()
environment.UISpecialFrames={}
environment.InCombatLockdown=function() return false end
local now, selected, resetCount = 0, "pve", 0
environment.GetTime=function() return now end
local normal = {contextKey="warrior-solo", class="WARRIOR", specName="Arms", levelBand=11,mode="solo",
    enabled=true,contextAvailable=true,ready=true,fights=8,learnedActions=2,activeAdjustments=1,
    arms={
        {title="Rend",bias=-1,active=true,spellId=772,fights=4},
        {title="Heroic Strike",bias=0,active=false,spellId=78,fights=4},
    }}
environment.HCOneButton.Systems.AdaptiveTuner = {
    SetViewProfile=function(profile) selected=profile; return true end,
    GetDisplayModel=function()
        if selected == "pve" then normal.viewProfile="pve"; return normal end
        return {viewProfile="pvp",mode="pvp",contextKey="warrior-pvp",enabled=true,
            contextAvailable=true,learningSupported=false,arms={}}
    end,
    Reset=function() resetCount=resetCount + 1; normal.arms={}; return true end,
}
ui.Create, ui.Refresh = createActual, refreshActual
local frame=ui.Create()
frame:Show()
assert(frame.legendText.text:find("Left (-)|r: lower priority",1,true)
    and frame.legendText.text:find("Center (0)|r: unchanged baseline",1,true)
    and frame.legendText.text:find("Right (+)|r: higher priority",1,true)
    and frame.legendText.text:find("not damage %",1,true)
    and frame.legendText.text:find("safety rules remain unchanged",1,true),"tuning legend is missing or misleading")
assert(frame.legendText.points[1][3] == -293 and frame.scroll.points[1][3] <= -348,
    "tuning list did not reserve space for the two-line legend")
assert(frame.rows[1].arm.title == "Rend" and frame.rows[2]:IsShown(), "real panel omitted zero-bias row")
assert(frame.profileButtons.pve.disabled and not frame.profileButtons.pvp.disabled, "selected tab styling incorrect")
frame.scroll:SetVerticalScroll(50)
frame.profileButtons.pvp.scripts.OnClick()
assert(selected == "pvp" and frame.model.learningSupported == false, "PvP tab did not select explicit profile")
assert(frame.stateText.text == "NOT SUPPORTED" and frame.emptyText.text:find("not a gameplay switch",1,true),
    "PvP view implied learning support")
assert(not frame.rows[1]:IsShown() and not frame.rows[2]:IsShown() and frame.scroll.scroll == 0,
    "PvP retained normal rows or scroll")
frame.profileButtons.pve.scripts.OnClick()
assert(frame.rows[1]:IsShown() and frame.rows[2]:IsShown(), "returning to Normal failed to restore rows")
frame:Hide()
frame:Show()
assert(frame.rows[2]:IsShown(), "reopening panel hid baseline action")
normal.fights=9
normal.arms[1].bias=-0.5
frame.scripts.OnUpdate(frame,1)
assert(frame.summaryText.text:find("9/8",1,true) and frame.rows[1].delta.text == "-0.50",
    "visible inspector did not refresh without notification")
frame.activeFilter:SetChecked(true)
frame.activeFilter.scripts.OnClick(frame.activeFilter)
assert(frame.rows[1]:IsShown() and not frame.rows[2]:IsShown(), "active filter failed on real rows")
frame.activeFilter:SetChecked(false)
frame.activeFilter.scripts.OnClick(frame.activeFilter)
assert(frame.rows[2]:IsShown(), "clearing active filter did not restore zero-bias row")
local tuner = environment.HCOneButton.Systems.AdaptiveTuner
local getModel = tuner.GetDisplayModel
tuner.GetDisplayModel=function() error("simulated failure") end
frame.scripts.OnUpdate(frame,1)
assert(frame.model == nil and not frame.rows[1]:IsShown() and frame.stateText.text == "UNAVAILABLE"
    and frame.progress.value == 0, "failed refresh left stale adapted state visible")
tuner.GetDisplayModel=getModel
frame.scripts.OnUpdate(frame,1)
assert(frame.rows[1]:IsShown() and frame.rows[2]:IsShown(), "refresh did not recover from transient error")
normal.impact={evaluated=20,changed=7,executed=4}
normal.arms[2].protected=true
normal.arms[1].situation="single:normal:main"
normal.arms[1].chosenFights,normal.arms[1].otherFights=8,5
ui.Refresh()
assert(frame.rows[2].delta.text=="FIXED" and frame.rows[1].evidence.text=="8 chosen\n5 alternative",
    "inspector hid protection or comparative evidence")
assert(frame.rows[1].meta.text=="1 target / mid resource / >30% HP","situation is not readable")
assert(frame.accountText.text=="Choices changed: 7 / 20\nExecuted: 4\nObserved impact, not DPS gain",
    "impact card is misleading or not confined to its three-line layout")
-- One summary per spell, explicitly expandable details and both ends of the
-- learned range. Returning to another profile must not reuse expanded rows.
normal.spells={{key="spell:772",spellId=772,title="Rend",summary=true,active=true,
    minBias=-2,maxBias=3,state="LEARNED",roleCount=1,situationCount=2,matureCount=2,
    details={normal.arms[1],normal.arms[2]}}}
normal.state="COMPARING"
ui.Refresh()
assert(frame.rows[1].name.text=="[+] Rend" and not frame.rows[2]:IsShown(),"spell summary did not collapse details")
assert(frame.rows[1].delta.text=="VARIES" and frame.rows[1].bar.negative:IsShown() and frame.rows[1].bar.positive:IsShown(),
    "opposing learned situations were concealed by one averaged bar")
assert(frame.stateText.text=="COMPARING","comparison collection displayed as ready")
frame.rows[1].scripts.OnMouseUp(frame.rows[1],"LeftButton")
assert(frame.rows[1].name.text=="[-] Rend" and frame.rows[3]:IsShown(),"spell details failed to expand")
frame.profileButtons.pvp.scripts.OnClick(); frame.profileButtons.pve.scripts.OnClick()
assert(not frame.rows[2]:IsShown() and not frame.rows[3]:IsShown(),"profile change retained old expansion")
normal.spells,normal.state=nil,nil
ui.Refresh()
frame.resetButton.scripts.OnClick(frame.resetButton)
local warning=frame.protectedText.text
now=4
frame.scripts.OnUpdate(frame,1)
assert(frame.protectedText.text == warning and resetCount == 0, "auto refresh dismissed/confirmed armed reset")
now=6
frame.scripts.OnUpdate(frame,1)
assert(not frame.resetArmedUntil and frame.resetButton.text == "Reset Learning" and resetCount == 0,
    "expired reset was left armed")
frame.resetButton.scripts.OnClick(frame.resetButton)
frame.resetButton.scripts.OnClick(frame.resetButton)
assert(resetCount == 1 and not frame.rows[1]:IsShown(), "confirmed reset did not clear displayed rows")
local closed
windows.Close=function(name,restore) closed={name,restore}; frame:Hide() end
frame.scripts.OnEvent(frame,"PLAYER_REGEN_DISABLED")
assert(closed[1] == "adaptive_tuning" and closed[2] == false and not frame:IsShown(),
    "combat entry did not close inspector without restoring Options")

print("adaptive detail view/navigation regression: PASS")
