local _, ns = ...

local Widget = {}
ns.Widget = Widget

local frame

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

function Widget:Init()
  frame = CreateFrame("Button", "JustLetMePlayWidget", UIParent, "BackdropTemplate")
  frame:SetSize(72, 40)
  frame:SetFrameStrata("MEDIUM")
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(0, 0, 0, 0.7)

  frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.count:SetPoint("TOP", 0, -5)
  frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.label:SetPoint("BOTTOM", 0, 6)

  frame.glow = frame:CreateTexture(nil, "BACKGROUND")
  frame.glow:SetPoint("TOPLEFT", -4, 4)
  frame.glow:SetPoint("BOTTOMRIGHT", 4, -4)
  frame.glow:SetColorTexture(0.2, 0.8, 0.2, 0.35)
  frame.glow:Hide()

  frame.pulse = frame.glow:CreateAnimationGroup()
  frame.pulse:SetLooping("BOUNCE")
  local alpha = frame.pulse:CreateAnimation("Alpha")
  alpha:SetFromAlpha(0.3)
  alpha:SetToAlpha(1)
  alpha:SetDuration(0.8)

  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    savePosition()
  end)
  frame:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      ns.Config:OpenMenu(frame)
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

  restorePosition()
  self:Refresh()
end

function Widget:SetGlow(show)
  if show then
    frame.glow:Show()
  else
    frame.pulse:Stop()
    frame.glow:Hide()
  end
end

function Widget:Pulse()
  if frame and frame.glow:IsShown() and not frame.pulse:IsPlaying() then
    frame.pulse:Play()
  end
end

function Widget:Refresh()
  if not frame then return end
  local active = ns.Core:ActiveApplicationCount()
  frame.count:SetText(("%d/%d"):format(active, ns.MAX_APPLICATIONS))

  local free = ns.MAX_APPLICATIONS - active
  if ns.pendingSearch then
    frame.label:SetText("Searching...")
    self:SetGlow(false)
  elseif ns.state == "SEARCHED" and #ns.results > 0 and free > 0 then
    frame.label:SetText(("Apply %d"):format(math.min(free, #ns.results)))
    self:SetGlow(true)
  elseif free > 0 then
    frame.label:SetText("Search")
    self:SetGlow(true)
  else
    frame.label:SetText("")
    self:SetGlow(false)
  end
end

function Widget:Flash(text)
  if not frame then return end
  frame.label:SetText(text)
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
      local name = info and info.name or "Unknown group"
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
  GameTooltip:AddLine("Left-click: search / apply", 0.5, 0.5, 0.5)
  GameTooltip:AddLine("Right-click: options. Drag to move.", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end
