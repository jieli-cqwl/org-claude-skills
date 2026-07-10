#!/usr/bin/env python3
"""Private durable storage for schema-2 Codex context snapshots."""

from __future__ import annotations

import errno
import hashlib
import hmac
import json
import math
import os
import re
import stat
import time
import uuid
from contextlib import ExitStack, contextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterator, Mapping

from codex_context_model import (
    RecoveryStatus,
    SCHEMA_VERSION,
    SnapshotValidationError,
    build_snapshot,
    canonical_json_bytes,
    verify_snapshot,
)


PRIMARY_NAME = "primary.json"
LATEST_CHECKPOINT_NAME = "checkpoint.latest.json"
PREVIOUS_CHECKPOINT_NAME = "checkpoint.previous.json"
PENDING_TURN_NAME = "pending-turn.json"
SESSION_LOCK_NAME = ".session.lock"
CLEANUP_LOCK_NAME = ".cleanup.lock"
LIFECYCLE_LOCK_NAME = ".lifecycle.lock"
CLEANUP_METADATA_NAME = "cleanup.meta.json"

_FULL_GENERATION_NAMES = {
    PRIMARY_NAME,
    LATEST_CHECKPOINT_NAME,
    PREVIOUS_CHECKPOINT_NAME,
}
_SESSION_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
_RESERVED_SESSION_IDS = frozenset({"cleanup.meta.json", "cleanup", "metadata"})
_WINDOWS_DEVICE_BASENAME_RE = re.compile(
    r"^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])$", re.IGNORECASE
)
_TEMP_NAME_RE = re.compile(
    r"^\.(?:primary\.json|pending-turn\.json|checkpoint\.(?:latest|previous)\.json)\.[0-9a-f]{32}\.tmp$"
)
_ROOT_TEMP_NAME_RE = re.compile(r"^\.cleanup\.meta\.json\.[0-9a-f]{32}\.tmp$")
_CHECKPOINT_FIELDS = {
    "schema_version",
    "session_id",
    "turn_id",
    "revision",
    "trigger",
    "sealed_at",
    "snapshot_sha256",
    "snapshot",
    "checkpoint_sha256",
}
_CLEANUP_FIELDS = {
    "schema_version",
    "last_cleanup_at",
    "deleted_sessions",
    "deleted_files",
    "deleted_bytes",
    "remaining_sessions",
    "remaining_bytes",
}
_MAX_JSON_BYTES = 256 * 1024
_MAX_PENDING_TURN_BYTES = 8 * 1024
_MAX_PENDING_PREVIEW_CHARS = 1024
_MAX_PENDING_REFERENCE_CHARS = 4096
_MAX_CLEANUP_METADATA_BYTES = 4 * 1024
_MAX_LOCK_BYTES = 1
_LOCK_POLL_SECONDS = 0.01
_EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_PENDING_TURN_FIELDS = {
    "schema_version",
    "kind",
    "session_id",
    "turn_id",
    "prompt_sha256",
    "prompt_preview",
    "transcript_path",
    "cwd",
    "base_revision",
    "created_at",
    "updated_at",
}

# Lock order is cleanup (cleanup only) -> lifecycle -> session; reversing it deadlocks.
# Per-session accounting includes directories, locks, generations, and exact temps.
# Root cleanup/lifecycle locks and cleanup metadata are fixed singleton overhead.


class StoreError(RuntimeError):
    """Raised when private state cannot be stored or inspected safely."""


class LockTimeout(StoreError):
    """Raised when an advisory lock remains held beyond its bounded timeout."""


class RevisionConflict(StoreError):
    """Raised when a compare-and-swap base revision is stale."""


class IntegrityError(StoreError):
    """Raised when managed state is malformed, unsafe, or contradictory."""


@dataclass(frozen=True)
class RetentionPolicy:
    inactive_days: int = 30
    max_inactive_sessions: int = 200
    max_total_bytes: int = 50 * 1024 * 1024
    max_full_generations: int = 3
    cleanup_interval_seconds: int = 24 * 60 * 60
    lock_timeout_seconds: float = 2.0

    def __post_init__(self) -> None:
        integer_limits = {
            "inactive_days": (self.inactive_days, 1, 3650),
            "max_inactive_sessions": (self.max_inactive_sessions, 1, 100_000),
            "max_total_bytes": (self.max_total_bytes, 1, 1024**4),
            "cleanup_interval_seconds": (
                self.cleanup_interval_seconds,
                1,
                7 * 24 * 60 * 60,
            ),
        }
        for name, (value, minimum, maximum) in integer_limits.items():
            if isinstance(value, bool) or not isinstance(value, int):
                raise StoreError(f"{name} must be an integer")
            if not minimum <= value <= maximum:
                raise StoreError(f"{name} must be between {minimum} and {maximum}")
        if (
            isinstance(self.max_full_generations, bool)
            or not isinstance(self.max_full_generations, int)
        ):
            raise StoreError("max_full_generations must be an integer")
        if self.max_full_generations != 3:
            raise StoreError("max_full_generations must equal the schema-2 limit of 3")
        timeout = self.lock_timeout_seconds
        if (
            isinstance(timeout, bool)
            or not isinstance(timeout, (int, float))
            or not math.isfinite(float(timeout))
            or not 0.01 <= float(timeout) <= 60.0
        ):
            raise StoreError("lock_timeout_seconds must be between 0.01 and 60")

    @classmethod
    def from_environment(
        cls, environ: Mapping[str, str] | None = None
    ) -> "RetentionPolicy":
        source = os.environ if environ is None else environ
        defaults = cls()
        integer_keys = {
            "inactive_days": "CODEX_CONTEXT_STORE_INACTIVE_DAYS",
            "max_inactive_sessions": "CODEX_CONTEXT_STORE_MAX_INACTIVE_SESSIONS",
            "max_total_bytes": "CODEX_CONTEXT_STORE_MAX_TOTAL_BYTES",
            "max_full_generations": "CODEX_CONTEXT_STORE_MAX_FULL_GENERATIONS",
            "cleanup_interval_seconds": "CODEX_CONTEXT_STORE_CLEANUP_INTERVAL_SECONDS",
        }
        values: dict[str, object] = {}
        for field, key in integer_keys.items():
            raw = source.get(key)
            if raw is None:
                values[field] = getattr(defaults, field)
                continue
            try:
                values[field] = int(raw, 10)
            except (TypeError, ValueError):
                raise StoreError(f"{key} must be a base-10 integer") from None
        timeout_key = "CODEX_CONTEXT_STORE_LOCK_TIMEOUT_SECONDS"
        raw_timeout = source.get(timeout_key)
        if raw_timeout is None:
            values["lock_timeout_seconds"] = defaults.lock_timeout_seconds
        else:
            try:
                values["lock_timeout_seconds"] = float(raw_timeout)
            except (TypeError, ValueError):
                raise StoreError(f"{timeout_key} must be a number") from None
        return cls(**values)


@dataclass(frozen=True)
class RecoveryPair:
    primary: dict[str, object] | None
    latest_checkpoint: dict[str, object] | None
    previous_checkpoint: dict[str, object] | None
    status: RecoveryStatus
    reason: str


@dataclass(frozen=True)
class CleanupResult:
    deleted_sessions: int
    deleted_files: int
    deleted_bytes: int
    remaining_sessions: int
    remaining_bytes: int
    skipped_active_session: bool


@dataclass
class _SessionRecord:
    session_id: str
    session_key: str
    directory: Path
    files: list[Path]
    updated_at: datetime
    total_bytes: int
    has_unrelated_content: bool


