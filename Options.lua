local _, ns = ...

local Options = {}
ns.Options = Options

local panel
local updating = false

local function pickColor(get, set, hasOpacity)
  local original = { get() }
  local function apply()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    set(r, g, b, ColorPickerFrame:GetColorAlpha())
  end
  ColorPickerFrame:SetupColorPickerAndShow({
    r = original[1], g = original[2], b = original[3],
    opacity = original[4],
    hasOpacity = hasOpacity,
    swatchFunc = apply,
    opacityFunc = hasOpacity and apply or nil,
    cancelFunc = function()
      set(unpack(original))
    end,
  })
end

local function makeSlider(label, minV, maxV, step, get, set)
  local holder = CreateFrame("Frame", nil, panel)
  holder:SetSize(240, 42)

  local title = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT")
  title:SetText(label)

  local value = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  value:SetPoint("TOPRIGHT")

  local slider = CreateFrame("Slider", nil, holder, "UISliderTemplate")
  slider:SetPoint("BOTTOMLEFT", 0, 4)
  slider:SetPoint("BOTTOMRIGHT", 0, 4)
  slider:SetHeight(16)
  slider:SetOrientation("HORIZONTAL")
  slider:SetMinMaxValues(minV, maxV)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  slider:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v / step + 0.5) * step
    value:SetText(tostring(v))
    if not updating then
      set(v)
    end
  end)

  holder.refresh = function()
    local v = get()
    slider:SetValue(v)
    value:SetText(tostring(v))
  end
  return holder
end

local function makeSwatch(label, get, set, hasOpacity)
  local holder = CreateFrame("Button", nil, panel)
  holder:SetSize(240, 24)

  local swatch = holder:CreateTexture(nil, "OVERLAY")
  swatch:SetSize(18, 18)
  swatch:SetPoint("LEFT", 1, 0)
  swatch:SetColorTexture(1, 1, 1)
  local ring = holder:CreateTexture(nil, "BORDER")
  ring:SetPoint("TOPLEFT", swatch, -1, 1)
  ring:SetPoint("BOTTOMRIGHT", swatch, 1, -1)
  ring:SetColorTexture(0.4, 0.4, 0.45)

  local title = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
  title:SetText(label)

  holder:SetScript("OnClick", function()
    pickColor(get, function(...)
      set(...)
      Options:RefreshControls()
      ns.Widget:ApplySkin()
    end, hasOpacity)
  end)

  holder.refresh = function()
    local r, g, b = get()
    swatch:SetVertexColor(r, g, b)
  end
  return holder
end

