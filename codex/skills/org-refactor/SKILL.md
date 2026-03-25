---
name: refactor
description: 代码结构重构与复杂度治理。Use when 代码结构混乱、过度设计需简化、模块拆分整理、代码可读性改善。
argument-hint: "[重构目标]"
user-invocable: true
hooks:
  Stop:
    - hooks:
        - type: command
          command: bash $HOME/.claude/skills/refactor/scripts/completion_check.sh
          timeout: 15
---

# /refactor -- 让代码恰到好处

## HARD-GATE

1. NO refactoring without a diagnosis (problem type + evidence at file_path:line_number).
2. NO refactoring without existing tests passing before AND after changes.
3. NO direction chosen without applying the 3 principles (Simple / Fit / Evolve).
4. NO /refactor completion without plan.md written to docs/重构-{模块名}/.

## 角色

你是代码质量守护者。重构不是"简化"——过度设计要做减法，设计不足要做加法，设计不当要调整。你追求恰到好处，不多不少。

## 输入

- 前置条件：目标文件/模块在 git 仓库内（`git rev-parse --git-dir` 通过），非 git 仓库时终止
- 用户输入：重构目标（文件路径/模块名/问题描述）

## 流程

### 1. 诊断

识别问题类型并确定重构方向：

| 问题类型 | 特征 | 方向 |
|---------|------|------|
| 过度设计 | 单一实现的接口、只透传的中间层、"万一需要"的代码 | 减法 |
| 设计不足 | 职责混乱、重复代码多、难以扩展 | 加法 |
| 设计不当 | 边界划分不清、依赖方向错误 | 调整 |

量化指标：文件 >300 行 / 类 >10 方法或 >5 依赖 / 函数 >50 行或圈复杂度 >10

统领自检：对每个待重构结构问——「去掉这个抽象/分层/模式，业务需求是否仍能被满足？」能 -> Accidental Complexity，方向是减法。

### 2. 三原则校验（详见 `reference/设计原则.md`）

| 原则 | 检查 |
|------|------|
| 简单 | 只有一个实现的接口？删除。"万一需要"的代码？删除(YAGNI)。 |
| 合适 | 业务本身复杂？保持。有真实扩展需求？保留扩展点。 |
| 演化 | 重复 3 次再抽象。需要时再加分层，不预设。 |
| 裁决 | 原则冲突时按 L1-L4 裁决。自检：去掉这个，业务需求是否仍满足？（详见 `reference/设计原则.md`） |

### 3. 语言路由与大型重构

Java: God Class、接口泛滥、Spring 分层。Python: ABC 滥用、装饰器嵌套、过度 OOP。大型重构使用并行分析：Explore Agent 检测坏味道 → Agent 生成重构方案 → 汇总计划交给 /project-manager 执行。

## 输出

输出到 `docs/重构-[模块名]/plan.md`（模板详见 `references/templates/refactor-plan-template.md`），包含：
- 诊断结果（问题类型 + 量化指标 + file_path:line_number）
- 重构方向（减法/加法/调整）+ 三原则校验
- 具体步骤（每步可验证）
- 影响分析（调用方 + 测试覆盖）

## 完成校验

- [ ] 诊断完成，问题类型和方向明确
- [ ] 三原则校验通过
- [ ] 每个重构步骤附 file_path:line_number
- [ ] 影响分析含调用方引用计数
- [ ] 全量测试通过
