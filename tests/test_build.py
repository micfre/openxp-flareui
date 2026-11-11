"""Seam 2 tests: the build script's produced addon folder is complete and
correct (spec section Testing Decisions, build seam).

Each test runs the real build script; a fresh clone of the branch contains
everything under src/, so prior_art is never needed at build time.
"""

import pathlib
import subprocess
import sys
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILD_SCRIPT = ROOT / "tools" / "build.py"
SRC = ROOT / "src" / "OXP-FUI"
DIST = ROOT / "dist" / "OXP-FUI"

# Exact byte sizes from the media inventory (prior_art/FlareUI).
MEDIA = {
    "Media/Borders/FlareUI-Frames.tga": 32786,
    "Media/Borders/FlareUI-Thick.tga": 32786,
    "Media/Borders/FlareUI-Thin.tga": 8210,
    "Media/Fonts/AsapCondensed-Regular.ttf": 108008,
    "Media/Fonts/BarlowCondensed-Regular.ttf": 97132,
    "Media/Fonts/CabinCondensed-Regular.ttf": 93196,
    "Media/Fonts/FiraSansExtraCondensed-Regular.ttf": 439548,
    "Media/Fonts/RobotoCondensed-Regular.ttf": 144848,
    "License/FlareUI-LICENSE.txt": 1505,
    "License/Fonts_OFL-1.1.txt": 4954,
    "License/Font_RobotoCondensed_Apache-2.0.txt": 11720,
}


def run_build(*args: str) -> None:
    result = subprocess.run(
        [sys.executable, str(BUILD_SCRIPT), *args],
        capture_output=True, text=True, check=False,
    )
    if result.returncode != 0:
        raise AssertionError(f"build failed:\n{result.stdout}\n{result.stderr}")


def toc_lines() -> list[str]:
    return (DIST / "OXP-FUI.toc").read_text().splitlines()


def toc_meta() -> dict:
    meta = {}
    for line in toc_lines():
        if line.startswith("## "):
            key, _, value = line[3:].partition(":")
            meta[key.strip()] = value.strip()
    return meta


def toc_loadable_files() -> list[str]:
    return [line.strip() for line in toc_lines()
            if line.strip() and not line.strip().startswith("#")
            and line.strip().endswith((".lua", ".xml"))]


class Build(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        run_build()

    def test_dist_addon_folder_exists_with_toc(self):
        self.assertTrue((DIST / "OXP-FUI.toc").is_file())
        self.assertTrue(DIST.is_dir())

    def test_every_file_listed_in_the_toc_exists(self):
        files = toc_loadable_files()
        self.assertGreater(len(files), 0)
        for f in files:
            self.assertTrue((DIST / f).is_file(), f"TOC lists missing file: {f}")

    def test_toc_targets_forever_interface_16001_and_declares_dependencies(self):
        meta = toc_meta()
        self.assertEqual(meta["Interface"], "16001")
        self.assertEqual(meta["RequiredDeps"], "OpenXP")
        self.assertEqual(meta["SavedVariables"], "OXPFUIDB")
        self.assertTrue(meta["Version"], "missing addon Version")
        # The tested OpenXP version is recorded so drift is detectable.
        self.assertEqual(meta["X-Tested-OpenXP"], "1.3.48")

    def test_all_bundled_media_and_license_files_resolve(self):
        for rel, size in MEDIA.items():
            path = DIST / rel
            self.assertTrue(path.is_file(), f"missing bundled file: {rel}")
            self.assertEqual(path.stat().st_size, size, f"wrong size: {rel}")

    def test_license_notices_and_attribution_are_included(self):
        flare = (DIST / "License" / "FlareUI-LICENSE.txt").read_text()
        self.assertIn("Malkkav", flare)              # attribution to FlareUI's author
        self.assertIn("MIT", flare)                  # FlareUI's MIT notice
        addon_license = (DIST / "LICENSE").read_text()
        self.assertIn("MIT License", addon_license)  # OXP-FUI's own MIT
        self.assertIn("Malkkav", addon_license)      # credits the look + art
        # Font licenses travel with the fonts.
        self.assertIn("Open Font License", (DIST / "License" / "Fonts_OFL-1.1.txt").read_text())
        self.assertIn("Apache License", (DIST / "License" / "Font_RobotoCondensed_Apache-2.0.txt").read_text())

    def test_zip_option_produces_a_zip_containing_the_addon(self):
        run_build("--zip")
        version = toc_meta()["Version"]
        zips = sorted((ROOT / "dist").glob("OXP-FUI-*.zip"))
        self.assertEqual(len(zips), 1, f"expected exactly one zip, got {zips}")
        with zipfile.ZipFile(zips[-1]) as zf:
            names = zf.namelist()
            self.assertIn("OXP-FUI/OXP-FUI.toc", names)
            self.assertIn(f"OXP-FUI/{MEDIA and 'Media/Borders/FlareUI-Frames.tga'}", names)

    def test_build_only_uses_committed_sources(self):
        # The build must never read prior_art (a fresh clone has none).
        source = BUILD_SCRIPT.read_text()
        self.assertNotIn("prior_art", source)
        self.assertNotIn("OpenXP/", source)

    def test_staging_happens_in_the_ephemeral_build_folder(self):
        self.assertTrue((ROOT / "build" / "stage" / "OXP-FUI" / "OXP-FUI.toc").is_file())


if __name__ == "__main__":
    unittest.main()
