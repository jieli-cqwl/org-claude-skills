# fix-1

## 输入来源与路径解析

- 输入来源：`delivery-owner` hook 最小复现 + `tests/test-skill-output-and-gate-contract.sh`
- 影响对象：
  - `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/scripts/completion_check.sh`
  - `/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh`
  - `/Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh`

## 环境快照

- 仓库：`/Users/lijieli/org-claude-skills`
- 分支状态：dirty worktree（仅在目标文件上做最小修复，未回退无关改动）
- 复现时间：`2026-04-12 22:29`

## 现象

### Issue 1

- 现象：`delivery-owner/scripts/completion_check.sh` 在缺少 `plan.md / design.md / code-review-report.md / qa-report.md` 的最小复现中返回 `EXIT=1`，但 `stdout/stderr` 为空。
- 预期：缺文件应作为业务 failure 累积，并最终由 `output_failures` 输出可读错误和 JSON block decision。

### Issue 2

- 现象：修复 Issue 1 后，`tests/test-skill-output-and-gate-contract.sh` 暴露 fixture 生成失败，`perl -0pi -e 's### ...'` 返回 `RC=255`。
- 预期：测试应正常构造“并行 Task 触发汇总代理”的 plan fixture。

### Issue 3

- 现象：修复 Issue 2 后，`pm-triggered-summaries-valid` 场景仍被 hook 误判：`developer_report_ref 必须留在当前 UNIT 工作区内`。
- 预期：同一 UNIT 工作区内的 `developer-report-Task-1.md#...` 应被接受。

### Issue 4

- 现象：Issue 1 修复后，最小复现虽然能正常 block，但 `stderr` 仍出现 `awk: can't open file ...` 之类的低价值 warning。
- 预期：缺文件应只体现为业务 failure，不应再额外打印底层解析警告。

## 假设与验证

| Issue | 假设 | 验证 | 结果 |
|------|------|------|------|
| 1 | hook 在缺文件分支中途被 `set -euo pipefail` 打断，未走 `output_failures` | 对最小复现场景执行 `bash -x shared/skills/delivery-owner/scripts/completion_check.sh`，定位到 `validate_synthesis_report_states` 内的 `invalid_states=$( ... grep -vE ... )` | 确认 |
| 1 | 早期 `resolve_feature_dir` / `output_failures` 顺序导致提前退出 | xtrace 显示脚本已进入 D12.2 合成汇总校验，排除早期出口 | 排除 |
| 2 | 测试 fixture 的 `perl` 替换本身语法错误 | 直接运行整条测试，得到 `RC=255`，错误定位到 `tests/test-skill-output-and-gate-contract.sh:1075` 的 `s###` | 确认 |
| 3 | `developer_report_ref` 真越界到当前 UNIT 工作区外 | 检查报错路径，实际文件位于当前 UNIT 工作区；继续看比较逻辑 | 排除 |
| 3 | `developer_report_file` 是绝对路径，而 `UNIT_WORK_DIR` 可能是相对路径，前缀比较失真 | 定位到 `shared/skills/delivery-owner/scripts/completion_check.sh:1420-1424`，确认比较两边坐标系不一致 | 确认 |
| 4 | 底层 markdown 解析在缺文件时直接调用 `awk`，导致 warning 泄漏到 stderr | 检查 `shared/hooks/lib/common.sh:605` 的 `extract_markdown_section()`，确认缺少 `[ -f "$file" ] || return 0` 守卫 | 确认 |

## 根因结论

