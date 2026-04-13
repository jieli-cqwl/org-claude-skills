# fix-2.md

## 输入分析
- 输入来源清单：
  - 用户追加要求：复核 3 个 review finding，确认成立则系统性修复并重新 review。
  - 上轮报告：`docs/hotfix-20260413-1147/fix-1.md`
  - 复核对象：
    - `/Users/lijieli/.codex/skills/*/SKILL.md`
    - `shared/skills/new-skills/references/resource-planning.md`
    - `shared/hooks/managed/codex_stop_dispatch.py`
- work_dir 解析结果：`docs/hotfix-20260413-1147`
- 问题数量汇总：3

差异说明（N > 1 时 REQUIRED）:
- 上轮 `fix-1` 解决的是仓库真源里的 Codex 安装器注入文案，并顺手修复了 fresh proving 中暴露的两个既有门禁漂移。
- 本轮不再微调 `install.sh` 本体，而是继续沿调用链向外追：
  1. 修当前 `~/.codex` 运行面残留；
  2. 修会再次制造同类问题的 `new-skills` 真源参考；
  3. 修 stop dispatcher 的结构性信息泄漏边界。

## 诊断阶段

### 环境快照
- 当前分支: `main`
- 工作树状态:
  - `M CHANGELOG.md`
  - `M install.sh`
  - `M shared/hooks/managed/codex_stop_dispatch.py`
  - `M shared/skills/delivery-owner/scripts/completion_check.sh`
  - `M shared/skills/new-skills/references/resource-planning.md`
  - `M tests/test-codex-skill-adapter.sh`
  - `M tests/test-skill-output-and-gate-contract.sh`
  - `?? docs/hotfix-20260413-1147/`
- 最近 5 条提交:
  - `7a4f5dd refactor: 收敛复杂链路运行时去噪与交付门禁`
  - `57454db refactor: streamline subagent context contracts and design docs`
  - `87d1294 refactor: 收敛复杂链路上下文治理与交付门禁`
  - `4f58ed9 chore: sync runtime cleanup and delivery docs`
  - `db02599 refactor: rename project-manager to delivery-owner`
- 最近改动文件:
  - `shared/hooks/managed/codex_stop_dispatch.py`
  - `shared/skills/new-skills/references/resource-planning.md`
  - `tests/test-codex-skill-adapter.sh`
  - `tests/test-skill-output-and-gate-contract.sh`
  - `CHANGELOG.md`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | 当前 `~/.codex` 运行面仍保留旧直跑 gate 文案 | 扫描 `/Users/lijieli/.codex/skills/*/SKILL.md` 中是否还存在“若 hooks 不可用或需要 fresh proving command，请显式运行” | 命中 13 个已安装 skill，说明仓库已修但本机运行面仍可继续复现下游误导 |
| 2 | `new-skills` 真源参考仍传播错误心智模型 | 读取 `shared/skills/new-skills/references/resource-planning.md` | 第 26 行仍把 `completion_check.sh` 描述为“在 Stop hook 或显式执行时运行”，继续把 gate script 当普通 helper script 教给作者 |
| 3 | stop dispatcher 仍可能把内部细节暴露给用户 | 用 fake gate 脚本向 `codex_stop_dispatch.py` 注入只写 stderr 的初始化失败文本 | 用户可见 `stopReason/systemMessage` 原样包含 `hook payload`、`transcript_path=`、`session_id=` |

当前环境复现结论:
- 可复现/不可复现: 可复现
- 不可复现时环境差异证据: N/A

