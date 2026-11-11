-- OXP-FUI · SkinTracker: the leveling tracker and its level-splits frame
-- in the FlareUI look.
--
-- Ticket #7, spec story 15: restyle OpenXP's XP/level windows so they match
-- the FlareUI Quest Tracker / guide card.
--
-- What gets the FlareUI look (appearance only):
--   * RXPLevelSplits + its title strip — bronze border + warm dark fill
--     (theme backdrop), the "Level splits" title in gold header typography
--   * the cogwheel button on the title strip — its icon tinted FlareUI bronze
--   * the three splits labels (history / current / total) — FlareUI
--     typography; palette: past splits dim grey (finished), the current
--     split light blue (focused/current), the total light grey
--   * the leveling report panel (OpenXP's AceGUI window attached to the
--     character frame, reached through OpenXP's addon table) — bronze
--     border + warm dark fill, gold window title, gold level-range button
--     text, bronze section headings with bronze-tinted divider art,
--     body text light grey
--
-- What never changes: positions and sizes, text contents, click handlers,
-- dropdown menus, OpenXP's data logic. None of these frames is secure
-- (research notes §6): OpenXP styles them any time, and so may OXP-FUI —
-- even in combat.

local ADDON_NAME, OXPFUI = ...

local theme = OXPFUI.theme

-- FlareUI look for one texture OpenXP draws (heading divider art, the
-- cogwheel icon): tinted to the bronze accent.
local function tintBronze(tex)
  if type(tex) == "table" and tex.SetVertexColor then
    local c = theme.C.ZONE
    tex:SetVertexColor(c[1], c[2], c[3], 1)
  end
end

-- One report container (LevelingTracker.lua 510-633): .label is an AceGUI
-- Heading widget (text in .label, divider art in .left/.right), .data is a
-- Label widget or a map of them. Missing pieces skip quietly.
local REPORT_CONTAINERS = {
  "reachedContainer", "speedContainer", "zonesContainer",
  "sourcesContainer", "teamworkContainer", "extrasContainer",
}

local function styleReportContainer(c)
  if type(c) ~= "table" then return end
  local h = c.label
  if type(h) == "table" then
    theme.ApplyText(h.label, "title", "ZONE")
    tintBronze(h.left)
    tintBronze(h.right)
  end
  local data = c.data
  if type(data) == "table" then
    theme.ApplyText(data.label, "body", "OBJECTIVE")
    for _, w in pairs(data) do
      theme.ApplyText(type(w) == "table" and w.label or nil, "body", "OBJECTIVE")
    end
  end
end

OXPFUI.RegisterSkin{
  name = "tracker",
  windows = { "tracker" },
  Apply = function(ctx)
    -- Level splits frame and its title strip (global names).
    local f = ctx.Frame("RXPLevelSplits")
    if f then
      theme.ApplyBackdrop(f)
      local title = ctx.Frame("RXPLevelSplits_title")
      if title then
        theme.ApplyBackdrop(title)
        theme.ApplyText(title.text, "header", "TITLE")
        local cog = ctx.Frame("RXPLevelSplits_titleCogwheel")
        if cog and cog.GetNormalTexture then
          tintBronze(cog:GetNormalTexture())
        end
      end
      -- The three splits labels: AceGUI Label widgets reached as frame
      -- fields; their font string is .label (LevelingTracker.lua 1073-1095).
      -- Palette by meaning, like the tracker's title lines: finished
      -- history grey, the current split light blue, the total body grey.
      local splitColors = {
        history = "OBJECTIVE_DONE", current = "TITLE_FOCUS", total = "OBJECTIVE",
      }
      for key, color in pairs(splitColors) do
        local w = f[key]
        theme.ApplyText(type(w) == "table" and w.label or nil, "body", color)
      end
    end

    -- The leveling report panel(s): AceGUI widgets reached through
    -- OpenXP's addon table (the window frame is unnamed; its texts hang
    -- off the widget tables). One entry per attachment frame
    -- (CharacterFrame, InspectFrame, ...).
    local openxp = ctx.OpenXP()
    local tracker = openxp and openxp.tracker
    local ui = tracker and tracker.ui
    if type(ui) ~= "table" then return end
    for _, trackerUi in pairs(ui) do
      if type(trackerUi) == "table" then
        local win = ctx.Guard(trackerUi.frame)
        if win then theme.ApplyBackdrop(win) end
        theme.ApplyText(trackerUi.titletext, "header", "TITLE")
        local levelButton = trackerUi.levelButton
        theme.ApplyText(type(levelButton) == "table" and levelButton.text or nil,
          "title", "TITLE")
        local target = trackerUi.target
        theme.ApplyText(type(target) == "table" and target.label or nil,
          "body", "OBJECTIVE")
        for _, key in ipairs(REPORT_CONTAINERS) do
          styleReportContainer(trackerUi[key])
        end
      end
    end
  end,
}
