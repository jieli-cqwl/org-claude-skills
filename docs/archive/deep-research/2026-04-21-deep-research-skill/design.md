# Deep Research Skill Design

## Why

用户需要把“横纵分析法”沉淀成一个可手动触发的 first-party Skill，用于在陌生领域快速建立完整认知框架，并在需要时产出可审计的深度研究报告。现有 `research` Skill 覆盖通用调研、选型和对象识别；`deep-research` 的价值在于固定采用“纵向追时间深度、横向追同期广度、横纵交汇出判断”的方法论，并交付 Markdown 与 PDF 报告。

该 Skill 的核心目标不是替代长期研究，而是把资料采集、历史叙事、横向比较、综合判断和报告归档收成一个稳定工作流。默认模式服务个人快速入门；严肃模式服务团队输入、决策前研究和证据链审计。

## Scope

- In scope: 创建 `deep-research` first-party manual-only Skill 的设计。
- In scope: 覆盖横纵分析法、双报告模式、来源分层、arxiv 条件查询、Markdown 事实源、PDF 派生物和完成证据。
- In scope: 设计 Claude Code 与 Codex 共用安装路径，保证 Codex runtime 裁剪自动 adapter。
- In scope: 设计最小 contract 测试、install/runtime 测试改动和 eval 样例。
- Out of scope: 第一版不接入特定 Deep Research 平台，不调用外部写入系统，不生成浏览器 UI，不自动写入飞书或知识库。
- Out of scope: 第一版不把 `deep-research` 合并进现有 `research` Skill。

## Approach

`deep-research` 放在 `shared/skills/deep-research/`，采用模块化 Skill 结构。`SKILL.md` 只承载触发边界、硬门禁、主流程和输出合同；横纵方法论、来源规则、arxiv 规则和报告模板放入 `references/`；确定性脚本放入 `scripts/`；测试样例放入 `evals/`。

Skill 由用户手动调用。用户给出研究对象后，Skill 先判断对象类型和报告模式，再建立输出目录。默认输出目录为 `docs/deep-research/{date}-{slug}/`，包含 `research-report.md`、`research-report.pdf`、`sources.json` 和 `run-notes.md`。

Markdown 是事实源。PDF 只由本地脚本从 Markdown 派生，不能改写、删减或重排报告事实。来源记录独立落在 `sources.json`，报告正文引用这些来源，便于验证和后续审阅。

## Components

| Component | Responsibility |
| --- | --- |
| `SKILL.md` | 触发边界、manual-only 合同、主流程、失败状态、输出合同和 reference 路由 |
| `agents/openai.yaml` | 源态 Codex adapter；安装到 Codex 后因 manual-only 被移除 |
| `references/methodology.md` | 横纵分析法、对象类型适配、快速入门版与严肃可审计版差异 |
| `references/source-policy.md` | 来源分层、一手来源优先、时间点标注、口碑样本偏差、未证实信息处理 |
| `references/arxiv-policy.md` | arxiv 触发条件、查询方式、强相关判定、弱相关结果排除 |
| `references/report-template.md` | Markdown 报告结构，包含快速版与严肃版增量段落 |
| `scripts/arxiv_search.py` | 通过 arxiv API 执行确定性论文检索，输出结构化 JSON |
| `scripts/render_report.py` | 将 `research-report.md` 渲染为 `research-report.pdf`，禁止联网和改写 Markdown |
| `scripts/manifest.json` | 声明脚本输入、输出、超时、失败状态、网络权限和验证命令 |
| `evals/evals.json` | 覆盖产品、公司、技术概念、严肃版和 PDF 失败路径的样例 |

## Trigger Boundary

Use `deep-research` when the user manually invokes `$deep-research` or explicitly asks to use 横纵分析法 / 横纵分析 / 纵向横向分析 / 深度研究报告 with this method.

Do not use `deep-research` for generic technology selection, repository object discovery, codebase scan, security review, prompt optimization, or one-off factual lookup. Those route to `research`, `scan`, `security`, `prompt`, or direct answer paths.

Manual-only behavior is required because the Skill can perform long-running web research, create files, and produce reports. Source `SKILL.md` declares `disable-model-invocation: true`; install logic copies it into Claude and Codex runtimes, then removes Codex `agents/openai.yaml`.

## Report Modes

Default mode is quick onboarding. It favors readability, narrative structure and cognitive map building. It still records sources and uncertainty, but does not expand every finding into an audit trail.

