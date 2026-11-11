-- Fake OpenXP for the OXP-FUI skin seam (Seam 1).
--
-- Mirrors the global frame names and the addon-table surface that OXP-FUI
-- touches, per the research notes (OpenXP 1.3.48):
--   * frames use OpenXP's REAL global names, so skins resolve them via _G;
--   * refresh calls (RenderFrame, ReloadTheme, SetupArrow, card.Refresh,
--     card.SkinPanels, card.ApplyFonts, targeting:UpdateTargetFrame, ...)
--     exist as callable functions that first restyle a few frames to the
--     "OpenXP look" (flat charcoal backdrop, Arial Narrow, OUTLINE) — the
--     engine under test must win over them;
--   * HARNESS.calls counts invocations so tests can assert the original
--     still runs after OXP-FUI hooks it (hooksecure semantics).

local function N(name) return _G[name] end

HARNESS.calls = {}
local function bump(k)
  HARNESS.calls[k] = (HARNESS.calls[k] or 0) + 1
end

HARNESS.openxpVersion = HARNESS.openxpVersion or "1.3.48"

-- -------------------------------------------------------------------------
-- Frames
-- -------------------------------------------------------------------------

-- Guide card (phase 1) ------------------------------------------------------
-- Mirrors OpenXPCard.lua's frame tree and field names (OpenXP 1.3.48):
-- the card frame is global; every child is UNNAMED and only some of them
-- are reachable as fields on the shared addon table (card.frame, card.grip,
-- card.hist, card.blocksForTest, card.xpStrip). header/body/upNext/bar/mini
-- are locals over there, so skins must find them by walking the children.
local card = CreateFrame("Frame", "OpenXPCard", UIParent, "BackdropTemplate")

-- OpenXP's own card palette (OpenXPCard.lua local C).
local CARD_C = {
  bg = { 16 / 255, 17 / 255, 21 / 255, 0.9 },
  border = { 150 / 255, 160 / 255, 180 / 255, 0.35 },
  text = { 0.92, 0.93, 0.95 },
  dim = { 0.62, 0.64, 0.70 },
  faint = { 0.54, 0.56, 0.61 },
  blue = { 90 / 255, 184 / 255, 1 },
  gold = { 242 / 255, 195 / 255, 92 / 255 },
  orange = { 1, 112 / 255, 67 / 255 },
  cyan = { 38 / 255, 198 / 255, 218 / 255 },
  purple = { 179 / 255, 157 / 255, 219 / 255 },
  green = { 61 / 255, 187 / 255, 122 / 255 },
}
local CARD_TEX = "Interface\\AddOns\\OpenXP\\Textures\\Card\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Resize grip.
local grip = CreateFrame("Button", nil, card)
card.grip = grip

-- Header: dot, ZONE, level range, "Step 12 / 82" + its hit-area button.
local header = CreateFrame("Frame", nil, card)
header.dot = header:CreateTexture(nil, "ARTWORK")
header.dot:SetTexture(CARD_TEX .. "filledcircle")
header.zone = header:CreateFontString(nil, "OVERLAY")
header.range = header:CreateFontString(nil, "OVERLAY")
header.step = header:CreateFontString(nil, "OVERLAY")
header.stepBtn = CreateFrame("Button", nil, header)

-- Progress strip under the header.
local progressBg = card:CreateTexture(nil, "ARTWORK")
local progress = card:CreateTexture(nil, "OVERLAY")

-- Status pills ("DONE" / "SKIPPED" / "CHAIN MISSED") and their colors.
local STATUS = {
  done = { text = "DONE", color = CARD_C.green },
  skipped = { text = "SKIPPED", color = CARD_C.faint },
  chain = { text = "CHAIN MISSED", color = CARD_C.gold },
}
card.STATUS = STATUS

local function MakePill(parent)
  local pill = CreateFrame("Frame", nil, parent)
  pill.bg = pill:CreateTexture(nil, "BACKGROUND")
  pill.bg:SetTexture(WHITE)
  pill.l = pill:CreateTexture(nil, "BACKGROUND")
  pill.l:SetTexture(WHITE)
  pill.r = pill:CreateTexture(nil, "BACKGROUND")
  pill.r:SetTexture(WHITE)
  pill.text = pill:CreateFontString(nil, "OVERLAY")
  function pill:SetStatus(status)
    local st = status and STATUS[status]
    if not st then self:Hide(); self.status = nil; return end
    self.status = status
    self.text:SetText(st.text)
    self.text:SetTextColor(st.color[1], st.color[2], st.color[3], 1)
    for _, t in ipairs({ self.bg, self.l, self.r }) do
      t:SetVertexColor(st.color[1], st.color[2], st.color[3], 0.16)
    end
    self:Show()
  end
  pill:Hide()
  return pill
