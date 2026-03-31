# fix-2

## 输入分析
- 输入来源：基于上一轮本地未提交优化的系统评审结果继续修复；本轮没有单独的 `code-review-report.md` / `qa-report.md` 作为 fix 输入，而是直接以当前工作树中的 skill contract、模板、hook 与测试作为诊断对象。
- phase_dir 解析结果：本轮问题是 repo 级 contract/脚本修复，无法映射到单一业务 `phase_dir`，按约定输出到 `docs/hotfix-20260331-1031/`。
- 问题数量汇总：3

差异说明（N > 1 时 REQUIRED）:
- 已阅读上一轮报告 [fix-1](/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/docs/hotfix-20260331-1031/fix-1.md)。`fix-1` 只补了 `project-manager completion_check` 的单点闭环校验；本轮复审证明问题不是单文件缺陷，而是 Phase 解析、QA 报告模板、前置约束状态机在多 skill 之间出现 contract 漂移。
- 本轮策略从“单脚本补洞”升级为“跨 shared hook / product / tech-lead / project-manager / qa / tests 的单一真源对齐”，并新增 RED/GREEN 回归用例，避免同类问题再次漂移。

## 诊断阶段

### 环境快照
- 当前分支：`chrome-wedge`
- 工作树状态：存在大量用户既有未提交改动；本轮实际修改集中在 `shared/hooks/lib/common.sh`、`shared/skills/{product,tech-lead,project-manager,qa}/...`、`tests/run-all.sh`、`tests/test-phase-context-resolution.sh`、`tests/test-project-manager-phase3-contract.sh`
- 最近 5 条提交：
  - `ee81095 refactor: align runtime protocols layout and sync governance docs`
  - `793cf38 refactor: align shared reference governance and authority layout`
  - `da55904 merge: bring phase1 shared authority cleanup into main`
  - `adce53f fix: align shared authority boundaries for phase1`
  - `1923980 release: v1.2.4`
- 最近改动文件：
  - `/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/hooks/lib/common.sh`
  - `/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/product/scripts/completion_check.sh`
  - `/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/tech-lead/scripts/completion_check.sh`
  - `/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/tech-lead/references/templates/plan-template.md`
  - `/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/project-manager/scripts/completion_check.sh`
  - `/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/project-manager/references/templates/qa-report-template.md`
  - `/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/project-manager/references/templates/acceptance-summary-template.md`
  - `/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/qa/references/templates/qa-report-template.md`
  - `/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/tests/test-phase-context-resolution.sh`
  - `/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/tests/test-project-manager-phase3-contract.sh`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | 当前 Phase 的 UNIT 解析会静默跑到错误 Phase | 构造临时 feature：`phase-1/unit-1`、`phase-2/unit-1`，PRD 仅声明 `phase-2/` 为 `IN_PROGRESS`，source `shared/hooks/lib/common.sh` 后调用 `resolve_current_phase_context_from_prd`、`resolve_all_unit_work_dirs`、`resolve_work_dir_from_prd` | `CURRENT_PHASE_WORK_DIR` 已是 `phase-2`，但 `ALL_UNIT_WORK_DIRS` / `UNIT_WORK_DIR` 退回到 `phase-1/unit-1` |
| 2 | 官方 QA 模板与官方门禁不兼容 | 读取 `shared/skills/qa/references/templates/qa-report-template.md`、`shared/skills/project-manager/references/templates/qa-report-template.md`、`shared/skills/project-manager/scripts/completion_check.sh` | QA 侧允许 `审查分级: 未指定`、要求 `执行范围` / `QA_A UNIT 执行汇总` / `AC 追踪表`，但 PM 模板和 PM 校验器仍沿用旧结构 |
| 3 | 前置约束状态机在上游/中游/下游语义不一致 | 对照 `product` / `tech-lead` / `project-manager` 脚本与 `plan-template.md`、`acceptance-summary-template.md` | `Constraint ID` 有的要求 `CON-001`，有的接受 `CON-1`；`test_ref = N/A` 模板允许但门禁拒绝；`BLOCKED` 在 plan/acceptance 模板中仍被当作最终状态展示 |

当前环境复现结论:
- 可复现/不可复现：可复现
- 不可复现时环境差异证据：N/A

