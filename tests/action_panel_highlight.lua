-- Flat theme helpers and the Action Panel recommendation highlight, driven
-- through the real CoreHUD and ActionPanel chunks with recording widgets.
local e=setmetatable({}, {__index=_G}); e._G=e
e.HCOneButton={Internal=e,Data={},Core={},Classes={},Systems={},UI={ActionPanel={}},Advisor={Engine={}}}
e.PLAYER_CLASS="WARLOCK"
e.HCOB_DB={visible=true,showAdvisor=true,secureActions=true}
local now=10
e.GetTime=function() return now end
e.GetCVar=function() return "1" end
e.InCombatLockdown=function() return false end
e.UnitExists=function() return false end
e.CanAccessValue=function() return true end
e.SafeNumber=function(v,fallback) return tonumber(v) or fallback end
e.wipe=function(t) for k in pairs(t) do t[k]=nil end return t end

local methods={}
local function widget(kind,name,parent)
    return setmetatable({kind=kind,parent=parent,points={},scripts={},attrs={},shown=true,alpha=1}, {__index=methods})
end
-- Unknown widget methods (CamelCase: SetSize, EnableMouse...) are harmless
-- no-ops; fields such as HCOBRectBorder stay nil. The ones under test record.
setmetatable(methods,{__index=function(_,key)
    if type(key)=="string" and key:match("^%u%l") then return function() end end
end})
function methods:CreateTexture(_,layer,_,sublevel) local t=widget("Texture",nil,self); t.layer,t.sublevel=layer,sublevel; return t end
function methods:CreateFontString() return widget("FontString",nil,self) end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
function methods:ClearAllPoints() self.points={} end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetVertexColor(...) self.vertex={...} end
function methods:SetTexCoord(...) self.texCoord={...} end
function methods:SetTexture(v) self.texture=v end
function methods:SetAlpha(v) self.alpha=v end
function methods:SetText(v) self.text=v end
function methods:SetTextColor(...) self.textColor={...} end
function methods:SetScript(k,fn) self.scripts[k]=fn end
function methods:SetAttribute(k,v) self.attrs[k]=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:GetWidth() return 376 end
e.CreateFrame=widget
e.UIParent=widget("Frame")

local function load(path)
    local chunk=assert(loadfile("HCOneButton/"..path)); setfenv(chunk,e); chunk()
end
load("Data/Spells.lua"); e.S=e.HCOneButton.Data.Spells
load("UI/CoreHUD.lua")
load("UI/ActionPanel.lua")
local panel=e.HCOneButton.UI.ActionPanel
local checks=0
local function expect(actual,wanted,label)
    checks=checks+1
    assert(actual==wanted,label..": got "..tostring(actual)..", wanted "..tostring(wanted))
end

-- Icon slot: cropped icon over a flat edge texture drawn first.
local edge,slot,icon=e.HCOB_MakeIconSlot(widget("Button"),1,2)
expect(edge.layer,"BACKGROUND","edge is background")
expect(edge.sublevel,-8,"edge is drawn below the slot fill")
expect(edge.color[1],1,"edge is a white texture tinted by SetVertexColor")
expect(slot.sublevel,0,"slot fill above the edge")
expect(icon.texCoord[1],0.08,"icon is cropped")
expect(e.btn.icon==nil and e.icon.texCoord~=nil,true,"BASE icon is cropped")
expect(e.border.color~=nil,true,"BASE border is a flat tintable frame")

-- Fixed slots for the class, keys printed in short form.
local S=e.S
e.IsKnown=function(id) return id~=S.HEALTH_FUNNEL end
e.IsUsable=function() return true end
e.SpellName=function(id) return "Spell"..tostring(id) end
e.SpellIcon=function() return "icon" end
panel.BuildMacro=function() return "/cast X" end
panel.ApplySlotBindings=function() end
panel.InRange=function() return nil end
panel.GetCooldown=function() return 0,0,true,0 end
panel.Configure()
expect(panel.ShortKey("SHIFT-4"),"S4","shift key")
expect(panel.ShortKey("CTRL-SHIFT-1"),"CS1","ctrl-shift key")
expect(panel.ShortKey("ALT-BUTTON4"),"AM4","mouse button key")
expect(panel.ShortKey(nil),"","no key")
panel.UpdateStates()
local bolt=panel.idToButton[S.SHADOW_BOLT]
local corruption=panel.idToButton[S.CORRUPTION]
local funnel=panel.idToButton[S.HEALTH_FUNNEL]
expect(bolt.keyText.text,"S4","slot 4 shows its default key")
expect(funnel.keyText.text,"","unlearned slot shows no key")
expect(bolt.icon.alpha,1,"no recommendation: full alpha")

-- Recommendation: glow, ring, larger icon, others dimmed, key colored.
panel.Highlight(S.SHADOW_BOLT)
panel.UpdateStates()
expect(panel.recommendedButton,bolt,"recommended button tracked")
expect(bolt.glow.shown,true,"glow shown")
expect(bolt.ring[1].shown,true,"ring shown")
expect(bolt.iconInset,0,"recommended icon covers its frame edge")
expect(corruption.iconInset,2,"other icons keep their inset")
expect(corruption.icon.alpha,0.55,"other slots step back")
expect(bolt.icon.alpha,1,"recommended slot stays bright")
expect(bolt.keyText.textColor[1],1,"recommended key is highlighted")

-- Pulse: flash on a new recommendation, then a steady breathing glow.
panel.frame.scripts.OnUpdate()
local flash=bolt.glow.alpha
now=now+1
panel.frame.scripts.OnUpdate()
expect(flash>=bolt.glow.alpha,true,"new recommendation starts brighter")
expect(bolt.glow.alpha>=0.45 and bolt.glow.alpha<=0.9,true,"steady pulse range")
panel.Highlight(S.SHADOW_BOLT)
expect(bolt.recommendedSince,10,"same recommendation keeps its start")

-- Unlearned or cleared recommendation: nothing highlighted, nothing dimmed.
panel.Highlight(S.HEALTH_FUNNEL)
expect(panel.recommendedButton,nil,"unlearned slot is never highlighted")
expect(funnel.glow.shown,false,"unlearned slot has no glow")
panel.Highlight(nil)
panel.UpdateStates()
expect(bolt.glow.shown,false,"glow cleared")
expect(bolt.ring[1].shown,false,"ring cleared")
expect(bolt.iconInset,2,"icon back to its inset")
expect(corruption.icon.alpha,1,"dimming cleared")
panel.frame.scripts.OnUpdate()
print("Action Panel highlight: "..checks.." checks PASS")
