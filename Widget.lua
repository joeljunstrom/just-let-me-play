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
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  frame:SetBackdropColor(0.06, 0.06, 0.09, 0.9)
  frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 0.9)

  frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.count:SetPoint("TOP", 0, -6)
  frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.label:SetPoint("BOTTOM", 0, 7)

  frame.glow = frame:CreateTexture(nil, "BACKGROUND")
  frame.glow:SetPoint("TOPLEFT", 1, -1)
  frame.glow:SetPoint("BOTTOMRIGHT", -1, 1)
  frame.glow:SetColorTexture(0.2, 0.8, 0.3, 0.15)
  frame.glow:Hide()

  frame:SetScript("OnMouseDown", function(f) f.count:SetPoint("TOP", 1, -7) end)
  frame:SetScript("OnMouseUp", function(f) f.count:SetPoint("TOP", 0, -6) end)

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
  self:Refresh()
end

function Widget:SetGlow(show)
  if show then
    frame.glow:Show()
    frame:SetBackdropBorderColor(0.3, 0.75, 0.35, 1)
  else
    frame.pulse:Stop()
    frame.glow:Hide()
    frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 0.9)
  end
end

function Widget:Pulse()
  if frame and frame.glow:IsShown() and not frame.pulse:IsPlaying() then
    frame.pulse:Play()
  end
end

function Widget:Refresh()
  if not frame then return end
  local active = math.min(ns.MAX_APPLICATIONS,
    ns.Core:ActiveApplicationCount() + ns.Core:PendingApplyCount())

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
  frame:Show()
  frame.count:SetText(("%d/%d"):format(active, ns.MAX_APPLICATIONS))

  if active >= ns.MAX_APPLICATIONS then
    frame.count:SetTextColor(0.4, 0.9, 0.45)
  elseif active > 0 then
    frame.count:SetTextColor(1, 0.85, 0.3)
  else
    frame.count:SetTextColor(0.9, 0.9, 0.9)
  end

  local free = ns.MAX_APPLICATIONS - active
  if ns.pendingSearch then
    frame.label:SetText("Searching...")
    frame.label:SetTextColor(0.6, 0.6, 0.6)
    self:SetGlow(false)
  elseif ns.state == "SEARCHED" and #ns.results > 0 and free > 0 then
    frame.label:SetText(("Apply (%d)"):format(math.min(free, #ns.results)))
    frame.label:SetTextColor(0.4, 0.9, 0.45)
    self:SetGlow(true)
  elseif free > 0 and ns.Search:HasSearchContext() then
    frame.label:SetText("Search")
    frame.label:SetTextColor(1, 0.85, 0.3)
    self:SetGlow(true)
  elseif free > 0 then
    frame.label:SetText("Set search")
    frame.label:SetTextColor(0.6, 0.6, 0.6)
    self:SetGlow(false)
  else
    frame.label:SetText("Queued")
    frame.label:SetTextColor(0.55, 0.55, 0.6)
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
  GameTooltip:AddLine("Left-click: one action (apply next / search)", 0.5, 0.5, 0.5)
  GameTooltip:AddLine("Shift-click: leave oldest application", 0.5, 0.5, 0.5)
  GameTooltip:AddLine("Right-click: options. Drag to move.", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end
