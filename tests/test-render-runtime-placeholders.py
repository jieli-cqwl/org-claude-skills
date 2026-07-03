from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "community" / "render_runtime_placeholders.py"


class RuntimePlaceholderRendererTests(unittest.TestCase):
    def run_renderer(self, tree: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                str(tree),
                "$HOME/.codex",
                "AGENTS.md",
                "$HOME/.agents/skills",
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    def test_replaces_placeholders_in_supported_text_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "skills" / "sample" / "SKILL.md"
            target.parent.mkdir(parents=True)
            target.write_text(
                "runtime={{RUNTIME_HOME}}\nentry={{ENTRY_DOC}}\nskills={{SKILLS_HOME}}\n",
                encoding="utf-8",
            )

            proc = self.run_renderer(root)

            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertEqual(
                target.read_text(encoding="utf-8"),
                "runtime=$HOME/.codex\n"
                "entry=AGENTS.md\n"
                "skills=$HOME/.agents/skills\n",
            )

    def test_ignores_unsupported_extensions(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "data.bin"
            target.write_bytes(b"{{RUNTIME_HOME}}")

            proc = self.run_renderer(root)

            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertEqual(target.read_bytes(), b"{{RUNTIME_HOME}}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
