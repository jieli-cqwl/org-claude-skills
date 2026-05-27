#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "shared/skills/qft-branch-flow/scripts/qft_branch_flow.py"


def run_flow(
    *args: str, input_payload: dict | None = None
) -> subprocess.CompletedProcess[str]:
    input_path = None
    with tempfile.TemporaryDirectory() as tmp_dir:
        if input_payload is not None:
            input_path = Path(tmp_dir) / "input.json"
            input_path.write_text(
                json.dumps(input_payload, ensure_ascii=False), encoding="utf-8"
            )
        command = ["python3", str(SCRIPT), *args]
        if input_path is not None:
            command.extend(["--input", str(input_path)])
        return subprocess.run(
            command,
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )


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
        self.assertEqual(plan["version"], "0301")
        self.assertEqual(plan["target_branch"], "3.0.0.DEV_QW_0001_0301")
        self.assertEqual(
            [
                (
                    item["repo"],
                    item["source_branch"],
                    item["target_branch"],
                    item["action"],
                )
                for item in plan["steps"]
            ],
            [
                ("qft-all", "3.0.0.MASTER", "3.0.0.DEV_QW_0001_0301", "create_branch"),
                ("qft-app", "master", "3.0.0.DEV_QW_0001_0301", "create_branch"),
            ],
        )
        self.assertFalse(plan["push"]["confirmed"])

    def test_plan_bug_branch_includes_create_and_merge_back(self) -> None:
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
            [
                (
                    item["repo"],
                    item["source_branch"],
                    item["target_branch"],
                    item["action"],
                )
                for item in plan["steps"]
            ],
            [
                (
                    "qft-harmonyos-vue3",
                    "V.0301",
                    "3.0.0.MASTER_BUG_0301",
                    "create_branch",
                ),
                ("qft-harmonyos-vue3", "3.0.0.MASTER_BUG_0301", "V.0301", "merge"),
                (
                    "qft-universal.gitersal",
                    "V.0301",
                    "3.0.0.MASTER_BUG_0301",
                    "create_branch",
                ),
                ("qft-universal.gitersal", "3.0.0.MASTER_BUG_0301", "V.0301", "merge"),
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
        self.assertEqual(plan["scenario"], "release-merge")
        self.assertEqual(
            [
                (
                    item["repo"],
                    item["source_branch"],
                    item["target_branch"],
                    item["action"],
                )
                for item in plan["steps"]
            ],
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
        self.assertEqual(plan["scenario"], "dev-sync")
        self.assertEqual(plan["target_branch"], "3.0.0.DEV_QW_0001_0301")
        self.assertEqual(
            [
                (
                    item["repo"],
                    item["source_branch"],
                    item["target_branch"],
                    item["action"],
                )
                for item in plan["steps"]
            ],
            [
                ("qft-all", "3.0.0.MASTER", "3.0.0.DEV_QW_0001_0301", "merge"),
                ("qft-app", "master", "3.0.0.DEV_QW_0001_0301", "merge"),
            ],
        )

    def test_plan_dev_sync_rejects_missing_business_branch_with_scenario_message(
        self,
    ) -> None:
        result = run_flow(
            "plan",
            "dev-sync",
            "--projects",
            "qft-all,qft-app",
            "--version",
            "0301",
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("dev-sync requires --business-branches", result.stderr)
        self.assertNotIn("release-merge requires --business-branches", result.stderr)
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
        self.assertIn("bugfix must merge BUG branch back to V.0301", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

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
        self.assertEqual(plan["scenario"], "release-sync-after")
        self.assertEqual(plan["target_branch"], "<project-main-branch>")
        self.assertEqual(
            [
                (
                    item["repo"],
                    item["source_branch"],
                    item["target_branch"],
                    item["action"],
                )
                for item in plan["steps"]
            ],
            [
                ("qft-app", "V.0301", "master", "merge"),
                ("qft-system", "V.0301", "master", "merge"),
            ],
        )

    def test_plan_rejects_duplicate_project(self) -> None:
        result = run_flow(
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
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate project: qft-all", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_plan_release_merge_rejects_missing_business_branch(self) -> None:
        result = run_flow(
            "plan",
            "release-merge",
            "--projects",
            "qft-all,qft-app",
            "--version",
            "0301",
            "--business-branches",
            "qft-all=3.0.0.DEV_QW_0001_0301",
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing business branch for: qft-app", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

        result = run_flow(
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
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown project: unknown-repo", result.stderr)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
