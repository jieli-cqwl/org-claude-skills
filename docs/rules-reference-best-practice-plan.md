# Rules + Reference 最佳实践改进方案

> 基于 LLM 指令文档最佳实践评审，全量改进 shared/rules 和 shared/reference 体系。

## 改进目标

1. rules 只放不可协商的红线，每条带 why，精简到高信噪比
2. reference 只放通用按需知识，不混入 MUST 级规则，不混入 skill-specific 协议
3. 入口文件（assistant.md）提供 reference 触发映射，让 LLM 知道何时读什么
4. 消除文件间的重复、矛盾和孤立引用

## 改动总览

| 类别 | 文件数 | 改动类型 |
|------|--------|---------|
| rules 改进 | 4 | 内容重写 |
| reference 通用知识改进 | 12 | 内容调整 + 合并 |
| reference → skills 迁移 | 5 | 文件移动 |
| reference 合并淘汰 | 3 | 合并为 1 |
| assistant.md 改进 | 1 | 增加触发映射 |
| 引用路径修复 | ~15 | 路径更新 |

---

## Phase 1：Rules 层改进（4 文件）

### 1.1 铁律.md — 补 why + 精简教学表格

改动：
- 每条铁律补充 why（一句话原因）
- "常见绕过借口"表格从 7 行精简到 3 行（保留最高频的），其余移到 reference
- 补充孤立引用：全栈完成标准指向 `reference/全栈开发.md`

改后结构：
```
# 铁律（零容忍）

## 禁止降级
方案执行失败时，必须报告失败原因并等待指示。
Why：静默降级掩盖真实失败，用户基于错误假设做后续决策，降级方案未经评估可能引入更大风险。

## 禁止用 Mock 伪造验收
验收结论必须建立在真实依赖、真实测试环境或已验证的集成路径上。
Why：Mock 只能证明替身行为，无法暴露真实环境中的集成问题、数据格式差异和性能瓶颈。
测试分层与隔离策略见 `reference/测试规范.md`。

## 硬编码规则来源
硬编码约束统一由 `rules/代码规范.md` 定义并执行，本文件不重复规则正文。

## 禁止跳过/删除/注释测试
测试失败时必须修复根因，禁止用 skip/注释/删除绕过。
Why：skip 的测试会被遗忘，随时间累积形成测试债务，掩盖回归风险的真实信号。

## 零容忍行为
- 虚假完成（代码是占位符）
- 删除 TODO/FIXME 假装修复——必须实现功能后再删除标记
- 部分实现假装全部完成——必须逐条对照需求
- 声称全栈任务完成时，前后端都必须完成并联调通过（详见 `reference/全栈开发.md`）
Why：LLM 训练分布倾向于"声称完成"以获得正反馈，这些是最常见的欺骗模式。

## 禁止模糊表述
禁止使用"基本上、应该、可能、大概、差不多"。
Why：模糊表述让用户无法判断完成度和风险，是虚假完成的前兆信号。

## 完成 = 验证通过
声称"完成"前，必须亲眼看到验证命令成功输出。详见 `reference/完成前验证.md`。
```

删除内容：
- "日志输出假装功能"（与虚假完成重复）
- "常见绕过借口"表格精简（保留"确信不是验证"、"Mock 一下更快"、"先跳过这个测试"3 条最高频的）

### 1.2 执行纪律.md — 补 why + 精简跑偏表格 + 删噪音规则

改动：
- 关键规则补 why
- "常见跑偏模式"表格从 10 行精简到 5 行（保留最高频的）
- 删除 2 条噪音规则（LLM 默认行为已覆盖）：
  - "项目已有命名风格 -> 保持一致"（LLM 默认遵循上下文风格）
  - "输出格式要求 -> 严格遵守"（LLM 默认遵循用户指定格式）

