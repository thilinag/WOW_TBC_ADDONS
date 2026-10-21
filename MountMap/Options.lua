local ADDON_NAME, ns = ...

-- Settings panel under Options > AddOns. It edits MountMapDB directly and
-- calls ns.Refresh, the same path the slash command uses.

local CONTENT_WIDTH = 580
local SLIDER_WIDTH = 260

local panel = CreateFrame("Frame")
panel.name = "MountMap"

local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 0, -8)
scroll:SetPoint("BOTTOMRIGHT", -28, 8)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(CONTENT_WIDTH, 1)
scroll:SetScrollChild(content)

-- Widgets stack top to bottom; each one's Refresh reads its value from the DB.
local widgets = {}
local cursor = -8

local function Place(widget, height, indent)
    widget:SetPoint("TOPLEFT", content, "TOPLEFT", 16 + (indent or 0), cursor)
    cursor = cursor - height
    if widget.Refresh then widgets[#widgets + 1] = widget end
end

local function Header(text)
    cursor = cursor - 8
    local fs = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetText(text)
    Place(fs, 28)
end

local function Checkbox(label, tooltip, get, set)
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    local text = cb.Text or cb.text or cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetFontObject("GameFontHighlight")
    text:ClearAllPoints()
    text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    text:SetText(label)
    cb.tooltipText = tooltip
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, 1, 1, 1)
        GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", GameTooltip_Hide)
    function cb:Refresh() self:SetChecked(get()) end
    Place(cb, 30)
    return cb
end

local SLIDER_BACKDROP = {
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
}

local function Slider(label, minValue, maxValue, step, format, get, set, indent)
    local holder = CreateFrame("Frame", nil, content)
    holder:SetSize(SLIDER_WIDTH + 80, 40)

    local title = holder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 4, 0)
    title:SetText(label)

    local slider = CreateFrame("Slider", nil, holder, BackdropTemplateMixin and "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(SLIDER_WIDTH, 17)
    slider:SetPoint("TOPLEFT", 0, -16)
    slider:SetHitRectInsets(0, 0, -6, -6)
    slider:SetBackdrop(SLIDER_BACKDROP)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end

    local value = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    value:SetPoint("LEFT", slider, "RIGHT", 10, 0)

    local updating = false
    slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        value:SetText(format:format(v))
        if not updating then set(v) end
    end)

    function holder:Refresh()
        local v = get()
        updating = true
        slider:SetValue(v)
        updating = false
        value:SetText(format:format(v))
    end

    Place(holder, 46, indent)
    return holder
end

