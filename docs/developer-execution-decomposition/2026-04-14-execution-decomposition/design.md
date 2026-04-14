# Developer 执行拆解阶段 + Tech-lead impact_files 下沉

## 问题

product → design → test-design → tech-lead → developer 链路中存在一个认知断层：

- **tech-lead Task** 定义了"交付什么、验什么"（文件路径、AC、依赖、proving_command）——这是**验证原子性**
- **developer** 需要知道"怎么实现"（用什么模式、复用什么代码、什么顺序）——这是**执行原子性**

人类开发者凭经验隐式填补这个空白。AI agent 无法稳定做到，导致三类失败：
1. 方向跑偏：没读已有代码就选了实现路径
2. 遗漏边界：不知道项目已有的约束和惯例
3. 粒度不够：面对多文件 Task 没有分步骤纪律，中途丢失上下文

当前 developer SKILL.md 步骤 1 "理解"只有一句话，然后直接进入 TDD 循环——断层就在这里。

## 设计决策

### 方案选择：增强 developer 的"理解"阶段（方案 C）

**否决方案 A（加新 skill）**：链路已 5 跳，再加 1 跳开销大；planner 读完代码后 developer 还要再读——重复上下文加载；计划在执行前生成，并行开发时可能过时。

**否决方案 B（增强 tech-lead）**：tech-lead 在计划层工作不在代码层——不应深度读代码；tech-lead 已很重（SKILL.md + 5 个 reference + 950 行 gate 脚本）；计划时的 hints 到执行时可能过时。

**选择方案 C 的理由**：developer 在执行时刻拥有最新鲜的代码上下文；探索和规划在同一次上下文中完成；不增加链路跳数；不增加重复加载。

### 附带调整：tech-lead impact_files 下沉

tech-lead 的 `impact_files`（受波及但不直接改的文件）下沉给 developer 在执行时自行发现。理由：

- developer 探索代码时会自然发现波及文件，比 tech-lead 的推测更准确
- delivery-owner 不依赖 impact_files 做调度决策（已确认）
- tech-lead 保留 `shared_files`（并行安全必需，调度前必须知道）

## Developer 执行拆解阶段

将步骤 1 从一句话"理解"扩展为 5 个子步骤：

| 子步骤 | 做什么 | 解决的不确定性 |
|--------|--------|-------------|
| 1a 代码探索 | 读取 Task 相关文件 + 同级目录 | "这片代码现在长什么样？" |
| 1b 模式识别与复用 | 提炼项目惯例，识别可复用代码 | "这个项目的惯例是什么？" |
| 1c 步骤规划 | AC → 有序 TDD 实现步骤 | "先做什么后做什么？" |
| 1d 风险标注 | 标注范围外文件、隐含依赖、模式不明确点 | "哪里可能出问题？" |
| 1e 确认或提问 | 清晰则进入 TDD；不确定则提问 delivery-owner | "有没有拿不准的？" |

### 比例缩放

| 深度 | 触发条件 | 内容 |
|------|---------|------|
| 轻量 | 单文件 AND 已有清晰模式 AND 复杂度 S（全部满足） | 记录遵循的模式，直接进 TDD |
| 标准 | 默认 | 探索 + 步骤规划 |
| 完整 | 4+ 文件 OR 首次接触代码区域 OR task_type=探索（任一满足） | 全部 5 步 + 详细 mini-plan |

### 输出物

mini-plan 记录在 `developer-report-Task-N.md` 的 `### 执行拆解` 区块中，位于 TDD 记录之前。包含：代码探索结论、复用候选、实现步骤、风险与发现、拆解深度。

### 自审新维度

自审增加第 7 维度"执行拆解遵循度"：实际实现是否偏离了拆解计划？偏离是否有合理原因？

## Tech-lead 简化

从 Task 字段中移除 `impact_files`，保留 `shared_files`。连带修改：plan-template、completion_check.sh、plan-reviewer-prompt、decomposition-patterns。
