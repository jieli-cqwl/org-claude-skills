# Gstack Systematic Rebenchmark V2.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a trusted, evidence-backed benchmark of `garrytan/gstack` as an agent operating system, not merely as a skill bundle or QA/browser tool.

**Architecture:** Execute a read-only audit in four gates: full upstream inventory, inventory-derived ontology, current-repo independent capability map, and red-team synthesis review. The executor must inventory both `SKILL.md` files and non-skill runtime/tooling assets before drawing conclusions. Every agent-team output is persisted under `/tmp/gstack-agent-outputs/` so the final report is auditable.

**Tech Stack:** Markdown report, Python stdlib inventory scripts, `git`, `find`, `rg`, `curl`, `npx skills`, optional Claude Code subagents, current repository contracts under `contracts/`, first-party skills under `shared/skills/`, community mirrors under `community/`, test gates under `tests/`, and external upstream evidence from GitHub/skills.sh.

## Success Criteria

- Create `docs/reports/gstack-systematic-rebenchmark-2026-05-26.md`.
- Create these non-repo evidence files:
  - `/tmp/gstack-systematic-benchmark-2026-05-26/`
  - `/tmp/gstack-skills-find.txt`
  - `/tmp/gstack-skills-page.html`
  - `/tmp/gstack-github-repo.json`
  - `/tmp/gstack-skill-inventory.json`
  - `/tmp/gstack-skill-inventory.md`
  - `/tmp/gstack-runtime-inventory.json`
  - `/tmp/gstack-runtime-inventory.md`
  - `/tmp/gstack-ontology-input.md`
  - `/tmp/gstack-agent-outputs/*.md`
- The final report includes every upstream `SKILL.md` path in `附录 A`.
- The final report includes every required runtime/tooling asset group in `附录 B`, including nested `docs/**` and `lib/**` files.
- The final report derives `gstack` capability categories from inventory before comparing with this repository.
- The final report treats these as hypotheses to test, not conclusions to force:
  - `gstack` may be most valuable in the front half.
  - `gstack` may be valuable because it behaves like an agent operating system.
  - Direct runtime integration may be unsafe while mechanism adoption remains valuable.
- The final report separately analyzes:
  - Front half: demand clarification, office hours, CEO/founder review, scope ambition, question quality.
  - Middle system: plan review, design review, engineering review, DX review, anti-false-completion.
  - Back half: implementation support, browser QA, shipping, canary, security, learning, context restore.
  - Runtime layer: `bin/`, `hosts/`, extension, gbrain, telemetry, config, upgrade, routing, package scripts.
- Every recommendation is classified as `Adopt`, `Adapt`, `Isolate`, `Reject`, or `Reference only`.
- Every major recommendation cites upstream evidence and current-repo evidence, or explicitly says no current analog exists.
- Red-team output identifies remaining uncertainty and either clears or blocks report completion.
- No implementation files, contracts, runtime surface, community sources, tests, or install scripts are modified.

## Non-Goals

- Do not install `gstack`.
- Do not run upstream setup, browser runtime, telemetry, sync, upgrade, routing injection, or commit scripts.
- Do not add `gstack` to `community/SOURCES.yaml`.
- Do not edit `contracts/skill-runtime-surface.json`.
- Do not modify `shared/skills/**`, `community/**`, `tests/**`, `install.sh`, or `README.md`.
- Do not claim QA/browser is the main value unless the evidence supports it.
- Do not claim front-half product work is the main value unless the evidence supports it.
- Do not reject valuable mechanisms solely because direct installation has risk.

## Required Context To Load First

- `/Users/lijieli/org-claude-skills/AGENTS.md`
- Every file under `/Users/lijieli/.codex/rules/`
- `/Users/lijieli/.codex/reference/协作判断.md`
- `/Users/lijieli/.codex/reference/测试规范.md`
- `/Users/lijieli/.codex/reference/代码复用.md`
- `/Users/lijieli/.codex/reference/设计原则.md`
- `/Users/lijieli/.codex/reference/影响范围分析.md`
- `/Users/lijieli/.codex/reference/代码质量.md`
- `/Users/lijieli/.codex/reference/完成前验证.md`
- `/Users/lijieli/.agents/skills/dispatching-parallel-agents/SKILL.md`
- `/Users/lijieli/.agents/skills/research/SKILL.md`
- `/Users/lijieli/.agents/skills/overview/SKILL.md`

If any required file is unreadable, stop and report the exact missing path.

## Current-Repo Evidence To Read

