# Install-Layer Manual-Only Visibility Design

Created: 2026-04-18
Updated: 2026-04-18

> 结构参照：contracts/small-chain.yaml -> brainstorming -> design.md key_fields

## Problem Statement

当前仓库已经有安装层逻辑在运行时注入 `disable-model-invocation: true`，并对 Codex manual-only skill 做 adapter 暴露裁剪，但这套机制只覆盖部分 first-party 与 superpowers skill。针对低频 community/shared skill 的可见性收敛，如果直接修改 vendored `SKILL.md`，会把运行时策略写进 upstream/vendor 正文，破坏来源真源与安装层职责分离，也无法稳定表达 Claude 与 Codex 的联动规则。

## Goals & Success Criteria

### Goals
- 在安装层集中维护低频 skill 的 manual-only 策略。
- 保持 vendored `community/*/skills/*/SKILL.md` 正文不变。
- 让 Claude 与 Codex 对同一组 manual-only skill 呈现一致的可见性与暴露行为。
- 保留 `webapp-testing` 的自动可见性。

### Success Criteria
- `install.sh` 能声明并消费低频 skill 的 manual-only 名单。
- Claude 安装产物对目标 skill 自动注入 `disable-model-invocation: true`。
- Codex 安装产物对目标 skill 自动移除 `agents/openai.yaml`。
- 现有安装来源选择、优先级、override 规则保持不变。
- `bash tests/test-single-source-layout.sh` 与 `bash tests/test-runtime-integrity.sh` 能直接证明该行为。

## Approach

在 `install.sh` 继续采用“安装时重写运行面”的机制，不改 vendored skill 正文。具体做法是把低频 skill 的 manual-only 策略维护在安装层名单中，由 Claude 安装流程统一注入 `disable-model-invocation: true`，由 Codex 安装流程统一裁掉对应 skill 的 `agents/openai.yaml`。这样可见性决策留在运行时装配层，而不是散落到不同来源目录的正文文件中。

实现上保持最小改动：
- 扩展 `install.sh` 中的 manual-only skill 列表与消费逻辑。
- 补充/调整测试断言，证明 Claude 与 Codex 运行面行为一致。
- 不改变 skill 的安装选择集合，不改变 community override 规则。

## Alternatives Considered

| Option | Pros | Cons | Verdict |
| --- | --- | --- | --- |
| 直接修改 vendored `SKILL.md` | 改动直观 | 污染 upstream/vendor 正文；Codex 联动不稳定 | Rejected |
| 在 `settings.json` 单独维护可见性 | 与运行时接近 | 脱离仓库安装真源；不利于 Claude/Codex 同步 | Rejected |
| 在 `install.sh` 安装层集中维护 | 职责清晰；Claude/Codex 可统一处理；符合现有机制 | 需要补齐列表与测试 | Chosen |

## Change Scope

### In scope
- `install.sh` 中 manual-only 名单与消费逻辑。
- `tests/test-single-source-layout.sh`。
- `tests/test-runtime-integrity.sh`。
- 必要时补充与 manual-only 相关的 helper 断言。

### Out of scope
- 修改任意 vendored community skill 正文。
- 改动 skill 描述、触发文案或来源选择集合。
- 调整 `webapp-testing` 的自动可见性。
- 重构安装框架或引入新的配置文件格式。

## Invariants

- `community/anthropic/skills`、`community/vercel/skills`、`community/alchaincyf/skills` 的 vendored 正文保持 upstream 原样。
- skill 的安装来源优先级不变。
- `webapp-testing` 不进入 manual-only 名单。
- Claude / Codex 针对同一 manual-only 决策必须来自同一安装层真源。

## Downstream Impact

- Claude runtime 的 skill 列表会减少低频 skill 自动注入，初始上下文 token 降低。
- Codex runtime 不再自动暴露对应 manual-only skill 的 `agents/openai.yaml`。
- 后续维护者需要在安装层名单里增删低频 skill，而不是直接改 vendored 正文。

## Risks

- 如果名单与测试不同步，安装行为可能漂移但不易察觉。
- 如果把不该 manual-only 的 skill 放进名单，可能降低自动触发可用性。
- 如果 Claude 与 Codex 使用不同名单来源，会重新引入双端行为不一致。

## Files Likely To Change

- `install.sh`
- `tests/test-single-source-layout.sh`
- `tests/test-runtime-integrity.sh`

## Verification Plan

- `bash tests/test-single-source-layout.sh`
- `bash tests/test-runtime-integrity.sh`
- 如需更强证明，再运行 `git diff --check`
