if select(2, ...).INERT then return end
local _, ns = ...
local L = ns.L

-- The picker's windows: the look pick at first login and on its minimap button's right-click, and its settings on its
-- command, its minimap button and the game's AddOns list. The game's own frame and controls; a look recolors the
-- interface at once, so the interface itself is the preview.

local O = ns.options
local PAD, ROW_H, CHECK_H, SLIDER_W, GAP = 20, 26, 24, 160, 12
local BAR_GAP, FOOT_H = 6, 50   -- the scroll bar's gap; under the content: Done and its margins
local LOOKS = {
    { label = "LOOKPICK_OWN" },
    { key = "themeDark" },
    { key = "themeBronze" },
    { key = "themeCustom" },
}
local syncs = {}   -- every built part's refresh
local byKey        -- the rows by key
local pick, settings, content, canvas
local scroll, idle   -- the settings window's scroll frame; its child while the AddOns list holds the content

-- The look showing now: false while the theme is off.
local function Current()
    local db = ns.db
    if not db.bronzeTheme then return false end
    for _, look in ipairs(LOOKS) do
        if look.key and db[look.key] then return look.key end
    end
    return false
end

local function SyncAll()
    for _, sync in ipairs(syncs) do sync() end
end

-- The theme on with one look (the radio's others off), or off, in one pass.
local function Pick(key)
    local db = ns.db
    db.bronzeTheme = key and true or false
    if key then
        for _, look in ipairs(LOOKS) do
            if look.key then db[look.key] = look.key == key end
        end
    end
    ns.TogglesChanged(key and { "bronzeTheme", key } or { "bronzeTheme" })
    SyncAll()
end

-- The four looks from top down at y in host: the game's radios, Dark's and Bronze's sliders and the custom color's
-- swatch beside their names. Returns the height and the widest row's need.
local function LookRows(host, y, prefix)
    local rows, need = {}, 0
    for i, look in ipairs(LOOKS) do
        local row = ns.NewFrame("Button", nil, host)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y - (i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, y - (i - 1) * ROW_H)
        local radio = ns.NewFrame("CheckButton", prefix .. i, row, "UIRadioButtonTemplate")
        radio:SetPoint("LEFT")
        local text = radio:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", radio, "RIGHT", 6, 0)
        text:SetText(L[look.label or ("OPT_" .. look.key)])
        local function Choose() Pick(look.key or false) end
        row:SetScript("OnClick", Choose)
        radio:SetScript("OnClick", Choose)
        row.radio, row.text, row.key = radio, text, look.key or false
        rows[i] = row
        need = math.max(need, 22 + text:GetStringWidth())
    end
    local dark, bronze, custom = rows[2], rows[3], rows[4]
    -- Both sliders past the wider name, lined up.
    local sliderX = 22 + math.max(dark.text:GetStringWidth(), bronze.text:GetStringWidth()) + 12
    local darkness = O.DarknessRow(dark, SLIDER_W)
    darkness:SetPoint("LEFT", dark, "LEFT", sliderX, 0)
    local bronzeShade = O.BronzeShadeRow(bronze, SLIDER_W)
    bronzeShade:SetPoint("LEFT", bronze, "LEFT", sliderX, 0)
    need = math.max(need, sliderX + SLIDER_W)
    -- The custom color's swatch: a click picks the look and opens the game's color picker.
    local chip = ns.NewFrame("Button", nil, custom)
    chip:SetSize(18, 18)
    chip:SetPoint("LEFT", custom.text, "RIGHT", 10, 0)
    local rim = chip:CreateTexture(nil, "BACKGROUND")
    rim:SetAllPoints()
    rim:SetColorTexture(0, 0, 0, 1)
    local swatch = chip:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 1, -1)
    swatch:SetPoint("BOTTOMRIGHT", -1, 1)
    chip:SetScript("OnClick", function()
        Pick("themeCustom")
        O.EditThemeColor(SyncAll)
    end)
    syncs[#syncs + 1] = function()
        local now = Current()
        for _, row in ipairs(rows) do row.radio:SetChecked(row.key == now) end
        -- Each look's slider: live while it is the look.
        darkness:SetEnabled(now == "themeDark")
        bronzeShade:SetEnabled(now == "themeBronze")
        local r, g, b = ns.HexColor(ns.db.themeColor)
        swatch:SetColorTexture(r or 1, g or 1, b or 1)
    end
    return #LOOKS * ROW_H, need
end

-- A setting's row is live while every setting above it is on.
local function Live(key)
    local entry = byKey[key]
    local parent = entry and entry.parent
    if not parent then return true end
    return ns.db[parent] == true and Live(parent)
end

local checks = 0
-- The game's check box for a row of the list, its label on it and its tip on hover. Returns it and its width.
local function Check(host, entry)
    local key = entry[1]
    checks = checks + 1
    local check = ns.NewFrame("CheckButton", "FallensUIColorPickerCheck" .. checks, host, "UICheckButtonTemplate")
    check:SetSize(CHECK_H, CHECK_H)
    local text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", check, "RIGHT", 2, 1)
    text:SetText(entry[2])
    check:SetHitRectInsets(0, -text:GetStringWidth() - 4, 0, 0)
    check:SetScript("OnClick", function(self)
        ns.db[key] = self:GetChecked() and true or false
        ns.ToggleChanged(key)
        SyncAll()
    end)
    if entry[3] then ns.AttachTip(check, { text = entry[2], r = 1, g = 1, b = 1, lines = { { entry[3], nil, nil, nil, true } } }) end
    syncs[#syncs + 1] = function()
        local live = Live(key)
        check:SetChecked(ns.db[key] == true)
        check:SetEnabled(live)
        text:SetTextColor(live and 1 or 0.5, live and 1 or 0.5, live and 1 or 0.5)
    end
    return check, CHECK_H + 4 + text:GetStringWidth()
end

-- The rows grouped under one check list (checks = name), in list order.
local function Group(name)
    local list = {}
    for _, entry in ipairs(ns.TOGGLES) do
        if entry.checks == name and not (entry.hideIf and entry.hideIf()) then list[#list + 1] = entry end
    end
    return list
end

-- Checks side by side from x at y, each as wide as the widest. Returns the row's width.
local function Inline(host, entries, x, y)
    local made, widest = {}, 0
    for i, entry in ipairs(entries) do
        local check, w = Check(host, entry)
        made[i], widest = check, math.max(widest, w)
    end
    for i, check in ipairs(made) do check:SetPoint("TOPLEFT", host, "TOPLEFT", x + (i - 1) * (widest + GAP), y) end
    return x + #made * (widest + GAP)
end

local COLS = 3   -- the grids' columns at the content's first width
local GRIDS = { { "themeParts", "OPT_DROP_THEMED" }, { "themePieces", "OPT_DROP_PIECES" } }

-- The settings, top down: the looks, Textured color and its parts, the themed parts and window pieces in columns, the
-- background shade, the elite and nameplate dragons, the minimap button and Forever welcome on one line. Built once,
-- shown in our window or the game's AddOns list (its canvas is about 600 high). Fit(width) lays the grids in as many
-- columns as fit; least and wide: its narrowest width and its first.
local function Content()
    byKey = {}
    for _, entry in ipairs(ns.TOGGLES) do byKey[entry[1]] = entry end
    local host = ns.NewFrame("Frame", nil, UIParent)
    local h, need = LookRows(host, 0, "FallensUIColorPickerSet")
    host.looks = h
    local y = -h - 6
    if byKey.themeTextured then
        local check, cw = Check(host, byKey.themeTextured)
        check:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y)
        need = math.max(need, cw)
        y = y - CHECK_H
        need = math.max(need, Inline(host, Group("texturedParts"), 24, y))
        y = y - CHECK_H - GAP
    end
    local above = -y
    -- The parts, then the window pieces, in columns as wide as the widest check of both.
    local grid = ns.NewFrame("Frame", nil, host)
    grid:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y)
    local grids, heads, colW = {}, {}, 0
    for i, spec in ipairs(GRIDS) do
        local made = {}
        for j, entry in ipairs(Group(spec[1])) do
            local check, cw = Check(grid, entry)
            made[j], colW = check, math.max(colW, cw)
        end
        grids[i] = made
        heads[i] = grid:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heads[i]:SetText(L[spec[2]])
    end
    local below = ns.NewFrame("Frame", nil, host)
    below:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, 0)
    y = 0
    do
        local head, row = O.PaneRow(below, SLIDER_W + 140)
        head:SetPoint("TOPLEFT", below, "TOPLEFT", -4, y)
        row:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
        syncs[#syncs + 1] = function() row:SetEnabled(ns.db.bronzeTheme == true) end
        y = y - 56 - GAP
    end
    if byKey.themeIgnoreElite then
        local check, cw = Check(below, byKey.themeIgnoreElite)
        check:SetPoint("TOPLEFT", below, "TOPLEFT", 0, y)
        need = math.max(need, Inline(below, Group("themeIgnoreEliteFrames"), cw + GAP, y))
        y = y - CHECK_H
    end
    if byKey.themeIgnorePlateDragon then
        local check, cw = Check(below, byKey.themeIgnorePlateDragon)
        check:SetPoint("TOPLEFT", below, "TOPLEFT", 0, y)
        need, y = math.max(need, cw), y - CHECK_H
    end
    local last = {}
    for _, key in ipairs({ "minimapButton", "foreverWelcome" }) do
        local entry = byKey[key]
        if entry and not (entry.hideIf and entry.hideIf()) then last[#last + 1] = entry end
    end
    need, y = math.max(need, Inline(below, last, 0, y)), y - CHECK_H
    local rest = -y
    below:SetSize(need, rest)
    host.least = math.max(need, colW + GAP)
    host.wide = math.max(need, COLS * (colW + GAP))
    function host.Fit(width)
        width = math.max(width, host.least)
        local cols = math.max(1, math.floor((width + GAP) / (colW + GAP)))
        local gy = 0
        for i, made in ipairs(grids) do
            heads[i]:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, gy)
            gy = gy - heads[i]:GetStringHeight() - 6
            for j, check in ipairs(made) do
                local col, line = (j - 1) % cols, math.floor((j - 1) / cols)
                check:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (colW + GAP), gy - line * CHECK_H)
            end
            gy = gy - math.ceil(#made / cols) * CHECK_H - GAP
        end
        grid:SetSize(width, -gy)
        host:SetSize(width, above - gy + rest)
    end
    host.Fit(host.wide)
    return host
end

-- Our content into the AddOns list's canvas at its top left.
local function Hold(holder, x, y)
    content = content or Content()
    if scroll then scroll:SetScrollChild(idle) end
    content:SetParent(holder)
    ns.SetPointOnce(content, "TOPLEFT", holder, "TOPLEFT", x, y)
    content.Fit(content.wide)
    content:Show()
    SyncAll()
end

-- Our content into the settings window's scroll frame, laid out for its width.
local function Scrolled(width)
    content = content or Content()
    content:ClearAllPoints()
    scroll:SetScrollChild(content)
    content.Fit(width)
    content:Show()
    SyncAll()
end

-- The game's own window: its title, close button and Escape, draggable.
local function Window(name)
    local frame = ns.NewFrame("Frame", name, UIParent, "DefaultPanelFlatTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    ns.MakeDraggable(frame)
    frame:Hide()
    frame.TitleContainer.TitleText:SetText(O.TITLE)
    local close = ns.NewFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 0)
    ns.CloseOnEscape(frame, function() frame:Hide() end)
    return frame
end

local function DoneButton(frame)
    local done = ns.NewFrame("Button", nil, frame, "UIPanelButtonTemplate")
    done:SetText(_G.DONE or "Done")
    done:SetSize(math.max(90, done:GetFontString():GetStringWidth() + 30), 22)
    done:SetScript("OnClick", function() frame:Hide() end)
    return done
end

-- The first login's pick: the looks, where to change them later, Done on a line of its own.
local function BuildPick()
    local frame = Window("FallensUIColorPickerLookPick")
    local looks = ns.NewFrame("Frame", nil, frame)
    looks:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -30)
    local h, need = LookRows(looks, 0, "FallensUIColorPickerLook")
    local width = math.max(280, need + 2 * PAD)
    looks:SetSize(width - 2 * PAD, h)
    frame:SetWidth(width)
    -- Its width now: a text measured before its anchored width exists is cut to one line.
    local foot = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot:SetPoint("TOPLEFT", looks, "BOTTOMLEFT", 0, -12)
    foot:SetWidth(width - 2 * PAD)
    foot:SetJustifyH("LEFT")
    foot:SetSpacing(2)
    foot:SetText(L["LOOKPICK_FOOT"]:format(ns.SLASH))
    local done = DoneButton(frame)
    done:SetPoint("TOPRIGHT", foot, "BOTTOMRIGHT", 4, -10)
    frame:SetHeight(30 + h + 12 + foot:GetStringHeight() + 10 + 22 + 14)
    frame:SetScript("OnShow", SyncAll)
    return frame
