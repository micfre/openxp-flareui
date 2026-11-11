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
                      "RXP_WMMenuFrame_MenuFrame", "WorldMapFrame", "Minimap",
                      "AnotherAddonFrame", "BugSackFrame"):
            self.assertEqual(env.calls_made_on(frame), 0, f"{frame} was touched")
        # The tooltip frames are excluded too (story 18/43): drive a full unit
        # tooltip — Blizzard line, then OpenXP's quest lines, styled — and
        # assert the frame itself was never modified.
        env.run("HARNESS.units.mouseover = { name = 'Forest Lurker', attackable = true }")
        env.run("GameTooltip:ClearLines()")
        env.run("GameTooltip:AddLine('Forest Lurker')")
        env.run("HARNESS.TooltipSetUnit()")
        for frame in ("GameTooltip", "ItemRefTooltip"):
            for method in TOOLTIP_FRAME_METHODS:
                self.assertEqual(env.calls_made_on(frame, method), 0,
                                 f"{frame}:{method} was called")
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
                      "RXP_WMMenuFrame_MenuFrame", "WorldMapFrame", "Minimap",
                      "AnotherAddonFrame", "BugSackFrame"):
            self.assertEqual(env.calls_made_on(frame), 0,
                             f"{frame} was touched while the master switch is off")
        # The tooltip frames keep OpenXP's own hook registrations (they are
        # OpenXP's, not ours) but are never modified by OXP-FUI.
        for frame in ("GameTooltip", "ItemRefTooltip"):
            for method in TOOLTIP_FRAME_METHODS:
                self.assertEqual(env.calls_made_on(frame, method), 0,
                                 f"{frame}:{method} while the master switch is off")


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


FLAREUI_EDGE = "Interface\\AddOns\\OXP-FUI\\Media\\Borders\\FlareUI-Frames.tga"
OPENXP_EDGE = "Interface\\Buttons\\WHITE8X8"
FRIZQ = "Fonts\\FRIZQT__.TTF"

# Story 43 for the tooltip frames: OpenXP itself registers script hooks on
# GameTooltip/ItemRefTooltip at load, so "no call at all" is not the invariant
# there — "the frame is never modified" is. Any of these methods would change
# the frame itself (backdrop, size, position, strata, ...).
TOOLTIP_FRAME_METHODS = (
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "SetPoint", "SetAllPoints", "ClearAllPoints",
    "SetSize", "SetWidth", "SetHeight", "SetScale",
    "SetFrameStrata", "SetFrameLevel", "SetAlpha", "SetMovable",
    "SetClampedToScreen", "SetToplevel", "SetHitRectInsets",
    "StartMoving", "StartSizing",
)

# The whole Quest Targets family (spec story 11): the frame, its title strip,
# the section labels and the secure target rows.
TARGET_ROWS = ("RXPTargetFrame_EnemyButton1", "RXPTargetFrame_EnemyButton2",
               "RXPTargetFrame_FriendlyButton1")


