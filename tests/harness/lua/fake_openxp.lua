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

local function refreshCard(force)
  bump("card.Refresh")
  if force then HARNESS.ApplyOpenXPLook() end
end

-- Set once the addon table exists; card functions defined before it reach
-- the module table (the hooked refresh path) through this.
local addonCard = nil

function card.ToggleStepList()
  bump("card.ToggleStepList")
  card.BuildStepList()
  if list:IsShown() then list:Hide(); return end
  list:SetPoint("TOPLEFT", card, "TOPRIGHT", 4, 0)
  list:Show()
  card.FillStepList()
  -- The real card's 0.25 s ticker refreshes right after a toggle (through
  -- the module table, where hooks live); the fake refreshes immediately.
  if addonCard and addonCard.Refresh then addonCard.Refresh(nil, true) end
end

-- Waypoint arrow (phase 1) --------------------------------------------------
-- Mirrors map.lua plus the card's arrow code (OpenXPCard.lua): StyleArrow
-- creates the dial textures and the dist/label font strings once; the
-- OnUpdate handler (card's ArrowUpdate) then repaints the ring tint and
-- the distance text colour EVERY FRAME, following the arrived state. A
-- skin under test must therefore win not only over the refresh calls but
-- also over that per-frame repaint.
local af = CreateFrame("Frame", "RXPG_ARROW", UIParent)
af.texture = af:CreateTexture(nil, "ARTWORK")
af.text = af:CreateFontString(nil, "OVERLAY")

local OXP_TEX = "Interface\\AddOns\\OpenXP\\Textures\\Card\\"
-- The slice of OpenXPCard.lua's local C table the arrow repaint uses.
local OXP_C = {
  blue = { 90 / 255, 184 / 255, 1 },
  green = { 61 / 255, 187 / 255, 122 / 255 },
}
local function OXPTint(tex, color, alpha)
  tex:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

-- Arrow state DrawArrow would maintain (map.lua); tests drive it directly.
af.distance = 100
af.element = { title = "Kill: Forest Wolf Pack" }

-- map.lua drag handlers: OpenXP behaviour OXP-FUI must leave untouched.
af:SetMovable(true)
af:EnableMouse(1)
af:SetScript("OnMouseDown", function(self)
  local a = HARNESS.openxp
  if a and not a.settings.profile.lockFrames and self:GetAlpha() ~= 0 then
    self:StartMoving()
  end
end)
af:SetScript("OnMouseUp", function(self)
  self:StopMovingOrSizing()
end)

-- card.StyleArrow (OpenXPCard.lua:2196): dial + text, created once.
local function StyleArrow()
  if af.openxpStyled then return end
  af.openxpStyled = true
  af.dialBg = af:CreateTexture(nil, "BACKGROUND")
  af.dialBg:SetTexture(OXP_TEX .. "dialdisc")
  af.dialBg:SetVertexColor(16 / 255, 17 / 255, 21 / 255, 0.85)
  af.dialRing = af:CreateTexture(nil, "BORDER")
  af.dialRing:SetTexture(OXP_TEX .. "dialring")
  af.arrived = af:CreateTexture(nil, "OVERLAY")
  af.arrived:SetTexture(OXP_TEX .. "check")
  OXPTint(af.arrived, OXP_C.green)
  af.arrived:Hide()
  af.text:SetAlpha(0)
  af.oxpDist = af:CreateFontString(nil, "OVERLAY")
  af.oxpDist:SetFont("Fonts\\ARIALN.TTF", 17, "OUTLINE")
  af.oxpLabel = af:CreateFontString(nil, "OVERLAY")
  af.oxpLabel:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
  af.oxpLabel:SetTextColor(0.72, 0.74, 0.8, 1)
end

-- The colour/text half of card.ArrowUpdate (OpenXPCard.lua:2261-2288):
-- OpenXP's own per-frame repaint, following the arrived state. Reused by
-- HARNESS.ApplyOpenXPLook so refresh calls reset the dial to OpenXP's look.
local function ArrowPaintOpenXP()
  if not af.oxpDist then return end
  local dist = af.distance or 0
  local element = af.oxpVia or af.element
  local here = element and dist <= 8
  if here then
    af.texture:Hide()
    af.arrived:Show()
    OXPTint(af.dialRing, OXP_C.green)
    af.oxpDist:SetText("Here")
    af.oxpDist:SetTextColor(OXP_C.green[1], OXP_C.green[2], OXP_C.green[3], 1)
  else
    af.texture:Show()
    af.arrived:Hide()
    OXPTint(af.dialRing, OXP_C.blue, 0.6)
    af.oxpDist:SetText(string.format("%d yd", dist))
    af.oxpDist:SetTextColor(0.96, 0.97, 0.98, 1)
  end
  af.oxpLabel:SetText(element and element.title or "")
end

-- The OnUpdate handler OpenXP installs on the arrow frame (card.TimedArrow).
local function ArrowUpdate(self)
  bump("ArrowUpdate")
  local a = HARNESS.openxp
  if a and a.DrawArrow then a.DrawArrow(self) end
  ArrowPaintOpenXP()
end

-- Quest Targets (phase 1) ---------------------------------------------------
-- Mirrors Targeting.lua: the frame, its title strip ("QUEST TARGETS" + a
-- keybind hint), the "KILL"/"TALK TO" section labels and the SECURE target
-- rows (SecureActionButtonTemplate macro buttons) with their RowifyTargets
-- internals: hl highlight, 2px class strip (bar), iconHolder + icon, key and
-- label font strings. Buttons are created on demand in the real addon and
-- kept in targetFrame.enemyTargetButtons / .friendlyTargetButtons.
local tf = CreateFrame("Frame", "RXPTargetFrame", UIParent, "BackdropTemplate")
local tfTitle = CreateFrame("Frame", "RXPTargetFrame_title", tf)
tfTitle.text = tfTitle:CreateFontString(nil, "OVERLAY")
tf.title = tfTitle
tfTitle.keyHint = tfTitle:CreateFontString(nil, "OVERLAY")
tfTitle.keyHint:SetFont("Fonts\\ARIALN.TTF", 10, "")
tfTitle.keyHint:SetText("nearest T")
tfTitle.keyHint:SetTextColor(0.54, 0.56, 0.61, 1)

tf.sections = {}
for _, secpair in ipairs({ { "enemy", "KILL" }, { "friendly", "TALK TO" } }) do
  local fs = tf:CreateFontString(nil, "OVERLAY")
  fs:SetFont("Fonts\\ARIALN.TTF", 10, "")
  fs:SetText(secpair[2])
  fs:SetTextColor(0.54, 0.56, 0.61, 1)
  tf.sections[secpair[1]] = fs
end

-- RowifyTargets (Targeting.lua 1089-1124): the OpenXP row look.
local function rowify(btn, kind)
  btn.kind = kind
  btn.hl = btn:CreateTexture(nil, "BACKGROUND")
  btn.hl:SetAllPoints()
  btn.hl:SetColorTexture(1, 1, 1, 0)
  btn.bar = btn:CreateTexture(nil, "ARTWORK")
  btn.bar:SetWidth(2)
  if kind == "enemy" then
    btn.bar:SetColorTexture(1, 112 / 255, 67 / 255, 1)
  else
    btn.bar:SetColorTexture(61 / 255, 187 / 255, 122 / 255, 1)
  end
  btn.iconHolder = CreateFrame("Frame", nil, btn)
  btn.icon = btn.iconHolder:CreateTexture(nil, "ARTWORK")
  btn.key = btn:CreateFontString(nil, "OVERLAY")
  btn.key:SetFont("Fonts\\ARIALN.TTF", 10, "")
  btn.key:SetTextColor(0.54, 0.56, 0.61, 1)
  btn.label = btn:CreateFontString(nil, "OVERLAY")
  btn.label:SetFont("Fonts\\ARIALN.TTF", 12, "")
  btn.label:SetTextColor(0.92, 0.93, 0.95, 1)
end

tf.enemyTargetButtons = {}
tf.friendlyTargetButtons = {}
local function targetButton(list, globalName, kind, macrotext)
  local btn = CreateFrame("Button", globalName, tf, "SecureActionButtonTemplate")
  btn.__protected = true
  btn:SetAttribute("type", "macro")
  btn:SetAttribute("macrotext", macrotext)
  btn:RegisterForClicks("AnyUp", "AnyDown")
  rowify(btn, kind)
  list[#list + 1] = btn
  return btn
end

local eb1 = targetButton(tf.enemyTargetButtons, "RXPTargetFrame_EnemyButton1",
  "enemy", "/targetexact Forest Lurker")
targetButton(tf.enemyTargetButtons, "RXPTargetFrame_EnemyButton2",
  "enemy", "/targetexact Mangy Wolf")
targetButton(tf.friendlyTargetButtons, "RXPTargetFrame_FriendlyButton1",
  "friendly", "/targetexact Wing Commander")

-- The secure template runs the macro on click; the fake records it so tests
-- can prove targeting still works after OXP-FUI restyles the rows.
eb1:SetScript("OnClick", function() bump("RXPTargetFrame_EnemyButton1 click") end)

-- Other phase 2 panels (tracker / active-item / windows tickets) ----------------
-- Active-item frame (ActiveItemFrame.lua 261-320): the frame, its title
-- strip ("Active Items", V1 visuals give the strip its own legacy edge
-- backdrop), the SECURE item buttons (SecureActionButtonTemplate, kept in
-- itemFrame.buttonList) and the two hidden SECURE teleport buttons (382-394).
local itemFrame = CreateFrame("Frame", "RXPItemFrame", UIParent, "BackdropTemplate")
local itemTitle = CreateFrame("Frame", "RXPItemFrame_title", itemFrame, "BackdropTemplate")
itemTitle.text = itemTitle:CreateFontString(nil, "OVERLAY")
itemTitle.text:SetFont("Fonts\\ARIALN.TTF", 9, "")
itemTitle.text:SetTextColor(0.62, 0.64, 0.70, 1)
itemFrame.title = itemTitle
itemFrame.buttonList = {}
local function itemButton(i)
  local btn = CreateFrame("Button", "RXPItemFrameButton" .. i, itemFrame,
    "SecureActionButtonTemplate")
  btn.__protected = true
  btn:SetAttribute("type1", "item")
  btn:SetAttribute("item", "item:19019")
  btn:RegisterForClicks("AnyUp", "AnyDown")
  btn.icon = btn:CreateTexture(nil, "BACKGROUND")
  btn.icon:SetAllPoints(true)
  btn.icon:SetTexture("Interface\\Icons\\INV_Misc_Gem_01")
  itemFrame.buttonList[i] = btn
  return btn
end
itemButton(1)
itemButton(2)
-- Hidden secure teleport buttons; like the quick-target buttons these are
-- never given any visual treatment.
CreateFrame("Button", "RXPTELEPORTTO", nil, "SecureActionButtonTemplate").__protected = true
CreateFrame("Button", "RXPTELEPORTHOME", nil, "SecureActionButtonTemplate").__protected = true
local splits = CreateFrame("Frame", "RXPLevelSplits", UIParent, "BackdropTemplate")
local splitsTitle = CreateFrame("Frame", "RXPLevelSplits_title", splits)
splitsTitle.text = splitsTitle:CreateFontString(nil, "OVERLAY")
splits.title = splitsTitle
-- Level splits children (LevelingTracker.lua 1030-1095): the cogwheel
-- button (rxp_cog-32 normal texture, half over the title's left edge), the
-- hidden dropdown menu, and the three AceGUI Label widgets
-- (history/current/total) whose font string is .label and whose SetFont
-- forwards to it.
local cog = CreateFrame("Button", "$parentCogwheel", splitsTitle)
splitsTitle.cog = cog
local cogTex = cog:CreateTexture(nil, "ARTWORK")
cogTex:SetTexture("Interface\\AddOns\\OpenXP\\Textures\\Minimal\\rxp_cog-32")
cog:SetNormalTexture(cogTex)
cog:SetScript("OnClick", function() bump("RXPLevelSplits_titleCogwheel click") end)
splitsTitle.splitsMenuFrame =
  CreateFrame("Frame", "RXPG_SplitsMenuFrame", splitsTitle, "UIDropDownMenuTemplate")

local function aceLabel(parent)
  -- AceGUI-3.0 Label: widget table with .frame and the .label font string
  -- (SetFont on the widget re-fonts the font string, AceGUIWidget-Label).
  local w = {}
  w.frame = CreateFrame("Frame", nil, parent)
  w.label = w.frame:CreateFontString(nil, "OVERLAY")
  w.SetFont = function(_, font, size, flags) w.label:SetFont(font, size, flags) end
  w.SetText = function(_, text) w.label:SetText(text) end
  return w
end
splits.history = aceLabel(splits)
splits.current = aceLabel(splits)
splits.total = aceLabel(splits)
-- UpdateLevelSplits content (LevelingTracker.lua 1242-1316).
splits.history:SetText("Level 40  4:41\nLevel 39  5:02")
splits.current:SetText("Level 41  12:07 (est 18:40)")
splits.total:SetText("Total  3:24:55")

-- The leveling tracker proper (the report panel): AceGUI widgets attached
-- to Blizzard frames and keyed by attachment name in addon.tracker.ui
-- (LevelingTracker.lua 420-633). The AceGUI frame container is unnamed;
-- the level button's frame carries an AceGUI30Button<N> name.
local reports = {}
local report = {}
report.frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
report.titletext = report.frame:CreateFontString(nil, "OVERLAY")
report.levelButton = {}
report.levelButton.frame = CreateFrame("Button", "AceGUI30Button1", UIParent)
report.levelButton.text = report.levelButton.frame:CreateFontString(nil, "OVERLAY")
report.levelMenuFrame = CreateFrame("Frame", "RXPG_LevelMenuFrame",
  report.levelButton.frame, "UIDropDownMenuTemplate")

local function headingWidget(parent)
  -- AceGUI Heading (AceGUIWidget-Heading): centered text between two
  -- UI-Tooltip-Border divider textures.
  local h = {}
  h.frame = CreateFrame("Frame", nil, parent)
  h.label = h.frame:CreateFontString(nil, "BACKGROUND")
  h.left = h.frame:CreateTexture(nil, "BACKGROUND")
  h.right = h.frame:CreateTexture(nil, "BACKGROUND")
  h.left:SetTexture(137057) -- Interface\Tooltips\UI-Tooltip-Border
  h.right:SetTexture(137057)
  return h
end

local function dataLabel(parent)
  return aceLabel(parent)
end

report.target = dataLabel(report.frame)
for _, key in ipairs({ "reachedContainer", "speedContainer", "zonesContainer",
                       "extrasContainer" }) do
  local c = { label = headingWidget(report.frame), data = dataLabel(report.frame) }
  report[key] = c
end
-- sourcesContainer.data and teamworkContainer.data are maps of labels
-- ({quests,mobs} and {solo,group}, LevelingTracker.lua 566-614).
report.sourcesContainer = {
  label = headingWidget(report.frame),
  data = { quests = dataLabel(report.frame), mobs = dataLabel(report.frame) },
}
report.teamworkContainer = {
  label = headingWidget(report.frame),
  data = { solo = dataLabel(report.frame), group = dataLabel(report.frame) },
}
reports.CharacterFrame = report
-- OpenXP aliases the (unnamed) AceGUI frame under this global for Escape.
_G["RESTEDXP_TRACKER_SUMMARY_WINDOW"] = report.frame

-- Welcome / what's-new + feedback windows (phase 2) ---------------------------
-- Mirrors WelcomeFrame.lua:799-989 and Feedback.lua:185-268: created lazily on
-- first Show(), children mostly unnamed, exposed on the addon table as
-- welcome.Show / feedback.Show. Showing a window re-asserts the OpenXP look
-- (creation-time styling, and what a rebuild would redo), so the engine
-- under test must win over it.
-- OpenXP's flat charcoal backdrop (WHITE8X8 hairline), used by the helpers
-- below and by the "OpenXP look" restyle further down.
local OXP_BACKDROP = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  tile = true, tileSize = 1, edgeSize = 1,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local OXP_COLORS = {
  bg = { 16 / 255, 17 / 255, 21 / 255, 0.96 },
  panel = { 22 / 255, 24 / 255, 29 / 255, 0.9 },
  accent = { 90 / 255, 184 / 255, 1 },
  border = { 60 / 255, 66 / 255, 78 / 255 },
  text = { 0.86, 0.86, 0.9 },
  muted = { 0.6, 0.62, 0.7 },
}

local function FrameBackdrop(fr, bg, edge)
  fr:SetBackdrop(OXP_BACKDROP)
  fr:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
  fr:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)
end

local function MakeFlatButton(parent, text, primary)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  local edge = primary and OXP_COLORS.accent or OXP_COLORS.border
  FrameBackdrop(b, primary and { 28 / 255, 70 / 255, 104 / 255, 1 } or OXP_COLORS.panel, edge)
  local label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetText(text)
  label:SetTextColor(1, 1, 1, 1)
  b.label = label
  -- OpenXP's own hover swap (WelcomeFrame.lua MakeButton): border flashes
  -- white, then back to the window's own edge colour.
  b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 1, 1, 0.8) end)
  b:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)
  end)
  return b
