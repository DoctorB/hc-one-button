-- Independent mouse overlay: original Blizzard/ElvUI click scripts are untouched.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)
local Q = HCOB.Systems.BagQuickDelete
local UI = {}
HCOB.UI.BagQuickDelete = UI
local overlay, source, pressed, pressReason
local unavailable = false
local controller = CreateFrame("Frame")

local function modifiers()
    return IsControlKeyDown and IsControlKeyDown() and IsAltKeyDown and IsAltKeyDown()
        and IsShiftKeyDown and not IsShiftKeyDown()
end

-- Restrict discovery to genuine, registered item widgets, not arbitrary frames
-- exposing a bag/slot field. Bank frames and bag-container icons are excluded.
function UI.Resolve(button)
    if not button or not button.GetName or not button.GetParent or not button.GetID then return end
    local name, parent = button:GetName(), button:GetParent()
    if name and name:match("^ContainerFrame%d+Item%d+$") and _G[name] == button and parent and parent.GetName then
        local parentName = parent:GetName()
        if parentName and parentName:match("^ContainerFrame%d+$") and _G[parentName] == parent then
            return parent:GetID(), button:GetID()
        end
    end
    local root = _G.ElvUI_ContainerFrame
    if root and not root.isBank and button.bagFrame == root and root.Bags then
        local bag, slot = button.BagID, button.SlotID
        if type(bag) == "number" and type(slot) == "number" and root.Bags[bag] and root.Bags[bag][slot] == button then
            return bag, slot
        end
    end
end

local function hide()
    source, pressed, pressReason = nil, nil, nil
    if overlay then overlay:Hide() end
end

local function focused()
    if GetMouseFoci then local foci = GetMouseFoci(); return foci and foci[1] end
    if GetMouseFocus then return GetMouseFocus() end
end

local function refresh()
    if not overlay or not modifiers() or Q.HasPending() then hide(); return end
    local target = focused()
    if target == overlay then target = source end
    local bag, slot = UI.Resolve(target)
    if type(bag) ~= "number" or bag < 0 or bag > 4 or type(slot) ~= "number"
        or not target:IsVisible() or not MouseIsOver or not MouseIsOver(target) then hide(); return end
    -- Use screen coordinates, not anchors/parenting to potentially protected bag
    -- widgets. Our overlay can always hide immediately when combat starts.
    local x, y, width, height = target:GetRect()
    if not x or not y or not width or not height or width <= 0 or height <= 0 then hide(); return end
    if source ~= target then pressed, pressReason = nil, nil end
    source = target
    local ratio = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
    overlay:ClearAllPoints()
    overlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x * ratio, y * ratio)
    overlay:SetSize(width * ratio, height * ratio)
    overlay:SetFrameStrata(target:GetFrameStrata())
    overlay:SetFrameLevel(target:GetFrameLevel() + 10)
    overlay:Show()
end

local function disableForSession()
    hide()
    Q.Cancel()
    controller:SetScript("OnUpdate", nil)
    if not unavailable then Q.Report("bag mouse integration is unavailable on this UI; disabled for this session.") end
    unavailable = true
end

local function safeRefresh()
    if not pcall(refresh) then disableForSession() end
end

local function createOverlay()
    if overlay then return true end
    local button = CreateFrame("Button", nil, UIParent)
    button:Hide()
    if not button.SetPassThroughButtons then return false end
    -- No replacement or forwarding of secure item-use handlers. Only right-click
    -- is intercepted; every other mouse button reaches the original bag widget.
    button:SetPassThroughButtons("LeftButton", "MiddleButton", "Button4", "Button5")
    button:RegisterForClicks("RightButtonUp")
    local tint = button:CreateTexture(nil, "OVERLAY")
    tint:SetAllPoints()
    tint:SetColorTexture(0.9, 0.08, 0.04, 0.32)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText("DEL")
    button:SetScript("OnMouseDown", function(_, mouse)
        pressed, pressReason = nil, nil
        if mouse ~= "RightButton" or not modifiers() then return end
        local bag, slot = UI.Resolve(source)
        pressed, pressReason = Q.SafeInspect(bag, slot)
    end)
    button:SetScript("OnClick", function(_, mouse)
        local item, reason, target = pressed, pressReason, source
        pressed, pressReason = nil, nil
        if mouse ~= "RightButton" or not modifiers() then return end
        local bag, slot = UI.Resolve(target)
        if not target or not target:IsVisible() or not MouseIsOver(target) then return end
        if item and item.bag == bag and item.slot == slot then Q.Request(item)
        elseif reason then Q.Report(reason) end
        hide()
    end)
    button:SetScript("OnLeave", hide)
    overlay = button
    return true
end

function UI.Sync()
    hide()
    if unavailable then return end
    if HCOB_DB.bagQuickDelete ~= true or not InCombatLockdown or InCombatLockdown()
        or (UnitAffectingCombat and UnitAffectingCombat("player"))
        or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then
        Q.Cancel()
        controller:SetScript("OnUpdate", nil)
        return
    end
    if not modifiers() then controller:SetScript("OnUpdate", nil); return end
    local ok, created = pcall(createOverlay)
    if not ok or not created then disableForSession(); return end
    controller:SetScript("OnUpdate", safeRefresh)
    safeRefresh()
end

controller:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGOUT" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_DEAD" then
        hide(); Q.Cancel(); controller:SetScript("OnUpdate", nil); return
    end
    if event == "BAG_UPDATE" then Q.InventoryChanged() end
    UI.Sync()
end)
for _, event in ipairs({"PLAYER_LOGIN", "MODIFIER_STATE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "BAG_UPDATE", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_LOGOUT"}) do
    controller:RegisterEvent(event)
end