def _filesystem_session_key(
    session_id: object, *, platform_semantics: str | None = None
) -> str | None:
    semantics = os.name if platform_semantics is None else platform_semantics
    if semantics not in {"nt", "posix"}:
        raise StoreError("platform semantics must be 'nt' or 'posix'")
    if not isinstance(session_id, str) or _SESSION_ID_RE.fullmatch(session_id) is None:
        return None
    folded = session_id.casefold()
    basename = session_id.split(".", 1)[0]
    if (
        session_id.endswith(".")
        or folded in _RESERVED_SESSION_IDS
        or _WINDOWS_DEVICE_BASENAME_RE.fullmatch(basename) is not None
    ):
        return None
    return folded if semantics == "nt" else session_id


def _session_id_matches_filesystem_key(
    session_id: object,
    session_key: object,
    *,
    platform_semantics: str | None = None,
) -> bool:
    return (
        isinstance(session_key, str)
        and _filesystem_session_key(
            session_id, platform_semantics=platform_semantics
        )
        == session_key
    )


def _is_owned_session_id(
    session_id: object, *, platform_semantics: str | None = None
) -> bool:
    return (
        _filesystem_session_key(
            session_id, platform_semantics=platform_semantics
        )
        is not None
    )


def _validate_session_id(
    session_id: object, *, platform_semantics: str | None = None
) -> str:
    if not isinstance(session_id, str) or not _SESSION_ID_RE.fullmatch(session_id):
        raise StoreError("session_id must use 1-128 safe ASCII identifier characters")
    if not _is_owned_session_id(
        session_id, platform_semantics=platform_semantics
    ):
        raise StoreError("session_id is reserved or not portable across filesystems")
    return session_id


def _enforce_directory_mode(path: Path, info: os.stat_result) -> None:
    if os.name != "posix" or stat.S_IMODE(info.st_mode) == 0o700:
        return
    chmod = getattr(os, "chmod", None)
    if not callable(chmod):
        raise StoreError("cannot enforce private directory permissions")
    try:
        supports_follow = chmod in getattr(os, "supports_follow_symlinks", set())
        if supports_follow:
            chmod(path, 0o700, follow_symlinks=False)
        else:
            chmod(path, 0o700)
    except (NotImplementedError, OSError) as exc:
        raise StoreError(f"cannot enforce private directory permissions: {exc}") from None


def _enforce_descriptor_mode(descriptor: int, mode: int) -> None:
    if os.name != "posix":
        return
    fchmod = getattr(os, "fchmod", None)
    if callable(fchmod):
        fchmod(descriptor, mode)
        return
    if stat.S_IMODE(os.fstat(descriptor).st_mode) != mode:
        raise OSError(errno.ENOTSUP, "descriptor permission enforcement is unavailable")


def _ensure_private_directory(path: Path) -> None:
    if path.is_symlink():
        raise StoreError("state directory must not be a symlink")
    try:
        path.mkdir(mode=0o700, parents=True, exist_ok=True)
        info = path.stat(follow_symlinks=False)
    except OSError as exc:
        raise StoreError(f"cannot prepare private state directory: {exc.strerror or exc}") from None
    if not stat.S_ISDIR(info.st_mode):
        raise StoreError("state directory is not a directory")
    if os.name == "posix" and info.st_uid != os.geteuid():
        raise StoreError("state directory is not owned by the current user")
    _enforce_directory_mode(path, info)


def _validate_owned_file_info(info: os.stat_result, *, descriptor: bool = False) -> None:
    if (not descriptor and stat.S_ISLNK(info.st_mode)) or not stat.S_ISREG(info.st_mode):
        raise IntegrityError("managed path is not a regular non-symlink file")
    if info.st_nlink != 1:
        raise IntegrityError("managed file has an ambiguous hard-link owner")
    if os.name == "posix" and info.st_uid != os.geteuid():
        raise IntegrityError("managed file is not owned by the current user")
    if os.name == "posix" and stat.S_IMODE(info.st_mode) != 0o600:
        raise IntegrityError("managed file permissions are not private")


def _same_file_identity(left: os.stat_result, right: os.stat_result) -> bool:
    return (left.st_dev, left.st_ino) == (right.st_dev, right.st_ino)


def _check_owned_file(path: Path, *, allow_missing: bool = True) -> os.stat_result | None:
    try:
        info = path.lstat()
    except FileNotFoundError:
        if allow_missing:
            return None
        raise IntegrityError("managed file is missing") from None
    except OSError as exc:
        raise IntegrityError(f"cannot inspect managed file: {exc.strerror or exc}") from None
    _validate_owned_file_info(info)
    return info


def _managed_path_present(path: Path) -> bool:
    try:
        info = path.lstat()
    except FileNotFoundError:
        return False
    except OSError as exc:
        raise IntegrityError(f"cannot inspect managed path: {exc.strerror or exc}") from None
    if stat.S_ISLNK(info.st_mode):
        raise IntegrityError("managed path must not be a symlink")
    return True


def _safe_open_lock(path: Path) -> int:
    flags = os.O_RDWR | os.O_CREAT
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor: int | None = None
    try:
        before = _check_owned_file(path)
        descriptor = os.open(path, flags, 0o600)
        info = os.fstat(descriptor)
        _enforce_descriptor_mode(descriptor, 0o600)
        info = os.fstat(descriptor)
        _validate_owned_file_info(info, descriptor=True)
        if info.st_size > _MAX_LOCK_BYTES:
            raise IntegrityError("lock file exceeds fixed control-plane overhead")
        after = _check_owned_file(path, allow_missing=False)
        assert after is not None
        if not _same_file_identity(info, after) or (
            before is not None and not _same_file_identity(before, info)
        ):
            raise IntegrityError("lock path changed while it was being opened")
        if os.name == "nt" and info.st_size == 0:
            os.write(descriptor, b"\0")
            os.fsync(descriptor)
        return descriptor
    except IntegrityError:
        if descriptor is not None:
            os.close(descriptor)
        raise
    except OSError:
        if descriptor is not None:
            os.close(descriptor)
        raise StoreError("cannot open advisory lock safely") from None


def _try_lock(descriptor: int) -> bool:
    if os.name == "nt":
        import msvcrt

        try:
            os.lseek(descriptor, 0, os.SEEK_SET)
            msvcrt.locking(descriptor, msvcrt.LK_NBLCK, 1)
            return True
        except OSError as exc:
            if exc.errno in {errno.EACCES, errno.EAGAIN, errno.EDEADLK}:
                return False
            raise
    import fcntl

    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return True
    except BlockingIOError:
        return False


def _unlock(descriptor: int) -> None:
    if os.name == "nt":
        import msvcrt

        os.lseek(descriptor, 0, os.SEEK_SET)
        msvcrt.locking(descriptor, msvcrt.LK_UNLCK, 1)
        return
    import fcntl

    fcntl.flock(descriptor, fcntl.LOCK_UN)


def _acquire_bounded_lock(path: Path, timeout_seconds: float) -> int:
    descriptor = _safe_open_lock(path)
    deadline = time.monotonic() + timeout_seconds
    try:
        while True:
            try:
                acquired = _try_lock(descriptor)
            except OSError as exc:
                raise StoreError(f"advisory lock failed: {exc.strerror or exc}") from None
            if acquired:
                return descriptor
            if time.monotonic() >= deadline:
                raise LockTimeout(f"advisory lock timed out after {timeout_seconds:g} seconds")
            time.sleep(min(_LOCK_POLL_SECONDS, max(0.0, deadline - time.monotonic())))
    except BaseException:
        os.close(descriptor)
        raise


