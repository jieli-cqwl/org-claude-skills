# Community Adapters

本目录只承载 community-first 运行面适配层。

允许的改动范围：
- 平台 metadata
- Codex `openai.yaml`
- Claude/Codex 命令或 prompt 落位
- 路径与占位符归一化
- 安装映射

禁止的改动范围：
- 改写 upstream 流程步骤
- 改写 upstream 角色与门禁
- 重命名 upstream skill 或 `opsx:*` 命令
- 用本地流程替换 upstream 正文

Source of truth:
- `third_party/community/superpowers`
- `third_party/community/openspec`
