# fix-1.md

## 输入分析
- 输入来源清单：
  - 人工 review 结论：`validate_review_json.py` 的 symlink 越界、`capture_baseline.py` 的 apply 失败恢复缺失、`completion_check.sh` 的全 transcript 误判、关键路径测试覆盖缺失。
  - 复现命令：`bash tests/test-review-fix-loop-skill.sh`、临时 repo/JSONL 复现、completion hook 临时 transcript 复现。
- work_dir 解析结果：`docs/review-fix-loop/2026-04-02-new-skill`
- 问题数量汇总：4

## 诊断阶段

### 环境快照
- 当前分支：`thorn-brick`
- 工作树状态：存在本轮 `review-fix-loop` 未提交改动，且仓内还有与本轮无关的既有未提交文件（`install.sh`、若干 `tests/*.sh`）。
- 最近 5 条提交：
  - `2ffc676 feat: vendor official Anthropic skills into community runtime`
  - `ea435d2 refactor: adopt explicit completion gate for pipeline skills`
  - `aa3e05f docs: extend research skill with discovery mode`
  - `d2e6f56 docs: normalize product gate bullet formatting`
  - `c9676e5 docs: unify step formatting and nested indentation for skill flows`
- 最近改动文件：
  - `claude/skills/review-fix-loop/scripts/capture_baseline.py`
  - `claude/skills/review-fix-loop/scripts/validate_review_json.py`
  - `claude/skills/review-fix-loop/scripts/completion_check.sh`
  - `tests/test-review-fix-loop-skill.sh`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | repo 边界逃逸 | 在临时 repo 内创建指向仓库外文件的 symlink，并让 review finding 指向该 symlink | `validate_review_json.py` 返回 0，把 finding 当作合法 repo 内文件 |
| 2 | baseline 恢复缺口 | monkeypatch `capture_baseline.py`，让 `stash apply --index` 抛错 | 只执行到 `stash push` 和失败的 `stash apply --index`，没有任何恢复调用 |
| 3 | completion gate 不可靠 | 直接运行源码树中的 `completion_check.sh` | 原脚本从 `claude/hooks/lib/common.sh` 取依赖，源码树下直接报缺文件 |
| 4 | completion gate 误判 + 关键路径缺测试 | transcript 前文放一段模板，末尾不输出最终块；同时检查测试文件 | 原脚本对全 transcript 全局 `grep`，理论上会被前文模板放行；测试未覆盖 JSONL 正路径与 gate 行为 |

当前环境复现结论:
- 可复现/不可复现：可复现
- 不可复现时环境差异证据：无

