"""Dock seam tests: the FlareUI Quest Tracker dock and width match
(Docking.lua), observed through the lupa harness with a fake FlareUI
tracker, like the skin seam tests act only through public surfaces:
client events, slash commands, panel clicks and OpenXP refresh calls."""

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from harness.env import Env  # noqa: E402

# OpenXP's file-load anchor for the card (OpenXPCard.lua): the position the
# tests give the card before docking, so restores are observable.
OXP_ANCHOR = 'OpenXPCard:SetPoint("RIGHT", UIParent, "RIGHT", -40, 120)'


def give_card_anchor(env):
    env.run(OXP_ANCHOR)


def card_anchor(env):
    """The card's first anchor: (point, relativePoint, x, y, onTracker)."""
    return env.run(
        "if OpenXPCard:GetNumPoints() == 0 then return nil end; "
        "local pt, rel, rpt, x, y = OpenXPCard:GetPoint(1); "
        "return pt, rpt, x, y, rel == FlareUI_ObjectiveTracker"
    )


class DockDefaults(unittest.TestCase):
    def test_defaults_and_bottom_dock_at_login(self):
        env = Env(flareui=True)
        give_card_anchor(env)
        env.boot()
        # Defaults: attach on, bottom, 8px padding, width match off.
        self.assertIs(env.run("return OXPFUIDB.attachTracker"), True)
        self.assertEqual(env.run("return OXPFUIDB.attachSide"), "bottom")
        self.assertEqual(env.run("return OXPFUIDB.attachPadding"), 8)
        self.assertIs(env.run("return OXPFUIDB.matchTrackerWidth"), False)
        # Docked below the tracker, left edges flush, 8px below it.
        self.assertEqual(card_anchor(env), ("TOPLEFT", "BOTTOMLEFT", 0, -8, True))

    def test_existing_saved_settings_are_kept(self):
        env = Env(flareui=True, db={
            "attachTracker": False, "attachSide": "top",
            "attachPadding": 20, "matchTrackerWidth": True,
        })
        env.boot()
        self.assertIs(env.run("return OXPFUIDB.attachTracker"), False)
        self.assertEqual(env.run("return OXPFUIDB.attachSide"), "top")
        self.assertEqual(env.run("return OXPFUIDB.attachPadding"), 20)
        self.assertIs(env.run("return OXPFUIDB.matchTrackerWidth"), True)


