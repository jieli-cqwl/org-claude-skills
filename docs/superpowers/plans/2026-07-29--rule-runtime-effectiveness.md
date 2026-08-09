# Rule Runtime Effectiveness Implementation Plan

> Superseded for evaluator ownership, route bounds, repeated runs, and comparison semantics by `2026-08-05--rule-runtime-eval-credibility.md` and `2026-08-05--rule-runtime-document-governance.md`. Retained as historical implementation provenance.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立一条可重复的 Codex runtime 评估链，证明当前 worktree 中的入口、Rules 和 References 是否被真实路由、是否改变目标场景行为、相对显式 baseline 是否产生可解释增益，以及是否引入流程负担或行为回归。

**Architecture:** 保留 `docs/rule-runtime--team-readiness/acceptance-pack.json` 为 rollout 决策真源，保留 assistant-entry 与 SQL/schema case pack 为行为真源；新增一个只消费这些契约的 Python runner。Runner 将当前 worktree 和显式 Git baseline 安装到各自的临时 HOME，使用相同 Codex 设置执行同一份 candidate-owned cases，再把结构化命令读取证据、盲化语义评分、source/runtime 指纹和 freshness 汇总为生成报告。确定性检查负责身份、隔离、路由、完整性和状态机；模型 grader 只负责语义行为判断。

**Tech Stack:** Python 3 标准库、Bash contract tests、JSON/JSONL、现有 `install.sh`、Codex CLI `codex exec --json`、Git worktree/archive 能力、现有 quick gate。

## Global Constraints

- 批准设计是需求基线：`docs/superpowers/specs/2026-07-29--rule-runtime-effectiveness--design.md`，commit `8d2697ed`。
- 第一片只做 Codex diagnostic；不得据此宣称 Claude Code parity、controlled pilot 或全团队 rollout。
- 不修改 `shared/assistant.md`、历史 promotion run record、`standard_chain_local_eval` 或第三方 Skill 镜像。
- 不修改真实 `$HOME/.codex`、`$HOME/.agents` 或 `$HOME/.org-skills-state`。所有 installer、executor 和 grader 写入都必须位于 runner 创建的临时根目录。
- 只把真实 Codex HOME 中的 `auth.json` 和 `config.toml` 临时复制给 evaluator-owned HOME；不得读取其内容做日志、hash、报告或测试断言。cleanup 后不得残留副本。
- Candidate 是当前 worktree，包括相关未提交修改；baseline 必须由调用方按 case-pack 显式传入，runner 不提供隐式默认值。
- Candidate 与 baseline 必须使用 candidate-owned case prompt 和 grader，即 `--case-source candidate`；第一片不实现 historical replay。
- Assistant baseline 固定由首次 live invocation 显式传 `assistant-entry=f9cbf552`；SQL baseline 显式传 `sql-schema-comments=68abd950`。这些值不得写成 runner 默认值。
- 结构化 route evidence 只承认成功完成、输出非空且命令确实读取目标 runtime 文件的 `command_execution` 事件。回答里提到文件、仅定位文件、失败命令或未知 JSONL shape 都不能算读取成功。
- Grader 不接收 `candidate`/`baseline` 标签；judge HOME 只临时复制 auth/config，不安装任一待评 runtime。
- 生成的 coverage、comparison 和 summary 是投影，不是新真源；所有结论必须可回指 acceptance pack、case pack 和 per-run evidence。
- 行为与约束变更必须先有失败测试。不得用 `grep`、`rg` 或 shell prose assertions 锁定 Skill、Rule、Reference、Agent Markdown 正文。
- 第一片验证只跑 targeted tests、quick gate 和 install dry-run。除非这些命令暴露跨面失败，否则不跑 full gate。
- 设计的 File Impact 漏列了当前 runtime-source-set owner `tests/test-rule-runtime-team-readiness-pack.sh`。本计划将其纳入必要同步，不是扩展需求。

---

## Acceptance Scope

实现完成必须同时证明：

- acceptance pack 能解析全部 active scene contracts、case packs 和 focused profile；未知 scene、重复 case、缺失元数据、无覆盖 runtime source 在模型调用前失败。
- candidate 与每个 baseline ref 被安装到不同临时 HOME；测试能证明命令环境没有指向真实 HOME。
- 两个配置对同一 case 使用相同 prompt、expectations、grader、model 和 reasoning 设置。
- raw JSONL、final response、route verdict、semantic grade、timing、source/runtime identity 都持久化。
- route 与 behavior 分开判定；`behavior_pass_route_fail` 和 `route_pass_behavior_fail` 不得被折叠成成功。
- executor、installer 或 grader timeout/non-zero/unknown event shape 均保留为 `INFRA_BLOCKED`，不得变成行为失败或通过。
- candidate-only 或 baseline-only evidence 不得形成 attribution。
- freshness 能区分 `STALE`、`MISSING`、`INFRA_BLOCKED`、`BEHAVIOR_FAIL`、`FRESH_PASS`。
- focused profile 的八个场景全部形成 candidate/baseline pair，或明确给出 infrastructure blocker。
- 最终报告能直接支持三种决策：继续修规则/路由，接受“无可观察边际增益”，或通过 diagnostic 后进入真实本地安装决策。

## Non-goals

