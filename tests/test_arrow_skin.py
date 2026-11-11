"""Seam 1 tests for the waypoint-arrow skin (ticket #3, spec section
"Waypoint arrow", user stories 7-10).

The real skin ships as part of the addon, so unlike the engine tests in
test_skin.py nothing is registered here: each Env loads ArrowSkin.lua with
the rest of the addon. The fake OpenXP models OpenXP's arrow surface
(dial textures, dist/label font strings, per-frame ArrowUpdate repaint,
drag handlers) per the research notes.
"""

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from harness.env import Env  # noqa: E402

# FlareUI palette values (Theme.lua / flareui-style.md).
AMBER = (0.80, 0.60, 0.34)          # C.ZONE — ring and pointer
GREEN = (0.13, 1.0, 0.13)           # C.TITLE_DONE — arrived state
WARM_DARK = (0.10, 0.08, 0.06)      # C.FILL — the dial disc
OBJECTIVE = (0.85, 0.85, 0.85)      # C.OBJECTIVE — travelling text

ARROW_CHILDREN = (  # fields on RXPG_ARROW holding regions, by creation
    "texture", "text", "dialBg", "dialRing", "arrived", "oxpDist", "oxpLabel",
)

LAYOUT_METHODS = (
    "SetPoint", "SetAllPoints", "ClearAllPoints", "SetSize", "SetWidth",
    "SetHeight", "SetScale", "SetMaxResize", "SetMinResize", "StartMoving",
    "StartSizing", "StopMovingOrSizing", "SetUserPlaced",
    "SetDontSavePosition", "SetClampedToScreen", "SetMovable", "SetResizable",
)


class ArrowLook(unittest.TestCase):
    """Stories 7-8: ring and pointer amber, disc FlareUI warm dark, arrived
    check green — applied when the addon loads."""

    def test_traveling_arrow_tints_after_login(self):
        env = Env()
        env.boot()
        # Ring: FlareUI amber, dimmed like OpenXP's travelling ring (0.6).
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.dialRing:GetVertexColor(); return r,g,b,a"),
            AMBER + (0.6,))
        # Disc: FlareUI warm near-black at OpenXP's dial opacity.
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.dialBg:GetVertexColor(); return r,g,b,a"),
            WARM_DARK + (0.85,))
        # Pointer: desaturated first (it contains a blue part), then amber.
        self.assertEqual(env.run("return RXPG_ARROW.texture:GetDesaturated()"), True)
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.texture:GetVertexColor(); return r,g,b,a"),
            AMBER + (1.0,))

    def test_arrived_check_texture_is_flareui_green(self):
        env = Env()
        env.boot()
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.arrived:GetVertexColor(); return r,g,b,a"),
            GREEN + (1.0,))


if __name__ == "__main__":
    unittest.main()