class QuestTargets(unittest.TestCase):
    """Ticket #5 (stories 11-12): the shipped Quest Targets skin, observed
    only through the skin seam — boot the real addon files against the fake
    OpenXP and read frame state back."""

    def test_frame_title_and_rows_get_flareui_look_after_login(self):
        env = Env()
        env.boot()
        # Frame: FlareUI backdrop like the guide card.
        self.assertEqual(env.run("return RXPTargetFrame.backdrop.edgeFile"), FLAREUI_EDGE)
        self.assertEqual(env.run("return RXPTargetFrame.backdrop.edgeSize"), 16)
        self.assertEqual(env.run(
            "local r,g,b,a = RXPTargetFrame:GetBackdropBorderColor(); return r,g,b,a"),
            (0.65, 0.49, 0.27, 1.0))
        self.assertEqual(env.run(
            "local r,g,b,a = RXPTargetFrame:GetBackdropColor(); return r,g,b,a"),
            (1.0, 1.0, 1.0, 0.6))
        # Title: FlareUI header typography, gold, 1px black shadow.
        self.assertEqual(env.run(
            "local p,s,f = RXPTargetFrame_title.text:GetFont(); return p,s,f"),
            (FRIZQ, 13, ""))
        self.assertEqual(env.run(
            "local r,g,b,a = RXPTargetFrame_title.text:GetTextColor(); return r,g,b,a"),
            (1.0, 0.82, 0.0, 1.0))
        self.assertEqual(env.run(
            "local x,y = RXPTargetFrame_title.text:GetShadowOffset(); return x,y"), (1, -1))
        self.assertEqual(env.run(
            "local r,g,b,a = RXPTargetFrame_title.text:GetShadowColor(); return r,g,b,a"),
            (0.0, 0.0, 0.0, 1.0))
        # Key hint ("nearest T"): body text, dim grey.
        self.assertEqual(env.run(
            "local p,s,f = RXPTargetFrame_title.keyHint:GetFont(); return p,s,f"),
            (FRIZQ, 11, ""))
        self.assertEqual(env.run(
            "local r,g,b,a = RXPTargetFrame_title.keyHint:GetTextColor(); return r,g,b,a"),
            (0.55, 0.55, 0.55, 1.0))
        # Section labels ("KILL" / "TALK TO"): FlareUI zone bronze, title size.
        for key in ("enemy", "friendly"):
            self.assertEqual(env.run(
                f"local p,s,f = RXPTargetFrame.sections[{key!r}]:GetFont(); return p,s,f"),
                (FRIZQ, 12, ""), f"section {key} font")
            self.assertEqual(env.run(
                f"local r,g,b,a = RXPTargetFrame.sections[{key!r}]:GetTextColor(); return r,g,b,a"),
                (0.80, 0.60, 0.34, 1.0), f"section {key} colour")
        # Rows: name in light grey body text, keybind hint dim, bronze strip.
        for row in TARGET_ROWS:
            self.assertEqual(env.run(
                f"local p,s,f = _G[{row!r}].label:GetFont(); return p,s,f"),
                (FRIZQ, 11, ""), f"{row} label font")
            self.assertEqual(env.run(
                f"local r,g,b,a = _G[{row!r}].label:GetTextColor(); return r,g,b,a"),
                (0.85, 0.85, 0.85, 1.0), f"{row} label colour")
            self.assertEqual(env.run(
                f"local p,s,f = _G[{row!r}].key:GetFont(); return p,s,f"),
                (FRIZQ, 11, ""), f"{row} key font")
            self.assertEqual(env.run(
                f"local r,g,b,a = _G[{row!r}].key:GetTextColor(); return r,g,b,a"),
                (0.55, 0.55, 0.55, 1.0), f"{row} key colour")
            self.assertEqual(env.run(
                f"local c = _G[{row!r}].bar.__colorTexture; return c[1],c[2],c[3],c[4]"),
                (0.80, 0.60, 0.34, 1.0), f"{row} class strip not bronze")
        # Quiet: no chat output from any of this.
        self.assertEqual(env.chat(), [])


    # -- helpers -----------------------------------------------------------

    def assert_flareui_look(self, env):
        """The visible identity of the skin, on frame + title + one row of
        each kind (enemy rows sit behind the friendly rows' section)."""
        self.assertEqual(env.run("return RXPTargetFrame.backdrop.edgeFile"), FLAREUI_EDGE)
        self.assertEqual(env.run(
            "local p,s,f = RXPTargetFrame_title.text:GetFont(); return p,s,f"),
            (FRIZQ, 13, ""))
        self.assertEqual(env.run(
            "local r,g,b,a = RXPTargetFrame_title.text:GetTextColor(); return r,g,b,a"),
            (1.0, 0.82, 0.0, 1.0))
        for row in ("RXPTargetFrame_EnemyButton2", "RXPTargetFrame_FriendlyButton1"):
            self.assertEqual(env.run(
                f"local p,s,f = _G[{row!r}].label:GetFont(); return p,s,f"),
                (FRIZQ, 11, ""), f"{row} label")
            self.assertEqual(env.run(
                f"local c = _G[{row!r}].bar.__colorTexture; return c[1],c[2],c[3]"),
                (0.80, 0.60, 0.34), f"{row} strip")

    def assert_openxp_look(self, env):
        """OpenXP's own look kept (nothing skinned)."""
        self.assertEqual(env.run("return RXPTargetFrame.backdrop.edgeFile"), OPENXP_EDGE)
        self.assertEqual(env.run(
            "local p,s,f = RXPTargetFrame_title.text:GetFont(); return p,s,f"),
            ("Fonts\\ARIALN.TTF", 11, ""))
        self.assertEqual(env.run(
            "local c = RXPTargetFrame_EnemyButton1.bar.__colorTexture; return c[1],c[2],c[3]"),
            (1.0, 112 / 255, 67 / 255))
        self.assertEqual(env.run(
            "local p,s,f = RXPTargetFrame_FriendlyButton1.label:GetFont(); return p,s,f"),
            ("Fonts\\ARIALN.TTF", 12, ""))

    # -- re-apply after OpenXP refreshes (story 22-23) ----------------------

    def test_skin_wins_after_every_openxp_refresh_of_the_target_frame(self):
        refreshes = [
            "HARNESS.openxp:RenderFrame()",
            "HARNESS.openxp:ReloadTheme()",
            "HARNESS.openxp.card.SkinPanels()",
            "HARNESS.openxp.card.ApplyFonts()",
            "HARNESS.openxp.targeting:UpdateTargetFrame()",
            "HARNESS.openxp.targeting:RenderTargetFrameBackground()",
        ]
        for call in refreshes:
            with self.subTest(call=call):
                env = Env()
                env.boot()
                env.run(call)
                self.assert_flareui_look(env)
                self.assertEqual(env.chat(), [])

    # -- combat deferral (stories 12, 30) -----------------------------------

    def test_request_during_combat_defers_until_combat_ends(self):
        env = Env()
        env.set_combat(True)
        env.boot()
        # While in combat nothing changed: the whole family keeps OpenXP's
        # look (secure rows included).
        self.assert_openxp_look(env)
        self.assertEqual(env.run("return RXPTargetFrame_EnemyButton1.backdrop.edgeFile"),
                         OPENXP_EDGE)
        env.slash("/oxpfui debug")
        self.assertIn("in combat", "\n".join(env.chat()))
        # Combat ends: the deferred pass applies.
        env.set_combat(False)
        env.fire("PLAYER_REGEN_ENABLED")
        self.assert_flareui_look(env)

    def test_no_call_is_made_on_any_targets_frame_while_in_combat(self):
        env = Env()
        family = ("RXPTargetFrame", "RXPTargetFrame_title",
                  "RXPTargetFrame_EnemyButton1", "RXPTargetFrame_EnemyButton2",
                  "RXPTargetFrame_FriendlyButton1",
                  "OpenXPTargetMobs", "OpenXPTargetNPCs")
        # Baseline: everything the fake OpenXP itself did while building.
        before = {f: env.calls_made_on(f) for f in family}
        env.set_combat(True)
        env.boot()
        env.run("HARNESS.openxp.targeting:UpdateTargetFrame()")  # OpenXP bails too
        for f in family:
            self.assertEqual(env.calls_made_on(f), before[f],
                             f"{f} was touched while in combat")

    # -- targeting never blocked (story 12) ---------------------------------

    def test_targeting_handlers_still_work_and_secure_setup_is_untouched(self):
        env = Env()
        env.boot()
        # The click still reaches OpenXP's handler (the fake's stand-in for
        # the secure macro template running /targetexact).
        self.assertEqual(env.openxp_calls("RXPTargetFrame_EnemyButton1 click"), 0)
        env.run("RXPTargetFrame_EnemyButton1:Click()")
        self.assertEqual(env.openxp_calls("RXPTargetFrame_EnemyButton1 click"), 1)
        # Attributes, scripts and click registrations are exactly what the
        # fake OpenXP set up — the skin never touched them.
        self.assertEqual(env.run("return RXPTargetFrame_EnemyButton1:GetAttribute('type')"),
                         "macro")
        self.assertEqual(env.run("return RXPTargetFrame_EnemyButton1:GetAttribute('macrotext')"),
                         "/targetexact Forest Lurker")
        self.assertEqual(env.calls_made_on("RXPTargetFrame_EnemyButton1", "SetAttribute"), 2)
        self.assertEqual(env.calls_made_on("RXPTargetFrame_EnemyButton1", "SetScript"), 1)
        self.assertEqual(env.calls_made_on("RXPTargetFrame_EnemyButton1", "RegisterForClicks"), 1)
        # The hidden keybound quick-target buttons are never styled at all.
        for f in ("OpenXPTargetMobs", "OpenXPTargetNPCs"):
            for method in ("SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
                           "SetFont", "SetTextColor", "SetTexture", "SetColorTexture"):
                self.assertEqual(env.calls_made_on(f, method), 0,
                                 f"{f}:{method} was called")

    # -- switches (stories 24-25) -------------------------------------------

    def test_per_window_switch_off_leaves_the_targets_family_untouched(self):
        env = Env(db={"windows": {"targets": False}})
        env.boot()
        env.run("HARNESS.openxp:RenderFrame()")
        self.assert_openxp_look(env)
        env.slash("/oxpfui debug")
        self.assertIn("window 'targets' is switched off", "\n".join(env.chat()))

    def test_master_switch_off_leaves_the_targets_family_untouched(self):
        env = Env(db={"enabled": False})
        env.boot()
        env.run("HARNESS.openxp:RenderFrame()")
        env.run("HARNESS.openxp.targeting:UpdateTargetFrame()")
        self.assert_openxp_look(env)
        self.assertEqual(env.chat(), [])

    # -- robustness (stories 31-32) -----------------------------------------

    def test_missing_frames_are_skipped_quietly_without_errors(self):
        # A future OpenXP rename removes the whole feature.
        env = Env()
        env.run("""
          _G.RXPTargetFrame_EnemyButton1 = nil
          _G.RXPTargetFrame_EnemyButton2 = nil
          _G.RXPTargetFrame_FriendlyButton1 = nil
          _G.RXPTargetFrame_title = nil
          _G.RXPTargetFrame = nil
          HARNESS.openxp.targeting.activeTargetFrame = nil
        """)
        env.boot()
        env.run("HARNESS.openxp:RenderFrame()")  # refresh paths stay safe too
        self.assertEqual(env.chat(), [])
        env.slash("/oxpfui debug")
        report = "\n".join(env.chat())
        self.assertIn("missing frame RXPTargetFrame", report)
        self.assertIn("Errors: none", report)

    def test_missing_fields_and_lists_are_skipped_quietly(self):
        # A partial drift: the frame stays, its internals are gone/renamed.
        env = Env()
        env.run("""
          local tf = _G.RXPTargetFrame
          tf.title.text = nil
          tf.title.keyHint = nil
          tf.sections = nil
          tf.enemyTargetButtons = {}
          tf.friendlyTargetButtons = {}
        """)
        env.boot()
        self.assertEqual(env.chat(), [])
        # What exists is still skinned (the frame itself), what is gone is
        # skipped, and the orphaned row buttons keep OpenXP's look.
        self.assertEqual(env.run("return RXPTargetFrame.backdrop.edgeFile"), FLAREUI_EDGE)
        self.assertEqual(env.run(
            "local p,s,f = RXPTargetFrame_EnemyButton1.label:GetFont(); return p,s,f"),
            ("Fonts\\ARIALN.TTF", 12, ""))
        env.slash("/oxpfui debug")
        self.assertIn("Errors: none", "\n".join(env.chat()))

    # -- appearance only (story 29) -----------------------------------------

    def test_no_position_or_size_is_ever_changed(self):
        env = Env()
        layout = ("SetPoint", "SetSize", "SetWidth", "SetHeight", "SetScale",
                  "SetAllPoints", "ClearAllPoints")
        family = ("RXPTargetFrame", "RXPTargetFrame_title",
                  "RXPTargetFrame_EnemyButton1", "RXPTargetFrame_EnemyButton2",
                  "RXPTargetFrame_FriendlyButton1",
                  "OpenXPTargetMobs", "OpenXPTargetNPCs")
        before = {(f, m): env.calls_made_on(f, m) for f in family for m in layout}
        env.boot()
        env.run("HARNESS.openxp:RenderFrame()")
        env.run("HARNESS.openxp.targeting:UpdateTargetFrame()")
        env.run("HARNESS.openxp.targeting:RenderTargetFrameBackground()")
        for (f, m), count in before.items():
            self.assertEqual(env.calls_made_on(f, m), count,
                             f"{f}:{m} was called by the skin")