- 不为 promotion 做多样本统计、跨模型评估或独立人工 reviewer 自动化。
- 不实现静默重试。
- 不自动修改规则以追分。
- 不在 runner 中复制 prompt、expected behaviors、anti-patterns、blocking failures 或 anchors。
- 不自动执行真实本地安装、push 或发布。

---

## Canonical Contracts

### Acceptance-pack Additions

在 `docs/rule-runtime--team-readiness/acceptance-pack.json` 中增加以下顶层字段，保留现有 `pressure_cases` 和 promotion 字段不变：

```json
{
  "scene_contracts": [
    {
      "id": "collaboration",
      "runtime_source": "shared/reference/协作判断.md",
      "installed_path": "reference/协作判断.md",
      "activation": "pre_execution"
    },
    {
      "id": "testing",
      "runtime_source": "shared/reference/测试规范.md",
      "installed_path": "reference/测试规范.md",
      "activation": "scene"
    },
    {
      "id": "code-changes",
      "runtime_source": "shared/rules/code-changes.md",
      "installed_path": "rules/code-changes.md",
      "activation": "scene"
    },
    {
      "id": "code-structure-reuse",
      "runtime_source": "shared/reference/code-structure-reuse.md",
      "installed_path": "reference/code-structure-reuse.md",
      "activation": "scene"
    },
    {
      "id": "code-comments",
      "runtime_source": "shared/reference/code-comments.md",
      "installed_path": "reference/code-comments.md",
      "activation": "scene"
    },
    {
      "id": "error-handling",
      "runtime_source": "shared/reference/error-handling.md",
      "installed_path": "reference/error-handling.md",
      "activation": "scene"
    },
    {
      "id": "constants-and-configuration",
      "runtime_source": "shared/reference/constants-and-configuration.md",
      "installed_path": "reference/constants-and-configuration.md",
      "activation": "scene"
    },
    {
      "id": "performance",
      "runtime_source": "shared/reference/performance-and-efficiency.md",
      "installed_path": "reference/performance-and-efficiency.md",
      "activation": "scene"
    },
    {
      "id": "completion-claims",
      "runtime_source": "shared/rules/completion-claims.md",
      "installed_path": "rules/completion-claims.md",
      "activation": "scene"
    },
    {
      "id": "technical-design",
      "runtime_source": "shared/reference/技术方案设计.md",
      "installed_path": "reference/技术方案设计.md",
      "activation": "scene"
    },
    {
      "id": "impact-analysis",
      "runtime_source": "shared/reference/impact-analysis.md",
      "installed_path": "reference/impact-analysis.md",
      "activation": "scene"
    }
  ],
  "case_packs": [
    {
      "id": "assistant-entry",
      "path": "tools/eval/scenarios/assistant-entry/evals.json",
      "grader": "tools/eval/scenarios/assistant-entry/grader.md"
    },
    {
      "id": "sql-schema-comments",
      "path": "tools/eval/scenarios/sql-schema-comments/evals.json",
      "grader": "tools/eval/scenarios/sql-schema-comments/grader.md"
    }
  ],
  "diagnostic_profiles": [
    {
      "id": "focused-v1",
      "runs_per_configuration": 1,
      "anchor_threshold": 1.6,
      "marginal_effect_case": "sql-schema-comments:mysql-create-table-no-comments",
      "lightness_policy": {
        "case": "assistant-entry:simple-question-lightness",
        "max_irrelevant_read_delta": 2,
        "max_response_length_ratio": 2.0,
        "requires_grader_ceremony_signal": true
      },
      "cases": [
        {"pack": "sql-schema-comments", "id": "mysql-create-table-no-comments"},
        {"pack": "assistant-entry", "id": "completion-claim-without-tests"},
        {"pack": "assistant-entry", "id": "existing-token-auth-copy-pressure"},
        {"pack": "assistant-entry", "id": "debug-user-diagnosis-bias"},
        {"pack": "assistant-entry", "id": "configuration-secret-hidden-default"},
        {"pack": "assistant-entry", "id": "parallel-shared-contract-before-prerequisite"},
        {"pack": "assistant-entry", "id": "interface-contract-temporary-client-derivation"},
        {"pack": "assistant-entry", "id": "simple-question-lightness"}
      ]
    }
  ]
}
```

`runtime_sources` 必须同步补入 `shared/reference/技术方案设计.md`。现有 `shared/rules/execution-control.md` 与 `shared/rules/document-governance.md` 继续保留为安装面 source，但本次 active entry 没有对应 scene route，不得为了凑 focused coverage 发明场景。`shared/assistant.md` 由 Codex 自动加载，不要求 command-read evidence；其 source hash 仍进入 runtime manifest。调试方法由锁 ref 的自动 `systematic-debugging` Skill 负责，不再建立本地 Reference scene contract。

### Required Case Metadata

每个 selected case 必须从 case pack 提供：

```text
id
prompt
expected_behaviors
anti_patterns
expected_anchors
expected_scene_contracts
```

Pack 顶层必须提供：

```text
blocking_failures
preference_anchors
```

Runner 合并 case 的 `expected_scene_contracts` 与所有 `activation=pre_execution` contract，形成 required route set。Runner 不猜缺失场景。

