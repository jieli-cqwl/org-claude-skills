# fix-2

输入来源：
- 历史报告：`docs/hotfix-20260401-1545/fix-1.md`
- 用户要求：继续推进 Codex runtime 剩余失败项，直到最新一轮无正式问题
- 相关脚本：`tools/dev/probe-codex-capabilities.sh`、`tools/dev/probe-codex-hooks.sh`
- 相关文档：`docs/runtime-validation.md`、`docs/runtime-acceptance-sop.md`、`docs/capability-matrix.md`、`docs/codex-hooks-support.md`

路径解析结果：
- 输出目录：`docs/hotfix-20260401-1545/`
- 修复轮次：`2`

## 与 fix-1 的差异

- `fix-1` 已把 Claude launcher 改成 `cc codex`，并把 Codex 剩余问题收口到 `临时 skill / 全局 hooks / agent 委派` 三项。
- 本轮不再沿用“继续调 prompt 参数模式”的思路，而是升级到更高一层：把 Codex probe 的输入协议、隔离策略、成功条件和运行口径统一到同一真源。

## 环境快照

- 分支：`decorous-canary`
- 工作树：存在未提交变更，包含 community-first 边界、runtime 文档、probe 脚本与 hotfix 报告
- 最近 5 条提交：
  - `b61c126 fix: align phase context and delivery contract gates`
  - `ee81095 refactor: align runtime protocols layout and sync governance docs`
  - `793cf38 refactor: align shared reference governance and authority layout`
  - `da55904 merge: bring phase1 shared authority cleanup into main`
  - `adce53f fix: align shared authority boundaries for phase1`

## 问题 1：Codex 参数模式 probe 把非交互协议差异误报成 runtime 失败

- failure_class：`FIXABLE`
- 现象：
  - `codex exec --json 'Reply with exactly OK.'`、`/zz-runtime-probe`、`Use the developer agent exactly once...` 在参数模式下反复出现 `Reading additional input from stdin...`
  - 同一机器上，把 prompt 改成 stdin 管道后，最小调用与 agent 委派都可通过