| Issue | failure_class | 根因 | 证据 |
|------|---------------|------|------|
| 1 | FIXABLE | `validate_synthesis_report_states` 中两处 `invalid_states=$(printf ... | grep -vE ... | sort -u | paste -sd, -)` 在“无非法状态”时让 `grep` 返回 `1`，被 `set -euo pipefail` 放大成脚本提前退出，导致未执行最终 `output_failures` | `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/scripts/completion_check.sh:443`, `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/scripts/completion_check.sh:450` |
| 2 | FIXABLE | fixture 生成逻辑中的 `perl -0pi -e 's### ...'` 缺少有效 pattern，导致测试脚本自身语法失败 | `/Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh:1075` |
| 3 | FIXABLE | `developer_report_ref` 校验把绝对路径 `developer_report_file` 与可能为相对路径的 `UNIT_WORK_DIR` 直接做前缀比较，误判合法文件为越界 | `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/scripts/completion_check.sh:1420-1424` |
| 4 | FIXABLE | `extract_markdown_section()` 在缺文件时直接执行 `awk`，把“正常的缺工件场景”额外放大成底层 warning | `/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh:605` |

## 修复四问

### Issue 1

1. 根因是什么？
   `pipefail` 下的命令替换把“无非法状态”误当成 shell failure。
2. 修复是否完整？
   是。脚本内同类两处都改成不会因空结果失败的过滤写法。
3. 是否引入新问题？
   风险低；仅改变非法状态收集方式，不改变业务判定语义。
4. 是否需要补测试覆盖？
   已由现有 `delivery-owner hook should reach full validation` 场景覆盖。

### Issue 2

1. 根因是什么？
   fixture 替换语句非法，不是业务逻辑错误。
2. 修复是否完整？
   是。改成 `awk + mv` 替换整段 `并行策略`，避免 `perl` pattern 语法和编码问题。
3. 是否引入新问题？
   风险低；仅影响测试 fixture 生成。
4. 是否需要补测试覆盖？
   不需要新测；现有整条 `test-skill-output-and-gate-contract.sh` 即覆盖。

### Issue 3

1. 根因是什么？
   路径比较坐标系不一致。
2. 修复是否完整？
   是。新增 `normalize_dir_path()`，把 `UNIT_WORK_DIR` 归一化后再比较。
3. 是否引入新问题？
   风险低；仅影响 “当前 UNIT 工作区内” 的合法性校验。
4. 是否需要补测试覆盖？
   已由 `pm-triggered-summaries-valid` 场景覆盖。

### Issue 4

1. 根因是什么？
   markdown 提取函数缺少缺文件短路保护。
2. 修复是否完整？
   是。仅在公共函数入口补 `[ -f "$file" ] || return 0`，不改变已有解析语义。
3. 是否引入新问题？
   风险低；缺文件时返回空内容本来就是多数调用方期望。
4. 是否需要补测试覆盖？
   不新增测试；最小复现已验证 warning 消失、业务 failure 保留。

## 处置

- Issue 1：将非法状态过滤改为 `awk 'NF && ...'`，避免“无输出”被当成 shell failure。
- Issue 2：将并行策略 fixture 改为 `awk + mv` 替换整段内容。
- Issue 3：新增 `normalize_dir_path()`，统一路径坐标系后再做 `developer_report_ref` 前缀判断。
- Issue 4：在 `extract_markdown_section()` 入口补文件存在性守卫，避免缺文件时输出底层 `awk` warning。

## GREEN 证据

- 最小复现修复后输出：
  - `EXIT=2`
  - `stdout` 含 JSON block decision
  - `stderr` 含 `D2: plan.md 不存在`、`D2: design.md 不存在`、`D8: code-review-report.md 不存在`、`D8: qa-report.md 不存在`

## 回归验证

- `bash tests/test-subagent-context-contract.sh` → PASS
- `bash tests/test-skill-output-and-gate-contract.sh` → PASS
- `git diff --check` → PASS

## 影响范围

- 直接改动：
  - `shared/skills/delivery-owner/scripts/completion_check.sh`
  - `shared/hooks/lib/common.sh`
  - `tests/test-skill-output-and-gate-contract.sh`
- 间接受益：
  - `delivery-owner` hook 在缺工件场景下恢复“失败可解释、可审计、可阻断”
  - 汇总代理相关 fixture 恢复可构造