end

-- Forward declarations: referenced by ApplyOpenXPLook above its definition.
local ResetWelcome, ResetFeedback

local function CreateWelcomeFrame()
  local f = CreateFrame("Frame", "OpenXPWelcomeFrame", UIParent, "BackdropTemplate")
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  FrameBackdrop(f, OXP_COLORS.bg, OXP_COLORS.accent)

  -- Accent-blue textures (the header divider and the logo glow).
  local divider = f:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(90 / 255, 184 / 255, 1, 0.6)
  local glow = f:CreateTexture(nil, "ARTWORK")
  glow:SetTexture("Interface/Cooldown/star4")
  glow:SetVertexColor(90 / 255, 184 / 255, 1, 0.35)

  -- Title block (title/subtitle are unnamed locals in the real addon).
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  title:SetText("OpenXP")
  title:SetTextColor(1, 1, 1, 1)
  title:SetShadowOffset(2, -2)
  local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  subtitle:SetText("Free leveling guides for WoW Forever")
  subtitle:SetTextColor(0.86, 0.86, 0.9, 1)

  local badge = CreateFrame("Frame", nil, f, "BackdropTemplate")
  FrameBackdrop(badge, { 16 / 255, 40 / 255, 70 / 255, 1 }, OXP_COLORS.accent)
  local badgeText = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  badgeText:SetText("v" .. HARNESS.openxpVersion)
  badgeText:SetTextColor(90 / 255, 184 / 255, 1, 1)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")

  -- Scrolling body: panel -> scroll (Blizzard template) -> content -> body.
  local panel = CreateFrame("Frame", nil, f, "BackdropTemplate")
  FrameBackdrop(panel, OXP_COLORS.panel, OXP_COLORS.border)
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  local content = CreateFrame("Frame", nil, scroll)
  scroll:SetScrollChild(content)
  local body = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  body:SetText("Welcome, adventurer!")
  body:SetTextColor(0.86, 0.86, 0.9, 1)
  f.body, f.content = body, content

  -- Choices row: route checkbox + label, colour swatch + label, Questie hint.
  local route = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  route:SetChecked(true)
  local routeText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  routeText:SetText("Show route lines on the world map and minimap")
  routeText:SetTextColor(0.86, 0.86, 0.9, 1)
  local swatch = CreateFrame("Button", nil, f, "BackdropTemplate")
  FrameBackdrop(swatch, { 0.72, 0.42, 1, 1 }, OXP_COLORS.border)
  local swatchText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  swatchText:SetText("Colour")
  swatchText:SetTextColor(0.6, 0.62, 0.7, 1)
  local function ShowColor()
    swatch:SetBackdropColor(0.72, 0.42, 1, 1) -- profile.openxpRouteColor default
  end
  local questie = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  questie:SetText("Recommended: install the free Questie addon.")
  -- (the real addon keeps the font object's colour here: no SetTextColor)

  local start = MakeFlatButton(f, "Start leveling", true)
  local later = MakeFlatButton(f, "Close", false)
  later.label:SetTextColor(0.86, 0.86, 0.9, 1)

  f.route, f.ShowColor = route, ShowColor
  f:Hide()

  HARNESS.welcome = {
    frame = f, title = title, subtitle = subtitle, badge = badge,
    badgeText = badgeText, close = close, panel = panel, scroll = scroll,
    content = content, body = body, route = route, routeText = routeText,
    swatch = swatch, swatchText = swatchText, questie = questie,
    divider = divider, glow = glow, start = start, later = later,
  }
  return f
end

function ResetWelcome()
  local w = HARNESS.welcome
  if not w then return end
  FrameBackdrop(w.frame, OXP_COLORS.bg, OXP_COLORS.accent)
  FrameBackdrop(w.badge, { 16 / 255, 40 / 255, 70 / 255, 1 }, OXP_COLORS.accent)
  FrameBackdrop(w.panel, OXP_COLORS.panel, OXP_COLORS.border)
  FrameBackdrop(w.swatch, { 0.72, 0.42, 1, 1 }, OXP_COLORS.border)
  FrameBackdrop(w.start, { 28 / 255, 70 / 255, 104 / 255, 1 }, OXP_COLORS.accent)
  FrameBackdrop(w.later, OXP_COLORS.panel, OXP_COLORS.border)
  w.divider:SetColorTexture(90 / 255, 184 / 255, 1, 0.6)
  w.glow:SetVertexColor(90 / 255, 184 / 255, 1, 0.35)
  w.title:SetTextColor(1, 1, 1, 1)
  w.subtitle:SetTextColor(0.86, 0.86, 0.9, 1)
  w.badgeText:SetTextColor(90 / 255, 184 / 255, 1, 1)
  w.body:SetTextColor(0.86, 0.86, 0.9, 1)
  w.routeText:SetTextColor(0.86, 0.86, 0.9, 1)
  w.swatchText:SetTextColor(0.6, 0.62, 0.7, 1)
  w.start.label:SetTextColor(1, 1, 1, 1)
  w.later.label:SetTextColor(0.86, 0.86, 0.9, 1)
end

local FEEDBACK_SECTIONS = {
  { key = "bug", title = "Report a bug", text = "Something broken or wrong in a guide?", button = "Full bug details" },
  { key = "suggestion", title = "Suggest something", text = "An idea for a feature, a better route or a quest the guide should add." },
  { key = "comment", title = "Leave a comment", text = "Say hi, ask a question or tell other players how OpenXP worked for you." },
  { key = "rate", title = "Rate OpenXP", text = "Enjoying OpenXP? A rating on CurseForge helps other players find it." },
}

local function MakeLinkBox(parent)
  local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  box:SetAutoFocus(false)
  box:SetFontObject("GameFontHighlightSmall")
  box:SetTextInsets(6, 6, 0, 0)
  FrameBackdrop(box, { 10 / 255, 11 / 255, 14 / 255, 1 }, OXP_COLORS.border)
  box.url = "https://github.com/mjared123/OpenXP"
  box:SetText(box.url)
  box:SetCursorPosition(0)
  return box
end

local function CreateFeedbackFrame()
  local f = CreateFrame("Frame", "OpenXPFeedbackFrame", UIParent, "BackdropTemplate")
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  FrameBackdrop(f, OXP_COLORS.bg, OXP_COLORS.accent)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetText("Feedback")
  title:SetTextColor(1, 1, 1, 1)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetText("WoW can't open web pages, so click a link and copy it.")
  hint:SetTextColor(0.6, 0.62, 0.7, 1)

  f.boxes = {}
  local panels = {}
  for _, s in ipairs(FEEDBACK_SECTIONS) do
    local panel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    FrameBackdrop(panel, OXP_COLORS.panel, OXP_COLORS.border)
    local head = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head:SetText(s.title)
    head:SetTextColor(90 / 255, 184 / 255, 1, 1)
    local bodyText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bodyText:SetText(s.text)
    bodyText:SetTextColor(0.86, 0.86, 0.9, 1)
    f.boxes[s.key] = MakeLinkBox(panel)
    local btn
    if s.button then
      btn = MakeFlatButton(panel, s.button, true)
      btn.label:SetTextColor(1, 1, 1, 1)
    end
    panels[#panels + 1] = { panel = panel, head = head, body = bodyText, box = f.boxes[s.key], btn = btn }
  end

  local footer = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetText("Thanks for helping make OpenXP better!")

  f:Hide()
  HARNESS.feedback = { frame = f, title = title, close = close, hint = hint, panels = panels, footer = footer }
  return f
end

function ResetFeedback()
  local fb = HARNESS.feedback
  if not fb then return end
  FrameBackdrop(fb.frame, OXP_COLORS.bg, OXP_COLORS.accent)
  fb.title:SetTextColor(1, 1, 1, 1)
  fb.hint:SetTextColor(0.6, 0.62, 0.7, 1)
  for _, p in ipairs(fb.panels) do
    FrameBackdrop(p.panel, OXP_COLORS.panel, OXP_COLORS.border)
    FrameBackdrop(p.box, { 10 / 255, 11 / 255, 14 / 255, 1 }, OXP_COLORS.border)
    p.head:SetTextColor(90 / 255, 184 / 255, 1, 1)
    p.body:SetTextColor(0.86, 0.86, 0.9, 1)
    if p.btn then
      FrameBackdrop(p.btn, { 28 / 255, 70 / 255, 104 / 255, 1 }, OXP_COLORS.accent)
      p.btn.label:SetTextColor(1, 1, 1, 1)
    end
  end
end

-- Talents (phase 2, ticket 8) ------------------------------------------------
-- Mirrors Talents.lua 264-285/339: OpenXP's tab button on Blizzard's talent
-- frame (square SpellBook-SkillLineTab box art behind the logo, hover
-- highlight) and its right-click menu anchor (UIDropDownMenuTemplate). The
-- visible list frame only appears once the menu has been opened.
local playerTalentFrame = CreateFrame("Frame", "PlayerTalentFrame", UIParent)
local talentsTab = CreateFrame("Button", "PlayerTalentFrameRXPTalents", playerTalentFrame)
talentsTab:SetNormalTexture("Interface\\AddOns\\OpenXP\\Textures\\openxp_logo-64")
talentsTab.bg = talentsTab:CreateTexture("PlayerTalentFrameRXPTalentsBG", "BACKGROUND")
talentsTab.bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
talentsTab.bg:SetVertexColor(1, 1, 1)
talentsTab.bg.ht = talentsTab:CreateTexture(nil, "HIGHLIGHT")
talentsTab.bg.ht:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
local talentsMenu = CreateFrame("Frame", "RXP_TalentsMenuFrame", talentsTab,
  "UIDropDownMenuTemplate")
-- Simulates the player right-clicking the tab once: the dropdown's list
-- frame is created lazily by the menu code, only then is it visible.
function HARNESS.OpenTalentsMenu()
  if not _G.RXP_TalentsMenuFrameListFrame then
    CreateFrame("Button", "RXP_TalentsMenuFrameListFrame", nil,
      "UIDropDownMenuListTemplate")
  end
  return _G.RXP_TalentsMenuFrameListFrame
end
-- Level tags OpenXP draws on Blizzard's talent rows (Talents.lua 846/1253):
-- reachable only through Blizzard's own PlayerTalentFrameTalent* namespace,
-- deliberately out of the skin's reach (see SkinWindows.lua).
local talentRow = CreateFrame("Button", "PlayerTalentFrameTalent1", playerTalentFrame)
talentRow.levelHeader = CreateFrame("Frame", "PlayerTalentFrameTalent1_levelText", talentRow)
talentRow.levelHeader.text = talentRow.levelHeader:CreateFontString(nil, "OVERLAY")
talentRow.levelHeader.text:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
talentRow.levelHeader.text:SetText("12,14")

-- Item upgrades (phase 2, ticket 8) -------------------------------------------
-- Mirrors ItemUpgrades.lua 850-860/2195-2233: the stat-diff comparison
-- tooltip OpenXP builds for itself (a GameTooltip with its own text lines),
-- and OpenXP's Auction House tab, which continues Blizzard's
-- AuctionFrameTab numbering and is marked isRXP — Blizzard's own tabs carry
-- no flag and must never be touched by anyone.
local auctionFrame = CreateFrame("Frame", "AuctionFrame", UIParent)
auctionFrame.numTabs = 1
local function auctionTab(index, label, isRXP)
  local tab = CreateFrame("Button", "AuctionFrameTab" .. index, auctionFrame,
    "AuctionTabTemplate")
  tab.isRXP = isRXP
  tab:SetID(index)
  tab.Text = tab:CreateFontString("AuctionFrameTab" .. index .. "Text", "OVERLAY",
    nil, "GameFontHighlightSmall")
  tab.Text:SetText(label)
  tab.Text:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
  tab.Text:SetTextColor(1, 1, 1, 1)
  return tab
end
auctionTab(1, "Bids", false)   -- Blizzard's own tab
auctionTab(2, "OpenXP", true)  -- OpenXP's item-upgrades tab
local comparisonTip = CreateFrame("GameTooltip", "RXPItemUpgradesComparison", nil,
  "GameTooltipTemplate")
comparisonTip.TextLeft1 = comparisonTip:CreateFontString(
  "RXPItemUpgradesComparisonTextLeft1", nil, nil, "GameTooltipText")
comparisonTip.TextRight1 = comparisonTip:CreateFontString(
  "RXPItemUpgradesComparisonTextRight1", nil, nil, "GameTooltipText")

-- Inventory manager (phase 2, ticket 8) ----------------------------------------
-- Mirrors InventoryManager.lua 85-143: no visible window exists — an
-- invisible keybind button, an input-propagation helper frame and a hidden
-- full-screen click passthrough (BACKGROUND strata, shown only while it
-- catches the delete-junk click).
local deleteJunkButton = CreateFrame("Button", "RXPInventory_DeleteJunk")
deleteJunkButton:SetScript("OnClick", function() bump("RXPInventory_DeleteJunk click") end)
local deleteJunkFrame = CreateFrame("Frame", "RXPDeleteJunk", UIParent)
local junkHandler = CreateFrame("Frame", "RXPJunkHandler", UIParent)
junkHandler:SetAllPoints(UIParent)
junkHandler:SetFrameStrata("BACKGROUND")
junkHandler:Hide()

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

-- The Quest Targets family reset to OpenXP's own look (Targeting.lua 813-838,
-- 899-908, 1089-1137). Nil-safe so tests can simulate frames going missing.
function HARNESS.ApplyTargetsOpenXPLook()
  local tf = N("RXPTargetFrame")
  if not tf then return end
  applyOpenXPLook(tf, tf.title and tf.title.text or nil)
  -- Harness stand-in: a backdrop on the secure enemy button gives tests an
  -- observable restyle state for it (the real rows carry no backdrop).
  local eb1 = N("RXPTargetFrame_EnemyButton1")
  applyOpenXPLook(eb1, eb1 and eb1.label or nil)
  local title = tf.title
  if title then
    if title.text then
      title.text:SetFont("Fonts\\ARIALN.TTF", 11, "")
      title.text:SetTextColor(0.62, 0.64, 0.70, 1)
    end
    if title.keyHint then
      title.keyHint:SetFont("Fonts\\ARIALN.TTF", 10, "")
      title.keyHint:SetTextColor(0.54, 0.56, 0.61, 1)
    end
  end
  if type(tf.sections) == "table" then
    for _, fs in pairs(tf.sections) do
      fs:SetFont("Fonts\\ARIALN.TTF", 10, "")
      fs:SetTextColor(0.54, 0.56, 0.61, 1)
    end
  end
  for _, list in ipairs({ tf.enemyTargetButtons, tf.friendlyTargetButtons }) do
    if type(list) == "table" then
      for _, btn in ipairs(list) do
        btn.hl:SetColorTexture(1, 1, 1, 0)
        if btn.kind == "enemy" then
          btn.bar:SetColorTexture(1, 112 / 255, 67 / 255, 1)
        else
          btn.bar:SetColorTexture(61 / 255, 187 / 255, 122 / 255, 1)
        end
        btn.key:SetFont("Fonts\\ARIALN.TTF", 10, "")
        btn.key:SetTextColor(0.54, 0.56, 0.61, 1)
        btn.label:SetFont("Fonts\\ARIALN.TTF", 12, "")
        btn.label:SetTextColor(0.92, 0.93, 0.95, 1)
      end
    end
  end
end

-- The level-splits family reset to OpenXP's own look (LevelingTracker.lua
-- 985-1095, 1030-1070, 1310-1340: RXPFrame edge backdrop, theme text
-- colour, Arial Narrow at levelSplitsFontSize). Nil-safe so tests can
-- simulate frames going missing.
function HARNESS.ApplySplitsOpenXPLook()
  local f = N("RXPLevelSplits")
  if not f then return end
  applyOpenXPLook(f)
  local title = f.title
  if title then
    applyOpenXPLook(title)
    if title.text then
      title.text:SetFont("Fonts\\ARIALN.TTF", 9, "")
      title.text:SetTextColor(0.92, 0.93, 0.95, 1)
      title.text:SetShadowOffset(0, 0)
    end
    local cog = title.cog
    if cog and cog.GetNormalTexture then
      local tex = cog:GetNormalTexture()
      if type(tex) == "table" and tex.SetVertexColor then
        tex:SetVertexColor(1, 1, 1, 1)
      end
    end
  end
  for _, key in ipairs({ "history", "current", "total" }) do
    local w = f[key]
    if type(w) == "table" and w.label and w.label.SetFont then
      w.label:SetFont("Fonts\\ARIALN.TTF", 11, "")
      w.label:SetTextColor(0.92, 0.93, 0.95, 1)
      w.label:SetShadowOffset(0, 0)
    end
  end
