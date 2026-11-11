"""Seam 1 tests: OXP-FUI behaviour observed through the lupa harness
(stubbed WoW API + fake OpenXP), per the spec's Testing Decisions.

The tests act only through public surfaces: firing client events, invoking
OpenXP refresh calls, running slash commands, registering skin modules via
the OXPFUI extension API, and reading back frame state.
"""

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from harness.env import Env  # noqa: E402

# A skin module written the way a follow-up ticket would write one: it goes
# through the engine's context (guarded frames, theme helpers) only.
ARROW_SKIN = """
OXPFUI.RegisterSkin{
  name = "test-arrow",
  windows = { "arrow" },
    Apply = function(ctx)
    local f = ctx.Frame("RXPG_ARROW")
    if not f then return end
    ctx.theme.ApplyBackdrop(f)
    local fs = f.text
    if fs then
      ctx.theme.ApplyFontString(fs, "body")
      ctx.theme.ApplyTextColor(fs, "TITLE")
    end
  end,
}
"""

CARD_SKIN = """
OXPFUI.RegisterSkin{
  name = "test-card",
  windows = { "card" },
  Apply = function(ctx)
    local f = ctx.Frame("OpenXPCard")
    if f then ctx.theme.ApplyBackdrop(f) end
  end,
}
"""

SECURE_SKIN = """
OXPFUI.RegisterSkin{
  name = "test-targets",
  windows = { "targets" },
  secure = true,
  Apply = function(ctx)
    local f = ctx.Frame("RXPTargetFrame_EnemyButton1")
    if f then ctx.theme.ApplyBackdrop(f) end
  end,
}
"""

MISSING_FRAME_SKIN = """
OXPFUI.RegisterSkin{
  name = "test-missing",
  windows = { "arrow" },
  Apply = function(ctx)
    local f = ctx.Frame("OpenXPCardDoesNotExist")
    if not f then return end
  end,
}
"""

EXCLUDED_FRAME_SKIN = """
OXPFUI.RegisterSkin{
  name = "test-greedy",
  windows = { "arrow", "card" },
  Apply = function(ctx)
    -- A sloppy skin that asks for excluded/foreign frames: the engine's
    -- resolver must refuse each one and the frames must stay untouched.
    for _, name in ipairs({
      "GameTooltip", "ItemRefTooltip", "WorldMapFrame", "Minimap",
      "RXPFrame", "RXPFrame_bottomFrame", "RXPFrameGuideName",
      "RXPG_MenuFrame", "RXP_MMMenuFrame", "RXP_WMMenuFrame",
      "RXP_WMMenuFrame_MenuFrame", "AnotherAddonFrame", "BugSackFrame",
    }) do
      ctx.Frame(name)
    end
  end,
}
"""

BROKEN_SKIN = """
OXPFUI.RegisterSkin{
  name = "test-broken",
  windows = { "arrow" },
  Apply = function() error("boom") end,
}
"""

LAYOUT_VIOLATING_SKIN = """
OXPFUI.RegisterSkin{
  name = "test-mover",
  windows = { "card" },
  Apply = function(ctx)
    local f = ctx.Frame("OpenXPCard")
    if f then
      f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
      f:SetSize(999, 999)
      f:SetScale(2)
    end
  end,
}
"""


