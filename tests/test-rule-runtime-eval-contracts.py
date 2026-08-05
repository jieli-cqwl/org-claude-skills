#!/usr/bin/env python3
"""Focused contract tests for the rule-runtime evaluator."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import MappingProxyType
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "eval" / "scripts"))

from rule_runtime_eval.contracts import (
    ContractError,
    EvalCase,
    SceneContract,
    load_acceptance_contract,
    load_profile_cases,
)
from rule_runtime_eval.evidence import classify_route_reads
from rule_runtime_eval.reporting import compare_pair, project_suite_decision
import run_rule_runtime_eval as runner


class RuleRuntimeEvalContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp_dir.name)
        (self.repo / "shared" / "reference").mkdir(parents=True)
        (self.repo / "tools" / "eval" / "scenarios" / "sample").mkdir(parents=True)
        (self.repo / "shared" / "assistant.md").write_text("entry\n", encoding="utf-8")
        (self.repo / "shared" / "reference" / "testing.md").write_text(
            "testing\n", encoding="utf-8"
        )
        (self.repo / "tools" / "eval" / "scenarios" / "sample" / "grader.md").write_text(
            "grader\n", encoding="utf-8"
        )

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_case_exposes_negative_route_bounds_and_repeated_runs(self) -> None:
        self._write_contract(runs=2)
        self._write_cases(
            expected=["testing"],
            forbidden=["unused-scene"],
            max_successful_scene_reads=2,
        )
        self._add_unused_scene()

        contract = load_acceptance_contract(self.repo, Path("contract.json"))
        profile, cases = load_profile_cases(contract, "focused-v2", self.repo)

        self.assertEqual(profile.runs_per_configuration, 2)
        self.assertEqual(cases[0].forbidden_scene_contracts, ("unused-scene",))
        self.assertEqual(cases[0].max_successful_scene_reads, 2)

    def test_case_rejects_required_and_forbidden_scene_overlap(self) -> None:
        self._write_contract(runs=2)
        self._write_cases(
            expected=["testing"],
            forbidden=["testing"],
            max_successful_scene_reads=1,
        )

        contract = load_acceptance_contract(self.repo, Path("contract.json"))
        with self.assertRaisesRegex(ContractError, "required and forbidden"):
            load_profile_cases(contract, "focused-v2", self.repo)

    def test_profile_rejects_single_run_effectiveness_claim(self) -> None:
        self._write_contract(runs=1)
        self._write_cases(
            expected=["testing"],
            forbidden=[],
            max_successful_scene_reads=1,
        )

        with self.assertRaisesRegex(ContractError, "at least two"):
            load_acceptance_contract(self.repo, Path("contract.json"))

    def _write_contract(self, *, runs: int) -> None:
        payload = {
            "runtime_sources": [
                "shared/assistant.md",
                "shared/reference/testing.md",
            ],
            "scene_contracts": [
                {
                    "id": "testing",
                    "runtime_source": "shared/reference/testing.md",
                    "installed_path": "reference/testing.md",
                    "activation": "scene",
                }
            ],
            "case_packs": [
                {
                    "id": "sample",
                    "path": "tools/eval/scenarios/sample/evals.json",
                    "grader": "tools/eval/scenarios/sample/grader.md",
                }
            ],
            "diagnostic_profiles": [
                {
                    "id": "focused-v2",
                    "runs_per_configuration": runs,
                    "anchor_threshold": 1.0,
                    "marginal_effect_case": "sample:case-1",
                    "lightness_policy": {
                        "case": "sample:case-1",
                        "max_irrelevant_read_delta": 0,
                        "max_response_length_ratio": 1.0,
                        "requires_grader_ceremony_signal": True,
                    },
                    "cases": [{"pack": "sample", "id": "case-1"}],
                }
            ],
        }
        (self.repo / "contract.json").write_text(
            json.dumps(payload, indent=2) + "\n", encoding="utf-8"
        )

    def _write_cases(
        self,
        *,
        expected: list[str],
        forbidden: list[str],
        max_successful_scene_reads: int,
    ) -> None:
        payload = {
            "blocking_failures": ["B1"],
            "preference_anchors": [{"id": "P1"}],
            "evals": [
                {
                    "id": "case-1",
                    "prompt": "prompt",
                    "expected_behaviors": ["behavior"],
                    "anti_patterns": ["anti-pattern"],
                    "expected_anchors": ["P1"],
                    "expected_scene_contracts": expected,
                    "forbidden_scene_contracts": forbidden,
                    "max_successful_scene_reads": max_successful_scene_reads,
                }
            ],
        }
        path = self.repo / "tools" / "eval" / "scenarios" / "sample" / "evals.json"
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    def _add_unused_scene(self) -> None:
        contract_path = self.repo / "contract.json"
        payload = json.loads(contract_path.read_text(encoding="utf-8"))
        source = self.repo / "shared" / "reference" / "unused.md"
        source.write_text("unused\n", encoding="utf-8")
        payload["runtime_sources"].append("shared/reference/unused.md")
        payload["scene_contracts"].append(
            {
                "id": "unused-scene",
                "runtime_source": "shared/reference/unused.md",
                "installed_path": "reference/unused.md",
                "activation": "scene",
            }
        )
        contract_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


class RuleRuntimeRouteEvidenceTest(unittest.TestCase):
    def test_forbidden_and_excess_reads_fail_an_otherwise_complete_route(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            codex_home = Path(temp_dir) / ".codex"
            testing = SceneContract(
                "testing", Path("testing.md"), Path("reference/testing.md"), "scene"
            )
            unused = SceneContract(
                "unused", Path("unused.md"), Path("reference/unused.md"), "scene"
            )
            events = [
                self._read_event("read-testing", codex_home / testing.installed_path),
                self._read_event("read-unused", codex_home / unused.installed_path),
            ]

            route = classify_route_reads(
                events,
                (testing,),
                codex_home,
                observed_contracts=(testing, unused),
                forbidden_contract_ids=("unused",),
                max_successful_scene_reads=1,
            )

            self.assertFalse(route.route_pass)
            self.assertEqual(route.forbidden_read_contract_ids, ("unused",))
            self.assertTrue(route.exceeded_max_successful_scene_reads)

    def test_exact_read_is_not_invalidated_by_later_ambiguous_read_of_same_target(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            codex_home = Path(temp_dir) / ".codex"
            testing = SceneContract(
                "testing", Path("testing.md"), Path("reference/testing.md"), "scene"
            )
            target = codex_home / testing.installed_path
            events = [
                self._read_event("exact", target),
                self._read_event("ambiguous", target, shell_pipe=True),
            ]

            route = classify_route_reads(events, (testing,), codex_home)

            self.assertTrue(route.route_evidence_available)
            self.assertTrue(route.route_pass)

    def test_failed_compound_command_that_mentions_target_is_infra_uncertain(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            codex_home = Path(temp_dir) / ".codex"
            testing = SceneContract(
                "testing", Path("testing.md"), Path("reference/testing.md"), "scene"
            )
            target = codex_home / testing.installed_path
            events = [
                {
                    "type": "item.completed",
                    "item": {
                        "id": "partial-read",
                        "type": "command_execution",
                        "command": f"bash -lc 'cat {target}\nrg --files -g README*'",
                        "exit_code": 1,
                        "status": "failed",
                        "aggregated_output": "contract contents",
                    },
                }
            ]

            route = classify_route_reads(events, (testing,), codex_home)

            self.assertFalse(route.route_evidence_available)
            self.assertFalse(route.route_pass)
            self.assertTrue(route.parser_uncertain)

    @staticmethod
    def _read_event(identifier: str, path: Path, *, shell_pipe: bool = False) -> dict[str, object]:
        command = f"bash -lc 'cat {path} | head'" if shell_pipe else f"cat {path}"
        return {
            "type": "item.completed",
            "item": {
                "id": identifier,
                "type": "command_execution",
                "command": command,
                "exit_code": 0,
                "status": "completed",
                "aggregated_output": "content",
            },
        }


class RuleRuntimeReportingTest(unittest.TestCase):
    def test_identical_outcomes_do_not_produce_effectiveness_pass(self) -> None:
        case = self._case()
        candidate = self._record("FRESH_PASS", passing=True)
        baseline = self._record("FRESH_PASS", passing=True)
        pair = compare_pair(case, candidate, baseline, ("shared/assistant.md",), ("shared/assistant.md",))

        decision = project_suite_decision(self._profile(), [pair])

        self.assertEqual(decision["verdict"], "NO_OBSERVED_UPLIFT")
        self.assertIsNone(pair["attribution"])

    def test_selected_subset_uses_its_own_pair_count(self) -> None:
        case = self._case()
        candidate = self._record("FRESH_PASS", passing=True)
        baseline = self._record("BEHAVIOR_FAIL", passing=False)
        pair = compare_pair(case, candidate, baseline, ("shared/assistant.md",), ("shared/assistant.md",))

        decision = project_suite_decision(self._profile(), [pair])

        self.assertEqual(decision["verdict"], "PASS")
        self.assertEqual(decision["complete_pairs"], 1)

    @staticmethod
    def _case() -> EvalCase:
        return EvalCase(
            pack_id="sample",
            id="case-1",
            prompt="prompt",
            expected_behaviors=("behavior",),
            anti_patterns=("anti-pattern",),
            blocking_failures=("blocking",),
            expected_anchors=("P1",),
            anchor_definitions=MappingProxyType({"P1": MappingProxyType({"id": "P1"})}),
            expected_scene_contracts=("testing",),
            forbidden_scene_contracts=(),
            max_successful_scene_reads=1,
        )

    @staticmethod
    def _record(state: str, *, passing: bool) -> dict[str, object]:
        return {
            "state": state,
            "route_pass": passing,
            "identity": {
                "case": "case",
                "grader": "grader",
                "model": "model",
                "reasoning": "medium",
            },
            "grading": {
                "behavior_verdict": "PASS" if passing else "FAIL",
                "expectations": [{"met": passing}],
                "anti_patterns": [{"present": not passing}],
                "blocking_failures": [{"present": False}],
                "anchors": [{"score": 2 if passing else 0}],
            },
            "irrelevant_successful_reads": 0,
            "response_characters": 100,
        }

    @staticmethod
    def _profile() -> dict[str, object]:
        return {
            "id": "focused-subset",
            "anchor_threshold": 1.0,
            "marginal_effect_case": "sample:case-1",
            "lightness_policy": {
                "case": "sample:case-1",
                "max_irrelevant_read_delta": 0,
                "max_response_length_ratio": 1.0,
                "requires_grader_ceremony_signal": True,
            },
        }


class RuleRuntimeRunnerBoundaryTest(unittest.TestCase):
    def test_baseline_must_be_a_distinct_ancestor(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo = Path(temp_dir)
            self._git(repo, "init")
            self._git(repo, "config", "user.email", "eval@example.invalid")
            self._git(repo, "config", "user.name", "Eval Test")
            (repo / "value.txt").write_text("one\n", encoding="utf-8")
            self._git(repo, "add", "value.txt")
            self._git(repo, "commit", "-m", "first")
            ancestor = self._git(repo, "rev-parse", "HEAD")
            (repo / "value.txt").write_text("two\n", encoding="utf-8")
            self._git(repo, "commit", "-am", "second")
            candidate = self._git(repo, "rev-parse", "HEAD")

            runner._validate_baseline_commits(
                repo, candidate, [{"pack_id": "sample", "commit": ancestor}]
            )
            with self.assertRaisesRegex(ContractError, "distinct"):
                runner._validate_baseline_commits(
                    repo, candidate, [{"pack_id": "sample", "commit": candidate}]
                )

    def test_installed_runtime_targets_include_rendered_entry(self) -> None:
        scene = SceneContract(
            "testing", Path("testing.md"), Path("reference/testing.md"), "scene"
        )
        contract = type("Contract", (), {"scene_contracts": (scene,)})()

        targets = runner._installed_runtime_targets(contract)

        self.assertEqual(targets[0], Path("AGENTS.md"))
        self.assertIn(Path("reference/testing.md"), targets)

    def test_repeated_run_order_is_interleaved(self) -> None:
        self.assertEqual(
            runner._configuration_order(1, "candidate", "baseline"),
            ("candidate", "baseline"),
        )
        self.assertEqual(
            runner._configuration_order(2, "candidate", "baseline"),
            ("baseline", "candidate"),
        )

    @staticmethod
    def _git(repo: Path, *args: str) -> str:
        completed = subprocess.run(
            ["git", "-C", str(repo), *args],
            check=True,
            capture_output=True,
            text=True,
        )
        return completed.stdout.strip()


if __name__ == "__main__":
    unittest.main()
