# Runtime Acceptance SOP

## 目的

用于安装后快速确认 Claude / Codex 运行面是否与仓库当前合同一致。

## 验收步骤

1. 运行 `bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills`
2. 运行 `bash tools/validate-contracts.sh`
3. 运行 `bash tests/run-all.sh`
4. 确认默认轻量链入口与文档合同一致：
   - `contracts/small-chain.yaml`
   - `docs/small-chain/README.md`
   - `docs/small-chain/boundary-contract.md`

## 运行面约束

- 允许出现额外系统 skills，但不得遮蔽仓库托管的 skills、rules、reference 与 hooks。
- `community/superpowers` 是当前本地 runtime 基线。
- `community/anthropic` 是官方 upstream skills 的镜像真源与 Codex adapter 真源。
- `small-chain` 是当前默认轻量链。
- OpenSpec CLI 不作为运行前提。
- 安装合成顺序固定为：`shared/skills -> community/superpowers/skills -> community/anthropic/skills`。
- 同名冲突默认 first-party 优先；当前唯一白名单特例是 `mcp-builder`，运行面应来自官方 Anthropic 目录。