class SkinApplication(unittest.TestCase):
    def test_registered_skin_applies_flareui_look_on_login(self):
        env = Env()
        env.install_skins(ARROW_SKIN)
        env.boot()
        edge = env.run("return RXPG_ARROW.backdrop.edgeFile")
        self.assertEqual(edge, "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga")
        self.assertEqual(env.run("return RXPG_ARROW.backdrop.edgeSize"), 16)
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW:GetBackdropBorderColor(); return r,g,b,a"), (0.65, 0.49, 0.27, 1.0))
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW:GetBackdropColor(); return r,g,b,a"), (1.0, 1.0, 1.0, 0.6))
        # Typography: Friz Quadrata 11 (body), no outline, 1px black shadow.
        self.assertEqual(env.run(
            "local p,s,f = RXPG_ARROW.text:GetFont(); return p,s,f"),
            ("Fonts\\FRIZQT__.TTF", 11, ""))
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW.text:GetTextColor(); return r,g,b,a"), (1.0, 0.82, 0.0, 1.0))

    def test_chosen_condensed_font_is_used(self):
        env = Env(db={"font": "Roboto Condensed"})
        env.install_skins(ARROW_SKIN)
        env.boot()
        self.assertEqual(env.run("return (RXPG_ARROW.text:GetFont())"),
                         "Interface\\AddOns\\OXP-FUI\\Media\\Fonts\\RobotoCondensed-Regular.ttf")

    def test_border_style_thin_uses_half_edge_size(self):
        env = Env(db={"borderStyle": "Thin"})
        env.install_skins(ARROW_SKIN)
        env.boot()
        self.assertEqual(env.run("return RXPG_ARROW.backdrop.edgeFile"),
                         "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Thin.tga")
        self.assertEqual(env.run("return RXPG_ARROW.backdrop.edgeSize"), 8)

    def test_per_window_switch_disables_that_skin_only(self):
        env = Env(db={"windows": {"arrow": False}})
        env.install_skins(ARROW_SKIN + CARD_SKIN)
        env.boot()
        # arrow skin skipped: OpenXP look kept
        self.assertEqual(env.run("return RXPG_ARROW.backdrop.edgeFile"),
                         "Interface\\Buttons\\WHITE8X8")
        # card skin still applied
        self.assertEqual(env.run("return OpenXPCard.backdrop.edgeFile"),
                         "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga")

    def test_missing_frame_is_skipped_quietly_without_errors(self):
        env = Env()
        env.install_skins(MISSING_FRAME_SKIN + ARROW_SKIN)
        env.boot()
        self.assertEqual(env.chat(), [])  # quiet: no error, no chat spam
        env.slash("/oxpfui debug")
        report = "\n".join(env.chat())
        self.assertIn("missing frame OpenXPCardDoesNotExist", report)

    def test_broken_skin_does_not_break_other_skins(self):
        env = Env()
        env.install_skins(BROKEN_SKIN + CARD_SKIN)
        env.boot()
        self.assertEqual(env.chat(), [])
        # card skin applied even though test-broken errored during the pass
        self.assertEqual(env.run("return OpenXPCard.backdrop.edgeFile"),
                         "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga")
        env.slash("/oxpfui debug")
        self.assertIn("boom", "\n".join(env.chat()))

    def test_no_position_or_size_change_ever_happens(self):
        env = Env()
        env.install_skins(ARROW_SKIN + LAYOUT_VIOLATING_SKIN + EXCLUDED_FRAME_SKIN)
        env.boot()
        # The layout-violating skin's calls are blocked by the guarded frame.
        for frame in ("OpenXPCard", "RXPG_ARROW"):
            for method in ("SetPoint", "SetSize", "SetWidth", "SetHeight",
                           "SetScale", "ClearAllPoints", "SetAllPoints"):
                self.assertEqual(env.calls_made_on(frame, method), 0,
                                 f"{frame}:{method} leaked through the guard")
        env.slash("/oxpfui debug")
        report = "\n".join(env.chat())
        self.assertIn("Blocked layout attempts: 3", report)


