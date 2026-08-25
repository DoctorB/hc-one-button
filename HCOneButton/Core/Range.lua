-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

function HostileLiveTarget()
    return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
end


function HCOB.Advisor.Engine.TargetIsClose()
    if not HostileLiveTarget() then return false end
    if HCOB.Advisor.Engine.lastMeleeAt and (GetTime() - HCOB.Advisor.Engine.lastMeleeAt) <= 2.5 then return true end
    if CheckInteractDistance then
        local ok, close = pcall(CheckInteractDistance, "target", 3)
        if ok and CanAccessValue(close) then return SafeBoolean(close, false) end
    end
    return false
end

