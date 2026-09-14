-- Dedicated secure mouseover bindings: never repurpose self-heal slots.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1,E)
local G=HCOB.Advisor.GroupHealing
local UI={buttons={},spells={}}
HCOB.UI.GroupHealing=UI
_G.BINDING_HEADER_HCOB_GROUP_HEAL="HC One Button - Group healing"
for slot,label in ipairs(G.labels) do
    _G["BINDING_NAME_"..G.BindingCommand(slot)]=label.." (mouseover)"
    local button=CreateFrame("Button","HCOneButtonGroupHeal"..slot,UIParent,"SecureActionButtonTemplate")
    button:SetSize(1,1)
    button:SetPoint("TOPLEFT",UIParent,"TOPLEFT",0,0)
    button:SetAlpha(0)
    button:EnableMouse(false)
    button:RegisterForClicks("LeftButtonUp")
    button:SetAttribute("useOnKeyDown",false)
    button:SetAttribute("type1","macro")
    button:SetAttribute("macrotext1","/stopmacro")
    button:SetScript("PreClick",function(self,mouse,down)
        if mouse=="LeftButton" and not down then G.NoteInput(self.spellID) end
    end)
    UI.buttons[slot]=button
end

function UI.Configure()
    if InCombatLockdown() then UI.pending=true; return false end
    if RebuildKnownSpellNames then RebuildKnownSpellNames() end
    local spells=G.Spells()
    for slot,button in ipairs(UI.buttons) do
        button:SetAttribute("macrotext1",G.Macro(spells[slot]))
        button.spellID=spells[slot]
    end
    UI.spells=spells
    UI.pending=false
    if HCOB.UI.GroupHealingPanel then HCOB.UI.GroupHealingPanel.Configure() end
    return true
end

local frame=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","SPELLS_CHANGED","PLAYER_TALENT_UPDATE","PLAYER_REGEN_ENABLED"}) do
    frame:RegisterEvent(event)
end
frame:SetScript("OnEvent",function() UI.Configure() end)