-- Built-in faces always exist; LibSharedMedia fonts are added when another
-- addon ships the library.
local function fontList()
  local fonts = {
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { name = "Morpheus", path = "Fonts\\MORPHEUS.ttf" },
    { name = "Skurri", path = "Fonts\\skurri.ttf" },
  }
  local lsm = LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true)
  if lsm then
    local seen = {}
    for _, font in ipairs(fonts) do
      seen[font.path] = true
    end
    for _, name in ipairs(lsm:List("font")) do
      local path = lsm:Fetch("font", name, true)
      if path and not seen[path] then
        seen[path] = true
        fonts[#fonts + 1] = { name = name, path = path }
      end
    end
    table.sort(fonts, function(a, b) return a.name < b.name end)
  end
  return fonts
end

local function makeFontRow()
  local holder = CreateFrame("Frame", nil, panel)
  holder:SetSize(240, 24)

  local title = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("LEFT")
  title:SetText("Font")

  local button = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
  button:SetSize(150, 22)
  button:SetPoint("RIGHT")

  local skin = ns.db.skin
  local function select(name, path)
    skin.font = path
    skin.fontName = name
    holder.refresh()
    ns.Widget:ApplySkin()
  end

  button:SetScript("OnClick", function()
    MenuUtil.CreateContextMenu(button, function(_, root)
      root:CreateRadio("Default (game font)", function()
        return skin.font == nil
      end, function()
        select(nil, nil)
      end)
      for _, font in ipairs(fontList()) do
        root:CreateRadio(font.name, function()
          return skin.font == font.path
        end, function()
          select(font.name, font.path)
        end)
      end
    end)
  end)

  holder.refresh = function()
    button:SetText(skin.font and (skin.fontName or "Custom") or "Default")
  end
  return holder
end

local controls = {}

local function build()
  panel = CreateFrame("Frame", "JustLetMePlayOptions", UIParent, "BackdropTemplate")
  panel:SetSize(280, 400)
  panel:SetPoint("CENTER", 200, 0)
  panel:SetFrameStrata("DIALOG")
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
  panel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  panel:SetBackdropColor(0.08, 0.08, 0.11, 0.95)
  panel:SetBackdropBorderColor(0.35, 0.35, 0.4, 0.9)
  tinsert(UISpecialFrames, "JustLetMePlayOptions")

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -14)
  title:SetText("JustLetMePlay")

  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)

  local skin = ns.db.skin
  local y = -48
  local function place(holder)
    holder:SetPoint("TOP", 0, y)
    y = y - holder:GetHeight() - 10
    controls[#controls + 1] = holder
  end

  place(makeSlider("Width", 24, 400, 2, function()
    return skin.width or (ns.Widget:GetBoxSize())
  end, function(v)
    skin.width = v
    ns.Widget:ApplySkin()
  end))

  place(makeSlider("Height", 24, 400, 2, function()
    local _, h = ns.Widget:GetBoxSize()
    return skin.height or h
  end, function(v)
    skin.height = v
    ns.Widget:ApplySkin()
  end))

  place(makeSlider("Font size", 8, 32, 1, function()
    return skin.fontSize or ns.Widget.DEFAULT_COUNT_SIZE
  end, function(v)
    skin.fontSize = v ~= ns.Widget.DEFAULT_COUNT_SIZE and v or nil
    ns.Widget:ApplySkin()
  end))

  place(makeSlider("Corner radius %", 0, 50, 1, function()
    return skin.radius or 0
  end, function(v)
    skin.radius = v > 0 and v or nil
    ns.Widget:ApplySkin()
  end))

  place(makeSwatch("Background", function()
    return unpack(skin.bg or ns.Widget.DEFAULT_BG)
  end, function(r, g, b, a)
    skin.bg = { r, g, b, a }
  end, true))

  place(makeSwatch("Border", function()
    return unpack(skin.border or ns.Widget.DEFAULT_BORDER)
  end, function(r, g, b, a)
    skin.border = { r, g, b, a }
  end, true))

  place(makeSwatch("Text", function()
    if skin.text then
      return unpack(skin.text)
    end
    return 0.9, 0.9, 0.9
  end, function(r, g, b)
    skin.text = { r, g, b }
  end, false))

  local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOP", 0, y)
  hint:SetWidth(240)
  hint:SetJustifyH("LEFT")
  hint:SetTextColor(0.6, 0.6, 0.6)
  hint:SetText("Drag the grip on the widget's corner to resize it while this window is open. 50% radius on a square box makes a circle. Text color off = state colors.")
  y = y - hint:GetStringHeight() - 14

  local resetText = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  resetText:SetSize(112, 22)
  resetText:SetPoint("TOP", -60, y)
  resetText:SetText("State text colors")
  resetText:SetScript("OnClick", function()
    skin.text = nil
    Options:RefreshControls()
    ns.Widget:ApplySkin()
  end)

  local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  reset:SetSize(112, 22)
  reset:SetPoint("TOP", 60, y)
  reset:SetText("Reset skin")
  reset:SetScript("OnClick", function()
    wipe(skin)
    Options:RefreshControls()
    ns.Widget:ApplySkin()
  end)

  panel:SetHeight(-y + 40)

  panel:SetScript("OnShow", function()
    Options:RefreshControls()
    ns.Widget:SetEditMode(true)
  end)
  panel:SetScript("OnHide", function()
    ns.Widget:SetEditMode(false)
  end)
end

function Options:RefreshControls()
  updating = true
  for _, holder in ipairs(controls) do
    holder.refresh()
  end
  updating = false
end

function Options:Toggle()
  if not panel then
    build()
    self:RefreshControls()
    ns.Widget:SetEditMode(true)
    return
  end
  panel:SetShown(not panel:IsShown())
end
