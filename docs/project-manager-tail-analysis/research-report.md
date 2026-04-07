# project-manager 尾部闭环与 Phase 3 审查分级 调研报告

## 一页判断
- 当前结论：部分成立
- 是否符合当前目标：高
- 一句话判断：`project-manager -> commit` 后确实缺少显式的尾部治理说明，但应该补的是“条件化 closeout phase”，不是机械追加一个新的最终 review、强制 archive、或无条件释放 worktree。
- 最大收益：把 `project-manager` 主链与 `small-chain` 的尾部口径对齐，减少事实漂移、漏收尾和错误清理。
- 最大风险：把 Phase 3 已完成的 `Code Review + QA + Sign-off` 再重复跑一遍，形成流程膨胀和仪式化闭环。
- 不适用场景：没有独立分支或 worktree、只做 phase 工件交付、没有 `docs/{feature}/YYYY-MM-DD-{change}/` 变更目录的场景。
- 结论翻转条件：如果后续有证据证明 `project-manager` Phase 3 之后仍持续出现“只有额外 final review 才能发现”的高价值问题，则“额外最终 review”才可能升级为强制门禁。

## 关键论点挑战表
| 对象/论点 | 最强支持证据 | 最强反方挑战 | 当前判断 | 结论稳健性 |
|-----------|-------------|-------------|---------|-----------|
| `Phase 3 审查分级` 已有清晰定义 | `plan-template.md` 已给出分级判定依据与矩阵；`phase3-grade-matrix.sh` 是唯一可执行规则源 | 定义被拆散在 `tech-lead` 模板、`project-manager` skill、dispatch、script 四层，理解成本高 | 部分成立 | 中 |
| `project-manager -> commit` 后应补尾部环节 | `small-chain` 合同已把 `verify-change -> finishing-a-development-branch -> archive` 定义为标准尾部 | `project-manager` 与 `small-chain` 不是同一条链；直接照搬会引入重复门禁和错误归档 | 部分成立 | 高 |
| 应把“最终 review、archive、释放 worktree”都设为 PM 后必做项 | 能统一交付口径、减少遗漏 | `project-manager` 已被仓库明确评价为“太重，需重做”；继续加环节会放大重量问题 | 不成立 | 高 |

## 优缺点速览
| 对象/论点 | 核心优势 | 核心短板 | 适用场景 | 不适用场景 |
|-----------|---------|---------|---------|-----------|
| 补“分支/工作区收尾” | 能解决 merge/PR/worktree 遗留问题 | 如果没有独立分支或 worktree，会变成空动作 | 并行开发、worktree 隔离、提交后仍需集成决策 | 直接在目标分支提交的极简场景 |
| 补“额外最终 review” | 理论上可防漏 | 与 Phase 3 的 `Code Review + QA` 高度重叠，容易重复验收 | 仅在 Phase 3 没覆盖合并结果、或只做 task 内 review 的链路 | 已有 Phase 3 整体验收的 PM 主链 |
| 补“archive” | 便于历史沉淀、CHANGELOG 闭环 | `project-manager` 产物是 `phase/unit` 结构，不天然等于 `small-chain` 的 change-dir 归档模型 | 变更目录符合 `docs/{feature}/YYYY-MM-DD-{change}/` 的场景 | 只有 phase 工件、没有 change-dir 的场景 |

