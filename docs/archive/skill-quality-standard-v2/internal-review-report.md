# Skill 质量标准 v2 内部 Review 处置报告

## 范围

本轮 review 覆盖以下对象：

| 对象 | 预期结果 |
| --- | --- |
| `docs/skill-quality-standard-v2/design.md` | Harness Engineering 背景、D1-D8、L1-L3、消费方关系与运行时裁决一致 |
| `shared/reference/Skill质量标准.md` | v2 正文与设计裁决一致，旧 D1-D7 不再作为主评级体系 |
| `shared/skills/skill-optimizer/` | 审计、计划、验证 artifact 能消费 v2 质量标准 |
| `shared/skills/scan/` | 静态扫描规则覆盖 v2 可机械检测子集 |
| `tests/` | 新标准、runtime artifact、eval、安装与运行时门禁可复验 |

## Review Team 维度

| Agent | 审查维度 | 初始结论 | 处置状态 |
| --- | --- | --- | --- |
| A1 | 标准架构与旧 D1-D7 迁移一致性 | REQUEST_CHANGES | 修复映射漂移与 D8 scan 关系 |
| A2 | Harness runtime、JSON fact source、consumer-first | COMMENT | 保持方向，增强验证链路 |
| A3 | `skill-creator` 与 `skill-optimizer` 边界 | COMMENT | 保持边界，未让标准接管创建流程 |
| A4 | optimizer artifact 消费者合同 | REQUEST_CHANGES | findings 字段、schema、semantic validator 已收紧 |
| A5 | scan 与静态门禁覆盖 | REQUEST_CHANGES | R1-R8、硬预算、非最终结论已固化 |
| A6 | 权限、脚本 manifest、外部写边界 | REQUEST_CHANGES | 只读工具、output roots、failure message、外部写信号已固化 |
| A7 | verification 链与 runtime catalog 裁决 | REQUEST_CHANGES | catalog 裁决修正，plan contract 与 verification-result 绑定 |
| A8 | Challenger：完整性、自证与脚本边界 | REQUEST_CHANGES | eval runner 去除 category 查表，补 audit fixture 边界，`audit_skill.py` 标记 deterministic-smoke |

## 关键裁决

| 问题 | 风险 | 裁决 | 固化位置 |
| --- | --- | --- | --- |
| 旧 D4/D6 到 v2 维度映射漂移 | reviewer 与 optimizer 口径分裂 | D4 增补 D8；D6 绑定 D2/D3/D7 | `shared/skills/skill-optimizer/references/d1-d7-mapping.md` |
| scan 规则缺 D8 | 可读复用质量无法进入静态信号 | scan 关系表与规则加入 D8 | `shared/reference/Skill质量标准.md`、`docs/skill-quality-standard-v2/design.md` |
| runtime catalog 是否全局挂载标准 | 全局 rules 噪音扩大 | 不全局挂载；通过 adapter、install、runtime 测试保持可达 | `docs/skill-quality-standard-v2/design.md`、`tests/test-runtime-contract-catalog.sh` |
| `Skill质量标准.md` 只描述文档质量 | 运行时稳定性无合同 | v2 改为 Harness Engineering 质量合同 | `shared/reference/Skill质量标准.md` |
| context budget 只做总量软提示 | `SKILL.md` 主入口过重无法阻断 | 增加按类型的 `SKILL.md` 硬预算；总量保留软信号 | `tests/test-skill-context-budget.sh` |
| scan 仍停在旧 R1-R5 | 静态巡检落后于 v2 标准 | 扩展为 R1-R8，补外部写 API 与裸 Bash 写入风险 | `shared/skills/scan/SKILL.md`、`shared/skills/scan/references/skills-scan-rules.md` |
| audit/review 类 Skill 默认持有写工具 | 审计阶段越权 | `skill-optimizer` audit 入口改为只读；权限 profile 明确写操作需授权与范围 | `shared/skills/skill-optimizer/SKILL.md`、`rules/permission-profiles.md` |
| script manifest 缺输出边界 | 脚本可写位置无法审计 | manifest 强制 `allowed_output_roots` 与 `failure_message` | `scripts/manifest.json`、`scripts/validate_manifest.py` |
| finding 缺 `dimension/impact/verification` | 下游 plan 无法精确消费 | schema 与 semantic validator 强制三字段，并拦截旧维度标签 | `schemas/skill-audit.schema.json`、`scripts/validate_semantics.py` |
| `audit_skill.py` 覆盖面被误读为完整审计 | 工具 smoke 被当成最终裁决 | artifact 加 `scope.mode = deterministic-smoke`，完整 D1-D8 仍由 v2 审计链承担 | `scripts/audit_skill.py`、`references/audit-method.md` |
| eval runner 用 category 推导结果 | 自证式 benchmark | observed decision 改由输入与信号推导，增加 audit fixture case，并校验 manifest allowed args | `scripts/run_evals.py`、`evals/README.md` |
| verification-result 固定 PASS | 计划与验证证据未强绑定 | accepted finding、file boundary、verification contract、fresh command 与 validator exit 必须逐项绑定 | `scripts/build_verification_result.py`、`schemas/verification-result.schema.json` |

