"""Seam 1 tests for the guide card + step list skin (ticket #4).

Observed only through the lupa harness: the real addon (Core, Locale, Theme,
Engine, Card, SettingsPanel) boots against the fake OpenXP, and tests read
frame state back — never the skin module's internals.
"""

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from harness.env import Env  # noqa: E402

FLARE_FRAMES = "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga"
FLARE_THICK = "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Thick.tga"
FLARE_THIN = "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Thin.tga"
FLARE_FILL = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
BRONZE = (0.65, 0.49, 0.27, 1.0)
OXP_EDGE = "Interface\\Buttons\\WHITE8X8"

# FlareUI palette (flareui-style.md, ObjectiveTracker constant table C).
ZONE = (0.80, 0.60, 0.34, 1.0)
GOLD = (1.0, 0.82, 0.0, 1.0)
GREEN = (0.13, 1.0, 0.13, 1.0)
FOCUS = (0.40, 0.80, 1.0, 1.0)
GREY = (0.85, 0.85, 0.85, 1.0)
GREY_DONE = (0.55, 0.55, 0.55, 1.0)
FRIZQT = "Fonts\\FRIZQT__.TTF"


class CardBackdrop(unittest.TestCase):
    def test_card_uses_flareui_backdrop_on_login(self):
        env = Env()
        env.boot()
        self.assertEqual(env.run("return OpenXPCard.backdrop.bgFile"), FLARE_FILL)
        self.assertEqual(env.run("return OpenXPCard.backdrop.edgeFile"), FLARE_FRAMES)
        self.assertEqual(env.run("return OpenXPCard.backdrop.edgeSize"), 16)
        self.assertEqual(env.run("return OpenXPCard.backdrop.tile"), False)
        self.assertEqual(
            env.run("local r,g,b,a = OpenXPCard:GetBackdropBorderColor(); return r,g,b,a"),
            BRONZE)
        # Warm dark fill drawn at the panel opacity setting (default 0.6).
        self.assertEqual(
            env.run("local r,g,b,a = OpenXPCard:GetBackdropColor(); return r,g,b,a"),
            (1.0, 1.0, 1.0, 0.6))

    def test_every_border_style_reaches_the_card(self):
        cases = (("Frames", FLARE_FRAMES, 16),
                 ("Thick", FLARE_THICK, 16),
                 ("Thin", FLARE_THIN, 8))
        for style, edge, size in cases:
            with self.subTest(style=style):
                env = Env(db={"borderStyle": style})
                env.boot()
                self.assertEqual(env.run("return OpenXPCard.backdrop.edgeFile"), edge)
                self.assertEqual(env.run("return OpenXPCard.backdrop.edgeSize"), size)
                self.assertEqual(
                    env.run("local r,g,b,a = OpenXPCard:GetBackdropBorderColor(); return r,g,b,a"),
                    BRONZE)

    def test_panel_opacity_setting_reaches_the_card_fill(self):
        env = Env(db={"opacity": 0.35})
        env.boot()
        self.assertEqual(env.run("local _,_,_,a = OpenXPCard:GetBackdropColor(); return a"), 0.35)


def font_of(env, lua_expr):
    return env.run(f"local p,s,f = {lua_expr}:GetFont(); return p,s,f")


def color_of(env, lua_expr):
    return env.run(f"local r,g,b,a = {lua_expr}:GetTextColor(); return r,g,b,a")


def vertex_of(env, lua_expr):
    return env.run(f"local r,g,b,a = {lua_expr}:GetVertexColor(); return r,g,b,a")


