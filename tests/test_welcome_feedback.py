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


class FeedbackWindow(unittest.TestCase):
    def test_feedback_window_wears_flareui_backdrop_on_show(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.feedback.Show()")
        self.assertEqual(env.run("return OpenXPFeedbackFrame.backdrop.edgeFile"),
                         "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga")
        self.assertEqual(env.run("return OpenXPFeedbackFrame.backdrop.edgeSize"), 16)
        self.assertEqual(env.run(
            "local r,g,b,a = OpenXPFeedbackFrame:GetBackdropBorderColor(); return r,g,b,a"),
            (0.65, 0.49, 0.27, 1.0))
        self.assertEqual(env.run(
            "local r,g,b,a = OpenXPFeedbackFrame:GetBackdropColor(); return r,g,b,a"),
            (1.0, 1.0, 1.0, 0.6))

    def test_feedback_typography_and_palette(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.feedback.Show()")
        fb = "HARNESS.feedback"
        # Title: gold Friz Quadrata header with the 1px shadow.
        self.assertEqual(env.run(
            f"local p,s,f = {fb}.title:GetFont(); return p,s,f"),
            ("Fonts\\FRIZQT__.TTF", 13, ""))
        self.assertEqual(env.run(
            f"local r,g,b,a = {fb}.title:GetTextColor(); return r,g,b,a"),
            (1.0, 0.82, 0.0, 1.0))
        # The hint (OpenXP muted) goes FlareUI dim; the footer keeps its font
        # object's colour in OpenXP and lands on FlareUI body grey.
        self.assertEqual(env.run(
            f"local r,g,b,a = {fb}.hint:GetTextColor(); return r,g,b,a"),
            (0.55, 0.55, 0.55, 1.0))
        self.assertEqual(env.run(
            f"local r,g,b,a = {fb}.footer:GetTextColor(); return r,g,b,a"),
            (0.85, 0.85, 0.85, 1.0))
        # Every section panel: title (OpenXP accent blue) -> bronze, body
        # grey -> FlareUI grey, all in Friz Quadrata 11 with the shadow.
        for i in (1, 2, 3, 4):
            with self.subTest(panel=i):
                self.assertEqual(env.run(
                    f"local p,s = {fb}.panels[{i}].head:GetFont(); return p,s"),
                    ("Fonts\\FRIZQT__.TTF", 11))
                self.assertEqual(env.run(
                    f"local r,g,b,a = {fb}.panels[{i}].head:GetTextColor(); return r,g,b,a"),
                    (0.80, 0.60, 0.34, 1.0))
                self.assertEqual(env.run(
                    f"local r,g,b,a = {fb}.panels[{i}].body:GetTextColor(); return r,g,b,a"),
                    (0.85, 0.85, 0.85, 1.0))
                self.assertEqual(env.run(
                    f"local x,y = {fb}.panels[{i}].body:GetShadowOffset(); return x,y"),
                    (1, -1))

    def test_feedback_panels_boxes_and_button_get_flareui_chrome(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.feedback.Show()")
        fb = "HARNESS.feedback"
        for i in (1, 2, 3, 4):
            with self.subTest(panel=i):
                # Section panel: bronze hairline inset, not border art.
                self.assertEqual(env.run(
                    f"local r,g,b,a = {fb}.panels[{i}].panel:GetBackdropBorderColor(); return r,g,b,a"),
                    (0.50, 0.38, 0.21, 1.0))
                # Link box: inset too, link text in FlareUI body grey.
                self.assertEqual(env.run(
                    f"local r,g,b,a = {fb}.panels[{i}].box:GetBackdropBorderColor(); return r,g,b,a"),
                    (0.50, 0.38, 0.21, 1.0))
                self.assertEqual(env.run(
                    f"local r,g,b,a = {fb}.panels[{i}].box:GetTextColor(); return r,g,b,a"),
                    (0.85, 0.85, 0.85, 1.0))
        # The one action button is a bronze box button with a styled label.
        self.assertEqual(env.run(
            f"local r,g,b,a = {fb}.panels[1].btn:GetBackdropColor(); return r,g,b,a"),
            (0.0, 0.0, 0.0, 0.85))
        self.assertEqual(env.run(
            f"local r,g,b,a = {fb}.panels[1].btn:GetBackdropBorderColor(); return r,g,b,a"),
            (0.50, 0.38, 0.21, 1.0))
        self.assertEqual(env.run(
            f"local p,s = {fb}.panels[1].btn.label:GetFont(); return p,s"),
            ("Fonts\\FRIZQT__.TTF", 11))


class GatingAndRobustness(unittest.TestCase):
    # Every OpenXP refresh/rebuild path that restyles these windows; the
    # skin must be back on top by the time each call returns. The two Show()
    # calls are the lazy-creation path: the window appears with OpenXP's
    # look, the engine re-applies after the hook.
    REFRESH_CALLS = [
        "HARNESS.openxp:RenderFrame()",
        "HARNESS.openxp:ReloadTheme()",
        "HARNESS.openxp.card.Refresh(nil, true)",
        "HARNESS.openxp.card.SkinPanels()",
        "HARNESS.openxp.card.ApplyFonts()",
        "HARNESS.openxp.welcome.Show('update')",
        "HARNESS.openxp.feedback.Show()",
    ]

    FLAREUI_EDGE = "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga"

    def test_skin_reapplied_after_every_openxp_refresh(self):
        for call in self.REFRESH_CALLS:
            with self.subTest(call=call):
                env = Env()
                env.boot()
                # Create both windows first so refreshes have something to
                # restyle (the fake's refresh calls reset the OpenXP look).
                env.run("HARNESS.openxp.welcome.Show('welcome')")
                env.run("HARNESS.openxp.feedback.Show()")
                env.run(call)
                for frame in ("OpenXPWelcomeFrame", "OpenXPFeedbackFrame"):
                    self.assertEqual(env.run(f"return {frame}.backdrop.edgeFile"),
                                     self.FLAREUI_EDGE,
                                     f"skin lost on {frame} after {call}")
                self.assertEqual(env.run(
                    "local r,g,b,a = HARNESS.welcome.title:GetTextColor(); return r,g,b,a"),
                    (1.0, 0.82, 0.0, 1.0), f"title lost after {call}")
                self.assertEqual(env.run(
                    "local r,g,b,a = HARNESS.feedback.panels[1].head:GetTextColor(); return r,g,b,a"),
                    (0.80, 0.60, 0.34, 1.0), f"palette lost after {call}")

    def test_lazy_windows_are_skipped_quietly_at_login_then_skinned_on_show(self):
        env = Env()
        env.boot()
        # Neither window exists yet at login: quiet, no chat, but the skip
        # is visible in the debug report.
        self.assertIsNone(env.run("return _G.OpenXPWelcomeFrame"))
        self.assertIsNone(env.run("return _G.OpenXPFeedbackFrame"))
        self.assertEqual(env.chat(), [])
        env.slash("/oxpfui debug")
        report = "\n".join(env.chat())
        self.assertIn("missing frame OpenXPWelcomeFrame", report)
        self.assertIn("missing frame OpenXPFeedbackFrame", report)
        env.run("HARNESS.chat = {}")  # drain: print() appends to this table
        # First Show creates and OpenXP-styles the window; the hook brings
        # the skin straight back on top.
        env.run("HARNESS.openxp.welcome.Show('welcome')")
        self.assertEqual(env.run("return OpenXPWelcomeFrame.backdrop.edgeFile"),
                         self.FLAREUI_EDGE)
        self.assertEqual(env.chat(), [])

    def test_welcome_switch_off_leaves_only_welcome_untouched(self):
        env = Env(db={"windows": {"welcome": False}})
        env.boot()
        env.run("HARNESS.openxp.welcome.Show('welcome')")
        env.run("HARNESS.openxp.feedback.Show()")
        # Welcome keeps OpenXP's own look, children included.
        self.assertEqual(env.run("return OpenXPWelcomeFrame.backdrop.edgeFile"),
                         "Interface\\Buttons\\WHITE8X8")
        self.assertEqual(env.run(
            "local r,g,b,a = HARNESS.welcome.title:GetTextColor(); return r,g,b,a"),
            (1.0, 1.0, 1.0, 1.0))
        self.assertIsNone(env.run("return HARNESS.welcome.title:GetFont()"))
        # The feedback window is still skinned.
        self.assertEqual(env.run("return OpenXPFeedbackFrame.backdrop.edgeFile"),
                         self.FLAREUI_EDGE)

    def test_feedback_switch_off_leaves_only_feedback_untouched(self):
        env = Env(db={"windows": {"feedback": False}})
        env.boot()
        env.run("HARNESS.openxp.welcome.Show('welcome')")
        env.run("HARNESS.openxp.feedback.Show()")
        self.assertEqual(env.run("return OpenXPFeedbackFrame.backdrop.edgeFile"),
                         "Interface\\Buttons\\WHITE8X8")
        self.assertEqual(env.run(
            "local r,g,b,a = HARNESS.feedback.title:GetTextColor(); return r,g,b,a"),
            (1.0, 1.0, 1.0, 1.0))
        self.assertEqual(env.run("return OpenXPWelcomeFrame.backdrop.edgeFile"),
                         self.FLAREUI_EDGE)

    def test_master_off_leaves_both_windows_in_openxp_look(self):
        env = Env(db={"enabled": False})
        env.boot()
        env.run("HARNESS.openxp.welcome.Show('welcome')")
        env.run("HARNESS.openxp.feedback.Show()")
        env.run("HARNESS.openxp:RenderFrame()")
        for frame in ("OpenXPWelcomeFrame", "OpenXPFeedbackFrame"):
            self.assertEqual(env.run(f"return {frame}.backdrop.edgeFile"),
                             "Interface\\Buttons\\WHITE8X8")
        # OpenXP's own colours survive on the children too.
        self.assertEqual(env.run(
            "local r,g,b,a = HARNESS.welcome.start:GetBackdropColor(); return r,g,b,a"),
            (28 / 255, 70 / 255, 104 / 255, 1.0))
        self.assertEqual(env.run(
            "local r,g,b,a = HARNESS.feedback.panels[2].panel:GetBackdropBorderColor(); return r,g,b,a"),
            (60 / 255, 66 / 255, 78 / 255, 1.0))
        self.assertEqual(env.chat(), [])

    def test_no_layout_calls_are_ever_made(self):
        env = Env()
        env.boot()
        env.run("HARNESS.openxp.welcome.Show('welcome')")
        env.run("HARNESS.openxp.feedback.Show()")
        env.run("HARNESS.openxp:RenderFrame()")
        targets = ["OpenXPWelcomeFrame", "OpenXPFeedbackFrame",
                   "HARNESS.welcome.badge", "HARNESS.welcome.panel",
                   "HARNESS.welcome.start", "HARNESS.welcome.swatch",
                   "HARNESS.feedback.panels[1].panel",
                   "HARNESS.feedback.panels[1].box"]
        for target in targets:
            for method in ("SetPoint", "SetSize", "SetWidth", "SetHeight",
                           "SetScale", "ClearAllPoints", "SetAllPoints"):
                self.assertEqual(env.calls_made_on(target, method), 0,
                                 f"{target}:{method} was called")
        env.slash("/oxpfui debug")
        self.assertIn("Blocked layout attempts: 0", "\n".join(env.chat()))

    def test_border_and_opacity_settings_reach_both_windows(self):
        env = Env(db={"borderStyle": "Thin", "opacity": 0.3})
        env.boot()
        env.run("HARNESS.openxp.welcome.Show('welcome')")
        env.run("HARNESS.openxp.feedback.Show()")
        for frame in ("OpenXPWelcomeFrame", "OpenXPFeedbackFrame"):
            self.assertEqual(env.run(f"return {frame}.backdrop.edgeFile"),
                             "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Thin.tga")
            self.assertEqual(env.run(f"return {frame}.backdrop.edgeSize"), 8)
            self.assertEqual(env.run(
                f"local r,g,b,a = {frame}:GetBackdropColor(); return a"), 0.3)
        # Insets sit a step firmer than the window fill.
        self.assertEqual(env.run(
            "local r,g,b,a = HARNESS.welcome.panel:GetBackdropColor(); return a"), 0.55)








if __name__ == "__main__":
    unittest.main()