Strict mode is selected when the user says 严肃版、可审计版、给团队看、用于决策、需要证据链、不要幻觉, or equivalent wording. Strict mode adds source coverage notes, conflict handling, confidence labels, strongest opposing evidence, invalidation conditions and open verification questions.

## Data Flow

```text
user input
  -> research scope
  -> evidence notes and sources.json
  -> research-report.md
  -> research-report.pdf
```

`research scope` records the object name, object type, report mode, arxiv decision, output directory and user constraints.

`sources.json` records source title, URL, source tier, publication date or access date, claim supported, confidence, limitation and retrieval path. It is consumed by `research-report.md` and by verification checks.

`research-report.md` is the human-readable fact source. All core claims, uncertainty notes and evidence references live there.

`research-report.pdf` is a generated reading artifact. It is never treated as the source of truth.

## Workflow

1. Input classification: parse the research object, requested report mode, arxiv override and output directory.
2. Scope gate: if the object or research boundary is unclear, ask one clarifying question before deep research.
3. Output directory: create or select the report directory. If the target already exists, choose a non-conflicting suffix or ask before overwrite.
4. Object typing: classify the object as product, company, technology concept, person, event, game, cultural object or other.
5. Source collection: gather primary sources first, then secondary sources, then community or user sentiment evidence.
6. arxiv routing: for technology and academic objects, run `scripts/arxiv_search.py`; for non-academic objects, skip unless the user asks for papers.
7. Vertical analysis: reconstruct origin, birth point, major turns, decision logic, constraints and causal history.
8. Horizontal analysis: identify direct competitors, adjacent alternatives or previous-generation substitutes, then compare by object-specific dimensions.
9. Intersection synthesis: explain how historical choices created current advantages, current liabilities and likely future paths.
10. Markdown generation: write `research-report.md` and bind claims to `sources.json`.
11. PDF rendering: run `scripts/render_report.py` to produce `research-report.pdf`.
12. Closeout: report artifact paths and verification evidence. If any required artifact fails, report the blocker and do not claim full delivery.

## Source Policy

Primary sources include official docs, release notes, source repositories, papers, standards, company announcements, filings and direct statements. They are preferred for factual claims.

Secondary sources include media reports, analyst notes, interviews and high-quality blogs. They can explain context and interpretation, but cannot override primary sources.

Community sources include forums, GitHub issues, social posts, reviews and user comments. They are useful for sentiment and workflow evidence, but must carry sample-bias notes.

Conflicting sources are not resolved by authority alone. Strict mode records the conflict, dates, claims and current judgment. Quick mode records the uncertainty in prose.

## arxiv Policy

arxiv lookup is required for technology concepts, algorithms, research fields, model methods and academic terms unless the user explicitly disables paper search.

arxiv lookup is skipped for companies, products, people, games, business events and geopolitical events unless the user explicitly asks for papers or academic background.

`scripts/arxiv_search.py` queries the arxiv API with timeouts and returns JSON. Weakly related papers are excluded instead of added for volume. If a required arxiv query fails, the Skill can produce a draft report, but full completion is blocked until the failure is resolved or the user changes the scope.

## PDF Rendering

`render_report.py` reads `research-report.md` and writes `research-report.pdf`. It may use local Markdown, HTML and PDF libraries, but it cannot access the network and cannot modify the Markdown file.

If rendering dependencies are absent, the script exits non-zero and prints a user-readable remediation. It must not create fake PDFs, empty PDFs or placeholder PDFs.

## Error Handling

| Error | Handling |
| --- | --- |
| Research object is unclear | Ask one clarifying question and stop deep research until answered |
| Scope is too broad | Propose a narrower first object or first phase |
| Web research is unavailable | Stop full research because the evidence workflow cannot be satisfied |
| Primary sources are insufficient | Continue only with explicit limitation notes in report and sources |
| Sources conflict | Record conflict and avoid unsupported certainty |
| arxiv has no strong match | Record no strong arxiv evidence; do not add weak matches |
| Required arxiv query fails | Mark full completion blocked unless user changes scope |
| PDF dependency is missing | Preserve Markdown, report remediation, mark full completion blocked |
| PDF rendering fails | Preserve Markdown, report logs, mark full completion blocked |
| Output directory exists | Avoid silent overwrite through suffix or confirmation |
| `sources.json` cannot be written | Mark full completion blocked |

## Alternatives Considered