end

-- The leveling report panel reset to OpenXP's own look
-- (LevelingTracker.lua 448-449, 523-633: RXPFrame edge backdrop, Arial
-- Narrow 12 labels, untinted heading divider art).
function HARNESS.ApplyReportOpenXPLook()
  -- Read through the addon table once it exists, so tests that remove or
  -- drift the report entries see the same thing OpenXP would.
  local ui = (HARNESS.openxp and HARNESS.openxp.tracker
    and HARNESS.openxp.tracker.ui) or reports
  if type(ui) ~= "table" then return end
  local function labelOpenXPLook(w)
    -- Works for a Label widget (.label font string) or a bare font string.
    local fs = type(w) == "table" and (w.label or w) or nil
    if type(fs) == "table" and fs.SetFont then
      fs:SetFont("Fonts\\ARIALN.TTF", 12, "")
      fs:SetTextColor(0.92, 0.93, 0.95, 1)
      fs:SetShadowOffset(0, 0)
    end
  end
  local function containerOpenXPLook(c)
    if type(c) ~= "table" then return end
    local h = c.label
    if type(h) == "table" then
      labelOpenXPLook(h)
      for _, side in ipairs({ "left", "right" }) do
        local tex = h[side]
        if type(tex) == "table" and tex.SetVertexColor then
          tex:SetVertexColor(1, 1, 1, 1)
        end
      end
    end
    if type(c.data) == "table" then
      labelOpenXPLook(c.data)
      for _, w in pairs(c.data) do labelOpenXPLook(w) end
    end
  end
  for _, trackerUi in pairs(ui) do
    if type(trackerUi) == "table" then
      applyOpenXPLook(trackerUi.frame, trackerUi.titletext)
      local lb = trackerUi.levelButton
      if type(lb) == "table" and lb.text then labelOpenXPLook(lb.text) end
      labelOpenXPLook(trackerUi.target)
      for _, key in ipairs({ "reachedContainer", "speedContainer", "zonesContainer",
                             "sourcesContainer", "teamworkContainer", "extrasContainer" }) do
        containerOpenXPLook(trackerUi[key])
      end
    end
  end