### 假设验证过程
每个问题至少 2 个已验证假设（结果为排除/确认/未决）。
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | 当前运行面残留旧文案 | H1：仓库真源里仍然存在旧注入模板，所以 reinstall 也会继续产出旧文案 | 检查 `install.sh:793-852`，确认真源模板已改成“依赖 hook payload / 不可裸跑”的新文案 | 排除 |
| 1 | 当前运行面残留旧文案 | H2：问题只存在于已安装 `~/.codex` 运行面，重新安装即可收口 | 扫描 `/Users/lijieli/.codex/skills/*/SKILL.md` 命中 13 个旧文案副本；执行 `bash install.sh --target codex --force --check quick` 后再扫，命中数归零 | 确认 |
| 2 | new-skills 真源误导 | H1：这只是历史文档，不在 active runtime source 中 | `shared/skills/new-skills/SKILL.md` 直接引用 `references/resource-planning.md`，说明它仍是 active workflow 真源 | 排除 |
| 2 | new-skills 真源误导 | H2：`resource-planning.md:26` 继续把 gate script 当 helper/可显式执行对象，会重新制造同类误导 | 检查原文并新增 RED 断言 `tests/test-skill-output-and-gate-contract.sh:1698-1700`，初次运行失败 | 确认 |
| 3 | stop dispatcher 泄漏内部细节 | H1：只有非结构化 stderr 会泄漏，结构化 JSON reason 已经安全 | 在现有 product gate 场景下检查 stop 输出，仍能看到 `transcript_path=` / `session_id=`，说明结构化 reason 也需要统一脱敏 | 排除“仅 raw stderr 泄漏”这个较窄假设 |
| 3 | stop dispatcher 泄漏内部细节 | H2：`extract_failure_reason()` 对结构化 reason 和 stderr/stdout 都缺少用户面脱敏层 | 检查 `shared/hooks/managed/codex_stop_dispatch.py:41-69`，确认此前直接返回 raw reason/text；新增 fake gate RED 用例后复现原样透传 | 确认 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | 当前 `~/.codex` 运行面残留旧文案 | `/Users/lijieli/.codex/skills/review/SKILL.md:10-12` 等 13 份已安装副本 | `fix-1` 已修仓库真源，但本机运行面尚未重新执行 `install.sh --target codex`，导致旧安装产物继续对下游可见 | 静态链路：`install.sh:924-926 -> render_runtime_contract -> rewrite_codex_skill_docs`；运行态对照：重装前后 `legacy_count 13 -> 0` |
| 2 | new-skills 真源误导 | `shared/skills/new-skills/references/resource-planning.md:26` | `/new-skills` 会引用该参考文档指导作者规划 `scripts/`；旧文案把 gate script 和 helper script 混在一起，后续极易再次生成“显式执行 completion_check.sh”的错误说明 | 静态引用：`shared/skills/new-skills/SKILL.md:46 -> references/resource-planning.md` |
| 3 | stop dispatcher 泄漏内部细节 | `shared/hooks/managed/codex_stop_dispatch.py:41-69` | `extract_failure_reason()` 以前拿到结构化 `reason` 或 raw stderr/stdout 后直接返回，`emit_stop_failure()` 再原样写进 `stopReason/systemMessage`，导致内部 runtime 协议细节直接上屏 | 静态调用链：`extract_failure_reason() -> emit_stop_failure()`；回归用例：`tests/test-codex-skill-adapter.sh:93-151` |

## 处置阶段

### 决策
- Issue 1 归为运行面 stale state，执行环境收口：重装当前 `~/.codex`。
- Issue 2 和 Issue 3 归为代码/文档真源缺陷：先写 RED 用例，再做最小修复。
- 修复目标不是隐藏所有失败，而是“保留用户可理解的失败摘要，去掉 hook payload / session_id / transcript_path / 内部路径等实现细节”。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | 当前 `~/.codex` 运行面残留旧文案 | ENV_ISSUE | 重装 Codex runtime 并验证残留计数归零 |
| 2 | new-skills 真源误导 | FIXABLE | 修改参考文案并加回归断言 |
| 3 | stop dispatcher 泄漏内部细节 | FIXABLE | 为失败原因加统一脱敏层，并补结构化/非结构化双场景回归 |

### FAIL-1: 当前 `~/.codex` 运行面残留旧文案

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | 仓库真源已修，但本机运行面未重新安装，旧渲染产物仍停留在 `/Users/lijieli/.codex/skills/*/SKILL.md` |
| 2 | 修复是否完整？ | 已执行 `bash install.sh --target codex --force --check quick`，并重新扫描确认旧文案命中数从 13 降到 0 |
| 3 | 是否引入新问题？ | 安装器自带 quick check；本轮只重装 Codex 运行面，不改用户代码仓库结构 |
| 4 | 是否需要补充测试覆盖？ | 仓库侧已有 `tests/test-codex-skill-adapter.sh` 约束安装输出；本轮额外做了运行面实机验证 |

