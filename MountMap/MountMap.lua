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
    ring = true,     -- dim compass ring around the map showing your heading
    ringAlpha = 0.35,
    buttons = "keep", -- minimap border and buttons while mounted: keep or hide
    fillAlpha = 0.5,  -- darkness of the empty space left at the minimap's spot
}

local RING_TEXTURE = "Interface\\AddOns\\MountMap\\Textures\\Ring"
-- Compass points as bearings, counter-clockwise from north like GetPlayerFacing.
local CARDINALS = { N = 0, W = math.pi / 2, S = math.pi, E = math.pi * 1.5 }

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
local movedFrames    -- frames moved onto the holder, put back on restore
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

-- The compass ring lives on its own frame rather than the minimap, so the
-- minimap's mask and icon scale don't apply to it.
local compass

-- Places a ring element at a screen angle, counter-clockwise from straight up.
local function PlaceOnRing(region, angle, radius)
    region:ClearAllPoints()
    region:SetPoint("CENTER", compass, "CENTER", -math.sin(angle) * radius, math.cos(angle) * radius)
end

local function UpdateCompass()
    -- With a rotating map the heading is always up, so the dial turns with
    -- the player; otherwise north stays up and the dial stays still.
    local turn = 0
    if GetCVar("rotateMinimap") == "1" then
        turn = GetPlayerFacing and GetPlayerFacing() or 0
    end
    compass.ring:SetRotation(-turn)
    local radius = compass:GetWidth() / 2
    for letter, bearing in pairs(CARDINALS) do
        PlaceOnRing(compass.letters[letter], bearing - turn, radius + 16)
    end
end

local function CreateCompass()
    compass = CreateFrame("Frame", nil, UIParent)
    compass:Hide()
    compass.ring = compass:CreateTexture(nil, "BORDER")
    compass.ring:SetTexture(RING_TEXTURE)
    compass.ring:SetAllPoints()
    compass.letters = {}
    for letter in pairs(CARDINALS) do
        local fs = compass:CreateFontString(nil, "ARTWORK")
        fs:SetFont(STANDARD_TEXT_FONT, letter == "N" and 26 or 22, "THICKOUTLINE")
        fs:SetText(letter)
        if letter == "N" then
            fs:SetTextColor(1, 0.25, 0.2)
        else
            fs:SetTextColor(1, 1, 1)
        end
        compass.letters[letter] = fs
    end
    compass:SetScript("OnUpdate", UpdateCompass)
end

local function LayoutCompass()
    local db = MountMapDB
    if not (active and db.ring) then
        if compass then compass:Hide() end
        return
    end
    if not compass then CreateCompass() end
    compass:SetFrameStrata(Minimap:GetFrameStrata())
    compass:SetFrameLevel(Minimap:GetFrameLevel() + 1)
    compass:ClearAllPoints()
    compass:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    compass:SetSize(db.size, db.size)
    -- Only the dial is dimmed; the letters stay at full strength.
    compass.ring:SetAlpha(db.ringAlpha)
    compass:Show()
    UpdateCompass()
end

local function ApplyLayout()
    local db = MountMapDB
    ApplyRotation()
    UpdateMouse()
    LayoutCompass()
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

-- An empty frame standing in for the minimap at its usual spot, so the
-- border, buttons and addon icons can stay there while the map is moved.
local holder

local function ShowHolder()
    if not holder then
        holder = CreateFrame("Frame")
        holder.fill = holder:CreateTexture(nil, "BACKGROUND")
        holder.fill:SetAllPoints()
    end
    -- A dark fill in the minimap's own shape; its mask textures are opaque
    -- where the map shows, so they work as the fill shape too.
    holder.fill:SetTexture(OriginalMask())
    holder.fill:SetVertexColor(0, 0, 0, MountMapDB.fillAlpha)
    holder.fill:SetShown(MountMapDB.fillAlpha > 0)
    local parent = Minimap:GetParent()
    holder:SetParent(parent)
    holder:SetFrameStrata(Minimap:GetFrameStrata())
    holder:SetFrameLevel(Minimap:GetFrameLevel())
    holder:SetScale(saved.scale)
    holder:SetAlpha(saved.alpha)
    holder:SetSize(saved.width, saved.height)
    holder:ClearAllPoints()
    for _, p in ipairs(saved.points) do
        holder:SetPoint(p[1], p[2] or parent, p[3], p[4], p[5])
    end
    holder:Show()
end