## 独立挑战记录
| 挑战点 | challenger 质疑 | 原结论回应 | 是否调整 |
|--------|----------------|-----------|---------|
| 最终 review | `project-manager` 的 Phase 3 已经是“整体审查与验收”，再补 final review 很可能是重复审查 | 保留“不要机械补 final review”的结论；若要补，必须重命名为“closeout review / integration review”，只审查 Phase 3 未覆盖的增量 | 是 |
| 最终 review 的用户价值 | `commit` 已自带质量门控与显式确认；若 final review 只是复述 `code-review-report.md + qa-report.md`，只会增加等待时间 | 增补“只有在收尾结果产生新证据时才值得做 closeout review”，否则不升级为固定门禁 | 是 |
| archive | `archive` 是 small-chain 的 change-dir 闭环，不一定适配 phase 工件 | 保留“archive 只应条件触发”的结论，不把它升级成 PM 后必做项 | 是 |
| 释放 worktree | PR 场景或“保留分支稍后处理”场景下，提前清理 worktree 反而破坏后续工作 | 将“释放 worktree”改成“分支终态已确定后的条件清理” | 是 |
| 继续往 PM 塞尾部 | 仓库已有文档明确判定 PM 过重；继续膨胀会降低可维护性 | 结论调整为“补尾部能力可以做，但不要继续堆进 PM 本体，优先走独立 closeout skill / routing” | 是 |
| 先加动作再补文档 | 当前 `README.md` 与 `docs/small-chain/README.md` 对 active chain 步骤数仍有漂移，此时再强加通用尾步骤会放大认知噪音 | 把“统一文档口径”提升为先决动作，先收敛活跃合同，再讨论哪些尾步骤值得强制化 | 是 |

## 采纳速览
- 现在该做什么：小范围试点
- 采纳前必须补的验证：选一个真实 `project-manager` 交付样本，验证“增加 closeout phase”是否减少遗留 worktree、未决分支和文档漂移，而不是只增加耗时
- 最匹配的点：仓库已经存在 `finishing-a-development-branch`、`archive`、`verify-change` 等尾部能力，可复用而不必重造
- 最不匹配的点：`project-manager` 使用 `phase/unit` 工件模型，和 `small-chain` 的 `change-dir` 归档模型不完全一致

## 调研背景
- 调研触发：用户质疑 `project-manager` 的 `Phase 3` 审查分级定义来源不清，且认为标准 `project-manager -> commit` 后还缺最终 review、归档、释放 worktree 等环节
- 决策目标：判断这些质疑哪些成立、哪些应该改写后吸收、哪些会把流程推向“rigor theater”
- 关键约束：只基于当前仓库事实判断；不把现有文档当权威结论，必须拆成可验证论点

## 检索路径与覆盖证明
- 名称归一化：`project-manager` / `Phase 3 审查分级` / `REVIEW_A/B/C` / `QA_A/B/C/D` / `verify-change` / `finishing-a-development-branch` / `archive` / `worktree` / `using-git-worktrees`
- 已查对象类型：skill、contract、template、script、README、历史设计/裁决文档
- 已查 discovery 入口：`shared/skills/`、`community/superpowers/skills/`、`contracts/`、`docs/small-chain/`、`docs/archive/`
- 已排除候选：OpenSpec 运行时链路（已被边界合同声明为非默认运行时）；历史 `best-practice-implementation-plan.md`（已退役）
- 剩余盲区：暂无额外实证数据证明 `plan-template.md` 中的分级阈值经过系统评估；也暂无仓库级样本证明“PM 后额外 final review”的质量增量

## 项目上下文
- 技术栈：技能仓库治理为主，运行时基线是 `community/superpowers`，默认轻量链是 `small-chain`
- 已有相关实现：`project-manager` 主链、`small-chain` 默认链、`commit`、`review`、`verify-change`、`finishing-a-development-branch`、`archive`、`using-git-worktrees/worktree`
- 约束条件：仓库同时维护 first-party 主链和 superpowers small-chain，两套工件模型并存；README 与运行合同存在过历史漂移

## 拆解对象概览
- 对象类型：项目方法 / workflow contract
- 原始观点：`project-manager` 的 `Phase 3 审查分级` 定义来源需要说清；标准 `project-manager -> commit` 主链之后应补最终 review、归档、释放 git worktree 等尾部环节
- 需要回答的问题：这些观点是否成立；哪些可以直接吸收；哪些需要改写；哪些不该采纳

## 核心论点拆解

### 论点 1：`Phase 3 审查分级` 的定义在哪里，是否算清晰标准

