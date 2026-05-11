# 字面量合约清理专项

## 背景

本仓库 `tests/` 下 55 个 `test-*.sh` 文件中，广泛存在对 skill markdown 文件（SKILL.md / references/*.md / projections/*.md 等）**具体措辞**的 `assert_present` / `assert_absent` 断言。

这类断言的**本质**：把 skill 文件的**表述形式**（章节标题、完整句式、特定术语）当作测试契约，任何字面改动都会让测试变红。

### 这种做法为什么错

1. **锁中间产物，不是锁目标**。skill 质量的最终定义是"LLM 读了能不能做对事"，这需要**行为 eval**，不是文本 grep。
2. **阻碍正确的演化**。当一份 skill 文件从"手册式"演化到"原则式"时（这本身是正向演化），文本必然变，但测试还锁着旧措辞 —— 测试从护栏退化为枷锁。活证据：`test-product-role-split-contract.sh` 在 `70e1d085` 提交后已红至今，没人修。
3. **脱裤子放屁**。测试断言实际在复制粘贴文件原文，信号价值几乎为零。
4. **业界最佳实践不这么做**。Anthropic 官方 `anthropics/skills` 仓库**根目录无 tests/**；`obra/superpowers` 的 tests 全部是**行为 eval**（真调 claude CLI + naive prompt 看 LLM 触发行为），没有一行字面量断言。本仓库 17 个 skill 每个都有 `evals/evals.json`，基建已经就位，字面量合约纯属历史债。

## 盘点结论（阶段 0）

扫描 `tests/test-*.sh` 所有 `assert_present` / `assert_absent` 断言：

| 类型 | 数量 | 占比 | 处置 |
|---|---:|---:|---|
| 🔴 **TEXT_MD**（锁 skill md 文本） | **1030** | 56% | 该删 |
| 🔴 **TEXT_PROJ**（锁 projections 模板文本） | **30** | 2% | 该删 |
| 🟡 **ANTI_PATTERN**（反模式黑名单） | **7** | 0.4% | eval 覆盖后删 |
| 🟢 **JSON_SCHEMA**（锁 json/yaml 字段） | 131 | 7% | 必留 |
| 🟢 **RUNTIME_OUTPUT**（锁命令 stdout/stderr） | 103 | 6% | 必留 |
| 🟢 **CROSS_REF**（锁跨 skill 引用） | 50 | 3% | 必留 |
| 🟢 **SHELL_SCRIPT**（锁脚本内容） | 47 | 3% | 必留 |
| 🟢 **LEGACY_GUARD**（锁遗留路径不复活） | 6 | 0.3% | 必留 |
| ⚪ **OTHER** / NO_MATCH | 424 | 23% | 人工细分，估半数为该删 |
| **总计** | **1828** | 100% | |

**核心数据**：明确该删 ≥ 1067 条，占总量 58%。加上 OTHER 里漏网的 TEXT 类（估 150-200 条），最终清理规模约 1200+ 条。

### 重灾区（按该删数降序，前 5）

| 文件 | 该删条数 |
|---|---:|
| `tests/test-design-skill-governance-redesign.sh` | 250 |
| `tests/test-product-role-split-contract.sh` | 68 |
| `tests/test-standard-chain-cutover.sh` | 65 |
| `tests/test-skill-refiner-agent-loop.sh` | 64 |
| `tests/test-product-stability-guidance-contract.sh` | 62 |

前 5 占总量的 **48%**。

### Eval 覆盖度校验

本仓库 17 个 skill 全部有 `evals/evals.json`，总 eval case 数约 **100+**：

- `product-manager`: 14 cases
- `delivery-owner`: 18 cases
- `product-director`: 8 cases
- `developer`: 7 cases
- 其他 skill 平均 3-5 cases

抽样对比"字面量合约锁的核心意图"vs"eval case 覆盖"：

| 字面量合约锁的意图 | eval 覆盖 |
|---|---|
| PM 不能改 Director 锁定字段 | ✅ `director-lock-drift-blocking` |
| PM 必须先做 M-S0 准入 | ✅ `handoff-validation-first` |
| PM 不能基于 legacy md 拆 UNIT | ✅ `canonical-review-required` |
| Director baseline 不能含完整 PRD | ✅ `director-baseline-no-prd` |
| Phase 不能超 14 天 timebox | ✅ `phase-timebox-enforced` |
| PM 不能把方法判断拆选项给用户 | ⚠️ 间接覆盖，建议补 1-2 个 case |

**核心意图几乎全部被 eval 覆盖**。字面量合约是冗余护栏。

## 清理阶段规划

### 阶段 1：删最明确的"锁章节名/锁整句"类（1 次 PR）

**范围**：TEXT_MD + TEXT_PROJ 桶中**锁章节标题**（`'^## XXX$'`）和**锁完整句式**（>30 字的字面断言）的条目。

**不动**：
- ANTI_PATTERN 桶（继续留作兜底，等阶段 2）
- JSON_SCHEMA / RUNTIME_OUTPUT / CROSS_REF / SHELL_SCRIPT / LEGACY_GUARD 全部
- OTHER 桶里所有条目（阶段 2 再细分）

**预期**：一次 PR 删 600-800 条，仓库体感立即好转。

**验证**：跑 `tests/run-all.sh`，所有其他非 TEXT 类测试应保持绿。

**审阅策略**：按文件分组成多个 commit，每个 commit 对应一个测试文件，便于 review。

### 阶段 2：补 eval → 删反模式黑名单 + 清 OTHER 里的 TEXT 漏网（多次 PR）

**步骤**：
1. 对每个 ANTI_PATTERN 断言，核查对应 skill `evals/evals.json` 是否已有 case 覆盖同一意图。
2. 未覆盖的，**先补 eval case**（提交 1 个 PR）。
3. eval 绿后，**再删字面量反模式黑名单**（提交另 1 个 PR）。
4. 同步把 OTHER 桶里 `assert_absent '某语义短语' "$md_file"` 这类漏网的 TEXT 类也处理掉（同样补 eval → 删）。

**预期**：补约 10-15 个 eval case，删约 200-250 条字面量。

### 阶段 3：文档化新规则（1 次 PR）

在 `CLAUDE.md` 或 `shared/rules/` 下新增一条：

> **skill 质量守护规则**
>
> `shared/skills/**/*.md` 文件的质量由 `shared/skills/*/evals/evals.json` 中的行为 eval 守护，**不得**在 `tests/*.sh` 中通过 `assert_present` / `assert_absent` 对 skill/reference/projection 文件的正文措辞做字面量断言。
>
> 允许在 `tests/*.sh` 中断言的对象：
> - JSON/YAML schema 字段（结构合约）
> - 命令运行的 stdout/stderr（行为合约）
> - 跨 skill 引用关系（依赖合约）
> - 遗留路径不复活（去遗留合约）
> - shell/python 脚本内容（实现合约）

同时在 `CONTRIBUTING.md` / 新增 skill 流程中强调"改 skill 文件前跑 eval，不是跑 grep"。

## 风险与不做项

- **不会误伤 schema 合约**：JSON_SCHEMA / CROSS_REF / LEGACY_GUARD 全部保留
- **不会丢失行为守护**：交叉校验 eval 已覆盖核心意图
- **本专项不改 skill md 文件本身**：只动 tests/
- **本专项不改 eval 运行基建**：eval 基建已就位，只补 case

## 执行工具

阶段 0 分类脚本：`/tmp/classify_v2.py`（保留供阶段 1 生成删除清单）

## 进度

- [x] 阶段 0：分类盘点完成
- [x] 阶段 0：eval 覆盖度交叉校验完成
- [x] 阶段 0：专项计划文档（本文档）
- [ ] 阶段 1：删明确字面量合约
- [ ] 阶段 2：补 eval + 删反模式黑名单
- [ ] 阶段 3：文档化新规则
