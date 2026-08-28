-- Pre-pull readiness gate for Hardcore play.
-- This module is advisory only: it never blocks or executes a player action.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Engine = HCOB.Advisor.Engine

local function AddIssue(issues, priority, state, key, text)
    issues[#issues + 1] = {priority=priority, state=state, key=key, text=text}
end

local function JoinIssues(issues)
    table.sort(issues, function(a, b) return (a.priority or 0) > (b.priority or 0) end)
    local lines = {}
    for i=1, math.min(2, #issues) do lines[#lines + 1] = issues[i].text end
    return table.concat(lines, " | ")
end

-- Shared recovery contract for the major reset/control cooldowns each class
-- already uses in its panic policy. The gate warns only on tough targets and
-- only when at least one option has been learned; low-level characters are
-- never penalized for abilities they cannot know yet.
local ESCAPE_OPTIONS = {
    WARRIOR = {S.SHIELD_WALL, S.RETALIATION},
    PALADIN = {S.DIVINE_SHIELD, S.DIVINE_PROTECTION},
    HUNTER = {S.FEIGN_DEATH, S.SCATTER_SHOT},
    ROGUE = {S.VANISH, S.EVASION, S.SPRINT},
    PRIEST = {S.PSYCHIC_SCREAM},
    MAGE = {S.ICE_BLOCK, S.FROST_NOVA, S.BLINK},
    WARLOCK = {S.DEATH_COIL, S.FEAR},
    SHAMAN = {S.STONECLAW_TOTEM, S.EARTHBIND_TOTEM},
    DRUID = {S.NATURES_GRASP, S.BARKSKIN, S.DASH},
}

function Engine.PrimaryEscapeState()
    if not IsKnown or not CooldownReady then return {known=false, ready=false} end
    local shortest, shortestName, known = nil, nil, false
    for _, spellID in ipairs(ESCAPE_OPTIONS[PLAYER_CLASS] or {}) do
        if spellID and IsKnown(spellID) then
            known = true
            local name = SpellName(spellID, "escape tool")
            if CooldownReady(spellID) then return {known=true, ready=true, id=spellID, name=name, remaining=0} end
            local remaining = CooldownRemaining and tonumber(CooldownRemaining(spellID)) or nil
            if remaining and (shortest == nil or remaining < shortest) then
                shortest, shortestName = remaining, name
            elseif not shortestName then
                shortestName = name
            end
        end
    end
    return {known=known, ready=false, name=shortestName, remaining=shortest or 0}
end

function Engine.EvaluatePrePullReadiness(context)
    context = context or {}
    if HCOB_DB and HCOB_DB.prePullSafety == false then
        local disabled = {ready=true, state="disabled", summary="Pre-pull safety gate disabled"}
        Engine.lastPrePullReadiness = disabled
        return disabled
    end

    local issues = {}
    local hp, hpReadable = UnitHealthPct("player")
    hp = tonumber(hp) or 0
    if not hpReadable then
        AddIssue(issues, 100, "prepare", "WAIT FOR DATA", "Player health is not readable")
    elseif hp < 85 then
        AddIssue(issues, 95, "recover", "HEAL / EAT", string.format("Health %.0f%%: recover before pulling", hp))
    end

    local powerType, powerToken = UnitPowerType("player")
    local powerPct, powerReadable = UnitPowerPct("player", powerType)
    powerPct = tonumber(powerPct) or 0
    if powerToken == "MANA" then
        if not powerReadable then
            AddIssue(issues, 90, "prepare", "WAIT FOR DATA", "Mana is not readable")
        elseif powerPct < 40 then
            AddIssue(issues, 92, "recover", "DRINK", string.format("Mana %.0f%%: recover before pulling", powerPct))
        elseif powerPct < 60 then
            AddIssue(issues, 68, "prepare", "RECOVER MANA", string.format("Mana %.0f%%: start with a safer reserve", powerPct))
        end
    elseif powerToken == "ENERGY" and powerReadable and powerPct < 60 then
        AddIssue(issues, 55, "prepare", "WAIT FOR ENERGY", string.format("Energy %.0f%%: let it refill", powerPct))
    end

    local level = tonumber(context.playerLevel) or PlayerLevel()
    if (PLAYER_CLASS == "HUNTER" or PLAYER_CLASS == "WARLOCK") and level >= 10 then
        local petExists = UnitExists("pet") and not UnitIsDead("pet")
        if not petExists then
            AddIssue(issues, 66, "prepare", "SUMMON / REVIVE PET", "No living pet is available for the pull")
        else
            local petHP, petReadable = UnitHealthPct("pet")
            petHP = tonumber(petHP) or 0
            if petReadable and petHP < 70 then
                AddIssue(issues, 88, "recover", "HEAL PET", string.format("Pet health %.0f%%: recover before pulling", petHP))
            elseif petReadable and petHP < 90 then
                AddIssue(issues, 64, "prepare", "MEND / FEED PET", string.format("Pet health %.0f%%: prepare it first", petHP))
            end
        end
    end

    local escape = context.targetTough == true and Engine.PrimaryEscapeState() or nil
    if escape and escape.known and not escape.ready then
        local timing = escape.remaining and escape.remaining > 0 and (" (" .. math.ceil(escape.remaining) .. "s)") or ""
        AddIssue(issues, 72, "prepare", "WAIT FOR ESCAPE",
            tostring(escape.name or "Primary escape") .. " is on cooldown" .. timing)
    end

    local consumables = HCOB.Systems and HCOB.Systems.Consumables
    local stocked, healingReady, cooldown = false, false, 0
    if consumables and consumables.HealingCooldownState then
        stocked, healingReady, cooldown = consumables.HealingCooldownState()
    end
    local targetTough = context.targetTough == true
    if targetTough and not stocked then
        AddIssue(issues, 84, "highrisk", "RESTOCK FIRST", "Tough target: no healing potion, Healthstone or bandage")
    elseif targetTough and stocked and not healingReady then
        AddIssue(issues, 70, "prepare", "WAIT FOR COOLDOWN",
            string.format("Tough target: healing tools cooling down%s", cooldown > 0 and (" (" .. math.ceil(cooldown) .. "s)") or ""))
    end

    if #issues > 0 then
        table.sort(issues, function(a, b) return (a.priority or 0) > (b.priority or 0) end)
        local lead = issues[1]
        local titles = {recover="RECOVER FIRST", highrisk="HIGH RISK", prepare="PREPARE"}
        local result = {
            ready=false, state=lead.state, title=titles[lead.state] or "PREPARE",
            key=lead.key or "WAIT / RECOVER", reason=JoinIssues(issues), issues=issues,
            healingStocked=stocked, healingReady=healingReady,
        }
        Engine.lastPrePullReadiness = result
        return result
    end

    local parts = {}
    if hpReadable then parts[#parts + 1] = string.format("HP %.0f%%", hp) end
    if powerToken == "MANA" and powerReadable then parts[#parts + 1] = string.format("mana %.0f%%", powerPct) end
    if stocked then parts[#parts + 1] = healingReady and "healing tools ready" or "healing tools stocked" end
    if escape and escape.known and escape.ready then parts[#parts + 1] = "escape ready" end
    local result = {
        ready=true, state="ready", title="PULL READY", key="PRESS BASE",
        summary=#parts > 0 and table.concat(parts, " | ") or "Core recovery checks passed",
        healingStocked=stocked, healingReady=healingReady,
    }
    Engine.lastPrePullReadiness = result
    return result
end

function Engine.PrePullRecommendation(context)
    local readiness = Engine.EvaluatePrePullReadiness(context)
    if readiness.ready then return nil end
    return nil, readiness.title, readiness.key, readiness.reason,
        readiness.state == "highrisk" and "danger" or "caution"
end
