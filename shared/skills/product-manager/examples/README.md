# Product Manager Skill 示例

本目录收录完整的端到端样例工件，供两个用途：
1. 作为 **参考样例**：新 PM 进入流程时可以参照 fixture 学 schema、字段含义、术语风格。
2. 作为 **回归夹具**：skill 优化后运行脚本验证三大新能力仍触发。

## feature--user-login-validation

### 背景
真实跑通 M-S0 到 M-S9 的产出。故意在 baseline 和 UNIT 中植入了 3 个测试信号：
- M-S0 语义歧义（risks_and_unknowns 中"会话过期策略"与 mitigation 不一致）
- M-S4 高优依赖低优（UNIT-1/2 P0 依赖 UNIT-3 P1）
- M-S7 术语不一致（UNIT-2 用 `token`/`认证状态`）

当前目录里的文件是 **已修正版**，优先级和术语均一致，可作为"正确答案"参照。

### 回归验证命令

```bash
PHASE_DIR=shared/skills/product-manager/examples/feature--user-login-validation/phase-1
BRIEF=shared/skills/product-manager/examples/feature--user-login-validation/brief.json

# Director handoff 检查
bash shared/skills/product-manager/scripts/preflight_check.sh --phase-dir "$PHASE_DIR"

# M-S4 优先级校验
python3 shared/skills/product-manager/scripts/check_priority_consistency.py --phase-dir "$PHASE_DIR"

# M-S7 术语校验
python3 shared/skills/product-manager/scripts/check_terminology_consistency.py --phase-dir "$PHASE_DIR"

# PM handoff gate
python3 tools/community/validate_product_closure.py --artifact "$PHASE_DIR/phase-prd.json" --require-review
```

全部应输出 `PASS` 或 exit 0。

### digest 工具使用

改动 `locked_fields` 后必须用专用工具重算 digest，用 jq 算出来的格式和 Python 规范化不一致：

```bash
# 只打印新 digest
python3 shared/skills/product-manager/scripts/compute_digest.py --brief "$BRIEF"

# 直接写回文件
python3 shared/skills/product-manager/scripts/compute_digest.py --brief "$BRIEF" --write
```
