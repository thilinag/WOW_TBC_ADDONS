local ADDON_NAME, ns = ...

-- PaladinPal.lua stops early on other classes, so there's nothing to set.
if not ns.reminders then return end

-- Settings panel under Options > AddOns. It edits PaladinPalDB directly,
-- the same as the slash commands.

local DESCRIPTIONS = {
    aura = "When you don't have an aura active.",
    crusader = "In a dungeon or raid while Crusader Aura is your aura and you're not mounted.",
    favor ="In combat in a dungeon or raid while Divine Favor is off cooldown.",
    illumination = "In combat in a dungeon or raid while Divine Illumination is off cooldown.",
    wisdom = "In combat while your enemy target doesn't have Judgement of Wisdom on it.",
    blessings = "A list of who's missing a PallyPower-assigned blessing, and which paladin should cast it.",
}

local panel = CreateFrame("Frame")
panel.name = "PaladinPal"

local checkboxes = {}
local cursor = -16

local function Place(region, height, indent)
    region:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + (indent or 0), cursor)
    cursor = cursor - height
end

local function Header(text)
    cursor = cursor - 8
    local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetText(text)
    Place(fs, 28)
end

local function Checkbox(label, description, key, indent)
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    local text = cb.Text or cb.text or cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetFontObject("GameFontHighlight")
    text:ClearAllPoints()
    text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    text:SetText(label)
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
    desc:SetTextColor(0.75, 0.75, 0.75)
    desc:SetText(description)
    cb:SetScript("OnClick", function(self)
        PaladinPalDB[key] = self:GetChecked() and true or false
        ns.Update()
    end)
    cb.key = key
    checkboxes[#checkboxes + 1] = cb
    Place(cb, 40, indent)
    return cb
end

local function Button(label, width, onClick)
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetText(label)
    b:SetSize(width, 24)
    b:SetScript("OnClick", onClick)
    return b
end

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
title:SetText("PaladinPal")
Place(title, 30)
local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetText("Flashing on-screen paladin reminders. Settings and positions are saved per character.")
Place(subtitle, 24)

Header("Reminders")
for _, reminder in ipairs(ns.reminders) do
    Checkbox(reminder.name, DESCRIPTIONS[reminder.key] or "", reminder.key)
    if reminder.key == "wisdom" then
        Checkbox("Show distance to target",
            "Under the warning, how far your target is while it's out of Judgement range.",
            "range", 26)
    elseif reminder.key == "blessings" then
        Checkbox("Also in combat",
            "Keep the list up during fights. Off, it only shows between pulls.",
            "blessingsCombat", 26)
    end
end

Header("Position")
local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
hint:SetText("Unlock shows every warning so you can drag them where you want, then lock them again.")
Place(hint, 22)

local unlockButton = Button("Unlock and move", 150, function()
    local unlock = not ns.IsUnlocked()
    ns.SetUnlocked(unlock)
    if unlock then
        -- The warnings sit behind the options window, so get it out of the way.
        HideUIPanel(SettingsPanel or InterfaceOptionsFrame)
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99PaladinPal|r: drag the warnings to move them, then type /pp lock.")
    end
end)
unlockButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, cursor)
local resetButton = Button("Reset positions", 150, function()
    for _, reminder in ipairs(ns.reminders) do reminder.warning:ResetPosition() end
end)
resetButton:SetPoint("LEFT", unlockButton, "RIGHT", 8, 0)

function ns.RefreshOptions()
    if not (PaladinPalDB and panel:IsVisible()) then return end
    for _, cb in ipairs(checkboxes) do cb:SetChecked(PaladinPalDB[cb.key]) end
    unlockButton:SetText(ns.IsUnlocked() and "Lock" or "Unlock and move")
end

panel:SetScript("OnShow", ns.RefreshOptions)

local category
if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
else
    InterfaceOptions_AddCategory(panel)
end

function ns.OpenOptions()
    if category then
        Settings.OpenToCategory(category:GetID())
    else
        -- The old options frame often needs two calls to land on the panel.
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end
