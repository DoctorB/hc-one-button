-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

advisor = CreateFrame("Frame", nil, UIParent)
advisor:SetSize(282, 82)
advisor:SetPoint("TOPLEFT", btn, "TOPRIGHT", 4, 0)
advisor:SetFrameStrata("HIGH")
advisor:SetFrameLevel(5)
advisor:EnableMouse(false)

advisorBG = advisor:CreateTexture(nil, "BACKGROUND")
advisorBG:SetAllPoints()
advisorBG:SetColorTexture(0, 0, 0, 0)

-- Border is owned by HCOB_CoreShell in the unified HUD.

advisorGlow = advisor:CreateTexture(nil, "OVERLAY")
advisorGlow:SetPoint("TOPLEFT", -6, 6)
advisorGlow:SetPoint("BOTTOMRIGHT", 6, -6)
advisorGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
advisorGlow:SetBlendMode("ADD")
advisorGlow:SetAlpha(0.72)
advisorGlow:Hide()

advisorIcon = advisor:CreateTexture(nil, "ARTWORK")
advisorIcon:SetSize(58, 58)
advisorIcon:SetPoint("LEFT", advisor, "LEFT", 9, 0)
advisorIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
advisor.iconBorder = advisor:CreateTexture(nil, "OVERLAY")
advisor.iconBorder:SetPoint("TOPLEFT", advisorIcon, "TOPLEFT", -3, 3)
advisor.iconBorder:SetPoint("BOTTOMRIGHT", advisorIcon, "BOTTOMRIGHT", 3, -3)
advisor.iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
advisor.iconBorder:SetVertexColor(0.42, 0.48, 0.52, 0.95)

-- Badge piccolo: MANUALE / HCOB / BASE / DANGER / OK.
advisorBanner = advisor:CreateTexture(nil, "ARTWORK")
advisorBanner:SetPoint("TOPLEFT", advisorIcon, "TOPRIGHT", 9, 0)
advisorBanner:SetSize(92, 17)
advisorBanner:SetColorTexture(0.18, 0.18, 0.18, 0.98)

advisorMode = advisor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
advisorMode:SetPoint("CENTER", advisorBanner, "CENTER", 0, 0)
advisorMode:SetWidth(88)
advisorMode:SetJustifyH("CENTER")
advisorMode:SetText("OK")

advisorTitle = advisor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
advisorTitle:SetPoint("TOPLEFT", advisorBanner, "BOTTOMLEFT", 0, -3)
advisorTitle:SetWidth(202)
advisorTitle:SetHeight(18)
advisorTitle:SetJustifyH("LEFT")
advisorTitle:SetText("ADVISOR")

advisorKey = advisor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
advisorKey:SetPoint("TOPLEFT", advisorTitle, "BOTTOMLEFT", 0, -1)
advisorKey:SetWidth(202)
advisorKey:SetHeight(15)
advisorKey:SetJustifyH("LEFT")
advisorKey:SetText("SPAM BASE")

advisorReason = advisor:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
advisorReason:SetPoint("TOPLEFT", advisorKey, "BOTTOMLEFT", 0, -1)
advisorReason:SetWidth(202)
advisorReason:SetHeight(13)
advisorReason:SetJustifyH("LEFT")
advisorReason:SetText("No priority")

-- Mini DPS meter. Intentionally remains a single compact line.
dpsMeter = CreateFrame("Frame", nil, UIParent)
dpsMeter:SetSize(282, 24)
dpsMeter:SetPoint("TOPLEFT", advisor, "BOTTOMLEFT", 0, -4)
dpsMeter:SetFrameStrata("HIGH")
dpsMeter:SetFrameLevel(5)
dpsMeter:EnableMouse(false)

dpsBG = dpsMeter:CreateTexture(nil, "BACKGROUND")
dpsBG:SetAllPoints()
dpsBG:SetColorTexture(0.020, 0.023, 0.029, 0.88)

