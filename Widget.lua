local _, ns = ...

local Widget = {}
ns.Widget = Widget

Widget.DEFAULT_BG = { 0.06, 0.06, 0.09, 0.9 }
Widget.DEFAULT_BORDER = { 0.35, 0.35, 0.4, 0.9 }
Widget.DEFAULT_WIDTH = 72
Widget.DEFAULT_COUNT_SIZE = 16

local GLOW_BORDER = { 0.3, 0.75, 0.35, 1 }
local GLOW_FILL = { 0.2, 0.8, 0.3, 0.15 }
local CIRCLE = "Interface\\AddOns\\JustLetMePlay\\Textures\\circle.png"
local FLAT = "Interface\\Buttons\\WHITE8x8"

local frame
local editMode = false

local function savePosition()
  local point, _, _, x, y = frame:GetPoint()
  ns.db.widgetPos = { point = point, x = x, y = y }
end

local function restorePosition()
  frame:ClearAllPoints()
  local pos = ns.db.widgetPos
  if pos then
    frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
  else
    frame:SetPoint("CENTER")
  end
end

-- Rounded rectangle built from parts: four quarter-circle corners cut out of
-- one anti-aliased circle texture plus three flat fill rects. The in-game
-- 9-slice API stretched the whole circle instead of slicing it, so the
-- geometry is laid out by hand.
local CORNER_COORDS = {
  TOPLEFT = { 0, 0.5, 0, 0.5 },
  TOPRIGHT = { 0.5, 1, 0, 0.5 },
  BOTTOMLEFT = { 0, 0.5, 0.5, 1 },
  BOTTOMRIGHT = { 0.5, 1, 0.5, 1 },
}

local function createShape(parent, inset)
  local shape = { inset = inset, textures = {} }

  shape.corners = {}
  for point, coords in pairs(CORNER_COORDS) do
    local tex = parent:CreateTexture(nil, "BACKGROUND")
    tex:SetTexture(CIRCLE)
    tex:SetTexCoord(unpack(coords))
    shape.corners[point] = tex
    shape.textures[#shape.textures + 1] = tex
  end
  shape.center = parent:CreateTexture(nil, "BACKGROUND")
  shape.left = parent:CreateTexture(nil, "BACKGROUND")
  shape.right = parent:CreateTexture(nil, "BACKGROUND")
  for _, band in ipairs({ shape.center, shape.left, shape.right }) do
    band:SetTexture(FLAT)
    shape.textures[#shape.textures + 1] = band
  end

  function shape:SetRadius(radius)
    local n = self.inset
    local parentFrame = self.center:GetParent()
    self.center:ClearAllPoints()
    if radius <= 0 then
      for _, point in pairs(self.corners) do point:Hide() end
      self.left:Hide()
      self.right:Hide()
      self.center:SetPoint("TOPLEFT", n, -n)
      self.center:SetPoint("BOTTOMRIGHT", -n, n)
      return
    end
    for point, tex in pairs(self.corners) do
      tex:Show()
      tex:SetSize(radius, radius)
      tex:ClearAllPoints()
      local xSign = point:find("LEFT") and 1 or -1
      local ySign = point:find("TOP") and -1 or 1
      tex:SetPoint(point, xSign * n, ySign * n)
    end
    self.center:SetPoint("TOPLEFT", n + radius, -n)
    self.center:SetPoint("BOTTOMRIGHT", -n - radius, n)
    self.left:Show()
    self.left:ClearAllPoints()
    self.left:SetPoint("TOPLEFT", n, -n - radius)
    self.left:SetPoint("BOTTOMLEFT", n, n + radius)
    self.left:SetWidth(radius)
    self.right:Show()
    self.right:ClearAllPoints()
    self.right:SetPoint("TOPRIGHT", -n, -n - radius)
    self.right:SetPoint("BOTTOMRIGHT", -n, n + radius)
    self.right:SetWidth(radius)
  end

  function shape:SetColor(r, g, b, a)
    for _, tex in ipairs(self.textures) do
      tex:SetVertexColor(r, g, b, a)
    end
  end

  return shape
end

function Widget:Init()
  frame = CreateFrame("Button", "JustLetMePlayWidget", UIParent)
  frame:SetFrameStrata("MEDIUM")
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  frame.borderShape = createShape(frame, 0)
  frame.bgShape = createShape(frame, 1)

  -- Glow and text live on stacked child frames so the glow can pulse via a
  -- frame-alpha animation and still render underneath the text.
  local glowHolder = CreateFrame("Frame", nil, frame)
  glowHolder:SetAllPoints()
  glowHolder:Hide()
  frame.glowHolder = glowHolder
  frame.glowShape = createShape(glowHolder, 1)
  frame.glowShape:SetColor(unpack(GLOW_FILL))

  local textHolder = CreateFrame("Frame", nil, frame)
  textHolder:SetAllPoints()
  textHolder:SetFrameLevel(glowHolder:GetFrameLevel() + 1)
  frame.count = textHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.label = textHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.fontPath = frame.count:GetFont()

  frame:SetScript("OnMouseDown", function(f)
    f.count:SetPoint("BOTTOM", f, "CENTER", 1, f.textGap - 1)
  end)
  frame:SetScript("OnMouseUp", function(f)
    f.count:SetPoint("BOTTOM", f, "CENTER", 0, f.textGap)
  end)

  frame.pulse = glowHolder:CreateAnimationGroup()
  frame.pulse:SetLooping("BOUNCE")
  local alpha = frame.pulse:CreateAnimation("Alpha")
  alpha:SetFromAlpha(0.3)
  alpha:SetToAlpha(1)
  alpha:SetDuration(0.8)

  frame.grip = CreateFrame("Button", nil, frame)
  frame.grip:SetSize(16, 16)
  frame.grip:SetPoint("BOTTOMRIGHT", -1, 1)
  frame.grip:SetFrameLevel(textHolder:GetFrameLevel() + 1)
  frame.grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  frame.grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  frame.grip:Hide()
  frame.grip:SetScript("OnMouseDown", function()
    frame:StartSizing("BOTTOMRIGHT")
  end)
  frame.grip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    ns.db.skin.width = math.floor(frame:GetWidth() + 0.5)
    ns.db.skin.height = math.floor(frame:GetHeight() + 0.5)
    savePosition()
    Widget:ApplySkin()
    ns.Options:RefreshControls()
  end)

  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    savePosition()
  end)
  frame:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      ns.Config:OpenMenu(frame)
    elseif IsShiftKeyDown() then
      ns.Core:OnUnsignAction()
    else
      ns.Core:OnHardwareAction()
    end
  end)
  frame:SetScript("OnEnter", function(f)
    Widget:ShowTooltip(f)
  end)
  frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local panel = LFGListFrame and LFGListFrame.SearchPanel
  if panel then
    panel:HookScript("OnShow", function() Widget:Refresh() end)
    panel:HookScript("OnHide", function() Widget:Refresh() end)
    if panel.SearchBox then
      panel.SearchBox:HookScript("OnTextChanged", function() Widget:Refresh() end)
    end
  end

  restorePosition()
  self:ApplySkin()
