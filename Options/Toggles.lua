if select(2, ...).INERT then return end
local _, ns = ...
local L = ns.L

-- Private table the Options files share.
local O = {}
ns.options = O
O.TITLE = ns.NAME

-- key, label, tooltip; parent: grayed while it is off; radio: one on; checks: a group of boxes laid out together;
-- hideIf: left out while true. Order is the settings window's.
ns.TOGGLES = {
    { "bronzeTheme", L["OPT_bronzeTheme"] },
    { "themeBronze", L["OPT_themeBronze"], nil, parent = "bronzeTheme", radio = "theme" },
    { "themeCustom", L["OPT_themeCustom"], nil, parent = "bronzeTheme", radio = "theme" },
    { "themeDark", L["OPT_themeDark"], nil, parent = "bronzeTheme", radio = "theme" },
    { "themeTextured", L["OPT_themeTextured"], L["OPT_themeTextured_TIP"], parent = "bronzeTheme" },
    { "texturedBars", L["OPT_texturedBars"], nil, parent = "themeTextured", checks = "texturedParts" },
    { "texturedCharacter", L["OPT_texturedCharacter"], nil, parent = "themeTextured", checks = "texturedParts" },
    { "texturedSpellbook", L["OPT_texturedSpellbook"], nil, parent = "themeTextured", checks = "texturedParts" },
    { "texturedWindows", L["OPT_texturedWindows"], nil, parent = "themeTextured", checks = "texturedParts" },
    { "themePartParchment", L["OPT_themePartParchment"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartUnits", L["OPT_themePartUnits"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartCastBars", L["OPT_themePartCastBars"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartNameplates", L["OPT_themePartNameplates"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartMinimap", L["OPT_themePartMinimap"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartBars", L["OPT_themePartBars"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartMicroMenu", L["OPT_themePartMicroMenu"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartBagBar", L["OPT_themePartBagBar"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartBagIcons", L["OPT_themePartBagIcons"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartXPBars", L["OPT_themePartXPBars"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartBags", L["OPT_themePartBags"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartTooltips", L["OPT_themePartTooltips"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartMenus", L["OPT_themePartMenus"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartChat", L["OPT_themePartChat"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartQuestTracker", L["OPT_themePartQuestTracker"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartWindows", L["OPT_themePartWindows"], nil, parent = "bronzeTheme", checks = "themeParts" },
    { "themePartAddons", L["OPT_themePartAddons"], L["OPT_themePartAddons_TIP"], parent = "bronzeTheme",
        checks = "themeParts" },
    { "themeIgnoreElite", L["OPT_themeIgnoreElite"], L["OPT_themeIgnoreElite_TIP"], parent = "bronzeTheme" },
    { "themeIgnoreElitePlayer", L["OPT_themeIgnoreElitePlayer"], L["OPT_themeIgnoreEliteFrames_TIP"],
        parent = "themeIgnoreElite", checks = "themeIgnoreEliteFrames" },
    { "themeIgnoreEliteTarget", L["OPT_themeIgnoreEliteTarget"], L["OPT_themeIgnoreEliteFrames_TIP"],
        parent = "themeIgnoreElite", checks = "themeIgnoreEliteFrames" },
    { "themeIgnoreEliteFocus", L["OPT_themeIgnoreEliteFocus"], L["OPT_themeIgnoreEliteFrames_TIP"],
        parent = "themeIgnoreElite", checks = "themeIgnoreEliteFrames" },
    { "themeIgnorePlateDragon", L["OPT_themeIgnorePlateDragon"], L["OPT_themeIgnorePlateDragon_TIP"],
        parent = "bronzeTheme" },
    { "minimapButton", L["PICKER_BUTTON"], L["PICKER_BUTTON_TIP"] },
}

-- Radio rows: key -> its group's keys (Core ToggleChanged keeps exactly one on).
ns.TOGGLE_RADIO = {}
do
    local groups = {}
    for _, entry in ipairs(ns.TOGGLES) do
        local name = entry.radio
        if name then
            local group = groups[name] or {}
            groups[name] = group
            group[#group + 1] = entry[1]
            ns.TOGGLE_RADIO[entry[1]] = group
        end
    end
end
