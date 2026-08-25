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

function UpdateDiagnosticPixel(spellId)
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