class Exclusions(unittest.TestCase):
    def test_excluded_and_foreign_frames_are_never_resolved_or_touched(self):
        env = Env()
        env.install_skins(EXCLUDED_FRAME_SKIN + ARROW_SKIN)
        env.boot()
        env.run("HARNESS.openxp:RenderFrame()")
        env.run("HARNESS.openxp:ReloadTheme()")
        for frame in ("RXPFrame", "RXPFrame_bottomFrame", "RXPFrameGuideName",
                      "RXPG_MenuFrame", "RXP_MMMenuFrame", "RXP_WMMenuFrame",
                      "RXP_WMMenuFrame_MenuFrame", "GameTooltip", "ItemRefTooltip",
                      "WorldMapFrame", "Minimap", "AnotherAddonFrame", "BugSackFrame"):
            self.assertEqual(env.calls_made_on(frame), 0, f"{frame} was touched")
        env.slash("/oxpfui debug")
        report = "\n".join(env.chat())
        self.assertIn("frame not skinnable: GameTooltip", report)
        self.assertIn("frame not skinnable: AnotherAddonFrame", report)

    def test_traversed_frames_are_denied_when_excluded(self):
        env = Env()
        env.install_skins(
            "OXPFUI.RegisterSkin{\n"
            "  name = 'test-via-table',\n"
            "  windows = { 'arrow' },\n"
            "  Apply = function(ctx)\n"
            "    local openxp = ctx.OpenXP()\n"
            "    -- Walk OpenXP's table to the legacy hidden window: same rules.\n"
            "    ctx.Guard(openxp and openxp.RXPFrame or nil)\n"
            "  end,\n"
            "}\n"
        )
        env.boot()
        self.assertEqual(env.calls_made_on("RXPFrame"), 0)
        env.slash("/oxpfui debug")
        self.assertIn("frame not skinnable: RXPFrame", "\n".join(env.chat()))


class LoadsQuietly(unittest.TestCase):
    def test_loads_and_boots_without_errors_or_chat_spam(self):
        env = Env()
        env.install_skins(ARROW_SKIN)
        env.boot()
        # No chat output, ever, unless the user runs /oxpfui debug.
        self.assertEqual(env.chat(), [])

    def test_master_switch_off_leaves_openxp_completely_untouched(self):
        env = Env(db={"enabled": False})
        env.install_skins(ARROW_SKIN)
        env.boot()
        # Fire every refresh path OpenXP has: OXP-FUI must stay inert, i.e.
        # every window keeps OpenXP's own look (state, not call counts: the
        # fake OpenXP legitimately restyles its own frames on refresh).
        env.run("HARNESS.openxp:RenderFrame()")
        env.run("HARNESS.openxp:ReloadTheme()")
        env.run("HARNESS.openxp.card.SkinPanels()")
        env.run("HARNESS.openxp.card.ApplyFonts()")
        for frame in ("OpenXPCard", "RXPG_ARROW", "RXPTargetFrame", "RXPItemFrame",
                      "RXPLevelSplits", "OpenXPWelcomeFrame", "OpenXPFeedbackFrame"):
            edge = env.run(f"return _G[{frame!r}].backdrop and _G[{frame!r}].backdrop.edgeFile")
            self.assertEqual(edge, "Interface\\Buttons\\WHITE8X8",
                             f"{frame} no longer has OpenXP's own backdrop")

    def test_master_switch_off_leaves_excluded_frames_without_any_call(self):
        env = Env(db={"enabled": False})
        env.install_skins(ARROW_SKIN)
        env.boot()
        env.run("HARNESS.openxp:RenderFrame()")
        for frame in ("RXPFrame", "RXPFrame_bottomFrame", "RXPFrameGuideName",
                      "RXPG_MenuFrame", "RXP_MMMenuFrame", "RXP_WMMenuFrame",
                      "RXP_WMMenuFrame_MenuFrame", "GameTooltip", "ItemRefTooltip",
                      "WorldMapFrame", "Minimap", "AnotherAddonFrame", "BugSackFrame"):
            self.assertEqual(env.calls_made_on(frame), 0,
                             f"{frame} was touched while the master switch is off")