def _release_lock(descriptor: int) -> None:
    unlock_error: OSError | None = None
    close_error: OSError | None = None
    try:
        _unlock(descriptor)
    except OSError as exc:
        unlock_error = exc
    try:
        os.close(descriptor)
    except OSError as exc:
        close_error = exc
    if unlock_error is not None:
        raise StoreError(
            f"advisory unlock failed: {unlock_error.strerror or unlock_error}"
        ) from None
    if close_error is not None:
        raise StoreError(
            f"advisory lock close failed: {close_error.strerror or close_error}"
        ) from None


@contextmanager
def _held_lock_descriptor(descriptor: int) -> Iterator[None]:
    body_error: BaseException | None = None
    try:
        yield
    except BaseException as exc:
        body_error = exc
        raise
    finally:
        try:
            _release_lock(descriptor)
        except StoreError:
            if body_error is None:
                raise


@contextmanager
def _bounded_lock(path: Path, timeout_seconds: float) -> Iterator[None]:
    descriptor = _acquire_bounded_lock(path, timeout_seconds)
    with _held_lock_descriptor(descriptor):
        yield


def _fsync_directory(directory: Path) -> None:
    if os.name == "nt":
        return
    flags = os.O_RDONLY
    if hasattr(os, "O_DIRECTORY"):
        flags |= os.O_DIRECTORY
    try:
        descriptor = os.open(directory, flags)
    except OSError as exc:
        if exc.errno in {errno.EINVAL, errno.ENOTSUP, errno.EOPNOTSUPP}:
            return
        raise StoreError(f"cannot open state directory for fsync: {exc.strerror or exc}") from None
    try:
        os.fsync(descriptor)
    except OSError as exc:
        if exc.errno not in {errno.EINVAL, errno.ENOTSUP, errno.EOPNOTSUPP}:
            raise StoreError(f"cannot fsync state directory: {exc.strerror or exc}") from None
    finally:
        os.close(descriptor)


def _cleanup_temp_after_failure(
    temp_path: Path, original: BaseException, operation: str
) -> None:
    try:
        temp_path.unlink()
    except FileNotFoundError:
        return
    except OSError as cleanup_error:
        raise StoreError(
            f"{operation}: {original}; temporary cleanup failed: {cleanup_error}"
        ) from None


def _prepare_temp(directory: Path, target_name: str, content: bytes) -> Path:
    temp_path = directory / f".{target_name}.{uuid.uuid4().hex}.tmp"
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor: int | None = None
    try:
        descriptor = os.open(temp_path, flags, 0o600)
        _enforce_descriptor_mode(descriptor, 0o600)
        with os.fdopen(descriptor, "wb") as stream:
            descriptor = None
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        return temp_path
    except (OSError, ValueError) as exc:
        if descriptor is not None:
            os.close(descriptor)
        _cleanup_temp_after_failure(temp_path, exc, "durable temporary write failed")
        raise StoreError(f"durable temporary write failed: {exc}") from None


def _publish_temp(temp_path: Path, target_path: Path) -> None:
    try:
        _check_owned_file(target_path)
        os.replace(temp_path, target_path)
        _fsync_directory(target_path.parent)
    except (OSError, StoreError, IntegrityError) as exc:
        _cleanup_temp_after_failure(temp_path, exc, "atomic state publish failed")
        if isinstance(exc, (StoreError, IntegrityError)):
            raise
        raise StoreError(f"atomic state publish failed: {exc.strerror or exc}") from None


def _read_json(path: Path, kind: str) -> object | None:
    before = _check_owned_file(path)
    if before is None:
        return None
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor: int | None = None
    try:
        descriptor = os.open(path, flags)
        descriptor_info = os.fstat(descriptor)
        _validate_owned_file_info(descriptor_info, descriptor=True)
        after = _check_owned_file(path, allow_missing=False)
        assert after is not None
        if not (
            _same_file_identity(before, descriptor_info)
            and _same_file_identity(descriptor_info, after)
        ):
            raise IntegrityError(f"{kind} changed while it was being opened")
        with os.fdopen(descriptor, "rb") as stream:
            descriptor = None
            content = stream.read(_MAX_JSON_BYTES + 1)
    except OSError as exc:
        raise IntegrityError(f"cannot read {kind}: {exc.strerror or exc}") from None
    finally:
        if descriptor is not None:
            os.close(descriptor)
    if len(content) > _MAX_JSON_BYTES:
        raise IntegrityError(f"{kind} exceeds the managed size limit")
    try:
        value = json.loads(content.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError):
        raise IntegrityError(f"{kind} is not canonical UTF-8 JSON") from None
    try:
        canonical = canonical_json_bytes(value)
    except (TypeError, ValueError, UnicodeError, RecursionError):
        raise IntegrityError(f"{kind} is not canonical UTF-8 JSON") from None
    if content != canonical:
        raise IntegrityError(f"{kind} bytes are not canonical JSON")
    return value


def _utc_now_text() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace(
        "+00:00", "Z"
    )


def _parse_utc_timestamp(value: object) -> datetime | None:
    if not isinstance(value, str) or not value.endswith("Z"):
        return None
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return None
    return parsed.astimezone(timezone.utc)


def _validate_snapshot_timestamps(snapshot: Mapping[str, object], kind: str) -> None:
    created_at = _parse_utc_timestamp(snapshot.get("created_at"))
    updated_at = _parse_utc_timestamp(snapshot.get("updated_at"))
    if created_at is None or updated_at is None or created_at > updated_at:
        raise IntegrityError(f"{kind} snapshot timestamps are invalid")


def _validate_pending_text(
    value: object,
    field: str,
    *,
    maximum: int,
    allow_empty: bool = False,
) -> str:
    if not isinstance(value, str):
        raise IntegrityError(f"pending turn {field} must be a string")
    if not allow_empty and not value.strip():
        raise IntegrityError(f"pending turn {field} must not be empty")
    if len(value) > maximum:
        raise IntegrityError(f"pending turn {field} exceeds its bounded size")
    if any(ord(character) < 0x20 or 0xD800 <= ord(character) <= 0xDFFF for character in value):
        raise IntegrityError(f"pending turn {field} contains invalid characters")
    return value


def _verify_pending_turn(value: object, session_id: str) -> dict[str, object]:
    if not isinstance(value, dict) or set(value) != _PENDING_TURN_FIELDS:
        raise IntegrityError("pending turn fields are invalid")
    if value.get("schema_version") != SCHEMA_VERSION or value.get("kind") != "pending_turn":
        raise IntegrityError("pending turn schema is invalid")
    if value.get("session_id") != session_id:
        raise IntegrityError("pending turn session does not match its store")
    _validate_pending_text(value.get("turn_id"), "turn_id", maximum=512)
    prompt_sha256 = value.get("prompt_sha256")
    if not isinstance(prompt_sha256, str) or _SHA256_RE.fullmatch(prompt_sha256) is None:
        raise IntegrityError("pending turn prompt hash is invalid")
    _validate_pending_text(
        value.get("prompt_preview"),
        "prompt_preview",
        maximum=_MAX_PENDING_PREVIEW_CHARS,
        allow_empty=True,
    )
    _validate_pending_text(
        value.get("transcript_path"),
        "transcript_path",
        maximum=_MAX_PENDING_REFERENCE_CHARS,
    )
    cwd = _validate_pending_text(
        value.get("cwd"), "cwd", maximum=_MAX_PENDING_REFERENCE_CHARS
    )
    if not Path(cwd).is_absolute() or str(Path(cwd).resolve()) != cwd:
        raise IntegrityError("pending turn cwd must be canonical and absolute")
    base_revision = value.get("base_revision")
    if (
        isinstance(base_revision, bool)
        or not isinstance(base_revision, int)
        or base_revision < 0
    ):
        raise IntegrityError("pending turn base revision is invalid")
    created_at = _parse_utc_timestamp(value.get("created_at"))
    updated_at = _parse_utc_timestamp(value.get("updated_at"))
    if created_at is None or updated_at is None or created_at > updated_at:
        raise IntegrityError("pending turn timestamps are invalid")
    try:
        serialized = canonical_json_bytes(value)
    except (TypeError, ValueError, UnicodeError, RecursionError):
        raise IntegrityError("pending turn is not canonical JSON") from None
    if len(serialized) > _MAX_PENDING_TURN_BYTES:
        raise IntegrityError("pending turn exceeds its bounded size")
    return dict(value)


