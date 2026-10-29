if select(2, ...).INERT then return end
local _, ns = ...

-- The command and the game's AddOns list page.

ns.SLASH = "/fcp"
SLASH_FALLENSUICOLORPICKER1 = ns.SLASH
SLASH_FALLENSUICOLORPICKER2 = "/fallenscolorpicker"
SlashCmdList.FALLENSUICOLORPICKER = function(msg)
    if (msg or ""):lower():match("^%s*look") then ns.ShowLookPick() else ns.OpenOptions() end
end

local registered = false
ns.EventFrame("PLAYER_LOGIN", function(self)
    self:UnregisterAllEvents()
    if registered or not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    registered = true
    local category = Settings.RegisterCanvasLayoutCategory(ns.PickerCanvas(), ns.NAME)
    Settings.RegisterAddOnCategory(category)
end)
