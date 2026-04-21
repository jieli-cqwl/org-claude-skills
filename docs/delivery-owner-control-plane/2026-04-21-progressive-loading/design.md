# Delivery Owner Progressive Loading Design

## 背景

`delivery-owner` 当前已经具备完整交付治理能力：承接已确认的 plan/design/test-cases，组织开发执行、代码审查、QA 验收、签收与提交，并维护全链路证据。它的问题不在于角色方向错误，而在于运行入口承载了过多状态、分级、字段和专家执行细节，导致 LLM 在进入流程时同时看到“该做什么”和“每个专家怎么做”，容易把控制面误用成执行手册。

用户已明确边界：轻量需求由 `small-chain` 承接；进入 `delivery-owner` 的任务天然是完整交付流程。因此，`delivery-owner` 不需要在自身内部继续维护轻量、标准、完整三档，也不需要为了复杂度治理设计自动升档路径。它要成为稳定的交付控制面：判断输入是否齐备、调度专家、消费专家证据、做流程裁决、推动签收。

## 问题陈述

当前运行内容有四类噪音：

1. 主入口过密：`SKILL.md` 内联 Phase 3 分级矩阵、动态升档、运行态字段、汇总代理触发、修复循环细节和模板字段引用。
2. 二级文档过密：`dispatch-guide.md` 同时描述派发合同、运行态协议、developer/verifier/fixer 具体 SOP、worktree merge 步骤和 replan 字段表。
3. 责任边界漂移：`delivery-owner` 应消费 `developer`、`review`、`qa`、`fix` 的输出，但当前文档会重复解释专家怎么做事。
4. 质量矩阵漂移：Phase 3 同时存在 plan grade、脚本矩阵、文档矩阵和动态升档映射，轻量路径的存在还会让人误以为该 skill 也服务小改动。

这些复杂度属于 Accidental Complexity。保留它们不能提升交付正确性，反而增加加载成本、维护成本和误触发风险。

## 目标

- 将 `SKILL.md` 收敛为运行入口：硬门禁、角色边界、前置条件、流程骨架、引用路由、输出和完成校验。
- 将 `delivery-owner` 明确为完整流程控制面，不再维护轻量、标准、完整分级。
- 将 Phase 3 固定为完整门禁：`REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_B + QA_C + QA_D`。
- 保留治理动作，但去掉“自动升档复杂度”叙事。运行裁决只保留 `CONTINUE / FIX / REPLAN / BLOCK / ESCALATE` 等控制动作。
- 将 `dispatch-guide.md` 降噪为派发合同：围绕需求、目标、验收标准、输入证据、输出证据和裁决条件组织内容。
- 不在 `delivery-owner` 文档中复制专家 SOP。`developer` 负责 TDD 实施，`review` 负责审查方法，`qa` 负责验收方法，`fix` 负责根因定位与最小修复。
- 保持 canonical JSON 与 active registry 的运行权威不变，legacy markdown 只作为人类投影视图或历史材料。

## 成功判定

| 目标 | 成功信号 | 验证方式 |
| --- | --- | --- |
| 主入口降噪 | `SKILL.md` 不再内联 Phase 3 分级、动态升档、专家 SOP 和 runtime 字段表 | contract test + `rg` 回归断言 |
| 完整流程固定 | Phase 3 固定包含 REVIEW_A/B/C 与 QA_A/B/C/D | `tests/test-delivery-owner-phase3-contract.sh` |
| 派发合同聚焦 | `dispatch-guide.md` 围绕 requirement/goal/AC/scope/evidence/control decision 组织 | contract test 禁止专家伪代码回流 |
| 专家边界清晰 | `delivery-owner` 只消费专家产物，不复制专家方法 | SKILL 文案断言 + reference noise 断言 |
| 下游同步 | completion gate、manifest、QA template、tech-lead template/test 不再依赖分级裁剪 | 相关 shell tests 全部通过 |

## 非目标

