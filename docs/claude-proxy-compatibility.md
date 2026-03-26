# Claude 代理兼容说明

目标：说明 Claude Code 在接入 LiteLLM / OpenAI 兼容代理时，哪些前置条件必须满足，否则会出现“基础调用可用，但 hooks / subagent / runtime probe 不可信”的隐性故障。

## 1. 适用范围

适用于以下场景：

- `~/.claude/settings.json` 中设置了 `ANTHROPIC_BASE_URL`
- Claude Code 不直接走 Anthropic 官方入口
- 本地使用 LiteLLM、OpenAI 兼容网关或公司内代理

不适用于：

- 直接使用 Anthropic 官方账号与官方 API

## 2. 必须满足的条件

### 2.1 代理必须是真实服务，不是 mock/probe

错误示例：

- 指向本地 `mock_anthropic_server.py`
- 指向仅用于协议探测的临时 mock 服务

后果：

- `claude -p` 可能无论输入什么都固定返回同一结果
- 运行时探针出现假阳性
- 团队误以为运行面已经通过验收

### 2.2 代理必须兼容 Claude 子代理使用的模型名

Claude 主会话和子代理不是同一个模型名：

- 主会话可能是 `gpt-5.4`
- 子代理会请求：
  - `claude-sonnet-4-6`
  - `claude-opus-4-6`
  - `claude-haiku-4-5-20251001`

如果代理只配置了 OpenAI 模型名，而没有这些 `claude-*` 别名，现象通常是：

```text
Invalid model name passed in model=claude-sonnet-4-6
```

这会导致：

- Claude agent 委派失败
- runtime probe 中 agent delegate 项失败
- 团队以为仓库能力有问题，实际是本机代理配置缺失

## 3. LiteLLM 示例

如果你用 LiteLLM 承接 Claude Code，可以显式加入 `claude-*` 到 OpenAI 模型的映射：

```yaml
model_list:
  - model_name: gpt-5.4
    litellm_params:
      model: openai/gpt-5.4
      api_base: os.environ/TEAMPLUS_API_BASE
      api_key: os.environ/TEAMPLUS_API_KEY

  - model_name: gpt-5.3-codex
    litellm_params:
      model: openai/gpt-5.3-codex
      api_base: os.environ/TEAMPLUS_API_BASE
      api_key: os.environ/TEAMPLUS_API_KEY

  - model_name: claude-sonnet-4-6
    litellm_params:
      model: openai/gpt-5.4
      api_base: os.environ/TEAMPLUS_API_BASE
      api_key: os.environ/TEAMPLUS_API_KEY

  - model_name: claude-opus-4-6
    litellm_params:
      model: openai/gpt-5.4
      api_base: os.environ/TEAMPLUS_API_BASE
      api_key: os.environ/TEAMPLUS_API_KEY

  - model_name: claude-haiku-4-5-20251001
    litellm_params:
      model: openai/gpt-5.3-codex
      api_base: os.environ/TEAMPLUS_API_BASE
      api_key: os.environ/TEAMPLUS_API_KEY
```

说明：

- 这不是仓库安装器管理的标准内容
- 这是本机或团队代理层的运行前置配置
- 映射到哪个 OpenAI 模型，由你们自己的成本/效果策略决定

## 4. 验收方式

代理配置完成后，至少执行：

```bash
cd ~/org-claude-skills
bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills
```

通过标准：

- Claude minimal bare: PASS
- Claude global hooks: PASS
- Claude skill-local hook: PASS
- Claude agent delegate: PASS

如果 agent delegate 仍失败，优先排查：

1. 代理是否支持 `claude-*` 模型名
2. 代理是否被切到了 mock/probe 服务
3. `ANTHROPIC_BASE_URL` 是否指向正确端口

## 5. 团队治理建议

- 代理配置属于运行环境前置条件，应写入团队环境接入文档
- 任何人修改本地 `ANTHROPIC_BASE_URL` 后，都必须重跑 runtime probe
- 不要用固定 `OK` 这类弱探针做验收；必须使用唯一 token