class CardTextColors(unittest.TestCase):
    """Story 2: gold titles, grey objectives, green completed; story 5/6:
    Friz Quadrata 13/12/11 with a 1px shadow, no outline."""

    def test_header_zone_range_step_use_flareui_colors_and_header_font(self):
        env = Env()
        env.boot()
        hb = "HARNESS.cardBits.header"
        self.assertEqual(color_of(env, f"{hb}.zone"), ZONE)      # zone headers bronze
        self.assertEqual(color_of(env, f"{hb}.range"), GREY_DONE)  # counters dim
        self.assertEqual(color_of(env, f"{hb}.step"), GOLD)      # step name gold
        # zone is 1pt under the 13 header size, range / step 2pt under it
        for part, size in (("zone", 12), ("range", 11), ("step", 11)):
            self.assertEqual(font_of(env, f"{hb}.{part}"), (FRIZQT, size, ""),
                             f"header.{part} must be Friz Quadrata {size}, no outline")
            self.assertEqual(env.run(
                f"local x,y = {hb}.{part}:GetShadowOffset(); return x,y"), (1, -1))
            self.assertEqual(env.run(
                f"local r,g,b,a = {hb}.{part}:GetShadowColor(); return r,g,b,a"),
                (0.0, 0.0, 0.0, 1.0))

    def test_step_block_titles_objectives_counts(self):
        env = Env()
        env.boot()
        b = "HARNESS.cardBits.blocks[1]"
        self.assertEqual(color_of(env, f"{b}.title"), GOLD)
        self.assertEqual(font_of(env, f"{b}.title"), (FRIZQT, 12, ""))
        # open objective: light grey body text at 11
        self.assertEqual(color_of(env, f"{b}.lines[1].text"), GREY)
        self.assertEqual(font_of(env, f"{b}.lines[1].text"), (FRIZQT, 11, ""))
        # kill/loot counter and the step number are dim
        self.assertEqual(color_of(env, f"{b}.lines[1].count"), GREY_DONE)
        self.assertEqual(color_of(env, f"{b}.num"), GREY_DONE)

    def test_completed_objective_line_is_flareui_green(self):
        env = Env()
        env.boot()
        line = "HARNESS.cardBits.blocks[1].lines[2]"  # the fake marks this one done
        self.assertEqual(color_of(env, f"{line}.text"), GREY_DONE)
        self.assertEqual(vertex_of(env, f"{line}.mark"), GREEN)

    def test_history_upnext_mini_and_bar_label_text(self):
        env = Env()
        env.boot()
        bits = "HARNESS.cardBits"
        # section headers bronze, body/hint text grey
        self.assertEqual(color_of(env, f"{bits}.hist.label"), ZONE)
        self.assertEqual(color_of(env, f"{bits}.hist.hint"), GREY_DONE)
        self.assertEqual(color_of(env, f"{bits}.hist.rows[1].text"), GREEN)  # done history row
        self.assertEqual(color_of(env, f"{bits}.upNext.label"), ZONE)
        self.assertEqual(color_of(env, f"{bits}.upNext.text"), GREY)
        self.assertEqual(color_of(env, f"{bits}.mini.text"), GOLD)
        self.assertEqual(font_of(env, f"{bits}.mini.text"), (FRIZQT, 12, ""))
        self.assertEqual(color_of(env, f"{bits}.mini.count"), GREY_DONE)
        self.assertEqual(color_of(env, f"{bits}.bar.find.label"), GREY)
        self.assertEqual(font_of(env, f"{bits}.bar.find.label"), (FRIZQT, 11, ""))

    def test_status_pills_use_flareui_status_colors(self):
        env = Env()
        env.boot()
        pill = "HARNESS.cardBits.hist.rows[1].pill"  # the fake tags it DONE
        self.assertEqual(color_of(env, f"{pill}.text"), GREEN)
        for part in ("bg", "l", "r"):
            self.assertEqual(vertex_of(env, f"{pill}.{part}"), (0.13, 1.0, 0.13, 0.16))


class CardPalette(unittest.TestCase):
    """Story 1 + spec palette: OpenXP's blue accent becomes FlareUI amber."""

    def test_blue_accent_elements_become_flareui_amber(self):
        env = Env()
        env.boot()
        bits = "HARNESS.cardBits"
        self.assertEqual(vertex_of(env, f"{bits}.header.dot"), ZONE)
        self.assertEqual(vertex_of(env, f"{bits}.progress"), ZONE)
        # the rested-XP wash keeps its softer alpha, just amber instead of blue
        self.assertEqual(vertex_of(env, f"{bits}.xpStrip.rested"),
                         (0.80, 0.60, 0.34, 0.35))

    def test_blue_badges_and_bars_become_amber_but_other_kinds_keep_color(self):
        env = Env()
        env.boot()
        b1 = "HARNESS.cardBits.blocks[1]"      # travel badge: blue in OpenXP
        b2 = "HARNESS.cardBits.blocks[2]"
        # block 1's badge stays travel: ring amber now
        self.assertEqual(vertex_of(env, f"{b1}.badge.ring"), ZONE)
        self.assertEqual(vertex_of(env, f"{b1}.lines[1].bar"), ZONE)
        # block 2 is recolored by the fake to a kill badge (orange): untouched
        env.run("HARNESS.cardBits.blocks[2].badge.ring:SetVertexColor(1, 112/255, 67/255, 1)")
        env.run("OXPFUI.Reapply('test')")
        self.assertEqual(vertex_of(env, f"{b2}.badge.ring"), (1.0, 112 / 255, 67 / 255, 1.0))


