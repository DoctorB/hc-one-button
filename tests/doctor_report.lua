local db = {
    actionSlotAutoBind = true,
    secureActions = true,
    diagPixel = true,
    actionSlotKeys = {},
    actionSlotAppliedKeys = {},
    scale = 1.0,
}
local combatLog = {fights = {{id = 1}}, totalFights = 1}
local characterDB = {
    logProfileId = "p-private-profile", logSession = "Private session",
    adaptive = {version=2, enabled=true, contexts={}, totalEligible=0},
}

HCOB_DB = db
HCOB_CombatLog = combatLog
HCOB_CharacterDB = characterDB
HCOneButton = {
    DB = db,
    CombatLog = combatLog,
    CharacterDB = characterDB,
    Core = {}, Data = {}, Classes = {}, Advisor = {Engine = {}}, UI = {ActionPanel = {}}, Systems = {}, Hunter = {},
}
HCOneButton.Internal = setmetatable({
    HCOB_DB = db,
    HCOB_CombatLog = combatLog,
    HCOB_CharacterDB = characterDB,
    VERSION = "1.27.8",
    MACRO_LIMIT = 255,
    PLAYER_CLASS = "WARLOCK",
    savedVariablesReady = true,
    runtimeSmartDisabled = false,
    runtimeCombatLogDisabled = false,
    runtimeTelemetryDisabled = false,
    runtimeErrors = {{area = "TestProbe", message = "contained diagnostic error"}},
    BIND_COMMAND = "CLICK HCOneButtonFrame:LeftButton",
    print = function() end,
}, {__index = _G})

HCOneButton.SavedVariableRepairs = {}
HCOneButton.Classes.WARLOCK = {
    GetBaseActionInfo = function() return 686, "PET + SHADOW BOLT" end,
}
HCOneButton.Advisor.Engine.IsClassRangedBaseAction = function(id) return id == 686 end
HCOneButton.Advisor.Engine.SpellRangeBounds = function() return 0, 30 end
HCOneButton.Advisor.Engine.SpellRange = function() return false end
HCOneButton.Advisor.Engine.RangedActionState = function() return "out" end
HCOneButton.Advisor.Engine.displayState = {
    spellId = 686, title = "SHADOW BOLT", kind = "action", key = "BASE", reason = "Test reason",
}

HCOneButton.UI.ActionPanel.actions = {WARLOCK = {172, 980, 348, 686}}
HCOneButton.UI.ActionPanel.idToSlot = {[686] = 4}
HCOneButton.UI.ActionPanel.visibleCount = 15
HCOneButton.UI.ActionPanel.buttons = {{configured=true}, {configured=true}}
HCOneButton.UI.ActionPanel.GetSlotKey = function(slot) return slot == 4 and "SHIFT-4" or nil end
HCOneButton.Systems.TuningTelemetry = {CONTRACT_VERSION = 1}
local adaptiveEnabled, adaptiveStatusPrinted, adaptiveReset = true, false, false
HCOneButton.Systems.AdaptiveTuner = {
    SCHEMA_VERSION = 2, REVISION = 1,
    IsEnabled = function() return adaptiveEnabled end,
    SetEnabled = function(value) adaptiveEnabled = value == true; return true end,
    PrintStatus = function() adaptiveStatusPrinted = true end,
    Reset = function() adaptiveReset = true; return true end,
}

function UnitClass() return "Warlock", "WARLOCK" end
function PlayerLevel() return 30 end
function TalentSpec() return 1, "Affliction", 20 end
function GetBuildInfo() return "1.15.9", "65000", "Aug 2026", 11509 end
function GetLocale() return "enUS" end
function SpellName(id, fallback) return id == 686 and "Shadow Bolt" or fallback end
function GetSpellInfo()
    return "Shadow Bolt", "Rank 4", 1, 2500, 0, 30, 695
end
function IsSpellInRange() return 0 end
function IsKnown(id) return id == 686 end
function IsUsable(id) return id == 686 end
function CooldownRemaining() return 0 end
function CanAccessValue() return true end
function GetCurrentBindingSet() return 0 end
function CurrentBindingSet() return 1 end
function GetBindingKey(command)
    assert(command == "CLICK HCOneButtonFrame:LeftButton")
    return "BUTTON4"
