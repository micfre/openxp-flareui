-- OXP-FUI · Locale: every user-visible English string in one table,
-- ready for future locales.

local ADDON_NAME, OXPFUI = ...

local L = {
  -- Settings panel ------------------------------------------------------
  panelTitle = "OXP-FUI",
  panelSubtitle = "FlareUI look for OpenXP",
  masterLabel = "Enable OXP-FUI skin",
  reloadNote = "Turning the skin on or off takes effect after a UI reload (/reload).",
  windowsHeader = "Windows",
  fontLabel = "Font",
  borderLabel = "Border style",
  opacityLabel = "Panel opacity",
  opacityValue = "%d%%",
  closeButton = "Close",
  versionNote = "OpenXP %s was found; this release was tested with %s — something may look off.",
  -- Per-window switch labels (keys = OXPFUI.WINDOWS entries).
  windows = {
    arrow = "Waypoint arrow",
    card = "Guide card and step list",
    targets = "Quest Targets",
    welcome = "Welcome / what's new",
    feedback = "Feedback",
    tracker = "Leveling tracker and splits",
    talents = "Talents",
    upgrades = "Item upgrades",
    inventory = "Inventory manager",
    activeitems = "Active items",
    tooltips = "Tooltip lines",
  },
  -- Debug report --------------------------------------------------------
  debugHeader = "%s %s — debug report",
  debugOpenXP = "OpenXP version: %s (tested with %s)",
  debugVersionDiffers = "OpenXP version differs from the tested one — some windows may look off.",
  debugOpenXPMissing = "OpenXP was not found — nothing can be skinned.",
  debugMaster = "Master switch: %s",
  debugEnabled = "enabled",
  debugDisabled = "disabled",
  debugWindows = "Windows: %s",
  debugPasses = "Apply passes: %d (last: %s)",
  debugNone = "none",
  debugSkipped = "Skipped: %s",
  debugErrors = "Errors: %s",
  debugBlocked = "Blocked layout attempts: %d (latest: %s)",
}

OXPFUI.L = L
