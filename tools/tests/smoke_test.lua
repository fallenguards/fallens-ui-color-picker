-- Loads an addon's toc files against a stubbed game, then runs ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD and
-- every frame's OnUpdate a few times. Usage: lua smoke_test.lua <addon dir> <toc> <addon name> [inert|old|era|forever]
-- inert: the full ClassicUI Forever enabled; old: settings saved by the build made from ClassicUI Forever; era: the
-- Classic Era client; forever: WoW Forever, its login timers run once (the welcome line).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212
local dir, tocName, addon, inert, old = arg[1], arg[2], arg[3], arg[4] == "inert", arg[4] == "old"
local era, forever = arg[4] == "era", arg[4] == "forever"

local Stub
local stubMeta = {}
stubMeta.__index = function(t, k)
    if k == "GetName" then return function() return nil end end
    if k == "GetNumPoints" or k == "GetNumRegions" or k == "GetNumChildren" then return function() return 0 end end
    if k == "GetWidth" or k == "GetHeight" or k == "GetScale" or k == "GetEffectiveScale" or k == "GetAlpha"
        or k == "GetFrameLevel" or k == "GetStringWidth" or k == "GetStringHeight" or k == "GetEffectiveAlpha" then
        return function() return 1 end
    end
    -- No children or regions at all, as the game answers: not one nil.
    if k == "GetRegions" or k == "GetChildren" then return function() end end
    if k == "GetPoint" or k == "GetCenter" or k == "GetLeft" or k == "GetTop" then
        return function() return nil end
    end
    if k == "IsShown" or k == "IsVisible" or k == "IsForbidden" or k == "IsProtected" or k == "IsObjectType"
        or k == "IsMouseOver" or k == "GetChecked" or k == "IsDesaturated" then
        return function() return false end
    end
    if k == "GetVertexColor" then return function() return 1, 1, 1, 1 end end
    local v = Stub()
    rawset(t, k, v)
    return v
end
stubMeta.__call = function() return Stub() end
stubMeta.__concat = function(a, b) return tostring(type(a) == "table" and "" or a) .. tostring(type(b) == "table" and "" or b) end
for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__unm", "__mod", "__pow" }) do stubMeta[op] = function() return 0 end end
stubMeta.__lt = function() return false end
stubMeta.__le = function() return false end
stubMeta.__len = function() return 0 end
function Stub() return setmetatable({}, stubMeta) end

