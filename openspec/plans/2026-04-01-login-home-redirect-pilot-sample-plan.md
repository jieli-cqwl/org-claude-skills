# Login Success Redirect Home Pilot Sample Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking and MUST include task-id tags like `[T1]`.

**Goal:** 为 `community-first` 试点补一条“登录成功后跳转首页”的完整模拟样本工件，验证该类需求能否被轻量链正确收口。

**Architecture:** 本计划不修改真实业务代码，而是在当前仓库中产出一套模拟样本工件：设计稿、单样本记录、样本结论。样本边界收口为“登录成功 -> 写入登录态 -> 跳转首页”的最小闭环，不扩展到注册、回跳策略或首页初始化。

**Tech Stack:** Markdown docs, existing `docs/community-first/*`, `openspec/designs/*`, repo validation scripts

---

### Task 1: 固化样本边界与设计

**Files:**
- Create: `openspec/designs/2026-04-01-login-home-redirect-pilot-sample-draft.md`

- [ ] [T1] **Step 1: 写入样本背景与目标**

Action:
- 明确这是试点模拟样本，不是当前仓库真实业务实现
- 写清样本需求、目标、非目标

Expected:
- 设计稿能说明“为什么要用这条需求做首样本”

- [ ] [T1] **Step 2: 写入方案选择与边界判断**

Action:
- 比较“最小跳首页 / 回跳参数 / 首页初始化”三种方案
- 选择最小闭环方案

Expected:
- 设计稿能回答“为什么这条需求仍属于小需求”

- [ ] [T1] **Step 3: 写入最小数据流和测试关注点**

Action:
- 补齐登录成功路径的最小语义
- 列出真实业务仓库中的最小测试点

Expected:
- 后续单样本记录可直接引用该设计稿

### Task 2: 沉淀单样本记录

**Files:**
- Create: `docs/community-first/pilot-records/2026-04-01_登录成功后跳转首页_单样本记录.md`

- [ ] [T2] **Step 1: 按模板补齐基本信息与前置检查**

Action:
- 引用当前仓库已通过的校验命令
- 标记本样本为“试点模拟样本”

Expected:
- 单样本记录可直接放入本周试点池

- [ ] [T2] **Step 2: 写清执行路径**

Action:
- 记录这条需求在轻量链中的预期走法：
  - `brainstorming`
  - `writing-plans`
  - 执行链可继续，但本轮停在模拟工件层

Expected:
- 样本记录能明确说明不需要退回标准链

- [ ] [T2] **Step 3: 写入问题与结论**

Action:
- 标注本轮未进入真实代码实现
- 标注 review / verification 为模拟样本结论

Expected:
- 记录能清楚区分“流程通过”与“真实业务已实现”

### Task 3: 产出样本结论

**Files:**
- Create: `docs/community-first/pilot-records/2026-04-01_登录成功后跳转首页_样本结论.md`

- [ ] [T3] **Step 1: 总结为什么通过**

Action:
- 总结该需求为什么适合 `community-first`
- 总结为什么不需要退回标准链

Expected:
- 样本结论能直接作为首周复盘输入

- [ ] [T3] **Step 2: 明确后续动作**

Action:
- 给出在真实业务仓库中继续推进时的下一步
- 指出哪些能力仍属于本期不交付

Expected:
- 后续执行人可据此挑选下一条真实样本

### Task 4: 回归验证

**Files:**
- Modify: `docs/community-first/试点执行入口.md`（如需引用新样本）

- [ ] [T4] **Step 1: 运行文档完整性检查**

Run:
```bash
bash tests/test-doc-reference-integrity.sh
```

Expected:
- PASS

- [ ] [T4] **Step 2: 运行仓库全量回归**

Run:
```bash
bash tests/run-all.sh
```

Expected:
- `All tests passed`
