#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOUNDARY="$ROOT/contracts/superpowers-boundary.yaml"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$BOUNDARY" || fail "缺少 contracts/superpowers-boundary.yaml"
test -s "$BOUNDARY" || fail "contracts/superpowers-boundary.yaml 不能为空"

for key in version target_state runtime_roles canonical_targets source_fidelity declared_forks allowed_legacy_paths closeout_policy overlay_files; do
  grep -Eq "^${key}:" "$BOUNDARY" || fail "boundary contract 缺少顶层字段: $key"
done

for key in community_superpowers small_chain openspec community_openspec; do
  grep -Eq "^  ${key}:" "$BOUNDARY" || fail "boundary contract 缺少 runtime_roles.${key}"
done

for key in default_chain_contract source_lock overlay_contract runtime_entry_skill; do
  value="$(awk -v key="$key" '
    /^canonical_targets:/ { in_block = 1; next }
    in_block && /^[^[:space:]]/ { exit }
    in_block {
      prefix = "  " key ": "
      if (index($0, prefix) == 1) {
        print substr($0, length(prefix) + 1)
        exit
      }
    }
  ' "$BOUNDARY")"
  [ -n "$value" ] || fail "boundary contract 缺少 canonical_targets.${key}"
  [ -f "$ROOT/$value" ] || fail "boundary contract 指向缺失文件: $value"
done

grep -Fq 'upstream_body_policy: locked_ref_original' "$BOUNDARY" || fail "boundary contract 缺少 upstream 正文原样策略"
grep -Fq 'declared_overlay_files' "$BOUNDARY" || fail "boundary contract 缺少声明式 overlay 允许范围"
grep -Fq 'generated_codex_adapters' "$BOUNDARY" || fail "boundary contract 缺少 Codex adapter 允许范围"
grep -Fq 'local_only_files:' "$BOUNDARY" || fail "boundary contract 缺少本地专属文件声明"
grep -Fq 'runtime_visibility_metadata:' "$BOUNDARY" || fail "boundary contract 缺少运行时可见元数据声明"
grep -Fq 'machine_generated_language_rewrite' "$BOUNDARY" || fail "boundary contract 缺少机器改写禁用项"
grep -Fq 'undeclared_body_rewrite' "$BOUNDARY" || fail "boundary contract 缺少未声明正文改写禁用项"
grep -Fq 'compatibility_anchors_for_rewritten_body' "$BOUNDARY" || fail "boundary contract 缺少改写锚点兼容禁用项"
grep -Fq 'required_after_implementation:' "$BOUNDARY" || fail "boundary contract 缺少 closeout_policy.required_after_implementation"
grep -Fq 'conditional_routes:' "$BOUNDARY" || fail "boundary contract 缺少 closeout_policy.conditional_routes"
grep -Fq 'when: branch_integration_or_worktree_cleanup_pending' "$BOUNDARY" || fail "boundary contract 缺少 branch integration conditional route"
grep -Fq 'when: already_integrated_on_target_branch_and_no_cleanup_pending' "$BOUNDARY" || fail "boundary contract 缺少 already-integrated conditional route"
grep -Fq 'finishing_required_when: branch_integration_or_worktree_cleanup_pending' "$BOUNDARY" || fail "boundary contract 缺少 closeout_policy.finishing_required_when"
grep -Fq 'verify_change_required_before:' "$BOUNDARY" || fail "boundary contract 缺少 closeout_policy.verify_change_required_before"
grep -Fq 'archive_requires: integrated_on_target_branch' "$BOUNDARY" || fail "boundary contract 缺少 closeout_policy.archive_requires"
grep -Fq 'brainstorming_design_completeness_gate' "$BOUNDARY" || fail "boundary contract 缺少 brainstorming design completeness fork"
grep -Fq 'writing_plans_task_traceability' "$BOUNDARY" || fail "boundary contract 缺少 writing-plans task traceability fork"
grep -Fq 'community/superpowers/skills/brainstorming/references/design-completeness-checklist.md' "$BOUNDARY" || fail "boundary contract 缺少 design completeness checklist overlay"
grep -Fq 'community/superpowers/codex/skills/brainstorming/agents/openai.yaml' "$BOUNDARY" || fail "boundary contract 缺少 Codex brainstorming adapter 声明"
grep -Fq 'community/superpowers/skills/verify-change/scripts/check_task_plan_consistency.py' "$BOUNDARY" || fail "boundary contract 缺少 verify-change 脚本声明"

while IFS= read -r path; do
  [ -f "$ROOT/$path" ] || fail "overlay_files 声明的文件不存在: $path"
done < <(sed -n 's/^  - \(community\/superpowers\/.*\)$/\1/p' "$BOUNDARY")

if rg -n 'docs/superpowers/specs|docs/superpowers/plans|openspec/designs|openspec/plans|executing-plans' "$ROOT/community/superpowers" >/tmp/org_superpowers_legacy_paths.out 2>&1; then
  cat /tmp/org_superpowers_legacy_paths.out >&2
  fail "community/superpowers 不应保留退役 small-chain 路径或 executing-plans 语义"
fi

if rg -n "Error 500|That.s an error|That's an error" "$ROOT/community/superpowers" >/tmp/org_superpowers_noise.out 2>&1; then
  cat /tmp/org_superpowers_noise.out >&2
  fail "community/superpowers 不应再保留正文噪音"
fi

if rg -n 'opsx:(propose|apply|verify|archive)' "$ROOT/community/superpowers" >/tmp/org_superpowers_local_workflow.out 2>&1; then
  cat /tmp/org_superpowers_local_workflow.out >&2
  fail "community/superpowers 不应继续回写本仓库特有的 opsx:* 本地流程名"
fi

echo "[PASS] superpowers boundary"