- `README.md`
- `AGENTS.md`
- `contracts/standard-chain.yaml`
- `contracts/skill-runtime-surface.json`
- `contracts/superpowers-boundary.yaml`
- `contracts/episode-package.schema.json`
- `community/SOURCES.yaml`
- `shared/skills/product-director/SKILL.md`
- `shared/skills/product-manager/SKILL.md`
- `shared/skills/design/SKILL.md`
- `shared/skills/test-design/SKILL.md`
- `shared/skills/developer/SKILL.md`
- `shared/skills/review/SKILL.md`
- `shared/skills/qa/SKILL.md`
- `shared/skills/qa/contracts/qa-result.schema.json`
- `shared/skills/qa/references/e2e-journey-methodology.md`
- `shared/skills/security/SKILL.md`
- `shared/skills/security/references/security-rules.md`
- `shared/skills/delivery-owner/SKILL.md`
- `community/vercel/skills/agent-browser/SKILL.md`
- `community/skills-sh/skills/bb-browser/SKILL.md`
- `tests/gate-plan.json`
- `tests/run-all.sh`
- `tests/test-qa-browser-gate-contract.sh`
- `docs/reports/standard-chain-harness-audit-2026-05-24.md`
- `docs/reports/standard-chain-harness-capability-matrix-2026-05-24.md`
- `docs/reports/standard-chain-harness-p2-capability-eval-2026-05-25.md`
- `docs/feature--quanfangtong-homepage-entry-center/worklog.md`
- `docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage/capture-manifest.json`

---

## Task 1: Preflight And Scope Lock

**Files:**
- Read only

- [ ] **Step 1: Announce stance**

Use this exact opening:

```text
执行 gstack systematic rebenchmark v2.1：先全量 inventory，再从 gstack 自身归纳 ontology，再做本仓对照。本轮不安装、不接入、不改能力实现。
```

- [ ] **Step 2: Check repository state**

Run:

```bash
git status --short
git branch --show-current
```

Expected:
- Branch prints successfully.
- Existing dirty files may exist. Record them as pre-existing and do not revert them.

- [ ] **Step 3: Load required rules and references**

Run the required context reads listed above. If any file is missing or unreadable, stop.

## Task 2: Acquire External Evidence Without Running Upstream Code

**Files:**
- Create outside repo under `/tmp`

- [ ] **Step 1: Capture public signals**

Run:

```bash
npx skills find gstack | tee /tmp/gstack-skills-find.txt
curl -L --fail --silent https://skills.sh/garrytan/gstack/gstack -o /tmp/gstack-skills-page.html
curl -L --fail --silent https://api.github.com/repos/garrytan/gstack -o /tmp/gstack-github-repo.json
python3 - <<'PY'
from pathlib import Path
for raw in [
    "/tmp/gstack-skills-find.txt",
    "/tmp/gstack-skills-page.html",
    "/tmp/gstack-github-repo.json",
]:
    path = Path(raw)
    if not path.exists() or path.stat().st_size == 0:
        raise SystemExit(f"missing external evidence: {raw}")
print("external evidence captured")
PY
```

Expected: `external evidence captured`.

- [ ] **Step 2: Clone upstream read-only**

Run:

```bash
rm -rf /tmp/gstack-systematic-benchmark-2026-05-26
git clone --filter=blob:none --depth 1 https://github.com/garrytan/gstack /tmp/gstack-systematic-benchmark-2026-05-26
git -C /tmp/gstack-systematic-benchmark-2026-05-26 rev-parse HEAD
```

Expected:
- Clone succeeds.
- Commit hash prints.
- Do not run any upstream executable.

## Task 3: Build Skill Inventory

**Files:**
- Create: `/tmp/gstack-skill-inventory.json`
- Create: `/tmp/gstack-skill-inventory.md`
- Create: `/tmp/gstack-ontology-input.md`

- [ ] **Step 1: Generate `SKILL.md` inventory**

Run:

