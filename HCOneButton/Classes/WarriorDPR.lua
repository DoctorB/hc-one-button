-- Focused Classic leveling DPR comparison. See docs/WARRIOR_DPR_REVIEW.md.
-- Rank constants are spell data, not level-based assumptions about training.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)
local Class = HCOB.Classes.WARRIOR

local ranks = {
    [S.HEROIC_STRIKE] = {{78,11},{284,21},{285,32},{1608,44},{11564,58},
        {11565,80},{11566,111},{11567,138},{25286,157}},
    [S.REND] = {{772,15,3},{6546,28,4},{6547,45,5},{6548,66,6},
        {11572,98,7},{11573,126,7},{11574,147,7}},
    [S.SUNDER_ARMOR] = {{7386,90},{7405,180},{8380,270},{11596,360},{11597,450}},
}
local learned, talents
local function Number(value)
    value = SafeNumber(value, nil)
    if value and value == value and value > -math.huge and value < math.huge then return value end
end
local function Call(api, ...)
    if type(api) ~= "function" then return nil end
    local ok, a,b,c,d,e,f,g = pcall(api, ...)
    if ok then return a,b,c,d,e,f,g end
end

function Class:ResetDPRInputs()
    learned, talents = nil, nil
end

function Class:DPRTalentRank(id, maximum)
    if not talents then
        talents = {}
        for tab=1,3 do
            local count = Number(Call(GetNumTalents, tab)) or 0
            for index=1,math.min(40,count) do
                local a,b,_,_,e,f = Call(GetTalentInfo, tab, index)
                local name, rank = a,e
                if type(a) == "number" and type(b) == "string" then name,rank = b,f end
                if type(name) == "string" then talents[name] = Number(rank) or 0 end
            end
        end
    end
    return math.max(0, math.min(maximum, talents[SpellName(id) or ""] or 0))
end

function Class:DPRLearnedRank(id)
    if not learned then learned = {} end
    if learned[id] ~= nil then return learned[id] or nil end
    local rows = ranks[id] or {}
    for index=#rows,1,-1 do
        local spell = rows[index][1]
        -- Never use IsKnown here: its name fallback intentionally merges ranks.
        if Call(IsPlayerSpell, spell) == true or Call(IsSpellKnown, spell) == true
            or Call(C_SpellBook and C_SpellBook.IsSpellKnown, spell) == true then
            learned[id] = rows[index]
            return rows[index]
        end
    end
    learned[id] = false
end

