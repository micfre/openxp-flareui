-- OXP-FUI · Card: the guide card and step list, in the FlareUI Quest
-- Tracker look (ticket #4: bronze border, warm dark fill, gold titles,
-- grey objectives, green completed, blue current and a bronze scrollbar;
-- OpenXP's own borderless icon buttons are left as they are).
--
-- Everything here is appearance only. The engine's guarded frames refuse
-- layout calls, so this skin cannot move or resize anything OpenXP owns.
-- OpenXP's card children are unnamed; they are found by walking the card
-- frame's children and matching OpenXP's own field shapes, and anything
-- missing (a renamed frame in a new OpenXP) is skipped quietly.

local ADDON_NAME, OXPFUI = ...

local theme = OXPFUI.theme
local C = theme.C

local function fields(obj, ...)
  if type(obj) ~= "table" then return false end
  for i = 1, select("#", ...) do
    if obj[(select(i, ...))] == nil then return false end
  end
  return true
end

-- OpenXP's blue label accent (a lighter blue it uses on button icons) also
-- becomes amber; the main accent blue itself is theme.OXP_BLUE.
local OXP_BLUE_LABEL = { 159 / 255, 212 / 255, 1 }

local function matches(tex, triple)
  local ok, r, g, b = pcall(tex.GetVertexColor, tex)
  if not ok or r == nil then return false end
  return theme.NearColor(r, g, b, triple)
end

local function setVertex(tex, triple, a)
  -- Real API: SetVertexColor(r, g, b) with no alpha means alpha 1.
  if a == nil then a = 1 end
  if tex and tex.SetVertexColor then tex:SetVertexColor(triple[1], triple[2], triple[3], a) end
end

-- Re-tint a texture only while OpenXP still has it in the blue accent.
local function amberIfBlue(tex, alpha)
  if tex and matches(tex, theme.OXP_BLUE) then setVertex(tex, C.ZONE, alpha) end
end

local function isFontString(fs)
  return fs and fs.SetFont and fs.SetTextColor and true or false
end

-- A step row's / history row's status colour, from OpenXP's own status
-- keys; PILL_COLORS encodes the status -> palette mapping once for the
-- step pills, the history rows and the step-list rows (default varies by
-- caller). A row's status uses OpenXP's own logic when it is reachable
-- and falls back to whatever the frames themselves show.
local PILL_COLORS = {
  done = "TITLE_DONE",
  skipped = "OBJECTIVE_DONE",
  chain = "TITLE",
}

local function pillStatus(pill, openxp)
  local fs = pill and pill.text
  if not isFontString(fs) then return nil end
  local label = fs:GetText()
  if not label or label == "" then return nil end
  local statusTable = openxp and openxp.card and openxp.card.STATUS
  if type(statusTable) == "table" then
    for key, def in pairs(statusTable) do
      if type(def) == "table" and def.text == label then return key end
    end
  end
  return "?"
end

local function skinPill(pill, openxp)
  if not pill then return end
  theme.ApplyText(pill.text, "body", "OBJECTIVE")
  local status = pillStatus(pill, openxp)
  if status and status ~= "?" then
    local colorName = PILL_COLORS[status] or "OBJECTIVE"
    local c = C[colorName]
    theme.ApplyTextColor(pill.text, colorName)
    for _, part in ipairs({ pill.bg, pill.l, pill.r }) do
      setVertex(part, c, 0.16)
    end
  end
end

local function rowStatus(row, openxp)
  if row.current then return nil end
  local addon = openxp
  if fields(addon, "card") and addon.card.StepStatus and row.index and addon.currentGuide then
    local cur = addon.GetGuideProgress and addon.GetGuideProgress() or nil
    local ok, status = pcall(addon.card.StepStatus, addon.card,
      addon.currentGuide, row.index, cur)
    if ok and status then return status end
  end
  if row.pill and row.pill.IsShown and row.pill:IsShown() then return "done" end
  return nil
end

-- ---------------------------------------------------------------------------
-- Element sections
-- ---------------------------------------------------------------------------

local function skinHeader(header)
  theme.ApplyText(header.zone, "zone", "ZONE")
  theme.ApplyText(header.range, "counter", "DIM")
  theme.ApplyText(header.step, "counter", "TITLE")
  setVertex(header.dot, C.ZONE)  -- the blue accent dot becomes amber
  -- header.stepBtn (the invisible hit area over "Step n / n" that opens the
  -- step list) is deliberately left as OpenXP draws it: no chrome.
end

-- FlareUI's header band: a divider texture right under OpenXP's header.
-- Own texture, anchored to the header; the header itself never moves.
local function ensureDivider(cardFrame, header)
  local rf = theme.RealFrame(cardFrame)
  local hf = theme.RealFrame(header)
  if not (rf and rf.CreateTexture and hf) then return end
  local t = rf.oxpfuiDivider
  if not t then
    t = rf:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    t:SetHeight(8)
    t:SetDrawLayer("ARTWORK", 1)
    rf.oxpfuiDivider = t
  end
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", hf, "BOTTOMLEFT", 2, -1)
  t:SetPoint("TOPRIGHT", hf, "BOTTOMRIGHT", -2, -1)
end

local function skinHist(hist, openxp)
  theme.ApplyText(hist.label, "title", "ZONE")
  theme.ApplyText(hist.hint, "body", "DIM")
  for _, row in ipairs(hist.rows or {}) do
    local status = row.status or rowStatus(row, openxp)
    local colorName = PILL_COLORS[status] or "OBJECTIVE"
    theme.ApplyText(row.text, "body", colorName)
    theme.ApplyText(row.num, "body", "DIM")
    skinPill(row.pill, openxp)
  end
end

local function skinBlocks(blocks)
  for _, b in ipairs(blocks or {}) do
    theme.ApplyText(b.title, "title", "TITLE")
    theme.ApplyText(b.num, "body", "DIM")
    -- travel badges are OpenXP's blue ones: amber, other kinds keep meaning
    amberIfBlue(b.badge and b.badge.fill, 0.16)
    amberIfBlue(b.badge and b.badge.ring)
    amberIfBlue(b.badge and b.badge.icon)
    for _, line in ipairs(b.lines or {}) do
      local done = false
      local mark = line.mark
      if mark and mark.GetTexture then
        local ok, tex = pcall(mark.GetTexture, mark)
        done = ok and type(tex) == "string" and tex:find("check", 1, true) ~= nil
      end
      theme.ApplyText(line.text, "body", done and "OBJECTIVE_DONE" or "OBJECTIVE")
      theme.ApplyText(line.count, "body", "DIM")
      if done then setVertex(mark, C.TITLE_DONE) end
      amberIfBlue(line.bar)
    end
  end
end

-- OpenXP sizes every "Up next" line to the card width minus the "UP NEXT"
-- label measured in OpenXP's own font, then the lines hang off the label's
-- right edge. The FlareUI label font is wider, so the lines would start
-- further right but keep the old width and run past the card's right
-- padding (the client's "..." cut included). Each shown line is narrowed by
-- exactly the amount the label grew, which restores OpenXP's right edge;
-- the client then places the "..." inside that width. This is the second
-- place the card skin lays anything out (see BAR_INSET); only the lines'
-- own widths change, and a re-apply with an unchanged label changes nothing.
local function skinUpNext(upNext)
  local label = theme.RealFrame(upNext.label)
  local before = label and label.GetStringWidth and label:GetStringWidth() or nil
  theme.ApplyText(upNext.label, "title", "ZONE")
  local after = label and label.GetStringWidth and label:GetStringWidth() or nil
  local delta = (before and after) and (after - before) or 0
  for _, line in ipairs(upNext.lines or {}) do
    theme.ApplyText(line, "body", "OBJECTIVE")
    local rl = theme.RealFrame(line)
    if delta ~= 0 and rl and rl.IsShown and rl:IsShown() and rl.GetWidth and rl.SetWidth then
      local w = rl:GetWidth()
      if type(w) == "number" and w > 0 then rl:SetWidth(math.max(1, w - delta)) end
    end
  end
end

local function skinBar(bar)
  for _, btn in ipairs({ bar.prev, bar.next, bar.menu, bar.settings,
                         bar.collapse, bar.find, bar.stop, bar.resume }) do
    if btn then
      theme.ApplyText(btn.label, "body", "OBJECTIVE")
      if btn.bg and matches(btn.bg, theme.OXP_BLUE) then
        setVertex(btn.bg, C.ZONE, 0.16)  -- labelled buttons' blue wash -> amber
      end
      if btn.icon and matches(btn.icon, OXP_BLUE_LABEL) then
        setVertex(btn.icon, C.ZONE)
      end
    end
  end
end

local function skinXPStrip(xpStrip)
  -- rested XP is drawn in the blue accent: amber keeps the meaning
  if xpStrip and xpStrip.rested and matches(xpStrip.rested, theme.OXP_BLUE) then
    setVertex(xpStrip.rested, C.ZONE, 0.35)
  end
end

local function skinMini(mini)
  theme.ApplyText(mini.text, "title", "TITLE")
  theme.ApplyText(mini.count, "body", "DIM")
  if mini.badge then
    amberIfBlue(mini.badge.fill, 0.16)
    amberIfBlue(mini.badge.ring)
    amberIfBlue(mini.badge.icon)
  end
end

local function skinStepList(list, openxp)
  theme.ApplyBackdrop(list)
  theme.ApplyText(list.title, "header", "TITLE")
  local rows = list.rows or {}
  for _, row in ipairs(rows) do
    local colorName = "TITLE"
    if row.current then
      colorName = "TITLE_FOCUS"
      if row.hl and row.hl.SetColorTexture then
        row.hl:SetColorTexture(C.TITLE_FOCUS[1], C.TITLE_FOCUS[2], C.TITLE_FOCUS[3], 0.08)
      end
      theme.ApplyText(row.num, "body", "TITLE_FOCUS")
    else
      local status = rowStatus(row, openxp)
      colorName = PILL_COLORS[status] or "TITLE"
      theme.ApplyText(row.num, "body", "DIM")
    end
    theme.ApplyText(row.text, "title", colorName)
    skinPill(row.pill, openxp)
  end
  -- FlareUI's procedural bronze scrollbar beside the wheel-scrolled list.
  theme.ApplyScrollBar(list, {
    state = function()
      local total = list.count or #rows
      local visible = #rows
      if total <= visible then return 0, 1, false end
      local frac = (list.offset or 0) / (total - visible)
      return frac, visible / total, true
    end,
  })
end

-- ---------------------------------------------------------------------------
-- Progress bars
-- ---------------------------------------------------------------------------

-- OpenXP draws both progress bars (the step progress under the header and
-- the XP strip along the bottom) edge to edge, 1px inside the card, so with
-- the FlareUI border art their ends sit on top of it. This is the one place
-- the card skin lays anything out: each bar is inset by BAR_INSET on BOTH
-- sides (shifting it right alone would push its right end past the border
-- and the window edge). Only the bars themselves move, never the header,
-- body or any other element; every pass is idempotent.
local BAR_INSET = 3

-- Inset the header progress bar: the 2px track and the fill that grows
-- from its left end. OpenXP anchors the body and history to the track's
-- bottom corners, so the track itself stays; it is hidden and an inset
-- copy of it is drawn instead, and only the fill is moved and shortened.
local function insetStepProgress(rf, header, ctx)
  local hf = theme.RealFrame(header)
  local okr, regions = pcall(function() return { rf:GetRegions() } end)
  if not (hf and okr) then return end
  -- The first anchor's relative frame, for any texture (nil when unreadable).
  local function anchorOf(region)
    if region == rf.oxpfuiTrack or not region.GetObjectType
        or region:GetObjectType() ~= "Texture" then
      return nil
    end
    local ok, _, rel = pcall(region.GetPoint, region, 1)
    return ok and rel or nil
  end
  -- The track is a thin texture hung under the header (a few px tall, not
  -- compared with == so pixel rounding cannot hide it).
  local track, fill
  for _, region in ipairs(regions) do
    if anchorOf(region) == hf then
      local okh, h = pcall(region.GetHeight, region)
      if okh and type(h) == "number" and h > 0 and h <= 4 then track = region end
    end
  end
  if not track then
    ctx.Skip("card: step progress track not found")
    return
  end
  for _, region in ipairs(regions) do
    if anchorOf(region) == track then fill = region end
  end
  if not fill then ctx.Skip("card: step progress fill not found") end

  local own = rf.oxpfuiTrack
  if not own then
    own = rf:CreateTexture(nil, "ARTWORK")
    own:SetHeight(2)
    rf.oxpfuiTrack = own
  end
  own:ClearAllPoints()
  own:SetPoint("TOPLEFT", hf, "BOTTOMLEFT", BAR_INSET, 0)
  own:SetPoint("TOPRIGHT", hf, "BOTTOMRIGHT", -BAR_INSET, 0)
  own:SetColorTexture(1, 1, 1, 0.08)
  track:SetAlpha(0)

  if not fill then return end
  fill:ClearAllPoints()
  fill:SetPoint("TOPLEFT", track, "TOPLEFT", BAR_INSET, 0)
  -- OpenXP sizes the fill to (card width - 2) * fraction on each refresh;
  -- scale that into the shorter track, once per OpenXP-set width.
  local width, cardW = fill:GetWidth(), rf:GetWidth()
  if width and cardW and cardW > 2 + 2 * BAR_INSET
      and not (fill.oxpfuiWidth and math.abs(fill.oxpfuiWidth - width) < 0.01) then
    local scaled = math.max(1, width * (cardW - 2 - 2 * BAR_INSET) / (cardW - 2))
    fill:SetWidth(scaled)
    fill.oxpfuiWidth = scaled
  end
end

-- Inset the XP strip: the strip frame carries its track, rested and fill
-- textures with it; OpenXP sizes them from the strip's own width, so it is
-- asked to do that again once the strip is narrower.
local function insetXPStrip(xpStrip, bar, cardModule)
  local sf, bf = theme.RealFrame(xpStrip), theme.RealFrame(bar)
  if not (sf and bf and sf.SetPoint) then return end
  sf:ClearAllPoints()
  sf:SetPoint("BOTTOMLEFT", bf, "BOTTOMLEFT", BAR_INSET, 0)
  sf:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", -BAR_INSET, 0)
  if cardModule and cardModule.UpdateXP then pcall(cardModule.UpdateXP) end
end

-- ---------------------------------------------------------------------------
-- Conditional progress bars (flight and step timers)
-- ---------------------------------------------------------------------------

-- OpenXP's timer bars (LibCandyBar frames, docked under the card) are filled
-- with the foreground texture of FlareUI's unit frame bars, "FlareUI Forever"
-- (Blizzard's Forever art in grey, so the bar colour tints it). FlareUI
-- hardcodes that texture today, so the path lives in this one function; when
-- FlareUI lets its maintainer-configured texture be read, only it changes.
-- Nil while FlareUI is not installed: the bars then keep OpenXP's own.
local function flareBarTexture()
  if not (GetAddOnMetadata and GetAddOnMetadata("FlareUI", "Version")) then
    return nil
  end
  return "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever.tga"
end

-- Texture one bar: the fill and its background, exactly as LibCandyBar's own
-- SetTexture does, with the fill's colour carried over. A bar already
-- showing the texture is left alone (OpenXP repaints its own one on every
-- StartTimer, so what the bar shows now is the only thing to go by).
local function textureBar(bar, texture)
  if type(bar) ~= "table" then return end
  local fill = bar.candyBarBar
  if not (fill and fill.SetStatusBarTexture and fill.GetStatusBarTexture
      and fill.GetStatusBarColor and fill.SetStatusBarColor
      and bar.candyBarBackground and bar.candyBarBackground.SetTexture) then
    return
  end
  local current = fill:GetStatusBarTexture()
  if current and current.GetTexture and current:GetTexture() == texture then return end
  local r, g, b, a = fill:GetStatusBarColor()
  fill:SetStatusBarTexture(texture)
  bar.candyBarBackground:SetTexture(texture)
  if r then fill:SetStatusBarColor(r, g, b, a) end
end

-- The active bars are RXPFrame.BarContainer.bars (label -> bar). OpenXP
-- restarts a pooled bar through StartTimer, which paints its own texture
-- again; the SortTimers hook (Engine) brings this skin back after it.
local function skinTimerBars(ctx, openxp)
  local texture = flareBarTexture()
  if not texture then
    ctx.Skip("card: timer bars keep OpenXP's texture (FlareUI not installed)")
    return
  end
  local container = openxp and openxp.RXPFrame and openxp.RXPFrame.BarContainer
  if type(container) ~= "table" or type(container.bars) ~= "table" then return end
  for _, raw in pairs(container.bars) do
    local bar = ctx.Guard(raw)
    if bar then textureBar(bar, texture) end
  end
end

-- ---------------------------------------------------------------------------
-- Skin entry
-- ---------------------------------------------------------------------------

local function Apply(ctx)
  local f = ctx.Frame("OpenXPCard")
  if not f then return end
  local openxp = ctx.OpenXP()
  local cardModule = openxp and openxp.card or nil
  local rf = theme.RealFrame(f)

  -- Bronze border art + warm near-black fill at the panel opacity setting.
  theme.ApplyBackdrop(f)

  -- OpenXP's unnamed card children, found by matching field shapes.
  local ok, children = pcall(function() return { rf:GetChildren() } end)
  if not ok then children = nil end
  local header, bar, upNext, mini, list
  for _, child in ipairs(children or {}) do
    if fields(child, "step", "dot") then header = child
    elseif fields(child, "prev", "collapse") then bar = child
    elseif fields(child, "label", "lines", "sep") then upNext = child
    elseif fields(child, "expand", "count") then mini = child
    elseif fields(child, "title", "rows", "close") then list = child
    end
  end
  if header then
    skinHeader(ctx.Guard(header))
    ensureDivider(f, header)
    insetStepProgress(rf, header, ctx)
  end
  if cardModule and cardModule.hist then skinHist(ctx.Guard(cardModule.hist), openxp) end
  if cardModule then skinBlocks(cardModule.blocksForTest) end
  if upNext then skinUpNext(ctx.Guard(upNext)) end
  if bar then skinBar(ctx.Guard(bar)) end
  if cardModule and cardModule.xpStrip then
    skinXPStrip(cardModule.xpStrip)
    if bar then insetXPStrip(cardModule.xpStrip, bar, cardModule) end
  end
  if mini then skinMini(ctx.Guard(mini)) end
  if list then skinStepList(ctx.Guard(list), openxp) end
  skinTimerBars(ctx, openxp)

  -- Any region still carrying OpenXP's blue accent (the progress strip
  -- under the header, theme-colored art) becomes FlareUI amber.
  local okr, regions = pcall(function() return { rf:GetRegions() } end)
  if okr then
    for _, region in ipairs(regions or {}) do
      if region.SetVertexColor then amberIfBlue(region) end
    end
  end
end

OXPFUI.RegisterSkin{
  name = "card",
  windows = { "card" },
  Apply = Apply,
}
