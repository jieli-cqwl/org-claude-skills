# Code Review Report

## Scope
- 仓库：`org-claude-skills`
- 范围：`install.sh`、`tests/run-all.sh`、`tests/test-codex-skill-adapter.sh`、`tools/dev/probe-claude-capabilities.sh`、相关发布与运行文档
- 基线：`65a1618 release: v1.2.0`
- 审查方式：Round 1 广度扫描 + Round 2 收敛复核

## Review Coverage
- 正确性：已覆盖
- 安全性：已覆盖
- 错误处理：已覆盖
- 并发/状态：已覆盖
- 设计：已覆盖
- 测试覆盖：已覆盖
- 注释准确性：已覆盖
- 向后兼容：已覆盖
- 性能：已覆盖
- 可观测性：已覆盖

## Round 1
- 审查-A：
  - 检查 Codex 安装适配是否仍生成不会生效的 `hooks:` frontmatter。
  - 检查 Claude 真实探针是否仍可能被本地 mock/probe 服务与旧会话污染。
- 审查-B：
  - 检查能力矩阵、发布检查清单、回滚 SOP 是否与真实运行边界一致。
  - 检查新增测试是否覆盖安装产物与运行验收链路。
- 审查-C：
  - 检查探针脚本输出是否足以定位失败原因。
  - 检查新增校验是否引入不必要的高成本执行。

## Round 2
- 复核 `install.sh` 的 Codex skill 文档重写逻辑在 staging 阶段执行，未污染共享源码层。
- 复核 `tests/run-all.sh` 已把新增探针脚本和 Codex adapter 测试纳入静态校验与回归入口。
- 复核 `docs/capability-matrix.md`、`docs/release-checklist.md` 的口径与本机实测结果一致。
- 复核结论：未发现新增阻断问题，Round 1 关注点已收敛。

## Findings
- 无置信度 >= 80 的正式问题。

## Excluded Potential Issues
1. EX-001 已排除：Codex 安装产物仍保留 dead hooks 配置，误导团队以为会自动执行。
   - Evidence:
   - [install.sh](/Users/lijieli/org-claude-skills/install.sh#L252) 在 Codex staging 阶段删除 frontmatter `hooks:`，并对含 `completion_check.sh` 的 skill 注入显式执行说明。
   - [install.sh](/Users/lijieli/org-claude-skills/install.sh#L339) 仅在 `build_staging_codex` 中调用该重写逻辑，没有回写共享源码层。
   - [test-codex-skill-adapter.sh](/Users/lijieli/org-claude-skills/tests/test-codex-skill-adapter.sh#L23) 通过真实安装样本验证 frontmatter 无 `hooks:`、旧文案被替换。
   - Confidence: 95

2. EX-002 已排除：Claude 真实探针仍可能因固定 token、本地 mock/probe 服务或旧会话污染而出现假阳性。
   - Evidence:
   - [probe-claude-capabilities.sh](/Users/lijieli/org-claude-skills/tools/dev/probe-claude-capabilities.sh#L25) 使用唯一 token 生成器，避免固定响应误判。
   - [probe-claude-capabilities.sh](/Users/lijieli/org-claude-skills/tools/dev/probe-claude-capabilities.sh#L59) 显式检查 `ANTHROPIC_BASE_URL` 指向的 localhost 监听进程，发现 `mock_` 或 `/probe/` 直接报 `[FAIL]`。
   - [probe-claude-capabilities.sh](/Users/lijieli/org-claude-skills/tools/dev/probe-claude-capabilities.sh#L107) [probe-claude-capabilities.sh](/Users/lijieli/org-claude-skills/tools/dev/probe-claude-capabilities.sh#L127) [probe-claude-capabilities.sh](/Users/lijieli/org-claude-skills/tools/dev/probe-claude-capabilities.sh#L183) [probe-claude-capabilities.sh](/Users/lijieli/org-claude-skills/tools/dev/probe-claude-capabilities.sh#L234) [probe-claude-capabilities.sh](/Users/lijieli/org-claude-skills/tools/dev/probe-claude-capabilities.sh#L267) 全部加了 `--no-session-persistence`，隔离历史会话状态。
   - Confidence: 93

3. EX-003 已排除：新增运行验收要求未进入统一回归入口，导致文档更新但自动化不跟进。
   - Evidence:
   - [run-all.sh](/Users/lijieli/org-claude-skills/tests/run-all.sh#L6) 已把新增探针脚本和 `test-codex-skill-adapter.sh` 纳入 bash 语法检查。
   - [run-all.sh](/Users/lijieli/org-claude-skills/tests/run-all.sh#L20) 已把同一批脚本纳入 `shellcheck`。
   - [run-all.sh](/Users/lijieli/org-claude-skills/tests/run-all.sh#L57) 已把 `codex skill adapter test` 纳入全量回归。
   - Confidence: 92

## Verification
- Critical/High findings：无
- Verification 状态：N/A

## REVIEW_A
- 结论：PASS
- 说明：未发现正确性、安全性、错误处理、并发/状态层面的阻断缺陷。

## REVIEW_B
- 结论：PASS
- 说明：设计与文档口径已对齐真实边界；发布与回滚流程不再引导在错误目录执行 Codex 验证。

## REVIEW_C
- 结论：PASS
- 说明：新增探针输出具备失败定位信息，执行成本仍以发布前验收为主，没有引入不可接受的常态性能负担。

## Test Evidence
- 自动化回归：`bash tests/run-all.sh` -> `All tests passed`
- 本机运行验证：`bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills`
  - Claude：全部 PASS
  - Codex：skills/agents PASS；hooks 边界保持显式 WARN

## Final Verdict
- RESULT: PASS
- FINAL: APPROVE