end

function HARNESS.ApplyOpenXPLook()
  applyCardOpenXPLook()
  -- Like OpenXP's own code (addon.arrowFrame), not a _G lookup: a test may
  -- nil the global to simulate a rename without breaking the fake itself.
  applyOpenXPLook(af, af.text)
  -- The dial/text repaint card.ArrowUpdate does (once the card styled it).
  ArrowPaintOpenXP()
  HARNESS.ApplyTargetsOpenXPLook()
  -- Active-item frame: V1 visuals backdrop the frame and its title strip
  -- and re-font the title (ActiveItemFrame.lua 206-226). Nil-safe so tests
  -- can simulate the frames going missing.
  applyOpenXPLook(N("RXPItemFrame"))
  local itemTitle = N("RXPItemFrame_title")
  if itemTitle then
    applyOpenXPLook(itemTitle)
    if itemTitle.text then
      itemTitle.text:SetFont("Fonts\\ARIALN.TTF", 9, "")
      itemTitle.text:SetTextColor(0.62, 0.64, 0.70, 1)
    end
  end
  HARNESS.ApplySplitsOpenXPLook()
  HARNESS.ApplyReportOpenXPLook()
  ResetWelcome()
  ResetFeedback()
  -- Talents: OpenXP never tints the tab's box art; the menu anchor carries
  -- the harness stand-in charcoal backdrop (nil-safe for missing-frame
  -- tests).
  local tab = N("PlayerTalentFrameRXPTalents")
  if tab and tab.bg and tab.bg.SetVertexColor then
    tab.bg:SetVertexColor(1, 1, 1)
  end
  applyOpenXPLook(N("RXP_TalentsMenuFrame"))
  applyOpenXPLook(N("RXP_TalentsMenuFrameListFrame"))
  -- Item upgrades: only OpenXP's own tab (isRXP) is reset — Blizzard's tabs
  -- are never touched by anyone. The comparison tooltip gets the harness
  -- stand-in charcoal backdrop.
  for i = 1, 12 do
    local tab = N("AuctionFrameTab" .. i)
    if not tab then break end
    if tab.isRXP then
      applyOpenXPLook(tab)
      if tab.Text then
        tab.Text:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
        tab.Text:SetTextColor(1, 1, 1, 1)
      end
    end
  end
  applyOpenXPLook(N("RXPItemUpgradesComparison"))
  -- Inventory manager: harness stand-in — OpenXP shows no backdrop anywhere
  -- here; the charcoal backdrop on the helper frame gives tests an
  -- observable OpenXP state for the one frame OXP-FUI dresses.
  applyOpenXPLook(N("RXPDeleteJunk"))
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
  Refresh = function(_, force) refreshCard(force) end,
  SkinPanels = function() bump("card.SkinPanels")
    HARNESS.ApplyOpenXPLook()
  end,
  SkinPanel = function(_, f) bump("card.SkinPanel"); if f then applyOpenXPLook(f.__raw or f) end end,
  ApplyFonts = function()
    bump("card.ApplyFonts")
    -- card.ApplyFonts re-fonts its remembered fixed text (OpenXPCard.lua
    -- 1898-1908) before SkinPanels/Refresh run.
    local function refont(fs, size)
      if not fs then return end
      fs:SetFont("Fonts\\ARIALN.TTF", size or 12, "OUTLINE")
      fs:SetShadowOffset(0, 0)
    end
    local h = HARNESS.cardBits and HARNESS.cardBits.header
    refont(h and h.zone, 12)
    refont(af.text, 12)
    refont(af.oxpDist, 17)
    refont(af.oxpLabel, 12)
    local t = N("RXPTargetFrame_title")
    if t and t.text then refont(t.text, 12) end
    HARNESS.ApplyOpenXPLook()
  end,
}
addonCard = addon.card