#### 证据拆解
1. `shared/skills/tech-lead/references/templates/plan-template.md`
   - 这里首次给出 `审查分级: {轻量, 标准, 完整}` 的判定依据：
   - `轻量: 1-2 Task 且无安全风险`
   - `标准: 3-5 Task 或涉及安全风险`
   - `完整: 6+ Task 或核心业务链路`
   - 同时给出强门禁矩阵，并明确“该字段是 `/project-manager` Phase 3 校验的唯一分级真源”
2. `shared/skills/project-manager/SKILL.md`
   - 明确要求从 `plan.md` 的 `Phase 3 审查分级` 读取分级，消费这个结果驱动 Phase 3
3. `shared/skills/project-manager/references/phase3-dispatch.md`
   - 给出 `REVIEW_A/B/C`、`QA_A/B/C/D` 的语义定义和裁剪方式
   - 并声明 `scripts/phase3-grade-matrix.sh` 是 completion check 的唯一可执行规则源
4. `shared/skills/project-manager/scripts/phase3-grade-matrix.sh`
   - 这是“必跑哪些 gate”的唯一脚本化真源：轻量=`REVIEW_A + QA_A`，标准=`REVIEW_A + REVIEW_B + QA_A + QA_C`，完整=`REVIEW_A + REVIEW_B + QA_A + QA_B + QA_C + QA_D`
5. `project-manager` 的报告模板与 `completion_check.sh`
   - `code-review-report.md`、`qa-report.md`、`acceptance-summary.md` 和 `completion_check.sh` 都消费上述分级，不再自行定义新矩阵

#### 当前判断
- 分级的“使用真源”是清晰的：运行时单一真源是 `plan.md` 中的 `审查分级` 字段
- 分级的“可执行矩阵真源”也是清晰的：脚本真源是 `phase3-grade-matrix.sh`
- 但分级的“制定标准”并不集中：判定依据在 `tech-lead` 的 `plan-template.md`，语义定义在 `phase3-dispatch.md`，消费逻辑在 `project-manager` skill 和脚本

#### 这是不是最佳实践
- 不是通用最佳实践，更像本仓库的本地启发式
- 原因有二：
  - 阈值带明显经验色彩：`1-2 / 3-5 / 6+ Task` 没有仓库内实证说明为什么这些数字能稳定代表风险
  - `Task 数量` 是弱信号，不等于真实变更风险；一个 1-Task 的安全改动可能比 6 个文档 Task 更需要重门禁
- 更稳健的表达应是：当前分级是一套“风险优先、Task 数量辅助”的本地裁剪规则，而不是普适标准

### 论点 2：`project-manager -> commit` 后是否真的缺尾部环节

#### 证据拆解
1. `contracts/skill-chain.yaml`
   - `project-manager` 的输出止于 `dev-report.md`、`code-review-report.md`、`qa-report.md`、`acceptance-summary.md`
   - 没有把 `verify-change`、`finishing-a-development-branch`、`archive` 接到这条主链后面
2. `shared/skills/project-manager/SKILL.md`
   - `Phase 4` 明确写成：用户签收确认后执行 `scripts/completion_check.sh`，通过后执行 `/commit`
   - skill 在这里结束，没有继续定义 branch closeout / archive / worktree cleanup
3. `contracts/small-chain.yaml`
   - 明确把尾部定义为：`verification-before-completion -> verify-change -> finishing-a-development-branch -> archive`
4. `docs/small-chain/README.md` 与 `docs/small-chain/boundary-contract.md`
   - 把 `finishing-a-development-branch` 定义为“分支集成与 worktree 收尾”
   - 把 `archive` 定义为“只在变更已经集成到目标分支后执行”
5. `README.md`
   - ~~仍把 `small-chain` 写成 6 步，只列到 `verify-change -> archive`~~ （已修复，2026-04-07：README 已更新为 9 步，与 contracts/small-chain.yaml 一致）
   - ~~已被现有研究报告点名为”活跃链路文档存在事实漂移”~~ （已修复）