class CardTypography(unittest.TestCase):
    def test_chosen_condensed_font_reaches_all_card_text_kinds(self):
        env = Env(db={"font": "Roboto Condensed"})
        env.boot()
        roboto = "Interface\\AddOns\\OXP-FUI\\Media\\Fonts\\RobotoCondensed-Regular.ttf"
        bits = "HARNESS.cardBits"
        for expr, size in ((f"{bits}.header.zone", 12),
                           (f"{bits}.blocks[1].title", 12),
                           (f"{bits}.blocks[1].lines[1].text", 11)):
            self.assertEqual(font_of(env, expr), (roboto, size, ""))

    def test_openxp_font_and_outline_settings_are_overridden(self):
        # Story 22: while enabled OXP-FUI wins over OpenXP's own font and
        # outline settings, even right after card.ApplyFonts re-fonts
        # everything to Arial Narrow OUTLINE.
        env = Env()
        env.boot()
        zone = "HARNESS.cardBits.header.zone"
        env.run("HARNESS.openxp.card.ApplyFonts()")
        self.assertEqual(font_of(env, zone), (FRIZQT, 12, ""))
        self.assertEqual(color_of(env, zone), ZONE)
        self.assertEqual(env.run(
            f"local x,y = {zone}:GetShadowOffset(); return x,y"), (1, -1))