end

-- The settings in the game's scroll frame (each client's own scroll bar), sized from the corner grip and kept; at first
-- the content's width and half its height.
local function BuildSettings()
    local frame = Window("FallensUIColorPickerSettings")
    content = content or Content()
    scroll = ns.NewFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
    idle = ns.NewFrame("Frame", nil, scroll)
    local bar = scroll.ScrollBar
    local side = bar:GetWidth() + BAR_GAP
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -30)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD - side, FOOT_H)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", BAR_GAP, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", BAR_GAP, 0)
    bar:SetHideIfUnscrollable(true)
    local chromeW, chromeH = 2 * PAD + side, 30 + FOOT_H
    local maxW, maxH = UIParent:GetWidth(), UIParent:GetHeight()
    local minW, minH = content.least + chromeW, chromeH + content.looks
    frame:SetResizeBounds(minW, minH, maxW, maxH)
    local db = ns.db
    local w = db.settingsWidth or content.wide + chromeW
    local h = db.settingsHeight or math.floor((chromeH + content:GetHeight()) / 2)
    frame:SetSize(math.min(math.max(w, minW), maxW), math.min(math.max(h, minH), maxH))
    DoneButton(frame):SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD - 2, 14)
    ns.AddSizeGrip(frame, function(self)
        db.settingsWidth, db.settingsHeight = math.floor(self:GetWidth() + 0.5), math.floor(self:GetHeight() + 0.5)
    end)
    frame:HookScript("OnSizeChanged", function(_, width)
        if scroll:GetScrollChild() == content then content.Fit(width - chromeW) end
    end)
    frame:SetScript("OnShow", function(self) Scrolled(self:GetWidth() - chromeW) end)
    return frame
end

function ns.ShowLookPick()
    pick = pick or BuildPick()
    pick:Show()
end

function ns.OpenOptions()
    settings = settings or BuildSettings()
    settings:SetShown(not settings:IsShown())
end

-- The game's AddOns list shows the same content on its page.
function ns.PickerCanvas()
    canvas = canvas or ns.NewFrame("Frame", nil, UIParent)
    canvas:SetScript("OnShow", function(self) Hold(self, 16, -16) end)
    return canvas
end
