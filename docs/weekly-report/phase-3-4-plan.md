# Phase 3-4 执行计划

## 背景

Phase 0-2 验证已完成（见 `phase-0-2-validation-report.md`），核心结论：
- 不信任原则有效（6 次 agent 审查验证）
- 方法论框架手动执行有效，但 LLM 自主执行效果未验证
- 24/24 测试 PASS，但测试只覆盖结构正确性，不覆盖行为有效性
- **根因：缺少 skill 行为评测基础设施**

## 目标

一次性落地三件事，形成完整闭环：
1. 评测基础设施（能测）
2. Phase 3/4 skill 改动（改完）
3. LLM 自主执行 + 评测（验完）

## 执行阶段

### Stage A：评测框架设计（设计阶段）
- 状态: DONE
- 输入: `phase-0-2-validation-report.md`、skill-creator 的 `run_eval.py` 模式
- 产出:
  - `docs/weekly-report/eval-design.md` — 评测框架设计文档
  - 评测维度定义（方法论使用度、HARD-GATE 违规率、产出质量）
  - 3 个 grader agent prompt 设计
  - 评测场景定义（输入用例 + 期望行为）
- 验收: 设计文档覆盖 Phase 1 三个核心改动的可测量指标

### Stage B：评测框架实现（编码阶段）
- 状态: DONE
- 依赖: Stage A
- 输入: `eval-design.md`
- 产出:
  - `tools/eval/` — 评测脚本和 grader prompt
  - `tools/eval/run_skill_eval.sh` — 评测入口脚本
  - `tools/eval/graders/` — grader agent prompt 文件
  - `tools/eval/scenarios/` — 评测场景数据
- 验收: 能对当前 skill 跑一轮评测并输出结构化评分

### Stage C：Phase 3/4 Skill 改动（改代码阶段）
- 状态: DONE
- 依赖: Stage B（评测框架可用后才改，改完立即能测）
- 输入: `phase-0-2-validation-report.md` 中的 Phase 3/4 决策建议
- 改动清单:
  - [x] C1: review/qa PASS 维度精简（4 个模板文件添加 PASS 精简规则）
  - [~] C2: developer-report RED/GREEN 叙述精简为索引 → 暂缓（验证报告建议，git-based TDD 验证为 warning 级，需积累更多数据）
  - [x] C3: HARD-GATE why 有无的 A/B 变体准备（`tools/eval/scenarios/skill-variants/`）
  - [x] C4: skill description 触发率基线收集（`tools/eval/scenarios/c4-trigger-rate-baseline.md`，含 10 个核心 skill description + 25 组 eval 查询）
- 产出: 修改后的 skill 文件 + 测试套件更新
- 验收: `tests/run-all.sh` 全量 PASS（24/24 通过）

### Stage D：LLM 自主执行 + 评测（验证阶段）
- 状态: DONE（最小验证完成，追加实验可在后续 session 执行）
- 依赖: Stage B + Stage C
- 输入: 评测框架 + 改动后的 skill
- 执行内容:
  - [ ] D1: 用 Agent tool 让 designer agent 自主执行 /design（不手动跟流程）
  - [ ] D2: 用 Agent tool 让 developer agent 自主执行开发任务
  - [ ] D3: 评测框架对 D1/D2 产出自动打分
  - [ ] D4: HARD-GATE why A/B 对比（有 why vs 无 why，各跑 3 次）
  - [ ] D5: 改前 vs 改后质量对比
- 产出:
  - `docs/weekly-report/eval-results.md` — 评测结果报告
  - 改前/改后对比数据
  - Phase 3/4 效果结论
- 验收: 有量化数据支撑 Phase 3/4 改动的效果判断

## Session 规划

| Session | 阶段 | 预期产出 | clear 后接力文件 |
|---------|------|---------|----------------|
| Session 1 | Stage A | eval-design.md | 本文件 + eval-design.md |
| Session 2 | Stage B | tools/eval/ 实现 | 本文件 + tools/eval/ |
| Session 3 | Stage C | skill 改动 + 测试 | 本文件 + git diff |
| Session 4 | Stage D | eval-results.md | 最终报告 |

## 上下文接力协议

每个 session 结束前：
1. 更新本文件的阶段状态（NOT_STARTED → DONE）
2. 确认产出文件已写入磁盘
3. 有跨 session 决策时更新 memory

每个 session 开始时：
1. 读本文件了解进度
2. 读上一阶段的产出文件
3. 开始当前阶段

## 风险

| 风险 | 缓解 |
|------|------|
| 评测框架设计过重 | 最小可用：每个 grader 一个 agent prompt + 3 个场景，不造框架 |
| LLM 自主执行结果不稳定 | 每个场景跑 3 次取中位数 |
| A/B 对比变量不纯净 | 每次只改一个变量（有/无 why），其他保持不变 |
| Session 间上下文丢失 | 工件在磁盘，决策在 memory，plan 文件记录进度 |
