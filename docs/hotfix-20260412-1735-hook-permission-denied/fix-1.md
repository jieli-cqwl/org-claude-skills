# fix-1

## 输入分析

- 输入来源清单：
  - 用户截图中的报错：`PreToolUse:Bash hook error`
  - 报错细节：`/Users/lijieli/.claude/hooks/block_dangerous.sh: line 7: /Users/lijieli/.claude/hooks/managed/block_dangerous.sh: Permission denied`
  - 受控复现实验：
    - `printf '{}' | bash /Users/lijieli/.claude/hooks/block_dangerous.sh`
    - `printf '{}' | bash /Users/lijieli/.claude/hooks/managed/block_dangerous.sh`
    - `printf '{}' | bash -x /Users/lijieli/.claude/hooks/block_dangerous.sh`
- `work_dir` 解析结果：`docs/hotfix-20260412-1735-hook-permission-denied`
- 问题数量汇总：1

## 诊断阶段

### 环境快照

- 当前分支：`main`
- 工作树状态：
  - 已有未提交改动：`community/superpowers/skills/brainstorming/SKILL.md`
  - 已有未提交改动：`community/superpowers/skills/finishing-a-development-branch/SKILL.md`
  - 已有未提交改动：`tests/test-closeout-routing.sh`
  - 已有未提交改动：`tests/test-skill-output-and-gate-contract.sh`
  - 已有未提交文档改动：`docs/delivery-owner-role-20260411/*`
  - 已有未提交文档改动：`docs/subagent-context-audit-20260411/*`
- 最近 5 条提交：
  - `4f58ed9 chore: sync runtime cleanup and delivery docs`
  - `db02599 refactor: rename project-manager to delivery-owner`
  - `7cf86a9 chore: commit pending repository updates`
  - `debdfd2 chore: sync workspace changes and eval assets`
  - `fa94c88 feat: rebuild project-manager delivery owner gates`
- 最近改动文件：
  - `community/superpowers/skills/brainstorming/SKILL.md`
  - `community/superpowers/skills/finishing-a-development-branch/SKILL.md`
  - `docs/delivery-owner-role-20260411/capability-model-rationale.md`
  - `docs/subagent-context-audit-20260411/master-plan.md`
  - `tests/test-closeout-routing.sh`
  - `tests/test-skill-output-and-gate-contract.sh`

### 现象与复现

| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | Claude `PreToolUse` 的 `block_dangerous` hook 报 `Permission denied` | 1. 保持当前 `~/.claude/hooks` 安装态；2. 执行 `printf '{}' | bash /Users/lijieli/.claude/hooks/block_dangerous.sh` | 返回码 `1`，stderr 为 `/Users/lijieli/.claude/hooks/block_dangerous.sh: line 7: /Users/lijieli/.claude/hooks/managed/block_dangerous.sh: Permission denied` |

当前环境复现结论：
- 可复现：是
- 复现证据：
  - `printf '{}' | bash /Users/lijieli/.claude/hooks/block_dangerous.sh` -> `rc=1`
  - `printf '{}' | bash -x /Users/lijieli/.claude/hooks/block_dangerous.sh` -> trace 落到 `exec /Users/lijieli/.claude/hooks/managed/block_dangerous.sh`
  - `printf '{}' | bash /Users/lijieli/.claude/hooks/managed/block_dangerous.sh` -> `rc=0`

### 假设验证过程

| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | Claude hook 权限报错 | H1：只是下游机器本地权限偶发损坏，仓库源文件本身正常 | 对比仓库源文件权限与已安装文件权限：`stat -f '%Sp %N' claude/hooks/block_dangerous.sh shared/hooks/managed/block_dangerous.sh`，以及 `git ls-files --stage claude/hooks/block_dangerous.sh shared/hooks/managed/block_dangerous.sh` | 排除。仓库源文件就是 `100644`，安装后仍是 `-rw-r--r--`，不是单纯下游环境漂移 |
| 1 | Claude hook 权限报错 | H2：Claude 注册命令本身写错了，直接把不可执行脚本当成可执行文件调用 | 读取 `shared/hooks/registry.json:158-163` 与 `install.sh:181-187`，确认 Claude 侧实际注册的是 `bash $HOME/.claude/hooks/block_dangerous.sh` | 排除。注册入口本身没错，wrapper 会由 `bash` 启动 |
| 1 | Claude hook 权限报错 | H3：wrapper 内部的二次转调方式有问题，直接 `exec` 了没有执行位的 managed 脚本 | 阅读 `claude/hooks/block_dangerous.sh:7`，并用 `bash -x` 追踪调用链；再对比 `bash /Users/lijieli/.claude/hooks/managed/block_dangerous.sh` 可正常返回 `0` | 确认。当前失败点正是 wrapper 的 `exec "$SCRIPT_DIR/managed/block_dangerous.sh"` |
| 1 | Claude hook 权限报错 | H4：安装链路或门禁本应拦住这个问题，但漏检了 | 读取 `install.sh:876-877`、`install.sh:1503`、`install.sh:1639-1640`、`tests/test-install-smoke.sh:37`、`tests/test-install-systematic.sh:133-139`、`tests/test-runtime-integrity.sh:360-364` | 确认。安装会原样复制文件 mode，quick check 和测试只校验“存在/已注册”，没有校验“可执行” |