end
card.MakePill = MakePill

-- History band ("EARLIER STEPS").
local hist = CreateFrame("Frame", nil, card)
hist.bg = hist:CreateTexture(nil, "BACKGROUND")
hist.label = hist:CreateFontString(nil, "OVERLAY")
hist.hint = hist:CreateFontString(nil, "OVERLAY")
hist.rows = {}
for i = 1, 3 do
  local row = CreateFrame("Button", nil, hist)
  row.hl = row:CreateTexture(nil, "BACKGROUND")
  row.num = row:CreateFontString(nil, "OVERLAY")
  row.pill = MakePill(row)
  row.text = row:CreateFontString(nil, "OVERLAY")
  row.status = "done" -- filled by LayoutHistory below
  hist.rows[i] = row
end
card.hist = hist

-- Body + pooled step blocks (card.blocksForTest in the real addon).
local body = CreateFrame("Frame", nil, card)
local blocks = {}
card.blocksForTest = blocks

local function NewLine(block)
  local line = CreateFrame("Frame", nil, block)
  line.mark = line:CreateTexture(nil, "ARTWORK")
  line.text = line:CreateFontString(nil, "OVERLAY")
  line.barBg = line:CreateTexture(nil, "ARTWORK")
  line.bar = line:CreateTexture(nil, "OVERLAY")
  line.count = line:CreateFontString(nil, "OVERLAY")
  return line
end

local function MakeBadge(parent)
  local b = CreateFrame("Frame", nil, parent)
  b.fill = b:CreateTexture(nil, "BACKGROUND")
  b.fill:SetTexture(CARD_TEX .. "disc")
  b.ring = b:CreateTexture(nil, "BORDER")
  b.ring:SetTexture(CARD_TEX .. "ring")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.glyph = b:CreateFontString(nil, "OVERLAY")
  return b
end

for i = 1, 2 do
  local b = CreateFrame("Frame", nil, body)
  b.sep = b:CreateTexture(nil, "ARTWORK")
  b.badge = MakeBadge(b)
  b.num = b:CreateFontString(nil, "OVERLAY")
  b.title = b:CreateFontString(nil, "OVERLAY")
  b.lines = { NewLine(b), NewLine(b) }
  blocks[i] = b
end

-- "Up next" band.
local upNext = CreateFrame("Frame", nil, card)
upNext.sep = upNext:CreateTexture(nil, "ARTWORK")
upNext.label = upNext:CreateFontString(nil, "OVERLAY")
upNext.text = upNext:CreateFontString(nil, "OVERLAY")
upNext.lines = { upNext.text }

-- Bottom button bar + XP strip + collapsed mini card.
local bar = CreateFrame("Frame", nil, card)
bar.bg = bar:CreateTexture(nil, "BACKGROUND")
bar.line = bar:CreateTexture(nil, "ARTWORK")

local function MakeBarButton(parent, hasLabel)
  local btn = CreateFrame("Button", nil, parent)
  btn.bg = btn:CreateTexture(nil, "BACKGROUND")
  btn.bg:SetTexture(WHITE)
  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  if hasLabel then
    btn.label = btn:CreateFontString(nil, "OVERLAY")
    btn.bg:SetVertexColor(CARD_C.blue[1], CARD_C.blue[2], CARD_C.blue[3], 0.16)
  else
    btn.bg:SetVertexColor(1, 1, 1, 0)
  end
  btn:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(1, 1, 1, 0.1)
  end)
  btn:SetScript("OnLeave", function(self)
    if hasLabel then
      self.bg:SetVertexColor(CARD_C.blue[1], CARD_C.blue[2], CARD_C.blue[3], 0.16)
    else
      self.bg:SetVertexColor(1, 1, 1, 0)
    end
  end)
  return btn
end

