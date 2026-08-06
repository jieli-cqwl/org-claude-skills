#!/usr/bin/env python3
"""Behavioral contract for the branch-protection apply script."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools/github/apply-branch-protection.sh"


class GitHubBranchProtectionContractTests(unittest.TestCase):
    def run_apply(self) -> dict[str, object]:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            capture_path = tmp_path / "capture.json"
            fake_gh = tmp_path / "gh"
            fake_gh.write_text(
                """#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

Path(os.environ["GH_CAPTURE_PATH"]).write_text(
    json.dumps({"argv": sys.argv[1:], "stdin": sys.stdin.read()}),
    encoding="utf-8",
)
""",
                encoding="utf-8",
            )
            fake_gh.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = f"{tmp_path}{os.pathsep}{env['PATH']}"
            env["GH_CAPTURE_PATH"] = str(capture_path)

            result = subprocess.run(
                ["bash", str(SCRIPT), "acme", "widgets", "trunk"],
                cwd=ROOT,
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(capture_path.read_text(encoding="utf-8"))

    def test_targets_requested_branch_protection_endpoint(self) -> None:
        capture = self.run_apply()
        argv = capture["argv"]
        self.assertIn("repos/acme/widgets/branches/trunk/protection", argv)
        self.assertIn("PUT", argv)

    def test_requires_github_actions_validate_check(self) -> None:
        capture = self.run_apply()
        payload = json.loads(capture["stdin"])
        status_checks = payload["required_status_checks"]
        self.assertTrue(status_checks["strict"])
        self.assertNotIn("contexts", status_checks)
        self.assertEqual(
            status_checks["checks"],
            [{"context": "validate", "app_id": 15368}],
        )

    def test_requires_pr_without_impossible_solo_approval(self) -> None:
        capture = self.run_apply()
        payload = json.loads(capture["stdin"])
        reviews = payload["required_pull_request_reviews"]
        self.assertEqual(reviews["required_approving_review_count"], 0)
        self.assertFalse(reviews["require_last_push_approval"])

    def test_blocks_admin_bypass_and_destructive_pushes(self) -> None:
        capture = self.run_apply()
        payload = json.loads(capture["stdin"])
        self.assertTrue(payload["enforce_admins"])
        self.assertTrue(payload["required_linear_history"])
        self.assertTrue(payload["required_conversation_resolution"])
        self.assertFalse(payload["allow_force_pushes"])
        self.assertFalse(payload["allow_deletions"])


if __name__ == "__main__":
    unittest.main()
