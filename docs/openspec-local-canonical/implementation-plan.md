# OpenSpec 本地中文 Canonical 实施计划

## 1. 目标

本计划用于落地以下已确认目标：

1. 保留 `OpenSpec + superpowers` 的融合流程关系不变。
2. 将 OpenSpec 这一侧改造成中文、本地 canonical 实现。
3. 不再直接混用英文 OpenSpec 正文作为运行资产。
4. 一次性统一文档与工件的物理目录结构。
5. 一次性修复当前 `opsx:*` runtime FAIL。
6. 保留社区验证过的结构和行为模型，只做最小化本地改造。

## 2. 不可变约束

### 2.1 流程关系不变

本轮不改变以下融合流程关系：

`brainstorming -> opsx:propose -> writing-plans -> using-git-worktrees -> opsx:apply -> (subagent-driven-development / executing-plans) -> requesting-code-review -> verification-before-completion -> opsx:verify -> opsx:archive`

### 2.2 标准流程不在本轮重写

以下 first-party 重型流程保留不变：

- `/product`
- `/design`
- `/test-design`
- `/tech-lead`
- `/project-manager`

### 2.3 OpenSpec 本地实现不强行套旧模板

新建的 OpenSpec 侧 runtime 内容遵循：

- 社区结构基线
- 中文正文
- 技术标识保留英文
- 本地最小兼容补丁

不为了贴合 existing first-party 模板而重写正文结构。

## 3. 目标结构

### 3.1 仓库结构

目标结构收敛为：

```text
shared/                         # 现有 first-party skill，保留
community/                      # 社区来源的本地中文 canonical 运行资产
  openspec/
  superpowers/
  SOURCES.yaml
openspec/                       # 统一后的实际工作台
  config.yaml
  designs/
  plans/
  specs/
  changes/
  changes/archive/
tools/
tests/
```

### 3.2 工作台结构

统一后的 `openspec/` 工作台职责如下：

- `openspec/designs/`
  - `brainstorming` 产物
  - 语义定义为“设计草稿”
- `openspec/plans/`
  - `writing-plans` 产物
  - 语义定义为“执行计划”
- `openspec/specs/`
  - 长期规格真源
- `openspec/changes/<change>/`
  - 当前 change 的正式 artifacts
- `openspec/changes/archive/`
  - 归档变更

## 4. 文档与 artifact 命名

### 4.1 设计草稿

`brainstorming` 输出统一改为：

- `openspec/designs/YYYY-MM-DD-<topic>-draft.md`

语义：

- 草稿
- 前置设计收口
- 允许在 `opsx:propose` 前继续修订

### 4.2 正式设计

OpenSpec change 内正式设计保持：

- `openspec/changes/<change>/design.md`

语义：

- 当前 change 的正式技术设计
- 进入 verify/archive 的正式输入

### 4.3 任务与计划

- `openspec/changes/<change>/tasks.md`
  - change 层 checklist
- `openspec/plans/YYYY-MM-DD-<change>.md`
  - 执行层详细计划

## 5. `tasks.md` 与 `plan.md` 规则

### 5.1 职责边界

`tasks.md`：

- change 层真源
- 只记录 implementation items 的完成态
- 为 `apply / verify / archive` 提供客观 checklist

`plan.md`：

- 执行层派生物
- 记录详细步骤、文件修改、测试顺序、执行细节

### 5.2 一致性约束

必须满足：

1. `tasks.md` 是 change 层唯一 checklist 真源。
2. `plan.md` 必须由 `tasks.md` 派生。
3. `plan.md` 每一步必须引用 task id。
4. `verify/archive` 必须做 `tasks-plan` 一致性检查。

### 5.3 推荐格式

`tasks.md` 示例：

```md
- [ ] T1 登录接口
- [ ] T2 登录页与本地会话
- [ ] T3 首页动画与恢复
```

`plan.md` 示例：

```md
1. [T1] 写登录接口测试
2. [T1] 实现 /api/login
3. [T2] 实现登录页和 localStorage
4. [T3] 实现首页动画和恢复
```

## 6. 语言与内容策略

### 6.1 中文化范围

以下内容统一中文化：

- OpenSpec 本地 canonical runtime 正文
- command / skill 说明
- 提示、输出说明、guardrail 文本
- 本地模板说明
- 设计草稿与计划模板

### 6.2 保留英文范围

以下内容继续保留英文：

- 命令名：`opsx:propose`
- 文件名：`proposal.md`、`tasks.md`
- 状态字段：`ready / blocked / done`
- checkbox 语法：`- [ ] / - [x]`
- 代码标识、API path、工具名

### 6.3 来源处理

不再长期保留整份英文 upstream 正文于主仓库。

仅保留：

- upstream repo URL
- commit/tag
- capture date
- 同步说明或拉取脚本
- 本地实现与上游的映射关系

统一记录于：

- `community/SOURCES.yaml`

## 7. 技术实现分层

### 7.1 Markdown

用于：

- `SKILL.md`
- `commands/*.md`
- 模板说明
- 本地 canonical 正文