### 假设验证过程
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | 当前 Phase 解析错位 | `resolve_current_phase_context_from_prd` 选错了 Phase | 构造最小临时 feature 后先检查 `CURRENT_PHASE_WORK_DIR` | 排除，当前 Phase 正确解析为 `phase-2` |
| 1 | 当前 Phase 解析错位 | 当 PRD 未显式列出 `phase-N/unit-M` 时，`resolve_all_unit_work_dirs` / `resolve_work_dir_from_prd` 回退到全局 `find`，因此选中了磁盘排序的第一个 Phase | 读取 `shared/hooks/lib/common.sh:316-386` 并执行最小复现脚本 | 确认 |
| 1 | 当前 Phase 解析错位 | PRD 中 `phase-N/unit-M` 匹配要求尾部 `/`，导致合法路径被漏抓 | 读取 `shared/hooks/lib/common.sh:204-246` 并用不带尾 `/` 的路径复现 | 确认 |
| 2 | QA 报告 contract 分裂 | 只有 PM 模板旧，PM 门禁其实已兼容 `未指定` 和结构化章节 | 读取 `shared/skills/project-manager/scripts/completion_check.sh:156-186,1172-1189` | 排除，脚本同样不兼容 `未指定` 继承逻辑 |
| 2 | QA 报告 contract 分裂 | QA skill/template 已经定义了新 contract，但 PM 仍保留旧模板 | 对比 `shared/skills/qa/references/templates/qa-report-template.md:1-29` 与 `shared/skills/project-manager/references/templates/qa-report-template.md` 旧内容 | 确认 |
| 2 | QA 报告 contract 分裂 | 只改模板即可，不需要改门禁脚本 | 阅读 PM `parse_report_grade`、D8 比对逻辑 | 排除，脚本必须显式处理 `未指定 -> plan_grade` |
| 3 | 前置约束状态机分裂 | 只有 acceptance 模板状态不一致，脚本层面其实统一 | 对比 `product` / `tech-lead` / `project-manager` 校验脚本中的 `Constraint ID` / `test_ref` / `plan_status` 规则 | 排除，三层脚本与模板都存在不一致 |
| 3 | 前置约束状态机分裂 | `CON-001` 零填充规则没有收敛，导致 PRD/plan/acceptance 分段通过、尾段失败 | 读取 `shared/skills/product/scripts/completion_check.sh:203-207`、`shared/skills/tech-lead/scripts/completion_check.sh:701-703,863-883`、`shared/skills/project-manager/scripts/completion_check.sh:784-798,1464-1478` | 确认 |
| 3 | 前置约束状态机分裂 | `test_ref = N/A` 只是文档样例，校验器不该允许 | 对比 `shared/skills/tech-lead/references/templates/plan-template.md:16-18`、`shared/skills/project-manager/references/templates/acceptance-summary-template.md:25-27` 与 tech-lead / PM 校验脚本 | 排除，模板明确允许 `N/A`，门禁必须消费它 |
| 3 | 前置约束状态机分裂 | `BLOCKED` 应继续作为最终 plan/acceptance 状态展示 | 对比 `shared/skills/tech-lead/SKILL.md`、`shared/skills/project-manager/SKILL.md` 中“无 BLOCKED 才能进入执行”的约束，与 `plan-template.md` / `acceptance-summary-template.md` 旧枚举 | 排除，`BLOCKED` 只能停留在上游诊断语义，不能进入最终交付表 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | 当前 Phase 解析错位 | `shared/hooks/lib/common.sh:204-246`、`shared/hooks/lib/common.sh:261-266`、`shared/hooks/lib/common.sh:316-386` | Phase 解析虽然能选中 `CURRENT_PHASE_WORK_DIR`，但当 PRD 未列全 UNIT 路径时，下游解析直接回退到全局 `find ... phase-*/unit-*`，导致门禁脚本对错误 Phase 执行校验 | 静态追踪 `shared/skills/project-manager/scripts/completion_check.sh` 与 QA 流程都消费 `resolve_all_unit_work_dirs` / `resolve_work_dir_from_prd`；最小复现脚本确认同一因果链 |
| 2 | QA 报告 contract 分裂 | `shared/skills/project-manager/scripts/completion_check.sh:156-186`、`shared/skills/project-manager/scripts/completion_check.sh:1172-1189`、`shared/skills/qa/references/templates/qa-report-template.md:1-29`、`shared/skills/project-manager/references/templates/qa-report-template.md:1-29` | QA skill 已升级到 Phase 级结构化报告，但 PM 仍提供旧模板、旧分级语义，导致“按 PM 官方模板写的 qa-report”本身可能过不了 PM 官方门禁 | 通过对照 QA skill/template、PM 模板、PM completion_check 的静态引用关系确认，并用 `tests/test-project-manager-phase3-contract.sh` 固化 |
| 3 | 前置约束状态机分裂 | `shared/skills/product/scripts/completion_check.sh:203-207`、`shared/skills/tech-lead/scripts/completion_check.sh:701-703,863-883`、`shared/skills/project-manager/scripts/completion_check.sh:784-798,1464-1478`、`shared/skills/tech-lead/references/templates/plan-template.md:13-22`、`shared/skills/project-manager/references/templates/acceptance-summary-template.md:21-33` | `Constraint ID`、`test_ref`、`plan_status` 在 product / tech-lead / project-manager / acceptance / plan-template 之间各自解释一版，造成同一条 constraint 在链路前段合法、后段非法，或模板鼓励填写门禁禁止的值 | 静态对表 product→tech-lead→project-manager→acceptance 的脚本与模板，并在二轮复审中继续发现 `plan-template` 残留 `BLOCKED` 枚举，证明问题是状态机级别的 contract 漂移 |