```bash
find /tmp/gstack-systematic-benchmark-2026-05-26 -name SKILL.md | sort > /tmp/gstack-skill-paths.txt
python3 - <<'PY'
from pathlib import Path
import json
import re

root = Path("/tmp/gstack-systematic-benchmark-2026-05-26")

def frontmatter(text):
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}, text
    end = None
    for index in range(1, len(lines)):
        if lines[index].strip() == "---":
            end = index
            break
    if end is None:
        return {}, text
    raw = "\n".join(lines[1:end])
    body = "\n".join(lines[end + 1:])
    data = {}
    current = None
    for line in raw.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if re.match(r"^[A-Za-z0-9_-]+:", line):
            key, value = line.split(":", 1)
            current = key.strip()
            data[current] = value.strip().strip('"') if value.strip() else []
            continue
        if current and line.strip().startswith("- "):
            if not isinstance(data.get(current), list):
                data[current] = [data[current]]
            data[current].append(line.strip()[2:].strip().strip('"'))
    return data, body

def found(pattern, text):
    return bool(re.search(pattern, text, re.I | re.M))

items = []
for path in sorted(root.rglob("SKILL.md")):
    rel = path.relative_to(root).as_posix()
    text = path.read_text(encoding="utf-8", errors="replace")
    fm, body = frontmatter(text)
    allowed = fm.get("allowed-tools", fm.get("allowed_tools", []))
    if isinstance(allowed, str):
        allowed = [allowed]
    item = {
        "path": rel,
        "dir": str(Path(rel).parent),
        "name": fm.get("name", ""),
        "description": fm.get("description", ""),
        "triggers": fm.get("triggers", []),
        "benefits_from": fm.get("benefits-from", fm.get("benefits_from", [])),
        "allowed_tools": allowed,
        "has_write_tool": any(tool in {"Write", "Edit", "MultiEdit"} for tool in allowed),
        "writes_gstack_state": found(r"~/.gstack|GSTACK_HOME|gstack-config set|gstack-.*log|gstack-brain|gstack-learnings", text),
        "modifies_repo": found(r"git add|git commit|git rm|CLAUDE\.md|TODOS\.md|\.gitignore|write.*plan|edit.*plan", text),
        "auto_commits": found(r"git commit|checkpoint.*commit|auto-commit|continuous checkpoint", text),
        "network_or_sync_behavior": found(r"curl |WebSearch|telemetry|sync|remote|GitHub|gbrain|artifacts_sync|fetch origin|push", text),
        "uses_browser": found(r"browse|browser|screenshot|CDP|Chrome|Playwright", text),
        "uses_questions": found(r"AskUserQuestion|question tuning|D<N>|one issue|decision brief", text),
        "produces_artifact": found(r"design doc|report|plan|artifact|jsonl|ceo-plans|review-log|timeline-log", text),
        "front_half_signals": found(r"office hours|demand|founder|CEO|scope|wedge|status quo|premise|10x|platonic|ambition|question", text),
        "middle_signals": found(r"plan review|architecture|design review|devex|anti-shortcut|confidence|outside voice|implementation alternatives", text),
        "back_half_signals": found(r"QA|ship|deploy|canary|benchmark|learn|retro|context-save|context-restore|investigate", text),
        "headings": [title for _, title in re.findall(r"^(#{1,3})\s+(.+)$", body, flags=re.M)[:30]],
    }
    items.append(item)

Path("/tmp/gstack-skill-inventory.json").write_text(json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8")

lines = [
    "# gstack skill inventory",
    "",
    f"Total SKILL.md files: {len(items)}",
    "",
    "| # | Path | Name | Front | Middle | Back | Questions | Browser | Write Tool | Writes State | Modifies Repo | Auto Commit | Network/Sync | Artifact |",
    "|---:|---|---|---|---|---|---|---|---|---|---|---|---|---|",
]
for index, item in enumerate(items, 1):
    def mark(key):
        return "yes" if item[key] else "no"
    lines.append(
        f"| {index} | `{item['path']}` | `{item['name']}` | {mark('front_half_signals')} | {mark('middle_signals')} | {mark('back_half_signals')} | {mark('uses_questions')} | {mark('uses_browser')} | {mark('has_write_tool')} | {mark('writes_gstack_state')} | {mark('modifies_repo')} | {mark('auto_commits')} | {mark('network_or_sync_behavior')} | {mark('produces_artifact')} |"
    )
Path("/tmp/gstack-skill-inventory.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

ontology = ["# gstack ontology input", ""]
for item in items:
    ontology.append(f"## {item['path']}")
    ontology.append(f"- name: {item['name']}")
    ontology.append(f"- description: {item['description']}")
    ontology.append(f"- triggers: {item['triggers']}")
    ontology.append(f"- allowed_tools: {item['allowed_tools']}")
    ontology.append(f"- flags: front={item['front_half_signals']}, middle={item['middle_signals']}, back={item['back_half_signals']}, questions={item['uses_questions']}, browser={item['uses_browser']}, write_tool={item['has_write_tool']}, writes_state={item['writes_gstack_state']}, modifies_repo={item['modifies_repo']}, auto_commits={item['auto_commits']}, network_sync={item['network_or_sync_behavior']}, artifact={item['produces_artifact']}")
    for heading in item["headings"][:14]:
        ontology.append(f"  - {heading}")
    ontology.append("")
Path("/tmp/gstack-ontology-input.md").write_text("\n".join(ontology), encoding="utf-8")

print(f"skill_inventory_count={len(items)}")
PY
```

Expected: `skill_inventory_count=N`.

- [ ] **Step 2: Verify skill inventory coverage**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
import json

paths = [Path(raw).relative_to("/tmp/gstack-systematic-benchmark-2026-05-26").as_posix() for raw in Path("/tmp/gstack-skill-paths.txt").read_text().splitlines() if raw.strip()]
items = json.loads(Path("/tmp/gstack-skill-inventory.json").read_text(encoding="utf-8"))
seen = {item["path"] for item in items}
missing = sorted(set(paths) - seen)
extra = sorted(seen - set(paths))
if missing or extra:
    raise SystemExit(f"skill inventory mismatch\nmissing={missing}\nextra={extra}")
