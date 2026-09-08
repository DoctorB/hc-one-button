-- Read-only Rogue equipment guidance. Never a pull gate or protected action.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)
local Class = HCOB.Classes.ROGUE
local cached, checkedAt

function Class:GetEquippedWeapon(slot)
    if not GetInventoryItemID then return nil end
    local ok, id = pcall(GetInventoryItemID, "player", slot)
    id = ok and SafeNumber(id, nil)
    if not id or id <= 0 then return nil end
    local api = GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)
    if type(api) ~= "function" then return nil end
    local read, _, _, subtype, _, _, classID, subclassID = pcall(api, id)
    if not read or SafeNumber(classID, nil) ~= 2 then return nil end
    subclassID = SafeNumber(subclassID, nil)
    if subclassID == nil then return nil end
    return {id=id, subclassID=subclassID, skillName=CanAccessValue(subtype) and type(subtype)=="string" and subtype or nil}
end

function Class:InvalidatePreparation(event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_LEVEL_UP" or event == "PLAYER_EQUIPMENT_CHANGED"
       or event == "SKILL_LINES_CHANGED" or event == "SPELLS_CHANGED" or event == "GET_ITEM_INFO_RECEIVED"
       or event == "PLAYER_REGEN_ENABLED" then cached, checkedAt = nil, nil end
end

function Class:GetPreparationNotice()
    if PLAYER_CLASS ~= "ROGUE" or not HCOB_DB or HCOB_DB.prePullSafety == false
       or not UnitAffectingCombat or UnitAffectingCombat("player")
       or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then return nil end
    local now = GetTime()
    if checkedAt and now >= checkedAt and now - checkedAt < 1 then return cached end
    checkedAt, cached = now, nil
    local skills = {}
    if GetNumSkillLines and GetSkillLineInfo then
        local ok, count = pcall(GetNumSkillLines)
        count = ok and SafeNumber(count, 0) or 0
        for index=1,math.min(200, count) do
            local read, name, header, _, rank, _, _, maximum = pcall(GetSkillLineInfo, index)
            rank, maximum = SafeNumber(rank, nil), SafeNumber(maximum, nil)
            if read and CanAccessValue(name) and type(name)=="string" and (header == false or header == nil)
               and rank and maximum and maximum > 0 then
                skills[name] = {rank=rank, maximum=maximum}
            end
        end
    end
    local warnings, seenSkills = {}, {}
    local weapons = {self:GetEquippedWeapon(16), self:GetEquippedWeapon(17)}
    local labels = {"MH", "OH"}
    for hand=1,2 do
        local weapon = weapons[hand]
        local skill = weapon and weapon.skillName and skills[weapon.skillName]
        if skill and not seenSkills[weapon.skillName] and skill.maximum - skill.rank >= 10 then
            seenSkills[weapon.skillName] = true
            warnings[#warnings+1] = string.format("%s %s skill %d/%d: practice on safer targets",
                labels[hand], weapon.skillName, skill.rank, skill.maximum)
        end
    end
    local poisonSkill = SpellName(2842) -- localized passive/skill name, not a level-only assumption
    local poisonsLearned = (IsKnown and IsKnown(2842)) or (poisonSkill and skills[poisonSkill])
    if PlayerLevel() >= 20 and poisonsLearned and GetWeaponEnchantInfo then
        local ok, mh, mhMS, _, _, oh, ohMS = pcall(GetWeaponEnchantInfo)
        if ok then
            local flags, expires = {mh, oh}, {mhMS, ohMS}
            for hand=1,2 do
                local present = flags[hand]
                local duration = SafeNumber(expires[hand], nil)
                -- Do not mistake an unreadable result for a missing poison, or
                -- a sharpening stone/other valid temporary coating for no enchant.
                if weapons[hand] and (present == nil or (CanAccessValue(present) and type(present)=="boolean"))
                   and (not present or (duration and duration <= 0)) then
                    warnings[#warnings+1] = labels[hand] .. " coating missing: check your poisons"
                end
            end
        end
    end
    if #warnings > 0 then cached = table.concat(warnings, "\n") end
    return cached
end
