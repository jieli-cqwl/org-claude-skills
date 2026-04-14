# fix-1.md

## 输入分析
- 输入来源清单：
  - 本轮人工 review 发现的 4 个高优先级问题
  - `bash tests/test-skill-output-and-gate-contract.sh`
  - `bash tests/test-delivery-owner-contract-closure.sh`
  - 静态复核 `shared/skills/product/scripts/completion_check.sh`、`shared/skills/tech-lead/scripts/completion_check.sh`、`shared/skills/delivery-owner/scripts/completion_check.sh`
- work_dir 解析结果：
  - `/Users/lijieli/org-claude-skills/docs/feature--skill-contract--goal-evidence/2026-04-14-product-techlead-hardening`
- 问题数量汇总：
  - 2 个 FIXABLE 问题簇

差异说明（N > 1 时 REQUIRED）:
- N/A，本轮为首个 fix 报告

## 诊断阶段

### 环境快照
- 当前分支: `main`
- 工作树状态:
  - 修改中：`shared/skills/product/**`、`shared/skills/tech-lead/**`、`shared/skills/delivery-owner/scripts/completion_check.sh`、`tests/**`
  - 未跟踪：`docs/feature--skill-contract--goal-evidence/2026-04-14-product-techlead-hardening/plan.md`、`tasks.md`
- 最近 5 条提交:
  - `a0234fe docs: add contract foundation and research artifacts`
  - `d9493a8 docs: add product tech-lead goal evidence hardening design`
  - `ae6ba67 docs: add notebooklm skill research report`
  - `eb3d72e fix: restore qa producer in skill chain`
  - `c691461 docs: align delivery-owner rollout wording`
- 最近改动文件:
  - `shared/skills/product/scripts/completion_check.sh`
  - `shared/skills/tech-lead/scripts/completion_check.sh`
  - `shared/skills/delivery-owner/scripts/completion_check.sh`
  - `shared/skills/tech-lead/references/templates/plan-template.md`
  - `tests/test-skill-output-and-gate-contract.sh`
  - `tests/test-delivery-owner-contract-closure.sh`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | `tech-lead / delivery-owner` 目标闭环可被重复行假覆盖，且 `execution_basis_ref` 锚点校验过松 | 运行 `bash tests/test-skill-output-and-gate-contract.sh`，关注 `duplicate goal review rows`、`missing second upstream goal same count`、`invalid execution basis anchor`；再运行 `bash tests/test-delivery-owner-contract-closure.sh` | gate 会误拦合法“同一目标拆多行”，也会放过“重复第一目标掩盖第二目标缺失”与坏锚点 |
| 2 | `product` 观察型成功信号仍可被章节级说明假覆盖 | 运行 `bash tests/test-skill-output-and-gate-contract.sh`，关注 `product observation note should bind every observation goal` | 多个观察型目标只写一条说明也能通过；说明与具体目标未绑定 |

当前环境复现结论:
- 可复现/不可复现:
  - 可复现。新增 RED 场景在修复前能够稳定失败，修复后转绿。
- 不可复现时环境差异证据:
  - N/A

