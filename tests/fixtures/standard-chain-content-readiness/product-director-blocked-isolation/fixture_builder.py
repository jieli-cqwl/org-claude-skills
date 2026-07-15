#!/usr/bin/env python3
"""Build and mutate the portable content-readiness contract fixture."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path, PurePosixPath
from typing import Any

PRIMARY_ROLES = [
    "product-director",
    "product-manager",
    "design",
    "test-design",
    "tech-lead",
    "delivery-owner",
]
ROLE_EVALUATION_FILENAMES = {
    "surface.json",
    "decision-atoms.json",
    "content-audit-alignment.json",
    "content-audit-report.json",
    "replay-lane.json",
    "replay-attempt.json",
    "transcript.json",
    "artifact-manifest.json",
    "divergence-review.json",
    "oracle-review.json",
    "downstream-consumption.json",
    "role-verdict.json",
}
ZERO_SHA = "0" * 64
ZERO_COMMIT = "0" * 40


def canonical_bytes(value: object) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def digest(value: object) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def file_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected JSON object")
    return value


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def run_git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args], text=True, stderr=subprocess.STDOUT
    ).strip()


def init_source_repo(path: Path, label: str) -> dict[str, str]:
    path.mkdir(parents=True)
    subprocess.run(["git", "init", "-q", "-b", "main", str(path)], check=True)
    run_git(path, "config", "user.name", "Synthetic Fixture")
    run_git(path, "config", "user.email", "fixture@example.invalid")

    (path / "base.txt").write_text(f"{label} baseline\n", encoding="utf-8")
    (path / "rename-me.txt").write_text(f"{label} rename source\n", encoding="utf-8")
    run_git(path, "add", ".")
    run_git(path, "commit", "-q", "-m", "baseline")
    baseline = run_git(path, "rev-parse", "HEAD")

    (path / "base.txt").write_text(f"{label} normal change\n", encoding="utf-8")
    run_git(path, "add", "base.txt")
    run_git(path, "commit", "-q", "-m", "normal change")
    normal = run_git(path, "rev-parse", "HEAD")

    run_git(path, "checkout", "-q", "-b", "side")
    run_git(path, "mv", "rename-me.txt", "renamed.txt")
    run_git(path, "commit", "-q", "-m", "rename on side")
    side = run_git(path, "rev-parse", "HEAD")

    run_git(path, "checkout", "-q", "main")
    (path / "main-only.txt").write_text(f"{label} main parent\n", encoding="utf-8")
    run_git(path, "add", "main-only.txt")
    run_git(path, "commit", "-q", "-m", "main parent")
    run_git(path, "merge", "-q", "--no-ff", "side", "-m", "two parent merge")
    merge = run_git(path, "rev-parse", "HEAD")

    (path / "result.txt").write_text(f"{label} result\n", encoding="utf-8")
    run_git(path, "add", "result.txt")
    run_git(path, "commit", "-q", "-m", "result")
    result = run_git(path, "rev-parse", "HEAD")
    return {
        "root": str(path.resolve()),
        "baseline": baseline,
        "normal": normal,
        "side": side,
        "merge": merge,
        "result": result,
    }


def command_init_sources(args: argparse.Namespace) -> None:
    root = Path(args.output_root).resolve()
    root.mkdir(parents=True, exist_ok=True)
    payload = {
        "synthetic-app": init_source_repo(root / "synthetic-app", "app"),
        "synthetic-backend": init_source_repo(
            root / "synthetic-backend", "backend"
        ),
    }
    write_json(Path(args.descriptor), payload)


def scoped_ref(
    scope: str,
    path: str,
    *,
    source_id: str | None = None,
    commit: str | None = None,
    blob: str | None = None,
    line: int | None = None,
) -> dict[str, Any]:
    value: dict[str, Any] = {"scope": scope, "path": path, "sha256": ZERO_SHA}
    if source_id is not None:
        value["source_id"] = source_id
    if commit is not None:
        value["commit"] = commit
    if blob is not None:
        value["blob"] = blob
    if line is not None:
        value["line"] = line
    return value


def run_ref(path: str) -> dict[str, Any]:
    return scoped_ref("run", path)


def repo_ref(
    path: str,
    *,
    commit: str | None = None,
    blob: str | None = None,
    line: int | None = None,
) -> dict[str, Any]:
    return scoped_ref("repo", path, commit=commit, blob=blob, line=line)


def external_ref(
    source_id: str,
    path: str,
    *,
    commit: str | None = None,
    blob: str | None = None,
    line: int | None = None,
) -> dict[str, Any]:
    return scoped_ref(
        "external_repo",
        path,
        source_id=source_id,
        commit=commit,
        blob=blob,
        line=line,
    )


def git_blob(repo: Path, commit: str, path: str) -> str:
    return run_git(repo, "rev-parse", f"{commit}:{path}")


def build_canonical_artifacts(
    template: dict[str, Any], run_root: Path, lane_id: str
) -> list[dict[str, Any]]:
    feature = f"qft-qmi-pc-001-executor-{lane_id}"
    relative_root = f"roles/product-director/executor-{lane_id}/attempt-1/canonical"
    output_root = run_root / relative_root
    business = copy.deepcopy(template["canonical_business"])
    produced_at = "2026-07-14T12:00:00Z"
    registry_digest = "sha256:" + hashlib.sha256(b"synthetic-registry").hexdigest()

    def add_envelope(
        payload: dict[str, Any],
        artifact_type: str,
        artifact_id: str,
        authority_scope: str,
        fields: list[str],
    ) -> None:
        locked_fields = {field: payload[field] for field in fields}
        payload.update(
            {
                "artifact_type": artifact_type,
                "artifact_id": artifact_id,
                "schema_version": "1.0.0",
                "producer": "product-director",
                "produced_at": produced_at,
                "chain_version": "standard-chain/v1",
                "chain_registry_digest": registry_digest,
                "authority_scope": authority_scope,
                "authoritative_fields": [f"$.{field}" for field in fields]
                + ["$.director_confirmation"],
                "director_confirmation": {
                    "status": "passed",
                    "confirmed_at": produced_at,
                    "locked_field_digest": "sha256:" + digest(locked_fields),
                    "locked_fields": locked_fields,
                },
            }
        )

    brief_fields = [
        "root_problem",
        "user_profile",
        "business_goals",
        "appetite",
        "scope_boundaries",
        "non_goals",
        "feasibility_constraints",
        "risks_and_unknowns",
        "decision_rationale",
        "delivery_plan",
    ]
    brief = {field: business[field] for field in brief_fields}
    phase_fields = ["phase_goal", "entry_conditions", "exit_conditions"]
    phase = {field: business[field] for field in phase_fields}
    add_envelope(brief, "brief", f"{feature}.brief", "feature", brief_fields)
    add_envelope(
        phase, "phase-prd", f"{feature}.phase-1.prd", "phase", phase_fields
    )

    steps = [
        "问题澄清",
        "目标、成功标准与投入边界",
        "业务语义收口",
        "范围、本期不做、可行性约束与决策理由",
        "风险与未知项",
        "Phase 规划",
        "Director Finalization",
    ]
    summaries = [
        "Root problem confirmed because split inventory records cause 4 missed exceptions per week.",
        "Success standard confirmed: reduce 4 weekly misses to zero in a 30-day observation window with a single focused investment phase.",
        "Business semantics set the inventory desk as owner of the daily exception review.",
        "Scope includes daily visibility and explicitly excludes supplier automation.",
        "Risk confirmed: daily export cadence remains bounded to the Phase 1 baseline.",
        "Phase confirmed as one 10-day daily exception-review value slice.",
        "Director Finalization accepts the synthetic brief and phase result as the handoff baseline.",
    ]
    confirmations = []
    for index, (step, summary) in enumerate(zip(steps, summaries), start=1):
        confirmations.append(
            {
                "checkpoint_id": f"SYN-PD-{index:02d}",
                "step": step,
                "subject_ref": f"{feature}:{step}",
                "confirmed_at": f"2026-07-14T12:{index:02d}:00Z",
                "decision_summary": summary,
                "source_refs": [f"docs/{feature}/brief.json"],
                "output_refs": [
                    f"docs/{feature}/brief.json",
                    f"docs/{feature}/phase-1/phase-prd.json",
                ],
            }
        )
    ledger = {
        "artifact_type": "co-creation-ledger",
        "schema_version": "1.0.0",
        "producer": "product-director",
        "scope_ref": f"docs/{feature}",
        "current_state": {
            "summary": "Synthetic Director baseline finalized for inventory review",
            "source_refs": [f"docs/{feature}/brief.json"],
            "next_step": "ready for downstream detail work",
        },
        "latest_checkpoint_id": confirmations[-1]["checkpoint_id"],
        "confirmations": confirmations,
        "open_questions": [],
        "supersedes": [],
        "handoff_refs": [
            f"docs/{feature}/brief.json",
            f"docs/{feature}/phase-1/phase-prd.json",
        ],
        "finalization_basis": {
            "status": "confirmed",
            "confirmed_at": produced_at,
            "summary": "All synthetic Director checkpoints were accepted",
            "accepted_checkpoint_ids": [
                item["checkpoint_id"] for item in confirmations
            ],
        },
    }

    paths = {
        "brief.json": brief,
        "phase-1/phase-prd.json": phase,
        "product-director-ledger.json": ledger,
    }
    refs = []
    for relative, payload in paths.items():
        write_json(output_root / relative, payload)
        refs.append(run_ref(f"{relative_root}/{relative}"))
    return refs


def prepare_audit_artifacts(repo_root: Path, run_root: Path) -> None:
    role_root = run_root / "roles/product-director"
    alignment_path = role_root / "content-audit-alignment.json"
    report_path = role_root / "content-audit-report.json"
    summary_path = role_root / "content-audit-summary.md"
    alignment = read_json(
        repo_root / "tests/fixtures/skill-quality-audit/alignments/valid-alignment.json"
    )
    report = read_json(
        repo_root / "shared/skills/skill-quality-audit/evals/fixtures/reports/valid-report.json"
    )

    alignment["target_skill"] = "shared/skills/product-director"
    for claim in alignment["target_capability_claims"]:
        claim["target_capability_id"] = "SC-CAP-PD-001"
        claim["label"] = "Synthetic Product Director case-bounded capability"
        claim["refs"] = [
            "docs/superpowers/specs/2026-07-14--standard-chain-manual-content-readiness-evaluation--design.md:36"
        ]
    alignment["capability_match_draft"]["gaps"][0][
        "target_capability_id"
    ] = "SC-CAP-PD-001"
    alignment["user_confirmation"]["confirmed_target_capability_ids"] = [
        "SC-CAP-PD-001"
    ]
    standard = alignment["capability_effectiveness_standard"]
    standard["target_capability_ids"] = ["SC-CAP-PD-001"]
    standard["confirmation_evidence"] = {
        "status": "recorded_user_confirmation",
        "ref": "docs/superpowers/specs/2026-07-14--standard-chain-manual-content-readiness-evaluation--approval-record.md:8",
        "path": "docs/superpowers/specs/2026-07-14--standard-chain-manual-content-readiness-evaluation--approval-record.md",
        "line": 8,
        "expected_snippet": "批准设计",
        "claim": "The immutable approval record confirms the capability baseline.",
    }
    write_json(alignment_path, alignment)

    report["target_skill"] = "shared/skills/product-director"
    report["artifact_paths"] = {
        "report_json": str(report_path),
        "summary_markdown": str(summary_path),
    }
    report["capability_baseline_ref"] = str(alignment_path)
    report["confirmed_target_capability_ids"] = ["SC-CAP-PD-001"]
    for item in report["content_behavior_audit"]:
        item["target_capability_id"] = "SC-CAP-PD-001"
    report["validation"] = {
        "status": "PASS",
        "alignment": {
            "status": "PASS",
            "command": f"python3 validate_skill_audit_alignment.py {alignment_path}",
            "output": "[PASS] skill audit alignment valid",
        },
        "report": {
            "status": "PASS",
            "command": f"python3 validate_skill_audit_report.py {report_path}",
            "output": "[PASS] skill audit report valid",
        },
    }
    write_json(report_path, report)
    summary_path.write_text(
        "# Synthetic Product Director content audit\n\nEvaluation fixture only.\n",
        encoding="utf-8",
    )


def build_run(
    repo_root: Path,
    template_path: Path,
    run_root: Path,
    runtime_root: Path,
    descriptor_path: Path,
    denominators: list[Path],
) -> dict[str, str]:
    template = read_json(template_path)
    sources = read_json(descriptor_path)
    if run_root.exists():
        shutil.rmtree(run_root)
    run_root.mkdir(parents=True)
    runtime_root.mkdir(parents=True, exist_ok=True)
    (runtime_root / "mandatory-runtime.md").write_text(
        "synthetic inherited runtime contract\n", encoding="utf-8"
    )
    (runtime_root / "harness.txt").write_text(
        "synthetic harness descriptor evidence\n", encoding="utf-8"
    )
    prepare_audit_artifacts(repo_root, run_root)

    head = run_git(repo_root, "rev-parse", "HEAD")
    approval_commit = "d7efad0923136d5cf7c9390a2d38a22cb6a71ff2"
    design_commit = "293f624455eb9570f9426b457fadfbb946351049"
    approval_path = "docs/superpowers/specs/2026-07-14--standard-chain-manual-content-readiness-evaluation--approval-record.md"
    design_path = "docs/superpowers/specs/2026-07-14--standard-chain-manual-content-readiness-evaluation--design.md"
    approval_ref = repo_ref(
        approval_path,
        commit=approval_commit,
        blob=git_blob(repo_root, approval_commit, approval_path),
        line=8,
    )
    design_ref = repo_ref(
        design_path,
        commit=design_commit,
        blob=git_blob(repo_root, design_commit, design_path),
        line=36,
    )
    case_id = template["case_id"]
    role = template["role"]

    write_json(
        run_root / "case/confirmation-ref.json",
        {
            "artifact_type": "confirmation-ref",
            "schema_version": 1,
            "case_id": case_id,
            "design_ref": design_ref,
            "approval_ref": approval_ref,
            "approval_line": 8,
            "capability_line": 18,
            "approved_capability_ids": [template["capability_id"]],
            "approved_oracle_atom_ids": [
                atom["atom_id"] for atom in template["oracle_atoms"]
            ],
            "approved_scope_lines": [8, 18],
            "stale_if": [
                "the approved design commit changes",
                "the approval record no longer contains the capability id",
            ],
        },
    )

    runtime_ref = external_ref("synthetic-runtime", "mandatory-runtime.md")
    harness_ref = external_ref("synthetic-runtime", "harness.txt")
    surface_file_ref = repo_ref(
        "shared/skills/product-director/SKILL.md",
        commit=head,
        blob=git_blob(repo_root, head, "shared/skills/product-director/SKILL.md"),
        line=1,
    )
    source_ref = copy.deepcopy(surface_file_ref)

    denominator_sources = []
    for denominator_path in denominators:
        denominator = read_json(denominator_path)["source"]
        for atom in denominator["source_atoms"]:
            atom["classification"] = "relevant"
            atom["reason"] = "Synthetic changed-path atom is in the fixture denominator."
            atom["oracle_atom_ids"] = [template["oracle_atoms"][0]["atom_id"]]
        denominator_sources.append(denominator)
    write_json(
        run_root / "case/source-classification.json",
        {
            "artifact_type": "source-classification",
            "schema_version": 1,
            "case_id": case_id,
            "path_diff_policy": "first_parent",
            "sources": denominator_sources,
        },
    )

    first_source_id = "synthetic-app"
    first_source = sources[first_source_id]
    baseline_ref = external_ref(
        first_source_id,
        "base.txt",
        commit=first_source["baseline"],
        blob=git_blob(Path(first_source["root"]), first_source["baseline"], "base.txt"),
        line=1,
    )
    oracle_atoms = []
    for atom in template["oracle_atoms"]:
        oracle_atoms.append(
            {
                **copy.deepcopy(atom),
                "approval_ref": copy.deepcopy(approval_ref),
                "design_line": 36,
                "historical_support_refs": [copy.deepcopy(baseline_ref)],
            }
        )
    proxy_facts = []
    for fact in template["business_proxy_facts"]:
        proxy_facts.append(
            {
                **copy.deepcopy(fact),
                "authority_refs": [copy.deepcopy(approval_ref)],
            }
        )
    write_json(
        run_root / "case/oracle-manifest.json",
        {
            "artifact_type": "oracle-manifest",
            "schema_version": 1,
            "case_id": case_id,
            "oracle_version": template["oracle_version"],
            "authority_ref": copy.deepcopy(approval_ref),
            "atoms": oracle_atoms,
            "business_proxy_facts": proxy_facts,
        },
    )

    write_json(
        run_root / "case/input-manifest.json",
        {
            "artifact_type": "input-manifest",
            "schema_version": 1,
            "case_id": case_id,
            "starting_clue": "A synthetic inventory desk misses stock-exception follow-ups.",
            "executor_visible": [copy.deepcopy(surface_file_ref), copy.deepcopy(baseline_ref)],
            "reviewer_only": [run_ref("case/oracle-manifest.json")],
            "forbidden_to_executor": [run_ref("case/source-classification.json")],
            "baseline_code_view": [copy.deepcopy(baseline_ref)],
            "oracle_version": template["oracle_version"],
            "product_director_content_digest": ZERO_SHA,
            "inherited_runtime_digest": ZERO_SHA,
            "inherited_runtime_refs": [copy.deepcopy(runtime_ref)],
            "authorized_business_proxy_fact_key_digest": ZERO_SHA,
            "starting_input_sha256": ZERO_SHA,
        },
    )

    surface = {
        "artifact_type": "role-surface",
        "schema_version": 1,
        "case_id": case_id,
        "role": role,
        "repo_revision": head,
        "files": [
            {
                "ref": copy.deepcopy(surface_file_ref),
                "surface_class": "skill",
                "in_scope_reason": "Synthetic fixture exercises the current role package.",
                "consumer_refs": ["standard-chain:product-manager"],
            }
        ],
        "dependency_edges": [
            {
                "from": "shared/skills/product-director/SKILL.md",
                "to": "standard-chain:product-manager",
                "relation": "canonical-handoff",
            }
        ],
        "scope_surfaces": ["SKILL.md", "runtime inheritance", "completion gate"],
        "runtime_inheritance": {
            "probe_prompt": "List mandatory inherited runtime inputs.",
            "probe_response": "One synthetic runtime file and one harness descriptor.",
            "declared_mandatory_refs": [copy.deepcopy(runtime_ref)],
            "harness_descriptor": {
                "runner": "synthetic-local",
                "version": "1",
                "descriptor_ref": harness_ref,
            },
            "unresolved_file_inputs": [],
            "unobservable_nonfile_injections": ["system instructions"],
            "system_injection_observable": False,
            "evidence_level": "DECLARED_ONLY",
            "inherited_runtime_digest": ZERO_SHA,
        },
    }
    write_json(run_root / f"roles/{role}/surface.json", surface)

    decision_atom = {
        "atom_id": "SYN-PD-ATOM-001",
        "sentence_class": "required-action",
        "source_ref": source_ref,
        "trigger": "A root problem clue is supplied.",
        "fact_source": "business proxy response",
        "decision_owner": "product-director",
        "action_mode": "required",
        "action": "Clarify the root problem and success standard.",
        "artifact_or_state_change": "Update the synthetic Director baseline.",
        "completion_evidence": "Canonical brief and phase outputs pass their gates.",
        "failure_conflict_unknown_route": "Stop and request the missing business decision.",
        "downstream_consumer": "product-manager",
        "validator_or_harness": "Product Director completion gate",
        "static_assessment": "The instruction is traceable but isolation remains declared-only.",
    }
    write_json(
        run_root / f"roles/{role}/decision-atoms.json",
        {
            "artifact_type": "decision-atom-register",
            "schema_version": 1,
            "case_id": case_id,
            "role": role,
            "target_capability_id": template["capability_id"],
            "atoms": [decision_atom],
        },
    )

    fact = proxy_facts[0]
    public_answer = {
        "fact_key": fact["fact_key"],
        "fact_class": fact["fact_class"],
        "answer_text": fact["answer_text"],
    }
    lane_refs = []
    decisive_refs = []
    for lane_id in ("a", "b"):
        lane_base = f"roles/{role}/executor-{lane_id}"
        attempt_base = f"{lane_base}/attempt-1"
        staging_root = run_root.parent / f"staging-{lane_id}"
        output_root = run_root.parent / f"output-{lane_id}"
        staging_root.mkdir(parents=True, exist_ok=True)
        output_root.mkdir(parents=True, exist_ok=True)
        (staging_root / "input.txt").write_text(
            "synthetic identical starting input\n", encoding="utf-8"
        )
        staged_files = [
            {"path": "input.txt", "sha256": file_digest(staging_root / "input.txt")}
        ]
        canonical_refs = build_canonical_artifacts(template, run_root, lane_id)
        write_json(
            run_root / f"{attempt_base}/transcript.json",
            {
                "artifact_type": "transcript",
                "schema_version": 1,
                "case_id": case_id,
                "role": role,
                "lane_id": lane_id,
                "attempt_number": 1,
                "turns": [
                    {
                        "turn_number": 1,
                        "actor": "executor",
                        "message": "Who owns the daily exception review?",
                        "visible_fact_keys": [],
                        "state_before": "root-problem-clue",
                        "state_after": "owner-question-open",
                    },
                    {
                        "turn_number": 2,
                        "actor": "business-proxy",
                        "message": canonical_bytes([public_answer]).decode("utf-8"),
                        "visible_fact_keys": [fact["fact_key"]],
                        "state_before": "owner-question-open",
                        "state_after": "owner-confirmed",
                        "answers": [copy.deepcopy(public_answer)],
                        "answer_authority_refs": [
                            {
                                "fact_key": fact["fact_key"],
                                "authority_refs": copy.deepcopy(fact["authority_refs"]),
                            }
                        ],
                    },
                ],
            },
        )
        write_json(
            run_root / f"{attempt_base}/artifact-manifest.json",
            {
                "artifact_type": "artifact-manifest",
                "schema_version": 1,
                "case_id": case_id,
                "role": role,
                "lane_id": lane_id,
                "attempt_number": 1,
                "evaluation_only": True,
                "canonical_output_refs": canonical_refs,
            },
        )
        attempt_path = f"{attempt_base}/replay-attempt.json"
        write_json(
            run_root / attempt_path,
            {
                "artifact_type": "replay-attempt",
                "schema_version": 1,
                "case_id": case_id,
                "role": role,
                "lane_id": lane_id,
                "attempt_number": 1,
                "starting_input_sha256": ZERO_SHA,
                "oracle_version": template["oracle_version"],
                "isolation_level": "DECLARED_ONLY",
                "attempt_status": "COMPLETED",
                "environment": {
                    "staging_root": str(staging_root.resolve()),
                    "output_root": str(output_root.resolve()),
                    "pwd": str(staging_root.resolve()),
                    "staging_root_realpath": str(staging_root.resolve()),
                    "output_root_realpath": str(output_root.resolve()),
                    "resolved_runtime_root": str(runtime_root.resolve()),
                    "tool_versions": {"python": "synthetic-3"},
                    "staged_files": staged_files,
                    "staged_manifest_digest": digest(staged_files),
                },
                "actual_read_declaration": [
                    {
                        "path": "input.txt",
                        "sha256": staged_files[0]["sha256"],
                        "authorization_result": "AUTHORIZED_STAGED",
                    },
                    {
                        "path": str((runtime_root / "mandatory-runtime.md").resolve()),
                        "sha256": file_digest(runtime_root / "mandatory-runtime.md"),
                        "authorization_result": "AUTHORIZED_INHERITED",
                    },
                ],
                "commands": ["read staged input", "write canonical output"],
                "business_fact_keys_received": [fact["fact_key"]],
                "output_refs": [
                    run_ref(f"{attempt_base}/transcript.json"),
                    run_ref(f"{attempt_base}/artifact-manifest.json"),
                ],
                "continue_stop_return": "return",
                "contamination_findings": [],
            },
        )
        lane_path = f"{lane_base}/replay-lane.json"
        write_json(
            run_root / lane_path,
            {
                "artifact_type": "replay-lane",
                "schema_version": 1,
                "case_id": case_id,
                "role": role,
                "lane_id": lane_id,
                "ordered_attempt_refs": [run_ref(attempt_path)],
                "terminal_condition": "DECISIVE",
                "decisive_attempt_ref": run_ref(attempt_path),
            },
        )
        lane_refs.append(run_ref(lane_path))
        decisive_refs.append(run_ref(attempt_path))

    write_json(
        run_root / f"roles/{role}/divergence-review.json",
        {
            "artifact_type": "divergence-review",
            "schema_version": 1,
            "case_id": case_id,
            "role": role,
            "lane_refs": copy.deepcopy(lane_refs),
            "comparisons": [
                {
                    "subject": "root problem and success standard",
                    "classification": "ALLOWED_VARIATION",
                    "lane_evidence_refs": [
                        run_ref(f"roles/{role}/executor-a/attempt-1/transcript.json"),
                        run_ref(f"roles/{role}/executor-b/attempt-1/transcript.json"),
                    ],
                    "impact": "No decision-changing drift.",
                    "owner": "evaluation-reviewer",
                }
            ],
            "blocking_findings": [],
        },
    )
    write_json(
        run_root / f"roles/{role}/oracle-review.json",
        {
            "artifact_type": "oracle-review",
            "schema_version": 1,
            "case_id": case_id,
            "role": role,
            "lane_refs": copy.deepcopy(lane_refs),
            "field_checks": [
                {
                    "artifact_field_ref": "brief.json:$.root_problem",
                    "oracle_atom_ids": [template["oracle_atoms"][0]["atom_id"]],
                    "fact_class": "fact",
                    "result": "MATCH",
                    "evidence_refs": [copy.deepcopy(approval_ref)],
                }
            ],
            "historical_implementation_boundary": "Synthetic history supports shape only and owns no business truth.",
        },
    )
    write_json(
        run_root / f"roles/{role}/downstream-consumption.json",
        {
            "artifact_type": "downstream-consumption",
            "schema_version": 1,
            "case_id": case_id,
            "producer_role": role,
            "consumer_role": "product-manager",
            "candidate_results": [
                {
                    "lane_id": lane_id,
                    "input_status": "CANONICAL_HANDOFF",
                    "consumer_action": "Consume the synthetic Director baseline.",
                    "checks": ["single source", "confirmed facts", "unknowns"],
                    "evidence_refs": [
                        run_ref(
                            f"roles/{role}/executor-{lane_id}/attempt-1/canonical/brief.json"
                        )
                    ],
                }
                for lane_id in ("a", "b")
            ],
        },
    )

    verdict_path = f"roles/{role}/role-verdict.json"
    write_json(
        run_root / verdict_path,
        {
            "artifact_type": "role-verdict",
            "schema_version": 1,
            "case_id": case_id,
            "role": role,
            "verdict_scope": "case_bounded_content_readiness",
            "skill_revision": head,
            "audit_report_ref": run_ref(f"roles/{role}/content-audit-report.json"),
            "decisive_attempt_refs": decisive_refs,
            "isolation_level": "DECLARED_ONLY",
            "oracle_bridge_used": False,
            "open_p0_p1": 0,
            "verdict": "BLOCKED_ISOLATION",
            "reason_codes": ["DECLARED_ONLY_RUNTIME"],
            "evidence_refs": [
                run_ref(f"roles/{role}/surface.json"),
                run_ref(f"roles/{role}/content-audit-report.json"),
                *copy.deepcopy(decisive_refs),
                run_ref(f"roles/{role}/divergence-review.json"),
                run_ref(f"roles/{role}/oracle-review.json"),
                run_ref(f"roles/{role}/downstream-consumption.json"),
            ],
            "claim_boundaries": [
                "Synthetic fixture only.",
                "Declared-only isolation cannot support content pass.",
            ],
            "next_decision": "Provide observed or enforced isolation before pass.",
            "content_digest": ZERO_SHA,
            "inherited_runtime_digest": ZERO_SHA,
        },
    )

    role_ref_paths = [
        f"roles/{role}/surface.json",
        f"roles/{role}/decision-atoms.json",
        f"roles/{role}/content-audit-alignment.json",
        f"roles/{role}/content-audit-report.json",
        f"roles/{role}/executor-a/replay-lane.json",
        f"roles/{role}/executor-b/replay-lane.json",
        f"roles/{role}/executor-a/attempt-1/replay-attempt.json",
        f"roles/{role}/executor-a/attempt-1/transcript.json",
        f"roles/{role}/executor-a/attempt-1/artifact-manifest.json",
        f"roles/{role}/executor-b/attempt-1/replay-attempt.json",
        f"roles/{role}/executor-b/attempt-1/transcript.json",
        f"roles/{role}/executor-b/attempt-1/artifact-manifest.json",
        f"roles/{role}/divergence-review.json",
        f"roles/{role}/oracle-review.json",
        f"roles/{role}/downstream-consumption.json",
        verdict_path,
    ]
    run_payload = {
        "artifact_type": "run",
        "schema_version": 1,
        "run_id": "SYNTHETIC-PD-RUN-001",
        "case_id": case_id,
        "evaluation_only": True,
        "lifecycle_status": "CLOSED",
        "current_stage": "ROLE_VERDICT",
        "active_role": role,
        "primary_roles": PRIMARY_ROLES,
        "evaluated_roles": [role],
        "case_refs": {
            "confirmation": run_ref("case/confirmation-ref.json"),
            "input": run_ref("case/input-manifest.json"),
            "oracle": run_ref("case/oracle-manifest.json"),
            "source_classification": run_ref("case/source-classification.json"),
        },
        "role_refs": {role: [run_ref(path) for path in role_ref_paths]},
        "isolation_assessment": {
            "level": "DECLARED_ONLY",
            "reason_codes": ["UNOBSERVABLE_SYSTEM_INJECTION"],
            "evidence_refs": [run_ref(f"roles/{role}/surface.json")],
        },
        "global_state": "BLOCKED_ISOLATION",
        "primary_role_outcome": {role: "BLOCKED_ISOLATION"},
        "next_authorized_action": "isolation harness design",
        "closure_validation_stage": "role-verdict",
    }
    write_json(run_root / "run.json", run_payload)

    source_roots = {key: Path(value["root"]) for key, value in sources.items()}
    source_roots["synthetic-runtime"] = runtime_root
    immutable_bytes_cache: dict[bytes, bytes] = {}
    blob_cache: dict[tuple[str, str, str], str] = {}
    refresh_refs(
        repo_root,
        run_root,
        source_roots,
        immutable_bytes_cache,
        blob_cache,
    )
    recompute_derived(run_root)
    refresh_refs(
        repo_root,
        run_root,
        source_roots,
        immutable_bytes_cache,
        blob_cache,
    )
    recompute_derived(run_root)
    refresh_refs(
        repo_root,
        run_root,
        source_roots,
        immutable_bytes_cache,
        blob_cache,
    )
    return {key: str(value) for key, value in source_roots.items()}


def iter_refs(value: object):
    if isinstance(value, dict):
        if {"scope", "path", "sha256"} <= set(value):
            yield value
        for child in value.values():
            yield from iter_refs(child)
    elif isinstance(value, list):
        for child in value:
            yield from iter_refs(child)


def refresh_run_refs_in_owner(
    run_root: Path, owner_relative: str, target_relatives: list[str]
) -> None:
    owner_path = run_root / owner_relative
    owner = read_json(owner_path)
    target_digests = {
        relative: file_digest(run_root / relative) for relative in target_relatives
    }
    matched: set[str] = set()
    for ref in iter_refs(owner):
        relative = ref.get("path")
        if ref.get("scope") == "run" and relative in target_digests:
            ref["sha256"] = target_digests[relative]
            matched.add(relative)
    missing = set(target_relatives) - matched
    if missing:
        raise ValueError(
            f"{owner_relative}: missing owner refs for {sorted(missing)}"
        )
    write_json(owner_path, owner)


def ref_bytes(
    repo_root: Path,
    run_root: Path,
    source_roots: dict[str, Path],
    ref: dict[str, Any],
    immutable_bytes_cache: dict[bytes, bytes] | None = None,
) -> bytes:
    scope = ref["scope"]
    if scope == "repo":
        root = repo_root
    elif scope == "run":
        root = run_root
    elif scope == "external_repo":
        root = source_roots[ref["source_id"]]
    else:
        raise ValueError(f"unsupported scope in fixture: {scope}")
    cache_key = canonical_bytes(
        {
            key: ref[key]
            for key in ("scope", "source_id", "path", "commit", "blob", "line")
            if key in ref
        }
    )
    if scope != "run" and immutable_bytes_cache is not None:
        cached = immutable_bytes_cache.get(cache_key)
        if cached is not None:
            return cached
    if "commit" in ref:
        raw = subprocess.check_output(
            ["git", "-C", str(root), "show", f"{ref['commit']}:{ref['path']}"],
            stderr=subprocess.DEVNULL,
        )
    else:
        raw = (root / ref["path"]).read_bytes()
    if scope != "run" and immutable_bytes_cache is not None:
        immutable_bytes_cache[cache_key] = raw
    return raw


def refresh_refs(
    repo_root: Path,
    run_root: Path,
    source_roots: dict[str, Path],
    immutable_bytes_cache: dict[bytes, bytes] | None = None,
    blob_cache: dict[tuple[str, str, str], str] | None = None,
) -> None:
    immutable_bytes_cache = (
        {} if immutable_bytes_cache is None else immutable_bytes_cache
    )
    blob_cache = {} if blob_cache is None else blob_cache
    paths = sorted(run_root.rglob("*.json"))
    for _ in range(32):
        changed = False
        for path in paths:
            payload = read_json(path)
            before = canonical_bytes(payload)
            for ref in iter_refs(payload):
                # Cases mutate only the run tree. Re-reading frozen repo/external
                # refs would waste a Git process per ref, while refreshing a
                # deliberately malformed immutable ref would hide the negative.
                if ref["scope"] != "run" and ref.get("sha256") != ZERO_SHA:
                    continue
                try:
                    raw = ref_bytes(
                        repo_root,
                        run_root,
                        source_roots,
                        ref,
                        immutable_bytes_cache,
                    )
                except (KeyError, OSError, ValueError, subprocess.SubprocessError):
                    # Negative cases deliberately leave one malformed leaf ref. The
                    # fixture refresher still updates owning artifact refs so the
                    # production validator, not test setup, owns that rejection.
                    continue
                ref["sha256"] = hashlib.sha256(raw).hexdigest()
                if "commit" in ref and "blob" not in ref:
                    root = (
                        repo_root
                        if ref["scope"] == "repo"
                        else source_roots[ref["source_id"]]
                    )
                    blob_key = (str(root), ref["commit"], ref["path"])
                    if blob_key not in blob_cache:
                        blob_cache[blob_key] = git_blob(
                            root, ref["commit"], ref["path"]
                        )
                    ref["blob"] = blob_cache[blob_key]
            if before != canonical_bytes(payload):
                write_json(path, payload)
                changed = True
        if not changed:
            return
    raise RuntimeError("fixture refs did not reach a stable digest state")


def recompute_derived(run_root: Path) -> None:
    surface_path = run_root / "roles/product-director/surface.json"
    oracle_path = run_root / "case/oracle-manifest.json"
    input_path = run_root / "case/input-manifest.json"
    verdict_path = run_root / "roles/product-director/role-verdict.json"
    surface = read_json(surface_path)
    oracle = read_json(oracle_path)
    input_manifest = read_json(input_path)
    runtime = surface["runtime_inheritance"]
    content_projection = sorted(
        (item["ref"] for item in surface["files"]),
        key=lambda item: canonical_bytes(item),
    )
    proxy_projection = {
        item["fact_key"]: {
            "fact_class": item["fact_class"],
            "answer_text": item["answer_text"],
            "authority_refs": item["authority_refs"],
        }
        for item in sorted(
            oracle["business_proxy_facts"], key=lambda item: item["fact_key"]
        )
    }
    runtime_projection = {
        "declared_mandatory_refs": sorted(
            runtime["declared_mandatory_refs"], key=lambda item: canonical_bytes(item)
        ),
        "harness_descriptor": runtime["harness_descriptor"],
    }
    content_digest = digest(content_projection)
    fact_digest = digest(proxy_projection)
    runtime_digest = digest(runtime_projection)
    input_manifest["product_director_content_digest"] = content_digest
    input_manifest["authorized_business_proxy_fact_key_digest"] = fact_digest
    input_manifest["inherited_runtime_digest"] = runtime_digest
    starting_projection = {
        "starting_clue": input_manifest["starting_clue"],
        "product_director_content_digest": content_digest,
        "inherited_runtime_digest": runtime_digest,
        "oracle_version": input_manifest["oracle_version"],
        "authorized_business_proxy_fact_key_digest": fact_digest,
    }
    input_manifest["starting_input_sha256"] = digest(starting_projection)
    write_json(input_path, input_manifest)
    runtime["inherited_runtime_digest"] = runtime_digest
    write_json(surface_path, surface)
    verdict = read_json(verdict_path)
    verdict["content_digest"] = content_digest
    verdict["inherited_runtime_digest"] = runtime_digest
    write_json(verdict_path, verdict)
    for lane_id in ("a", "b"):
        attempt_path = (
            run_root
            / f"roles/product-director/executor-{lane_id}/attempt-1/replay-attempt.json"
        )
        attempt = read_json(attempt_path)
        attempt["starting_input_sha256"] = input_manifest["starting_input_sha256"]
        attempt["environment"]["staged_manifest_digest"] = digest(
            attempt["environment"]["staged_files"]
        )
        write_json(attempt_path, attempt)


def command_build(args: argparse.Namespace) -> None:
    run_root = Path(args.run_root).resolve()
    runtime_root = Path(args.runtime_root).resolve()
    source_roots = build_run(
        Path(args.repo_root).resolve(),
        Path(args.template).resolve(),
        run_root,
        runtime_root,
        Path(args.descriptor).resolve(),
        [Path(path).resolve() for path in args.denominator],
    )
    for relative in (
        "roles/product-director/surface.json",
        "roles/product-director/executor-a/attempt-1/replay-attempt.json",
    ):
        shadow = runtime_root / relative
        shadow.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(run_root / relative, shadow)
    write_json(Path(args.source_roots_output), source_roots)


def load_source_roots(path: Path) -> dict[str, Path]:
    return {key: Path(value) for key, value in read_json(path).items()}


def command_refresh(args: argparse.Namespace) -> None:
    refresh_refs(
        Path(args.repo_root).resolve(),
        Path(args.run_root).resolve(),
        load_source_roots(Path(args.source_roots).resolve()),
    )


def remove_tree(path: Path) -> None:
    if path.is_dir():
        shutil.rmtree(path)
    elif path.exists():
        path.unlink()


def set_product_director_role_refs(
    run_root: Path, relative_paths: list[str]
) -> None:
    run_path = run_root / "run.json"
    run = read_json(run_path)
    run["role_refs"]["product-director"] = [
        run_ref(f"roles/product-director/{path}") for path in relative_paths
    ]
    write_json(run_path, run)


def index_present_product_director_artifacts(run_root: Path) -> None:
    role_root = run_root / "roles/product-director"
    relative_paths = sorted(
        str(path.relative_to(role_root))
        for path in role_root.rglob("*")
        if path.is_file()
        and path.name in ROLE_EVALUATION_FILENAMES
        and "canonical" not in path.parts
    )
    set_product_director_role_refs(run_root, relative_paths)


def clear_replay_and_reviews(run_root: Path) -> None:
    role_root = run_root / "roles/product-director"
    for relative in (
        "executor-a",
        "executor-b",
        "divergence-review.json",
        "oracle-review.json",
        "downstream-consumption.json",
    ):
        remove_tree(role_root / relative)


def copy_attempt(
    run_root: Path,
    lane_id: str,
    source_number: int,
    target_number: int,
) -> tuple[Path, Path, Path]:
    role_root = run_root / "roles/product-director"
    source = role_root / f"executor-{lane_id}/attempt-{source_number}"
    target = role_root / f"executor-{lane_id}/attempt-{target_number}"
    shutil.copytree(source, target)
    attempt_path = target / "replay-attempt.json"
    transcript_path = target / "transcript.json"
    manifest_path = target / "artifact-manifest.json"
    attempt = read_json(attempt_path)
    attempt["attempt_number"] = target_number
    attempt["output_refs"] = [
        run_ref(
            f"roles/product-director/executor-{lane_id}/attempt-{target_number}/transcript.json"
        ),
        run_ref(
            f"roles/product-director/executor-{lane_id}/attempt-{target_number}/artifact-manifest.json"
        ),
    ]
    write_json(attempt_path, attempt)
    transcript = read_json(transcript_path)
    transcript["attempt_number"] = target_number
    write_json(transcript_path, transcript)
    manifest = read_json(manifest_path)
    manifest["attempt_number"] = target_number
    canonical_refs = manifest["canonical_output_refs"]
    rewritten_refs = []
    for ref in canonical_refs:
        rewritten = copy.deepcopy(ref)
        rewritten["path"] = rewritten["path"].replace(
            f"attempt-{source_number}/", f"attempt-{target_number}/"
        )
        rewritten_refs.append(rewritten)
    manifest["canonical_output_refs"] = rewritten_refs
    write_json(manifest_path, manifest)
    return attempt_path, transcript_path, manifest_path


def make_non_output_attempt(
    attempt_path: Path, manifest_path: Path, status: str
) -> None:
    attempt = read_json(attempt_path)
    attempt["attempt_status"] = status
    attempt["output_refs"] = []
    write_json(attempt_path, attempt)
    manifest = read_json(manifest_path)
    manifest["canonical_output_refs"] = []
    write_json(manifest_path, manifest)


def append_completed_retry(run_root: Path) -> None:
    role_root = run_root / "roles/product-director"
    copy_attempt(run_root, "a", 1, 2)
    attempt_2_ref = run_ref(
        "roles/product-director/executor-a/attempt-2/replay-attempt.json"
    )
    lane_path = role_root / "executor-a/replay-lane.json"
    lane = read_json(lane_path)
    lane["ordered_attempt_refs"].append(copy.deepcopy(attempt_2_ref))
    lane["decisive_attempt_ref"] = copy.deepcopy(attempt_2_ref)
    write_json(lane_path, lane)

    verdict_path = role_root / "role-verdict.json"
    verdict = read_json(verdict_path)
    verdict["decisive_attempt_refs"][0] = copy.deepcopy(attempt_2_ref)
    for ref in verdict["evidence_refs"]:
        if ref["path"] == (
            "roles/product-director/executor-a/attempt-1/replay-attempt.json"
        ):
            ref["path"] = attempt_2_ref["path"]
    write_json(verdict_path, verdict)

    downstream_path = role_root / "downstream-consumption.json"
    downstream = read_json(downstream_path)
    downstream["candidate_results"][0]["evidence_refs"][0]["path"] = (
        "roles/product-director/executor-a/attempt-2/canonical/brief.json"
    )
    write_json(downstream_path, downstream)
    index_present_product_director_artifacts(run_root)


def set_closed_track(
    run_root: Path,
    *,
    current_stage: str,
    closure_stage: str,
    global_state: str,
    role_outcome: str | None,
    next_action: str,
) -> None:
    path = run_root / "run.json"
    run = read_json(path)
    run["lifecycle_status"] = "CLOSED"
    run["current_stage"] = current_stage
    run["closure_validation_stage"] = closure_stage
    run["global_state"] = global_state
    run["next_authorized_action"] = next_action
    if role_outcome is None:
        run.pop("primary_role_outcome", None)
    else:
        run["primary_role_outcome"] = {"product-director": role_outcome}
    write_json(path, run)


def set_open_track(run_root: Path, current_stage: str) -> None:
    path = run_root / "run.json"
    run = read_json(path)
    run["lifecycle_status"] = "OPEN"
    run["current_stage"] = current_stage
    for field in (
        "global_state",
        "primary_role_outcome",
        "next_authorized_action",
        "closure_validation_stage",
    ):
        run.pop(field, None)
    write_json(path, run)


def set_role_verdict_value(run_root: Path, verdict_value: str) -> None:
    role_root = run_root / "roles/product-director"
    path = role_root / "role-verdict.json"
    verdict = read_json(path)
    verdict["verdict"] = verdict_value
    verdict["reason_codes"] = [f"SYNTHETIC_{verdict_value}"]
    write_json(path, verdict)
    set_closed_track(
        run_root,
        current_stage="ROLE_VERDICT",
        closure_stage="role-verdict",
        global_state="BLOCKED_ISOLATION",
        role_outcome=verdict_value,
        next_action=(
            "repair design"
            if verdict_value == "CONTENT_FAIL"
            else "isolation harness design"
            if verdict_value == "BLOCKED_ISOLATION"
            else "Oracle/evidence resolution"
        ),
    )


def make_lane_contaminated_history(
    run_root: Path, lane_id: str, attempt_count: int
) -> None:
    role_root = run_root / "roles/product-director"
    for number in range(2, attempt_count + 1):
        copy_attempt(run_root, lane_id, 1, number)
    ordered_refs = []
    for number in range(1, attempt_count + 1):
        attempt_root = role_root / f"executor-{lane_id}/attempt-{number}"
        make_non_output_attempt(
            attempt_root / "replay-attempt.json",
            attempt_root / "artifact-manifest.json",
            "VOID_CONTAMINATED",
        )
        attempt = read_json(attempt_root / "replay-attempt.json")
        attempt["contamination_findings"] = [
            "Synthetic unauthorized read contamination."
        ]
        write_json(attempt_root / "replay-attempt.json", attempt)
        remove_tree(attempt_root / "canonical")
        ordered_refs.append(
            run_ref(
                f"roles/product-director/executor-{lane_id}/attempt-{number}/replay-attempt.json"
            )
        )
    lane_path = role_root / f"executor-{lane_id}/replay-lane.json"
    lane = read_json(lane_path)
    lane["ordered_attempt_refs"] = ordered_refs
    lane["terminal_condition"] = "ALL_CONTAMINATED"
    lane.pop("decisive_attempt_ref", None)
    write_json(lane_path, lane)


def clear_branch_d_reviews(run_root: Path) -> None:
    role_root = run_root / "roles/product-director"
    for relative in (
        "divergence-review.json",
        "oracle-review.json",
        "downstream-consumption.json",
    ):
        remove_tree(role_root / relative)


def remove_formal_report(run_root: Path) -> None:
    role_root = run_root / "roles/product-director"
    for relative in ("content-audit-report.json", "content-audit-summary.md"):
        remove_tree(role_root / relative)


def set_branch_c_p1_audit(run_root: Path) -> None:
    role_root = run_root / "roles/product-director"
    alignment_path = role_root / "content-audit-alignment.json"
    alignment = read_json(alignment_path)
    alignment["capability_match_draft"]["gaps"][0]["status"] = "partial"
    write_json(alignment_path, alignment)

    evidence_path = (
        "docs/superpowers/specs/"
        "2026-07-14--standard-chain-manual-content-readiness-evaluation--approval-record.md"
    )
    finding = {
        "id": "SC-PD-P1-001",
        "severity": "P1",
        "title": "Static content readiness defect",
        "confirmed_gap_refs": ["GAP-001"],
        "evidence_level": "E2",
        "evidence": f"{evidence_path}:8 records the approved evaluation boundary.",
        "evidence_checks": [
            {
                "path": evidence_path,
                "line": 8,
                "expected_snippet": "批准设计",
                "claim": "The approved boundary is present at the cited line.",
            }
        ],
        "claim_review": {
            "required_claims": ["The static defect is inside the approved boundary."],
            "refutation_check": f"{evidence_path}:8",
            "status": "supported",
        },
        "severity_calibration": {
            "calibrated_severity": "P1",
            "team_use_impact": "The role cannot be accepted as content-ready.",
            "rationale": "The confirmed static gap blocks the bounded role outcome.",
        },
        "impact": "The role cannot receive a passing content-readiness verdict.",
        "repair_target": "Repair the static instruction defect.",
        "verification_hint": "Repeat the formal static audit after repair.",
    }
    report_path = role_root / "content-audit-report.json"
    report = read_json(report_path)
    report["verdict"] = "conditional"
    report["verdict_reason"] = "One blocking P1 static finding remains open."
    report["findings"] = [finding]
    report["artifact_paths"] = {
        "report_json": str(report_path),
        "summary_markdown": str(role_root / "content-audit-summary.md"),
    }
    report["capability_baseline_ref"] = str(alignment_path)
    report["validation"]["alignment"]["command"] = (
        f"python3 validate_skill_audit_alignment.py {alignment_path}"
    )
    report["validation"]["report"]["command"] = (
        f"python3 validate_skill_audit_report.py {report_path}"
    )
    report["repair_handoff"] = [
        {
            "target": "shared/skills/product-director",
            "action": finding["repair_target"],
            "owner": "product-director maintainer",
        }
    ]
    write_json(report_path, report)
    summary = "\n".join(
        [
            "# Synthetic Product Director content audit",
            "",
            finding["id"],
            finding["severity"],
            finding["title"],
            finding["impact"],
            finding["repair_target"],
            finding["verification_hint"],
            f"{evidence_path}:8",
            "",
        ]
    )
    (role_root / "content-audit-summary.md").write_text(summary, encoding="utf-8")


def set_stopped_attempts(run_root: Path, *, keep_canonical_files: bool) -> None:
    role_root = run_root / "roles/product-director"
    for lane_id in ("a", "b"):
        attempt_root = role_root / f"executor-{lane_id}/attempt-1"
        attempt_path = attempt_root / "replay-attempt.json"
        manifest_path = attempt_root / "artifact-manifest.json"
        attempt = read_json(attempt_path)
        attempt["attempt_status"] = "STOPPED"
        attempt["output_refs"] = []
        attempt["blocking_fact_refs"] = [run_ref("case/oracle-manifest.json")]
        write_json(attempt_path, attempt)
        manifest = read_json(manifest_path)
        manifest["canonical_output_refs"] = []
        write_json(manifest_path, manifest)
        if not keep_canonical_files:
            remove_tree(attempt_root / "canonical")
    downstream_path = role_root / "downstream-consumption.json"
    downstream = read_json(downstream_path)
    for candidate in downstream["candidate_results"]:
        lane_id = candidate["lane_id"]
        candidate["input_status"] = "BLOCKED_UPSTREAM"
        candidate["consumer_action"] = "Wait for the blocking fact to be resolved."
        candidate["evidence_refs"] = [
            run_ref(
                f"roles/product-director/executor-{lane_id}/attempt-1/replay-attempt.json"
            )
        ]
    write_json(downstream_path, downstream)


def mutate(run_root: Path, name: str) -> None:
    role_root = run_root / "roles/product-director"
    input_path = run_root / "case/input-manifest.json"
    surface_path = role_root / "surface.json"
    verdict_path = role_root / "role-verdict.json"
    attempt_a_path = role_root / "executor-a/attempt-1/replay-attempt.json"
    attempt_b_path = role_root / "executor-b/attempt-1/replay-attempt.json"
    lane_a_path = role_root / "executor-a/replay-lane.json"
    lane_b_path = role_root / "executor-b/replay-lane.json"
    transcript_b_path = role_root / "executor-b/attempt-1/transcript.json"

    if name == "absolute_path":
        payload = read_json(input_path)
        payload["executor_visible"][0]["path"] = "/tmp/forbidden"
        write_json(input_path, payload)
    elif name == "parent_escape":
        payload = read_json(input_path)
        payload["executor_visible"][0]["path"] = "../forbidden"
        write_json(input_path, payload)
    elif name == "wrong_scope":
        payload = read_json(input_path)
        payload["executor_visible"][0]["scope"] = "mystery"
        write_json(input_path, payload)
    elif name == "missing_source_root":
        payload = read_json(input_path)
        payload["executor_visible"][0] = external_ref("unmapped-source", "x.txt")
        write_json(input_path, payload)
    elif name == "stale_file_sha":
        payload = read_json(input_path)
        payload["executor_visible"][0]["sha256"] = ZERO_SHA
        write_json(input_path, payload)
    elif name == "stale_approval":
        path = run_root / "case/confirmation-ref.json"
        payload = read_json(path)
        payload["approval_ref"]["line"] = 999
        write_json(path, payload)
    elif name.startswith("source_"):
        path = run_root / "case/source-classification.json"
        payload = read_json(path)
        source = payload["sources"][0]
        if name == "source_missing_commit":
            source["ancestry_commits"].pop()
        elif name == "source_wrong_parent":
            source["source_atoms"][0]["parent_commit"] = ZERO_COMMIT
        elif name == "source_missing_rename_previous":
            rename = next(
                atom
                for atom in source["source_atoms"]
                if atom["change_status"].startswith("R")
            )
            rename.pop("previous_path", None)
        elif name == "source_duplicate_atom":
            source["source_atoms"].append(copy.deepcopy(source["source_atoms"][0]))
        write_json(path, payload)
    elif name == "lane_starting_input":
        payload = read_json(attempt_b_path)
        payload["starting_input_sha256"] = ZERO_SHA
        write_json(attempt_b_path, payload)
    elif name in {"business_answer_drift", "business_message_drift"}:
        payload = read_json(transcript_b_path)
        proxy_turn = payload["turns"][1]
        if name == "business_answer_drift":
            proxy_turn["answers"][0]["answer_text"] = "A different owner."
            proxy_turn["message"] = canonical_bytes(proxy_turn["answers"]).decode(
                "utf-8"
            )
        else:
            proxy_turn["message"] = "{}"
        write_json(transcript_b_path, payload)
    elif name == "stale_proxy_digest":
        path = run_root / "case/oracle-manifest.json"
        payload = read_json(path)
        payload["business_proxy_facts"][0]["answer_text"] = "Changed baseline."
        write_json(path, payload)
    elif name == "stale_runtime_digest":
        payload = read_json(surface_path)
        payload["runtime_inheritance"]["harness_descriptor"]["version"] = "2"
        write_json(surface_path, payload)
    elif name == "stale_starting_input":
        payload = read_json(input_path)
        payload["starting_input_sha256"] = ZERO_SHA
        write_json(input_path, payload)
    elif name in {"duplicate_proxy_fact_conflict", "duplicate_proxy_fact_exact"}:
        path = run_root / "case/oracle-manifest.json"
        oracle = read_json(path)
        duplicate = copy.deepcopy(oracle["business_proxy_facts"][0])
        if name == "duplicate_proxy_fact_conflict":
            duplicate["answer_text"] = "Conflicting duplicate answer."
            oracle["business_proxy_facts"].insert(0, duplicate)
        else:
            oracle["business_proxy_facts"].append(duplicate)
        write_json(path, oracle)
        refresh_run_refs_in_owner(
            run_root,
            "case/input-manifest.json",
            ["case/oracle-manifest.json"],
        )
        refresh_run_refs_in_owner(
            run_root,
            "run.json",
            ["case/oracle-manifest.json", "case/input-manifest.json"],
        )
    elif name == "unresolved_runtime":
        payload = read_json(surface_path)
        payload["runtime_inheritance"]["unresolved_file_inputs"] = [
            {
                "input_id": "HOME-RULES",
                "reason": "Synthetic unresolved inherited file.",
            }
        ]
        write_json(surface_path, payload)
    elif name == "unauthorized_read":
        payload = read_json(attempt_a_path)
        payload["actual_read_declaration"].append(
            {
                "path": "/tmp/not-authorized.txt",
                "sha256": ZERO_SHA,
                "authorization_result": "AUTHORIZED_STAGED",
            }
        )
        write_json(attempt_a_path, payload)
    elif name == "contaminated_decisive":
        payload = read_json(attempt_a_path)
        payload["attempt_status"] = "VOID_CONTAMINATED"
        write_json(attempt_a_path, payload)
    elif name == "attempt_limit":
        lane = read_json(lane_a_path)
        original = read_json(attempt_a_path)
        for number in (2, 3, 4):
            attempt = copy.deepcopy(original)
            attempt["attempt_number"] = number
            path = f"roles/product-director/executor-a/attempt-{number}/replay-attempt.json"
            write_json(run_root / path, attempt)
            lane["ordered_attempt_refs"].append(run_ref(path))
        lane["decisive_attempt_ref"] = copy.deepcopy(lane["ordered_attempt_refs"][-1])
        write_json(lane_a_path, lane)
    elif name == "attempt_history_gap":
        lane = read_json(lane_a_path)
        attempt = read_json(attempt_a_path)
        attempt["attempt_number"] = 3
        path = "roles/product-director/executor-a/attempt-3/replay-attempt.json"
        write_json(run_root / path, attempt)
        lane["ordered_attempt_refs"].append(run_ref(path))
        write_json(lane_a_path, lane)
    elif name in {"completed_after_completed", "completed_after_stopped"}:
        append_completed_retry(run_root)
        if name == "completed_after_stopped":
            manifest_path = role_root / "executor-a/attempt-1/artifact-manifest.json"
            make_non_output_attempt(attempt_a_path, manifest_path, "STOPPED")
            attempt = read_json(attempt_a_path)
            attempt["blocking_fact_refs"] = [run_ref("case/oracle-manifest.json")]
            write_json(attempt_a_path, attempt)
            remove_tree(role_root / "executor-a/attempt-1/canonical")
    elif name == "infra_decisive":
        payload = read_json(attempt_a_path)
        payload["attempt_status"] = "INFRA_FAILURE"
        write_json(attempt_a_path, payload)
    elif name == "infra_nondecisive_outputs":
        attempt_2_path, _, _ = copy_attempt(run_root, "a", 1, 2)
        first = read_json(attempt_a_path)
        first["attempt_status"] = "INFRA_FAILURE"
        write_json(attempt_a_path, first)
        lane = read_json(lane_a_path)
        attempt_2_ref = run_ref(
            "roles/product-director/executor-a/attempt-2/replay-attempt.json"
        )
        lane["ordered_attempt_refs"].append(copy.deepcopy(attempt_2_ref))
        lane["decisive_attempt_ref"] = copy.deepcopy(attempt_2_ref)
        write_json(lane_a_path, lane)
        verdict = read_json(verdict_path)
        verdict["decisive_attempt_refs"][0] = copy.deepcopy(attempt_2_ref)
        for ref in verdict["evidence_refs"]:
            if ref["path"] == (
                "roles/product-director/executor-a/attempt-1/replay-attempt.json"
            ):
                ref["path"] = attempt_2_ref["path"]
        write_json(verdict_path, verdict)
        downstream_path = role_root / "downstream-consumption.json"
        downstream = read_json(downstream_path)
        downstream["candidate_results"][0]["evidence_refs"][0]["path"] = (
            "roles/product-director/executor-a/attempt-2/canonical/brief.json"
        )
        write_json(downstream_path, downstream)
        index_present_product_director_artifacts(run_root)
    elif name == "immutable_retry_history":
        copy_attempt(run_root, "a", 1, 3)
        attempt_2_path, _, manifest_2_path = copy_attempt(run_root, "a", 1, 2)
        make_non_output_attempt(
            attempt_a_path,
            role_root / "executor-a/attempt-1/artifact-manifest.json",
            "VOID_CONTAMINATED",
        )
        make_non_output_attempt(attempt_2_path, manifest_2_path, "INFRA_FAILURE")
        remove_tree(role_root / "executor-a/attempt-1/canonical")
        remove_tree(role_root / "executor-a/attempt-2/canonical")
        lane = read_json(lane_a_path)
        lane["ordered_attempt_refs"] = [
            run_ref(
                f"roles/product-director/executor-a/attempt-{number}/replay-attempt.json"
            )
            for number in (1, 2, 3)
        ]
        lane["decisive_attempt_ref"] = copy.deepcopy(
            lane["ordered_attempt_refs"][-1]
        )
        write_json(lane_a_path, lane)
        verdict = read_json(verdict_path)
        verdict["decisive_attempt_refs"][0] = copy.deepcopy(
            lane["decisive_attempt_ref"]
        )
        for ref in verdict["evidence_refs"]:
            if ref["path"] == (
                "roles/product-director/executor-a/attempt-1/replay-attempt.json"
            ):
                ref["path"] = lane["decisive_attempt_ref"]["path"]
        write_json(verdict_path, verdict)
        downstream_path = role_root / "downstream-consumption.json"
        downstream = read_json(downstream_path)
        downstream["candidate_results"][0]["evidence_refs"][0]["path"] = (
            "roles/product-director/executor-a/attempt-3/canonical/brief.json"
        )
        write_json(downstream_path, downstream)
        index_present_product_director_artifacts(run_root)
    elif name == "content_pass_declared":
        payload = read_json(verdict_path)
        payload["verdict"] = "CONTENT_PASS"
        write_json(verdict_path, payload)
    elif name == "isolation_spoof_pass":
        verdict = read_json(verdict_path)
        verdict["verdict"] = "CONTENT_PASS"
        verdict["isolation_level"] = "OBSERVED"
        write_json(verdict_path, verdict)
        run_path = run_root / "run.json"
        run = read_json(run_path)
        run["primary_role_outcome"]["product-director"] = "CONTENT_PASS"
        write_json(run_path, run)
    elif name == "missing_baseline":
        payload = read_json(verdict_path)
        payload.pop("content_digest")
        write_json(verdict_path, payload)
    elif name == "partial_baseline":
        payload = read_json(verdict_path)
        payload["content_digest"] = "partial"
        write_json(verdict_path, payload)
    elif name == "bridge_pass":
        payload = read_json(verdict_path)
        payload["verdict"] = "CONTENT_PASS"
        payload["isolation_level"] = "OBSERVED"
        payload["oracle_bridge_used"] = True
        write_json(verdict_path, payload)
    elif name == "canonical_metadata":
        path = role_root / "executor-a/attempt-1/canonical/brief.json"
        payload = read_json(path)
        payload["evaluation_only"] = True
        write_json(path, payload)
    elif name == "ghost_staged_file":
        for attempt_path in (attempt_a_path, attempt_b_path):
            attempt = read_json(attempt_path)
            attempt["environment"]["staged_files"].append(
                {"path": "ghost.txt", "sha256": ZERO_SHA}
            )
            attempt["environment"]["staged_files"].sort(
                key=lambda item: item["path"]
            )
            attempt["environment"]["staged_manifest_digest"] = digest(
                attempt["environment"]["staged_files"]
            )
            write_json(attempt_path, attempt)
    elif name == "relative_staging_root":
        for attempt_path in (attempt_a_path, attempt_b_path):
            attempt = read_json(attempt_path)
            attempt["environment"]["staging_root"] = "relative-staging"
            write_json(attempt_path, attempt)
    elif name in {
        "cross_case_identity",
        "cross_role_identity",
        "wrong_lane_identity",
        "wrong_attempt_identity",
    }:
        if name == "cross_case_identity":
            path = role_root / "executor-a/attempt-1/transcript.json"
            payload = read_json(path)
            payload["case_id"] = "OTHER-CASE"
        elif name == "cross_role_identity":
            path = role_root / "executor-a/attempt-1/artifact-manifest.json"
            payload = read_json(path)
            payload["role"] = "product-manager"
        elif name == "wrong_lane_identity":
            path = role_root / "executor-a/attempt-1/transcript.json"
            payload = read_json(path)
            payload["lane_id"] = "b"
        else:
            path = role_root / "executor-a/attempt-1/artifact-manifest.json"
            payload = read_json(path)
            payload["attempt_number"] = 2
        write_json(path, payload)
    elif name == "input_oracle_version_drift":
        payload = read_json(input_path)
        payload["oracle_version"] = "synthetic-oracle/v2"
        write_json(input_path, payload)
        recompute_derived(run_root)
    elif name == "attempt_oracle_version_drift":
        payload = read_json(attempt_a_path)
        payload["oracle_version"] = "synthetic-oracle/v2"
        write_json(attempt_a_path, payload)
    elif name == "schema_invalid_case_refs":
        path = run_root / "run.json"
        payload = read_json(path)
        payload["case_refs"] = []
        write_json(path, payload)
    elif name == "not_run_placeholder":
        path = run_root / "run.json"
        payload = read_json(path)
        payload["primary_role_outcome"]["product-director"] = "NOT_RUN"
        write_json(path, payload)
    elif name == "child_report_failure":
        path = role_root / "content-audit-report.json"
        payload = read_json(path)
        payload["overall_score"] = 99
        write_json(path, payload)
    elif name == "child_alignment_failure":
        path = role_root / "content-audit-alignment.json"
        payload = read_json(path)
        payload["stage"] = "draft"
        write_json(path, payload)
    elif name == "early_chain_verdict":
        write_json(
            run_root / "chain-verdict.json",
            {
                "artifact_type": "chain-verdict",
                "schema_version": 1,
                "case_id": read_json(run_root / "run.json")["case_id"],
                "role_verdict_refs": [run_ref(str(verdict_path.relative_to(run_root)))],
                "isolation_level": "OBSERVED",
                "oracle_bridge_used": False,
                "verdict": "CASE_REPLAY_PASS",
                "evidence_refs": [run_ref(str(verdict_path.relative_to(run_root)))],
            },
        )
    elif name == "replay_pass_state_only":
        path = run_root / "run.json"
        payload = read_json(path)
        payload["global_state"] = "CASE_REPLAY_PASS"
        write_json(path, payload)
    elif name == "unsupported_role_verdict":
        payload = read_json(verdict_path)
        payload["verdict"] = "READY_FOR_BEHAVIOR_EVAL"
        write_json(verdict_path, payload)
    elif name == "unsupported_chain_verdict":
        mutate(run_root, "early_chain_verdict")
        path = run_root / "chain-verdict.json"
        payload = read_json(path)
        payload["verdict"] = "READY_FOR_BEHAVIOR_EVAL"
        write_json(path, payload)
    elif name == "direct_static_content_fail":
        clear_replay_and_reviews(run_root)
        set_branch_c_p1_audit(run_root)
        verdict = read_json(verdict_path)
        verdict["verdict"] = "CONTENT_FAIL"
        verdict["open_p0_p1"] = 1
        verdict["decisive_attempt_refs"] = []
        verdict["reason_codes"] = ["STATIC_AUDIT_CONTENT_DEFECT"]
        verdict["evidence_refs"] = [
            run_ref("roles/product-director/surface.json"),
            run_ref("roles/product-director/decision-atoms.json"),
            run_ref("roles/product-director/content-audit-report.json"),
        ]
        write_json(verdict_path, verdict)
        set_closed_track(
            run_root,
            current_stage="ROLE_VERDICT",
            closure_stage="role-verdict",
            global_state="BLOCKED_ISOLATION",
            role_outcome="CONTENT_FAIL",
            next_action="repair design",
        )
        index_present_product_director_artifacts(run_root)
    elif name == "branch_c_no_p0_p1":
        mutate(run_root, "direct_static_content_fail")
        verdict = read_json(verdict_path)
        verdict["open_p0_p1"] = 0
        write_json(verdict_path, verdict)
    elif name in {"role_global_mismatch", "declared_global_not_blocked"}:
        mutate(run_root, "direct_static_content_fail")
        path = run_root / "run.json"
        payload = read_json(path)
        payload["global_state"] = "REPAIR_REQUIRED"
        write_json(path, payload)
    elif name.startswith("branch_d_") and name not in {
        "branch_d_missing_reviews",
    }:
        verdict_value = {
            "branch_d_content_fail": "CONTENT_FAIL",
            "branch_d_blocked_oracle": "BLOCKED_ORACLE",
            "branch_d_blocked_evidence": "BLOCKED_EVIDENCE",
            "branch_d_blocked_isolation": "BLOCKED_ISOLATION",
        }.get(name)
        if verdict_value is None:
            raise ValueError(f"unknown Branch D mutation: {name}")
        set_role_verdict_value(run_root, verdict_value)
        index_present_product_director_artifacts(run_root)
    elif name == "branch_d_missing_reviews":
        clear_branch_d_reviews(run_root)
        verdict = read_json(verdict_path)
        verdict["evidence_refs"] = [
            ref
            for ref in verdict["evidence_refs"]
            if PurePosixPath(ref["path"]).name
            not in {
                "divergence-review.json",
                "oracle-review.json",
                "downstream-consumption.json",
            }
        ]
        write_json(verdict_path, verdict)
        index_present_product_director_artifacts(run_root)
    elif name == "unindexed_present_artifact":
        index_present_product_director_artifacts(run_root)
        path = run_root / "run.json"
        run = read_json(path)
        run["role_refs"]["product-director"] = [
            ref
            for ref in run["role_refs"]["product-director"]
            if ref["path"]
            != "roles/product-director/executor-a/attempt-1/transcript.json"
        ]
        write_json(path, run)
    elif name == "duplicate_role_ref":
        index_present_product_director_artifacts(run_root)
        path = run_root / "run.json"
        run = read_json(path)
        run["role_refs"]["product-director"].append(
            copy.deepcopy(run["role_refs"]["product-director"][0])
        )
        write_json(path, run)
    elif name == "duplicate_decisive_attempt_ref":
        verdict = read_json(verdict_path)
        verdict["decisive_attempt_refs"].append(
            copy.deepcopy(verdict["decisive_attempt_refs"][0])
        )
        write_json(verdict_path, verdict)
    elif name == "duplicate_verdict_evidence_ref":
        verdict = read_json(verdict_path)
        verdict["evidence_refs"].append(copy.deepcopy(verdict["evidence_refs"][0]))
        write_json(verdict_path, verdict)
    elif name == "invalid_next_authorized_action":
        path = run_root / "run.json"
        run = read_json(path)
        run["next_authorized_action"] = "arbitrary nonempty action"
        write_json(path, run)
    elif name == "verdict_evidence_incomplete":
        verdict = read_json(verdict_path)
        verdict["evidence_refs"] = [
            ref
            for ref in verdict["evidence_refs"]
            if PurePosixPath(ref["path"]).name != "downstream-consumption.json"
        ]
        write_json(verdict_path, verdict)
        index_present_product_director_artifacts(run_root)
    elif name in {"verdict_surface_scope_swap", "verdict_attempt_scope_swap"}:
        target = {
            "verdict_surface_scope_swap": "roles/product-director/surface.json",
            "verdict_attempt_scope_swap": (
                "roles/product-director/executor-a/attempt-1/replay-attempt.json"
            ),
        }[name]
        verdict = read_json(verdict_path)
        ref = next(item for item in verdict["evidence_refs"] if item["path"] == target)
        ref["scope"] = "external_repo"
        ref["source_id"] = "synthetic-runtime"
        write_json(verdict_path, verdict)
        refresh_run_refs_in_owner(
            run_root,
            "run.json",
            ["roles/product-director/role-verdict.json"],
        )
    elif name in {
        "unavailable_baselines_blocked_evidence",
        "branch_b_admission",
        "branch_b_missing_verdict",
        "branch_b_missing_outcome",
        "branch_b_missing_typed_evidence",
        "branch_b_admission_isolation_unknown",
        "branch_b_admission_unproven_baseline_spoof",
        "branch_b_admission_observed_spoof",
    }:
        clear_replay_and_reviews(run_root)
        for relative in (
            "surface.json",
            "decision-atoms.json",
            "content-audit-alignment.json",
            "content-audit-report.json",
            "content-audit-summary.md",
        ):
            remove_tree(role_root / relative)
        input_manifest = read_json(input_path)
        for field in (
            "product_director_content_digest",
            "inherited_runtime_digest",
            "inherited_runtime_refs",
            "authorized_business_proxy_fact_key_digest",
            "starting_input_sha256",
        ):
            input_manifest.pop(field, None)
        write_json(input_path, input_manifest)
        verdict = read_json(verdict_path)
        verdict["verdict"] = "BLOCKED_EVIDENCE"
        verdict["decisive_attempt_refs"] = []
        verdict.pop("content_digest", None)
        verdict.pop("inherited_runtime_digest", None)
        verdict["unavailable_baselines"] = [
            {
                "baseline_type": baseline_type,
                "reason_code": "UNRESOLVED_FILE_INPUT",
                "evidence_refs": [run_ref("case/input-manifest.json")],
            }
            for baseline_type in (
                "PRODUCT_DIRECTOR_CONTENT",
                "INHERITED_RUNTIME",
            )
        ]
        verdict["reason_codes"] = ["UNRESOLVED_FILE_INPUT"]
        verdict["evidence_refs"] = [
            run_ref("case/input-manifest.json"),
            run_ref("case/oracle-manifest.json"),
        ]
        verdict.pop("audit_report_ref", None)
        write_json(verdict_path, verdict)
        set_closed_track(
            run_root,
            current_stage="CASE_ADMISSION",
            closure_stage="terminal-run",
            global_state="BLOCKED_ISOLATION",
            role_outcome="BLOCKED_EVIDENCE",
            next_action="Oracle/evidence resolution",
        )
        run_path = run_root / "run.json"
        run = read_json(run_path)
        run["isolation_assessment"]["evidence_refs"] = [
            run_ref("case/input-manifest.json")
        ]
        write_json(run_path, run)
        if name == "branch_b_admission_observed_spoof":
            run_path = run_root / "run.json"
            run = read_json(run_path)
            run["isolation_assessment"]["level"] = "OBSERVED"
            run["global_state"] = "BLOCKED_EVIDENCE"
            write_json(run_path, run)
            verdict = read_json(verdict_path)
            verdict["isolation_level"] = "OBSERVED"
            write_json(verdict_path, verdict)
        elif name == "branch_b_admission_isolation_unknown":
            run_path = run_root / "run.json"
            run = read_json(run_path)
            run.pop("isolation_assessment", None)
            run["global_state"] = "BLOCKED_EVIDENCE"
            write_json(run_path, run)
            verdict = read_json(verdict_path)
            verdict["isolation_level"] = "OBSERVED"
            write_json(verdict_path, verdict)
        elif name == "branch_b_admission_unproven_baseline_spoof":
            verdict = read_json(verdict_path)
            verdict["content_digest"] = "f" * 64
            verdict["inherited_runtime_digest"] = "f" * 64
            verdict.pop("unavailable_baselines", None)
            write_json(verdict_path, verdict)
        elif name == "branch_b_missing_verdict":
            remove_tree(verdict_path)
        elif name == "branch_b_missing_outcome":
            run_path = run_root / "run.json"
            run = read_json(run_path)
            run.pop("primary_role_outcome", None)
            write_json(run_path, run)
        elif name == "branch_b_missing_typed_evidence":
            verdict = read_json(verdict_path)
            verdict["unavailable_baselines"] = verdict["unavailable_baselines"][:1]
            write_json(verdict_path, verdict)
        index_present_product_director_artifacts(run_root)
    elif name == "branch_b_admission_approved_tokens":
        mutate(run_root, "branch_b_admission")
        verdict = read_json(verdict_path)
        approved = {
            "content_digest": "PRODUCT_DIRECTOR_CONTENT",
            "inherited_runtime_digest": "INHERITED_RUNTIME",
        }
        for item in verdict["unavailable_baselines"]:
            item["baseline_type"] = approved.get(
                item["baseline_type"], item["baseline_type"]
            )
        write_json(verdict_path, verdict)
    elif name == "branch_b_admission_legacy_tokens":
        mutate(run_root, "branch_b_admission")
        verdict = read_json(verdict_path)
        legacy = {
            "PRODUCT_DIRECTOR_CONTENT": "content_digest",
            "INHERITED_RUNTIME": "inherited_runtime_digest",
        }
        for item in verdict["unavailable_baselines"]:
            item["baseline_type"] = legacy.get(
                item["baseline_type"], item["baseline_type"]
            )
        write_json(verdict_path, verdict)
    elif name == "branch_b_static":
        clear_replay_and_reviews(run_root)
        remove_formal_report(run_root)
        verdict = read_json(verdict_path)
        verdict["verdict"] = "BLOCKED_ORACLE"
        verdict["decisive_attempt_refs"] = []
        verdict["reason_codes"] = ["BUSINESS_ORACLE_CONFLICT"]
        verdict["evidence_refs"] = [
            run_ref("case/oracle-manifest.json"),
            run_ref("roles/product-director/surface.json"),
            run_ref("roles/product-director/decision-atoms.json"),
            run_ref("roles/product-director/content-audit-alignment.json"),
        ]
        verdict.pop("audit_report_ref", None)
        write_json(verdict_path, verdict)
        set_closed_track(
            run_root,
            current_stage="STATIC_AUDIT",
            closure_stage="terminal-run",
            global_state="BLOCKED_ISOLATION",
            role_outcome="BLOCKED_ORACLE",
            next_action="Oracle/evidence resolution",
        )
        index_present_product_director_artifacts(run_root)
    elif name in {
        "branch_b_diagnostic",
        "branch_b_diagnostic_missing_blocker",
        "terminal_unrecoverable_infra",
    }:
        clear_branch_d_reviews(run_root)
        remove_formal_report(run_root)
        attempt = read_json(attempt_b_path)
        attempt["attempt_status"] = "INFRA_FAILURE"
        attempt["output_refs"] = []
        attempt["blocking_fact_refs"] = [run_ref("case/input-manifest.json")]
        write_json(attempt_b_path, attempt)
        manifest_path = role_root / "executor-b/attempt-1/artifact-manifest.json"
        manifest = read_json(manifest_path)
        manifest["canonical_output_refs"] = []
        write_json(manifest_path, manifest)
        remove_tree(role_root / "executor-b/attempt-1/canonical")
        lane_b = read_json(lane_b_path)
        lane_b["terminal_condition"] = "UNRECOVERABLE_INFRA_FAILURE"
        lane_b.pop("decisive_attempt_ref", None)
        write_json(lane_b_path, lane_b)
        verdict = read_json(verdict_path)
        verdict["verdict"] = "BLOCKED_EVIDENCE"
        verdict["decisive_attempt_refs"] = [
            run_ref(
                "roles/product-director/executor-a/attempt-1/replay-attempt.json"
            )
        ]
        verdict["reason_codes"] = ["UNRECOVERABLE_INFRASTRUCTURE"]
        verdict["evidence_refs"] = [
            run_ref("roles/product-director/executor-b/replay-lane.json"),
            run_ref(
                "roles/product-director/executor-b/attempt-1/replay-attempt.json"
            ),
            run_ref("case/input-manifest.json"),
        ]
        verdict.pop("audit_report_ref", None)
        write_json(verdict_path, verdict)
        set_closed_track(
            run_root,
            current_stage="DIAGNOSTIC_REPLAY",
            closure_stage="terminal-run",
            global_state="BLOCKED_ISOLATION",
            role_outcome="BLOCKED_EVIDENCE",
            next_action="Oracle/evidence resolution",
        )
        if name == "branch_b_diagnostic_missing_blocker":
            attempt = read_json(attempt_b_path)
            attempt.pop("blocking_fact_refs", None)
            write_json(attempt_b_path, attempt)
        index_present_product_director_artifacts(run_root)
    elif name in {
        "terminal_all_contaminated",
        "branch_a_single_lane_triple",
        "branch_a_one_contaminated",
        "branch_a_two_contaminated",
        "branch_a_missing_contamination_evidence",
    }:
        attempt_count = {
            "branch_a_one_contaminated": 1,
            "branch_a_two_contaminated": 2,
        }.get(name, 3)
        make_lane_contaminated_history(run_root, "a", attempt_count)
        if name == "branch_a_missing_contamination_evidence":
            path = role_root / "executor-a/attempt-3/replay-attempt.json"
            attempt = read_json(path)
            attempt["contamination_findings"] = []
            write_json(path, attempt)
        clear_branch_d_reviews(run_root)
        remove_tree(verdict_path)
        remove_formal_report(run_root)
        set_closed_track(
            run_root,
            current_stage="DIAGNOSTIC_REPLAY",
            closure_stage="terminal-run",
            global_state="INCONCLUSIVE_CONTAMINATED",
            role_outcome=None,
            next_action="Oracle/evidence resolution",
        )
        index_present_product_director_artifacts(run_root)
    elif name in {"open_static", "open_static_future_artifacts"}:
        if name == "open_static":
            clear_replay_and_reviews(run_root)
        remove_tree(verdict_path)
        remove_formal_report(run_root)
        set_open_track(run_root, "STATIC_AUDIT")
        index_present_product_director_artifacts(run_root)
    elif name in {
        "open_diagnostic",
        "open_diagnostic_missing_review",
        "open_diagnostic_one_lane",
    }:
        remove_tree(verdict_path)
        remove_formal_report(run_root)
        set_open_track(run_root, "DIAGNOSTIC_REPLAY")
        if name == "open_diagnostic_missing_review":
            remove_tree(role_root / "downstream-consumption.json")
        elif name == "open_diagnostic_one_lane":
            remove_tree(role_root / "executor-b")
            divergence_path = role_root / "divergence-review.json"
            divergence = read_json(divergence_path)
            divergence["lane_refs"] = divergence["lane_refs"][:1]
            divergence["comparisons"][0]["lane_evidence_refs"] = (
                divergence["comparisons"][0]["lane_evidence_refs"][:1]
            )
            write_json(divergence_path, divergence)
            oracle_review_path = role_root / "oracle-review.json"
            oracle_review = read_json(oracle_review_path)
            oracle_review["lane_refs"] = oracle_review["lane_refs"][:1]
            write_json(oracle_review_path, oracle_review)
            downstream_path = role_root / "downstream-consumption.json"
            downstream = read_json(downstream_path)
            downstream["candidate_results"] = downstream["candidate_results"][:1]
            write_json(downstream_path, downstream)
        index_present_product_director_artifacts(run_root)
    elif name == "terminal_empty":
        clear_replay_and_reviews(run_root)
        remove_tree(verdict_path)
        for relative in (
            "content-audit-alignment.json",
            "content-audit-report.json",
            "content-audit-summary.md",
        ):
            remove_tree(role_root / relative)
        run_path = run_root / "run.json"
        run = read_json(run_path)
        run["current_stage"] = "DIAGNOSTIC_REPLAY"
        run["closure_validation_stage"] = "terminal-run"
        run["global_state"] = "BLOCKED_EVIDENCE"
        run.pop("primary_role_outcome", None)
        run["next_authorized_action"] = "Oracle/evidence resolution"
        write_json(run_path, run)
        set_product_director_role_refs(
            run_root,
            [
                "surface.json",
                "decision-atoms.json",
            ],
        )
    elif name in {"stopped_attempts", "stopped_canonical_residue"}:
        set_stopped_attempts(
            run_root, keep_canonical_files=name == "stopped_canonical_residue"
        )
        index_present_product_director_artifacts(run_root)
    else:
        raise ValueError(f"unknown mutation: {name}")


def command_mutate(args: argparse.Namespace) -> None:
    mutate(Path(args.run_root).resolve(), args.name)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init-sources")
    init_parser.add_argument("--output-root", required=True)
    init_parser.add_argument("--descriptor", required=True)
    init_parser.set_defaults(func=command_init_sources)

    build_parser = subparsers.add_parser("build")
    build_parser.add_argument("--repo-root", required=True)
    build_parser.add_argument("--template", required=True)
    build_parser.add_argument("--run-root", required=True)
    build_parser.add_argument("--runtime-root", required=True)
    build_parser.add_argument("--descriptor", required=True)
    build_parser.add_argument("--denominator", action="append", required=True)
    build_parser.add_argument("--source-roots-output", required=True)
    build_parser.set_defaults(func=command_build)

    refresh_parser = subparsers.add_parser("refresh")
    refresh_parser.add_argument("--repo-root", required=True)
    refresh_parser.add_argument("--run-root", required=True)
    refresh_parser.add_argument("--source-roots", required=True)
    refresh_parser.set_defaults(func=command_refresh)

    mutate_parser = subparsers.add_parser("mutate")
    mutate_parser.add_argument("--run-root", required=True)
    mutate_parser.add_argument("--name", required=True)
    mutate_parser.set_defaults(func=command_mutate)
    return parser.parse_args()


if __name__ == "__main__":
    parsed = parse_args()
    parsed.func(parsed)
