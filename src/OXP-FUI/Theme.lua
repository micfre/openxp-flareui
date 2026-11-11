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

OXPFUI.theme = theme
