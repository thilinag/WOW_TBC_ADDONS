local ADDON_NAME, ns = ...

-- Minimap button: left-click turns the overlay on or off, right-click opens
-- the settings, and dragging moves it around the minimap's edge. It's an
-- ordinary minimap button, so while mounted it follows the "buttons" setting
-- like any other addon icon.

local ICON = "Interface\\Icons\\Ability_Mount_RidingHorse"

local button = CreateFrame("Button", "MountMapMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
button:Hide()

local background = button:CreateTexture(nil, "BACKGROUND")
background:SetSize(20, 20)
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
background:SetPoint("TOPLEFT", 7, -5)

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetSize(17, 17)
icon:SetTexture(ICON)
icon:SetPoint("TOPLEFT", 7, -6)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetPoint("TOPLEFT")

-- Placed on a circle just outside whatever it's parented to: the minimap,
-- or the stand-in frame MountMap moves it to while mounted.
local function UpdatePosition()
    local parent = button:GetParent()
    local angle = math.rad(MountMapDB.minimapAngle)
    local radius = parent:GetWidth() / 2 + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", parent, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("MountMap")
    if MountMapDB.enabled then
        GameTooltip:AddLine("Overlay: on", 0.3, 1, 0.3)
    else
        GameTooltip:AddLine("Overlay: off", 1, 0.3, 0.3)
    end
    GameTooltip:AddLine("Left-click to turn on or off", 1, 1, 1)
    GameTooltip:AddLine("Right-click for settings", 1, 1, 1)
    GameTooltip:AddLine("Drag to move", 1, 1, 1)
    GameTooltip:Show()
end

function ns.UpdateMinimapButton()
    if not MountMapDB then return end
    UpdatePosition()
    if not MountMapDB.minimapButton then
        button:Hide()
    elseif not (ns.IsActive() and MountMapDB.buttons == "hide") then
        -- While mounted with buttons hidden, MountMap shows it on dismount.
        button:Show()
    end
    icon:SetDesaturated(not MountMapDB.enabled)
    if GameTooltip:IsOwned(button) then ShowTooltip(button) end
end

button:SetScript("OnClick", function(self, mouseButton)
    if mouseButton == "RightButton" then
        ns.OpenOptions()
        return
    end
    MountMapDB.enabled = not MountMapDB.enabled
    ns.Print("overlay " .. (MountMapDB.enabled and "enabled." or "disabled."))
    ns.Refresh()
end)

button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local parent = self:GetParent()
        local scale = parent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        local cx, cy = parent:GetCenter()
        MountMapDB.minimapAngle = math.deg(math.atan2(y / scale - cy, x / scale - cx))
        UpdatePosition()
    end)
end)

button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

-- MountMap shows every button it hid when you dismount, so a turned-off
-- button hides itself again.
button:SetScript("OnShow", function(self)
    if MountMapDB and not MountMapDB.minimapButton then self:Hide() end
end)
button:SetScript("OnEnter", ShowTooltip)
button:SetScript("OnLeave", GameTooltip_Hide)

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", ns.UpdateMinimapButton)
