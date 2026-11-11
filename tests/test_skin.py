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
      fs:SetTextColor(1, 0.82, 0)
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
            "local r,g,b,a = RXPG_ARROW.text:GetTextColor(); return r,g,b,a"), (1.0, 0.82, 0.0, None))

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


if __name__ == "__main__":
    unittest.main()
