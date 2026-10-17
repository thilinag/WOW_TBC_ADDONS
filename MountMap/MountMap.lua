local ADDON_NAME = ...

local DEFAULTS = {
    enabled = true,
    alpha = 0.5,
    size = 400,
    x = 0,
    y = 0,
    zoom = -1,       -- -1 keeps the current minimap zoom
    edge = "soft",
    forms = true,    -- treat druid travel/flight forms and ghost wolf as mounted
    rotate = true,   -- rotate the map so the player arrow always points up
    iconScale = 2,   -- size multiplier for node icons and the player arrow
    taxi = false,    -- show the overlay on flight paths
    hover = "alt",   -- key to hold for node tooltips: alt, shift, ctrl, always, off
}

local MASKS = {
    soft = "Interface\\AddOns\\MountMap\\Textures\\MaskSoft",
    medium = "Interface\\AddOns\\MountMap\\Textures\\MaskMedium",
    hard = "Interface\\AddOns\\MountMap\\Textures\\MaskHard",
}
-- Fallback masks for restoring, used if we never saw another addon set one.
-- The client's built-in mask path isn't reliable across versions, and a
-- missing mask blanks the whole minimap, so use textures we know exist.
local ROUND_MASK = "Interface\\AddOns\\MountMap\\Textures\\MaskRound"
local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"

-- GetShapeshiftFormID values: travel, ghost wolf, swift flight, flight.
local MOUNT_FORMS = { [3] = true, [16] = true, [27] = true, [29] = true }

local POLL_INTERVAL = 0.2

local active = false
local preview = false
local saved          -- original minimap state, captured on activate
local hiddenFrames   -- frames we hid, shown again on restore
local hookedFrames = {}
local settingMask = false
local lastMask       -- mask most recently set by the UI or another addon

