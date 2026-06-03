---
name: qft-branch-flow
user-invocable: true
description: "全房通 Git 分支流程向导。Use when 需要按全房通分支规范准备需求分支、版本分支、紧急 BUG 分支、合并到部署分支或主分支、推送远端，尤其是多项目、多仓库、容易选错来源/目标分支、误用已有分支或需要执行前风险确认的场景。"
model: sonnet
---

# /qft-branch-flow -- 全房通分支流程向导

## Goal

按全房通分支管理规范，引导用户选择场景、项目、分支字段、操作计划、Git 检查、执行和 push；选择项必须可见，低风险输入不反复确认，高风险动作必须确认，防止错项目、错仓库、错来源分支、错目标分支、错合并方向、误用已有分支和未确认推送。

## HARD-GATE

1. 低风险输入不逐步二次确认；用户已明确提供或选择的场景、项目和分支字段，可直接进入计划生成与检查。
2. 场景、项目、push 范围等多选或枚举输入必须展示可选项；不要让用户凭记忆输入项目编号、业务名或仓库名。
3. 选择动作本身就是低风险确认；选完后不要再要求用户重复回复 `确认`。
4. 只有歧义、缺失、冲突或会改变执行对象的输入才追问；不要为了流程完整要求用户重复回复 `确认`。
5. 所有项目展示必须包含业务名、仓库名和主分支。
6. 目标分支只能由开发输入字段生成，或由开发选择/输入已有分支；不要替开发猜。
7. 操作计划必须由 `scripts/qft_branch_flow.py plan` 生成，并由 `scripts/qft_branch_flow.py validate` 校验通过；不要手写最终执行计划。
8. Git 本地写操作前必须展示 plan + preflight 总览，并要求用户确认执行。
9. `requires_user_confirmation=true` 的已有目标分支复用、preflight blocker 后只执行通过项目，必须在执行确认文案中显式命名。
10. push 必须在本地创建/复用/合并完成后单独确认。
11. 工作区不干净、remote 不匹配、preflight 阻塞或必要确认缺失时，阻塞对应项目；不要静默跳过。

## Workflow

| 步骤 | 输入 | 动作 | 输出 | 失败状态 |
| --- | --- | --- | --- | --- |
| 1. 场景选择 | 用户业务意图或场景编号 | 识别场景；无法唯一识别时展示场景选项 | scenario | 场景缺失或多义则停留本步 |
| 2. 项目选择 | 项目编号、业务名或仓库名列表 | 展示项目选择面板；用户已给出项目时回显解析结果 | project set | 未知项目则停留本步 |
| 3. 分支信息收集 | 场景所需字段 | 生成或识别分支名并展示 | branch inputs | 字段缺失、格式错误或用户修改则回到本步 |
| 4. 计划生成与校验 | scenario、projects、branch inputs | 调用 `plan` 生成 JSON，再调用 `validate` 校验 | 已校验 plan.json | validate 失败则阻塞 Git 检查 |
| 5. 执行前检查与总览 | 已校验 plan.json | 调用 `preflight`，展示 plan + preflight 总览和风险确认文案 | 通过/阻塞项目分组、待确认执行项 | preflight 非 0 或存在 blocker 时阻塞对应项目 |
| 6. 执行与 push | 用户确认执行或推送 | 只对 preflight 通过且已选择项目执行本地 Git 操作；push 单独确认 | 完成、未执行、下一步 | 冲突或 Git 失败时停止并报告项目状态 |

## 分支规范

项目清单：

| 编号 | 业务名 | 仓库名 | 主分支 |
| --- | --- | --- | --- |
| 1 | 全房通后端业务 | `qft-all` | `3.0.0.MASTER` |
| 2 | 全房通 PC 前端 | `qft-app` | `master` |
| 3 | 全房通 System 前端 | `qft-system` | `master` |
| 4 | 全房通 APP | `qft-harmonyos-vue3` | `master` |
| 5 | 全房通租客端 H5 | `qft-universal.gitersal` | `master` |
| 6 | 全房通后端定时器 | `qft-job-executor` | `master` |
| 7 | 全房通后端公共代码 | `qft-common` | `master` |

