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


if __name__ == "__main__":
    unittest.main()
