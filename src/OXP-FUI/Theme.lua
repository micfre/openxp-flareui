-- OXP-FUI · Theme: the FlareUI Quest Tracker look, re-implemented.
--
-- Constants and recipes come from FlareUI's objective-tracker module
-- (FlareUI by Malkkav, MIT; art and fonts bundled under Media/ and License/,
-- see License/FlareUI-LICENSE.txt). No FlareUI code is copied — this file is
-- a new implementation of the same API calls.

local ADDON_NAME, OXPFUI = ...

local theme = {}

-- Palette (RGB triples, 0..1). FlareUI ObjectiveTracker constants.
theme.C = {
  ZONE = { 0.80, 0.60, 0.34 },      -- #CC9957 amber/bronze accent, zone headers
  TITLE = { 1, 0.82, 0 },           -- gold: quest and step titles
  TITLE_DONE = { 0.13, 1, 0.13 },   -- green: completed / arrived
  TITLE_FOCUS = { 0.40, 0.80, 1 },  -- light blue: focused / current
  OBJECTIVE = { 0.85, 0.85, 0.85 }, -- body text, light grey
  OBJECTIVE_DONE = { 0.55, 0.55, 0.55 },
  DIM = { 0.55, 0.55, 0.55 },       -- counters and hints
  URGENT = { 1, 0.25, 0.25 },       -- red: urgent / warning
  BOX = { 0.50, 0.38, 0.21 },       -- bronze square buttons at rest
  BOX_LIT = { 0.65, 0.49, 0.27 },   -- bronze square buttons hovered
  BORDER = { 0.65, 0.49, 0.27, 1 }, -- #A67D45 frame border tint
}

-- Typography: header 13 / title 12 / body 11, no outline, 1px black shadow.
theme.FONT_SIZES = { header = 13, title = 12, body = 11 }

-- Bundled and built-in font choices (order = settings panel cycle order).
local MEDIA = "Interface\\AddOns\\OXP-FUI\\Media\\"
theme.FONTS = {
  { key = "Friz Quadrata",   path = "Fonts\\FRIZQT__.TTF" },
  { key = "Asap Condensed",  path = MEDIA .. "Fonts\\AsapCondensed-Regular.ttf" },
  { key = "Barlow Condensed", path = MEDIA .. "Fonts\\BarlowCondensed-Regular.ttf" },
  { key = "Cabin Condensed", path = MEDIA .. "Fonts\\CabinCondensed-Regular.ttf" },
  { key = "Fira Condensed",  path = MEDIA .. "Fonts\\FiraSansExtraCondensed-Regular.ttf" },
  { key = "Roboto Condensed", path = MEDIA .. "Fonts\\RobotoCondensed-Regular.ttf" },
}
theme.DEFAULT_FONT = "Friz Quadrata"

function theme.FontPath(key)
  for _, f in ipairs(theme.FONTS) do
    if f.key == key then return f.path end
  end
  return theme.FONTS[1].path
end

-- Border styles: bundled FlareUI border art, drawn grey and tinted bronze.
-- Thin is drawn at half the edge size (FlareUI's own rule).
theme.BORDERS = {
  Frames = { file = MEDIA .. "Borders\\FlareUI-Frames.tga", edgeSize = 16 },
  Thick = { file = MEDIA .. "Borders\\FlareUI-Thick.tga", edgeSize = 16 },
  Thin = { file = MEDIA .. "Borders\\FlareUI-Thin.tga", edgeSize = 8 },
}
theme.DEFAULT_BORDER = "Frames"

-- The tracker backdrop recipe: Blizzard's dark dialog fill (a warm near-black
-- vertical gradient), FlareUI border art, insets 3, bronze tint, panel
-- opacity from settings. Appearance only — callers never resize the frame.
function theme.ApplyBackdrop(frame)
  local db = OXPFUI.db or {}
  local border = theme.BORDERS[db.borderStyle] or theme.BORDERS[theme.DEFAULT_BORDER]
  local opacity = db.opacity
  if type(opacity) ~= "number" then opacity = 0.6 end
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = border.file,
    tile = false, tileSize = 0, edgeSize = border.edgeSize,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(1, 1, 1, opacity)
  local b = theme.C.BORDER
  frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4])
