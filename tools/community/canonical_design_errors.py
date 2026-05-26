"""Error message builders for canonical_design_rules / canonical_design_trace_rules.

Separated from the rules themselves so that each rule module stays under
the 400-line limit while still giving self-explanatory FAIL messages
that include expected format, actual value, available options, and
guidance for the correct fix.
"""

from __future__ import annotations


DESIGN_REVIEW_WRAPPER_FIELDS_DEFAULT = (
    "candidate_design_json",
    "review_payload_json",
    "open_warns",
    "handoff_summary",
    "co_creation_confirmations",
    "source_refs",
)


def manager_ref_not_string(path: str, ref: object) -> str:
    return (
        f"{path} must be a string manager ref. "
        f"Expected format: 'phase-prd.<array_field>[<index>]' "
        f"(e.g. 'phase-prd.exit_conditions[0]'). Got: {type(ref).__name__}."
    )


def manager_ref_bad_format(path: str, ref: str, array_fields: list[str]) -> str:
    return (
        f"{path}={ref!r} does not match manager ref format. "
        f"Expected: 'phase-prd.<array_field>[<index>]' "
        f"(e.g. 'phase-prd.exit_conditions[0]'). "
        f"Available array fields in phase-prd.json: {array_fields}. "
        f"If you need to cite an AC, decision or risk, write it in "
        f"verification_mapping[*].design_validation instead."
    )


def manager_ref_not_array(
    path: str, ref: str, field: str, array_fields: list[str]
) -> str:
    return (
        f"{path}={ref!r} references phase-prd.{field} which is not an array. "
        f"Available array fields in phase-prd.json: {array_fields}."
    )


def manager_ref_out_of_range(path: str, ref: str, field: str, length: int) -> str:
    return (
        f"{path}={ref!r} index out of range. "
        f"phase-prd.{field} has {length} entries "
        f"(valid indices 0..{length - 1})."
    )


def handoff_ref_not_string(path: str, ref: object) -> str:
    return (
        f"{path} must be a string handoff ref. "
        f"Expected: 'brief.json#<anchor>' or 'phase-prd.json#<anchor>' "
        f"(e.g. 'brief.json#/scope/primary_goal'). "
        f"Got: {type(ref).__name__}."
    )


def handoff_ref_bad_format(path: str, ref: str) -> str:
    return (
        f"{path}={ref!r} does not match handoff ref format. "
        f"Expected: 'brief.json#<anchor>' or 'phase-prd.json#<anchor>'. "
        f"Anchors can be JSON Pointers ('/scope/primary_goal') or field "
        f"anchors ('unit_index'). UNIT-* / design.json refs are not allowed."
    )


def handoff_ref_document_missing(path: str, ref: str, document_name: str) -> str:
    return (
        f"{path}={ref!r} points to {document_name} which is not loaded in this context."
    )


def handoff_ref_anchor_missing(
    path: str, ref: str, document_name: str, top_level: list[str]
) -> str:
    return (
        f"{path}={ref!r} anchor does not resolve in {document_name}. "
        f"Top-level fields available: {top_level}."
    )


def design_ref_not_string(path: str, ref: object) -> str:
    return (
        f"{path} must be a string design-internal ref. "
        f"Expected: 'design.json#<field>[<index>]' "
        f"(e.g. 'design.json#key_decisions[0]'). "
        f"Got: {type(ref).__name__}."
    )


def design_ref_wrong_prefix(path: str, ref: str) -> str:
    return (
        f"{path}={ref!r} must target design.json. "
        f"Expected prefix: 'design.json#'. "
        f"For cross-document refs use product_handoff.accepted_refs "
        f"(brief.json# / phase-prd.json#) or verification_mapping.manager_vp_ref "
        f"(phase-prd.<field>[<index>])."
    )


def candidate_fields_leaked(leaked: list[str], canonical: list[str]) -> str:
    return (
        f"design.json contains review-wrapper-only fields: {leaked}. "
        f"These belong outside canonical design.json; strip them before writing "
        f"the design artifact. Review-wrapper fields: {canonical}."
    )