分支类型：

| 类型 | 命名 | 来源 | 用途 |
| --- | --- | --- | --- |
| 业务开发分支 | `3.0.0.DEV_名字_需求编号_版本号` | 项目主分支 | 需求开发 |
| 延期业务分支 | `3.0.0.DEV_名字_需求编号_版本号_DELAY` | 项目主分支 | 无上线时间或暂停需求 |
| 版本部署分支 | `V.版本号` | 项目主分支 | 测试、预发布、线上部署 |
| 私有化部署分支（规范记录，当前向导不执行） | `V.DZ.公司名首字母` | 项目主分支 | 私有化部署 |
| 紧急 BUG 分支 | `3.0.0.MASTER_BUG_反馈日期` | `V.线上版本号` | 紧急线上 BUG 修复 |

合并方向：

- 业务提测/发版：业务开发分支 -> `V.版本号` -> 项目主分支。
- 线上 BUG：先执行 `bugfix` 从 `V.线上版本号` 确保紧急 BUG 分支 `3.0.0.MASTER_BUG_反馈日期` 可用；修复完成后再执行 `bugfix-finish` 将 BUG 分支合回 `V.线上版本号`。两个阶段必须分开确认，不得在创建 BUG 分支时同时合回。
- 日常同步：项目主分支 -> 当前业务开发分支。
- 上线前同步：项目主分支 -> `V.版本号`。
- 业务分支和 BUG 分支同时存在时，以业务分支为准。

## 确定性计划机制

固定规则交给脚本处理，向导负责展示可选项、收集输入、解释计划、展示检查结果和执行前风险确认。

- 多选输入必须优先用可见选项降低记忆成本；减少的是重复确认，不是选择入口。
- 项目选择完成后，执行前总览仍必须再次展示最终项目集合，作为写操作前证据。

- 项目白名单来自 `references/project-registry.json`。
- 分支命名和场景规则来自 `references/branch-policy.json`。
- 计划结构以 `contracts/branch-plan.schema.json` 为准。Load timing: 第 4 步生成计划前读取；purpose: 校验计划字段和步骤结构；output: 合法 plan JSON；consumer: Git 检查和执行步骤；verification: `python3 scripts/qft_branch_flow.py validate --input <plan.json>`。
- 生成计划：`python3 scripts/qft_branch_flow.py plan <scenario> --projects <项目编号|业务名|repo,...> --version <版本号> ...`；项目输入可用项目编号、业务名或 repo，向导必须把用户选择回显为业务名、仓库名和主分支；`dev-sync` / `release-merge` 的同名业务分支优先用 `--business-branch <分支名>`，各项目不同分支时才用 `--business-branches <项目=分支,...>`；`bugfix` / `bugfix-finish` 的 `--version` 是线上版本号，必须另传 `--bug-version <客户反馈日期>`。
- 校验计划：`python3 scripts/qft_branch_flow.py validate --input <plan.json>`。
- `create-dev`、`release-merge`、`bugfix` 和 `release-sync-before` 中的分支准备动作统一使用 `ensure_branch`：目标不存在才从规定来源创建，目标已存在则展示状态并等待用户确认复用。
- `create-dev` 的名字缩写可接收小写输入，计划脚本会标准化为大写；向导回显时使用 plan 输出的标准化值。
- `dev-sync` / `release-merge` 的业务分支如果符合 `3.0.0.DEV_*_*_版本号` 或 `_DELAY` 命名，分支尾号必须与 `--version` 一致；不一致时停止并让用户修正版本或分支。
- `bugfix-finish` 只在修复完成后将 BUG 分支合回版本分支。
- 执行前检查必须调用：`python3 scripts/qft_branch_flow.py preflight --input <plan.json>`，默认以当前 AI Coding workspace 作为入口自动识别当前单仓、多仓父目录或 sibling 仓库；只有自动识别失败或 remote 校验无法裁决时，才让用户提供 `--repo-root <workspace>`。preflight 输出为唯一检查依据，不要用自然语言自行推断 Git 状态。
- preflight 必须按项目展示 resolved path，并用 `origin` URL 与 `project-registry.json` 的 `remote_url` 做归一化匹配；不要只用仓库名判断 remote。
- preflight action 口径：`create_branch` 要求来源存在且与远端一致、目标精确不存在且无大小写冲突；`ensure_branch` 允许目标不存在，存在则要求目标与远端一致，不存在则要求来源可用于创建；`merge` 要求来源和目标都存在且与远端一致。
- preflight 对每个 step 输出 `target_resolution`：`create_missing` 表示将新建目标分支，`reuse_existing` 表示目标分支已存在且需要用户确认复用，`not_applicable` 表示该 action 不准备目标分支。`requires_user_confirmation=true` 时，向导必须展示本地/远端 SHA、ahead/behind、来源和目标分支，再等待用户确认。
- preflight 只报告需要同步的 blocker，不自动 `pull`；`pull` 会改变本地分支，必须由用户在本向导外处理或另行确认后再重跑 preflight。`ensure_branch` 的目标远端已存在且 preflight 通过时，执行阶段按用户确认切换/创建本地跟踪分支，不重新创建同名分支。
- 第 4 步 plan 中 `push.confirmed` 必须为 `false`，`push.branches` 必须为空；push 只能在本地操作完成后作为第 6 步运行态单独确认。
- `target_branch` 为 `<project-main-branch>` 时，表示每个项目使用自己的主分支；实际 Git 目标以 `steps[*].target_branch` 为准。
- `validate` 失败时停止；只能回到前序步骤修正输入或计划，不进入 Git 检查和执行。

