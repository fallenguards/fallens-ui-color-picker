if select(2, ...).INERT then return end
local _, ns = ...

-- Which pieces a theme paints (the Parts drop down under the theme): a piece's part by the frames it sits in, anything
-- else the other windows'. Parchment is a kind, not a place: its layers and pages ask for it by name.

local weak = { __mode = "k" }
local DEPTH = 16

-- A frame by global name, or keys under one ("MainActionBar.ActionBarPageNumber").
local function Lookup(name)
    local frame
    for key in name:gmatch("[^.]+") do
        if frame then frame = frame[key] else frame = _G[key] end
        if type(frame) ~= "table" then return nil end
    end
    return frame
end

-- A finder of a piece's part (roots: part -> frame names; names: { pattern, part } families by frame name; other: the
-- part of anything else; orphan: of a piece hanging from no window, as the game's menus), worked out once a piece and
-- again after an addon loads (its frames are new).
function ns.PartFinder(roots, names, other, orphan)
    local parts, rootPart = setmetatable({}, weak), setmetatable({}, weak)
    local stale = true
    ns.EventFrame("ADDON_LOADED", function() stale = true end)
    local function Named(frame)
        local name = names and frame.GetName and frame:GetName()
        if type(name) ~= "string" or ns.IsSecret(name) then return nil end
        for _, family in ipairs(names) do
            if name:find(family[1]) then return family[2] end
        end
    end
    return function(region)
        if stale then
            stale = false
            wipe(parts)
            for part, list in pairs(roots) do
                for _, name in ipairs(list) do
                    local frame = Lookup(name)
                    if frame then rootPart[frame] = part end
                end
            end
        end
        local part = parts[region]
        if part then return part end
        local frame = region
        for _ = 1, DEPTH do
            if not frame or frame == UIParent or ns.IsForbidden(frame) then break end
            part = rootPart[frame] or Named(frame)
            if part then break end
            local parent = frame:GetParent()
            if not parent then
                part = orphan
                break
            end
            frame = parent
        end
        part = part or other
        parts[region] = part
        return part
    end
end

-- The band's frames; Textured color's Bar art part reads them too (Art/ThemeFlat.lua).
ns.BAR_ROOTS = { "FallensUIColorPickerBar", "FallensUIColorPickerMicroGroup", "FallensUIColorPickerBagsExtra", "MainActionBar",
    "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7",
    "StanceBar", "PetActionBar", "PossessActionBar", "BagsBar", "MicroMenuContainer", "StatusTrackingBarManager" }
local OTHER = "themePartWindows"
-- A bag bar button's picture (Forever's backpack and key ring, the bags, the reagent bag): Bag icons, apart from its
-- border. Art/GameArt.lua too.
ns.BAG_ICONS = { "Bag%dSlotIconTexture$", "^MainMenuBarBackpackButtonIconTexture$", "^KeyRingButtonIconTexture$" }
-- Every bag, chat window with its tab and box, nameplate; the micro and bag buttons the band takes onto its art.
local FAMILIES = { { ns.BAG_ICONS[1], "themePartBagIcons" }, { ns.BAG_ICONS[2], "themePartBagIcons" },
    { ns.BAG_ICONS[3], "themePartBagIcons" }, { "^ContainerFrame%d", "themePartBags" }, { "^ChatFrame%d", "themePartChat" },
    { "^NamePlate%d", "themePartNameplates" }, { "MicroButton", "themePartMicroMenu" },
    { "^CharacterBag%dSlot", "themePartBagBar" }, { "^CharacterReagentBag%dSlot", "themePartBagBar" },
    { "^MainMenuBarBackpackButton", "themePartBagBar" }, { "^KeyRingButton", "themePartBagBar" },
    { "^BagBarExpandToggle", "themePartBagBar" } }
-- The band's action bars: its frames but the micro menu, bag bar and XP bars, each a part of its own.
local OWN_PART = { BagsBar = true, MicroMenuContainer = true, StatusTrackingBarManager = true,
    FallensUIColorPickerMicroGroup = true, FallensUIColorPickerBagsExtra = true }
