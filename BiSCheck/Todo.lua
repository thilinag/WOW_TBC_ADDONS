local ADDON_NAME, ns = ...

-- BiSCheck.lua stops early on other classes, so there's nothing to add to.
if not ns.todoPage then return end

-- The To-do page: for every slot that isn't BiS yet, its next upgrade and
-- its BiS item, grouped by where they come from. The places with the most
-- items come first. Rebuilt on every update, so it follows your gear.

local LINE_HEIGHT = 18
local NEXT_MARK = "|cffffd100+|r"
local BIS_MARK = "|cff00ff00*|r"

-- First match wins, so specific names come before broad words like "Quest".
local PLACES = {
    { "Black Temple", "Black Temple" },
    { "Hyjal", "Hyjal Summit" },
    { "Zul'Aman", "Zul'Aman" },
    { "Serpentshrine", "Serpentshrine Cavern" },
    { "Tempest Keep", "Tempest Keep" },
    { "Kael'thas", "Tempest Keep" },
    { "Al'ar", "Tempest Keep" },
    { "Karazhan", "Karazhan" },
    { "Maiden of Virtue", "Karazhan" },
    { "Malchezaar", "Karazhan" },
    { "Magtheridon", "Magtheridon's Lair" },
    { "Gruul", "Gruul's Lair" },
    { "World Boss", "World bosses" },
    { "Doomwalker", "World bosses" },
    { "Kazzak", "World bosses" },
    { "Badge", "Badges of Justice" },
    { "G'eras", "Badges of Justice" },
    { "Arena", "PvP" },
    { "Honor Points", "PvP" },
    { "Profession", "Crafting" },
    { "Naxxramas", "Classic raids" },
    { "Blackwing", "Classic raids" },
    { "Brewfest", "Brewfest (seasonal)" },
    { "Revered", "Reputation" },
    { "Exalted", "Reputation" },
    { "Heroic", "Dungeons" },
    { "Botanica", "Dungeons" },
    { "Sethekk", "Dungeons" },
    { "Quest", "Quests" },
}

local function Place(source)
    for _, place in ipairs(PLACES) do
        if source:find(place[1], 1, true) then return place[2] end
    end
    return "Other"
end

-- The boss or vendor without the place, which the group header already shows.
local function Who(source)
    return (source:gsub("%s*%b()", ""):gsub("^.-Champion %- ", ""):gsub("^.- from ", ""))
end

local page = ns.todoPage
local width = ns.PANEL_WIDTH - 54

local scroll = CreateFrame("ScrollFrame", "BiSCheckTodoScroll", page, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 14, 0)
scroll:SetPoint("BOTTOMRIGHT", -32, 14)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(width, 1)
scroll:SetScrollChild(content)

local lines = {}

local function ShowLineTooltip(line)
    local item = line.item
    GameTooltip:SetOwner(line, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. item.entry[1])
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("For: " .. table.concat(item.slots, ", "), 1, 1, 1)
    GameTooltip:AddLine("From: " .. item.entry[2], 1, 1, 1)
    if item.isNext then GameTooltip:AddLine(NEXT_MARK .. " Next upgrade over what you wear") end
    if item.isBiS then GameTooltip:AddLine(BIS_MARK .. " Best in slot (" .. item.entry.label .. ")") end
    GameTooltip:Show()
end

local function GetLine(index)
    local line = lines[index]
    if line then return line end

    line = CreateFrame("Button", nil, content)
    line:SetSize(width, LINE_HEIGHT)
    line:SetPoint("TOPLEFT", 0, -(index - 1) * LINE_HEIGHT)

    local highlight = line:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    line.highlight = highlight

    line.mark = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    line.mark:SetPoint("LEFT", 2, 0)
    line.mark:SetWidth(10)

    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(14, 14)
    line.icon:SetPoint("LEFT", 14, 0)
    line.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    line.right = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    line.right:SetPoint("RIGHT", -2, 0)
    line.right:SetJustifyH("RIGHT")
    line.right:SetWordWrap(false)

    line.left = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    line.left:SetJustifyH("LEFT")
    line.left:SetWordWrap(false)

    line:SetScript("OnEnter", function(self)
        if self.item then ShowLineTooltip(self) end
    end)
    line:SetScript("OnLeave", function() GameTooltip:Hide() end)
    line:SetScript("OnClick", function(self)
        if self.item and IsModifiedClick("CHATLINK") then
            local _, link = GetItemInfo(self.item.entry[1])
            if link then ChatEdit_InsertLink(link) end
        end
    end)

    lines[index] = line
    return line
