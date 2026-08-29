local now = 100
local timers = {}
local colors = {}

HCOneButton = {
    UI = {ActionPanel = {idToSlot = {[101]=2, [202]=3}}},
}
HCOneButton.Internal = setmetatable({}, {__index=_G})
UIParent = {}
advisor = {}

function GetTime() return now end
function SafeNumber(value, fallback) return tonumber(value) or fallback end
function SpellName(id)
    return ({[101]="Heal", [1101]="Heal", [202]="Smite"})[id]
end

C_Timer = {}
function C_Timer.After(delay, callback)
    timers[#timers + 1] = {delay=delay, callback=callback}
end

function CreateFrame()
    local frame = {}
    function frame:SetSize() end
    function frame:SetPoint() end
    function frame:SetFrameStrata() end
    function frame:EnableMouse() end
    function frame:CreateTexture()
        local texture = {}
        function texture:SetAllPoints() end
        function texture:SetColorTexture(r, g, b, a)
            colors[#colors + 1] = {r, g, b, a}
        end
        return texture
    end
    return frame
end

local function expect(actual, wanted, label)
    assert(actual == wanted, string.format("%s: expected %s, got %s", label, tostring(wanted), tostring(actual)))
end

local function lastColor()
    return colors[#colors]
end

assert(dofile("HCOneButton/UI/DiagnosticPixel.lua") == nil)
local E = HCOneButton.Internal

E.UpdateDiagnosticPixel(101)
expect(lastColor()[1], 24 / 255, "slot color emitted")
expect(E.AcknowledgeDiagnosticPixelCast(999), false, "unrelated cast ignored")
expect(lastColor()[1], 24 / 255, "unrelated cast preserves recommendation")

-- A higher rank with the same localized spell name acknowledges the rank-1
-- deterministic slot used by the Advisor.
expect(E.AcknowledgeDiagnosticPixelCast(1101), true, "rank-safe cast acknowledgement")
expect(lastColor()[1], 0, "acknowledged spell emits black edge")
assert(timers[1] and timers[1].delay >= 0.060, "black edge is too short for a 50 Hz reader")

-- Advisor may already compute the next spell during the gap; it remains black
-- until the timer releases the latest desired recommendation.
E.UpdateDiagnosticPixel(202)
expect(lastColor()[1], 0, "next spell suppressed during acknowledgement gap")
now = now + 0.061
timers[1].callback()
expect(lastColor()[1], 36 / 255, "next spell emitted after black edge")

-- Recommending the same spell again must still create an observable edge.
expect(E.AcknowledgeDiagnosticPixelCast(202), true, "same-spell acknowledgement")
E.UpdateDiagnosticPixel(202)
expect(lastColor()[1], 0, "same spell remains black during gap")
now = now + 0.061
timers[#timers].callback()
expect(lastColor()[1], 36 / 255, "same spell re-emitted after black edge")

print("diagnostic pixel acknowledgement edge regression: PASS")