- 不把轻量路径重新设计进 `delivery-owner`。轻量需求继续走 `small-chain`。
- 不削弱完整交付门禁，不减少 REVIEW/QA 真实验证要求。
- 不重命名 skill，不把现有用户调用心智改成新的命令。
- 不让 `delivery-owner` 亲自实现代码、写 QA 结论或替用户接受风险。
- 不在本设计里改 small-chain、developer、qa、review、fix 的内部 SOP。

## 设计原则

Essential Complexity 需要保留：完整交付天然有多角色、多证据、多门禁、签收和风险接受，因此必须保留控制动作、证据链、签收边界和熔断。

Accidental Complexity 需要删除：轻量/标准/完整分级、动态升档映射、专家执行伪代码、重复字段表、legacy 叙事和模板细节不应挤在主入口或 Phase 2 派发指南中。

渐进式加载的边界是“当前步骤需要什么就读什么”。主入口只说明何时读取 reference，以及读取后期待拿到什么合同；reference 也只写该步骤的控制合同，不承载专家技能的完整手册。

## 复用决策

本设计复用标准链路已有结构裁决：`HARD-GATE / Runtime Authority / 角色 / 前置条件 / 流程 / 输出 / 完成校验`。不新增新的 skill 结构模板。

本设计复用现有 canonical JSON、active registry、completion gate 和 shell contract test 机制。新增质量约束优先落到现有测试中，不创建新的旁路验证体系。

本轮保留 `scripts/phase3-grade-matrix.sh` 文件名，是为了复用现有 `delivery-owner` 与 `tech-lead` gate 引用路径；只修改它表达的运行语义。旧函数名和旧 grade 参数短期保留兼容，但函数忽略 `轻量/标准/完整` 差异，统一返回完整门禁。后续重命名为 full-gate helper 属于独立清理，不混入本轮。

## 复核裁决

本设计已经按当前仓库实现复核过以下风险，并把裁决纳入本轮范围：

| 复核点 | 裁决 | 设计处理 |
| --- | --- | --- |
| `phase3-grade-matrix.sh` 是否直接拒绝旧 grade 参数 | 不直接拒绝。现有 `delivery-owner` 与 `tech-lead` gate 会传入 `plan_grade`，直接拒绝会破坏 gate | 文件名、函数名、旧参数兼容；分支语义归一为完整门禁 |
| canonical 与 legacy 是否混用 | 需要分层。canonical `plan.json` 当前没有 Phase 3 分级字段，旧分级主要存在于 legacy `plan.md`、模板、hook 与测试 fixture | canonical lane 不新增 plan grade；legacy markdown lane 移除分级口径 |
| `allowed-tools` 是否要收紧 | 要收紧。控制面不应持有主实现编辑能力 | `delivery-owner` frontmatter 移除 `Edit`；hook 仍可监听 `Edit|Write`，这是运行门禁触发面，不代表 skill 主代理权限 |
| code review 模板是否属于范围 | 属于范围。模板仍有 `审查分级` 和 metadata `grade`，会让旧口径回流 | 纳入变更范围和测试断言 |
| rollout/replay 是否还能保留“动态升档”维度 | 不能保留为当前真源。该维度与固定完整门禁冲突 | 改为“偏差治理 / 完整门禁承接”口径，并归档旧 role 文档 |

## 目标结构