class DockPosition(unittest.TestCase):
    def test_side_top_docks_above_tracker(self):
        env = Env(flareui=True, db={"attachSide": "top"})
        give_card_anchor(env)
        env.boot()
        self.assertEqual(card_anchor(env), ("BOTTOMLEFT", "TOPLEFT", 0, 8, True))

    def test_padding_setting_is_honoured(self):
        env = Env(flareui=True, db={"attachPadding": 16})
        give_card_anchor(env)
        env.boot()
        self.assertEqual(card_anchor(env), ("TOPLEFT", "BOTTOMLEFT", 0, -16, True))

    def test_hidden_tracker_card_takes_its_spot_and_docks_back(self):
        env = Env(flareui=True)
        give_card_anchor(env)
        env.boot()
        env.run("HARNESS.flareui.holder:Hide()")
        self.assertEqual(card_anchor(env), ("TOPLEFT", "TOPLEFT", 0, 0, True))
        env.run("HARNESS.flareui.holder:Show()")
        self.assertEqual(card_anchor(env), ("TOPLEFT", "BOTTOMLEFT", 0, -8, True))

    def test_hidden_tracker_spot_is_side_aware(self):
        env = Env(flareui=True, db={"attachSide": "top"})
        give_card_anchor(env)
        env.boot()
        env.run("HARNESS.flareui.holder:Hide()")
        self.assertEqual(card_anchor(env),
                         ("BOTTOMLEFT", "BOTTOMLEFT", 0, 0, True))

    def test_minimized_tracker_keeps_card_docked_and_open(self):
        env = Env(flareui=True)
        give_card_anchor(env)
        env.boot()
        env.run("HARNESS.flareui.holder:MinimizeToList()")
        # Still docked to the (now header-only) tracker, never hidden.
        self.assertEqual(card_anchor(env), ("TOPLEFT", "BOTTOMLEFT", 0, -8, True))
        self.assertEqual(env.calls_made_on("OpenXPCard", "Hide"), 0)

    def test_tracker_module_not_on_never_moves_the_card(self):
        # No FlareUI at all: not one layout call on the card (the recorded
        # setup call is wiped so only post-boot calls count).
        env = Env()
        give_card_anchor(env)
        env.run("wipe(OpenXPCard.__calls)")
        env.boot()
        for method in ("SetPoint", "ClearAllPoints", "SetWidth", "SetSize"):
            self.assertEqual(env.calls_made_on("OpenXPCard", method), 0,
                             f"OpenXPCard:{method} was called without a tracker")
        self.assertEqual(card_anchor(env), ("RIGHT", "RIGHT", -40, 120, False))
        # No discovery polling either: FlareUI is not installed.
        self.assertEqual(env.run("return HARNESS.timers.after"), 0)

    def test_tracker_appearing_after_login_still_docks(self):
        env = Env(flareui_late=True)
        give_card_anchor(env)
        env.boot()
        # FlareUI had not loaded yet: the card keeps OpenXP's anchor.
        self.assertEqual(card_anchor(env), ("RIGHT", "RIGHT", -40, 120, False))
        env.run("HARNESS.CreateFlareUITracker()")
        env.fire("PLAYER_ENTERING_WORLD")
        self.assertEqual(card_anchor(env), ("TOPLEFT", "BOTTOMLEFT", 0, -8, True))

    def test_openxp_reanchoring_the_card_redocks_on_refresh(self):
        env = Env(flareui=True)
        give_card_anchor(env)
        env.boot()
        # OpenXP's card.Enable restores its saved position on login:
        env.run('OpenXPCard:ClearAllPoints(); '
                'OpenXPCard:SetPoint("CENTER", UIParent, "CENTER", 0, 0)')
        env.run("HARNESS.openxp.card.Refresh(nil, true)")
        self.assertEqual(card_anchor(env), ("TOPLEFT", "BOTTOMLEFT", 0, -8, True))

    def test_toggling_attach_off_restores_the_cards_own_position(self):
        env = Env(flareui=True)
        give_card_anchor(env)
        env.boot()
        self.assertEqual(card_anchor(env)[0], "TOPLEFT")
        env.run("OXPFUIDB.attachTracker = false; OXPFUI.Dock.Update('test')")
        self.assertEqual(card_anchor(env), ("RIGHT", "RIGHT", -40, 120, False))
        env.run("OXPFUIDB.attachTracker = true; OXPFUI.Dock.Update('test')")
        self.assertEqual(card_anchor(env), ("TOPLEFT", "BOTTOMLEFT", 0, -8, True))

    def test_master_switch_off_releases_the_dock(self):
        env = Env(flareui=True)
        give_card_anchor(env)
        env.boot()
        env.run("OXPFUIDB.enabled = false; OXPFUI.Dock.Update('test')")
        self.assertEqual(card_anchor(env), ("RIGHT", "RIGHT", -40, 120, False))

    def test_drag_is_suspended_while_docked_and_returned_after(self):
        env = Env(flareui=True)
        env.run("OpenXPCard:SetScript('OnDragStart', "
                "function(self) self:StartMoving() end)")
        env.boot()
        env.run("local fn = OpenXPCard:GetScript('OnDragStart'); fn(OpenXPCard)")
        self.assertEqual(env.calls_made_on("OpenXPCard", "StartMoving"), 0)
        env.run("OXPFUIDB.attachTracker = false; OXPFUI.Dock.Update('test')")
        env.run("local fn = OpenXPCard:GetScript('OnDragStart'); fn(OpenXPCard)")
        self.assertEqual(env.calls_made_on("OpenXPCard", "StartMoving"), 1)

    def test_grip_position_save_is_repaired_while_docked(self):
        # OpenXP's grip saves the card anchor to the profile on mouse-up
        # (OpenXPCard.lua); docked, that anchor is tracker-relative and
        # unrestorable — the dock must put the captured one back.
        env = Env(flareui=True)
        give_card_anchor(env)
        env.run("""
        HARNESS.openxp.card.grip:SetScript("OnMouseUp", function(self)
          local card = HARNESS.openxp.card
          if not card.sizing then return end
          card.sizing = false
          local point, _, relPoint, x, y = OpenXPCard:GetPoint()
          HARNESS.openxp.settings.profile.openxpCardPos = { point, relPoint, x, y }
        end)
        """)
        env.boot()
        env.run("HARNESS.openxp.card.sizing = true")
        env.run("local fn = HARNESS.openxp.card.grip:GetScript('OnMouseUp'); "
                "fn(HARNESS.openxp.card.grip)")
        self.assertEqual(
            env.run("return unpack(HARNESS.openxp.settings.profile.openxpCardPos)"),
            ("RIGHT", "RIGHT", -40, 120))