### 7.2 Bash

用于：

- 安装
- probe
- 运行时审计
- 测试入口
- shell 级迁移动作

### 7.3 Python

用于：

- 中文 canonical 生成/校验
- `tasks-plan` 一致性检查
- 目录迁移辅助
- source-lock 校验

### 7.4 不再作为 canonical 保留

以下不继续作为本地 canonical 长期保留：

- 英文 upstream 正文快照
- TS 模板源码作为本地运行真源
- 已证明不稳的 Codex `prompts/opsx-*.md` 入口形态

## 8. 脚本规划

### 8.1 保留脚本

- [install.sh](/Users/lijieli/org-claude-skills/install.sh)
- `tools/dev/probe-*.sh`
- `tools/validate-contracts.sh`
- `tests/*.sh`

### 8.2 退役或降级的脚本/目录

- `tools/dev/generate_opsx_adapters.py`
- `community-adapters/`
- `third_party/community/` 作为运行来源的角色

### 8.3 新增脚本

建议新增：

1. `tools/community/render_canonical.py`
   - 生成/校验中文 canonical OpenSpec 内容
2. `tools/community/check_task_plan_consistency.py`
   - 校验 `tasks.md` 与 `plan.md`
3. `tools/community/migrate_workspace_paths.py`
   - 迁移旧目录到统一后的 `openspec/`
4. `tools/community/source_lock_check.py`
   - 校验 `community/SOURCES.yaml`

## 9. 迁移顺序

### 阶段 1：冻结 canonical 结构

完成项：

- 新建 `community/`
- 新建 `community/SOURCES.yaml`
- 确定 `openspec/` 新目录结构

### 阶段 2：重建 OpenSpec 本地 canonical

完成项：

- 新建中文 `opsx:*` commands/skills
- 保持社区结构和语义
- 补本地 metadata

### 阶段 3：统一工件目录

完成项：

- `docs/superpowers/specs/* -> openspec/designs/*`
- `docs/superpowers/plans/* -> openspec/plans/*`
- 更新合同、文档、测试、安装路径

### 阶段 4：修 runtime FAIL

完成项：

- 显式 `/opsx:propose|apply|verify|archive` 真实可用
- 默认链真实跑通
- 移除当前错位接法

### 阶段 5：补一致性与来源校验

完成项：

- `tasks-plan` 校验脚本
- source-lock 校验脚本
- 迁移校验

### 阶段 6：全量验收

完成项：

- 安装通过
- probe 通过
- tests 通过
- 用真实小需求复验整条链

## 10. 第一批改动范围

第一批只动“结构和真源边界”，不先做复杂运行修复。

### 第一批要改的目录/文件

- 新建：
  - `community/`
  - `community/SOURCES.yaml`
  - `docs/openspec-local-canonical/implementation-plan.md`
- 重写口径：
  - `shared/assistant.md`
  - `contracts/community-first-chain.yaml`
  - 相关 docs / SOP / capability 文档
- 规划迁移：
  - `openspec/designs/`
  - `openspec/plans/`

### 第一批验收点

1. 新真源边界清楚
2. `design-draft` / `design.md` 语义分离
3. `tasks.md` / `plan.md` 规则写死
4. 统一目录路径在合同和文档中一致

## 11. 第二批改动范围

第二批进入运行层修复。

### 第二批要改的目录/文件

- OpenSpec 本地 canonical runtime 资产
- 安装逻辑
- probe
- runtime tests
- FAIL 相关入口

### 第二批验收点

1. `/opsx:*` 显式可用
2. 默认链可真实推进
3. 安装与测试全部通过

## 12. 验收标准

必须同时满足：

1. OpenSpec 本地 canonical 正文只有一套
2. OpenSpec 运行正文为中文
3. 工作台统一到 `openspec/` 单根
4. `brainstorming` 输出为设计草稿
5. change 内 `design.md` 为正式设计
6. `tasks.md` 与 `plan.md` 通过 task-id 绑定
7. 一致性校验脚本存在并可运行
8. `opsx:*` 显式入口可用
9. 默认融合链真实跑通
10. 全量安装与测试通过

## 13. 风险与控制

### 风险 A：翻译改变行为语义

控制：

- 逐段对照社区结构
- 技术标识不翻
- 关键 guardrails 做对照清单

### 风险 B：目录迁移导致断链

控制：

- 先改合同和文档，再迁实现
- 用迁移脚本和测试一起校验

### 风险 C：`tasks.md` 与 `plan.md` 再次双真源

控制：

- 先写死职责边界
- 再补一致性校验
- archive 前做门禁

### 风险 D：runtime 继续“文档通、实现不通”

控制：

- 以真实 probe 和真实小需求复验为准
- 不以文档链路成立替代 runtime 通过

## 14. 执行建议

执行顺序建议固定为：

1. 先完成第一批结构与真源边界改造
2. 再进入第二批运行时修复
3. 最后再考虑收口旧目录和历史内容

这样可以避免一上来同时改：

- 目录
- 真源
- 运行入口
- 安装逻辑
- probe
- 测试

导致定位困难。
