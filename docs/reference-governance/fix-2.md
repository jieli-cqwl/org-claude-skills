# fix-2.md

## 输入分析

- 输入来源清单：
  - `docs/reference-governance/phase-1/code-review-report.md`
  - 用户反馈：安装后的 `reference/` 目录外观仍保留 protocol 文件，产生理解成本噪音
  - `rg -n "reference/(phase-selection-protocol|review-fix-loop-protocol|review-iteration-protocol)\\.md|protocols/(phase-selection-protocol|review-fix-loop-protocol|review-iteration-protocol)\\.md" shared docs tests tools install.sh`
  - `bash tests/test-install-smoke.sh`
  - `bash tests/test-runtime-integrity.sh`
  - `bash tests/test-single-source-layout.sh`
  - `bash tests/test-skill-output-and-gate-contract.sh`
- work_dir 解析结果：`docs/reference-governance`
- 问题数量汇总：1

差异说明（N > 1 时 REQUIRED）:
- 已存在 `fix-1.md`，本轮为在用户实际观察到 runtime 目录后触发的追加修复。

## 诊断阶段

### 环境快照
- 当前分支：`main`
- 工作树状态：本轮聚焦 `install.sh`、`tools/migration/retire-dot-claude.sh`、`shared/protocols`、若干 skill 引用路径与测试门禁。
- 最近 5 条提交：
  - `793cf38 refactor: align shared reference governance and authority layout`
  - `da55904 merge: bring phase1 shared authority cleanup into main`
  - `adce53f fix: align shared authority boundaries for phase1`
  - `1923980 release: v1.2.4`
  - `5ec1616 Merge branch 'solstice-xenoposeidon'`
- 最近改动文件：
  - `install.sh`
  - `tests/test-runtime-integrity.sh`
  - `tests/test-install-smoke.sh`
  - `tests/test-single-source-layout.sh`
  - `tests/test-skill-output-and-gate-contract.sh`
  - `shared/skills/product/SKILL.md`
  - `shared/skills/design/SKILL.md`
  - `shared/skills/test-design/SKILL.md`
  - `shared/skills/tech-lead/SKILL.md`
  - `shared/skills/project-manager/SKILL.md`
  - `shared/skills/review/SKILL.md`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | source 与 runtime 的协议目录语义不一致 | 安装后查看 `~/.codex/reference/` 或 `~/.claude/reference/` | source 真源已迁到 `shared/protocols/`，但 runtime 仍把 3 个协议文件放在 `reference/` 根目录，用户会感觉“结构并没有真正改掉”。 |

当前环境复现结论:
- 可复现：是
- 不可复现时环境差异证据：无

### 假设验证过程
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | runtime/source 目录不一致 | H1: 只是 IDE 缓存或截图误读，runtime 实际已经有独立 `protocols/` | 直接列目录：`find "$HOME/.codex/reference" -maxdepth 1 -type f` 与 `find "$HOME/.claude/reference" -maxdepth 1 -type f` | 排除；runtime `reference/` 里确实仍有 3 个 protocol 文件。 |
| 1 | runtime/source 目录不一致 | H2: 这是 install 脚本故意保留的兼容层，不是 bug | 静态追踪 `install.sh:507-508`、`install.sh:533-534` | 确认；安装链路把 `shared/protocols` 继续复制进 staging `reference/`，导致 source/runtime 语义分叉。 |
| 1 | runtime/source 目录不一致 | H3: 如果 runtime 也改成 `protocols/`，现有 skill 和门禁会大面积断裂 | 全仓搜索协议引用路径，并针对安装 / runtime / source 门禁跑 `bash tests/test-install-smoke.sh`、`bash tests/test-runtime-integrity.sh`、`bash tests/test-skill-output-and-gate-contract.sh` | 排除；只要同步把 skill 引用切到 `protocols/...`，并更新 install/runtime 完整性测试，行为可以稳定。 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | runtime/source 目录不一致 | `install.sh:507-508`、`install.sh:533-534` | 第一轮修复为保兼容，只把 source 拆到 `shared/protocols/`，却继续把协议文件落到 runtime `reference/`。结果是行为兼容了，但目录语义没收敛，用户在安装目录看到的仍是旧布局。 | 通过静态追踪安装链路与实际 runtime 目录确认：问题不在 source，而在 staging 输出布局。 |

