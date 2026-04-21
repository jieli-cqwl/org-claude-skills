我按当前工作区 `shared/skills/developer/SKILL.md` 判断：**Task T3 现在必须阻断，不能继续实现，也不能宣称完成。**

复述理解：T3 的 AC 是给 API 响应新增 `display_name` 字段；声明文件范围只有 `src/api/user.ts` 和 `tests/api/user.test.ts`；`design_refs` 指向 `design.json#/interfaces/UserResponse`。实现中发现必须同步 `design.json`，但 `design.json` 没有被显式列入文件范围。

按 developer skill：

- 这是接口微调：新增 API 响应字段属于 `TWEAK / 响应字段补充`。
- 但 `design.json` 未显式列入 Task 文件范围。
- HARD-GATE 要求：禁止修改声明文件范围外文件，遇到范围外文件必须停止并报告 `delivery-owner`。
- 异常处理要求：接口微调只有在 `{phase_dir}/design.json` 已显式列入 Task 文件范围时才能原地同步；否则必须报告 `delivery-owner`。

下一步：**立即向 delivery-owner 报告并等待指示**，请求其确认是否扩大 T3 文件范围以包含 `design.json`，或由上游拆分/调整设计工件后重新派发。当前不能擅自修改 `design.json`，不能继续 GREEN/REFACTOR，也不能输出“完成”结论。