-- The card's CurrentStep() reads this off the addon table.
function addon.GetGuideProgress() return 4 end
addon.currentGuide = { name = "Fake Guide", displayname = "Fake Guide 1-10", steps = {} }

addon.arrowFrame = af
addon.targeting = {
  activeTargetFrame = tf,
  -- OpenXP itself bails out of combat for target-frame rebuilds
  -- (Targeting.lua 1210): so does the fake.
  UpdateTargetFrame = function()
    bump("targeting.UpdateTargetFrame")
    if InCombatLockdown() then return end
    HARNESS.ApplyOpenXPLook()
  end,
  RenderTargetFrameBackground = function() bump("targeting.RenderTargetFrameBackground")
    HARNESS.ApplyTargetsOpenXPLook()
  end,
}
addon.tracker = {
  levelSplits = splits,
  ui = reports,
  UpdateLevelSplits = function() bump("tracker.UpdateLevelSplits"); HARNESS.ApplyOpenXPLook() end,
  -- A rebuild recreates the frame family with OpenXP's own look
  -- (CreateLevelSplits early-outs to UpdateLevelSplits when it exists).
  CreateLevelSplits = function() bump("tracker.CreateLevelSplits"); HARNESS.ApplyOpenXPLook() end,
}
addon.activeItemFrame = itemFrame
-- UpdateV1IconFrameVisuals (ActiveItemFrame.lua 206-226): the frame and its
-- title strip get the legacy backdrop, the title is re-fonted at 9pt.
addon.activeItemFrame.UpdateVisuals = function() bump("activeItemFrame.UpdateVisuals")
  applyOpenXPLook(N("RXPItemFrame"))
  local itemTitle = N("RXPItemFrame_title")
  if itemTitle then
    applyOpenXPLook(itemTitle)
    if itemTitle.text then
      itemTitle.text:SetFont("Fonts\\ARIALN.TTF", 9, "")
      itemTitle.text:SetTextColor(0.62, 0.64, 0.70, 1)
    end
  end