def _checkpoint_hash(checkpoint: dict[str, object]) -> str:
    hashed = {
        key: value for key, value in checkpoint.items() if key != "checkpoint_sha256"
    }
    return hashlib.sha256(canonical_json_bytes(hashed)).hexdigest()


def _build_checkpoint(
    snapshot: dict[str, object], trigger: str, sealed_at: str
) -> dict[str, object]:
    checkpoint: dict[str, object] = {
        "schema_version": "2.0",
        "session_id": snapshot["session_id"],
        "turn_id": snapshot["turn_id"],
        "revision": snapshot["revision"],
        "trigger": trigger,
        "sealed_at": sealed_at,
        "snapshot_sha256": snapshot["snapshot_sha256"],
        "snapshot": snapshot,
    }
    checkpoint["checkpoint_sha256"] = _checkpoint_hash(checkpoint)
    return checkpoint


def _verify_checkpoint(value: object, session_id: str) -> dict[str, object]:
    if not isinstance(value, dict) or set(value) != _CHECKPOINT_FIELDS:
        raise IntegrityError("checkpoint fields do not match schema 2")
    if value.get("schema_version") != "2.0":
        raise IntegrityError("checkpoint schema_version is not 2.0")
    if value.get("session_id") != session_id:
        raise IntegrityError("checkpoint session does not match its store")
    if not isinstance(value.get("trigger"), str) or not value["trigger"].strip():
        raise IntegrityError("checkpoint trigger is invalid")
    if _parse_utc_timestamp(value.get("sealed_at")) is None:
        raise IntegrityError("checkpoint seal timestamp is invalid")
    digest = value.get("checkpoint_sha256")
    if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise IntegrityError("checkpoint hash is invalid")
    try:
        expected = _checkpoint_hash(value)
    except (TypeError, ValueError, UnicodeError, RecursionError):
        raise IntegrityError("checkpoint is not canonical JSON") from None
    if not hmac.compare_digest(digest, expected):
        raise IntegrityError("checkpoint hash does not match canonical content")
    try:
        snapshot = verify_snapshot(value.get("snapshot"))
    except SnapshotValidationError as exc:
        raise IntegrityError(f"checkpoint snapshot is invalid: {exc}") from None
    _validate_snapshot_timestamps(snapshot, "checkpoint")
    for field in ("session_id", "turn_id", "revision", "snapshot_sha256"):
        if value.get(field) != snapshot.get(field):
            raise IntegrityError(f"checkpoint {field} contradicts its snapshot")
    return dict(value)