## 处置阶段

### 决策
- 处置策略：取消“仅 runtime 兼容”的折中方案，让 source 和 runtime 都显式使用 `protocols/`。
- 优先级：
  1. 修改安装链路，runtime 输出独立 `protocols/`
  2. 把所有 workflow 协议引用从 `reference/...` 切到 `protocols/...`
  3. 用安装/运行时/技能契约门禁锁住新布局

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | runtime/source 目录不一致 | FIXABLE | 调整 install 输出目录、迁移脚本与引用路径，并补充回归测试。 |

### FAIL-1: runtime 目录语义残留旧布局

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | 第一轮修复只迁 source，不迁 runtime 输出布局，`install.sh` 继续把协议复制到 `reference/`。 |
| 2 | 修复是否完整？ | 已改为 runtime 输出 `protocols/` 目录，相关 skill / protocol / dispatch 文档也都切到 `protocols/...`。 |
| 3 | 是否引入新问题？ | 主要风险是旧 `reference/...` 协议引用残留；已用 `tests/test-single-source-layout.sh` 与 `tests/test-skill-output-and-gate-contract.sh` 双重门禁锁住。 |
| 4 | 是否需要补充测试覆盖？ | 已补充 `install smoke`、`runtime integrity`、`source layout`、`skill output` 四条路径上的断言。 |

RED:
- 修复前，`~/.codex/reference/phase-selection-protocol.md` 与 `~/.claude/reference/phase-selection-protocol.md` 仍存在。

GREEN:
- 修复后，安装输出改为 `~/.codex/protocols/*.md` 与 `~/.claude/protocols/*.md`，且 `reference/` 中不再保留这 3 个协议文件。
- 修复后，`bash tests/test-install-smoke.sh`、`bash tests/test-runtime-integrity.sh`、`bash tests/test-single-source-layout.sh`、`bash tests/test-skill-output-and-gate-contract.sh` 通过。

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|------|------|---------|---------|
| 1 | runtime/source 目录不一致 | install 输出继续把协议塞进 runtime `reference/` | `install.sh`、`tools/migration/retire-dot-claude.sh`、`tests/test-install-smoke.sh`、`tests/test-runtime-integrity.sh`、`tests/test-single-source-layout.sh`、`tests/test-skill-output-and-gate-contract.sh`、`shared/skills/*` 协议引用文件 | `bash tests/test-install-smoke.sh`、`bash tests/test-runtime-integrity.sh`、`bash tests/test-single-source-layout.sh`、`bash tests/test-skill-output-and-gate-contract.sh` |

### 全量测试结果
TEST_CMD: `bash tests/test-install-smoke.sh`
通过: 是 / 失败: 0 / 跳过: 0

TEST_CMD: `bash tests/test-runtime-integrity.sh`
通过: 是 / 失败: 0 / 跳过: 0

TEST_CMD: `bash tests/test-single-source-layout.sh`
通过: 是 / 失败: 0 / 跳过: 0

TEST_CMD: `bash tests/test-skill-output-and-gate-contract.sh`
通过: 是 / 失败: 0 / 跳过: 0

### 阻断清单（全部/部分非 FIXABLE 时必填）
- 无

### 交接项清单
- source 与 runtime 现在都显式暴露 `protocols/` 目录，不再依赖“source 分层、runtime 兼容”的折中设计。
- 历史文档中对旧 runtime `reference/...` 协议路径的描述可能仍存在，但当前 source/skill/install 真源已全部切到 `protocols/...`。
- 最新审查结论见 `docs/reference-governance/phase-1/code-review-report.md`。
