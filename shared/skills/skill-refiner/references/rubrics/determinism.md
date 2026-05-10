# Determinism 诊断口径

**目标**：可枚举、可复验的检查由工程机制执行，LLM 专注理解、判断和取舍。

## 裁决标准

1. 判断可分类：区分专业判断和确定性检查。
2. 入口明确：脚本、schema、hook、gate 或测试命令可执行。
3. 时机明确：知道由主流程、hook、CI、eval 或人工复验触发。
4. 参数明确：命令需要的路径、payload 或 fixture 可定位；缺参数时阻断，不猜测。
5. 失败可行动：失败结果能指向修复、阻断、回退或上游裁决。
6. 证据新鲜：完成证明来自当前输出或可复验命令，不用历史结论替代。
7. **真实输入验证过**：自写脚本/inline bash 必须至少在 1 个真实项目（非空 fixture，含典型忽略目录如 `.git`/`__pycache__`/`node_modules`）上跑过，诊断台账附退出码 + 首屏输出或错误前 3 行。静态打磨未跑过的自写脚本一律按 ISSUE 登记。

## 问题信号

- "执行前确认 X 存在"但没有命令。
- 命令包含参数但 Skill 没给出参数来源。
- 只有命令字符串，没有当前输出或复验结果。
- hook 何时触发、payload 从哪来、失败如何处理不清楚。
- LLM 自审替代 schema、lint、测试或引用扫描。
- **shell 脚本使用 `eval` + 通配模式（如 `eval find ... $EXCLUDES` 里包含 `*/xxx/*`），路径模式未加单引号保护——目标项目根含 `__pycache__`/`.git` 等实际目录时会被 shell globbing 误展开。**
- **脚本 `grep -c PATTERN 2>/dev/null || echo 0` 形式 fallback：grep 无匹配时输出 `0` + `echo 0` 会造成多行值，破坏后续 `$((...))` 算术；应改 `awk '/PATTERN/ {c++} END{print c+0}'`。**
- **脚本声明 `set -euo pipefail` 但依赖可能空的变量；需在关键变量处显式提供默认值。**

## 真实输入验证要求

凡满足以下任一条的 Skill，Determinism 维度默认 ISSUE，直至补齐真实运行证据：

1. 有自写 `scripts/*.sh` 或 `scripts/*.py` 被主流程调用
2. `SKILL.md` 含 inline bash（`` !` ` `` 形式）且命令非平凡（超出 `echo`/`ls`/单条 `grep`）
3. 依赖项目根目录特定结构（忽略目录、特征文件）

验证方式：

- 选 ≥ 1 个真实项目（含 `.git`、至少一个忽略目录、符合特征文件要求）
- 逐个跑脚本 / inline bash
- 记录：退出码、stdout 首屏、stderr 前 3 行（如有）
- 台账 `verification_commands` 节点登记命令 + status=pass + evidence 摘录
- 任一 FAIL 必须修到 PASS 才能收口