class Tooltips(unittest.TestCase):
    """Ticket #9 (stories 17-18): only the quest lines OpenXP adds to
    mob/NPC/item tooltips get the FlareUI palette and typography. Blizzard's
    tooltip frame, Blizzard's own lines and other addons' lines (Questie) are
    never touched."""

    MOUSEOVER = ("HARNESS.units.mouseover = { name = 'Forest Lurker',"
                 " guid = 'Creature-0-0-0-123-999-0000A0B2C', attackable = true }")

    def hover_unit(self, env, blizzard_lines=("Forest Lurker", "Level 5 Humanoid")):
        """Play the client: fill the tooltip's own lines, then fire the
        OnTooltipSetUnit hooks OpenXP registered (which add its quest lines)."""
        env.run(self.MOUSEOVER)
        env.run("GameTooltip:ClearLines()")
        for line in blizzard_lines:
            env.run(f"GameTooltip:AddLine({line!r})")
        env.run("HARNESS.TooltipSetUnit()")

    def test_openxp_added_lines_get_flareui_font_colour_and_shadow(self):
        env = Env()
        env.boot()
        self.hover_unit(env, blizzard_lines=(
            "Forest Lurker",                       # Blizzard: unit name
            "Level 5 Humanoid",                    # Blizzard: level line
            "Questie: Kobold Vermin 3/8",          # another addon's line
        ))
        # OpenXP appended: 4 spacer, 5 header, 6 item name + progress,
        # 7 quest sub-line, 8 guide step.
        # Header ("Loot for your quests"): OpenXP orange -> FlareUI zone
        # bronze, title typography, 1px black shadow, icon kept.
        header = env.run("return GameTooltipTextLeft5:GetText()")
        self.assertIn("|cFFCC9957", header)
        self.assertNotIn("|cFFFF8C1A", header)
        self.assertIn("|TInterface\\GossipFrame\\AvailableQuestIcon:16|t", header)
        self.assertEqual(env.run(
            "local p,s,f = GameTooltipTextLeft5:GetFont(); return p,s,f"),
            (FRIZQ, 12, ""))
        self.assertEqual(env.run(
            "local x,y = GameTooltipTextLeft5:GetShadowOffset(); return x,y"), (1, -1))
        self.assertEqual(env.run(
            "local r,g,b,a = GameTooltipTextLeft5:GetShadowColor(); return r,g,b,a"),
            (0.0, 0.0, 0.0, 1.0))
        self.assertEqual(env.run(
            "local r,g,b,a = GameTooltipTextLeft5:GetTextColor(); return r,g,b,a"),
            (0.80, 0.60, 0.34, 1.0))
        # Item name: OpenXP gold -> FlareUI gold; body typography.
        loot = env.run("return GameTooltipTextLeft6:GetText()")
        self.assertIn("|cFFFFD100", loot)
        self.assertNotIn("|cFFFFC107", loot)
        self.assertEqual(env.run(
            "local p,s,f = GameTooltipTextLeft6:GetFont(); return p,s,f"),
            (FRIZQ, 11, ""))
        # Progress counter (right side of the double line): white -> light grey.
        self.assertEqual(env.run("return GameTooltipTextRight6:GetText()"),
                         "|cFFD9D9D91/4|r")
        self.assertEqual(env.run(
            "local p,s,f = GameTooltipTextRight6:GetFont(); return p,s,f"),
            (FRIZQ, 11, ""))
        # Quest sub-line: OpenXP grey -> FlareUI dim grey.
        sub = env.run("return GameTooltipTextLeft7:GetText()")
        self.assertIn("|cFF8C8C8C", sub)
        self.assertNotIn("|cFF9E9E9E", sub)
        # Guide step line: OpenXP badge green -> FlareUI green, suffix dim,
        # and the un-escaped " step 12" segment keeps its meaning.
        step = env.run("return GameTooltipTextLeft8:GetText()")
        self.assertIn("|cFF21FF21OpenXP|r step 12", step)
        self.assertIn("|cFF8C8C8C - Kill|r", step)
        self.assertNotIn("|cFF66BB6A", step)
        # Quiet: no chat output from any of this.
        self.assertEqual(env.chat(), [])

    def test_blizzard_and_other_addon_lines_keep_their_own_look(self):
        env = Env()
        env.boot()
        env.run(self.MOUSEOVER)
        env.run("GameTooltip:ClearLines()")
        env.run(f"GameTooltip:AddLine('Forest Lurker')")
        env.run(f"GameTooltipTextLeft1:SetFont({FRIZQ!r}, 13, 'OUTLINE')")
        env.run("GameTooltipTextLeft1:SetTextColor(1, 1, 1)")
        env.run("GameTooltip:AddLine('Questie: Kobold Vermin 3/8')")
        env.run("GameTooltipTextLeft2:SetFont('Fonts\\\\ARIALN.TTF', 10, '')")
        env.run("GameTooltipTextLeft2:SetTextColor(0.4, 0.8, 1)")
        env.run("HARNESS.TooltipSetUnit()")
        # Lines OpenXP did not add are untouched: same text, font and colour,
        # and no extra styling call reached them.
        for line, text, font, size, flags, color in (
            ("GameTooltipTextLeft1", "Forest Lurker", FRIZQ, 13, "OUTLINE", (1.0, 1.0, 1.0)),
            ("GameTooltipTextLeft2", "Questie: Kobold Vermin 3/8", "Fonts\\ARIALN.TTF", 10, "", (0.4, 0.8, 1.0)),
        ):
            self.assertEqual(env.run(f"return {line}:GetText()"), text)
            self.assertEqual(env.run(
                f"local p,s,f = {line}:GetFont(); return p,s,f"), (font, size, flags))
            self.assertEqual(env.run(
                f"local r,g,b,a = {line}:GetTextColor(); return r,g,b,a"),
                (*color, 1.0))
            # One SetText (from AddLine) and one font call (the test's own):
            # if OXP-FUI had styled the line there would be more.
            self.assertEqual(env.calls_made_on(line, "SetText"), 1)
            self.assertEqual(env.calls_made_on(line, "SetFont"), 1)
            self.assertEqual(env.calls_made_on(line, "SetShadowOffset"), 0)

    def test_item_tooltip_lines_are_styled_and_openxp_border_kept(self):
        env = Env()
        env.boot()
        env.run("""
          HARNESS.tooltipScenario.itemLines = {
            { title = 'Elixir of Ferocity', have = 1, need = 4, done = false, later = 5 },
          }
          HARNESS.tooltipItem = { id = 15264, name = 'Tough Condor Meat' }
        """)
        env.run("GameTooltip:ClearLines()")
        env.run("GameTooltip:AddLine('Tough Condor Meat')")
        env.run("HARNESS.TooltipSetItem()")
        # Line 2 spacer, 3 header, 4 quest title + progress.
        header = env.run("return GameTooltipTextLeft3:GetText()")
        self.assertIn("|cFFCC9957", header)
        self.assertIn("QUEST ITEM - DON'T SELL", header)
        left = env.run("return GameTooltipTextLeft4:GetText()")
        self.assertIn("|cFFFFD100Elixir of Ferocity|r", left)
        self.assertIn("|cFF8C8C8C (pick up at step 5)|r", left)
        self.assertEqual(env.run("return GameTooltipTextRight4:GetText()"),
                         "|cFFD9D9D91/4|r")
        self.assertEqual(env.run(
            "local p,s,f = GameTooltipTextLeft4:GetFont(); return p,s,f"),
            (FRIZQ, 11, ""))
        # OpenXP's own gold border on item tooltips is OpenXP's behaviour:
        # exactly its one call, un-interfered with by OXP-FUI.
        self.assertEqual(env.calls_made_on("GameTooltip", "SetBackdropBorderColor"), 1)
        self.assertEqual(env.run(
            "local r,g,b,a = GameTooltip:GetBackdropBorderColor(); return r,g,b,a"),
            (1.0, 0.55, 0.1, 1.0))
        self.assertEqual(env.chat(), [])

    def test_game_tooltip_frame_itself_is_never_modified(self):
        env = Env()
        env.boot()
        self.hover_unit(env)
        for frame in ("GameTooltip", "ItemRefTooltip"):
            for method in TOOLTIP_FRAME_METHODS:
                self.assertEqual(env.calls_made_on(frame, method), 0,
                                 f"{frame}:{method} was called")

    def test_per_window_switch_off_leaves_openxp_lines_alone(self):
        env = Env(db={"windows": {"tooltips": False}})
        env.boot()
        self.hover_unit(env, blizzard_lines=(
            "Forest Lurker", "Level 5 Humanoid", "Questie: Kobold Vermin 3/8"))
        # OpenXP still adds its lines with its own look: inline codes kept,
        # no font, no shadow, no base colour set.
        self.assertIn("|cFFFF8C1A", env.run("return GameTooltipTextLeft5:GetText()"))
        self.assertIsNone(env.run("return GameTooltipTextLeft5:GetFont()"))
        self.assertEqual(env.calls_made_on("GameTooltipTextLeft5", "SetFont"), 0)
        self.assertEqual(env.calls_made_on("GameTooltipTextLeft5", "SetTextColor"), 0)
        self.assertEqual(env.chat(), [])
        env.slash("/oxpfui debug")
        self.assertIn("window 'tooltips' is switched off", "\n".join(env.chat()))

    def test_master_switch_off_leaves_openxp_lines_alone(self):
        env = Env(db={"enabled": False})
        env.boot()
        self.hover_unit(env, blizzard_lines=(
            "Forest Lurker", "Level 5 Humanoid", "Questie: Kobold Vermin 3/8"))
        self.assertIn("|cFFFF8C1A", env.run("return GameTooltipTextLeft5:GetText()"))
        self.assertEqual(env.calls_made_on("GameTooltipTextLeft5", "SetFont"), 0)
        self.assertEqual(env.chat(), [])


if __name__ == "__main__":
    unittest.main()
