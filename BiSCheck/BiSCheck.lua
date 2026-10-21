local ADDON_NAME, ns = ...

-- The lists are for Holy Paladin, so other classes get nothing.
local _, playerClass = UnitClass("player")
if playerClass ~= "PALADIN" then return end

local DEFAULTS = { shown = true, phase = 4, page = "upgrades" }
local ROW_HEIGHT = 21
local PANEL_WIDTH = 330
local ICON_READY = "Interface\\RaidFrame\\ReadyCheck-Ready"
local ICON_NOT_READY = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local ENCHANTING = GetSpellInfo(7411)

local rows = {}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BiSCheck|r: " .. msg)
end

-- Item names and icons come from the item cache, which can be empty for
-- items you've never seen. GET_ITEM_INFO_RECEIVED refreshes the panel when
-- they arrive.
local function ItemText(itemID)
    local name, _, quality = GetItemInfo(itemID)
    if not name then return "|cff888888item " .. itemID .. "|r" end
    local color = ITEM_QUALITY_COLORS[quality] or ITEM_QUALITY_COLORS[1]
    return color.hex .. name .. "|r"
end

local function ItemIcon(itemID)
    return select(5, GetItemInfoInstant(itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- The guides rank several items as BiS for some slots (haste or not, shield
-- or off-hand, one per libram style). Phase 2 calls them "Best".
local function IsBiS(entry)
    return entry.label:find("^BiS") or entry.label:find("^Best")
end

-- Compares the equipped item with the guide's list. Any BiS item counts as
-- done. Otherwise the next upgrade is the closest item ranked above it, or
-- the lowest-ranked item when what you wear isn't on the list. Rings and
-- trinkets skip whatever the other slot wears, unless you can wear two.
local function Evaluate(slot)
    local list = ns.LISTS[BiSCheckDB.phase][slot.list]
    local equipped = GetInventoryItemID("player", slot.id)
    local other = slot.pair and GetInventoryItemID("player", slot.pair)

    local rank
    for i, entry in ipairs(list) do
        if entry[1] == equipped then rank = i break end
    end

    local nextUp
    if not (rank and IsBiS(list[rank])) then
        for i = (rank or #list + 1) - 1, 1, -1 do
            local entry = list[i]
            if entry[1] ~= other or entry.dup then nextUp = entry break end
        end
    end

    return { list = list, equipped = equipped, rank = rank, nextUp = nextUp, other = other }
end

local function HasEnchanting()
    for i = 1, GetNumSkillLines() do
        if GetSkillLineInfo(i) == ENCHANTING then return true end
    end
    return false
end

-- nil when the slot has nothing that counts, otherwise
-- { missing = bool, current = enchant ID, match = recommended entry or nil }.
local function EnchantStatus(slotID)
    local options = ns.ENCHANTS[slotID]
    local link = GetInventoryItemLink("player", slotID)
    if not options or not link then return nil end
    if options.needs == "enchanting" and not HasEnchanting() then return nil end
    if options.needs == "shield" and select(4, GetItemInfoInstant(link)) ~= "INVTYPE_SHIELD" then
        return nil
    end

    local current = tonumber(link:match("item:%d+:(%d*)")) or 0
    local match
    for _, option in ipairs(options) do
        if option[1] == current then match = option break end
    end
    return { missing = current == 0, current = current, match = match, options = options }
end

-- Shared with Todo.lua.
ns.ItemText, ns.ItemIcon, ns.IsBiS = ItemText, ItemIcon, IsBiS
ns.PANEL_WIDTH = PANEL_WIDTH

local panel = CreateFrame("Frame", "BiSCheckPanel", PaperDollFrame, "BackdropTemplate")
panel:SetSize(PANEL_WIDTH, 86 + #ns.SLOTS * ROW_HEIGHT)
-- CharacterFrame's art stops short of its right edge, so pull the panel in.
panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", -32, -13)
panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
})

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
title:SetPoint("TOPLEFT", 16, -14)

local summary = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -4, -4)
close:SetScript("OnClick", function()
    BiSCheckDB.shown = false
    panel:Hide()
end)

-- Phase buttons in the header, left of the close button. The chosen one
-- stays highlighted.
local phaseButtons = {}

local function SetPhase(phase)
    BiSCheckDB.phase = phase
    ns.Update()
end

local function UpdatePhaseButtons()
    for phase, button in pairs(phaseButtons) do
        if phase == BiSCheckDB.phase then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
end

for i = #ns.PHASES, 1, -1 do
    local phase = ns.PHASES[i]
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(32, 20)
    button:SetText("P" .. phase)
    local offset = (#ns.PHASES - i) * 34
    button:SetPoint("TOPRIGHT", -34 - offset, -8)
    button:SetScript("OnClick", function() SetPhase(phase) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Phase " .. phase .. " BiS list")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    phaseButtons[phase] = button
end

-- Two pages under the header: the per-slot upgrades, and the to-do list
-- (Todo.lua) of where to get them.
local pages = {}
local pageButtons = {}

local function NewPage(key)
    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", 0, -74)
    page:SetPoint("BOTTOMRIGHT")
    page:Hide()
    pages[key] = page
    return page
end

local upgradesPage = NewPage("upgrades")
ns.todoPage = NewPage("todo")

local function SetPage(key)
    if not pages[key] then key = "upgrades" end
    BiSCheckDB.page = key
    for pageKey, page in pairs(pages) do
        page:SetShown(pageKey == key)
        if pageKey == key then
            pageButtons[pageKey]:LockHighlight()
        else
            pageButtons[pageKey]:UnlockHighlight()
        end
    end
    ns.Update()
end

for i, info in ipairs({ { "upgrades", "Upgrades" }, { "todo", "To-do" } }) do
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(80, 20)
    button:SetText(info[2])
    button:SetPoint("TOPLEFT", 14 + (i - 1) * 84, -48)
    button:SetScript("OnClick", function() SetPage(info[1]) end)
    pageButtons[info[1]] = button
end

local function ShowRowTooltip(row)
    local slot, result, enchant = row.slot, row.result, row.enchant
    if not result then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(slot.label)

    if not result.equipped then
        GameTooltip:AddLine("Nothing equipped", 1, 0.3, 0.3)
    elseif result.rank then
        GameTooltip:AddLine(("Equipped: %s  (%d of %d)"):format(ItemText(result.equipped), result.rank, #result.list), 1, 1, 1)
    else
        GameTooltip:AddLine("Equipped: " .. ItemText(result.equipped) .. "  (not on the list)", 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Guide ranking")
    for i, entry in ipairs(result.list) do
        local marker = "   "
        if entry[1] == result.equipped then
            marker = "|cff00ff00>|r "
        elseif entry == result.nextUp then
            marker = "|cffffd100+|r "
        end
        local label = (IsBiS(entry) and " |cff00ff00" or " |cffaaaaaa") .. entry.label .. "|r"
        local worn = entry[1] == result.other and " |cff888888(other slot)|r" or ""
        GameTooltip:AddDoubleLine(("%s%d. %s%s%s"):format(marker, i, ItemText(entry[1]), label, worn),
            entry[2], 1, 1, 1, 0.6, 0.6, 0.6)
    end

    if enchant then
        GameTooltip:AddLine(" ")
        if enchant.missing then
            GameTooltip:AddLine("Enchant: missing", 1, 0.3, 0.3)
        elseif enchant.match then
            GameTooltip:AddLine("Enchant: " .. enchant.match[2], 0.3, 1, 0.3)
        else
            GameTooltip:AddLine("Enchant: a different one (ID " .. enchant.current .. ")", 1, 0.82, 0)
        end
        if not enchant.match then
            for i, option in ipairs(enchant.options) do
                GameTooltip:AddDoubleLine((i == 1 and "Use: " or "  or: ") .. option[2], option[3],
                    1, 1, 1, 0.6, 0.6, 0.6)
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Shift-click to link the next upgrade.", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function CreateRow(index, slot)
    local row = CreateFrame("Button", nil, upgradesPage)
    row:SetSize(PANEL_WIDTH - 28, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 14, -(index - 1) * ROW_HEIGHT)
    row.slot = slot

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)

    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetWidth(64)
    row.label:SetJustifyH("LEFT")
    row.label:SetText(slot.label)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 68, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.enchantIcon = row:CreateTexture(nil, "ARTWORK")
    row.enchantIcon:SetSize(14, 14)
    row.enchantIcon:SetPoint("RIGHT", -2, 0)

    row.rank = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.rank:SetPoint("RIGHT", row.enchantIcon, "LEFT", -6, 0)
    row.rank:SetWidth(36)
    row.rank:SetJustifyH("RIGHT")

    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.text:SetPoint("RIGHT", row.rank, "LEFT", -4, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    row:SetScript("OnEnter", ShowRowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        local target = self.result and self.result.nextUp
        if target and IsModifiedClick("CHATLINK") then
            local _, link = GetItemInfo(target[1])
            if link then ChatEdit_InsertLink(link) end
        end
    end)
    return row
end

for i, slot in ipairs(ns.SLOTS) do
    rows[i] = CreateRow(i, slot)
end

function ns.Update()
    if not panel:IsVisible() then return end
    local bisCount, missingEnchants = 0, 0

    for _, row in ipairs(rows) do
        local result = Evaluate(row.slot)
        local enchant = EnchantStatus(row.slot.id)
        row.result, row.enchant = result, enchant

        if result.equipped and not result.nextUp then
            bisCount = bisCount + 1
            row.icon:SetTexture(ItemIcon(result.equipped))
            row.text:SetText(ItemText(result.equipped))
            row.rank:SetText("|cff00ff00BiS|r")
        elseif result.nextUp then
            row.icon:SetTexture(ItemIcon(result.nextUp[1]))
            row.text:SetText(ItemText(result.nextUp[1]))
            row.rank:SetText(result.rank and (result.rank .. "/" .. #result.list) or "|cff888888-|r")
        else
            row.icon:SetTexture(nil)
            row.text:SetText("|cff888888No list|r")
            row.rank:SetText("")
        end

        if not enchant then
            row.enchantIcon:Hide()
        else
            if enchant.missing then missingEnchants = missingEnchants + 1 end
            row.enchantIcon:SetTexture(enchant.missing and ICON_NOT_READY or ICON_READY)
            row.enchantIcon:Show()
        end
    end

    UpdatePhaseButtons()
    if ns.todoPage:IsShown() then ns.UpdateTodo(rows) end
    local heading = ns.todoPage:IsShown() and "To-do" or "Next upgrades"
    title:SetText(("%s  |cff888888Phase %d|r"):format(heading, BiSCheckDB.phase))
    local enchantText = missingEnchants == 0 and "|cff00ff00all enchanted|r"
        or ("|cffff4d4d%d missing enchant%s|r"):format(missingEnchants, missingEnchants == 1 and "" or "s")
    summary:SetText(("BiS in %d of %d slots  -  %s"):format(bisCount, #rows, enchantText))

    local owner = GameTooltip:GetOwner()
    if owner and owner.slot and GameTooltip:IsShown() then ShowRowTooltip(owner) end
end

panel:SetScript("OnShow", ns.Update)

-- Toggle button on the character tab, next to the close button.
local toggle = CreateFrame("Button", nil, PaperDollFrame, "UIPanelButtonTemplate")
toggle:SetSize(42, 20)
toggle:SetText("BiS")
toggle:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -44, -40)
toggle:SetScript("OnClick", function()
    BiSCheckDB.shown = not panel:IsShown()
    panel:SetShown(BiSCheckDB.shown)
end)

-- Item info and equipment events arrive in bursts, so batch them.
local pending = false
local function QueueUpdate()
    if pending or not panel:IsVisible() then return end
    pending = true
    C_Timer.After(0.1, function()
        pending = false
        ns.Update()
    end)
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            BiSCheckDB = BiSCheckDB or {}
            for key, value in pairs(DEFAULTS) do
                if BiSCheckDB[key] == nil then BiSCheckDB[key] = value end
            end
            SetPage(BiSCheckDB.page)
            panel:SetShown(BiSCheckDB.shown)
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
        return
    else
        QueueUpdate()
    end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:RegisterEvent("SKILL_LINES_CHANGED")

SLASH_BISCHECK1 = "/bischeck"
SLASH_BISCHECK2 = "/bis"
SlashCmdList.BISCHECK = function(msg)
    local cmd, arg = strsplit(" ", strtrim(msg or ""):lower())
    if cmd == "" or cmd == "toggle" then
        BiSCheckDB.shown = not BiSCheckDB.shown
        panel:SetShown(BiSCheckDB.shown)
        if not PaperDollFrame:IsVisible() then ToggleCharacter("PaperDollFrame") end
    elseif cmd == "phase" and ns.LISTS[tonumber(arg or "")] then
        SetPhase(tonumber(arg))
        Print("Using the Phase " .. arg .. " list.")
    elseif cmd == "enchants" then
        -- Prints enchant IDs so a wrong ID in Data.lua is easy to spot.
        for _, slot in ipairs(ns.SLOTS) do
            local link = GetInventoryItemLink("player", slot.id)
            if link then
                Print(("%s: %s enchant %s"):format(slot.label, link, link:match("item:%d+:(%d*)") or "?"))
            end
        end
    else
        Print("/bis - show or hide the panel")
        Print("/bis phase 2 | 3 | 4 - which phase's BiS list to compare against")
        Print("/bis enchants - print the enchant ID on each equipped item")
    end
end
