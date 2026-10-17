local ADDON_NAME = ...

-- Paladin auras live on the stance bar in TBC, so GetShapeshiftForm()
-- tells us whether one is active without matching spell names.
local _, playerClass = UnitClass("player")
if playerClass ~= "PALADIN" then return end

local DIVINE_FAVOR = 20216
local DIVINE_ILLUMINATION = 31842
-- Each rank is a separate spell ID. You need the seal to judge it.
local SEAL_OF_WISDOM_RANKS = { 20166, 20356, 20357, 27166 }
-- Debuff IDs left on the target, keyed for lookup.
local JUDGEMENT_OF_WISDOM_RANKS = { [20186] = true, [20354] = true, [20355] = true, [27164] = true }
local JUDGEMENT_OF_WISDOM = 20186
-- There's no distance API for enemies, so range is bracketed by checking
-- which of these are in range. Spells you haven't learned are skipped, and
-- Exorcism only checks undead and demons.
local JUDGEMENT = 20271
local RANGE_PROBES = {
    { yards = 10, spell = JUDGEMENT },
    { yards = 20, spell = 20473 },   -- Holy Shock
    { yards = 28, interact = 4 },    -- follow distance
    { yards = 30, spell = 24275 },   -- Hammer of Wrath
    { yards = 30, spell = 31935 },   -- Avenger's Shield
    { yards = 30, spell = 879 },     -- Exorcism
}
local RANGE_INTERVAL = 0.1
-- Cooldowns at or below this are just the global cooldown.
local GCD_THRESHOLD = 1.5
local ICON_SIZE = 40
local ICON_GAP = 8

local unlocked = false

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99PaladinPal|r: " .. msg)
end

local function GetIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    end
    return GetSpellTexture(spellID)
end

local function CreateWarning(reminder)
    local posKey = reminder.key .. "Pos"
    local warning = CreateFrame("Frame", "PaladinPal_" .. reminder.key, UIParent)
    warning:SetSize(480, 50)
    warning:SetMovable(true)
    warning:SetClampedToScreen(true)
    warning:RegisterForDrag("LeftButton")
    warning:Hide()

    local text = warning:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 32, "THICKOUTLINE")
    text:SetTextColor(unpack(reminder.color))
    text:SetText(reminder.text)

    if reminder.spell then
        local icon = warning:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon:SetPoint("RIGHT", text, "LEFT", -ICON_GAP, 0)
        warning.icon = icon
        -- Shift the text so icon + text stay centered as a group.
        text:SetPoint("CENTER", (ICON_SIZE + ICON_GAP) / 2, 0)
    else
        text:SetPoint("CENTER")
    end

    local bg = warning:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)
    bg:Hide()
    warning.bg = bg

    local pulse = warning:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.3)
    fade:SetDuration(0.6)

    warning:SetScript("OnShow", function(self)
        -- Spell textures can be nil until spell data has loaded, so fill on show.
        if self.icon and not self.icon:GetTexture() then
            self.icon:SetTexture(GetIcon(reminder.spell))
        end
        pulse:Play()
    end)
    warning:SetScript("OnHide", function() pulse:Stop() end)
    warning:SetScript("OnDragStart", function(self) self:StartMoving() end)
    warning:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        PaladinPalDB[posKey] = { point, relPoint, x, y }
    end)

    function warning:ApplyPosition()
        local pos = PaladinPalDB[posKey]
        self:ClearAllPoints()
        if pos then
            self:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
        else
            self:SetPoint("CENTER", UIParent, "CENTER", 0, reminder.defaultY)
        end
    end

    function warning:Nudge(dx, dy)
        local point, _, relPoint, x, y = self:GetPoint()
        PaladinPalDB[posKey] = { point, relPoint, x + dx, y + dy }
        self:ApplyPosition()
    end

    function warning:ResetPosition()
        PaladinPalDB[posKey] = nil
        self:ApplyPosition()
    end

    return warning
end

local function GetCooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then return info.startTime, info.duration end
        return 0, 0
    end
    return GetSpellCooldown(spellID)
end

local function HasBuff(spellID)
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, id = UnitBuff("player", i)
        if not name then return false end
        if id == spellID then return true end
    end
    return false
end

local function InDungeonOrRaid()
    local _, instanceType = IsInInstance()
    return instanceType == "party" or instanceType == "raid"
end

local Update
local recheckPending = false

-- SPELL_UPDATE_COOLDOWN doesn't reliably fire the moment a cooldown ends,
-- so schedule a re-check for when it should be ready.
local function ScheduleRecheck(delay)
    if recheckPending then return end
    recheckPending = true
    C_Timer.After(delay + 0.1, function()
        recheckPending = false
        Update()
    end)
end