### 假设验证过程
每个问题至少 2 个已验证假设（结果为排除/确认/未决）。
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | 目标闭环误判 | 根因是按总行数比对，导致“一个目标拆多行”被误判为失败 | 在 `tests/test-skill-output-and-gate-contract.sh:685-717,2556-2558` 构造 `duplicate_brief_goal_rows`，运行总套件 | 确认 |
| 1 | 目标闭环误判 | 根因是只记录 `brief/phase` 是否出现过，没有逐个上游目标核对 | 在 `tests/test-skill-output-and-gate-contract.sh:696-706,2560-2562` 与 `tests/test-delivery-owner-contract-closure.sh:161-166` 构造“重复第一目标、漏第二目标但行数不变”场景 | 确认 |
| 1 | 目标闭环误判 | 只是 fixture 写错，不是 gate 逻辑问题 | 修复 `create_tech_lead_fixture` 中单引号 heredoc 的插入缺陷后重跑相同场景 | 排除 |
| 1 | 锚点误判 | 根因是 `execution_basis_ref` 只校验文件存在，没有校验真实锚点 | 在 `tests/test-skill-output-and-gate-contract.sh:708-716,2568-2570` 构造 `design.md#不存在的锚点`，运行总套件 | 确认 |
| 2 | 观察型说明假覆盖 | 根因是 gate 只检查章节内是否出现过一次 `观察型说明` | 在 `tests/test-skill-output-and-gate-contract.sh:1166-1168,2678-2687` 构造两个观察型目标但只写一条说明 | 确认 |
| 2 | 观察型说明假覆盖 | 根因是模板未要求目标级绑定，导致使用者误写 | 复核 `shared/skills/product/references/templates/brief-template.md:11` 与当前 gate 语义 | 排除。模板已经要求“每个观察型目标一行”，真正缺口在 gate |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | `tech-lead / delivery-owner` 目标闭环误判与锚点漏检 | `shared/skills/tech-lead/scripts/completion_check.sh:244-285,413-538`；`shared/skills/delivery-owner/scripts/completion_check.sh:2994-3115`；`shared/skills/tech-lead/references/templates/plan-template.md:62-63` | 原实现把“是否出现过某类来源”当作“所有上游目标都被承接”，并把锚点校验退化成“文件存在”；结果同时出现 false fail 和 false pass。模板说明还残留“可只写后续承接位置”，与 gate / skill 契约漂移。 | `tests/test-skill-output-and-gate-contract.sh:631-718,2548-2574` 直接构造 `tech-lead` fixture 并调用 gate；`tests/test-delivery-owner-contract-closure.sh:149-166` 直接构造 `acceptance-summary` 闭环场景，形成脚本逻辑与失败现象的一一对应 |
| 2 | `product` 观察型说明未与目标逐行绑定 | `shared/skills/product/scripts/completion_check.sh:113-188` | 原实现只做章节级存在性判断，缺少“每个观察型目标都要有自己的说明行”的约束；多个观察型目标时可被一条公共说明假覆盖。 | `tests/test-skill-output-and-gate-contract.sh:1051-1168,2656-2687` 通过 `create_product_goal_gate_fixture` 生成 RED 场景，并直接驱动 `product` gate |

## 处置阶段

### 决策
- 优先修复 gate 真实漏洞，再补回归测试，最后清理文档合同漂移。
- 不扩大范围到新的字段设计或新流程，只做最小闭环修复。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | `tech-lead / delivery-owner` 目标闭环误判与锚点漏检 | FIXABLE | 收紧锚点校验、逐目标承接校验，补 RED/GREEN 回归 |
| 2 | `product` 观察型说明未逐目标绑定 | FIXABLE | 收紧 `product` gate，补 RED/GREEN 回归 |

### FAIL-1: 目标闭环与锚点合同误判

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `shared/skills/tech-lead/scripts/completion_check.sh:244-285,413-538` 与 `shared/skills/delivery-owner/scripts/completion_check.sh:2994-3115` 把“来源出现过”误当“每个上游目标已承接”，且对 `execution_basis_ref` 缺少真实锚点校验；`shared/skills/tech-lead/references/templates/plan-template.md:62-63` 还有口径漂移。 |
| 2 | 修复是否完整？ | 已同时覆盖 `tech-lead` gate、`delivery-owner` gate、`tech-lead` 模板说明和对应回归测试，处理了 false fail、false pass、坏锚点漏检 3 条路径。 |
| 3 | 是否引入新问题？ | 主要风险是“多目标场景的匹配规则过严”。本轮通过“单目标允许摘要式表达、多目标要求逐项承接”的方式收口，并保留重复行合法拆分。 |
| 4 | 是否需要补充测试覆盖？ | 已补。新增 `duplicate_brief_goal_rows`、`missing_second_brief_goal_same_count`、`invalid_execution_basis_anchor` 以及 `delivery-owner contract closure` 对应场景。 |

RED:
- `bash tests/test-skill-output-and-gate-contract.sh`
  - 失败于 `duplicate goal review rows for one upstream goal should pass`
  - 失败于 `missing second upstream goal should fail even when row count matches`
  - 失败于 `invalid execution basis anchor should fail`