## 处置阶段

### 决策
- 优先级 1：先修共享路径解析，避免门禁跑错对象。
- 优先级 2：统一 QA 报告模板与 PM 门禁语义，保证模板和校验器一致。
- 优先级 3：统一前置约束状态机的零填充、`N/A`、`BLOCKED` 规则，并把残留模板语义转成自动化断言。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | 当前 Phase 解析错位 | FIXABLE | 增补最小复现测试，修正 `common.sh` 的 phase 内优先解析逻辑 |
| 2 | QA 报告 contract 分裂 | FIXABLE | 对齐 QA / PM 模板与 PM 分级校验逻辑，并补 contract 回归 |
| 3 | 前置约束状态机分裂 | FIXABLE | 统一 `Constraint ID`、`N/A`、`BLOCKED` 规则并扩展 contract 回归 |

### FAIL-1: 当前 Phase 解析错位

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `shared/hooks/lib/common.sh:204-246` 对 `phase-N/unit-M` 的抓取过度依赖输入形式，且 `shared/hooks/lib/common.sh:316-386` 在当前 Phase 已知但 UNIT 列表为空时直接退回全局搜索，导致 Phase 语义丢失 |
| 2 | 修复是否完整？ | 已同时修复 `resolve_current_phase_context_from_prd`、`resolve_work_dir_from_prd`、`resolve_all_unit_work_dirs` 三条路径，并新增 `find_unit_dirs_in_phase_dir` 强制优先限定在 `CURRENT_PHASE_WORK_DIR` 内 |
| 3 | 是否引入新问题？ | 影响范围局限在 shared hook 的 Phase/UNIT 解析；已用最小临时 feature 覆盖“PRD 只写 phase、不写 unit”场景，避免误伤已有明确 unit 路径场景 |
| 4 | 是否需要补充测试覆盖？ | 已新增 `tests/test-phase-context-resolution.sh`，并纳入 `tests/run-all.sh` |

RED: `bash tests/test-phase-context-resolution.sh` 初次执行失败，报 `resolve_all_unit_work_dirs should stay inside current phase, got: .../phase-1/unit-1`。  
GREEN: 修复后 `bash tests/test-phase-context-resolution.sh` 通过。

### FAIL-2: QA 报告 contract 分裂

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `shared/skills/project-manager/references/templates/qa-report-template.md` 仍是旧版最小模板，而 `shared/skills/project-manager/scripts/completion_check.sh:156-186,1172-1189` 又按旧分级语义解释 `qa-report`，没有把 `未指定` 当作继承 `plan.md` 的合法写法 |
| 2 | 修复是否完整？ | 已将 PM QA 模板升级为与 QA skill 一致的 Phase 级结构，并同步补入强门禁矩阵、执行范围、QA_A UNIT 汇总、AC 追踪表、元数据枚举；同时修正 PM 分级解析和 `未指定 -> plan_grade` 继承逻辑 |
| 3 | 是否引入新问题？ | 模板字段增加，但都来自已存在的 QA skill contract；两份 QA 模板已做到字节级一致，降低后续漂移风险 |
| 4 | 是否需要补充测试覆盖？ | 已在 `tests/test-project-manager-phase3-contract.sh` 中增加对分级、执行范围、QA_A 汇总、AC 追踪表、元数据与 `未指定` 继承逻辑的断言 |

RED: `bash tests/test-project-manager-phase3-contract.sh` 初次执行失败，先后报出 `qa template missing inherited grade option`、`qa template missing gate matrix note`。  
GREEN: 对齐模板与门禁后，`bash tests/test-project-manager-phase3-contract.sh` 通过。

