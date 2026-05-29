#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from qft_branch_flow_helpers import run_flow


class QftBranchFlowPlanTests(unittest.TestCase):
    def test_plan_create_dev_branch_for_multiple_projects(self) -> None:
        result = run_flow(
            "plan",
            "create-dev",
            "--projects",
            "qft-all,qft-app",
            "--owner",
            "QW",
            "--requirement",
            "0001",
            "--version",
            "0301",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["scenario"], "create-dev")
        self.assertEqual(plan["target_branch"], "3.0.0.DEV_QW_0001_0301")
        self.assertEqual(
            step_tuples(plan),
            [
                ("qft-all", "3.0.0.MASTER", "3.0.0.DEV_QW_0001_0301", "create_branch"),
                ("qft-app", "master", "3.0.0.DEV_QW_0001_0301", "create_branch"),
            ],
        )
        self.assertFalse(plan["push"]["confirmed"])

    def test_plan_bug_branch_only_creates_bug_branch(self) -> None:
        result = run_flow(
            "plan",
            "bugfix",
            "--projects",
            "qft-harmonyos-vue3,qft-universal.gitersal",
            "--version",
            "0301",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["scenario"], "bugfix")
        self.assertEqual(plan["target_branch"], "3.0.0.MASTER_BUG_0301")
        self.assertEqual(
            step_tuples(plan),
            [
                (
                    "qft-harmonyos-vue3",
                    "V.0301",
                    "3.0.0.MASTER_BUG_0301",
                    "create_branch",
                ),
                (
                    "qft-universal.gitersal",
                    "V.0301",
                    "3.0.0.MASTER_BUG_0301",
                    "create_branch",
                ),
            ],
        )

    def test_plan_bugfix_finish_merges_bug_branch_back(self) -> None:
        result = run_flow(
            "plan",
            "bugfix-finish",
            "--projects",
            "qft-harmonyos-vue3,qft-universal.gitersal",
            "--version",
            "0301",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["scenario"], "bugfix-finish")
        self.assertEqual(plan["target_branch"], "V.0301")
        self.assertEqual(
            step_tuples(plan),
            [
                (
                    "qft-harmonyos-vue3",
                    "3.0.0.MASTER_BUG_0301",
                    "V.0301",
                    "merge",
                ),
                (
                    "qft-universal.gitersal",
                    "3.0.0.MASTER_BUG_0301",
                    "V.0301",
                    "merge",
                ),
            ],
        )

    def test_plan_release_merge_ensures_release_branch_then_merges_business_branch(
        self,
    ) -> None:
        result = run_flow(
            "plan",
            "release-merge",
            "--projects",
            "qft-all,qft-app",
            "--version",
            "0301",
            "--business-branches",
            "qft-all=3.0.0.DEV_QW_0001_0301,qft-app=3.0.0.DEV_QW_0001_0301",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(
            step_tuples(plan),
            [
                ("qft-all", "3.0.0.MASTER", "V.0301", "ensure_branch"),
                ("qft-all", "3.0.0.DEV_QW_0001_0301", "V.0301", "merge"),
                ("qft-app", "master", "V.0301", "ensure_branch"),
                ("qft-app", "3.0.0.DEV_QW_0001_0301", "V.0301", "merge"),
            ],
        )

    def test_plan_dev_sync_merges_main_branch_to_business_branch(self) -> None:
        result = run_flow(
            "plan",
            "dev-sync",
            "--projects",
            "qft-all,qft-app",
            "--version",
            "0301",
            "--business-branches",
            "qft-all=3.0.0.DEV_QW_0001_0301,qft-app=3.0.0.DEV_QW_0001_0301",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["target_branch"], "3.0.0.DEV_QW_0001_0301")
        self.assertEqual(
            step_tuples(plan),
            [
                ("qft-all", "3.0.0.MASTER", "3.0.0.DEV_QW_0001_0301", "merge"),
                ("qft-app", "master", "3.0.0.DEV_QW_0001_0301", "merge"),
            ],
        )

    def test_plan_rejects_missing_or_invalid_inputs(self) -> None:
        cases = [
            (
                (
                    "plan",
                    "dev-sync",
                    "--projects",
                    "qft-all,qft-app",
                    "--version",
                    "0301",
                ),
                "dev-sync requires --business-branches",
            ),
            (
                (
                    "plan",
                    "create-dev",
                    "--projects",
                    "qft-all,qft-all",
                    "--owner",
                    "QW",
                    "--requirement",
                    "0001",
                    "--version",
                    "0301",
                ),
                "duplicate project: qft-all",
            ),
            (
                (
                    "plan",
                    "create-dev",
                    "--projects",
                    "qft-all,unknown-repo",
                    "--owner",
                    "QW",
                    "--requirement",
                    "0001",
                    "--version",
                    "0301",
                ),
                "unknown project: unknown-repo",
            ),
            (
                (
                    "plan",
                    "release-merge",
                    "--projects",
                    "qft-all,qft-app",
                    "--version",
                    "0301",
                    "--business-branches",
                    "qft-all=3.0.0.DEV_QW_0001_0301",
                ),
                "missing business branch for: qft-app",
            ),
        ]
        for args, message in cases:
            with self.subTest(message=message):
                result = run_flow(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stderr)
                self.assertNotIn("Traceback", result.stderr)

    def test_validate_rejects_wrong_bug_merge_direction(self) -> None:
        bad_plan = {
            "schema_version": "1.0.0",
            "scenario": "bugfix",
            "version": "0301",
            "projects": ["qft-harmonyos-vue3"],
            "target_branch": "3.0.0.MASTER_BUG_0301",
            "steps": [
                {
                    "repo": "qft-harmonyos-vue3",
                    "source_branch": "3.0.0.MASTER_BUG_0301",
                    "target_branch": "master",
                    "action": "merge",
                }
            ],
            "push": {"confirmed": False, "branches": []},
        }

        result = run_flow("validate", input_payload=bad_plan)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("bugfix must create BUG branch from V.0301", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_validate_rejects_preconfirmed_push_in_initial_plan(self) -> None:
        plan = {
            "schema_version": "1.0.0",
            "scenario": "create-dev",
            "version": "0301",
            "owner": "QW",
            "requirement": "0001",
            "delay": False,
            "projects": ["qft-app"],
            "target_branch": "3.0.0.DEV_QW_0001_0301",
            "steps": [
                {
                    "repo": "qft-app",
                    "source_branch": "master",
                    "target_branch": "3.0.0.DEV_QW_0001_0301",
                    "action": "create_branch",
                }
            ],
            "push": {"confirmed": True, "branches": []},
        }

        result = run_flow("validate", input_payload=plan)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "push.confirmed must be false before local execution", result.stderr
        )

    def test_validate_rejects_push_branches_in_initial_plan(self) -> None:
        plan = {
            "schema_version": "1.0.0",
            "scenario": "create-dev",
            "version": "0301",
            "owner": "QW",
            "requirement": "0001",
            "delay": False,
            "projects": ["qft-app"],
            "target_branch": "3.0.0.DEV_QW_0001_0301",
            "steps": [
                {
                    "repo": "qft-app",
                    "source_branch": "master",
                    "target_branch": "3.0.0.DEV_QW_0001_0301",
                    "action": "create_branch",
                }
            ],
            "push": {
                "confirmed": False,
                "branches": [{"repo": "qft-app", "branch": "master"}],
            },
        }

        result = run_flow("validate", input_payload=plan)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "push.branches must be empty before local execution", result.stderr
        )

    def test_plan_release_sync_after_targets_project_main_branch(self) -> None:
        result = run_flow(
            "plan",
            "release-sync-after",
            "--projects",
            "qft-app,qft-system",
            "--version",
            "0301",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["target_branch"], "<project-main-branch>")
        self.assertEqual(
            step_tuples(plan),
            [
                ("qft-app", "V.0301", "master", "merge"),
                ("qft-system", "V.0301", "master", "merge"),
            ],
        )


def step_tuples(plan: dict) -> list[tuple[str, str, str, str]]:
    return [
        (item["repo"], item["source_branch"], item["target_branch"], item["action"])
        for item in plan["steps"]
    ]


if __name__ == "__main__":
    unittest.main(verbosity=2)
