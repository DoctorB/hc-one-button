-- HCOneButton modular runtime.
-- Internal symbols live in one private addon environment, not in _G.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

VERSION = HCOB.VERSION or "1.28.0"
MACRO_LIMIT = 255

_, PLAYER_CLASS = UnitClass("player")

S = HCOB.Data.Spells


savedVariablesReady = false
pendingRebuild = false
pendingHUDScale = false
appliedHUDScale = nil
appliedActionScale = nil
playerGUID = nil
activeEnemies = {}
activeTargetCast = nil
lastAutoAttack = nil
lastRecommendationKey = nil
lastDangerSound = 0
lastInterruptSound = 0
currentMods = nil
runtimeSmartDisabled = false
runtimeCombatLogDisabled = false
runtimeTelemetryDisabled = false
runtimeErrors = {}
lastErrorNotice = 0
currentFight = nil
