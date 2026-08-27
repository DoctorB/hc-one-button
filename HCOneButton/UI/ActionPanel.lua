-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

-- v1.18 Secure Advisor Actions
--
-- Blizzard does not allow a single SecureActionButton to change spells in
-- combat based on a Lua decision. The secure and stable solution is
-- a palette of FIXED buttons: each icon has a spell/macro assigned out of
-- combat; during the fight the Advisor only changes the visual highlight.
-- The player click on the specific icon therefore remains the only input that
-- executes the protected action.
-- -------------------------------------------------------------------------
HCOB.UI.ActionPanel = HCOB.UI.ActionPanel
HCOB.UI.ActionPanel.buttons = HCOB.UI.ActionPanel.buttons or {}
HCOB.UI.ActionPanel.idToButton = HCOB.UI.ActionPanel.idToButton or {}
HCOB.UI.ActionPanel.idToSlot = HCOB.UI.ActionPanel.idToSlot or {}
HCOB.UI.ActionPanel.idToActionIndex = HCOB.UI.ActionPanel.idToActionIndex or {}
HCOB.UI.ActionPanel.maxButtons = 20

-- Diagnostic RGB protocol v3. The external reader does NOT know classes or spells:
-- it only knows the color and translates it into a fixed panel SLOT.
--   R = fixed slot (1..20) * 12
--   G = 96
--   B = 224
-- Black = NONE. White = recommendation not mapped to the panel.
--
-- Important: panel slots are deterministic per class and are NOT
-- ever compacted based on learned spells. Example Hunter:
-- SLOT 01 Hunter's Mark, SLOT 02 Serpent Sting, SLOT 03 Arcane Shot, etc.

HCOB.UI.ActionPanel.actions = {
    WARRIOR={S.REND,S.OVERPOWER,S.EXECUTE,S.HEROIC_STRIKE,S.SUNDER_ARMOR,S.THUNDER_CLAP,S.DEMO_SHOUT,S.BATTLE_SHOUT,S.BLOODRAGE,S.HAMSTRING,S.MORTAL_STRIKE,S.BLOODTHIRST,S.WHIRLWIND,S.PUMMEL,S.SHIELD_BASH,S.BERSERKER_RAGE,S.RETALIATION,S.SHIELD_WALL,S.CHARGE},
    PALADIN={S.SEAL_RIGHTEOUSNESS,S.SEAL_COMMAND,S.JUDGEMENT,S.BLESSING_MIGHT,S.CONSECRATION,S.HAMMER_JUSTICE,S.EXORCISM,S.HAMMER_WRATH,S.DIVINE_PROTECTION,S.LAY_ON_HANDS,S.HOLY_LIGHT,S.FLASH_LIGHT,S.DIVINE_SHIELD,S.SEAL_CRUSADER},
    HUNTER={S.HUNTERS_MARK,S.SERPENT_STING,S.ARCANE_SHOT,S.AIMED_SHOT,S.MULTI_SHOT,S.CONCUSSIVE_SHOT,S.SCATTER_SHOT,S.WING_CLIP,S.RAPTOR_STRIKE,S.MONGOOSE_BITE,S.MEND_PET,S.FEED_PET,S.FEIGN_DEATH,S.INTIMIDATION,S.BESTIAL_WRATH,S.RAPID_FIRE,S.FREEZING_TRAP,S.ASPECT_HAWK,S.ASPECT_MONKEY,S.ASPECT_CHEETAH},
    ROGUE={S.SINISTER_STRIKE,S.HEMORRHAGE,S.EVISCERATE,S.GOUGE,S.KICK,S.STEALTH,S.SPRINT,S.EVASION,S.VANISH,S.BLADE_FLURRY,S.SLICE_DICE,S.GARROTE,S.CHEAP_SHOT,S.KIDNEY_SHOT,S.BLIND,S.ADRENALINE_RUSH,S.RIPOSTE},
    PRIEST={S.SHADOW_WORD_PAIN,S.MIND_BLAST,S.MIND_FLAY,S.POWER_WORD_SHIELD,S.RENEW,S.PSYCHIC_SCREAM,S.SILENCE,S.FADE,S.FORTITUDE,S.SHOOT,S.LESSER_HEAL,S.HEAL,S.FLASH_HEAL,S.INNER_FIRE,S.HOLY_FIRE,S.SMITE},
    MAGE={S.FROSTBOLT,S.FIREBALL,S.FIRE_BLAST,S.FROST_NOVA,S.BLINK,S.COUNTERSPELL,S.POLYMORPH,S.ICE_BARRIER,S.MANA_SHIELD,S.ICE_BLOCK,S.COLD_SNAP,S.EVOCATION,S.PYROBLAST,S.SCORCH,S.CONE_OF_COLD,S.ARCANE_EXPLOSION,S.BLIZZARD,S.SHOOT,S.ARCANE_MISSILES},
    WARLOCK={S.CORRUPTION,S.CURSE_AGONY,S.IMMOLATE,S.SHADOW_BOLT,S.FEAR,S.DRAIN_LIFE,S.LIFE_TAP,S.SHADOWBURN,S.DEATH_COIL,S.SPELL_LOCK,S.DEMON_ARMOR,S.DEMON_SKIN,S.SHOOT,S.DRAIN_SOUL,S.CURSE_WEAKNESS},
    DRUID={S.MOONFIRE,S.WRATH,S.RAKE,S.CLAW,S.FEROCIOUS_BITE,S.MAUL,S.ENTANGLING_ROOTS,S.FERAL_CHARGE,S.BASH,S.BARKSKIN,S.NATURES_GRASP,S.DASH,S.TRAVEL_FORM,S.MARK_WILD,S.CAT_FORM,S.BEAR_FORM,S.RIP,S.FAERIE_FIRE_FERAL,S.HEALING_TOUCH,S.FRENZIED_REGENERATION},
    SHAMAN={S.FLAME_SHOCK,S.EARTH_SHOCK,S.LIGHTNING_BOLT,S.STORMSTRIKE,S.LIGHTNING_SHIELD,S.EARTHBIND_TOTEM,S.STONECLAW_TOTEM,S.HEALING_WAVE,S.GHOST_WOLF,S.FROST_SHOCK,S.SEARING_TOTEM,S.FIRE_NOVA_TOTEM,S.CHAIN_LIGHTNING,S.ROCKBITER_WEAPON,S.WINDFURY_WEAPON},
}