dpsMeter.topLine = dpsMeter:CreateTexture(nil, "BORDER")
dpsMeter.topLine:SetPoint("TOPLEFT", dpsMeter, "TOPLEFT", 0, 0)
dpsMeter.topLine:SetPoint("TOPRIGHT", dpsMeter, "TOPRIGHT", 0, 0)
dpsMeter.topLine:SetHeight(1)
dpsMeter.topLine:SetColorTexture(0.28, 0.38, 0.48, 0.65)

dpsValue = dpsMeter:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dpsValue:SetPoint("LEFT", dpsMeter, "LEFT", 8, 0)
dpsValue:SetWidth(76)
dpsValue:SetJustifyH("LEFT")
dpsValue:SetText("DPS --")

dpsMeta = dpsMeter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dpsMeta:SetPoint("LEFT", dpsValue, "RIGHT", 4, 0)
dpsMeta:SetPoint("RIGHT", dpsMeter, "RIGHT", -8, 0)
dpsMeta:SetJustifyH("RIGHT")
dpsMeta:SetText("AVG5 -- | DMG 0 | 0.0s")


function SetDisplay(spellId, title, keyHint, reason, kind)
    UpdateDiagnosticPixel(spellId)
    if HCOB.UI.ActionPanel then
        HCOB.UI.ActionPanel.Highlight(spellId)
        HCOB.UI.ActionPanel.UpdateStates()
    end
    if HCOB_DB.showAdvisor == false then return end

    -- Do not show a ? when there is simply no manual priority.
    -- While idle use the base action icon; for warnings without a spell use
    -- explicit UI textures. The question mark remains a true error fallback.
    local displayId = spellId
    local fallbackTexture
    if not displayId then
        if kind == "idle" then
            displayId = select(1, BaseActionInfo())
            fallbackTexture = "Interface\\RaidFrame\\ReadyCheck-Ready"
        elseif kind == "danger" then
            fallbackTexture = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
        elseif kind == "interrupt" then
            fallbackTexture = "Interface\\Icons\\Ability_Kick"
        else
            fallbackTexture = "Interface\\RaidFrame\\ReadyCheck-Ready"
        end
    end
    advisorIcon:SetTexture(SpellIcon(displayId, fallbackTexture))
    advisorTitle:SetText(title or "ADVISOR")
    advisorReason:SetText(reason or "")

    local actionHint = keyHint or "CAST MANUALLY"
    local baseKey = nil
    if GetBindingKey then baseKey = GetBindingKey("CLICK HCOneButtonFrame:LeftButton") end
    baseKey = baseKey or "HCOB KEY"
    local manual = (actionHint == "CAST MANUALLY")
    local clickable = HCOB_DB.secureActions ~= false and HCOB.UI.ActionPanel and HCOB.UI.ActionPanel.Has(spellId)
    local holdAction = (actionHint == "LET IT RUN")
    local baseAction = (actionHint == "PRESS BASE" or actionHint == "KEEP SPAMMING" or actionHint == "BASE SPAM OK")
    local modifier = (actionHint == "SHIFT" or actionHint == "CTRL" or actionHint == "ALT" or actionHint == "CTRL+SHIFT" or actionHint == "ALT+SHIFT" or actionHint == "ALT+CTRL" or actionHint == "CTRL+ALT+SHIFT")

    -- v1.27.2: CoreShell border is alert-only. Only CAUTION/DANGER (including
    -- critical recommendations represented as danger) render the outer frame.
    -- DANGER/CAUTION take precedence over input type. In v1.9 a warning
    -- Hamstring with ALT could appear blue like a normal "HCOB NOW":
    -- which was visually ambiguous exactly when clarity was needed.
    if kind == "danger" then
        advisorMode:SetText("HC DANGER")
        advisorMode:SetTextColor(1, 0.88, 0.88)
        advisorBanner:SetColorTexture(0.72, 0.015, 0.015, 1.0)
        advisorBG:SetColorTexture(0.13, 0.008, 0.008, 0.98)
        HCOB_SetRectBorderColor(HCOB_CoreShell, 1, 0.12, 0.08, 1)
        HCOB_SetRectBorderColor(dpsMeter, 1, 0.12, 0.08, 0.95)
        if clickable then
            advisorKey:SetText("CLICK HIGHLIGHTED ICON")
        elseif manual then
            advisorKey:SetText("PRESS FROM ACTION BAR")
        elseif modifier then
            advisorKey:SetText(actionHint .. " + " .. baseKey)
        else
            advisorKey:SetText(actionHint)
        end
        advisorKey:SetTextColor(1, 0.46, 0.38)
        advisorTitle:SetTextColor(1, 0.38, 0.24)
        advisor:SetAlpha(1.0)
        if advisorIcon.SetDesaturated then advisorIcon:SetDesaturated(false) end
    elseif kind == "caution" then
        advisorMode:SetText("HC CAUTION")
        advisorMode:SetTextColor(1, 0.92, 0.65)
        advisorBanner:SetColorTexture(0.62, 0.30, 0.015, 1.0)
        advisorBG:SetColorTexture(0.075, 0.045, 0.008, 0.97)
        HCOB_SetRectBorderColor(HCOB_CoreShell, 1, 0.62, 0.10, 0.98)
        HCOB_SetRectBorderColor(dpsMeter, 1, 0.62, 0.10, 0.90)
        if clickable then
            advisorKey:SetText("CLICK HIGHLIGHTED ICON")
        elseif manual then
            advisorKey:SetText("PRESS FROM ACTION BAR")
        elseif modifier then
            advisorKey:SetText(actionHint .. " + " .. baseKey)
        else
            advisorKey:SetText(actionHint)
        end
        advisorKey:SetTextColor(1, 0.78, 0.30)
        advisorTitle:SetTextColor(1, 0.78, 0.22)
        advisor:SetAlpha(1.0)
        if advisorIcon.SetDesaturated then advisorIcon:SetDesaturated(false) end
    elseif manual then
        advisorMode:SetText(clickable and "CLICK NOW" or "MANUAL NOW")
        advisorMode:SetTextColor(1, 0.90, 0.20)
        advisorBanner:SetColorTexture(0.62, 0.07, 0.02, 0.98)
        advisorBG:SetColorTexture(0.018, 0.018, 0.022, 0.95)
        HCOB_SetRectBorderColor(HCOB_CoreShell, 0, 0, 0, 0)
        HCOB_SetRectBorderColor(dpsMeter, 0.35, 0.35, 0.35, 0.85)
        advisorKey:SetText(clickable and "CLICK HIGHLIGHTED ICON" or "PRESS FROM ACTION BAR")
        advisorKey:SetTextColor(1, 0.92, 0.25)
        advisorTitle:SetTextColor(1, 0.82, 0)
        advisor:SetAlpha(1.0)
        if advisorIcon.SetDesaturated then advisorIcon:SetDesaturated(false) end
    elseif modifier then
        advisorMode:SetText("HCOB NOW")
        advisorMode:SetTextColor(0.85, 0.95, 1)
        advisorBanner:SetColorTexture(0.04, 0.28, 0.52, 0.98)
        advisorBG:SetColorTexture(0.018, 0.018, 0.022, 0.95)
        HCOB_SetRectBorderColor(HCOB_CoreShell, 0, 0, 0, 0)
        HCOB_SetRectBorderColor(dpsMeter, 0.35, 0.35, 0.35, 0.85)
        advisorKey:SetText(clickable and "CLICK HIGHLIGHTED ICON" or (actionHint .. " + " .. baseKey))
        advisorKey:SetTextColor(0.65, 0.90, 1)
        advisorTitle:SetTextColor(1, 0.82, 0)
        advisor:SetAlpha(1.0)
        if advisorIcon.SetDesaturated then advisorIcon:SetDesaturated(false) end
    elseif holdAction then
        advisorMode:SetText("AUTO ACTIVE")
        advisorMode:SetTextColor(0.72, 0.92, 1)
        advisorBanner:SetColorTexture(0.04, 0.24, 0.38, 0.96)
        advisorBG:SetColorTexture(0.018, 0.018, 0.022, 0.95)
        HCOB_SetRectBorderColor(HCOB_CoreShell, 0, 0, 0, 0)
        HCOB_SetRectBorderColor(dpsMeter, 0.35, 0.35, 0.35, 0.85)
        advisorKey:SetText("LET IT RUN")
        advisorKey:SetTextColor(0.70, 0.90, 1)
        advisorTitle:SetTextColor(0.80, 0.90, 1)
        advisor:SetAlpha(0.86)
        if advisorIcon.SetDesaturated then advisorIcon:SetDesaturated(false) end
    elseif baseAction then
        advisorMode:SetText(PLAYER_CLASS == "HUNTER" and "PULL" or "BASE SPAM")
        advisorMode:SetTextColor(0.75, 1, 0.75)
        advisorBanner:SetColorTexture(0.04, 0.35, 0.10, 0.96)
        advisorBG:SetColorTexture(0.018, 0.018, 0.022, 0.95)
        HCOB_SetRectBorderColor(HCOB_CoreShell, 0, 0, 0, 0)
        HCOB_SetRectBorderColor(dpsMeter, 0.35, 0.35, 0.35, 0.85)
        advisorKey:SetText((PLAYER_CLASS == "HUNTER" and "PRESS " or "SPAM ") .. baseKey)
        advisorKey:SetTextColor(0.65, 1, 0.65)
        advisorTitle:SetTextColor(1, 0.82, 0)
        advisor:SetAlpha(0.92)
        if advisorIcon.SetDesaturated then advisorIcon:SetDesaturated(false) end
    else
        advisorMode:SetText("OK")
        advisorMode:SetTextColor(0.65, 0.75, 0.80)
        advisorBanner:SetColorTexture(0.12, 0.14, 0.16, 0.94)
        advisorBG:SetColorTexture(0.018, 0.018, 0.022, 0.95)
        HCOB_SetRectBorderColor(HCOB_CoreShell, 0, 0, 0, 0)
        HCOB_SetRectBorderColor(dpsMeter, 0.35, 0.35, 0.35, 0.85)
        advisorKey:SetText("SPAM " .. baseKey)
        advisorKey:SetTextColor(0.65, 0.75, 0.8)
        advisorTitle:SetTextColor(0.75, 0.75, 0.75)
        advisor:SetAlpha(0.66)
        if advisorIcon.SetDesaturated then advisorIcon:SetDesaturated(true) end
    end

    if kind == "danger" then
        advisorGlow:SetVertexColor(1,0.1,0.1); advisorGlow:Show()
        advisorReason:SetTextColor(1, 0.8, 0.8)
    elseif kind == "caution" then
        advisorGlow:SetVertexColor(1,0.55,0.05); advisorGlow:Show()
        advisorReason:SetTextColor(1, 0.86, 0.55)
    elseif kind == "interrupt" then
        advisorGlow:SetVertexColor(1,0.45,0.05); advisorGlow:Show()
        advisorReason:SetTextColor(1, 0.88, 0.72)
    elseif kind == "buff" then
        advisorGlow:SetVertexColor(0.2,0.65,1); advisorGlow:Show()
        advisorReason:SetTextColor(0.82, 0.92, 1)
    elseif kind == "action" then
        advisorGlow:SetVertexColor(0.95,0.8,0.15); advisorGlow:Show()
        advisorReason:SetTextColor(1, 0.95, 0.8)
    else
        advisorGlow:Hide()
        advisorReason:SetTextColor(0.75,0.75,0.75)
    end
