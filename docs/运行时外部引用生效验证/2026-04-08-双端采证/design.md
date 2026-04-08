# Design

## Why

当前仓库已经能验证运行时目录中 `reference/`、`rules/`、`skills/` 等文件被正确安装，并且相对路径不会悬空，但还不能证明 Claude Code 与 Codex 在真实运行时会实际读取入口文档里声明的外部 `reference/*.md`。这会留下“文件存在但语义未生效”的盲区。

## Scope

- In scope: 为 Claude Code 与 Codex 增加“入口文档外部 reference 生效”真实采证探针
- In scope: 为探针新增仓库内可回归的契约测试，校验探针结构、隔离策略与输出约定
- In scope: 将新探针接入现有 `tools/dev/probe-claude-capabilities.sh`、`tools/dev/probe-codex-capabilities.sh`
- Out of scope: 改造生产运行时入口文档语义
- Out of scope: 为所有 `skills/*/references/*` 建立全量行为级评测矩阵
- Out of scope: 在 CI 中默认执行依赖本机鉴权和联网的真实 live probe

## Approach

在两个平台现有 capability probe 中各新增一个 `Entry Reference Activation` 探针，核心做法一致：

1. 以当前已安装的 `~/.claude` / `~/.codex` 作为真源，复制到临时 `HOME`，避免污染用户运行时。
2. 在临时运行时中写入一个随机 token 的 `reference/runtime-reference-probe.md`。
3. 在临时 `CLAUDE.md` / `AGENTS.md` 末尾追加一段最小 probe 指令：当用户发送固定触发词时，必须读取上述 reference 文件，并按文件中的随机 token 精确回复。
4. 通过真实 CLI 调用该临时运行时，发送触发词并校验输出。
5. 只有在收到精确随机 token 时才判定 PASS；否则视为入口外部 reference 未被真实消费。

仓库内测试不直接跑 live probe，而是校验探针脚本是否满足三个硬约束：

1. 使用临时 HOME 复制运行时而不是直接修改用户目录
2. 通过外部 reference 文件承载随机 token，而不是把 token 直接写进入口 prompt
3. 对 Claude/Codex 分别使用各自现有 JSON/stream 输出解析方式做精确匹配

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| 只做静态引用完整性检查 | 稳定、易 CI | 仍然无法证明运行时会读外部文件 | Rejected |
| 直接修改用户 `~/.claude` / `~/.codex` 做 live probe | 最接近真实环境 | 有污染风险，失败时回滚复杂 | Rejected |
| 复制已安装运行时到临时 HOME 再做 live probe | 接近真实环境，且隔离安全 | 实现稍复杂，仍依赖本机鉴权 | Accepted |

## Key Decisions

- D1: 使用“复制已安装运行时到临时 HOME”的隔离策略，避免 accidental complexity 和环境污染
- D2: 使用随机 token + 外部 `reference/runtime-reference-probe.md` 承载唯一答案，降低模型猜中概率
- D3: live probe 作为开发与验收证据，仓库默认回归只覆盖探针契约，不把不稳定的联网鉴权链路强塞进 CI

## Success Criteria

- `tools/dev/probe-claude-capabilities.sh` 能输出一项新的 Claude 入口 reference 生效探针结果
- `tools/dev/probe-codex-capabilities.sh` 能输出一项新的 Codex 入口 reference 生效探针结果
- 新探针不会修改用户真实 `~/.claude` / `~/.codex`
- 新增仓库测试能在不联网的情况下校验探针契约并纳入 `tests/run-all.sh`
- 在当前机器上执行 probe 时，能得到明确的 PASS/WARN/FAIL 证据，而不是“无法判断”
