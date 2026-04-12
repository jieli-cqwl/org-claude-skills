#!/usr/bin/env bash
# 轻量契约验证器
# 基于 contracts/*.yaml + contracts/identifiers.yaml 执行 4 项检查
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
export BASE_DIR
IDS_FILE="$BASE_DIR/contracts/identifiers.yaml"

if ! command -v python3 >/dev/null 2>&1; then
  echo "FATAL: python3 not found. Install Python 3 to run this validator."
  exit 1
fi

python3 -c "import yaml" 2>/dev/null || {
  echo "FATAL: PyYAML not installed. Run: pip3 install pyyaml"
  exit 1
}

[ -f "$IDS_FILE" ] || { echo "FATAL: $IDS_FILE not found."; exit 1; }

python3 <<'PYEOF'
import os
import re
import sys
import yaml

base_dir = os.environ.get("BASE_DIR", ".")
ids_file = os.path.join(base_dir, "contracts", "identifiers.yaml")
skills_dir = os.path.join(base_dir, "shared", "skills")
community_skills_dir = os.path.join(base_dir, "third_party", "community", "superpowers", "skills")
chain_files = [
    os.path.join(base_dir, "contracts", "skill-chain.yaml"),
    os.path.join(base_dir, "contracts", "small-chain.yaml"),
]

errors = 0
warnings = 0
known_subagent_kinds = {"fact_scan", "hypothesis_draft", "structure_draft", "synthesis"}
main_stage_names = {"product", "design", "test-design", "tech-lead", "delivery-owner"}


def err(msg):
    global errors
    print(f"ERROR: {msg}")
    errors += 1


def warn(msg):
    global warnings
    print(f"WARNING: {msg}")
    warnings += 1


def info(msg):
    print(f"INFO: {msg}")


def rel_file_exists(rel_path):
    if not rel_path:
        return False
    return os.path.isfile(os.path.join(base_dir, rel_path))


with open(ids_file, "r", encoding="utf-8") as f:
    ids_data = yaml.safe_load(f) or {}
identifiers = ids_data.get("identifiers", {})

skill_names_in_fs = set()
for base in [skills_dir, community_skills_dir]:
    if os.path.isdir(base):
        for entry in os.listdir(base):
            if entry == "lib":
                continue
            skill_md = os.path.join(base, entry, "SKILL.md")
            if os.path.isfile(skill_md):
                skill_names_in_fs.add(entry)