class WidthMatch(unittest.TestCase):
    def test_width_is_its_own_by_default(self):
        env = Env(flareui=True)
        env.boot()
        self.assertIsNone(env.run("return HARNESS.openxp.card.width"))
        self.assertEqual(env.calls_made_on("OpenXPCard", "SetWidth"), 0)

    def test_width_follows_the_tracker_exactly(self):
        env = Env(flareui=True, db={"matchTrackerWidth": True})
        env.boot()
        self.assertEqual(env.run("return HARNESS.openxp.card.width"), 250)
        self.assertEqual(env.run("return OpenXPCard:GetWidth()"), 250)
        # The tracker's width setting changes: the card follows, exactly —
        # not clamped to OpenXP's own user-resize bounds (180 < 200 min).
        env.run("HARNESS.flareui.holder:Resize(180)")
        self.assertEqual(env.run("return HARNESS.openxp.card.width"), 180)
        self.assertEqual(env.run("return OpenXPCard:GetWidth()"), 180)
        env.run("HARNESS.flareui.holder:Resize(320)")
        self.assertEqual(env.run("return OpenXPCard:GetWidth()"), 320)

    def test_width_restores_to_the_profile_width_when_switched_off(self):
        env = Env(flareui=True, db={"matchTrackerWidth": True})
        env.run("HARNESS.openxp.settings.profile.openxpCardWidth = 280")
        env.boot()
        self.assertEqual(env.run("return OpenXPCard:GetWidth()"), 250)
        env.run("OXPFUIDB.matchTrackerWidth = false; OXPFUI.Dock.Update('test')")
        self.assertEqual(env.run("return HARNESS.openxp.card.width"), 280)
        self.assertEqual(env.run("return OpenXPCard:GetWidth()"), 280)

    def test_width_restores_to_openxp_default_without_a_profile_width(self):
        env = Env(flareui=True, db={"matchTrackerWidth": True})
        env.boot()
        env.run("OXPFUIDB.matchTrackerWidth = false; OXPFUI.Dock.Update('test')")
        self.assertIsNone(env.run("return HARNESS.openxp.card.width"))
        self.assertEqual(env.run("return OpenXPCard:GetWidth()"), 330)

    def test_width_matches_without_attach_leaving_position_alone(self):
        env = Env(flareui=True,
                  db={"attachTracker": False, "matchTrackerWidth": True})
        give_card_anchor(env)
        env.boot()
        self.assertEqual(card_anchor(env), ("RIGHT", "RIGHT", -40, 120, False))
        self.assertEqual(env.run("return OpenXPCard:GetWidth()"), 250)

    def test_no_tracker_no_width_change(self):
        env = Env(db={"matchTrackerWidth": True})
        env.boot()
        self.assertEqual(env.calls_made_on("OpenXPCard", "SetWidth"), 0)
        self.assertIsNone(env.run("return HARNESS.openxp.card.width"))


class PanelAndDebug(unittest.TestCase):
    def test_panel_controls_write_db_and_move_the_dock(self):
        env = Env(flareui=True)
        give_card_anchor(env)
        env.boot()
        env.slash("/oxpfui")
        # Detach via the panel: back to the card's own position.
        env.run("OXPFUIPanel.attachBtn:Click()")
        self.assertIs(env.run("return OXPFUIDB.attachTracker"), False)
        self.assertEqual(card_anchor(env), ("RIGHT", "RIGHT", -40, 120, False))
        # Side cycles bottom -> top; padding via the slider; attach back on.
        env.run("OXPFUIPanel.attachSideBtn:Click()")
        self.assertEqual(env.run("return OXPFUIDB.attachSide"), "top")
        env.run("OXPFUIPanel.paddingSlider:SetValue(20)")
        self.assertEqual(env.run("return OXPFUIDB.attachPadding"), 20)
        env.run("OXPFUIPanel.attachBtn:Click()")
        self.assertEqual(card_anchor(env), ("BOTTOMLEFT", "TOPLEFT", 0, 20, True))
        # Width match via the panel.
        env.run("OXPFUIPanel.matchBtn:Click()")
        self.assertIs(env.run("return OXPFUIDB.matchTrackerWidth"), True)
        self.assertEqual(env.run("return OpenXPCard:GetWidth()"), 250)

    def test_debug_report_tells_the_dock_state(self):
        env = Env(flareui=True)
        env.boot()
        env.slash("/oxpfui debug")
        self.assertIn("Tracker dock: on — card below the tracker, 8px padding, "
                      "width its own", "\n".join(env.chat()))
        env.run("HARNESS.flareui.holder:Hide()")
        env.slash("/oxpfui debug")
        self.assertIn("tracker hidden, the card takes its spot",
                      "\n".join(env.chat()))

    def test_debug_report_without_flareui(self):
        env = Env()
        env.boot()
        env.slash("/oxpfui debug")
        self.assertIn("Tracker dock: off — no FlareUI Quest Tracker found",
                      "\n".join(env.chat()))


if __name__ == "__main__":
    unittest.main()
