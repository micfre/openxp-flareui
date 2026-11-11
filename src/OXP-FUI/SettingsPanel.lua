-- OXP-FUI · SettingsPanel: the /oxpfui panel, in the FlareUI look.
--
-- The panel is an OXP-FUI-owned frame (it never touches OpenXP frames):
-- FlareUI backdrop, gold Friz Quadrata title, procedural bronze square
-- buttons, one switch per window, font/border/opacity controls. Saves into
-- OXPFUIDB.

local ADDON_NAME, OXPFUI = ...

local L = OXPFUI.L
local theme = OXPFUI.theme

local panel -- built lazily on first open

local function applyFont(fs, kind, colorName)
  theme.ApplyFontString(fs, kind)
  theme.ApplyTextColor(fs, colorName)
end

-- Procedural bronze square toggle (FlareUI box button look, simplified):
-- bronze outline, dark fill, bronze inner square when on, lit on hover.
local function makeToggle(parent, getDescription)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(12, 12)
  btn.border = btn:CreateTexture(nil, "OVERLAY")
  btn.border:SetColorTexture(theme.C.BOX[1], theme.C.BOX[2], theme.C.BOX[3], 1)
  btn.border:SetAllPoints(btn)
  btn.fill = btn:CreateTexture(nil, "ARTWORK")
  btn.fill:SetColorTexture(0, 0, 0, 0.85)
  btn.fill:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
  btn.fill:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
  btn.dot = btn:CreateTexture(nil, "OVERLAY")
  btn.dot:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
  btn.dot:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)

  local function paint()
    local desc = getDescription()
    if desc.isOn then
      btn.dot:SetColorTexture(desc.lit and theme.C.BOX_LIT[1] or theme.C.BOX[1],
        desc.lit and theme.C.BOX_LIT[2] or theme.C.BOX[2],
        desc.lit and theme.C.BOX_LIT[3] or theme.C.BOX[3], 1)
      btn.dot:Show()
    else
      btn.dot:Hide()
    end
    btn.border:SetColorTexture(desc.lit and theme.C.BOX_LIT[1] or theme.C.BOX[1],
      desc.lit and theme.C.BOX_LIT[2] or theme.C.BOX[2],
      desc.lit and theme.C.BOX_LIT[3] or theme.C.BOX[3], 1)
  end

  btn:SetScript("OnEnter", function() getDescription().hover = true; paint() end)
  btn:SetScript("OnLeave", function() getDescription().hover = false; paint() end)
  btn.paint = paint
  paint()
  return btn
end

local function label(parent, text, kind, colorName)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetText(text)
  applyFont(fs, kind or "body", colorName or "OBJECTIVE")
  return fs
end

local ROW = 22

