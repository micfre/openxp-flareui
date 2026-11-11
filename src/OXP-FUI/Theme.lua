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
  FILL = { 0.10, 0.08, 0.06 },      -- warm near-black: solid form of the
                                     -- tracker fill's lighter top colour,
                                     -- used where a plain texture is tinted
}

-- OpenXP's own blue accent (90/255, 184/255, 1 — its COLORS tables and the
-- card art it tints), retinted to FlareUI amber/bronze by the card and the
-- welcome/feedback skins. One shared definition — with one shared
-- near-match tolerance — so every skin agrees what counts as "OpenXP blue".
theme.OXP_BLUE = { 90 / 255, 184 / 255, 1 }

-- Near-match tolerance when comparing a vertex/text colour against a
-- palette triple: the palettes are set as exact constants, so this only
-- absorbs float noise.
local COLOR_EPS = 1 / 64

function theme.NearColor(r, g, b, target)
  return math.abs(r - target[1]) <= COLOR_EPS
    and math.abs(g - target[2]) <= COLOR_EPS
    and math.abs(b - target[3]) <= COLOR_EPS
end

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

-- Panel fill opacity from settings; every backdrop recipe shares this
-- default for a missing/non-numeric value.
local DEFAULT_OPACITY = 0.6

local function panelOpacity(db)
  local opacity = db.opacity
  if type(opacity) ~= "number" then opacity = DEFAULT_OPACITY end
  return opacity
end

-- The tracker backdrop recipe: Blizzard's dark dialog fill (a warm near-black
-- vertical gradient), FlareUI border art, insets 3, bronze tint, panel
-- opacity from settings. Appearance only — callers never resize the frame.
function theme.ApplyBackdrop(frame)
  local db = OXPFUI.db or {}
  local border = theme.BORDERS[db.borderStyle] or theme.BORDERS[theme.DEFAULT_BORDER]
  local opacity = panelOpacity(db)
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

-- The header-band variant: FlareUI's tracker header sits on the panel fill
-- with no border of its own (ObjectiveTracker CreateFrames has no separate
-- header background). Used for OpenXP's small title strips that carry their
-- own legacy edge backdrop — the strip blends into the framed panel instead
-- of drawing a second border inside it.
function theme.ApplyPanelFill(frame)
  local db = OXPFUI.db or {}
  local opacity = panelOpacity(db)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = nil,
    tile = false, tileSize = 0, edgeSize = 0,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(1, 1, 1, opacity)
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

-- The canonical "typography + colour" pass over a font string:
-- ApplyFontString(fs, kind) + ApplyTextColor(fs, colorName) in one call,
-- nil-safe, so skins can pass OpenXP fields that a version drift may have
-- renamed or removed (a missing font string is skipped quietly).
function theme.ApplyText(fs, kind, colorName)
  if type(fs) == "table" and fs.SetFont then
    theme.ApplyFontString(fs, kind)
    theme.ApplyTextColor(fs, colorName)
  end
  return fs
end

-- FlareUI's bronze box-button paint (CreateBoxButton in the tracker) applied
-- to an existing BackdropTemplate button: hairline bronze border over a
-- near-black fill, bronze-lit while hovered. OpenXP's own white hover swap
-- runs first (HookScript chains), so the bronze wins. Hooking once per
-- button keeps re-applies from stacking handlers.
function theme.ApplyBoxButton(btn)
  btn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  btn:SetBackdropColor(0, 0, 0, 0.85)
  local rest, lit = theme.C.BOX, theme.C.BOX_LIT
  btn:SetBackdropBorderColor(rest[1], rest[2], rest[3], 1)
  if not btn.__oxpfuiBoxHover then
    btn.__oxpfuiBoxHover = true
    btn:HookScript("OnEnter", function(self)
      self:SetBackdropBorderColor(lit[1], lit[2], lit[3], 1)
    end)
    btn:HookScript("OnLeave", function(self)
      self:SetBackdropBorderColor(rest[1], rest[2], rest[3], 1)
    end)
  end
  return btn
end

-- ---------------------------------------------------------------------------
-- Shared FlareUI chrome recipes (procedural, no art files)
-- ---------------------------------------------------------------------------