#### 当前判断
- 你的判断成立一半：
  - 成立的部分：仓库确实已经有另一条默认链把“验证后的分支收口、worktree 收尾、archive”定义成标准尾部，而 `project-manager` 主链没有承接这块
  - 不成立的部分：不能因此直接推出“PM 后必须补 final review + archive + worktree cleanup 全套动作”

#### 为什么不能一刀切补
- `project-manager` 主链和 `small-chain` 默认链并不是同一个工件模型
  - `project-manager` 面向 `phase/unit` 交付与签收
  - `small-chain` 面向 `docs/{feature}/YYYY-MM-DD-{change}/` 变更目录闭环
- `project-manager` 已经自带 Phase 3 的整体 Code Review + QA + Sign-off
  - 这和“补一个 final review”高度重叠
- `archive` 技能的输入要求是“verified change directory”
  - 这并不天然等于 `project-manager` 的 `phase-{N}/` 工作区

### 论点 3：真正应该补什么，哪些会变成仪式化动作

#### 可以直接吸收
1. 补“尾部路由”而不是补“额外 PM 阶段”
   - 在 `project-manager -> commit` 之后补一个显式 closeout 决策：
   - 是否仍有分支集成待处理？
   - 是否存在 worktree 需要清理？
   - 当前工件模型是否支持 archive？
2. 统一文档口径
   - 至少要修正 `README.md` 与活跃合同的漂移，避免维护者继续误判尾部定义
3. 把分级来源写清楚
   - 最少应明确区分：
   - `plan-template.md` 负责“如何选 grade”
   - `phase3-grade-matrix.sh` 负责“grade 对应哪些强门禁”

#### 必须改写后吸收
1. “补最终 review”
   - 应改写成：只在存在“Phase 3 未覆盖的收尾风险”时做 `closeout review`
   - 例如：merge 后结果复核、PR 描述与变更范围复核、branch finalization 前的差异检查
   - 不应改写成再次跑完整 `Code Review + QA`
2. “释放 git worktree”
   - 应改写成：仅当 worktree 存在且分支终态已确定时清理
   - `finishing-a-development-branch` 已明确：
     - Option 1 本地 merge：清理
     - Option 2 创建 PR：保留
     - Option 3 先保留分支：保留
     - Option 4 丢弃工作：清理
3. “archive”
   - 应改写成：只在变更已经集成、且工件模型符合 `archive` 输入约束时执行
   - 对 phase 型交付，可能需要单独的 phase-archive 策略，而不是直接复用 small-chain archive
4. “统一追加固定尾步骤”
   - 应改写成：先补 `closeout routing` 文档与条件判断，再决定哪些路径需要 review / branch finalization / archive
   - 否则用户看到的将是“多一串必须做的步骤”，而不是“更清晰的收尾边界”

#### 不应采纳
1. 把“final review、archive、释放 worktree”全部升级成 PM 后必做项
2. 把这些动作继续硬塞进 `project-manager` 本体
   - 仓库已有裁决文档明确指出 PM 当前实现“太重”，需要下一轮重做

## 论点挑战总表
| 论点 | 最强支持证据 | 最强反方挑战 | 当前判定 | 对我们的启示 |
|------|-------------|-------------|---------|-------------|
| 审查分级已经有清晰标准 | `plan-template.md + phase3-grade-matrix.sh + phase3-dispatch.md` 已覆盖判定依据、矩阵、语义 | 标准分散、阈值经验化、`Task 数量` 不是强风险代理变量 | 部分成立 | 应拆清“选 grade”和“执行 gate”的职责边界 |
| PM 后应补尾部环节 | `small-chain` 已把 verify/branch/archive 作为标准尾部 | 两条链工件模型不同，不能直接照搬 | 部分成立 | 应补路由与条件，而不是复制 small-chain 全套 |
| 最终 review 应该成为 PM 后强制门禁 | 可降低漏审风险 | 与 PM Phase 3 高重叠，容易重复验收 | 不成立 | 若保留，必须改名并缩窄为 closeout review |
| archive 应成为 PM 后强制动作 | 有助于长期沉淀和追溯 | 可能不匹配 phase 工件；会把“沉淀需求”误当成“交付完成条件” | 不成立 | archive 应绑定工件模型，而不是绑定所有交付 |

