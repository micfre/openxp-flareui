-- OXP-FUI · Card: the guide card and step list, in the FlareUI Quest
-- Tracker look (ticket #4: bronze border, warm dark fill, gold titles,
-- grey objectives, green completed, blue current, bronze square buttons
-- and a bronze scrollbar over OpenXP's existing controls).
--
-- Everything here is appearance only. The engine's guarded frames refuse
-- layout calls, so this skin cannot move or resize anything OpenXP owns;
-- frames are found by walking OpenXP's own card table and children, and
-- anything missing is skipped quietly (each step re-runs on every pass).

local ADDON_NAME, OXPFUI = ...

local theme = OXPFUI.theme

-- Guarded frames carry the raw frame in .__raw (see Engine.lua): chrome
-- textures created here must be parented and anchored to the real frame.
local function raw(frame)
  if type(frame) ~= "table" then return nil end
  return frame.__raw or frame
end

local function Apply(ctx)
  local f = ctx.Frame("OpenXPCard")
  if not f then return end

  -- Bronze border art + warm near-black fill at the panel opacity setting.
  theme.ApplyBackdrop(f)
end

OXPFUI.RegisterSkin{
  name = "card",
  windows = { "card" },
  Apply = Apply,
}
