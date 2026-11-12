# OXP-FUI

A companion addon for **OpenXP** on the Forever client that restyles
OpenXP's windows to match **FlareUI's Quest Tracker** look — bronze borders,
warm dark fill, gold/amber/green text colours and FlareUI typography.

OpenXP itself is never modified (it keeps receiving upstream updates), the
skins never move or resize any frame, nothing on the world Map or Minimap
is touched, and FlareUI does not need to be installed. The one deliberate
exception is the optional [tracker dock](#tracker-dock), which re-anchors
only the guide card while its switch is on.

## Install

Build the ready-to-copy addon folder, then copy it into your `Interface\AddOns`
(or `_classic_`_) folder yourself — there is no install-to-game step:

    python3 tools/build.py            # writes dist/OXP-FUI/
    python3 tools/build.py --zip      # also writes dist/OXP-FUI-<version>.zip

In game: `/oxpfui` opens the settings panel (master switch, one switch per
window, font, border style, panel opacity, and the FlareUI Quest Tracker
dock: attach on/off, top/bottom, padding, width match). `/oxpfui debug`
prints a report:
the OpenXP version you run versus the tested one (see the
`## X-Tested-OpenXP` TOC field), the master switch and per-window switches,
how many apply passes ran, and the latest pass's outcome — which skins were
skinned (`Skinned:`), what was skipped and why (`Skipped:`), errors
(`Errors:`, plus `Earlier errors (previous passes):` as labelled history)
and blocked layout attempts.

## Timer bars

With FlareUI installed, OpenXP's conditional progress bars (the flight
timer and other step timers, shown under the card) are filled with the
texture of FlareUI's unit frame bars ("FlareUI Forever"), keeping the bar's
own colour. FlareUI hardcodes that texture today; if its maintainer adds a
configurable unit frame texture, the bars should follow it. Without
FlareUI the bars keep OpenXP's texture.

## Tracker dock

When FlareUI is installed and its Quest Tracker is on, the settings panel
(`/oxpfui`, "FlareUI Quest Tracker" section) can dock the OpenXP guide
card to it:

- **Attach guide card to tracker** (on by default): the card sits at the
  tracker's bottom edge (default) or top edge, with a configurable padding
  between them (default 8 px), and follows every tracker move or resize by
  anchoring. Minimizing the tracker keeps the card open, docked under the
  header; a hidden tracker (minimized to a lone "+" button, or hidden
  while nothing is tracked) makes the card move into the tracker's spot.
  With FlareUI missing or its Quest Tracker module turned off, the card is
  not moved at all.
- **Match tracker width** (off by default): the card becomes exactly as
  wide as the tracker and follows the tracker's own width setting, so the
  two stack seamlessly.

While docked the card cannot be dragged (the dock owns its place — move
the tracker instead); its resize grip keeps working, and OpenXP's own
saved card position survives, so switching attach off puts the card back
where you left it. Every dock control acts immediately, no reload needed.

## Repository layout

    src/OXP-FUI/        addon source (Lua + bundled FlareUI media and licenses)
    tools/build.py      build script (stages into build/, publishes into dist/)
    tests/              lupa test harness (Seam 1) and build tests (Seam 2)
    build/              ephemeral: staging output and the Python venv (ignored)
    dist/               build output: the ready-to-copy addon folder (ignored)
    prior_art/          local reference copies of OpenXP and FlareUI (ignored,
                        research only — never distributed, never needed to
                        build or test)

## Tests

    python3 tests/run_tests.py

First run creates a venv with `lupa` under `build/venv`. Skin behaviour is
verified against a stubbed WoW API and a fake OpenXP (no game needed); the
build tests verify the produced addon folder. A report is written to
`tests/output/report.txt`.

## Known limitations

- OpenXP 1.3.48 exposes no visible inventory-manager window (only an
  invisible keybind button, an input-propagation helper and a hidden
  full-screen click passthrough), so the inventory-manager skin dresses the
  hidden delete-junk helper frame.
- The dock padding is measured in UI units at the card's own scale; with a
  non-default card scale the on-screen gap scales with it.

## Credits and licenses

- OXP-FUI code: MIT (see `LICENSE`).
- The bundled border art and fonts come from **FlareUI by Malkkav** (MIT) and
  their font licenses; see `src/OXP-FUI/LICENSE` and `src/OXP-FUI/License/`.
  The FlareUI look is re-implemented in new code; no FlareUI code is copied.
- OpenXP (CC BY-NC-SA 4.0) is a runtime dependency, unmodified and
  unredistributed; no OpenXP code is included here.
