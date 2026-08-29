-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

-- Passive diagnostic pixel for external read-only tools.
-- RGB protocol v3: the color encodes ONLY the fixed slot.
-- The reader knows neither the class nor the spell.
-- R = slot * 12, G = 96, B = 224.
-- Black = no recommended action; white = unmapped recommendation.
diagPixel = CreateFrame("Frame", "HCOneButtonDiagPixel", UIParent)
diagPixel:SetSize(8, 8)
diagPixel:SetPoint("TOPLEFT", advisor, "TOPRIGHT", 4, 0)
diagPixel:SetFrameStrata("TOOLTIP")
diagPixel:EnableMouse(false)
diagPixelTex = diagPixel:CreateTexture(nil, "OVERLAY")
diagPixelTex:SetAllPoints()
diagPixelTex:SetColorTexture(0, 0, 0, 1)

-- A 50 Hz reader samples every 20 ms. Keep a completed recommendation black
-- for 60 ms so the external process always observes a nil edge before the
-- next recommendation, including when the same spell is recommended again.
local ACK_GAP_SECONDS = 0.060
local desiredSpellID = nil
local suppressionUntil = 0
local acknowledgementToken = 0

local function PixelNow()
    return GetTime and GetTime() or 0
end

local function RenderDiagnosticPixel(spellId)
    if not diagPixelTex then return end
    if not spellId then
        diagPixelTex:SetColorTexture(0, 0, 0, 1)
        return
    end

    local slot = HCOB.UI.ActionPanel.idToSlot[spellId]
    if slot then
        diagPixelTex:SetColorTexture((slot * 12) / 255, 96 / 255, 224 / 255, 1)
    else
        diagPixelTex:SetColorTexture(1, 1, 1, 1)
    end
end

function UpdateDiagnosticPixel(spellId)
    desiredSpellID = spellId
    if PixelNow() < suppressionUntil then
        RenderDiagnosticPixel(nil)
        return
    end
    RenderDiagnosticPixel(spellId)
end

local function SameRecommendedSpell(castSpellID)
    if not desiredSpellID or not castSpellID then return false end
    local wanted = SafeNumber(desiredSpellID, nil)
    local cast = SafeNumber(castSpellID, nil)
    if wanted and cast and wanted == cast then return true end
    if not wanted or not cast or not SpellName then return false end
    local okWanted, wantedName = pcall(SpellName, wanted)
    local okCast, castName = pcall(SpellName, cast)
    return okWanted and okCast and wantedName ~= nil and wantedName == castName
end

local SchedulePixelRelease
SchedulePixelRelease = function(token, delay)
    if not C_Timer or not C_Timer.After then return end
    C_Timer.After(math.max(0.001, delay), function()
        if token ~= acknowledgementToken then return end
        local remaining = suppressionUntil - PixelNow()
        if remaining > 0.001 then
            SchedulePixelRelease(token, remaining)
            return
        end
        RenderDiagnosticPixel(desiredSpellID)
    end)
end

function AcknowledgeDiagnosticPixelCast(castSpellID)
    if not SameRecommendedSpell(castSpellID) then return false end
    acknowledgementToken = acknowledgementToken + 1
    suppressionUntil = PixelNow() + ACK_GAP_SECONDS
    RenderDiagnosticPixel(nil)
    SchedulePixelRelease(acknowledgementToken, ACK_GAP_SECONDS)
    return true
end

