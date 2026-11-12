-- OXP-FUI · Docking: attach the OpenXP guide card to FlareUI's Quest
-- Tracker, and optionally match the card's width to the tracker's.
--
-- This is the one deliberate, user-controlled exception to "OXP-FUI never
-- moves an OpenXP frame": the skin engine keeps refusing every layout call
-- through its guards (see Engine.lua), but while the attach switch is on
-- AND a live FlareUI Quest Tracker exists (the global frame
-- FlareUI_ObjectiveTracker — FlareUI only creates it when its tracker
-- module is enabled), this module re-anchors the card frame to it:
--   * tracker visible: the card sits at the tracker's far edge — below it
--     (default) or above it — with the configured padding between them,
--     and follows every tracker move/resize by anchoring;
--   * tracker hidden (minimized to a lone "+" button, or hidden while
--     nothing is tracked): the card moves into the tracker's spot — the
--     dock edge becomes the tracker's own near edge, with no padding;
--   * tracker absent (FlareUI not installed, or its tracker module off):
--     the card is not moved at all.
-- A minimized tracker keeps the card open: nothing here ever hides it.
-- While docked, dragging the card is suspended (the dock owns its spot)
-- and the resize grip's position save is repaired, so OpenXP's profile
-- never records a tracker-relative anchor it cannot restore.
-- The separate width switch (off by default) makes the card exactly as
-- wide as the tracker by writing openxp.card.width — the one value
-- OpenXP's own card.Refresh keeps — so the match survives every refresh.
-- Padding is in UI units at the card's own scale; both windows default to
-- scale 1.

local ADDON_NAME, OXPFUI = ...

local Dock = {}
OXPFUI.Dock = Dock

local state = {
  active = false,       -- the card is currently docked
  savedPoint = nil,     -- { point, relativeTo, relativePoint, x, y } at dock
  savedPos = nil,       -- the same in OpenXP's profile format
  matchedWidth = false, -- we last overrove openxp.card.width
  polls = 0,
}

-- OpenXP's own card defaults (OpenXPCard.lua): the fallback width when the
-- profile has none, and the file-load anchor used when the card had no
-- readable point when we docked (only reachable in tests).
local DEFAULT_WIDTH = 330
local MAX_POLLS = 60

local function cardFrame() return _G.OpenXPCard end
local function trackerFrame() return _G.FlareUI_ObjectiveTracker end

local function side()
  local db = OXPFUI.db or {}
  return db.attachSide == "top" and "top" or "bottom"
end

local function padding()
  local db = OXPFUI.db or {}
  local p = tonumber(db.attachPadding)
  if not p then p = 8 end
  if p < 0 then p = 0 elseif p > 128 then p = 128 end
  return math.floor(p + 0.5)
end

local function trackerVisible(tracker)
  local ok, v = pcall(function() return tracker:IsVisible() end)
  if ok then return v and true or false end
  ok, v = pcall(function() return tracker:IsShown() end)
  if ok then return v and true or false end
  return true
end

-- ---------------------------------------------------------------------------
-- Position
-- ---------------------------------------------------------------------------

-- The dock anchor for the current side and the tracker's visibility.
-- Visible: the tracker's far edge, padding away. Hidden: the tracker's own
-- near edge on the dock side, so the card takes the tracker's spot.
local function anchorFor(top, visible)
  if top then
    if visible then return "BOTTOMLEFT", "TOPLEFT", padding() end
    return "BOTTOMLEFT", "BOTTOMLEFT", 0
  end
  if visible then return "TOPLEFT", "BOTTOMLEFT", -padding() end
  return "TOPLEFT", "TOPLEFT", 0
end

local function applyPoint(f, tracker)
  local point, trackerPoint, y = anchorFor(side() == "top", trackerVisible(tracker))
  -- Idempotent: skip the relayout while the dock anchor is already in
  -- place (Update runs again on every OpenXP refresh).
  local ok, n = pcall(f.GetNumPoints, f)
  if ok and type(n) == "number" and n > 0 then
    local pt, rel, rpt, x, yy = f:GetPoint(1)
    if pt == point and rel == tracker and rpt == trackerPoint
      and (x or 0) == 0 and math.abs((yy or 0) - y) < 0.01 then
      return
    end
  end
  f:ClearAllPoints()
  f:SetPoint(point, tracker, trackerPoint, 0, y)