class RefreshReapply(unittest.TestCase):
    """OXP-FUI must win over OpenXP's own theme/font/outline settings: every
    OpenXP refresh/rebuild call re-applies the skins afterwards."""

    REFRESH_CALLS = [
        "HARNESS.openxp:RenderFrame()",
        "HARNESS.openxp:ReloadTheme()",
        "HARNESS.openxp.card.Refresh(nil, true)",
        "HARNESS.openxp.card.SkinPanels()",
        "HARNESS.openxp.card.ApplyFonts()",
        "HARNESS.openxp.targeting:UpdateTargetFrame()",
        "HARNESS.openxp.targeting:RenderTargetFrameBackground()",
        "HARNESS.openxp.tracker:UpdateLevelSplits()",
        "HARNESS.openxp.activeItemFrame.UpdateVisuals()",
        "HARNESS.openxp.SetupArrow()",
        "RXPG_ARROW.UpdateVisuals()",
    ]

    def test_every_openxp_refresh_call_restores_the_skin(self):
        for call in self.REFRESH_CALLS:
            with self.subTest(call=call):
                env = Env()
                env.install_skins(ARROW_SKIN + CARD_SKIN)
                env.boot()
                self.assertEqual(env.run("return RXPG_ARROW.backdrop.edgeFile"),
                                 "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga")
                before = env.openxp_calls("RenderFrame")
                env.run(call)
                # The refresh ran (hook preserved the original) and OpenXP
                # restyled its frames back to its own look...
                self.assertGreaterEqual(env.run(f"return #RXPG_ARROW.__calls"), 1)
                # ...but OXP-FUI's skin wins again by the time it returns.
                self.assertEqual(env.run("return RXPG_ARROW.backdrop.edgeFile"),
                                 "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga",
                                 f"skin lost after {call}")
                self.assertEqual(env.run(
                    "local p,s,f = RXPG_ARROW.text:GetFont(); return p,s,f"),
                    ("Fonts\\FRIZQT__.TTF", 11, ""),
                    f"font override lost after {call}")

    def test_hooked_originals_still_run(self):
        env = Env()
        env.install_skins(ARROW_SKIN)
        env.boot()
        env.run("HARNESS.openxp:RenderFrame()")
        env.run("HARNESS.openxp:ReloadTheme()")
        self.assertGreaterEqual(env.openxp_calls("RenderFrame"), 1)
        self.assertGreaterEqual(env.openxp_calls("ReloadTheme"), 1)

    def test_refresh_before_login_does_nothing(self):
        env = Env(load_addon=False)
        env.run("_G.__OXPFUI_NAMESPACE = {}")
        from harness.env import ADDON_FILES
        import pathlib
        for fname in ADDON_FILES:
            env.run(f"_G.__chunk = assert(loadfile({str(pathlib.Path('src/OXP-FUI') / fname)!r})); "
                    "_G.__chunk('OXP-FUI', __OXPFUI_NAMESPACE)")
        env.install_skins(ARROW_SKIN)
        env.fire("ADDON_LOADED", "OXP-FUI")
        env.run("HARNESS.openxp:RenderFrame()")
        self.assertEqual(env.run("return RXPG_ARROW.backdrop.edgeFile"),
                         "Interface\\Buttons\\WHITE8X8")


class CombatDeferral(unittest.TestCase):
    def test_secure_skin_defers_in_combat_and_applies_after_combat_ends(self):
        env = Env()
        env.install_skins(SECURE_SKIN)
        env.set_combat(True)
        env.boot()
        # Deferred: the secure button keeps OpenXP's look while in combat.
        self.assertEqual(env.run("return RXPTargetFrame_EnemyButton1.backdrop.edgeFile"),
                         "Interface\\Buttons\\WHITE8X8")
        env.slash("/oxpfui debug")
        self.assertIn("in combat", "\n".join(env.chat()))
        env.chat()  # drain
        env.set_combat(False)
        env.fire("PLAYER_REGEN_ENABLED")
        self.assertEqual(env.run("return RXPTargetFrame_EnemyButton1.backdrop.edgeFile"),
                         "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga")

    def test_secure_skin_redoes_deferred_reapply_after_combat(self):
        env = Env()
        env.install_skins(SECURE_SKIN)
        env.boot()
        self.assertEqual(env.run("return RXPTargetFrame_EnemyButton1.backdrop.edgeFile"),
                         "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga")
        env.set_combat(True)
        # OpenXP rebuilds the frame look mid-combat: re-apply is deferred...
        env.run("HARNESS.openxp:RenderFrame()")
        self.assertEqual(env.run("return RXPTargetFrame_EnemyButton1.backdrop.edgeFile"),
                         "Interface\\Buttons\\WHITE8X8")
        # ...and flushed when combat ends.
        env.set_combat(False)
        env.fire("PLAYER_REGEN_ENABLED")
        self.assertEqual(env.run("return RXPTargetFrame_EnemyButton1.backdrop.edgeFile"),
                         "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga")

    def test_insecure_skin_applies_even_in_combat(self):
        env = Env()
        env.install_skins(ARROW_SKIN)
        env.set_combat(True)
        env.boot()
        self.assertEqual(env.run("return RXPG_ARROW.backdrop.edgeFile"),
                         "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga")


