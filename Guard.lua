local _, ns = ...

-- ClassicUI Forever (the full addon) carries this theme itself: with it enabled the picker stands down, every other
-- file of ours returning at its first line, and says so once at login. Its standalone pieces run beside the picker.
-- Asked for this character: with no name the game answers for all of them, and one enabled elsewhere would count.
if C_AddOns.GetAddOnEnableState("ClassicUIForever", (UnitName("player"))) > 0 then
    ns.INERT = true
    StaticPopupDialogs.FALLENSUICOLORPICKER_STANDS_DOWN = {
        text = ns.L["PICKER_STANDS_DOWN"],
        button1 = OKAY or "Okay",
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    local notice = CreateFrame("Frame")
    notice:RegisterEvent("PLAYER_ENTERING_WORLD")
    notice:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        StaticPopup_Show("FALLENSUICOLORPICKER_STANDS_DOWN")
    end)
    -- The addon list's compartment entry still calls this.
    function FallensUIColorPicker_OnAddonCompartmentClick()
        StaticPopup_Show("FALLENSUICOLORPICKER_STANDS_DOWN")
    end
end
