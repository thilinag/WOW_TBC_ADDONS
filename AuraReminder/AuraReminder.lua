local ADDON_NAME = ...

-- Paladin auras live on the stance bar in TBC, so GetShapeshiftForm()
-- tells us whether one is active without matching spell names.
local _, playerClass = UnitClass("player")
if playerClass ~= "PALADIN" then return end

local unlocked = false

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AuraReminder|r: " .. msg)
end

local warning = CreateFrame("Frame", "AuraReminderFrame", UIParent)
warning:SetSize(300, 50)
warning:SetMovable(true)
warning:SetClampedToScreen(true)
warning:RegisterForDrag("LeftButton")
warning:Hide()

local text = warning:CreateFontString(nil, "OVERLAY")
text:SetFont(STANDARD_TEXT_FONT, 32, "THICKOUTLINE")
text:SetTextColor(1, 0.2, 0.2)
text:SetPoint("CENTER")
text:SetText("NO AURA")

local bg = warning:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.5)
bg:Hide()

local pulse = warning:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.3)
fade:SetDuration(0.6)

warning:SetScript("OnShow", function() pulse:Play() end)
warning:SetScript("OnHide", function() pulse:Stop() end)
warning:SetScript("OnDragStart", function(self) self:StartMoving() end)
warning:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    AuraReminderDB.pos = { point, relPoint, x, y }
end)

local function ApplyPosition()
    local pos = AuraReminderDB.pos
    warning:ClearAllPoints()
    if pos then
        warning:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        warning:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
end

local function NeedsAura()
    -- No auras learned yet (low level).
    if GetNumShapeshiftForms() == 0 then return false end
    if UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then return false end
    return GetShapeshiftForm() == 0
end

local function Update()
    if unlocked then
        warning:Show()
    elseif AuraReminderDB.enabled and NeedsAura() then
        warning:Show()
    else
        warning:Hide()
    end
end

local function SetUnlocked(value)
    unlocked = value
    warning:EnableMouse(value)
    bg:SetShown(value)
    Update()
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON_NAME then
            AuraReminderDB = AuraReminderDB or {}
            if AuraReminderDB.enabled == nil then AuraReminderDB.enabled = true end
            ApplyPosition()
            self:UnregisterEvent("ADDON_LOADED")
        end
    else
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

SLASH_AURAREMINDER1 = "/aurareminder"
SLASH_AURAREMINDER2 = "/ar"
SlashCmdList.AURAREMINDER = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "on" then
        AuraReminderDB.enabled = true
        Print("reminder enabled.")
    elseif cmd == "off" then
        AuraReminderDB.enabled = false
        Print("reminder disabled.")
    elseif cmd == "unlock" then
        SetUnlocked(true)
        Print("drag the warning to move it, then type /ar lock.")
        return
    elseif cmd == "lock" then
        SetUnlocked(false)
        Print("warning locked.")
        return
    elseif cmd == "reset" then
        AuraReminderDB.pos = nil
        ApplyPosition()
        Print("position reset.")
    else
        Print("commands: on, off, unlock, lock, reset")
        return
    end
    Update()
end