def validate_chain(chain_file):
    if not os.path.isfile(chain_file):
        return

    with open(chain_file, "r", encoding="utf-8") as f:
        chain_data = yaml.safe_load(f) or {}

    skills = chain_data.get("chain", [])
    skill_names_in_chain = {s.get("name") for s in skills if s.get("name")}
    known_skill_names = skill_names_in_chain | skill_names_in_fs
    all_outputs = {}
    output_defs = {}
    all_inputs_required = {}
    all_inputs_optional = {}
    label = os.path.relpath(chain_file, base_dir)
    artifact_contract = chain_data.get("artifact_contract", {})
    authority_contract = chain_data.get("authority_contract", {})

    info(f"=== Validating chain: {label} ===")

    for skill in skills:
        name = skill.get("name")
        if not name:
            err(f"SKILL_NAME_MISSING: {label} has chain entry without name")
            continue

        for output in skill.get("outputs", []):
            artifact = output.get("artifact")
            if not artifact:
                err(f"OUTPUT_ARTIFACT_MISSING: skill '{name}' in {label} has output without artifact")
                continue
            if artifact in all_outputs and all_outputs[artifact] != name:
                err(
                    f"DUPLICATE_OUTPUT: '{artifact}' in {label} is produced by both '{all_outputs[artifact]}' and '{name}'"
                )
            all_outputs[artifact] = name
            output_defs[artifact] = output

        inputs = skill.get("inputs", {})
        for art in inputs.get("required", []):
            all_inputs_required.setdefault(art, []).append(name)
        for art in inputs.get("optional", []):
            all_inputs_optional.setdefault(art, []).append(name)

        if os.path.basename(chain_file) == "skill-chain.yaml" and name in main_stage_names:
            subagent_policy = skill.get("subagent_policy")
            max_subagents = skill.get("max_subagents")
            recovery_contract_ref = skill.get("recovery_contract_ref")
            metrics_ref = skill.get("metrics_ref")
            allowed_subagent_kinds = skill.get("allowed_subagent_kinds")

            if not isinstance(subagent_policy, str) or not subagent_policy.strip():
                err(f"SUBAGENT_POLICY_MISSING: skill '{name}' in {label} must declare non-empty subagent_policy")
            if not isinstance(max_subagents, int) or max_subagents < 0:
                err(f"MAX_SUBAGENTS_INVALID: skill '{name}' in {label} must declare non-negative integer max_subagents")
            if not isinstance(recovery_contract_ref, str) or not recovery_contract_ref.strip():
                err(f"RECOVERY_CONTRACT_MISSING: skill '{name}' in {label} missing recovery_contract_ref")
            elif not rel_file_exists(recovery_contract_ref):
                err(f"RECOVERY_CONTRACT_MISSING_FILE: skill '{name}' in {label} points to missing recovery_contract_ref '{recovery_contract_ref}'")
            if not isinstance(metrics_ref, str) or not metrics_ref.strip():
                err(f"METRICS_REF_MISSING: skill '{name}' in {label} missing metrics_ref")
            elif not rel_file_exists(metrics_ref):
                err(f"METRICS_REF_MISSING_FILE: skill '{name}' in {label} points to missing metrics_ref '{metrics_ref}'")
            if not isinstance(allowed_subagent_kinds, list) or len(allowed_subagent_kinds) == 0:
                err(f"ALLOWED_SUBAGENT_KINDS_INVALID: skill '{name}' in {label} must declare non-empty allowed_subagent_kinds")
            else:
                unknown_kinds = [kind for kind in allowed_subagent_kinds if kind not in known_subagent_kinds]
                if unknown_kinds:
                    err(f"ALLOWED_SUBAGENT_KINDS_UNKNOWN: skill '{name}' in {label} has unknown allowed_subagent_kinds {unknown_kinds}")

    info("=== Check 1: UNMET detection (required inputs without upstream outputs) ===")
    for artifact, consumers in all_inputs_required.items():
        if artifact not in all_outputs:
            if artifact in ["用户请求", "用户需求描述", "Task 全文(from plan.md)", "workflow-discipline", "isolated-worktree", "code", "review-feedback", "verification-evidence"]:
                continue
            err(f"UNMET: '{artifact}' in {label} is required by [{', '.join(consumers)}] but no skill produces it")

    info("=== Check 2: ORPHAN detection (outputs with no downstream consumers) ===")
    all_consumed = set(all_inputs_required.keys()) | set(all_inputs_optional.keys())
    for artifact, producer in all_outputs.items():
        if artifact in all_consumed:
            continue
        output_def = output_defs.get(artifact, {})
        if output_def.get("consumers"):
            continue
        if output_def.get("terminal") or output_def.get("human_only"):
            continue
        warn(f"ORPHAN: '{artifact}' produced by '{producer}' in {label} has no downstream consumers in inputs declarations")

    info("=== Check 4: Consumer declaration consistency ===")
    chain_consumers = {}
    for skill in skills:
        for output in skill.get("outputs", []):
            artifact = output.get("artifact")
            consumers = output.get("consumers", [])
            if artifact and consumers:
                chain_consumers[artifact] = set(consumers)

    for artifact, consumers in chain_consumers.items():
        for consumer in consumers:
            if consumer not in known_skill_names:
                err(f"CONSUMER_MISSING: '{artifact}' in {label} declares consumer '{consumer}' but no such skill exists in chain or filesystem")
            elif consumer not in skill_names_in_chain:
                info(f"  {artifact}: consumer '{consumer}' exists in filesystem but is outside chain scope")

    if os.path.basename(chain_file) == "skill-chain.yaml":
        metrics_template_ref = artifact_contract.get("metrics_log_template_ref")
        qa_report_artifact = artifact_contract.get("qa_report_artifact")
        qa_report_producer = artifact_contract.get("qa_report_producer")
        quality_judgment_owner = authority_contract.get("quality_judgment_owner")

        if not isinstance(metrics_template_ref, str) or not metrics_template_ref.strip():
            err(f"METRICS_TEMPLATE_REF_MISSING: {label} missing artifact_contract.metrics_log_template_ref")
        elif not rel_file_exists(metrics_template_ref):
            err(f"METRICS_TEMPLATE_REF_MISSING_FILE: {label} points to missing metrics_log_template_ref '{metrics_template_ref}'")
        else:
            metrics_ref = os.path.join(base_dir, "shared", "reference", "context-noise-metrics.md")
            if not os.path.isfile(metrics_ref):
                err(f"METRICS_REF_MISSING_FILE: {label} requires '{metrics_ref}' for metrics consistency checks")
            else:
                with open(metrics_ref, "r", encoding="utf-8") as f:
                    metrics_ref_text = f.read()
                with open(os.path.join(base_dir, metrics_template_ref), "r", encoding="utf-8") as f:
                    metrics_template_text = f.read()

                ref_metric_ids = set(re.findall(r"`(M[1-6])`", metrics_ref_text))
                template_metric_ids = set(re.findall(r"^\|\s*(M[1-6])\s*\|", metrics_template_text, re.MULTILINE))
                if ref_metric_ids != template_metric_ids:
                    err(
                        f"METRICS_TEMPLATE_MISMATCH: {label} metrics template rows {sorted(template_metric_ids)} do not match metrics reference {sorted(ref_metric_ids)}"
                    )

                for required_field in ["阶段", "样本编号", "基线来源", "采集人", "证据锚点"]:
                    if required_field not in metrics_template_text:
                        err(
                            f"METRICS_TEMPLATE_FIELD_MISSING: {label} metrics template missing required field '{required_field}'"
                        )

                for decision in ["PASS", "FAIL", "INCONCLUSIVE"]:
                    if decision not in metrics_template_text:
                        err(
                            f"METRICS_TEMPLATE_DECISION_MISSING: {label} metrics template missing decision '{decision}'"
                        )

        if qa_report_artifact and quality_judgment_owner:
            chain_declared_producer = all_outputs.get(qa_report_artifact)
            if not isinstance(qa_report_producer, str) or not qa_report_producer.strip():
                err(f"QA_REPORT_PRODUCER_MISSING: {label} missing artifact_contract.qa_report_producer")
            elif qa_report_producer != quality_judgment_owner:
                err(
                    f"QA_REPORT_PRODUCER_MISMATCH: '{qa_report_artifact}' in {label} declares producer '{qa_report_producer}', expected '{quality_judgment_owner}'"
                )
            elif qa_report_producer not in known_skill_names:
                err(
                    f"QA_REPORT_PRODUCER_UNKNOWN: '{qa_report_artifact}' in {label} declares producer '{qa_report_producer}' but no such skill exists in chain or filesystem"
                )

            if chain_declared_producer and chain_declared_producer != quality_judgment_owner:
                err(
                    f"QA_REPORT_OWNER_MISMATCH: '{qa_report_artifact}' in {label} is produced by '{chain_declared_producer}', expected '{quality_judgment_owner}'"
                )


