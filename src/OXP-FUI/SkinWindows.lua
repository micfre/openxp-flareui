-- OXP-FUI · SkinWindows: the remaining phase 2 windows in the FlareUI look.
--
-- Ticket #8, spec story 16: restyle the talents surfaces, the item-upgrades
-- surfaces, the inventory manager and the active-item frame so that none of
-- OpenXP's own windows stand out. One file, four skins — each window keeps
-- its own per-window switch key and its own protected-call isolation, exactly
-- like SkinTargets.lua.
--
-- Scope decisions (from the OpenXP 1.3.48 research notes):
--   * Talents: OpenXP's surfaces are the tab button it adds to Blizzard's
--     talent frame (square SpellBook-SkillLineTab box art behind the logo)
--     and its right-click menu. The level tags OpenXP draws on Blizzard's
--     talent rows are left alone on purpose: their names live in Blizzard's
--     PlayerTalentFrameTalent* namespace (allowlisting that prefix would
--     expose Blizzard's own buttons), and OpenXP re-fonts them itself with
--     overlap tuning (sizes 7-10, Talents.lua DrawTalentLevels), so a skin
--     could never durably win there.
--   * Item upgrades: OpenXP's own Auction House tab continues Blizzard's
--     AuctionFrameTab numbering and is told apart by OpenXP's isRXP flag;
--     Blizzard's tabs never get the flag and are never touched. The hidden
--     comparison tooltip OpenXP builds for stat diffs gets the panel look;
--     its text lines are re-styled by the tooltip machinery on every fill,
--     so only the chrome is skinned.
--   * Inventory manager: there is no visible window (InventoryManager.lua
--     builds an invisible keybind button, an input-propagation helper and a
--     hidden full-screen click passthrough). Only the helper frame is
--     dressed — a backdrop on the full-screen passthrough would flash on
--     screen while it catches the delete click.
--   * Active items: the frame gets the FlareUI panel, the title strip
--     becomes a FlareUI header band (panel fill, no border of its own) with
--     the gold header typography. The SECURE item buttons and the hidden
--     teleport buttons keep their icons, attributes and scripts untouched —
--     nothing is styled on them, so the skin needs no combat deferral.
--
-- Positions, sizes, icons, click attributes, scripts and keybindings are
-- never changed by any of the four skins.

local ADDON_NAME, OXPFUI = ...

local theme = OXPFUI.theme

-- ---------------------------------------------------------------------------
-- Active-item frame
-- ---------------------------------------------------------------------------

OXPFUI.RegisterSkin{
  name = "activeitems",
  windows = { "activeitems" },
  Apply = function(ctx)
    local f = ctx.Frame("RXPItemFrame")
    if f then theme.ApplyBackdrop(f) end

    local title = ctx.Frame("RXPItemFrame_title")
    if title then
      -- OpenXP's V1 visuals give the strip its own legacy edge backdrop;
      -- a FlareUI header band sits on the panel fill instead.
      theme.ApplyPanelFill(title)
      if title.text then
        theme.ApplyFontString(title.text, "header")
        theme.ApplyTextColor(title.text, "TITLE")
      end
    end
  end,
}
