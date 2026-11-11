-- OXP-FUI · WelcomeFeedback: skins for OpenXP's welcome / what's-new window
-- and feedback window (spec stories 13-14, phase 2).
--
-- Both windows are flat charcoal-and-blue panels with mostly unnamed
-- children, created lazily the first time OpenXP shows them. The skins
-- restyle what OpenXP built, in place, without touching layout:
--   * window backdrop: FlareUI border art tinted bronze, warm dark fill at
--     the panel opacity setting (theme.ApplyBackdrop);
--   * typography: Friz Quadrata 13/12/11 by role with a 1px shadow, no
--     outline, honouring the chosen font (theme.ApplyFontString);
--   * palette mapping: OpenXP's blue accent becomes FlareUI bronze, its
--     text greys become the FlareUI greys (MapTextColor);
--   * chrome: OpenXP's flat buttons get the bronze box-button look, its
--     sub-panels and link boxes a bronze hairline inset, and textures it
--     painted accent blue (header divider, logo glow) are retinted bronze.
-- Missing frames or children are skipped quietly; nothing is moved or
-- resized, and no layout call is ever made.

local ADDON_NAME, OXPFUI = ...
local theme = OXPFUI.theme

-- ---------------------------------------------------------------------------
-- OpenXP child walking (both windows keep almost every child unnamed)
-- ---------------------------------------------------------------------------

-- The real API returns GetChildren/GetRegions as a vararg while the test
-- stub returns a table; normalize both into a list.
local function CallList(obj, method)
  if type(obj) ~= "table" or type(obj[method]) ~= "function" then return {} end
  local packed = { obj[method](obj) }
  local first = packed[1]
  if #packed == 1 and type(first) == "table" and first[1] ~= nil then
    return first
  end
  return packed
end

local function IsType(obj, objectType)
  return type(obj) == "table" and type(obj.IsObjectType) == "function"
    and obj:IsObjectType(objectType)
end