## 吸收建议
### 可以直接吸收
| 论点/做法 | 适用条件 | 如何吸收 |
|-----------|---------|---------|
| 明确 PM 之后的尾部路由 | `project-manager` 交付后仍可能存在分支/工作区状态 | 增加一份“PM closeout boundary”文档，说明何时结束于 `/commit`，何时继续走 branch finalization / archive |
| 统一文档口径 | 活跃合同与 README 存在漂移 | 修正 `README.md` 对活跃链路的描述，并交叉链接 `docs/small-chain/*` |
| 说明审查分级来源分层 | 当前理解成本高 | 在 `project-manager` 或 `tech-lead` 文档中显式写出“grade 选择规则源 / gate 执行规则源 / 语义定义源” |

### 改写后吸收
| 原始说法 | 改写后的做法 | 改写原因 |
|---------|-------------|---------|
| PM 后补“最终 review” | 仅在 branch integration / PR closeout 场景补 `closeout review` | 避免与 Phase 3 重复 |
| PM 后补“释放 git worktree” | 仅在 worktree 存在且分支终态为 merge/discard 时清理 | PR/保留分支场景应保留 worktree |
| PM 后补“archive” | 仅对符合 change-dir 模型、且已集成的变更执行 archive | phase 工件与 change-dir 模型不完全同构 |

### 不采纳
| 论点/做法 | 不采纳理由 |
|-----------|-----------|
| 把 `final review + archive + worktree cleanup` 统一升级为 PM 后强制门禁 | 会制造伪闭环、重复验收和交付延迟 |
| 继续把尾部逻辑塞进 `project-manager` skill | 与“PM 过重、下轮重做”的现有裁决方向冲突 |

## 落地行动项
- `P0` 写一份 `project-manager` 的尾部边界说明：`/commit` 之后何时结束，何时继续进入 branch/worktree/archive 收尾
- `P0` 修正 `README.md` 对 active `small-chain` 的描述，使之与 `docs/small-chain/README.md` 和 `contracts/small-chain.yaml` 一致
- `P1` 把 `Phase 3 审查分级` 的来源拆成两层明示：grade 选择规则源、gate 执行规则源
- `P1` 评估是否新增一个轻量 `closeout` skill，专门承接 branch finalization 与条件式 worktree cleanup，而不是继续膨胀 PM
- `P2` 决定 phase 工件是否需要独立 archive 策略；若需要，不直接复用 small-chain 的 change-dir archive

## 证据索引
- `E1` `shared/skills/project-manager/SKILL.md`
- `E2` `shared/skills/project-manager/references/phase3-dispatch.md`
- `E3` `shared/skills/project-manager/scripts/phase3-grade-matrix.sh`
- `E4` `shared/skills/project-manager/scripts/completion_check.sh`
- `E5` `shared/skills/tech-lead/references/templates/plan-template.md`
- `E6` `contracts/skill-chain.yaml`
- `E7` `contracts/small-chain.yaml`
- `E8` `docs/small-chain/README.md`
- `E9` `docs/small-chain/boundary-contract.md`
- `E10` `README.md`
- `E11` `community/superpowers/skills/subagent-driven-development/SKILL.md`
- `E12` `community/superpowers/skills/finishing-a-development-branch/SKILL.md`
- `E13` `community/superpowers/skills/archive/SKILL.md`
- `E14` `community/superpowers/skills/verify-change/SKILL.md`
- `E15` `community/superpowers/skills/using-git-worktrees/SKILL.md`
- `E16` `shared/skills/worktree/SKILL.md`
- `E17` `docs/skill-restructure-decision.md`
- `E18` `docs/everything-claude-code-fit-assessment/research-report.md`
- `E19` `docs/archive/small-chain-refactor-plan.md`
