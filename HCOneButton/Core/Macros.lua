-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

function NewLines()
    return {}
end

function AddLine(lines, text, priority)
    if text and text ~= "" then
        table.insert(lines, { text = text, priority = priority or 5 })
    end
end

function FitMacro(lines)
    local function join()
        local out = {}
        for _, v in ipairs(lines) do table.insert(out, v.text) end
        return table.concat(out, "\n")
    end
    local text = join()
    while #text > MACRO_LIMIT and #lines > 1 do
        local worstIndex, worstPriority = nil, -1
        for i, v in ipairs(lines) do
            if v.priority > worstPriority then
                worstIndex, worstPriority = i, v.priority
            elseif v.priority == worstPriority and worstIndex then
                worstIndex = i
            end
        end
        if not worstIndex then break end
        table.remove(lines, worstIndex)
        text = join()
    end
    if #text > MACRO_LIMIT then
        return "/stopmacro"
    end
    return text
end

function CastLine(id, condition, bang)
    if not id or not IsKnown(id) then return nil end
    local cond = condition and ("[" .. condition .. "] ") or ""
    return "/cast " .. cond .. (bang and "!" or "") .. SpellName(id)
end

function RawCastLine(id, condition, bang)
    local name = SpellName(id)
    if not name then return nil end
    local cond = condition and ("[" .. condition .. "] ") or ""
    return "/cast " .. cond .. (bang and "!" or "") .. name
end

function SequenceLine(condition, reset, ids)
    local names = {}
    for _, id in ipairs(ids or {}) do
        if id == 0 then
            table.insert(names, "null")
        elseif IsKnown(id) then
            table.insert(names, SpellName(id))
        end
    end
    if #names == 0 then return nil end
    local cond = condition and ("[" .. condition .. "] ") or ""
    return "/castsequence " .. cond .. "reset=" .. reset .. " " .. table.concat(names, ",")
end

currentWarriorAutoRend = false

function WarriorTargetWantsRend()
    if HCOB_DB.warriorAutoRend == false or not IsKnown(S.REND) then return false end
    if not HostileLiveTarget() then return false end
    local playerLevel = PlayerLevel()
    local targetLevel = SafeUnitLevel("target", -1) or -1
    local classification = SafeUnitClassification("target", "normal") or "normal"
    local tough = classification == "elite" or classification == "rareelite" or classification == "worldboss"
    if tough then return true end
    -- At low level Rend is worth the GCD mainly when the target is expected to
    -- live for a while.  Skip it on trivial mobs two or more levels below us.
    return targetLevel <= 0 or targetLevel >= (playerLevel - 1)
end



















function BuildSpellMacro(id, condition, startAttack, allowUnknown)
    if not id then return "/stopmacro" end
    if not allowUnknown and not IsKnown(id) then return "/stopmacro" end
    local line = allowUnknown and RawCastLine(id, condition, false) or CastLine(id, condition, false)
    if not line then return "/stopmacro" end
    if startAttack then return "/startattack\n" .. line end
    return line
end











-- -------------------------------------------------------------------------

function ApplyAttributes(target, main, mods)
    if not target or InCombatLockdown() then return false end
    target:SetAttribute("type1", "macro")
    target:SetAttribute("macrotext1", main or "/stopmacro")
    target:SetAttribute("shift-type1", "macro")
    target:SetAttribute("shift-macrotext1", mods.shift or "/stopmacro")
    target:SetAttribute("ctrl-type1", "macro")
    target:SetAttribute("ctrl-macrotext1", mods.ctrl or "/stopmacro")
    target:SetAttribute("alt-type1", "macro")
    target:SetAttribute("alt-macrotext1", mods.alt or "/stopmacro")
    target:SetAttribute("ctrl-shift-type1", "macro")
    target:SetAttribute("ctrl-shift-macrotext1", mods.ctrlshift or "/stopmacro")
    target:SetAttribute("alt-shift-type1", "macro")
    target:SetAttribute("alt-shift-macrotext1", mods.altshift or "/stopmacro")
    target:SetAttribute("alt-ctrl-type1", "macro")
    target:SetAttribute("alt-ctrl-macrotext1", mods.altctrl or "/stopmacro")
    target:SetAttribute("alt-ctrl-shift-type1", "macro")
    target:SetAttribute("alt-ctrl-shift-macrotext1", mods.all or "/stopmacro")
    return true
end


function ActiveClassModuleForMacros()
    return HCOB.Classes and HCOB.Classes[PLAYER_CLASS] or nil
end

function BaseActionInfo()
    local class = ActiveClassModuleForMacros()
    if class and class.GetBaseActionInfo then
        return class:GetBaseActionInfo(TalentSpec())
    end
    return nil, "BASE SPAM"
end

function UpdateBaseVisual()
    local class = ActiveClassModuleForMacros()
    local id, desc = BaseActionInfo()
    icon:SetTexture(SpellIcon(id))
    label:SetText(class and class.GetBaseLabel and class:GetBaseLabel() or "BASE SPAM")
    hint:SetText(desc or "Base action")
    reasonText:SetText("Situational -> Advisor")
    glow:Hide()

    if icon.SetDesaturated then icon:SetDesaturated(false) end
    border:SetVertexColor(0.42, 0.48, 0.52, 0.95)

    local state = class and class.GetBaseVisualState and class:GetBaseVisualState() or nil
    if state == "ready" then
        border:SetVertexColor(0.20, 0.95, 0.35, 1.0)
        glow:SetVertexColor(0.20, 1.0, 0.35)
        glow:SetAlpha(0.72)
        glow:Show()
    elseif state == "close" or state == "out" then
        border:SetVertexColor(1.0, 0.22, 0.18, 1.0)
        if icon.SetDesaturated then icon:SetDesaturated(true) end
    elseif state then
        border:SetVertexColor(0.95, 0.72, 0.18, 1.0)
    end
end

function BuildMacros()
    if InCombatLockdown() then pendingRebuild = true; return end
    local class = ActiveClassModuleForMacros()
    local main = class and class.BuildMainMacro and class:BuildMainMacro() or "/stopmacro"
    local mods = class and class.BuildModifierMacros and class:BuildModifierMacros() or {desc={}}
    currentMods = mods
    ApplyAttributes(btn, main, mods)
    if HCOB.UI.ActionPanel then HCOB.UI.ActionPanel.Configure(); HCOB.UI.ActionPanel.SyncVisibility() end
    pendingRebuild = false
end


function PrintPlan()
    local localizedClass = UnitClass("player")
    local specIndex, specName = TalentSpec()
    print("|cff00ff98HCOB:|r " .. (localizedClass or PLAYER_CLASS) .. " L" .. PlayerLevel() .. " - " .. tostring(specName) .. " (tree " .. specIndex .. ")")
    print("|cffffcc00BASE SPAM macro:|r")
    print(btn:GetAttribute("macrotext1") or "")
    if currentMods and currentMods.desc then
        local d=currentMods.desc
        print("SHIFT="..tostring(d.shift).." | CTRL="..tostring(d.ctrl).." | ALT="..tostring(d.alt))
        print("CTRL+SHIFT="..tostring(d.ctrlshift).." | ALT+SHIFT="..tostring(d.altshift).." | ALT+CTRL="..tostring(d.altctrl).." | ALL="..tostring(d.all))
    end
end