### 根因结论

| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | Claude `block_dangerous` hook `Permission denied` | `claude/hooks/block_dangerous.sh:7` | Claude 运行时按 `shared/hooks/registry.json:158-163` 与 `install.sh:181-187` 注册为 `bash ~/.claude/hooks/block_dangerous.sh` -> wrapper 启动后在 `claude/hooks/block_dangerous.sh:7` 直接 `exec` `managed/block_dangerous.sh` -> 该 managed 脚本源文件在仓库中以 `100644` 跟踪，并由 `install.sh:876-877`、`install.sh:1503` 原样复制到 `~/.claude/hooks/managed/block_dangerous.sh` -> 运行时缺少执行位，触发 `Permission denied` | 静态调用链：`shared/hooks/registry.json:158-163` -> `install.sh:181-187` -> `claude/hooks/block_dangerous.sh:7`；静态安装链：`install.sh:876-877` -> `install.sh:1503`；权限证据：`git ls-files --stage` 显示 `claude/hooks/block_dangerous.sh` 与 `shared/hooks/managed/block_dangerous.sh` 均为 `100644` |

## 处置阶段

### 决策

- 处置策略选择：
  - 本轮按用户要求停在根因定位，不改实现
  - 下一步最小修复建议：
    - 给 `claude/hooks/block_dangerous.sh` 与 `shared/hooks/managed/block_dangerous.sh` 补执行位
    - 增加 quick check 与安装测试，对 hook 使用 `test -x` 或直接执行一次 smoke command
    - 可选增强：把 `claude/hooks/block_dangerous.sh:7` 改成显式 `bash` 调 managed 脚本，避免再次依赖执行位

失败分类：

| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | Claude `block_dangerous` hook `Permission denied` | `FIXABLE` | 进入 TDD 修复：先补失败测试，再修文件 mode/调用方式，再跑安装与 runtime 回归 |

### FAIL-1: Claude `block_dangerous` hook 权限错误

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `claude/hooks/block_dangerous.sh:7` 直接 `exec` 非可执行的 `managed/block_dangerous.sh`；而该 managed 脚本在仓库与安装产物里都是 `0644` |
| 2 | 修复是否完整？ | 还未执行修复。完整修复至少覆盖 3 个面：源文件权限、安装后 quick check、安装测试/运行 smoke |
| 3 | 是否引入新问题？ | 诊断阶段未改代码，不引入新问题；若后续只补执行位，风险低；若同时改调用方式，需要补一次 Claude runtime 回归 |
| 4 | 是否需要补充测试覆盖？ | 需要。当前测试只验证文件存在与 hook 注册，缺少“可执行/可实际运行”的门禁 |

RED：
- `printf '{}' | bash /Users/lijieli/.claude/hooks/block_dangerous.sh`
- 结果：`rc=1`
- stderr：`/Users/lijieli/.claude/hooks/block_dangerous.sh: line 7: /Users/lijieli/.claude/hooks/managed/block_dangerous.sh: Permission denied`

GREEN：
- 本轮未进入修复阶段，未执行 GREEN

## 产出

### 修复清单

| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|------|------|---------|---------|
| 1 | Claude `block_dangerous` hook 权限错误 | hook wrapper 与 managed 脚本的执行约定和文件 mode 不一致，且门禁漏检 | 本轮未修改 | 本轮未执行 |

### 全量测试结果

- 本轮未执行。原因：当前请求范围是根因定位，不是修复交付

### 阻断清单

| # | 问题 | 阻断原因 | 下一步动作 | 责任归属 |
|---|------|---------|-----------|---------|
| 1 | 还未消除下游报错 | 当前轮次按诊断止步，未进入 `RED -> GREEN` 修复流程 | 若继续，由仓库维护侧补执行位与门禁，再重跑安装测试和 hook smoke test | 仓库运行时/安装链路维护者 |

### 交接项清单

- 根因分析结论与定位文件:行号：
  - `/Users/lijieli/org-claude-skills/claude/hooks/block_dangerous.sh:7`
  - `/Users/lijieli/org-claude-skills/shared/hooks/registry.json:158-163`
  - `/Users/lijieli/org-claude-skills/install.sh:181-187`
  - `/Users/lijieli/org-claude-skills/install.sh:876-877`
  - `/Users/lijieli/org-claude-skills/install.sh:1503`
  - `/Users/lijieli/org-claude-skills/install.sh:1639-1640`
- 关键权限证据：
  - 仓库索引：`git ls-files --stage claude/hooks/block_dangerous.sh shared/hooks/managed/block_dangerous.sh` -> `100644`
  - 已安装文件：`stat -f '%Sp %N' /Users/lijieli/.claude/hooks/block_dangerous.sh /Users/lijieli/.claude/hooks/managed/block_dangerous.sh` -> `-rw-r--r--`
- 建议修复范围与回归测试：
  - hook 源文件 mode
  - 安装 quick check
  - `tests/test-install-smoke.sh`
  - `tests/test-install-systematic.sh`
  - `tests/test-runtime-integrity.sh`
