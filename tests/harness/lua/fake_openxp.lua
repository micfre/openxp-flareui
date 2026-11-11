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
local card = CreateFrame("Frame", "OpenXPCard", UIParent, "BackdropTemplate")
local cardHeader = CreateFrame("Frame", nil, card)
card.header = cardHeader
card.header.zone = cardHeader:CreateFontString(nil, "OVERLAY")

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

-- Other phase 2 panels (tracker/active-item tickets) --------------------------
local itemFrame = CreateFrame("Frame", "RXPItemFrame", UIParent, "BackdropTemplate")
local itemTitle = CreateFrame("Frame", "RXPItemFrame_title", itemFrame)
itemTitle.text = itemTitle:CreateFontString(nil, "OVERLAY")
itemFrame.title = itemTitle
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
  local card = N("OpenXPCard")
  applyOpenXPLook(card, card and card.header and card.header.zone or nil)
  -- Like OpenXP's own code (addon.arrowFrame), not a _G lookup: a test may
  -- nil the global to simulate a rename without breaking the fake itself.
  applyOpenXPLook(af, af.text)
  -- The dial/text repaint card.ArrowUpdate does (once the card styled it).
  ArrowPaintOpenXP()
  HARNESS.ApplyTargetsOpenXPLook()
  local itemFrame = N("RXPItemFrame")
  applyOpenXPLook(itemFrame, itemFrame and itemFrame.title and itemFrame.title.text or nil)
  HARNESS.ApplySplitsOpenXPLook()
  HARNESS.ApplyReportOpenXPLook()
  ResetWelcome()
  ResetFeedback()
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
  Refresh = function(_, force) bump("card.Refresh"); if force then HARNESS.ApplyOpenXPLook() end end,
  SkinPanels = function() bump("card.SkinPanels")
    HARNESS.ApplyOpenXPLook()
  end,
  SkinPanel = function(_, f) bump("card.SkinPanel"); if f then applyOpenXPLook(f.__raw or f) end end,
  ApplyFonts = function()
    bump("card.ApplyFonts")
    local function refont(fs, size)
      if not fs then return end
      fs:SetFont("Fonts\\ARIALN.TTF", size or 12, "OUTLINE")
      fs:SetShadowOffset(0, 0)
    end
    refont(N("OpenXPCard").header.zone, 12)
    refont(af.text, 12)
    refont(af.oxpDist, 17)
    refont(af.oxpLabel, 12)
    local t = N("RXPTargetFrame_title")
    if t and t.text then refont(t.text, 12) end
  end,
}

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
addon.activeItemFrame.UpdateVisuals = function() bump("activeItemFrame.UpdateVisuals")
  applyOpenXPLook(N("RXPItemFrame"))
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