-- Fixed Action Panel bindings. The physical slot remains deterministic; only
-- the hardware binding can be customized. Defaults are preserved exactly from
-- v1.18.5. Custom values live in HCOB_DB.actionSlotKeys. A stored `false` means
-- that slot is intentionally unbound.
HCOB.UI.ActionPanel.defaultSlotKeys = {
    "SHIFT-1", "SHIFT-2", "SHIFT-3", "SHIFT-4", "SHIFT-5",
    "SHIFT-6", "SHIFT-7", "SHIFT-8", "SHIFT-9", "SHIFT-0",
    "CTRL-SHIFT-1", "CTRL-SHIFT-2", "CTRL-SHIFT-3", "CTRL-SHIFT-4",
    "CTRL-SHIFT-5", "CTRL-SHIFT-6", "CTRL-SHIFT-7", "CTRL-SHIFT-8",
    "CTRL-SHIFT-9", "CTRL-SHIFT-0",
}
-- Compatibility alias for older code/tools that inspected this table.
HCOB.UI.ActionPanel.slotKeys = HCOB.UI.ActionPanel.defaultSlotKeys

function HCOB.UI.ActionPanel.NormalizeSlotKey(key)
    if key == false then return false end
    key = tostring(key or ""):upper():gsub("%s+", ""):gsub("%+", "-")
    key = key:gsub("CONTROL", "CTRL")
    if key == "" or key == "NONE" or key == "UNBOUND" then return false end

    local ctrl, alt, shift, base = false, false, false, nil
    for part in key:gmatch("[^%-]+") do
        if part == "CTRL" then ctrl = true
        elseif part == "ALT" then alt = true
        elseif part == "SHIFT" then shift = true
        elseif part ~= "" then base = part end
    end
    if not base then return false end

    local parts = {}
    if ctrl then parts[#parts+1] = "CTRL" end
    if alt then parts[#parts+1] = "ALT" end
    if shift then parts[#parts+1] = "SHIFT" end
    parts[#parts+1] = base
    return table.concat(parts, "-")
end

function HCOB.UI.ActionPanel.GetSlotKey(slot)
    slot = tonumber(slot)
    if not slot then return nil end
    local custom = HCOB_DB and HCOB_DB.actionSlotKeys
    if custom and custom[slot] ~= nil then
        if custom[slot] == false then return nil end
        return HCOB.UI.ActionPanel.NormalizeSlotKey(custom[slot])
    end
    return HCOB.UI.ActionPanel.defaultSlotKeys and HCOB.UI.ActionPanel.defaultSlotKeys[slot] or nil
end

function HCOB.UI.ActionPanel.GetSlotBindingCommand(slot)
    if not slot then return nil end
    return "CLICK HCOneButtonAdvisorAction" .. tostring(slot) .. ":LeftButton"
end

function HCOB.UI.ActionPanel.GetSlotActionName(slot)
    slot = tonumber(slot)
    local list = HCOB.UI.ActionPanel.actions[PLAYER_CLASS] or {}
    local id = slot and list[slot] or nil
    if not id then return "<unused slot>" end
    return SpellName(id, "Spell " .. tostring(id))
end

function HCOB.UI.ActionPanel.FindSlotUsingKey(key, exceptSlot)
    key = HCOB.UI.ActionPanel.NormalizeSlotKey(key)
    if not key then return nil end
    for slot=1,(HCOB.UI.ActionPanel.maxButtons or 20) do
        if slot ~= tonumber(exceptSlot) and HCOB.UI.ActionPanel.GetSlotKey(slot) == key then
            return slot
        end
    end
    return nil
end

function HCOB.UI.ActionPanel.ApplySlotBindings()
    if InCombatLockdown() then return false end
    if HCOB_DB and HCOB_DB.actionSlotAutoBind == false then return false end

    HCOB_DB.actionSlotAppliedKeys = HCOB_DB.actionSlotAppliedKeys or {}
    local visible = tonumber(HCOB.UI.ActionPanel.visibleCount) or 0
    local changed = false
    local overwritten = {}
    for slot=1,math.min(visible, HCOB.UI.ActionPanel.maxButtons or 20) do
        local key = HCOB.UI.ActionPanel.GetSlotKey(slot)
        local button = HCOB.UI.ActionPanel.buttons and HCOB.UI.ActionPanel.buttons[slot]
        local expected = HCOB.UI.ActionPanel.GetSlotBindingCommand(slot)
        local oldKey = HCOB_DB.actionSlotAppliedKeys[slot]

        -- On upgrade, the old default may already be saved in WoW bindings even
        -- before actionSlotAppliedKeys exists. Clear it only if it still points
        -- to this exact HCOB slot, never if the user reassigned it elsewhere.
        if not oldKey then oldKey = HCOB.UI.ActionPanel.defaultSlotKeys[slot] end
        oldKey = HCOB.UI.ActionPanel.NormalizeSlotKey(oldKey)
        if oldKey and oldKey ~= key and GetBindingAction and SetBinding then
            if GetBindingAction(oldKey) == expected then
                SetBinding(oldKey)
                changed = true
            end
        end

        if key and button then
            local current = GetBindingAction and GetBindingAction(key) or ""
            if current ~= expected and SetBindingClick then
                if SetBindingClick(key, "HCOneButtonAdvisorAction"..slot, "LeftButton") then
                    changed = true
                    if current and current ~= "" then
                        overwritten[#overwritten + 1] = string.format(
                            "%s (%s)", key:gsub("%-", "+"), tostring(current)
                        )
                    end
                end
            end
            button.bindingKey = key
            HCOB_DB.actionSlotAppliedKeys[slot] = key
        else
            if button then button.bindingKey = nil end
            HCOB_DB.actionSlotAppliedKeys[slot] = false
        end
    end

    -- SavedVariables are account-wide. A character/class with fewer fixed slots
    -- must release stale HCOB bindings left by a character with more slots.
    -- Clear only a key that still points to the exact HCOB slot command; never
    -- touch a key the user has rebound to another action.
    for slot=visible+1,(HCOB.UI.ActionPanel.maxButtons or 20) do
        local expected = HCOB.UI.ActionPanel.GetSlotBindingCommand(slot)
        local oldKey = HCOB_DB.actionSlotAppliedKeys[slot]
        if not oldKey then
            local custom = HCOB_DB.actionSlotKeys and HCOB_DB.actionSlotKeys[slot]
            oldKey = custom == false and nil or custom or HCOB.UI.ActionPanel.defaultSlotKeys[slot]
        end
        oldKey = HCOB.UI.ActionPanel.NormalizeSlotKey(oldKey)
        if oldKey and GetBindingAction and SetBinding and GetBindingAction(oldKey) == expected then
            SetBinding(oldKey)
            changed = true
        end
        local button = HCOB.UI.ActionPanel.buttons and HCOB.UI.ActionPanel.buttons[slot]
        if button then button.bindingKey = nil end
        HCOB_DB.actionSlotAppliedKeys[slot] = false
    end

    if changed and SaveBindings then
        local bindingSet = GetCurrentBindingSet and GetCurrentBindingSet() or 1
        SaveBindings(bindingSet)
    end

    if #overwritten > 0 then
        local shown = {}
        local limit = math.min(#overwritten, 6)
        for i = 1, limit do shown[#shown + 1] = overwritten[i] end
        local remaining = #overwritten - limit
        local suffix = remaining > 0 and string.format("; +%d more", remaining) or ""
        print(string.format(
            "|cffffcc00HCOB BINDING WARNING:|r auto-bind replaced %d existing binding(s): %s%s.",
            #overwritten, table.concat(shown, ", "), suffix
        ))
        print("|cffffcc00HCOB:|r review /hcob actions binds, or use /hcob actions bind off to stop automatic reapplication.")
    end
    return true, overwritten
end

function HCOB.UI.ActionPanel.SetSlotKey(slot, key)
    if InCombatLockdown() then return false, "Change bindings out of combat." end
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > (HCOB.UI.ActionPanel.maxButtons or 20) then
        return false, "Invalid slot."
    end

    key = HCOB.UI.ActionPanel.NormalizeSlotKey(key)
    if key then
        local duplicate = HCOB.UI.ActionPanel.FindSlotUsingKey(key, slot)
        if duplicate then
            return false, string.format("%s is already used by SLOT %02d.", key:gsub("%-", "+"), duplicate)
        end
    end

    HCOB_DB.actionSlotKeys = HCOB_DB.actionSlotKeys or {}
    local defaultKey = HCOB.UI.ActionPanel.defaultSlotKeys[slot]
    if key and key == defaultKey then
        HCOB_DB.actionSlotKeys[slot] = nil
    elseif key then
        HCOB_DB.actionSlotKeys[slot] = key
    else
        HCOB_DB.actionSlotKeys[slot] = false
    end

    if HCOB_DB.actionSlotAutoBind ~= false then HCOB.UI.ActionPanel.ApplySlotBindings() end
    return true
end

function HCOB.UI.ActionPanel.ResetSlotKey(slot)
    if InCombatLockdown() then return false, "Change bindings out of combat." end
    slot = tonumber(slot)
    if not slot then return false, "Invalid slot." end
    if HCOB_DB.actionSlotKeys then HCOB_DB.actionSlotKeys[slot] = nil end
    if HCOB_DB.actionSlotAutoBind ~= false then HCOB.UI.ActionPanel.ApplySlotBindings() end
    return true
end

function HCOB.UI.ActionPanel.ResetAllSlotKeys()
    if InCombatLockdown() then return false, "Change bindings out of combat." end
    HCOB_DB.actionSlotKeys = nil
    if HCOB_DB.actionSlotAutoBind ~= false then HCOB.UI.ActionPanel.ApplySlotBindings() end
    return true
end

function HCOB.UI.ActionPanel.PrintSlotBindings()
    local visible = tonumber(HCOB.UI.ActionPanel.visibleCount) or 0
    print("|cff00ff98HCOB ACTION BINDS:|r slot -> key -> action")
    for slot=1,math.min(visible, HCOB.UI.ActionPanel.maxButtons or 20) do
        local key = HCOB.UI.ActionPanel.GetSlotKey(slot)
        local b = HCOB.UI.ActionPanel.buttons and HCOB.UI.ActionPanel.buttons[slot]
        local name = b and b.actionName or HCOB.UI.ActionPanel.GetSlotActionName(slot)
        print(string.format("%02d -> %s -> %s", slot, key and key:gsub("%-", "+") or "<none>", tostring(name)))
    end
end

function HCOB.UI.ActionPanel.CapturedKey(base)
    base = tostring(base or ""):upper()
    local ignore = {LSHIFT=true,RSHIFT=true,LCTRL=true,RCTRL=true,LALT=true,RALT=true,SHIFT=true,CTRL=true,ALT=true}
    if ignore[base] then return nil end
    local mouseMap = {LEFTBUTTON="BUTTON1",RIGHTBUTTON="BUTTON2",MIDDLEBUTTON="BUTTON3",BUTTON4="BUTTON4",BUTTON5="BUTTON5"}
    base = mouseMap[base] or base
    local parts = {}
    if IsControlKeyDown and IsControlKeyDown() then parts[#parts+1] = "CTRL" end
    if IsAltKeyDown and IsAltKeyDown() then parts[#parts+1] = "ALT" end
    if IsShiftKeyDown and IsShiftKeyDown() then parts[#parts+1] = "SHIFT" end
    parts[#parts+1] = base
    return HCOB.UI.ActionPanel.NormalizeSlotKey(table.concat(parts, "-"))
end

function HCOB.UI.ActionPanel.RefreshBindingOptions()
    local panel = HCOB.UI.ActionPanel.bindingOptions
    if not panel then return end
    local visible = tonumber(HCOB.UI.ActionPanel.visibleCount) or #(HCOB.UI.ActionPanel.actions[PLAYER_CLASS] or {})
    if panel.classText then
        panel.classText:SetText(string.format("Class: %s | active slots: %d | fixed layout", tostring(PLAYER_CLASS), visible))
    end
    for slot,row in ipairs(panel.rows or {}) do
        local active = slot <= visible
        local key = HCOB.UI.ActionPanel.GetSlotKey(slot)
        local name = HCOB.UI.ActionPanel.GetSlotActionName(slot)
        row.slotText:SetText(string.format("%02d", slot))
        row.spellText:SetText(name)
        row.keyButton:SetText(key and key:gsub("%-", "+") or "<none>")
        row.keyButton:SetEnabled(active)
        row.defaultButton:SetEnabled(active)
        row.clearButton:SetEnabled(active)
        if active then
            row.spellText:SetTextColor(0.92,0.92,0.94)
            row.slotText:SetTextColor(1,0.82,0.20)
        else
            row.spellText:SetTextColor(0.40,0.40,0.43)
            row.slotText:SetTextColor(0.38,0.38,0.40)
        end
    end
    if panel.autoText then
        panel.autoText:SetText(HCOB_DB.actionSlotAutoBind ~= false and "Auto-bind: ON" or "Auto-bind: OFF")
        panel.autoText:SetTextColor(HCOB_DB.actionSlotAutoBind ~= false and 0.35 or 1.0, HCOB_DB.actionSlotAutoBind ~= false and 1.0 or 0.72, 0.45)
    end
end

function HCOB.UI.ActionPanel.BeginBindingCapture(slot)
    if InCombatLockdown() then
        print("|cffff5555HCOB:|r change bindings out of combat.")
        return
    end
    local panel = HCOB.UI.ActionPanel.bindingOptions
    if not panel or not panel.capture then return end
    panel.capture.slot = tonumber(slot)
    panel.captureText:SetText(string.format(
        "SLOT %02d - %s\n\nPress the new key combination.\nESC cancels | DEL/BACKSPACE clears the binding",
        tonumber(slot) or 0, HCOB.UI.ActionPanel.GetSlotActionName(slot)))
    panel.capture:Show()
    panel.capture:EnableKeyboard(true)
    if panel.capture.SetPropagateKeyboardInput then panel.capture:SetPropagateKeyboardInput(false) end
end

function HCOB.UI.ActionPanel.EndBindingCapture(message, isError)
    local panel = HCOB.UI.ActionPanel.bindingOptions
    if not panel or not panel.capture then return end
    panel.capture:EnableKeyboard(false)
    panel.capture:Hide()
    panel.capture.slot = nil
    if panel.status then
        panel.status:SetText(message or "")
        if isError then panel.status:SetTextColor(1,0.35,0.30) else panel.status:SetTextColor(0.35,1,0.55) end
    end
    HCOB.UI.ActionPanel.RefreshBindingOptions()
end

function HCOB.UI.ActionPanel.AcceptCapturedBinding(base)
    local panel = HCOB.UI.ActionPanel.bindingOptions
    local slot = panel and panel.capture and panel.capture.slot
    if not slot then return end
    base = tostring(base or ""):upper()
    if base == "ESCAPE" then
        HCOB.UI.ActionPanel.EndBindingCapture("Change cancelled.", false)
        return
    end
    if base == "DELETE" or base == "BACKSPACE" then
        local ok, err = HCOB.UI.ActionPanel.SetSlotKey(slot, false)
        HCOB.UI.ActionPanel.EndBindingCapture(ok and string.format("SLOT %02d has no binding.", slot) or err, not ok)
        return
    end
    local key = HCOB.UI.ActionPanel.CapturedKey(base)
    if not key then return end
    local previous = GetBindingAction and GetBindingAction(key) or ""
    local ok, err = HCOB.UI.ActionPanel.SetSlotKey(slot, key)
    if ok then
        local note = string.format("SLOT %02d -> %s", slot, key:gsub("%-", "+"))
        local own = HCOB.UI.ActionPanel.GetSlotBindingCommand(slot)
        if previous and previous ~= "" and previous ~= own then
            note = note .. " (replaced WoW binding: " .. tostring(previous) .. ")"
        end
        HCOB.UI.ActionPanel.EndBindingCapture(note, false)
    else
        HCOB.UI.ActionPanel.EndBindingCapture(err or "Invalid binding.", true)
    end
end

function HCOB.UI.ActionPanel.CreateBindingOptions()
    if HCOB.UI.ActionPanel.bindingOptions then return HCOB.UI.ActionPanel.bindingOptions end

    local panel = CreateFrame("Frame", "HCOneButtonActionBindingOptions", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(690, 760)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    panel:Hide()
    if panel.TitleText then panel.TitleText:SetText("HC One Button - Fixed Action Panel bindings") end

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -36)
    title:SetText("Fixed Action Panel bindings")

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
    hint:SetWidth(640)
    hint:SetJustifyH("LEFT")
    hint:SetText("Slots stay fixed per class. Warning: applying a key replaces its existing WoW/addon binding. Defaults: SHIFT+1...SHIFT+0 and CTRL+SHIFT+1...0.")

    panel.classText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    panel.classText:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)

    local hSlot = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hSlot:SetPoint("TOPLEFT", 26, -103)
    hSlot:SetText("SLOT")
    local hSpell = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hSpell:SetPoint("TOPLEFT", 76, -103)
    hSpell:SetText("FIXED ACTION")
    local hBind = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hBind:SetPoint("TOPLEFT", 330, -103)
    hBind:SetText("BINDING")

    panel.rows = {}
    for slot=1,(HCOB.UI.ActionPanel.maxButtons or 20) do
        local row = {}
        local y = -120 - (slot-1) * 27

        row.slotText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.slotText:SetPoint("TOPLEFT", 30, y-5)
        row.slotText:SetWidth(32)
        row.slotText:SetJustifyH("RIGHT")

        row.spellText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.spellText:SetPoint("TOPLEFT", 76, y-5)
        row.spellText:SetWidth(240)
        row.spellText:SetJustifyH("LEFT")

        row.keyButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        row.keyButton:SetSize(175, 23)
        row.keyButton:SetPoint("TOPLEFT", 326, y)
        row.keyButton:SetScript("OnClick", function() HCOB.UI.ActionPanel.BeginBindingCapture(slot) end)

        row.defaultButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        row.defaultButton:SetSize(74, 23)
        row.defaultButton:SetPoint("LEFT", row.keyButton, "RIGHT", 7, 0)
        row.defaultButton:SetText("Default")
        row.defaultButton:SetScript("OnClick", function()
            local ok, err = HCOB.UI.ActionPanel.ResetSlotKey(slot)
            if panel.status then
                panel.status:SetText(ok and string.format("SLOT %02d restored to default.", slot) or tostring(err))
                panel.status:SetTextColor(ok and 0.35 or 1, ok and 1 or 0.35, ok and 0.55 or 0.30)
            end
            HCOB.UI.ActionPanel.RefreshBindingOptions()
        end)

        row.clearButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        row.clearButton:SetSize(64, 23)
        row.clearButton:SetPoint("LEFT", row.defaultButton, "RIGHT", 5, 0)
        row.clearButton:SetText("None")
        row.clearButton:SetScript("OnClick", function()
            local ok, err = HCOB.UI.ActionPanel.SetSlotKey(slot, false)
            if panel.status then
                panel.status:SetText(ok and string.format("SLOT %02d has no binding.", slot) or tostring(err))
                panel.status:SetTextColor(ok and 0.35 or 1, ok and 1 or 0.35, ok and 0.55 or 0.30)
            end
            HCOB.UI.ActionPanel.RefreshBindingOptions()
        end)

        panel.rows[slot] = row
    end

    panel.autoText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.autoText:SetPoint("BOTTOMLEFT", 26, 48)

    panel.status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.status:SetPoint("BOTTOMLEFT", 160, 48)
    panel.status:SetWidth(350)
    panel.status:SetJustifyH("LEFT")
    panel.status:SetText("")

    local resetAll = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetAll:SetSize(145, 25)
    resetAll:SetPoint("BOTTOMRIGHT", -112, 17)
    resetAll:SetText("Reset all")
    resetAll:SetScript("OnClick", function()
        local ok, err = HCOB.UI.ActionPanel.ResetAllSlotKeys()
        panel.status:SetText(ok and "All bindings restored to defaults." or tostring(err))
        panel.status:SetTextColor(ok and 0.35 or 1, ok and 1 or 0.35, ok and 0.55 or 0.30)
        HCOB.UI.ActionPanel.RefreshBindingOptions()
    end)

    local close = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    close:SetSize(90, 25)
    close:SetPoint("BOTTOMRIGHT", -16, 17)
    close:SetText("Close")
    close:SetScript("OnClick", function()
        local windows = HCOB.UI and HCOB.UI.WindowManager
        if windows and windows.Close then windows.Close("bindings") else panel:Hide() end
    end)
    panel.closeButton = close

    panel.capture = CreateFrame("Frame", nil, panel)
    panel.capture:SetAllPoints(panel)
    panel.capture:SetFrameLevel(panel:GetFrameLevel() + 20)
    panel.capture:EnableMouse(true)
    panel.capture:EnableKeyboard(false)
    panel.capture:EnableMouseWheel(true)
    panel.capture:Hide()

    local captureBG = panel.capture:CreateTexture(nil, "BACKGROUND")
    captureBG:SetAllPoints()
    captureBG:SetColorTexture(0,0,0,0.88)
    panel.captureText = panel.capture:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.captureText:SetPoint("CENTER", 0, 10)
    panel.captureText:SetWidth(560)
    panel.captureText:SetJustifyH("CENTER")
    panel.captureText:SetTextColor(1,0.85,0.25)

    panel.capture:SetScript("OnKeyDown", function(_, key) HCOB.UI.ActionPanel.AcceptCapturedBinding(key) end)
    panel.capture:SetScript("OnMouseDown", function(_, button)
        HCOB.UI.ActionPanel.AcceptCapturedBinding(button)
    end)
    panel.capture:SetScript("OnMouseWheel", function(_, delta)
        HCOB.UI.ActionPanel.AcceptCapturedBinding(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
    end)

    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:SetScript("OnEvent", function(self)
        if self.capture and self.capture:IsShown() then
            self.capture:EnableKeyboard(false)
            self.capture:Hide()
        end
        local windows = HCOB.UI and HCOB.UI.WindowManager
        if windows and windows.Close then windows.Close("bindings", false) else self:Hide() end
        print("|cffffcc00HCOB:|r binding configuration closed because combat started.")
    end)
    panel:SetScript("OnShow", function() HCOB.UI.ActionPanel.RefreshBindingOptions() end)
    HCOB.UI.ActionPanel.bindingOptions = panel
    if HCOB.UI and HCOB.UI.WindowManager and HCOB.UI.WindowManager.Register then
        HCOB.UI.WindowManager.Register("bindings", panel)
    end
    return panel
end

function HCOB.UI.ActionPanel.OpenBindingOptions(fromOptions)
    if InCombatLockdown() then
        print("|cffffcc00HCOB:|r open panel bindings out of combat.")
        return
    end
    local panel = HCOB.UI.ActionPanel.CreateBindingOptions()
    HCOB.UI.ActionPanel.RefreshBindingOptions()
    if panel.closeButton then panel.closeButton:SetText(fromOptions and "Back to Options" or "Close") end
    local windows = HCOB.UI and HCOB.UI.WindowManager
    if windows and windows.Open then
        if fromOptions then windows.OpenChild("bindings", "options") else windows.Open("bindings") end
    else
        panel:Show()
        panel:Raise()
    end
end

function HCOB.UI.ActionPanel.BuildMacro(id)
    if not id then return "/stopmacro" end

    local class = HCOB.Classes and HCOB.Classes[PLAYER_CLASS]
    if class and class.BuildActionPanelMacro then
        local macro = class:BuildActionPanelMacro(id)
        if macro then return macro end
    end

    if id == S.SHOOT then
        local name = SpellName(id)
        return name and ("/cast !" .. name) or "/stopmacro"
    end

    local selfTarget = {
        [S.BATTLE_SHOUT]=true,[S.BLOODRAGE]=true,[S.BERSERKER_RAGE]=true,[S.RETALIATION]=true,[S.SHIELD_WALL]=true,
        [S.BLESSING_MIGHT]=true,[S.DIVINE_PROTECTION]=true,[S.DIVINE_SHIELD]=true,[S.LAY_ON_HANDS]=true,[S.HOLY_LIGHT]=true,[S.FLASH_LIGHT]=true,[S.SEAL_RIGHTEOUSNESS]=true,[S.SEAL_COMMAND]=true,[S.SEAL_CRUSADER]=true,
        [S.STEALTH]=true,[S.SPRINT]=true,[S.EVASION]=true,[S.VANISH]=true,
        [S.POWER_WORD_SHIELD]=true,[S.RENEW]=true,[S.FORTITUDE]=true,[S.FADE]=true,[S.LESSER_HEAL]=true,[S.HEAL]=true,[S.FLASH_HEAL]=true,[S.INNER_FIRE]=true,
        [S.ICE_BARRIER]=true,[S.MANA_SHIELD]=true,[S.ICE_BLOCK]=true,[S.COLD_SNAP]=true,[S.EVOCATION]=true,
        [S.LIFE_TAP]=true,[S.DEMON_ARMOR]=true,[S.DEMON_SKIN]=true,
        [S.BARKSKIN]=true,[S.NATURES_GRASP]=true,[S.DASH]=true,[S.TRAVEL_FORM]=true,[S.MARK_WILD]=true,
        [S.LIGHTNING_SHIELD]=true,[S.HEALING_WAVE]=true,[S.GHOST_WOLF]=true,[S.ROCKBITER_WEAPON]=true,[S.WINDFURY_WEAPON]=true,
        [S.ASPECT_HAWK]=true,[S.ASPECT_MONKEY]=true,[S.ASPECT_CHEETAH]=true,[S.RAPID_FIRE]=true,
    }
    if selfTarget[id] then return BuildSpellMacro(id, "@player") end

    if id == S.SPELL_LOCK then return BuildSpellMacro(id, "harm", false, true) end
    return BuildSpellMacro(id, "harm")
end

function HCOB.UI.ActionPanel.Configure()
    if InCombatLockdown() then return false end
    wipe(HCOB.UI.ActionPanel.idToButton)
    wipe(HCOB.UI.ActionPanel.idToSlot)
    wipe(HCOB.UI.ActionPanel.idToActionIndex)

    local list = HCOB.UI.ActionPanel.actions[PLAYER_CLASS] or {}
    -- v1.18.6: DETERMINISTIC layout. The slot always matches the logical index
    -- in the class list, even if the spell has not been learned yet.
    -- This prevents level/trainer changes from ever shifting bindings.
    local visible = math.min(#list, HCOB.UI.ActionPanel.maxButtons or 20)

    for slot=1,visible do
        local id = list[slot]
        local b = HCOB.UI.ActionPanel.buttons[slot]
        if b and id then
            local known = IsKnown(id) or id == S.SPELL_LOCK
            local macro = known and HCOB.UI.ActionPanel.BuildMacro(id) or "/stopmacro"

            b:SetAttribute("type1", "macro")
            b:SetAttribute("macrotext1", macro or "/stopmacro")
            b.actionId = id
            b.slotIndex = slot
            b.actionIndex = slot
            b.configured = true
            b.known = known and true or false
            b.actionName = SpellName(id, "Spell " .. tostring(id))
            b.icon:SetTexture(SpellIcon(id))
            b.recommended = false
            b.glow:Hide()
            if b.recommendedBG then b.recommendedBG:Hide() end
            if b.cooldown then b.cooldown:Hide() end
            if b.cdText then b.cdText:SetText("") end
            if b.rangeText then b.rangeText:SetText("") end

            if b.icon.SetDesaturated then b.icon:SetDesaturated(not b.known) end
            b.icon:SetAlpha(b.known and 1.0 or 0.18)
            b.border:SetVertexColor(b.known and 0.38 or 0.16, b.known and 0.38 or 0.16, b.known and 0.38 or 0.18, 0.95)
            b:Show()

            -- Mapping is always present, including spells not learned yet.
            HCOB.UI.ActionPanel.idToButton[id] = b
            HCOB.UI.ActionPanel.idToSlot[id] = slot
            HCOB.UI.ActionPanel.idToActionIndex[id] = slot
        end
    end

    -- Only slots beyond the fixed class table are hidden.
    for i=visible+1,HCOB.UI.ActionPanel.maxButtons do
        local b = HCOB.UI.ActionPanel.buttons[i]
        if b then
            b:SetAttribute("type1", "macro")
            b:SetAttribute("macrotext1", "/stopmacro")
            b.actionId = nil
            b.slotIndex = nil
            b.actionIndex = nil
            b.configured = false
            b.known = false
            b.actionName = nil
            b.recommended = false
            b.glow:Hide()
            if b.recommendedBG then b.recommendedBG:Hide() end
            if b.cooldown then b.cooldown:Hide() end
            if b.cdText then b.cdText:SetText("") end
            if b.rangeText then b.rangeText:SetText("") end
            b:Hide()
        end
    end

    HCOB.UI.ActionPanel.visibleCount = visible
    if HCOB.UI.ActionPanel.frame then
        local rows = math.max(1, math.ceil(visible / (HCOB.UI.ActionPanel.columns or 10)))
        local size = HCOB.UI.ActionPanel.buttonSize or 32
        local gap = HCOB.UI.ActionPanel.gap or 4
        local top = HCOB.UI.ActionPanel.topOffset or 8
        local bottom = 8
        HCOB.UI.ActionPanel.frame:SetHeight(top + rows * size + math.max(0, rows - 1) * gap + bottom)
    end
    HCOB.UI.ActionPanel.ApplySlotBindings()
    return true
end

function HCOB.UI.ActionPanel.Has(id)
    local b = id and HCOB.UI.ActionPanel.idToButton[id] or nil
    return b ~= nil and b.known == true
end

function HCOB.UI.ActionPanel.GetCooldown(id)
    if not id then return 0,0,false,0 end
    local startTime, duration, enabled, modRate
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
        if ok and cd then
            startTime, duration, enabled, modRate = cd.startTime, cd.duration, cd.isEnabled, cd.modRate
        end
    elseif GetSpellCooldown then
        startTime, duration, enabled, modRate = GetSpellCooldown(id)
    end
    startTime = SafeNumber(startTime, 0) or 0
    duration = SafeNumber(duration, 0) or 0
    modRate = SafeNumber(modRate, 1) or 1
    if enabled ~= nil and not CanAccessValue(enabled) then return 0,0,false,0 end
    if enabled == false or enabled == 0 then return startTime,duration,false,0 end
    local remaining = 0
    if startTime > 0 and duration > 0 then
        remaining = math.max(0, startTime + (duration / math.max(0.01, modRate)) - GetTime())
    end
    return startTime,duration,true,remaining
end

function HCOB.UI.ActionPanel.FormatCooldown(remaining)
    remaining = tonumber(remaining) or 0
    if remaining <= 1.6 then return "" end -- do not clutter every icon with the GCD
    if remaining >= 60 then return tostring(math.ceil(remaining / 60)) .. "m" end
    if remaining >= 10 then return tostring(math.ceil(remaining)) end
    return string.format("%.1f", remaining)
end

function HCOB.UI.ActionPanel.InRange(id)
    if not id or not UnitExists("target") or not UnitCanAttack("player","target") then return nil end
    return HCOB.Advisor.Engine.SpellRange(id, "target")
end

function HCOB.UI.ActionPanel.Highlight(id)
    for _, b in ipairs(HCOB.UI.ActionPanel.buttons) do
        if b then
            b.recommended = (id and b.actionId == id and b.known == true) and true or false
            if b.recommended then
                b.glow:SetVertexColor(1,0.82,0.10)
                b.glow:Show()
                if b.recommendedBG then b.recommendedBG:Show() end
            else
                b.glow:Hide()
                if b.recommendedBG then b.recommendedBG:Hide() end
            end
        end
    end
end

function HCOB.UI.ActionPanel.UpdateStates()
    local now = GetTime()
    for _, b in ipairs(HCOB.UI.ActionPanel.buttons) do
        if b and b.configured and b.actionId then
            local known = IsKnown(b.actionId) or b.actionId == S.SPELL_LOCK
            b.known = known and true or false
            local startTime, duration, enabled, remaining = HCOB.UI.ActionPanel.GetCooldown(b.actionId)
            local usable = known and IsUsable(b.actionId) or false
            local inRange = known and HCOB.UI.ActionPanel.InRange(b.actionId) or nil

            if b.cooldown then
                if enabled and startTime > 0 and duration > 0 and remaining > 0.05 then
                    b.cooldown:SetCooldown(startTime, duration)
                    b.cooldown:Show()
                else
                    b.cooldown:Hide()
                end
            end
            if b.cdText then b.cdText:SetText(HCOB.UI.ActionPanel.FormatCooldown(remaining)) end
            if b.rangeText then b.rangeText:SetText(inRange == false and "R" or "") end

            if b.icon.SetDesaturated then b.icon:SetDesaturated(not usable) end
            if not known then
                b.icon:SetAlpha(0.18)
            else
                b.icon:SetAlpha(usable and 1.0 or 0.42)
            end

            if b.recommended and known then
                b.border:SetVertexColor(1,0.72,0.08,1)
                b.glow:SetAlpha(0.62 + 0.30 * math.abs(math.sin(now * 4.5)))
            elseif not known then
                b.border:SetVertexColor(0.16,0.16,0.18,0.72)
            elseif inRange == false then
                b.border:SetVertexColor(0.95,0.12,0.08,1)
            elseif not usable then
                b.border:SetVertexColor(0.28,0.28,0.30,0.82)
            elseif remaining > 1.6 then
                b.border:SetVertexColor(0.25,0.42,0.62,0.92)
            else
                b.border:SetVertexColor(0.42,0.48,0.52,0.95)
            end
        end
    end
end

function HCOB.UI.ActionPanel.SyncVisibility()
    if InCombatLockdown() then return end
    if not HCOB.UI.ActionPanel.frame then return end
    local show = HCOB_DB.visible and HCOB_DB.showAdvisor ~= false and HCOB_DB.secureActions ~= false
    if show then HCOB.UI.ActionPanel.frame:Show() else HCOB.UI.ActionPanel.frame:Hide() end
    for _, b in ipairs(HCOB.UI.ActionPanel.buttons) do
        if b then
            if show and b.configured then b:Show() else b:Hide() end
        end
    end
end

-- Secure action palette: created inside a separate function to avoid
-- consuming locals/registers in the main chunk (Classic has a tight limit).
function HCOB.UI.ActionPanel.CreateFrames()
    HCOB.UI.ActionPanel.columns = 10
    HCOB.UI.ActionPanel.buttonSize = 32
    HCOB.UI.ActionPanel.gap = 4
    -- v1.18.2: no text header; the panel contains only icons.
    HCOB.UI.ActionPanel.topOffset = 8

    -- v1.27.1: compact combat layout. The deterministic 1-20 slot order is
    -- unchanged, but ten smaller icons fit per row so every class uses at
    -- most two rows. This substantially reduces vertical screen occlusion.
    local rowWidth = HCOB.UI.ActionPanel.columns * HCOB.UI.ActionPanel.buttonSize
        + (HCOB.UI.ActionPanel.columns - 1) * HCOB.UI.ActionPanel.gap
    local width = (HCOB_CoreShell and HCOB_CoreShell.GetWidth and HCOB_CoreShell:GetWidth()) or 376
    HCOB.UI.ActionPanel.padding = math.max(8, (width - rowWidth) / 2)
    HCOB.UI.ActionPanel.frame = CreateFrame("Frame", "HCOneButtonAdvisorActions", UIParent)
    HCOB.UI.ActionPanel.frame:SetSize(width, 60)
    HCOB.UI.ActionPanel.frame:SetPoint("TOP", HCOB_CoreShell, "BOTTOM", 0, -4)
    HCOB.UI.ActionPanel.frame:SetFrameStrata("HIGH")
    HCOB.UI.ActionPanel.frame:EnableMouse(false)

    HCOB.UI.ActionPanel.bg = HCOB.UI.ActionPanel.frame:CreateTexture(nil, "BACKGROUND")
    HCOB.UI.ActionPanel.bg:SetAllPoints()
    HCOB.UI.ActionPanel.bg:SetColorTexture(0.012,0.014,0.018,0.96)
    HCOB_MakeRectBorder(HCOB.UI.ActionPanel.frame, 0.28,0.38,0.48,0.88)
    for i=1,HCOB.UI.ActionPanel.maxButtons do
        local b = CreateFrame("Button", "HCOneButtonAdvisorAction"..i, UIParent, "SecureActionButtonTemplate")
        b:SetSize(HCOB.UI.ActionPanel.buttonSize,HCOB.UI.ActionPanel.buttonSize)
        local col = (i-1) % HCOB.UI.ActionPanel.columns
        local row = math.floor((i-1) / HCOB.UI.ActionPanel.columns)
        b:SetPoint("TOPLEFT", HCOB.UI.ActionPanel.frame, "TOPLEFT",
            HCOB.UI.ActionPanel.padding + col * (HCOB.UI.ActionPanel.buttonSize + HCOB.UI.ActionPanel.gap),
            -HCOB.UI.ActionPanel.topOffset - row * (HCOB.UI.ActionPanel.buttonSize + HCOB.UI.ActionPanel.gap))
        b:SetFrameStrata("HIGH")
        b:RegisterForClicks("AnyDown", "AnyUp")
        b:SetAttribute("useOnKeyDown", hcobUseKeyDown)

        b.bg = b:CreateTexture(nil,"BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(0.025,0.028,0.034,0.99)
        b.icon = b:CreateTexture(nil,"ARTWORK")
        b.icon:SetPoint("TOPLEFT",3,-3)
        b.icon:SetPoint("BOTTOMRIGHT",-3,3)
        b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

        b.recommendedBG = b:CreateTexture(nil,"ARTWORK")
        b.recommendedBG:SetAllPoints(b.icon)
        b.recommendedBG:SetColorTexture(1,0.72,0.02,0.13)
        b.recommendedBG:Hide()

        b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        b.cooldown:SetAllPoints(b.icon)
        if b.cooldown.SetDrawEdge then b.cooldown:SetDrawEdge(true) end
        if b.cooldown.SetDrawSwipe then b.cooldown:SetDrawSwipe(true) end
        if b.cooldown.SetHideCountdownNumbers then b.cooldown:SetHideCountdownNumbers(true) end
        b.cooldown:Hide()

        b.cdText = b:CreateFontString(nil,"OVERLAY","GameFontNormal")
        b.cdText:SetPoint("CENTER",0,0)
        b.cdText:SetJustifyH("CENTER")
        b.cdText:SetTextColor(1,0.92,0.72)
        if b.cdText.SetShadowOffset then b.cdText:SetShadowOffset(1,-1) end
        b.cdText:SetText("")

        b.rangeText = b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        b.rangeText:SetPoint("BOTTOMRIGHT",-4,4)
        b.rangeText:SetTextColor(1,0.18,0.12)
        b.rangeText:SetText("")

        b.border = b:CreateTexture(nil,"OVERLAY")
        b.border:SetAllPoints()
        b.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        b.border:SetVertexColor(0.42,0.48,0.52,0.95)
        b.glow = b:CreateTexture(nil,"OVERLAY")
        b.glow:SetPoint("TOPLEFT",-7,7)
        b.glow:SetPoint("BOTTOMRIGHT",7,-7)
        b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        b.glow:SetBlendMode("ADD")
        b.glow:SetAlpha(0.90)
        b.glow:Hide()
        b:SetScript("OnEnter", function(self)
            if GameTooltip and self.actionName then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetText(self.actionName,1,0.82,0.15)
                if self.bindingKey then
                    GameTooltip:AddLine("Bind: " .. tostring(self.bindingKey):gsub("%-", "+"),0.45,0.85,1)
                end
                if self.actionId and not IsKnown(self.actionId) and self.actionId ~= S.SPELL_LOCK then
                    GameTooltip:AddLine("NOT LEARNED YET - reserved slot",0.65,0.65,0.68)
                else
                    GameTooltip:AddLine("Click to execute the HCOB action",0.75,0.85,1)
                end
                local _, _, _, remaining = HCOB.UI.ActionPanel.GetCooldown(self.actionId)
                if remaining and remaining > 0.05 then
                    GameTooltip:AddLine("Cooldown: "..HCOB.UI.ActionPanel.FormatCooldown(remaining),1,0.75,0.30)
                else
                    GameTooltip:AddLine("Cooldown: ready",0.45,1,0.45)
                end
                local range = HCOB.UI.ActionPanel.InRange(self.actionId)
                if range == false then GameTooltip:AddLine("Out of range",1,0.25,0.20) end
                if not IsUsable(self.actionId) then GameTooltip:AddLine("Not usable now (resource/condition)",0.70,0.70,0.70) end
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        HCOB.UI.ActionPanel.buttons[i] = b
    end
end
HCOB.UI.ActionPanel.CreateFrames()
