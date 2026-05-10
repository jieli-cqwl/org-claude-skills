#!/usr/bin/env python3
"""Unit tests for PM preflight's canonical validation integration.

These tests lock the contract that `preflight_check.py` adds on top of the
legacy Director-lock checks: in --phase-dir mode with units present, it must
invoke validate_canonical_schema + validate_canonical_rules and surface
specific failure_codes, while legacy --brief/--phase-prd mode must stay
unchanged (no canonical call, canonical_validated=false).

The eval suite covers the semantic user-facing behavior; these tests lock
exact failure_code names and input→output relationships so refactors cannot
silently break downstream consumers that parse preflight output.
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
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "shared/skills/product-manager/scripts/preflight_check.py"
FIXTURE = ROOT / "shared/skills/product-manager/examples/feature--user-login-validation"


def load_module():
    """Import the preflight script so internal helpers (run_canonical_validator,
    assert_units_present, PreflightFailure) are directly testable."""
    spec = importlib.util.spec_from_file_location("pm_preflight_check", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


def _clone_fixture(dest_root: Path) -> Path:
    """Copy the canonical-clean PM fixture into a writable tmp root, return the
    phase-1 directory ready for mutation."""
    target = dest_root / "feature"
    shutil.copytree(FIXTURE, target)
    return target / "phase-1"


def _run_preflight(*args: str) -> subprocess.CompletedProcess:
    """Run the preflight script as subprocess with the given CLI args."""
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True,
        text=True,
        check=False,
    )


class AssertUnitsPresentTests(unittest.TestCase):
    """assert_units_present must block when units/ is missing or empty."""

    def setUp(self) -> None:
        self.mod = load_module()

    def test_missing_units_dir_raises_missing_input(self):
        with tempfile.TemporaryDirectory() as td:
            phase_dir = Path(td)
            with self.assertRaises(self.mod.PreflightFailure) as ctx:
                self.mod.assert_units_present(phase_dir)
            self.assertEqual(ctx.exception.code, "MISSING_INPUT")

    def test_empty_units_dir_raises_missing_input(self):
        with tempfile.TemporaryDirectory() as td:
            phase_dir = Path(td)
            (phase_dir / "units").mkdir()
            with self.assertRaises(self.mod.PreflightFailure) as ctx:
                self.mod.assert_units_present(phase_dir)
            self.assertEqual(ctx.exception.code, "MISSING_INPUT")

    def test_units_present_passes_silently(self):
        with tempfile.TemporaryDirectory() as td:
            phase_dir = Path(td)
            units = phase_dir / "units"
            units.mkdir()
            (units / "UNIT-1.json").write_text("{}", encoding="utf-8")
            self.mod.assert_units_present(phase_dir)  # should not raise


class RunCanonicalValidatorUnitTests(unittest.TestCase):
    """run_canonical_validator must translate subprocess failures into
    PreflightFailure with the caller-supplied failure_code."""

    def setUp(self) -> None:
        self.mod = load_module()

    def test_zero_exit_does_not_raise(self):
        fake = mock.Mock(returncode=0, stdout="", stderr="")
        with mock.patch.object(self.mod.subprocess, "run", return_value=fake):
            # Should return silently.
            self.mod.run_canonical_validator(
                "x.py", "CANONICAL_SCHEMA_FAILURE", Path("/tmp")
            )

    def test_nonzero_exit_raises_with_supplied_code(self):
        fake = mock.Mock(
            returncode=2, stdout="", stderr="  boom: missing field\nline2\n"
        )
        with mock.patch.object(self.mod.subprocess, "run", return_value=fake):
            with self.assertRaises(self.mod.PreflightFailure) as ctx:
                self.mod.run_canonical_validator(
                    "validate_canonical_schema.py",
                    "CANONICAL_SCHEMA_FAILURE",
                    Path("/tmp"),
                )
        self.assertEqual(ctx.exception.code, "CANONICAL_SCHEMA_FAILURE")
        # First non-empty line of stderr must be embedded in the reason.
        self.assertIn("boom: missing field", ctx.exception.reason)

    def test_stderr_preferred_over_stdout(self):
        fake = mock.Mock(
            returncode=1,
            stdout="stdout-line",
            stderr="stderr-line",
        )
        with mock.patch.object(self.mod.subprocess, "run", return_value=fake):
            with self.assertRaises(self.mod.PreflightFailure) as ctx:
                self.mod.run_canonical_validator(
                    "x.py", "CANONICAL_RULES_FAILURE", Path("/tmp")
                )
        self.assertIn("stderr-line", ctx.exception.reason)
        self.assertNotIn("stdout-line", ctx.exception.reason)


class FailureOwnerMappingTests(unittest.TestCase):
    """Canonical failure codes must map to product-manager ownership."""

    def setUp(self) -> None:
        self.mod = load_module()

    def test_both_canonical_codes_owned_by_pm(self):
        self.assertEqual(
            self.mod.FAILURE_OWNER["CANONICAL_SCHEMA_FAILURE"], "product-manager"
        )
        self.assertEqual(
            self.mod.FAILURE_OWNER["CANONICAL_RULES_FAILURE"], "product-manager"
        )


class EndToEndCleanFixtureTests(unittest.TestCase):
    """End-to-end: clean canonical fixture must pass with canonical_validated=true."""

    def test_clean_phase_dir_mode_passes_with_canonical_true(self):
        with tempfile.TemporaryDirectory() as td:
            phase_dir = _clone_fixture(Path(td))
            result = _run_preflight("--phase-dir", str(phase_dir))
        self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "PASS")
        self.assertTrue(payload["canonical_validated"])

    def test_legacy_brief_mode_passes_with_canonical_false(self):
        """--brief/--phase-prd mode (pre-UNIT-split) must not run canonical."""
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
    """End-to-end: each of the PM-side canonical drift classes must be blocked
    with the specific CANONICAL_SCHEMA_FAILURE failure_code."""

    def _load_phase_prd(self, phase_dir: Path) -> dict:
        return json.loads((phase_dir / "phase-prd.json").read_text(encoding="utf-8"))

    def _dump_phase_prd(self, phase_dir: Path, data: dict) -> None:
        (phase_dir / "phase-prd.json").write_text(
            json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    def _assert_canonical_schema_failure(self, phase_dir: Path) -> dict:
        result = _run_preflight("--phase-dir", str(phase_dir))
        self.assertEqual(result.returncode, 1, msg=result.stdout + result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "BLOCKED")
        self.assertEqual(payload["failure_code"], "CANONICAL_SCHEMA_FAILURE")
        self.assertEqual(payload["owner"], "product-manager")
        return payload

    def test_missing_chain_registry_digest_blocks(self):
        with tempfile.TemporaryDirectory() as td:
            phase_dir = _clone_fixture(Path(td))
            data = self._load_phase_prd(phase_dir)
            data.pop("chain_registry_digest", None)
            self._dump_phase_prd(phase_dir, data)
            self._assert_canonical_schema_failure(phase_dir)

    def test_wrong_producer_blocks(self):
        with tempfile.TemporaryDirectory() as td:
            phase_dir = _clone_fixture(Path(td))
            data = self._load_phase_prd(phase_dir)
            data["producer"] = "product-manager"
            self._dump_phase_prd(phase_dir, data)
            self._assert_canonical_schema_failure(phase_dir)

    def test_cross_unit_dependencies_dict_form_blocks(self):
        with tempfile.TemporaryDirectory() as td:
            phase_dir = _clone_fixture(Path(td))
            unit_path = phase_dir / "units" / "UNIT-1.json"
            data = json.loads(unit_path.read_text(encoding="utf-8"))
            data["integration_context"]["cross_unit_dependencies"] = [
                {"depends_on": "UNIT-2", "reason": "x"}
            ]
            unit_path.write_text(
                json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
            )
            self._assert_canonical_schema_failure(phase_dir)


if __name__ == "__main__":
    unittest.main()
