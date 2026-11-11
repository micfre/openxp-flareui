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

-- Phase 2 windows -----------------------------------------------------------
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

function HARNESS.ApplyOpenXPLook()
  applyOpenXPLook(N("OpenXPCard"), N("OpenXPCard").header.zone)
  applyOpenXPLook(N("RXPG_ARROW"), N("RXPG_ARROW").text)
  HARNESS.ApplyTargetsOpenXPLook()
  -- Active-item frame: V1 visuals backdrop the frame and its title strip
  -- and re-font the title (ActiveItemFrame.lua 206-226). Nil-safe so tests
  -- can simulate the frames going missing.
  applyOpenXPLook(N("RXPItemFrame"))
  local itemTitle = N("RXPItemFrame_title")
  if itemTitle then
    applyOpenXPLook(itemTitle, itemTitle.text)
    if itemTitle.text then
      itemTitle.text:SetFont("Fonts\\ARIALN.TTF", 9, "")
      itemTitle.text:SetTextColor(0.62, 0.64, 0.70, 1)
    end
  end
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
    local function refont(fs)
      fs:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
      fs:SetShadowOffset(0, 0)
    end
    refont(N("OpenXPCard").header.zone)
    refont(N("RXPG_ARROW").text)
    local t = N("RXPTargetFrame_title")
    if t and t.text then refont(t.text) end
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