-- Returns true when the spell is off cooldown, ignoring the global cooldown.
local function SpellReady(spellID)
    local start, duration = GetCooldown(spellID)
    if start and start > 0 and duration > GCD_THRESHOLD then
        ScheduleRecheck(start + duration - GetTime())
        return false
    end
    return true
end

-- For talented cooldowns worth pressing on pull: shows while the spell is
-- off cooldown in combat inside a dungeon or raid.
local function CombatCooldownReady(spellID)
    if not IsPlayerSpell(spellID) then return false end
    if UnitIsDeadOrGhost("player") or not UnitAffectingCombat("player") then return false end
    if not InDungeonOrRaid() then return false end
    -- Already popped and still active.
    if HasBuff(spellID) then return false end
    return SpellReady(spellID)
end

local function TargetHasDebuff(ids)
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, id = UnitDebuff("target", i)
        if not name then return false end
        if ids[id] then return true end
    end
    return false
end

-- Shows in combat while your hostile target lacks Judgement of Wisdom.
-- Any paladin's Judgement of Wisdom counts, since only one can be on a target.
local function JudgementMissing()
    local known = false
    for _, id in ipairs(SEAL_OF_WISDOM_RANKS) do
        if IsPlayerSpell(id) then known = true break end
    end
    if not known then return false end
    if UnitIsDeadOrGhost("player") or not UnitAffectingCombat("player") then return false end
    if not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then
        return false
    end
    return not TargetHasDebuff(JUDGEMENT_OF_WISDOM_RANKS)
end

-- To add a reminder, add an entry here. `key` is used for the slash
-- command (/pp <key> on|off) and saved settings; `check` returns true
-- when the warning should show. Set `spell` to show that spell's icon.
local reminders = {
    {
        key = "aura",
        name = "Aura",
        text = "NO AURA",
        color = { 1, 0.2, 0.2 },
        defaultY = 200,
        check = function()
            -- No auras learned yet (low level).
            if GetNumShapeshiftForms() == 0 then return false end
            if UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then return false end
            return GetShapeshiftForm() == 0
        end,
    },
    {
        key = "favor",
        name = "Divine Favor",
        text = "DIVINE FAVOR",
        spell = DIVINE_FAVOR,
        color = { 1, 0.82, 0 },
        defaultY = 145,
        check = function() return CombatCooldownReady(DIVINE_FAVOR) end,
    },
    {
        key = "illumination",
        name = "Divine Illumination",
        text = "DIVINE ILLUMINATION",
        spell = DIVINE_ILLUMINATION,
        color = { 0.4, 0.8, 1 },
        defaultY = 90,
        check = function() return CombatCooldownReady(DIVINE_ILLUMINATION) end,
    },
    {
        key = "wisdom",
        name = "Judgement of Wisdom",
        text = "JUDGEMENT OF WISDOM",
        spell = JUDGEMENT_OF_WISDOM,
        color = { 0.7, 0.5, 1 },
        defaultY = 35,
        check = JudgementMissing,
    },
}

local remindersByKey = {}
for _, reminder in ipairs(reminders) do
    reminder.warning = CreateWarning(reminder)
    remindersByKey[reminder.key] = reminder
end

-- Returns true or false, or nil when this probe can't check the target.
local function ProbeInRange(probe)
    if probe.interact then
        local ok, result = pcall(CheckInteractDistance, "target", probe.interact)
        if not ok or result == nil then return nil end
        return result and true or false
    end
    if not IsPlayerSpell(probe.spell) then return nil end
    -- Newer clients only have these under C_Spell, which also takes the ID.
    local result
    if C_Spell and C_Spell.IsSpellInRange then
        result = C_Spell.IsSpellInRange(probe.spell, "target")
    elseif IsSpellInRange and GetSpellInfo then
        local name = GetSpellInfo(probe.spell)
        if not name then return nil end
        result = IsSpellInRange(name, "target")
    end
    if result == nil then return nil end
    return result == 1 or result == true
end

-- Returns the target's distance as a bracket (lower, upper) in yards, with
-- upper nil when it's past every probe. Returns nil when in Judgement range
-- or when range can't be checked.
local function EstimateRange()
    local judge = ProbeInRange(RANGE_PROBES[1])
    if judge ~= false then return nil end
    local results, upper = {}, nil
    for i = 2, #RANGE_PROBES do
        local probe = RANGE_PROBES[i]
        results[i] = ProbeInRange(probe)
        if results[i] and (not upper or probe.yards < upper) then upper = probe.yards end
    end
    local lower = 10
    for i = 2, #RANGE_PROBES do
        local yards = RANGE_PROBES[i].yards
        if results[i] == false and yards > lower and (not upper or yards < upper) then
            lower = yards
        end
    end
    return lower, upper
