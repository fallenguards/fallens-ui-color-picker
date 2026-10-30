local _, ns = ...

-- ClassicUI Forever (the full addon) carries this theme itself: with it enabled the picker stands down, every other
-- file of ours returning at its first line, and says so once ever (the compartment entry again on a click). Its
-- standalone pieces run beside the picker. Asked for this character by its GUID, as the game's AddOns list asks.
if C_AddOns.GetAddOnEnableState("ClassicUIForever", UnitGUID("player")) > 0 then
    ns.INERT = true
    local saved = FallensUIColorPickerDB or {}
    FallensUIColorPickerDB = saved
    StaticPopupDialogs.FALLENSUICOLORPICKER_STANDS_DOWN = {
        text = ns.L["PICKER_STANDS_DOWN"],
        button1 = OKAY or "Okay",
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    if not saved.standsDownSeen then
        local notice = CreateFrame("Frame")
        notice:RegisterEvent("PLAYER_ENTERING_WORLD")
        notice:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            saved.standsDownSeen = true
            StaticPopup_Show("FALLENSUICOLORPICKER_STANDS_DOWN")
        end)
    end
    -- The addon list's compartment entry still calls this.
    function FallensUIColorPicker_OnAddonCompartmentClick()
        StaticPopup_Show("FALLENSUICOLORPICKER_STANDS_DOWN")
    end
end
