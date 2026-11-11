#!/usr/bin/env python3
"""Build OXP-FUI.

Stages the addon from src/OXP-FUI into the ephemeral build folder, then
writes the finished, ready-to-copy addon folder into dist/. Optional zip
via Python's zipfile (the dev machine has no zip CLI).

    python3 tools/build.py            # dist/OXP-FUI/
    python3 tools/build.py --zip      # also dist/OXP-FUI-<version>.zip

No reference-folder access: everything shipped lives committed under src/.
"""

from __future__ import annotations

import argparse
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "OXP-FUI"
BUILD_STAGE = ROOT / "build" / "stage" / "OXP-FUI"
DIST = ROOT / "dist"
ADDON = "OXP-FUI"


def read_toc_metadata(toc: Path) -> dict:
    meta = {}
    for line in toc.read_text().splitlines():
        if line.startswith("## "):
            key, _, value = line[3:].partition(":")
            meta[key.strip()] = value.strip()
    return meta


def toc_files(toc: Path) -> list[str]:
    """Loadable files (lua/xml) listed in the TOC, in order."""
    files = []
    for line in toc.read_text().splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#") and stripped.endswith((".lua", ".xml")):
            files.append(stripped)
    return files


def build(make_zip: bool) -> Path:
    toc = SRC / f"{ADDON}.toc"
    if not toc.exists():
        sys.exit(f"error: {toc} not found")
    meta = read_toc_metadata(toc)
    version = meta.get("Version", "0dev")

    # Stage into the ephemeral build folder, then publish to dist/.
    if BUILD_STAGE.parent.exists():
        shutil.rmtree(BUILD_STAGE.parent)
    BUILD_STAGE.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(SRC, BUILD_STAGE)

    # Validate: every loadable file listed in the TOC must exist in the
    # staged addon (never ship a broken folder).
    missing = [f for f in toc_files(toc) if not (BUILD_STAGE / f).is_file()]
    if missing:
        sys.exit(f"error: TOC lists files missing from src/: {', '.join(missing)}")

    dist_addon = DIST / ADDON
    if dist_addon.exists():
        shutil.rmtree(dist_addon)
    DIST.mkdir(parents=True, exist_ok=True)
    shutil.copytree(BUILD_STAGE, dist_addon)

    zip_path = None
    if make_zip:
        zip_path = DIST / f"{ADDON}-{version}.zip"
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for path in sorted(dist_addon.rglob("*")):
                zf.write(path, path.relative_to(DIST))

    print(f"staged:  {BUILD_STAGE}")
    print(f"dist:    {dist_addon}")
    if zip_path:
        print(f"zip:     {zip_path}")
    return dist_addon


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--zip", action="store_true", help="also write dist/OXP-FUI-<version>.zip")
    args = parser.parse_args()
    build(make_zip=args.zip)
    return 0


if __name__ == "__main__":
    sys.exit(main())
