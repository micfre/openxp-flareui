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