- `bash tests/test-delivery-owner-contract-closure.sh`
  - 失败于 `goal-missing-second-same-count`

GREEN:
- `bash tests/test-skill-output-and-gate-contract.sh` -> PASS
- `bash tests/test-delivery-owner-contract-closure.sh` -> PASS

### FAIL-2: 观察型成功信号未逐目标绑定

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `shared/skills/product/scripts/completion_check.sh:113-188` 只做章节级 `观察型说明` 检查，缺少“每个观察型目标独立说明”的逐行绑定校验。 |
| 2 | 修复是否完整？ | 已同时覆盖模板口径、`product` gate 和回归 fixture，明确要求按目标匹配 `观察型说明：目标=...; 原因=...; 替代观测信号=...`。 |
| 3 | 是否引入新问题？ | 风险较低；主要是旧文档若只写章节级说明会被新 gate 拦截，但这正是期望收紧的合同。 |
| 4 | 是否需要补充测试覆盖？ | 已补。新增 `observation_without_note` 和 `observation_partial_note` 两个场景。 |

RED:
- `bash tests/test-skill-output-and-gate-contract.sh`
  - 失败于 `product observation signal should require note`
  - 失败于 `product observation note should bind every observation goal`

GREEN:
- `bash tests/test-skill-output-and-gate-contract.sh` -> PASS
- `bash tests/test-product-stability-guidance-contract.sh` -> PASS

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | `tech-lead` 目标闭环误判 | 行数对比 + 布尔覆盖判断过粗 | `shared/skills/tech-lead/scripts/completion_check.sh` | `bash tests/test-skill-output-and-gate-contract.sh` |
| 2 | `tech-lead` 锚点漏检 | `execution_basis_ref` 未校验真实锚点 | `shared/skills/tech-lead/scripts/completion_check.sh` | `bash tests/test-skill-output-and-gate-contract.sh` |
| 3 | `delivery-owner` 目标闭环误判 | 与 `tech-lead` 同类的布尔覆盖判断过粗 | `shared/skills/delivery-owner/scripts/completion_check.sh` | `bash tests/test-delivery-owner-contract-closure.sh` |
| 4 | `product` 观察型说明假覆盖 | 仅章节级 grep，无目标级绑定 | `shared/skills/product/scripts/completion_check.sh` | `bash tests/test-skill-output-and-gate-contract.sh` |
| 5 | 模板口径漂移 | 模板允许“只写后续承接位置”，与 gate/skill 不一致 | `shared/skills/tech-lead/references/templates/plan-template.md` | `bash tests/test-skill-output-and-gate-contract.sh` |
| 6 | 回归盲区 | 缺少重复行、坏锚点、局部说明等负例 | `tests/test-skill-output-and-gate-contract.sh`、`tests/test-delivery-owner-contract-closure.sh` | 同上 |

### 全量测试结果
TEST_CMD: `bash tests/test-product-stability-guidance-contract.sh`
- 通过: 1 / 失败: 0 / 跳过: 0

TEST_CMD: `bash tests/test-skill-output-and-gate-contract.sh`
- 通过: 1 / 失败: 0 / 跳过: 0

TEST_CMD: `bash tests/test-delivery-owner-contract-closure.sh`
- 通过: 1 / 失败: 0 / 跳过: 0

TEST_CMD: `bash tests/test-delivery-owner-source-anchor-contract.sh`
- 通过: 1 / 失败: 0 / 跳过: 0

TEST_CMD: `bash tests/test-delivery-owner-phase3-contract.sh`
- 通过: 1 / 失败: 0 / 跳过: 0

TEST_CMD: `git diff --check`
- 通过: 1 / 失败: 0 / 跳过: 0

### 阻断清单（全部/部分非 FIXABLE 时必填）
- 无。本轮问题均已作为 FIXABLE 收敛。

### 交接项清单
- 根因分析结论与定位文件:行号
- 修复范围与回归测试清单
- `tech-lead / product / delivery-owner` 3 侧合同口径已同步
