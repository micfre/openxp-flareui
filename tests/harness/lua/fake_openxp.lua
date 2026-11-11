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

-- Other phase 2 panels (tracker/active-item tickets) --------------------------
local itemFrame = CreateFrame("Frame", "RXPItemFrame", UIParent, "BackdropTemplate")
local itemTitle = CreateFrame("Frame", "RXPItemFrame_title", itemFrame)
itemTitle.text = itemTitle:CreateFontString(nil, "OVERLAY")
itemFrame.title = itemTitle
local splits = CreateFrame("Frame", "RXPLevelSplits", UIParent, "BackdropTemplate")
local splitsTitle = CreateFrame("Frame", "RXPLevelSplits_title", splits)
splitsTitle.text = splitsTitle:CreateFontString(nil, "OVERLAY")
splits.title = splitsTitle

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
  FrameBackdrop(b, primary and { 28 / 255, 70 / 255, 104 / 255, 1 } or OXP_COLORS.panel,
                primary and OXP_COLORS.accent or OXP_COLORS.border)
  local label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetText(text)
  label:SetTextColor(1, 1, 1, 1)
  b.label = label
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
local rxpFrame = CreateFrame("Frame", "RXPFrame", UIParent, "BackdropTemplate")CreateFrame("Frame", "RXPFrame_bottomFrame", rxpFrame)
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

function HARNESS.ApplyOpenXPLook()
  applyOpenXPLook(N("OpenXPCard"), N("OpenXPCard").header.zone)
  applyOpenXPLook(N("RXPG_ARROW"), N("RXPG_ARROW").text)
  applyOpenXPLook(N("RXPTargetFrame"), N("RXPTargetFrame_title").text)
  -- UpdateTargetFrame rebuilds the secure target rows, restyling them too.
  applyOpenXPLook(N("RXPTargetFrame_EnemyButton1"), N("RXPTargetFrame_EnemyButton1").label)
  applyOpenXPLook(N("RXPItemFrame"), N("RXPItemFrame_title").text)
  applyOpenXPLook(N("RXPLevelSplits"), N("RXPLevelSplits_title").text)
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
    local function refont(fs)
      fs:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
      fs:SetShadowOffset(0, 0)
    end
    refont(N("OpenXPCard").header.zone)
    refont(N("RXPG_ARROW").text)
    refont(N("RXPTargetFrame_title").text)
  end,
}

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
