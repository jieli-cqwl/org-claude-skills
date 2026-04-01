# fix-1

输入来源：
- 用户要求：Claude 启动方式改为 `cc codex`，其余继续推进 runtime 阻塞排查
- 相关脚本：`tools/dev/probe-claude-capabilities.sh`
- 相关文档：`docs/runtime-acceptance-sop.md`、`docs/runtime-validation.md`

路径解析结果：
- 输出目录：`docs/hotfix-20260401-1545/`
- 修复轮次：`1`

## 问题 1：Claude 探针启动器与用户指定不一致

- failure_class：`FIXABLE`
- 现象：
  - `tools/dev/probe-claude-capabilities.sh` 中所有 Claude 探针都直接调用 `claude`
  - 用户明确要求使用 `cc codex`
- 假设 1：
  - 根因是脚本硬编码了 `claude` 启动器
  - 验证：检查 `tools/dev/probe-claude-capabilities.sh:41,107,127,183,234,267,294`
  - 结果：确认
- 假设 2：
  - 当前机器不存在 `cc codex`，无法替换
  - 验证：执行 `command -v cc` 与 `cc codex --help`
  - 结果：排除，`/Users/lijieli/.npm-global/bin/cc` 存在，且 `cc codex` 可返回 Claude Code CLI 帮助
- 假设 3：
  - 只是文档口径不一致，脚本无需改
  - 验证：对照脚本和文档引用位置
  - 结果：排除，脚本与文档都存在 `claude` 直调
- 根因确认：
  - 根因位置：`[probe-claude-capabilities.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/tools/dev/probe-claude-capabilities.sh):41`、`[probe-claude-capabilities.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/tools/dev/probe-claude-capabilities.sh):107`、`[probe-claude-capabilities.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/tools/dev/probe-claude-capabilities.sh):294`
  - 因果链：探针脚本把启动器写死为 `claude`，导致用户要求的 `cc codex` 无法生效；相关运行文档继续传播相同口径
  - 语义关系证据：`docs/runtime-acceptance-sop.md` 与 `docs/runtime-validation.md` 都直接引用了同一类 `claude ...` 运行方式，与脚本保持同向耦合

### 修复四问

1. 根因是什么？
   - 探针和验收文档把 Claude 启动器硬编码为 `claude`，没有给 `cc codex` 留入口。
2. 修复是否完整？
   - 已把探针改成可配置启动器，默认 `CLAUDE_LAUNCHER=\"cc codex\"`，并同步修正文档样例命令。
3. 是否引入新问题？
   - 风险较低；保留 `CLAUDE_LAUNCHER` 覆盖能力，仍可显式切回其他启动器。
4. 是否需要补充测试覆盖？
   - 需要通过脚本执行验证至少确认探针能以 `cc codex` 启动并输出 launcher/version。

### 处置结果

- 已修复：
  - `tools/dev/probe-claude-capabilities.sh`
  - `docs/runtime-acceptance-sop.md`
  - `docs/runtime-validation.md`

## 问题 2：当前机器的 runtime probe 仍被环境阻断

- failure_class：`ENV_ISSUE`
- 现象：
  - Claude probe 返回 `403`，提示额度不足
  - Codex 最小探针 `timeout 20 codex exec --json 'Reply with exactly OK.'` 返回 `124`
  - 后台可见长期残留进程
- 假设 1：
  - 根因在仓库脚本逻辑
  - 验证：仓库级检查 `tests/run-all.sh`、`install.sh --check full` 已通过
  - 结果：排除，仓库侧合同、文档和安装流程可正常通过
- 假设 2：
  - Claude 运行面被代理额度或鉴权阻断
  - 验证：上一轮 `probe-runtime-capabilities` 输出 `403` 和“用户额度不足”
  - 结果：确认
- 假设 3：
  - Codex probe 被残留进程或运行面阻塞
  - 验证：`ps -o pid,ppid,etime,command` 可见长期残留 `codex exec` 与 probe 子进程
  - 结果：确认
- 根因确认：
  - 环境根因，不是仓库代码根因
  - 证据：`ps` 输出中的长期残留进程，以及 Claude probe 返回的 `403`

## 问题 3：Codex skills 枚举探针本身过于脆弱