bar.prev = MakeBarButton(bar)
bar.next = MakeBarButton(bar)
bar.find = MakeBarButton(bar, true)
bar.stop = MakeBarButton(bar, true)
bar.resume = MakeBarButton(bar, true)
bar.settings = MakeBarButton(bar)
bar.menu = MakeBarButton(bar)
bar.collapse = MakeBarButton(bar)

local xpStrip = CreateFrame("Frame", nil, bar)
xpStrip.bg = xpStrip:CreateTexture(nil, "ARTWORK")
xpStrip.rested = xpStrip:CreateTexture(nil, "ARTWORK")
xpStrip.fill = xpStrip:CreateTexture(nil, "ARTWORK")
card.xpStrip = xpStrip

local mini = CreateFrame("Frame", nil, card)
mini.badge = MakeBadge(mini)
mini.text = mini:CreateFontString(nil, "OVERLAY")
mini.count = mini:CreateFontString(nil, "OVERLAY")
mini.expand = MakeBarButton(mini)

-- Step list popup (built lazily by card.BuildStepList, exactly like the
-- real addon; mouse-wheel only, no slider — list.offset/list.count drive it).
local LIST_ROWS = 6
local list = nil

-- Test-only observation handles for the card's unnamed children (skins
-- must find them by walking; tests read state through these).
HARNESS.cardBits = {
  header = header, bar = bar, upNext = upNext, mini = mini,
  blocks = blocks, hist = hist, xpStrip = xpStrip, progress = progress,
  list = nil, -- set by card.BuildStepList
}
local cardBits = HARNESS.cardBits

function card.BuildStepList()
  if list then return list end
  list = CreateFrame("Frame", nil, card, "BackdropTemplate")
  list.offset = 0
  list.count = 0
  list.title = list:CreateFontString(nil, "OVERLAY")
  list.close = MakeBarButton(list)
  list.rows = {}
  for r = 1, LIST_ROWS do
    local row = CreateFrame("Button", nil, list)
    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.num = row:CreateFontString(nil, "OVERLAY")
    row.pill = MakePill(row)
    row.text = row:CreateFontString(nil, "OVERLAY")
    list.rows[r] = row
  end
  list:SetHeight(28 + LIST_ROWS * 18 + 8)
  list:EnableMouseWheel(true)
  list:Hide()
  cardBits.list = list
  return list
end

-- Fake guide the list renders: 40 steps, current step 4 (rows 1-3 done).
local FAKE_STEPS = 40
local FAKE_CURRENT = 4

function card.StepStatus(_, index, current)
  current = current or FAKE_CURRENT
  if index < current then return "done" end
end

function card.FillStepList()
  if not (list and list:IsShown()) then return end
  list.title:SetText("Fake Guide 1-10")
  list.count = FAKE_STEPS
  for r, row in ipairs(list.rows) do
    local i = list.offset + r
    row.index = i
    row.current = i == FAKE_CURRENT
    row.num:SetText(i)
    row.text:SetText("Fake step " .. i)
    local status = not row.current and card.StepStatus(nil, i, FAKE_CURRENT) or nil
    row.pill:SetStatus(status)
    local color = row.current and CARD_C.blue or status and CARD_C.faint or CARD_C.text
    row.text:SetTextColor(color[1], color[2], color[3], 1)
    row.num:SetTextColor((row.current and CARD_C.blue or CARD_C.dim)[1],
      (row.current and CARD_C.blue or CARD_C.dim)[2],
      (row.current and CARD_C.blue or CARD_C.dim)[3], 1)
    row.hl:SetColorTexture(1, 1, 1, row.current and 0.05 or 0)
    row:Show()
  end
end

function card.ToggleStepList()
  bump("card.ToggleStepList")
  card.BuildStepList()
  if list:IsShown() then list:Hide(); return end
  list:SetPoint("TOPLEFT", card, "TOPRIGHT", 4, 0)
  list:Show()
  card.FillStepList()
  -- The real card's 0.25 s ticker refreshes right after a toggle; the fake
  -- refreshes immediately so re-application is observable in tests.
  card.Refresh(nil, true)
end

-- Waypoint arrow (phase 1) --------------------------------------------------
local af = CreateFrame("Frame", "RXPG_ARROW", UIParent)
af.texture = af:CreateTexture(nil, "ARTWORK")
af.text = af:CreateFontString(nil, "OVERLAY")

