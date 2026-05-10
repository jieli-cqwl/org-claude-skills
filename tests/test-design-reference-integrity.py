#!/usr/bin/env python3
"""Unit tests for check_design_reference_integrity.py.

These tests lock the observable contract of each reference-integrity check so
refactors cannot silently drop a violation type or change a violation field
name. The eval suite exercises the script end-to-end with an LLM; these tests
pin the exact {type, unit_id / unit_ref / section / ref / location} shapes
that downstream consumers (SKILL completion gates, future audit tools) rely
on.
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "shared/skills/design/scripts/check_design_reference_integrity.py"


def load_module():
    """Import the target script as a module so individual helpers are testable."""
    spec = importlib.util.spec_from_file_location(
        "check_design_reference_integrity", SCRIPT
    )
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


def _phase_prd(unit_ids):
    """Build a minimal phase-prd.json payload that only the checks read."""
    return {
        "unit_priority_order": [{"unit_id": uid, "priority": "P0"} for uid in unit_ids]
    }


def _design_skeleton(unit_ids, module_refs=None, verification_refs=None):
    """Build a minimal design.json payload covering the four sections we check."""
    return {
        "unit_coverage": [{"unit_id": uid} for uid in unit_ids],
        "modules": [
            {
                "module_id": "MOD-A",
                "unit_refs": list(module_refs if module_refs is not None else unit_ids),
            }
        ],
        "verification_mapping": [
            {"evidence_ref": "EV-1"},
            {"evidence_ref": "EV-2"},
        ],
        "quality_attributes": [
            {"id": "QA-1", "verification_refs": list(verification_refs or ["EV-1"])}
        ],
        "cross_cutting_concerns": [{"id": "CC-1", "verification_refs": ["EV-1"]}],
        "impact_scope": [{"id": "IS-1", "verification_refs": ["EV-2"]}],
        "risk_response": [{"id": "RR-1", "verification_refs": ["EV-2"]}],
    }


class UnitCoverageCheckTests(unittest.TestCase):
    """Cover the unit_coverage completeness and coverage-vs-phase-prd delta."""

    def setUp(self) -> None:
        self.mod = load_module()

    def test_clean_coverage_yields_no_violations(self):
        phase_set = {"UNIT-1", "UNIT-2"}
        design = _design_skeleton(["UNIT-1", "UNIT-2"])
        self.assertEqual(self.mod.check_unit_coverage(design, phase_set), [])

    def test_missing_unit_yields_unit_not_covered_by_design(self):
        phase_set = {"UNIT-1", "UNIT-2", "UNIT-3"}
        design = _design_skeleton(["UNIT-1", "UNIT-2"])
        violations = self.mod.check_unit_coverage(design, phase_set)
        self.assertEqual(len(violations), 1)
        v = violations[0]
        self.assertEqual(v["type"], "unit_not_covered_by_design")
        self.assertEqual(v["unit_id"], "UNIT-3")
        self.assertEqual(v["location"], "design.json#unit_coverage")

    def test_phantom_unit_yields_unknown_unit_violation(self):
        phase_set = {"UNIT-1"}
        design = _design_skeleton(["UNIT-1", "UNIT-99"])
        violations = self.mod.check_unit_coverage(design, phase_set)
        self.assertEqual(len(violations), 1)
        self.assertEqual(violations[0]["type"], "unit_coverage_references_unknown_unit")
        self.assertEqual(violations[0]["unit_id"], "UNIT-99")

    def test_non_array_coverage_reports_shape_error(self):
        design = {"unit_coverage": "not-an-array"}
        violations = self.mod.check_unit_coverage(design, {"UNIT-1"})
        self.assertEqual(violations, [{"type": "unit_coverage_not_array"}])


class ModuleUnitRefsCheckTests(unittest.TestCase):
    """Cover modules[*].unit_refs integrity against phase-prd."""

    def setUp(self) -> None:
        self.mod = load_module()

    def test_all_refs_valid_yields_no_violations(self):
        design = _design_skeleton(["UNIT-1", "UNIT-2"])
        self.assertEqual(
            self.mod.check_module_unit_refs(design, {"UNIT-1", "UNIT-2"}), []
        )

    def test_ghost_unit_ref_is_reported(self):
        design = _design_skeleton(
            ["UNIT-1", "UNIT-2"], module_refs=["UNIT-1", "UNIT-99"]
        )
        violations = self.mod.check_module_unit_refs(design, {"UNIT-1", "UNIT-2"})
        self.assertEqual(len(violations), 1)
        v = violations[0]
        self.assertEqual(v["type"], "module_references_unknown_unit")
        self.assertEqual(v["module_id"], "MOD-A")
        self.assertEqual(v["unit_ref"], "UNIT-99")
        self.assertIn("modules[0].unit_refs", v["location"])


class VerificationRefCheckTests(unittest.TestCase):
    """Cover verification_refs resolution across the four sections."""

    def setUp(self) -> None:
        self.mod = load_module()

    def test_resolvable_refs_pass(self):
        design = _design_skeleton(["UNIT-1"])
        self.assertEqual(self.mod.check_verification_refs(design), [])

    def test_unresolved_ref_flagged_with_section_and_field(self):
        design = _design_skeleton(["UNIT-1"], verification_refs=["EV-MISSING"])
        violations = self.mod.check_verification_refs(design)
        self.assertEqual(len(violations), 1)
        v = violations[0]
        self.assertEqual(v["type"], "verification_ref_not_in_mapping")
        self.assertEqual(v["section"], "quality_attributes")
        self.assertEqual(v["verification_ref"], "EV-MISSING")
        self.assertEqual(
            v["location"], "design.json#quality_attributes[0].verification_refs"
        )

    def test_each_of_four_sections_is_checked(self):
        design = _design_skeleton(["UNIT-1"])
        # Force unresolved refs in every target section.
        design["quality_attributes"][0]["verification_refs"] = ["GHOST"]
        design["cross_cutting_concerns"][0]["verification_refs"] = ["GHOST"]
        design["impact_scope"][0]["verification_refs"] = ["GHOST"]
        design["risk_response"][0]["verification_refs"] = ["GHOST"]
        violations = self.mod.check_verification_refs(design)
        sections = {v["section"] for v in violations}
        self.assertEqual(
            sections,
            {
                "quality_attributes",
                "cross_cutting_concerns",
                "impact_scope",
                "risk_response",
            },
        )


class EndToEndMainTests(unittest.TestCase):
    """Run the script as a subprocess against a temp phase-dir."""

    def _write_phase(self, tmp: Path, phase_prd: dict, design: dict) -> Path:
        """Materialize a minimal phase directory with phase-prd.json and design.json."""
        phase_dir = tmp / "phase-1"
        phase_dir.mkdir()
        (phase_dir / "phase-prd.json").write_text(
            json.dumps(phase_prd), encoding="utf-8"
        )
        (phase_dir / "design.json").write_text(json.dumps(design), encoding="utf-8")
        return phase_dir

    def _run(self, phase_dir: Path) -> subprocess.CompletedProcess:
        """Invoke the script as a child process and return the completed run."""
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--phase-dir", str(phase_dir)],
            capture_output=True,
            text=True,
            check=False,
        )

    def test_clean_phase_exits_zero_with_status_pass(self):
        with tempfile.TemporaryDirectory() as td:
            phase_dir = self._write_phase(
                Path(td),
                _phase_prd(["UNIT-1", "UNIT-2"]),
                _design_skeleton(["UNIT-1", "UNIT-2"]),
            )
            result = self._run(phase_dir)
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "PASS")
        self.assertIn("unit_coverage_completeness", payload["checks"])

    def test_missing_design_exits_two(self):
        with tempfile.TemporaryDirectory() as td:
            phase_dir = Path(td) / "phase-1"
            phase_dir.mkdir()
            (phase_dir / "phase-prd.json").write_text("{}", encoding="utf-8")
            result = self._run(phase_dir)
        self.assertEqual(result.returncode, 2)

    def test_seeded_defects_exit_one_with_both_violations(self):
        with tempfile.TemporaryDirectory() as td:
            design = _design_skeleton(["UNIT-1"], module_refs=["UNIT-1", "UNIT-99"])
            phase_dir = self._write_phase(
                Path(td),
                _phase_prd(
                    ["UNIT-1", "UNIT-2"]
                ),  # UNIT-2 present in phase but not in coverage
                design,
            )
            result = self._run(phase_dir)
        self.assertEqual(result.returncode, 1)
        types_seen = {
            json.loads(line)["type"]
            for line in result.stderr.splitlines()
            if line.strip()
        }
        self.assertIn("unit_not_covered_by_design", types_seen)
        self.assertIn("module_references_unknown_unit", types_seen)


if __name__ == "__main__":
    unittest.main()
