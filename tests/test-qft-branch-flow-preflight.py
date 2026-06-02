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