end
addon.talents = {
  talentsButton = talentsTab,
  menuFrame = talentsMenu,
}
addon.itemUpgrades = {}
addon.inventoryManager = {
  deleteJunkButton = deleteJunkButton,
  DeleteJunkFrame = deleteJunkFrame,
  clickFrame = junkHandler,
}

-- Tooltips (phase 2) — OpenXPTooltips.lua -----------------------------------
-- Mirrors how OpenXP adds quest lines to Blizzard's GameTooltip: the module
-- builds its lines with inline |c hex prefixes (GREEN/GREY/GOLD/WHITE/ORANGE,
-- OpenXPTooltips.lua lines 19-20) inside tips.AddLines (unit tooltips) and
-- tips.AddItemLines (item tooltips), which are pcall'ed from the
-- OnTooltipSetUnit / OnTooltipSetItem script hooks OpenXP registers on the
-- tooltip frames. What gets added is driven by HARNESS.tooltipScenario so
-- tests control what the "guide" knows. Pristine copies let tests simulate
-- OpenXP reinstalling its own functions (a refresh that wipes wraps).
local GREEN, GREY, GOLD, WHITE = "|cFF66BB6A", "|cFF9E9E9E", "|cFFFFC107", "|cFFFFFFFF"
local ORANGE = "|cFFFF8C1A"
local QUEST_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"

