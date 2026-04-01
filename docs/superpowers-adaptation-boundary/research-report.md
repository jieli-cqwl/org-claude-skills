# superpowers 适配边界调研报告

日期：2026-03-31  
调研模式：`analysis`  
调研对象：当前仓库对 `obra/superpowers` 的采用方式，重点判断哪些属于薄适配，哪些已经进入深分叉，以及哪些位置应回到上游优先。

## 1. 结论先行

当前仓库**不再是“直接使用 superpowers”**，而是已经形成了一个“`superpowers` 方法论 + `OpenSpec` 工件语义 + 本地 rules/reference/contracts 治理”的融合体系。

因此，最佳实践不是回到“完全原样使用”，也不是继续“在本地正文里自由改”，而是：

1. **保留薄适配**
   - 例如中文化、来源锁定、平台 metadata、自动暴露面收窄、工具映射。
2. **承认并单独治理深分叉**
   - 例如 `brainstorming -> opsx:propose`、`writing-plans` 绑定 `tasks.md` 强一致契约、community-first 融合链。
3. **把容易漂移的本地正文改成可再生或可验证**
   - 当前已出现正文损坏和内部路径不一致，说明“本地持有并人工改写正文”已经带来维护风险。

一句话总结：

**你现在的做法不是错，但必须从“下载后改一改”升级为“锁定上游 + 薄适配 + 明确分叉 + 自动校验”的治理模式。**

## 2. 项目上下文扫描

### 2.1 当前仓库如何定义自己

仓库 README 已明确把 `community/` 定义为“社区方案的本地中文 canonical 真源”，其中 `community/superpowers` 承载中文 runtime，`community/SOURCES.yaml` 锁定上游来源和 ref。

证据：

- `README.md`
- `community/SOURCES.yaml`

### 2.2 当前仓库如何定义默认链

`docs/community-first/README.md` 把默认小需求链定义为：

`brainstorming -> opsx:propose -> writing-plans -> using-git-worktrees -> opsx:apply -> (subagent-driven-development 默认 / executing-plans 备选) -> requesting-code-review -> verification-before-completion -> opsx:verify -> opsx:archive`

这已经不是 upstream `superpowers` 原生链，而是本地融合链。

证据：

- `docs/community-first/README.md`
- `README.md`

### 2.3 上游锁定声明

`community/SOURCES.yaml` 对 `superpowers` 锁定到：

- repo: `https://github.com/obra/superpowers`
- ref: `eafe962b18f6c5dc70fb7c8cc7e83e61f4cdde06`

并声明“运行正文改为中文 canonical，但结构、顺序、职责边界保持社区基线”。

这是一个很重要的承诺，因为后续判断的核心就是：**当前实现还是否符合这句承诺。**

## 3. 上游基线

根据锁定的 upstream commit 与 upstream README，`superpowers` 的定位是：

- 一套“coding agents 的软件开发 workflow”
- 核心价值在 workflow discipline，而不是本地组织级工件状态机
- 基本链路是 `brainstorming -> writing-plans -> subagent-driven-development/executing-plans -> review -> verification/finish`
- 安装与更新的理想模式是插件/技能更新，而不是长期手工维护分叉正文

证据：

- upstream README: <https://github.com/obra/superpowers>

## 4. 分类标准

本次将改动分为三类：

### 4.1 薄适配

满足以下特征：

- 不改变上游 skill 的核心职责边界
- 不重写默认 workflow 状态机
- 主要解决平台差异、语言差异、安装差异、暴露面差异
- 可以随着上游更新低成本再生

### 4.2 深分叉

满足以下任一特征：

- 改写了 skill 的终点、前后依赖或工件真源
- 把本地 workflow contract 或组织治理要求直接写进 upstream skill 正文
- 需要本地独立维护正确性，不能再假设上游语义天然成立

### 4.3 应回到上游优先

满足以下任一特征：

- 本地正文已经出现内容损坏、路径漂移或相互矛盾
- 改动本身不提供核心业务价值，只是增加维护面
- 更适合放在 adapter、contract、reference、tests，而不是继续写进 upstream 正文

## 5. 盘点结果

### 5.1 建议保留的薄适配

#### A. 来源锁定与来源标记

这是健康适配，建议保留：

- `community/SOURCES.yaml` 锁定 upstream repo/ref/scope
- 各 skill 文件头部增加 `Source:` 标记

价值：

- 让本地运行资产可追溯
- 明确“这是基于哪一版 upstream”
- 为后续 diff、再生、回归测试提供基线

判断：**薄适配，保留**

#### B. 中文化 runtime