### FAIL-3: 前置约束状态机分裂

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `product`、`tech-lead`、`project-manager` 的校验脚本与 `plan-template.md`、`acceptance-summary-template.md` 各自维护 `Constraint ID`、`test_ref`、`plan_status` 规则，缺少单一真源；结果是 `CON-1`、`N/A`、`BLOCKED` 在不同阶段被不同解释 |
| 2 | 修复是否完整？ | 已统一 `Constraint ID` 为 `^CON-[0-9]{3,}$`，统一 `test_ref` 允许 `N/A`，收紧 acceptance / plan 最终状态仅为 `MAPPED|VERIFIED`，并把 `BLOCKED` 明确限定为必须在 plan/执行阶段消解的上游状态 |
| 3 | 是否引入新问题？ | 规则整体变得更严格，但与当前 skill 文档“无 BLOCKED 方可进入执行”的门禁一致；新增回归已覆盖零填充、`N/A`、`BLOCKED` 三类边界 |
| 4 | 是否需要补充测试覆盖？ | 已扩展 `tests/test-project-manager-phase3-contract.sh`，并在二轮复审后继续加上 `plan-template` 不得保留 `BLOCKED` 最终行的断言 |

RED: `bash tests/test-project-manager-phase3-contract.sh` 初次执行失败时，脚本对 `CON-001` / `N/A` / `BLOCKED` 相关 contract 均未收敛；二轮复审又发现 `plan-template.md` 仍保留 `BLOCKED` 最终状态说明。  
GREEN: 统一脚本与模板后，`bash tests/test-project-manager-phase3-contract.sh`、`bash tests/run-all.sh` 均通过，且 QA/PM 模板已字节级一致。

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | 当前 Phase 解析错位 | 当前 Phase 已解析但 UNIT 回退到全局搜索 | `/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/hooks/lib/common.sh`、`/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/tests/test-phase-context-resolution.sh`、`/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/tests/run-all.sh` | `bash tests/test-phase-context-resolution.sh`、`bash tests/run-all.sh` |
| 2 | QA 报告 contract 分裂 | PM 模板/门禁未跟上 QA skill contract | `/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/project-manager/scripts/completion_check.sh`、`/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/project-manager/references/templates/qa-report-template.md`、`/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/qa/references/templates/qa-report-template.md`、`/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/tests/test-project-manager-phase3-contract.sh` | `bash tests/test-project-manager-phase3-contract.sh`、`bash tests/run-all.sh` |
| 3 | 前置约束状态机分裂 | 零填充、`N/A`、`BLOCKED` 规则未统一 | `/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/product/scripts/completion_check.sh`、`/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/tech-lead/scripts/completion_check.sh`、`/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/tech-lead/references/templates/plan-template.md`、`/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/project-manager/scripts/completion_check.sh`、`/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/shared/skills/project-manager/references/templates/acceptance-summary-template.md`、`/Users/lijieli/.superset/worktrees/org-claude-skills/chrome-wedge/tests/test-project-manager-phase3-contract.sh` | `bash tests/test-project-manager-phase3-contract.sh`、`bash tests/run-all.sh` |

### 全量测试结果
TEST_CMD: `bash tests/test-phase-context-resolution.sh && bash tests/test-project-manager-phase3-contract.sh && bash tests/test-skill-output-and-gate-contract.sh && bash tests/run-all.sh`
通过: 4 / 失败: 0 / 跳过: 0

### 交接项清单
- 根因分析结论与定位文件:行号
  - `shared/hooks/lib/common.sh:204-246`
  - `shared/hooks/lib/common.sh:261-266`
  - `shared/hooks/lib/common.sh:316-386`
  - `shared/skills/project-manager/scripts/completion_check.sh:156-186`
  - `shared/skills/project-manager/scripts/completion_check.sh:1172-1189`
  - `shared/skills/product/scripts/completion_check.sh:203-207`
  - `shared/skills/tech-lead/scripts/completion_check.sh:701-703`
  - `shared/skills/tech-lead/scripts/completion_check.sh:863-883`
  - `shared/skills/tech-lead/references/templates/plan-template.md:13-22`
  - `shared/skills/project-manager/references/templates/acceptance-summary-template.md:21-33`
- 修复范围与回归测试清单
  - 修复范围：shared hook、product/tech-lead/project-manager/qa 模板与门禁脚本、两条新增/增强 contract 测试
  - 回归测试：`bash tests/test-phase-context-resolution.sh`、`bash tests/test-project-manager-phase3-contract.sh`、`bash tests/test-skill-output-and-gate-contract.sh`、`bash tests/run-all.sh`
- 非 FIXABLE 问题的后续处理动作
  - 无