end

function Widget:GetBoxSize()
  if not frame then return Widget.DEFAULT_WIDTH, 40 end
  return math.floor(frame:GetWidth() + 0.5), math.floor(frame:GetHeight() + 0.5)
end

function Widget:ApplySkin()
  if not frame then return end
  local skin = ns.db.skin
  local countSize = skin.fontSize or Widget.DEFAULT_COUNT_SIZE
  local labelSize = math.max(6, countSize - 6)
  frame.count:SetFont(frame.fontPath, countSize, "")
  frame.label:SetFont(frame.fontPath, labelSize, "")

  -- Text hugs the middle: count above center, label below, with a gap that
  -- grows with the font.
  local gap = math.max(2, math.floor(countSize / 5))
  frame.textGap = gap / 2
  frame.count:ClearAllPoints()
  frame.count:SetPoint("BOTTOM", frame, "CENTER", 0, frame.textGap)
  frame.label:ClearAllPoints()
  frame.label:SetPoint("TOP", frame, "CENTER", 0, -frame.textGap)

  -- Box follows the fonts unless the user set an explicit size (grip drag or
  -- the size sliders). No SetScale: the widget follows WoW's own UI scale.
  local width = skin.width or math.max(Widget.DEFAULT_WIDTH, countSize * 4.5)
  local height = skin.height or (countSize + labelSize + gap + 14)
  frame:SetSize(width, height)
  frame:SetResizeBounds(24, 24, 400, 400)

  -- Radius is a percentage of the short side: 50% is a pill, and a circle
  -- on a square box, whatever the size.
  local pct = math.min(skin.radius or 0, 50)
  local radius = math.floor(math.min(width, height) * pct / 100 + 0.5)
  frame.borderShape:SetRadius(radius)
  frame.bgShape:SetRadius(math.max(0, radius - 1))
  frame.glowShape:SetRadius(math.max(0, radius - 1))

  local bg = skin.bg or Widget.DEFAULT_BG
  frame.bgShape:SetColor(bg[1], bg[2], bg[3], bg[4])

  self:SetGlow(frame.glowHolder:IsShown())
  self:Refresh()
end

-- While the options window is open the widget stays visible and shows its
-- resize grip, whatever the search state.
function Widget:SetEditMode(on)
  editMode = on
  if frame then
    frame.grip:SetShown(on)
    self:Refresh()
  end
end

function Widget:SetGlow(show)
  if show then
    frame.glowHolder:Show()
    frame.borderShape:SetColor(unpack(GLOW_BORDER))
  else
    frame.pulse:Stop()
    frame.glowHolder:Hide()
    local border = ns.db.skin.border or Widget.DEFAULT_BORDER
    frame.borderShape:SetColor(border[1], border[2], border[3], border[4])
  end
