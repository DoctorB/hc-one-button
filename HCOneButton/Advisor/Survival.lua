-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

function HCOB.Advisor.Engine.ManaPct()
    local pct, readable = UnitPowerPct("player", 0)
    return readable and pct or 0
end


function HCOB.Advisor.Engine.PriestHealSpell(emergency)
    if emergency and IsKnown(S.FLASH_HEAL) and IsUsable(S.FLASH_HEAL) then return S.FLASH_HEAL end
    if IsKnown(S.HEAL) and IsUsable(S.HEAL) then return S.HEAL end
    if IsKnown(S.LESSER_HEAL) and IsUsable(S.LESSER_HEAL) then return S.LESSER_HEAL end
    if IsKnown(S.FLASH_HEAL) and IsUsable(S.FLASH_HEAL) then return S.FLASH_HEAL end
    return nil
end

function HCOB.Advisor.Engine.PaladinHealSpell(emergency)
    if emergency and IsKnown(S.FLASH_LIGHT) and IsUsable(S.FLASH_LIGHT) then return S.FLASH_LIGHT end
    if IsKnown(S.HOLY_LIGHT) and IsUsable(S.HOLY_LIGHT) then return S.HOLY_LIGHT end
    if IsKnown(S.FLASH_LIGHT) and IsUsable(S.FLASH_LIGHT) then return S.FLASH_LIGHT end
    return nil
end

function HCOB.Advisor.Engine.SurvivalReserve()
    local hp, hpReadable = UnitHealthPct("player")
    if not hpReadable then hp = 0 end
    local enemies = CountActiveEnemies()
    local mana, manaReadable = UnitPowerPct("player", 0)
    if not manaReadable then mana = 0 end
    local class = HCOB.Classes and HCOB.Classes[PLAYER_CLASS]
    local score

    if class and class.GetSurvivalReserve then
        score = class:GetSurvivalReserve({ hp = hp, mana = mana, enemies = enemies })
    end
    if score == nil then
        score = hp * 0.76 + math.min(100, mana) * 0.08 + 12
    end

    score = score - math.max(0, enemies - 1) * 12
    score = Clamp(score, 0, 100)
    local label = score >= 72 and "HIGH" or (score >= 48 and "MED" or (score >= 30 and "LOW" or "CRITICAL"))
    HCOB.Advisor.Engine.lastReserve = score
    HCOB.Advisor.Engine.lastReserveLabel = label
    return score, label
end


function PanicRecommendation(context)
    local class = HCOB.Classes and HCOB.Classes[PLAYER_CLASS]
    if class and class.GetPanicRecommendation then
        return class:GetPanicRecommendation(context)
    end
    return nil, "RUN!", "PREPARE ESCAPE", "No immediate class defensive available"
end


function MultiPullRecommendation(enemies, hp, targetHP)
    if HCOB_DB.hcDangerAdvisor == false or enemies < 2 then return nil end
    local class = HCOB.Classes and HCOB.Classes[PLAYER_CLASS]
    if class and class.GetMultiPullRecommendation then
        return class:GetMultiPullRecommendation(enemies, hp, targetHP)
    end
    if enemies >= 3 or hp <= 50 then
        local id, _, key, reason = PanicRecommendation({
            source="multi", enemies=enemies, hp=hp, targetHP=targetHP,
        })
        return id, enemies >= 3 and "3+ MOBS - PANIC" or "MULTI - GET OUT",
            key or "ALL MODS", reason or "Create distance", "danger"
    end
    return nil, "MULTI x2", "PREPARE CONTROL", "Multi-pull: preserve defensive cooldowns", "caution"
end


-- Situational Hardcore estimate using percentages, so it does not depend on whether
-- Classic exposes absolute or normalized mob HP. It is used only on
-- single target and after a few seconds, to avoid false alerts at the opener.
