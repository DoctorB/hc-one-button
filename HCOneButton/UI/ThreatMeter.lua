-- Read-only, current-target threat display. No rotation/telemetry side effects.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Meter = {}
HCOB.UI.ThreatMeter = Meter

local function flag(api, ...)
    if type(api) ~= "function" then return nil end
    local ok, value = pcall(api, ...)
    if not ok then return nil end
    return SafeBoolean(value, false)
end

local function finite(value)
    value = SafeNumber(value, nil)
    if value and value == value and value > -math.huge and value < math.huge then return value end
end

local function threat(unit)
    local tanking, status, percent
    if type(UnitDetailedThreatSituation) == "function" then
        local ok, tank, state, scaled = pcall(UnitDetailedThreatSituation, unit, "target")
        if ok then
            tanking, status, percent = SafeBoolean(tank, false), finite(state), finite(scaled)
        end
    end
    if status == nil and type(UnitThreatSituation) == "function" then
        local ok, state = pcall(UnitThreatSituation, unit, "target")
        if ok then status = finite(state) end
    end
    if status and (status < 0 or status > 3 or status ~= math.floor(status)) then status = nil end
    if percent and percent < 0 then percent = nil end
    -- Use scaledPercentage, NOT rawPercentage (110/130% raw can pull aggro).
    if percent then percent = math.min(100, percent) end
    return tanking or (status and status >= 2) or false, status, percent
end

function Meter.Snapshot()
    local out = {state="idle", label="NO TARGET"}
    if flag(UnitExists, "target") ~= true then return out end
    if flag(UnitIsPlayer, "target") ~= false then out.label="N/A"; return out end
    if flag(UnitCanAttack, "player", "target") ~= true then out.label="N/A"; return out end
    if flag(UnitIsDeadOrGhost, "target") ~= false then out.label="N/A"; return out end
    local pet = flag(UnitExists, "pet") == true
    -- A pet can pull before its owner enters combat. Do not hide that state.
    if flag(UnitAffectingCombat, "player") ~= true
        and flag(UnitAffectingCombat, "target") ~= true
        and not (pet and flag(UnitAffectingCombat, "pet") == true) then
        out.label="IDLE"; return out
    end
    local tanking, status, percent = threat("player")
    out.percent = percent
    out.petTanking = pet and threat("pet") or false
    if tanking then
        out.state, out.label = "aggro", "AGGRO"
    elseif (percent and percent >= 85) or status == 1 then
        out.state, out.label = "high", out.petTanking and "HIGH / PET" or "HIGH"
    elseif percent ~= nil or status ~= nil then
        out.state, out.label = "low", out.petTanking and "PET" or "LOW"
    else
        out.state, out.label = "unknown", out.petTanking and "PET" or "NO DATA"
    end
    return out
end

function Meter.Init(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 8, 5)
    row:SetSize(266, 14)
    row:EnableMouse(false)
    Meter.row = row
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.value:SetSize(96, 14)
    row.value:SetJustifyH("LEFT")
    row.value:SetText("THREAT --")
    row.track = row:CreateTexture(nil, "BACKGROUND")
    row.track:SetPoint("LEFT", row, "LEFT", 98, 0)
    row.track:SetSize(98, 6)
    row.track:SetColorTexture(0.12, 0.14, 0.17, 0.95)
    row.fill = row:CreateTexture(nil, "ARTWORK")
    row.fill:SetPoint("LEFT", row.track, "LEFT", 0, 0)
    row.fill:SetSize(1, 6)
    row.fill:Hide()
    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.status:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.status:SetSize(66, 14)
    row.status:SetJustifyH("RIGHT")
    row.status:SetText("NO TARGET")
end

local colors = {
    idle={0.55, 0.60, 0.66}, unknown={0.55, 0.60, 0.66},
    low={0.35, 0.85, 0.72}, high={1.0, 0.74, 0.20}, aggro={1.0, 0.35, 0.28},
}

function Meter.Update()
    if not Meter.row then return end
    local snapshot = Meter.Snapshot()
    local row, color = Meter.row, colors[snapshot.state]
    row.value:SetText(snapshot.percent and ("THREAT " .. math.floor(snapshot.percent) .. "%") or "THREAT --")
    row.status:SetText(snapshot.label)
    row.value:SetTextColor(unpack(color))
    row.status:SetTextColor(unpack(color))
    if snapshot.percent and snapshot.percent > 0 then
        row.fill:SetWidth(math.max(1, 98 * snapshot.percent / 100))
        row.fill:SetColorTexture(color[1], color[2], color[3], 0.95)
        row.fill:Show()
    else
        row.fill:Hide()
    end
end
