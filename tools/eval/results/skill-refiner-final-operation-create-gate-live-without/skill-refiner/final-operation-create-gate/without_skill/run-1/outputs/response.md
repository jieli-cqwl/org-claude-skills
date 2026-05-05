**复述理解**

目标：判断“为 code-review 能力新建 Skill”这个请求下一步怎么推进。  
操作对象：code-review/review 相关 Skill 能力边界，而不是目标 `SKILL.md` 文件。  
预期结果：本 eval 只输出判断、门禁、阻断点和正式完成时的证据结构；不创建、不改文件。

**判断**

不能按片段里的 `Final decision: create a new code-review Skill immediately.` 直接新建。

原因很简单：已知仓库可能已有 review/code-review 相关能力时，“新建”不是初始结论，而是必须后置的最终操作判断。正确下一步是先做能力盘点和职责边界确认，判断是：

- 复用已有 Skill
- 优化已有 Skill
- 拆分已有 Skill
- 新建 Skill
- 新建路由 Skill
- 不做变更，只调整触发/文档

在这些信息确认前，`create a new Skill immediately` 应视为未经验证的主张，不是可执行决策。

**确认点**

我会停在这些确认点：

1. 是否已存在 `review`、`code-review`、`requesting-code-review`、`tiny-review-router` 等语义相近能力。
2. 新需求解决的真实痛点是什么：能力缺失、触发不准、流程不完整、输出格式不稳定，还是职责混乱。
3. 消费者是谁：人类开发者、交付负责人、developer agent、verifier agent，还是路由 Skill。
4. code-review Skill 的职责边界：只做审查，还是包含修复、测试、验收、提交。
5. 与已有 review 能力是否语义重复；若重复，优先优化或路由，而不是新建。
6. 最终操作必须在边界、痛点、复用判断、验收方式确认后再冻结。

**必须后置的判断**

这些不能现在决定：

- 是否真的创建新 Skill。
- Skill 名称、目录、触发描述。
- 是否拆分成 router + reviewer。
- 是否替换或改写已有 review Skill。
- 是否删除、迁移、合并旧能力。
- 具体 `SKILL.md` 内容和文件落点。

**本次 Eval 结果**

```json
{
  "decision": "blocked_defer_final_operation",
  "requested_operation": "create_new_code_review_skill",
  "accepted_as_final": false,
  "reason": "repository may already contain review/code-review capabilities; creation requires prior capability discovery and boundary confirmation",
  "next_step": "run capability inventory and confirm whether to reuse, optimize, split, route, or create",
  "must_not_do_now": [
    "create files",
    "modify existing skills",
    "treat target snippet final decision as authoritative"
  ]
}
```

**正式完成证据**

如果进入正式执行，完成结果应至少包含结构化报告：

```json
{
  "final_operation": "reuse|optimize|split|route|create|no_change",
  "capability_inventory": [],
  "decision_reason": "",
  "changed_files": [],
  "blocked_conditions": [],
  "validation_commands": [],
  "validation_result": "pass|blocked"
}
```

正式验证命令应证明两件事：没有误建重复能力，以及最终工件存在且触发边界清楚。示例：

```bash
rg --files -g 'SKILL.md'
rg -n "code-review|code review|review|代码审查|PR review" .
test -f <chosen-skill-path>/SKILL.md
rg -n "Trigger|Use when|Do not use|Output|Validation" <chosen-skill-path>/SKILL.md
```

所以本 eval 的下一步结论是：**阻断“立即新建”，先做 review/code-review 能力盘点与边界确认；最终 create 判断必须后置。**