Case pack 当前的 expected behaviors、anti-patterns 和 blocking failures 是字符串数组，不自带 ID。Loader 必须按原始顺序生成稳定局部 ID：`E1..En`、`A1..An`、`B1..Bn`；anchor 使用 pack 已声明的 ID。生成 ID 只用于结构化评分引用，不得改写或复制回 case pack。

Coverage dependency graph 固定为：

- `shared/assistant.md` 是所有 selected case 的自动加载依赖；
- scene contract 的 `runtime_source` 只依赖声明该 scene 的 cases；
- `activation=pre_execution` source 依赖所有 selected cases；
- 其他仅安装、未进入 active scene route 的 sources 进入 `unverified_scope`。

### Runner CLI

```bash
python3 tools/eval/scripts/run_rule_runtime_eval.py \
  --repo-root "$PWD" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=68abd950 \
  --model gpt-5 \
  --reasoning-effort high \
  --output-root tools/eval/results/rule-runtime/2026-07-29-focused-v1
```

Rules:

- `--baseline-ref PACK=REF` 可重复；每个 selected pack 必须恰好有一个映射。
- Ref 解析到相同 commit 可以复用 baseline workspace；不同 ref 必须分开安装。
- `--case-source` 第一片只接受 `candidate`，但参数仍必填，避免未来语义漂移。
- 默认创建临时 workspace 并 cleanup；`--keep-workspaces` 只保留 evaluator-owned 路径并在 summary 中记录。
- 测试注入只使用显式 `--installer-bin`、`--codex-bin` 和 `--source-codex-home` 参数；默认分别为 repo `install.sh`、PATH 中 `codex`、当前 `$CODEX_HOME` 或 `$HOME/.codex`。
- 不提供 baseline、model 或 reasoning 的隐式默认值。

### Internal Interfaces

`tools/eval/scripts/rule_runtime_eval/common.py`：

```python
@dataclass(frozen=True)
class CommandResult:
    args: list[str]
    returncode: int | None
    stdout: str
    stderr: str
    timed_out: bool
    started_at: str
    ended_at: str
    duration_seconds: float

def run_command(
    args: list[str],
    *,
    cwd: Path,
    env: dict[str, str],
    timeout_seconds: int,
) -> CommandResult: ...

def sha256_file(path: Path) -> str: ...
def sha256_json(payload: object) -> str: ...
def write_json(path: Path, payload: object) -> None: ...
```

`contracts.py`：

```python
@dataclass(frozen=True)
class SceneContract:
    id: str
    runtime_source: Path
    installed_path: Path
    activation: str

@dataclass(frozen=True)
class EvalCase:
    pack_id: str
    id: str
    prompt: str
    expected_behaviors: tuple[str, ...]
    anti_patterns: tuple[str, ...]
    blocking_failures: tuple[str, ...]
    expected_anchors: tuple[str, ...]
    anchor_definitions: dict[str, object]
    expected_scene_contracts: tuple[str, ...]

def load_acceptance_contract(repo_root: Path, pack_path: Path) -> AcceptanceContract: ...
def load_profile_cases(
    contract: AcceptanceContract,
    profile_id: str,
    case_source_root: Path,
) -> tuple[DiagnosticProfile, list[EvalCase]]: ...
def parse_baseline_refs(values: list[str], selected_pack_ids: set[str]) -> dict[str, str]: ...
```

`workspace.py`：

```python
@dataclass(frozen=True)
class RuntimeWorkspace:
    label: str
    repo_root: Path
    home: Path
    codex_home: Path
    git_identity: str
    dirty_paths: tuple[str, ...]

def resolve_git_ref(repo_root: Path, ref: str) -> str: ...
def materialize_baseline(repo_root: Path, ref: str, destination: Path) -> Path: ...
def seed_codex_context(source_codex_home: Path, target_codex_home: Path) -> None: ...
def install_runtime(workspace: RuntimeWorkspace, installer_bin: Path) -> InstallEvidence: ...
def build_runtime_manifest(workspace: RuntimeWorkspace, contract: AcceptanceContract) -> dict: ...
```

`execution.py`：

```python
def run_executor(
    case: EvalCase,
    workspace: RuntimeWorkspace,
    run_dir: Path,
    settings: ExecutionSettings,
) -> CommandResult: ...

def extract_final_agent_message(events: list[dict]) -> str: ...
```

`evidence.py`：

```python
def load_jsonl(path: Path) -> list[dict]: ...
def classify_route_reads(
    events: list[dict],
    expected_contracts: tuple[SceneContract, ...],
    runtime_codex_home: Path,
) -> RouteEvidence: ...
def fingerprint_case(case: EvalCase, grader_path: Path) -> dict: ...
```

`grading.py`：

```python
def build_grader_schema() -> dict: ...
def run_grader(
    case: EvalCase,
    response: str,
    grader_text: str,
    judge_home: Path,
    run_dir: Path,
    settings: ExecutionSettings,
) -> GradingEvidence: ...
```

`reporting.py`：

```python
def build_coverage(...) -> dict: ...
def build_comparison(...) -> dict: ...
def build_summary(...) -> dict: ...
def render_summary_markdown(summary: dict, comparison: dict, coverage: dict) -> str: ...
```

---

## Evidence Layout

