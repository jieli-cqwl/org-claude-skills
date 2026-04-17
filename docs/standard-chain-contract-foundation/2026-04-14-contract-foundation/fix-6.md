# Fix-6

## 目的
记录本轮合并 `main` 后的 product role split 对齐、canonical runtime 控制面统一、以及 review finding 后续复核修复的证据。

## 输入分析
- 输入来源清单：用户要求合并一次 `main`，并把 `main` 新增的 `product-director / product-manager` 拆分与本 feature 的 standard-chain canonical-only 目标统一处理。
- 重点风险：`product-director / product-manager` 拆分后可能重新引入 `brief.md / prd.md / review.md` 作为运行时真源；delivery/readiness gate 可能漏消费必要工件；merge-main 新增合同测试可能与 canonical 改造发生漂移。
- 差异说明：`fix-1` 至 `fix-5` 已收紧 readiness、validator、runtime dispatcher、signoff、review/verify/developer-report 等标准链路合同；本轮专注于把这些合同与 `main` 的产品角色拆分和安装/eval/agent 合同合并到同一条 runtime 控制面。

## 诊断阶段

### 已确认问题
| # | 问题 | 证据 | 结论 |
|---|------|------|------|
| 1 | `contracts/skill-chain.yaml` 在合并后无法同时表达 Director 初始化、Manager 完善同一 canonical 工件 | `tools/dev/validate-contracts.sh` 报 `DUPLICATE_OUTPUT: brief.json / phase-prd.json` | 需要显式表达 `operation: refine`，而不是回退为不同文件或绕过 validator |
| 2 | developer 输入仍以自然语言 `Task 全文(from phase-{N}/tasks.json)` 进入 artifact graph | `tools/dev/validate-contracts.sh` 报 `UNMET` | 合同层应使用 artifact-level `phase-{N}/tasks.json`，Task 全文是其中内容 |
| 3 | `main` 的 product/eval/source-anchor/install 测试仍存在 legacy md 断言 | `test-product-eval-contract.sh`、`test-product-context-signal-quality.sh`、`test-delivery-owner-source-anchor-contract.sh`、`test-install-smoke.sh` 曾失败 | 测试应区分 canonical runtime 真源与 legacy projection/审计 sidecar |
| 4 | product review 继承能力要求 `review.md` 审计锚点保留 | `test-product-inherited-capability-parity.sh` 要求 `review.md 产物契约` | 保留 legacy sidecar 合同，但明确不作为 standard-chain 下游控制输入 |

## 处置阶段

### 修复清单
| # | 修复点 | 文件 |
|---|--------|------|
| 1 | `skill-chain.yaml` 增加 product-manager 对 `brief.json / phase-prd.json` 的 `operation: refine`，并把 developer 输入改为 `phase-{N}/tasks.json` | `contracts/skill-chain.yaml` |
| 2 | `validate-contracts.sh` 支持显式 `refine/update/augment` 的同工件多阶段写入，仍对未声明重复输出 fail-closed | `tools/dev/validate-contracts.sh` |
| 3 | product-manager review contract 保留 `review.md` legacy 审计锚点，同时声明 canonical `review_conclusion / issue_ledger` 是运行时真源 | `shared/skills/product-manager/references/review-orchestration-contract.md` |
| 4 | design/tech-lead 下游边界改为只消费冻结后的 canonical 结论、WARN 承接和待设计/待计划项，不读取产品评审流水账 | `shared/skills/design/SKILL.md`、`shared/skills/tech-lead/SKILL.md` |
| 5 | Director markdown 模板补 `引用锚点合同`，同时指向 canonical JSON pointer 与 legacy 投影锚点 | `shared/skills/product-director/references/templates/brief-template.md`、`shared/skills/product-director/references/templates/phase-prd-template.md` |
| 6 | 将受影响测试从旧 md 真源断言切到 canonical/runtime 断言，并保留 fresh smoke benchmark 对 executor log 的运行时验证 | `tests/test-product-eval-contract.sh`、`tests/test-product-context-signal-quality.sh`、`tests/test-developer-contract-alignment.sh`、`tests/test-install-smoke.sh` |

## Fresh Evidence
- `bash tests/test-product-role-split-contract.sh`
- `bash tests/test-product-artifact-contract.sh`
- `bash tests/test-product-output-contract-reference.sh`
- `bash tests/test-product-inherited-capability-parity.sh`
- `bash tests/test-product-context-signal-quality.sh`
- `bash tests/test-product-eval-contract.sh`
- `bash tests/test-product-split-benchmark-contract.sh`
- `bash tests/test-standard-chain-cutover.sh`
- `bash tests/test-standard-chain-readiness-gate.sh`
- `bash tests/test-standard-chain-validator-stack.sh`
- `bash tests/test-standard-chain-runtime-state.sh`
- `bash tests/test-standard-chain-projection-replay.sh`
- `bash tests/test-skill-output-and-gate-contract.sh`
- `bash tests/test-codex-skill-adapter.sh`
- `bash tests/test-runtime-integrity.sh`
- `bash tests/test-install-smoke.sh`
- `bash tools/dev/validate-contracts.sh`
- `bash tests/test-subagent-context-contract.sh`
- `bash tests/test-developer-contract-alignment.sh`
- `bash tests/test-delivery-owner-source-anchor-contract.sh`
- `bash tests/test-install-systematic.sh`（19 passed, 0 skipped）
- `python3 -m py_compile shared/hooks/managed/codex_stop_dispatch.py tools/community/validate_standard_chain_readiness.py`
- `bash -n shared/skills/product-director/scripts/completion_check.sh shared/skills/product-manager/scripts/completion_check.sh tests/test-install-smoke.sh tests/test-product-eval-contract.sh tests/test-product-context-signal-quality.sh tools/dev/validate-contracts.sh`
- `git diff --check`

## 当前状态
- merge-main 冲突：已解析。
- product split 与 standard-chain canonical runtime 控制面：已统一。
- review finding 中的 readiness 必需工件覆盖：仍由 `tests/test-standard-chain-readiness-gate.sh` fresh 通过证明。
- 本轮新增 P0/P1：0。