for chain_file in chain_files:
    validate_chain(chain_file)

info("=== Check 3: Identifier consistency ===")
regexes = {}
for id_name, id_def in identifiers.items():
    regex = id_def.get("regex", "")
    if not regex:
        warn(f"REGEX_MISSING: identifier '{id_name}' has empty regex")
        continue
    try:
        regexes[id_name] = re.compile(regex)
    except re.error as ex:
        err(f"REGEX_INVALID: identifier '{id_name}' has invalid canonical regex '{regex}': {ex}")

identifier_samples = {}
for id_name, id_def in identifiers.items():
    samples = id_def.get("samples", [])
    if not isinstance(samples, list):
        err(f"SAMPLES_INVALID: identifier '{id_name}' samples must be a list")
        samples = []
    identifier_samples[id_name] = [str(s) for s in samples if str(s).strip()]
    if not identifier_samples[id_name]:
        warn(f"SAMPLES_MISSING: identifier '{id_name}' has no samples, overlap checks may be weak")

for id_name, samples in identifier_samples.items():
    if id_name not in regexes:
        continue
    own_pattern = regexes[id_name]
    for sample in samples:
        if own_pattern.fullmatch(sample) is None:
            err(f"SAMPLE_MISMATCH: sample '{sample}' does not match canonical regex of '{id_name}'")

        matching = []
        for other_name, other_pattern in regexes.items():
            if other_pattern.fullmatch(sample):
                matching.append(other_name)
        if len(matching) > 1:
            err(f"REGEX_OVERLAP: '{sample}' matches multiple canonical regexes: {matching}")
        elif len(matching) == 0:
            err(f"REGEX_UNMATCHED: sample '{sample}' is not matched by any canonical regex")

