#!/usr/bin/env python3
"""OXP-FUI test runner.

Bootstraps the lupa venv under build/ (gitignored) on first use, then runs
the whole suite:

    python3 tests/run_tests.py

A text report is written to tests/output/report.txt (gitignored).
"""

from __future__ import annotations

import os
import pathlib
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
VENV_DIR = ROOT / "build" / "venv"
VENV_PY = VENV_DIR / "bin" / "python"
OUTPUT_DIR = ROOT / "tests" / "output"


def ensure_venv() -> None:
    """Create build/venv with lupa if this interpreter cannot import it."""
    try:
        import lupa  # noqa: F401
        return
    except ImportError:
        pass
    if not VENV_PY.exists():
        print("creating venv with lupa under build/ ...", file=sys.stderr)
        VENV_DIR.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([sys.executable, "-m", "venv", str(VENV_DIR)], check=True)
        subprocess.run([str(VENV_PY), "-m", "pip", "install", "--quiet", "lupa"], check=True)
    os.execv(str(VENV_PY), [str(VENV_PY), __file__, *sys.argv[1:]])


def main() -> int:
    ensure_venv()
    suite = unittest.defaultTestLoader.discover(
        start_dir=str(ROOT / "tests"), pattern="test_*.py", top_level_dir=str(ROOT / "tests")
    )
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    lines = [
        f"ran={result.testsRun} failures={len(result.failures)} errors={len(result.errors)} skipped={len(result.skipped)}",
    ]
    for kind, entries in (("FAILURES", result.failures), ("ERRORS", result.errors)):
        for test, tb in entries:
            lines.append(f"{kind}: {test}\n{tb}")
    (OUTPUT_DIR / "report.txt").write_text("\n".join(lines) + "\n")
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