end

-- ---------------------------------------------------------------------------
-- Width match
-- ---------------------------------------------------------------------------

local function matchWidth(f, tracker, openxp)
  local ok, w = pcall(tracker.GetWidth, tracker)
  if not (ok and type(w) == "number" and w >= 40) then return end
  -- OpenXP's card.Refresh sizes the frame to card.width on every pass, so
  -- the match is written there; the immediate SetWidth covers the calls
  -- between passes. OpenXP's min/max resize bounds apply to user resizing,
  -- not to this: the match is exact.
  local cardModule = openxp and openxp.card or nil
  if cardModule then cardModule.width = w end
  local okw, cw = pcall(f.GetWidth, f)
  if not okw or cw ~= w then f:SetWidth(w) end
  state.matchedWidth = true
end

local function restoreWidth(f, openxp)
  local cardModule = openxp and openxp.card or nil
  local profile = openxp and openxp.settings and openxp.settings.profile or nil
  local w = profile and tonumber(profile.openxpCardWidth) or nil
  if cardModule then cardModule.width = w end
  if not w then w = DEFAULT_WIDTH end
  f:SetWidth(w)
  state.matchedWidth = false
end

-- ---------------------------------------------------------------------------
-- Drag suspension + grip save repair
-- ---------------------------------------------------------------------------

local dragWrapped = {} -- cardFrame -> original OnDragStart (false: none)
local gripHooked = {}  -- gripFrame -> true

local function suspendDrag(f)
  if dragWrapped[f] ~= nil then return end
  local orig = f.GetScript and f:GetScript("OnDragStart") or nil
  dragWrapped[f] = orig or false
  f:SetScript("OnDragStart", function(self, ...)
    if state.active then return end -- the dock owns the card's spot
    if orig then return orig(self, ...) end
  end)
end

local function restoreDrag(f)
  local orig = dragWrapped[f]
  if orig == nil then return end
  f:SetScript("OnDragStart", orig or nil)
  dragWrapped[f] = nil
end

-- OpenXP's resize grip saves the card's anchor to its profile on mouse-up;
-- docked, that anchor is tracker-relative, which OpenXP cannot restore (it
-- re-anchors everything to UIParent on load). Post-hook the save and put
-- the captured pre-dock position back into the profile.
local function hookGrip(openxp)
  local grip = openxp and openxp.card and openxp.card.grip or nil
  if not grip or gripHooked[grip] or not grip.HookScript then return end
  gripHooked[grip] = true
  grip:HookScript("OnMouseUp", function()
    if not (state.active and state.savedPos) then return end
    local profile = openxp.settings and openxp.settings.profile or nil
    if profile then
      local s = state.savedPos
      profile.openxpCardPos = { s[1], s[2], s[3], s[4] }
    end
  end)
end

-- ---------------------------------------------------------------------------
-- Tracker hooks
-- ---------------------------------------------------------------------------

local hookedTracker = nil

local function hookTracker(tracker)
  if hookedTracker == tracker then return end
  hookedTracker = tracker
  -- Show/Hide cover the spot <-> dock transition (minimize styles, the
  -- hide-when-empty setting); SetWidth covers tracker width changes while
  -- the width match is on. Moves need no hook: the card is anchored.
  pcall(tracker.HookScript, tracker, "OnShow",
    function() Dock.Update("tracker shown") end)
  pcall(tracker.HookScript, tracker, "OnHide",
    function() Dock.Update("tracker hidden") end)
  if type(tracker.SetWidth) == "function" then
    pcall(hooksecurefunc, tracker, "SetWidth", function()
      Dock.Update("tracker resized")
    end)
  end
end

-- ---------------------------------------------------------------------------
-- Dock / release
-- ---------------------------------------------------------------------------