-- A row of buttons for picking one of a few values; the chosen one stays lit.
local function Choice(label, options, get, set)
    local holder = CreateFrame("Frame", nil, content)
    holder:SetSize(CONTENT_WIDTH - 32, 46)

    local title = holder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 4, 0)
    title:SetText(label)

    local buttons, x = {}, 0
    for _, option in ipairs(options) do
        local b = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
        b:SetText(option.text)
        b:SetSize(math.max(56, b:GetFontString():GetStringWidth() + 24), 22)
        b:SetPoint("TOPLEFT", x, -16)
        b:SetScript("OnClick", function() set(option.value) end)
        b.value = option.value
        buttons[#buttons + 1] = b
        x = x + b:GetWidth() + 4
    end

    function holder:Refresh()
        local current = get()
        for _, b in ipairs(buttons) do
            if b.value == current then b:LockHighlight() else b:UnlockHighlight() end
        end
    end

    Place(holder, 50)
    return holder
end

local function Button(label, width, onClick)
    local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    b:SetText(label)
    b:SetSize(width, 24)
    b:SetScript("OnClick", onClick)
    return b
end

-- Setters write the DB and re-apply, like the matching slash command.
local function Setter(key, rebuild)
    return function(value)
        MountMapDB[key] = value
        ns.Refresh(rebuild)
    end
end

local function Getter(key)
    return function() return MountMapDB[key] end
end

-- Title and the buttons beside it.
local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
title:SetText("MountMap")
Place(title, 30)
local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetWidth(CONTENT_WIDTH - 32)
subtitle:SetJustifyH("LEFT")
subtitle:SetText("Moves a see-through minimap to the middle of the screen while you're mounted. Changes apply straight away; use Preview to see them without mounting. Settings are shared across your characters.")
Place(subtitle, 36)

local previewButton = Button("Preview", 120, function()
    ns.SetPreview(not ns.IsPreview())
    ns.RefreshOptions()
end)
previewButton:SetPoint("TOPLEFT", content, "TOPLEFT", 16, cursor)
local resetButton = Button("Reset to defaults", 150, function()
    for k, v in pairs(ns.DEFAULTS) do MountMapDB[k] = v end
    ns.Refresh(true)
end)
resetButton:SetPoint("LEFT", previewButton, "RIGHT", 8, 0)
cursor = cursor - 32

Header("General")
Checkbox("Enable", "Show the overlay while mounted.",
    Getter("enabled"), Setter("enabled"))
Checkbox("Show minimap button",
    "A button on the minimap edge: left-click turns the overlay on or off, right-click opens these settings, drag to move it.",
    Getter("minimapButton"), Setter("minimapButton"))
Checkbox("Count travel forms as mounted",
    "Druid travel and flight forms and Shaman Ghost Wolf show the overlay too.",
    Getter("forms"), Setter("forms"))
Checkbox("Show on flight paths", "Show the overlay while on a flight path.",
    Getter("taxi"), Setter("taxi"))
Checkbox("Rotate the map",
    "Rotate the map while mounted so the direction you face is always up. Your own minimap rotation setting comes back when you dismount.",
    Getter("rotate"), Setter("rotate"))

Header("Map")
Slider("Opacity", 0.05, 1, 0.05, "%.2f", Getter("alpha"), Setter("alpha"))
Slider("Size", 100, 1200, 10, "%d px", Getter("size"), Setter("size"))
Slider("Horizontal offset", -800, 800, 5, "%d", Getter("x"), Setter("x"))
Slider("Vertical offset", -600, 600, 5, "%d", Getter("y"), Setter("y"))
Slider("Icon size", 0.5, 4, 0.1, "%.1fx", Getter("iconScale"), Setter("iconScale"))
Choice("Zoom while mounted", {
    { text = "Keep", value = -1 },
    { text = "0", value = 0 }, { text = "1", value = 1 }, { text = "2", value = 2 },
    { text = "3", value = 3 }, { text = "4", value = 4 }, { text = "5", value = 5 },
}, Getter("zoom"), Setter("zoom"))
Choice("Edge fade", {
    { text = "Soft", value = "soft" },
    { text = "Medium", value = "medium" },
    { text = "Hard", value = "hard" },
}, Getter("edge"), Setter("edge"))
Choice("Hold for node tooltips", {
    { text = "Alt", value = "alt" },
    { text = "Shift", value = "shift" },
    { text = "Ctrl", value = "ctrl" },
    { text = "Always", value = "always" },
    { text = "Off", value = "off" },
}, Getter("hover"), Setter("hover"))

Header("Compass")
Checkbox("Show compass ring", "A dim dial around the map with N, E, S and W.",
    Getter("ring"), Setter("ring"))
Slider("Ring opacity", 0.05, 1, 0.05, "%.2f", Getter("ringAlpha"), Setter("ringAlpha"), 30)

Header("Minimap buttons")
Choice("Border, buttons and addon icons while mounted", {
    { text = "Keep in place", value = "keep" },
    { text = "Hide", value = "hide" },
}, Getter("buttons"), Setter("buttons", true))
Slider("Darkness of the empty minimap spot", 0, 1, 0.05, "%.2f",
    Getter("fillAlpha"), Setter("fillAlpha"))

content:SetHeight(-cursor + 16)

function ns.RefreshOptions()
    -- OnShow catches up with anything changed while the panel was closed.
    if not (MountMapDB and panel:IsVisible()) then return end
    for _, widget in ipairs(widgets) do widget:Refresh() end
    previewButton:SetText(ns.IsPreview() and "Stop preview" or "Preview")
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
