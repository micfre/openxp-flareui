-- OXP-FUI · ArrowSkin: the waypoint arrow (RXPG_ARROW) in the FlareUI
-- Quest Tracker look.
--
-- Spec section "Waypoint arrow": no new textures are generated. OpenXP's
-- ring, disc and arrived-check art is near-white and takes a tint directly;
-- the pointer art contains a blue part, so it is desaturated first and then
-- tinted. Ring and pointer become FlareUI amber, the arrived state FlareUI
-- green, the disc FlareUI's warm near-black (an amber disc would hide the
-- amber ring and pointer on the solid opaque disc art). OpenXP's dimmer
-- travelling ring (alpha 0.6, full colour when arrived) is preserved so the
-- arrow keeps its meaning, and the distance/label text keeps OpenXP's
-- content — only colour and font change.
--
-- OpenXP repaints the ring tint and the distance colour from the arrow's
-- OnUpdate handler EVERY FRAME (card.ArrowUpdate). Winning once at login is
-- not enough, so this skin also chains a tiny re-assert onto that handler:
-- OpenXP's own update always runs first, untouched, and the FlareUI colours
-- are re-applied after it. The re-assert does nothing while the skin is
-- switched off, letting OpenXP's per-frame repaint restore its own look.
--
-- OpenXP's arrow position, scale, drag behaviour and logic are never
-- touched: the engine's guarded frame access blocks layout calls, and this
-- file makes none.

local ADDON_NAME, OXPFUI = ...

local theme = OXPFUI.theme
local C = theme.C

-- ---------------------------------------------------------------------------
-- Colouring
-- ---------------------------------------------------------------------------

-- OpenXP's arrived state: the check texture is shown and the pointer hidden
-- (card.ArrowUpdate). Reading that is more robust than re-deriving the
-- distance threshold, and works even when OpenXP changes it.
local function IsArrived(af)
  return af.arrived ~= nil and af.arrived:IsShown()
end

-- The per-frame part: exactly what OpenXP repaints every frame (ring tint
-- and distance colour), re-asserted in FlareUI colours for the state
-- OpenXP itself decided.
local function ReassertTick(af)
  local arrived = IsArrived(af)
  local ring = af.dialRing
  if ring then
    local c = arrived and C.TITLE_DONE or C.ZONE
    local a = arrived and 1 or 0.6
    ring:SetVertexColor(c[1], c[2], c[3], a)
  end
  local dist = af.oxpDist
  if dist then
    local c = arrived and C.TITLE_DONE or C.OBJECTIVE
    dist:SetTextColor(c[1], c[2], c[3], 1)
  end
end

-- Full paint for engine passes (login, OpenXP refresh calls): everything
-- ReassertTick covers, plus the disc, the arrived check, the pointer and
-- the typography. Every piece is independent — a missing field (an OpenXP
-- update that renamed it) skips just that piece.
local function Paint(af)
  ReassertTick(af)

  local disc = af.dialBg
  if disc then
    disc:SetVertexColor(C.FILL[1], C.FILL[2], C.FILL[3], 0.85)
  end

  local check = af.arrived
  if check then
    check:SetVertexColor(C.TITLE_DONE[1], C.TITLE_DONE[2], C.TITLE_DONE[3], 1)
  end

  local pointer = af.texture
  if pointer then
    -- The pointer art contains a blue part: desaturate, then tint amber.
    pointer:SetDesaturated(true)
    pointer:SetVertexColor(C.ZONE[1], C.ZONE[2], C.ZONE[3], 1)
  end

  -- Story 9: distance and label in the chosen FlareUI font with the 1px
  -- shadow, overriding OpenXP's font and OUTLINE settings. The distance is
  -- the arrow's headline number (header size); the label is supporting
  -- body text. Content stays OpenXP's.
  local dist = af.oxpDist
  if dist then
    theme.ApplyFontString(dist, "header")
  end
  local label = af.oxpLabel
  if label then
    theme.ApplyFontString(label, "body")
    theme.ApplyTextColor(label, "OBJECTIVE")
  end
end

-- ---------------------------------------------------------------------------
-- Per-frame re-assert (chained after OpenXP's OnUpdate)
-- ---------------------------------------------------------------------------

local tickHandler = nil -- the currently installed wrapper, for idempotence

local function InstallTick(af)
  local current = af:GetScript("OnUpdate")
  if type(current) ~= "function" then return end -- nothing to preserve
  if current == tickHandler then return end       -- already chained
  local orig = current
  tickHandler = function(self, elapsed)
    orig(self, elapsed) -- OpenXP's arrow logic first, untouched
    local db = OXPFUI.db
    if db and db.enabled and db.windows and db.windows.arrow ~= false then
      pcall(ReassertTick, af) -- never break OpenXP's update
    end
  end
  af:SetScript("OnUpdate", tickHandler)
end

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------

OXPFUI.RegisterSkin{
  name = "arrow",
  windows = { "arrow" },
  Apply = function(ctx)
    local af = ctx.Frame("RXPG_ARROW")
    if not af then return end
    Paint(af)
    InstallTick(af)
  end,
}