| Option | Pros | Cons | Verdict |
| --- | --- | --- | --- |
| Lightweight single-file Skill | Fast to create, fewer files | Crowds method, source policy, arxiv and report template into one context-heavy file | Rejected |
| Modular first-party manual-only Skill | Clear boundaries, installable, testable, consistent with existing first-party patterns | More files in first version | Chosen |
| Extend existing `research` Skill | Reuses existing research machinery | Blurs generic research with a branded report method and PDF artifact workflow | Rejected |

## Reuse Decisions

The design reuses the `shared/skills/` first-party source layout, the `feishu-docs` manual-only installation pattern, and the existing install/runtime test style. It does not reuse `research` directly because the semantic contract is different: `research` optimizes for decision, understanding and audit modes across many research shapes; `deep-research` optimizes for one fixed longitudinal plus cross-sectional method with Markdown and PDF delivery.

## Goals and Success Criteria

| Goal | Success Criteria | Verification |
| --- | --- | --- |
| First-party source | `shared/skills/deep-research/` contains Skill, references, scripts and evals | `bash tests/test-deep-research-skill-contract.sh` |
| Manual trigger | Source declares `user-invocable: true` and `disable-model-invocation: true` | `bash tests/test-single-source-layout.sh` |
| Claude and Codex install | Runtime installs `deep-research` into both skill trees | `bash tests/test-install-runtime-smoke.sh`; `bash tests/test-runtime-integrity.sh` |
| Codex manual-only | Codex runtime has no `deep-research/agents/openai.yaml` | `bash tests/test-codex-skill-adapter.sh` |
| Source policy | Skill contains source-tier routing and conflict handling | `bash tests/test-deep-research-skill-contract.sh` |
| arxiv routing | Technology objects require arxiv path; non-academic objects skip by default | `evals/evals.json`; contract test |
| PDF rendering | `render_report.py` creates a real PDF from Markdown or exits with clear failure | script test tied to available renderer |
| Complete delivery | Markdown, PDF, sources and run notes are all present for a full report | report workflow verification |

## Change Scope

| File or Area | Change Type | Size |
| --- | --- | --- |
| `shared/skills/deep-research/SKILL.md` | create | medium |
| `shared/skills/deep-research/agents/openai.yaml` | create | small |
| `shared/skills/deep-research/references/` | create | medium |
| `shared/skills/deep-research/scripts/arxiv_search.py` | create | medium |
| `shared/skills/deep-research/scripts/render_report.py` | create | medium |
| `shared/skills/deep-research/scripts/manifest.json` | create | small |
| `shared/skills/deep-research/evals/evals.json` | create | small |
| `install.sh` | modify | small |
| `tests/test-deep-research-skill-contract.sh` | create | small |
| `tests/test-single-source-layout.sh` | modify | small |
| `tests/test-install-runtime-smoke.sh` | modify | small |
| `tests/test-runtime-integrity.sh` | modify | small |
| `tests/test-codex-skill-adapter.sh` | modify | small |
| `README.md` | modify | small |

## Downstream Impact

| Consumer | Impact | Propagation Needed |
| --- | --- | --- |
| Claude runtime | New manual Skill appears under `~/.claude/skills/deep-research` | install smoke and runtime integrity |
| Codex runtime | New manual Skill appears under `~/.codex/skills/deep-research` without adapter | Codex adapter test |
| Users | They can manually invoke `$deep-research` for longitudinal and cross-sectional research reports | README mention |
| Existing `research` Skill | No behavior change; boundary documentation prevents routing confusion | Skill contract and eval wording |
| Install tests | Manual-only lists need `deep-research` | single-source, runtime-smoke and runtime tests |

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Skill overlaps with `research` | Wrong routing and user confusion | Explicit trigger boundary and negative evals |
| Weak sources produce confident claims | Misleading report | Source tiers, conflict handling and strict-mode challenge sections |
| arxiv results add noise | Report includes irrelevant papers | Strong relevance filter and no-results recording |
| PDF renderer is unavailable | Complete delivery blocked | Dependency detection and clear remediation |
| Fake PDF generation slips in | False completion evidence | Script test rejects empty or placeholder output |
| Long reports exceed context budget | Incomplete report or weak sources | Progressive references and structured sources file |

## Invariants

- `research-report.md` remains the fact source.
- `research-report.pdf` remains a derived artifact.
- `sources.json` records evidence and retrieval notes.
- `render_report.py` cannot access network and cannot modify Markdown.
- `arxiv_search.py` only runs when arxiv policy requires it or the user asks for it.
- `deep-research` remains manual-only in Claude and Codex.
- `research` remains the generic research Skill and is not modified for this feature.