local frames = {}
local function NewFrame(_, name)
    local f = Stub()
    local scripts, events = {}, {}
    rawset(f, "SetScript", function(self, which, fn) scripts[which] = fn end)
    rawset(f, "HookScript", function(self, which, fn) scripts[which] = scripts[which] or fn end)
    rawset(f, "GetScript", function(self, which) return scripts[which] end)
    rawset(f, "RegisterEvent", function(self, e) events[e] = true end)
    rawset(f, "UnregisterEvent", function(self, e) events[e] = nil end)
    rawset(f, "UnregisterAllEvents", function() for e in pairs(events) do events[e] = nil end end)
    rawset(f, "IsEventRegistered", function(self, e) return events[e] == true end)
    rawset(f, "RegisterUnitEvent", function(self, e) events[e] = true end)
    rawset(f, "GetName", function() return name end)
    rawset(f, "CreateTexture", function() return NewFrame() end)
    rawset(f, "CreateFontString", function() return NewFrame() end)
    rawset(f, "CreateMaskTexture", function() return NewFrame() end)
    f.scripts, f.events = scripts, events
    frames[#frames + 1] = f
    if type(name) == "string" then _G[name] = f end
    return f
end

-- Saved variables start nil, as on a first login (a stub there read as saved settings).
local SAVED = { FallensUIColorPickerDB = true }
local env = setmetatable({}, { __index = function(t, k)
    local v = rawget(_G, k)
    if v ~= nil or SAVED[k] then return v end
    v = Stub()
    rawset(t, k, v)
    return v
end })
_G.CreateFrame = NewFrame
_G.GetLocale = function() return "enUS" end
_G.GetTime = function() return 100 end
_G.GetBuildInfo = function()
    if era then return "1.15.9", "70576", "", 11509 end
    if forever then return "1.60.1", "70790", "", 16001 end
    return "12.1.5", "70575", "", 120105
end
_G.InCombatLockdown = function() return false end
_G.issecretvalue = function() return false end
_G.issecurevariable = function() return true end
_G.hooksecurefunc = function() end
-- Errors the addon reports through the game's handler (its SafeCall): each fails the run at the end.
local reported = {}
_G.geterrorhandler = function() return function(e) reported[#reported + 1] = tostring(e) end end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
-- Timers wait here; the forever run fires the login ones once, after the events.
local timers = {}
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() return Stub() end,
    NewTimer = function() return Stub() end }
-- Chat lines, read back by the welcome checks.
local printed = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, line) printed[#printed + 1] = tostring(line) end }
-- The game keys a character by GUID: ClassicUI Forever is on for other characters always, for this one when inert.
local ME = "Player-1-0000000A"
_G.UnitGUID = function(unit) return unit == "player" and ME or nil end
_G.C_AddOns = {
    GetAddOnEnableState = function(name, character)
        if name ~= "ClassicUIForever" then return 0 end
        if character == ME then return inert and 2 or 0 end
        return character == nil and 1 or 0
    end,
    IsAddOnLoaded = function() return false end,
}
_G.UIParent = NewFrame(nil, "UIParent")
_G.C_NamePlate = { GetNamePlates = function() return {} end }
-- Numbers where the game gives numbers (a drag's OnUpdate runs here every frame); Lua 5.1's atan2.
_G.GetCursorPosition = function() return 0, 0 end
math.atan2 = math.atan2 or math.atan -- luacheck: ignore 142 143
-- A forbidden frame in the walks, beside a window and inside it: every method but IsForbidden refuses addon code, as
-- the game's do (asking one its name ended the whole theme walk once).
local forbidden = setmetatable({}, { __index = function(_, k)
    if k == "IsForbidden" then return function() return true end end
    return function() error("a forbidden frame was asked " .. k, 2) end
end })
local window = NewFrame(nil, "SmokeWindow")
rawset(window, "GetChildren", function() return forbidden end)
rawset(_G.UIParent, "GetChildren", function() return window, forbidden end)
_G.Minimap = NewFrame(nil, "Minimap")
rawset(_G.Minimap, "GetCenter", function() return 0, 0 end)
_G.StaticPopupDialogs = {}
_G.SlashCmdList = {}
_G.UnitName = function() return "Tester" end
_G.date = os.date
_G.strsplit = function(sep, s) local out = {} for p in s:gmatch("[^" .. sep .. "]+") do out[#out + 1] = p end return table.unpack(out) end
_G.unpack = table.unpack
_G.tinsert, _G.tremove = table.insert, table.remove
_G.securecallfunction = function(fn, ...) return fn(...) end
_G.getmetatable = getmetatable

if old then
    _G.FallensUIColorPickerDB = { dbVersion = 29, minimapButton = false, bronzeTheme = true, themeDark = true,
        themeBronze = false, welcomed = false, profiles = {}, windowPos = {} }
end
local ns = {}
local toc = assert(io.open(dir .. "/" .. tocName)):read("a")
local count = 0
for line in toc:gmatch("[^\r\n]+") do
    if line:match("%.lua$") and not line:match("^#") then
        local path = dir .. "/" .. line:gsub("\\", "/")
        local chunk, err = loadfile(path, "t", env)
        if not chunk then print("LOAD " .. err) os.exit(1) end
        local ok, runErr = pcall(chunk, addon, ns)
        if not ok then print("RUN " .. line .. ": " .. tostring(runErr)) os.exit(1) end
        count = count + 1
    end
end
print("loaded " .. count .. " files" .. (ns.INERT and " (inert)" or ""))
if (ns.INERT == true) ~= inert then
    print("FAIL stand-down: inert " .. tostring(ns.INERT) .. " with ClassicUI Forever on here " .. tostring(inert))
    os.exit(1)
end

local function Fire(event, ...)
    for i = 1, #frames do
        local f = frames[i]
        if f.events[event] and f.scripts.OnEvent then
            local ok, err = pcall(f.scripts.OnEvent, f, event, ...)
            if not ok then print("EVENT " .. event .. ": " .. tostring(err)) end
        end
    end
end
Fire("ADDON_LOADED", addon)
Fire("PLAYER_LOGIN")
Fire("PLAYER_ENTERING_WORLD", true, false)
for _ = 1, 3 do
    for i = 1, #frames do
        local f = frames[i]
        if f.scripts.OnUpdate then
            local ok, err = pcall(f.scripts.OnUpdate, f, 0.016)
            if not ok then print("ONUPDATE: " .. tostring(err)) break end
        end
    end
end
if old then
    local db = _G.FallensUIColorPickerDB
    local ok = db.minimapButton == true and db.bronzeTheme == true and db.themeDark == true and db.profiles == nil
        and db.dbVersion == 1
    print((ok and "PASS" or "FAIL") .. " old settings: minimap button " .. tostring(db.minimapButton) .. ", theme kept "
        .. tostring(db.bronzeTheme and db.themeDark) .. ", leftovers gone " .. tostring(db.profiles == nil))
    if not ok then os.exit(1) end
end
if not ns.INERT then
    print("db " .. tostring(ns.db ~= nil) .. ", modules " .. #(ns.modules or {}) .. ", slash " .. tostring(ns.SLASH))
    for _, fn in ipairs({ "OpenOptions", "ShowLookPick" }) do
        local ok, err = pcall(ns[fn])
        print(fn .. (ok and " ran" or (" ERROR " .. tostring(err))))
    end
    ns.db.bronzeTheme, ns.db.themeDark, ns.db.themeBronze = true, true, false
    local ok, err = pcall(ns.ToggleChanged, "bronzeTheme")
    print("theme on (Dark) " .. (ok and "ran" or ("ERROR " .. tostring(err))))
    ok, err = pcall(ns.ToggleChanged, "themePartTooltips")
    print("part toggle " .. (ok and "ran" or ("ERROR " .. tostring(err))))
end

-- Window pieces: each kind by its frames' names, its atlas or its button; a slot's rim and the bars' art stay out.
local function Piece(kind, name, key, parent, atlas)
    local f = NewFrame(nil, name)
    rawset(f, "GetParentKey", function() return key end)
    rawset(f, "GetParent", function() return parent end)
    rawset(f, "IsObjectType", function(_, t) return t == kind or (t == "Button" and kind == "CheckButton") end)
    rawset(f, "GetAtlas", function() return atlas end)
    if kind == "Texture" then rawset(f, "GetChildren", false) end
    return f
end
if not ns.INERT then
    local host = Piece("Frame", "SmokePieceWindow", nil, _G.UIParent)
    local function Art(parent, atlas, name) return Piece("Texture", name, nil, parent, atlas) end
    local scroll = Piece("Frame", nil, "ScrollBar", host)
    local thumb = Piece("Button", nil, "Thumb", Piece("Frame", nil, "Track", scroll))
    local dropdown = Piece("Frame", "SmokeOptionsDropDown", nil, host)
    local menuRow = Piece("Button", "DropDownList1Button1", nil, Piece("Frame", "DropDownList1", nil, host))
    local slot = Piece("Button", nil, nil, host)
    rawset(slot, "icon", Art(slot))
    local pane = Art(host)
    ns.PinBackground(pane, true)
    _G.PlayerFrame = Piece("Button", "PlayerFrame", nil, _G.UIParent)
    Fire("ADDON_LOADED", "SmokePieces")
    local button = Art(Piece("Button", nil, "CloseButton", host))
    local cases = {
        { "scroll bar thumb", Art(thumb), "themePieceScrollBars" },
        { "scroll bar track by name", Art(host, nil, "SmokeListScrollBarTop"), "themePieceScrollBars" },
        { "dropdown by name", Art(Piece("Button", "SmokeOptionsDropDownButton", nil, dropdown)), "themePieceDropdowns" },
        { "dropdown by atlas", Art(Piece("Button", nil, nil, host), "common-dropdown-a-button"), "themePieceDropdowns" },
        { "menu row", Art(menuRow), "themePieceButtons" },
        { "tab by name", Art(Piece("Button", "SmokeFrameTab2", nil, host)), "themePieceTabs" },
        { "tab by atlas", Art(Piece("Button", nil, nil, host), "_UIFrame-ActiveTab-Mid"), "themePieceTabs" },
        { "close button", button, "themePieceButtons" },
        { "check box", Art(Piece("CheckButton", nil, nil, host)), "themePieceButtons" },
        { "slot rim", Art(slot), "themePieceBorders" },
        { "frame metal", Art(host, "UI-Frame-Metal-EdgeTop"), "themePieceBorders" },
        { "background", pane, "themePartParchment" },
    }
    local failed = 0
    for _, case in ipairs(cases) do
        local got = ns.ThemePieceOf(case[2])
        if got ~= case[3] then
            failed = failed + 1
            print("FAIL piece " .. case[1] .. ": " .. tostring(got) .. ", want " .. case[3])
        end
    end
    -- Buttons left out: a window's button as drawn, the unit frame (a button) still in the theme.
    ns.db.themePieceButtons = false
    local hud = Art(_G.PlayerFrame)
    local leftOut = ns.ThemePartOn(button) == false and ns.ThemePartOn(hud) == true and ns.ThemePartOn(pane) == true
    ns.db.themePieceButtons = true
    if not leftOut then failed = failed + 1 end
    print((failed == 0 and "PASS" or "FAIL") .. " window pieces: " .. #cases .. " kinds, Buttons left out "
        .. (leftOut and "as drawn, bars and backgrounds kept" or "WRONG"))
    if failed > 0 then os.exit(1) end
end
-- A frame the client refuses addon code while saying it is not forbidden (the target's aura buttons): its name
-- read errors, so the walks leave it alone; a plain frame and an object with no name are walked.
if ns.IsForbidden then
    local refusing = NewFrame(nil, nil)
    rawset(refusing, "GetName", function() error("Attempt to access forbidden object from code tainted by an AddOn") end)
    local ok = ns.IsForbidden(refusing) == true and ns.IsForbidden(NewFrame(nil, "PlainFrame")) == false
        and ns.IsForbidden({}) == false and ns.IsForbidden(nil) == true
    print((ok and "PASS" or "FAIL") .. " forbidden: a frame refusing its name is left alone")
    if not ok then os.exit(1) end
end
-- The aura rim pass meets those buttons too (every half second with a target's auras): one refusing every call, with
-- its icon there, is passed over without an error.
if ns.bronze and ns.bronze.AuraRim then
    local function Refuse() error("Attempt to access forbidden object from code tainted by an AddOn") end
    local aura = setmetatable({}, { __index = function(_, k)
        if k == "IsForbidden" then return function() return false end end
        return Refuse
    end })
    rawset(aura, "Icon", aura)
    local ok, err = pcall(ns.bronze.AuraRim, aura)
    print((ok and "PASS" or "FAIL") .. " aura rims: a refusing aura button is passed over" .. (ok and "" or (": " .. tostring(err))))
    if not ok then os.exit(1) end
end
-- A bag bar button's picture: slot art (Bag slots) while the slot is empty and for the key ring, the bag's own icon
-- (Bag icons) once a bag is in it.
if ns.ThemePartOf then
    local bagSlot = NewFrame(nil, "CharacterBag0Slot")
    local icon = NewFrame(nil, "CharacterBag0SlotIconTexture")
    rawset(icon, "GetParent", function() return bagSlot end)
    local ring = NewFrame(nil, "KeyRingButtonIconTexture")
    rawset(ring, "GetParent", function() return NewFrame(nil, "KeyRingButton") end)
    env.C_Container = { ContainerIDToInventoryID = function(id) return 19 + id end }
    local asked, held = nil, nil
    env.GetInventoryItemID = function(_, slot) asked = slot return held end
    local empty = ns.ThemePartOf(icon)
    held = 4500
    local filled = ns.ThemePartOf(icon)
    local ok = empty == "themePartBagSlots" and filled == "themePartBagIcons" and asked == 20
        and ns.ThemePartOf(ring) == "themePartBagSlots"
    print((ok and "PASS" or "FAIL") .. " bag slots: empty " .. tostring(empty) .. ", with a bag " .. tostring(filled)
        .. ", key ring " .. tostring(ns.ThemePartOf(ring)))
    if not ok then os.exit(1) end
end
-- The Forever welcome: on Forever a line with both its links, nowhere else.
local function Welcomed()
    for _, line in ipairs(printed) do
        if line:find("|Hfcp:issues|h", 1, true) and line:find("|Hfcp:hidewelcome|h", 1, true) then return true end
    end
    return false
end
if not ns.INERT and (forever or era) then
    local queued = timers
    timers = {}
    for _, fn in ipairs(queued) do
        local ok, err = pcall(fn)
        if not ok then reported[#reported + 1] = "timer: " .. tostring(err) end
    end
    local want = forever
    print((Welcomed() == want and "PASS" or "FAIL") .. " Forever welcome " .. (want and "shown" or "not shown"))
    if Welcomed() ~= want then os.exit(1) end
end
if #reported > 0 then
    for _, e in ipairs(reported) do print("REPORTED " .. e) end
    os.exit(1)
end
