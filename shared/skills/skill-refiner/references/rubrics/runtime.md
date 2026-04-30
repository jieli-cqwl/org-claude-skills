# Runtime 环节标准

## Why

Runtime 决定 Skill 是否真正可达、是否安全、是否和触发描述、安装清单一致。运行面不是主流程，但会影响触发和验收。

## 目标

frontmatter、allowed tools、installer、catalog、adapter、hook、manifest 和有效性记录与当前职责一致。

## 裁决标准

1. 入口可达：目标 runtime 能安装或显式调用该 Skill。
2. 入口一致：manual-only、user-invocable、disable-model-invocation 和 agents metadata 不冲突。
3. 权限匹配：allowed tools 支持职责动作，不用文字重复替代运行时授权。
4. hook 有边界：hook 注册、payload、handler、失败状态和消费者可定位。
5. checker 沉底：静态 checker 只作为候选信号和证据工具，不抢改造入口。
6. 有效性记录一致：`eval-type`、evals 和有效性信号不漂移。

## 证据

- frontmatter、agents/openai.yaml、install.sh、catalog、adapter。
- hooks registry、scripts manifest、schemas。
- `evals/evals.json` 和有效性记录。
- runtime/install tests。

## 问题信号

- Skill 声明不可自动触发，但安装入口与触发描述冲突。
- allowed-tools 已控制的权限又在主流程长篇重复。
- hook 规则写在 Skill 主流程里，但没有 registry 证据。
- checker 输出被当作语义裁决，替代你的验收。

## 验收

运行入口、权限、hook、checker 和有效性记录支持当前职责，不把运行面细节泄漏成主流程噪音。
