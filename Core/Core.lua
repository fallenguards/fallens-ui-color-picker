if select(2, ...).INERT then return end
local ADDON, ns = ...
local L = ns.L

ns.NAME = "Fallen's UI Color Picker"
-- Chat lines lead with the picker's gem (the addon list icon).
ns.PREFIX = "|TInterface\\Icons\\INV_Misc_Gem_Variety_01:14:14|t |cffe6c56c" .. ns.NAME .. "|r: "

-- { key = db key, apply, restore, init, id }, walked in ns.MODULE_ORDER; id defaults to key.
ns.modules = {}

function ns.RegisterModule(key, mod)
    mod.key = key
    ns.modules[#ns.modules + 1] = mod
end

-- Stable in-place sort; unlisted ids go last in registration order.
local function OrderModules()
    local rank = {}
    for i, id in ipairs(ns.MODULE_ORDER) do rank[id] = rank[id] or i end
    local listed = {}
    for i, mod in ipairs(ns.modules) do listed[i] = { mod = mod, rank = rank[mod.id or mod.key] or 1000, at = i } end
    table.sort(listed, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.at < b.at
    end)
    for i, entry in ipairs(listed) do ns.modules[i] = entry.mod end
end

-- Only an attached dev tool receives these lines.
function ns.Persist(line)
    if ns.debugSink then ns.debugSink(line) end
end

-- Forever has a 16xxx toc, retail 120xxx; branch on this, never on whether a function exists.
function ns.OnForever()
    local _, _, _, toc = GetBuildInfo()
    return type(toc) == "number" and toc >= 16000 and toc < 17000
end

function ns.Print(msg)
    if ns.IsSecret(msg) then msg = "<protected value>" end
    DEFAULT_CHAT_FRAME:AddMessage(ns.PREFIX .. tostring(msg))
end

-- xpcall handler: the error handler is looked up only when an error happens.
local function Report(err)
    return geterrorhandler()(err)
end
ns.Report = Report

function ns.SafeCall(fn, ...)
    return xpcall(fn, Report, ...)
end

-- Work on client windows waits for combat to end.
local calmJobs, calmWatch = {}, nil
function ns.WhenCalm(key, fn)
    if not InCombatLockdown() then return ns.SafeCall(fn) end
    calmJobs[key] = fn
    if calmWatch then return end
    calmWatch = CreateFrame("Frame")
    calmWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
    calmWatch:SetScript("OnEvent", function()
        if InCombatLockdown() then return end
        local held = calmJobs
        calmJobs = {}
        for _, job in pairs(held) do ns.SafeCall(job) end
    end)
end

-- At most one deferred pass per frame; a full one asked for too wins.
local queued, queuedFull = false, false
local NO_KEYS = {}
local function RunQueuedApply()
    local full = queuedFull
    queued, queuedFull = false, false
    if full then ns.ApplyAll() else ns.ApplyChanged(NO_KEYS) end
end
local function Queue(full)
    if full then queuedFull = true end
    if queued then return end
    queued = true
    C_Timer.After(0, RunQueuedApply)
end
function ns.QueueApply() Queue(true) end
-- A setting written outside a check box (a slider at rest): the modules that read it, next frame.
function ns.QueueChanged() Queue(false) end

local toggleParent, toggleOrder

local function ToggleTree()
    if toggleParent then return end
    toggleParent, toggleOrder = {}, {}
    for i, entry in ipairs(ns.TOGGLES) do
        toggleParent[entry[1]] = entry.parent
        toggleOrder[entry[1]] = i
    end
end

-- A module runs while its setting and every setting above it are on.
local function ModuleOn(key)
    if ns.db[key] == false then return false end
    ToggleTree()
    local parent = toggleParent[key]
    if parent and parent ~= key then return ModuleOn(parent) end
    return true
end

-- Whether a setting is in force; ClassicUI Forever's module names, asked by the engine, are never ours.
function ns.ModuleInForce(key)
    ToggleTree()
    if not ns.db or not toggleOrder[key] then return false end
    return ModuleOn(key)
end

-- Settings each module read in its last run: a change runs only the modules that read it. During a run ns.db is a
-- reader noting each key; writes go straight through. No record (an error) runs every pass.
local NIL_READ = {}
local realDb, reading, running
local dbReader = setmetatable({}, {
    __index = function(_, key)
        if reading then reading[key] = true end
        return realDb[key]
    end,
    __newindex = function(_, key, value) realDb[key] = value end,
})

-- The engine notes game setting reads; the picker writes none, so they never make a module stale.
function ns.NoteCVarRead() end

local function ReadInto(seen, fn, ...)
    local outer = reading
    if not outer then realDb, ns.db = ns.db, dbReader end
    reading = seen
    local ok = ns.SafeCall(fn, ...)
    reading = outer
    if outer then
        for key in pairs(seen) do outer[key] = true end
    else
        ns.db = realDb
    end
    return ok
end

local function Note(mod, seen)
    for key in pairs(seen) do
        local value = realDb[key]
        if value == nil then value = NIL_READ end
        mod.reads[key] = value
    end
end

local function Step(mod)
    if ModuleOn(mod.key) then mod.apply() else mod.restore() end
end

local function RunModule(mod)
    local seen, outer = {}, running
    running = mod
    local ok = ReadInto(seen, Step, mod)
    running = outer
    if not ok then
        mod.reads = nil
        return
    end
    mod.reads = wipe(mod.reads or {})
    Note(mod, seen)
end

-- Work a module's run leaves for later (ns.Sched.Soon) counts as its run's reads.
function ns.PassReads(fn)
    local mod = running
    if not mod then return fn end
    return function(...)
        local seen, outer = {}, running
        running = mod
        local ok = ReadInto(seen, fn, ...)
        running = outer
        if not ok then mod.reads = nil elseif mod.reads then Note(mod, seen) end
    end
end

-- named: keys a caller changed.
local function Stale(mod, named)
    local reads = mod.reads
    if not reads then return true end
    for key, was in pairs(reads) do
        if named[key] then return true end
        local value = ns.db[key]
        if value == nil then value = NIL_READ end
        if value ~= was then return true end
    end
    return false
end

-- A pass asked for in combat runs when it ends; a module that touches nothing protected (inFight) runs now as well.
local applyAfterCombat = false
local function Pass(named)
    if not ns.db or not ns.ready then return end
    local fight = InCombatLockdown()
    if fight then applyAfterCombat = true end
    for _, mod in ipairs(ns.modules) do
        if (mod.inFight or not fight) and (not named or Stale(mod, named)) then RunModule(mod) end
    end
end

function ns.ApplyAll() Pass(nil) end

function ns.ApplyChanged(keys)
    local named = {}
    for i = 1, #keys do named[keys[i]] = true end
    Pass(named)
end

-- Told of every changed setting, even one whose pass waits for a fight's end.
local toggleWatchers = {}
function ns.OnToggle(fn)
    if type(fn) == "function" then toggleWatchers[#toggleWatchers + 1] = fn end
end

-- A radio row turned on turns the rest of its group off; the last one on stays on.
local function PickRadio(key)
    local group = ns.TOGGLE_RADIO[key]
    if not group then return end
    local db = ns.db
    if db[key] ~= true then
        for i = 1, #group do
            if db[group[i]] == true then return end
        end
        db[key] = true
        return
    end
    for i = 1, #group do
        if group[i] ~= key then db[group[i]] = false end
    end
end

-- Settings changed at once: one pass, then the watchers.
function ns.TogglesChanged(changed)
    ns.ApplyChanged(changed)
    for i = 1, #changed do
        for j = 1, #toggleWatchers do ns.SafeCall(toggleWatchers[j], changed[i]) end
    end
end

function ns.ToggleChanged(key)
    PickRadio(key)
    ns.TogglesChanged({ key })
end

-- Edit mode is watched, never hooked: its active flag flips only in the manager's OnShow/OnHide, answered a frame after.
local editWatchers = {}
local editWatched, editState
local function EditModeEdge()
    local open = ns.EditMode.Live()
    if open == editState then return end
    editState = open
    ns.EditMode.state = open
    for _, watcher in ipairs(editWatchers) do ns.SafeCall(watcher) end
end
local function QueueEditEdge()
    ns.Sched.NextFrame("core.editMode", EditModeEdge)
end
local function WatchEditMode()
    if editWatched then return end
    local mgr = EditModeManagerFrame
    if not mgr then
        ns.EventFrame("ADDON_LOADED", function(self)
            if not EditModeManagerFrame then return end
            self:UnregisterAllEvents()
            WatchEditMode()
        end)
        return
    end
    editWatched = true
    -- Under its Border (out of the manager's layout): the manager counts its children.
    ns.Sched.OnVisible(mgr.Border or mgr, "core.editMode", QueueEditEdge)
    QueueEditEdge()
end
function ns.OnEditMode(fn)
    if type(fn) ~= "function" then return false end
    editWatchers[#editWatchers + 1] = fn
    if editState == nil then
        editState = ns.EditMode.Live()
        ns.EditMode.state = editState
        WatchEditMode()
    end
    return true
end

-- A first login: where the settings are, and the look pick.
local function FirstRun()
    if ns.db.welcomed then return end
    ns.db.welcomed = true
    ns.Print(L["PICKER_INTRO"]:format(ns.SLASH))
    ns.ShowLookPick()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UI_SCALE_CHANGED")
frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_REGEN_ENABLED" then
        if applyAfterCombat then
            applyAfterCombat = false
            ns.ApplyAll()
        end
        return
    end
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        FallensUIColorPickerDB = FallensUIColorPickerDB or {}
        ns.db = FallensUIColorPickerDB
        -- Saved by the build made from ClassicUI Forever (its dbVersion, past ours): it switched every setting outside
        -- the theme off, the minimap button too. The theme's picks stay; the rest starts at our defaults.
        if (tonumber(ns.db.dbVersion) or 0) > ns.DB_VERSION then
            for key in pairs(ns.db) do
                if ns.DB_DEFAULTS[key] == nil or key == "minimapButton" then ns.db[key] = nil end
            end
        end
        ns.CopyDefaults(ns.db, ns.DB_DEFAULTS)
        ns.db.dbVersion = ns.DB_VERSION
    elseif event == "PLAYER_LOGIN" then
        ns.ready = true
        OrderModules()
        for _, mod in ipairs(ns.modules) do
            if mod.init then ns.SafeCall(mod.init) end
        end
        ns.ApplyAll()
        ns.OnEditMode(function() ns.QueueApply() end)
    else
        ns.QueueApply()
        if event == "PLAYER_ENTERING_WORLD" and not ns.firstChecked then
            ns.firstChecked = true
            C_Timer.After(3, FirstRun)
        end
    end
end)

function FallensUIColorPicker_OnAddonCompartmentClick()
    ns.OpenOptions()
end
