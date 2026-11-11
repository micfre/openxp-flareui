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
        for part in ("zone", "range", "step"):
            self.assertEqual(font_of(env, f"{hb}.{part}"), (FRIZQT, 13, ""),
                             f"header.{part} must be Friz Quadrata 13, no outline")
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
        for expr, size in ((f"{bits}.header.zone", 13),
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
        self.assertEqual(font_of(env, zone), (FRIZQT, 13, ""))
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


if __name__ == "__main__":
    unittest.main()
