-- Manual, single-stack destruction. No event, timer or inventory scan deletes items.
local HCOB = HCOneButton
local E = HCOB.Internal
setfenv(1, E)

local Q = {}
HCOB.Systems.BagQuickDelete = Q
local pending
local POPUP = "HCOB_BAG_QUICK_DELETE"
local revision = 0

local function api(name)
    return C_Container and C_Container[name] or _G[name]
end

local function integer(value, low, high)
    return type(value) == "number" and value == math.floor(value) and value >= low and value <= high
end

local function message(reason)
    print("|cffffcc00HCOB:|r Quick delete: " .. reason)
end

local function ready()
    if not HCOB_DB or HCOB_DB.bagQuickDelete ~= true then return false, "disabled in Options." end
    if not InCombatLockdown or InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) then
        return false, "unavailable in combat."
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false, "unavailable while dead." end
    if not GetCursorInfo or GetCursorInfo() then return false, "the cursor must be empty." end
    if (SpellIsTargeting and SpellIsTargeting()) or (SpellCanTargetItem and SpellCanTargetItem()) then
        return false, "finish or cancel the spell targeting first."
    end
    if not api("PickupContainerItem") or not DeleteCursorItem then return false, "required item APIs are unavailable." end
    return true
end

function Q.Inspect(bag, slot)
    local ok, reason = ready()
    if not ok then return nil, reason end
    if not integer(bag, 0, 4) or not integer(slot, 1, 100) then return nil, "only carried bag items are supported." end
    local slotsAPI, infoAPI, questAPI = api("GetContainerNumSlots"), api("GetContainerItemInfo"), api("GetContainerItemQuestInfo")
    if not slotsAPI or not infoAPI or not questAPI or not GetItemInfo then return nil, "item metadata is unavailable." end
    local slots = slotsAPI(bag)
    if not integer(slots, 0, 100) or slot > slots then return nil, "invalid bag slot." end
    local icon, count, locked, quality, readable, hasLoot, link = infoAPI(bag, slot)
    local info
    if type(icon) == "table" then
        info = icon
        count, locked, quality, hasLoot, link = info.stackCount, info.isLocked, info.quality, info.hasLoot, info.hyperlink
    end
    if type(locked) ~= "boolean" or type(hasLoot) ~= "boolean" then return nil, "wait for complete item information." end
    if locked then return nil, "the item is locked." end
    if hasLoot then return nil, "loot containers must be emptied first." end
    if not integer(count, 1, 100000) or not integer(quality, 0, 8) or type(link) ~= "string" then
        return nil, "wait for complete item information."
    end
    local itemID = tonumber(link:match("item:(%d+):"))
    if not itemID or (info and info.itemID and info.itemID ~= itemID) then return nil, "item identity is unavailable." end
    if itemID == 6948 then return nil, "the Hearthstone is protected." end
    local quest, questID = questAPI(bag, slot)
    if type(quest) == "boolean" then quest = {isQuestItem=quest, questID=questID} end
    if type(quest) ~= "table" or type(quest.isQuestItem) ~= "boolean" then return nil, "quest status is unavailable." end
    if quest.isQuestItem or quest.questID then return nil, "quest items are protected." end
    local name, _, cachedQuality, _, _, _, _, _, _, _, _, classID, _, bindType = GetItemInfo(link)
    if not name or cachedQuality ~= quality or not integer(classID, 0, 30) or not integer(bindType, 0, 5) then
        return nil, "wait for complete item information."
    end
    if classID == 12 or bindType == 4 then return nil, "quest items are protected." end
    return {bag=bag, slot=slot, itemID=itemID, link=link, count=count, quality=quality, revision=revision}
end

local function inspect(bag, slot)
    local ok, item, reason = pcall(Q.Inspect, bag, slot)
    if not ok then return nil, "item information could not be read safely." end
    return item, reason
end
Q.SafeInspect = inspect

local function same(a, b)
    return a and b and a.bag == b.bag and a.slot == b.slot and a.itemID == b.itemID
        and a.link == b.link and a.count == b.count and a.quality == b.quality and a.revision == b.revision
end

function Q.Cancel()
    pending = nil
    if StaticPopup_Hide then StaticPopup_Hide(POPUP) end
end

function Q.InventoryChanged()
    revision = revision + 1
    Q.Cancel()
end

function Q.HasPending() return pending ~= nil end

local function destroy(item)
    local current, reason = inspect(item.bag, item.slot)
    if not same(item, current) then message(reason or "the bag contents changed; click the item again."); return false end
    -- This function is called ONLY by a hardware click (right-click / confirmation).
    -- Do not clear a foreign cursor, invoke normal bag use, or retry asynchronously.
    local ok = pcall(api("PickupContainerItem"), item.bag, item.slot)
    local cursorOK, kind, id, link = pcall(GetCursorInfo)
    if not ok or not cursorOK or kind ~= "item" or id ~= item.itemID or link ~= item.link then
        message("pickup could not be verified; nothing was deleted.")
        return false
    end
    local deleted = pcall(DeleteCursorItem)
    -- Native client restrictions/confirmations remain intact. Never claim success
    -- or clear the cursor here: Blizzard may still own a deletion confirmation.
    if not deleted then message("the client blocked deletion; return the item from the cursor to your bag.") end
    return deleted
end

function Q.Confirm(item)
    if not item or pending ~= item then return false end
    pending = nil
    return destroy(item)
end

function Q.Request(item)
    Q.Cancel()
    if not item then return false end
    local current, reason = inspect(item.bag, item.slot)
    if not same(item, current) then message(reason or "the bag contents changed; click the item again."); return false end
    if item.quality == 0 then return destroy(item) end
    if not StaticPopupDialogs or not StaticPopup_Show then message("confirmation dialog is unavailable."); return false end
    pending = item
    local shown, dialog = pcall(StaticPopup_Show, POPUP, item.link, tostring(item.count), item)
    if not shown or not dialog then pending = nil; message("close the other dialogs and try again."); return false end
    return true
end

function Q.Report(reason) message(reason or "this item cannot be deleted safely.") end

if StaticPopupDialogs then
    StaticPopupDialogs[POPUP] = {
        text = "HC One Button\nDestroy %s x%s?\n\nThe ENTIRE stack will be destroyed. This cannot be undone by the addon.",
        button1 = DELETE or "Delete", button2 = CANCEL or "Cancel",
        OnAccept = function(_, data) Q.Confirm(data) end,
        OnCancel = function() pending = nil end,
        OnHide = function() pending = nil end,
        timeout = 0, whileDead = false, hideOnEscape = true, preferredIndex = 3,
    }
end