### 假设验证过程
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | repo 边界逃逸 | 仅 `..`/绝对路径 被拦截，symlink 目标未校验真实路径 | 复现 symlink finding，观察脚本返回 0；静态检查 [validate_review_json.py](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/validate_review_json.py#L95) 和 [validate_review_json.py](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/validate_review_json.py#L204) | 确认 |
| 1 | repo 边界逃逸 | `repo_root / file` 后续还有别的边界保护 | 搜索 `validate_review_json.py` 全文件，未见 `resolve()` + `relative_to()` 或等价校验 | 排除 |
| 2 | baseline 恢复缺口 | `stash apply --index` 失败后已有自动恢复 | monkeypatch 记录调用序列，仅出现 `stash push` 与失败的 `stash apply --index` | 排除 |
| 2 | baseline 恢复缺口 | 失败分支至少显式告知恢复方式 | 检查旧实现异常路径，错误直接从 [capture_baseline.py](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/capture_baseline.py#L160) 抛出，没有恢复说明 | 确认 |
| 3 | completion gate 不可靠 | 仅 runtime 布局可用，源码树不在支持范围 | 运行源码树脚本直接失败；同时查 `tests/run-all.sh` 已直接执行源码树测试 helper，源码树必须自洽 | 排除 |
| 3 | completion gate 不可靠 | 路径问题来自 hook 公共库缺失，而不是脚本相对路径错误 | 仓内存在 [common.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/shared/hooks/lib/common.sh#L1)，旧路径指向 `claude/hooks/lib/common.sh` | 确认 |
| 4 | completion gate 误判 + 缺测试 | 旧 gate 已只看最后一段输出 | 检查旧实现 [completion_check.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/completion_check.sh#L17) 到 [completion_check.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/completion_check.sh#L33)，全部是全局 `grep` | 排除 |
| 4 | completion gate 误判 + 缺测试 | 关键正路径已被现有 helper 覆盖 | 检查旧 [test-review-fix-loop-skill.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/tests/test-review-fix-loop-skill.sh#L189) 到 [test-review-fix-loop-skill.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/tests/test-review-fix-loop-skill.sh#L310)，没有 JSONL 正路径、没有 completion gate 执行测试 | 确认 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | repo 边界逃逸 | [validate_review_json.py](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/validate_review_json.py#L123) | 旧实现只做词法路径校验，随后直接访问 `repo_root / file`，导致 repo 内 symlink 指向仓库外真实文件时仍被接受 | `validate_finding()` 唯一文件定位路径为 `is_safe_repo_relative_path -> repo_root/file -> count_file_lines`，静态追踪见 [validate_review_json.py](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/validate_review_json.py#L174) |
| 2 | baseline 恢复缺口 | [capture_baseline.py](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/capture_baseline.py#L117) | 旧实现把 `stash apply --index` 作为单点恢复步骤，一旦抛错就直接失败返回，没有任何状态比对、索引恢复或显式恢复指令 | `create_baseline()` 的 dirty 分支唯一恢复调用是 `stash apply --index`，新增恢复链路位于 [capture_baseline.py](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/capture_baseline.py#L117) 到 [capture_baseline.py](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/capture_baseline.py#L178) |
| 3 | completion gate 不可靠 | [completion_check.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/completion_check.sh#L7) | 旧脚本把 runtime 相对路径硬编码成源码树也会命中的唯一路径，源码执行直接缺依赖 | 脚本启动链为 `source -> hook_init -> 解析 transcript`，旧版在 `source` 即失败；修复后多候选路径见 [completion_check.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/completion_check.sh#L7) |
| 4 | completion gate 误判 + 缺测试 | [completion_check.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/completion_check.sh#L34) 与 [test-review-fix-loop-skill.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/tests/test-review-fix-loop-skill.sh#L202) | 旧 gate 只做全局关键字命中，且 helper 未覆盖 JSONL 正路径 / gate 正反两类行为，回归时无法阻断这类漂移 | 入口静态追踪：`tests/run-all.sh -> tests/test-review-fix-loop-skill.sh -> capture/validate/completion_check`，引用见 [tests/run-all.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/tests/run-all.sh#L107) |

## 处置阶段

### 决策
- 处置策略：全部按 `FIXABLE` 处理。
- 优先级：
  1. 先补 RED 用例，锁定 repo 边界、恢复分支、completion gate 正反路径。
  2. 再做最小实现修复，避免额外扩张 skill 合同。
  3. 最后跑 helper + 全量回归，再做二轮复审。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | repo 边界逃逸 | FIXABLE | 用真实路径解析补仓库边界校验 |
| 2 | baseline 恢复缺口 | FIXABLE | 加入状态快照、index tree 恢复和显式错误提示 |
| 3 | completion gate 不可靠 | FIXABLE | 兼容源码树/运行时双路径 |
| 4 | completion gate 误判 + 缺测试 | FIXABLE | 解析最后输出块并补正反向回归 |

### FAIL-1: review JSON repo 边界

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | [validate_review_json.py:123](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/validate_review_json.py#L123) 新增 `resolve_repo_file()`，根因是旧实现没校验真实文件落点是否仍在 repo 内。 |
| 2 | 修复是否完整？ | 已覆盖 direct JSON、Codex JSONL 两条入口，因为二者都会收敛到 `validate_finding()`。 |
| 3 | 是否引入新问题？ | 只收紧边界，不改变合法 repo 内 finding 的排序和 summary 逻辑。 |
| 4 | 是否需要补充测试覆盖？ | 已补 symlink 越界 fail-close 与 JSONL 正路径用例。 |

RED: `tests/test-review-fix-loop-skill.sh` 中 symlink repo 用例在旧实现下返回 0。  
GREEN: symlink 用例现在 fail-close，JSONL 正路径正常通过。

### FAIL-2: baseline 恢复分支

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | [capture_baseline.py:117](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/capture_baseline.py#L117) 新增恢复函数与状态比对，根因是旧实现把 `stash apply --index` 当作无失败分支。 |
| 2 | 修复是否完整？ | 已覆盖 staged/unstaged/untracked 状态快照、`read-tree` 恢复 index、二次 `stash apply` 恢复工作树，以及显式手动恢复指令。 |
| 3 | 是否引入新问题？ | 恢复逻辑只在 `stash apply --index` 抛错时触发；happy path 仍是原单路径。 |
| 4 | 是否需要补充测试覆盖？ | 已补 monkeypatch 回归，强制验证恢复分支会走 `stash apply` 和 `read-tree`。 |

RED: 恢复分支测试在旧实现下只记录到 `stash push` 和失败的 `stash apply --index`。  
GREEN: 现在会记录恢复调用，并在错误消息中给出恢复指令。

### FAIL-3: completion gate 路径与解析

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | [completion_check.sh:7](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/completion_check.sh#L7) 旧路径硬编码只适合 runtime；[completion_check.sh:34](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/claude/skills/review-fix-loop/scripts/completion_check.sh#L34) 以后改成只解析最后一个最终块。 |
| 2 | 修复是否完整？ | 已同时覆盖源码树执行、runtime 拷贝执行、合法最终块通过、模板误判阻断。 |
| 3 | 是否引入新问题？ | 允许的附加行只保留 `错误原因/剩余问题/剩余 findings`，避免过宽匹配。 |
| 4 | 是否需要补充测试覆盖？ | 已补 source pass / source fail / runtime pass 三类 hook 行为。 |

RED: 源码树直接执行旧脚本报缺 `common.sh`；模板 transcript 理论上会被全局 `grep` 放行。  
GREEN: 三类 hook 用例全部通过。

### FAIL-4: 关键路径测试覆盖

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | [test-review-fix-loop-skill.sh:202](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/tests/test-review-fix-loop-skill.sh#L202) 到 [test-review-fix-loop-skill.sh:353](/Users/lijieli/.superset/worktrees/org-claude-skills/thorn-brick/tests/test-review-fix-loop-skill.sh#L353) 新增覆盖，根因是旧 helper 只测了基础 JSON 校验和 baseline happy path。 |
| 2 | 修复是否完整？ | 覆盖了 JSONL 正路径、symlink 越界、恢复分支、completion gate 正反路径与 runtime 布局。 |
| 3 | 是否引入新问题？ | 新测试只触达 `review-fix-loop` helper，不影响其他 skill。 |
| 4 | 是否需要补充测试覆盖？ | 当前关键路径已补齐；后续若扩展最终块字段，再同步补 gate 测试即可。 |

RED: 新增用例在旧实现下出现失败。  
GREEN: `bash tests/test-review-fix-loop-skill.sh` 通过。

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | repo 边界逃逸 | 真实路径未做 repo 边界校验 | `claude/skills/review-fix-loop/scripts/validate_review_json.py` | `bash tests/test-review-fix-loop-skill.sh` |
| 2 | baseline 恢复缺口 | apply 失败无恢复链路 | `claude/skills/review-fix-loop/scripts/capture_baseline.py` | `bash tests/test-review-fix-loop-skill.sh` |
| 3 | completion gate 不可靠 | 源码树路径硬编码 + 全 transcript 误判 | `claude/skills/review-fix-loop/scripts/completion_check.sh` | `bash tests/test-review-fix-loop-skill.sh` |
| 4 | 关键路径覆盖缺失 | helper 测试面不足 | `tests/test-review-fix-loop-skill.sh` | `bash tests/test-review-fix-loop-skill.sh`, `bash tests/run-all.sh` |

### 全量测试结果
TEST_CMD: `bash tests/run-all.sh`
通过: 25 / 失败: 0 / 跳过: 0

### 阻断清单（全部/部分非 FIXABLE 时必填）
- 无

### 交接项清单
- 根因分析结论与定位文件:行号已记录在上表。
- 修复范围限制在 `review-fix-loop` helper 与对应测试。
- 最新全量回归通过，可继续进入复审结论落盘。