## 证据命令

| 命令 | 结果 |
| --- | --- |
| `bash tests/test-skill-quality-standard-v2.sh` | PASS |
| `bash tests/test-skill-context-budget.sh` | exit 0；`SKILL.md` 硬预算 PASS；design、tech-lead 总量软 WARN |
| `bash tests/test-skill-optimizer-runtime-artifacts.sh` | PASS |
| `bash tests/test-skill-optimizer-evals.sh` | PASS |
| `bash tests/test-skill-optimizer-contract.sh` | PASS |
| `bash tests/test-skill-optimizer-migration.sh` | PASS |
| `bash tests/test-skill-optimizer-end-to-end.sh` | PASS |
| `bash tests/test-runtime-integrity.sh` | PASS |
| `bash tests/test-install-smoke.sh` | PASS |
| `bash tests/test-runtime-contract-catalog.sh` | PASS |
| `bash tests/test-skill-runtime-noise.sh` | PASS |
| `bash tests/test-codex-skill-adapter.sh` | PASS |
| `bash tests/test-install-systematic.sh` | PASS；19 passed，0 skipped |
| `git diff --check` | PASS |
| 目标文件禁词扫描 | no matches |

## 给 Claude 的评审关注点

1. 挑战 `Skill质量标准.md` v2 是否完整覆盖 D1-D8 的运行时风险。
2. 检查 `skill-optimizer` 是否只消费质量标准，不建立第二套评级体系。
3. 检查 JSON artifact、schema、semantic validator、rendered view、fresh command 的职责边界。
4. 检查 scan 的 R1-R8 是否只作为静态信号，不越权给最终质量结论。
5. 检查 `audit_skill.py` 的 deterministic-smoke 边界是否足够清晰。

## Claude Round 1 处置

| Finding | 裁决 | 处置 |
| --- | --- | --- |
| B-01 eval runner 自证 | 具体 category 查表已修；seed eval 边界仍需收口 | 增加 `audit-reference-broken-finding` 与 `audit-minimal-good-no-fail`，补 `evals/README.md` 声明 seed eval 不等于 live model benchmark |
| B-02 verification-result 固定 PASS | 采纳为阻塞项 | `build_verification_result.py` 直接运行 schema、semantic、consumer、rendered view、eval result validator；语义错误 artifact 被 e2e 反例拦截 |
| B-03 过时 `new-skills` 共存设计未归档 | 采纳为阻塞项 | `docs/skill-governance-rationalization-20260415/` 已归档到 `docs/archive/skill-governance-rationalization-20260415-superseded/` |

## Codex 自审 Round 2 处置

| Finding | 裁决 | 处置 |
| --- | --- | --- |
| SR-01 verification-result 最终校验前落盘 | 采纳为阻塞项 | `build_verification_result.py` 改为临时文件校验通过后原子替换；e2e 反例锁定最终 schema 失败时不留下正式 artifact |

## Codex 自审 Round 3 同类风险扫描