大部分 diff 本质上是中文翻译，而不是流程改写。对中文团队而言，这能降低理解成本。

但这里有前提：

- 中文正文必须保持“可再生”
- 必须有上游 diff 检查
- 必须有内容损坏检测

否则中文化会从“提升可用性”变成“制造分叉噪音”。

判断：**薄适配，但必须受自动校验约束**

#### C. 平台适配 metadata 与工具映射

例如：

- `community/superpowers/codex/skills/brainstorming/agents/openai.yaml`
- `community/superpowers/skills/using-superpowers/references/codex-tools.md`

这类改动解决的是 Codex/Claude/Gemini 的工具差异和自动暴露面问题，不改变上游 skill 的业务语义。

判断：**薄适配，保留**

#### D. 自动暴露面收窄

仓库当前把默认自动入口收敛到 `brainstorming`，并把 `using-superpowers` 视为 manual-only 元规则。

这属于运行面策略，不是重写上游方法论本身。它更适合落在：

- adapter
- 安装脚本
- platform metadata
- runtime contract

而不是继续写进大量 skill 正文。

判断：**薄适配，保留，但应尽量放在 adapter/contract 层**

### 5.2 已经进入深分叉、需要单独治理的部分

#### A. `brainstorming` 的终点已从 `writing-plans` 改为 `opsx:propose`

当前本地 skill 明确写成：

- 设计文档落到 `openspec/designs/...`
- 终点是 `Invoke opsx:propose skill`
- “唯一下一步”是 `opsx:propose`

证据：

- `community/superpowers/skills/brainstorming/SKILL.md`

这不是翻译，也不是 metadata。它直接改了 skill 的流程终点和工件体系。

判断：**深分叉**

#### B. `writing-plans` 被注入了本地 `tasks.md` 强一致契约

当前本地 skill 除了保存路径改成 `openspec/plans/...`，还新增了：

- checklist 必须带 `[task-id]`
- `plan.md` 引用的 task id 必须全部来自 `tasks.md`
- 必须能通过一致性校验器
- 服务于 `opsx:verify` 的强阻断

证据：

- `community/superpowers/skills/writing-plans/SKILL.md`

这已经不是 upstream 的“如何写计划”，而是本地工件模型和验证机制的一部分。

判断：**深分叉**

#### C. community-first 融合链本身

仓库文档把 `superpowers` 与 `OpenSpec` 串成一个默认链，并把 `opsx:*` 放进中间。

证据：

- `docs/community-first/README.md`
- `README.md`

这意味着仓库现在维护的不是单纯的 superpowers 采用策略，而是一条本地产品化流程。

判断：**深分叉**

#### D. “superpowers 执行骨架 + OpenSpec 工件语义” 的本地产品化设计

`docs/community-first/best-practice-implementation-plan.md` 已进一步把体系重新定义为：

- superpowers 管执行骨架
- OpenSpec 只吸收概念，不依赖其运行时
- `tasks.md` 是独立验收真源
- 执行收口在 `subagent-driven-development`

这比当前 `docs/community-first/README.md` 的链路更进一步，说明本地设计还在继续演化。

判断：**深分叉，而且内部仍在变化**

### 5.3 最值得回到上游优先的位置

#### A. 本地正文已经出现损坏

`community/superpowers/skills/requesting-code-review/SKILL.md` 中混入了明显无关的错误文本：

- `Error 500 (Server Error)!!1500...`

证据：

- `community/superpowers/skills/requesting-code-review/SKILL.md`

这说明当前人工维护正文的链路已经不稳定。

判断：**应回到上游优先，至少把正文维护改成可再生或有 diff/完整性校验**

#### B. 本地正文内部路径已经不一致

当前仓库里同时存在：

- `brainstorming` 写入 `openspec/designs/...`
- `writing-plans` 写入 `openspec/plans/...`
- `spec-document-reviewer-prompt` 仍写 `docs/superpowers/specs/`
- `subagent-driven-development` 示例仍写 `docs/superpowers/plans/feature-plan.md`
- `requesting-code-review` 示例仍写 `docs/superpowers/plans/deployment-plan.md`

证据：

- `community/superpowers/skills/brainstorming/SKILL.md`
- `community/superpowers/skills/writing-plans/SKILL.md`
- `community/superpowers/skills/brainstorming/spec-document-reviewer-prompt.md`
- `community/superpowers/skills/subagent-driven-development/SKILL.md`
- `community/superpowers/skills/requesting-code-review/SKILL.md`

这说明当前分叉不是“统一改造”，而是“部分迁移 + 部分遗留”。