改后关键 section 示例：
```
## 理解优先

- 不确定需求含义时，必须 AskUserQuestion，禁止猜测后执行
  Why：LLM 倾向于用训练分布中最常见的解释填补歧义，而非承认不确定性
- 发现需求有矛盾/遗漏时，报告矛盾并提出建议，等用户裁决
- 理解后复述关键点，AskUserQuestion 对齐后再执行

## 遵守约定

- 项目已有技术栈/框架/库 -> 使用现有的，禁止引入替代品（除非用户要求）
  Why：LLM 训练数据中某些技术栈出现频率更高，会倾向于推荐"更流行"的方案而非项目已有方案

## 流程守门

- 显式调用 skill 时，只按该 skill 的定义执行，禁止自行切换到另一条流程
  Why：流程切换会导致前置条件和工件链断裂，下游 skill 收到不完整输入
- Skill 定义的流程步骤必须逐步执行，禁止跳过或合并步骤
  Why：每个步骤存在是因为它产出下一步的必要输入，跳过会导致后续步骤基于不完整信息执行
```

### 1.3 代码规范.md — SHOULD 和原则映射表移到 reference + 补孤立引用

改动：
- SHOULD 区（6 条建议）移到 `reference/代码质量.md`
- 原则映射表（11 行）移到 `reference/代码质量.md`
- 硬编码规范 section 补充引用：`详细分层与命名见 reference/硬编码治理规范.md`
- "边界与引用" section 补充：`全栈开发协作边界：见 reference/全栈开发.md`

### 1.4 文档管理.md — 补 why + 清理矛盾

改动：
- 每条规则补 why
- 修复 `{{RUNTIME_HOME}}` 模板变量为相对路径 `reference/文档规范.md`

改后：
```
# 文档管理

> 过时文档被 LLM 读取 → 按错误模式写代码 → 连锁错误。文档准确性是代码正确性的前提。

## 同步

- 代码与文档必须同步更新，过时文档视为 Bug
- 完成标准：代码 + 文档同步完成才算完成

## 归档

- 过时文档必须归档至 docs/archive/（不参考此目录）
  Why：未归档的过时文档会被 LLM 当作有效参考读取，产生连锁错误
- 任务完成后整目录移至 docs/archive/{task}/
- 发现过时文档时立即归档，不留到"以后处理"
  Why：延迟归档 = 延迟风险暴露，下一次对话就可能读到错误文档

## 设计文档

- 只描述"是什么"和"为什么"，禁止 checklist/版本待办（进度跟踪属于 plan 文档）
  Why：设计文档混入进度跟踪会导致职责模糊，LLM 无法区分"设计决策"和"执行状态"

## 详细规范

- 稳定的命名、强调和归档约定 → 详见 `reference/文档规范.md`
- workflow-specific 的目录骨架、阶段工件与模板要求 → 以对应 skill / template / protocol 文档为准
```

---

## Phase 2：Reference 通用知识改进

### 2.1 合并测试三件套为一个文件

将 `TDD规范.md` + `测试分层策略.md` + `测试代码质量.md` 合并为 `测试规范.md`。

原因：
- 三个文件有大量重复（Mock 禁令 3 处、测试命名 2 处、AAA 模式 2 处、测试分层表 2 处）
- 它们的触发场景完全相同（写测试时）
- 合并后约 120 行，仍在合理范围内

合并策略：
- TDD规范.md 的 Red-Green-Refactor 作为主干
- 测试分层策略.md 的金字塔和隔离策略合入"测试分层"章节
- 测试代码质量.md 的 AAA/DAMP/命名/工厂合入"测试代码质量"章节
- Mock 禁令统一为一处，引用 `rules/铁律.md`
- 删除旧的三个文件

### 2.2 文档规范.md — 清理内部矛盾

改动：
- 删除"目录结构" section（第 5-14 行）——这是 workflow-specific 内容，与文件头声明和第 49 行声明矛盾
- 删除"workflow-specific 目录骨架" section（第 49-56 行）——纯声明性内容，删除矛盾源后不再需要
- 删除"创建条件" section（第 25-33 行）——这是 workflow-specific 的规模判断，应由 skill 定义
- 保留：命名规则、术语约定、强调格式边界（这些是跨流程稳定的约定）
- 补充触发条件

改后：
```
# 文档规范

> 触发条件：创建或更新文档时读取。
> rules/文档管理.md 定义核心原则。本文件补充稳定的文档命名、强调和归档约定。

## 命名规则
（保留原内容）

## 术语约定（范围边界）
（保留原内容）

## 强调格式边界
（保留原内容）
```

