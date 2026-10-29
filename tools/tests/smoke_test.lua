-- Loads an addon's toc files against a stubbed game, then runs ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD and
-- every frame's OnUpdate a few times. Usage: lua smoke_test.lua <addon dir> <toc> <addon name> [inert|old]
-- inert: the full ClassicUI Forever enabled; old: settings saved by the build made from ClassicUI Forever.
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212
local dir, tocName, addon, inert, old = arg[1], arg[2], arg[3], arg[4] == "inert", arg[4] == "old"

local Stub
local stubMeta = {}
stubMeta.__index = function(t, k)
    if k == "GetName" then return function() return nil end end
    if k == "GetNumPoints" or k == "GetNumRegions" or k == "GetNumChildren" then return function() return 0 end end
    if k == "GetWidth" or k == "GetHeight" or k == "GetScale" or k == "GetEffectiveScale" or k == "GetAlpha"
        or k == "GetFrameLevel" or k == "GetStringWidth" or k == "GetStringHeight" or k == "GetEffectiveAlpha" then
        return function() return 1 end
    end
    if k == "GetRegions" or k == "GetChildren" or k == "GetPoint" or k == "GetCenter" or k == "GetLeft" or k == "GetTop" then
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

local env = setmetatable({}, { __index = function(t, k)
    local v = rawget(_G, k)
    if v ~= nil then return v end
    v = Stub()
    rawset(t, k, v)
    return v
end })
_G.CreateFrame = NewFrame
_G.GetLocale = function() return "enUS" end
_G.GetTime = function() return 100 end
_G.GetBuildInfo = function() return "12.1.5", "70575", "", 120105 end
_G.InCombatLockdown = function() return false end
_G.issecretvalue = function() return false end
_G.issecurevariable = function() return true end
_G.hooksecurefunc = function() end
_G.geterrorhandler = function() return function(e) error(e, 0) end end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.C_Timer = { After = function(_, fn) end, NewTicker = function() return Stub() end, NewTimer = function() return Stub() end }
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
_G.Minimap = NewFrame(nil, "Minimap")
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