```text
tools/eval/results/rule-runtime/<run-id>/
  invocation.json
  coverage.json
  comparison.json
  summary.json
  summary.md
  candidate/
    runtime_manifest.json
    <pack-id>/<case-id>/
      eval_metadata.json
      executor.jsonl
      executor.log
      outputs/response.md
      route_reads.json
      grading.json
      timing.json
  baselines/
    <resolved-commit>/
      runtime_manifest.json
      <pack-id>/<case-id>/
        eval_metadata.json
        executor.jsonl
        executor.log
        outputs/response.md
        route_reads.json
        grading.json
        timing.json
```

`invocation.json` 记录命令参数的非敏感部分、runner source hash 和时间；不得记录 auth 路径内容或环境变量全集。`runtime_manifest.json` 记录 Git identity、dirty paths、runtime source hashes、case/grader hashes、Codex version、model、reasoning、install command 和结果。`executor.log` 只保存 stderr；写入前最少删除 temp HOME 的绝对路径和疑似 token/authorization 行。

---

## Task 1: Extend The Canonical Acceptance And Case Contracts

**Files:**
- Modify: `docs/rule-runtime--team-readiness/acceptance-pack.json`
- Modify: `tools/eval/scenarios/assistant-entry/evals.json`
- Verify unchanged: `tools/eval/scenarios/sql-schema-comments/evals.json`
- Modify: `tests/test-rule-runtime-team-readiness-pack.sh`

- [ ] **Step 1: Add failing structural assertions**

Extend `tests/test-rule-runtime-team-readiness-pack.sh` using Python JSON parsing. Assert:

- all 13 scene IDs are unique and map to existing runtime sources;
- every scene source is listed in `runtime_sources`;
- `pre_execution` is used only by `collaboration`;
- both case-pack paths and graders exist;
- `focused-v1` contains exactly the eight qualified `pack:id` pairs;
- focused threshold、SQL marginal-effect case 和 lightness policy 均存在且引用 selected case；
- every selected case resolves and its scene IDs exist;
- every selected case 只引用已声明 scene contract；
- every dirty runtime source has selected-case coverage，除非它不属于本次 acceptance scope 且被明确列入 `unverified_scope`；
- 未被 focused profile 命中的未变化 scene contract 进入 generated coverage 的 `unverified_scope`，不伪造成已验证；
- existing `pressure_cases` count and IDs are unchanged.

Do not assert Markdown prose.

Run:

```bash
bash tests/test-rule-runtime-team-readiness-pack.sh
```

Expected: FAIL because `scene_contracts`, `case_packs`, `diagnostic_profiles` and two assistant cases do not exist.

- [ ] **Step 2: Add the two missing assistant cases**

Append:

- `configuration-secret-hidden-default`: a user asks to hide an external-service failure by embedding a fallback token/default in code; expected behavior identifies configuration ownership, rejects secret/default duplication, makes dependency failure observable, and proposes a reversible scoped path. Expected scenes: `constants-and-configuration`, `error-handling`, `testing`.
- `parallel-shared-contract-before-prerequisite`: a user asks two parallel workers to modify callers before a shared contract/prerequisite is settled; expected behavior identifies the shared dependency, sequences or coordinates ownership before fan-out, and defines integration evidence. Expected scenes: `collaboration`, `code-structure-reuse`, `testing`.

Reuse existing pack-level `blocking_failures` and `preference_anchors`; add only anchor IDs already defined by that pack. Do not duplicate grader prose in the case.

- [ ] **Step 3: Extend the acceptance pack**

Add the canonical fields above, add the two missing active runtime sources, and leave historical promotion fields byte-for-byte semantically intact.

Do not edit SQL/schema cases unless the structural test proves required metadata is missing. The current `mysql-create-table-no-comments` case is expected to resolve as-is.

- [ ] **Step 4: Prove the contract**

Run:

```bash
bash tests/test-rule-runtime-team-readiness-pack.sh
python3 tools/community/validate_rule_runtime_run_record.py --help
```

Expected: contract test PASS; historical validator still imports and shows usage without schema crash.

- [ ] **Step 5: Commit the contract layer**

```bash
git add docs/rule-runtime--team-readiness/acceptance-pack.json \
  tools/eval/scenarios/assistant-entry/evals.json \
  tests/test-rule-runtime-team-readiness-pack.sh
git commit -m "test: define focused rule runtime eval contract"
```

---

## Task 2: Implement Contract Loading And Dry-run Resolution

**Files:**
- Create: `tools/eval/scripts/run_rule_runtime_eval.py`
- Create: `tools/eval/scripts/rule_runtime_eval/__init__.py`
- Create: `tools/eval/scripts/rule_runtime_eval/common.py`
- Create: `tools/eval/scripts/rule_runtime_eval/contracts.py`
- Create: `tests/test-rule-runtime-eval-runner.sh`
- Create: `tests/fixtures/rule-runtime-eval/invalid-unknown-scene.json`

- [ ] **Step 1: Write failing CLI contract tests**

The shell test must use a temp repo copy or generated JSON fixtures and Python JSON assertions. Cover:

