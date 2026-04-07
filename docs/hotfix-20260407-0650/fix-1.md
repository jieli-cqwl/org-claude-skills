# Fix-1: Codex Review 3 Issues

## 来源

Codex code review 发现 3 个问题（2 x P1, 1 x P2）。
无 code-review-report.md 或 qa-report.md 输入（用户直接提供问题描述）。

## 修复清单

### P1-1: W3 命令注入风险

- 文件: `shared/skills/developer/scripts/completion_check.sh`
- 位置: W3 测试命令执行部分（约 L291-296）
- 问题: 前缀白名单 grep 只检查命令开头，命令如 `npx vitest && curl ...` 会通过白名单后被 `bash -c` 执行
- 修复: 在白名单检查之前增加 shell 元字符检测（`&&`、`||`、`;`、`|`、`$(`、反引号、重定向），命中时跳过执行并输出 `[WARN]`
- 验证: `bash -n` 语法检查通过

### P1-2: preflight-evidence 硬门禁导致现有样例失败

- 文件: `shared/skills/project-manager/scripts/completion_check.sh`
- 位置: D-PRE 检查部分（约 L649-658）
- 问题: 现有 `docs/weekly-report/phase-1/plan.md` 已有 CON-001~004 但无 `preflight-evidence.md`，硬门禁直接 FAIL
- 修复: 将 `add_failure` 改为 `echo [WARN] ... >&2`，初期 warning 不阻断，与其他 Phase 2 新增检查保持一致
- 验证: `bash -n` 语法检查通过

### P2: TDD 证据索引校验被削弱

- 文件: `shared/skills/developer/scripts/completion_check.sh`
- 位置: C2.5 检查部分（约 L118-142）
- 问题: 新的 TDD 证据索引检查只验证"非空"，不再要求同时有 RED 和 GREEN 记录，也不验证 Commit SHA 是否为占位符
- 修复:
  1. 在新格式（`### TDD 证据索引`）非空检查通过后的 `else` 分支，增加 RED/GREEN 行检测（`grep -ciE 'RED|FAIL'` / `grep -ciE 'GREEN|PASS'`）
  2. 增加非占位符 SHA 检测（`grep -coE '[0-9a-f]{7,40}'`），至少需要 1 个有效 SHA
  3. 旧格式（`### RED 阶段完整输出`）回退路径不受影响
- 验证: `bash -n` 语法检查通过

## 验证结果

| 检查项 | 结果 |
|--------|------|
| developer/completion_check.sh `bash -n` | PASS (exit 0) |
| project-manager/completion_check.sh `bash -n` | PASS (exit 0) |

## 交接项

- 三项修复均为行为变更，无新增文件/依赖
- P1-1 的元字符黑名单可根据实际需求扩展（当前覆盖: `&&`, `||`, `;`, `|`, `$(`, 反引号, `>`, `>>`, `<`, `<<`）
- P1-2 后续可在 preflight-evidence 机制稳定后升级回硬门禁
