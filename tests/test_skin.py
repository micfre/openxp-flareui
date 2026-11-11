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