class StepList(unittest.TestCase):
    """Story 4 + ticket scope: the step list popup in the FlareUI look with
    a procedural bronze scrollbar, opened the way a user opens it."""

    def setUp(self):
        self.env = Env()
        self.env.boot()
        self.env.run("HARNESS.openxp.card.ToggleStepList()")  # builds + shows it
        self.list = "HARNESS.cardBits.list"

    def test_open_list_gets_flareui_backdrop_and_gold_title(self):
        env, lst = self.env, self.list
        self.assertEqual(env.run(f"return {lst}:IsShown()"), True)
        self.assertEqual(env.run(f"return {lst}.backdrop.edgeFile"), FLARE_FRAMES)
        self.assertEqual(
            env.run(f"local r,g,b,a = {lst}:GetBackdropBorderColor(); return r,g,b,a"),
            BRONZE)
        self.assertEqual(color_of(env, f"{lst}.title"), GOLD)
        self.assertEqual(font_of(env, f"{lst}.title"), (FRIZQT, 13, ""))

    def test_rows_are_colored_by_step_state(self):
        env, lst = self.env, self.list
        # the fake guide's current step is 4: row 4 is current (light blue),
        # earlier rows are finished (green), later ones are plain (gold).
        self.assertEqual(color_of(env, f"{lst}.rows[4].text"), FOCUS)
        self.assertEqual(color_of(env, f"{lst}.rows[4].num"), FOCUS)
        self.assertEqual(color_of(env, f"{lst}.rows[1].text"), GREEN)
        self.assertEqual(color_of(env, f"{lst}.rows[1].num"), GREY_DONE)
        self.assertEqual(color_of(env, f"{lst}.rows[5].text"), GOLD)
        self.assertEqual(font_of(env, f"{lst}.rows[5].text"), (FRIZQT, 12, ""))
        # finished rows carry a green DONE pill
        self.assertEqual(color_of(env, f"{lst}.rows[1].pill.text"), GREEN)

    def test_scrollbar_chrome_is_procedural_bronze(self):
        env, lst = self.env, self.list
        scroll = f"{lst}.oxpfuiScroll"
        track, thumb = f"{scroll}.track", f"{scroll}.thumb"
        self.assertNotEqual(env.run(f"return {scroll} == nil"), True)
        # both drawn as colour textures: faint bronze track, solid bronze thumb
        self.assertEqual(env.run(
            f"local t = {track}; local r,g,b = t:GetVertexColor();"
            "return r,g,b,t.__colorTexture and t.__colorTexture[4]"), (0.50, 0.38, 0.21, 0.25))
        self.assertEqual(env.run(
            f"local t = {thumb}; local r,g,b = t:GetVertexColor();"
            "return r,g,b,t.__colorTexture and t.__colorTexture[4]"), (0.50, 0.38, 0.21, 1.0))
        self.assertEqual(env.run(f"return {track}:GetWidth()"), 1)
        self.assertEqual(env.run(f"return {thumb}:GetWidth()"), 3)
        # chrome belongs to the list frame itself, never a new window
        self.assertEqual(env.run(f"return {track}:GetParent() == HARNESS.cardBits.list"), True)
        # 40 steps over 6 rows scrolls: both ends visible
        self.assertEqual(env.run(f"return {track}:IsShown()"), True)
        self.assertEqual(env.run(f"return {thumb}:IsShown()"), True)
        # a thumb is never tiny
        self.assertGreaterEqual(env.run(f"return {thumb}:GetHeight()"), 16)

    def test_scrollbar_tracks_scrolling_and_hides_when_short(self):
        env, lst = self.env, self.list
        thumb = f"{lst}.oxpfuiScroll.thumb"
        top = env.run(f"local _,_,_,_,y = {thumb}:GetPoint(1); return y")
        # scroll near the bottom the way the mouse wheel does, then refresh
        env.run(f"{lst}.offset = 34; HARNESS.openxp.card.FillStepList(); OXPFUI.Reapply('test')")
        bottom = env.run(f"local _,_,_,_,y = {thumb}:GetPoint(1); return y")
        self.assertLess(bottom, top)
        # a short guide does not scroll: the chrome hides
        env.run(f"{lst}.count = 6; OXPFUI.Reapply('test')")
        self.assertEqual(env.run(f"return {lst}.oxpfuiScroll.track:IsShown()"), False)
        self.assertEqual(env.run(f"return {thumb}:IsShown()"), False)

    def test_list_keeps_flareui_look_after_refreshes(self):
        env, lst = self.env, self.list
        for call in ("HARNESS.openxp.card.Refresh(nil, true)",
                     "HARNESS.openxp.card.ApplyFonts()",
                     "HARNESS.openxp:RenderFrame()",
                     "HARNESS.openxp:ReloadTheme()"):
            env.run(call)
            self.assertEqual(env.run(f"return {lst}.backdrop.edgeFile"), FLARE_FRAMES,
                             f"list skin lost after {call}")
            self.assertEqual(color_of(env, f"{lst}.rows[4].text"), FOCUS,
                             f"row colors lost after {call}")

    def test_border_style_setting_reaches_the_list(self):
        env = Env(db={"borderStyle": "Thin"})
        env.boot()
        env.run("HARNESS.openxp.card.ToggleStepList()")
        self.assertEqual(env.run("return HARNESS.cardBits.list.backdrop.edgeFile"), FLARE_THIN)
        self.assertEqual(env.run("return HARNESS.cardBits.list.backdrop.edgeSize"), 8)


BOX = (0.50, 0.38, 0.21, 1.0)
BOX_LIT = (0.65, 0.49, 0.27, 1.0)

# Every OpenXP button the card chrome covers.
CARD_BUTTONS = (
    "HARNESS.cardBits.bar.prev",
    "HARNESS.cardBits.bar.next",
    "HARNESS.cardBits.bar.menu",
    "HARNESS.cardBits.bar.settings",
    "HARNESS.cardBits.bar.collapse",
    "HARNESS.cardBits.bar.find",
    "HARNESS.cardBits.bar.stop",
    "HARNESS.cardBits.bar.resume",
    "HARNESS.cardBits.mini.expand",
)