-- There's no way to read the current mask, so remember what others set
-- (e.g. ElvUI's square mask) and put that back on restore.
hooksecurefunc(Minimap, "SetMaskTexture", function(_, texture)
    if not settingMask then lastMask = texture end
end)

local function SetMask(texture)
    settingMask = true
    Minimap:SetMaskTexture(texture)
    settingMask = false
end

local function OriginalMask()
    if lastMask then return lastMask end
    -- ElvUI's minimap is square; the default UI's is round.
    if ElvUI then return SQUARE_MASK end
    return ROUND_MASK
end

local frame = CreateFrame("Frame")

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99MountMap|r: " .. msg)
end

local function IsMountedish()
    -- Flight paths count as mounted; skip them unless asked.
    if UnitOnTaxi("player") and not MountMapDB.taxi then return false end
    if IsMounted() then return true end
    if MountMapDB.forms and GetShapeshiftFormID then
        return MOUNT_FORMS[GetShapeshiftFormID() or 0] or false
    end
    return false
end

-- The minimap only redraws its terrain at a new size after a zoom change.
local function RefreshZoom()
    local z = Minimap:GetZoom()
    Minimap:SetZoom(z > 0 and z - 1 or z + 1)
    Minimap:SetZoom(z)
end

local function IsAnchoredToMinimap(f)
    for i = 1, f:GetNumPoints() do
        local _, relativeTo = f:GetPoint(i)
        if relativeTo == Minimap then return true end
    end
    return false
end

-- Reading anchors of forbidden or restricted frames raises an error, so any
-- frame we can't inspect is treated as not a minimap button.
local function SafeAnchoredToMinimap(f)
    if f.IsForbidden and f:IsForbidden() then return false end
    local ok, result = pcall(IsAnchoredToMinimap, f)
    return ok and result
end

-- Minimap buttons are either children of the minimap or parented elsewhere
-- and anchored to it; both kinds would follow the map to the screen centre.
local function CollectMinimapButtons()
    local found, seen = {}, { [Minimap] = true, [MinimapCluster] = true }
    -- Never hide a frame the minimap sits inside.
    local ancestor = Minimap:GetParent()
    while ancestor do
        seen[ancestor] = true
        ancestor = ancestor:GetParent()
    end
    local function add(f)
        if not seen[f] then
            seen[f] = true
            found[#found + 1] = f
        end
    end
    for _, child in ipairs({ Minimap:GetChildren() }) do
        add(child)
    end
    for _, parent in ipairs({ Minimap:GetParent(), MinimapCluster, UIParent }) do
        for _, child in ipairs({ parent:GetChildren() }) do
            if not seen[child] and SafeAnchoredToMinimap(child) then add(child) end
        end
    end
    return found
end

local function HideButton(f)
    if (f.IsForbidden and f:IsForbidden()) or not f:IsShown() or f:IsProtected() then return end
    if not pcall(f.Hide, f) then return end
    hiddenFrames[#hiddenFrames + 1] = f
    hiddenFrames[f] = true
    -- Some addons re-show their buttons (fade-in, updates); keep them hidden.
    if not hookedFrames[f] then
        hookedFrames[f] = true
        f:HookScript("OnShow", function(self)
            if active and hiddenFrames and hiddenFrames[self] then self:Hide() end
        end)
    end
end

-- rotateMinimap is saved to the client config, so the player's own value is
-- kept in the DB until restored; that survives a crash or disconnect.
local function RestoreRotation()
    if MountMapDB.prevRotate then
        SetCVar("rotateMinimap", MountMapDB.prevRotate)
        MountMapDB.prevRotate = nil
    end
end

local function ApplyRotation()
    if MountMapDB.rotate then
        if not MountMapDB.prevRotate then
            MountMapDB.prevRotate = GetCVar("rotateMinimap")
        end
        SetCVar("rotateMinimap", "1")
    else
        RestoreRotation()
    end
end

local HOVER_KEYS = {
    alt = IsAltKeyDown,
    shift = IsShiftKeyDown,
    ctrl = IsControlKeyDown,
    always = function() return true end,
    off = function() return false end,
}

-- Node tooltips need mouse input on the minimap, but a mouse-enabled map in
-- the middle of the screen blocks clicks and camera dragging. Only take the
-- mouse while the hover key is held.
local function UpdateMouse()
    if not active then return end
    local want = (HOVER_KEYS[MountMapDB.hover] or HOVER_KEYS.alt)()
    if want == Minimap:IsMouseEnabled() then return end
    Minimap:EnableMouse(want)
    if not want and GameTooltip:IsOwned(Minimap) then
        GameTooltip:Hide()
    end
end

local function ApplyLayout()
    local db = MountMapDB
    ApplyRotation()
    UpdateMouse()
    Minimap:ClearAllPoints()
    -- Node icons have a fixed size in the minimap's own units, so scaling the
    -- frame up and shrinking its size by the same factor enlarges the icons
    -- while the map keeps its on-screen size. Offsets are in scaled units too.
    local s = db.iconScale
    Minimap:SetScale(s)
    Minimap:SetPoint("CENTER", UIParent, "CENTER", db.x / s, db.y / s)
    Minimap:SetSize(db.size / s, db.size / s)
    Minimap:SetAlpha(db.alpha)
    SetMask(MASKS[db.edge] or MASKS.soft)
    if db.zoom >= 0 then
        Minimap:SetZoom(math.min(db.zoom, Minimap:GetZoomLevels() - 1))
    end
    C_Timer.After(0, RefreshZoom)
end

local function Activate()
    if active then return end
    active = true

    -- Only position, size, scale, alpha, mask and mouse are changed. Parent,
    -- strata and frame level are left alone: changing them reorders the map
    -- against UI backdrops (ElvUI's ends up drawn over the map on restore).
    saved = {
        width = Minimap:GetWidth(),
        height = Minimap:GetHeight(),
        scale = Minimap:GetScale(),
        alpha = Minimap:GetAlpha(),
        zoom = Minimap:GetZoom(),
        mouse = Minimap:IsMouseEnabled(),
        wheel = Minimap:IsMouseWheelEnabled(),
        points = {},
    }
    for i = 1, Minimap:GetNumPoints() do
        saved.points[i] = { Minimap:GetPoint(i) }
    end

    -- Collect buttons before reparenting, while they're still anchored as usual.
    local buttons = CollectMinimapButtons()

    -- Let clicks and the mouse wheel pass through to the game world;
    -- UpdateMouse turns clicks back on while the hover key is held.
    Minimap:EnableMouse(false)
    Minimap:EnableMouseWheel(false)
    Minimap:Show()
    ApplyLayout()

    -- Hide the border, buttons and addon icons so only the map itself shows.
    hiddenFrames = {}
    for _, f in ipairs(buttons) do
        HideButton(f)
    end
end

local function Deactivate()
    if not active then return end
    active = false

    Minimap:SetScale(saved.scale)
    Minimap:SetSize(saved.width, saved.height)
    Minimap:SetAlpha(saved.alpha)
    SetMask(OriginalMask())
    RestoreRotation()
    Minimap:ClearAllPoints()
    for _, p in ipairs(saved.points) do
        Minimap:SetPoint(unpack(p))
    end
    Minimap:EnableMouse(saved.mouse)
    Minimap:EnableMouseWheel(saved.wheel)
    Minimap:SetZoom(saved.zoom)
    Minimap:Show()
    -- Redraw once now and again shortly after, once the new size has settled.
    C_Timer.After(0, RefreshZoom)
    C_Timer.After(0.2, RefreshZoom)

    local frames = hiddenFrames or {}
    hiddenFrames = nil
    for _, f in ipairs(frames) do
        f:Show()
    end
    saved = nil
end

local function Update()
    local want = MountMapDB.enabled and (preview or IsMountedish())
    if want then Activate() else Deactivate() end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON_NAME then
            MountMapDB = MountMapDB or {}
            for k, v in pairs(DEFAULTS) do
                if MountMapDB[k] == nil then MountMapDB[k] = v end
            end
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        -- Undo a rotation left on by a crash or disconnect while mounted.
        RestoreRotation()
        -- Mount state has no dedicated event in this client, so poll it.
        C_Timer.NewTicker(POLL_INTERVAL, Update)
        Update()
    elseif event == "MODIFIER_STATE_CHANGED" then
        UpdateMouse()
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("MODIFIER_STATE_CHANGED")

local function ShowSettings()
    local db = MountMapDB
    Print(("%s | alpha %.2f | size %d | offset %d,%d | zoom %s | edge %s | forms %s | rotate %s | icons %.1fx | taxi %s | hover %s"):format(
        db.enabled and "on" or "off", db.alpha, db.size, db.x, db.y,
        db.zoom >= 0 and tostring(db.zoom) or "keep", db.edge, db.forms and "on" or "off",
        db.rotate and "on" or "off", db.iconScale, db.taxi and "on" or "off", db.hover))
end

local function FrameName(f)
    return f and (f:GetName() or tostring(f)) or "nil"
end

local function ShowDebug()
    local p, rel, rp, x, y = Minimap:GetPoint(1)
    Print(("active %s | mounted %s | shown %s | visible %s | parent %s"):format(
        tostring(active), tostring(IsMountedish()), tostring(Minimap:IsShown()),
        tostring(Minimap:IsVisible()), FrameName(Minimap:GetParent())))
    Print(("strata %s | level %d | alpha %.2f | size %dx%d | point %s %s %s %d,%d"):format(
        Minimap:GetFrameStrata(), Minimap:GetFrameLevel(), Minimap:GetEffectiveAlpha(),
        Minimap:GetWidth(), Minimap:GetHeight(),
        tostring(p), FrameName(rel), tostring(rp), x or 0, y or 0))
    if hiddenFrames then
        local names = {}
        for _, f in ipairs(hiddenFrames) do names[#names + 1] = FrameName(f) end
        Print("hidden: " .. (#names > 0 and table.concat(names, ", ") or "none"))
    end
end

local function Usage()
    Print("commands: on, off, alpha <0-1>, size <px>, offset <x> <y>, zoom <0-5|keep>, "
        .. "edge <soft|medium|hard>, forms <on|off>, rotate <on|off>, icons <0.5-4>, taxi <on|off>, hover <alt|shift|ctrl|always|off>, test, show, debug, reset")
end

SLASH_MOUNTMAP1 = "/mountmap"
SLASH_MOUNTMAP2 = "/mmap"
SlashCmdList.MOUNTMAP = function(msg)
    local cmd, a, b = strsplit(" ", strtrim(msg or ""):lower())
    local db = MountMapDB

    if cmd == "on" or cmd == "off" then
        db.enabled = cmd == "on"
        Print("overlay " .. (db.enabled and "enabled." or "disabled."))
    elseif cmd == "alpha" and tonumber(a) then
        db.alpha = math.max(0.05, math.min(1, tonumber(a)))
        Print(("alpha set to %.2f."):format(db.alpha))
    elseif cmd == "size" and tonumber(a) then
        db.size = math.max(100, math.min(1200, math.floor(tonumber(a))))
        Print(("size set to %d."):format(db.size))
    elseif cmd == "offset" and tonumber(a) and tonumber(b) then
        db.x, db.y = math.floor(tonumber(a)), math.floor(tonumber(b))
        Print(("offset set to %d,%d."):format(db.x, db.y))
    elseif cmd == "zoom" and (a == "keep" or tonumber(a)) then
        db.zoom = a == "keep" and -1 or math.max(0, math.floor(tonumber(a)))
        Print("zoom set to " .. (db.zoom >= 0 and db.zoom or "keep") .. ".")
    elseif cmd == "edge" and MASKS[a or ""] then
        db.edge = a
        Print("edge set to " .. a .. ".")
    elseif cmd == "forms" and (a == "on" or a == "off") then
        db.forms = a == "on"
        Print("shapeshift forms " .. a .. ".")
    elseif cmd == "icons" and tonumber(a) then
        db.iconScale = math.max(0.5, math.min(4, tonumber(a)))
        Print(("icon scale set to %.1fx."):format(db.iconScale))
    elseif cmd == "hover" and HOVER_KEYS[a or ""] then
        db.hover = a
        Print("tooltip key set to " .. a .. ".")
    elseif cmd == "taxi" and (a == "on" or a == "off") then
        db.taxi = a == "on"
        Print("flight paths " .. a .. ".")
    elseif cmd == "rotate" and (a == "on" or a == "off") then
        db.rotate = a == "on"
        Print("rotation " .. a .. ".")
    elseif cmd == "test" then
        preview = not preview
        Print("preview " .. (preview and "on (type /mmap test again to stop)." or "off."))
    elseif cmd == "show" then
        ShowSettings()
        return
    elseif cmd == "debug" then
        ShowDebug()
        return
    elseif cmd == "reset" then
        for k, v in pairs(DEFAULTS) do db[k] = v end
        Print("settings reset.")
    else
        Usage()
        return
    end

    if active then ApplyLayout() end
    Update()
end