end
function UnitExists(unit) return unit == "target" or unit == "pet" or unit == "pettarget" end
function UnitCanAttack(_, unit) return unit == "target" end
function UnitIsDead() return false end
function UnitAffectingCombat(unit) return unit == "pet" end
function InCombatLockdown() return false end
function GetTime() return 10 end
function CountActiveEnemies() return 0 end
function InitCombatLogDB() error("Doctor must not initialize or mutate combat log") end
function UnitName(unit) return unit == "player" and "SensitivePlayer" or "SensitiveTarget" end

C_Spell = {
    GetSpellInfo = function() return {spellID = 695, name = "Shadow Bolt", minRange = 0, maxRange = 30} end,
    IsSpellInRange = function() error("simulated client range failure") end,
}

HCOneButton.Internal.btn = {
    GetAttribute = function(_, attribute)
        assert(attribute == "macrotext1")
        return "/petattack [combat,harm]\n/cast [harm] Shadow Bolt"
    end,
}

assert(dofile("HCOneButton/Systems/Feedback.lua") == nil)
local report = HCOneButton.Systems.Feedback.GenerateDoctorReport()

local function includes(text)
    assert(report:find(text, 1, true), "Doctor report missing: " .. text)
end

includes("HCOneButton Doctor Report")
includes("ID/name: 686 / Shadow Bolt")
includes("Resolved learned ID/rank: 695 / Rank 4")
includes("Bounds min/max: 0 / 30")
includes("Shared range/state: false / out")
includes("Raw IsSpellInRange(name): 0")
includes("Raw C_Spell.IsSpellInRange(ID): ERROR: simulated client range failure")
includes("/petattack [combat,harm]")
includes("Main command/keys: CLICK HCOneButtonFrame:LeftButton / BUTTON4")
includes("Binding set raw/normalized: 0 / 1")
includes("BASE panel slot/key: 4 / SHIFT-4")
includes("DB public/private identity: true / true")
includes("Log public/private identity: true / true")
includes("Character public/private identity: true / true")
includes("Anonymous character telemetry profile: true")
includes("Adaptive store/contexts/active: table / table / true")
includes("Adaptive telemetry contract: 1")
includes("Adaptive learner schema/revision: 2 / 1")
includes("[TestProbe] contained diagnostic error")
includes("Doctor summary: WARN (1)")
assert(not report:find("SensitivePlayer", 1, true), "Doctor leaked player name")
assert(not report:find("SensitiveTarget", 1, true), "Doctor leaked target name")
assert(not report:find("p-private-profile", 1, true), "Doctor leaked anonymous character profile")
assert(HCOB_DB == db and HCOB_CombatLog == combatLog and HCOB_CharacterDB == characterDB and db.scale == 1.0 and #combatLog.fights == 1,
    "Doctor mutated SavedVariables")

-- Slash dispatch opens the existing report window directly in Doctor mode.
local openedMode
HCOneButton.UI.Feedback = {Open = function(mode) openedMode = mode end}
SlashCmdList = {}
assert(dofile("HCOneButton/Core/Commands.lua") == nil)
assert(type(SlashCmdList.HCOB) == "function", "slash handler missing")
SlashCmdList.HCOB("doctor")
assert(openedMode == "doctor", "/hcob doctor did not open Doctor mode")
SlashCmdList.HCOB("tuning status")
assert(adaptiveStatusPrinted, "/hcob tuning status did not dispatch to the learner")
SlashCmdList.HCOB("tuning off")
assert(not adaptiveEnabled, "/hcob tuning off did not disable the learner")
SlashCmdList.HCOB("tuning on")
assert(adaptiveEnabled, "/hcob tuning on did not enable the learner")
SlashCmdList.HCOB("tuning reset")
assert(adaptiveReset, "/hcob tuning reset did not reset per-character learning")

print("doctor report/command regression: PASS")
