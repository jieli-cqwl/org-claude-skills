# 代码复用（强制）

> 开发任何新功能前，必须先搜索现有代码库并做 LSP 语义确认。

## 强制流程

1. 搜索：>=3 关键词（功能词+领域对象+动词）做 Grep/Glob 文本召回
2. 语义确认：LSP `workspaceSymbol` 定位 -> `goToDefinition` 确认 -> `findReferences` 统计引用
3. 评估：能复用就复用，需要改就重构现有代码
4. 新建门槛：搜索无结果，或满足任一——影响 >=3 调用方、需改动 >=50%、会造成循环依赖、语义完全不同

## 搜索目录

- Java: `service/` `util/` `common/` `helper/`
- Python: `services/` `utils/` `core/` `helpers/`
- TS: `services/` `utils/` `hooks/` `lib/` `components/`

## 新建时强制要求

必须在代码注释或 PR 描述中说明不复用的原因（含 LSP 证据）。

> LSP 不可用的判定：项目无对应语言的 LSP server（如纯 shell 脚本项目）或 LSP 调用返回 "server not initialized" 错误。网络延迟、响应慢不构成"不可用"。可用时禁止跳过语义确认。
