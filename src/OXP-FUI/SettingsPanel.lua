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
    local c = desc.lit and theme.C.BOX_LIT or theme.C.BOX
    if desc.isOn then
      btn.dot:SetColorTexture(c[1], c[2], c[3], 1)
      btn.dot:Show()
    else
      btn.dot:Hide()
    end
    btn.border:SetColorTexture(c[1], c[2], c[3], 1)
  end

  btn:SetScript("OnEnter", function() getDescription().hover = true; paint() end)
  btn:SetScript("OnLeave", function() getDescription().hover = false; paint() end)
  btn.paint = paint
  paint()
  return btn
end

local function label(parent, text, kind, colorName)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  -- Font before text: a fresh font string has no font, and the client
  -- raises "FontString:SetText(): Font not set" if SetText runs first.
  theme.ApplyText(fs, kind or "body", colorName or "OBJECTIVE")
  fs:SetText(text)
  return fs
end

-- A settings cycle button (font choice, border style): dark plate with a
-- centred bronze label. Size, anchor and OnClick are the caller's.
local function makeCycleButton(parent)
  local btn = CreateFrame("Button", nil, parent)
  btn.tex = btn:CreateTexture(nil, "BACKGROUND")
  btn.tex:SetAllPoints(btn)
  btn.tex:SetColorTexture(0, 0, 0, 0.5)
  btn.text = btn:CreateFontString(nil, "OVERLAY")
  btn.text:SetAllPoints(btn)
  btn.text:SetJustifyH("CENTER")
  theme.ApplyText(btn.text, "body", "ZONE")
  return btn
end

local ROW = 22