-- Unwrap an engine-guarded frame to the real frame, so chrome textures are
-- parented and anchored to the frame the client knows (see Engine.lua).
function theme.RealFrame(frame)
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
  local rf = theme.RealFrame(frame)
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

-- FlareUI's bronze square button, redrawn procedurally (no art file):
-- a bronze outline with chamfered corner steps around a near-black fill,
-- every rect a whole-pixel colour texture with snapping off. Applied over
-- an existing OpenXP button — nothing about the button is moved or resized;
-- the button's own icon and label draw on top. Hover lights the outline to
-- the frame-border bronze (C.BOX -> C.BOX_LIT) via hooked scripts, leaving
-- whatever OpenXP's own OnEnter/OnLeave do untouched.
--   opts.size:   square size in pixels (default 12, FlareUI's header button)
--   opts.offset: {x, y} shift from the button's centre, in pixels
function theme.ApplyBoxButtonPaint(button, opts)
  local rf = theme.RealFrame(button)
  if not (rf and rf.CreateTexture and rf.HookScript) then return end
  opts = opts or {}
  local size = math.floor(opts.size or 12)
  local dx = (opts.offset and opts.offset.x) or 0
  local dy = (opts.offset and opts.offset.y) or 0

  local chrome = rf.oxpfuiBox
  if not chrome then
    local function rect(w, h)
      local t = rf:CreateTexture(nil, "BACKGROUND")
      t:SetSnapToPixelGrid(false)
      t:SetTexelSnappingBias(0)
      t:SetWidth(w)
      t:SetHeight(h)
      return t
    end
    -- half the square, from its centre
    local half = size / 2
    local function place(t, x, y)
      t:SetPoint("TOPLEFT", rf, "CENTER", dx + x, dy + y)
    end
    local outline = {}
    -- four edges
    outline[1] = rect(size, 1);      place(outline[1], -half, half)        -- top
    outline[2] = rect(size, 1);      place(outline[2], -half, -half + 1)   -- bottom
    outline[3] = rect(1, size - 2);  place(outline[3], -half, half - 1)    -- left
    outline[4] = rect(1, size - 2);  place(outline[4], half - 1, half - 1) -- right
    -- four chamfer steps just outside the corners
    outline[5] = rect(2, 1)
    outline[5]:SetPoint("BOTTOMRIGHT", rf, "CENTER", dx - half, dy + half)
    outline[6] = rect(2, 1)
    outline[6]:SetPoint("BOTTOMLEFT", rf, "CENTER", dx + half, dy + half)
    outline[7] = rect(2, 1)
    outline[7]:SetPoint("TOPRIGHT", rf, "CENTER", dx - half, dy - half)
    outline[8] = rect(2, 1)
    outline[8]:SetPoint("TOPLEFT", rf, "CENTER", dx + half, dy - half)
    local fill = rect(size - 2, size - 2)
    fill:SetPoint("TOPLEFT", rf, "CENTER", dx - half + 1, dy + half - 1)
    fill:SetColorTexture(0, 0, 0, 0.85)
    chrome = { size = size, outline = outline, fill = fill }
    rf.oxpfuiBox = chrome
    local function paint(lit)
      local c = lit and theme.C.BOX_LIT or theme.C.BOX
      for _, t in ipairs(chrome.outline) do
        t:SetColorTexture(c[1], c[2], c[3], 1)
      end
    end
    chrome.paint = paint
    rf:HookScript("OnEnter", function() paint(true) end)
    rf:HookScript("OnLeave", function() paint(false) end)
  end
  chrome.paint(false)
end

-- Sub-panel inset: the warm dark fill at a slightly firmer opacity than the
-- window (OpenXP's own sub-panels are a step lighter than their windows),
-- with a bronze hairline instead of border art — the window already wears
-- the border art.
function theme.ApplyInsetBackdrop(frame)
  local db = OXPFUI.db or {}
  local opacity = panelOpacity(db)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  frame:SetBackdropColor(1, 1, 1, math.min(1, opacity + 0.25))
  local c = theme.C.BOX
  frame:SetBackdropBorderColor(c[1], c[2], c[3], 1)
  return frame
end

OXPFUI.theme = theme
