-- OXP-FUI · Core: namespace, saved settings, slash commands.
--
-- OXP-FUI restyles OpenXP's windows to the FlareUI Quest Tracker look at
-- runtime. It never modifies OpenXP files, never changes OpenXP layout,
-- positions or sizes, and never touches the world Map, the Minimap,
-- OpenXP's settings windows, the hidden legacy RestedXP window or any
-- Blizzard frame. See Engine.lua for the skin-module extension points.

local ADDON_NAME, OXPFUI = ...

OXPFUI.name = ADDON_NAME
OXPFUI.version = (GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version")) or "dev"
-- The OpenXP version this release was tested against (also in the TOC).
OXPFUI.testedOpenXP = "1.3.48"

-- Exported for skin modules (which are files of this same addon) and tests.
_G.OXPFUI = OXPFUI

-- Per-window switches. Keys are stable identifiers used by skin modules and
-- the settings panel; labels live in Locale.lua.
OXPFUI.WINDOWS = {
  "arrow",      -- waypoint arrow
  "card",       -- guide card + step list
  "targets",    -- Quest Targets list
  "welcome",    -- welcome / what's-new window
  "feedback",   -- feedback window
  "tracker",    -- leveling tracker + level splits
  "talents",    -- talents
  "upgrades",   -- item upgrades
  "inventory",  -- inventory manager
  "activeitems",-- active-item frame
  "tooltips",   -- lines OpenXP adds to mob/NPC tooltips
}

local function defaults()
  local windows = {}
  for _, key in ipairs(OXPFUI.WINDOWS) do windows[key] = true end
  return {
    enabled = true,
    font = "Friz Quadrata", -- key into Theme.FONTS
    opacity = 0.6,          -- panel fill opacity, 0..1
    borderStyle = "Frames", -- Frames | Thick | Thin
    windows = windows,
  }
end

-- Merge saved settings over the defaults in place, so OXPFUIDB always has
-- every key even after new options are introduced.
function OXPFUI.InitDB()
  if type(_G.OXPFUIDB) ~= "table" then _G.OXPFUIDB = {} end
  local db = _G.OXPFUIDB
  local d = defaults()
  for key, value in pairs(d) do
    if db[key] == nil then db[key] = value end
  end
  if type(db.windows) ~= "table" then db.windows = d.windows end
  for _, key in ipairs(OXPFUI.WINDOWS) do
    if db.windows[key] == nil then db.windows[key] = true end
  end
  OXPFUI.db = db
  return db
end

-- /oxpfui — open the settings panel (default).
-- /oxpfui debug — print what was skinned, what was skipped and why.
SLASH_OXPFUI1 = "/oxpfui"
SlashCmdList.OXPFUI = function(msg)
  local cmd = msg and msg:lower():match("^%s*(%S*)") or ""
  if cmd == "debug" then
    print(OXPFUI.DebugReport and OXPFUI.DebugReport() or (ADDON_NAME .. " " .. OXPFUI.version))
  else
    if OXPFUI.OpenPanel then OXPFUI.OpenPanel() end
  end
end