class SessionStore:
    """Own one session's locked snapshot and bounded checkpoint generations."""

    def __init__(
        self,
        root: Path,
        session_id: str,
        *,
        lock_timeout_seconds: float = 2.0,
        _platform_semantics: str | None = None,
    ) -> None:
        self.session_id = _validate_session_id(
            session_id, platform_semantics=_platform_semantics
        )
        self.session_key = _filesystem_session_key(
            self.session_id, platform_semantics=_platform_semantics
        )
        assert self.session_key is not None
        if (
            isinstance(lock_timeout_seconds, bool)
            or not isinstance(lock_timeout_seconds, (int, float))
            or not math.isfinite(float(lock_timeout_seconds))
            or float(lock_timeout_seconds) <= 0
        ):
            raise StoreError("lock timeout must be a positive finite number")
        self.lock_timeout_seconds = float(lock_timeout_seconds)
        self.root = Path(root)
        _ensure_private_directory(self.root)
        self.session_dir = self.root / self.session_key
        if self.session_dir.parent.resolve() != self.root.resolve():
            raise StoreError("session path escapes the state root")
        self.primary_path = self.session_dir / PRIMARY_NAME
        self.latest_checkpoint_path = self.session_dir / LATEST_CHECKPOINT_NAME
        self.previous_checkpoint_path = self.session_dir / PREVIOUS_CHECKPOINT_NAME
        self.pending_turn_path = self.session_dir / PENDING_TURN_NAME
        self.lock_path = self.session_dir / SESSION_LOCK_NAME
        self.lifecycle_lock_path = self.root / LIFECYCLE_LOCK_NAME
        with _bounded_lock(self.lifecycle_lock_path, self.lock_timeout_seconds):
            _ensure_private_directory(self.session_dir)
            with _bounded_lock(self.lock_path, self.lock_timeout_seconds):
                self._assert_stored_session_identity()

    def _assert_stored_session_identity(self) -> None:
        for path, label in (
            (self.primary_path, "primary snapshot"),
            (self.latest_checkpoint_path, "latest checkpoint"),
            (self.previous_checkpoint_path, "previous checkpoint"),
            (self.pending_turn_path, "pending turn"),
        ):
            value = _read_json(path, label)
            if value is not None and isinstance(value, dict):
                if value.get("session_id") != self.session_id:
                    raise IntegrityError(
                        "stored session identity does not match the session store"
                    )

    @contextmanager
    def _locked(self, *, timeout_seconds: float | None = None) -> Iterator[None]:
        timeout = self.lock_timeout_seconds if timeout_seconds is None else timeout_seconds
        with ExitStack() as session_cleanup:
            with _bounded_lock(self.lifecycle_lock_path, float(timeout)):
                _ensure_private_directory(self.session_dir)
                session_descriptor = _acquire_bounded_lock(
                    self.lock_path, float(timeout)
                )
                # Register before lifecycle release so either handoff failure closes it.
                session_cleanup.enter_context(
                    _held_lock_descriptor(session_descriptor)
                )
            yield

    def _load_primary_unlocked(self) -> dict[str, object] | None:
        value = _read_json(self.primary_path, "primary snapshot")
        if value is None:
            return None
        try:
            snapshot = verify_snapshot(value)
        except SnapshotValidationError as exc:
            raise IntegrityError(f"primary snapshot is invalid: {exc}") from None
        if snapshot["session_id"] != self.session_id:
            raise IntegrityError("primary snapshot session does not match its store")
        _validate_snapshot_timestamps(snapshot, "primary")
        return snapshot

    def _load_checkpoint_unlocked(self, path: Path, label: str) -> dict[str, object] | None:
        value = _read_json(path, label)
        if value is None:
            return None
        return _verify_checkpoint(value, self.session_id)

    def _load_pending_turn_unlocked(self) -> dict[str, object] | None:
        value = _read_json(self.pending_turn_path, "pending turn")
        if value is None:
            return None
        return _verify_pending_turn(value, self.session_id)

    def load_pending_turn(self) -> dict[str, object] | None:
        with self._locked():
            return self._load_pending_turn_unlocked()

    def record_pending_turn(
        self,
        *,
        turn_id: str,
        prompt_sha256: str,
        prompt_preview: str,
        transcript_path: str,
        cwd: str,
    ) -> dict[str, object]:
        now = _utc_now_text()
        with self._locked():
            current = self._load_primary_unlocked()
            candidate: dict[str, object] = {
                "schema_version": SCHEMA_VERSION,
                "kind": "pending_turn",
                "session_id": self.session_id,
                "turn_id": turn_id,
                "prompt_sha256": prompt_sha256,
                "prompt_preview": prompt_preview,
                "transcript_path": transcript_path,
                "cwd": cwd,
                "base_revision": 0 if current is None else current["revision"],
                "created_at": now,
                "updated_at": now,
            }
            verified = _verify_pending_turn(candidate, self.session_id)
            temp_path = _prepare_temp(
                self.session_dir,
                PENDING_TURN_NAME,
                canonical_json_bytes(verified),
            )
            try:
                temporary = _read_json(temp_path, "temporary pending turn")
                if _verify_pending_turn(temporary, self.session_id) != verified:
                    raise IntegrityError(
                        "temporary pending turn differs from its candidate"
                    )
                _publish_temp(temp_path, self.pending_turn_path)
                published = self._load_pending_turn_unlocked()
            except (IntegrityError, StoreError) as exc:
                _cleanup_temp_after_failure(
                    temp_path, exc, "pending turn candidate processing failed"
                )
                raise
            if published != verified:
                raise IntegrityError(
                    "published pending turn differs from the verified candidate"
                )
            return verified

    def load_primary(self) -> dict[str, object] | None:
        with self._locked():
            return self._load_primary_unlocked()

    def commit_snapshot(
        self,
        task: object,
        runtime: object,
        base_revision: int,
        *,
        expected_pending: object | None = None,
    ) -> dict[str, object]:
        if isinstance(base_revision, bool) or not isinstance(base_revision, int) or base_revision < 0:
            raise RevisionConflict("base revision must be a non-negative integer")
        if not isinstance(runtime, dict) or runtime.get("session_id") != self.session_id:
            raise StoreError("runtime session does not match the session store")
        runtime_base_revision = runtime.get("base_revision")
        if (
            isinstance(runtime_base_revision, bool)
            or not isinstance(runtime_base_revision, int)
            or runtime_base_revision != base_revision
        ):
            raise RevisionConflict(
                "revision conflict: "
                f"argument base_revision {base_revision}, runtime observed "
                f"{runtime_base_revision!r}"
            )
        with self._locked():
            if expected_pending is not None:
                expected = _verify_pending_turn(expected_pending, self.session_id)
                observed_pending = self._load_pending_turn_unlocked()
                if observed_pending != expected:
                    raise RevisionConflict(
                        "revision conflict: pending turn changed before snapshot commit"
                    )
            current = self._load_primary_unlocked()
            observed_revision = 0 if current is None else current["revision"]
            if base_revision != observed_revision:
                raise RevisionConflict(
                    f"revision conflict: expected {base_revision}, observed {observed_revision}"
                )
            runtime_values = dict(runtime)
            now = _utc_now_text()
            created_at = now if current is None else current["created_at"]
            try:
                snapshot = build_snapshot(
                    task,
                    runtime_values,
                    revision=base_revision + 1,
                    created_at=created_at,
                    updated_at=now,
                )
            except SnapshotValidationError as exc:
                raise StoreError(f"snapshot validation failed: {exc}") from None
            temp_path = _prepare_temp(
                self.session_dir, PRIMARY_NAME, canonical_json_bytes(snapshot)
            )
            try:
                candidate = _read_json(temp_path, "temporary primary snapshot")
                verify_snapshot(candidate)
                _publish_temp(temp_path, self.primary_path)
                published = self._load_primary_unlocked()
            except (IntegrityError, SnapshotValidationError, StoreError) as exc:
                _cleanup_temp_after_failure(
                    temp_path, exc, "primary candidate processing failed"
                )
                raise
            if published != snapshot:
                raise IntegrityError("published primary differs from the verified candidate")
            return published

    def seal_checkpoint(
        self, trigger: str, runtime: object
    ) -> dict[str, object]:
        if (
            not isinstance(trigger, str)
            or not trigger.strip()
            or len(trigger) > 64
            or any(0xD800 <= ord(character) <= 0xDFFF for character in trigger)
        ):
            raise StoreError("checkpoint trigger must be a non-empty string up to 64 characters")
        if not isinstance(runtime, dict):
            raise StoreError("checkpoint runtime must be an object")
        with self._locked():
            primary = self._load_primary_unlocked()
            if primary is None:
                raise IntegrityError("cannot seal a checkpoint without a primary snapshot")
            expected_runtime = {
                "session_id": primary["session_id"],
                "turn_id": primary["turn_id"],
                "base_revision": primary["base_revision"],
                "cwd": primary["cwd"],
                "git_head": primary["git_head"],
                "last_user_prompt_hash": primary["last_user_prompt_hash"],
            }
            if runtime != expected_runtime:
                raise IntegrityError("checkpoint runtime does not match the primary snapshot")
            try:
                checkpoint = _build_checkpoint(primary, trigger, _utc_now_text())
                checkpoint_bytes = canonical_json_bytes(checkpoint)
            except (TypeError, ValueError, UnicodeError, RecursionError):
                raise StoreError("checkpoint serialization failed") from None

            try:
                existing_latest = self._load_checkpoint_unlocked(
                    self.latest_checkpoint_path, "latest checkpoint"
                )
            except IntegrityError:
                existing_latest = None
            try:
                existing_previous = self._load_checkpoint_unlocked(
                    self.previous_checkpoint_path, "previous checkpoint"
                )
            except IntegrityError:
                existing_previous = None
            _check_owned_file(self.latest_checkpoint_path)
            _check_owned_file(self.previous_checkpoint_path)
            self._assert_generation_consistency(
                primary, existing_latest, existing_previous
            )

            try:
                temp_path = _prepare_temp(
                    self.session_dir,
                    LATEST_CHECKPOINT_NAME,
                    checkpoint_bytes,
                )
            except OSError as exc:
                raise StoreError(
                    f"cannot prepare checkpoint candidate: {exc.strerror or exc}"
                ) from None
            try:
                candidate = self._load_checkpoint_unlocked(
                    temp_path, "temporary checkpoint"
                )
                if candidate != checkpoint:
                    raise IntegrityError("temporary checkpoint differs from its candidate")

                if existing_latest is not None:
                    try:
                        os.replace(
                            self.latest_checkpoint_path, self.previous_checkpoint_path
                        )
                        _fsync_directory(self.session_dir)
                    except OSError as exc:
                        raise StoreError(
                            f"checkpoint fallback rotation failed: {exc.strerror or exc}"
                        ) from None
                _publish_temp(temp_path, self.latest_checkpoint_path)
                published = self._load_checkpoint_unlocked(
                    self.latest_checkpoint_path, "latest checkpoint"
                )
            except OSError as exc:
                _cleanup_temp_after_failure(
                    temp_path, exc, "checkpoint candidate processing failed"
                )
                raise StoreError(
                    f"checkpoint candidate processing failed: {exc.strerror or exc}"
                ) from None
            except (IntegrityError, StoreError) as exc:
                _cleanup_temp_after_failure(
                    temp_path, exc, "checkpoint candidate processing failed"
                )
                raise
            if published != checkpoint:
                raise IntegrityError("published checkpoint differs from verified candidate")
            return published

    @staticmethod
    def _assert_generation_consistency(
        primary: dict[str, object] | None,
        latest: dict[str, object] | None,
        previous: dict[str, object] | None,
    ) -> None:
        if latest is not None and previous is not None:
            if previous["revision"] > latest["revision"]:
                raise IntegrityError("previous checkpoint is newer than latest checkpoint")
            if (
                previous["revision"] == latest["revision"]
                and previous["snapshot_sha256"] != latest["snapshot_sha256"]
            ):
                raise IntegrityError("checkpoint generations contradict at one revision")
        reference = latest if latest is not None else previous
        if primary is None or reference is None:
            return
        if reference["revision"] > primary["revision"]:
            raise IntegrityError("checkpoint is newer than the primary snapshot")
        if (
            reference["revision"] == primary["revision"]
            and reference["snapshot_sha256"] != primary["snapshot_sha256"]
        ):
            raise IntegrityError("primary and checkpoint contradict at one revision")

    def load_recovery_pair(self) -> RecoveryPair:
        with self._locked():
            paths_exist = any(
                _managed_path_present(path)
                for path in (
                    self.primary_path,
                    self.latest_checkpoint_path,
                    self.previous_checkpoint_path,
                )
            )
            if not paths_exist:
                return RecoveryPair(
                    None,
                    None,
                    None,
                    RecoveryStatus.INCOMPLETE,
                    "no primary or checkpoint generation exists",
                )

            errors: list[str] = []
            primary: dict[str, object] | None = None
            latest: dict[str, object] | None = None
            previous: dict[str, object] | None = None
            try:
                primary = self._load_primary_unlocked()
            except IntegrityError as exc:
                errors.append(str(exc))
            try:
                latest = self._load_checkpoint_unlocked(
                    self.latest_checkpoint_path, "latest checkpoint"
                )
            except IntegrityError as exc:
                errors.append(str(exc))
            try:
                previous = self._load_checkpoint_unlocked(
                    self.previous_checkpoint_path, "previous checkpoint"
                )
            except IntegrityError as exc:
                errors.append(str(exc))

            self._assert_generation_consistency(primary, latest, previous)
            if errors:
                reason = "; ".join(errors)
                if primary is None and (latest is not None or previous is not None):
                    reason += "; a validated checkpoint can restore the primary"
                return RecoveryPair(
                    primary,
                    latest,
                    previous,
                    RecoveryStatus.CORRUPT,
                    reason,
                )
            if primary is None:
                return RecoveryPair(
                    None,
                    latest,
                    previous,
                    RecoveryStatus.INCOMPLETE,
                    "primary snapshot is missing; a checkpoint is available",
                )
            reference = latest if latest is not None else previous
            if reference is None:
                return RecoveryPair(
                    primary,
                    None,
                    None,
                    RecoveryStatus.INCOMPLETE,
                    "primary snapshot is valid but no checkpoint generation exists",
                )
            if reference["revision"] < primary["revision"]:
                return RecoveryPair(
                    primary,
                    latest,
                    previous,
                    RecoveryStatus.STALE,
                    "latest available checkpoint is older than the primary snapshot",
                )
            return RecoveryPair(
                primary,
                latest,
                previous,
                RecoveryStatus.READY,
                "primary snapshot and available checkpoint generations are valid",
            )

    def restore_primary(self, checkpoint: object) -> dict[str, object]:
        validated = _verify_checkpoint(checkpoint, self.session_id)
        snapshot = validated["snapshot"]
        assert isinstance(snapshot, dict)
        with self._locked():
            try:
                current = self._load_primary_unlocked()
            except IntegrityError:
                current = None
            if current is not None:
                if current["snapshot_sha256"] == snapshot["snapshot_sha256"]:
                    return current
                raise IntegrityError("valid primary contradicts the requested checkpoint")
            try:
                temp_path = _prepare_temp(
                    self.session_dir, PRIMARY_NAME, canonical_json_bytes(snapshot)
                )
            except OSError as exc:
                raise StoreError(
                    f"cannot prepare restored primary: {exc.strerror or exc}"
                ) from None
            try:
                verify_snapshot(_read_json(temp_path, "temporary restored primary"))
                _publish_temp(temp_path, self.primary_path)
                restored = self._load_primary_unlocked()
            except OSError as exc:
                _cleanup_temp_after_failure(
                    temp_path, exc, "restored primary candidate processing failed"
                )
                raise StoreError(
                    f"restored primary candidate processing failed: {exc.strerror or exc}"
                ) from None
            except (SnapshotValidationError, IntegrityError, StoreError) as exc:
                _cleanup_temp_after_failure(
                    temp_path, exc, "restored primary candidate processing failed"
                )
                raise
            if restored != snapshot:
                raise IntegrityError("restored primary differs from the checkpoint snapshot")
            return restored