## 风险分层向导


### 第 1 步：选择操作场景

用户意图已明确时直接识别场景；缺失或多义时展示场景选项，不展示 Git 细节：

```text
第 1 步：选择操作场景

1. 开发需求：准备业务开发分支
2. 日常同步：主分支同步到业务开发分支
3. 提测/发版：确保版本分支，并合并业务分支
4. 线上 BUG：准备紧急 BUG 分支
5. 上线回合：版本分支与主分支同步

请输入编号：
```

用户输入后直接进入下一步；若输入与已识别场景冲突，先回显差异并追问。

### 第 2 步：选择涉及项目

项目选择必须可见，不要求用户记忆项目编号、业务名或仓库名：

- 用户未明确项目时，展示完整项目选择面板。
- 用户只说“前端”“后端”“APP”等泛称时，展示匹配候选，让用户用编号多选。
- 用户已明确给出业务名或仓库名时，回显解析结果和主分支，不再要求二次确认；若解析到多个候选，展示候选让用户选择。
- 用户选择编号后直接进入下一步；不要再要求输入 `确认`。

选择面板示例：

```text
第 2 步：选择涉及项目

1. 后端业务 qft-all
   主分支：3.0.0.MASTER

2. PC 前端 qft-app
   主分支：master

3. System 前端 qft-system
   主分支：master

4. APP qft-harmonyos-vue3
   主分支：master

5. 租客端 H5 qft-universal.gitersal
   主分支：master

6. 后端定时器 qft-job-executor
   主分支：master

7. 公共代码 qft-common
   主分支：master

请输入编号，可多选，例如：1,2,5
```

用户选择后直接进入分支字段收集；若存在未知项目、业务名和仓库名冲突，先展示候选差异并追问。

### 第 3 步：收集分支信息

按场景只问必要字段：