-- Quest Targets (phase 1) ---------------------------------------------------
local tf = CreateFrame("Frame", "RXPTargetFrame", UIParent, "BackdropTemplate")
local tfTitle = CreateFrame("Frame", "RXPTargetFrame_title", tf)
tfTitle.text = tfTitle:CreateFontString(nil, "OVERLAY")
tf.title = tfTitle
-- A secure enemy button (SecureActionButtonTemplate in the real addon).
local eb = CreateFrame("Button", "RXPTargetFrame_EnemyButton1", tf, "SecureActionButtonTemplate")
eb.__protected = true
eb.label = eb:CreateFontString(nil, "OVERLAY")

-- Phase 2 windows -----------------------------------------------------------
local itemFrame = CreateFrame("Frame", "RXPItemFrame", UIParent, "BackdropTemplate")
local itemTitle = CreateFrame("Frame", "RXPItemFrame_title", itemFrame)
itemTitle.text = itemTitle:CreateFontString(nil, "OVERLAY")
itemFrame.title = itemTitle
local splits = CreateFrame("Frame", "RXPLevelSplits", UIParent, "BackdropTemplate")
local splitsTitle = CreateFrame("Frame", "RXPLevelSplits_title", splits)
splitsTitle.text = splitsTitle:CreateFontString(nil, "OVERLAY")
splits.title = splitsTitle
CreateFrame("Frame", "OpenXPWelcomeFrame", UIParent, "BackdropTemplate")
CreateFrame("Frame", "OpenXPFeedbackFrame", UIParent, "BackdropTemplate")

-- EXCLUDED frames (must never be touched by OXP-FUI) ------------------------
local rxpFrame = CreateFrame("Frame", "RXPFrame", UIParent, "BackdropTemplate")
CreateFrame("Frame", "RXPFrame_bottomFrame", rxpFrame)
CreateFrame("Frame", "RXPFrameGuideName", rxpFrame)
CreateFrame("Frame", "RXPG_MenuFrame", UIParent, "UIDropDownMenuTemplate")
CreateFrame("Frame", "RXP_MMMenuFrame", UIParent, "UIDropDownMenuTemplate")
CreateFrame("Frame", "RXP_WMMenuFrame", WorldMapFrame)
CreateFrame("Frame", "RXP_WMMenuFrame_MenuFrame", WorldMapFrame, "UIDropDownMenuTemplate")
CreateFrame("Frame", "OpenXPTargetMobs", UIParent, "SecureActionButtonTemplate").__protected = true
CreateFrame("Frame", "OpenXPTargetNPCs", UIParent, "SecureActionButtonTemplate").__protected = true
-- Other addons' / Blizzard frames.
CreateFrame("Frame", "AnotherAddonFrame", UIParent)
CreateFrame("Frame", "BugSackFrame", UIParent)

-- -------------------------------------------------------------------------
-- "OpenXP look" restyle (what the engine must always win over)
-- -------------------------------------------------------------------------

local OXP_BACKDROP = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  tile = true, tileSize = 1, edgeSize = 1,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function applyOpenXPLook(frame, fontString)
  if frame then
    frame:SetBackdrop(OXP_BACKDROP)
    frame:SetBackdropColor(16 / 255, 17 / 255, 21 / 255, 0.9)
    frame:SetBackdropBorderColor(150 / 255, 160 / 255, 180 / 255, 0.35)
  end
  if fontString then
    fontString:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
    fontString:SetTextColor(90 / 255, 184 / 255, 1, 1)
    fontString:SetShadowColor(0, 0, 0, 0)
    fontString:SetShadowOffset(0, 0)
  end
end

-- Restyle one fontstring the way OpenXP's card does: its font + outline and
-- a caller-supplied palette color, shadow off.
local function oxpFont(fs, color, size)
  if not fs then return end
  fs:SetFont("Fonts\\ARIALN.TTF", size or 12, "OUTLINE")
  if color then fs:SetTextColor(color[1], color[2], color[3], 1) end
  fs:SetShadowColor(0, 0, 0, 0)
  fs:SetShadowOffset(0, 0)
end

local function oxpTint(tex, color, alpha)
  if not tex then return end
  tex:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