def _is_owned_session_file_name(name: str) -> bool:
    return (
        name in _FULL_GENERATION_NAMES
        or name == PENDING_TURN_NAME
        or name == SESSION_LOCK_NAME
        or _TEMP_NAME_RE.fullmatch(name) is not None
    )


def _owned_session_files(directory: Path) -> list[Path]:
    files: list[Path] = []
    try:
        children = list(directory.iterdir())
    except OSError as exc:
        raise StoreError(f"cannot scan managed session: {exc.strerror or exc}") from None
    for path in children:
        if _is_owned_session_file_name(path.name):
            info = _check_owned_file(path, allow_missing=False)
            assert info is not None
            if path.name == SESSION_LOCK_NAME and info.st_size > _MAX_LOCK_BYTES:
                raise IntegrityError("lock file exceeds fixed control-plane overhead")
            files.append(path)
    return files


def _account_session_tree(
    directory: Path, owned_files: list[Path]
) -> tuple[int, bool]:
    try:
        total_bytes = directory.stat(follow_symlinks=False).st_size
    except OSError as exc:
        raise StoreError(
            f"cannot account managed session directory: {exc.strerror or exc}"
        ) from None
    owned_names = {path.name for path in owned_files}
    has_unrelated_content = False
    pending = [directory]
    while pending:
        current = pending.pop()
        try:
            entries = list(os.scandir(current))
        except OSError as exc:
            raise StoreError(
                f"cannot account managed session content: {exc.strerror or exc}"
            ) from None
        for entry in entries:
            try:
                info = entry.stat(follow_symlinks=False)
            except OSError as exc:
                raise StoreError(
                    f"cannot account managed session entry: {exc.strerror or exc}"
                ) from None
            total_bytes += info.st_size
            path = Path(entry.path)
            if current != directory or entry.name not in owned_names:
                has_unrelated_content = True
            if stat.S_ISDIR(info.st_mode):
                pending.append(path)
    return total_bytes, has_unrelated_content