- 开发需求：名字缩写、需求编号、版本号（月日，如 `0301`）、是否 `_DELAY`；计划确保业务开发分支可用，目标已存在则复用确认，不存在才创建。
- 日常同步：版本号、业务开发分支名；多项目共用同一业务分支时只收一次分支名，计划用 `--business-branch` 将项目主分支合入该业务开发分支；各项目不同分支时才逐项目收集并映射。
- 提测/发版：版本号、业务分支名；多项目共用同一业务分支时只收一次分支名，计划先确保版本分支可用，再将业务分支合入版本分支；各项目不同分支时才逐项目收集并映射；版本分支已存在时先确认复用。
- 上线 BUG 创建：线上版本号（月日，如 `0528`）、客户反馈日期（月日，如 `0602`）、来源版本分支 `V.线上版本号`、目标 BUG 分支 `3.0.0.MASTER_BUG_反馈日期`；计划只包含从 `V.线上版本号` 确保 BUG 分支可用，目标已存在则复用，不存在才创建。
- 上线 BUG 完成：线上版本号、客户反馈日期、已修复 BUG 分支 `3.0.0.MASTER_BUG_反馈日期`、目标版本分支 `V.线上版本号`；计划只包含将 BUG 分支合回 `V.线上版本号`。
- 上线回合：选择上线前同步（先确保版本分支可用，再将主分支合入版本分支）或上线后回合（版本分支 -> 主分支）。

生成或识别分支名后进入计划生成；若字段缺失、格式错误或用户输入与生成结果冲突，先展示差异并追问。

### 第 4 步：生成并校验操作计划

分支信息完整后，先调用脚本生成 `plan.json`，再调用脚本校验同一份计划。示例：

```bash
python3 scripts/qft_branch_flow.py plan create-dev --projects qft-all,qft-app --owner QW --requirement 0001 --version 0301 > plan.json
python3 scripts/qft_branch_flow.py validate --input plan.json
```

计划校验通过后，不要求用户单独输入 `确认计划`；将计划摘要并入第 5 步执行前总览。示例摘要：

```text
计划摘要

1. 后端业务 qft-all
   来源分支：3.0.0.MASTER
   目标分支：3.0.0.DEV_QW_0001_0301
   操作：确保业务开发分支可用

2. PC 前端 qft-app
   来源分支：master
   目标分支：3.0.0.DEV_QW_0001_0301
   操作：确保业务开发分支可用
```

计划未通过 `validate` 时，不做 Git 检查和执行。

### 第 5 步：执行前检查与总览

计划校验通过后调用 preflight，不自行组合 Git 检查结论：

```bash
python3 scripts/qft_branch_flow.py preflight --input plan.json
```

preflight 默认从当前 AI Coding workspace 自动识别仓库路径：当前目录是目标单仓、当前目录是多仓父目录、或当前目录是某个 sibling 仓库都应由脚本解析；只有识别失败或 remote 校验无法裁决时，才提示用户提供 `--repo-root <workspace>`。

preflight exit 0 且项目 `status=ok` 才能进入执行。存在 blocker 时，按 blocker 输出展示阻塞原因和下一步；不要把 `create_branch` 或 `ensure_branch` 的目标分支不存在解释为阻塞。

每个 action 的判定口径：

| action | 来源分支 | 目标分支 | 阻塞条件 |
| --- | --- | --- | --- |
| `create_branch` | 必须存在且与远端一致 | 必须精确不存在，且不能有大小写近似远端引用 | 来源缺失/落后远端、目标已存在、目标大小写冲突、remote 检查失败 |
| `ensure_branch` | 目标不存在时必须存在且与远端一致 | 存在则复用并要求用户确认；不存在则从来源创建 | 目标大小写冲突、目标存在但落后远端、目标不存在且来源不可用 |
| `merge` | 必须存在且与远端一致 | 必须存在且与远端一致 | 来源/目标缺失、落后远端、大小写冲突、remote 检查失败 |

按 preflight 通过/阻塞分组展示，并同时展示计划摘要和检查摘要。存在阻塞时，让用户选择“只继续通过项目”或“全部停止”。

执行前只要求一次本地写操作确认，确认文案必须覆盖当前风险：

| 条件 | 确认文案 |
| --- | --- |
| 全部通过，且无已有目标分支复用 | `确认执行` |
| 任一步 `requires_user_confirmation=true` | `确认复用已有分支并执行` |
| 存在 blocker 但用户选择只继续通过项目 | `确认仅执行通过项目` |
| 同时存在 blocker 和已有目标分支复用 | `确认复用已有分支并仅执行通过项目` |

