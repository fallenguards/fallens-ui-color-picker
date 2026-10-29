if select(2, ...).INERT then return end
local _, ns = ...
local L = ns.L

-- The picker's minimap button, 1.x tracking-button style: the gem on a black disc in Era's ring, dragged round the
-- map with its angle saved. Left-click the settings, right-click the look pick.

local SIZE = 32
local FULL = { 0, 1, 0, 1 }
local ICON = "Interface\\Icons\\INV_Misc_Gem_Variety_01"

-- Ring centre is at (20, 19) on its 64px sheet; the face's edge hides under the ring.
local RING_SIZE = 54
local CX, CY = RING_SIZE * 20 / 64, -RING_SIZE * 19 / 64
local FACE = 24

-- An icon file's face, cropped past its own border.
local ICON_FACE = { layer = "ARTWORK", coords = { 0.08, 0.92, 0.08, 0.92 }, w = FACE, h = FACE,
    point = "CENTER", relPoint = "TOPLEFT", x = CX, y = CY }
-- Black disc under it: the zoomed art's own disc no longer reaches the ring everywhere.
local BACK = { layer = "BACKGROUND", w = FACE, h = FACE, point = "CENTER", relPoint = "TOPLEFT", x = CX, y = CY,
    vertex = { 0, 0, 0 } }
local RING = { layer = "OVERLAY", w = RING_SIZE, h = RING_SIZE, point = "TOPLEFT" }
local HL_RING = { coords = FULL, fill = true, add = true, states = { "Highlight" } }

local button, face, dragJob

local function Radius()
    return (Minimap:GetWidth() or 140) / 2 + 5
end

-- Another addon's square map: the spot slides out along the angle to the square of that radius.
local function Square()
    return type(GetMinimapShape) == "function" and GetMinimapShape() == "SQUARE"
end

local function CursorAngle()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    if angle < 0 then angle = angle + 360 end
    return angle
end

-- Only we move the button, so an unchanged angle, radius, scale and shape means no move.
local placed = {}
local function Position()
    if not button then return end
    local degrees, r = ns.db.minimapButtonAngle or 213, Radius()
    local k = button:GetEffectiveScale() / Minimap:GetEffectiveScale()
    local square = Square()
    if degrees == placed.angle and r == placed.radius and k == placed.scale and square == placed.square then return end
    placed.angle, placed.radius, placed.scale, placed.square = degrees, r, k, square
    local a, f = math.rad(degrees), 1 / k
    local x, y = math.cos(a), math.sin(a)
    if square then
        local out = 1 / math.max(math.abs(x), math.abs(y))
        x, y = x * out, y * out
    end
    ns.SetPointOnce(button, "CENTER", Minimap, "CENTER", x * r * f, y * r * f)
end

-- Last cursor and map, to skip idle frames.
local last = {}
local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    if cx == last.x and cy == last.y and mx == last.mx and my == last.my and scale == last.scale then return end
    last.x, last.y, last.mx, last.my, last.scale = cx, cy, mx, my, scale
    ns.db.minimapButtonAngle = CursorAngle()
    Position()
end

-- Era's minimap button press (MiniMapButtonTemplate): the face 1 right and 1 down while held, back on release.
local heldAt
local function Press(down)
    if down and not heldAt then
        local point, rel, relPoint, x, y = face:GetPoint(1)
        if not point then return end
        heldAt = { point, rel, relPoint, x, y }
        ns.SetPointOnce(face, point, rel, relPoint, x + 1, y - 1)
    elseif not down and heldAt then
        ns.SetPointOnce(face, heldAt[1], heldAt[2], heldAt[3], heldAt[4], heldAt[5])
        heldAt = nil
    end
end

local function Build()
    local b = CreateFrame("Button", "FallensUIColorPickerMinimapButton", Minimap)
    b:SetSize(SIZE, SIZE)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel((Minimap:GetFrameLevel() or 2) + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetMovable(true)
    ns.DressNew(b, "portraitMask", BACK)
    -- Round mask first: RoundIcon sets its own crop, which the dress then replaces.
    face = b:CreateTexture("FallensUIColorPickerMinimapButtonIcon")
    ns.RoundIcon(face)
    face:SetTexture(ICON)
    ns.Dress(face, nil, ICON_FACE)
    ns.DressNew(b, "trackingBorder", RING)
    ns.DressStates(b, nil, nil, nil, "zoomHighlight", HL_RING)
    b.icon = face
    b:HookScript("OnMouseDown", function() Press(true) end)
    b:HookScript("OnMouseUp", function() Press(false) end)
    b:HookScript("OnHide", function() Press(false) end)
    -- Pure child watcher, asleep until a drag starts.
    dragJob = ns.Sched.OnFrame(CreateFrame("Frame", nil, b),
        { name = "minimapButton.drag", every = 0, awake = false, fn = OnDragUpdate })
    b:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then ns.ShowLookPick() else ns.OpenOptions() end
    end)
    b:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        last.x = nil
        dragJob:Wake()
    end)
    b:SetScript("OnDragStop", function()
        dragJob:Sleep()
        Press(false)
        Position()
    end)
    ns.AttachTip(b, { anchor = "ANCHOR_LEFT", text = ns.NAME, r = 1, g = 1, b = 1, lines = {
        { L["MAP_LEFT_CLICK_OPTIONS"], 0.8, 0.8, 0.8 },
        { L["MAP_RIGHT_CLICK_PICK"], 0.8, 0.8, 0.8 },
        { L["PICKER_DRAG"], 0.8, 0.8, 0.8 },
    } })
    -- The map's own size and layout changes move the ring.
    ns.HookMethod(Minimap, "SetSize", Position)
    if MinimapCluster then ns.HookMethod(MinimapCluster, "Layout", Position) end
    return b
end

local function Show()
    if not Minimap then return end
    button = button or Build()
    Position()
    button:Show()
end

local function Hide()
    if button then button:Hide() end
end

ns.RegisterModule("minimapButton", { apply = Show, restore = Hide })
