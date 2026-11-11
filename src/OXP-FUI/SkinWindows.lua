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
--     Blizzard's tabs never get the flag and are never touched. Verify in
--     game that the flag still marks OpenXP's tab: if it is absent the skin
--     must skip the tab rather than guess by number (which could dress a
--     Blizzard tab). The hidden
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
-- Talents
-- ---------------------------------------------------------------------------

OXPFUI.RegisterSkin{
  name = "talents",
  windows = { "talents" },
  Apply = function(ctx)
    -- OpenXP's tab on Blizzard's talent frame: the square box art behind
    -- the logo takes the bronze tint; logo and hover highlight stay as
    -- OpenXP drew them. The level tags on Blizzard's talent rows are out of
    -- reach on purpose (see the file header).
    local tab = ctx.Frame("PlayerTalentFrameRXPTalents")
    if tab then
      if type(tab.bg) == "table" and tab.bg.SetVertexColor then
        local b = theme.C.BORDER
        tab.bg:SetVertexColor(b[1], b[2], b[3])
      end
    end

    -- The right-click menu: the anchor now, the visible list frame once the
    -- menu has been opened at least once (created lazily by the menu code).
    local menu = ctx.Frame("RXP_TalentsMenuFrame")
    if menu then theme.ApplyBackdrop(menu) end
    local list = ctx.Frame("RXP_TalentsMenuFrameListFrame")
    if list then theme.ApplyBackdrop(list) end
  end,
}

-- ---------------------------------------------------------------------------
-- Item upgrades
-- ---------------------------------------------------------------------------

OXPFUI.RegisterSkin{
  name = "upgrades",
  windows = { "upgrades" },
  Apply = function(ctx)
    -- The stat-diff comparison tooltip OpenXP builds for itself. Its text
    -- lines are re-styled by the tooltip machinery on every fill, so only
    -- the chrome is skinned.
    local tip = ctx.Frame("RXPItemUpgradesComparison")
    if tip then theme.ApplyBackdrop(tip) end

    -- OpenXP's Auction House tab. Blizzard's tabs share the AuctionFrameTab
    -- numbering, so the frames are told apart by OpenXP's own isRXP flag;
    -- unflagged tabs are never touched.
    for i = 1, 12 do
      local name = "AuctionFrameTab" .. i
      local raw = _G[name]
      if raw == nil then break end
      if raw.isRXP == true then
        local tab = ctx.Frame(name)
        if tab then
          theme.ApplyBackdrop(tab)
          local text = ctx.Frame(name .. "Text")
          if text then
            theme.ApplyFontString(text, "title")
            theme.ApplyTextColor(text, "TITLE")
          end
        end
      end
    end
  end,
}

-- ---------------------------------------------------------------------------
-- Inventory manager
-- ---------------------------------------------------------------------------

OXPFUI.RegisterSkin{
  name = "inventory",
  windows = { "inventory" },
  Apply = function(ctx)
    -- No visible window exists (InventoryManager.lua): dress the helper
    -- frame so it matches if OpenXP ever shows it. The invisible keybind
    -- button and the hidden full-screen click passthrough are left alone —
    -- a backdrop on the passthrough would flash on screen while it catches
    -- the delete click.
    local f = ctx.Frame("RXPDeleteJunk")
    if f then theme.ApplyBackdrop(f) end
  end,
}

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