local ACTION_ROOTS = {}
for _, name in ipairs(ns.BAR_ROOTS) do
    if not OWN_PART[name] then ACTION_ROOTS[#ACTION_ROOTS + 1] = name end
end
-- The nearest root up a piece's frames wins: a target's cast bar before its unit frame.
local PartOf = ns.PartFinder({
    themePartUnits = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "PartyFrame", "TargetFrameToT",
        "FocusFrameToT", "BossTargetFrameContainer" },
    themePartCastBars = { "PlayerCastingBarFrame", "PetCastingBarFrame", "TargetFrameSpellBar", "FocusFrameSpellBar",
        "OverlayPlayerCastingBarFrame" },
    themePartMinimap = { "MinimapCluster", "Minimap", "QueueStatusButton", "FallensUIColorPickerMinimapBag", "GameTimeFrame",
        "TimeManagerClockButton" },
    themePartBars = ACTION_ROOTS,
    themePartPageArrows = { "MainActionBar.ActionBarPageNumber" },
    themePartMicroMenu = { "MicroMenuContainer", "FallensUIColorPickerMicroGroup" },
    themePartBagBar = { "BagsBar", "FallensUIColorPickerBagsExtra" },
    themePartXPBars = { "StatusTrackingBarManager", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" },
    themePartBags = { "ContainerFrameCombinedBags", "BankFrame" },
    themePartTooltips = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" },
    themePartChat = { "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton" },
    themePartQuestTracker = { "ObjectiveTrackerFrame", "FallensUIColorPickerQuestWatch" },
}, FAMILIES, OTHER, "themePartMenus")
-- A piece of ours in another part than where it hangs (the backpack's bag picture, Bag icons on its button).
local pinned = setmetatable({}, weak)
function ns.PinThemePart(region, part) pinned[region] = part end
-- Read by the dev addon's theme probes.
function ns.ThemePartOf(region) return pinned[region] or PartOf(region) end

-- Window pieces (their rows under the parts): a scroll bar's, a dropdown's or a tab's by a name on it or up its frames,
-- else by its atlas; a button's by the button it sits on (an item or spell slot's rim is border); the rest border.
-- Backgrounds are pinned by the walks that find them (Parchment's row). The bars, unit frames and minimap are each
-- one piece: only their part's row turns them.
local BACKGROUNDS, BORDERS, BUTTONS = "themePartParchment", "themePieceBorders", "themePieceButtons"
local TABS, SCROLL_BARS, DROPDOWNS = "themePieceTabs", "themePieceScrollBars", "themePieceDropdowns"
local PIECE_PARTS = { [OTHER] = true, themePartBags = true, themePartChat = true, themePartQuestTracker = true,
    themePartTooltips = true, themePartMenus = true }
local LOOK_UP = 3
local ATLAS_PIECES = { { "scrollbar", SCROLL_BARS }, { "dropdown", DROPDOWNS }, { "^uiframe%-tab", TABS },
    { "^uiframe%-activetab", TABS }, { "sidetab", TABS }, { "toptab", TABS }, { "^options_tab", TABS },
    { "^questlog%-tab", TABS }, { "^uitools%-tab", TABS }, { "^transmog%-tab", TABS }, { "^gm%-tab", TABS },
    { "^garrlanding%-tab", TABS } }
local SLOT_KEYS = { "icon", "Icon", "IconTexture" }

-- A name or parent key that says the piece (lower case): the menus' lists are no dropdowns.
local function Said(text)
    if type(text) ~= "string" or ns.IsSecret(text) then return nil end
    text = text:lower()
    if text:find("scrollbar", 1, true) then return SCROLL_BARS end
    if text:find("dropdown", 1, true) and not text:find("dropdownlist", 1, true) then return DROPDOWNS end
    if text:find("tab%d*$") or text:find("tabbutton%d*$") then return TABS end
end

local function NamedPiece(obj)
    return Said(obj:GetName()) or Said(obj.GetParentKey and obj:GetParentKey())
end

local atlasPiece = {}   -- atlas -> its piece or false, worked out once
local function AtlasPiece(atlas)
    local known = atlasPiece[atlas]
    if known ~= nil then return known end
    local name = atlas:lower():gsub("^[_!]+", "")
    known = false
    for _, entry in ipairs(ATLAS_PIECES) do
        if name:find(entry[1]) then
            known = entry[2]
            break
        end
    end
    atlasPiece[atlas] = known
    return known
end

local function Slot(button)
    for _, key in ipairs(SLOT_KEYS) do
        local icon = rawget(button, key)
        if type(icon) == "table" and icon.IsObjectType and icon:IsObjectType("Texture") then return true end
    end
    local name = button:GetName()
    return type(name) == "string" and not ns.IsSecret(name) and _G[name .. "IconTexture"] ~= nil
end

local function JudgePiece(region)
    if ns.IsForbidden(region) then return BORDERS end
    local piece = NamedPiece(region)
    local owner = region.GetChildren and region or region:GetParent()
    local frame = owner
    for _ = 0, LOOK_UP do
        if piece or not frame or frame == UIParent or ns.IsForbidden(frame) then break end
        piece = NamedPiece(frame)
        frame = frame:GetParent()
    end
    if piece then return piece end
    local atlas = region.GetAtlas and region:GetAtlas()
    if type(atlas) == "string" and not ns.IsSecret(atlas) then
        piece = AtlasPiece(atlas)
        if piece then return piece end
    end
    if owner and not ns.IsForbidden(owner) and owner:IsObjectType("Button") and not Slot(owner) then return BUTTONS end
    return BORDERS
end

-- Worked out once a piece, its atlas as it first came (the theme's copies put files in their place).
local pieceOf, pinnedPiece = setmetatable({}, weak), setmetatable({}, weak)
function ns.PinBackground(region, on) pinnedPiece[region] = on and BACKGROUNDS or nil end
-- Read by the dev addon's theme probes.
function ns.ThemePieceOf(region)
    local piece = pinnedPiece[region] or pieceOf[region]
    if piece then return piece end
    piece = JudgePiece(region)
    pieceOf[region] = piece
    return piece
end

-- Each part's row; a theme change repaints on it as on any theme setting.
local PART_KEYS = { themePartParchment = true, themePartUnits = true, themePartCastBars = true,
    themePartNameplates = true, themePartMinimap = true, themePartBars = true, themePartPageArrows = true,
    themePartMicroMenu = true, themePartBagBar = true, themePartBagIcons = true, themePartXPBars = true, themePartBags = true,
    themePartTooltips = true, themePartMenus = true, themePartChat = true, themePartQuestTracker = true, [OTHER] = true,
    themePartAddons = true, [BORDERS] = true, [BUTTONS] = true, [TABS] = true, [SCROLL_BARS] = true, [DROPDOWNS] = true }

-- Other addons: their frames on the game's windows, walked only while it is checked (off by default), each piece the
-- walks paint marked so leaving it out hands them back.
local addonPieces = setmetatable({}, weak)
function ns.ThemeAddonsOn() return ns.db ~= nil and ns.db.themePartAddons == true end
function ns.MarkAddonPiece(region) addonPieces[region] = true end
for key in pairs(PART_KEYS) do ns.bronze.THEME_KEYS[key] = true end
function ns.IsThemePart(key) return PART_KEYS[key] == true end

-- dbVersion 29: the parts split finer; each new one starts as the part it came out of.
local SPLIT_FROM = { themePartMicroMenu = "themePartBars", themePartBagBar = "themePartBars",
    themePartXPBars = "themePartBars", themePartCastBars = "themePartUnits", themePartNameplates = "themePartUnits",
    themePartMenus = "themePartTooltips", themePartQuestTracker = "themePartWindows" }
local function Split(db)
    for new, old in pairs(SPLIT_FROM) do
        if db[new] == nil and db[old] == false then db[new] = false end
    end
end
function ns.SplitThemeParts()
    local db = ns.db
    Split(db)
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" then Split(shot) end
    end
    db.dbVersion = 29
end

-- where: a region, or a part's key (a module that paints no region of its own: menus, chat buttons); nil: any part.
function ns.ThemePartOn(where)
    local db = ns.db
    if not db or where == nil then return true end
    if type(where) == "string" then return db[where] ~= false end
    if addonPieces[where] and db.themePartAddons ~= true then return false end
    local part = ns.ThemePartOf(where)
    if db[part] == false then return false end
    return not PIECE_PARTS[part] or db[ns.ThemePieceOf(where)] ~= false
end

-- The theme on for this piece, or nil: none picked, or its part left out. No piece: the theme on at all.
function ns.ThemeFor(where)
    local name = ns.ThemeName()
    if name and ns.ThemePartOn(where) then return ns.bronze.THEMES[name] end
end
