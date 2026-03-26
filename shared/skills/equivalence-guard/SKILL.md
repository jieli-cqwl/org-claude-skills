---
name: equivalence-guard
description: 迁移接口行为等价验证与证据门禁。Use when 需要对新旧接口执行全量比对并产出可审计的 EQUIV_OK/EQUIV_BLOCKED 结论。
argument-hint: "[work_dir]"
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, Grep
hooks:
  Stop:
    - hooks:
        - type: command
          command: bash {{RUNTIME_HOME}}/skills/equivalence-guard/scripts/completion_check.sh
          timeout: 20
---

# /equivalence-guard -- 迁移行为等价门禁

## HARD-GATE

1. NO run without fixed inputs: `equivalence/endpoint-manifest.csv` + `request-set.jsonl` + `snapshot.lock` + `equiv-config.yaml`.
2. NO EQUIV_OK without full coverage (`verified_endpoints == total_endpoints`) and zero unresolved diffs.
3. NO fingerprint omission: `run_id/git_sha/manifest_hash/config_hash/snapshot_id/generated_at` must all exist.
4. NO whitelist bypass without explicit `api_id + field_path` rule in `equiv-config.yaml`.
5. NO completion without `equivalence-report.md` + `evidence-index.md` + `diff-details.csv` written to `{work_dir}/equivalence/`.

## 角色

你是迁移等价性守门人。你的结论会直接决定是否允许项目推进到灰度/切流阶段，任何放行都必须有可复核证据链。

## 输入

- 前置条件：`[work_dir]/equivalence/` 下具备 4 个输入文件（manifest/request-set/snapshot/config）
- 用户输入：`/equivalence-guard [work_dir]`，默认当前目录 `.`

## 流程

1. 解析工作目录：`WORK_DIR=${1:-.}`，失败时终止。
2. 校验 4 个输入文件存在且非空，缺失项直接标记 `EQUIV_BLOCKED`。
3. 运行比对引擎：`bash {{RUNTIME_HOME}}/skills/equivalence-guard/scripts/api-equiv-diff.sh "$WORK_DIR"`。
4. 读取引擎产物：`tool-summary.json` + `diff-details.csv` + `api-results.jsonl`。
5. 检查白名单命中与未解决差异，确认覆盖率是否 100%。
6. 审核证据指纹字段、哈希一致性、时间新鲜度（默认 24h）。
7. 输出报告与索引（模板见 `references/templates/equivalence-report-template.md` 与 `references/templates/evidence-index-template.md`），结论仅可为 `EQUIV_OK` 或 `EQUIV_BLOCKED`。

## 输出

- `equivalence/equivalence-report.md`
- `equivalence/evidence-index.md`
- `equivalence/diff-details.csv`
- `equivalence/tool-summary.json`
- `equivalence/api-results.jsonl`

## 完成校验

- [ ] 4 个输入文件存在且非空
- [ ] `diff-details.csv` 列包含 `api_id/field_path/old_value_masked/new_value_masked/status`
- [ ] 报告包含完整证据指纹字段
- [ ] `EQUIV_OK` 时覆盖率为 100% 且未解决差异为 0
- [ ] `EQUIV_BLOCKED` 时报告列出未解决差异与未验证接口
