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
                ("qft-all", "3.0.0.MASTER", "3.0.0.DEV_QW_0001_0301", "ensure_branch"),
                ("qft-app", "master", "3.0.0.DEV_QW_0001_0301", "ensure_branch"),
            ],
        )
        self.assertFalse(plan["push"]["confirmed"])

    def test_plan_accepts_project_numbers_and_business_names(self) -> None:
        result = run_flow(
            "plan",
            "create-dev",
            "--projects",
            "1,全房通 PC 前端",
            "--owner",
            "qw",
            "--requirement",
            "0001",
            "--version",
            "0301",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["owner"], "QW")
        self.assertEqual(plan["projects"], ["qft-all", "qft-app"])
        self.assertEqual(plan["target_branch"], "3.0.0.DEV_QW_0001_0301")
        self.assertEqual(
            step_tuples(plan),
            [
                ("qft-all", "3.0.0.MASTER", "3.0.0.DEV_QW_0001_0301", "ensure_branch"),
                ("qft-app", "master", "3.0.0.DEV_QW_0001_0301", "ensure_branch"),
            ],
        )

    def test_plan_bug_branch_uses_feedback_date_and_reuses_existing_branch(
        self,
    ) -> None:
        result = run_flow(
            "plan",
            "bugfix",
            "--projects",
            "qft-harmonyos-vue3,qft-universal.gitersal",
            "--version",
            "0528",
            "--bug-version",
            "0602",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["scenario"], "bugfix")
        self.assertEqual(plan["version"], "0528")
        self.assertEqual(plan["bug_version"], "0602")
        self.assertEqual(plan["target_branch"], "3.0.0.MASTER_BUG_0602")
        self.assertEqual(
            step_tuples(plan),
            [
                (
                    "qft-harmonyos-vue3",
                    "V.0528",
                    "3.0.0.MASTER_BUG_0602",
                    "ensure_branch",
                ),
                (
                    "qft-universal.gitersal",
                    "V.0528",
                    "3.0.0.MASTER_BUG_0602",
                    "ensure_branch",
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
            "0528",
            "--bug-version",
            "0602",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["scenario"], "bugfix-finish")
        self.assertEqual(plan["version"], "0528")
        self.assertEqual(plan["bug_version"], "0602")
        self.assertEqual(plan["target_branch"], "V.0528")
        self.assertEqual(
            step_tuples(plan),
            [
                (
                    "qft-harmonyos-vue3",
                    "3.0.0.MASTER_BUG_0602",
                    "V.0528",
                    "merge",
                ),
                (
                    "qft-universal.gitersal",
                    "3.0.0.MASTER_BUG_0602",
                    "V.0528",
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

    def test_plan_release_merge_accepts_single_business_branch_for_all_projects(
        self,
    ) -> None:
        result = run_flow(
            "plan",
            "release-merge",
            "--projects",
            "qft-all,qft-app",
            "--version",
            "0301",
            "--business-branch",
            "3.0.0.DEV_QW_0001_0301",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(
            plan["business_branches"],
            {
                "qft-all": "3.0.0.DEV_QW_0001_0301",
                "qft-app": "3.0.0.DEV_QW_0001_0301",
            },
        )
        self.assertEqual(
            step_tuples(plan),
            [
                ("qft-all", "3.0.0.MASTER", "V.0301", "ensure_branch"),
                ("qft-all", "3.0.0.DEV_QW_0001_0301", "V.0301", "merge"),
                ("qft-app", "master", "V.0301", "ensure_branch"),
                ("qft-app", "3.0.0.DEV_QW_0001_0301", "V.0301", "merge"),
            ],
        )

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

    def test_plan_dev_sync_accepts_single_business_branch_for_all_projects(
        self,
    ) -> None:
        result = run_flow(
            "plan",
            "dev-sync",
            "--projects",
            "qft-all,qft-app",
            "--version",
            "0301",
            "--business-branch",
            "3.0.0.DEV_QW_0001_0301",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["target_branch"], "3.0.0.DEV_QW_0001_0301")
        self.assertEqual(
            plan["business_branches"],
            {
                "qft-all": "3.0.0.DEV_QW_0001_0301",
                "qft-app": "3.0.0.DEV_QW_0001_0301",
            },
        )
        self.assertEqual(
            step_tuples(plan),
            [
                ("qft-all", "3.0.0.MASTER", "3.0.0.DEV_QW_0001_0301", "merge"),
                ("qft-app", "master", "3.0.0.DEV_QW_0001_0301", "merge"),
            ],
        )

    def test_plan_rejects_business_branch_version_mismatch(self) -> None:
        result = run_flow(
            "plan",
            "dev-sync",
            "--projects",
            "qft-all,qft-app",
            "--version",
            "0301",
            "--business-branch",
            "3.0.0.DEV_QW_0001_0625",
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "business branch version 0625 must match --version 0301",
            result.stderr,
        )

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
            (
                (
                    "plan",
                    "bugfix",
                    "--projects",
                    "qft-harmonyos-vue3",
                    "--version",
                    "0528",
                ),
                "bug-version must match ^[0-9]{4}$",
            ),
        ]
        for args, message in cases:
            with self.subTest(message=message):
                result = run_flow(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stderr)
                self.assertNotIn("Traceback", result.stderr)

    def test_validate_rejects_business_branch_version_mismatch(self) -> None:
        plan = {
            "schema_version": "1.0.0",
            "scenario": "dev-sync",
            "version": "0301",
            "projects": ["qft-app"],
            "business_branches": {"qft-app": "3.0.0.DEV_QW_0001_0625"},
            "target_branch": "3.0.0.DEV_QW_0001_0625",
            "steps": [
                {
                    "repo": "qft-app",
                    "source_branch": "master",
                    "target_branch": "3.0.0.DEV_QW_0001_0625",
                    "action": "merge",
                }
            ],
            "push": {"confirmed": False, "branches": []},
        }

        result = run_flow("validate", input_payload=plan)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "business branch version 0625 must match --version 0301",
            result.stderr,
        )
        self.assertNotIn("Traceback", result.stderr)

    def test_validate_rejects_wrong_bug_merge_direction(self) -> None:
        bad_plan = {
            "schema_version": "1.0.0",
            "scenario": "bugfix",
            "version": "0528",
            "bug_version": "0602",
            "projects": ["qft-harmonyos-vue3"],
            "target_branch": "3.0.0.MASTER_BUG_0602",
            "steps": [
                {
                    "repo": "qft-harmonyos-vue3",
                    "source_branch": "3.0.0.MASTER_BUG_0602",
                    "target_branch": "master",
                    "action": "merge",
                }
            ],
            "push": {"confirmed": False, "branches": []},
        }

        result = run_flow("validate", input_payload=bad_plan)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("bugfix must ensure BUG branch from V.0528", result.stderr)
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
                    "action": "ensure_branch",
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
                    "action": "ensure_branch",
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

    def test_plan_release_sync_before_ensures_release_branch_then_merges_main(
        self,
    ) -> None:
        result = run_flow(
            "plan",
            "release-sync-before",
            "--projects",
            "qft-app,qft-system",
            "--version",
            "0301",
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["target_branch"], "V.0301")
        self.assertEqual(
            step_tuples(plan),
            [
                ("qft-app", "master", "V.0301", "ensure_branch"),
                ("qft-app", "master", "V.0301", "merge"),
                ("qft-system", "master", "V.0301", "ensure_branch"),
                ("qft-system", "master", "V.0301", "merge"),
            ],
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
