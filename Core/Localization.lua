local _, ns = ...

-- Localization: Locales/enUS.lua fills L first, then the client's language file overrides what it translates.
-- Keys are stable ids (OPT_<toggle key>, GROUP_<title>): wording edits never desync the translations.
-- A key no file sets returns itself, so a missing string shows in development instead of breaking.

-- Our text a player keeps in English on another client (Options: English text), by key prefix; the rest is windows and
-- edit mode. The saved settings are read before any code runs (TOC LoadSavedVariablesFirst), so a pick needs a reload.
local GROUP_OF = { OPT = "englishSettings", OPTWIN = "englishSettings", GROUP = "englishSettings", FAQ = "englishSettings",
    SUPPORT = "englishSettings", WN = "englishNews", WELCOME = "englishNews", CHAT = "englishMessages",
    CORE = "englishMessages" }
-- The settings' dropdown choices.
local SETTINGS_KEYS = { UI_HEALTH_GREEN = true, UI_FAILED_RED = true, UI_CAST_GOLD = true, UI_DARK_GOLD = true,
    UI_FOCUS_ORANGE = true, UI_ENERGY_YELLOW = true, UI_MANA_BLUE = true, UI_BY_REACTION = true, UI_BY_REACTION_TIP = true,
    UNIT_CHANNEL_GREEN = true, WIN_MARBLE = true }
local saved = FallensUIColorPickerDB
local english = {}   -- key -> the English text, the first one set
ns.savedFirst = type(saved) == "table"
-- Our text's language: the client's, or another one for a dev build to look at.
ns.LOCALE = ns.savedFirst and type(saved.devLocale) == "string" and saved.devLocale or GetLocale()
ns.ENGLISH_CLIENT = ns.LOCALE == "enUS" or ns.LOCALE == "enGB"

local function KeepEnglish(key)
    if type(saved) ~= "table" or type(key) ~= "string" then return false end
    return saved[SETTINGS_KEYS[key] and "englishSettings" or GROUP_OF[key:match("^%u+")] or "englishWindows"] == true
end

local store = setmetatable({}, { __index = function(_, key)
    if type(key) == "string" then return key end
    return ""
end })
local L = setmetatable({}, {
    __index = store,
    __newindex = function(_, key, text)
        if english[key] == nil then
            english[key] = text
        elseif KeepEnglish(key) then
            return
        end
        store[key] = text
    end,
})
ns.L = L
