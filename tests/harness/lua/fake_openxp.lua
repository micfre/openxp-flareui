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
  applyOpenXPLook(N("RXPG_ARROW"), N("RXPG_ARROW").text)
  applyOpenXPLook(N("RXPTargetFrame"), N("RXPTargetFrame_title").text)
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
