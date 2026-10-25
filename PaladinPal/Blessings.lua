local ADDON_NAME, ns = ...

local _, playerClass = UnitClass("player")
if playerClass ~= "PALADIN" then return end

-- A movable list of group members missing a blessing that PallyPower has
-- assigned to a paladin in the group, and who's meant to cast it. It reads
-- PallyPower's saved assignments, so PallyPower has to be enabled too.

-- PallyPower's blessing numbers, as normal and greater spell IDs. Sacrifice
-- is left out since it only lasts 30 seconds.
local BLESSINGS = {
    [1] = { 19742, 25894 },  -- Wisdom
    [2] = { 19740, 25782 },  -- Might
    [3] = { 20217, 25898 },  -- Kings
    [4] = { 1038, 25895 },   -- Salvation
    [5] = { 19977, 25890 },  -- Light
    [6] = { 20911, 25899 },  -- Sanctuary
}
local SALVATION = 4
-- PallyPower's class numbers in TBC, used if its own table isn't there.
local CLASS_IDS = {
    WARRIOR = 1, ROGUE = 2, PRIEST = 3, DRUID = 4, PALADIN = 5,
    HUNTER = 6, MAGE = 7, WARLOCK = 8, SHAMAN = 9,
}
local MAX_ROWS = 15
local ROW_HEIGHT = 18
local WIDTH = 330
local NAME_X, BLESSING_X, PALADIN_X = 24, 140, 230

local function GetName(spellID)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    return (GetSpellInfo(spellID))
end

local function GetIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spellID) end
    return GetSpellTexture(spellID)
end

-- "Kings" from "Blessing of Kings", for the narrow column.
local function ShortName(blessing)
    local name = GetName(BLESSINGS[blessing][1]) or "?"
    return name:match("of (.+)$") or name
end

-- Either rank of the blessing counts, from whoever cast it.
local function HasBlessing(buffs, blessing)
    local normal, greater = GetName(BLESSINGS[blessing][1]), GetName(BLESSINGS[blessing][2])
    return (normal and buffs[normal]) or (greater and buffs[greater]) or false
end

local function BuffNames(unit)
    local buffs = {}
    for i = 1, 40 do
        local name = UnitBuff(unit, i)
        if not name then break end
        buffs[name] = true
    end
    return buffs
end

local function GroupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
    end
    return units
end

-- The blessing a paladin is meant to give this player: a single-target
-- assignment wins over the one for their class. Returns nil for none.
local function AssignedBlessing(paladin, classID, name)
    local blessing
    local normal = PallyPower_NormalAssignments and PallyPower_NormalAssignments[paladin]
    if normal and normal[classID] then blessing = normal[classID][name] end
    if not blessing or blessing == 0 then
        blessing = PallyPower_Assignments[paladin] and PallyPower_Assignments[paladin][classID]
    end
    if BLESSINGS[blessing] then return blessing end
end

local missing = {}

