阻断结论：当前不能继续产出或写入 `UNIT-1.json` / AC 草案。

目标理解：基于 `request-review-flow` 的 `brief.json` + `phase-1/phase-prd.json`，为 Phase 1 收口一个闭环 UNIT，并把 AC 收到可交给 `/design`、`/test-design` 的粒度。  
操作对象：当前 eval workspace 内的 `brief.json`、`phase-prd.json`、`units/UNIT-1.json`。  
预期结果：UNIT 具备 `输入/触发 → 核心行为 → 可观察结果`，并补齐 Integration Context、AC 示例输入/预期结果/边界情况/失败模式、Verification Plan、依赖和排除项。

实际执行到 M-S0 preflight 时失败：

```text
ModuleNotFoundError: No module named 'validate_product_closure'
```

失败命令：

```bash
bash shared/skills/product-manager/scripts/preflight_check.sh --brief .../brief.json --phase-prd .../phase-1/phase-prd.json
```

按 `product-manager/SKILL.md` 的 M-HG-0、M-HG-5、M-HG-7 和执行纪律，preflight 未可复验通过时不能推进 M-S4/M-S5，且阻断时不得输出 PRD / UNIT / AC 草案、不得替用户补签或绕过门禁。

准入阻断固定回复：`缺少 handoff 工件；docs/{feature}/brief.json 和 docs/{feature}/phase-{N}/phase-prd.json 是准入必需输入，用于校验 director_confirmation.status、locked_fields、当前 Phase 边界与 14 天 timebox。`

本次真实阻断原因不是文件路径缺失，而是 preflight 依赖的 `tools/community/validate_product_closure.py` 在当前 workspace 中不可用，导致 M-S0 无法形成可复验证据。

下一步：补齐或恢复 preflight 依赖后，重新运行 M-S0；通过后再进入 M-S4/M-S5，补齐 `UNIT-1` 的闭环定义、业务级 Integration Context、排除项追踪、示例驱动 AC 和 Verification Plan。