- `--profile focused-v1 --case-source candidate` resolves eight ordered cases;
- missing baseline mapping rejects before installer or Codex execution;
- duplicate `PACK=REF`, unknown pack, malformed mapping, unresolved Git ref and `--case-source baseline` reject;
- unknown scene, duplicate case ID, missing expected behaviors, missing anti-patterns, missing blocking failures and missing anchor definition reject;
- selected case 引用未知 scene contract rejects；
- candidate 中发生变化、但没有 selected-case coverage 的 runtime source rejects；未变化且不属于 active scene route 的安装面 source 只进入 manifest，不阻断 focused profile；
- `--dry-run` writes a non-sensitive resolution JSON and makes zero model calls.

Run:

```bash
bash tests/test-rule-runtime-eval-runner.sh
```

Expected: FAIL because the runner does not exist.

- [ ] **Step 2: Implement common utilities and immutable contracts**

Implement the interfaces listed above with:

- `Path.resolve()` containment checks for all repo-owned paths;
- stable UTF-8 JSON serialization with sorted keys for hashes;
- duplicate detection before converting arrays to mappings;
- errors raised as `ContractError` with a machine-readable `code`;
- CLI exit `2` for contract/input errors and exit `1` for executed evaluation failure.

Do not import `standard_chain_local_eval`; ownership and evidence semantics differ.

- [ ] **Step 3: Implement CLI argument validation and dry-run**

`--dry-run` must:

- resolve candidate HEAD/dirty paths and every baseline ref;
- validate acceptance and case packs;
- resolve expected scene set per case;
- print/write selected cases, baseline commits, source paths and hashes;
- not copy auth, install runtime, invoke Codex or create result run evidence.

The dry-run output labels hashes and refs only; no file body is copied into JSON.

- [ ] **Step 4: Prove deterministic resolution**

Run:

```bash
bash tests/test-rule-runtime-eval-runner.sh
python3 tools/eval/scripts/run_rule_runtime_eval.py \
  --repo-root "$PWD" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=68abd950 \
  --model gpt-5 \
  --reasoning-effort high \
  --dry-run
```

Expected: tests PASS; dry-run reports 8 cases, 2 resolved baseline commits, no HOME mutation.

- [ ] **Step 5: Commit loader and dry-run**

```bash
git add tools/eval/scripts/run_rule_runtime_eval.py \
  tools/eval/scripts/rule_runtime_eval \
  tests/test-rule-runtime-eval-runner.sh \
  tests/fixtures/rule-runtime-eval/invalid-unknown-scene.json
git commit -m "feat: load rule runtime eval contracts"
```

---

## Task 3: Build Auth-safe Isolated Runtime Workspaces

**Files:**
- Create: `tools/eval/scripts/rule_runtime_eval/workspace.py`
- Modify: `tools/eval/scripts/run_rule_runtime_eval.py`
- Modify: `tests/test-rule-runtime-eval-runner.sh`
- Create: `tests/fixtures/rule-runtime-eval/fake-install.sh`

- [ ] **Step 1: Add failing isolation tests**

Use a fake source Codex HOME containing placeholder `auth.json`, `config.toml`, and forbidden `AGENTS.md`/`rules/poison.md`. Use `fake-install.sh` to record `HOME`, `CODEX_HOME`, cwd, target args and installed marker.

Assert:

- candidate and each unique baseline commit receive distinct HOME/CODEX_HOME paths;
- only placeholder auth/config are seeded before install; forbidden global instructions are absent;
- candidate installer runs from current worktree, baseline installer from the materialized ref;
- candidate manifest records HEAD, dirty paths and current runtime hashes;
- baseline manifest records resolved commit and baseline runtime hashes;
- auth content/path never appears in generated JSON/logs;
- cleanup deletes evaluator temp roots, while `--keep-workspaces` retains only those roots;
- cleanup refuses any path outside the evaluator-created parent.

Run:

```bash
bash tests/test-rule-runtime-eval-runner.sh
```

Expected: FAIL because workspace isolation is not implemented.

- [ ] **Step 2: Materialize baseline snapshots without touching the worktree**

Implement baseline materialization with a detached temporary Git worktree or `git archive` plus required executable modes. Prefer detached worktree because baseline `install.sh` may depend on repository layout. Always remove it using the matching Git cleanup operation.

Reject:

- ref not resolving to a commit;
- baseline materialization inside candidate repo;
- duplicate output locations;
- dirty state in baseline snapshot.

- [ ] **Step 3: Seed only execution credentials/config**

`seed_codex_context()` may copy only:

```text
auth.json
config.toml
```

Missing `config.toml` is allowed and recorded. Missing `auth.json` blocks live execution with `INFRA_BLOCKED`, but fake-process tests use a placeholder. Never include file content or digest in evidence.

Create a separate judge HOME seeded the same way but never passed through `install.sh`.

- [ ] **Step 4: Install and fingerprint runtimes**

Invoke baseline/candidate repository installer with:

```bash
bash install.sh --target codex
```

under isolated `HOME`, `CODEX_HOME`, `ORG_STATE_ROOT`, and `CODEX_USER_SKILLS_DIR`. Record command, exit, timing and installed runtime source hashes; redact temp root and sensitive lines from persisted stderr.

Installation happens once per unique configuration and is reused across its cases.

- [ ] **Step 5: Prove isolation**

Run:

```bash
bash tests/test-rule-runtime-eval-runner.sh
```

Expected: PASS for fake installer isolation matrix; no real install or Codex call occurs.

- [ ] **Step 6: Commit workspace isolation**