function Class:DamageEfficiency(estimatedTTK)
    -- Group damage composition, PvP armor and dual-wield queue interactions
    -- need a different model. Keep the existing policy for those contexts.
    local engine = HCOB.Advisor.Engine
    if (engine.PlayerIsGrouped and engine.PlayerIsGrouped())
        or Call(UnitIsPlayer, "target") == true or CountActiveEnemies() ~= 1 then return nil end
    local speed, offSpeed = Call(UnitAttackSpeed, "player")
    speed, offSpeed = Number(speed), Number(offSpeed)
    if not speed or speed <= 0 or (offSpeed and offSpeed > 0) then return nil end
    local low, high, _, _, _, _, multiplier = Call(UnitDamage, "player")
    low, high = Number(low), Number(high)
    local health = Number(Call(UnitHealth, "target"))
    local maximum = Number(Call(UnitHealthMax, "target"))
    local level = Number(PlayerLevel())
    local crit = Number(Call(GetCritChance))
    local heroic = self:DPRLearnedRank(S.HEROIC_STRIKE)
    if (IsKnown(S.REND) and not self:DPRLearnedRank(S.REND))
        or (IsKnown(S.SUNDER_ARMOR) and not self:DPRLearnedRank(S.SUNDER_ARMOR)) then return nil end
    if not heroic or not low or not high or low <= 0 or high < low
        or not health or not maximum or maximum <= 0 or health <= 0 or health > maximum
        or not level or level < 1 or level > 60 or not crit then return nil end

    local weapon = (low + high) / 2 -- already includes AP, equipment and damage buffs
    multiplier = Number(multiplier) or 1
    if multiplier <= 0 then return nil end
    crit = math.max(0, math.min(1, crit / 100)) -- includes Cruelty/weapon-specialization crit
    local hda = 400 + 85 * level
    local _, armor = Call(UnitArmor, "target")
    armor = Number(armor)
    -- NPC armor is often unavailable/zero in Classic. Do not interpret that as
    -- a verified armorless NPC. Use a disclosed 30% mitigation estimate then.
    local estimatedArmor = not armor or armor <= 0
    if estimatedArmor then armor = hda * 0.30 / 0.70 end
    local mitigation = hda / (hda + armor)
    local rageConversion = 0.0091107836 * level * level + 3.225598133 * level + 4.2652911
    -- Simplified landed-hit expectation; do not invent enemy avoidance or a
    -- maxed weapon skill. No predicted miss/glancing/proc bonus is added.
    local white = weapon * mitigation * (1 + crit)
    local lostRage = 7.5 * white / rageConversion
    local impale = 0.1 * self:DPRTalentRank(16493, 2)
    local extra = (heroic[2] * multiplier * (1 + crit * (1 + impale))
        + weapon * crit * impale) * mitigation
    local hsCost = self:RageCost(S.HEROIC_STRIKE)
    if not hsCost then return nil end
    local remaining = Number(estimatedTTK)
    if not remaining or remaining <= 0 then remaining = health / (white / speed) end
    local model = {estimatedArmor=estimatedArmor, mitigation=mitigation,
        weapon=weapon, white=white, lostRage=lostRage, horizon=remaining,
        heroicRank=heroic[1], finishing=health <= (weapon + heroic[2] * multiplier) * mitigation}
    model[S.HEROIC_STRIKE] = {damage=extra, cost=hsCost + lostRage, dpr=extra / math.max(1, hsCost + lostRage)}

    local rend = self:DPRLearnedRank(S.REND)
    if rend then
        local ticks = math.min(rend[3], math.max(0, math.floor(remaining / 3)))
        local improved = ({1,1.15,1.25,1.35})[self:DPRTalentRank(12286,3)+1]
        local damage = rend[2] / rend[3] * ticks * improved * multiplier
        local cost = self:RageCost(S.REND)
        if cost then model[S.REND] = {damage=damage, cost=cost, dpr=damage / math.max(1,cost), ticks=ticks, rank=rend[1]} end
    end
    local sunder = self:DPRLearnedRank(S.SUNDER_ARMOR)
    if sunder then
        -- Sheet's remaining-HP armor benefit, expressed in damage rather than
        -- unmitigated EHP. Only the first stack is considered by class policy.
        -- Limit the payoff to Sunder's 30s duration and subtract extra white Rage.
        local damage = health * math.min(armor,sunder[2]) / (hda + armor) * math.min(1,30 / remaining)
        local nominal = self:RageCost(S.SUNDER_ARMOR)
        if nominal then
            local cost = math.max(1, nominal - 7.5 * damage / rageConversion)
            model[S.SUNDER_ARMOR] = {damage=damage, cost=cost, dpr=damage/cost,
                rank=sunder[1], enoughSwings=remaining >= math.max(3,speed * 2)}
        end
    end
    return model
end

function Class:DPRSetupWorth(model, id)
    if not model then return nil end -- nil means use the existing fallback
    local value = model[id]
    if not value then return nil end -- unverified rank must not become a guessed rank
    if model.finishing then return false end
    if id == S.SUNDER_ARMOR and not value.enoughSwings then return false end
    if id == S.REND and value.ticks < 2 then return false end
    -- A modest margin avoids committing setup on near-equal estimates.
    return value.dpr > model[S.HEROIC_STRIKE].dpr * 1.10
end

function Class:RankDamageCandidates(candidates, model, rage)
    if not model then return end
    local best = 0
    for _,c in ipairs(candidates) do
        if model[c.id] then best = math.max(best,model[c.id].dpr) end
    end
    if best <= 0 then return end
    for _,c in ipairs(candidates) do
        local value = model[c.id]
        if value then
            -- Keep core strikes, reactive windows, interrupts and critical
            -- survival above this bounded optional-spender comparison.
            c.score = 62 + 16 * value.dpr / best
            if c.id == S.HEROIC_STRIKE and (rage >= 80 or model.finishing) then c.score = 82 end
            c.reason = c.reason .. string.format(" | est. DPR %.2f%s", value.dpr,
                model.estimatedArmor and " (armor estimated)" or "")
        end
    end
end
