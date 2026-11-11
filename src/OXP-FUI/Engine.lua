-- OXP-FUI · Engine: the skin engine.
--
-- Extension points for skin modules (see the follow-up window tickets):
--   OXPFUI.RegisterSkin{ name, windows, secure, Apply(ctx) }
--     - name:    string id used in the debug report
--     - windows: list of per-window switch keys (OXPFUI.WINDOWS) gating it
--     - secure:  true when the skin touches secure frames (Quest Targets
--                buttons, item buttons); those are deferred out of combat
--     - Apply:   called with a ctx (below); runs inside a protected call,
--                a failed skin never breaks the others
--   ctx:Frame("GlobalName") -> guarded frame or nil
--     - nil (and a debug-log skip entry) when missing, excluded, or not an
--       OpenXP-owned name; never returns Map/Minimap/settings/legacy/Blizzard
--       frames or other addons' frames
--   ctx.Guard(rawFrame)     -> guarded frame or nil (same rules, for frames
--     reached by walking OpenXP's addon table; denied names return nil)
--   ctx.OpenXP()            -> OpenXP's shared addon table (may be nil)
--   ctx.theme / ctx.db      -> OXPFUI.theme / OXPFUI.db
--
-- Guarded frames refuse layout calls (SetPoint/SetSize/SetWidth/SetHeight/
-- SetScale/...): OXP-FUI never moves or resizes an OpenXP frame, by
-- construction; the attempt is logged for /oxpfui debug. A guarded frame
-- carries the real frame in .__raw, so skins (and Theme chrome recipes)
-- parent and anchor their own textures to the frame the client knows.
--
-- After login the engine post-hooks OpenXP's refresh/rebuild calls
-- (RenderFrame, ReloadTheme, SetupArrow, arrowFrame.UpdateVisuals,
-- card.Refresh/SkinPanels/SkinPanel/ApplyFonts, targeting updates, tracker
-- splits, active-item visuals) and re-applies every skin after each one, so
-- OXP-FUI always wins over OpenXP's own theme, font and outline settings.

local ADDON_NAME, OXPFUI = ...

local InCombatLockdown = InCombatLockdown

-- Names OXP-FUI must never touch (spec exclusions), by exact match or
-- prefix. Enforced centrally in ctx.Frame/ctx.Guard.
local DENIED_EXACT = {
  GameTooltip = true, ItemRefTooltip = true,
  WorldMapFrame = true, Minimap = true,
}
local DENIED_PREFIXES = {
  "RXPFrame",          -- hidden legacy RestedXP guide window and children
  "RXPG_MenuFrame",    -- its menu (also used by the card)
  "RXP_MMMenuFrame",   -- minimap button menu
  "RXP_WMMenuFrame",   -- world-map button and its menu
  "GameTooltip",
  "ItemRefTooltip",
  "WorldMapFrame",
  "Minimap",
}

-- The OpenXP-owned global names skins may ask for (allowlist). Everything
-- else — other addons, Blizzard frames — is refused.
local ALLOWED_PREFIXES = {
  "OpenXPCard",
  "RXPG_ARROW",
  "RXPTargetFrame",
  "OpenXPTargetMobs",
  "OpenXPTargetNPCs",
  "OpenXPWelcomeFrame",
  "OpenXPFeedbackFrame",
  "RXPLevelSplits",
  "RXPG_SplitsMenuFrame",
  "RXPG_LevelMenuFrame",
  "PlayerTalentFrameRXPTalents",
  "RXP_TalentsMenuFrame",
  "RXPItemFrame",
  "RXPItemUpgradesComparison",
  "RXPTELEPORTTO",
  "RXPTELEPORTHOME",
  "RXPDeleteJunk",
  "RXPInventory_DeleteJunk",
  "RXPJunkHandler",
  "AuctionFrameTab", -- item-upgrades tab buttons (skin must check isRXP)
}

local function startswith(s, prefix)
  return s:sub(1, #prefix) == prefix
end

local function DeniedName(name)
  if DENIED_EXACT[name] then return true end
  for _, p in ipairs(DENIED_PREFIXES) do
    if startswith(name, p) then return true end
  end
  return false
end

local function AllowedName(name)
  if DeniedName(name) then return false end
  for _, p in ipairs(ALLOWED_PREFIXES) do
    if startswith(name, p) then return true end
  end
  return false
end

-- Layout methods blocked on guarded frames (OXP-FUI is appearance-only).
local BLOCKED_LAYOUT = {
  SetPoint = true, SetAllPoints = true, ClearAllPoints = true,
  SetSize = true, SetWidth = true, SetHeight = true,
  SetScale = true, SetMaxResize = true, SetMinResize = true,
  StartMoving = true, StartSizing = true, StopMovingOrSizing = true,
  SetUserPlaced = true, SetDontSavePosition = true, SetClampedToScreen = true,
}

-- ---------------------------------------------------------------------------
-- Debug log (the ONLY thing that ever reaches chat is DebugReport, and only
-- when the user asks for it)
-- ---------------------------------------------------------------------------

local logEntries = {} -- { type, skin, info }
local blockedCount = 0
local blockedLatest = nil

local function Log(entryType, skin, info)
  logEntries[#logEntries + 1] = { type = entryType, skin = skin, info = info }
  if #logEntries > 500 then table.remove(logEntries, 1) end
end

-- ---------------------------------------------------------------------------
-- Skin registry
-- ---------------------------------------------------------------------------

local skins = {} -- registration order

function OXPFUI.RegisterSkin(def)
  if type(def) ~= "table" or type(def.name) ~= "string"
    or type(def.Apply) ~= "function" then
    Log("invalid", def and def.name or "?", "bad skin definition")
    return
  end
  def.windows = def.windows or {}
  -- Unknown window keys could never be switched off: say so in /oxpfui debug.
  for _, w in ipairs(def.windows) do
    local known = false
    for _, key in ipairs(OXPFUI.WINDOWS) do
      if key == w then known = true end
    end
    if not known then
      Log("invalid", def.name, "unknown window key '" .. tostring(w) .. "'")
    end
  end
  skins[#skins + 1] = def
end

-- ---------------------------------------------------------------------------
-- Guarded frame access
-- ---------------------------------------------------------------------------

local function NoteBlocked(skinName, frameName, method)
  blockedCount = blockedCount + 1
  blockedLatest = skinName .. " -> " .. frameName .. ":" .. method
  Log("blocked", skinName, frameName .. ":" .. method)
end

local function Guard(raw, name, skinName)
  return setmetatable({ __raw = raw, __guardname = name }, {
    __index = function(_, k)
      local v = raw[k]
      if BLOCKED_LAYOUT[k] then
        return function()
          NoteBlocked(skinName, name, k)
        end
      end
      return v
    end,
    __newindex = function(_, k, v) raw[k] = v end,
  })
end

-- ---------------------------------------------------------------------------
-- Engine state
-- ---------------------------------------------------------------------------

local openxp = nil        -- OpenXP's shared addon table (fake or real)
local openxpVersion = nil
local state = {
  ready = false,        -- PLAYER_LOGIN seen
  openxpFound = false,
  passes = 0,
  lastReason = "none",
  deferred = false,     -- a secure skin is waiting for combat to end
}

local function GetOpenXP()
  local ok, result = pcall(function()
    local LibStub = _G.LibStub
    if not LibStub then return nil end
    local ace = LibStub("AceAddon-3.0", true)
    if not ace then return nil end
    return ace:GetAddon("OpenXP")
  end)
  if ok then return result end
  return nil
end

function OXPFUI.GetOpenXP()
  return openxp
end

function OXPFUI.OpenXPVersion()
  if openxp then
    return openxp.openxpVersion
      or (GetAddOnMetadata and GetAddOnMetadata("OpenXP", "Version"))
      or nil
  end
  return openxpVersion
end

-- ---------------------------------------------------------------------------
-- Apply passes
-- ---------------------------------------------------------------------------

local function WindowGates(def)
  local db = OXPFUI.db
  if not db or not db.enabled then
    return false, "master switch is off"
  end
  if not state.openxpFound then
    return false, "OpenXP not found"
  end
  for _, w in ipairs(def.windows) do
    if db.windows[w] == false then
      return false, "window '" .. w .. "' is switched off"
    end
  end
  return true
end

local function ApplySkin(def, reason)
  local allowed, why = WindowGates(def)
  if not allowed then
    Log("skip", def.name, why)
    return
  end
  if def.secure and InCombatLockdown() then
    state.deferred = true
    Log("deferred", def.name, "in combat (secure skin)")
    return
  end

  local ctx
  ctx = {
    theme = OXPFUI.theme,
    db = OXPFUI.db,
    OpenXP = function() return openxp end,
    -- Called dot-style: ctx.Frame("GlobalName") / ctx.Guard(rawFrame).
    Frame = function(name)
      local raw = name and _G[name]
      if raw == nil then
        Log("skip", def.name, "missing frame " .. tostring(name))
        return nil
      end
      if not AllowedName(name) then
        Log("skip", def.name, "frame not skinnable: " .. name)
        return nil
      end
      return Guard(raw, name, def.name)
    end,
    Guard = function(raw)
      if type(raw) ~= "table" then return nil end
      local name = "?"
      if raw.GetName then name = raw:GetName() or "?" end
      if name ~= "?" and not AllowedName(name) then
        Log("skip", def.name, "frame not skinnable: " .. name)
        return nil
      end
      return Guard(raw, name, def.name)
    end,
  }

  local ok, err = pcall(def.Apply, ctx)
  if ok then
    Log("applied", def.name, reason)
  else
    Log("error", def.name, tostring(err))
  end
end

-- Re-run every registered skin. Public: settings changes and tests use it.
function OXPFUI.Reapply(reason)
  if not state.ready then return end
  state.passes = state.passes + 1
  state.lastReason = reason or "?"
  for _, def in ipairs(skins) do
    ApplySkin(def, state.lastReason)
  end
end

-- ---------------------------------------------------------------------------
-- Refresh/rebuild hooks: re-apply the skin whenever OpenXP re-renders, so
-- OXP-FUI always wins over OpenXP's theme/font/outline settings.
-- ---------------------------------------------------------------------------

local hooked = {}

local function HookRefresh(tableOrFrame, key, label)
  if hooked[label] then return end
  local target = tableOrFrame
  if type(target) ~= "table" or type(target[key]) ~= "function" then
    return
  end
  hooked[label] = true
  local ok = pcall(hooksecurefunc, target, key, function()
    OXPFUI.Reapply(label)
  end)
  if not ok then hooked[label] = nil end
end

local function InstallHooks()
  if not openxp then return end
  HookRefresh(openxp, "RenderFrame", "OpenXP RenderFrame")
  HookRefresh(openxp, "ReloadTheme", "OpenXP ReloadTheme")
  HookRefresh(openxp, "SetupArrow", "OpenXP SetupArrow")
  HookRefresh(openxp.card, "Refresh", "card.Refresh")
  HookRefresh(openxp.card, "SkinPanels", "card.SkinPanels")
  HookRefresh(openxp.card, "SkinPanel", "card.SkinPanel")
  HookRefresh(openxp.card, "ApplyFonts", "card.ApplyFonts")
  HookRefresh(openxp.targeting, "UpdateTargetFrame", "targeting.UpdateTargetFrame")
  HookRefresh(openxp.targeting, "RenderTargetFrameBackground", "targeting.RenderTargetFrameBackground")
  HookRefresh(openxp.tracker, "UpdateLevelSplits", "tracker.UpdateLevelSplits")
  HookRefresh(openxp.tracker, "CreateLevelSplits", "tracker.CreateLevelSplits")
  HookRefresh(openxp.activeItemFrame, "UpdateVisuals", "activeItemFrame.UpdateVisuals")
  HookRefresh(openxp.arrowFrame, "UpdateVisuals", "arrowFrame.UpdateVisuals")
end

OXPFUI._InstallHooks = InstallHooks -- exposed for tests/skin development

-- ---------------------------------------------------------------------------
-- Event frame
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame", "OXPFUIEngineFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    OXPFUI.InitDB()
    openxp = GetOpenXP()
    if openxp then
      state.openxpFound = true
      openxpVersion = OXPFUI.OpenXPVersion()
      if not OXPFUI.db.enabled then
        Log("skip", "engine", "master switch off at load: hooks not installed")
      end
    else
      Log("skip", "engine", "OpenXP not found")
    end
  elseif event == "PLAYER_LOGIN" then
    state.ready = true
    if OXPFUI.db and OXPFUI.db.enabled then
      InstallHooks()
    end
    OXPFUI.Reapply("login")
  elseif event == "PLAYER_REGEN_ENABLED" then
    if state.deferred then
      state.deferred = false
      OXPFUI.Reapply("combat ended")
    end
  end
end)

-- ---------------------------------------------------------------------------
-- Debug report (/oxpfui debug)
-- ---------------------------------------------------------------------------

function OXPFUI.DebugReport()
  local L = OXPFUI.L
  local lines = {}
  lines[#lines + 1] = L.debugHeader:format(ADDON_NAME, OXPFUI.version)

  local version = OXPFUI.OpenXPVersion()
  if state.openxpFound and version then
    lines[#lines + 1] = L.debugOpenXP:format(version, OXPFUI.testedOpenXP)
    if version ~= OXPFUI.testedOpenXP then
      lines[#lines + 1] = L.debugVersionDiffers
    end
  else
    lines[#lines + 1] = L.debugOpenXPMissing
  end

  local db = OXPFUI.db or {}
  lines[#lines + 1] = L.debugMaster:format(
    db.enabled and L.debugEnabled or L.debugDisabled)
  if db.windows then
    local parts = {}
    for _, key in ipairs(OXPFUI.WINDOWS) do
      parts[#parts + 1] = key .. "=" .. (db.windows[key] and "on" or "off")
    end
    lines[#lines + 1] = L.debugWindows:format(table.concat(parts, ", "))
  end
  lines[#lines + 1] = L.debugPasses:format(state.passes, state.lastReason)

  -- Per-skin outcome of the latest pass.
  local skips, errs = {}, {}
  for _, e in ipairs(logEntries) do
    if e.type == "skip" or e.type == "deferred" then
      skips[#skips + 1] = e.skin .. " — " .. e.info
    end
    if e.type == "error" then errs[#errs + 1] = e.skin .. " — " .. e.info end
  end
  lines[#lines + 1] = L.debugSkipped:format(#skips > 0 and table.concat(skips, "; ") or L.debugNone)
  lines[#lines + 1] = L.debugErrors:format(#errs > 0 and table.concat(errs, "; ") or L.debugNone)
  lines[#lines + 1] = L.debugBlocked:format(blockedCount, blockedLatest or L.debugNone)

  return table.concat(lines, "\n")
end

-- Whether the installed OpenXP differs from the tested one (nil = unknown).
function OXPFUI.VersionMismatch()
  local version = OXPFUI.OpenXPVersion()
  if not version then return nil end
  if version == OXPFUI.testedOpenXP then return nil end
  return version
end
