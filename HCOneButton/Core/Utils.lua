-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

function Default(key, value)
    local current = HCOB_DB[key]
    if current == nil then
        HCOB_DB[key] = value
        return
    end

    if type(value) == "number" and type(current) ~= "number" then
        local numeric = tonumber(current)
        if numeric then
            HCOB_DB[key] = numeric
            HCOB.RecordSavedVariableRepair("HCOB_DB." .. key)
            return
        end
    end

    if type(current) ~= type(value) then
        HCOB_DB[key] = value
        HCOB.RecordSavedVariableRepair("HCOB_DB." .. key)
    end
end
function InitializeSavedVariables()
    Default("visible", true)
    Default("x", 0)
    Default("y", -180)
    Default("hudPoint", "CENTER")
    Default("hudRelativePoint", "CENTER")
    Default("scale", 1.0)
    Default("dangerHP", 35)
    Default("criticalHP", 20)
    Default("soundAlerts", true)
    Default("enemyWindow", 6)
    Default("showSwing", true)
    Default("locked", false)
    Default("showOptionsHint", true)
    Default("smartDisplay", true)
    Default("warriorHeroicRage", 35)
    Default("showAdvisor", true)
    Default("showDPSMeter", true)
    Default("hcDangerAdvisor", true)
    Default("warriorSunderBase", true)
    Default("warriorHeroicSpam", false)
    Default("warriorAutoRend", true)
    Default("combatLogging", true)
    Default("diagPixel", true)
    Default("profCoach", true)
    Default("secureActions", true)
    Default("actionScale", 1.0)
    Default("actionSlotAutoBind", true)
    Default("prePullSafety", true)
    Default("showConsumables", true)

    for _, key in ipairs({"actionSlotKeys", "actionSlotAppliedKeys"}) do
        if HCOB_DB[key] ~= nil and type(HCOB_DB[key]) ~= "table" then
            HCOB_DB[key] = nil
            HCOB.RecordSavedVariableRepair("HCOB_DB." .. key)
        end
    end

    -- v1.11: Heroic Strike must never live in the BASE SPAM macro. A secure macro
    -- cannot test the player's current rage, so putting !Heroic Strike in the base
    -- button queued it even when rage was scarce. Migrate existing SavedVariables
    -- once so upgrades from older versions cannot retain the unsafe behavior.
    if HCOB_DB.warriorHeroicSafeBaseV111 ~= true then
        HCOB_DB.warriorHeroicSpam = false
        HCOB_DB.warriorHeroicSafeBaseV111 = true
    end
    Default("combatLogMaxFights", 60)

    Default("hunterAmmoCriticalMinutes", 8)
    Default("hunterAmmoLowMinutes", 20)
    Default("hunterTrainingPointNotice", 10)

    -- Combat history remains account-wide for one bounded diagnostic store,
    -- while this anonymous identifier is persisted by WoW per character. New
    -- fight records can therefore be selected without storing a name, realm or
    -- GUID and without mixing two characters of the same class.
    if type(HCOB_CharacterDB.version) ~= "number" then
        if HCOB_CharacterDB.version ~= nil then HCOB.RecordSavedVariableRepair("HCOB_CharacterDB.version") end
        HCOB_CharacterDB.version = 1
    end
    if type(HCOB_CharacterDB.logProfileId) ~= "string" or #HCOB_CharacterDB.logProfileId < 8 or #HCOB_CharacterDB.logProfileId > 80 then
        if HCOB_CharacterDB.logProfileId ~= nil then HCOB.RecordSavedVariableRepair("HCOB_CharacterDB.logProfileId") end
        local wallClock = (GetServerTime and GetServerTime()) or (time and time()) or 0
        local sessionClock = (GetTime and GetTime()) or 0
        local randomPart = math.random and math.random(100000, 999999) or 0
        HCOB_CharacterDB.logProfileId = string.format("p%d-%d-%d", math.floor(wallClock), math.floor(sessionClock * 1000), randomPart)
    end
    if type(HCOB_CharacterDB.logSession) ~= "string" or HCOB_CharacterDB.logSession == "" then
        if HCOB_CharacterDB.logSession ~= nil then HCOB.RecordSavedVariableRepair("HCOB_CharacterDB.logSession") end
        local legacySession = type(HCOB_CombatLog.session) == "string" and HCOB_CombatLog.session or nil
        if legacySession and legacySession ~= "" and not legacySession:match("^HCOneButton %d+%.%d+%.%d+$") then
            HCOB_CharacterDB.logSession = legacySession
        else
            HCOB_CharacterDB.logSession = "HCOneButton " .. VERSION
        end
    elseif HCOB_CharacterDB.logSession:match("^HCOneButton %d+%.%d+%.%d+$") then
        HCOB_CharacterDB.logSession = "HCOneButton " .. VERSION
    end

    -- Stable per-character learner store. Collection is available in 1.28.6,
    -- while automatic policy changes remain explicitly disabled until the
    -- learner, rollback and user controls ship together.
    if type(HCOB_CharacterDB.adaptive) ~= "table" then
        if HCOB_CharacterDB.adaptive ~= nil then HCOB.RecordSavedVariableRepair("HCOB_CharacterDB.adaptive") end
        HCOB_CharacterDB.adaptive = {}
    end
    local adaptive = HCOB_CharacterDB.adaptive
    if type(adaptive.version) ~= "number" then
        if adaptive.version ~= nil then HCOB.RecordSavedVariableRepair("HCOB_CharacterDB.adaptive.version") end
        adaptive.version = 1
    end
    if type(adaptive.enabled) ~= "boolean" then
        if adaptive.enabled ~= nil then HCOB.RecordSavedVariableRepair("HCOB_CharacterDB.adaptive.enabled") end
        adaptive.enabled = false
    end
    if type(adaptive.contexts) ~= "table" then
        if adaptive.contexts ~= nil then HCOB.RecordSavedVariableRepair("HCOB_CharacterDB.adaptive.contexts") end
        adaptive.contexts = {}
    end
