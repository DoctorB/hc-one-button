local hostGlobal = _G

local function loadInto(environment, path)
    local chunk = assert(loadfile(path))
    setfenv(chunk, environment)
    chunk()
end

local function newRuntime(characterDB)
    local environment = setmetatable({}, {__index=hostGlobal})
    environment._G = environment
    environment.HCOB_CharacterDB = characterDB
    environment.PLAYER_CLASS = "MAGE"
    environment.GetServerTime = function() return 1788400000 end
    environment.print = function() end
    environment.HCOneButton = {
        Internal=environment, Core={}, Advisor={}, UI={},
        Systems={TuningTelemetry={
            HashParts=function(parts) return table.concat(parts, "|") end,
            CandidateKey=function(id, tag) return tostring(id or "none") .. ":" .. tostring(tag or "action") end,
        }},
    }
    loadInto(environment, "HCOneButton/Systems/AdaptiveTuner.lua")
    loadInto(environment, "HCOneButton/UI/Options.lua")
    return environment
end

local characterDB = {adaptive={version=2, enabled=true, contexts={}, totalEligible=0}}
local firstLoad = newRuntime(characterDB)
local options = assert(firstLoad.HCOneButton.UI.Options)
assert(options.IsAdaptiveTuningEnabled(), "Options did not reflect the enabled per-character flag")
assert(options.SetAdaptiveTuningEnabled(false), "Options could not disable Local Adaptive Tuning")
assert(characterDB.adaptive.enabled == false, "Options OFF was not written to the per-character SavedVariables")
local detailsOpenedFromOptions
firstLoad.HCOneButton.UI.AdaptiveTuning = {Open=function(fromOptions) detailsOpenedFromOptions = fromOptions end}
assert(options.OpenAdaptiveTuningDetails(), "Options could not open the Adaptive Tuning details")
assert(detailsOpenedFromOptions == true, "Options did not open Adaptive Tuning as a managed child")

-- A reload creates fresh addon tables while WoW restores the same
-- SavedVariablesPerCharacter table. The explicit OFF choice must survive.
local reloaded = newRuntime(characterDB)
local reloadedOptions = assert(reloaded.HCOneButton.UI.Options)
assert(reloadedOptions.IsAdaptiveTuningEnabled() == false, "Options OFF did not survive a simulated reload")
assert(reloadedOptions.SetAdaptiveTuningEnabled(true), "Options could not re-enable Local Adaptive Tuning")
assert(characterDB.adaptive.enabled == true, "Options ON was not persisted per character")

local reloadedAgain = newRuntime(characterDB)
assert(reloadedAgain.HCOneButton.UI.Options.IsAdaptiveTuningEnabled(), "Options ON did not survive a second simulated reload")

print("adaptive Options persistence regression: PASS")
