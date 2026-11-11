-- OXP-FUI · SkinTooltips: the quest lines OpenXP adds to mob/NPC/item
-- tooltips, in the FlareUI look.
--
-- Ticket #9, spec stories 17-18: colour and font ONLY the extra lines
-- OpenXP adds to Blizzard's GameTooltip/ItemRefTooltip. The tooltip frames
-- themselves are never touched — no backdrop, no size, no position, no
-- strata (spec exclusion list, proven by the story-43 test) — and lines
-- OpenXP did not add (Blizzard's own, other addons' like Questie) keep
-- their own text, font and colour.
--
-- How (research notes, OpenXPTooltips.lua): OpenXP builds its lines with
-- inline |c hex prefixes inside two module functions —
-- openxpTooltips.AddLines (unit tooltips) and openxpTooltips.AddItemLines
-- (item tooltips) — which it calls through the tooltip's
-- OnTooltipSetUnit/OnTooltipSetItem hooks. This skin wraps those two
-- functions on the module table (hooksecure-style: the current value is
-- kept and called first, so OpenXP's behaviour is unchanged). Afterwards
-- exactly the newly added lines — the NumLines() delta — get the FlareUI
-- treatment:
--   * inline colours remapped to the FlareUI palette:
--       ORANGE section header -> zone bronze   GREEN done -> FlareUI green
--       GOLD name/title       -> title gold    WHITE progress -> light grey
--       GREY sub-lines        -> dim grey
--   * FlareUI typography on the line font strings: the chosen font, title
--     size on header lines and body size on the rest, no outline, 1px black
--     shadow at (+1,-1).
-- Everything else is left exactly as-is, including the gold border tint
-- OpenXP itself applies to item tooltips (OpenXP's own behaviour).
--
-- The wrapper checks the master + per-window switches on every call, so
-- lines added while the skin is switched off keep OpenXP's own look. The
-- engine's refresh hooks re-run Apply, which re-installs the wrap whenever
-- OpenXP reinstalls its own functions — a refresh never loses the skin.
-- The engine cannot gate this after the wrap is in place, so the gate is
-- re-checked at tooltip time; Apply itself only keeps the wrap current.
--
-- The skin is not secure (tooltip line font strings are not secure
-- frames): it applies in combat like every other insecure skin.

local ADDON_NAME, OXPFUI = ...

local theme = OXPFUI.theme

-- OpenXP's inline colour codes (OpenXPTooltips.lua 19-20) -> FlareUI palette.
local function Hex(c)
  return string.format("|cFF%02X%02X%02X",
    math.floor(c[1] * 255 + 0.5),
    math.floor(c[2] * 255 + 0.5),
    math.floor(c[3] * 255 + 0.5))
end

local HEADER_CODE = "|cFFFF8C1A" -- OpenXP's ORANGE: the section header lines

local RECOLOR = {
  ["|cFFFF8C1A"] = Hex(theme.C.ZONE),        -- section header -> zone bronze
  ["|cFFFFC107"] = Hex(theme.C.TITLE),       -- name / quest title -> gold
  ["|cFF66BB6A"] = Hex(theme.C.TITLE_DONE),  -- done progress / badge -> green
  ["|cFFFFFFFF"] = Hex(theme.C.OBJECTIVE),   -- progress counters -> light grey
  ["|cFF9E9E9E"] = Hex(theme.C.DIM),         -- sub-lines / suffixes -> dim grey
}

-- Rewrite OpenXP's inline colour codes in a line's text; every other escape
-- (icons |T..|t, |r, other addons' colours) passes through untouched.
local function Recolor(text)
  return (text:gsub("|c%x%x%x%x%x%x%x%x", function(code)
    return RECOLOR[code] or code
  end))
end

-- FlareUI treatment for one tooltip line font string. Header lines (the ones
-- carrying OpenXP's ORANGE code) get title typography and a bronze base
-- colour; the rest get body typography and the light-grey body base colour
-- that shows through the segments OpenXP leaves un-coloured.
local function StyleLine(fs)
  if type(fs) ~= "table" or type(fs.SetText) ~= "function" then return end
  local kind, baseColor = "body", "OBJECTIVE"
  local text = fs.GetText and fs:GetText() or nil
  if type(text) == "string" then
    if text:find(HEADER_CODE, 1, true) then
      kind, baseColor = "title", "ZONE"
    end
    fs:SetText(Recolor(text))
  end
  theme.ApplyFontString(fs, kind)
  theme.ApplyTextColor(fs, baseColor)
end

-- Style exactly the lines with index > firstAdded on this tooltip: the ones
-- OpenXP just added. The line font strings are the game's own globals
-- (<tooltip name>TextLeft/Right<N>); anything missing is skipped quietly.
local function StyleAddedLines(tooltip, firstAdded)
  local name = tooltip.GetName and tooltip:GetName() or nil
  if not name then return end
  local ok, total = pcall(tooltip.NumLines, tooltip)
  if not ok or type(total) ~= "number" then return end
  for i = firstAdded + 1, total do
    StyleLine(_G[name .. "TextLeft" .. i])
    StyleLine(_G[name .. "TextRight" .. i])
  end
end

-- Switches: once the wrap is installed it outlives the engine's apply pass,
-- so it re-checks on its own whether the skin should act.
local function TooltipsEnabled()
  local db = OXPFUI.db
  if not db or not db.enabled then return false end
  local w = db.windows
  return w == nil or w.tooltips ~= false
end

-- One pass of a wrapped OpenXP tooltip function: remember the line count,
-- let OpenXP add its lines unchanged, then style only the new ones. Every
-- step is protected — a tooltip must never become a Lua error (spec
-- robustness).
local function RunPass(original, tooltip, ...)
  local styled = TooltipsEnabled()
    and type(tooltip) == "table"
    and type(tooltip.NumLines) == "function"
  local before = 0
  if styled then
    local ok, n = pcall(tooltip.NumLines, tooltip)
    styled = ok and type(n) == "number"
    before = n or 0
  end
  local ok = pcall(original, tooltip, ...)
  if ok and styled then
    pcall(StyleAddedLines, tooltip, before)
  end
end

-- Wrap bookkeeping: `mine` holds every wrapper this skin installed, so a
-- re-apply never double-wraps, and a wrap is redone only when OpenXP
-- reinstalled its own function in between.
local mine = {}

local function WrapModuleFunction(tips, key)
  local current = tips[key]
  if mine[current] then return true end -- already ours
  if type(current) ~= "function" then return false end
  local original = current
  local function wrapper(tooltip, ...)
    RunPass(original, tooltip, ...)
  end
  mine[wrapper] = true
  tips[key] = wrapper
  return true
end

OXPFUI.RegisterSkin{
  name = "tooltips",
  windows = { "tooltips" },
  Apply = function(ctx)
    local openxp = ctx.OpenXP()
    local tips = openxp and openxp.openxpTooltips
    if type(tips) ~= "table" then
      ctx.Skip("OpenXP tooltip module not found")
      return
    end
    local wrapped = 0
    if WrapModuleFunction(tips, "AddLines") then
      wrapped = wrapped + 1
    else
      ctx.Skip("OpenXP tooltip function AddLines not found")
    end
    if WrapModuleFunction(tips, "AddItemLines") then
      wrapped = wrapped + 1
    else
      ctx.Skip("OpenXP tooltip function AddItemLines not found")
    end
    if wrapped == 0 then return end
  end,
}