end

function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Defensive shared-API guard. Blizzard currently documents Secret Values as
-- disabled on Classic clients, so ordinary Classic Era/Hardcore reads remain
-- normal Lua values. Keep these checks fail-closed for shared API surfaces and
-- future/restricted contexts; on current Classic they are transparent.
function CanAccessValue(value)
    if value == nil then return false end
    if canaccessvalue then
        local ok, allowed = pcall(canaccessvalue, value)
        if ok then return allowed == true end
    end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret == true then return false end
    end
    return true
end

function CanAccessTable(value)
    if type(value) ~= "table" then return false end
    if canaccesstable then
        local ok, allowed = pcall(canaccesstable, value)
        if ok then return allowed == true end
    end
    if issecrettable then
        local ok, secret = pcall(issecrettable, value)
        if ok and secret == true then return false end
    end
    return true
end

function SafeNumber(value, fallback)
    if not CanAccessValue(value) then return fallback end
    local ok, number = pcall(tonumber, value)
    if ok and number ~= nil then return number end
    return fallback
end

function SafeBoolean(value, fallback)
    if not CanAccessValue(value) then return fallback and true or false end
    return value and true or false
end

function SafeString(value, fallback)
    if value == nil or not CanAccessValue(value) then return fallback end
    if type(value) == "string" then return value end
    local ok, text = pcall(tostring, value)
    if ok then return text end
    return fallback
end

local validHUDPoints = {
    TOPLEFT=true, TOP=true, TOPRIGHT=true,
    LEFT=true, CENTER=true, RIGHT=true,
    BOTTOMLEFT=true, BOTTOM=true, BOTTOMRIGHT=true,
}

local function PersistentSettingsDB()
    -- SavedVariables are serialized from the TOC-declared global. Rebind a
    -- stale private reference defensively so drag-stop can never write only to
    -- a bootstrap/runtime table and lose the position on /reload.
    local globalDB = _G and rawget(_G, "HCOB_DB") or nil
    if type(globalDB) == "table" then
        if HCOB.DB ~= globalDB or HCOB_DB ~= globalDB then
            HCOB.DB = globalDB
            E.HCOB_DB = globalDB
            HCOB_DB = globalDB
        end
        return globalDB
    end
    if type(HCOB.DB) == "table" then return HCOB.DB end
    return type(HCOB_DB) == "table" and HCOB_DB or nil
end

local function ValidHUDPoint(value, fallback)
    value = SafeString(value, nil)
    if value and validHUDPoints[value] then return value end
    return fallback
end

function ReadHUDPosition()
    local db = PersistentSettingsDB()
    if not db then return "CENTER", "CENTER", 0, -180 end
    local point = ValidHUDPoint(db.hudPoint, "CENTER")
    local relativePoint = ValidHUDPoint(db.hudRelativePoint, point)
    return point, relativePoint, SafeNumber(db.x, 0), SafeNumber(db.y, -180)
end

function SaveHUDPosition(frame)
    if not frame or type(frame.GetPoint) ~= "function" then return false end
    local ok, point, _, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
    if not ok then return false end
    point = ValidHUDPoint(point, nil)
    relativePoint = ValidHUDPoint(relativePoint, point)
    x, y = SafeNumber(x, nil), SafeNumber(y, nil)
    if not point or not relativePoint or x == nil or y == nil then return false end

    local db = PersistentSettingsDB()
    if not db then return false end
    db.hudPoint, db.hudRelativePoint = point, relativePoint
    db.x, db.y = x, y
    return true
end

function SafeUnitGUID(unit)
    if not UnitGUID then return nil end
    local ok, value = pcall(UnitGUID, unit)
    if not ok or not CanAccessValue(value) then return nil end
    return value
end

function SafeUnitName(unit, fallback)
    if not UnitName then return fallback end
    local ok, value = pcall(UnitName, unit)
    if not ok then return fallback end
    return SafeString(value, fallback)
end