end

-- The distance to your target, under the Judgement of Wisdom warning, shown
-- while you're too far away to judge.
local function CreateRangeText(warning)
    local text = warning:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 26, "THICKOUTLINE")
    text:SetTextColor(1, 0.55, 0.2)
    text:SetPoint("TOP", warning, "BOTTOM", 0, -2)
    text:Hide()

    local elapsed = 0
    -- Don't show the last reading from a previous target; check on the next frame.
    warning:HookScript("OnShow", function()
        text:Hide()
        elapsed = RANGE_INTERVAL
    end)
    warning:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed < RANGE_INTERVAL then return end
        elapsed = 0
        local lower, upper
        if unlocked then
            lower, upper = 10, 28   -- sample, so it can be seen while moving
        elseif PaladinPalDB.range then
            lower, upper = EstimateRange()
        end
        if lower then
            if upper then
                text:SetText(("TOO FAR: %d-%d yd"):format(lower, upper))
            else
                text:SetText(("TOO FAR: %d+ yd"):format(lower))
            end
            text:Show()
            self.icon:SetVertexColor(1, 0.35, 0.35)
        else
            text:Hide()
            self.icon:SetVertexColor(1, 1, 1)
        end
    end)
end

CreateRangeText(remindersByKey.wisdom.warning)

Update = function()
    for _, reminder in ipairs(reminders) do
        reminder.warning:SetShown(unlocked or (PaladinPalDB[reminder.key] and reminder.check()))
    end
end

local function SetUnlocked(value)
    unlocked = value
    for _, reminder in ipairs(reminders) do
        reminder.warning:EnableMouse(value)
        reminder.warning.bg:SetShown(value)
    end
    Update()
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON_NAME then
            PaladinPalDB = PaladinPalDB or {}
            for _, reminder in ipairs(reminders) do
                if PaladinPalDB[reminder.key] == nil then PaladinPalDB[reminder.key] = true end
                reminder.warning:ApplyPosition()
            end
            if PaladinPalDB.range == nil then PaladinPalDB.range = true end
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif PaladinPalDB then
        Update()
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("PLAYER_CONTROL_LOST")
frame:RegisterEvent("PLAYER_CONTROL_GAINED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterUnitEvent("UNIT_AURA", "player", "target")

local function SetEnabled(reminder, value)
    PaladinPalDB[reminder.key] = value
    Print(reminder.name .. (value and " reminder enabled." or " reminder disabled."))
end

local function Usage()
    local keys = {}
    for _, reminder in ipairs(reminders) do keys[#keys + 1] = reminder.key end
    Print("commands: on, off, <reminder> on|off, range on|off, move [reminder] <x> <y>, unlock, lock, reset")
    Print("reminders: " .. table.concat(keys, ", "))
end

SLASH_PALADINPAL1 = "/paladinpal"
SLASH_PALADINPAL2 = "/pp"
SlashCmdList.PALADINPAL = function(msg)
    local cmd, arg = strsplit(" ", strtrim(msg or ""):lower(), 2)
    if remindersByKey[cmd] and (arg == "on" or arg == "off") then
        SetEnabled(remindersByKey[cmd], arg == "on")
    elseif cmd == "range" and (arg == "on" or arg == "off") then
        PaladinPalDB.range = arg == "on"
        Print("Judgement range display" .. (PaladinPalDB.range and "enabled." or "disabled."))
    elseif cmd == "on" or cmd == "off" then
        for _, reminder in ipairs(reminders) do SetEnabled(reminder, cmd == "on") end
    elseif cmd == "unlock" then
        SetUnlocked(true)
        Print("drag the warnings to move them, then type /pp lock.")
        return
    elseif cmd == "lock" then
        SetUnlocked(false)
        Print("warnings locked.")
        return
    elseif cmd == "move" then
        -- /pp move <x> <y> moves every warning; /pp move <reminder> <x> <y> moves one.
        local a, b, c = strsplit(" ", arg or "")
        local targets, dx, dy = reminders, tonumber(a), tonumber(b)
        if remindersByKey[a] then
            targets, dx, dy = { remindersByKey[a] }, tonumber(b), tonumber(c)
        end
        if not dx or not dy then
            Print("usage: /pp move [reminder] <x> <y>, e.g. /pp move 0 50 moves all warnings 50 pixels up.")
            return
        end
        for _, reminder in ipairs(targets) do reminder.warning:Nudge(dx, dy) end
        Print("warnings moved.")
    elseif cmd == "reset" then
        for _, reminder in ipairs(reminders) do reminder.warning:ResetPosition() end
        Print("positions reset.")
    else
        Usage()
        return
    end
    Update()
end
