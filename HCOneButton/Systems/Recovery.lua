-- Between-pull recovery. Selection/state only; item use belongs to secure UI.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)
local C = HCOB.Systems.Consumables
local R = {catalog={food={},drink={}}}
HCOB.Systems.Recovery = R

-- Plain Classic food/water only: never select raw cooking materials, buff food,
-- alcohol or battleground-only refreshments by an English tooltip substring.
local function tier(role, rank, level, ids, conjured)
    for _, id in ipairs(ids) do
        R.catalog[role][#R.catalog[role]+1] = {id=id, rank=rank, level=level, conjured=conjured == true}
    end
end
tier("food",1,0,{117,2070,4536,4540,4604,787,2679,2681,6290,7097})
tier("food",2,5,{2287,414,4537,4541,4605,4592,5095,6316,6890})
tier("food",3,15,{3770,422,4538,4542,4606,4593,2685,5478,5526})
tier("food",4,25,{3771,1707,4539,4544,4607,4594,8364})
tier("food",5,35,{4599,3927,4601,4602,4608,6887,13930,16766,13546})
tier("food",6,45,{8952,8932,8950,8953,8948,8957,13933,13935})
for index, id in ipairs({5349,1113,1114,1487,8075,8076,22895}) do
    tier("food",index,index == 1 and 0 or (index-2)*10+5,{id},true)
end
for index, id in ipairs({159,1179,1205,1708,1645,8766,18300}) do
    tier("drink",index,index == 1 and 0 or (index-2)*10+5,{id})
end
for index, id in ipairs({5350,2288,2136,3772,8077,8078,8079}) do
    tier("drink",index,index == 1 and 0 or (index-2)*10+5,{id},true)
end

for _, role in ipairs({"food","drink"}) do C.roleOrder[#C.roleOrder+1] = role end
C.roleLabels.food, C.roleLabels.drink = "FOOD", "DRINK"
C.roleDescriptions.food = "Highest usable plain-food tier in your bags; conjured first at equal tier"
C.roleDescriptions.drink = "Highest usable water tier in your bags; conjured first at equal tier"

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j, k, l, m, n = pcall(fn, ...)
    if ok then return a,b,c,d,e,f,g,h,i,j,k,l,m,n end
end
local function number(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge and value or nil
end
local function isTrue(value) return value == true or value == 1 end
local requests = {}

function R.IsRole(role) return role == "food" or role == "drink" end

function R.UsesMana()
    -- Query the mana pool explicitly: shapeshifted Druids still have mana.
    if PLAYER_CLASS == "WARRIOR" or PLAYER_CLASS == "ROGUE" then return false end
    local maximum = number(call(UnitPowerMax, "player", 0))
    if maximum then return maximum > 0 end
    return PLAYER_CLASS == "PALADIN" or PLAYER_CLASS == "HUNTER" or PLAYER_CLASS == "PRIEST"
        or PLAYER_CLASS == "SHAMAN" or PLAYER_CLASS == "MAGE" or PLAYER_CLASS == "WARLOCK" or PLAYER_CLASS == "DRUID"
end

function R.Expected(role)
    return {role=role,name=role == "food" and "Food" or "Water",count=0,available=false,expected=true,
        icon=role == "food" and "Interface\\Icons\\INV_Misc_Food_73CinnamonRoll" or "Interface\\Icons\\INV_Drink_07"}
end

function R.FindBest(role)
    if role == "drink" and not R.UsesMana() then return nil end
    local level = number(call(PlayerLevel)) or number(call(UnitLevel, "player")) or 1
    local best
    for _, entry in ipairs(R.catalog[role] or {}) do
        local count = C.GetItemCount(entry.id)
        -- Some cooked equivalents unlock before vendor food of the same tier.
        -- Strength is not a use-level requirement; the live cache decides that.
        if count > 0 then
            local name, _, quality, _, minimum, _, _, _, _, icon, _, classID, _, bindType = call(GetItemInfo or (C_Item and C_Item.GetItemInfo), entry.id)
            minimum = number(minimum)
            if not name or not minimum then
                if not requests[entry.id] and C_Item and C_Item.RequestLoadItemDataByID then
                    requests[entry.id] = true
                    call(C_Item.RequestLoadItemDataByID, entry.id)
                end
            elseif minimum >= 0 and minimum <= level and classID == 0 and bindType ~= 4
                and number(quality) and quality >= 0 and quality <= 1 then
                requests[entry.id] = nil
                if not best or entry.rank > best.rank
                    or (entry.rank == best.rank and entry.conjured and not best.conjured)
                    or (entry.rank == best.rank and entry.conjured == best.conjured and entry.id < best.id) then
                    best = {role=role,id=entry.id,name=name,icon=icon,count=count,minLevel=minimum,
                        rank=entry.rank,conjured=entry.conjured,available=true}
                end
            end
        end
    end
    return best
end

local function aura(id)
    local name = call(SpellName, id)
    if not name then return false end
    return call(AuraByName, "player", name, "HELPFUL", false) == true
end

function R.State()
    local state = {hasMana=R.UsesMana()}
    state.combat = isTrue(call(InCombatLockdown)) or isTrue(call(UnitAffectingCombat,"player"))
    state.food, state.drink = aura(433), aura(430) -- localized Food / Drink, not Well Fed
    local hp, hpKnown = call(UnitHealthPct,"player")
    local mana, manaKnown = call(UnitPowerPct,"player",0)
    state.hp, state.mana = number(hp), number(mana)
    state.hpKnown = hpKnown == true and state.hp ~= nil and state.hp >= 0 and state.hp <= 100
    state.manaKnown = manaKnown == true and state.mana ~= nil and state.mana >= 0 and state.mana <= 100 and state.hasMana
    state.needFood = state.hpKnown and state.hp < 100
    state.needDrink = state.manaKnown and state.mana < 100
    if state.combat then state.blocked = "COMBAT"
    elseif isTrue(call(UnitIsDeadOrGhost,"player")) then state.blocked = "DEAD"
    elseif isTrue(call(IsMounted)) or isTrue(call(IsFlying)) then state.blocked = "DISMOUNT"
    elseif (number(call(GetUnitSpeed,"player")) or 0) > 0 then state.blocked = "STOP TO REST"
    elseif PLAYER_CLASS == "DRUID" and (number(call(GetShapeshiftForm)) or 0) > 0 then state.blocked = "SHIFT OUT"
    elseif call(UnitCastingInfo,"player") or call(UnitChannelInfo,"player") then state.blocked = "LET IT FINISH" end
    -- Food is not a combat heal. A stale eating aura must never mask danger.
    state.hold = not state.blocked and ((state.food and (state.needFood or not state.hpKnown))
        or (state.drink and state.hasMana and (state.needDrink or not state.manaKnown))) or false
    state.text = state.food and state.drink and "EAT + DRINK" or (state.food and "EATING" or (state.drink and "DRINKING" or nil))
    return state
end

function R.CanUse(role, item, state)
    state = state or R.State()
    if state.blocked then return false, state.blocked end
    if role == "drink" and not state.hasMana then return false, "N/A" end
    if state[role] then return false, role == "food" and "EATING" or "DRINKING" end
    if not (role == "food" and state.hpKnown or role == "drink" and state.manaKnown) then return false, "WAIT FOR DATA" end
    if not (role == "food" and state.needFood or role == "drink" and state.needDrink) then return false, "FULL" end
    if not item or not item.id or C.GetItemCount(item.id) <= 0 then return false, "NO STOCK" end
    local _, _, enabled, remaining = C.GetCooldown(item.id)
    if not enabled or remaining > 0.05 then return false, "COOLDOWN" end
    local usable = call(IsUsableItem or (C_Item and C_Item.IsUsableItem), item.id)
    if usable == false or usable == 0 then return false, "UNAVAILABLE" end
    return true, "Click to use outside combat"
end

function R.Recommend(state)
    state = state or R.State()
    if state.blocked then return nil end
    if state.hpKnown and state.hp <= 85 and R.CanUse("food",C.GetRole("food"),state) then return "food" end
    if state.manaKnown and state.mana < 60 and R.CanUse("drink",C.GetRole("drink"),state) then return "drink" end
end