function SafeUnitLevel(unit, fallback)
    if not UnitLevel then return fallback end
    local ok, value = pcall(UnitLevel, unit)
    if not ok then return fallback end
    return SafeNumber(value, fallback)
end

function SafeUnitClassification(unit, fallback)
    if not UnitClassification then return fallback end
    local ok, value = pcall(UnitClassification, unit)
    if not ok then return fallback end
    return SafeString(value, fallback)
end

function SafeUnitHealth(unit, fallback)
    if not UnitHealth then return fallback end
    local ok, value = pcall(UnitHealth, unit)
    if not ok then return fallback end
    return SafeNumber(value, fallback)
end

function SafeUnitHealthMax(unit, fallback)
    if not UnitHealthMax then return fallback end
    local ok, value = pcall(UnitHealthMax, unit)
    if not ok then return fallback end
    return SafeNumber(value, fallback)
end

function SafeUnitPower(unit, powerType, fallback)
    if not UnitPower then return fallback end
    local ok, value = pcall(UnitPower, unit, powerType)
    if not ok then return fallback end
    return SafeNumber(value, fallback)
end

function SafeUnitPowerMax(unit, powerType, fallback)
    if not UnitPowerMax then return fallback end
    local ok, value = pcall(UnitPowerMax, unit, powerType)
    if not ok then return fallback end
    return SafeNumber(value, fallback)
end

function UnitHealthPct(unit)
    if not UnitExists(unit) then return 100, true end
    local hp = SafeUnitHealth(unit, nil)
    local maxHP = SafeUnitHealthMax(unit, nil)
    if hp == nil or maxHP == nil then return 100, false end
    if maxHP <= 0 then return 100, true end
    return (hp / maxHP) * 100, true
end

function UnitPowerPct(unit, powerType)
    local value = SafeUnitPower(unit, powerType, nil)
    local maxValue = SafeUnitPowerMax(unit, powerType, nil)
    if value == nil or maxValue == nil then return 100, false end
    if maxValue <= 0 then return 100, true end
    return (value / maxValue) * 100, true
end

function PlayerLevel()
    return SafeUnitLevel("player", 1) or 1
end


function TalentTabCompat(index)
    -- Classic Era 1.15.8+ changed GetTalentTabInfo from the legacy
    -- name, texture, pointsSpent... layout to
    -- id, name, description, icon, pointsSpent... .
    -- Detect the layout at runtime so the addon also remains compatible
    -- with older Classic branches.
    local a, b, c, d, e = GetTalentTabInfo(index)
    local name, points
    if type(a) == "number" and type(b) == "string" then
        name = b
        points = tonumber(e) or 0
    else
        name = type(a) == "string" and a or (type(b) == "string" and b or nil)
        points = tonumber(c) or tonumber(e) or 0
    end
    return name, points
end

function TalentSpec()
    local class = HCOB.Classes and HCOB.Classes[PLAYER_CLASS]
    local fallback = class and tonumber(class.fallbackSpec) or 1
    if not GetTalentTabInfo or PlayerLevel() < 10 then
        return fallback, "Leveling", 0
    end
    local bestIndex, bestName, bestPoints = fallback, "Leveling", -1
    for i = 1, 3 do
        local name, points = TalentTabCompat(i)
        if points > bestPoints then
            bestIndex, bestName, bestPoints = i, (name or ("Tree " .. i)), points
        end
    end
    if bestPoints <= 0 then bestIndex = fallback end
    return bestIndex, bestName, bestPoints
end

function HasWandEquipped()
    local link = GetInventoryItemLink("player", 18)
    if not link or not GetItemInfo then return false end
    local classID = select(12, GetItemInfo(link))
    local subClassID = select(13, GetItemInfo(link))
    return classID == 2 and subClassID == 19
end

function MainhandSpeed()
    if not UnitAttackSpeed then return 0 end
    local ok, speed = pcall(UnitAttackSpeed, "player")
    return ok and (SafeNumber(speed, 0) or 0) or 0
end



function RecordRuntimeError(area, err)
    local message = tostring(err or "unknown error")
    runtimeErrors[#runtimeErrors + 1] = { area = area, message = message, at = GetTime and GetTime() or 0 }
    if #runtimeErrors > 8 then table.remove(runtimeErrors, 1) end
    local now = GetTime and GetTime() or 0
    if now - lastErrorNotice > 3 then
        lastErrorNotice = now
        print("|cffff5555HCOB:|r error caught in " .. tostring(area) .. ". Fail-safe active; use /hcob errors for details.")
    end
end

function SafeRun(area, fn, ...)
    local args = { ... }
    local function runner() return fn(unpack(args)) end
    local ok, result = xpcall(runner, function(err) return tostring(err) end)
    if not ok then
        RecordRuntimeError(area, result)
        return false, result
    end
    return true, result
end

-- ---------------------------------------------------------------------------
-- Combat telemetry
-- ---------------------------------------------------------------------------
-- WoW addons cannot write files directly in real time. These
-- data are kept in memory and serialized by the client into
-- WTF/.../SavedVariables/HCOneButton.lua during /reload, logout, or exit.
