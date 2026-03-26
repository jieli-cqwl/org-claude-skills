# 2026-03-26 community-first 轻量流程采用建议

评审时间：2026-03-26  
评审对象：`org-claude-skills`  
证据基线：`git rev-parse --short HEAD = b68e90e`（当前工作区为 dirty）

## 评审范围

- 目标：判断 community-first 是否已经具备“日常小需求默认流程”的采用条件
- 非本次范围：
  - 大需求替代标准流程
  - 轻量链自动升级到标准链
  - 团队多机推广
  - 真实业务仓库的长期运行数据

## 核心结论

- 日常小需求默认流程：`GO`
- 大需求/高风险变更：`NO-GO`，继续走标准链
- 自动升级迁移：`NO-GO`，v1 不建议做
- 团队全面切换：`Conditional GO`，建议先试点，再推广

换句话说：

- `community-first` 已经足够作为默认“小需求入口”
- 但它不是标准流程替代品
- 最稳妥的落地方式仍然是“双轨制”

## 为什么现在可以 GO

### 1. 默认链已具备运行前提

当前仓库已经把最关键的运行前提补齐：

1. `openspec` CLI 已提升为安装硬前置  
2. `opsx:*` 适配正文由 upstream 模板生成，不再手工维护  
3. `brainstorming` 是唯一默认自动入口  
4. `using-superpowers` 已降为 manual-only  
5. 本地标准链与本地重叠 workflow skill 已完成降级策略

这意味着现在的默认链不是概念设计，而是具备可执行约束的运行面。

### 2. 仓库级全量回归已通过

执行：

```bash
bash tests/run-all.sh
```

结果：

- `All tests passed`
- 覆盖：
  - 安装/卸载
  - runtime integrity
  - Codex 可见性降级
  - 合同校验
  - single-source layout
  - community-first 相关适配一致性

### 3. 真实隔离环境已完成 OpenSpec 闭环验证

在隔离环境中安装真实 `openspec 1.2.0` 后，已实际完成：

1. `openspec init`
2. `openspec new change`
3. `openspec status --json`
4. `openspec instructions ... --json`
5. `openspec change validate`
6. `openspec archive --yes`

结果：

- change 能创建
- artifacts 能按 schema 被识别
- validate 可通过
- archive 可把 delta specs 合并回主 `openspec/specs/`

这说明当前方案不是“文件存在但链路不通”。

### 4. 真实小需求样本已跑通

本轮用一个典型日常需求样本做了端到端验证：

- 登录页
- 后端登录接口
- 本地存储登录态
- 刷新恢复
- 登出
- 动画首页

验证层级包括：

1. OpenSpec 工件闭环
2. 代码实现
3. 自动测试
4. 接口冒烟
5. Playwright 浏览器验收
6. 移动端视口验收
7. archive 归档

结论：这类“小而完整”的需求，community-first 可以稳定承载。

## 推荐采用方式

### 1. 流程定位

推荐把三条能力边界固定成下面这组：

- `OpenSpec`：管改什么
- `superpowers`：管怎么改
- 本地标准链：管大需求的强治理

不要再把 community-first 理解成：

- 轻量版标准流程裁剪
- 本地自创 orchestrator
- 只是一组新 description

更准确的定位是：

- 一个以 upstream 语义为主的默认小需求链

### 2. 默认入口

推荐长期固定为：

- 默认自动入口：`brainstorming`
- 元规则：`using-superpowers`，manual-only
- 规格命令：`opsx:propose / opsx:apply / opsx:verify / opsx:archive`

理由：

1. `brainstorming` 负责最关键的人机桥接
2. `using-superpowers` 更适合作为约束，不适合作为默认自动发现入口
3. `opsx:*` 负责规格落盘和 change 生命周期

### 3. 与标准链的关系

建议长期保留双轨制：

- 小需求：走 community-first
- 大需求：显式走 `/product -> /design -> /test-design -> /tech-lead -> /project-manager`

不要做的事：

- 不要让 community-first 替代标准链
- 不要让标准链继续作为默认自动入口
- 不要在 v1 做轻量链自动升级标准链

### 4. 落地原则

这几条建议固定为硬原则：

1. 上游正文优先
   - `superpowers` 和 `OpenSpec` 的正文不在本地重写
