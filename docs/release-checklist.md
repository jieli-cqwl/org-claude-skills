# Release Checklist

## 发布前检查

1. 确认 `VERSION`、`CHANGELOG.md` 与发布说明一致。
2. 运行 `bash tools/validate-contracts.sh`。
3. 运行 `bash tests/run-all.sh`。
4. 确认 `docs/small-chain/*` 与 `contracts/small-chain.yaml` 口径一致。

## 运行时检查

- 允许存在额外系统 skills，但不得遮蔽仓库托管技能或改变默认链路入口。
- 默认轻量链必须保持为 `small-chain`。
- 安装面不得重新引入 OpenSpec CLI 依赖。
