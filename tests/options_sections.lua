-- Build the real Options panel for every class. Check class-only grouping,
-- saved-setting callbacks and vertical clearance rather than source strings.
local function runtime(class, saved)
    local env = setmetatable({}, {__index=_G})
    env._G, env.PLAYER_CLASS = env, class
    env.HCOB_DB = saved or {warriorAutoRend=false, warriorSunderBase=false, warriorHeroicRage=48,
        scale=1, dangerHP=35, criticalHP=20, enemyWindow=6}
    env.HCOB_CharacterDB = {adaptive={version=2,enabled=true,contexts={}}}
    env.InCombatLockdown=function() return false end
    env.print=function() end
    env.UpdateDisplay=function() env.updates=(env.updates or 0)+1 end
    env.BuildMacros=function() env.builds=(env.builds or 0)+1 end
    env.RefreshButtonState=function() end
    env.UpdateDPSMeter=function() end
    env.PrintPlan=function() end

    local methods, widgets = {}, {}
    local function widget(kind, parent, name)
        local item=setmetatable({kind=kind,parent=parent,name=name,scripts={},points={},width=0,height=12}, {__index=methods})
        widgets[#widgets+1]=item
        return item
    end
    for _, name in ipairs({"SetFrameStrata","SetClampedToScreen","SetMovable","EnableMouse","RegisterForDrag",
        "StartMoving","StopMovingOrSizing","SetAllPoints","SetColorTexture","SetJustifyH","SetObeyStepOnDrag"}) do
        methods[name]=function() end
    end
    function methods:SetPoint(...) self.points[#self.points+1]={...} end
    function methods:SetSize(w,h) self.width,self.height=w,h end
    function methods:SetWidth(w) self.width=w end
    function methods:SetHeight(h) self.height=h end
    function methods:SetText(text) self.text=text end
    function methods:SetScript(event,fn) self.scripts[event]=fn end
    function methods:SetChecked(v) self.checked=v end
    function methods:GetChecked() return self.checked end
    function methods:SetMinMaxValues(low,high) self.low,self.high=low,high end
    function methods:SetValueStep(step) self.step=step end
    function methods:SetValue(value)
        self.value=value
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,value) end
    end
    function methods:CreateFontString() return widget("FontString",self) end
    function methods:CreateTexture() return widget("Texture",self) end
    function methods:Hide() self.shown=false end
    function methods:Show()
        self.shown=true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    env.UIParent=widget("Frame")
    env.CreateFrame=function(kind,name,parent,template)
        local item=widget(kind,parent,name)
        if template == "BasicFrameTemplateWithInset" then item.TitleText=widget("FontString",item) end
        if template == "InterfaceOptionsCheckButtonTemplate" then
            item:SetSize(26,26)
            item.Text=widget("FontString",item)
        elseif template == "OptionsSliderTemplate" then
            item:SetSize(220,17)
            item.title=widget("FontString",item)
            item.title:SetPoint("BOTTOM",item,"TOP",0,8)
            env[name.."Text"]=item.title
            env[name.."Low"]=widget("FontString",item)
            env[name.."High"]=widget("FontString",item)
        end
        return item
    end
    env.HCOneButton={Internal=env,Systems={},UI={WindowManager={Register=function() end}}}
    for _, path in ipairs({"HCOneButton/Systems/AdaptiveTuner.lua","HCOneButton/UI/Options.lua"}) do
        local chunk=assert(loadfile(path)); setfenv(chunk,env); chunk()
    end
    env.CreateOptionsPanel()
    return env, widgets
end

local function find(widgets,label)
    for _, w in ipairs(widgets) do
        if (w.kind == "Button" and w.text == label) or (w.Text and w.Text.text == label)
            or (w.title and w.title.text == label) then return w end
    end
end

local function rect(widget)
    if widget.name == "HCOneButtonOptionsPanel" then return 0,0,widget.width,widget.height end
    local anchor=assert(widget.points[1],"missing anchor for "..tostring(widget.text or widget.kind))
    local point,relative,relativePoint,dx,dy
    if #anchor == 3 then point,dx,dy=unpack(anchor); relative,relativePoint=widget.parent,point
    else point,relative,relativePoint,dx,dy=unpack(anchor) end
    local x,y,w,h=rect(relative)
    local function offset(p,width,height)
        local ox=p:find("LEFT") and 0 or (p:find("RIGHT") and width or width/2)
        local oy=p:find("TOP") and 0 or (p:find("BOTTOM") and height or height/2)
        return ox,oy
    end
    local rx,ry=offset(relativePoint,w,h)
    local sx,sy=offset(point,widget.width,widget.height)
    return x+rx+(dx or 0)-sx,y+ry-(dy or 0)-sy,widget.width,widget.height
end

local warriorDB
for _, class in ipairs({"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","MAGE","WARLOCK","DRUID","SHAMAN"}) do
    local env,widgets=runtime(class)
    local panel=env.optionsPanel
    assert(panel.width == 700 and panel.height == 760,"Options window grew unexpectedly")
    local rend=find(widgets,"Smart pre-pull Rend")
    local sunder=find(widgets,"Situational Sunder")
    local heroic=find(widgets,"Heroic Strike rage threshold")
    local center,report,bindings=find(widgets,"Center HUD"),find(widgets,"Report a problem..."),find(widgets,"Configure slot bindings...")
    if class == "WARRIOR" then
        local section=assert(panel.warriorSection,"Warrior section missing")
        assert(rend and sunder and heroic and rend.parent == section and sunder.parent == section and heroic.parent == section,
            "Warrior controls are not grouped in one parent")
        assert(not rend.checked and not sunder.checked and heroic.value == 48,"saved Warrior preferences were reset")
        local sx,sy,sw,sh=rect(section)
        for _, control in ipairs({rend,sunder,heroic,heroic.ValueText}) do
            local x,y,w,h=rect(control)
            assert(x>=sx and y>=sy and x+w<=sx+sw and y+h<=sy+sh,"Warrior control/value escapes its section")
        end
        local _,sunderY,_,sunderH=rect(sunder)
        local _,labelY=rect(heroic.title)
        local _,centerY=rect(center)
        assert(labelY>=sunderY+sunderH+4,"Rage slider label overlaps Sunder")
        assert(centerY>=sy+sh+10,"utility buttons overlap Warrior section")
        rend:SetChecked(true); rend.scripts.OnClick(rend)
        sunder:SetChecked(true); sunder.scripts.OnClick(sunder)
        heroic:SetValue(52)
        assert(env.HCOB_DB.warriorAutoRend and env.HCOB_DB.warriorSunderBase and env.HCOB_DB.warriorHeroicRage == 52,
            "moved controls did not persist the original saved keys")
        assert(env.builds == 2 and env.updates>=3,"moved controls lost gameplay refresh callbacks")
        warriorDB=env.HCOB_DB
    else
        assert(not panel.warriorSection and not rend and not sunder and not heroic,class..": Warrior options visible")
        assert(env.HCOB_DB.warriorAutoRend == false and env.HCOB_DB.warriorSunderBase == false
            and env.HCOB_DB.warriorHeroicRage == 48,class..": opening Options changed hidden Warrior values")
        local _,y=rect(center)
        assert(y<400,class..": hidden Warrior section left a large layout gap")
    end
    local logger,meter,tuning,details=find(widgets,"Combat logger"),find(widgets,"DPS / aggro meter"),
        find(widgets,"Local Adaptive Tuning"),find(widgets,"View learned adjustments...")
    local previousBottom=372+12
    for _, control in ipairs({logger,meter,tuning,details}) do
        local x,y,_,h=rect(control)
        assert(x==350 and y>=previousBottom+4,"Combat data/learning controls are scattered or overlapping")
        previousBottom=y+h
    end
    logger:SetChecked(false); logger.scripts.OnClick(logger)
    assert(env.HCOB_DB.combatLogging == false,"moved logger toggle did not persist")
    meter:SetChecked(false); meter.scripts.OnClick(meter)
    assert(env.HCOB_DB.showDPSMeter == false,"DPS/aggro toggle lost the existing saved key")
    tuning:SetChecked(false); tuning.scripts.OnClick(tuning)
    assert(env.HCOB_CharacterDB.adaptive.enabled == false,"moved tuning checkbox lost per-character persistence")
    for _, button in ipairs({report,bindings}) do
        local _,y,_,h=rect(button)
        assert(y+h<=637,"Options CTA overlaps dedicated footer rule at y=647")
    end
    panel:Show()
    assert(not tuning.checked and not logger.checked and not meter.checked,"Options reopening did not refresh moved controls")
end
local _,reloadWidgets=runtime("WARRIOR",warriorDB)
assert(find(reloadWidgets,"Smart pre-pull Rend").checked and find(reloadWidgets,"Situational Sunder").checked
    and find(reloadWidgets,"Heroic Strike rage threshold").value == 52,"Warrior values did not survive reload")

print("Options class sections/layout/persistence regression: PASS")
