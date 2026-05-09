#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


RUNTIME_HOME = Path(__file__).resolve().parents[2]
REGISTRY_FILE = RUNTIME_HOME / "hooks" / "registry.json"
STATE_DIR = Path(
    os.environ.get(
        "ORG_CODEX_ACTIVE_SKILLS_STATE_DIR",
        str(RUNTIME_HOME / "hooks" / "state" / "active-skills"),
    )
)
SKILL_PATTERN = re.compile(r"^[/$]([A-Za-z0-9-]+)(?:\s|$)")


def load_codex_support_map() -> dict[str, bool]:
    data = json.loads(REGISTRY_FILE.read_text(encoding="utf-8"))
    return {
        entry["skill"]: bool(entry.get("codex", {}).get("supported"))
        for entry in data.get("skill_completion_gates", [])
        if isinstance(entry.get("skill"), str)
    }


def state_file_for(session_id: str) -> Path:
    return STATE_DIR / f"{session_id}.json"


def main() -> int:
    payload = json.loads(sys.stdin.read() or "{}")
    session_id = payload.get("session_id") or payload.get("sessionId")
    prompt = (payload.get("prompt") or "").strip()
    if not session_id:
        return 0

    match = SKILL_PATTERN.match(prompt)
    if not match:
        return 0

    skill = match.group(1)
    state_file = state_file_for(session_id)

    support_map = load_codex_support_map()
    if support_map.get(skill) is not True:
        state_file.unlink(missing_ok=True)
        return 0

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state_file.write_text(
        json.dumps(
            {
                "session_id": session_id,
                "skill": skill,
                "prompt": prompt,
                "updated_at": datetime.now(timezone.utc).isoformat(),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
