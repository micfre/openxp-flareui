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
  if type(reports) ~= "table" then return end
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
  for _, trackerUi in pairs(reports) do
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
  local af = N("RXPG_ARROW")
  applyOpenXPLook(af, af and af.text or nil)
  HARNESS.ApplyTargetsOpenXPLook()
  local itemFrame = N("RXPItemFrame")
  applyOpenXPLook(itemFrame, itemFrame and itemFrame.title and itemFrame.title.text or nil)
  HARNESS.ApplySplitsOpenXPLook()
  HARNESS.ApplyReportOpenXPLook()
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