for id_name, id_def in identifiers.items():
    compat = id_def.get("parser_compat")
    if compat is None and id_def.get("parser_compat_regex"):
        compat = {"regex": id_def.get("parser_compat_regex"), "maps_to": [id_name]}

    if compat is None:
        continue

    if not isinstance(compat, dict):
        err(f"PARSER_COMPAT_INVALID: identifier '{id_name}' parser_compat must be an object")
        continue

    compat_regex = compat.get("regex")
    maps_to = compat.get("maps_to")
    if not compat_regex:
        err(f"PARSER_COMPAT_INVALID: identifier '{id_name}' parser_compat.regex is required")
        continue
    if not isinstance(maps_to, list) or len(maps_to) == 0:
        err(f"PARSER_COMPAT_INVALID: identifier '{id_name}' parser_compat.maps_to must be a non-empty list")
        continue
    if id_name not in maps_to:
        err(f"PARSER_COMPAT_INVALID: identifier '{id_name}' parser_compat.maps_to must include itself")

    try:
        compat_pattern = re.compile(compat_regex)
    except re.error as ex:
        err(f"PARSER_COMPAT_INVALID: identifier '{id_name}' has invalid parser_compat regex '{compat_regex}': {ex}")
        continue

    missing_targets = [t for t in maps_to if t not in identifiers]
    if missing_targets:
        err(
            f"PARSER_COMPAT_INVALID: identifier '{id_name}' parser_compat maps_to unknown identifiers: {missing_targets}"
        )
        continue

    target_samples = []
    for target in maps_to:
        target_samples.extend(identifier_samples.get(target, []))
    if len(target_samples) == 0:
        err(
            f"PARSER_COMPAT_INVALID: identifier '{id_name}' parser_compat maps_to {maps_to} but no target samples are available"
        )
        continue

    for sample in target_samples:
        if compat_pattern.fullmatch(sample) is None:
            err(
                f"PARSER_COMPAT_MISMATCH: compat regex '{compat_regex}' of '{id_name}' does not match mapped sample '{sample}'"
            )

    for other_name, samples in identifier_samples.items():
        if other_name in maps_to:
            continue
        for sample in samples:
            if compat_pattern.fullmatch(sample):
                err(
                    f"PARSER_COMPAT_OVERMATCH: compat regex '{compat_regex}' of '{id_name}' matches non-mapped sample '{sample}' ({other_name})"
                )

    info(f"  {id_name}: parser_compat '{compat_regex}' maps_to {maps_to}")

for id_name, id_def in identifiers.items():
    consumers = id_def.get("consumers", [])
    for consumer in consumers:
        if consumer not in skill_names_in_fs:
            err(f"IDENTIFIER_CONSUMER_MISSING: identifier '{id_name}' declares unknown consumer '{consumer}'")

print()
if errors == 0 and warnings == 0:
    print("OK: all checks passed")
elif errors == 0:
    print(f"PASS with {warnings} warning(s)")
else:
    print(f"FAIL: {errors} error(s), {warnings} warning(s)")

sys.exit(1 if errors > 0 else 0)
PYEOF