local function buildPanel()
  local db = OXPFUI.db

  -- BackdropTemplate: theme.ApplyBackdrop needs the frame's SetBackdrop
  -- (a plain frame has none on this client family).
  local f = CreateFrame("Frame", "OXPFUIPanel", UIParent, "BackdropTemplate")
  f:SetSize(340, 500)
  f:SetPoint("CENTER", UIParent, "CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  theme.ApplyBackdrop(f)

  -- Hidden until the build completes (OpenPanel shows it): a mid-build
  -- error must never leave a shown, empty, closeless panel on screen.
  -- Escape closes the panel too, via the client's UISpecialFrames list.
  f:Hide()
  tinsert(UISpecialFrames, f:GetName())

  -- Header ---------------------------------------------------------------
  f.title = label(f, L.panelTitle, "header", "TITLE")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)

  f.subtitle = label(f, L.panelSubtitle, "body", "ZONE")
  f.subtitle:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)

  f.closeBtn = CreateFrame("Button", nil, f)
  f.closeBtn:SetSize(12, 12)
  f.closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
  f.closeBtn.tex = f.closeBtn:CreateTexture(nil, "OVERLAY")
  f.closeBtn.tex:SetAllPoints(f.closeBtn)
  f.closeBtn.tex:SetColorTexture(theme.C.BOX[1], theme.C.BOX[2], theme.C.BOX[3], 1)
  f.closeBtn.mark = label(f.closeBtn, "×")
  f.closeBtn.mark:SetAllPoints(f.closeBtn)
  f.closeBtn:SetScript("OnClick", function() f:Hide() end)

  -- Version note (only when installed != tested OpenXP) --------------------
  local mismatch = OXPFUI.VersionMismatch()
  if mismatch then
    f.versionNote = label(f, L.versionNote:format(mismatch, OXPFUI.testedOpenXP),
                          "body", "URGENT")
    f.versionNote:SetPoint("TOPLEFT", f.subtitle, "BOTTOMLEFT", 0, -4)
    -- Right edge pinned to the pane so an unusually long note wraps instead
    -- of overflowing (the text is sized to fit on one line normally).
    f.versionNote:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  end

  -- Master switch ---------------------------------------------------------
  local masterDesc = { isOn = db.enabled, hover = false }
  f.masterBtn = makeToggle(f, function() return masterDesc end)
  f.masterBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -58)
  f.masterBtn:SetScript("OnClick", function()
    db.enabled = not db.enabled
    masterDesc.isOn = db.enabled
    f.masterBtn.paint()
    OXPFUI.Reapply("settings changed")
    if OXPFUI.Dock and OXPFUI.Dock.Update then
      OXPFUI.Dock.Update("settings changed")
    end
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
  f.fontBtn = makeCycleButton(f)
  f.fontBtn:SetSize(160, 18)
  f.fontBtn:SetPoint("LEFT", f.fontLabel, "RIGHT", 10, 0)
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
  f.borderBtn = makeCycleButton(f)
  f.borderBtn:SetSize(160, 18)
  f.borderBtn:SetPoint("LEFT", f.borderLabel, "RIGHT", 10, 0)
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

  -- FlareUI Quest Tracker dock ----------------------------------------------
  -- Every control here acts immediately (no reload needed): Docking.lua
  -- re-anchors the card on each change.
  local function dockChanged()
    if OXPFUI.Dock and OXPFUI.Dock.Update then
      OXPFUI.Dock.Update("settings changed")
    end
  end

  f.trackerHeader = label(f, L.trackerHeader, "header", "ZONE")
  f.trackerHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -326)

  local attachDesc = { isOn = db.attachTracker ~= false, hover = false }
  f.attachBtn = makeToggle(f, function() return attachDesc end)
  f.attachBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -344)
  f.attachBtn:SetScript("OnClick", function()
    db.attachTracker = not (db.attachTracker ~= false)
    attachDesc.isOn = db.attachTracker ~= false
    f.attachBtn.paint()
    dockChanged()
  end)
  f.attachLabel = label(f, L.attachLabel, "body", "OBJECTIVE")
  f.attachLabel:SetPoint("LEFT", f.attachBtn, "RIGHT", 6, 0)

  f.attachSideLabel = label(f, L.attachSideLabel, "title", "TITLE")
  f.attachSideLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -370)
  f.attachSideBtn = makeCycleButton(f)
  f.attachSideBtn:SetSize(160, 18)
  f.attachSideBtn:SetPoint("LEFT", f.attachSideLabel, "RIGHT", 10, 0)
  f.attachSideBtn:SetScript("OnClick", function()
    db.attachSide = db.attachSide == "top" and "bottom" or "top"
    f.attachSideBtn.text:SetText(db.attachSide == "top" and L.sideTop or L.sideBottom)
    dockChanged()
  end)
  f.attachSideBtn.text:SetText(db.attachSide == "top" and L.sideTop or L.sideBottom)

  f.paddingLabel = label(f, L.attachPaddingLabel, "title", "TITLE")
  f.paddingLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -396)
  f.paddingSlider = CreateFrame("Slider", nil, f)
  f.paddingSlider:SetSize(100, 18)
  f.paddingSlider:SetPoint("LEFT", f.paddingLabel, "RIGHT", 10, 0)
  f.paddingSlider:SetMinMaxValues(0, 40)
  f.paddingSlider:SetValueStep(1)
  f.paddingSlider:SetValue(tonumber(db.attachPadding) or 8)
  f.paddingValue = label(f, L.attachPaddingValue:format(tonumber(db.attachPadding) or 8))
  f.paddingValue:SetPoint("LEFT", f.paddingSlider, "RIGHT", 8, 0)
  f.paddingSlider:SetScript("OnValueChanged", function(_, value)
    db.attachPadding = math.floor(value + 0.5)
    f.paddingValue:SetText(L.attachPaddingValue:format(db.attachPadding))
    dockChanged()
  end)

  local matchDesc = { isOn = db.matchTrackerWidth == true, hover = false }
  f.matchBtn = makeToggle(f, function() return matchDesc end)
  f.matchBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -424)
  f.matchBtn:SetScript("OnClick", function()
    db.matchTrackerWidth = not (db.matchTrackerWidth == true)
    matchDesc.isOn = db.matchTrackerWidth == true
    f.matchBtn.paint()
    dockChanged()
  end)
  f.matchLabel = label(f, L.matchWidthLabel, "body", "OBJECTIVE")
  f.matchLabel:SetPoint("LEFT", f.matchBtn, "RIGHT", 6, 0)

  -- Reload note --------------------------------------------------------------
  f.reloadNote = label(f, L.reloadNote, "body", "DIM")
  f.reloadNote:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
  -- Same wrap safety net as the version note: pinned right, grows upward.
  f.reloadNote:SetPoint("RIGHT", f, "RIGHT", -10, 0)

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