RED: 运行前扫描 `~/.codex/skills/*/SKILL.md`，旧文案命中 13 个 skill
GREEN: 重装后再次扫描，`legacy_count = 0`

### FAIL-2: new-skills 真源误导

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `resource-planning.md:26` 把 gate script 说成“Stop hook 或显式执行时运行”，错误混淆了 helper script 与 gate script |
| 2 | 修复是否完整？ | 已改为“gate 只能由 runtime hook 或带 payload 的内部排查调用；不能当作 fresh proving/helper script 暴露给用户”，并在合同测试中锁住 |
| 3 | 是否引入新问题？ | 保留了 helper script 可以用 `script --help` 的指导，只把 gate script 从该建议中剥离 |
| 4 | 是否需要补充测试覆盖？ | 已补：`tests/test-skill-output-and-gate-contract.sh:1698-1700` |

RED: `bash tests/test-skill-output-and-gate-contract.sh` -> `missing pattern ... resource-planning.md`
GREEN: 同命令通过

### FAIL-3: stop dispatcher 泄漏内部细节

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `extract_failure_reason()` 对结构化/非结构化失败都缺少统一脱敏层，`emit_stop_failure()` 直接把内部细节写进用户可见字段 |
| 2 | 修复是否完整？ | 已新增 `sanitize_failure_reason()`，统一处理 `hook payload`、`stdin`、`tool_input.file_path`、`transcript_path=`、`session_id=` 和内部路径，再限制输出为用户可读摘要 |
| 3 | 是否引入新问题？ | 仍保留失败上下文摘要，例如“产品文档完整性检查未通过”或“Completion hook 初始化失败”；没有把错误完全压成黑盒 |
| 4 | 是否需要补充测试覆盖？ | 已补：`tests/test-codex-skill-adapter.sh` 同时覆盖结构化 reason 和 raw stderr fake gate 两个场景 |

RED: `bash tests/test-codex-skill-adapter.sh` -> `raw gate failure should be sanitized before reaching user-visible output`
GREEN: 同命令通过

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | 当前运行面残留旧文案 | 运行面 stale state，未重装 Codex runtime | `~/.codex/skills/*/SKILL.md`（通过安装器重渲染） | 运行面扫描 + `bash install.sh --target codex --force --check quick` |
| 2 | new-skills 真源误导 | 参考文档错误传播 gate/helper 混淆 | `shared/skills/new-skills/references/resource-planning.md`、`tests/test-skill-output-and-gate-contract.sh` | `bash tests/test-skill-output-and-gate-contract.sh` |
| 3 | stop dispatcher 泄漏内部细节 | 无脱敏层，原样透传结构化/非结构化失败文本 | `shared/hooks/managed/codex_stop_dispatch.py`、`tests/test-codex-skill-adapter.sh` | `bash tests/test-codex-skill-adapter.sh` |

### 全量测试结果
TEST_CMD: `bash tests/run-all.sh`
通过: 36 / 失败: 0 / 跳过: 0

补充说明：
- `skill context budget test` 仍输出 3 条 WARN（`design/product/tech-lead` 超过 800 行 budget），但脚本最终结论为 `All tests passed`，未形成失败门禁。

### 阻断清单（全部/部分非 FIXABLE 时必填）
| # | 问题 | 阻断原因 | 下一步动作 | 责任归属 |
|---|------|---------|-----------|---------|
| 1 | 当前 `~/.codex` 运行面残留旧文案 | 非代码 defect，而是运行面未重装 | 已执行 `bash install.sh --target codex --force --check quick` 并复核 | 当前修复轮处理完成 |

### 交接项清单
- 本轮新增真源修复：`resource-planning.md`、`codex_stop_dispatch.py`
- 本轮新增回归：`tests/test-codex-skill-adapter.sh`、`tests/test-skill-output-and-gate-contract.sh`
- 运行面收口：当前 `~/.codex` 已重装，旧直跑 gate 文案命中数已清零
- 修后复审：当前 active source 与当前 `~/.codex` 运行面未再发现同类 active finding；残留命中仅存在于测试断言和 `install.sh` 的旧字符串替换源文本
