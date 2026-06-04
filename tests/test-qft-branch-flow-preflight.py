#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from qft_branch_flow_helpers import (
    blocker_codes,
    bugfix_plan,
    clone_project,
    commit_file,
    create_dev_plan,
    create_remote_repo,
    dev_sync_plan,
    release_merge_plan,
    run_git,
    run_preflight,
)


class QftBranchFlowPreflightTests(unittest.TestCase):
    def test_preflight_ensure_branch_allows_missing_target(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            origin, _seed = create_remote_repo(root)
            clone_project(root, origin)

            result = run_preflight(root, create_dev_plan())

        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "ok")
        self.assertEqual(blocker_codes(report), set())
        check = report["repos"][0]["checks"][0]
        self.assertIsNone(check["target"]["local_sha"])
        self.assertIsNone(check["target"]["remote_sha"])
        self.assertEqual(check["target_resolution"], "create_missing")
        self.assertFalse(check["requires_user_confirmation"])
        repo = report["repos"][0]
        self.assertEqual(repo["worktree"]["status"], "ok")
        self.assertTrue(repo["worktree"]["clean"])
        self.assertEqual(repo["remote"]["status"], "ok")
        self.assertEqual(repo["remote"]["actual"], str(origin))
        self.assertEqual(repo["remote"]["expected"], str(origin))

    def test_preflight_create_dev_reuses_existing_remote_branch(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            origin, seed = create_remote_repo(root)
            dev_branch = "3.0.0.DEV_ZY_4109_0625"
            run_git(seed, "switch", "-c", dev_branch)
            commit_file(seed, "dev.txt", "dev\n")
            run_git(seed, "push", "origin", dev_branch)
            clone_project(root, origin)

            result = run_preflight(root, create_dev_plan())

        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "ok")
        self.assertEqual(blocker_codes(report), set())
        check = report["repos"][0]["checks"][0]
        self.assertEqual(check["action"], "ensure_branch")
        self.assertEqual(check["target_resolution"], "reuse_existing")
        self.assertTrue(check["requires_user_confirmation"])
        self.assertIsNotNone(check["target"]["remote_sha"])

    def test_preflight_accepts_current_project_workspace(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            origin, _seed = create_remote_repo(root)
            checkout = clone_project(root, origin)

            result = run_preflight(root, create_dev_plan(), repo_root_arg=str(checkout))

        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "ok")
        self.assertEqual(blocker_codes(report), set())
        self.assertEqual(report["repos"][0]["repo"], "qft-app")
        self.assertEqual(Path(report["repos"][0]["path"]).name, "qft-app")

    def test_preflight_resolves_from_current_window_subdirectory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            app_origin, _app_seed = create_remote_repo(root, "qft-app")
            app_checkout = clone_project(root, app_origin, "qft-app")
            common_origin, _common_seed = create_remote_repo(root, "qft-common")
            clone_project(root, common_origin, "qft-common")
            current_window_dir = app_checkout / "src" / "main"
            current_window_dir.mkdir(parents=True)
            plan = create_dev_plan()
            plan["projects"] = ["qft-app", "qft-common"]
            plan["steps"].append(
                {
                    "repo": "qft-common",
                    "source_branch": "master",
                    "target_branch": plan["target_branch"],
                    "action": "ensure_branch",
                }
            )

            result = run_preflight(current_window_dir, plan)

        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "ok")
        self.assertEqual(
            {item["repo"]: Path(item["path"]).name for item in report["repos"]},
            {"qft-app": "qft-app", "qft-common": "qft-common"},
        )

    def test_preflight_blocks_same_basename_wrong_remote(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            origin, _seed = create_remote_repo(root)
            checkout = clone_project(root, origin)
            wrong_origin = root / "mirror" / "qft-app.git"
            wrong_origin.parent.mkdir()
            subprocess_result = run_git(
                checkout, "remote", "set-url", "origin", str(wrong_origin)
            )
            self.assertEqual(subprocess_result.returncode, 0)

            result = run_preflight(root, create_dev_plan())

        self.assertNotEqual(result.returncode, 0)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "blocked")
        self.assertIn("remote_mismatch", blocker_codes(report))

    def test_preflight_blocks_same_host_wrong_port_remote(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            origin, _seed = create_remote_repo(root)
            checkout = clone_project(root, origin)
            run_git(
                checkout,
                "remote",
                "set-url",
                "origin",
                "http://121.42.43.167:10011/qft-web/qft-app.git",
            )

            result = run_preflight(root, create_dev_plan())

        self.assertNotEqual(result.returncode, 0)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "blocked")
        self.assertIn("remote_mismatch", blocker_codes(report))

    def test_preflight_skips_current_git_repo_when_remote_mismatches(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            app_origin, _app_seed = create_remote_repo(root)
            clone_project(root, app_origin)
            wrong_origin, _wrong_seed = create_remote_repo(root, "wrong-repo")
            wrong_checkout = clone_project(root, wrong_origin, "wrong-repo")

            result = run_preflight(
                root, create_dev_plan(), repo_root_arg=str(wrong_checkout)
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "ok")
        self.assertEqual(blocker_codes(report), set())
        self.assertEqual(report["repos"][0]["repo"], "qft-app")
        self.assertEqual(Path(report["repos"][0]["path"]).name, "qft-app")

    def test_preflight_blocks_source_when_remote_has_new_commit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            origin, seed = create_remote_repo(root)
            clone_project(root, origin)
            commit_file(seed, "remote.txt", "remote\n")
            run_git(seed, "push", "origin", "master")

            result = run_preflight(root, create_dev_plan())

        self.assertNotEqual(result.returncode, 0)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "blocked")
        self.assertIn("source_differs_remote", blocker_codes(report))

    def test_preflight_blocks_target_case_conflict(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            origin, seed = create_remote_repo(root)
            clone_project(root, origin)
            case_branch = "3.0.0.dev_zy_4109_0625"
            run_git(seed, "switch", "-c", case_branch)
            commit_file(seed, "case.txt", "case\n")
            run_git(seed, "push", "origin", case_branch)

            result = run_preflight(root, create_dev_plan())

        self.assertNotEqual(result.returncode, 0)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "blocked")
        self.assertIn("target_case_conflict", blocker_codes(report))

    def test_preflight_blocks_missing_merge_target(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            origin, _seed = create_remote_repo(root)
            clone_project(root, origin)

            result = run_preflight(root, dev_sync_plan())

        self.assertNotEqual(result.returncode, 0)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "blocked")
        self.assertIn("target_missing", blocker_codes(report))

    def test_preflight_blocks_local_only_ensure_target(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            origin, _seed = create_remote_repo(root)
            checkout = clone_project(root, origin)
            run_git(checkout, "switch", "-c", "3.0.0.DEV_ZY_4109_0625")
            commit_file(checkout, "local.txt", "local\n")

            result = run_preflight(root, create_dev_plan())

        self.assertNotEqual(result.returncode, 0)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "blocked")
        self.assertIn("target_local_only", blocker_codes(report))

    def test_preflight_blocks_local_only_merge_target(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            origin, _seed = create_remote_repo(root)
            checkout = clone_project(root, origin)
            run_git(checkout, "switch", "-c", "3.0.0.DEV_ZY_4109_0625")
            commit_file(checkout, "local.txt", "local\n")

            result = run_preflight(root, dev_sync_plan())

        self.assertNotEqual(result.returncode, 0)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "blocked")
        self.assertIn("target_local_only", blocker_codes(report))

    def test_preflight_allows_merge_target_created_by_earlier_step(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            origin, seed = create_remote_repo(root)
            run_git(seed, "switch", "-c", "3.0.0.DEV_ZY_4109_0625")
            commit_file(seed, "business.txt", "business\n")
            run_git(seed, "push", "origin", "3.0.0.DEV_ZY_4109_0625")
            clone_project(root, origin)

            result = run_preflight(root, release_merge_plan())

        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "ok")
        self.assertEqual(blocker_codes(report), set())
        merge_check = report["repos"][0]["checks"][1]
        self.assertTrue(merge_check["target_planned"])

    def test_preflight_bugfix_reuses_existing_remote_bug_branch(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            origin, seed = create_remote_repo(root)
            run_git(seed, "switch", "-c", "V.0528")
            commit_file(seed, "release.txt", "release\n")
            run_git(seed, "push", "origin", "V.0528")
            run_git(seed, "switch", "-c", "3.0.0.MASTER_BUG_0602")
            commit_file(seed, "bug.txt", "bug\n")
            run_git(seed, "push", "origin", "3.0.0.MASTER_BUG_0602")
            clone_project(root, origin)

            result = run_preflight(root, bugfix_plan())

        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "ok")
        self.assertEqual(blocker_codes(report), set())
        check = report["repos"][0]["checks"][0]
        self.assertEqual(check["action"], "ensure_branch")
        self.assertEqual(check["target_resolution"], "reuse_existing")
        self.assertTrue(check["requires_user_confirmation"])
        self.assertIsNotNone(check["target"]["remote_sha"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