HARNESS.tooltipScenario = {
  -- Mob tooltips: items you still need (with the quest they are for) and a
  -- guide step needing the NPC (AddLines, OpenXPTooltips.lua 360-399).
  loot = {
    { name = "Tough Condor Meat", title = "Elixir of Ferocity",
      have = 1, need = 4, done = false, later = 5 },
  },
  kills = {
    { title = "Kobold Vermin", have = 3, need = 8, done = false },
  },
  step = { index = 12, what = "Kill" },
  -- Item tooltips: quests that need the item (AddItemLines, 426-441).
  itemLines = {},
}

local function Progress(have, need, done)
  return ((done or have >= need) and GREEN or WHITE) .. have .. "/" .. need .. "|r"
end

local function Icon(texture, size)
  return "|T" .. tostring(texture) .. ":" .. (size or 14) .. "|t "
end

local tips = {}
addon.openxpTooltips = tips

function tips.AddLines(tooltip, unit)
  bump("tips.AddLines")
  if not unit or not UnitExists(unit) then return end
  if UnitIsPlayer(unit) then return end
  local sc = HARNESS.tooltipScenario or {}
  local added = false
  if UnitCanAttack("player", unit) then
    local loot = sc.loot or {}
    if #loot > 0 then
      tooltip:AddLine(" ")
      tooltip:AddLine(Icon(QUEST_ICON, 16) .. ORANGE .. "Loot for your quests" .. "|r")
      for _, n in ipairs(loot) do
        local left = Icon(QUEST_ICON) .. GOLD .. (n.name or "?") .. "|r"
        tooltip:AddDoubleLine(left, Progress(n.have, n.need, n.done))
        local sub = "    " .. GREY .. n.title
        if n.later then sub = sub .. " (pick up at step " .. n.later .. ")" end
        tooltip:AddLine(sub .. "|r")
      end
      added = true
    else
      for _, q in ipairs(sc.kills or {}) do
        if not added then tooltip:AddLine(" "); added = true end
        tooltip:AddDoubleLine((q.done and GREY or GOLD) .. q.title .. "|r",
                              Progress(q.have, q.need, q.done))
      end
    end
  end
  local step = sc.step
  if step then
    if not added then tooltip:AddLine(" ") end
    tooltip:AddLine(GREEN .. "OpenXP|r step " .. step.index .. GREY .. " - " .. step.what .. "|r")
    added = true
  end
  if added then tooltip:Show() end