### 2.3 性能效率.md — MUST 规则上提到 rules

改动：
- 将"禁止无限累积"、"大表必须分页"、"必须有超时控制"、"缓存引入必须经用户同意"4 条 MUST 规则上提到 `rules/代码规范.md` 的新 section "性能约束"
- 本文件保留为指南性质（检查清单、推荐做法），措辞从"必须/禁止"改为"应/建议"

### 2.4 硬编码治理规范.md — MUST 规则上提到 rules + 补引用入口

改动：
- 将"X 必须提升到全局"、"禁止跨模块导入模块级常量"2 条 MUST 规则上提到 `rules/代码规范.md` 硬编码规范 section
- 本文件保留为分层指南和命名规范
- 补充触发条件

### 2.5 全栈开发.md — 措辞对齐 + 补引用入口

改动：
- 第 7 行"前后端都应完成"改为"前后端都必须完成"，与铁律对齐
- 补充触发条件：`触发条件：任务涉及前后端同时修改、接口联调、或全栈功能交付时读取`
- 铁律.md 补充引用指向本文件（已在 1.1 中处理）

### 2.6 技术选型.md — 补引用入口

改动：
- 补充触发条件：`触发条件：引入新技术栈/框架、>=2 可行方案、基础设施变更时读取`
- `rules/执行纪律.md` 的"遵守约定"section 补充引用：`技术选型流程见 reference/技术选型.md`

### 2.7 其余通用 reference 文件 — 补触发条件

对以下文件补充触发条件行（文件头 blockquote 下方）：

| 文件 | 触发条件 |
|------|---------|
| 代码复用.md | 新增功能实现前、发现疑似重复代码时读取 |
| 复用证据与新建门禁.md | 准备新增实现且需要收集复用证据时读取 |
| 代码质量.md | 执行代码质量检查、配置门禁变量、查找 lint 命令时读取 |
| 完成前验证.md | 准备声称任务"完成"前读取 |
| 设计原则.md | 面临设计决策（是否抽象/分层/引入模式）时读取 |
| 影响范围分析.md | 评估变更影响范围、填写 impact_files 时读取 |
| 系统调试.md | 遇到报错、测试失败、运行异常需要定位原因时读取 |
| mcp-server开发.md | 开发 MCP server 时读取 |

---

## Phase 3：Skill-Specific 协议迁移（5 文件）

### 3.1 迁移文件列表

| 源文件 | 目标位置 | 引用方 |
|--------|---------|--------|
| review-iteration-protocol.md | 移到 `shared/protocols/`，安装时仍渲染到 runtime `reference/` | product, design, test-design, review |
| review-fix-loop-protocol.md | 移到 `shared/protocols/`，安装时仍渲染到 runtime `reference/` | product, design, tech-lead, project-manager |
| phase-selection-protocol.md | 移到 `shared/protocols/`，安装时仍渲染到 runtime `reference/` | design, test-design, tech-lead, project-manager |
| constitution-template.md | 移到 shared/skills/design/references/ | design (主), product (读取检查) |
| description-spec.md | 移到 shared/skills/new-skills/references/ | new-skills |

注意：review-iteration-protocol、review-fix-loop-protocol、phase-selection-protocol 被 4+ 个 skill 共同引用，如果移到某一个 skill 下会造成跨 skill 引用混乱。因此不下沉到某个 skill 私有目录，而是提升到 `shared/protocols/`，再由安装链路汇总进 runtime `reference/`。

修正后的迁移策略：
- constitution-template.md → `shared/skills/design/references/constitution-template.md`
- description-spec.md → `shared/skills/new-skills/references/description-spec.md`
- review-iteration-protocol.md → `shared/protocols/review-iteration-protocol.md`
- review-fix-loop-protocol.md → `shared/protocols/review-fix-loop-protocol.md`
- phase-selection-protocol.md → `shared/protocols/phase-selection-protocol.md`

### 3.2 引用路径更新

- constitution-template.md 迁移后：更新 `design/SKILL.md` 和 `product/SKILL.md` 中的引用路径
- description-spec.md 迁移后：更新 `new-skills/SKILL.md` 中的引用路径
- 文档规范.md 中对 phase-selection-protocol.md 的引用：删除（该 section 已在 2.2 中被清理）

