if select(2, ...).INERT then return end
local _, ns = ...
local L = ns.L

-- The settings' own controls: the custom color in the game's color picker, and the 0-100 sliders (Dark's darkness,
-- the background shade) in the game's slider with steppers.

local O = ns.options

local function PickColor(r, g, b)
    ns.Sched.NextFrame("options.themeColor", function() ns.SetThemeColor(r, g, b) end)
end

-- The game's color picker on the custom color; changed(): after each pick or undo.
function O.EditThemeColor(changed)
    local was = ns.db.themeColor
    local r, g, b = ns.HexColor(was)
    ColorPickerFrame:SetupColorPickerAndShow({
        r = r or 1, g = g or 1, b = b or 1,
        swatchFunc = function()
            PickColor(ColorPickerFrame:GetColorRGB())
            changed()
        end,
        -- The game's picker cancels on any click outside it: that click keeps the pick, Cancel and Escape undo it.
        cancelFunc = function()
            if IsMouseButtonDown() and not ColorPickerFrame:IsMouseOver() then return end
            PickColor(ns.HexColor(was))
            changed()
        end,
    })
end

local RESET_TIP = { text = L["OPTWIN_RESET_TO_DEFAULT"], r = 1, g = 1, b = 1 }

-- A 0-100 slider (spec: key, default, set, label, tip) with a button back to its default at its right.
local function ThemeSlider(parent, width, spec)
    local function Value() return tonumber(ns.db[spec.key]) or spec.default end
    local row = ns.NewFrame("Frame", nil, parent)
    row:SetSize(width, 32)
    local reset = ns.NewFrame("Button", nil, row, "UIPanelButtonTemplate")
    reset:SetSize(24, 24)
    reset:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    local icon = reset:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    icon:SetSize(14, 14)
    icon:SetPoint("CENTER", 0, 0)
    ns.AttachTip(reset, RESET_TIP)
    local ok, slider = pcall(CreateFrame, "Frame", nil, row, "MinimalSliderWithSteppersTemplate")
    if not (ok and slider and slider.Init) then slider = nil end
    local filling = false
    if slider then
        slider:SetSize(width - 34, 32)
        slider:SetPoint("LEFT", row, "LEFT", 2, 0)
        slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
            if filling or type(value) ~= "number" then return end
            row.shown = math.floor(value + 0.5)
            ns.Sched.NextFrame("options." .. spec.key, function() spec.set(row.shown) end)
        end, row)
        ns.AttachTip(slider, { text = spec.label, r = 1, g = 1, b = 1, lines = { { spec.tip, nil, nil, nil, true } } })
    end
    -- No refill while the player drags: only when the saved value or the enabled state moved under it.
    function row:Sync()
        if not slider or (self.shown == Value() and self.filledOn == self.on) then return end
        self.shown, self.filledOn = Value(), self.on
        filling = true
        slider:Init(self.shown, 0, 100, 20)
        filling = false
        slider:SetAlpha(self.on == false and 0.4 or 1)
        if slider.SetEnabled then slider:SetEnabled(self.on ~= false) end
    end
    function row:SetEnabled(on)
        self.on = on and true or false
        reset:SetEnabled(self.on)
        icon:SetDesaturated(not self.on)
        self:Sync()
    end
    reset:SetScript("OnClick", function()
        spec.set(spec.default)
        row.shown = nil
        row:Sync()
    end)
    return row
end

-- Dark's slider, light gray to black.
function O.DarknessRow(parent, width)
    return ThemeSlider(parent, width, { key = "themeDarkness", default = ns.DARKNESS_DEFAULT, set = ns.SetThemeDarkness,
        label = L["OPTWIN_DARKNESS"], tip = L["OPTWIN_DARKNESS_TIP"] })
end

-- Background shade: its name on a line of its own, the slider under it.
function O.PaneRow(parent, width)
    local label, tip = L["OPTWIN_BACKGROUND_SHADE"], L["OPTWIN_BACKGROUND_SHADE_TIP"]
    local head = ns.NewFrame("Frame", nil, parent)
    head:SetSize(width, 24)
    head:EnableMouse(true)
    local text = head:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", head, "LEFT", 4, 0)
    text:SetText(label)
    ns.AttachTip(head, { text = label, r = 1, g = 1, b = 1, lines = { { tip, nil, nil, nil, true } } })
    local row = ThemeSlider(parent, width, { key = "themePaneShade", default = ns.PANE_SHADE_DEFAULT,
        set = ns.SetThemePaneShade, label = label, tip = tip })
    return head, row
end