2. 本地只做薄适配
   - metadata
   - `openai.yaml`
   - 安装映射
   - 占位符渲染
3. adapter 必须可再生
   - `opsx:*` 不允许手写维护，必须由上游模板生成
4. 前置条件必须阻断
   - 缺少 `openspec` CLI 时不得“安装成功但运行失败”
5. 自动暴露面必须收窄
   - Codex 默认只自动暴露 `brainstorming`

## 适用边界

### 适合走 community-first 的需求

满足以下大部分特征时，建议默认走 community-first：

1. 单次能收口
2. 需求目标明确
3. 风险低到中
4. 不需要多阶段排期
5. 影响范围可在一次 change 内讲清
6. 不需要完整跨职能重审链

典型例子：

- 单页面功能
- 小型接口新增/改造
- 单一业务闭环
- 文档+实现一体的小需求

### 不适合走 community-first 的需求

出现以下任一特征，建议直接走标准链：

1. 多阶段交付
2. 核心数据模型或核心接口大改
3. 跨多个系统或多个团队协同
4. 安全/性能/兼容风险高
5. 用户场景复杂，需求很难在短对话里收口
6. 必须要正式测试设计、正式 phase 计划、正式验收分级

## 最佳实践清单

### 最应该坚持的 8 条

1. 默认只让 `brainstorming` 自动命中
2. `using-superpowers` 保持 manual-only，不抢入口
3. 标准链统一降级为 manual-only
4. `opsx:*` 永远从 upstream 模板生成
5. `openspec` CLI 永远作为安装硬前置
6. 轻量链完成定义必须包含 `archive`
7. 真实小需求要用样本回放持续校准
8. 不在 v1 引入自动升级、自动迁移、双向继承

### 最不建议做的 6 条

1. 本地重写一套“看起来像 superpowers”的 skill 正文
2. 手工维护 `opsx:*` 文本
3. 让 `using-superpowers` 和 `brainstorming` 一起自动暴露
4. 为了追求统一，把大需求也强塞进轻量链
5. 一开始就做轻量链到标准链的自动升级
6. 没跑真实样本就直接宣布团队推广

## 已确认的风险

### 1. 仍缺真实业务仓库长期数据

当前证据足以证明“可行”，但还不足以证明：

- 长期稳定性
- 误路由率
- 团队成员学习成本
- 与真实业务复杂度的适配率

### 2. 上游变更风险

因为当前方案依赖 upstream 语义，所以未来上游若调整：

- skill 正文
- template 结构
- CLI 输出格式

本地薄适配和生成脚本都需要复验。

### 3. route judgement 仍需实际校准

理论边界已经清楚，但“哪些真实需求会被误判成小需求”只能通过真实样本继续校准。

## 推荐 rollout

建议按 3 步走，不要一步切满。

### Phase 1：个人/小范围试点

- 1-3 个熟悉流程的人先用
- 每周回放 3-5 个真实小需求
- 记录：
  - 是否误判
  - 是否卡在 brainstorming
  - 是否卡在 `opsx:*`
  - 是否需要退回标准链

### Phase 2：团队受控推广

- 只开放给明确属于“小需求”的场景
- 标准链继续保留显式强入口
- 每两周复盘一次：
  - 成功率
  - 平均交付时间
  - 返工率
  - 升级到标准链的比例

### Phase 3：默认化

当下面 4 条同时满足，再考虑彻底默认化：

1. 真实样本通过率稳定
2. 误路由率可接受
3. 团队已形成共识
4. 上游同步和本地适配已有固定复验流程

## 最终建议

当前最合理的决策不是“继续证明它能不能跑”，而是：

1. 确认采用 community-first 作为日常小需求默认流程
2. 保留标准链作为大需求显式入口
3. 禁止 v1 引入自动升级
4. 用真实业务样本继续校准边界

## 结论

- 日常小需求默认流程采用建议：`GO`
- 大需求替代标准链：`NO-GO`
- 团队全面立即切换：`NO-GO`
- 小范围试点推广：`GO`

如果只用一句话总结：

`community-first 现在已经足够作为小需求默认入口，但最稳的落地方式仍然是双轨制试点，而不是一次性替换标准流程。`