---

## Phase 4：Assistant.md 入口改进

### 4.1 增加 reference 触发映射

在"配置导航"section 后增加：

```
## Reference 触发映射

| 场景 | 读取 |
|------|------|
| 写测试 | reference/测试规范.md |
| 新增实现 | reference/代码复用.md → reference/复用证据与新建门禁.md |
| 声称完成 | reference/完成前验证.md |
| 设计决策 | reference/设计原则.md |
| 评估变更影响 | reference/影响范围分析.md |
| 定位问题 | reference/系统调试.md |
| 全栈任务 | reference/全栈开发.md |
| 技术选型 | reference/技术选型.md |
| 代码质量检查 | reference/代码质量.md |
| 文档创建/更新 | reference/文档规范.md |
| 硬编码治理 | reference/硬编码治理规范.md |
| 性能优化 | reference/性能效率.md |
```

### 4.2 修复模板变量

`{{ENTRY_DOC}}` 保留（由安装脚本替换），但确认安装脚本覆盖所有模板变量。

---

## Phase 5：消除重复与统一 Mock 禁令

### 5.1 Mock 禁令统一

当前 5 处出现，措辞各异：
1. 铁律.md："禁止用 Mock 或跳过外部交互的方式伪造通过信心"
2. TDD规范.md："用 Mock 代替真实验收"（反模式表）
3. TDD规范.md："禁止用 Mock 直接充当验收证据"（完成前检查）
4. 测试分层策略.md："用 Mock 代替集成测试"（常见错误表）
5. 代码质量.md："禁止用 Mock 伪造验收结论"

改后：
- 铁律.md 保留唯一权威定义（已在 1.1 中处理）
- 合并后的 测试规范.md 中统一改为：`见 rules/铁律.md "禁止用 Mock 伪造验收"`
- 代码质量.md 中统一改为：`见 rules/铁律.md`

---

## 改后文件清单

### rules/（4 文件，不变）
- 铁律.md（重写）
- 执行纪律.md（重写）
- 代码规范.md（调整）
- 文档管理.md（重写）

### reference/（从 22 → 17 文件）
删除：
- TDD规范.md（合并入 测试规范.md）
- 测试分层策略.md（合并入 测试规范.md）
- 测试代码质量.md（合并入 测试规范.md）
- constitution-template.md（迁移到 skills/design/references/）
- description-spec.md（迁移到 skills/new-skills/references/）

新增：
- 测试规范.md（合并产物）

保留并改进（15 文件）：
- 代码复用.md（补触发条件）
- 复用证据与新建门禁.md（补触发条件）
- 代码质量.md（接收 SHOULD 区和原则映射表，补触发条件）
- 完成前验证.md（补触发条件）
- 设计原则.md（补触发条件）
- 影响范围分析.md（补触发条件）
- 系统调试.md（补触发条件）
- 全栈开发.md（措辞对齐，补触发条件）
- 技术选型.md（补触发条件）
- 性能效率.md（MUST 上提后降级为指南，补触发条件）
- 硬编码治理规范.md（MUST 上提后降级为指南，补触发条件）
- 文档规范.md（清理矛盾，补触发条件）
- mcp-server开发.md（补触发条件）
- review-iteration-protocol.md（标注 skill-specific）
- review-fix-loop-protocol.md（标注 skill-specific）
- phase-selection-protocol.md（标注 skill-specific）
- Skill质量标准.md（保持不变）

---

## 执行顺序

1. Phase 1：Rules 层改进（铁律 → 执行纪律 → 代码规范 → 文档管理）
2. Phase 2：Reference 通用知识改进（合并测试三件套 → 清理文档规范 → MUST 上提 → 补触发条件）
3. Phase 3：Skill-specific 协议迁移（constitution-template → description-spec → 标注剩余 3 个）
4. Phase 4：Assistant.md 入口改进
5. Phase 5：消除重复（Mock 禁令统一 → 交叉引用修复）

## 风险控制

- 每个 Phase 完成后运行现有测试确认无破坏
- 文件移动前确认所有引用路径已更新
- 合并文件前确认无内容遗漏
