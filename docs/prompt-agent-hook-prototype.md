# Prompt/Agent Hook Type 原型验证

> 创建时间: 2026-04-06
> 状态: FEASIBLE — 官方文档确认支持，原型已设计，待实际部署验证
> 验证环境: Claude Code v2.1.92，官方 hooks 文档列出 command/http/prompt/agent 四种 type

## 背景

当前项目 hooks 全部使用 `type: command`。Claude Code v2.1.92 官方文档已支持四种 hook type：

| Type | 通信方式 | 适用场景 |
|------|---------|---------|
| `command` | shell 命令，stdin/stdout JSON | 确定性检查（文件存在、格式匹配、regex） |
| `http` | POST JSON 到 URL | 外部服务集成 |
| `prompt` | 发送 prompt 给 Claude 做单轮判断 | 语义级评审（"这份设计是否考虑了 X？"） |
| `agent` | 启动子 agent，可用 Read/Grep/Glob | 需要阅读代码后判断的复杂检查 |

## 原型设计

### Prompt Hook：TDD 语义评审

```json
{
  "matcher": "Stop",
  "hooks": [
    {
      "type": "prompt",
      "prompt": "Review the developer report in the current working directory. Check: (1) Are there real test files that were created BEFORE implementation files? (2) Do the tests verify actual behavior, not just mock responses? (3) Is there evidence of a RED phase (failing test) before GREEN phase? Answer PASS or FAIL with a one-line reason.",
      "timeout": 30
    }
  ]
}
```

### Agent Hook：设计文档依赖分析

```json
{
  "matcher": "SubagentStop",
  "hooks": [
    {
      "type": "agent",
      "prompt": "Read the design.md in the current feature directory. Check if external dependencies (third-party APIs, environment prerequisites, credentials) are explicitly listed. If any are missing, return FAIL with the missing items. Use Grep to search for import statements and API calls in the implementation files.",
      "timeout": 60
    }
  ]
}
```

## 与 Command Hook 的对比

| 维度 | Command | Prompt | Agent |
|------|---------|--------|-------|
| 检查类型 | 结构性（文件/格式/regex） | 语义性（内容理解） | 复杂语义（需读代码） |
| 误报率 | 低（确定性逻辑） | 中（LLM 判断波动） | 中-低（有工具辅助） |
| 延迟 | <1s | 5-15s | 15-60s |
| Token 成本 | 0 | 每次调用消耗 token | 每次调用消耗更多 token |
| 可测试性 | bash -n + shellcheck | 需要 eval 评测 | 需要 eval 评测 |

## 适用场景建议

| 场景 | 推荐 Type |
|------|----------|
| 文件存在性、章节有无、格式匹配 | command（现有方案，不变） |
| "这份报告是否真正考虑了 X" | prompt |
| "代码中是否存在 Y 且与设计文档一致" | agent |
| CI/CD 门禁（需要稳定性） | command（prompt/agent 误报率不适合硬门禁） |

## 限制和注意事项

1. **不稳定性**：prompt/agent hook 的判断依赖 LLM，同一输入可能返回不同结果。不适合作为硬门禁（exit 2 阻断），建议作为 warning 级别使用。
2. **成本**：每次 Stop 事件触发都消耗 token。高频触发场景（如 wizard 模式 skill 的中间暂停）应避免使用。
3. **超时**：prompt 建议 30s，agent 建议 60s。超时后 hook 被跳过，不阻断。
4. **当前集成建议**：在 hooks-fragment.json 中以注释形式保留原型配置，供用户手动启用测试。不默认启用，避免影响现有流程稳定性。

## 下一步

1. 用户在本地 settings.json 中手动添加 prompt hook 原型
2. 在 3-5 次实际 skill 执行中观察触发效果和误报率
3. 如果误报率 < 10%，考虑将语义检查作为 completion_check.sh 的补充层
4. 如果误报率过高，记录原因并关闭原型