| 文件 | 保留职责 | 下沉或删除 |
| --- | --- | --- |
| `shared/skills/delivery-owner/SKILL.md` | 硬门禁、运行权威、角色边界、前置条件、完整流程骨架、reference 路由、输出、完成校验 | Phase 3 分级矩阵、动态升档规则、运行态字段表、专家 SOP、模板字段细节 |
| `references/dispatch-guide.md` | Phase 2 派发合同：需求、目标、AC、文件范围、证据输入、专家输出、控制裁决、replan 边界 | developer TDD 步骤、verifier 分阶段伪代码、fix 详细 SOP、worktree 操作手册、过细 runtime 字段表 |
| `references/phase3-dispatch.md` | Phase 3 完整门禁合同、REVIEW/QA handoff、fix-loop 控制、风险接受边界、汇总代理越权边界 | 轻量/标准/完整矩阵、动态升档章节、按分级裁剪执行说明 |
| `scripts/phase3-grade-matrix.sh` | 本轮保留文件名以降低 `completion_check.sh` 与 `tech-lead` gate 的同步风险，但语义改为固定完整门禁 helper | 不再按 `轻量/标准/完整` 裁剪门禁；旧参数只做兼容输入，不再驱动分支；不再提供 escalation stage helper |
| `tests/test-delivery-owner-phase3-contract.sh` | 验证完整门禁、引用合同、无分级回退、无动态升档回退 | 旧分级矩阵断言和旧 QA template 分级断言 |
| `scripts/manifest.json` | 声明脚本权限、参数、超时和验证命令 | 不再把 `phase3-grade-matrix` 描述成分级矩阵 |

## 变更范围

| 范围 | 变更类型 |
| --- | --- |
| `shared/skills/delivery-owner/SKILL.md` | 主入口降噪，固定完整流程，更新 reference 路由和完成校验；frontmatter 移除 `Edit` |
| `shared/skills/delivery-owner/references/dispatch-guide.md` | 改为 Phase 2 派发合同，删除专家 SOP 与过细字段表 |
| `shared/skills/delivery-owner/references/phase3-dispatch.md` | 改为固定完整 Phase 3 gate 合同，删除分级与动态升档 |
| `shared/skills/delivery-owner/references/templates/code-review-report-template.md` | 删除 `审查分级` 与 metadata `grade`，固定 REVIEW_A/B/C |
| `shared/skills/delivery-owner/scripts/phase3-grade-matrix.sh` | 保留文件名，语义改为 fixed full gate helper |
| `shared/skills/delivery-owner/scripts/completion_check.sh` | canonical lane 继续走 readiness validator；legacy lane 从按分级校验改为完整门禁证据校验 |
| `shared/skills/delivery-owner/scripts/manifest.json` | 更新 helper 描述、失败信息和验证命令口径 |
| `shared/skills/tech-lead/references/templates/plan-template.md` | legacy markdown 模板移除 Phase 3 审查分级字段；canonical `plan.json` schema 不新增 grade |
| `shared/skills/tech-lead/scripts/completion_check.sh` | legacy markdown hook 不再要求 plan 分级矩阵；保留 canonical phase validator 路径 |
| `shared/skills/qa/references/templates/qa-report-template.md` | 同步固定完整 QA_A/B/C/D 验收口径 |
| `shared/skills/qa/scripts/completion_check.sh` | canonical `qa-result.json` 继续以 schema 和 readiness 为准；legacy `qa-report.md` 不再要求审查分级 |
| `tests/` 相关 delivery-owner、tech-lead、qa、standard-chain contract tests | 先 RED 后 GREEN，防止旧分级和专家 SOP 回流 |
| `tools/eval/graders/task-constraint-grader.md` | 将“分级匹配”评分改为“完整门禁与证据链承接”评分 |
| `docs/delivery-owner-role-20260411/` | 归档到 `docs/archive/`，避免旧 PM/分级/动态升档口径污染上下文；若测试仍需 fixture，则迁移到测试 fixture 目录 |

## 主入口运行形态

`SKILL.md` 保留五段控制面语义：

- 输入门禁：plan/design/tasks/test-cases/canonical registry 和用户执行确认齐备。
- Phase 1：kickoff readiness，缺证据即暂停。
- Phase 2：按 plan 调度专家，消费 developer/verify/fix 产物，维护 `delivery-state.json`。
- Phase 3：执行固定完整 Review/QA 门禁，消费 `code-review-result.json` 和 `qa-result.json`。
- Sign-off/Commit：生成 `signoff-package.json`，用户签收后再提交。

`SKILL.md` 中的 reference 路由采用契约式引用。每个被引用文档都需要能回答：

