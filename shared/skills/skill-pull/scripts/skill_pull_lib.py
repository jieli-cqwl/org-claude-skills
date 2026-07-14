#!/usr/bin/env python3
"""Shared helpers for the skill pull workflow.

This module owns source-lock parsing, candidate classification, command
execution wrappers, branch naming, and source-lock text updates. It avoids
depending on repository-global Python packages so the bundled skill can run in
the installed runtime with only Python and Git available.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Sequence


DEFAULT_TIMEOUT_SECONDS = 30
UPSTREAM_LOOKUP_TIMEOUT_SECONDS = 90
UPSTREAM_LOOKUP_RETRIES = 1
UPSTREAM_LOOKUP_MAX_WORKERS = 8
GIT_HTTP_LOW_SPEED_LIMIT = 1
GIT_HTTP_LOW_SPEED_TIME_SECONDS = 20
SOURCE_REQUIRED_PATHS = {
    "skills_sh_mattpocock_to_prd": "skills/engineering/to-prd/SKILL.md",
}
MANAGED_SOURCE_NAMES = (
    "anthropic_skills",
    "superpowers",
    "vercel_skills",
    "vercel_agent_browser",
    "alchaincyf_darwin_skill",
    "nextlevelbuilder_ui_ux_pro_max",
    "panniantong_agent_reach",
    "skills_sh_alirezarezvani_code_to_prd",
    "skills_sh_baoyu_markdown_to_html",
    "skills_sh_bb_browser",
    "skills_sh_github_prd",
    "skills_sh_github_prompt_optimizer",
    "skills_sh_graphify",
    "skills_sh_markdown_viewer_architecture",
    "skills_sh_humanizer_zh",
    "skills_sh_mattpocock_to_prd",
    "skills_sh_notebooklm",
    "skills_sh_othmanadi_planning_with_files",
    "skills_sh_self_improving_agent",
    "skills_sh_softaworks_mermaid_diagrams",
)
SOURCE_BLOCK_RE = re.compile(
    r"^  (?P<name>[A-Za-z0-9_]+):\n(?P<body>(?:^    .*(?:\n|$)|^      .*(?:\n|$))*)",
    flags=re.MULTILINE,
)


@dataclass(frozen=True)
class SourceLock:
    """One locked external source from community/SOURCES.yaml."""

    name: str
    repo: str
    ref: str
    captured_at: str


@dataclass(frozen=True)
class CandidateRef:
    """Candidate upstream ref for a locked source."""

    name: str
    ref: str
    source: str
    summary: str = ""
    blocker: str = ""


@dataclass(frozen=True)
class SourceStatus:
    """Comparison result between a source lock and an upstream candidate."""

    name: str
    status: str
    current_ref: str
    candidate_ref: str
    candidate_source: str
    summary: str = ""
    blocker: str = ""


def _field(body: str, key: str, source_name: str) -> str:
    """Read a scalar field from a simple source-lock block."""
    match = re.search(
        rf"^    {re.escape(key)}:\s*(?P<value>\S.+?)\s*$", body, flags=re.MULTILINE
    )
    if not match:
        raise ValueError(f"source {source_name} missing field: {key}")
    return match.group("value")


def load_source_locks(lock_path: Path) -> dict[str, SourceLock]:
    """Parse source locks needed by the skill-pull workflow.

    Failure means the source lock cannot be trusted, so callers must treat the
    update run as blocked instead of guessing a partial source list.
    """
    text = lock_path.read_text(encoding="utf-8")
    locks: dict[str, SourceLock] = {}
    for match in SOURCE_BLOCK_RE.finditer(text):
        name = match.group("name")
        body = match.group("body")
        locks[name] = SourceLock(
            name=name,
            repo=_field(body, "repo", name),
            ref=_field(body, "ref", name),
            captured_at=_field(body, "captured_at", name),
        )

    missing = [name for name in MANAGED_SOURCE_NAMES if name not in locks]
    if missing:
        raise ValueError(f"source lock missing managed sources: {', '.join(missing)}")
    return locks


def managed_locks(locks: dict[str, SourceLock]) -> dict[str, SourceLock]:
    """Return default managed runtime sources."""
    return {name: locks[name] for name in MANAGED_SOURCE_NAMES if name in locks}


def classify_candidates(
    locks: dict[str, SourceLock],
    candidates: dict[str, CandidateRef],
) -> list[SourceStatus]:
    """Compare managed source locks with upstream candidates."""
    statuses: list[SourceStatus] = []
    for name, lock in managed_locks(locks).items():
        candidate = candidates.get(name)
        if candidate is None:
            statuses.append(
                SourceStatus(
                    name=name,
                    status="blocked",
                    current_ref=lock.ref,
                    candidate_ref="",
                    candidate_source="missing",
                    blocker="candidate lookup missing",
                )
            )
            continue
        if candidate.blocker or not candidate.ref:
            statuses.append(
                SourceStatus(
                    name=name,
                    status="blocked",
                    current_ref=lock.ref,
                    candidate_ref=candidate.ref,
                    candidate_source=candidate.source,
                    summary=candidate.summary,
                    blocker=candidate.blocker or "candidate ref empty",
                )
            )
            continue
        status = "current" if candidate.ref == lock.ref else "update"
        statuses.append(
            SourceStatus(
                name=name,
                status=status,
                current_ref=lock.ref,
                candidate_ref=candidate.ref,
                candidate_source=candidate.source,
                summary=candidate.summary,
            )
        )
    return statuses


def run_command(
    cmd: Sequence[str],
    *,
    cwd: Path | None = None,
    timeout: int = DEFAULT_TIMEOUT_SECONDS,
) -> subprocess.CompletedProcess[str]:
    """Run an external command with timeout and captured output."""
    return subprocess.run(
        list(cmd),
        cwd=str(cwd) if cwd else None,
        check=False,
        text=True,
        capture_output=True,
        timeout=timeout,
    )


def _run_upstream_lookup_command(cmd: Sequence[str]) -> subprocess.CompletedProcess[str]:
    last_timeout: subprocess.TimeoutExpired | None = None
    for attempt in range(UPSTREAM_LOOKUP_RETRIES + 1):
        try:
            return run_command(
                cmd,
                timeout=UPSTREAM_LOOKUP_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired as exc:
            last_timeout = exc
            if attempt == UPSTREAM_LOOKUP_RETRIES:
                raise
    assert last_timeout is not None
    raise last_timeout


def _git_lookup_command(args: Sequence[str]) -> list[str]:
    return [
        "git",
        "-c",
        f"http.lowSpeedLimit={GIT_HTTP_LOW_SPEED_LIMIT}",
        "-c",
        f"http.lowSpeedTime={GIT_HTTP_LOW_SPEED_TIME_SECONDS}",
        *args,
    ]


def _git_ls_remote(repo: str, ref: str) -> str:
    """Resolve a remote ref to a commit hash using git."""
    result = _run_upstream_lookup_command(
        _git_lookup_command(["ls-remote", repo, ref])
    )
    if result.returncode != 0:
        raise RuntimeError(
            result.stderr.strip() or result.stdout.strip() or "git ls-remote failed"
        )
    first = result.stdout.strip().splitlines()[0] if result.stdout.strip() else ""
    if not first:
        raise RuntimeError(f"remote ref not found: {ref}")
    return first.split()[0]


def _release_tag_ref(repo: str, tag: str) -> str:
    """Resolve a release tag to the target commit hash."""
    result = _run_upstream_lookup_command(
        _git_lookup_command(
            ["ls-remote", repo, f"refs/tags/{tag}^{{}}", f"refs/tags/{tag}"]
        )
    )
    if result.returncode != 0:
        raise RuntimeError(
            result.stderr.strip()
            or result.stdout.strip()
            or "release tag lookup failed"
        )
    peeled = ""
    direct = ""
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        if parts[1] == f"refs/tags/{tag}^{{}}":
            peeled = parts[0]
        elif parts[1] == f"refs/tags/{tag}":
            direct = parts[0]
    ref = peeled or direct
    if not ref:
        raise RuntimeError(f"remote release tag not found: {tag}")
    return ref


def _default_branch_candidate(repo: str) -> tuple[str, str]:
    """Resolve the upstream default branch name and HEAD commit in one call."""
    result = _run_upstream_lookup_command(
        _git_lookup_command(["ls-remote", "--symref", repo, "HEAD"])
    )
    if result.returncode != 0:
        raise RuntimeError(
            result.stderr.strip()
            or result.stdout.strip()
            or "default branch lookup failed"
        )
    default_ref = ""
    head_ref = ""
    for line in result.stdout.splitlines():
        if line.startswith("ref: "):
            default_ref = line.split()[1]
            continue
        parts = line.split()
        if len(parts) >= 2 and parts[1] == "HEAD":
            head_ref = parts[0]
    if not default_ref:
        raise RuntimeError("default branch symref missing")
    if not head_ref:
        raise RuntimeError("default branch HEAD ref missing")
    return default_ref, head_ref


def _github_repo_match(repo: str) -> re.Match[str] | None:
    match = re.match(
        r"https://github\.com/(?P<owner>[A-Za-z0-9_.-]+)/(?P<repo>[A-Za-z0-9_.-]+?)(?:\.git)?$",
        repo,
    )
    return match


def _latest_release(repo: str) -> dict[str, Any] | None:
    """Fetch latest non-prerelease GitHub release metadata."""
    match = _github_repo_match(repo)
    if not match:
        return None
    url = f"https://api.github.com/repos/{match.group('owner')}/{match.group('repo')}/releases/latest"
    parsed = urllib.parse.urlparse(url)
    if (
        parsed.scheme != "https"
        or parsed.netloc != "api.github.com"
        or not parsed.path.startswith("/repos/")
    ):
        raise RuntimeError("unexpected GitHub releases API URL")
    request = urllib.request.Request(
        url, headers={"Accept": "application/vnd.github+json"}
    )
    last_error: BaseException | None = None
    for attempt in range(UPSTREAM_LOOKUP_RETRIES + 1):
        try:
            with urllib.request.urlopen(
                request, timeout=UPSTREAM_LOOKUP_TIMEOUT_SECONDS
            ) as response:  # nosec B310
                payload = json.loads(response.read().decode("utf-8"))
            break
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                return None
            raise RuntimeError(f"GitHub release lookup failed: HTTP {exc.code}") from exc
        except (TimeoutError, urllib.error.URLError) as exc:
            last_error = exc
            if attempt == UPSTREAM_LOOKUP_RETRIES:
                reason = getattr(exc, "reason", exc)
                raise RuntimeError(f"GitHub release lookup failed: {reason}") from exc
    else:
        raise RuntimeError(f"GitHub release lookup failed: {last_error}")
    if payload.get("prerelease"):
        return None
    return payload


def _github_path_exists(repo: str, ref: str, path: str) -> bool:
    """Check whether a GitHub repo ref contains a required source path."""
    match = _github_repo_match(repo)
    if not match:
        raise RuntimeError("required source path checks only support GitHub repos")
    encoded_path = urllib.parse.quote(path, safe="/")
    query = urllib.parse.urlencode({"ref": ref})
    url = (
        f"https://api.github.com/repos/{match.group('owner')}/{match.group('repo')}"
        f"/contents/{encoded_path}?{query}"
    )
    request = urllib.request.Request(
        url, headers={"Accept": "application/vnd.github+json"}
    )
    last_error: BaseException | None = None
    for attempt in range(UPSTREAM_LOOKUP_RETRIES + 1):
        try:
            with urllib.request.urlopen(
                request, timeout=UPSTREAM_LOOKUP_TIMEOUT_SECONDS
            ) as response:  # nosec B310
                response.read(1)
            return True
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                return False
            raise RuntimeError(f"GitHub path lookup failed: HTTP {exc.code}") from exc
        except (TimeoutError, urllib.error.URLError) as exc:
            last_error = exc
            if attempt == UPSTREAM_LOOKUP_RETRIES:
                reason = getattr(exc, "reason", exc)
                raise RuntimeError(f"GitHub path lookup failed: {reason}") from exc
    raise RuntimeError(f"GitHub path lookup failed: {last_error}")


def _enforce_required_source_path(
    lock: SourceLock, candidate: CandidateRef
) -> CandidateRef:
    required_path = SOURCE_REQUIRED_PATHS.get(lock.name)
    if not required_path:
        return candidate
    if _github_path_exists(lock.repo, candidate.ref, required_path):
        return candidate
    if _github_path_exists(lock.repo, lock.ref, required_path):
        return CandidateRef(
            name=lock.name,
            ref=lock.ref,
            source="current_contract",
            summary=(
                f"{candidate.summary or candidate.source} lacks {required_path}; "
                "kept locked ref"
            ),
        )
    return CandidateRef(
        name=lock.name,
        ref="",
        source="error",
        summary=candidate.summary,
        blocker=(
            f"candidate and locked refs both lack required source path: "
            f"{required_path}"
        ),
    )


def lookup_candidate(lock: SourceLock) -> CandidateRef:
    """Find the latest stable candidate for one GitHub source."""
    try:
        release = _latest_release(lock.repo)
        if release and release.get("tag_name"):
            tag = str(release["tag_name"])
            ref = _release_tag_ref(lock.repo, tag)
            return _enforce_required_source_path(
                lock,
                CandidateRef(name=lock.name, ref=ref, source="release", summary=tag),
            )
        default_ref, ref = _default_branch_candidate(lock.repo)
        return _enforce_required_source_path(
            lock,
            CandidateRef(
                name=lock.name, ref=ref, source="default_branch", summary=default_ref
            ),
        )
    except (RuntimeError, subprocess.TimeoutExpired) as exc:
        return CandidateRef(name=lock.name, ref="", source="error", blocker=str(exc))


def lookup_candidates(locks: dict[str, SourceLock]) -> dict[str, CandidateRef]:
    """Find latest stable candidates, reusing one upstream lookup per repo."""
    repo_to_lock: dict[str, SourceLock] = {}
    for lock in locks.values():
        repo_to_lock.setdefault(lock.repo, lock)

    by_repo: dict[str, CandidateRef] = {}
    max_workers = min(UPSTREAM_LOOKUP_MAX_WORKERS, len(repo_to_lock)) or 1
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_repo = {
            executor.submit(lookup_candidate, lock): repo
            for repo, lock in repo_to_lock.items()
        }
        for future in as_completed(future_to_repo):
            repo = future_to_repo[future]
            by_repo[repo] = future.result()

    candidates: dict[str, CandidateRef] = {}
    for name, lock in locks.items():
        candidate = by_repo.get(lock.repo)
        if candidate is None:
            raise RuntimeError(f"candidate lookup missing for repo: {lock.repo}")
        candidates[name] = CandidateRef(
            name=lock.name,
            ref=candidate.ref,
            source=candidate.source,
            summary=candidate.summary,
            blocker=candidate.blocker,
        )
    return candidates


def load_candidate_fixture(path: Path) -> dict[str, CandidateRef]:
    """Load deterministic candidate refs for tests and dry runs."""
    data = json.loads(path.read_text(encoding="utf-8"))
    items = data.get("candidates", data)
    return {
        name: CandidateRef(
            name=name, **{key: value for key, value in item.items() if key != "name"}
        )
        for name, item in items.items()
    }


def statuses_to_json(statuses: Sequence[SourceStatus]) -> list[dict[str, str]]:
    """Convert statuses to JSON-serializable dictionaries."""
    return [asdict(status) for status in statuses]


def load_statuses(path: Path) -> list[SourceStatus]:
    """Load source statuses from a JSON file written by check_candidates.py."""
    data = json.loads(path.read_text(encoding="utf-8"))
    items = data.get("statuses", data)
    return [SourceStatus(**item) for item in items]


def write_json(path: Path, payload: dict[str, Any]) -> None:
    """Write stable pretty JSON for script handoffs."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def build_arg_parser(description: str) -> argparse.ArgumentParser:
    """Create a parser with the common repo-root argument."""
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument(
        "--repo-root",
        default=".",
        help="Repository root. Defaults to current directory.",
    )
    return parser