local function GetPoints(f)
    local points = {}
    for i = 1, f:GetNumPoints() do
        points[i] = { f:GetPoint(i) }
    end
    return points
end

local function SetPoints(f, points, from, to)
    f:ClearAllPoints()
    for _, p in ipairs(points) do
        local relativeTo = p[2]
        if relativeTo == from then relativeTo = to end
        f:SetPoint(p[1], relativeTo, p[3], p[4], p[5])
    end
end

-- Re-anchors a frame from the minimap onto the holder, and re-parents it
-- too if it was a child of the minimap. Protected frames are skipped, as
-- moving them back after a dismount in combat would be blocked.
local function MoveToHolder(f)
    if (f.IsForbidden and f:IsForbidden()) or f:IsProtected() then return false end
    local ok, points = pcall(GetPoints, f)
    if not ok then return false end
    local entry = {
        frame = f,
        parent = f:GetParent(),
        points = points,
        strata = f:GetFrameStrata(),
        level = f:GetFrameLevel(),
    }
    if entry.parent == Minimap then f:SetParent(holder) end
    SetPoints(f, points, Minimap, holder)
    -- Re-parenting resets the frame level, which can bury a button under
    -- the border; put back the original drawing order.
    f:SetFrameStrata(entry.strata)
    f:SetFrameLevel(entry.level)
    movedFrames[#movedFrames + 1] = entry
    return true
end

local function RestoreMovedFrames()
    local entries = movedFrames or {}
    movedFrames = nil
    for i = #entries, 1, -1 do
        local e = entries[i]
        if e.frame:GetParent() ~= e.parent then e.frame:SetParent(e.parent) end
        SetPoints(e.frame, e.points)
        e.frame:SetFrameStrata(e.strata)
        e.frame:SetFrameLevel(e.level)
    end
    if holder then holder:Hide() end
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

    -- Leave the border, buttons and addon icons where they were, or hide them.
    -- Anything that can't be moved is hidden instead, where possible.
    hiddenFrames, movedFrames = {}, {}
    if MountMapDB.buttons == "keep" then ShowHolder() end
    for _, f in ipairs(buttons) do
        if not (MountMapDB.buttons == "keep" and MoveToHolder(f)) then
            HideButton(f)
        end
    end
end

local function Deactivate()
    if not active then return end
    active = false

    if compass then compass:Hide() end
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
    RestoreMovedFrames()
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
    Print(("%s | alpha %.2f | size %d | offset %d,%d | zoom %s | edge %s | forms %s | rotate %s | icons %.1fx | taxi %s | hover %s | ring %s | buttons %s | fill %.2f"):format(
        db.enabled and "on" or "off", db.alpha, db.size, db.x, db.y,
        db.zoom >= 0 and tostring(db.zoom) or "keep", db.edge, db.forms and "on" or "off",
        db.rotate and "on" or "off", db.iconScale, db.taxi and "on" or "off", db.hover,
        db.ring and ("%.2f"):format(db.ringAlpha) or "off", db.buttons, db.fillAlpha))
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
        names = {}
        for _, e in ipairs(movedFrames or {}) do names[#names + 1] = FrameName(e.frame) end
        Print("kept in place: " .. (#names > 0 and table.concat(names, ", ") or "none"))
    end
end

local function Usage()
    Print("commands: on, off, alpha <0-1>, size <px>, offset <x> <y>, zoom <0-5|keep>, "
        .. "edge <soft|medium|hard>, forms <on|off>, rotate <on|off>, icons <0.5-4>, taxi <on|off>, hover <alt|shift|ctrl|always|off>, ring <on|off|0-1>, buttons <keep|hide>, fill <0-1>, test, show, debug, reset")
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
    elseif cmd == "ring" and (a == "on" or a == "off" or tonumber(a)) then
        if tonumber(a) then
            db.ring = true
            db.ringAlpha = math.max(0.05, math.min(1, tonumber(a)))
        else
            db.ring = a == "on"
        end
        Print("compass ring " .. (db.ring and ("on at %.2f."):format(db.ringAlpha) or "off."))
    elseif cmd == "buttons" and (a == "keep" or a == "hide") then
        db.buttons = a
        Print("minimap buttons: " .. a .. ".")
        -- Buttons are only moved or hidden on activate, so redo it.
        if active then Deactivate() end
    elseif cmd == "fill" and tonumber(a) then
        db.fillAlpha = math.max(0, math.min(1, tonumber(a)))
        Print(("fill set to %.2f."):format(db.fillAlpha))
        if active and holder and holder:IsShown() then ShowHolder() end
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