-- The card's own Refresh: put every card element back on the OpenXP look.
local function applyCardOpenXPLook()
  applyOpenXPLook(card)
  header.dot:SetTexture(CARD_TEX .. "filledcircle")
  oxpTint(header.dot, CARD_C.blue)
  oxpFont(header.zone, CARD_C.text)
  oxpFont(header.range, CARD_C.dim)
  oxpFont(header.step, CARD_C.dim)
  progressBg:SetColorTexture(1, 1, 1, 0.08)
  progress:SetColorTexture(CARD_C.blue[1], CARD_C.blue[2], CARD_C.blue[3], 1)
  oxpFont(hist.label, CARD_C.dim)
  oxpFont(hist.hint, CARD_C.faint)
  for _, row in ipairs(hist.rows) do
    oxpFont(row.num, CARD_C.faint)
    oxpFont(row.text, row.status == "done" and CARD_C.dim or CARD_C.text)
    row.pill:SetStatus(row.status)
  end
  for _, b in ipairs(blocks) do
    b.badge.fill:SetTexture(CARD_TEX .. "disc")
    b.badge.ring:SetTexture(CARD_TEX .. "ring")
    -- travel badges are the blue ones
    oxpTint(b.badge.fill, CARD_C.blue, 0.16)
    oxpTint(b.badge.ring, CARD_C.blue)
    oxpTint(b.badge.icon, CARD_C.blue)
    oxpFont(b.num, CARD_C.faint)
    oxpFont(b.title, CARD_C.text)
    for _, line in ipairs(b.lines) do
      oxpFont(line.text, CARD_C.text)
      oxpFont(line.count, CARD_C.dim)
      line.bar:SetColorTexture(CARD_C.blue[1], CARD_C.blue[2], CARD_C.blue[3], 1)
    end
  end
  -- block 1 = the current step: line 1 open, line 2 finished (check mark,
  -- dimmed text and 0.7 alpha, exactly like card.Refresh does)
  local cur = blocks[1]
  cur.lines[1].mark:SetTexture(CARD_TEX .. "opencircle")
  oxpTint(cur.lines[1].mark, CARD_C.dim)
  cur.lines[1]:SetAlpha(1)
  cur.lines[2].mark:SetTexture(CARD_TEX .. "check")
  oxpTint(cur.lines[2].mark, CARD_C.green)
  cur.lines[2]:SetAlpha(0.7)
  oxpFont(cur.lines[2].text, CARD_C.faint)
  oxpFont(upNext.label, CARD_C.dim)
  for _, line in ipairs(upNext.lines) do oxpFont(line, CARD_C.dim) end
  for _, btn in ipairs({ bar.prev, bar.next, bar.menu, bar.settings, bar.collapse }) do
    btn.bg:SetVertexColor(1, 1, 1, 0)
    oxpTint(btn.icon, { 0.87, 0.88, 0.92 })
  end
  for _, btn in ipairs({ bar.find, bar.stop, bar.resume }) do
    btn.bg:SetVertexColor(CARD_C.blue[1], CARD_C.blue[2], CARD_C.blue[3], 0.16)
    if btn.label then oxpFont(btn.label, { 159 / 255, 212 / 255, 1 }, 13) end
  end
  xpStrip.bg:SetColorTexture(1, 1, 1, 0.06)
  xpStrip.rested:SetColorTexture(CARD_C.blue[1], CARD_C.blue[2], CARD_C.blue[3], 0.35)
  xpStrip.fill:SetColorTexture(CARD_C.gold[1], CARD_C.gold[2], CARD_C.gold[3], 0.9)
  oxpFont(mini.text, CARD_C.text)
  oxpFont(mini.count, CARD_C.dim)
  if list then
    applyOpenXPLook(list)
    oxpFont(list.title, CARD_C.dim)
    card.FillStepList()
  end
end

function HARNESS.ApplyOpenXPLook()
  applyCardOpenXPLook()
  applyOpenXPLook(N("RXPG_ARROW"), N("RXPG_ARROW").text)
  applyOpenXPLook(N("RXPTargetFrame"), N("RXPTargetFrame_title").text)
  -- UpdateTargetFrame rebuilds the secure target rows, restyling them too.
  applyOpenXPLook(N("RXPTargetFrame_EnemyButton1"), N("RXPTargetFrame_EnemyButton1").label)
  applyOpenXPLook(N("RXPItemFrame"), N("RXPItemFrame_title").text)
  applyOpenXPLook(N("RXPLevelSplits"), N("RXPLevelSplits_title").text)
  applyOpenXPLook(N("OpenXPWelcomeFrame"))
  applyOpenXPLook(N("OpenXPFeedbackFrame"))
