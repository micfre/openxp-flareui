"""Seam 1 tests for the welcome / what's-new and feedback windows (ticket #6,
spec user stories 13-14), observed through the lupa harness like test_skin.py.

The fake OpenXP creates both windows lazily on welcome.Show() / feedback.Show()
with OpenXP's real global names and children (see fake_openxp.lua); these
tests fire client events and OpenXP calls, then read back frame state.
"""

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from harness.env import Env  # noqa: E402


class WelcomeWindow(unittest.TestCase):
    def test_welcome_window_wears_flareui_backdrop_on_show(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.welcome.Show('welcome')")
        self.assertEqual(env.run("return OpenXPWelcomeFrame.backdrop.edgeFile"),
                         "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga")
        self.assertEqual(env.run("return OpenXPWelcomeFrame.backdrop.edgeSize"), 16)
        self.assertEqual(env.run(
            "local r,g,b,a = OpenXPWelcomeFrame:GetBackdropBorderColor(); return r,g,b,a"),
            (0.65, 0.49, 0.27, 1.0))
        self.assertEqual(env.run(
            "local r,g,b,a = OpenXPWelcomeFrame:GetBackdropColor(); return r,g,b,a"),
            (1.0, 1.0, 1.0, 0.6))  # warm dark fill at the panel opacity setting

    def test_welcome_typography_is_flareui_with_palette_mapping(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.welcome.Show('welcome')")
        w = "HARNESS.welcome"
        # Window title: Friz Quadrata 13 header, FlareUI gold, 1px shadow.
        self.assertEqual(env.run(
            f"local p,s,f = {w}.title:GetFont(); return p,s,f"),
            ("Fonts\\FRIZQT__.TTF", 13, ""))
        self.assertEqual(env.run(
            f"local r,g,b,a = {w}.title:GetTextColor(); return r,g,b,a"),
            (1.0, 0.82, 0.0, 1.0))
        self.assertEqual(env.run(
            f"local x,y = {w}.title:GetShadowOffset(); return x,y"), (1, -1))
        # Subtitle (OpenXP body grey) -> FlareUI body grey, size 11.
        self.assertEqual(env.run(
            f"local p,s = {w}.subtitle:GetFont(); return p,s"),
            ("Fonts\\FRIZQT__.TTF", 11))
        self.assertEqual(env.run(
            f"local r,g,b,a = {w}.subtitle:GetTextColor(); return r,g,b,a"),
            (0.85, 0.85, 0.85, 1.0))
        # The muted swatch label goes FlareUI dim; the questie hint keeps the
        # font object's white in OpenXP, which lands on FlareUI body grey.
        self.assertEqual(env.run(
            f"local r,g,b,a = {w}.swatchText:GetTextColor(); return r,g,b,a"),
            (0.55, 0.55, 0.55, 1.0))
        self.assertEqual(env.run(
            f"local r,g,b,a = {w}.questie:GetTextColor(); return r,g,b,a"),
            (0.85, 0.85, 0.85, 1.0))
        # The scrolling body keeps FlareUI body typography too.
        self.assertEqual(env.run(
            f"local p,s = {w}.body:GetFont(); return p,s"),
            ("Fonts\\FRIZQT__.TTF", 11))
        self.assertEqual(env.run(
            f"local r,g,b,a = {w}.body:GetTextColor(); return r,g,b,a"),
            (0.85, 0.85, 0.85, 1.0))

    def test_welcome_honours_chosen_font(self):
        env = Env(db={"font": "Asap Condensed"})
        env.boot()
        env.run("HARNESS.openxp.welcome.Show('welcome')")
        self.assertEqual(env.run("return (HARNESS.welcome.title:GetFont())"),
                         "Interface\\AddOns\\OXP-FUI\\Media\\Fonts\\AsapCondensed-Regular.ttf")

    def test_welcome_accent_blue_textures_turn_bronze(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.welcome.Show('welcome')")
        # The header divider and logo glow keep their alpha, gain bronze.
        self.assertEqual(env.run(
            "local r,g,b,a = HARNESS.welcome.divider:GetVertexColor(); return r,g,b,a"),
            (0.80, 0.60, 0.34, 0.6))
        self.assertEqual(env.run(
            "local r,g,b,a = HARNESS.welcome.glow:GetVertexColor(); return r,g,b,a"),
            (0.80, 0.60, 0.34, 0.35))

    def test_welcome_flat_buttons_become_bronze_box_buttons(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.welcome.Show('welcome')")
        for btn in ("start", "later"):
            with self.subTest(button=btn):
                self.assertEqual(env.run(
                    f"local r,g,b,a = HARNESS.welcome.{btn}:GetBackdropColor(); return r,g,b,a"),
                    (0.0, 0.0, 0.0, 0.85))  # FlareUI box-button fill
                self.assertEqual(env.run(
                    f"local r,g,b,a = HARNESS.welcome.{btn}:GetBackdropBorderColor(); return r,g,b,a"),
                    (0.50, 0.38, 0.21, 1.0))  # bronze at rest
        # Hover lights the bronze (FlareUI's box-button hover), replacing
        # OpenXP's white hover border.
        env.run("HARNESS.welcome.start:GetScript('OnEnter')(HARNESS.welcome.start)")
        self.assertEqual(env.run(
            "local r,g,b,a = HARNESS.welcome.start:GetBackdropBorderColor(); return r,g,b,a"),
            (0.65, 0.49, 0.27, 1.0))
        env.run("HARNESS.welcome.start:GetScript('OnLeave')(HARNESS.welcome.start)")
        self.assertEqual(env.run(
            "local r,g,b,a = HARNESS.welcome.start:GetBackdropBorderColor(); return r,g,b,a"),
            (0.50, 0.38, 0.21, 1.0))
        # Button labels get FlareUI typography too.
        self.assertEqual(env.run(
            "local p,s = HARNESS.welcome.start.label:GetFont(); return p,s"),
            ("Fonts\\FRIZQT__.TTF", 11))

    def test_welcome_sub_panels_get_bronze_hairline_insets(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.welcome.Show('welcome')")
        for panel in ("badge", "panel"):
            with self.subTest(panel=panel):
                self.assertEqual(env.run(
                    f"return HARNESS.welcome.{panel}.backdrop.edgeFile"),
                    "Interface\\Buttons\\WHITE8X8")  # hairline, not border art
                self.assertEqual(env.run(
                    f"local r,g,b,a = HARNESS.welcome.{panel}:GetBackdropBorderColor(); return r,g,b,a"),
                    (0.50, 0.38, 0.21, 1.0))
        # The badge version chip reads bronze in the FlareUI palette.
        self.assertEqual(env.run(
            "local r,g,b,a = HARNESS.welcome.badgeText:GetTextColor(); return r,g,b,a"),
            (0.80, 0.60, 0.34, 1.0))
        # The route swatch keeps showing the route colour (OpenXP's own
        # ShowColor re-runs), over a bronze hairline.
        self.assertEqual(env.run(
            "local r,g,b,a = HARNESS.welcome.swatch:GetBackdropColor(); return r,g,b,a"),
            (0.72, 0.42, 1.0, 1.0))
        self.assertEqual(env.run(
            "local r,g,b,a = HARNESS.welcome.swatch:GetBackdropBorderColor(); return r,g,b,a"),
            (0.50, 0.38, 0.21, 1.0))


if __name__ == "__main__":
    unittest.main()