class VersionNote(unittest.TestCase):
    def test_debug_report_shows_versions_and_no_note_when_matching(self):
        env = Env(openxp_version="1.3.48")
        env.install_skins(ARROW_SKIN)
        env.boot()
        env.slash("/oxpfui debug")
        report = "\n".join(env.chat())
        self.assertIn("1.3.48", report)
        self.assertNotIn("differs", report)

    def test_debug_report_notes_version_mismatch(self):
        env = Env(openxp_version="1.3.40")
        env.install_skins(ARROW_SKIN)
        env.boot()
        env.slash("/oxpfui debug")
        report = "\n".join(env.chat())
        self.assertIn("1.3.40", report)
        self.assertIn("differs", report)

    def test_missing_openxp_is_reported_and_quiet(self):
        env = Env(openxp=False)
        env.install_skins(ARROW_SKIN)
        env.boot()
        self.assertEqual(env.chat(), [])
        self.assertIsNone(env.run("return _G.RXPG_ARROW"))  # no OpenXP at all
        env.slash("/oxpfui debug")
        self.assertIn("OpenXP was not found", "\n".join(env.chat()))


class SettingsPanel(unittest.TestCase):
    def test_slash_opens_flareui_styled_panel(self):
        env = Env()
        env.boot()
        env.slash("/oxpfui")
        self.assertEqual(env.run("return OXPFUIPanel:IsShown()"), True)
        # FlareUI look: bundled border art at edge size 16, bronze tint,
        # panel opacity fill, gold Friz Quadrata header with 1px shadow.
        self.assertEqual(env.run("return OXPFUIPanel.backdrop.edgeFile"),
                         "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga")
        self.assertEqual(env.run("return OXPFUIPanel.backdrop.edgeSize"), 16)
        self.assertEqual(env.run(
            "local r,g,b,a = OXPFUIPanel:GetBackdropBorderColor(); return r,g,b,a"),
            (0.65, 0.49, 0.27, 1.0))
        self.assertEqual(env.run(
            "local p,s,f = OXPFUIPanel.title:GetFont(); return p,s,f"),
            ("Fonts\\FRIZQT__.TTF", 13, ""))
        self.assertEqual(env.run(
            "local r,g,b,a = OXPFUIPanel.title:GetTextColor(); return r,g,b,a"),
            (1.0, 0.82, 0.0, 1.0))
        self.assertEqual(env.run(
            "local x,y = OXPFUIPanel.title:GetShadowOffset(); return x,y"), (1, -1))

    def test_panel_has_switch_for_every_window(self):
        env = Env()
        env.boot()
        env.slash("/oxpfui")
        from harness.env import ADDON_FILES  # noqa: F401  (order checked by build tests)
        for key in ("arrow", "card", "targets", "welcome", "feedback",
                    "tracker", "talents", "upgrades", "inventory",
                    "activeitems", "tooltips"):
            self.assertTrue(env.run(f"return OXPFUIPanel.windowBtns[{key!r}] ~= nil"),
                            f"panel missing a toggle for window '{key}'")

    def test_master_and_window_switches_write_the_saved_db(self):
        env = Env()
        env.boot()
        env.slash("/oxpfui")
        self.assertEqual(env.run("return OXPFUIDB.enabled"), True)
        env.run("OXPFUIPanel.masterBtn:Click()")
        self.assertEqual(env.run("return OXPFUIDB.enabled"), False)
        env.run("OXPFUIPanel.masterBtn:Click()")
        self.assertEqual(env.run("return OXPFUIDB.enabled"), True)

        env.run("OXPFUIPanel.windowBtns['arrow']:Click()")
        self.assertEqual(env.run("return OXPFUIDB.windows['arrow']"), False)
        env.run("OXPFUIPanel.windowBtns['arrow']:Click()")
        self.assertEqual(env.run("return OXPFUIDB.windows['arrow']"), True)

    def test_font_and_border_cycle_and_opacity_slider_write_db(self):
        env = Env()
        env.boot()
        env.slash("/oxpfui")
        # Font cycles Friz Quadrata -> Asap -> ... -> back.
        env.run("OXPFUIPanel.fontBtn:Click()")
        self.assertEqual(env.run("return OXPFUIDB.font"), "Asap Condensed")
        env.run("OXPFUIPanel.fontBtn:Click()")
        self.assertEqual(env.run("return OXPFUIDB.font"), "Barlow Condensed")
        # Border cycles Frames -> Thick -> Thin.
        self.assertEqual(env.run("return OXPFUIDB.borderStyle"), "Frames")
        env.run("OXPFUIPanel.borderBtn:Click()")
        self.assertEqual(env.run("return OXPFUIDB.borderStyle"), "Thick")
        env.run("OXPFUIPanel.borderBtn:Click()")
        self.assertEqual(env.run("return OXPFUIDB.borderStyle"), "Thin")
        # Opacity slider.
        env.run("OXPFUIPanel.opacitySlider:SetValue(0.85)")
        self.assertEqual(env.run("return OXPFUIDB.opacity"), 0.85)

    def test_setting_changes_reapply_the_skin_immediately(self):
        env = Env()
        env.install_skins(ARROW_SKIN)
        env.boot()
        env.slash("/oxpfui")
        env.run("OXPFUIPanel.fontBtn:Click()")  # -> Asap Condensed
        self.assertEqual(env.run("return (RXPG_ARROW.text:GetFont())"),
                         "Interface\\AddOns\\OXP-FUI\\Media\\Fonts\\AsapCondensed-Regular.ttf")
        env.run("OXPFUIPanel.opacitySlider:SetValue(0.3)")
        self.assertEqual(env.run(
            "local r,g,b,a = RXPG_ARROW:GetBackdropColor(); return a"), 0.3)

    def test_panel_never_touches_openxp_frames(self):
        env = Env()
        env.boot()
        frames = ("OpenXPCard", "RXPG_ARROW", "RXPTargetFrame", "RXPFrame",
                  "GameTooltip", "WorldMapFrame")
        # Baseline: the fake OpenXP styles its own frames during setup.
        baseline = {f: env.calls_made_on(f) for f in frames}
        env.slash("/oxpfui")
        env.run("OXPFUIPanel.masterBtn:Click()")
        env.run("OXPFUIPanel.windowBtns['card']:Click()")
        env.run("OXPFUIPanel.fontBtn:Click()")
        env.run("OXPFUIPanel.borderBtn:Click()")
        env.run("OXPFUIPanel.opacitySlider:SetValue(0.5)")
        env.run("OXPFUIPanel.closeBtn:Click()")
        for frame in frames:
            self.assertEqual(env.calls_made_on(frame), baseline[frame],
                             f"{frame} was touched by the settings panel")

    def test_version_note_in_panel_when_versions_differ(self):
        env = Env(openxp_version="1.3.40")
        env.boot()
        env.slash("/oxpfui")
        self.assertIsNotNone(env.run("return OXPFUIPanel.versionNote"))
        self.assertIn("1.3.40", env.run("return OXPFUIPanel.versionNote:GetText()"))
        # No note when versions match.
        env2 = Env(openxp_version="1.3.48")
        env2.boot()
        env2.slash("/oxpfui")
        self.assertIsNone(env2.run("return OXPFUIPanel.versionNote"))

    def test_panel_strings_come_from_the_locale_table(self):
        env = Env()
        env.boot()
        env.slash("/oxpfui")
        for key in ("arrow", "card", "targets", "welcome", "feedback",
                    "tracker", "talents", "upgrades", "inventory",
                    "activeitems", "tooltips"):
            label = env.run(f"return OXPFUI.L.windows[{key!r}]")
            self.assertTrue(label and len(label) > 2, f"missing locale label for {key}")
        self.assertEqual(env.run("return OXPFUIPanel.reloadNote:GetText()"),
                         env.run("return OXPFUI.L.reloadNote"))


if __name__ == "__main__":
    unittest.main()