end

function tips.AddItemLines(tooltip, itemId)
  bump("tips.AddItemLines")
  if not itemId then return end
  local lines = (HARNESS.tooltipScenario and HARNESS.tooltipScenario.itemLines) or {}
  if #lines == 0 then return end
  tooltip:AddLine(" ")
  tooltip:AddLine(Icon(QUEST_ICON, 20) .. ORANGE .. "QUEST ITEM - DON'T SELL" .. "|r")
  for _, q in ipairs(lines) do
    local left = (q.done and GREY or GOLD) .. q.title .. "|r"
    if q.later then left = left .. GREY .. " (pick up at step " .. q.later .. ")" .. "|r" end
    tooltip:AddDoubleLine(left, Progress(q.have, q.need, q.done))
  end
  -- OpenXP's own gold border on item tooltips (its behaviour, not OXP-FUI's).
  tips.SetBorder(tooltip, 1, 0.55, 0.1)
  tooltip.openxpBorder = true
  tooltip:Show()
end

function tips.SetBorder(tooltip, r, g, b)
  local ns = tooltip.NineSlice
  if ns and ns.SetBorderColor then
    pcall(ns.SetBorderColor, ns, r, g, b)
  elseif tooltip.SetBackdropBorderColor then
    pcall(tooltip.SetBackdropBorderColor, tooltip, r, g, b)
  end
end

local function ResetBorder(tooltip)
  if tooltip.openxpBorder then
    tooltip.openxpBorder = nil
    local c = _G.TOOLTIP_DEFAULT_COLOR
    tips.SetBorder(tooltip, c and c.r or 1, c and c.g or 1, c and c.b or 1)
  end
end

local function OnUnitTooltip(tooltip)
  if tooltip ~= GameTooltip then return end
  local _, unit = tooltip:GetUnit()
  unit = unit or (UnitExists("mouseover") and "mouseover")
  ResetBorder(tooltip)
  pcall(tips.AddLines, tooltip, unit)
end

local function OnItemTooltip(tooltip)
  if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
  local itemId = HARNESS.tooltipItem and HARNESS.tooltipItem.id or nil
  ResetBorder(tooltip)
  pcall(tips.AddItemLines, tooltip, itemId)
end

GameTooltip:HookScript("OnTooltipSetUnit", OnUnitTooltip)
GameTooltip:HookScript("OnTooltipSetItem", OnItemTooltip)
ItemRefTooltip:HookScript("OnTooltipSetItem", OnItemTooltip)
GameTooltip:HookScript("OnHide", ResetBorder)
ItemRefTooltip:HookScript("OnHide", ResetBorder)

-- Pristine copies of the module functions (before any wrap).
HARNESS.pristineTooltips = { AddLines = tips.AddLines, AddItemLines = tips.AddItemLines }

-- Test drivers: the client fills the tooltip with the game's own lines
-- first, then fires the set-unit/set-item script hooks.
function HARNESS.TooltipSetUnit()
  local fn = GameTooltip:GetScript("OnTooltipSetUnit")
  if fn then fn(GameTooltip) end
end

function HARNESS.TooltipSetItem(tooltip)
  tooltip = tooltip or GameTooltip
  local fn = tooltip:GetScript("OnTooltipSetItem")
  if fn then fn(tooltip) end
end

-- The two windows this harness creates lazily (see the phase 2 section
-- above). Real signatures: welcome.Show(mode, lastSeen) / feedback.Show().
addon.welcome = {
  changelog = {},
  Show = function()
    bump("welcome.Show")
    if not HARNESS.welcome then CreateWelcomeFrame() end
    ResetWelcome()
    HARNESS.welcome.frame:Show()
  end,
}
addon.feedback = {
  Show = function()
    bump("feedback.Show")
    if not HARNESS.feedback then CreateFeedbackFrame() end
    ResetFeedback()
    HARNESS.feedback.frame:Show()
  end,
}

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
  af.text:SetFont("Fonts\\ARIALN.TTF", 9, "OUTLINE")
  af:UpdateVisuals()
  applyOpenXPLook(nil, af.text)
  -- The card wraps addon.SetupArrow and runs card.SetupArrow, which styles
  -- the arrow once and re-points OnUpdate at card.TimedArrow (ArrowUpdate).
  StyleArrow()
  af:SetScript("OnUpdate", ArrowUpdate)
end

af.UpdateVisuals = function()
  bump("arrowFrame.UpdateVisuals")
  af.texture:SetTexture("Interface\\AddOns\\OpenXP\\Textures\\Card\\pointer")
end

addon.DrawArrow = function(self)
  bump("DrawArrow")
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

-- addon:OnInitialize calls addon.SetupArrow() (RXPGuides.lua:1572) — the
-- card's wrapper styles the dial and installs the per-frame update.
addon.SetupArrow()

-- Advance the arrow by one frame: run whatever OnUpdate script OpenXP (or a
-- skin under test) currently has installed, exactly like the client would.
function HARNESS.ArrowTick()
  local script = af:GetScript("OnUpdate")
  if script then script(af, 1 / 60) end
end