- failure_class：`FIXABLE`
- 现象：
  - `timeout 20 codex exec --json 'Reply with exactly OK.'` 可以在 7 秒内返回 `OK`
  - `timeout 20 codex exec --json 'List all currently available skills by exact name only, one per line, no extra text.'` 返回 `124`
  - 超时输出显示模型先去读取 `using-superpowers`，而不是直接给出技能列表
- 假设 1：
  - Codex runtime 整体不可用
  - 验证：最小调用返回 `OK`
  - 结果：排除
- 假设 2：
  - 失败来自“枚举 skill 名称”这个探针设计本身，而不是 Codex 基础调用
  - 验证：对比最小调用和 skills 枚举的结果差异
  - 结果：确认
- 假设 3：
  - 失败来自自动暴露面本身缺失
  - 验证：检查 `$HOME/.codex/skills/*/agents/openai.yaml`
  - 结果：排除，`brainstorming` 自动暴露而 `using-superpowers/product` 保持 manual-only，布局符合预期
- 根因确认：
  - 根因位置：`[probe-codex-capabilities.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/tools/dev/probe-codex-capabilities.sh)`
  - 因果链：脚本把“枚举全部可用 skill 名称”当成 runtime truth，但当前仓库的 AGENTS/skills 规则会让模型先进入启动技能流程，导致探针对时延异常敏感，进而把“探针设计脆弱”误判为“运行面故障”

### 修复四问

1. 根因是什么？
   - `probe_skills` 的提示词对当前仓库运行规则不稳，容易超时。
2. 修复是否完整？
   - 已改成更稳定的验证组合：`codex exec` 最小调用 + 自动暴露面文件检查 + 临时 skill 解析。
   - 同时给 Codex skill、hooks、agent 探针补了硬超时，避免整份 runtime probe 被单个子探针拖死。
3. 是否引入新问题？
   - 风险较低；脚本少了一项兼容路径探针，但和当前 community-first 默认链更一致。
4. 是否需要补充测试覆盖？
   - 需要重新执行 `tools/dev/probe-codex-capabilities.sh` 验证新探针能稳定跑完并输出诊断结果。

## 当前环境复现结论

- 可复现
- 证据：
  - `cc codex --help` 可正常返回 CLI 帮助
  - `CLAUDE_LAUNCHER='cc codex' timeout 20 bash tools/dev/probe-claude-capabilities.sh ~/org-claude-skills` 已输出 `claude_launcher=cc codex`，并通过 bare 最小调用
  - `timeout 130 bash tools/dev/probe-codex-capabilities.sh ~/org-claude-skills` 可自然结束并输出诊断结果
  - Codex 当前剩余失败点为：临时 skill 调用、全局 hooks、agent 委派

## RED/GREEN 证据

- GREEN：
  - `CLAUDE_LAUNCHER='cc codex' timeout 20 bash tools/dev/probe-claude-capabilities.sh ~/org-claude-skills`
  - 结果：输出 `claude_launcher=cc codex`，并出现 `[PASS] Claude bare 最小调用通过`
- GREEN：
  - `timeout 20 codex exec --json 'Reply with exactly OK.'`
  - 结果：返回 `OK`
- GREEN：
  - `timeout 130 bash tools/dev/probe-codex-capabilities.sh ~/org-claude-skills`
  - 结果：脚本自然结束，输出
    - `[PASS] codex exec 最小调用通过`
    - `[PASS] community-first 自动暴露面符合预期`
    - `[FAIL] Codex 临时 skill 调用失败`
    - `[FAIL] Codex 全局 hooks 探针脚本执行失败`
    - `[FAIL] Codex agent 委派探针失败`
- 全量回归：
  - `bash tests/run-all.sh`
  - 结果：`All tests passed`

## 下一步动作

- 处理 Claude 代理额度或鉴权
- 清理并定位长期残留 `codex exec` 进程
- 环境恢复后重跑：
  - `CLAUDE_LAUNCHER='cc codex' bash tools/dev/probe-claude-capabilities.sh ~/org-claude-skills`
  - `bash tools/dev/probe-codex-capabilities.sh ~/org-claude-skills`
  - `bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills`
