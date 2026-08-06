#!/usr/bin/env python3
"""Contract tests for the repository validation workflow."""

from __future__ import annotations

import unittest
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/test.yml"


class GitHubWorkflowContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow = yaml.load(
            WORKFLOW.read_text(encoding="utf-8"), Loader=yaml.BaseLoader
        )

    def test_push_validation_runs_only_on_main(self) -> None:
        triggers = self.workflow["on"]
        self.assertEqual(triggers["push"]["branches"], ["main"])
        self.assertIn("pull_request", triggers)

    def test_duplicate_runs_are_cancelled_per_pull_request(self) -> None:
        concurrency = self.workflow["concurrency"]
        self.assertIn("github.event.pull_request.number", concurrency["group"])
        self.assertEqual(concurrency["cancel-in-progress"], "true")

    def test_validation_installs_required_python_dependencies(self) -> None:
        steps = self.workflow["jobs"]["validate"]["steps"]
        install_step = next(step for step in steps if step.get("name") == "Install dependencies")
        install_command = install_step["run"]
        for dependency in ("pyyaml", "jsonschema", "defusedxml"):
            self.assertIn(dependency, install_command)

    def test_validate_job_runs_full_gate(self) -> None:
        steps = self.workflow["jobs"]["validate"]["steps"]
        test_step = next(step for step in steps if step.get("name") == "Run tests")
        self.assertIn("bash tests/run-all.sh", test_step["run"])


if __name__ == "__main__":
    unittest.main()
