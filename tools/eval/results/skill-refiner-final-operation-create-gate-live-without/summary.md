# Standard-Chain Local Skill Eval

- total expectations: 6
- failed expectations: 3
- infra failures: 0
- pass rate: 0.50

## Runs
- skill-refiner / final-operation-create-gate: 3/6 passed
  - failed: 把新建、优化、替换或拆分后置为 SR-F1 的最终操作判断
  - failed: 要求 SR-S2、SR-S3 和 SR-R1~SR-R10 先沉淀台账结论，关键假设闭合后再执行
  - failed: 要求结构化结果和 validator/scoped proof 作为完成证据

## Optimization Findings
- 没有显式加载/引用 Skill 质量标准与 SR 流程。 -> 补充先读取 Skill 质量标准，按 G/S/E 映射问题卡，并按 SR-S2/SR-S3、SR-R1~SR-R10、SR-F1 排序推进。
- 完成证据过于通用。 -> 要求输出 `skill-refiner-result.json`，并用 validator、self-dogfood 或 scoped proof 作为完成证明。
