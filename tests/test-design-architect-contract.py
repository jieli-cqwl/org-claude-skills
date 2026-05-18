#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "shared/skills/design/scripts/validate_design_architect_contract.py"


def load_module():
    spec = importlib.util.spec_from_file_location("validate_design_architect_contract", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


def base_design() -> dict:
    return {
        "runtime_facts": [
            "users table has password_hash; evidence=src/auth/schema.sql; observed_at=2026-05-18T00:00:00Z"
        ],
        "interfaces": [
            {
                "interface_id": "IF-LOGIN",
                "owner": "MOD-AUTH",
                "contract_summary": "POST /api/login sets a session cookie.",
                "error_modes": ["validation error", "auth failure", "system failure"],
                "input_params": [{"name": "email", "type": "string", "required": True, "validation": "email", "description": "login identity"}],
                "output_params": [{"name": "set_cookie", "type": "header", "description": "HttpOnly session cookie"}],
                "error_codes": [{"code": "INVALID_CREDENTIALS", "condition": "bad credentials", "user_message": "账号或密码错误"}],
                "boundary_behaviors": [
                    {"scenario": "wrong password", "expected_behavior": "return 401 without account enumeration", "verification_ref": "VP-LOGIN"}
                ],
            }
        ],
        "interface_boundary": ["browser -> IF-LOGIN -> MOD-AUTH: input/output/error/boundary behavior"],
        "verification_mapping": [
            {"evidence_ref": "VP-LOGIN", "scope": "login behavior"}
        ],
        "key_decisions": [{"decision_id": "D-SESSION", "option_ref": "OPT-COOKIE"}],
        "option_analysis": [
            {"option_id": "OPT-COOKIE", "decision_ref": "D-SESSION"},
            {"option_id": "OPT-BEARER", "decision_ref": "D-SESSION"},
        ],
        "cross_cutting_concerns": [
            {"concern": "auth", "decision": "Use existing auth middleware", "owner": "MOD-AUTH", "verification_refs": ["VP-LOGIN"]},
            {"concern": "error", "decision": "Use stable error envelope", "owner": "MOD-AUTH", "verification_refs": ["VP-LOGIN"]},
            {"concern": "log", "decision": "Log security events without password", "owner": "MOD-AUTH", "verification_refs": ["VP-LOGIN"]},
            {"concern": "config", "decision": "Read TTL from config", "owner": "MOD-AUTH", "verification_refs": ["VP-LOGIN"]},
        ],
        "risks": [
            {"risk_id": "R-COOKIE", "description": "cookie settings can regress"}
        ],
        "risk_response": [
            {"risk_id": "R-COOKIE", "response": "add cookie contract test", "verification_refs": ["VP-LOGIN"]}
        ],
        "review_closure": {
            "reviewed_design_digest": "sha256:" + "0" * 64,
            "reviewed_at": "2026-05-18T00:00:00Z",
            "reviewers": [
                {"reviewer": "architecture", "verdict": "PASS", "reviewed_design_digest": "sha256:" + "0" * 64, "finding_refs": []},
                {"reviewer": "product", "verdict": "PASS", "reviewed_design_digest": "sha256:" + "0" * 64, "finding_refs": []},
                {"reviewer": "test", "verdict": "PASS", "reviewed_design_digest": "sha256:" + "0" * 64, "finding_refs": []},
            ],
            "resolved_failures": [],
            "warn_followups": [],
        },
    }


class ArchitectContractUnitTests(unittest.TestCase):
    def setUp(self) -> None:
        self.mod = load_module()

    def test_clean_design_has_no_violations(self):
        self.assertEqual(self.mod.check_design(base_design()), [])

    def test_runtime_fact_self_reference_is_rejected(self):
        design = base_design()
        design["runtime_facts"] = [
            "users table has password_hash; evidence=design.json#input_analysis; observed_at=2026-05-18T00:00:00Z"
        ]
        violations = self.mod.check_design(design)
        self.assertIn("runtime_fact_weak_evidence", {v["type"] for v in violations})

    def test_interface_requires_boundary_behaviors_when_interfaces_exist(self):
        design = base_design()
        del design["interfaces"][0]["boundary_behaviors"]
        violations = self.mod.check_design(design)
        self.assertIn("interface_missing_boundary_behaviors", {v["type"] for v in violations})

    def test_empty_interfaces_are_allowed_with_boundary_summary(self):
        design = base_design()
        design["interfaces"] = []
        design["interface_boundary"] = ["No interface changes; existing IF-LOGIN contract remains unchanged."]
        self.assertEqual(self.mod.check_design(design), [])

    def test_boundary_behavior_verification_ref_must_resolve(self):
        design = base_design()
        design["interfaces"][0]["boundary_behaviors"][0]["verification_ref"] = "VP-MISSING"
        violations = self.mod.check_design(design)
        self.assertIn("boundary_behavior_verification_ref_unresolved", {v["type"] for v in violations})

    def test_cross_cutting_concerns_must_be_exact_set(self):
        design = base_design()
        design["cross_cutting_concerns"] = design["cross_cutting_concerns"][:3]
        violations = self.mod.check_design(design)
        self.assertIn("cross_cutting_missing_concern", {v["type"] for v in violations})

    def test_risk_response_must_cover_each_risk(self):
        design = base_design()
        design["risk_response"] = []
        violations = self.mod.check_design(design)
        self.assertIn("risk_without_response", {v["type"] for v in violations})

    def test_reviewers_must_be_unique_exact_set(self):
        design = base_design()
        design["review_closure"]["reviewers"][2]["reviewer"] = "product"
        violations = self.mod.check_design(design)
        self.assertIn("reviewer_set_invalid", {v["type"] for v in violations})


class ArchitectContractSubprocessTests(unittest.TestCase):
    def test_cli_reports_jsonl_and_nonzero_for_seeded_defect(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "design.json"
            design = base_design()
            design["risk_response"] = []
            path.write_text(json.dumps(design), encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--design", str(path)],
                text=True,
                capture_output=True,
                check=False,
            )
        self.assertEqual(result.returncode, 1)
        self.assertIn("risk_without_response", result.stderr)


if __name__ == "__main__":
    unittest.main()