end

function ResourceDisplay()
    if PLAYER_CLASS == "ROGUE" then local v = SafeUnitPower("player", 3, nil); return v ~= nil and (tostring(v) .. "E") or "?E" end
    local pType, pToken = UnitPowerType("player")
    local value = SafeUnitPower("player", pType, nil)
    local maxv = SafeUnitPowerMax("player", pType, nil)
    if value == nil then return "?" end
    if pToken == "RAGE" then return tostring(value) .. "R" end
    if pToken == "ENERGY" then return tostring(value) .. "E" end
    if pToken == "MANA" then return maxv and maxv > 0 and (tostring(math.floor(value/maxv*100)) .. "%M") or "?M" end
    return tostring(value)
end

function UpdateStatusBars(hp)
    local hpPct = Clamp((hp or 0) / 100, 0, 1)
    local width = hpBarBG:GetWidth(); if not width or width <= 1 then width = 82 end
    hpBarFill:SetWidth(math.max(1, width * hpPct))
    if hp > (HCOB_DB.dangerHP or 35) then
        hpBarFill:SetColorTexture(0.18, 0.82, 0.22, 0.96)
    elseif hp > (HCOB_DB.criticalHP or 20) then
        hpBarFill:SetColorTexture(0.95, 0.72, 0.12, 0.96)
    else
        hpBarFill:SetColorTexture(0.92, 0.14, 0.14, 0.96)
    end

    local pType, pToken = UnitPowerType("player")
    local value = SafeUnitPower("player", pType, nil)
    local maxv = SafeUnitPowerMax("player", pType, nil)
    local pPct = (value ~= nil and maxv ~= nil) and Clamp(value / math.max(1, maxv), 0, 1) or 0
    powerBarFill:SetWidth(math.max(1, width * pPct))
    if pToken == "RAGE" then
        powerBarFill:SetColorTexture(0.82, 0.18, 0.18, 0.96)
    elseif pToken == "ENERGY" then
        powerBarFill:SetColorTexture(0.96, 0.84, 0.12, 0.96)
    elseif pToken == "MANA" then
        powerBarFill:SetColorTexture(0.2, 0.55, 1, 0.96)
    else
        powerBarFill:SetColorTexture(0.75, 0.35, 1, 0.96)
    end
