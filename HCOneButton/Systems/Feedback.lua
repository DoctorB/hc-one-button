-- HCOneButton Feedback & Telemetry export system.
-- Builds anonymized, copy/paste-friendly diagnostic reports for CurseForge Issues.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

HCOB.Systems.Feedback = HCOB.Systems.Feedback or {}
local F = HCOB.Systems.Feedback

F.ISSUE_URL = "https://www.curseforge.com/wow/addons/hconebutton/issues"
F.MAX_TRACE_EVENTS = 32
F.MAX_REPORT_CHARS = 18000

local function CleanText(value, maxLen)
    if value == nil then return "" end
    local s = tostring(value):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("[\r\n\t]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
    if maxLen and #s > maxLen then s = s:sub(1, math.max(1, maxLen - 3)) .. "..." end
    return s
end

local function SafeFinite(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

local function ActionSlotForSpell(spellId)
    if not spellId then return nil end
    local panel = HCOB.UI and HCOB.UI.ActionPanel
    if panel and panel.idToSlot and panel.idToSlot[spellId] then return panel.idToSlot[spellId] end
    local list = panel and panel.actions and panel.actions[PLAYER_CLASS]
    if list then
        for slot, id in ipairs(list) do if id == spellId then return slot end end
    end
    return nil
end

local function CandidateSnapshot(spellId)
    local engine = HCOB.Advisor and HCOB.Advisor.Engine
    if not engine or not engine.lastCandidates or not engine.lastCandidateSelectionAt then return nil end
    if (GetTime() - engine.lastCandidateSelectionAt) > 0.12 then return nil end
    local first = engine.lastCandidates[1]
    if not first or first.id ~= spellId then return nil end

    local out = {}
    for i=1, math.min(3, #engine.lastCandidates) do
        local c = engine.lastCandidates[i]
        out[#out+1] = {
            slot = ActionSlotForSpell(c.id),
            title = CleanText(c.title or SpellName(c.id, "?"), 44),
            score = math.floor(((tonumber(c.effectiveScore) or tonumber(c.score) or 0) * 10) + 0.5) / 10,
            tag = CleanText(c.tag, 18),
        }
    end
    return out
end

function F.RecordRecommendation(spellId, title, keyHint, reason, kind, reserve, enemies, playerHP, playerHPReadable)
    if not currentFight or HCOB_DB.combatLogging == false or runtimeTelemetryDisabled then return end

    local slot = ActionSlotForSpell(spellId)
    local signature = table.concat({tostring(spellId or ""), tostring(slot or ""), tostring(kind or ""), tostring(title or "")}, ":")
    if currentFight._feedbackLastKey == signature then return end
    currentFight._feedbackLastKey = signature

    currentFight.advisorTrace = currentFight.advisorTrace or {}
    if #currentFight.advisorTrace >= F.MAX_TRACE_EVENTS then
        currentFight.advisorTraceDropped = (tonumber(currentFight.advisorTraceDropped) or 0) + 1
        return
    end

    local targetHP, targetReadable = nil, false
    if UnitExists("target") then targetHP, targetReadable = UnitHealthPct("target") end
    local dyn = HCOB.Advisor and HCOB.Advisor.Engine and HCOB.Advisor.Engine.lastDynamics or nil
    local entry = {
        t = math.max(0, GetTime() - (currentFight.startClock or GetTime())),
        slot = slot,
        spellId = tonumber(spellId),
        title = CleanText(title or (spellId and SpellName(spellId, "?")) or "BASE", 48),
        kind = CleanText(kind or "idle", 18),
        key = CleanText(keyHint, 30),
        reason = CleanText(reason, 120),
        reserve = SafeFinite(reserve),
        hp = playerHPReadable == false and nil or SafeFinite(playerHP),
        targetHP = targetReadable and SafeFinite(targetHP) or nil,
        enemies = tonumber(enemies) or CountActiveEnemies(),
        candidates = CandidateSnapshot(spellId),
    }
    if dyn and SafeFinite(dyn.confidence) and dyn.confidence >= 0.38 then
        entry.confidence = SafeFinite(dyn.confidence)
        entry.ttk = SafeFinite(dyn.ttk)
        entry.ttd = SafeFinite(dyn.ttd)
    end
    currentFight.advisorTrace[#currentFight.advisorTrace + 1] = entry
end

local function Add(lines, text)
    lines[#lines+1] = tostring(text or "")
end

local function Fmt(value, format, fallback)
    value = tonumber(value)
    if value == nil then return fallback or "?" end
    return string.format(format, value)
end

local function PowerSummary(f)
    if not f then return "?" end
    local token = CleanText(f.powerType or "Power", 20)
    return string.format("%s start/end/avg: %s / %s / %s",
        token,
        Fmt(f.powerStart, "%.0f"), Fmt(f.powerEnd, "%.0f"), Fmt(f.powerAvg, "%.1f"))
end

local function AddTrace(lines, f, detailed)
    local trace = f and f.advisorTrace or nil
    Add(lines, "Advisor recommendation trace:")
    if not trace or #trace == 0 then
        Add(lines, "  Not available (fight may have been recorded before HCOneButton 1.27.0).")
        return
    end

    local maxEvents = detailed and #trace or math.min(14, #trace)
    local startIndex = detailed and 1 or math.max(1, #trace - maxEvents + 1)
    for i=startIndex,#trace do
        local e = trace[i]
        local slot = e.slot and string.format("S%02d", e.slot) or "S--"
        local state = string.format("%5.1fs  %-3s  %-9s  %s", tonumber(e.t) or 0, slot, CleanText(e.kind, 9), CleanText(e.title, 42))
        local extras = {}
        if e.hp ~= nil then extras[#extras+1] = "HP " .. Fmt(e.hp, "%.0f%%") end
        if e.targetHP ~= nil then extras[#extras+1] = "THP " .. Fmt(e.targetHP, "%.0f%%") end
        if e.reserve ~= nil then extras[#extras+1] = "SR " .. Fmt(e.reserve, "%.0f") end
        if e.enemies ~= nil then extras[#extras+1] = "x" .. tostring(e.enemies) end
        if e.ttk ~= nil and e.ttk < 999 then extras[#extras+1] = "TTK " .. Fmt(e.ttk, "%.1fs") end
        if e.ttd ~= nil and e.ttd < 999 then extras[#extras+1] = "TTD " .. Fmt(e.ttd, "%.1fs") end
        if e.confidence ~= nil then extras[#extras+1] = "conf " .. Fmt(e.confidence * 100, "%.0f%%") end
        if #extras > 0 then state = state .. "  [" .. table.concat(extras, " | ") .. "]" end
        Add(lines, state)
        if e.reason and e.reason ~= "" then Add(lines, "         reason: " .. CleanText(e.reason, 120)) end
        if detailed and e.candidates and #e.candidates > 0 then
            local bits = {}
            for _, c in ipairs(e.candidates) do
                bits[#bits+1] = string.format("%s%s %.1f", c.slot and ("S" .. string.format("%02d", c.slot) .. " ") or "", CleanText(c.title, 28), tonumber(c.score) or 0)
            end
            Add(lines, "         top: " .. table.concat(bits, " | "))
        end
    end
    if not detailed and #trace > maxEvents then Add(lines, string.format("  ... %d earlier recommendation changes omitted; enable detailed telemetry to include them.", #trace - maxEvents)) end
    if (tonumber(f.advisorTraceDropped) or 0) > 0 then Add(lines, string.format("  Trace cap reached: %d additional changes were not stored.", tonumber(f.advisorTraceDropped) or 0)) end
end

local function AddAbilities(lines, f)
    local list = SortedAbilityList and SortedAbilityList(f) or {}
    Add(lines, "Ability telemetry:")
    if #list == 0 then Add(lines, "  No player ability telemetry recorded."); return end
    for i=1,math.min(10,#list) do
        local a = list[i]
        Add(lines, string.format("  %-28s casts=%d hits=%d crits=%d damage=%d misses=%d",
            CleanText(a.name or a.spellName or "Unknown", 28), tonumber(a.casts) or 0, tonumber(a.hits) or 0,
            tonumber(a.crits) or 0, tonumber(a.damage) or 0, tonumber(a.misses) or 0))
    end
end

local function AddFight(lines, f, detailed, label)
    if not f then
        Add(lines, (label or "Fight") .. ": no completed fight recorded.")
        return
    end
    Add(lines, string.format("%s: #%s", label or "Fight", tostring(f.id or "?")))
    Add(lines, string.format("  Duration: %s | DPS: %s | damage: %d | damage taken: %d | healing: %d",
        Fmt(f.duration, "%.1fs"), Fmt(f.dps, "%.1f"), tonumber(f.totalDamage) or 0, tonumber(f.damageTaken) or 0, tonumber(f.healingDone) or 0))
    Add(lines, string.format("  Min HP: %s | max enemies: %d | kills: %d | died: %s",
        Fmt(f.hpMinPct, "%.1f%%"), tonumber(f.maxEnemies) or 1, tonumber(f.kills) or 0, tostring(f.died == true)))
    Add(lines, "  " .. PowerSummary(f))
    if f.targetLevel ~= nil or f.targetClassification then
        Add(lines, string.format("  Initial target: level %s | classification %s (name/GUID omitted)", tostring(f.targetLevel or "?"), CleanText(f.targetClassification or "?", 20)))
    end
    if f.survivalReserveAvg ~= nil then
        Add(lines, string.format("  Survival Reserve avg/min: %.1f / %.1f", tonumber(f.survivalReserveAvg) or 0, tonumber(f.survivalReserveMin) or 0))
    end
    if f.advisorDangerPct ~= nil then
        Add(lines, string.format("  Advisor states: DANGER %.1f%% | CAUTION %.1f%% | INTERRUPT %.1f%% | manual %.1f%%",
            tonumber(f.advisorDangerPct) or 0, tonumber(f.advisorCautionPct) or 0,
            tonumber(f.advisorInterruptPct) or 0, tonumber(f.advisorManualPct) or 0))
    end
    AddTrace(lines, f, detailed)
    if detailed then AddAbilities(lines, f) end
end

local function AddRuntimeErrors(lines)
    Add(lines, "Runtime fail-safe:")
    Add(lines, string.format("  SmartSafe=%s | CombatLogSafe=%s | TelemetrySafe=%s | caught errors=%d",
        tostring(runtimeSmartDisabled), tostring(runtimeCombatLogDisabled), tostring(runtimeTelemetryDisabled), #(runtimeErrors or {})))
    if runtimeErrors and #runtimeErrors > 0 then
        for i=math.max(1,#runtimeErrors-4),#runtimeErrors do
            local e = runtimeErrors[i]
            Add(lines, string.format("  [%s] %s", CleanText(e.area, 40), CleanText(e.message, 280)))
        end
    else
        Add(lines, "  None recorded this session.")
    end
end

local function TruncateReport(text)
    if #text <= F.MAX_REPORT_CHARS then return text end
    return text:sub(1, F.MAX_REPORT_CHARS - 140) .. "\n\n[REPORT TRUNCATED BY HCOneButton TO KEEP THE ISSUE COPY/PASTE MANAGEABLE]\n"
end

function F.GenerateReport(mode, detailed)
    InitCombatLogDB()
    mode = mode == "recent" and "recent" or "last"
    detailed = detailed and true or false

    local _, localizedClass = UnitClass("player")
    local specIndex, specName = TalentSpec()
    local clientVersion, clientBuild, clientDate, interfaceVersion = nil, nil, nil, nil
    if GetBuildInfo then clientVersion, clientBuild, clientDate, interfaceVersion = GetBuildInfo() end

    local lines = {}
    Add(lines, "HCOneButton Diagnostic Report")
    Add(lines, "============================")
    Add(lines, "Addon version: " .. tostring(VERSION))
    Add(lines, "Interface: " .. tostring(interfaceVersion or 11509))
    Add(lines, "Client: " .. CleanText(clientVersion or "?", 30) .. " build " .. CleanText(clientBuild or "?", 20))
    Add(lines, "Class: " .. tostring(PLAYER_CLASS or localizedClass or "?") .. " | Level: " .. tostring(PlayerLevel()) .. " | Spec: " .. CleanText(specName or "Unknown", 32) .. " (tab " .. tostring(specIndex or 0) .. ")")
    Add(lines, "Locale: " .. tostring(GetLocale and GetLocale() or "?"))
    Add(lines, "Combat logger: " .. (HCOB_DB.combatLogging ~= false and "ON" or "OFF"))
    Add(lines, "Report mode: " .. (mode == "recent" and "recent fights" or "last fight") .. " | detailed telemetry: " .. tostring(detailed))
    Add(lines, "Privacy: character name/realm, target names/GUIDs, zone/subzone and equipment item IDs are not exported.")
    Add(lines, "")

    local fights = HCOB_CombatLog.fights or {}
    if #fights == 0 then
        Add(lines, "No completed combat telemetry is available.")
        Add(lines, "Reproduce the issue with Combat logger enabled, finish the fight, then generate the report again.")
    elseif mode == "recent" then
        local count = math.min(detailed and 5 or 3, #fights)
        Add(lines, string.format("Recent fights included: %d", count))
        Add(lines, "")
        for i=#fights-count+1,#fights do
            AddFight(lines, fights[i], detailed, "Fight " .. tostring(i - (#fights-count)))
            Add(lines, "")
        end
    else
        AddFight(lines, fights[#fights], detailed, "Last fight")
    end

    Add(lines, "")
    AddRuntimeErrors(lines)
    Add(lines, "")
    Add(lines, "Issue page: " .. F.ISSUE_URL)
    Add(lines, "Please describe what you expected HCOneButton to recommend/do above this diagnostic block when creating the issue.")
    return TruncateReport(table.concat(lines, "\n"))
end

function F.GetIssueURL()
    return F.ISSUE_URL
end