判断：**应回到上游优先，并把路径差异沉到 adapter 或模板生成层**

#### C. “保持社区基线”这句承诺已经不再完全成立

`community/SOURCES.yaml` 声明结构、顺序、职责边界保持社区基线，但实际已经发生：

- 终点改写
- 工件真源改写
- 验证契约注入
- 融合链扩展

这不是坏事，但意味着不应继续把这些文件当成“只是中文 canonical runtime”。

更准确的做法是二选一：

1. 要么承认它是 `org-community runtime`，不再强调“保持社区基线”
2. 要么把深分叉挪出 upstream skill 正文，保留 upstream-ish skill，分叉逻辑放 wrapper/adapter/contract

判断：**建议重新分层**

## 6. 最终建议

### 6.1 你现在应该保留什么

保留：

- upstream 来源锁定
- 中文化能力
- 平台 metadata / 工具映射
- 自动暴露面治理
- tests/contracts 对运行面的约束

这些都是高价值、低锁定、易再生的改动。

### 6.2 你现在应该承认什么

承认以下内容已经不是“二次封装”，而是“本地产品化分叉”：

- `brainstorming -> opsx:propose`
- `writing-plans + tasks.md` 强一致
- community-first 默认链
- superpowers 与 OpenSpec 的融合状态机

这些内容不该再伪装成“上游原样使用”。

### 6.3 你现在最应该调整什么

优先级最高的调整是：

1. **修正文损坏和内部路径漂移**
2. **把深分叉逻辑从 upstream skill 正文里尽量外移**
3. **为中文 canonical 加再生机制**
   - upstream diff 检查
   - 关键路径一致性检查
   - 非法文本/损坏内容检查
4. **重新定义分层**
   - upstream-ish runtime
   - adapter
   - workflow contract
   - org-specific governance

## 7. 推荐落地方案

### 方案 A：继续当前方向，但补治理

做法：

- 保留 `community/superpowers`
- 明确它是本地 runtime，不再强调“保持社区基线”
- 为正文建立生成/校验/回归机制

优点：

- 兼容当前仓库设计
- 不需要大搬迁

缺点：

- 仍然要长期维护本地分叉正文
- 上游升级成本持续存在

推荐度：**可行，但不是最优**

### 方案 B：上游优先 + wrapper/adapter 分层

做法：

- 尽量保留 upstream 对等 skill 正文
- 中文化和平台化作为薄适配保留
- 把 `opsx:*` 融合、`tasks.md` 契约、默认链状态机放到 wrapper skill、contract、docs、tests

优点：

- 分叉边界清晰
- 上游升级成本最低
- 更容易判断“这是 upstream 问题还是本地策略”

缺点：

- 需要一次分层整理
- 运行面会比“所有逻辑写进一个 skill 正文”更抽象一点

推荐度：**最推荐**

### 方案 C：彻底本地化，放弃上游对齐

做法：

- 把当前体系彻底改名为本地 workflow
- upstream 仅作为参考，不再保留“社区基线”约束

优点：

- 设计自由度最高

缺点：

- 完全失去 upstream 升级红利
- 长期维护成本最高

推荐度：**不推荐，除非你确定以后不再追 upstream**

## 8. 最终判断

对你当前场景，最优答案不是“直接拿来用”也不是“继续随手二改”，而是：

**以上游为方法论基线，以本地 adapter 承接平台差异，以 contract/tests 承接治理约束，以显式分叉文档承接真正的产品化偏离。**

换句话说：

- **社区最佳实践应该优先拿来用**
- **但团队长期运行几乎一定需要薄封装**
- **只有当你已经改了 workflow 状态机和工件真源时，才应该承认自己进入了深分叉治理**

当前仓库已经进入这个阶段。

## 9. 证据索引

### 本地仓库证据

- `community/SOURCES.yaml`
- `README.md`
- `docs/community-first/README.md`
- `docs/community-first/best-practice-implementation-plan.md`
- `community/superpowers/skills/brainstorming/SKILL.md`
- `community/superpowers/skills/writing-plans/SKILL.md`
- `community/superpowers/skills/requesting-code-review/SKILL.md`
- `community/superpowers/skills/brainstorming/spec-document-reviewer-prompt.md`
- `community/superpowers/skills/subagent-driven-development/SKILL.md`
- `community/superpowers/codex/skills/brainstorming/agents/openai.yaml`

### 外部一手资料

- `obra/superpowers` upstream README  
  <https://github.com/obra/superpowers>
- GitHub Copilot custom instructions 文档  
  <https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions>
- GitHub Copilot skills 文档  
  <https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-skills>