local function FontStringsOf(frame)
  local out = {}
  for _, r in ipairs(CallList(frame, "GetRegions")) do
    if IsType(r, "FontString") then out[#out + 1] = r end
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Palette mapping: OpenXP's own window palette -> FlareUI palette
-- ---------------------------------------------------------------------------

-- OpenXP's WelcomeFrame.lua / Feedback.lua COLORS tables. Its blue accent
-- becomes FlareUI bronze (spec: "OpenXP's blue accent becomes FlareUI
-- amber/bronze"), its text greys the FlareUI greys. The FlareUI entries map
-- to themselves so re-applying over an already-skinned string is stable
-- (some OpenXP refresh paths restyle nothing before we run again).
local PALETTE_MAP = {
  { from = { 90 / 255, 184 / 255, 1 }, to = "ZONE" },    -- accent blue -> bronze
  { from = { 0.86, 0.86, 0.9 }, to = "OBJECTIVE" },      -- body text grey
  { from = { 0.6, 0.62, 0.7 }, to = "DIM" },             -- muted grey
  { from = theme.C.ZONE, to = "ZONE" },
  { from = theme.C.OBJECTIVE, to = "OBJECTIVE" },
  { from = theme.C.DIM, to = "DIM" },
}
local EPS = 1 / 64

local function NearColor(r, g, b, target)
  return math.abs(r - target[1]) <= EPS
    and math.abs(g - target[2]) <= EPS
    and math.abs(b - target[3]) <= EPS
end

-- Recolour a font string by the OpenXP colour it currently wears; anything
-- unknown lands on FlareUI body grey.
local function MapTextColor(fs)
  local r, g, b = fs:GetTextColor()
  for _, m in ipairs(PALETTE_MAP) do
    if r and NearColor(r, g, b, m.from) then
      return theme.ApplyTextColor(fs, m.to)
    end
  end
  return theme.ApplyTextColor(fs, "OBJECTIVE")
end

-- Retint textures OpenXP painted accent blue (the welcome divider and logo
-- glow), keeping their alpha; everything else is left alone.
local function RetintAccentTexture(tex)
  if not tex or type(tex.GetVertexColor) ~= "function" then return end
  local r, g, b, a = tex:GetVertexColor()
  if not r then return end
  local accent = PALETTE_MAP[1].from
  if NearColor(r, g, b, accent) then
    local c = theme.C.ZONE
    tex:SetVertexColor(c[1], c[2], c[3], a)
  end
end

-- ---------------------------------------------------------------------------
-- Window bodies
-- ---------------------------------------------------------------------------

-- Style one child of a skinned window by what OpenXP built: flat buttons
-- become bronze box buttons, link edit boxes and sub-panels bronze hairline
-- insets with their texts re-typographed. CheckButtons and Blizzard template
-- chrome (UIPanelCloseButton, the scroll frame and its scrollbar) are left
-- as they are. `inner` recurses one level, for the panels inside the
-- feedback window that hold the link boxes and the action button.
local function StyleChild(child, inner)
  local objectType = type(child.GetObjectType) == "function" and child:GetObjectType() or nil
  if objectType == "Button" then
    theme.ApplyBoxButton(child)
  elseif objectType == "EditBox" then
    -- An edit box's text is not a font-string region: the box itself takes
    -- the font/colour calls.
    theme.ApplyInsetBackdrop(child)
    theme.ApplyFontString(child, "body")
    MapTextColor(child)
  elseif objectType == "Frame" and child.GetBackdrop and child:GetBackdrop() then
    theme.ApplyInsetBackdrop(child)
  else
    return
  end
  for _, fs in ipairs(FontStringsOf(child)) do
    theme.ApplyFontString(fs, "body")
    MapTextColor(fs)
  end
  if inner and objectType == "Frame" then
    for _, grand in ipairs(CallList(child, "GetChildren")) do
      StyleChild(grand, false)
    end
  end
end

-- FlareUI typography and palette over every text a window shows. The window
-- titles are OpenXP's white headline strings; they become FlareUI gold
-- headers.
local function ApplyWindowTypography(frame, titleText)
  for _, r in ipairs(CallList(frame, "GetRegions")) do
    if IsType(r, "FontString") then
      if r.GetText and r:GetText() == titleText then
        theme.ApplyFontString(r, "header")
        theme.ApplyTextColor(r, "TITLE")
      else
        theme.ApplyFontString(r, "body")
        MapTextColor(r)
      end
    elseif IsType(r, "Texture") then
      RetintAccentTexture(r)
    end
  end
end

local function ApplyWelcome(ctx)
  local f = ctx.Frame("OpenXPWelcomeFrame")
  if not f then return end
  theme.ApplyBackdrop(f)
  ApplyWindowTypography(f, "OpenXP")
  for _, child in ipairs(CallList(f, "GetChildren")) do
    StyleChild(child, false)
  end
  -- The scrolling body lives on the content frame inside the scroll frame;
  -- OpenXP stores it as a field. (The scroll frame itself is Blizzard
  -- template chrome and is left alone.)
  if IsType(f.body, "FontString") then
    theme.ApplyFontString(f.body, "body")
    MapTextColor(f.body)
  end
  -- Let OpenXP re-paint the route colour swatch fill (it shows the player's
  -- route-line colour; only the hairline is ours).
  if type(f.ShowColor) == "function" then f.ShowColor() end
end

local function ApplyFeedback(ctx)
  local f = ctx.Frame("OpenXPFeedbackFrame")
  if not f then return end
  theme.ApplyBackdrop(f)
  ApplyWindowTypography(f, "Feedback")
  for _, child in ipairs(CallList(f, "GetChildren")) do
    StyleChild(child, true)
  end
end

OXPFUI.RegisterSkin{
  name = "welcome",
  windows = { "welcome" },
  Apply = ApplyWelcome,
}

OXPFUI.RegisterSkin{
  name = "feedback",
  windows = { "feedback" },
  Apply = ApplyFeedback,
}
