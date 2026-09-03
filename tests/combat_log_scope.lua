local hostGlobal = _G

local environment = setmetatable({}, {__index = hostGlobal})
environment._G = environment
environment.VERSION = "1.29.0"
environment.PLAYER_CLASS = "WARRIOR"
environment.HCOB_DB = {combatLogMaxFights = 60}
environment.HCOB_CharacterDB = {logProfileId = "p-current-profile", logSession = "Current Warrior"}
environment.HCOB_CombatLog = {
    fights = {
        {id=1, class="WARRIOR", addonVersion="1.28.5", totalDamage=100, duration=10, hpMinPct=80}, -- legacy current-class
        {id=2, class="MAGE", profileId="p-current-profile", addonVersion="1.29.0", totalDamage=800, duration=10, hpMinPct=10},
        {id=3, class="WARRIOR", profileId="p-other-warrior", addonVersion="1.29.0", totalDamage=900, duration=10, hpMinPct=5},
        {id=4, class="MAGE", addonVersion="1.29.0", totalDamage=700, duration=10, hpMinPct=15},
        {id=5, class="WARRIOR", profileId="p-current-profile", addonVersion="1.28.5", totalDamage=200, duration=10, hpMinPct=70},
        {id=6, class="WARRIOR", profileId="p-current-profile", addonVersion="1.29.0", totalDamage=300, duration=10, hpMinPct=60},
        {id=7, class="WARRIOR", profileId="p-current-profile", addonVersion="1.29.0", totalDamage=500, duration=10, hpMinPct=50},
    },
    totalFights = 7,
    session = "Legacy shared session",
}

local output = {}
environment.print = function(message) output[#output + 1] = tostring(message) end
environment.HCOneButton = {
    Internal = {},
    CombatLog = environment.HCOB_CombatLog,
    RecordSavedVariableRepair = function() end,
}
setmetatable(environment.HCOneButton.Internal, {__index = environment})
environment.Clamp = function(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local chunk = assert(loadfile("HCOneButton/Systems/CombatLog.lua"))
setfenv(chunk, environment)
chunk()

local runtime = environment.HCOneButton.Internal
assert(runtime.CurrentCombatLogProfileId() == "p-current-profile", "current anonymous profile not resolved")
assert(runtime.CurrentCombatLogSession() == "Current Warrior", "per-character session not resolved")

local current = runtime.CurrentCharacterFights()
assert(#current == 4, "current-character filter included a foreign class/profile")
assert(current[1].id == 1 and current[2].id == 5 and current[3].id == 6 and current[4].id == 7,
    "current-character fights were not returned in chronological order")
assert(runtime.LastCurrentCharacterFight().id == 7, "last fight came from another character")

local average, count = runtime.RecentCharacterDPSAverage(2)
assert(count == 2 and math.abs(average - 40) < 0.001,
    "DPS average did not prefer current-version fights from the active character")

runtime.PrintCombatLogStats()
local stats = table.concat(output, "\n")
assert(stats:find("last 4 fights", 1, true), "stats did not use the current-character fight count")
assert(stats:find("avg DPS 27.5", 1, true), "stats included damage from another class/profile")
assert(stats:find("min HP 50.0%", 1, true), "stats included another character's lower HP")

local scoped = {}
for i=1,12 do
    scoped[#scoped + 1] = {id=i, class="WARRIOR", profileId="p-current-profile", duration=1, totalDamage=i}
end
for i=1,3 do
    scoped[#scoped + 1] = {id=100+i, class="WARRIOR", profileId="p-other-warrior", duration=1, totalDamage=100}
end
environment.HCOB_CombatLog.fights = scoped
environment.HCOB_DB.combatLogMaxFights = 10
runtime.TrimCombatLog()
assert(#runtime.CurrentCharacterFights() == 10, "per-character retention limit was not enforced")
assert(#environment.HCOB_CombatLog.fights == 13, "another character's retained fights were evicted by the active quota")
assert(runtime.CurrentCharacterFights()[1].id == 3, "retention did not remove the oldest active-character fights")

runtime.ClearCombatLog(false)
assert(#runtime.CurrentCharacterFights() == 0, "current-character clear left matching fights behind")
assert(#environment.HCOB_CombatLog.fights == 3, "current-character clear removed another profile")

runtime.ClearCombatLog(true)
assert(#environment.HCOB_CombatLog.fights == 0 and environment.HCOB_CombatLog.totalFights == 0,
    "account-wide clear did not reset the complete log")

print("combat log character-scope regression: PASS")