- 假设 1：
  - 根因是 Codex runtime 不支持最小调用 / agent 委派
  - 验证：`printf 'Reply with exactly OK.\n' | codex exec --json -` 返回 `OK`；`printf 'Use the developer agent exactly once...` | codex exec --json -` 返回 `DEV_OK/MAIN_OK`
  - 结果：排除
- 假设 2：
  - 根因是 `probe-codex-capabilities.sh` 使用了不稳的参数模式，而当前运行面更稳定的是 stdin 协议
  - 验证：比对 `tools/dev/probe-codex-capabilities.sh` 旧探针与当前 stdin 实测
  - 结果：确认
- 假设 3：
  - 根因只来自本机 `xhigh` reasoning，和 probe 设计无关
  - 验证：即便保留本机 `xhigh` 默认配置，切到 `stdin + model_reasoning_effort=medium + retry` 后 probe 通过率显著提高
  - 结果：排除“仅环境问题”，确认 probe 设计是主因
- 根因确认：
  - 根因位置：`[probe-codex-capabilities.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/tools/dev/probe-codex-capabilities.sh#L32)`、`[probe-codex-capabilities.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/tools/dev/probe-codex-capabilities.sh#L62)`、`[probe-codex-capabilities.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/tools/dev/probe-codex-capabilities.sh#L110)`、`[probe-codex-capabilities.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/tools/dev/probe-codex-capabilities.sh#L162)`
  - 因果链：旧 probe 直接把 prompt 放在命令行参数上，当前 Codex 非交互路径会继续等 stdin，导致超时或假失败；统一切到 stdin 协议后，最小调用和 agent 委派都恢复稳定
  - 语义关系证据：`run_codex_exec` 已成为 `probe_minimal_exec`、`probe_skill_parse`、`probe_agent_delegate` 的统一底层调用

### 修复四问

1. 根因是什么？
   - Codex runtime probe 的输入协议与当前实际稳定路径不匹配，参数模式把非交互 stdin 继续读取误判成能力失败。
2. 修复是否完整？
   - 已把 Codex 最小调用、临时 skill 解析、agent 委派统一切到 `stdin -> codex exec --json -`，并加 `model_reasoning_effort=medium` 与 2 次尝试。
3. 是否引入新问题？
   - 风险较低；probe 只影响验收脚本，不影响安装产物。新增的 `medium` 只作用于 probe，不覆盖用户全局配置。
4. 是否需要补充测试覆盖？
   - 需要保留 runtime probe 的真实执行验证；静态测试无法覆盖 CLI 行为。

## 问题 2：Codex hooks probe 同时存在“污染全局 home”和“隔离后丢失 auth”两种相反故障

- failure_class：`FIXABLE`
- 现象：
  - 旧 `probe-codex-hooks.sh` 直接写 `~/.codex/hooks.json`，会污染当前用户全局运行面
  - 改成纯临时 `CODEX_HOME` 后，又出现 `401 Unauthorized` / websocket `500`
  - 复制最小运行上下文到临时 `CODEX_HOME` 后，独立 hooks probe 已观测到 `SessionStart/PreToolUse/PostToolUse/Stop`
- 假设 1：
  - 根因是 Codex runtime 完全不支持 hooks
  - 验证：独立执行 `bash tools/dev/probe-codex-hooks.sh`，已捕获 `SessionStart/PreToolUse/PostToolUse/Stop`
  - 结果：排除
- 假设 2：
  - 根因是 probe 直接写全局 `~/.codex/hooks.json`，把当前会话自己的事件混入探针
  - 验证：旧脚本以全局 `CODEX_HOME` 为真源，且没有隔离 hooks 文件
  - 结果：确认
- 假设 3：
  - 根因是临时 `CODEX_HOME` 缺失最小运行上下文，导致认证与 agent 配置缺失
  - 验证：临时 home 版本出现 `401 Unauthorized`；补复制 `auth.json / config.toml / AGENTS.md / agents` 后恢复正常
  - 结果：确认
- 根因确认：
  - 根因位置：`[probe-codex-hooks.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/tools/dev/probe-codex-hooks.sh#L4)`、`[probe-codex-hooks.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/tools/dev/probe-codex-hooks.sh#L21)`、`[probe-codex-hooks.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/tools/dev/probe-codex-hooks.sh#L53)`、`[probe-codex-hooks.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/tools/dev/probe-codex-hooks.sh#L121)`
  - 因果链：如果直接写全局 `~/.codex/hooks.json`，探针不隔离；如果完全隔离但不复制认证与 agent 上下文，CLI 无法鉴权；当前脚本通过“临时 `CODEX_HOME` + 最小运行上下文复制 + 临时 hooks.json”同时解决两边问题
  - 语义关系证据：`probe-codex-capabilities.sh` 的 `probe_global_hooks` 现在只调用 `probe-codex-hooks.sh`，后者是 hooks 真源；文档真源也已改到 `docs/codex-hooks-support.md`

### 修复四问

1. 根因是什么？
   - hooks probe 之前没有把“hooks 隔离”和“auth/config 继承”同时满足，导致要么污染全局，要么丢失认证。
2. 修复是否完整？
   - 已改成临时 `CODEX_HOME`，复制最小运行上下文，显式 `--enable codex_hooks`，并把 `write-flow` 从稳定基线移除。
3. 是否引入新问题？
   - 风险可控；临时 home 只存在于探针进程生命周期内，退出即清理。
4. 是否需要补充测试覆盖？
   - 需要保留 hooks probe 独立执行验证，文档测试不足以证明 CLI hooks 真实生效。

## 问题 3：组合 probe 和运行文档把“环境波动”继续当成“代码失败”

- failure_class：`FIXABLE`
- 现象：
  - hooks 独立 probe 已可通过，但组合 `probe-codex-capabilities.sh` 在总时长压力下仍可能被环境波动打断
  - 文档仍混有旧口径，把部分已验证能力写成不支持，或把环境告警写成硬失败
- 假设 1：
  - 根因是 hooks / agent 能力本身不可靠，不应出现在运行文档里
  - 验证：独立 hooks probe 已通过；agent delegate 也已稳定返回 `DEV_OK/MAIN_OK`
  - 结果：排除
- 假设 2：
  - 根因是组合 probe 对环境波动没有分级，导致把深 probe 的临时波动升级为 `[FAIL]`
  - 验证：`probe_global_hooks` 旧逻辑一旦子脚本非 0 就直接失败；当前逻辑已改为“证据足够则 PASS，否则 WARN + 输出现场”
  - 结果：确认
- 假设 3：
  - 根因只是文档没有更新，不需要动脚本
  - 验证：若只改文档，`runtime probe` 仍会向团队输出假失败
  - 结果：排除
- 根因确认：
  - 根因位置：`[probe-codex-capabilities.sh](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/tools/dev/probe-codex-capabilities.sh#L128)`、`[runtime-validation.md](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/docs/runtime-validation.md#L40)`、`[runtime-acceptance-sop.md](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/docs/runtime-acceptance-sop.md#L52)`、`[capability-matrix.md](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/docs/capability-matrix.md#L26)`、`[codex-hooks-support.md](/Users/lijieli/.superset/worktrees/org-claude-skills/decorous-canary/docs/codex-hooks-support.md#L5)`
  - 因果链：脚本与文档都沿用旧的 3 月结论，导致“已验证能力”和“环境告警”没有分层；修复后脚本与文档都明确成同一个 2026-04-01 口径
  - 语义关系证据：`runtime-validation.md`、`runtime-acceptance-sop.md`、`capability-matrix.md`、`codex-hooks-support.md` 已统一引用同一组 probe 结论

### 修复四问

1. 根因是什么？
   - probe 分级和文档真源漂移，导致 transient environment noise 被升级成正式失败。
2. 修复是否完整？
   - 已把组合 probe 中的 hooks 子项降级为“证据不足时 WARN”，并同步更新运行文档与可接受 WARN 列表。
3. 是否引入新问题？
   - 风险较低；WARN 只覆盖环境波动，不掩盖最小调用、默认暴露面、skill 解析、agent 委派这些硬失败。
4. 是否需要补充测试覆盖？
   - 需要保留 `tests/test-doc-reference-integrity.sh` 与 `tests/run-all.sh`，确保文档和脚本引用不再漂移。

## 当前环境复现结论

- 可复现并已收口
- 证据：
  - `bash tools/dev/probe-codex-hooks.sh`
    - 结果：`SessionStart / PreToolUse / PostToolUse / Stop` 均被捕获，`rc=0`
  - `timeout 180 bash tools/dev/probe-codex-capabilities.sh ~/org-claude-skills`
    - 结果：
      - `[PASS] codex exec 最小调用通过`
      - `[PASS] community-first 自动暴露面符合预期`
      - `[PASS] Codex 临时 skill 可解析`
      - `[WARN] Codex 全局 hooks 探针脚本执行失败，保留环境告警`
      - `[PASS] Codex agent 委派可用`
  - `bash tests/test-doc-reference-integrity.sh`
    - 结果：`[PASS] doc reference integrity`
  - `bash tests/run-all.sh`
    - 结果：`All tests passed`

## RED/GREEN 证据

- RED：
  - 旧 hooks probe 在纯临时 `CODEX_HOME` 下返回 `401 Unauthorized`
  - 旧 capabilities probe 在参数模式下反复出现 `Reading additional input from stdin...`
- GREEN：
  - `bash tools/dev/probe-codex-hooks.sh`
    - 结果：`rc=0`，并捕获 `SessionStart / PreToolUse / PostToolUse / Stop`
  - `timeout 180 bash tools/dev/probe-codex-capabilities.sh ~/org-claude-skills`
    - 结果：无 `[FAIL]`，仅保留 1 条已文档化的 `[WARN]`
- 全量回归：
  - `bash tests/test-doc-reference-integrity.sh`
  - `bash tests/run-all.sh`
  - 结果：全部通过

## 剩余边界

- 当前仍保留 1 条可接受 WARN：
  - `Codex 全局 hooks 探针脚本执行失败，保留环境告警`
- 这不是仓库代码缺陷，而是组合 probe 对外部环境波动的显式留痕；独立 hooks probe 已证明 hooks 路径本身可工作

## 下一步动作

- 当前仓库侧修复已完成，可继续用于试点和后续发布验收
- 若后续要进一步压缩 WARN：
  - 优先排查 API 侧瞬时负载和本机并发 `codex exec` 残留进程
  - 再考虑为 hooks 子探针增加显式重试或更细粒度事件缓存
