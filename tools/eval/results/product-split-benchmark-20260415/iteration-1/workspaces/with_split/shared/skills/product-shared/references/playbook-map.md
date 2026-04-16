# Product Split Playbook Map

> 引用者：`/product`、`/product-director`、`/product-manager`
> 作用：提供 split 后唯一的总览式玩法入口，回答“整套打法是什么、当前在哪一段、下一步该去哪”

这份 playbook 只描述共享方法论与路由，不自证“split 一定更强”。
“是否比旧 monolith 更强”必须由 `docs/product-role-split-20260414/evidence-and-eval-plan.md` 约定的 contract、benchmark、blind comparison 与人工可复核证据共同回答。

## 全局流程图

```mermaid
flowchart TD
    A["/product compat shell"] --> B["/product-director\n根问题 / 目标 / 范围 / Phase 骨架"]
    B --> C["D-G1 总监确认\nbrief.lock.json + prd.lock.json"]
    C --> D["/product-manager\nUNIT / AC / 审查 / 交付确认"]
    D --> E["M-G1 PM 裁决门\n锁漂移 / FAIL 清零"]
    E --> F["/design"]
    F --> G["/test-design"]
    G --> H["/tech-lead"]
    H --> I["/delivery-owner"]
```

## 角色分工

### `/product-director`

- 负责：根问题、目标与成功标准、范围、前置约束事实、Phase 规划、Director 基线冻结
- 不负责：UNIT 拆解、AC 细化、三方评审闭环、交付确认
- 典型问题：这件事到底在解决什么、做到什么算成功、为什么要拆成这些 Phase

### `/product-manager`

- 负责：详细业务流程、用户路径、UNIT、AC、完整性扫描、三方评审、交付确认
- 不负责：改写 Director 锁定字段
- 典型问题：每个 Phase 具体拆什么 UNIT、怎么验收、哪些问题要回退 Director

## 当前在哪一段

- 需求还停留在“想法 / 方案 / 大致目标”层：先去 `/product-director`
- 已经有 Director 确认和 lock snapshot：进入 `/product-manager`
- Manager 发现根问题、范围、规则、Phase 边界要变：回退 `/product-director`

## 共享判断框架

### 价值假设验证

在定义需求前先逼自己回答：
- 假设是什么
- 怎么验证
- 当前基线是什么
- 目标值或方向是什么
- 观测窗口是什么
- 数据来源是什么
- 失败长什么样

核心问句：
`如果这个功能上线，你怎么知道它成功了？`

### MVP 最小闭环三分法

- 核心：没有它，问题就没解决
- 增强：有它更好，但核心已经能独立交付价值
- 未来：明确延后，本期不做

核心问句：
`如果只能做一件事，是哪件？`

## 警示信号

出现以下想法时，必须暂停并重校当前步骤：
- 用户已经给了方案，我直接整理成需求
- 已经够清楚了，可以停止追问
- 这个 AC 用模糊词描述也没关系
- 我先按主题拆几个 UNIT，后面让下游自己再拆
- 先全部标 MVP，后面再说
- 这一步我自己判断就行，不用等用户

## Agent Team 评审编排

Manager 阶段的三方评审不是“有 reviewer 就算做了”，而是必须按下面的闭环执行：

### 三视角并行

- 产品视角：检查 `R1~R6 + R13 + PR-C1`
- 架构视角：检查技术可行性、隐含依赖、技术约束
- 测试视角：检查回归风险、AC 可测试性、异常与边界覆盖

### 复审纪律

- 首轮全 PASS，也必须再做一轮 `CONFIRMATION`
- 若存在 FAIL，只重提 FAIL 视角，不重跑已 PASS 视角
- 连续 2 轮 FAIL 数不减少：`ASK_USER`
- 同一问题连续 3 轮未关闭：`BLOCKED`
- WARN 必须显式承接，不能口头忽略

### 产品视角新增检查点

- `R13`：成功信号完整性
- `PR-C1`：共创可信度
- Director 锁定字段与 `brief.lock.json / prd.lock.json` 一致性

## 路由速查

| 情况 | 入口 |
|------|------|
| 先澄清问题、目标、范围、Phase | `/product-director` |
| 已有 handoff，继续细化 UNIT / AC / 审查 | `/product-manager` |
| 历史链接、旧入口、只想看总览 | `/product` |
