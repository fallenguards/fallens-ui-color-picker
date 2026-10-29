if select(2, ...).INERT then return end
local _, ns = ...

-- Saved settings' layout version: a change to what a saved setting means gets a migration in Core.lua and a bump here.
ns.DB_VERSION = 1

ns.DB_DEFAULTS = {
    bronzeTheme = false,
    themeBronze = true,
    themeDark = false,
    themeCustom = false,
    themeColor = "e69e52",
    themeDarkness = 50,
    themePaneShade = 50,
    themeTextured = false,
    texturedBars = true, texturedCharacter = true, texturedSpellbook = true, texturedWindows = true,
    themePartParchment = true, themePartUnits = true, themePartMinimap = true, themePartBars = true, themePartBags = true,
    themePartTooltips = true, themePartChat = true, themePartWindows = true, themePartCastBars = true,
    themePartNameplates = true, themePartMicroMenu = true, themePartBagBar = true, themePartXPBars = true,
    themePartMenus = true, themePartQuestTracker = true, themePartBagIcons = false, themePartAddons = false,
    themeIgnoreElite = false,
    themeIgnoreElitePlayer = true, themeIgnoreEliteTarget = true, themeIgnoreEliteFocus = true,
    themeIgnorePlateDragon = false,
    minimapButton = true,
    minimapButtonAngle = 213,
}

-- The minimap button first, the theme's repaint, then the walk over the game's art.
ns.MODULE_ORDER = { "minimapButton", "bronzeTheme", "gameArt" }
