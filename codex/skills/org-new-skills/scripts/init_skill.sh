#!/usr/bin/env bash
# 文件职责：生成符合 /new-skills 6 节结构的 Skill 骨架目录和 SKILL.md 模板。
# 边界：仅创建骨架，不覆盖已有文件。

set -euo pipefail

SKILL_NAME="${1:?用法: init_skill.sh <skill-name> [目标目录]}"
TARGET_DIR="${2:-$HOME/.claude/skills}"

# 校验 skill 名称（小写字母/数字/连字符，不以连字符开头或结尾）
if [[ ! "$SKILL_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
  echo "ERROR: skill 名称只允许小写字母、数字、连字符，且不可以连字符开头或结尾" >&2
  exit 1
fi

SKILL_DIR="$TARGET_DIR/$SKILL_NAME"

if [[ -d "$SKILL_DIR" ]]; then
  echo "ERROR: 目录已存在: $SKILL_DIR" >&2
  exit 1
fi

mkdir -p "$SKILL_DIR"/{references,scripts}

cat > "$SKILL_DIR/SKILL.md" << 'TEMPLATE'
---
name: SKILL_NAME_PLACEHOLDER
description: TODO {能力陈述}。Use when {触发场景}。
user-invocable: true
---

# /SKILL_NAME_PLACEHOLDER -- TODO 一句话目标

## HARD-GATE

1. NO TODO without TODO.

## 角色

你是 TODO{身份}。TODO{心理驱动}。TODO{质量锚点}。

## 流程

1. TODO 步骤A
2. TODO 步骤B

## 输出

TODO 输出格式/路径/模板

## 完成校验

- [ ] TODO 校验项A
- [ ] TODO 校验项B
- [ ] TODO 校验项C
TEMPLATE

# 替换占位符为实际 skill 名称
sed -i '' "s/SKILL_NAME_PLACEHOLDER/$SKILL_NAME/g" "$SKILL_DIR/SKILL.md"

echo "Skill 骨架已创建:"
echo "  $SKILL_DIR/"
echo "  ├── SKILL.md (6 节结构模板，含 TODO 占位)"
echo "  ├── references/"
echo "  └── scripts/"
echo ""
echo "下一步: 编辑 $SKILL_DIR/SKILL.md，替换所有 TODO 占位符"
