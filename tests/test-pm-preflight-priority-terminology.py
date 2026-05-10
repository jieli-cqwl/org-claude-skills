#!/usr/bin/env python3
"""Unit tests for PM preflight's priority + terminology check integration.

Locks the contract that `preflight_check.py` in --phase-dir mode invokes
check_priority_consistency.py and check_terminology_consistency.py, surfacing
PRIORITY_INCONSISTENCY_FAILURE and TERMINOLOGY_DRIFT_FAILURE failure_codes
owned by product-manager. Legacy --brief/--phase-prd mode must stay
unchanged (no cross-UNIT check, canonical_validated=false).

Mirrors the layout of test-pm-preflight-canonical.py so future refactors
that touch the preflight wiring cannot silently drop these gates.
"""

from __future__ import annotations

import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "shared/skills/product-manager/scripts/preflight_check.py"
FIXTURE = ROOT / "shared/skills/product-manager/examples/feature--user-login-validation"


def load_module():
    """Import the preflight script so FAILURE_OWNER / SCRIPT_DIR are inspectable."""
    spec = importlib.util.spec_from_file_location("pm_preflight_check", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


def _clone_fixture(dest_root: Path) -> Path:
    target = dest_root / "feature"
    shutil.copytree(FIXTURE, target)
    return target / "phase-1"


def _run_preflight(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True,
        text=True,
        check=False,
    )


def _mutate_priority_drift(phase_dir: Path) -> None:
    """Demote UNIT-2 to P2 while UNIT-1 (P0) still depends on it.

    Reproduces the M-S4 gate: a high-priority UNIT must not depend on a
    low-priority one without documented business justification.
    """
    phase_prd = phase_dir / "phase-prd.json"
    data = json.loads(phase_prd.read_text(encoding="utf-8"))
    for entry in data["unit_priority_order"]:
        if entry.get("unit_id") == "UNIT-2":
            entry["priority"] = "P2"
    phase_prd.write_text(
        json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def _mutate_terminology_drift(phase_dir: Path) -> None:
    """Replace one occurrence of '会话标识' with 'token' in UNIT-1, leaving
    the other UNITs untouched so the session-identifier cluster reports
    two competing synonyms."""
    unit_path = phase_dir / "units" / "UNIT-1.json"
    data = json.loads(unit_path.read_text(encoding="utf-8"))
    ac_text = json.dumps(data["acceptance_criteria"], ensure_ascii=False)
    mutated = ac_text.replace("会话标识", "token", 1)
    if mutated == ac_text:
        raise RuntimeError("fixture drift: UNIT-1 has no '会话标识' to mutate")
    data["acceptance_criteria"] = json.loads(mutated)
    unit_path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
    )


class FailureOwnerMappingTests(unittest.TestCase):
    """New failure codes must be explicitly owned by product-manager."""

    def setUp(self) -> None:
        self.mod = load_module()

    def test_priority_code_owned_by_pm(self):
        self.assertEqual(
            self.mod.FAILURE_OWNER["PRIORITY_INCONSISTENCY_FAILURE"], "product-manager"
        )

    def test_terminology_code_owned_by_pm(self):
        self.assertEqual(
            self.mod.FAILURE_OWNER["TERMINOLOGY_DRIFT_FAILURE"], "product-manager"
        )


class EndToEndCleanFixtureTests(unittest.TestCase):
    """Clean PM fixture must still PASS with canonical_validated=true after
    the two extra cross-UNIT checks are wired in."""

    def test_clean_phase_dir_mode_passes(self):
        with tempfile.TemporaryDirectory() as td:
            phase_dir = _clone_fixture(Path(td))
            result = _run_preflight("--phase-dir", str(phase_dir))
        self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "PASS")
        self.assertTrue(payload["canonical_validated"])

    def test_legacy_brief_mode_skips_cross_unit_checks(self):
        """--brief/--phase-prd mode (pre-UNIT-split) must not invoke the new
        PM-local scripts; canonical_validated stays false."""
        with tempfile.TemporaryDirectory() as td:
            phase_dir = _clone_fixture(Path(td))
            brief = phase_dir.parent / "brief.json"
            phase_prd = phase_dir / "phase-prd.json"
            result = _run_preflight(
                "--brief", str(brief), "--phase-prd", str(phase_prd)
            )
        self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "PASS")
        self.assertFalse(payload["canonical_validated"])


class EndToEndDriftBlockingTests(unittest.TestCase):
    """Each PM-owned cross-UNIT drift must be blocked with the right
    failure_code and owner=product-manager."""

    def test_priority_drift_blocks_with_specific_code(self):
        with tempfile.TemporaryDirectory() as td:
            phase_dir = _clone_fixture(Path(td))
            _mutate_priority_drift(phase_dir)
            result = _run_preflight("--phase-dir", str(phase_dir))
        self.assertEqual(result.returncode, 1, msg=result.stdout + result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "BLOCKED")
        self.assertEqual(payload["failure_code"], "PRIORITY_INCONSISTENCY_FAILURE")
        self.assertEqual(payload["owner"], "product-manager")
        self.assertIn("check_priority_consistency.py", payload["reason"])

    def test_terminology_drift_blocks_with_specific_code(self):
        with tempfile.TemporaryDirectory() as td:
            phase_dir = _clone_fixture(Path(td))
            _mutate_terminology_drift(phase_dir)
            result = _run_preflight("--phase-dir", str(phase_dir))
        self.assertEqual(result.returncode, 1, msg=result.stdout + result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "BLOCKED")
        self.assertEqual(payload["failure_code"], "TERMINOLOGY_DRIFT_FAILURE")
        self.assertEqual(payload["owner"], "product-manager")
        self.assertIn("check_terminology_consistency.py", payload["reason"])


if __name__ == "__main__":
    unittest.main()