def unresolved_bracket_token(value: str) -> str:
    return (
        f"design.json still contains an unresolved angle-bracket token: {value!r}. "
        f"Replace the angle-bracket token with a concrete value before finalizing."
    )


def co_creation_missing_stages(
    missing: list[str], required: list[str], seen: list[str]
) -> str:
    return (
        f"co_creation_summary missing stages: {missing}. "
        f"Every design session must record one entry per required co-creation stage "
        f"(required set: {required}). "
        f"Seen: {seen}. "
        f"Add a co_creation_summary row for each missing stage with "
        f"stage_name, question_or_focus, user_response_summary and decision_refs."
    )


def digest_bad_format(digest: object) -> str:
    return (
        f"review_closure.reviewed_design_digest must match 'sha256:<64 hex chars>'. "
        f"Got: {digest!r}. "
        f"Generate it via: "
        f"python3 shared/skills/design/scripts/review_digest.py "
        f"--review-payload $TMPDIR/design-review.json"
    )


def reviewer_name_invalid(index: int, name: object) -> str:
    return (
        f"review_closure.reviewers[{index}].reviewer={name!r} is invalid. "
        f"Allowed: 'architecture' | 'product' | 'test'."
    )


def reviewer_verdict_invalid(index: int, verdict: object) -> str:
    return (
        f"review_closure.reviewers[{index}].verdict={verdict!r} is invalid. "
        f"Allowed: 'PASS' | 'WARN'. "
        f"FAIL verdicts must be resolved before closure (and logged in resolved_failures)."
    )


def reviewer_digest_mismatch(index: int, reviewed: object, expected: str) -> str:
    return (
        f"review_closure.reviewers[{index}].reviewed_design_digest "
        f"({reviewed!r}) does not match "
        f"review_closure.reviewed_design_digest ({expected!r}). "
        f"Every reviewer must review the same self-checked design artifact. If you did "
        f"lint-only fixes after review, follow the lint-only flow: re-compute "
        f"the digest, keep the reviewer verdicts, and log each lint fix in "
        f"resolved_failures (finding_id=LINT-REVIEW-N)."
    )


def reviewers_missing(missing: list[str]) -> str:
    return (
        f"review_closure missing reviewers: {missing}. "
        f"All three perspectives (architecture, product, test) are required."
    )


def warn_followup_target_invalid(index: int, target: object, allowed: list[str]) -> str:
    return (
        f"review_closure.warn_followups[{index}].target="
        f"{target!r} is not allowed. "
        f"Allowed targets: {allowed}. "
        f"WARN items can only land in one of these four sections of "
        f"design.json; if the WARN belongs downstream (e.g. to /test-design), "
        f"route it via product_handoff."
    )


def warn_followups_missing(missing: list[str], allowed: list[str]) -> str:
    return (
        f"review_closure missing warn_followups for WARN finding refs: "
        f"{missing}. "
        f"Every WARN finding_ref from reviewers must have a matching entry in "
        f"warn_followups that pins it to one of {allowed}."
    )


def decision_state_not_frozen(index: int, state: object) -> str:
    return (
        f"key_decisions[{index}].decision_state={state!r} must be '已冻结'. "
        f"Draft / pending decisions cannot be written into key_decisions; "
        f"keep them in option_analysis until the user confirms and freezes."
    )


def decision_options_too_few(index: int, decision_id: str, options: list[str]) -> str:
    return (
        f"key_decisions[{index}] decision_id={decision_id!r} must have "
        f"at least two option_analysis entries under the same decision_ref. "
        f"Found: {options}. "
        f"Every key decision needs >= 2 materially-different options with "
        f"tradeoffs and fact anchors before it can be frozen."
    )


def decision_option_ref_mismatch(
    index: int, option_ref: object, decision_id: str, options: list[str]
) -> str:
    return (
        f"key_decisions[{index}].option_ref={option_ref!r} does not resolve "
        f"within decision_ref={decision_id!r} option group. "
        f"Candidate options for this decision: {options}."
    )


