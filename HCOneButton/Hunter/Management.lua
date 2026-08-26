-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

-- HCOneButton Hunter Management v1.26.0
-- Event-driven Hunter logistics and pet supervision for WoW Classic Era.
-- This module never performs protected actions. It only exposes state and
-- recommendations consumed by the main HCOneButton Advisor.

local H = HCOB.Hunter

H.managementCache = H.managementCache or {}
H.managementCache.ammoDirty = true
H.managementCache.petDirty = true

H.PET_SKILL_IDS = H.PET_SKILL_IDS or {
    growl = 2649,
    bite = 17253,
    claw = 16827,
    dash = 23099,
    dive = 23110,
}

local function IsSoloWorld()
    local grouped = IsInGroup and IsInGroup() or false
    local inInstance, instanceType = false, "none"
    if IsInInstance then
        local ok, a, b = pcall(IsInInstance)
        if ok then inInstance, instanceType = a and true or false, b or "none" end
    end
    return not grouped and (not inInstance or instanceType == "none")
end

function H.InvalidateManagement()
    H.managementCache.ammoDirty = true
    H.managementCache.petDirty = true
end

function H.ManagementCandidates(inCombat, hostile)
    local list = {}
    local ammo = H.AmmoStatus(false)
    if ammo.required then
        if ammo.level == "empty" then
            list[#list + 1] = {title="NO AMMO", key="RESTOCK BEFORE PULL", reason="No compatible " .. tostring(ammo.ammoType) .. " detected for the equipped ranged weapon", score=(inCombat and 90 or 140), tag="logistics", displayKind=(inCombat and "caution" or "danger")}
        elseif ammo.level == "critical" and not inCombat then
            list[#list + 1] = {title="AMMO CRITICAL", key="RESTOCK SOON", reason=string.format("%d shots remaining | ~%.0f min estimated", ammo.total or 0, ammo.minutes or 0), score=118, tag="logistics", displayKind="caution"}
        elseif ammo.level == "low" and not inCombat and not hostile then
            list[#list + 1] = {title="LOW AMMO", key="RESTOCK WHEN PRACTICAL", reason=string.format("%d shots remaining | ~%.0f min estimated", ammo.total or 0, ammo.minutes or 0), score=68, tag="logistics", displayKind="caution"}
        end
    end

    local pet = H.PetSkillStatus(false)
    if (SafeUnitLevel("player", 1) or 1) >= 10 and not pet.petExists and not inCombat and hostile then
        list[#list + 1] = {title="NO PET SUMMONED", key="SUMMON PET BEFORE PULL", reason="Hunter leveling efficiency and threat control depend heavily on the pet", score=122, tag="pet", displayKind="caution"}
    elseif pet.petExists then
        local solo = IsSoloWorld()
        if not pet.growlKnown and not inCombat then
            list[#list + 1] = {title="PET NEEDS GROWL", key="OPEN BEAST TRAINING", reason="Growl is not detected on the current pet; threat control will be unreliable", score=116, tag="pet", displayKind="caution"}
        elseif pet.growlAutocastable and solo and not pet.growlAutocast and not inCombat then
            list[#list + 1] = {title="ENABLE GROWL AUTOCAST", key="RIGHT-CLICK GROWL", reason="Solo world play: Growl autocast is off, so the pet may struggle to hold threat", score=109, tag="pet", displayKind="caution"}
        elseif pet.growlAutocastable and not solo and pet.growlAutocast and not inCombat and not hostile then
            list[#list + 1] = {title="GROWL AUTOCAST ON", key="CHECK GROUP ROLE", reason="In grouped content Growl may compete with the tank; disable it when appropriate", score=58, tag="pet", displayKind="caution"}
        end

        local available = tonumber(pet.availablePoints) or 0
        local notice = tonumber(HCOB_DB and HCOB_DB.hunterTrainingPointNotice) or 10
        if available >= notice and not inCombat and not hostile then
            list[#list + 1] = {title="PET TRAINING POINTS", key="OPEN BEAST TRAINING", reason=string.format("%d training points available | review active skills, stamina, armor and resistances", available), score=56, tag="pet", displayKind="idle"}
        end
    end
    return list
end

function H.PrintAmmoStatus()
    if select(2, UnitClass("player")) ~= "HUNTER" then print("|cffffcc00HCOB HUNTER:|r Hunter-only command."); return end
    local a = H.AmmoStatus(true)
    if not a.required then
        print("|cff55c8ffHCOB AMMO:|r equipped ranged weapon does not use arrows/bullets.")
        return
    end
    print(string.format("|cff55c8ffHCOB AMMO:|r %s=%d | status=%s | estimated %.1f min | drain ~%.1f shots/min", tostring(a.ammoType), tonumber(a.total) or 0, tostring(a.level), tonumber(a.minutes) or 0, tonumber(a.shotsPerMinute) or 0))
end

function H.PrintPetSkillStatus()
    if select(2, UnitClass("player")) ~= "HUNTER" then print("|cffffcc00HCOB HUNTER:|r Hunter-only command."); return end
    local p = H.PetSkillStatus(true)
    if not p.petExists then print("|cff55c8ffHCOB PET SKILLS:|r no pet summoned."); return end
    print(string.format("|cff55c8ffHCOB PET SKILLS:|r %s L%s | Growl=%s autocast=%s | Bite=%s Claw=%s Dash=%s Dive=%s", tostring(p.family or "Pet"), tostring(p.level or "?"), tostring(p.growlKnown), tostring(p.growlAutocast), tostring(p.bite), tostring(p.claw), tostring(p.dash), tostring(p.dive)))
    if p.availablePoints ~= nil then
        print(string.format("|cff55c8ffHCOB PET TRAINING:|r total=%d spent=%d available=%d", tonumber(p.totalPoints) or 0, tonumber(p.spentPoints) or 0, tonumber(p.availablePoints) or 0))
    else
        print("|cff55c8ffHCOB PET TRAINING:|r training-point API unavailable on this client.")
    end
end

function H.PrintThreatStatus()
    if select(2, UnitClass("player")) ~= "HUNTER" then print("|cffffcc00HCOB HUNTER:|r Hunter-only command."); return end
    local t = H.ThreatSnapshot()
    print(string.format("|cff55c8ffHCOB THREAT:|r %s | player=%s%% | pet=%s%% | playerTanking=%s | petTanking=%s", tostring(t.state), t.playerPct and string.format("%.0f", t.playerPct) or "?", t.petPct and string.format("%.0f", t.petPct) or "?", tostring(t.playerTanking), tostring(t.petTanking)))
end

function H.PrintManagementStatus()
    H.PrintAmmoStatus()
    H.PrintPetSkillStatus()
    if UnitExists("target") and UnitCanAttack("player", "target") then H.PrintThreatStatus() end
end

local f = CreateFrame("Frame")
local events = {"PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "UNIT_PET", "PET_BAR_UPDATE", "SPELLS_CHANGED", "PLAYER_LEVEL_UP"}
for _, e in ipairs(events) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function(_, event, unit)
    if select(2, UnitClass("player")) ~= "HUNTER" then return end
    if event ~= "UNIT_INVENTORY_CHANGED" or unit == "player" then H.InvalidateManagement() end
end)