end

-- Apply the FlareUI typography to a font string: chosen face, size for its
-- kind, no outline, 1px black shadow at (+1, -1).
function theme.ApplyFontString(fs, kind)
  local db = OXPFUI.db or {}
  local size = theme.FONT_SIZES[kind] or theme.FONT_SIZES.body
  fs:SetFont(theme.FontPath(db.font), size, "")
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)
  return fs
end

function theme.ApplyTextColor(fs, colorName)
  local c = theme.C[colorName] or theme.C.OBJECTIVE
  fs:SetTextColor(c[1], c[2], c[3], 1)
end

-- ---------------------------------------------------------------------------
-- Shared FlareUI chrome recipes (procedural, no art files)
-- ---------------------------------------------------------------------------

-- Unwrap an engine-guarded frame to the real frame, so chrome textures are
-- parented and anchored to the frame the client knows (see Engine.lua).
local function realFrame(frame)
  if type(frame) ~= "table" then return nil end
  return frame.__raw or frame
end

-- FlareUI's scrollbar: a 1px faint bronze track down the right margin and a
-- 3px solid bronze thumb, both drawn with colour textures (ObjectiveTracker
-- has no slider art either — its list is mouse-wheel scrolled).
--   frame: the list's frame (guarded or raw)
--   opts.state(): -> fraction (0..1 through the list), visibleRatio
--                 (0..1 of the list that fits), scrollable (bool)
-- Re-applied chrome is reused; nothing is resized except our own textures.
function theme.ApplyScrollBar(frame, opts)
  local rf = realFrame(frame)
  if not (rf and rf.CreateTexture and rf.SetWidth) then return end
  local chrome = rf.oxpfuiScroll
  if not chrome then
    local track = rf:CreateTexture(nil, "ARTWORK")
    track:SetSnapToPixelGrid(false)
    track:SetTexelSnappingBias(0)
    track:SetWidth(1)
    local thumb = rf:CreateTexture(nil, "OVERLAY")
    thumb:SetSnapToPixelGrid(false)
    thumb:SetTexelSnappingBias(0)
    thumb:SetWidth(3)
    chrome = { track = track, thumb = thumb }
    rf.oxpfuiScroll = chrome
  end
  local box = theme.C.BOX
  chrome.track:SetColorTexture(box[1], box[2], box[3], 0.25)
  chrome.thumb:SetColorTexture(box[1], box[2], box[3], 1)
  chrome.track:ClearAllPoints()
  chrome.track:SetPoint("TOPRIGHT", rf, "TOPRIGHT", -6, -30)
  chrome.track:SetPoint("BOTTOMRIGHT", rf, "BOTTOMRIGHT", -6, 8)

  local fraction, visibleRatio, scrollable = 0, 1, false
  if opts and opts.state then
    local ok, frac, ratio, scroll = pcall(opts.state)
    if ok then
      fraction = frac or 0
      visibleRatio = ratio or 1
      scrollable = scroll and true or false
    end
  end
  if fraction < 0 then fraction = 0 elseif fraction > 1 then fraction = 1 end
  if visibleRatio < 0.05 then visibleRatio = 0.05 elseif visibleRatio > 1 then visibleRatio = 1 end

  -- list body height: the frame minus its title row and bottom padding
  local trackHeight = (rf:GetHeight() or 0) - 38
  if trackHeight < 16 then trackHeight = 16 end
  local thumbHeight = trackHeight * visibleRatio
  if thumbHeight < 16 then thumbHeight = 16 end
  local offset = (trackHeight - thumbHeight) * fraction
  chrome.thumb:ClearAllPoints()
  chrome.thumb:SetPoint("TOPRIGHT", chrome.track, "TOPRIGHT", -1, -offset)
  chrome.thumb:SetHeight(thumbHeight)

  if scrollable then
    chrome.track:Show()
    chrome.thumb:Show()
  else
    chrome.track:Hide()
    chrome.thumb:Hide()
  end
end

OXPFUI.theme = theme