local function captureAnchor(f)
  local ok, n = pcall(f.GetNumPoints, f)
  if ok and type(n) == "number" and n > 0 then
    local pt, rel, rpt, x, y = f:GetPoint(1)
    state.savedPoint = { pt, rel, rpt, x, y }
    state.savedPos = { pt, rpt, x, y }
  else
    state.savedPoint, state.savedPos = nil, nil
  end
end

local function releasePosition(f)
  if not state.active then return end
  state.active = false
  restoreDrag(f)
  if f and f.SetPoint then
    f:ClearAllPoints()
    local sp = state.savedPoint
    if sp then
      f:SetPoint(sp[1], sp[2], sp[3], sp[4], sp[5])
    else
      -- OpenXP's own file-load anchor: the safest free-floating spot.
      f:SetPoint("RIGHT", UIParent, "RIGHT", -40, 120)
    end
  end
  state.savedPoint, state.savedPos = nil, nil
end

-- Everything off: give the card back its own position and width.
function Dock.Release()
  local f = cardFrame()
  local openxp = OXPFUI.GetOpenXP and OXPFUI.GetOpenXP() or nil
  releasePosition(f)
  if state.matchedWidth and f then restoreWidth(f, openxp) end
end

-- Central evaluation, run at login, on every OpenXP refresh the engine
-- re-applies after, on tracker show/hide/resize and on settings changes.
function Dock.Update(reason)
  local db = OXPFUI.db
  local openxp = OXPFUI.GetOpenXP and OXPFUI.GetOpenXP() or nil
  if not (db and openxp) then return end
  local f = cardFrame()
  local tracker = trackerFrame()
  if db.enabled ~= true or not f or not tracker then
    Dock.Release()
    return
  end
  local attachOn = db.attachTracker ~= false
  local matchOn = db.matchTrackerWidth == true

  if attachOn then
    hookTracker(tracker)
    suspendDrag(f)
    hookGrip(openxp)
    if not state.active then
      captureAnchor(f)
      state.active = true
    end
    applyPoint(f, tracker)
  else
    releasePosition(f)
  end

  -- The width follows the tracker whenever its switch is on, docked or not.
  if matchOn then
    matchWidth(f, tracker, openxp)
  elseif state.matchedWidth then
    restoreWidth(f, openxp)
  end
end

function Dock.IsActive()
  return state.active
end

-- ---------------------------------------------------------------------------
-- Debug report line (/oxpfui debug)
-- ---------------------------------------------------------------------------

function Dock.Status()
  local L = OXPFUI.L
  local db = OXPFUI.db or {}
  if not (OXPFUI.GetOpenXP and OXPFUI.GetOpenXP() and cardFrame()) then
    return L.dockNoOpenXP
  end
  if db.enabled ~= true then
    return L.dockOff
  end
  local tracker = trackerFrame()
  if not tracker then
    return L.dockNoTracker
  end
  if state.active then
    if not trackerVisible(tracker) then
      return L.dockSpot
    end
    return L.dockOn:format(
      side() == "top" and L.dockSideAbove or L.dockSideBelow,
      padding(),
      db.matchTrackerWidth == true and L.dockWidthMatched or L.dockWidthOwn)
  end
  if db.matchTrackerWidth == true then
    return L.dockWidthOnly
  end
  return L.dockOff
end

-- ---------------------------------------------------------------------------
-- Discovery: addon load order between OXP-FUI and FlareUI is not
-- guaranteed, and FlareUI builds its frames at its own PLAYER_LOGIN.
-- ---------------------------------------------------------------------------

local function flareuiInstalled()
  if not GetAddOnMetadata then return false end
  return GetAddOnMetadata("FlareUI", "Version") ~= nil
end

local function pollForTracker()
  if state.polls >= MAX_POLLS then return end
  if trackerFrame() then return end
  state.polls = state.polls + 1
  C_Timer.After(0.5, function()
    if trackerFrame() then
      Dock.Update("tracker appeared")
    else
      pollForTracker()
    end
  end)
end

local eventFrame = CreateFrame("Frame", "OXPFUIDockFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    Dock.Update(event == "PLAYER_LOGIN" and "login" or "entering world")
    -- FlareUI installed but no tracker yet: it may still be loading.
    if flareuiInstalled() then pollForTracker() end
  end
end)