print(f"skill inventory coverage ok: {len(items)}")
PY
```

Expected: `skill inventory coverage ok: N`.

## Task 4: Build Runtime And Tooling Inventory

**Files:**
- Create: `/tmp/gstack-runtime-inventory.json`
- Create: `/tmp/gstack-runtime-inventory.md`

- [ ] **Step 1: Generate runtime/tooling inventory**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
import json
import re

root = Path("/tmp/gstack-systematic-benchmark-2026-05-26")
patterns = [
    "bin/*",
    "hosts/*",
    "extension/*",
    "docs/**/*.md",
    "lib/*",
    "model-overlays/*.md",
    "agents/openai.yaml",
    "package.json",
    "conductor.json",
    "BROWSER.md",
    "ARCHITECTURE.md",
    "DESIGN.md",
    "ETHOS.md",
    "USING_GBRAIN_WITH_GSTACK.md",
    "README.md",
    "SKILL.md",
]

def found(pattern, text):
    return bool(re.search(pattern, text, re.I | re.M))

files = []
for pattern in patterns:
    for path in root.glob(pattern):
        if path.is_file():
            rel = path.relative_to(root).as_posix()
            text = path.read_text(encoding="utf-8", errors="replace")
            files.append({
                "path": rel,
                "group": rel.split("/", 1)[0],
                "bytes": path.stat().st_size,
                "mentions_telemetry": found(r"telemetry|analytics|skill-usage", text),
                "mentions_sync_or_remote": found(r"sync|remote|gbrain|GitHub|artifacts|fetch|push", text),
                "mentions_browser_runtime": found(r"browser|CDP|Chrome|extension|screenshot|Playwright", text),
                "mentions_host_integration": found(r"claude|codex|cursor|opencode|host|mcp", text),
                "mentions_update_or_install": found(r"install|upgrade|update|setup|uninstall", text),
                "mentions_repo_mutation": found(r"git add|git commit|git rm|CLAUDE\.md|\.gitignore|TODOS\.md", text),
                "mentions_security": found(r"security|permission|allowlist|secret|token|trust|sandbox", text),
            })

deduped = {item["path"]: item for item in files}
items = [deduped[path] for path in sorted(deduped)]
Path("/tmp/gstack-runtime-inventory.json").write_text(json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8")

lines = [
    "# gstack runtime/tooling inventory",
    "",
    f"Total runtime/tooling files: {len(items)}",
    "",
    "| # | Path | Group | Telemetry | Sync/Remote | Browser Runtime | Host Integration | Update/Install | Repo Mutation | Security |",
    "|---:|---|---|---|---|---|---|---|---|---|",
]
for index, item in enumerate(items, 1):
    def mark(key):
        return "yes" if item[key] else "no"
    lines.append(
        f"| {index} | `{item['path']}` | `{item['group']}` | {mark('mentions_telemetry')} | {mark('mentions_sync_or_remote')} | {mark('mentions_browser_runtime')} | {mark('mentions_host_integration')} | {mark('mentions_update_or_install')} | {mark('mentions_repo_mutation')} | {mark('mentions_security')} |"
    )
Path("/tmp/gstack-runtime-inventory.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"runtime_inventory_count={len(items)}")
PY
```

Expected: `runtime_inventory_count=N`.

- [ ] **Step 2: Verify required runtime groups exist or are explicitly absent**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
import json

items = json.loads(Path("/tmp/gstack-runtime-inventory.json").read_text(encoding="utf-8"))
paths = {item["path"] for item in items}
required_any = {
    "bin": lambda p: p.startswith("bin/"),
    "hosts": lambda p: p.startswith("hosts/"),
    "extension": lambda p: p.startswith("extension/"),
    "docs": lambda p: p.startswith("docs/"),
    "lib": lambda p: p.startswith("lib/"),
    "agents": lambda p: p == "agents/openai.yaml",
    "package": lambda p: p == "package.json",
    "root-docs": lambda p: p in {"README.md", "ARCHITECTURE.md", "BROWSER.md", "DESIGN.md", "ETHOS.md"},
}
missing = [name for name, predicate in required_any.items() if not any(predicate(path) for path in paths)]
if missing:
    raise SystemExit("runtime inventory missing groups: " + ", ".join(missing))
