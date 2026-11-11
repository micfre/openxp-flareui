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


if __name__ == "__main__":
    unittest.main()
