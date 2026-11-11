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


class ArrowPerFrameState(unittest.TestCase):
    """OpenXP repaints ring tint and distance colour EVERY FRAME from the
    OnUpdate handler (card.ArrowUpdate). The skin must win over that repaint
    in both states while keeping OpenXP's logic and text content."""

    def tick(self, env, distance=None):
        if distance is not None:
            env.run(f"RXPG_ARROW.distance = {distance!r}")
        env.run("HARNESS.ArrowTick()")

    def test_traveling_state_survives_openxp_per_frame_repaint(self):
        env = Env()
        env.boot()
        self.tick(env, distance=100)
        # OpenXP's update ran (logic preserved) and repainted its blue ring...
        self.assertGreaterEqual(env.openxp_calls("ArrowUpdate"), 1)
        self.assertGreaterEqual(env.openxp_calls("DrawArrow"), 1)
        # ...but FlareUI amber survives it, with OpenXP's dimmed travelling
        # ring alpha.
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.dialRing:GetVertexColor(); return r,g,b,a"),
            AMBER + (0.6,))
        # Distance text: OpenXP's content and position logic, FlareUI colour.
        self.assertEqual(env.run("return RXPG_ARROW.oxpDist:GetText()"), "100 yd")
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.oxpDist:GetTextColor(); return r,g,b,a"),
            OBJECTIVE + (1.0,))
        self.assertEqual(env.run("return RXPG_ARROW.texture:IsShown()"), True)
        self.assertEqual(env.run("return RXPG_ARROW.arrived:IsShown()"), False)
        # Label text is OpenXP's (element title), never rewritten by the skin.
        self.assertEqual(env.run("return RXPG_ARROW.oxpLabel:GetText()"),
                         "Kill: Forest Wolf Pack")

    def test_arrived_state_is_flareui_green(self):
        env = Env()
        env.boot()
        self.tick(env, distance=3)
        # OpenXP decided "arrived" (check shown, pointer hidden) —
        self.assertEqual(env.run("return RXPG_ARROW.arrived:IsShown()"), True)
        self.assertEqual(env.run("return RXPG_ARROW.texture:IsShown()"), False)
        # — and the skin colours that state FlareUI green, full alpha.
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.dialRing:GetVertexColor(); return r,g,b,a"),
            GREEN + (1.0,))
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.oxpDist:GetTextColor(); return r,g,b,a"),
            GREEN + (1.0,))
        self.assertEqual(env.run("return RXPG_ARROW.oxpDist:GetText()"), "Here")

    def test_state_transitions_reassert_each_frame(self):
        env = Env()
        env.boot()
        for distance, ring in ((100, AMBER + (0.6,)), (3, GREEN + (1.0,)),
                               (250, AMBER + (0.6,)), (0, GREEN + (1.0,))):
            with self.subTest(distance=distance):
                self.tick(env, distance=distance)
                self.assertEqual(env.run(
                    "local r,g,b,a = RXPG_ARROW.dialRing:GetVertexColor();"
                    " return r,g,b,a"), ring)


class ArrowTypography(unittest.TestCase):
    """Story 9: distance and label text in the chosen FlareUI font with a
    1px shadow (no outline — OXP-FUI wins over OpenXP's OUTLINE setting)."""

    def test_dist_and_label_use_flareui_font_with_shadow(self):
        env = Env()
        env.boot()
        # Distance: the arrow's headline number — header size 13.
        self.assertEqual(env.run(
            "local p,s,f = RXPG_ARROW.oxpDist:GetFont(); return p,s,f"),
            ("Fonts\\FRIZQT__.TTF", 13, ""))
        # Label: supporting text — body size 11.
        self.assertEqual(env.run(
            "local p,s,f = RXPG_ARROW.oxpLabel:GetFont(); return p,s,f"),
            ("Fonts\\FRIZQT__.TTF", 11, ""))
        for fs in ("oxpDist", "oxpLabel"):
            self.assertEqual(env.run(
                f"local r,g,b,a = RXPG_ARROW.{fs}:GetShadowColor(); return r,g,b,a"),
                (0.0, 0.0, 0.0, 1.0), fs)
            self.assertEqual(env.run(
                f"local x,y = RXPG_ARROW.{fs}:GetShadowOffset(); return x,y"),
                (1, -1), fs)

    def test_chosen_condensed_font_is_used_on_arrow_text(self):
        env = Env(db={"font": "Fira Condensed"})
        env.boot()
        path = "Interface\\AddOns\\OXP-FUI\\Media\\Fonts\\FiraSansExtraCondensed-Regular.ttf"
        self.assertEqual(env.run("return (RXPG_ARROW.oxpDist:GetFont())"), path)
        self.assertEqual(env.run("return (RXPG_ARROW.oxpLabel:GetFont())"), path)

    def test_label_text_colour_is_flareui_objective_grey(self):
        env = Env()
        env.boot()
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.oxpLabel:GetTextColor(); return r,g,b,a"),
            OBJECTIVE + (1.0,))