local function buildPanel()
  local db = OXPFUI.db

  local f = CreateFrame("Frame", "OXPFUIPanel", UIParent)
  f:SetSize(340, 470)
  f:SetPoint("CENTER", UIParent, "CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  theme.ApplyBackdrop(f)

  -- Header ---------------------------------------------------------------
  f.title = f:CreateFontString(nil, "OVERLAY")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
  f.title:SetText(L.panelTitle)
  applyFont(f.title, "header", "TITLE")

  f.subtitle = f:CreateFontString(nil, "OVERLAY")
  f.subtitle:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
  f.subtitle:SetText(L.panelSubtitle)
  applyFont(f.subtitle, "body", "ZONE")

  f.closeBtn = CreateFrame("Button", nil, f)
  f.closeBtn:SetSize(12, 12)
  f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
  f.closeBtn.tex = f.closeBtn:CreateTexture(nil, "OVERLAY")
  f.closeBtn.tex:SetAllPoints(f.closeBtn)
  f.closeBtn.tex:SetColorTexture(theme.C.BOX[1], theme.C.BOX[2], theme.C.BOX[3], 1)
  f.closeBtn.mark = f.closeBtn:CreateFontString(nil, "OVERLAY")
  f.closeBtn.mark:SetAllPoints(f.closeBtn)
  f.closeBtn.mark:SetText("×")
  applyFont(f.closeBtn.mark, "body", "OBJECTIVE")
  f.closeBtn:SetScript("OnClick", function() f:Hide() end)

  -- Version note (only when installed != tested OpenXP) --------------------
  local mismatch = OXPFUI.VersionMismatch()
  if mismatch then
    f.versionNote = f:CreateFontString(nil, "OVERLAY")
    f.versionNote:SetPoint("TOPLEFT", f.subtitle, "BOTTOMLEFT", 0, -4)
    f.versionNote:SetText(L.versionNote:format(mismatch, OXPFUI.testedOpenXP))
    applyFont(f.versionNote, "body", "URGENT")
  end

  -- Master switch ---------------------------------------------------------
  local masterDesc = { isOn = db.enabled, hover = false }
  f.masterBtn = makeToggle(f, function() return masterDesc end)
  f.masterBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -58)
  f.masterBtn:SetScript("OnClick", function()
    db.enabled = not db.enabled
    masterDesc.isOn = db.enabled
    f.masterBtn.paint()
  end)
  f.masterLabel = label(f, L.masterLabel, "title", "TITLE")
  f.masterLabel:SetPoint("LEFT", f.masterBtn, "RIGHT", 6, 0)

  -- Windows ---------------------------------------------------------------
  f.windowsHeader = label(f, L.windowsHeader, "header", "ZONE")
  f.windowsHeader:SetPoint("TOPLEFT", f.masterBtn, "BOTTOMLEFT", 0, -12)

  f.windowBtns = {}
  local COLS, startY = 2, -96
  local colWidth = 160
  for i, key in ipairs(OXPFUI.WINDOWS) do
    local col = (i - 1) % COLS
    local row = math.floor((i - 1) / COLS)
    local desc = { isOn = db.windows[key] ~= false, hover = false }
    local btn = makeToggle(f, function() return desc end)
    btn:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + col * colWidth, startY - row * ROW)
    btn:SetScript("OnClick", function()
      db.windows[key] = not (db.windows[key] ~= false)
      desc.isOn = db.windows[key] ~= false
      btn.paint()
      OXPFUI.Reapply("settings changed")
    end)
    local fs = label(f, L.windows[key], "body", "OBJECTIVE")
    fs:SetPoint("LEFT", btn, "RIGHT", 6, 0)
    f.windowBtns[key] = btn
  end

  -- Font choice (cycle button) ---------------------------------------------
  local function fontIndex()
    for i, entry in ipairs(theme.FONTS) do
      if entry.key == db.font then return i end
    end
    return 1
  end

  f.fontLabel = label(f, L.fontLabel, "title", "TITLE")
  f.fontLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -240)
  f.fontBtn = CreateFrame("Button", nil, f)
  f.fontBtn:SetSize(160, 18)
  f.fontBtn:SetPoint("LEFT", f.fontLabel, "RIGHT", 10, 0)
  f.fontBtn.tex = f.fontBtn:CreateTexture(nil, "BACKGROUND")
  f.fontBtn.tex:SetAllPoints(f.fontBtn)
  f.fontBtn.tex:SetColorTexture(0, 0, 0, 0.5)
  f.fontBtn.text = f.fontBtn:CreateFontString(nil, "OVERLAY")
  f.fontBtn.text:SetAllPoints(f.fontBtn)
  f.fontBtn.text:SetJustifyH("CENTER")
  applyFont(f.fontBtn.text, "body", "ZONE")
  f.fontBtn:SetScript("OnClick", function()
    db.font = theme.FONTS[fontIndex() % #theme.FONTS + 1].key
    f.fontBtn.text:SetText(db.font)
    OXPFUI.Reapply("settings changed")
  end)
  f.fontBtn.text:SetText(db.font)

  -- Border style (cycle button) --------------------------------------------
  local borderKeys = { "Frames", "Thick", "Thin" }
  f.borderLabel = label(f, L.borderLabel, "title", "TITLE")
  f.borderLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -266)
  f.borderBtn = CreateFrame("Button", nil, f)
  f.borderBtn:SetSize(160, 18)
  f.borderBtn:SetPoint("LEFT", f.borderLabel, "RIGHT", 10, 0)
  f.borderBtn.tex = f.borderBtn:CreateTexture(nil, "BACKGROUND")
  f.borderBtn.tex:SetAllPoints(f.borderBtn)
  f.borderBtn.tex:SetColorTexture(0, 0, 0, 0.5)
  f.borderBtn.text = f.borderBtn:CreateFontString(nil, "OVERLAY")
  f.borderBtn.text:SetAllPoints(f.borderBtn)
  f.borderBtn.text:SetJustifyH("CENTER")
  applyFont(f.borderBtn.text, "body", "ZONE")
  f.borderBtn:SetScript("OnClick", function()
    local current
    for i, k in ipairs(borderKeys) do
      if k == db.borderStyle then current = i end
    end
    db.borderStyle = borderKeys[(current or 1) % #borderKeys + 1]
    f.borderBtn.text:SetText(db.borderStyle)
    OXPFUI.Reapply("settings changed")
  end)
  f.borderBtn.text:SetText(db.borderStyle)

  -- Opacity slider ----------------------------------------------------------
  f.opacityLabel = label(f, L.opacityLabel, "title", "TITLE")
  f.opacityLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -294)
  f.opacitySlider = CreateFrame("Slider", nil, f)
  f.opacitySlider:SetSize(160, 18)
  f.opacitySlider:SetPoint("LEFT", f.opacityLabel, "RIGHT", 10, 0)
  f.opacitySlider:SetMinMaxValues(0, 1)
  f.opacitySlider:SetValueStep(0.05)
  f.opacitySlider:SetValue(db.opacity)
  f.opacityValue = label(f, L.opacityValue:format(math.floor(db.opacity * 100 + 0.5)))
  f.opacityValue:SetPoint("LEFT", f.opacitySlider, "RIGHT", 8, 0)
  f.opacitySlider:SetScript("OnValueChanged", function(_, value)
    db.opacity = math.floor(value * 20 + 0.5) / 20
    f.opacityValue:SetText(L.opacityValue:format(math.floor(db.opacity * 100 + 0.5)))
    OXPFUI.Reapply("settings changed")
  end)

  -- Reload note --------------------------------------------------------------
  f.reloadNote = f:CreateFontString(nil, "OVERLAY")
  f.reloadNote:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
  f.reloadNote:SetText(L.reloadNote)
  applyFont(f.reloadNote, "body", "DIM")

  f:Hide()
  return f
end

function OXPFUI.OpenPanel()
  if not panel then panel = buildPanel() end
  panel:Show()
  return panel
end

function OXPFUI.Panel() -- for tests and debugging
  return panel
end