| 扫描对象 | 关注点 | 结论 |
| --- | --- | --- |
| runtime artifact producers | 是否存在第二个“PASS 结论早于证据落盘”路径 | 未发现新增阻塞；最终 PASS 只由 `verification-result.json` 承载 |
| `run_evals.py` | eval 失败时是否留下成功态 artifact | 失败 case 输出 `blocked` 并返回非 0，不发布 PASS 裁决 |
| `generate_optimization_plan.py` | `planned` 是否被当成最终质量结论 | plan 是中间 artifact，runtime test 与 final builder 在最终 PASS 前复核 |
| `audit_skill.py` | deterministic-smoke 是否被误读为完整审计 | artifact scope 声明人工复核维度，final builder 只把它作为输入证据 |
| `render_report.py` | rendered view metadata 是否先于视图证据 | metadata 写入前已生成视图；final builder 运行 `validate_rendered_views.py` 后才发布 PASS |

Round 3 裁决：无新增阻塞；保留 SR-02 边界说明，seed eval 不称为 live model benchmark。

## Codex 自审 Round 3 Fresh Proving

| 命令 | 结果 |
| --- | --- |
| `bash tests/test-skill-quality-standard-v2.sh` | PASS |
| `bash tests/test-skill-context-budget.sh` | exit 0；`skill-optimizer` PASS；design、tech-lead 保留既有软 WARN |
| `bash tests/test-skill-optimizer-runtime-artifacts.sh` | PASS |
| `bash tests/test-skill-optimizer-evals.sh` | PASS |
| `bash tests/test-skill-optimizer-contract.sh` | exit 0 |
| `bash tests/test-skill-optimizer-migration.sh` | PASS |
| `bash tests/test-skill-optimizer-end-to-end.sh` | PASS |
| `bash tests/test-runtime-integrity.sh` | PASS |
| `bash tests/test-install-smoke.sh` | PASS |
| `bash tests/test-runtime-contract-catalog.sh` | PASS |
| `bash tests/test-skill-runtime-noise.sh` | PASS |
| `bash tests/test-codex-skill-adapter.sh` | PASS |
| `bash tests/test-install-systematic.sh` | PASS；19 passed，0 skipped |
| `bash tests/test-skill-output-and-gate-contract.sh` | PASS |
| `git diff --check` | PASS |
| 目标文件禁词扫描 | no matches |

## Claude Round 2 处置

| Finding | 裁决 | 处置 |
| --- | --- | --- |
| NB-04 `derive_observed_decision()` 关键词优先级隐式 | 非阻塞，采纳为交付前小修 | 增加 `priority-conflict-markdown-over-fork` eval case，确认格式注入风险优先于 fork 工作流路由；`run_evals.py` 函数说明同步优先级语义 |

| 命令 | 结果 |
| --- | --- |
| RED：`bash tests/test-skill-optimizer-evals.sh` | 失败于 `one or more eval cases failed` |
| GREEN：`bash tests/test-skill-optimizer-evals.sh` | PASS |

## Review 环节经验沉淀

| 目标 | 处置 |
| --- | --- |
| 将 Claude 抓到的证据链问题转成 review 机制 | `/review` 增加“证据链完整性专项”，触发范围限定为 skill、eval、validator、artifact、installer 和 runtime gate 改动 |
| 保留现有十维审查，不增加普通业务 review 噪音 | 专项通过 `references/evidence-integrity-review.md` 渐进加载；`SKILL.md` 只记录触发条件和输出要求 |
| 把 10 个复盘维度变成可复用检查项 | 新增 EI-1 到 EI-10，覆盖自证检测、声称/证据一致、负例驱动、过时材料、行为边界、消费者、权限、漂移、失败产物污染和回归证明 |
| 让报告和 gate 能承接专项 | `code-review-report-template.md` 增加“证据链完整性专项”记录区；新增 `test-review-evidence-integrity-contract.sh`，并接入 `test-skill-output-and-gate-contract.sh` |

| 验证命令 | 结果 |
| --- | --- |
| `bash tests/test-review-evidence-integrity-contract.sh` | PASS |
| `bash tests/test-skill-output-and-gate-contract.sh` | PASS |
| `bash tests/test-skill-context-budget.sh` | exit 0；`review` PASS |
| `bash tests/test-codex-skill-adapter.sh` | PASS |