- Trigger：什么时候读。
- Read：读取哪些事实源。
- Expect：读完后必须拿到什么判断或合同。
- Consume：谁消费该合同。
- Evidence：哪些测试或 gate 证明它仍有效。
- Sync：变更时需要同步哪些文件。

`delivery-owner` 主代理不保留 `Edit` 权限。它可以写入交付控制工件，可以运行确定性脚本，可以派发专家；实现代码改动只能由 `developer` 或 `fix` 承接。completion gate 继续监听 `Edit|Write`，因为 hook 需要拦截运行时文件写入事件；该监听面不等于 `delivery-owner` 主代理可直接编辑实现文件。

## Phase 3 固定门禁

Phase 3 不再读取 `plan.json` 的审查分级作为裁剪依据。进入 `delivery-owner` 就执行完整门禁：

| 类型 | 固定阶段 | 责任边界 |
| --- | --- | --- |
| Code Review | `REVIEW_A + REVIEW_B + REVIEW_C` | review/code-reviewer 独立产出结论，delivery-owner 消费结果 |
| QA | `QA_A + QA_B + QA_C + QA_D` | qa 独立产出 `qa-result.json`，delivery-owner 消费结果 |
| Fix Loop | 对未通过项触发 fix/developer，重跑对应门禁 | delivery-owner 控制循环与熔断，不替专家判断 |
| Risk / Waiver | 仅用户可接受残余业务风险 | delivery-owner 准备证据包，不替用户签收 |

固定完整门禁不是“更重”的选择，而是入口职责的收敛：小任务不进该路径，进来的任务就需要完整交付控制。

## 派发合同

`dispatch-guide.md` 的核心不再是“专家怎么执行”，而是“delivery-owner 怎样给专家一个可执行合同，并怎样根据专家证据裁决下一步”。

派发合同包含：

- Requirement：这次 Task 要解决的需求或问题。
- Goal：该 Task 对 Phase 目标的贡献。
- Acceptance Criteria：可验证验收标准、test_ref、proving command。
- Scope：允许修改的文件、禁止越界的边界、共享文件冲突。
- Evidence In：冻结的 plan/design/test-cases、已有 runtime state、相关问题证据。
- Evidence Out：developer-report、verify-result、fix evidence、更新后的 delivery-state。
- Control Decision：`CONTINUE / FIX / REPLAN / BLOCK / ESCALATE` 的触发条件。

专家内部方法不在该文档展开。派发时只需要点名目标专家、输入、输出和验收基线。

## 证据与签收边界

`delivery-owner` 的签收依据仍然是 canonical artifacts：

- Task 级：`developer-report.json`、`verify-result.json`。
- Phase 级：`delivery-state.json`、`code-review-result.json`、`qa-result.json`、`signoff-package.json`。
- 用户裁决：`user-decision.json`。

`delivery-owner` 可以汇总证据、发现缺口、要求补证据、暂停和升级；不能写入专家结论，不能接受业务风险，不能把 legacy markdown 当作 gate 真源。

## 下游影响

| 影响对象 | 变化 |
| --- | --- |
| `delivery-owner` 用户 | 看到的是完整交付控制面，不再在该 skill 内选择轻量/标准/完整 |
| `tech-lead` 输出 | canonical `plan.json` 无 Phase 3 grade；legacy `plan.md` 移除审查分级章节，不再驱动 `delivery-owner` Phase 3 裁剪 |
| `review` / code-review 投影视图 | 删除 `审查分级` 与 metadata `grade`，固定 REVIEW_A/B/C |
| `qa` 模板 | 删除分级描述，固定 full 执行范围下 QA_A/B/C/D 均有结果 |
| completion gate | canonical lane 保持 readiness validator；legacy lane 从“分级匹配”改成“完整门禁证据齐备” |
| `tech-lead` gate | 目前会 source `delivery-owner/scripts/phase3-grade-matrix.sh`；本轮保留文件名，改函数语义，避免跨 skill gate 找不到脚本 |
| `tests/test-skill-output-and-gate-contract.sh` | 存在旧 `审查分级` fixture 与断言，需要同步为完整门禁口径 |
| `tools/eval/graders/task-constraint-grader.md` | 仍把 Phase 3 分级当计划质量维度，需要调整为“完整门禁承接与证据链完整性” |
| replay/rollout 测试 | `quality escalation` 与 `动态升档` 改为“偏差治理 / 完整门禁承接”口径 |
| 历史文档 | 旧 role 目录归档；当前设计目录成为本轮有效设计真源 |