def runtime_fact_missing_tokens(index: int, fact: str) -> str:
    return (
        f"runtime_facts[{index}] must include both 'evidence=' and "
        f"'observed_at=' tokens. Got: {fact!r}. "
        f"Example: 'Redis aof-config always enabled "
        f"evidence=<command/path> observed_at=2026-05-01T12:00:00Z'. "
        f"If runtime capture is not applicable (pure refactor), still write "
        f"a single fact explaining 'not applicable' with evidence= and "
        f"observed_at= populated."
    )


def cross_cutting_missing_concerns(
    missing: list[str], required: list[str], seen: list[str]
) -> str:
    return (
        f"cross_cutting_concerns missing required concerns: {missing}. "
        f"Required baseline concerns: {required}. "
        f"Seen: {seen}. "
        f"Add a cross_cutting_concerns entry for each missing concern with a "
        f"decision, owner and verification_refs. If a concern genuinely does "
        f"not apply, state that explicitly in the entry (do not omit the concern)."
    )


def unit_ac_refs_unknown(
    index: int, unit_id: str, unknown: list[str], known: list[str]
) -> str:
    return (
        f"unit_coverage[{index}].ac_refs cites unknown AC ids for "
        f"{unit_id}: {unknown}. "
        f"ac_refs must come from acceptance_criteria[*].ac_id inside the "
        f"same UNIT file; cross-UNIT AC references are not allowed. "
        f"Known ac_ids for {unit_id}: {known}. "
        f"If an AC is missing, route back to /product-manager "
        f"or /test-design instead of inventing it here."
    )


def unit_design_refs_unknown(index: int, unknown: list[str], known: list[str]) -> str:
    return (
        f"unit_coverage[{index}].design_refs contains ids not declared in this "
        f"design.json: {unknown}. "
        f"design_refs must only cite modules[*].module_id or "
        f"interfaces[*].interface_id. "
        f"Decision ids (D-*), verification ids, DB table names, and free "
        f"text are not allowed here. "
        f"Known ids in this design.json: {known}."
    )


def unit_coverage_unknown_unit(index: int, unit_id: str, known: list[str]) -> str:
    return (
        f"unit_coverage[{index}].unit_id={unit_id!r} does not match any "
        f"UNIT-*.json artifact in this phase. "
        f"Known unit_ids: {known}."
    )


def impact_modules_unknown(index: int, unknown: list[str], known: list[str]) -> str:
    return (
        f"impact_scope[{index}].affected_modules cites ids not declared in "
        f"this design.json: {unknown}. "
        f"affected_modules must only cite modules[*].module_id. "
        f"Interface ids (IF-*), decision ids (D-*), and free text are not "
        f"allowed here. "
        f"Known module_ids: {known}."
    )


def verification_refs_unresolved(
    collection: str, index: int, missing: list[str], available: list[str]
) -> str:
    return (
        f"{collection}[{index}].verification_refs unresolved: "
        f"{missing}. "
        f"verification_refs must only cite evidence_ref values that "
        f"exist in verification_mapping[*].evidence_ref. "
        f"Available evidence_ref values: {available}. "
        f"Do not cite verification_plan ids, array indices, or "
        f"natural-language descriptions here."
    )


def risk_response_missing(missing: list[str]) -> str:
    return (
        f"risk_response missing entries for risk ids: {missing}. "
        f"Every risks[*].risk_id must have a matching risk_response[*].risk_id. "
        f"Each risk_response entry must include architecture_response plus "
        f"either verification_refs (citing verification_mapping evidence_ref) "
        f"or an escalation_path."
    )


def risk_response_missing_containment(index: int, risk_id: object) -> str:
    return (
        f"risk_response[{index}] (risk_id={risk_id!r}) must "
        f"include either a non-empty verification_refs array (citing "
        f"verification_mapping evidence_ref) or a non-empty escalation_path. "
        f"At least one containment mechanism is required per risk."
    )


def missing_unit_artifacts(missing: list[str], known: list[str]) -> str:
    return (
        f"design contract missing unit-definition artifacts for "
        f"phase-prd.unit_index entries: {missing}. "
        f"Every unit id listed in phase-prd.json#unit_index must have a "
        f"matching UNIT-*.json artifact loaded in the design context. "
        f"Loaded unit ids: {known}."
    )
