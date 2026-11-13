if select(2, ...).INERT then return end
local _, ns = ...

-- Our windows: dragging, sizing and tooltips.

-- StartMoving drops every anchor of a frame move watchers hang on: they let go for the drag.
local function DragStart(self)
    ns.Sched.LetGo(self, true)
    self:StartMoving()
end

-- StopMovingOrSizing leaves a frame others hang on with no anchor: read where it was drawn first and pin it there.
local function DragStop(self)
    local left, top = self:GetLeft(), self:GetTop()
    self:StopMovingOrSizing()
    if self:GetNumPoints() == 0 and left and top then
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
    ns.Sched.LetGo(self, false)
    local after = self.fcpDragStop
    if after then after(self) end
end

-- Our own frames only; onStop(frame) runs after the move ends.
function ns.MakeDraggable(frame, onStop)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame.fcpDragStop = onStop
    frame:SetScript("OnDragStart", DragStart)
    frame:SetScript("OnDragStop", DragStop)
    frame:SetClampedToScreen(true)
end

-- A size grip in a window's bottom right corner, the chat window's art; onStop(frame) runs after a resize. The window
-- is pinned by its top left first, so that corner stays put.
function ns.AddSizeGrip(frame, onStop)
    frame:SetResizable(true)
    local grip = ns.NewFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel(frame:GetFrameLevel() + 10)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local left, top = frame:GetLeft(), frame:GetTop()
        ns.Sched.LetGo(frame, true)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        DragStop(frame)
        onStop(frame)
    end)
    frame.fcpGrip = grip   -- read by the dev probe
    return grip
end

local function HideTip() GameTooltip:Hide() end
ns.HideTip = HideTip

-- fcpTip: { text or fn, r, g, b, anchor, when = fn, lines = { { text or fn, r, g, b, wrap } } }.
-- A nil text or false when shows nothing; a nil line is skipped.
local function ShowTip(self)
    local spec = self.fcpTip
    if not spec or (spec.when and not spec.when(self)) then return end
    local text = spec.text
    if type(text) == "function" then text = text(self) end
    if text == nil then return end
    GameTooltip:SetOwner(self, spec.anchor or "ANCHOR_RIGHT")
    if spec.r ~= nil then GameTooltip:SetText(text, spec.r, spec.g, spec.b) else GameTooltip:SetText(text) end
    local lines = spec.lines
    if lines then
        for i = 1, #lines do
            local line = lines[i]
            local lineText = line[1]
            if type(lineText) == "function" then lineText = lineText(self) end
            if lineText ~= nil then GameTooltip:AddLine(lineText, line[2], line[3], line[4], line[5]) end
        end
    end
    GameTooltip:Show()
end
ns.ShowTip = ShowTip

-- Our own widgets only: replaces OnEnter and OnLeave.
function ns.AttachTip(widget, spec)
    widget.fcpTip = spec
    widget:SetScript("OnEnter", ShowTip)
    widget:SetScript("OnLeave", HideTip)
end