end

function AutoAttackSpeed()
    if PLAYER_CLASS == "HUNTER" or HasWandEquipped() then
        if UnitRangedDamage then
            local ok, speed = pcall(UnitRangedDamage, "player")
            speed = ok and SafeNumber(speed, nil) or nil
            if speed and speed > 0 then return speed end
        end
    end
    if not UnitAttackSpeed then return nil end
    local ok, speed = pcall(UnitAttackSpeed, "player")
    return ok and SafeNumber(speed, nil) or nil
end

function UpdateSwingBar()
    if not HCOB_DB.showSwing then swingBG:Hide(); return end
    local speed = AutoAttackSpeed()
    if not speed or speed <= 0 or not lastAutoAttack then swingBG:Hide(); return end
    swingBG:Show()
    local elapsed = GetTime() - lastAutoAttack
    local pct = Clamp(elapsed / speed, 0, 1)
    local width = swingBG:GetWidth(); if not width or width <= 1 then width = 82 end
    swingFill:SetWidth(math.max(1, width * pct))
end

function UpdateDisplayMinimal(reason)
    if not UnitExists("player") then return end
    local hp, hpReadable = UnitHealthPct("player")
    hpText:SetText(hpReadable and (tostring(math.floor(hp)) .. "%") or "?%")
    local pType = UnitPowerType("player")
    local value = SafeUnitPower("player", pType, nil)
    resourceText:SetText(value ~= nil and tostring(value) or "?")
    enemyText:SetText("")
    UpdateStatusBars(hpReadable and hp or 0)
    UpdateBaseVisual()
    SetDisplay(nil, "ADVISOR OFF", "BASE SPAM OK", reason or "Smart HUD disabled", "idle")
    if HCOB_DB.showSwing then UpdateSwingBar() else swingBG:Hide() end
    UpdateDPSMeter()
