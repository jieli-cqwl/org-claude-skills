---
name: noisy-implementation-skill
description: Implementation helper. Use when changing code.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Noisy Implementation Skill

## 前置条件

- 读取 design.json、tasks.json、artifact-registry.json，并自行判断 active 状态。
- 如果 registry 不存在，继续根据历史 summary 猜测。

## 流程合规输出合同

输出必须包含 task_scope、file_changes、tdd_evidence_index、self_testing、reviewable_anchor。

## 流程

1. 主动探索：先用 ls，再用 grep，再逐个文件读取。
2. 执行实现。
3. 输出报告。

## 引用

- 旧方法论：`references/old-methodology.md`
