# OXP-FUI

A companion addon for **OpenXP** on the Forever client that restyles
OpenXP's windows to match **FlareUI's Quest Tracker** look — bronze borders,
warm dark fill, gold/amber/green text colours and FlareUI typography.

OpenXP itself is never modified (it keeps receiving upstream updates), no
frame is ever moved or resized, nothing on the world Map or Minimap is
touched, and FlareUI does not need to be installed.

## Install

Build the ready-to-copy addon folder, then copy it into your `Interface\AddOns`
(or `_classic_`_) folder yourself — there is no install-to-game step:

    python3 tools/build.py            # writes dist/OXP-FUI/
    python3 tools/build.py --zip      # also writes dist/OXP-FUI-<version>.zip

In game: `/oxpfui` opens the settings panel (master switch, one switch per
window, font, border style, panel opacity). `/oxpfui debug` prints a report:
the OpenXP version you run versus the tested one (see the
`## X-Tested-OpenXP` TOC field), the master switch and per-window switches,
how many apply passes ran, and the latest pass's outcome — which skins were
skinned (`Skinned:`), what was skipped and why (`Skipped:`), errors
(`Errors:`, plus `Earlier errors (previous passes):` as labelled history)
and blocked layout attempts.

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

## Credits and licenses

- OXP-FUI code: MIT (see `LICENSE`).
- The bundled border art and fonts come from **FlareUI by Malkkav** (MIT) and
  their font licenses; see `src/OXP-FUI/LICENSE` and `src/OXP-FUI/License/`.
  The FlareUI look is re-implemented in new code; no FlareUI code is copied.
- OpenXP (CC BY-NC-SA 4.0) is a runtime dependency, unmodified and
  unredistributed; no OpenXP code is included here.