end

local function SetHeader(line, text, count)
    line.item = nil
    line.highlight:Hide()
    line.mark:SetText("")
    line.icon:Hide()
    line.left:SetFontObject("GameFontNormal")
    line.left:ClearAllPoints()
    line.left:SetPoint("LEFT", 2, 0)
    line.left:SetPoint("RIGHT", line.right, "LEFT", -4, 0)
    line.left:SetText(text)
    line.right:SetWidth(0)
    line.right:SetText(count and ("|cff888888%d item%s|r"):format(count, count == 1 and "" or "s") or "")
end

local function SetItem(line, item)
    line.item = item
    line.highlight:Show()
    line.mark:SetText(item.isNext and NEXT_MARK or BIS_MARK)
    line.icon:SetTexture(ns.ItemIcon(item.entry[1]))
    line.icon:Show()
    line.right:SetWidth(100)
    line.right:SetText("|cff999999" .. Who(item.entry[2]) .. "|r")
    line.left:SetFontObject("GameFontHighlightSmall")
    line.left:ClearAllPoints()
    line.left:SetPoint("LEFT", line.icon, "RIGHT", 4, 0)
    line.left:SetPoint("RIGHT", line.right, "LEFT", -4, 0)
    line.left:SetText(ns.ItemText(item.entry[1]) .. " |cff888888" .. table.concat(item.slots, ", ") .. "|r")
end

-- rows are the Upgrades page rows, each with .slot and the .result of
-- comparing it with the guide.
function ns.UpdateTodo(rows)
    local items, byID = {}, {}

    local function Add(entry, slot, isNext)
        local item = byID[entry[1]]
        if not item then
            item = { entry = entry, slots = {}, place = Place(entry[2]) }
            byID[entry[1]] = item
            items[#items + 1] = item
        end
        if not tContains(item.slots, slot.label) then
            item.slots[#item.slots + 1] = slot.label
        end
        if isNext then item.isNext = true end
        if ns.IsBiS(entry) then item.isBiS = true end
    end

    for _, row in ipairs(rows) do
        local result = row.result
        if result and result.nextUp then
            Add(result.nextUp, row.slot, true)
            for _, entry in ipairs(result.list) do
                if ns.IsBiS(entry) and (entry[1] ~= result.other or entry.dup) then
                    Add(entry, row.slot, false)
                    break
                end
            end
        end
    end

    local groups, byPlace = {}, {}
    for _, item in ipairs(items) do
        local group = byPlace[item.place]
        if not group then
            group = { place = item.place, items = {} }
            byPlace[item.place] = group
            groups[#groups + 1] = group
        end
        group.items[#group.items + 1] = item
    end
    table.sort(groups, function(a, b)
        if #a.items ~= #b.items then return #a.items > #b.items end
        return a.place < b.place
    end)

    local count = 0
    local function NextLine()
        count = count + 1
        local line = GetLine(count)
        line:Show()
        return line
    end

    SetHeader(NextLine(), NEXT_MARK .. " next upgrade   " .. BIS_MARK .. " best in slot")
    if #groups == 0 then
        SetHeader(NextLine(), "|cff00ff00Every slot is BiS for this phase.|r")
    end
    for _, group in ipairs(groups) do
        SetHeader(NextLine(), group.place, #group.items)
        for _, item in ipairs(group.items) do
            SetItem(NextLine(), item)
        end
    end

    for i = count + 1, #lines do
        lines[i]:Hide()
    end
    content:SetHeight(math.max(1, count * LINE_HEIGHT))
end