print(f"runtime group coverage ok: {len(items)} files")
PY
```

Expected: `runtime group coverage ok: N files`.

## Task 5: Dispatch Agent Team And Persist Outputs

**Files:**
- Create: `/tmp/gstack-agent-outputs/*.md`

- [ ] **Step 1: Prepare output directory**

Run:

```bash
rm -rf /tmp/gstack-agent-outputs
mkdir -p /tmp/gstack-agent-outputs
```

Expected: directory exists.

If subagent tooling is unavailable, perform the same role sequentially in the current session and still save each role's output to the specified file.

For every role below, persist the response with this pattern:

```bash
cat > /tmp/gstack-agent-outputs/<role-file>.md <<'EOF_AGENT_OUTPUT'
<paste the role output verbatim>
EOF_AGENT_OUTPUT
```

Do not save summaries in these files. Save the actual role output so the final report can be audited against source agent judgments.

- [ ] **Step 2: Dispatch Inventory Auditor**

Prompt:

```text
You are the Inventory Auditor.

Inputs:
- /tmp/gstack-skill-inventory.json
- /tmp/gstack-runtime-inventory.json
- /tmp/gstack-skill-inventory.md
- /tmp/gstack-runtime-inventory.md
- Upstream repo: /tmp/gstack-systematic-benchmark-2026-05-26

Task:
Verify inventory quality. Do not compare to the current repo. Do not modify files.

Required output:
1. PASS/FAIL for skill inventory coverage.
2. PASS/FAIL for runtime/tooling group coverage.
3. Misclassified or ambiguous inventory flags.
4. High-value upstream files requiring deep reading.
5. Runtime files that likely affect integration risk.
6. Evidence paths.
```

Persist verbatim output to `/tmp/gstack-agent-outputs/01-inventory-auditor.md`.

- [ ] **Step 3: Dispatch Ontology Agent**

Prompt:

```text
You are the Ontology Agent.

Inputs:
- /tmp/gstack-skill-inventory.json
- /tmp/gstack-runtime-inventory.json
- /tmp/gstack-ontology-input.md
- Upstream repo: /tmp/gstack-systematic-benchmark-2026-05-26

Task:
Derive gstack's capability ontology from the inventories. Do not start from current-repo categories. Do not modify files.

Required output:
1. Primary capability categories.
2. Every skill path assigned to exactly one primary category.
3. Optional secondary categories.
4. Runtime/tooling assets mapped to the relevant categories.
5. What the ontology suggests about gstack's real product shape.
6. Evidence paths.
```

Persist verbatim output to `/tmp/gstack-agent-outputs/02-ontology.md`.

- [ ] **Step 4: Dispatch Community Value Agent**

Prompt:

```text
You are the Community Value Agent.

Inputs:
- /tmp/gstack-skills-find.txt
- /tmp/gstack-skills-page.html
- /tmp/gstack-github-repo.json
- /tmp/gstack-skill-inventory.json
- /tmp/gstack-runtime-inventory.json
- Upstream repo: /tmp/gstack-systematic-benchmark-2026-05-26

Task:
Explain why friends/community might strongly recommend gstack. Treat front-half value as a hypothesis to test, not a conclusion to prove. Do not modify files.

Required output:
1. Community/adoption signals.
2. User-perceived value hypotheses.
3. Evidence for front-half value.
4. Evidence for middle-system value.
5. Evidence for back-half value.
6. Evidence for runtime/agent-OS value.
7. Hype, survivorship, or adoption-risk caveats.
```

Persist verbatim output to `/tmp/gstack-agent-outputs/03-community-value.md`.

- [ ] **Step 5: Dispatch Front-Half Agent**

Prompt:

```text
You are the Front-Half Agent.

Inputs:
- Upstream repo: /tmp/gstack-systematic-benchmark-2026-05-26
- Current repo: /Users/lijieli/org-claude-skills

Task:
Deeply compare front-half demand clarification and CEO/founder review. Do not modify files.

Read upstream:
- office-hours/SKILL.md
- plan-ceo-review/SKILL.md
- autoplan/SKILL.md
- plan-tune/SKILL.md
- plan-eng-review/SKILL.md
- plan-design-review/SKILL.md
- plan-devex-review/SKILL.md

Read current repo:
- contracts/standard-chain.yaml
- shared/skills/product-director/SKILL.md
- shared/skills/product-manager/SKILL.md
- shared/skills/design/SKILL.md
- shared/skills/test-design/SKILL.md
- docs/reports/standard-chain-harness-capability-matrix-2026-05-24.md

Required output:
1. What office-hours does beyond brainstorming.
2. How six forcing questions affect demand clarity.
3. How CEO review handles premise challenge, existing-code leverage, dream state, implementation alternatives, expansion modes, temporal interrogation, and decision gates.
4. How question tuning affects collaboration.
5. Current repo analogs and gaps.
6. Adopt/Adapt/Isolate/Reject recommendations.
7. Evidence paths.
```

Persist verbatim output to `/tmp/gstack-agent-outputs/04-front-half.md`.

- [ ] **Step 6: Dispatch Middle-System Agent**

Prompt:

```text
You are the Middle-System Agent.

Inputs:
- Upstream repo: /tmp/gstack-systematic-benchmark-2026-05-26
- Current repo: /Users/lijieli/org-claude-skills

Task:
Compare plan review, design review, engineering review, DX review, plan-output quality, and anti-false-completion. Do not modify files.

Read upstream:
- plan-eng-review/SKILL.md
- plan-design-review/SKILL.md
- plan-devex-review/SKILL.md
- design-consultation/SKILL.md
- design-review/SKILL.md
- review/SKILL.md
- careful/SKILL.md
- freeze/SKILL.md
- guard/SKILL.md

Read current repo:
- contracts/standard-chain.yaml
- contracts/episode-package.schema.json
- shared/skills/review/SKILL.md
- shared/skills/developer/SKILL.md
- tests/gate-plan.json
- docs/reports/standard-chain-harness-audit-2026-05-24.md

Required output:
1. Middle-system mechanism matrix.
2. Anti-false-completion mechanisms.
3. Plan quality mechanisms.
4. Current repo strengths and gaps.
5. Adopt/Adapt/Isolate/Reject recommendations.
6. Evidence paths.
```

Persist verbatim output to `/tmp/gstack-agent-outputs/05-middle-system.md`.

- [ ] **Step 7: Dispatch Back-Half Agent**

Prompt:

```text
You are the Back-Half Agent.

Inputs:
- Upstream repo: /tmp/gstack-systematic-benchmark-2026-05-26
- Current repo: /Users/lijieli/org-claude-skills

Task:
Compare implementation support, investigate, QA, browser, ship, canary, deploy, benchmark, learn, retro, and context restore. Do not modify files.

Use /tmp/gstack-skill-inventory.json to identify relevant upstream skills, including qa, qa-only, browse, open-gstack-browser, investigate, pair-agent, land-and-deploy, canary, benchmark, learn, retro, context-save, context-restore, and ios-qa if present.

Read current repo:
- shared/skills/qa/SKILL.md
- shared/skills/qa/contracts/qa-result.schema.json
- shared/skills/qa/references/e2e-journey-methodology.md
- shared/skills/developer/SKILL.md
- shared/skills/delivery-owner/SKILL.md
- community/vercel/skills/agent-browser/SKILL.md
- community/skills-sh/skills/bb-browser/SKILL.md
- tests/test-qa-browser-gate-contract.sh
- docs/feature--quanfangtong-homepage-entry-center/worklog.md
- docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage/capture-manifest.json

Required output:
1. Back-half mechanism matrix.
2. What gstack does well beyond browser usage.
3. What current repo already enforces better.
4. Adopt/Adapt/Isolate/Reject recommendations.
5. Evidence paths.
```

Persist verbatim output to `/tmp/gstack-agent-outputs/06-back-half.md`.

- [ ] **Step 8: Dispatch Runtime/Governance Agent**

Prompt:

```text
You are the Runtime/Governance Agent.

Inputs:
- Upstream repo: /tmp/gstack-systematic-benchmark-2026-05-26
- /tmp/gstack-runtime-inventory.json
- Current repo: /Users/lijieli/org-claude-skills

Task:
Analyze runtime, host integration, extension, gbrain, telemetry, update, routing, source governance, and integration safety. Separate value from install risk. Do not modify files.

Read upstream:
- SKILL.md
- agents/openai.yaml
- package.json
- conductor.json
- BROWSER.md
- ARCHITECTURE.md
- USING_GBRAIN_WITH_GSTACK.md
- bin/* names and high-signal scripts
- hosts/*
- extension/*
- docs/gbrain-sync.md if present
- gstack-upgrade/SKILL.md
- health/SKILL.md
- cso/SKILL.md

Read current repo:
- community/SOURCES.yaml
- contracts/skill-runtime-surface.json
- contracts/superpowers-boundary.yaml
- shared/skills/security/SKILL.md
- shared/skills/security/references/security-rules.md
- install.sh
- AGENTS.md

Required output:
1. Runtime capability map.
2. Integration risk table.
3. Valuable governance/security mechanisms.
4. Current repo governance strengths.
5. Adopt/Adapt/Isolate/Reject recommendations.
6. Evidence paths.
```

Persist verbatim output to `/tmp/gstack-agent-outputs/07-runtime-governance.md`.

- [ ] **Step 9: Dispatch Current-Repo Independent Agent**

Prompt:

```text
You are the Current-Repo Independent Agent.

Input:
- Current repo: /Users/lijieli/org-claude-skills

Task:
Map this repository's agent-workflow capabilities without looking at gstack. Do not modify files.

Required output:
1. Current repo capability ontology.
2. Maturity 0-4 for each capability.
3. Strongest advantages.
4. Known gaps with evidence.
5. Relevant files.
```

Persist verbatim output to `/tmp/gstack-agent-outputs/08-current-repo.md`.

- [ ] **Step 10: Dispatch Red-Team Agent**

Prompt:

```text
You are the Red-Team Agent.

Inputs:
- /tmp/gstack-skill-inventory.json
- /tmp/gstack-runtime-inventory.json
- Upstream repo: /tmp/gstack-systematic-benchmark-2026-05-26
- Current repo: /Users/lijieli/org-claude-skills

Task:
Attack the benchmark process before the final report is accepted. Do not produce the main report. Do not modify files.

Required output:
1. Top 10 ways the benchmark could still be wrong.
2. Skills likely to be underweighted or missed.
3. Runtime/tooling assets likely to be underweighted or missed.
4. Evidence that front-half value could be overstated.
5. Evidence that QA/browser value could be overstated.
6. Evidence that install risk could be overstated or understated.
7. Questions the coordinator must answer before finalizing.
```

Persist verbatim output to `/tmp/gstack-agent-outputs/09-red-team.md`.

## Task 6: Synthesize Final Report

**Files:**
- Create: `docs/reports/gstack-systematic-rebenchmark-2026-05-26.md`

- [ ] **Step 1: Create report skeleton**

Create `docs/reports/gstack-systematic-rebenchmark-2026-05-26.md` with this structure:

```markdown
# gstack Systematic Rebenchmark - 2026-05-26

## 结论

## 执行口径

## 证据来源

## 1. 全量 Skill Inventory 覆盖证明

## 2. Runtime / Tooling Inventory 覆盖证明

## 3. 从 gstack 自身归纳出的能力 Ontology

## 4. 社区推荐价值假设验证

## 5. Front Half: 需求澄清与 CEO 视角

## 6. Middle System: 计划评审与实施前质量门

## 7. Back Half: 实现、验证、发布与学习闭环

## 8. Runtime Layer: 主机集成、浏览器、gbrain、遥测与路由

## 9. 当前仓库独立能力地图

## 10. 双方成熟度矩阵

## 11. Adopt / Adapt / Isolate / Reject 决策表

## 12. 当前仓库查漏补缺

## 13. 分阶段路线图

## 14. 明确不建议做的事

## 15. Red-Team 复核结果

## 16. 剩余不确定性

## 附录 A: gstack Skill Coverage Table

## 附录 B: Runtime / Tooling Coverage Table

## 附录 C: Agent Team Verbatim Output Index

## 附录 D: 关键证据索引
```

- [ ] **Step 2: Treat conclusion as evidence result, not forced thesis**

The conclusion must answer these questions, and it may answer `no` if evidence supports that:

```text
1. Is gstack best understood as an agent operating system rather than a skill bundle?
2. Is the front half actually the community-recommended value center?
3. What does gstack do better than this repository?
4. What does this repository do better than gstack?
5. Which mechanisms are worth learning even if runtime installation is unsafe?
6. Which mechanisms should not be brought over?
```

- [ ] **Step 3: Add coverage tables**

`附录 A` must include every path from `/tmp/gstack-skill-inventory.json`:

```markdown
| Skill Path | Primary Category | Secondary Category | Covered In Section | Decision |
|---|---|---|---|---|
```

`附录 B` must include every path from `/tmp/gstack-runtime-inventory.json` or summarize low-signal files by explicit group with a reason:

```markdown
| Runtime Path Or Group | Coverage Mode | Covered In Section | Risk/Value Notes |
|---|---|---|---|
```

Allowed `Coverage Mode` values:
- `individual`
- `grouped-low-signal`
- `not-relevant-with-reason`

- [ ] **Step 4: Add maturity matrix**

Use this scale:

```text
0 absent
1 documented only
2 structured artifact/schema
3 enforced by gate/test
4 proven by real run and feedback loop
```

Required rows:

```text
Demand reality clarification
Status quo and wedge analysis
CEO/founder scope review
Question quality and question tuning
Product/design handoff artifacts
Implementation alternatives
Engineering plan review
Design review
DX review
Anti-false-completion review
Browser QA evidence
Fix/reverify loop
Shipping/readiness verification
Canary/deploy risk
Security posture
Skill supply-chain governance
Runtime/host integration safety
Learning/memory/context restore
Episode/run trace
Community adoption signal
```

- [ ] **Step 5: Add decision table**

At minimum include:

```text
office-hours six forcing questions
demand reality vs interest
status quo as competitor
desperate specificity
narrowest wedge
watch-don't-demo observation assignment
CEO premise challenge
existing-code leverage
dream-state mapping
implementation alternatives before mode selection
scope expansion/selective/hold/reduction
individual expansion opt-in ceremony
temporal interrogation
question tuning
design doc prerequisite before plan review
autoplan review pipeline
outside voice plan challenge
plan-eng error/rescue map
plan-design UX/state coverage
plan-devex review
review confidence and quote gate
QA browser evidence
QA baseline diff
QA fix/reverify loop
ship stale verification
canary
learn/context-save/context-restore
gbrain/artifacts sync
telemetry
auto-update
routing injection
browser extension
host integrations
direct browser runtime
manual-only community mirror
```

For every `Adopt` or `Adapt`, name likely landing files and later verification.

## Task 7: Verification Gates

**Files:**
- Read: `/tmp/gstack-skill-inventory.json`
- Read: `/tmp/gstack-runtime-inventory.json`
- Read: `docs/reports/gstack-systematic-rebenchmark-2026-05-26.md`

If any verification gate fails, do not proceed to final handoff. Fix the report inside the benchmark scope and rerun the failed gate. If fixing would require changing scope, installing `gstack`, or modifying repo implementation files, stop and report the blocker.

- [ ] **Step 1: Verify all skill paths are covered**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
import json

inventory = json.loads(Path("/tmp/gstack-skill-inventory.json").read_text(encoding="utf-8"))
report = Path("docs/reports/gstack-systematic-rebenchmark-2026-05-26.md").read_text(encoding="utf-8")
missing = [item["path"] for item in inventory if item["path"] not in report]
if missing:
    raise SystemExit("report missing skill paths:\n" + "\n".join(missing))
print(f"skill coverage ok: {len(inventory)}")
PY
```

Expected: `skill coverage ok: N`.

- [ ] **Step 2: Verify runtime coverage**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
import json

inventory = json.loads(Path("/tmp/gstack-runtime-inventory.json").read_text(encoding="utf-8"))
report = Path("docs/reports/gstack-systematic-rebenchmark-2026-05-26.md").read_text(encoding="utf-8")
missing = []
for item in inventory:
    path = item["path"]
    group = path.split("/", 1)[0]
    group_marker = f"`{group}/`"
    path_marker = f"`{path}`"
    if path_marker not in report and group_marker not in report:
        missing.append(path)
if missing:
    raise SystemExit("report missing runtime paths/groups:\n" + "\n".join(missing[:80]))
print(f"runtime coverage ok: {len(inventory)}")
PY
```

Expected: `runtime coverage ok: N`.

- [ ] **Step 3: Verify front-half structural coverage**

Run:

```bash
python3 - <<'PY'
from pathlib import Path

text = Path("docs/reports/gstack-systematic-rebenchmark-2026-05-26.md").read_text(encoding="utf-8")
required = [
    "office-hours/SKILL.md",
    "plan-ceo-review/SKILL.md",
    "autoplan/SKILL.md",
    "plan-tune/SKILL.md",
    "six forcing questions",
    "demand reality",
    "status quo",
    "narrowest wedge",
    "premise challenge",
    "scope expansion",
    "selective expansion",
    "question tuning",
]
missing = [term for term in required if term not in text]
if missing:
    raise SystemExit("front-half structural coverage missing:\n" + "\n".join(missing))
print("front-half structural coverage ok")
PY
```

Expected: `front-half structural coverage ok`.

- [ ] **Step 4: Verify agent outputs are referenced**

Run:

```bash
python3 - <<'PY'
from pathlib import Path

report = Path("docs/reports/gstack-systematic-rebenchmark-2026-05-26.md").read_text(encoding="utf-8")
expected = [
    "01-inventory-auditor.md",
    "02-ontology.md",
    "03-community-value.md",
    "04-front-half.md",
    "05-middle-system.md",
    "06-back-half.md",
    "07-runtime-governance.md",
    "08-current-repo.md",
    "09-red-team.md",
]
missing_files = [name for name in expected if not Path("/tmp/gstack-agent-outputs", name).exists()]
missing_refs = [name for name in expected if name not in report]
if missing_files:
    raise SystemExit("missing persisted agent outputs:\n" + "\n".join(missing_files))
if missing_refs:
    raise SystemExit("report missing agent output references:\n" + "\n".join(missing_refs))
print("agent output references ok")
PY
```

Expected: `agent output references ok`.

- [ ] **Step 5: Verify repo references**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
import re

text = Path("docs/reports/gstack-systematic-rebenchmark-2026-05-26.md").read_text(encoding="utf-8")
refs = set(re.findall(r'`((?:README|AGENTS|contracts|shared|community|tests|docs|tools|install\.sh)[^`\n]*)`', text))
missing = []
for raw in refs:
    candidate = raw.split(":")[0]
    if "*" in candidate or "{" in candidate or " " in candidate:
        continue
    if not Path(candidate).exists():
        missing.append(raw)
if missing:
    raise SystemExit("missing repo references:\n" + "\n".join(sorted(missing)))
print(f"repo references ok: {len(refs)}")
PY
```

Expected: exits 0.

- [ ] **Step 6: Verify red-team result is not empty**

Run:

```bash
python3 - <<'PY'
from pathlib import Path

text = Path("docs/reports/gstack-systematic-rebenchmark-2026-05-26.md").read_text(encoding="utf-8")
marker = "## 15. Red-Team 复核结果"
if marker not in text:
    raise SystemExit("missing red-team section")
section = text.split(marker, 1)[1].split("## 16.", 1)[0]
if len(section.strip()) < 1000:
    raise SystemExit("red-team section too thin")
for required in ["遗漏", "偏置", "runtime", "front", "QA"]:
    if required not in section:
        raise SystemExit(f"red-team section missing required concern: {required}")
print("red-team section ok")
PY
```

Expected: `red-team section ok`.

## Task 8: Final Verification And Handoff

**Files:**
- Verify: `docs/reports/gstack-systematic-rebenchmark-2026-05-26.md`

- [ ] **Step 1: Check diff scope**

Run:

```bash
git diff --check -- docs/reports/gstack-systematic-rebenchmark-2026-05-26.md
git status --short -- docs/reports/gstack-systematic-rebenchmark-2026-05-26.md
```

Expected:
- `git diff --check` exits 0.
- The report file is the only repo file created by the execution window.

- [ ] **Step 2: Do not run full tests unless code changed**

Because the benchmark execution is report-only, do not run `bash tests/run-all.sh --quick` by default. If the executor accidentally changes code, contracts, skills, community mirrors, tests, install files, or runtime files, revert only the executor's accidental changes and then run:

```bash
bash tests/run-all.sh --quick
```

- [ ] **Step 3: Final response format**

Use this success response only after every Task 7 gate and Task 8 diff check passes. Final response must start with:

```text
结论：v2.1 系统复核报告已完成；这次覆盖了 skill 与 runtime/tooling 两层 inventory，并通过 coverage/red-team gates。
```

Then include:
- Report path.
- Upstream commit hash.
- Skill inventory count.
- Runtime/tooling inventory count.
- Top 3 findings.
- Top 3 recommended next actions.
- Verification commands run.
- Explicit note that no runtime integration or implementation change was made.

---

## Completion Checklist For Executor

- [ ] Every upstream `SKILL.md` path is in the final report.
- [ ] Runtime/tooling assets are covered individually or by explicit low-signal group.
- [ ] The report does not force front-half or QA/browser as the main value before evidence.
- [ ] Agent-team outputs are persisted and referenced.
- [ ] Red-team concerns are answered, not merely listed.
- [ ] Every `Adopt` or `Adapt` item names current-repo landing files and later verification.
- [ ] Direct installation risk is separated from mechanism value.
- [ ] Repo diff is limited to the final report created by the execution window.
