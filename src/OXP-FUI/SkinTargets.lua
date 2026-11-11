-- OXP-FUI · SkinTargets: the Quest Targets list in the FlareUI look.
--
-- Ticket #5, spec stories 11-12: restyle OpenXP's target mob/NPC frame and
-- its buttons so they match the FlareUI Quest Tracker / guide card, without
-- ever blocking targeting.
--
-- What gets the FlareUI look (appearance only):
--   * RXPTargetFrame   — bronze border + warm dark fill (theme backdrop)
--   * the title strip  — "QUEST TARGETS" in gold header typography, the
--                        keybind hint in dim grey
--   * section labels   — "KILL" / "TALK TO" in FlareUI zone bronze
--   * target rows      — name in light grey body text, keybind hint dim,
--                        the 2px class strip recoloured to the bronze accent
--
-- What never changes: positions and sizes, icons/portraits, highlight
-- textures, click attributes, scripts and keybindings.
--
-- The row buttons are SECURE frames (SecureActionButtonTemplate macro
-- buttons, keybound), so this skin registers with secure = true: the engine
-- applies it only out of combat and defers a requested re-apply to
-- PLAYER_REGEN_ENABLED — the same rule OpenXP follows for its own rebuilds
-- (Targeting.lua bails out of combat too).

local ADDON_NAME, OXPFUI = ...

local theme = OXPFUI.theme

-- FlareUI look for one target row. `raw` is a button taken from OpenXP's own
-- reference lists; ctx.Guard re-applies the engine's rules (name allow/deny,
-- layout blocking) before anything is touched, and missing fields skip
-- quietly (OpenXP updates must never give Lua errors).
local function StyleRow(ctx, raw)
  local btn = ctx.Guard(raw)
  if not btn then return end
  if type(btn.bar) == "table" and btn.bar.SetColorTexture then
    local c = theme.C.ZONE -- bronze accent, like every FlareUI strip
    btn.bar:SetColorTexture(c[1], c[2], c[3], 1)
  end
  if type(btn.label) == "table" and btn.label.SetFont then
    theme.ApplyFontString(btn.label, "body")
    theme.ApplyTextColor(btn.label, "OBJECTIVE")
  end
  if type(btn.key) == "table" and btn.key.SetFont then
    theme.ApplyFontString(btn.key, "body")
    theme.ApplyTextColor(btn.key, "DIM")
  end
end

OXPFUI.RegisterSkin{
  name = "targets",
  windows = { "targets" },
  secure = true,
  Apply = function(ctx)
    local f = ctx.Frame("RXPTargetFrame")
    if f then theme.ApplyBackdrop(f) end

    local title = ctx.Frame("RXPTargetFrame_title")
    if title then
      if title.text then
        theme.ApplyFontString(title.text, "header")
        theme.ApplyTextColor(title.text, "TITLE")
      end
      if title.keyHint then
        theme.ApplyFontString(title.keyHint, "body")
        theme.ApplyTextColor(title.keyHint, "DIM")
      end
    end

    -- Rows and section labels are reached through OpenXP's addon table (the
    -- buttons are created on demand and kept in these reference lists).
    local openxp = ctx.OpenXP()
    local tf = openxp and openxp.targeting and openxp.targeting.activeTargetFrame
    if type(tf) ~= "table" then return end
    if type(tf.sections) == "table" then
      for _, fs in pairs(tf.sections) do
        if type(fs) == "table" and fs.SetFont then
          theme.ApplyFontString(fs, "title")
          theme.ApplyTextColor(fs, "ZONE")
        end
      end
    end
    for _, listName in ipairs({ "enemyTargetButtons", "friendlyTargetButtons" }) do
      if type(tf[listName]) == "table" then
        for _, raw in ipairs(tf[listName]) do
          StyleRow(ctx, raw)
        end
      end
    end
  end,
}