end

HARNESS.ApplyOpenXPLook()

-- -------------------------------------------------------------------------
-- The shared addon table (reached by OXP-FUI via LibStub AceAddon-3.0)
-- -------------------------------------------------------------------------

local addon = {
  openxpVersion = HARNESS.openxpVersion,
  title = "OpenXP",
  RXPFrame = rxpFrame,
  settings = {
    profile = {
      guideFont = "default",          -- "Arial Narrow" default in OpenXP
      guideFontSize = 12,
      guideFontOutline = "OUTLINE",
      activeTheme = "RXP Blue",
    },
  },
  enabledFrames = {
    arrowFrame = af,
    activeTargetFrame = tf,
    activeItemFrame = itemFrame,
    levelSplits = splits,
    RXPFrame = rxpFrame,
  },
}

addon.card = {
  frame = card,
  grip = grip,
  hist = hist,
  blocksForTest = blocks,
  xpStrip = xpStrip,
  STATUS = STATUS,
  MakePill = MakePill,
  StepStatus = card.StepStatus,
  BuildStepList = card.BuildStepList,
  FillStepList = card.FillStepList,
  ToggleStepList = card.ToggleStepList,
  Refresh = function(_, force) bump("card.Refresh"); if force then HARNESS.ApplyOpenXPLook() end end,
  SkinPanels = function() bump("card.SkinPanels")
    HARNESS.ApplyOpenXPLook()
  end,
  SkinPanel = function(_, f) bump("card.SkinPanel"); if f then applyOpenXPLook(f.__raw or f) end end,
  ApplyFonts = function()
    bump("card.ApplyFonts")
    HARNESS.ApplyOpenXPLook()
  end,
}

-- The card's CurrentStep() reads this off the addon table.
function addon.GetGuideProgress() return 4 end
addon.currentGuide = { name = "Fake Guide", displayname = "Fake Guide 1-10", steps = {} }

addon.arrowFrame = af
addon.targeting = {
  activeTargetFrame = tf,
  UpdateTargetFrame = function() bump("targeting.UpdateTargetFrame"); HARNESS.ApplyOpenXPLook() end,
  RenderTargetFrameBackground = function() bump("targeting.RenderTargetFrameBackground")
    applyOpenXPLook(N("RXPTargetFrame"))
  end,
}
addon.tracker = {
  levelSplits = splits,
  UpdateLevelSplits = function() bump("tracker.UpdateLevelSplits"); HARNESS.ApplyOpenXPLook() end,
  CreateLevelSplits = function() bump("tracker.CreateLevelSplits") end,
}
addon.activeItemFrame = itemFrame
addon.activeItemFrame.UpdateVisuals = function() bump("activeItemFrame.UpdateVisuals")
  applyOpenXPLook(N("RXPItemFrame"))
end

function addon.RenderFrame(_, themeUpdate, isLoading)
  bump("RenderFrame")
  HARNESS.ApplyOpenXPLook()
end

function addon.ReloadTheme(_)
  bump("ReloadTheme")
  HARNESS.ApplyOpenXPLook()
end

function addon.SetupArrow()
  bump("SetupArrow")
  af.texture:SetTexture("Interface\\AddOns\\OpenXP\\Textures\\Card\\pointer")
  applyOpenXPLook(nil, af.text)
end

af.UpdateVisuals = function()
  bump("arrowFrame.UpdateVisuals")
  af.texture:SetTexture("Interface\\AddOns\\OpenXP\\Textures\\Card\\pointer")
end

-- LibStub AceAddon-3.0 shim serving the fake addon table.
HARNESS.libs["AceAddon-3.0"] = {
  GetAddon = function(_, name)
    if name == "OpenXP" then return addon end
    error("AceAddon:GetAddon(): not found: " .. tostring(name), 2)
  end,
}

HARNESS.openxp = addon
_G.RXPGuides = {}
HARNESS.addonMetadata["OpenXP"] = { Title = "OpenXP", Version = HARNESS.openxpVersion }
