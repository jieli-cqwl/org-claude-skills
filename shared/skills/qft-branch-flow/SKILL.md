---
name: qft-branch-flow
user-invocable: true
description: "全房通 Git 分支流程向导。Use when 需要按全房通分支规范创建需求分支、版本分支、紧急 BUG 分支、合并到部署分支或主分支、推送远端，尤其是多项目、多仓库、容易选错来源/目标分支或需要逐步确认的场景。"
model: sonnet
---

# /qft-branch-flow -- 全房通分支流程向导

## Goal

按全房通分支管理规范，一步一步引导用户选择场景、项目、分支字段、操作计划、Git 检查、执行和 push；防止错项目、错仓库、错来源分支、错目标分支、错合并方向和未确认推送。

## HARD-GATE

1. 每一步只处理一个决策；用户确认当前步骤后，才进入下一步。
2. 所有项目展示必须包含业务名、仓库名和主分支。
3. 目标分支只能由开发输入字段生成，或由开发选择/输入已有分支；不要替开发猜。
4. 操作计划必须由 `scripts/qft_branch_flow.py plan` 生成，并由 `scripts/qft_branch_flow.py validate` 校验通过；不要手写最终执行计划。
5. Git 写操作前必须先确认已校验计划，再确认执行。
6. push 必须在本地创建/合并完成后单独确认。
7. 工作区不干净、来源分支缺失、目标分支冲突或 remote 不匹配时，阻塞对应项目；不要静默跳过。

## Workflow

| 步骤 | 输入 | 动作 | 输出 | 失败状态 |
| --- | --- | --- | --- | --- |
| 1. 场景确认 | 用户选择的业务场景编号 | 回显场景语义并等待 `确认` | 已确认 scenario | 用户未确认则停留本步 |
| 2. 项目确认 | 项目编号列表 | 展示业务名、仓库名和主分支 | 已确认 project set | 未知项目或未确认则停留本步 |
| 3. 分支信息确认 | 场景所需字段 | 生成或识别分支名并回显 | 已确认 branch inputs | 字段缺失或用户修改则回到本步 |
| 4. 计划生成与校验 | scenario、projects、branch inputs | 调用 `plan` 生成 JSON，再调用 `validate` 校验 | 已校验 plan.json | validate 失败则阻塞 Git 检查 |
| 5. 执行前检查 | 已校验 plan.json | 检查仓库、remote、工作区、来源分支、目标分支和同步状态 | 通过/阻塞项目分组 | 存在阻塞时由用户选择继续范围 |
| 6. 执行与 push | 用户确认执行或推送 | 执行本地 Git 操作；push 单独确认 | 完成、未执行、下一步 | 冲突或 Git 失败时停止并报告项目状态 |

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
| 紧急 BUG 分支 | `3.0.0.MASTER_BUG_版本号` | `V.版本号` | 紧急线上 BUG 修复 |

合并方向：

- 业务提测/发版：业务开发分支 -> `V.版本号` -> 项目主分支。
- 紧急 BUG：先从 `V.版本号` 创建紧急 BUG 分支，修复完成后再将紧急 BUG 分支合回 `V.版本号`，最后由 `V.版本号` 回合项目主分支。
- 日常同步：项目主分支 -> 当前业务开发分支。
- 上线前同步：项目主分支 -> `V.版本号`。
- 业务分支和 BUG 分支同时存在时，以业务分支为准。

## 确定性计划机制

固定规则交给脚本处理，向导只负责收集输入、解释计划和逐步确认。

- 项目白名单来自 `references/project-registry.json`。
- 分支命名和场景规则来自 `references/branch-policy.json`。
- 计划结构以 `contracts/branch-plan.schema.json` 为准。Load timing: 第 4 步生成计划前读取；purpose: 校验计划字段和步骤结构；output: 合法 plan JSON；consumer: Git 检查和执行步骤；verification: `python3 scripts/qft_branch_flow.py validate --input <plan.json>`。
- 生成计划：`python3 scripts/qft_branch_flow.py plan <scenario> --projects <repo1,repo2> --version <版本号> ...`
- 校验计划：`python3 scripts/qft_branch_flow.py validate --input <plan.json>`。
- `ensure_branch` 表示目标分支存在则使用现有分支，不存在才从来源分支创建；执行前检查必须验证目标分支状态。
- `target_branch` 为 `<project-main-branch>` 时，表示每个项目使用自己的主分支；实际 Git 目标以 `steps[*].target_branch` 为准。
- `validate` 失败时停止；只能回到前序步骤修正输入或计划，不进入 Git 检查和执行。

## 逐步确认向导


### 第 1 步：确认操作场景

只展示业务语义，不展示 Git 细节：