end

function Widget:Pulse()
  if frame and frame.glowHolder:IsShown() and not frame.pulse:IsPlaying() then
    frame.pulse:Play()
  end
end

local function textColor(r, g, b)
  local c = ns.db.skin.text
  if c then
    return c[1], c[2], c[3]
  end
  return r, g, b
end

function Widget:Refresh()
  if not frame then return end
  local active = math.min(ns.MAX_APPLICATIONS,
    ns.Core:ActiveApplicationCount() + ns.Core:PendingApplyCount())

  if not editMode then
    -- Get out of the way once the player has joined a group; alwaysShow wins.
    if ns.joinedGroup and not ns.db.alwaysShow then
      frame:Hide()
      return
    end

    -- Stay hidden until there is something meaningful to search for; keep
    -- showing while applications or scored results are still live.
    if not ns.db.alwaysShow and not ns.Search:HasSearchContext()
      and active == 0 and #ns.results == 0 then
      frame:Hide()
      return
    end
  end
  frame:Show()
  -- Denominator is what this search can actually reach: applications out plus
  -- results left to apply to, capped at the server's 5. "3/3" after a search
  -- that found three groups, not a forever-unreachable "3/5".
  local reachable = math.min(ns.MAX_APPLICATIONS, active + #ns.results)
  if reachable == 0 then
    reachable = ns.MAX_APPLICATIONS
  end
  frame.count:SetText(("%d/%d"):format(active, reachable))

  if active >= reachable then
    frame.count:SetTextColor(textColor(0.4, 0.9, 0.45))
  elseif active > 0 then
    frame.count:SetTextColor(textColor(1, 0.85, 0.3))
  else
    frame.count:SetTextColor(textColor(0.9, 0.9, 0.9))
  end

  local free = ns.MAX_APPLICATIONS - active
  if ns.pendingSearch then
    frame.label:SetText("Searching...")
    frame.label:SetTextColor(textColor(0.6, 0.6, 0.6))
    self:SetGlow(false)
  elseif ns.state == "SEARCHED" and #ns.results > 0 and free > 0 then
    frame.label:SetText(("Apply (%d)"):format(math.min(free, #ns.results)))
    frame.label:SetTextColor(textColor(0.4, 0.9, 0.45))
    self:SetGlow(true)
  elseif free > 0 and ns.Search:HasSearchContext() then
    frame.label:SetText("Search")
    frame.label:SetTextColor(textColor(1, 0.85, 0.3))
    self:SetGlow(false)
  elseif free > 0 then
    frame.label:SetText("Set search")
    frame.label:SetTextColor(textColor(0.6, 0.6, 0.6))
    self:SetGlow(false)
  else
    frame.label:SetText("Queued")
    frame.label:SetTextColor(textColor(0.55, 0.55, 0.6))
    self:SetGlow(false)
  end
end

function Widget:Flash(text)
  if not frame then return end
  frame.label:SetText(text)
  frame.label:SetTextColor(0.95, 0.35, 0.3)
  C_Timer.After(3, function()
    Widget:Refresh()
  end)
end

function Widget:ShowTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_BOTTOMLEFT")
  GameTooltip:AddLine("JustLetMePlay")

  local shown = 0
  for _, id in ipairs(C_LFGList.GetApplications()) do
    local _, appStatus, _, appDuration = C_LFGList.GetApplicationInfo(id)
    if appStatus == "applied" or appStatus == "invited" then
      local info = C_LFGList.GetSearchResultInfo(id)
      local name = info and (ns.Search:ActivityName(info) or info.name) or "Unknown group"
      local timeLeft = appDuration and SecondsToTime(appDuration) or "?"
      GameTooltip:AddDoubleLine(name, timeLeft, 1, 1, 1, 0.7, 0.7, 0.7)
      shown = shown + 1
    end
  end
  if shown == 0 then
    GameTooltip:AddLine("No active applications", 0.6, 0.6, 0.6)
  end

  if #ns.results > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Next picks", 0.4, 0.8, 1)
    for i = 1, math.min(5, #ns.results) do
      local id = ns.results[i]
      local pick = ns.resultInfo[id]
      if pick then
        local detail = ("%ds old"):format(pick.age)
        if pick.bestRunLevel then
          detail = detail .. (", best +%d"):format(pick.bestRunLevel)
        end
        if not pick.needsMyRole then
          detail = detail .. ", role full?"
        end
        GameTooltip:AddDoubleLine(pick.name or "?", detail, 1, 1, 1, 0.7, 0.7, 0.7)
      end
    end
  end

  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Left-click: one action (apply next / search)", 0.5, 0.5, 0.5)
  GameTooltip:AddLine("Shift-click: leave oldest application", 0.5, 0.5, 0.5)
  GameTooltip:AddLine("Right-click: options. Drag to move.", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end
