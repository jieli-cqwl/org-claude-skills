#!/usr/bin/env python3
"""Validate skill-harness calibration, ownership, and standard-chain fixtures.
The checker stays repo-local and deterministic. It accepts only fixture shapes
with active runtime consumers, then reports stable failure codes for shell gates.
"""
from __future__ import annotations
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any
import yaml
REPO_ROOT = Path(__file__).resolve().parents[4]
LOCATION_REF = re.compile(r"^[^:\n]+:\d+$")
SHA256_REF = re.compile(r"^sha256:[0-9a-f]{64}$")
CALIBRATION_SAMPLE = "delivery-owner-practice-risk"
CALIBRATION_LABEL = "Correctness PASS / Practice FAIL"
REQUIRED_FIELDS = set("sample_id mode overall_verdict dimension_result finding_severity dimension failure_code fact_source json_consumer audit_proof_type file_line evidence impact proof_command manifest_command_exists active_alias hard_gate_position expected_result".split())
CALIBRATION_STRING_FIELDS = REQUIRED_FIELDS - {"evidence", "manifest_command_exists", "active_alias"}
FINAL_DIMENSIONS = set("Trigger|Loading|Decision|Execution|Verification|Evolution|Main Content Noise|Chain Integration|Engineering Control|Directory Capability".split("|"))
OVERALL_VERDICTS = {"PASS", "FAIL", "COMMENT"}
DIMENSION_RESULTS = {"PASS", "FAIL", "WARN", "NOT_APPLICABLE"}
SEVERITIES = {"S1", "S2", "S3", "INFO"}
AUDIT_PROOF_TYPES = {"file_evidence", "fixture_proof", "fresh_proving"}
LEGACY_BASELINE_LABEL_MODES = {"baseline_smoke", "calibration_audit", "migration_audit"}
ALLOWED_RUNTIME_CONSUMERS = set("check_skill_harness_contract.py human_projection hook_adapter release_gate runner validator".split())
FIELD_KEYS = set("field consumer read_purpose validation_command drop_condition failure_state".split())
VALIDATION_PREFIXES = {"bash", "python3", "python"}
KNOWN_VALIDATION_COMMANDS = {f"bash tests/test-skill-harness-{name}.sh" for name in ("field-consumers", "gates", "legacy-label-migration", "main-content-noise", "responsibility-contract", "runtime-noise")}
ASSET_KEYS = set("asset_id source_path target_action consumer validation_command drop_condition failure_state".split())
ASSET_TARGET_KEYS = {"immediate_target_path", "target_path_when_triggered", "archive_boundary"}
ASSET_ACTIONS = set("keep_inline_summary route_to_reference port_to_contract move_to_fixture triggered_artifact archive_only".split())
REQUIRED_ASSET_IDS = set("audit-method runtime-noise-contract reference-contract permission-script-contract hook-adapter-contract subagent-handoff-contract field-consumers schemas evals examples templates-renderer optimization-plan verification-result old-runtime-entry old-agent-exposure permission-profiles source-map quality-dimension-mapping old-scripts-manifest old-audit-runner-scripts old-artifact-builders archive-readme-docs".split())
STANDARD_ROLES = "product-director product-manager design test-design tech-lead delivery-owner developer verify review qa sign-off archive".split()
ROLE_KEYS = set("role input output state_transition hard_gate evidence consumer handoff_boundary".split())
USER_DECISION_FIELDS = set("artifact_type artifact_id schema_version producer produced_at chain_version chain_registry_digest authority_scope authoritative_fields baseline_plan_version_ref baseline_tasks_version_ref active_plan_version_ref active_tasks_version_ref current_stage decision decision_source actor_id sign_off_status business_risk_acceptance_status authority_proof_refs decision_basis_refs director_lock_digests".split())
USER_DECISION_FLAGS = "must_verify_authority_proof_refs must_verify_payload_digest must_match_actor_and_channel".split()
def fail(message: str) -> None:
    """Print a stable failure message and stop validation."""
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)
def load_json(path: Path) -> dict[str, Any]:
    """Load a fixture JSON object and reject malformed inputs."""
    try:
        data = json.load(path.open(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"file not found: {path}")
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in {path}: {exc}")
    if not isinstance(data, dict):
        fail(f"top-level JSON must be object: {path}")
    return data
def require_string(sample: dict[str, Any], field: str, code: str | None = None) -> str:
    """Return a nonblank string field, except legacy optional calibration fields."""
    value = sample.get(field)
    if not isinstance(value, str):
        fail(code or f"{field} must be string")
    if field not in {"failure_code", "json_consumer"} and not value.strip():
        fail(code or f"{field} must be nonempty")
    return value
def require_enum(sample: dict[str, Any], field: str, allowed: set[str]) -> None:
    """Validate a string enum field against its active contract."""
    value = require_string(sample, field)
    if value not in allowed:
        fail(f"{field} must be one of: {', '.join(sorted(allowed))}")
def missing_string(sample: dict[str, Any], field: str) -> bool:
    """Return whether a field is absent, not a string, or blank."""
    value = sample.get(field)
    return not isinstance(value, str) or not value.strip()
def require_keys(sample: dict[str, Any], keys: set[str] | list[str], code: str) -> None:
    """Require keys with nonblank object, array, boolean, or string values."""
    for key in keys:
        value = sample.get(key)
        if value in (None, "", [], {}):
            fail(code)
def repo_path(raw_path: str) -> Path:
    """Resolve a repo-local path without absolute or parent traversal."""
    path = Path(raw_path)
    if path.is_absolute() or ".." in path.parts:
        fail(f"path must be repo-local: {raw_path}")
    return REPO_ROOT / path
def validate_file_line(ref: str, code: str) -> None:
    """Validate a repo-local file:line locator and line bounds."""
    if not LOCATION_REF.match(ref):
        fail(code)
    raw_path, raw_line = ref.rsplit(":", 1); path = repo_path(raw_path)
    if not path.is_file():
        fail(code)
    if not 1 <= int(raw_line) <= len(path.read_text(encoding="utf-8").splitlines()):
        fail(code)
def validate_consumer_ref(consumer: str, failure_code: str) -> None:
    """Require a known runtime consumer type or an existing repo path."""
    if consumer not in ALLOWED_RUNTIME_CONSUMERS and not repo_path(consumer).exists():
        fail(failure_code)
def validation_script(command: str, failure_code: str) -> Path:
    """Resolve a controlled repo-local bash/python script command."""
    try:
        parts = shlex.split(command)
    except ValueError:
        fail(failure_code)
    if len(parts) < 2 or parts[0] not in VALIDATION_PREFIXES:
        fail(failure_code)
    script = repo_path(parts[1])
    if not script.is_file() or script.relative_to(REPO_ROOT).parts[:1] == ("docs",):
        fail(failure_code)
    return script
def run_controlled_smoke(command: str, failure_code: str) -> None:
    """Execute a validation command with the self-recursion guard enabled."""
    env = dict(os.environ)
    env["SKILL_HARNESS_FIELD_CONSUMER_SKIP_SELF"] = "1"
    try:
        subprocess.run(shlex.split(command), cwd=REPO_ROOT, env=env, timeout=30, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (subprocess.SubprocessError, ValueError):
        fail(failure_code)
def validate_legacy_baseline_label(sample: dict[str, Any]) -> None:
    """Keep migration-only calibration labels out of active/default output."""
    if "legacy_baseline_label" in sample and sample["mode"] not in LEGACY_BASELINE_LABEL_MODES:
        fail(f"legacy_baseline_label is allowed only for: {', '.join(sorted(LEGACY_BASELINE_LABEL_MODES))}")
    if "legacy_baseline_label" in sample:
        require_string(sample, "legacy_baseline_label")
def validate_shape(sample: dict[str, Any]) -> None:
    """Validate the calibration fixture shape before applying gate rules."""
    if "proof_type" in sample:
        fail("proof_type is not allowed; use audit_proof_type")
    missing = sorted(REQUIRED_FIELDS - set(sample))
    if missing:
        fail(f"missing fields: {', '.join(missing)}")
    for field in CALIBRATION_STRING_FIELDS:
        require_string(sample, field)
    evidence = sample.get("evidence")
    if not isinstance(evidence, list):
        fail("evidence must be array")
    if any(not isinstance(item, str) or not item.strip() for item in evidence):
        fail("evidence entries must be nonempty strings")
    for field in ["manifest_command_exists", "active_alias"]:
        if not isinstance(sample.get(field), bool):
            fail(f"{field} must be boolean")
    require_enum(sample, "overall_verdict", OVERALL_VERDICTS)
    require_enum(sample, "dimension", FINAL_DIMENSIONS)
    require_enum(sample, "dimension_result", DIMENSION_RESULTS)
    require_enum(sample, "finding_severity", SEVERITIES)
    require_enum(sample, "audit_proof_type", AUDIT_PROOF_TYPES)
    require_enum(sample, "expected_result", {"pass", "fail"})
    validate_legacy_baseline_label(sample)
def detect_failure_code(sample: dict[str, Any]) -> str:
    """Return the first calibration failure code, or blank when valid."""
    fail_result = sample["dimension_result"] == "FAIL"
    checks = (
        ("NEED_EVIDENCE", fail_result and not sample["evidence"]),
        ("MISSING_RECOMMENDATION", fail_result and missing_string(sample, "recommendation")),
        ("INVALID_FILE_LINE", fail_result and not LOCATION_REF.match(sample["file_line"])),
        ("MISSING_COMMAND", not sample["manifest_command_exists"]),
        ("ACTIVE_ALIAS", sample["active_alias"]),
        ("MARKDOWN_FACT_SOURCE", sample["fact_source"] == "markdown" and sample["json_consumer"]),
        ("CONTENT_ORDER", sample["hard_gate_position"] == "tail"),
        ("JSON_WITHOUT_CONSUMER", sample["fact_source"] == "json" and not sample["json_consumer"]),
        ("CALIBRATION_MISMATCH", sample["sample_id"] == CALIBRATION_SAMPLE and sample.get("legacy_baseline_label") != CALIBRATION_LABEL),
    )
    return next((code for code, triggered in checks if triggered), "")
def validate_sample(sample: dict[str, Any]) -> None:
    """Validate one calibration fixture and enforce its declared outcome."""
    validate_shape(sample)
    actual = detect_failure_code(sample)
    declared = sample["failure_code"]
    if actual:
        if declared != actual:
            fail(f"FAILURE_CODE_MISMATCH expected={declared} actual={actual}")
        fail(actual)
    if sample["expected_result"] != "pass":
        fail(f"EXPECTED_FAILURE_WITHOUT_RULE: {sample['sample_id']}")
    if declared:
        fail(f"UNUSED_FAILURE_CODE: {declared}")
def validate_field_row(row: dict[str, Any]) -> None:
    """Validate one runtime field consumer and execute its smoke command."""
    missing = sorted(FIELD_KEYS - row.keys())
    if missing:
        fail(f"FIELD_CONSUMER_MISSING_KEYS: {', '.join(missing)}")
    for field in FIELD_KEYS:
        if missing_string(row, field):
            fail("FIELD_CONSUMER_MISSING_DROP_CONDITION" if field == "drop_condition" else f"FIELD_CONSUMER_INCOMPLETE_ROW: {row.get('field', '<unknown>')}")
    validate_consumer_ref(row["consumer"], "FIELD_CONSUMER_INVALID_CONSUMER")
    validation_script(row["validation_command"], "FIELD_CONSUMER_INVALID_COMMAND")
    run_controlled_smoke(row["validation_command"], "FIELD_CONSUMER_VALIDATION_FAILED")
def validate_field_consumer_contract(sample: dict[str, Any]) -> None:
    """Validate field-consumer contract fixtures and schema rows."""
    fields = sample.get("fields")
    if not isinstance(fields, list) or not fields:
        fail("FIELD_CONSUMER_FIELDS_REQUIRED")
    for row in fields:
        if not isinstance(row, dict):
            fail("FIELD_CONSUMER_ROW_MUST_BE_OBJECT")
        validate_field_row(row)
    print(f"[PASS] {sample.get('sample_id', 'field-consumers')}")
def nonempty_string(row: dict[str, Any], key: str, failure_code: str) -> str:
    """Return a required nonblank string from an ownership row."""
    value = row.get(key)
    if not isinstance(value, str) or not value.strip():
        fail(failure_code)
    return value
def active_target(row: dict[str, Any]) -> str:
    """Validate exactly one ownership target mode and return its path."""
    present = [key for key in ASSET_TARGET_KEYS if row.get(key)]
    if len(present) != 1:
        fail("ASSET_OWNERSHIP_TARGET_MODE_CONFLICT" if len(present) > 1 else "ASSET_OWNERSHIP_MISSING_TARGET")
    if present[0] != "target_path_when_triggered":
        target_path = nonempty_string(row, present[0], "ASSET_OWNERSHIP_MISSING_TARGET")
    else:
        target = row[present[0]]
        if not isinstance(target, dict):
            fail("ASSET_OWNERSHIP_TRIGGERED_TARGET_INVALID")
        validate_consumer_ref(nonempty_string(target, "consumer", "ASSET_OWNERSHIP_TRIGGERED_TARGET_INVALID"), "ASSET_OWNERSHIP_INVALID_CONSUMER")
        nonempty_string(target, "deferred_until", "ASSET_OWNERSHIP_TRIGGERED_TARGET_INVALID")
        target_path = nonempty_string(target, "path", "ASSET_OWNERSHIP_TRIGGERED_TARGET_INVALID")
    if not path_exists(target_path):
        fail("ASSET_OWNERSHIP_MISSING_TARGET")
    return target_path
def contains_reverse_reference(row: dict[str, Any], target_path: str, script: Path) -> bool:
    """Check owner artifacts mention the legacy source or active target path."""
    candidates = [script, REPO_ROOT / "shared/skills/skill-harness/scripts/manifest.json"]
    if row["consumer"] not in ALLOWED_RUNTIME_CONSUMERS and repo_path(row["consumer"]).is_file():
        candidates.append(repo_path(row["consumer"]))
    return any(any(token in path.read_text(encoding="utf-8") for token in {row["source_path"], target_path}) for path in candidates if path.is_file())
def validate_asset_shape(row: dict[str, Any]) -> None:
    """Validate one legacy asset ownership row shape."""
    if not isinstance(row, dict):
        fail("ASSET_OWNERSHIP_ROW_MUST_BE_OBJECT")
    missing = sorted(ASSET_KEYS - row.keys())
    if missing:
        fail(f"ASSET_OWNERSHIP_MISSING_KEYS: {', '.join(missing)}")
    for key in ASSET_KEYS:
        nonempty_string(row, key, "ASSET_OWNERSHIP_INCOMPLETE_ROW")
def validate_asset_identity(row: dict[str, Any], seen_sources: set[str], seen_ids: set[str]) -> None:
    """Validate asset identity, action, source existence, and uniqueness."""
    if row["asset_id"] not in REQUIRED_ASSET_IDS:
        fail("ASSET_OWNERSHIP_UNKNOWN_ASSET_ID")
    if row["asset_id"] in seen_ids or row["source_path"] in seen_sources:
        fail("ASSET_OWNERSHIP_DUPLICATE_ASSET_ID" if row["asset_id"] in seen_ids else "ASSET_OWNERSHIP_DUPLICATE_SOURCE")
    if row["target_action"] not in ASSET_ACTIONS or not repo_path(row["source_path"]).exists():
        fail("ASSET_OWNERSHIP_INVALID_ACTION" if row["target_action"] not in ASSET_ACTIONS else "ASSET_OWNERSHIP_MISSING_SOURCE")
    seen_ids.add(row["asset_id"])
    seen_sources.add(row["source_path"])
def validate_asset_command(row: dict[str, Any], smoke_ran: set[str]) -> Path:
    """Validate and smoke-run an ownership command once."""
    command = row["validation_command"]
    if command not in KNOWN_VALIDATION_COMMANDS:
        fail("ASSET_OWNERSHIP_INVALID_COMMAND")
    script = validation_script(command, "ASSET_OWNERSHIP_INVALID_COMMAND")
    if command not in smoke_ran:
        run_controlled_smoke(command, "ASSET_OWNERSHIP_INVALID_COMMAND")
        smoke_ran.add(command)
    return script
def validate_asset_row(row: dict[str, Any], seen_sources: set[str], seen_ids: set[str], smoke_ran: set[str]) -> None:
    """Validate one legacy asset ownership row and its reverse reference."""
    validate_asset_shape(row)
    validate_asset_identity(row, seen_sources, seen_ids)
    target_path = active_target(row)
    validate_consumer_ref(row["consumer"], "ASSET_OWNERSHIP_INVALID_CONSUMER")
    script = validate_asset_command(row, smoke_ran)
    if not contains_reverse_reference(row, target_path, script):
        fail("ASSET_OWNERSHIP_MISSING_REVERSE_REFERENCE")
def validate_asset_ownership(sample: dict[str, Any]) -> None:
    """Validate legacy skill-audit asset ownership rows."""
    assets = sample.get("assets")
    if not isinstance(assets, list) or not assets:
        fail("ASSET_OWNERSHIP_ASSETS_REQUIRED")
    seen_sources: set[str] = set()
    seen_ids: set[str] = set()
    smoke_ran: set[str] = set()
    for row in assets:
        validate_asset_row(row, seen_sources, seen_ids, smoke_ran)
    missing_ids = sorted(REQUIRED_ASSET_IDS - seen_ids)
    if missing_ids:
        fail(f"ASSET_OWNERSHIP_MISSING_REQUIRED_IDS: {', '.join(missing_ids)}")
    print(f"[PASS] {sample.get('sample_id', 'legacy-asset-ownership')}")
def load_authority_registry() -> dict[str, Any]:
    """Load the canonical authority registry consumed by user-decision gates."""
    return yaml.safe_load((REPO_ROOT / "contracts/canonical/authority-registry.yaml").read_text(encoding="utf-8"))
def decision_payload_digest(sample: dict[str, Any]) -> str:
    """Digest only canonical user-decision payload fields, excluding the digest."""
    payload = {key: sample[key] for key in sorted(USER_DECISION_FIELDS) if key in sample}
    return "sha256:" + hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()
def validate_role_catalog(sample: dict[str, Any]) -> None:
    """Validate the complete standard-chain role catalog fixture."""
    roles = sample.get("roles")
    if not isinstance(roles, list) or [row.get("role") for row in roles if isinstance(row, dict)] != STANDARD_ROLES:
        fail("ROLE_CATALOG_INCOMPLETE")
    for row in roles:
        if not isinstance(row, dict) or set(row) != ROLE_KEYS:
            fail("ROLE_CATALOG_INCOMPLETE")
        require_keys(row, ROLE_KEYS, "ROLE_CATALOG_INCOMPLETE")
def validate_gate(sample: dict[str, Any]) -> None:
    """Validate machine, human, and user decision gate fixture contracts."""
    gate_type = require_string(sample, "gate_type", "GATE_FIELDS_REQUIRED")
    if gate_type == "machine_gate":
        require_nonempty_array(sample, "must_block_when", "GATE_FIELDS_REQUIRED"); require_string(sample, "failure_state", "GATE_FIELDS_REQUIRED")
    elif gate_type == "human_review_gate":
        for field in ["review_owner", "verdict_field", "evidence_ref"]:
            require_string(sample, field, "GATE_FIELDS_REQUIRED")
        require_nonempty_array(sample, "block_when", "GATE_FIELDS_REQUIRED")
    elif gate_type == "user_decision_gate":
        validate_user_decision(sample)
    else:
        fail("GATE_FIELDS_REQUIRED")
def require_nonempty_array(sample: dict[str, Any], field: str, code: str) -> None:
    """Require a nonempty list of nonblank strings."""
    value = sample.get(field)
    if not isinstance(value, list) or not value or any(missing_string({field: item}, field) for item in value):
        fail(code)
def validate_standard_proof(sample: dict[str, Any]) -> None:
    """Validate standard-chain evidence proof fixture shapes."""
    proof_type = require_string(sample, "audit_proof_type", "PROOF_COMMAND_REQUIRED")
    if proof_type == "file_evidence":
        require_keys(sample, ["file_line", "evidence_locator"], "EVIDENCE_LOCATOR_REQUIRED")
        validate_file_line(sample["file_line"], "INVALID_FILE_EVIDENCE"); validate_file_line(sample["evidence_locator"], "INVALID_FILE_EVIDENCE")
    elif proof_type == "fixture_proof":
        require_keys(sample, ["fixture_path", "fixture_command"], "FIXTURE_COMMAND_REQUIRED")
        if not repo_path(sample["fixture_path"]).is_file():
            fail("INVALID_FIXTURE_PROOF")
        validation_script(sample["fixture_command"], "INVALID_FIXTURE_PROOF"); run_controlled_smoke(sample["fixture_command"], "INVALID_FIXTURE_PROOF")
    elif proof_type == "fresh_proving":
        if sample.get("freshness_required") is not True:
            fail("PROOF_COMMAND_REQUIRED")
        require_keys(sample, ["proof_command"], "PROOF_COMMAND_REQUIRED")
        validation_script(sample["proof_command"], "INVALID_PROOF_COMMAND"); run_controlled_smoke(sample["proof_command"], "INVALID_PROOF_COMMAND")
    else:
        fail("PROOF_COMMAND_REQUIRED")
def validate_user_decision_shape(sample: dict[str, Any], registry: dict[str, Any]) -> dict[str, Any]:
    """Validate user-decision fields and return the source-specific rule."""
    require_keys(sample, USER_DECISION_FIELDS | {"decision_payload_digest", "allowed_final_decision_sources", "authority_proof"} | set(USER_DECISION_FLAGS), "USER_AUTHORITY_REQUIRED")
    if any(sample[field] is not True for field in USER_DECISION_FLAGS):
        fail("USER_AUTHORITY_REQUIRED")
    if sample["artifact_type"] != "user-decision" or not sample["authority_proof_refs"]:
        fail("USER_AUTHORITY_REQUIRED")
    allowed = registry["v1_user_decision_policy"]["allowed_final_sources"]
    if sample["allowed_final_decision_sources"] != allowed or sample["decision_source"] not in allowed:
        fail("USER_AUTHORITY_REQUIRED")
    rule = registry["decision_source_rules"].get(sample["decision_source"])
    if not isinstance(rule, dict):
        fail("USER_AUTHORITY_REQUIRED")
    return rule
def validate_user_authority(sample: dict[str, Any], rule: dict[str, Any]) -> None:
    """Validate proof type, actor, channel, and digest binding."""
    proof = sample["authority_proof"]
    if not isinstance(proof, dict):
        fail("USER_AUTHORITY_REQUIRED")
    require_keys(proof, ["proof_type", "verified_actor_id", "verified_channel", "decision_payload_digest"], "USER_AUTHORITY_REQUIRED")
    if proof["proof_type"] != rule["required_proof_type"]:
        fail("PROOF_TYPE_MISMATCH")
    if proof["verified_channel"] not in rule["allowed_channels"]:
        fail("CHANNEL_MISMATCH")
    if proof["verified_actor_id"] != sample["actor_id"]:
        fail("ACTOR_MISMATCH")
    if proof["decision_payload_digest"] != sample["decision_payload_digest"]:
        fail("DIGEST_MISMATCH")
def validate_user_decision(sample: dict[str, Any]) -> None:
    """Validate standard-chain user decision authority and baseline gates."""
    rule = validate_user_decision_shape(sample, load_authority_registry())
    if sample["baseline_plan_version_ref"] != sample["active_plan_version_ref"]:
        fail("BASELINE_DRIFT")
    if sample["baseline_tasks_version_ref"] != sample["active_tasks_version_ref"]:
        fail("BASELINE_DRIFT")
    validate_user_authority(sample, rule)
    if not SHA256_REF.match(sample["decision_payload_digest"]):
        fail("DIGEST_MISMATCH")
    if sample["decision_payload_digest"] != decision_payload_digest(sample):
        fail("DIGEST_MISMATCH")
def validate_standard_chain(sample: dict[str, Any]) -> None:
    """Dispatch standard-chain contract fixture validation."""
    if "roles" in sample:
        validate_role_catalog(sample)
    elif "gate_type" in sample:
        validate_gate(sample)
    elif "audit_proof_type" in sample:
        validate_standard_proof(sample)
    else:
        fail("STANDARD_CHAIN_CONTRACT_REQUIRED")
    print(f"[PASS] {sample.get('sample_id', 'standard-chain')}")
def main(argv: list[str]) -> None:
    """Run fixture validation from the command line."""
    if len(argv) != 2:
        fail("usage: check_skill_harness_contract.py <case.json>")
    sample = load_json(Path(argv[1]))
    mode = sample.get("mode")
    if mode == "field_consumer_contract":
        validate_field_consumer_contract(sample)
    elif mode == "legacy_asset_ownership":
        validate_asset_ownership(sample)
    elif mode == "standard_chain_contract":
        validate_standard_chain(sample)
    else:
        validate_sample(sample)
        print(f"[PASS] {sample['sample_id']}")
if __name__ == "__main__":
    main(sys.argv)
