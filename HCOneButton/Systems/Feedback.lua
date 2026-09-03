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

local function TableCount(values)
    local count = 0
    for _ in pairs(values or {}) do count = count + 1 end
    return count
end

local function AddAdaptiveTelemetry(lines, f, detailed)
    local tuning = f and f.tuning
    if type(tuning) ~= "table" then
        Add(lines, "Adaptive telemetry: not available for this fight.")
        return
    end
    local eligibility = type(tuning.eligibility) == "table" and tuning.eligibility or {}
    local adherence = tuning.adherencePct ~= nil and Fmt(tuning.adherencePct, "%.1f%%") or "n/a"
    Add(lines, string.format(
        "Adaptive telemetry: contract %s | mode %s | eligible %s | adherence %s (%d/%d correlated actions)",
        tostring(tuning.contract or "?"), CleanText(eligibility.mode or "?", 12),
        tostring(eligibility.adaptive == true), adherence,
        tonumber(tuning.matchedActions) or 0, tonumber(tuning.comparableActions) or 0))
    Add(lines, string.format("  Decisions/candidates: %d/%d | action/input trace: %d/%d | dropped: %d/%d",
        TableCount(tuning.decisions), TableCount(tuning.candidates), #(tuning.actions or {}), #(tuning.inputs or {}),
        tonumber(tuning.actionTraceDropped) or 0, tonumber(tuning.inputTraceDropped) or 0))
    if eligibility.reasons and #eligibility.reasons > 0 then
        Add(lines, "  Eligibility filters: " .. CleanText(table.concat(eligibility.reasons, ", "), 180))
    end
    if not detailed then return end

    for token, resource in pairs(tuning.resources or {}) do
        Add(lines, string.format("  Resource %-10s avg/min/max %.1f / %.0f / %.0f | cap %.1f%% (%d samples)",
            CleanText(token, 10), tonumber(resource.average) or 0, tonumber(resource.min) or 0,
            tonumber(resource.max) or 0, tonumber(resource.capPct) or 0, tonumber(resource.samples) or 0))
    end
    local metrics = {}
    for name, metric in pairs(tuning.metrics or {}) do metrics[#metrics + 1] = {name=name, metric=metric} end
    table.sort(metrics, function(a, b) return tostring(a.name) < tostring(b.name) end)
    for i=1,math.min(12, #metrics) do
        local item, metric = metrics[i], metrics[i].metric or {}
        if metric.kind == "distribution" then
            local count = math.max(1, tonumber(metric.count) or 0)
            Add(lines, string.format("  Metric %s: avg/min/max %.2f / %.2f / %.2f (%d)",
                CleanText(item.name, 56), (tonumber(metric.sum) or 0) / count,
                tonumber(metric.min) or 0, tonumber(metric.max) or 0, tonumber(metric.count) or 0))
        else
            Add(lines, string.format("  Metric %s: %.2f", CleanText(item.name, 56), tonumber(metric.value) or 0))
        end
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
    AddAdaptiveTelemetry(lines, f, detailed)
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

local function DoctorError(value, maxLen)
    local message = CleanText(value, maxLen or 160)
    return message:match(":%d+:%s*(.+)$") or message
end

local function DoctorValue(fn, ...)
    if type(fn) ~= "function" then return nil, "unavailable" end
    local ok, value = pcall(fn, ...)
    if not ok then return nil, "ERROR: " .. DoctorError(value, 160) end
    if value ~= nil and type(value) ~= "table" and CanAccessValue then
        local accessOK, readable = pcall(CanAccessValue, value)
        if accessOK and readable == false then return nil, "restricted" end
    end
    return value, nil
end

local function DoctorText(value, problem)
    if problem then return problem end
    if value == nil then return "nil" end
    return CleanText(value, 180)
end

local function DoctorBoolean(fn, ...)
    local value, problem = DoctorValue(fn, ...)
    if problem then return problem end
    return tostring(value == true or value == 1)
end

local function DoctorBindings(command)
    if not GetBindingKey then return "unavailable" end
    local ok, first, second = pcall(GetBindingKey, command)
    if not ok then return "ERROR: " .. DoctorError(first, 160) end
    local keys = {}
    if first and first ~= "" then keys[#keys+1] = tostring(first) end
    if second and second ~= "" then keys[#keys+1] = tostring(second) end
    return #keys > 0 and table.concat(keys, ", ") or "<none>"
end

local function DoctorSpellResolution(id, name)
    local resolvedId, rank
    if C_Spell and C_Spell.GetSpellInfo and name then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        if ok and type(info) == "table" then resolvedId = tonumber(info.spellID) end
    end
    if GetSpellInfo and (name or id) then
        local ok, _, legacyRank, _, _, _, _, legacyId = pcall(GetSpellInfo, name or id)
        if ok then
            if legacyRank and legacyRank ~= "" then rank = CleanText(legacyRank, 40) end
            if not resolvedId then resolvedId = tonumber(legacyId) end
        end
    end
    return resolvedId, rank
end

-- Read-only live snapshot for API behavior that cannot be reproduced by the
-- offline harnesses. It intentionally does not call InitCombatLogDB, rebuild
-- macros, save bindings, refresh frames or mutate SavedVariables.
function F.GenerateDoctorReport()
    local lines, warnings = {}, {}
    local function Warn(text) warnings[#warnings+1] = text end

    local localizedClass = DoctorValue(UnitClass, "player")
    local level = DoctorValue(PlayerLevel)
    local specIndex, specName = nil, nil
    if TalentSpec then
        local ok, index, name = pcall(TalentSpec)
        if ok then specIndex, specName = index, name else Warn("TalentSpec failed: " .. CleanText(index, 120)) end
    end

    local clientVersion, clientBuild, interfaceVersion = nil, nil, nil
    if GetBuildInfo then
        local ok, version, build, _, interface = pcall(GetBuildInfo)
        if ok then clientVersion, clientBuild, interfaceVersion = version, build, interface end
    end

    local class = HCOB.Classes and HCOB.Classes[PLAYER_CLASS]
    local baseId, baseDescription
    if class and class.GetBaseActionInfo then
        local ok, id, description = pcall(class.GetBaseActionInfo, class, specIndex)
        if ok then baseId, baseDescription = id, description else Warn("GetBaseActionInfo failed: " .. CleanText(id, 120)) end
    else
        Warn("active class BASE contract unavailable")
    end

    local baseName, baseNameProblem = DoctorValue(SpellName, baseId, "Unknown")
    local resolvedId, learnedRank = DoctorSpellResolution(baseId, baseName)
    if not baseId then Warn("BASE spell ID unavailable") end

    local engine = HCOB.Advisor and HCOB.Advisor.Engine
    local forceRanged = false
    if engine and engine.IsClassRangedBaseAction and baseId then
        local ok, result = pcall(engine.IsClassRangedBaseAction, baseId)
        if ok then forceRanged = result == true else Warn("class ranged-BASE probe failed: " .. CleanText(result, 120)) end
    end

    local minRange, maxRange, rangeBoundsProblem
    if engine and engine.SpellRangeBounds and baseId then
        local ok, minimum, maximum = pcall(engine.SpellRangeBounds, baseId)
        if ok then minRange, maxRange = minimum, maximum else rangeBoundsProblem = "ERROR: " .. CleanText(minimum, 160) end
    else
        rangeBoundsProblem = "unavailable"
    end

    local sharedRange, sharedRangeProblem
    if engine and engine.SpellRange and baseId then
        sharedRange, sharedRangeProblem = DoctorValue(engine.SpellRange, baseId, "target")
    else
        sharedRangeProblem = "unavailable"
    end

    local rangedState, rangedStateProblem
    if engine and engine.RangedActionState and baseId then
        rangedState, rangedStateProblem = DoctorValue(engine.RangedActionState, baseId, forceRanged)
    else
        rangedStateProblem = "unavailable"
    end

    local legacyRange, legacyRangeProblem = nil, "unavailable"
    if baseName then legacyRange, legacyRangeProblem = DoctorValue(IsSpellInRange, baseName, "target") end
    local cSpellRange, cSpellRangeProblem = nil, "unavailable"
    if C_Spell and C_Spell.IsSpellInRange and baseId then
        cSpellRange, cSpellRangeProblem = DoctorValue(C_Spell.IsSpellInRange, baseId, "target")
    end
    if legacyRangeProblem and legacyRangeProblem:find("^ERROR:") then Warn("legacy range API failed") end
    if cSpellRangeProblem and cSpellRangeProblem:find("^ERROR:") then Warn("C_Spell range API failed") end

    local known, knownProblem = DoctorValue(IsKnown, baseId)
    local usable, usableProblem = DoctorValue(IsUsable, baseId)
    local cooldown, cooldownProblem = DoctorValue(CooldownRemaining, baseId)

    local macro, macroProblem
    if btn and btn.GetAttribute then
        macro, macroProblem = DoctorValue(btn.GetAttribute, btn, "macrotext1")
    else
        macroProblem = "secure BASE frame unavailable"
    end
    macro = type(macro) == "string" and macro or ""
    if macro == "" then Warn("BASE macro unavailable or empty") end

    local bindingCommand = BIND_COMMAND or "CLICK HCOneButtonFrame:LeftButton"
    local rawBindingSet, rawBindingProblem = DoctorValue(GetCurrentBindingSet)
    local normalizedBindingSet, normalizedBindingProblem = DoctorValue(CurrentBindingSet)
    local panel = HCOB.UI and HCOB.UI.ActionPanel
    local baseSlot = ActionSlotForSpell(baseId)
    local baseSlotKey, baseSlotKeyProblem
    if panel and panel.GetSlotKey and baseSlot then
        baseSlotKey, baseSlotKeyProblem = DoctorValue(panel.GetSlotKey, baseSlot)
    else
        baseSlotKeyProblem = baseSlot and "unavailable" or "not mapped"
    end

    local panelConfigured = 0
    if panel and type(panel.buttons) == "table" then
        for _, button in ipairs(panel.buttons) do
            if button and button.configured then panelConfigured = panelConfigured + 1 end
        end
    end

    local dbRoot = type(HCOB_DB) == "table" and HCOB_DB or nil
    local logRoot = type(HCOB_CombatLog) == "table" and HCOB_CombatLog or nil
    local characterRoot = type(HCOB_CharacterDB) == "table" and HCOB_CharacterDB or nil
    local dbPublicIdentity = dbRoot ~= nil and HCOB.DB == dbRoot
    local dbPrivateIdentity = dbRoot ~= nil and HCOB.Internal.HCOB_DB == dbRoot
    local logPublicIdentity = logRoot ~= nil and HCOB.CombatLog == logRoot
    local logPrivateIdentity = logRoot ~= nil and HCOB.Internal.HCOB_CombatLog == logRoot
    local characterPublicIdentity = characterRoot ~= nil and HCOB.CharacterDB == characterRoot
    local characterPrivateIdentity = characterRoot ~= nil and HCOB.Internal.HCOB_CharacterDB == characterRoot
    if not dbPublicIdentity or not dbPrivateIdentity then Warn("HCOB_DB identity mismatch") end
    if not logPublicIdentity or not logPrivateIdentity then Warn("HCOB_CombatLog identity mismatch") end
    if not characterPublicIdentity or not characterPrivateIdentity then Warn("HCOB_CharacterDB identity mismatch") end

    Add(lines, "HCOneButton Doctor Report")
    Add(lines, "=========================")
    Add(lines, "Addon version: " .. tostring(VERSION))
    Add(lines, "Interface: " .. tostring(interfaceVersion or 11509))
    Add(lines, "Client: " .. CleanText(clientVersion or "?", 30) .. " build " .. CleanText(clientBuild or "?", 20))
    Add(lines, "Class: " .. tostring(PLAYER_CLASS or localizedClass or "?") .. " | Level: " .. DoctorText(level) .. " | Spec: " .. CleanText(specName or "Unknown", 32) .. " (tab " .. tostring(specIndex or 0) .. ")")
    Add(lines, "Locale: " .. tostring(GetLocale and GetLocale() or "?"))
    Add(lines, "Privacy: character name/realm, target names/GUIDs, zone and equipment IDs are not collected.")
    Add(lines, "Snapshot is read-only: no settings, bindings, macros or SavedVariables were changed.")
    Add(lines, "")

    Add(lines, "BASE action:")
    Add(lines, "  ID/name: " .. tostring(baseId or "nil") .. " / " .. DoctorText(baseName, baseNameProblem))
    Add(lines, "  Resolved learned ID/rank: " .. tostring(resolvedId or "?") .. " / " .. tostring(learnedRank or "not exposed"))
    Add(lines, "  Description: " .. CleanText(baseDescription or "?", 80))
    Add(lines, "  Known/usable/cooldown: " .. DoctorText(known, knownProblem) .. " / " .. DoctorText(usable, usableProblem) .. " / " .. DoctorText(cooldown, cooldownProblem))
    Add(lines, "  Class declares ranged BASE: " .. tostring(forceRanged))
    Add(lines, "  Bounds min/max: " .. (rangeBoundsProblem or (tostring(minRange or "nil") .. " / " .. tostring(maxRange or "nil"))))
    Add(lines, "  Shared range/state: " .. DoctorText(sharedRange, sharedRangeProblem) .. " / " .. DoctorText(rangedState, rangedStateProblem))
    Add(lines, "  Raw IsSpellInRange(name): " .. DoctorText(legacyRange, legacyRangeProblem))
    Add(lines, "  Raw C_Spell.IsSpellInRange(ID): " .. DoctorText(cSpellRange, cSpellRangeProblem))
    Add(lines, "  Macro length: " .. tostring(#macro) .. "/" .. tostring(MACRO_LIMIT or 255))
    if macro ~= "" then
        for line in macro:gmatch("[^\r\n]+") do Add(lines, "    " .. CleanText(line, 240)) end
    else
        Add(lines, "    " .. tostring(macroProblem or "empty"))
    end
    Add(lines, "")

    Add(lines, "Live units:")
    Add(lines, "  Player combat/lockdown: " .. DoctorBoolean(UnitAffectingCombat, "player") .. " / " .. DoctorBoolean(InCombatLockdown))
    Add(lines, "  Target exists/hostile/dead: " .. DoctorBoolean(UnitExists, "target") .. " / " .. DoctorBoolean(UnitCanAttack, "player", "target") .. " / " .. DoctorBoolean(UnitIsDead, "target"))
    Add(lines, "  Pet exists/dead/combat/has target: " .. DoctorBoolean(UnitExists, "pet") .. " / " .. DoctorBoolean(UnitIsDead, "pet") .. " / " .. DoctorBoolean(UnitAffectingCombat, "pet") .. " / " .. DoctorBoolean(UnitExists, "pettarget"))
    Add(lines, "")

    Add(lines, "Bindings and Action Panel:")
    Add(lines, "  Main command/keys: " .. bindingCommand .. " / " .. DoctorBindings(bindingCommand))
    Add(lines, "  Binding set raw/normalized: " .. DoctorText(rawBindingSet, rawBindingProblem) .. " / " .. DoctorText(normalizedBindingSet, normalizedBindingProblem))
    Add(lines, "  Auto-bind/secure actions: " .. tostring(dbRoot and dbRoot.actionSlotAutoBind ~= false) .. " / " .. tostring(dbRoot and dbRoot.secureActions ~= false))
    Add(lines, "  BASE panel slot/key: " .. tostring(baseSlot or "unmapped") .. " / " .. DoctorText(baseSlotKey, baseSlotKeyProblem))
    Add(lines, "  Panel visible/configured slots: " .. tostring(panel and panel.visibleCount or "?") .. " / " .. tostring(panel and type(panel.buttons) == "table" and panelConfigured or "?"))
    Add(lines, "  Diagnostic Pixel enabled: " .. tostring(dbRoot and dbRoot.diagPixel ~= false))
    Add(lines, "")

    Add(lines, "SavedVariables:")
    Add(lines, "  Ready/root types: " .. tostring(savedVariablesReady) .. " / " .. type(HCOB_DB) .. " / " .. type(HCOB_CombatLog) .. " / " .. type(HCOB_CharacterDB))
    Add(lines, "  DB public/private identity: " .. tostring(dbPublicIdentity) .. " / " .. tostring(dbPrivateIdentity))
    Add(lines, "  Log public/private identity: " .. tostring(logPublicIdentity) .. " / " .. tostring(logPrivateIdentity))
    Add(lines, "  Character public/private identity: " .. tostring(characterPublicIdentity) .. " / " .. tostring(characterPrivateIdentity))
    Add(lines, "  Anonymous character telemetry profile: " .. tostring(characterRoot and type(characterRoot.logProfileId) == "string"))
    Add(lines, "  Adaptive store/contexts/active: " .. type(characterRoot and characterRoot.adaptive) .. " / " .. type(characterRoot and characterRoot.adaptive and characterRoot.adaptive.contexts) .. " / " .. tostring(characterRoot and characterRoot.adaptive and characterRoot.adaptive.enabled == true))
    Add(lines, "  Adaptive telemetry contract: " .. tostring(HCOB.Systems and HCOB.Systems.TuningTelemetry and HCOB.Systems.TuningTelemetry.CONTRACT_VERSION or "unavailable"))
    Add(lines, "  Binding map types: " .. type(dbRoot and dbRoot.actionSlotKeys) .. " / " .. type(dbRoot and dbRoot.actionSlotAppliedKeys))
    Add(lines, "  Saved fights/total: " .. tostring(logRoot and type(logRoot.fights) == "table" and #logRoot.fights or 0) .. " / " .. tostring(logRoot and logRoot.totalFights or 0))
    Add(lines, "  Repairs this load: " .. tostring(HCOB.SavedVariableRepairs and #HCOB.SavedVariableRepairs or 0))
    if HCOB.SavedVariableRepairs and #HCOB.SavedVariableRepairs > 0 then
        Add(lines, "    " .. CleanText(table.concat(HCOB.SavedVariableRepairs, ", "), 500))
    end
    Add(lines, "")

    Add(lines, "Advisor snapshot:")
    local display = engine and engine.displayState
    if display then
        Add(lines, "  ID/title/kind: " .. tostring(display.spellId or "nil") .. " / " .. CleanText(display.title or "?", 60) .. " / " .. CleanText(display.kind or "?", 24))
        Add(lines, "  Key/reason: " .. CleanText(display.key or "?", 32) .. " / " .. CleanText(display.reason or "?", 180))
        Add(lines, "  Action slot: " .. tostring(ActionSlotForSpell(display.spellId) or "unmapped"))
    else
        Add(lines, "  No stabilized Advisor display state is available yet.")
    end
    Add(lines, "")

    AddRuntimeErrors(lines)
    Add(lines, "")
    Add(lines, "Doctor summary: " .. (#warnings == 0 and "OK" or ("WARN (" .. #warnings .. ")")))
    for _, warning in ipairs(warnings) do Add(lines, "  - " .. warning) end
    Add(lines, "Issue page: " .. F.ISSUE_URL)
    return TruncateReport(table.concat(lines, "\n"))
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

    local fights = CurrentCharacterFights and CurrentCharacterFights() or {}
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
