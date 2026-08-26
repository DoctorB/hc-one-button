-- HCOneButton managed standalone-window navigation.
-- Only one HCOB dialog is visible at a time. Child dialogs opened from
-- Options replace the Options window and restore it when they close.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

HCOB.UI.WindowManager = HCOB.UI.WindowManager or {}
local W = HCOB.UI.WindowManager

W.windows = W.windows or {}
W.returnTo = W.returnTo or {}
W.suppressHide = W.suppressHide or {}
W.current = W.current or nil

local function CanRestore(name)
    if name == "options" and InCombatLockdown and InCombatLockdown() then
        return false
    end
    return true
end

local function ShowManaged(name)
    local frame = W.windows[name]
    if not frame then return false end
    frame:Show()
    if frame.Raise then frame:Raise() end
    W.current = name
    return true
end

local function HideManaged(name, suppress)
    local frame = W.windows[name]
    if not frame or not frame:IsShown() then return end
    if suppress then W.suppressHide[name] = true end
    frame:Hide()
    if suppress then W.suppressHide[name] = nil end
end

local function RestoreFrom(name)
    if W.suppressHide[name] then return end
    if W.current == name then W.current = nil end

    local back = W.returnTo[name]
    W.returnTo[name] = nil
    if not back or not CanRestore(back) then return end

    -- A close via the BasicFrame X button follows the same navigation path as
    -- the explicit Back/Close button: never reveal a second HCOB dialog below.
    for other, frame in pairs(W.windows) do
        if other ~= back and frame and frame:IsShown() then
            HideManaged(other, true)
        end
    end
    ShowManaged(back)
end

function W.Register(name, frame)
    if not name or not frame then return frame end
    W.windows[name] = frame
    frame.HCOBWindowName = name
    if not frame.HCOBWindowManagerHooked and frame.HookScript then
        frame.HCOBWindowManagerHooked = true
        frame:HookScript("OnHide", function() RestoreFrom(name) end)
    end
    return frame
end

function W.IsShown(name)
    local frame = W.windows[name]
    return frame and frame:IsShown() and true or false
end

function W.Open(name, returnTo)
    local frame = W.windows[name]
    if not frame then return false end

    local back = nil
    if returnTo and W.IsShown(returnTo) then back = returnTo end
    W.returnTo[name] = back

    for other, otherFrame in pairs(W.windows) do
        if other ~= name and otherFrame and otherFrame:IsShown() then
            HideManaged(other, true)
        end
    end
    return ShowManaged(name)
end

function W.OpenChild(name, parentName)
    return W.Open(name, parentName)
end

function W.Close(name, restoreParent)
    local frame = W.windows[name]
    if not frame then return false end

    if restoreParent == false then
        W.returnTo[name] = nil
        W.suppressHide[name] = true
        frame:Hide()
        W.suppressHide[name] = nil
        if W.current == name then W.current = nil end
        return true
    end

    -- Normal Hide triggers RestoreFrom through the registered OnHide hook.
    frame:Hide()
    return true
end

function W.HideAll()
    for name, frame in pairs(W.windows) do
        W.returnTo[name] = nil
        if frame and frame:IsShown() then HideManaged(name, true) end
    end
    W.current = nil
end