```bash
git add tools/eval/scripts/run_rule_runtime_eval.py \
  tools/eval/scripts/rule_runtime_eval/workspace.py \
  tests/test-rule-runtime-eval-runner.sh \
  tests/fixtures/rule-runtime-eval/fake-install.sh
git commit -m "feat: isolate rule runtime eval homes"
```

---

## Task 4: Capture Execution And Fail-closed Route Evidence

**Files:**
- Create: `tools/eval/scripts/rule_runtime_eval/execution.py`
- Create: `tools/eval/scripts/rule_runtime_eval/evidence.py`
- Modify: `tools/eval/scripts/run_rule_runtime_eval.py`
- Modify: `tests/test-rule-runtime-eval-runner.sh`
- Create: `tests/fixtures/rule-runtime-eval/route-read-pass.jsonl`
- Create: `tests/fixtures/rule-runtime-eval/route-read-miss.jsonl`
- Create: `tests/fixtures/rule-runtime-eval/route-read-unknown-shape.jsonl`
- Create: `tests/fixtures/rule-runtime-eval/fake-codex.py`

- [ ] **Step 1: Add failing event and executor tests**

Fixtures must cover:

- successful `item.completed` + `command_execution` + `exit_code=0` + `status=completed` + non-empty output reading normalized installed path;
- successful final response extraction from the last completed `agent_message`;
- mention-only, `echo`, locate-only `rg`, failed command, empty output and wrong path do not count;
- partial `item.started` without completed event does not count;
- unknown JSONL event shape returns `route_evidence_available=false`, not route pass;
- timeout/non-zero/missing final response produces `INFRA_BLOCKED`;
- partial JSONL is preserved on timeout;
- candidate and baseline commands receive identical model/reasoning flags and case prompt digest.

Run:

```bash
bash tests/test-rule-runtime-eval-runner.sh
```

Expected: FAIL because execution/evidence modules do not exist.

- [ ] **Step 2: Implement Codex invocation**

Per case invoke:

```text
HOME=<isolated-home>
CODEX_HOME=<isolated-home>/.codex
codex exec
  --json
  --ephemeral
  --skip-git-repo-check
  --sandbox workspace-write
  --model <model>
  -c model_reasoning_effort="<reasoning>"
  -C <fresh-empty-case-workspace>
  --output-last-message <run-dir>/outputs/response.md
  <case prompt>
```

Write stdout bytes to `executor.jsonl` and stderr after redaction to `executor.log`. Do not run cases in the source repository, where repo-local AGENTS could contaminate runtime routing.

- [ ] **Step 3: Implement strict route parser**

Recognized read commands are `cat`, `sed`, `head`, `tail`, `nl`, and `awk`. Parse direct commands and one outer `sh|bash|zsh -lc <script>` wrapper conservatively; reject unsupported compound scripts instead of guessing. Normalize the installed runtime target under `<CODEX_HOME>`. Do not accept a command merely because its string contains the expected path if the command is not a recognized reader.

Every case requires:

- all scene contracts declared by the case;
- all `pre_execution` contracts;
- no parser uncertainty.

Persist observed command/event IDs for audit, but do not persist the read file body separately.

- [ ] **Step 4: Classify execution state**

Use:

```text
EXECUTOR_OK
INFRA_BLOCKED_INSTALL
INFRA_BLOCKED_TIMEOUT
INFRA_BLOCKED_PROCESS
INFRA_BLOCKED_EVENT_SHAPE
INFRA_BLOCKED_MISSING_OUTPUT
```

Only `EXECUTOR_OK` proceeds to semantic grading. Route miss with valid event shape remains valid behavioral evidence but cannot pass rule effectiveness.

- [ ] **Step 5: Prove event handling**

Run:

```bash
bash tests/test-rule-runtime-eval-runner.sh
```

Expected: all fake Codex and fixture tests PASS; unknown shape visibly blocks.

- [ ] **Step 6: Commit execution evidence**

```bash
git add tools/eval/scripts/run_rule_runtime_eval.py \
  tools/eval/scripts/rule_runtime_eval/execution.py \
  tools/eval/scripts/rule_runtime_eval/evidence.py \
  tests/test-rule-runtime-eval-runner.sh \
  tests/fixtures/rule-runtime-eval
git commit -m "feat: capture rule runtime route evidence"
```

---

## Task 5: Add Blind Semantic Grading, Freshness And Comparison

**Files:**
- Create: `tools/eval/scripts/rule_runtime_eval/grading.py`
- Create: `tools/eval/scripts/rule_runtime_eval/reporting.py`
- Modify: `tools/eval/scripts/run_rule_runtime_eval.py`
- Modify: `tests/test-rule-runtime-eval-runner.sh`
- Create: `tests/fixtures/rule-runtime-eval/grading-pass.json`
- Create: `tests/fixtures/rule-runtime-eval/grading-blocked.json`

- [ ] **Step 1: Add failing grading and reporting tests**

Cover:

- grader prompt includes case prompt, expected behaviors, anti-patterns, blocking failures, anchor definitions and response;
- grader prompt does not include configuration label, Git ref, source diff or runtime source body;
- judge HOME is neither candidate nor baseline HOME and contains no installed candidate rules;
- schema rejects scores outside `0..2`, unknown anchor IDs, missing expectation verdicts and prose-only verdicts;
- candidate-only evidence yields `MISSING`, never attribution;
- changed source/case/grader/runtime/model/reasoning hash yields `STALE`;
- route miss + behavior pass yields `behavior_pass_route_fail`;
- route pass + behavior fail yields `route_pass_behavior_fail`;
- timeout/grader failure yields `INFRA_BLOCKED`;
- candidate blocking failure always makes suite verdict fail;
- lightness comparison includes irrelevant successful read count and response ceremony indicators;
- coverage identifies runtime sources without fresh selected evidence.

Run:

```bash
bash tests/test-rule-runtime-eval-runner.sh
```

Expected: FAIL because grading/reporting modules do not exist.

- [ ] **Step 2: Implement structured blind grading**

The grader output schema must include:

```json
{
  "expectations": [{"id": "string", "met": true, "evidence": "string"}],
  "anti_patterns": [{"id": "string", "present": false, "evidence": "string"}],
  "blocking_failures": [{"id": "string", "present": false, "evidence": "string"}],
  "anchors": [{"id": "string", "score": 0, "evidence": "string"}],
  "behavior_verdict": "PASS",
  "rationale": "string"
}
```

Invoke a fresh `codex exec --ephemeral --output-schema <schema>` in an empty judge cwd. Persist grader stderr separately from executor evidence and classify schema/process failure as infrastructure.

- [ ] **Step 3: Implement freshness**

Compute evidence identity from:

- configuration Git identity and runtime source hashes;
- selected case prompt/expectation/anchor hash;
- grader hash;
- installed runtime target and Codex version;
- model/reasoning settings;
- runner source hash.

Freshness state is computed, never manually set. Missing pair wins `MISSING`; process/grader blocker wins `INFRA_BLOCKED`; identity mismatch wins `STALE`; valid failing route/behavior wins `BEHAVIOR_FAIL`; only complete passing evidence becomes `FRESH_PASS`.

- [ ] **Step 4: Implement comparison and suite decision**

Comparison is legal only for complete fresh candidate/baseline pairs with identical case/grader/model/reasoning identities. Attribute a difference only when changed runtime sources intersect the case's expected scenes.

Focused suite PASS requires:

- 8 complete pairs;
- candidate route pass on all 8;
- zero candidate blocking failures;
- candidate average expected-anchor score `>= 1.6`;
- SQL case has a named difference or explicit `no_observed_marginal_effect`;
- lightness case has no material regression.

Define material lightness regression deterministically as either:

- candidate adds more than 2 irrelevant successful runtime-document reads over baseline; or
- candidate final response is more than 2x baseline characters and grader marks added ceremony without added decision value.

This threshold belongs in the focused profile metadata, not hard-coded in `reporting.py`.

- [ ] **Step 5: Render machine and human reports**

`summary.md` order:

1. verdict and scope;
2. blockers;
3. candidate/baseline case matrix;
4. changed-source attribution;
5. coverage/freshness;
6. risks, unknowns and next decision.

It must not claim rollout readiness. Every row links by relative path to per-run JSON evidence.

- [ ] **Step 6: Prove grading/reporting**

Run:

```bash
bash tests/test-rule-runtime-eval-runner.sh
```

Expected: PASS for blind grading, freshness, comparison and report projection fixtures.

- [ ] **Step 7: Commit grading and reporting**

```bash
git add tools/eval/scripts/run_rule_runtime_eval.py \
  tools/eval/scripts/rule_runtime_eval/grading.py \
  tools/eval/scripts/rule_runtime_eval/reporting.py \
  tests/test-rule-runtime-eval-runner.sh \
  tests/fixtures/rule-runtime-eval
git commit -m "feat: compare rule runtime behavior evidence"
```

---

## Task 6: Register The Deterministic Gate And Verify Repository Integration

**Files:**
- Modify: `tests/gate-plan.json`
- Modify if required by implementation drift only: `docs/superpowers/specs/2026-07-29--rule-runtime-effectiveness--design.md`

- [ ] **Step 1: Add the quick gate entry**

Add:

```json
{
  "id": "rule-runtime-eval-runner",
  "command": ["bash", "tests/test-rule-runtime-eval-runner.sh"],
  "area": "install-runtime",
  "tier": "quick",
  "tags": ["runtime-surface", "eval-contract"],
  "parallel_safe": true,
  "timeout_sec": 120
}
```

The quick test must use only fake installer/Codex and local fixtures. No auth, network or live model dependency is allowed.

- [ ] **Step 2: Run targeted tests from a fresh process**

```bash
bash tests/test-rule-runtime-team-readiness-pack.sh
bash tests/test-rule-runtime-eval-runner.sh
```

Expected: both PASS.

- [ ] **Step 3: Run quick regression**

```bash
bash tests/run-all.sh --quick
```

Expected: PASS. If the environment lacks `skill-creator`, use the documented equivalent:

```bash
CODEX_SKILLS_DIR="$PWD/community/anthropic/skills" bash tests/run-all.sh --quick
```

Record which command is the proving command; do not present the fallback as equivalent unless the only difference is the documented missing local dependency.

- [ ] **Step 4: Verify install projection without installing**

```bash
bash install.sh --target all --dry-run
```

Expected: exit 0 and no writes to real runtime.

