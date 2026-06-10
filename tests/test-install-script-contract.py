#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def extract_shell_function(script: str, name: str) -> str:
    marker = f"{name}() {{"
    start = script.index(marker)
    lines = script[start:].splitlines()
    body: list[str] = []
    for line in lines:
        body.append(line)
        if len(body) > 1 and line == "}":
            return "\n".join(body)
    raise AssertionError(f"function not closed: {name}")


class InstallScriptContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.script = (ROOT / "install.sh").read_text(encoding="utf-8")
        self.uninstall_target = extract_shell_function(self.script, "uninstall_target")

    def test_uninstall_precomputes_restore_plans_instead_of_per_path_lookups(
        self,
    ) -> None:
        self.assertIn("manifest_restore_plan", self.uninstall_target)
        self.assertIn("pruned_restore_plan", self.uninstall_target)
        self.assertIn("backup_only_restore_plan", self.uninstall_target)

        disallowed_patterns = (
            "awk -F '\\t' -v key=\"$dst\" '$1==key {print $2; exit}' \"$backup_manifest\"",
            "is_in_manifest \"$manifest\" \"$dst\" && continue",
            "is_in_manifest \"$pruned_manifest\" \"$dst\" && continue",
        )
        for pattern in disallowed_patterns:
            self.assertNotIn(pattern, self.uninstall_target)

    def test_uninstall_restore_plan_awk_does_not_depend_on_nonempty_first_file(
        self,
    ) -> None:
        self.assertNotIn("NR==FNR { backup[$1]=$2; next }", self.uninstall_target)
        self.assertNotIn("NR==FNR { managed[$0]=1; next }", self.uninstall_target)
        self.assertIn("FILENAME == ARGV[1]", self.uninstall_target)

    def test_uninstall_loop_avoids_per_path_dirname_processes(self) -> None:
        self.assertNotIn('$(dirname "$dst")', self.uninstall_target)


if __name__ == "__main__":
    unittest.main(verbosity=2)