class BorderlessButtons(unittest.TestCase):
    """OpenXP's icon buttons (and the invisible "Step n / n" hit area) keep
    their own borderless look: the skin paints no square around them."""

    def test_no_card_button_gets_a_square_border(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.card.ToggleStepList()")
        for expr in CARD_BUTTONS + ("HARNESS.cardBits.header.stepBtn",):
            with self.subTest(button=expr):
                self.assertEqual(env.run(f"return {expr}.oxpfuiBox == nil"), True)

    def test_chrome_never_moves_or_resizes_the_buttons(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.card.Refresh(nil, true)")
        for expr in CARD_BUTTONS:
            with self.subTest(button=expr):
                for method in ("SetPoint", "SetSize", "SetWidth", "SetHeight",
                               "SetScale", "ClearAllPoints", "SetAllPoints"):
                    self.assertEqual(
                        env.run(f"local n=0; local f={expr}; "
                                f"for _,c in ipairs(f.__calls) do if c[1]=={method!r} then n=n+1 end end; return n"),
                        0, f"{expr}:{method} was called")


class ProgressBarsClearTheBorder(unittest.TestCase):
    """The step progress bar and the XP strip are inset 3px on both sides so
    neither end sits on the border art (a right-only shift would push the
    right end past the window edge)."""

    W = 320  # the fake card's width

    def _x(self, env, expr, point):
        # offset of the named anchor point, from the Lua anchors
        return env.run(
            f"for i = 1, {expr}:GetNumPoints() do local p,_,_,x = {expr}:GetPoint(i); "
            f"if p == {point!r} then return x end end return nil")

    def test_step_progress_fill_starts_3px_in_and_stays_inside_the_track(self):
        env = Env()
        env.boot()
        fill = "HARNESS.cardBits.progress"
        self.assertEqual(self._x(env, fill, "TOPLEFT"), 3)
        # OpenXP sized it to (W - 2) * 0.5; the track is now W - 8 wide
        self.assertAlmostEqual(env.run(f"return {fill}:GetWidth()"),
                               (self.W - 8) * 0.5)
        # full progress would end at 3 + (W - 8) = W - 5: inside the window
        self.assertLess(3 + (self.W - 8), self.W - 3)

    def test_reapply_does_not_shrink_the_fill_again(self):
        env = Env()
        env.boot()
        fill = "HARNESS.cardBits.progress"
        before = env.run(f"return {fill}:GetWidth()")
        env.run("OXPFUI.Reapply('test')")
        env.run("OXPFUI.Reapply('test')")
        self.assertEqual(env.run(f"return {fill}:GetWidth()"), before)
        # a fresh OpenXP refresh resizes it, and it is scaled once more
        env.run("HARNESS.openxp.card.Refresh(nil, true)")
        self.assertAlmostEqual(env.run(f"return {fill}:GetWidth()"),
                               (self.W - 8) * 0.5)

    def test_openxp_track_is_hidden_and_replaced_by_an_inset_one(self):
        env = Env()
        env.boot()
        self.assertEqual(env.run("return OpenXPCard.oxpfuiTrack ~= nil"), True)
        self.assertEqual(self._x(env, "OpenXPCard.oxpfuiTrack", "TOPLEFT"), 3)
        self.assertEqual(self._x(env, "OpenXPCard.oxpfuiTrack", "TOPRIGHT"), -3)
        self.assertEqual(env.run("return #OpenXPCard.oxpfuiTrack.__points"), 2)

    def test_xp_strip_is_inset_on_both_sides_and_resized(self):
        env = Env()
        env.boot()
        strip = "HARNESS.cardBits.xpStrip"
        self.assertEqual(self._x(env, strip, "BOTTOMLEFT"), 3)
        self.assertEqual(self._x(env, strip, "BOTTOMRIGHT"), -3)
        self.assertEqual(env.run(f"return {strip}:GetWidth()"), self.W - 8)
        self.assertAlmostEqual(env.run(f"return {strip}.fill:GetWidth()"),
                               (self.W - 8) * 0.4)

    def test_body_and_header_anchors_are_untouched(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.card.Refresh(nil, true)")
        self.assertEqual(env.run(
            "local n=0; for _,c in ipairs(HARNESS.cardBits.header.__calls) do "
            "if c[1]=='SetPoint' or c[1]=='ClearAllPoints' then n=n+1 end end; return n"), 2)  # OpenXP's own two anchors
        # the track the body anchors to is never re-anchored
        self.assertEqual(env.run(
            "local n=0; for _,r in ipairs({OpenXPCard:GetRegions()}) do "
            "if r.__height == 2 and r ~= OpenXPCard.oxpfuiTrack and r.__points[1] "
            "and r.__points[1][2] == HARNESS.cardBits.header then "
            "for _,c in ipairs(r.__calls) do if c[1]=='ClearAllPoints' then n=n+1 end end end end return n"), 0)


class HeaderBand(unittest.TestCase):
    def test_header_band_gets_flareui_divider_under_it(self):
        env = Env()
        env.boot()
        divider = "OpenXPCard.oxpfuiDivider"
        self.assertNotEqual(env.run(f"return {divider} == nil"), True)
        self.assertEqual(env.run(f"return {divider}:GetTexture()"),
                         "Interface\\Common\\UI-TooltipDivider-Transparent")
        self.assertEqual(env.run(f"return {divider}:GetHeight()"), 8)
        # chrome is parented to the real card frame and anchored to the
        # header without touching it
        self.assertEqual(env.run(f"return {divider}:GetParent() == _G.OpenXPCard"), True)
        self.assertGreaterEqual(env.run(f"return {divider}:GetNumPoints()"), 2)


FLAREUI_BAR = "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever.tga"
OXP_BAR = "Interface\\CHARACTERFRAME\\BarFill"
PIN_BLUE = (0.35, 0.72, 1.0, 1.0)


class ConditionalProgressBar(unittest.TestCase):
    """OpenXP's conditional progress bars (flight and step timers, docked
    under the card) get the foreground texture of FlareUI's unit frame bars,
    "FlareUI Forever". FlareUI hardcodes that texture today; a future
    configured texture would change only the one constant that names it."""

    BAR = "HARNESS.openxp.RXPFrame.BarContainer.bars['Refuge Pointe, Arathi']"

    def _env(self, **kw):
        env = Env(**kw)
        env.boot()
        env.run("HARNESS.openxp.StartTimer(38, 'Refuge Pointe, Arathi')")
        return env

    def _textures(self, env):
        fill = env.run(f"return {self.BAR}.candyBarBar:GetStatusBarTexture():GetTexture()")
        bg = env.run(f"return {self.BAR}.candyBarBackground:GetTexture()")
        return fill, bg

    def test_new_bar_fill_and_background_use_the_flareui_texture(self):
        env = self._env(flareui=True)
        self.assertEqual(self._textures(env), (FLAREUI_BAR, FLAREUI_BAR))

    def test_bar_keeps_openxps_colour_over_the_new_texture(self):
        env = self._env(flareui=True)
        self.assertEqual(env.run(
            f"local r,g,b,a = {self.BAR}.candyBarBar:GetStatusBarColor(); return r,g,b,a"),
            PIN_BLUE)
        self.assertEqual(env.run(
            f"local r,g,b,a = {self.BAR}.candyBarBar:GetStatusBarTexture():GetVertexColor(); "
            "return r,g,b,a"), PIN_BLUE)

    def test_bar_started_again_is_re_textured(self):
        env = self._env(flareui=True)
        env.run("HARNESS.openxp.StartTimer(40, 'Refuge Pointe, Arathi')")
        self.assertEqual(self._textures(env), (FLAREUI_BAR, FLAREUI_BAR))

    def test_reapply_is_idempotent(self):
        env = self._env(flareui=True)
        env.run("OXPFUI.Reapply('test')")
        env.run("OXPFUI.Reapply('test')")
        self.assertEqual(self._textures(env), (FLAREUI_BAR, FLAREUI_BAR))
        self.assertEqual(env.run(
            f"local n = 0; for _, c in ipairs({self.BAR}.candyBarBar.__calls) do "
            "if c[1] == 'SetStatusBarTexture' then n = n + 1 end end; return n"), 2)

    def test_without_flareui_the_bar_stays_openxps(self):
        env = self._env()
        self.assertEqual(self._textures(env), (OXP_BAR, OXP_BAR))

    def test_card_window_switch_off_leaves_the_bar_openxps(self):
        env = self._env(flareui=True, db={"windows": {"card": False}})
        self.assertEqual(self._textures(env), (OXP_BAR, OXP_BAR))

    def test_master_switch_off_leaves_the_bar_openxps(self):
        env = self._env(flareui=True, db={"enabled": False})
        self.assertEqual(self._textures(env), (OXP_BAR, OXP_BAR))

    def test_bar_is_never_moved_or_resized(self):
        env = self._env(flareui=True)
        env.run("OXPFUI.Reapply('test')")
        self.assertEqual(env.run(
            f"local n = 0; for _, c in ipairs({self.BAR}.__calls) do "
            "if c[1] == 'SetPoint' or c[1] == 'SetWidth' or c[1] == 'SetHeight' "
            "or c[1] == 'SetSize' then n = n + 1 end end; return n"), 0)

    def test_missing_timer_parts_are_skipped_quietly(self):
        env = Env(flareui=True)
        env.boot()
        env.run("HARNESS.openxp.RXPFrame.BarContainer = nil")
        env.run("OXPFUI.Reapply('test')")
        env.run("HARNESS.openxp.RXPFrame.BarContainer = { bars = { x = {} } }")
        env.run("OXPFUI.Reapply('test')")
        report = env.run("return OXPFUI.DebugReport()")
        self.assertIn("Errors: none", report)


class CardSwitches(unittest.TestCase):
    """Story 24/25: the master switch and the card's per-window switch."""

    def test_card_window_switch_off_leaves_the_card_openxp_looking(self):
        env = Env(db={"windows": {"card": False}})
        env.boot()
        env.run("HARNESS.openxp.card.Refresh(nil, true)")
        self.assertEqual(env.run("return OpenXPCard.backdrop.edgeFile"), OXP_EDGE)
        self.assertEqual(color_of(env, "HARNESS.cardBits.header.zone"),
                         (0.92, 0.93, 0.95, 1.0))  # OpenXP text white
        self.assertEqual(env.run("return OpenXPCard.oxpfuiDivider == nil"), True)
        self.assertEqual(env.run(
            "return HARNESS.cardBits.bar.prev.oxpfuiBox == nil"), True)

    def test_master_switch_off_leaves_the_card_untouched(self):
        env = Env(db={"enabled": False})
        env.boot()
        for call in ("HARNESS.openxp:RenderFrame()",
                     "HARNESS.openxp.card.Refresh(nil, true)",
                     "HARNESS.openxp.card.ApplyFonts()",
                     "HARNESS.openxp.card.SkinPanels()"):
            env.run(call)
        self.assertEqual(env.run("return OpenXPCard.backdrop.edgeFile"), OXP_EDGE)
        self.assertEqual(color_of(env, "HARNESS.cardBits.header.zone"),
                         (0.92, 0.93, 0.95, 1.0))
        # opening the step list while disabled stays OpenXP-styled
        env.run("HARNESS.openxp.card.ToggleStepList()")
        self.assertEqual(env.run("return HARNESS.cardBits.list.backdrop.edgeFile"),
                         OXP_EDGE)

    def test_live_setting_changes_reapply_to_the_card(self):
        env = Env()
        env.install_skins("")  # (no extra skins needed; the real card skin)
        env.boot()
        env.slash("/oxpfui")
        env.run("OXPFUIPanel.opacitySlider:SetValue(0.2)")
        self.assertEqual(env.run(
            "local _,_,_,a = OpenXPCard:GetBackdropColor(); return a"), 0.2)
        env.run("OXPFUIPanel.borderBtn:Click()")  # Frames -> Thick
        self.assertEqual(env.run("return OpenXPCard.backdrop.edgeFile"), FLARE_THICK)


class UpNextLineEnding(unittest.TestCase):
    """The "..." cut of an Up next line stays inside the card's right
    padding: the skin's wider label must narrow the lines it pushes right."""

    RIGHT_EDGE = "return HARNESS.UP_NEXT.cardWidth - HARNESS.UP_NEXT.pad - 2"
    LINE_RIGHT = (
        "local u = HARNESS.cardBits.upNext; local _, _, _, dx = u.text:GetPoint(1); "
        "return HARNESS.UP_NEXT.pad + u.label:GetStringWidth() + dx + u.text:GetWidth()")

    def test_line_right_edge_matches_openxps_with_the_flareui_label(self):
        for font in ("Friz Quadrata", "Barlow Condensed"):
            with self.subTest(font=font):
                env = Env(db={"font": font})
                env.boot()
                env.run("HARNESS.openxp.card.Refresh(nil, true)")
                self.assertEqual(env.run(self.LINE_RIGHT), env.run(self.RIGHT_EDGE))

    def test_reapply_does_not_narrow_the_line_again(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.card.Refresh(nil, true)")
        width = env.run("return HARNESS.cardBits.upNext.text:GetWidth()")
        env.run("OXPFUI.Reapply('test')")
        env.run("OXPFUI.Reapply('test')")
        self.assertEqual(env.run("return HARNESS.cardBits.upNext.text:GetWidth()"), width)

    def test_font_change_keeps_the_right_edge(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.card.Refresh(nil, true)")
        env.run("OXPFUI.db.font = 'Barlow Condensed'")
        env.run("OXPFUI.Reapply('test')")
        self.assertEqual(env.run(self.LINE_RIGHT), env.run(self.RIGHT_EDGE))


class CardNeverMovesAnything(unittest.TestCase):
    """Story 29: no OpenXP frame is ever moved or resized by the skin."""

    def test_card_frame_never_gets_layout_calls(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp:RenderFrame()")
        env.run("HARNESS.openxp.card.Refresh(nil, true)")
        env.run("HARNESS.openxp.card.ApplyFonts()")
        env.run("HARNESS.openxp.card.ToggleStepList()")
        for method in ("SetPoint", "SetSize", "SetWidth", "SetHeight",
                       "SetScale", "ClearAllPoints", "SetAllPoints"):
            self.assertEqual(env.calls_made_on("OpenXPCard", method), 0,
                             f"OpenXPCard:{method} was called")

    def test_card_children_keep_their_geometry_through_reapplies(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.card.ToggleStepList()")
        header_calls = env.run("return #HARNESS.cardBits.header.__calls")
        list_layout = {m: env.run(
            "local n=0; for _,c in ipairs(HARNESS.cardBits.list.__calls) do "
            f"if c[1]=={m!r} then n=n+1 end end; return n")
            for m in ("SetPoint", "SetSize", "SetHeight", "SetWidth", "SetScale")}
        env.run("HARNESS.openxp.card.Refresh(nil, true)")
        env.run("OXPFUI.Reapply('test')")
        env.run("OXPFUI.Reapply('test')")
        # OpenXP's own ToggleStepList laid the list out once; re-applies
        # added nothing, and the header was never touched at all.
        self.assertLessEqual(env.run("return #HARNESS.cardBits.header.__calls"),
                             header_calls)
        for m, n in list_layout.items():
            self.assertEqual(env.run(
                "local n=0; for _,c in ipairs(HARNESS.cardBits.list.__calls) do "
                f"if c[1]=={m!r} then n=n+1 end end; return n"), n,
                f"step list {m} changed by a re-apply")


class CardRobustness(unittest.TestCase):
    """Story 31: a changed OpenXP (missing frames/fields) is skipped
    quietly — no errors, no chat spam, the rest of the skin still applies."""

    def test_missing_card_bits_are_skipped_quietly(self):
        env = Env(load_addon=False)
        env.run("HARNESS.openxp.card.hist = nil")
        env.run("HARNESS.openxp.card.blocksForTest = nil")
        env.run("HARNESS.openxp.card.xpStrip = nil")
        env.run("HARNESS.openxp.card.STATUS = nil")
        env.run("HARNESS.openxp.card.StepStatus = nil")
        env.run("HARNESS.cardBits.header.zone = nil")      # header lost its zone
        env.run("HARNESS.cardBits.bar.prev = nil")         # a button vanished
        env.load_addon()
        env.boot()
        env.run("HARNESS.openxp.card.Refresh(nil, true)")
        self.assertEqual(env.chat(), [])
        env.slash("/oxpfui debug")
        report = "\n".join(env.chat())
        self.assertIn("Errors: none", report)
        # the card frame itself is still skinned
        self.assertEqual(env.run("return OpenXPCard.backdrop.edgeFile"), FLARE_FRAMES)
        self.assertEqual(color_of(env, "HARNESS.cardBits.header.step"), GOLD)
        self.assertNotEqual(env.run("return OpenXPCard.oxpfuiDivider == nil"), True)


if __name__ == "__main__":
    unittest.main()