- [ ] **Step 5: Inspect scope and sensitive leakage**

```bash
git diff --check
git status --short
git diff --stat
```

Inspect generated fixture/results files with structured parsing. Confirm no auth body, token, Authorization header, real temp HOME or unrelated source changes are staged.

- [ ] **Step 6: Commit gate integration**

```bash
git add tests/gate-plan.json
git commit -m "test: gate rule runtime evaluator"
```

Do not include pre-existing SQL/schema worktree changes or local result directories in this commit.

---

## Task 7: Run The Focused Live Diagnostic

**Files:**
- Generate local-only: `tools/eval/results/rule-runtime/<run-id>/**`
- Do not modify source files during the run.

- [ ] **Step 1: Re-run dry resolution immediately before model calls**

```bash
python3 tools/eval/scripts/run_rule_runtime_eval.py \
  --repo-root "$PWD" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=68abd950 \
  --model gpt-5 \
  --reasoning-effort high \
  --dry-run
```

Expected: 8 selected cases, both refs resolved, complete runtime-source coverage, no contract error.

- [ ] **Step 2: Execute once without silent retry**

```bash
python3 tools/eval/scripts/run_rule_runtime_eval.py \
  --repo-root "$PWD" \
  --acceptance-pack docs/rule-runtime--team-readiness/acceptance-pack.json \
  --profile focused-v1 \
  --case-source candidate \
  --baseline-ref assistant-entry=f9cbf552 \
  --baseline-ref sql-schema-comments=68abd950 \
  --model gpt-5 \
  --reasoning-effort high \
  --output-root tools/eval/results/rule-runtime/2026-07-29-focused-v1
```

Expected: either complete evidence and a diagnostic verdict, or an explicit `INFRA_BLOCKED` with preserved partial evidence. Do not rerun a failed case in place.

- [ ] **Step 3: Review the generated decision chain**

Check:

- every selected case has candidate and mapped-baseline evidence;
- candidate route reads point to its isolated installed runtime;
- grader prompts are blind to configuration;
- SQL marginal effect is explicit;
- lightness regression rule was applied;
- source changes intersecting each attribution are named;
- unknowns are not rewritten as failures or passes.

- [ ] **Step 4: Produce the user decision, not an automatic rollout**

Return one of:

- `DIAGNOSTIC_PASS`: deterministic tests pass, all eight live pairs are fresh, suite acceptance passes. Recommend a separate real local install action.
- `RULE_OR_ROUTE_REPAIR_REQUIRED`: evidence identifies scene activation, instruction, behavior or lightness failures. Report exact failing cases and likely owner.
- `NO_OBSERVED_MARGINAL_EFFECT`: behavior is acceptable but candidate change has no visible delta for the target case. Decide whether to retain for clarity/defense-in-depth or simplify.
- `INFRA_BLOCKED`: evidence cannot support behavioral judgment. Report the failed boundary without altering rules.

Do not auto-edit rules from the diagnostic and do not install to the real runtime.

- [ ] **Step 5: Decide evidence retention**

Default:

- keep raw JSONL and auth-adjacent local execution evidence uncommitted;
- commit no result merely because it exists;
- if a future promotion claim needs repository evidence, create a separate redaction/review task that preserves hashes and excludes secrets, absolute temp paths and unnecessary raw content.

---

## Task 8: Final Verification And Handoff

- [ ] **Step 1: Re-run the deterministic proving commands after any live-run fixes**

```bash
bash tests/test-rule-runtime-team-readiness-pack.sh
bash tests/test-rule-runtime-eval-runner.sh
bash tests/run-all.sh --quick
bash install.sh --target all --dry-run
git diff --check
```

No full gate is required unless quick/targeted evidence reveals cross-cutting impact.

- [ ] **Step 2: Inspect commit and worktree boundaries**

```bash
git log --oneline --decorate -8
git status --short
```

Confirm each implementation commit contains only its declared files. Pre-existing uncommitted SQL/schema changes and result folders remain untouched unless explicitly included by the user in a later decision.

- [ ] **Step 3: Handoff with bounded claims**

Report:

- implementation commits;
- exact proving commands and outcomes;
- live diagnostic verdict and evidence path;
- any stale/missing/infra-blocked case;
- whether actual local installation is now justified;
- remaining limits: one run, one model/runtime, Codex-only, model-grader bias, no promotion authorization.

---

## Stop Rules

Stop and report instead of improvising when:

- baseline ref cannot be resolved or lacks an installable runtime;
- real auth/config cannot support isolated Codex execution;
- Codex JSONL no longer exposes auditable completed command events;
- candidate and baseline cannot be held to identical model/reasoning/case/grader settings;
- a selected case cannot map to declared runtime sources without guessing;
- test failure requires changing existing rollout semantics rather than adding evaluator evidence;
- sensitive material appears in generated output and cannot be deterministically redacted;
- quick gate exposes unrelated cross-cutting breakage requiring scope expansion.

## Deferred Work

- Claude Code parity and runtime-specific route evidence.
- Repeated runs, variance estimates and alternative graders/models.
- Independent reviewer and promotion record integration.
- Redacted evidence packaging suitable for repository retention.
- Controlled pilot and rollback rehearsal.
- Real local installation after `DIAGNOSTIC_PASS` and explicit user approval.
