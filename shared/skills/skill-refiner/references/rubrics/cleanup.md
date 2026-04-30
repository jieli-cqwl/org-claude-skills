# Cleanup 环节标准

## Why

残留 active 引用会被 Agent 或 runtime 当成当前事实。清理不完整会让已修好的 Skill 被旧入口拖回旧目标。

## 目标

旧目录、旧名称、旧引用、旧测试、历史说明和无消费者资源从 active 链路中移除或迁到 fixture/archive。

## 裁决标准

1. active 引用清零：installer、catalog、adapter、tests、eval、README、docs 和 Skill 间引用一致。
2. 旧名不泄漏：退休名称不出现在 active source，除非测试明确允许。
3. 历史归位：历史证据进 archive 或 fixture，不留在默认读取路径。
4. 测试目标一致：run-all、shellcheck、fixtures 和断言跟新目标一致。
5. 删除有证据：每个删除都有证据表明无人消费或迁移后消费者已更新。

## 证据

- `rg` 引用扫描。
- install/runtime tests。
- eval/test fixture。
- archive 或 fixture 路径。

## 问题信号

- 只删除目录，没有处理 installer、tests 或 eval 引用。
- README、reference 头部仍写旧 Skill 历史。
- legacy 名称被 active migration test 报出。
- 旧测试为了通过而保留噪音。

## 验收

active 链路引用扫描和目标测试证明旧目标不再影响当前 Skill；保留历史只存在于 archive/fixture。