```text
第 1 步：选择操作场景

1. 开发需求：创建业务开发分支
2. 日常同步：主分支同步到业务开发分支
3. 提测/发版：确保版本分支，并合并业务分支
4. 线上 BUG：创建紧急 BUG 分支
5. 上线回合：版本分支与主分支同步

请输入编号：
```

用户输入后回显，并等待 `确认`。

### 第 2 步：确认涉及项目

按短卡片展示，可多选：

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

回显所选项目，并等待 `确认`。

### 第 3 步：确认分支信息

按场景只问必要字段：

- 开发需求：名字缩写、需求编号、版本号（月日，如 `0301`）、是否 `_DELAY`。
- 日常同步：版本号、业务开发分支名；计划将项目主分支合入业务开发分支。
- 提测/发版：版本号、业务分支名；计划先确保版本分支可用，再将业务分支合入版本分支。
- 线上 BUG：版本号、来源版本分支 `V.版本号`、目标 BUG 分支 `3.0.0.MASTER_BUG_版本号`；计划必须包含从 `V.版本号` 创建 BUG 分支，以及修复后将 BUG 分支合回 `V.版本号`。
- 上线回合：选择上线前同步（主分支 -> 版本分支）或上线后回合（版本分支 -> 主分支）。

生成或识别分支名后先回显，等待 `确认`。

### 第 4 步：生成并确认操作计划

用户确认分支信息后，先调用脚本生成 `plan.json`，再调用脚本校验同一份计划。示例：

```bash
python3 scripts/qft_branch_flow.py plan create-dev --projects qft-all,qft-app --owner QW --requirement 0001 --version 0301 > plan.json
python3 scripts/qft_branch_flow.py validate --input plan.json
```

只展示校验通过后的计划摘要，用项目卡片，不用密集表格：

```text
第 4 步：确认操作计划

1. 后端业务 qft-all
   来源分支：3.0.0.MASTER
   目标分支：3.0.0.DEV_QW_0001_0301
   操作：创建业务开发分支

2. PC 前端 qft-app
   来源分支：master
   目标分支：3.0.0.DEV_QW_0001_0301
   操作：创建业务开发分支

确认计划正确请输入：确认计划
```

未收到 `确认计划` 前，不做 Git 写操作；计划未通过 `validate` 时，也不做 Git 检查和执行。

### 第 5 步：执行前检查

计划确认后才运行检查。每个项目至少检查：

- 当前目录是否是 Git 仓库。
- remote 是否匹配仓库名。
- 工作区是否干净。
- 来源分支是否存在。
- 目标分支是否已存在。
- 本地和远端状态是否需要 fetch/pull。

按通过/阻塞分组展示。存在阻塞时，让用户选择“只继续通过项目”或“全部停止”。

### 第 6 步：执行与 push

执行创建或合并前，要求用户输入 `确认执行`。

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
- 遇到冲突立即停止，列出冲突文件；不要自动解决冲突。
- 不自动删除分支；删除属于维护动作，当前只提示规范，不执行。
- 不使用 `git reset --hard`、`git clean`、强推或跳过 hook。

## 输出

每轮结束输出分组结果：

```text
完成：
- qft-all：已从 3.0.0.MASTER 创建 3.0.0.DEV_QW_0001_0301，已推送 origin

未执行：
- qft-app：工作区有未提交改动，已阻塞

下一步：
- 处理 qft-app 未提交改动后重新运行本向导
```

## Verification

- 计划生成后必须运行 `python3 scripts/qft_branch_flow.py validate --input <plan.json>`；只有 exit 0 且 plan JSON 符合 schema 才能进入 Git 检查。
- 执行前检查必须逐项目展示仓库、remote、工作区、来源分支、目标分支和同步状态；任一失败项进入阻塞分组。
- 本地写操作后必须用 `git status` 和目标分支存在性证明结果；push 后必须显示已推送的 remote 和 branch。
- 输出分组必须包含已完成、未执行和下一步，供用户继续处理阻塞项目。

## 常见错误

| 错误 | 正确做法 |
| --- | --- |
| 一次性展示所有流程、项目和字段 | 分步确认，当前步骤确认后再进入下一步 |
| 只写业务名不写仓库名 | 同时展示业务名、仓库名、主分支 |
| 替用户猜目标分支 | 由输入字段生成或由用户选择已有分支 |
| 创建分支和 push 一起确认 | 本地写操作确认一次，push 单独确认 |
| 手写最终执行计划 | 用 `scripts/qft_branch_flow.py plan` 生成，并用 `validate` 校验通过后再展示 |
| validate 失败后继续执行 | 回到前序步骤修正输入或计划，通过后再进入 Git 检查 |
| 一个项目失败后静默跳过 | 标为阻塞，并询问是否继续其他通过项目 |
