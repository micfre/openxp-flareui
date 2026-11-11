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

function HARNESS.ApplyOpenXPLook()
  applyOpenXPLook(N("OpenXPCard"), N("OpenXPCard").header.zone)
  -- Like OpenXP's own code (addon.arrowFrame), not a _G lookup: a test may
  -- nil the global to simulate a rename without breaking the fake itself.
  applyOpenXPLook(af, af.text)
  -- The dial/text repaint card.ArrowUpdate does (once the card styled it).
  ArrowPaintOpenXP()
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
  Refresh = function(_, force) bump("card.Refresh"); if force then HARNESS.ApplyOpenXPLook() end end,
  SkinPanels = function() bump("card.SkinPanels")
    HARNESS.ApplyOpenXPLook()
  end,
  SkinPanel = function(_, f) bump("card.SkinPanel"); if f then applyOpenXPLook(f.__raw or f) end end,
  ApplyFonts = function()
    bump("card.ApplyFonts")
    local function refont(fs, size)
      if not fs then return end
      fs:SetFont("Fonts\\ARIALN.TTF", size, "OUTLINE")
      fs:SetShadowOffset(0, 0)
    end
    refont(N("OpenXPCard").header.zone, 12)
    refont(af.text, 12)
    refont(af.oxpDist, 17)
    refont(af.oxpLabel, 12)
    refont(N("RXPTargetFrame_title").text, 12)
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