def _record_timestamp(
    files: list[Path],
    session_key: str,
    *,
    platform_semantics: str | None = None,
) -> datetime:
    timestamps: list[datetime] = []
    invalid = False
    for path in files:
        if path.name == SESSION_LOCK_NAME:
            continue
        if _TEMP_NAME_RE.fullmatch(path.name):
            invalid = True
            continue
        try:
            value = _read_json(path, "retention generation")
            if path.name == PRIMARY_NAME:
                snapshot = verify_snapshot(value)
                if not _session_id_matches_filesystem_key(
                    snapshot["session_id"],
                    session_key,
                    platform_semantics=platform_semantics,
                ):
                    raise IntegrityError("retention primary belongs to another session")
                parsed = _parse_utc_timestamp(snapshot["updated_at"])
            elif path.name == PENDING_TURN_NAME:
                if not isinstance(value, dict) or not _session_id_matches_filesystem_key(
                    value.get("session_id"),
                    session_key,
                    platform_semantics=platform_semantics,
                ):
                    raise IntegrityError("retention pending turn belongs to another session")
                pending_session_id = value["session_id"]
                assert isinstance(pending_session_id, str)
                pending = _verify_pending_turn(value, pending_session_id)
                parsed = _parse_utc_timestamp(pending["updated_at"])
            else:
                if not isinstance(value, dict) or not _session_id_matches_filesystem_key(
                    value.get("session_id"),
                    session_key,
                    platform_semantics=platform_semantics,
                ):
                    raise IntegrityError("retention checkpoint belongs to another session")
                checkpoint_session_id = value["session_id"]
                assert isinstance(checkpoint_session_id, str)
                checkpoint = _verify_checkpoint(value, checkpoint_session_id)
                parsed = _parse_utc_timestamp(checkpoint["sealed_at"])
            if parsed is None:
                invalid = True
            else:
                timestamps.append(parsed)
        except (IntegrityError, SnapshotValidationError):
            invalid = True
    if invalid or not timestamps:
        return _EPOCH
    return max(timestamps)


def _scan_session_records(
    root: Path, *, platform_semantics: str | None = None
) -> list[_SessionRecord]:
    records: list[_SessionRecord] = []
    session_keys: set[str] = set()
    try:
        children = list(root.iterdir())
    except OSError as exc:
        raise StoreError(f"cannot scan state root: {exc.strerror or exc}") from None
    for directory in children:
        if not _is_owned_session_id(
            directory.name, platform_semantics=platform_semantics
        ):
            continue
        if directory.is_symlink():
            raise StoreError("session directory symlink makes retention ownership ambiguous")
        if not directory.is_dir():
            continue
        session_key = _filesystem_session_key(
            directory.name, platform_semantics=platform_semantics
        )
        assert session_key is not None
        if session_key in session_keys:
            raise StoreError("session directory filesystem aliases collide")
        session_keys.add(session_key)
        _ensure_private_directory(directory)
        files = _owned_session_files(directory)
        total_bytes, has_unrelated_content = _account_session_tree(directory, files)
        records.append(
            _SessionRecord(
                directory.name,
                session_key,
                directory,
                files,
                _record_timestamp(
                    files,
                    session_key,
                    platform_semantics=platform_semantics,
                ),
                total_bytes,
                has_unrelated_content,
            )
        )
    records.sort(
        key=lambda record: (record.updated_at, record.session_key, record.session_id)
    )
    return records


def _read_cleanup_metadata(path: Path) -> dict[str, object] | None:
    info = _check_owned_file(path)
    if info is not None and info.st_size > _MAX_CLEANUP_METADATA_BYTES:
        raise StoreError("cleanup metadata exceeds its bounded size")
    value = _read_json(path, "cleanup metadata")
    if value is None:
        return None
    if not isinstance(value, dict) or set(value) != _CLEANUP_FIELDS:
        raise StoreError("cleanup metadata fields are invalid")
    if value.get("schema_version") != 2 or _parse_utc_timestamp(
        value.get("last_cleanup_at")
    ) is None:
        raise StoreError("cleanup metadata content is invalid")
    for field in _CLEANUP_FIELDS - {"schema_version", "last_cleanup_at"}:
        field_value = value.get(field)
        if isinstance(field_value, bool) or not isinstance(field_value, int) or field_value < 0:
            raise StoreError("cleanup metadata counters are invalid")
    return dict(value)


def _delete_owned_root_temps(root: Path) -> tuple[int, int]:
    deleted_files = 0
    deleted_bytes = 0
    try:
        children = list(root.iterdir())
    except OSError as exc:
        raise StoreError(f"cannot scan state root: {exc.strerror or exc}") from None
    for path in children:
        if not _ROOT_TEMP_NAME_RE.fullmatch(path.name):
            continue
        info = _check_owned_file(path, allow_missing=False)
        assert info is not None
        try:
            path.unlink()
        except FileNotFoundError:
            continue
        except OSError as exc:
            raise StoreError(f"cannot delete abandoned root temp: {exc.strerror or exc}") from None
        deleted_files += 1
        deleted_bytes += info.st_size
    if deleted_files:
        _fsync_directory(root)
    return deleted_files, deleted_bytes


def _sweep_record_temps(
    root: Path, record: _SessionRecord, timeout_seconds: float
) -> tuple[int, int]:
    deleted_files = 0
    deleted_bytes = 0
    with ExitStack() as session_cleanup:
        with _bounded_lock(root / LIFECYCLE_LOCK_NAME, timeout_seconds):
            if not record.directory.exists():
                return 0, 0
            if record.directory.is_symlink() or not record.directory.is_dir():
                raise StoreError("temp sweep candidate is not a safe session directory")
            descriptor = _acquire_bounded_lock(
                record.directory / SESSION_LOCK_NAME, timeout_seconds
            )
            # The session descriptor must outlive lifecycle handoff on every exit.
            session_cleanup.enter_context(_held_lock_descriptor(descriptor))

        for path in _owned_session_files(record.directory):
            if _TEMP_NAME_RE.fullmatch(path.name) is None:
                continue
            info = _check_owned_file(path, allow_missing=False)
            assert info is not None
            try:
                path.unlink()
            except FileNotFoundError:
                continue
            except OSError as exc:
                raise StoreError(
                    f"cannot delete abandoned session temp: {exc.strerror or exc}"
                ) from None
            deleted_files += 1
            deleted_bytes += info.st_size
        if deleted_files:
            _fsync_directory(record.directory)
    return deleted_files, deleted_bytes


def _delete_record(
    root: Path, record: _SessionRecord, timeout_seconds: float
) -> tuple[int, int, bool]:
    lock_path = record.directory / SESSION_LOCK_NAME
    deleted_files = 0
    deleted_bytes = 0
    with _bounded_lock(root / LIFECYCLE_LOCK_NAME, timeout_seconds):
        if not record.directory.exists():
            return 0, 0, True
        if record.directory.is_symlink() or not record.directory.is_dir():
            raise StoreError("retention candidate is no longer a safe session directory")
        with ExitStack() as session_cleanup:
            session_descriptor = _acquire_bounded_lock(lock_path, timeout_seconds)
            session_cleanup.enter_context(_held_lock_descriptor(session_descriptor))
            try:
                lock_info = os.fstat(session_descriptor)
            except OSError as exc:
                raise StoreError(
                    f"cannot inspect retention lock: {exc.strerror or exc}"
                ) from None
            try:
                current_files = _owned_session_files(record.directory)
                unrelated = [
                    path
                    for path in record.directory.iterdir()
                    if not _is_owned_session_file_name(path.name)
                ]
                current_payload = [
                    path for path in current_files if path.name != SESSION_LOCK_NAME
                ]
                expected_payload = [
                    path for path in record.files if path.name != SESSION_LOCK_NAME
                ]
                current_sizes = {
                    path.name: path.stat(follow_symlinks=False).st_size
                    for path in current_payload
                }
                expected_sizes = {
                    path.name: path.stat(follow_symlinks=False).st_size
                    for path in expected_payload
                }
            except OSError as exc:
                raise StoreError(
                    f"cannot revalidate retention candidate: {exc.strerror or exc}"
                ) from None
            if unrelated:
                raise StoreError(
                    "cannot remove inactive session directory: unrelated files remain"
                )
            if (
                current_sizes != expected_sizes
                or _record_timestamp(current_payload, record.session_id)
                != record.updated_at
            ):
                raise StoreError("session changed while retention was selecting candidates")
            for path in current_payload:
                try:
                    size = path.stat(follow_symlinks=False).st_size
                    path.unlink()
                except FileNotFoundError:
                    continue
                except OSError as exc:
                    raise StoreError(
                        f"cannot delete managed generation: {exc.strerror or exc}"
                    ) from None
                deleted_files += 1
                deleted_bytes += size
            _fsync_directory(record.directory)

        current_lock = _check_owned_file(lock_path, allow_missing=False)
        assert current_lock is not None
        if not _same_file_identity(lock_info, current_lock):
            raise IntegrityError("session lock changed during lifecycle handoff")
        try:
            lock_path.unlink()
        except OSError as exc:
            raise StoreError(f"cannot delete inactive session lock: {exc.strerror or exc}") from None
        deleted_files += 1
        deleted_bytes += current_lock.st_size
        _fsync_directory(record.directory)

        try:
            if any(record.directory.iterdir()):
                return deleted_files, deleted_bytes, False
            directory_bytes = record.directory.stat(follow_symlinks=False).st_size
            record.directory.rmdir()
        except OSError as exc:
            raise StoreError(
                f"cannot remove inactive session directory: {exc.strerror or exc}"
            ) from None
        deleted_bytes += directory_bytes
        _fsync_directory(root)
        return deleted_files, deleted_bytes, True