未收到匹配当前风险的确认文案前，不做 Git 本地写操作。

### 第 6 步：执行与 push

执行创建、复用或合并前，必须已经收到第 5 步匹配当前风险的确认文案；不要再要求第二次本地执行确认。

本地操作完成后，单独询问 push：

```text
第 6 步：确认是否推送远端

1. 推送全部已处理分支
2. 只推送指定项目
3. 暂不推送

请输入编号：
```

如果选择推送，列出仓库和分支，要求输入 `确认推送` 后才能执行。

## Git 执行边界

- 允许执行 `git status`、`git remote -v`、`git branch`、`git fetch`、`git switch`、`git merge`、`git push`。
- preflight 不执行 `git pull` 或其他写操作；preflight 发现落后远端时阻塞，由用户在向导外处理或另行确认同步后重跑 preflight。目标远端已存在且 preflight 通过时，执行阶段可按确认结果 fetch 并切换/创建本地跟踪分支，不重新创建同名分支。
- 遇到冲突立即停止，列出冲突文件；不要自动解决冲突。
- 不自动删除分支；删除属于维护动作，当前只提示规范，不执行。
- 不使用 `git reset --hard`、`git clean`、强推或跳过 hook。

## 输出

每轮结束输出分组结果：

```text
完成：
- qft-all：已确保 3.0.0.DEV_QW_0001_0301 可用，已推送 origin

未执行：
- qft-app：工作区有未提交改动，已阻塞

下一步：
- 处理 qft-app 未提交改动后重新运行本向导
```

## Verification

- 计划生成后必须运行 `python3 scripts/qft_branch_flow.py validate --input <plan.json>`；只有 exit 0 且 plan JSON 符合 schema 才能进入 Git 检查。
- 执行前必须运行 `python3 scripts/qft_branch_flow.py preflight --input <plan.json>`；默认使用当前 AI Coding workspace 自动识别仓库路径，只有识别失败或 remote 校验无法裁决时才追加 `--repo-root <workspace>`；只有 exit 0 且目标项目 `status=ok` 才能执行。
- preflight 输出必须逐项目展示仓库、remote、工作区、来源分支、目标分支、`target_resolution`、`requires_user_confirmation`、同步状态和执行前确认文案；所有 blocker 原样保留，不得改写成其他 Git 结论。
- 本地写操作后必须用 `git status` 和目标分支存在性证明结果；push 后必须显示已推送的 remote 和 branch。
- 输出分组必须包含已完成、未执行和下一步，供用户继续处理阻塞项目。

## 常见错误

| 错误 | 正确做法 |
| --- | --- |
| 一次性执行所有流程、不展示执行前总览 | 输入可一次性收集，但本地写操作前必须展示 plan + preflight 总览和匹配风险的确认文案 |
| 低风险输入后反复要求 `确认` | 用户已明确提供或选择的场景、项目、字段直接进入确定性计划和检查；只在歧义、缺失、冲突或高风险执行前确认 |
| 只写业务名不写仓库名 | 同时展示业务名、仓库名、主分支 |
| 替用户猜目标分支 | 由输入字段生成或由用户选择已有分支 |
| 创建分支和 push 一起确认 | 本地写操作确认一次，push 单独确认 |
| 手写最终执行计划 | 用 `scripts/qft_branch_flow.py plan` 生成，并用 `validate` 校验通过后再展示 |
| validate 失败后继续执行 | 回到前序步骤修正输入或计划，通过后再进入 Git 检查 |
| 自行解释 Git 状态、不跑 preflight | 用 `preflight` 结构化结果作为唯一执行前检查依据 |
| 目标分支已存在时静默复用或强行新建 | 展示 preflight 的已有分支状态，用户确认复用后再执行 |
| 一个项目失败后静默跳过 | 标为阻塞，并询问是否继续其他通过项目 |