class ArrowRefreshReapply(unittest.TestCase):
    """Story 23 / override policy: OXP-FUI re-applies after OpenXP's
    refresh/rebuild calls, including the arrow-specific ones."""

    REFRESH_CALLS = [
        "HARNESS.openxp:RenderFrame()",
        "HARNESS.openxp:ReloadTheme()",
        "HARNESS.openxp.SetupArrow()",
        "RXPG_ARROW.UpdateVisuals()",
        "HARNESS.openxp.card.ApplyFonts()",
    ]

    def test_every_arrow_refresh_call_keeps_the_flareui_look(self):
        for call in self.REFRESH_CALLS:
            with self.subTest(call=call):
                env = Env()
                env.boot()
                env.run("RXPG_ARROW.distance = 100")
                env.run(call)
                # The original ran (hook preserved it)...
                self.assertGreaterEqual(env.run("return #RXPG_ARROW.__calls"), 1)
                # ...and the FlareUI look survived it: pointer desaturated +
                # amber, ring amber, OpenXP's outline font overridden.
                self.assertEqual(env.run(
                    "return RXPG_ARROW.texture:GetDesaturated()"), True)
                self.assertEqual(env.run(
                    "local r,g,b,a = RXPG_ARROW.texture:GetVertexColor(); return r,g,b,a"),
                    AMBER + (1.0,))
                self.assertEqual(env.run(
                    "local r,g,b,a = RXPG_ARROW.dialRing:GetVertexColor(); return r,g,b,a"),
                    AMBER + (0.6,))
                self.assertEqual(env.run(
                    "local p,s,f = RXPG_ARROW.oxpDist:GetFont(); return p,s,f"),
                    ("Fonts\\FRIZQT__.TTF", 13, ""))
                self.assertEqual(env.run(
                    "local p,s,f = RXPG_ARROW.oxpLabel:GetFont(); return p,s,f"),
                    ("Fonts\\FRIZQT__.TTF", 11, ""))

    def test_openxp_per_frame_repaint_after_refresh_still_loses(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp:ReloadTheme()")
        env.run("RXPG_ARROW.distance = 40")
        env.run("HARNESS.ArrowTick()")
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.dialRing:GetVertexColor(); return r,g,b,a"),
            AMBER + (0.6,))


class ArrowSwitches(unittest.TestCase):
    """Stories 24-25: master and per-window switches leave the arrow with
    OpenXP's own look — including after refresh calls and per-frame ticks."""

    OXP_BLUE_RING = (90 / 255, 184 / 255, 1.0, 0.6)

    def assert_openxp_look(self, env):
        # Everything the skin would have changed keeps OpenXP's values.
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.dialRing:GetVertexColor(); return r,g,b,a"),
            self.OXP_BLUE_RING)
        self.assertEqual(env.run("return RXPG_ARROW.texture:GetDesaturated()"), False)
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.dialBg:GetVertexColor(); return r,g,b,a"),
            (16 / 255, 17 / 255, 21 / 255, 0.85))
        self.assertEqual(env.run(
            "local p,s,f = RXPG_ARROW.oxpDist:GetFont(); return p,s,f"),
            ("Fonts\\ARIALN.TTF", 17, "OUTLINE"))

    def test_arrow_window_switch_off_leaves_arrow_untouched(self):
        env = Env(db={"windows": {"arrow": False}})
        env.boot()
        env.run("HARNESS.openxp:RenderFrame()")
        env.run("HARNESS.openxp.card.ApplyFonts()")
        env.run("RXPG_ARROW.distance = 100")
        env.run("HARNESS.ArrowTick()")
        self.assert_openxp_look(env)
        self.assertEqual(env.chat(), [])

    def test_arrow_window_switched_off_mid_session_stops_reasserting(self):
        env = Env()
        env.boot()
        env.run("RXPG_ARROW.distance = 100")
        env.run("HARNESS.ArrowTick()")
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.dialRing:GetVertexColor(); return r,g,b,a"),
            AMBER + (0.6,))
        # The settings panel flips the switch; the engine's next pass skips
        # the skin, and the chained per-frame re-assert goes quiet — OpenXP's
        # own repaint wins again from the next tick on.
        env.run("OXPFUIDB.windows['arrow'] = false")
        env.run("OXPFUI.Reapply('settings change')")
        env.chat()  # drain
        env.run("HARNESS.ArrowTick()")
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.dialRing:GetVertexColor(); return r,g,b,a"),
            self.OXP_BLUE_RING)
        env.slash("/oxpfui debug")
        self.assertIn("window 'arrow' is switched off", "\n".join(env.chat()))

    def test_master_switch_off_leaves_arrow_untouched(self):
        env = Env(db={"enabled": False})
        env.boot()
        env.run("HARNESS.openxp:RenderFrame()")
        env.run("HARNESS.openxp.SetupArrow()")
        env.run("RXPG_ARROW.distance = 100")
        env.run("HARNESS.ArrowTick()")
        self.assert_openxp_look(env)
        # OpenXP's own OnUpdate handler runs un-chained.
        self.assertGreaterEqual(env.openxp_calls("ArrowUpdate"), 1)
        self.assertEqual(env.chat(), [])


if __name__ == "__main__":
    unittest.main()