def _cleanup_result(
    records: list[_SessionRecord],
    *,
    skipped_active_session: bool,
    deleted_files: int = 0,
    deleted_bytes: int = 0,
) -> CleanupResult:
    return CleanupResult(
        deleted_sessions=0,
        deleted_files=deleted_files,
        deleted_bytes=deleted_bytes,
        remaining_sessions=len(records),
        remaining_bytes=sum(record.total_bytes for record in records),
        skipped_active_session=skipped_active_session,
    )


def prune_state_root(
    root: Path,
    active_session_id: str,
    policy: RetentionPolicy,
    now: datetime,
) -> CleanupResult:
    """Apply age, inactive-session, and byte limits under a separate lock."""
    _validate_session_id(active_session_id)
    active_session_key = _filesystem_session_key(active_session_id)
    assert active_session_key is not None
    if not isinstance(policy, RetentionPolicy):
        raise StoreError("retention policy must be a validated RetentionPolicy")
    if not isinstance(now, datetime) or now.tzinfo is None:
        raise StoreError("cleanup time must be timezone-aware")
    now = now.astimezone(timezone.utc)
    root = Path(root)
    _ensure_private_directory(root)

    with _bounded_lock(root / CLEANUP_LOCK_NAME, policy.lock_timeout_seconds):
        metadata_path = root / CLEANUP_METADATA_NAME
        metadata_info = _check_owned_file(metadata_path)
        try:
            metadata = _read_cleanup_metadata(metadata_path)
        except (IntegrityError, StoreError):
            current_info = _check_owned_file(metadata_path, allow_missing=False)
            assert metadata_info is not None and current_info is not None
            if (current_info.st_dev, current_info.st_ino) != (
                metadata_info.st_dev,
                metadata_info.st_ino,
            ):
                raise IntegrityError("cleanup metadata changed during validation") from None
            metadata = None
        root_temp_files, root_temp_bytes = _delete_owned_root_temps(root)
        records = _scan_session_records(root)
        session_temp_files = 0
        session_temp_bytes = 0
        for record in records:
            file_count, byte_count = _sweep_record_temps(
                root, record, policy.lock_timeout_seconds
            )
            session_temp_files += file_count
            session_temp_bytes += byte_count
        records = _scan_session_records(root)
        active_present = any(
            record.session_key == active_session_key for record in records
        )
        if metadata is not None:
            last_cleanup = _parse_utc_timestamp(metadata["last_cleanup_at"])
            assert last_cleanup is not None
            elapsed = now - last_cleanup
            if timedelta(0) <= elapsed < timedelta(
                seconds=policy.cleanup_interval_seconds
            ):
                return _cleanup_result(
                    records,
                    skipped_active_session=active_present,
                    deleted_files=root_temp_files + session_temp_files,
                    deleted_bytes=root_temp_bytes + session_temp_bytes,
                )

        inactive = [
            record for record in records if record.session_key != active_session_key
        ]
        selected: list[_SessionRecord] = []
        selected_ids: set[str] = set()

        def select(record: _SessionRecord) -> None:
            if record.session_key not in selected_ids:
                selected.append(record)
                selected_ids.add(record.session_key)

        age_cutoff = now - timedelta(days=policy.inactive_days)
        for record in inactive:
            if record.updated_at < age_cutoff:
                select(record)

        remaining_inactive = [
            record for record in inactive if record.session_key not in selected_ids
        ]
        while len(remaining_inactive) > policy.max_inactive_sessions:
            select(remaining_inactive.pop(0))

        remaining_bytes = sum(
            record.total_bytes
            for record in records
            if record.session_key not in selected_ids
        )
        byte_candidates = [
            record for record in inactive if record.session_key not in selected_ids
        ]
        while remaining_bytes > policy.max_total_bytes and byte_candidates:
            record = byte_candidates.pop(0)
            select(record)
            remaining_bytes -= record.total_bytes

        if any(record.has_unrelated_content for record in selected):
            raise StoreError(
                "cannot remove selected inactive session: unrelated content remains"
            )

        deleted_files = root_temp_files + session_temp_files
        deleted_bytes = root_temp_bytes + session_temp_bytes
        deleted_sessions = 0
        for record in selected:
            file_count, byte_count, removed_session = _delete_record(
                root, record, policy.lock_timeout_seconds
            )
            deleted_files += file_count
            deleted_bytes += byte_count
            deleted_sessions += int(removed_session)

        remaining_records = _scan_session_records(root)
        remaining_bytes = sum(record.total_bytes for record in remaining_records)
        remaining_inactive_count = sum(
            record.session_key != active_session_key for record in remaining_records
        )
        if any(
            record.session_key != active_session_key
            and record.updated_at < age_cutoff
            for record in remaining_records
        ):
            raise StoreError("inactive session age limit could not be satisfied")
        if remaining_inactive_count > policy.max_inactive_sessions:
            raise StoreError("inactive session limit could not be satisfied")
        if remaining_bytes > policy.max_total_bytes:
            raise StoreError("byte limit cannot be satisfied without deleting the active session")

        result = CleanupResult(
            deleted_sessions=deleted_sessions,
            deleted_files=deleted_files,
            deleted_bytes=deleted_bytes,
            remaining_sessions=len(remaining_records),
            remaining_bytes=remaining_bytes,
            skipped_active_session=active_present,
        )
        metadata_value: dict[str, object] = {
            "schema_version": 2,
            "last_cleanup_at": now.isoformat(timespec="microseconds").replace(
                "+00:00", "Z"
            ),
            "deleted_sessions": result.deleted_sessions,
            "deleted_files": result.deleted_files,
            "deleted_bytes": result.deleted_bytes,
            "remaining_sessions": result.remaining_sessions,
            "remaining_bytes": result.remaining_bytes,
        }
        metadata_bytes = canonical_json_bytes(metadata_value)
        if len(metadata_bytes) > _MAX_CLEANUP_METADATA_BYTES:
            raise StoreError("cleanup metadata exceeds its bounded size")
        temp_path = _prepare_temp(root, CLEANUP_METADATA_NAME, metadata_bytes)
        _publish_temp(temp_path, metadata_path)
        return result