## 测试策略

测试先验证回退，再驱动实现：

- `test-delivery-owner-phase3-contract.sh` 先改成 RED：断言 `SKILL.md` 和 `phase3-dispatch.md` 不出现轻量/标准分级和动态升档章节，且固定包含完整 REVIEW/QA 阶段。
- phase3 helper 测试断言旧 grade 参数兼容但统一返回完整门禁；文件名本轮保留，manifest 文案改为 full gate contract。
- dispatch guide 测试断言保留 Trigger/Read/Expect/Consume/Evidence/Sync，并禁止出现专家执行伪代码与 developer TDD 手册型段落。
- code-review 与 QA 模板测试断言不再出现 `审查分级` / metadata `grade` / 轻量标准裁剪说明。
- allowed-tools 测试断言 `delivery-owner` frontmatter 不含 `Edit`，同时 runtime adapter contract 仍说明 hook 监听 `Edit|Write`。
- manifest 测试断言脚本描述不再叫 grade matrix，验证命令指向新的 Phase 3 contract。
- replay/rollout 测试断言旧 `动态升档` 维度已经替换为“偏差治理 / 完整门禁承接”。
- 运行全量相关测试，至少覆盖 `tests/test-delivery-owner-phase3-contract.sh`、replay contract、rollout gate、standard-chain skill structure、`tests/test-skill-output-and-gate-contract.sh`。

## 备选方案

| 方案 | 优点 | 代价 | 裁决 |
| --- | --- | --- | --- |
| 保留现状，仅删少量文案 | 风险最小 | 不能解决主入口密集和分级误导 | 拒绝 |
| 在 `delivery-owner` 内新增轻量 lane | 可覆盖更多任务类型 | 与用户边界冲突，也与 single responsibility 冲突 | 拒绝 |
| 固定完整流程并做渐进式加载 | 角色清晰，分流清晰，主入口降噪，测试可证明 | 需要同步脚本、测试和部分模板口径 | 采用 |

## 风险

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| 删除分级后旧 legacy 计划仍带 `Phase 3 审查分级` | LLM 继续读取旧字段 | legacy 模板和测试 fixture 同步删除；canonical plan schema 不新增 grade |
| 二级文档降噪过度 | 派发合同丢失必要边界 | 保留 requirement/goal/AC/scope/evidence/control decision 七要素 |
| helper 名称仍含 grade | 名称存在历史噪音 | 本轮为保护 gate 稳定保留文件名，manifest 和注释改成 fixed full gate contract；重命名进入后续独立清理 |
| 移除 `Edit` 后 hook 触发口径被误删 | completion gate 漏拦截编辑写入事件 | 明确区分 skill 主代理工具权限与 hook runtime 监听面；hook 仍保留 `Edit|Write` |
| 历史文档继续污染上下文 | 后续 agent 读到旧 PM/分级口径 | 按文档管理规则归档旧 role 目录；测试需要的样例迁移到 fixture |
| 完整门禁被误解为所有任务默认路径 | 小改动流程变重 | 在角色边界写清：轻量需求走 `small-chain`，该 skill 只服务完整交付 |

## 不变量

- `delivery-owner` 是交付控制面，不是实现、审查、QA 或用户签收代理。
- 轻量需求不进入 `delivery-owner`。
- Phase 3 固定完整 REVIEW/QA 门禁。
- 专家 skill 保留自己的 SOP，`delivery-owner` 只定义 handoff 和消费合同。
- canonical JSON 与 active registry 是运行事实源。
- 非 canonical markdown 只做人类投影视图或历史材料。
- 用户签收与业务风险接受不可被 agent 代替。
