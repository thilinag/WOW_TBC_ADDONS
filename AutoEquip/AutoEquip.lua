local ADDON_NAME = ...

local SKIP_SLOTS = {
    [INVSLOT_BODY] = true,   -- shirt
    [INVSLOT_TABARD] = true, -- tabard
}

local SLOT_NAMES = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist",
    [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Finger 1",
    [12] = "Finger 2", [13] = "Trinket 1", [14] = "Trinket 2", [15] = "Back",
    [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged",
}

local wasInInstance = false
local pending = false

local frame = CreateFrame("Frame")

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AutoEquip|r: " .. msg)
end

local function ItemIDFromLink(link)
    if not link then return nil end
    return tonumber(link:match("item:(%d+)"))
end

local function InInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "party" or instanceType == "raid")
end

local function SaveSet()
    local set = {}
    local count = 0
    for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        if not SKIP_SLOTS[slot] then
            local link = GetInventoryItemLink("player", slot)
            if link then
                set[slot] = link
                count = count + 1
            end
        end
    end
    AutoEquipDB.set = set
    Print(("saved %d items."):format(count))
end

local MAX_ATTEMPTS = 5
local RETRY_DELAY = 1

local function EquipSet(attempt)
    attempt = attempt or 1
    if not next(AutoEquipDB.set) then
        Print("no set saved. Wear your gear and type /ae save.")
        return
    end

    if InCombatLockdown() or UnitAffectingCombat("player") then
        if not pending then
            pending = true
            Print("in combat, will equip when combat ends.")
        end
        return
    end

    local equipped, missing = 0, {}
    for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local link = AutoEquipDB.set[slot]
        local itemID = ItemIDFromLink(link)
        if itemID and GetInventoryItemID("player", slot) ~= itemID then
            if IsEquippedItem(itemID) or GetItemCount(itemID) > 0 then
                EquipItemByName(link, slot)
                equipped = equipped + 1
            else
                missing[#missing + 1] = link
            end
        end
    end

    if equipped > 0 then
        Print(("equipped instance set (%d items)."):format(equipped))
    end
    if #missing > 0 then
        -- Inventory data can lag behind a loading screen; retry before
        -- reporting items as missing.
        if attempt < MAX_ATTEMPTS then
            C_Timer.After(RETRY_DELAY, function() EquipSet(attempt + 1) end)
        else
            Print("missing " .. table.concat(missing, ", "))
        end
    end
end

local function CheckZone()
    local inInstance = InInstance()
    if inInstance and not wasInInstance and AutoEquipDB.enabled then
        -- Give the client a moment to load inventory after the loading screen.
        C_Timer.After(RETRY_DELAY, function() EquipSet() end)
    end
    wasInInstance = inInstance
end

local function ShowSet()
    if not next(AutoEquipDB.set) then
        Print("no set saved.")
        return
    end
    Print(("saved set (auto-equip %s):"):format(AutoEquipDB.enabled and "on" or "off"))
    for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local link = AutoEquipDB.set[slot]
        if link then
            Print(("  %s: %s"):format(SLOT_NAMES[slot] or slot, link))
        end
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON_NAME then
            AutoEquipDB = AutoEquipDB or {}
            if AutoEquipDB.enabled == nil then AutoEquipDB.enabled = true end
            -- Clean up settings from the removed mount trinket swap.
            AutoEquipDB.mountEnabled = nil
            AutoEquipDB.mountPrev = nil
            AutoEquipDB.set = AutoEquipDB.set or {}
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        if isInitialLogin or isReloadingUi then
            -- Don't equip on login/reload; just record where we are.
            wasInInstance = InInstance()
        else
            CheckZone()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        CheckZone()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then
            pending = false
            EquipSet()
        end
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

SLASH_AUTOEQUIP1 = "/autoequip"
SLASH_AUTOEQUIP2 = "/ae"
SlashCmdList.AUTOEQUIP = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "save" then
        SaveSet()
    elseif cmd == "equip" then
        EquipSet()
    elseif cmd == "show" then
        ShowSet()
    elseif cmd == "on" then
        AutoEquipDB.enabled = true
        Print("auto-equip enabled.")
    elseif cmd == "off" then
        AutoEquipDB.enabled = false
        Print("auto-equip disabled.")
    elseif cmd == "clear" then
        AutoEquipDB.set = {}
        Print("saved set cleared.")
    else
        Print("commands: save, equip, show, on, off, clear")
    end
end