local function Scan()
    wipe(missing)
    if type(PallyPower_Assignments) ~= "table" then return end
    local me = GetUnitName("player", true)
    local classIDs = (PallyPower and PallyPower.ClassToID) or CLASS_IDS
    local units = GroupUnits()

    -- Only paladins in the group count; PallyPower can keep old ones around.
    local paladins = {}
    for _, unit in ipairs(units) do
        local _, class = UnitClass(unit)
        local name = GetUnitName(unit, true)
        if class == "PALADIN" and name and PallyPower_Assignments[name] then
            paladins[#paladins + 1] = name
        end
    end
    if #paladins == 0 then return end

    for _, unit in ipairs(units) do
        -- Skip players nobody can buff right now: offline, dead, or too far to see.
        if UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and UnitIsVisible(unit) then
            local name = GetUnitName(unit, true)
            local _, class = UnitClass(unit)
            local classID = class and classIDs[class]
            -- Tanks click off Salvation, so don't nag about it.
            local isTank = GetPartyAssignment("MAINTANK", unit)
            local buffs
            for _, paladin in ipairs(paladins) do
                local blessing = classID and AssignedBlessing(paladin, classID, name)
                if blessing and not (blessing == SALVATION and isTank) then
                    buffs = buffs or BuffNames(unit)
                    if not HasBlessing(buffs, blessing) then
                        missing[#missing + 1] = {
                            name = name, class = class, blessing = blessing,
                            paladin = paladin, mine = paladin == me,
                        }
                    end
                end
            end
        end
    end

    -- Yours first, then grouped by paladin and blessing.
    table.sort(missing, function(a, b)
        if a.mine ~= b.mine then return a.mine end
        if a.paladin ~= b.paladin then return a.paladin < b.paladin end
        if a.blessing ~= b.blessing then return a.blessing < b.blessing end
        return a.name < b.name
    end)
end

local SAMPLE = {
    { name = "Jaina", class = "MAGE", blessing = 3, mine = true },
    { name = "Thrall", class = "SHAMAN", blessing = 1, mine = true },
    { name = "Garrosh", class = "WARRIOR", blessing = 2, paladin = "Uther" },
}

local function ClassColored(text, class)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not color then return text end
    return ("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, text)
end

local function CreateText(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function CreatePanel()
    local panel = CreateFrame("Frame", "PaladinPal_blessings", UIParent)
    panel:SetSize(WIDTH, 40)
    panel:Hide()

    local backdrop = panel:CreateTexture(nil, "BACKGROUND")
    backdrop:SetAllPoints()
    backdrop:SetColorTexture(0, 0, 0, 0.35)

    local title = CreateText(panel, 15)
    title:SetPoint("TOPLEFT", 6, -6)
    title:SetTextColor(0.3, 1, 0.5)

    local rows = {}
    for i = 1, MAX_ROWS do
        local y = -26 - (i - 1) * ROW_HEIGHT
        local row = {}
        row.icon = panel:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ROW_HEIGHT - 2, ROW_HEIGHT - 2)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.icon:SetPoint("TOPLEFT", 6, y)
        row.name = CreateText(panel, 13)
        row.name:SetPoint("TOPLEFT", NAME_X, y - 1)
        row.name:SetWidth(BLESSING_X - NAME_X - 4)
        row.blessing = CreateText(panel, 13)
        row.blessing:SetPoint("TOPLEFT", BLESSING_X, y - 1)
        row.blessing:SetWidth(PALADIN_X - BLESSING_X - 4)
        row.paladin = CreateText(panel, 13)
        row.paladin:SetPoint("TOPLEFT", PALADIN_X, y - 1)
        row.paladin:SetWidth(WIDTH - PALADIN_X - 6)
        rows[i] = row
    end

    local more = CreateText(panel, 12)
    more:SetTextColor(0.75, 0.75, 0.75)

    function panel:ShowList(list)
        title:SetText(("MISSING BLESSINGS (%d)"):format(#list))
        local shown = math.min(#list, MAX_ROWS)
        for i, row in ipairs(rows) do
            local entry = list[i]
            local visible = i <= shown
            if visible then
                row.icon:SetTexture(GetIcon(BLESSINGS[entry.blessing][2]))
                row.name:SetText(ClassColored(Ambiguate(entry.name, "short"), entry.class))
                row.blessing:SetText(ShortName(entry.blessing))
                if entry.mine then
                    row.paladin:SetText("|cffff5050you|r")
                else
                    row.paladin:SetText(ClassColored(Ambiguate(entry.paladin, "short"), "PALADIN"))
                end
            end
            row.icon:SetShown(visible)
            row.name:SetShown(visible)
            row.blessing:SetShown(visible)
            row.paladin:SetShown(visible)
        end
        local height = 30 + shown * ROW_HEIGHT
        if #list > MAX_ROWS then
            more:SetText(("+%d more"):format(#list - MAX_ROWS))
            more:ClearAllPoints()
            more:SetPoint("TOPLEFT", NAME_X, -26 - shown * ROW_HEIGHT)
            more:Show()
            height = height + ROW_HEIGHT
        else
            more:Hide()
        end
        self:SetHeight(height)
    end

    return panel
end

ns.blessingsReminder = {
    key = "blessings",
    name = "Missing blessings",
    -- Grows downward from its top-left corner as the list gets longer.
    defaultPos = { "TOPLEFT", "TOPLEFT", 40, -220 },
    create = CreatePanel,
    check = function()
        if UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then return false end
        if UnitAffectingCombat("player") and not PaladinPalDB.blessingsCombat then return false end
        Scan()
        return #missing > 0
    end,
    refresh = function(panel, unlocked)
        panel:ShowList(unlocked and SAMPLE or missing)
    end,
}