end


function UpdateDisplayCore(recordTelemetrySample)
    if not UnitExists("player") then return end
    UpdateBaseVisual()
    if HCOB_DB.smartDisplay == false or runtimeSmartDisabled then
        return UpdateDisplayMinimal(runtimeSmartDisabled and "SAFE MODE: /hcob errors" or "Smart HUD disabled")
    end
    local hp, hpReadable = UnitHealthPct("player")
    local enemies = CountActiveEnemies()
    hpText:SetText(hpReadable and (tostring(math.floor(hp)) .. "%") or "?%")
    resourceText:SetText(ResourceDisplay())
    enemyText:SetText(enemies >= 2 and ("x" .. enemies) or "")
    UpdateStatusBars(hpReadable and hp or 0)
    local spellId, title, keyHint, reason, kind = Recommend()
    spellId, title, keyHint, reason, kind = HCOB.Advisor.Engine.Stabilize(spellId, title, keyHint, reason, kind)
    SetDisplay(spellId, title, keyHint, reason, kind)

    local telemetryReserve = nil
    if currentFight and HCOB_DB.combatLogging ~= false and not runtimeTelemetryDisabled then
        -- Event-driven refreshes still need the current reserve in the feedback
        -- trace, but only heartbeat refreshes contribute to time-sampled combat
        -- percentages/averages. This keeps 1.27 telemetry comparable even when
        -- UNIT_AURA or UNIT_POWER fire at different rates for different classes.
        local reserve = HCOB.Advisor.Engine.SurvivalReserve()
        telemetryReserve = tonumber(reserve)
        if recordTelemetrySample ~= false then
            currentFight.survivalReserveSamples = (tonumber(currentFight.survivalReserveSamples) or 0) + 1
            currentFight.survivalReserveSum = (tonumber(currentFight.survivalReserveSum) or 0) + (tonumber(reserve) or 0)
            currentFight.survivalReserveMin = math.min(tonumber(currentFight.survivalReserveMin) or 100, tonumber(reserve) or 100)
            currentFight.advisorSamples = (tonumber(currentFight.advisorSamples) or 0) + 1
            if kind == "danger" then
                currentFight.advisorDangerSamples = (tonumber(currentFight.advisorDangerSamples) or 0) + 1
            elseif kind == "caution" then
                currentFight.advisorCautionSamples = (tonumber(currentFight.advisorCautionSamples) or 0) + 1
            elseif kind == "interrupt" then
                currentFight.advisorInterruptSamples = (tonumber(currentFight.advisorInterruptSamples) or 0) + 1
            end
            if keyHint == "CAST MANUALLY" then
                currentFight.advisorManualSamples = (tonumber(currentFight.advisorManualSamples) or 0) + 1
            end
        end
    end

    if currentFight and HCOB.Systems and HCOB.Systems.Feedback and HCOB.Systems.Feedback.RecordRecommendation then
        local ok, err = pcall(HCOB.Systems.Feedback.RecordRecommendation, spellId, title, keyHint, reason, kind, telemetryReserve, enemies, hp, hpReadable)
        if not ok then RecordRuntimeError("FeedbackTrace", err) end
    end

    local recKey = tostring(spellId) .. ":" .. tostring(kind) .. ":" .. tostring(title)
    if recKey ~= lastRecommendationKey then
        if currentFight then
            if kind == "danger" then
                currentFight.advisorDangerEvents = (tonumber(currentFight.advisorDangerEvents) or 0) + 1
            elseif kind == "caution" then
                currentFight.advisorCautionEvents = (tonumber(currentFight.advisorCautionEvents) or 0) + 1
            end
        end
        if kind == "danger" then
            PlayAlert("danger")
        elseif kind == "interrupt" then
            PlayAlert("interrupt")
        end
        lastRecommendationKey = recKey
    end
    UpdateSwingBar()
    UpdateDPSMeter()
end


function UpdateDisplay(recordTelemetrySample)
    local ok = SafeRun("SmartHUD", UpdateDisplayCore, recordTelemetrySample)
    if not ok then
        -- A single Smart HUD error is enough to put it into safe mode.
        -- The SecureActionButton and macro remain independent and continue working.
        runtimeSmartDisabled = true
        pcall(UpdateDisplayMinimal, "SAFE MODE: HUD error caught")
    end
end

