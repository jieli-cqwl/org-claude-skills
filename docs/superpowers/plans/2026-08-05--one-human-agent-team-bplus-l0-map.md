# One-Human + Agent Team B+ L0 Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the rejected high-density architecture-map candidate with one Chinese-first, desktop-readable B+ L0 SVG/PNG candidate that exposes the Human boundary, five-stage path, observable stage-completion gates, two deployment boundaries, shared support, and accountable stop/return rules without turning L0 back into a role inventory.

**Architecture:** The approved Markdown specification remains the sole architecture-semantic source. Reuse the existing SVG → PNG → targeted-test path in place: the SVG is the only editable visual projection, the PNG is deterministic review output, and the Python test guards structure, rendering safety, and provenance without becoming a competing prose specification. The candidate remains `DRAFT` until the Human approves its exact commit, SVG SHA-256, and PNG SHA-256; publication is a separate gated task.

**Tech Stack:** self-contained SVG 1.1; Python 3 standard-library `unittest`, `xml.etree.ElementTree`, `zlib`, `hashlib`, `datetime`, and `subprocess`; `rsvg-convert 2.60.0`; `xmllint`; Git.

## Status

- `READY FOR EXECUTION — written B+ contract approved; no replacement candidate exists yet`.
- This plan becomes `CLOSED — DO NOT EXECUTE` only after Task 3 publishes the exact Human-approved bytes.
- Projection lifecycle and accepted-byte identity are authoritative only in the canonical specification, never in this plan or the asset README.

## Global Constraints

- Semantic source: `docs/superpowers/specs/2026-08-03--one-human-agent-team-operating-architecture-l0--design.md`, approved B+ contract at commit `fe812224d84600110c139ae7d1c8d63d9235743b`.
- Reuse these existing paths; do not add a new renderer, asset family, test entry, or duplicate copy manifest.
- Formal canvas: `1920×1080`, 16:9. Acceptance uses an actual `1440×810` render at 100% zoom.
- Chinese is the primary explanatory language; canonical English role names are secondary labels.
- At `1440×810`, actual displayed type is at least `30px` title, `18px` stage title, `14px` purpose/completion, and `12.5px` secondary text. With uniform 0.75 scaling, source SVG minima are `40`, `24`, `19`, and `17` respectively.
- Each stage card has at most 3 purpose lines, 2 integrator lines, 5 completion lines, and 2 optional-note lines. Human groups, foundation items, deployment-gate steps, return rule, and stop rule have at most 2 lines each.
- Do not make text smaller, remove frames while retaining the same detail as loose text, hide prose, place required text off-canvas, or use metadata-only semantics to pass tests.
- Do not render individual Professional Owner or Executor card inventories on L0. Stage Result Integrators remain visible; detailed ownership remains in the canonical specification.
- Do not create either deferred L1 view, an Owner design, a Skill, runtime orchestration, or any `qft-tenants` solution.
- Do not modify `tests/gate-plan.json` or `tests/run-all.sh`; the existing test path is already registered.
- Do not modify or regenerate any asset under `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/`.
- Use `apply_patch` for tracked text changes. Use `rsvg-convert` only to derive PNG files and temporary review renders.
- Keep the replacement candidate `DRAFT`. No Agent may infer byte approval from approval of the B+ design contract.
- The canonical specification owns projection lifecycle and accepted identity. The asset README owns only path, renderer, derivation, and provenance instructions; tests read approval state from the canonical specification.
- During candidate work, changed-path scope is limited to the canonical status line, the existing SVG/PNG/README/test path, and no other architecture artifact. A future L1 is not prohibited globally; it is merely outside this plan.
- Track Task 1/2 progress in the active task state; do not tick or otherwise edit this plan until Task 3 closes it.
- The repo-wide quick gate currently has an unrelated baseline failure at `rule-runtime-team-readiness-pack` because `docs/rule-runtime--team-readiness/acceptance-pack.json` is absent. Re-run it and report whether the failure remains identical; do not call the full gate green.

---

## Existing-Path and File-Responsibility Map

| Path | Responsibility | Planned action |
|---|---|---|
| `docs/superpowers/specs/2026-08-03--one-human-agent-team-operating-architecture-l0--design.md` | Sole semantic source, projection lifecycle, accepted identity, and accepted-projection pointer | During Task 1, change only the stale projection-status line; during Task 3, record exact accepted identity and close the L0 visual gate |
| `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg` | Only editable L0 visual projection | Replace in place with B+ candidate |
| `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png` | Deterministic render of the SVG | Regenerate from the replacement SVG |
| `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/README.md` | Projection paths, renderer, derivation, and authority pointer | Update renderer/provenance and point lifecycle/identity to the canonical specification; never record an independent status or accepted identity |
| `tests/test-one-human-agent-team-architecture-map.py` | Structural, raster, provenance, and link safety net | Replace the old dense-map contract in place |
| `docs/superpowers/plans/2026-08-03--one-human-agent-team-chinese-macro-architecture-map.md` | Closed historical-plan tombstone | Read-only historical evidence; do not turn it into a forward-work entry |

No new production or test module is justified. The current path already owns this projection, its derived raster, and its gate registration.

---

### Task 1: Build and Prove the B+ Draft Candidate

**Files:**
- Modify: `docs/superpowers/specs/2026-08-03--one-human-agent-team-operating-architecture-l0--design.md` — projection-status line only
- Modify: `tests/test-one-human-agent-team-architecture-map.py`
- Modify: `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg`
- Modify: `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png`
- Modify: `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/README.md`

**Interfaces:**
- Consumes: the approved B+ projection contract in the canonical specification; existing `SVG_PATH`, `PNG_PATH`, `README_PATH`, `CANONICAL_SPEC`, `CANONICAL_POINTERS`, PNG decoder, Markdown-link resolver, and SVG visibility helpers in the current test.
- Produces: one committed `DRAFT` SVG/PNG candidate with `data-projection="bplus-l0-v1"`, a `1920×1080` raster bound by SHA-256 to the SVG root, a canonical lifecycle line that truthfully identifies the replacement candidate as pending exact-byte acceptance, and a targeted test that rejects the current high-density candidate before accepting the replacement.

- [ ] **Step 1: Record the rejected-candidate baseline without changing files**

Run:

```bash
git status --short
python3 tests/test-one-human-agent-team-architecture-map.py
xmllint --xpath 'count(//*[local-name()="rect"])' docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg
xmllint --xpath 'count(//*[local-name()="text"])' docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg
```

Expected: clean worktree; the old test passes; the rejected SVG reports 65 rectangles and 130 text nodes. These numbers are diagnosis only, not the B+ acceptance metric.

- [ ] **Step 2: Replace the old dense-map test contract with the B+ structural contract**

Retain the existing path constants, `markdown_targets`, PNG decoding/CRC checks, and generic XML visibility helpers; add `from collections import Counter`, `from datetime import date`, and the standard-library `subprocess` import for closed-set, accepted-date, and approved-commit blob checks. Delete the role-inventory constants and the tests that require every Professional Owner, Executor, four boxed forward facts, five boxed return facts, and four boxed Stage 5 facts to appear on L0.

Use structural manifests without absolute layout coordinates:

```python
APPROVED_CONTRACT_COMMIT = "fe812224d84600110c139ae7d1c8d63d9235743b"

STAGES = (
    ("stage-product-definition", "1"),
    ("stage-verification-planning", "2"),
    ("stage-development-delivery", "3"),
    ("stage-independent-quality", "4"),
    ("stage-production-closeout", "5"),
)

GATES = (
    ("test-deployment", "3-4"),
    ("production-deployment", "4-5"),
)

DELIVERY_SEQUENCE = (
    "stage-product-definition",
    "stage-verification-planning",
    "stage-development-delivery",
    "test-deployment",
    "stage-independent-quality",
    "production-deployment",
    "stage-production-closeout",
)

REQUIRED_CONCEPTS = {
    "map-header",
    "human-governance",
    "cross-owner-handoff",
    "agent-team",
    *(stage[0] for stage in STAGES),
    *(gate[0] for gate in GATES),
    "behavior-obligation-trace",
    "shared-foundation",
    "accountable-return-safe-stop",
}

EXPECTED_KIND_CONCEPTS = {
    "governance-layer": {"human-governance"},
    "agent-team": {"agent-team"},
    "delivery-stage": {stage[0] for stage in STAGES},
    "deployment-boundary": {gate[0] for gate in GATES},
    "cross-cutting-foundation": {"shared-foundation"},
    "return-stop-law": {"accountable-return-safe-stop"},
}

RECT_VISUAL_COUNTS = {
    "canvas-background": 1,
    "human-governance-layer": 1,
    "agent-team-container": 1,
    "stage-card": 5,
    "deployment-card": 2,
    "shared-foundation-layer": 1,
    "return-stop-layer": 1,
}

SOURCE_FONT_MINIMUM = {
    "title": 40.0,
    "stage-title": 24.0,
    "body": 19.0,
    "secondary": 17.0,
}

STAGE_SLOT_LIMITS = {"purpose": 3, "integrator": 2, "completion": 5, "note": 2}

OTHER_SLOT_LIMITS = {
    "human-group": 2,
    "handoff": 2,
    "gate-step": 2,
    "foundation-item": 2,
    "return-rule": 2,
    "stop-rule": 2,
}

COPY_SLOT_COUNTS = {
    "purpose": 5,
    "integrator": 5,
    "completion": 5,
    "note": 4,
    "human-group": 3,
    "handoff": 1,
    "gate-step": 4,
    "foundation-item": 4,
    "return-rule": 1,
    "stop-rule": 1,
}

SLOT_TEXT_TIER = {
    "purpose": "body",
    "integrator": "secondary",
    "completion": "body",
    "note": "secondary",
    "human-group": "body",
    "handoff": "secondary",
    "gate-step": "secondary",
    "foundation-item": "secondary",
    "return-rule": "secondary",
    "stop-rule": "secondary",
}

TEXT_ROLE_MANIFEST = {
    "map-title": ("title", 1, 1),
    "map-proposition": ("body", 1, 2),
    "map-status": ("secondary", 1, 1),
    "map-initial-operation": ("secondary", 1, 1),
    "human-title": ("stage-title", 1, 1),
    "human-boundary": ("secondary", 1, 2),
    "agent-team-title": ("stage-title", 1, 1),
    "stage-title": ("stage-title", 5, 2),
    "gate-label": ("secondary", 4, 1),
    "obligation-trace": ("secondary", 1, 1),
    "foundation-title": ("body", 1, 1),
}

ALLOWED_DATA_ATTRIBUTES = {
    "data-architecture",
    "data-baseline",
    "data-projection",
    "data-status",
    "data-png-sha256",
    "data-concept",
    "data-kind",
    "data-order",
    "data-integrator",
    "data-controlled-by",
    "data-between",
    "data-visual",
    "data-copy-slot",
    "data-max-lines",
    "data-text-role",
    "data-text-tier",
}

ALLOWED_SVG_ELEMENTS = {"svg", "title", "desc", "g", "rect", "line", "path", "text"}

FORBIDDEN_TEXT_POSITIONING_ATTRIBUTES = {
    "dx",
    "dy",
    "rotate",
    "textLength",
    "lengthAdjust",
}

SCALAR_NUMBER = re.compile(r"^-?(?:\d+(?:\.\d*)?|\.\d+)$")

```

Do not paste the canonical Chinese copy into Python. Extract required and forbidden visible fragments from the approved Markdown contract:

```python
def markdown_section(source: str, start: str, end: str) -> str:
    return source.split(start, 1)[1].split(end, 1)[0]


def backtick_values(source: str) -> tuple[str, ...]:
    return tuple(re.findall(r"`([^`]+)`", source))


def committed_blob(commit: str, path: Path) -> bytes:
    result = subprocess.run(
        ["git", "show", f"{commit}:{path.relative_to(ROOT).as_posix()}"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    return result.stdout


def projection_contract(source: str) -> str:
    return markdown_section(source, "### B+ view boundary", "## Risks, Unknowns, and Reopen Conditions")


def approved_contract_source() -> str:
    approved = committed_blob(APPROVED_CONTRACT_COMMIT, CANONICAL_SPEC).decode("utf-8")
    current = CANONICAL_SPEC.read_text(encoding="utf-8")
    if projection_contract(current) != projection_contract(approved):
        raise AssertionError("current B+ contract drifted from the Human-approved commit")
    return approved


def role_slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.casefold()).strip("-")


def canonical_completion_prefix() -> str:
    source = approved_contract_source()
    match = re.search(r"The prefix `([^`]+)` is visible", source)
    assert match
    return match.group(1)


def canonical_stage_rows() -> tuple[tuple[str, ...], ...]:
    source = approved_contract_source()
    exact = markdown_section(source, "### Exact visible content", "### Visual grammar and density budget")
    stages = markdown_section(exact, "**Five-stage path**", "**Why the Stage 3 → 4 boundary exists**")
    rows = tuple(backtick_values(line) for line in stages.splitlines() if line.startswith("| `"))
    assert len(rows) == 5 and all(len(row) in {4, 5} for row in rows)
    return rows


def canonical_gate_steps() -> tuple[str, ...]:
    source = approved_contract_source()
    exact = markdown_section(source, "### Exact visible content", "### Visual grammar and density budget")
    boundary = markdown_section(exact, "**Why the Stage 3 → 4 boundary exists**", "**Shared support and failure handling**")
    steps = tuple(backtick_values(line)[0] for line in boundary.splitlines() if line.startswith("- `"))
    assert len(steps) == 4
    return steps


def canonical_header_copy() -> tuple[str, ...]:
    source = approved_contract_source()
    exact = markdown_section(source, "### Exact visible content", "### Visual grammar and density budget")
    values = backtick_values(markdown_section(exact, "**Header**", "**Human band**"))
    assert len(values) == 4
    return values


def canonical_human_copy() -> tuple[str, ...]:
    source = approved_contract_source()
    exact = markdown_section(source, "### Exact visible content", "### Visual grammar and density budget")
    values = backtick_values(markdown_section(exact, "**Human band**", "**Cross-Owner handoff line**"))
    assert len(values) == 8
    return values


def canonical_handoff_text() -> str:
    source = approved_contract_source()
    exact = markdown_section(source, "### Exact visible content", "### Visual grammar and density budget")
    handoff = markdown_section(exact, "**Cross-Owner handoff line**", "**Five-stage path**")
    fence = "`" * 3
    block = re.search(rf"{fence}text\n(.*?)\n{fence}", handoff, re.DOTALL)
    assert block
    return "".join(line.strip() for line in block.group(1).splitlines())


def canonical_gate_rows() -> tuple[tuple[str, str], ...]:
    rows = tuple(
        (label + "｜", phrase)
        for label, phrase in (step.split("｜", 1) for step in canonical_gate_steps())
    )
    assert len(rows) == 4 and all(len(row) == 2 for row in rows)
    return rows


def canonical_support_copy() -> tuple[str, ...]:
    source = approved_contract_source()
    exact = markdown_section(source, "### Exact visible content", "### Visual grammar and density budget")
    support = exact.split("**Shared support and failure handling**", 1)[1]
    values = tuple(
        value
        for line in support.splitlines()
        if line.startswith("- ")
        for value in backtick_values(line)
    )
    assert len(values) == 8
    return values


def canonical_required_visible_copy() -> tuple[str, ...]:
    source = approved_contract_source()
    exact = markdown_section(source, "### Exact visible content", "### Visual grammar and density budget")
    header = markdown_section(exact, "**Header**", "**Human band**")
    human = markdown_section(exact, "**Human band**", "**Cross-Owner handoff line**")
    handoff = markdown_section(exact, "**Cross-Owner handoff line**", "**Five-stage path**")
    support = exact.split("**Shared support and failure handling**", 1)[1]

    required = [*backtick_values(header), *backtick_values(human)]
    fence = "`" * 3
    handoff_block = re.search(rf"{fence}text\n(.*?)\n{fence}", handoff, re.DOTALL)
    assert handoff_block
    required.extend(line.strip().removeprefix("→ ") for line in handoff_block.group(1).splitlines())
    for row in canonical_stage_rows():
        required.extend(row)
    required.append(canonical_completion_prefix())
    required.extend(canonical_gate_steps())
    for line in support.splitlines():
        if line.startswith("- "):
            required.extend(backtick_values(line))
    return tuple(value for value in required if value and value != "—")


def canonical_forbidden_visible_copy() -> tuple[str, ...]:
    source = approved_contract_source()
    forbidden = []
    for pattern in (
        r"Abstract labels such as ([^\n]+?) must not substitute",
        r"Defensive prose such as ([^\n]+?) is forbidden",
    ):
        match = re.search(pattern, source)
        assert match
        forbidden.extend(backtick_values(match.group(1)))
    return tuple(forbidden)
```

Add or replace targeted tests so they assert these contracts:

```python
def copy_slots(self, concept: str, slot_name: str) -> list[ET.Element]:
    return [
        element
        for element in self.concept(concept).iter()
        if element.attrib.get("data-copy-slot") == slot_name
    ]


def copy_slot_count(self, concept: str, slot_name: str) -> int:
    return len(self.copy_slots(concept, slot_name))


def text_role_blocks(self, concept: str, role_name: str) -> list[ET.Element]:
    return [
        element
        for element in self.concept(concept).iter()
        if element.attrib.get("data-text-role") == role_name
    ]


def single_role_text(self, concept: str, role_name: str) -> str:
    blocks = self.text_role_blocks(concept, role_name)
    self.assertEqual(len(blocks), 1, (concept, role_name))
    return compact_text(self.rendered_text(blocks[0]))


def text_anchor(self, block: ET.Element, axis: str) -> float:
    lines = [child for child in list(block) if local_name(child) == "text"]
    self.assertTrue(lines, ET.tostring(block, encoding="unicode"))
    values = []
    for line in lines:
        raw = line.attrib.get(axis, "")
        self.assertRegex(raw, SCALAR_NUMBER, ET.tostring(line, encoding="unicode"))
        values.append(float(raw))
    return min(values)


def text_tail(self, block: ET.Element, axis: str) -> float:
    lines = [child for child in list(block) if local_name(child) == "text"]
    self.assertTrue(lines, ET.tostring(block, encoding="unicode"))
    values = []
    for line in lines:
        raw = line.attrib.get(axis, "")
        self.assertRegex(raw, SCALAR_NUMBER, ET.tostring(line, encoding="unicode"))
        values.append(float(raw))
    return max(values)


def assert_visible_order(
    self,
    blocks: list[ET.Element],
    axis: str,
    label: str,
    minimum_gap: float = 0.0,
) -> None:
    anchors = [self.text_anchor(block, axis) for block in blocks]
    self.assertTrue(
        all(b - a >= minimum_gap for a, b in zip(anchors, anchors[1:])),
        (label, anchors, minimum_gap),
    )


def test_root_declares_bplus_projection_and_16_by_9_canvas(self) -> None:
    self.assertEqual(self.root.attrib.get("data-architecture"), "one-human-agent-team")
    self.assertEqual(self.root.attrib.get("data-baseline"), "L0-R3")
    self.assertEqual(self.root.attrib.get("data-projection"), "bplus-l0-v1")
    self.assertEqual(self.root.attrib.get("data-status"), "m0-manual-not-runtime-active")
    self.assertEqual(self.root.attrib.get("viewBox"), "0 0 1920 1080")
    self.assertEqual(self.root.attrib.get("width"), "1920")
    self.assertEqual(self.root.attrib.get("height"), "1080")
    self.assertRegex(self.root.attrib.get("data-png-sha256", ""), r"^[0-9a-f]{64}$")


def test_bplus_keeps_only_the_navigation_structure(self) -> None:
    concepts = {
        element.attrib["data-concept"]
        for element in self.elements
        if "data-concept" in element.attrib
    }
    self.assertEqual(concepts, REQUIRED_CONCEPTS)
    self.assertFalse(any("data-role-id" in element.attrib for element in self.elements))
    self.assertFalse(any("data-role-type" in element.attrib for element in self.elements))
    self.assertEqual(sum(e.attrib.get("data-kind") == "delivery-stage" for e in self.elements), 5)
    self.assertEqual(sum(e.attrib.get("data-kind") == "deployment-boundary" for e in self.elements), 2)

    kinds: dict[str, set[str | None]] = {}
    for element in self.elements:
        if element.attrib.get("data-kind"):
            kinds.setdefault(element.attrib["data-kind"], set()).add(element.attrib.get("data-concept"))
    self.assertEqual(kinds, EXPECTED_KIND_CONCEPTS)

    painted_rects = [
        element
        for element in self.elements
        if local_name(element) == "rect" and self.is_renderable_drawable(element)
    ]
    self.assertEqual(
        Counter(element.attrib.get("data-visual") for element in painted_rects),
        Counter(RECT_VISUAL_COUNTS),
    )

    self.assertEqual({local_name(element) for element in self.elements} - ALLOWED_SVG_ELEMENTS, set())
    for element in self.elements:
        unknown = {
            name
            for name in element.attrib
            if name.startswith("data-") and name not in ALLOWED_DATA_ATTRIBUTES
        }
        self.assertEqual(unknown, set(), ET.tostring(element, encoding="unicode"))
        self.assertFalse(
            any(name == "title" or name.startswith("aria-") for name in element.attrib),
            ET.tostring(element, encoding="unicode"),
        )
        if local_name(element) not in {"title", "desc", "text"}:
            self.assertFalse((element.text or "").strip(), ET.tostring(element, encoding="unicode"))
        self.assertFalse((element.tail or "").strip(), ET.tostring(element, encoding="unicode"))
    self.assertNotIn("<!--", SVG_PATH.read_text(encoding="utf-8"))
    all_titles = [node for node in self.elements if local_name(node) == "title"]
    all_descriptions = [node for node in self.elements if local_name(node) == "desc"]
    titles = [node for node in list(self.root) if local_name(node) == "title"]
    descriptions = [node for node in list(self.root) if local_name(node) == "desc"]
    self.assertEqual((len(titles), len(descriptions)), (1, 1))
    self.assertEqual((all_titles, all_descriptions), (titles, descriptions))
    self.assertEqual((titles[0].attrib, descriptions[0].attrib), ({}, {}))
    self.assertEqual((list(titles[0]), list(descriptions[0])), ([], []))
    header = canonical_header_copy()
    self.assertEqual(compact_text("".join(titles[0].itertext())), compact_text(header[0]))
    self.assertEqual(compact_text("".join(descriptions[0].itertext())), compact_text(header[1]))

    agent_team = self.concept("agent-team")
    top_level = (
        "map-header",
        "human-governance",
        "cross-owner-handoff",
        "agent-team",
        "shared-foundation",
        "accountable-return-safe-stop",
    )
    for concept in top_level:
        self.assertIs(self.parent.get(self.concept(concept)), self.root, concept)
    for concept, _ in STAGES:
        self.assertIs(self.parent.get(self.concept(concept)), agent_team, concept)
    for concept, _ in GATES:
        self.assertIs(self.parent.get(self.concept(concept)), agent_team, concept)
    self.assertTrue(self.is_inside(self.concept("behavior-obligation-trace"), agent_team))


def test_layers_and_delivery_path_use_relative_order_without_overlap(self) -> None:
    layer_boxes = [
        self.visual_rect(self.concept(concept), visual)
        for concept, visual in (
            ("human-governance", "human-governance-layer"),
            ("agent-team", "agent-team-container"),
            ("shared-foundation", "shared-foundation-layer"),
            ("accountable-return-safe-stop", "return-stop-layer"),
        )
    ]
    for box in layer_boxes:
        self.assert_inside_rect(box, (0.0, 0.0, 1920.0, 1080.0), "top-level layer")
    self.assertTrue(all(a[1] + a[3] <= b[1] for a, b in zip(layer_boxes, layer_boxes[1:])))

    agent_box = self.visual_rect(self.concept("agent-team"), "agent-team-container")
    path_boxes = []
    for concept in DELIVERY_SEQUENCE:
        group = self.concept(concept)
        visual = "deployment-card" if group.attrib.get("data-kind") == "deployment-boundary" else "stage-card"
        path_boxes.append(self.visual_rect(group, visual))
    self.assert_horizontal_non_overlap(path_boxes, agent_box, "delivery path")

    for (concept, order), row in zip(STAGES, canonical_stage_rows(), strict=True):
        group = self.concept(concept)
        self.assertEqual(group.attrib.get("data-kind"), "delivery-stage")
        self.assertEqual(group.attrib.get("data-order"), order)
        self.assertEqual(group.attrib.get("data-integrator"), role_slug(row[2]))
    for concept, between in GATES:
        group = self.concept(concept)
        self.assertEqual(group.attrib.get("data-kind"), "deployment-boundary")
        self.assertEqual(group.attrib.get("data-controlled-by"), "human")
        self.assertEqual(group.attrib.get("data-between"), between)


def test_visible_copy_is_derived_from_the_canonical_contract(self) -> None:
    visible = compact_text(self.visible_text())
    required = canonical_required_visible_copy()
    for fragment in required:
        self.assertIn(compact_text(fragment), visible, fragment)
    allowed = tuple(compact_text(fragment) for fragment in (*required, canonical_handoff_text()))
    for line in (element for element in self.elements if self.is_renderable_text(element)):
        rendered = compact_text("".join(line.itertext()))
        self.assertTrue(any(rendered in fragment for fragment in allowed), rendered)
    for fragment in canonical_forbidden_visible_copy():
        self.assertNotIn(compact_text(fragment), visible, fragment)

    header = canonical_header_copy()
    for role_name, expected in zip(
        ("map-title", "map-proposition", "map-status", "map-initial-operation"),
        header,
        strict=True,
    ):
        self.assertEqual(self.single_role_text("map-header", role_name), compact_text(expected))

    human = canonical_human_copy()
    self.assertEqual(self.single_role_text("human-governance", "human-title"), compact_text(human[0]))
    self.assertEqual(self.single_role_text("human-governance", "human-boundary"), compact_text(human[1]))
    human_groups = self.copy_slots("human-governance", "human-group")
    self.assertEqual(len(human_groups), 3)
    for order, (block, expected) in enumerate(
        zip(human_groups, (human[2:4], human[4:6], human[6:8]), strict=True),
        1,
    ):
        self.assertEqual(block.attrib.get("data-order"), str(order))
        self.assertEqual(compact_text(self.rendered_text(block)), compact_text("".join(expected)))
    self.assert_visible_order(human_groups, "x", "Human responsibility groups", 420.0)

    handoff_slots = self.copy_slots("cross-owner-handoff", "handoff")
    self.assertEqual(len(handoff_slots), 1)
    self.assertEqual(
        compact_text(self.rendered_text(handoff_slots[0])),
        compact_text(canonical_handoff_text()),
    )
    self.assertEqual(
        self.single_role_text("agent-team", "agent-team-title"),
        compact_text("Agent Team"),
    )

    completion_prefix = canonical_completion_prefix()
    for (concept, _), row in zip(STAGES, canonical_stage_rows(), strict=True):
        stage_visible = compact_text(self.rendered_text(self.concept(concept)))
        self.assertEqual(self.single_role_text(concept, "stage-title"), compact_text(row[0]))
        self.assertEqual(stage_visible.count(compact_text(completion_prefix)), 1, concept)
        expected_slots = {
            "purpose": row[1],
            "integrator": row[2],
            "completion": completion_prefix + row[3],
        }
        for slot_name, expected in expected_slots.items():
            slots = self.copy_slots(concept, slot_name)
            self.assertEqual(len(slots), 1, (concept, slot_name))
            self.assertEqual(
                compact_text(self.rendered_text(slots[0])),
                compact_text(expected),
                (concept, slot_name),
            )
        notes = self.copy_slots(concept, "note")
        if len(row) == 5:
            self.assertEqual(len(notes), 1, concept)
            self.assertEqual(compact_text(self.rendered_text(notes[0])), compact_text(row[4]), concept)
        else:
            self.assertEqual(notes, [], concept)

    gate_rows = canonical_gate_rows()
    for concept, rows in (
        ("test-deployment", gate_rows[:2]),
        ("production-deployment", gate_rows[2:]),
    ):
        labels = self.text_role_blocks(concept, "gate-label")
        steps = self.copy_slots(concept, "gate-step")
        self.assertEqual((len(labels), len(steps)), (2, 2), concept)
        row_bounds = []
        for order, (label, step, (expected_label, expected_step)) in enumerate(
            zip(labels, steps, rows, strict=True),
            1,
        ):
            self.assertEqual(label.attrib.get("data-order"), str(order))
            self.assertEqual(step.attrib.get("data-order"), str(order))
            self.assertEqual(compact_text(self.rendered_text(label)), compact_text(expected_label))
            self.assertEqual(compact_text(self.rendered_text(step)), compact_text(expected_step))
            self.assertLess(self.text_tail(label, "y"), self.text_anchor(step, "y"), concept)
            row_bounds.append(
                (
                    min(self.text_anchor(label, "y"), self.text_anchor(step, "y")),
                    max(self.text_tail(label, "y"), self.text_tail(step, "y")),
                )
            )
        self.assertTrue(
            all(a[1] < b[0] for a, b in zip(row_bounds, row_bounds[1:])),
            (concept, row_bounds),
        )

    support = canonical_support_copy()
    self.assertEqual(
        self.single_role_text("behavior-obligation-trace", "obligation-trace"),
        compact_text(support[0]),
    )
    self.assertEqual(
        self.single_role_text("shared-foundation", "foundation-title"),
        compact_text(support[1]),
    )
    foundation_items = self.copy_slots("shared-foundation", "foundation-item")
    self.assertEqual(len(foundation_items), 4)
    for order, (block, expected) in enumerate(zip(foundation_items, support[2:6], strict=True), 1):
        self.assertEqual(block.attrib.get("data-order"), str(order))
        self.assertEqual(compact_text(self.rendered_text(block)), compact_text(expected))
    self.assert_visible_order(foundation_items, "x", "shared foundation items", 330.0)
    return_slots = self.copy_slots("accountable-return-safe-stop", "return-rule")
    stop_slots = self.copy_slots("accountable-return-safe-stop", "stop-rule")
    self.assertEqual((len(return_slots), len(stop_slots)), (1, 1))
    self.assertEqual(compact_text(self.rendered_text(return_slots[0])), compact_text(support[6]))
    self.assertEqual(compact_text(self.rendered_text(stop_slots[0])), compact_text(support[7]))


def test_text_tiers_and_copy_slots_enforce_the_1440_readability_budget(self) -> None:
    self.assertFalse(any(local_name(node) in {"style", "tspan", "textPath"} for node in self.elements))
    self.assertFalse(any("style" in node.attrib for node in self.elements))
    slot_blocks = [node for node in self.elements if node.attrib.get("data-copy-slot")]
    role_blocks = [node for node in self.elements if node.attrib.get("data-text-role")]
    self.assertEqual(Counter(node.attrib["data-copy-slot"] for node in slot_blocks), Counter(COPY_SLOT_COUNTS))
    self.assertEqual(
        Counter(node.attrib["data-text-role"] for node in role_blocks),
        Counter({name: values[1] for name, values in TEXT_ROLE_MANIFEST.items()}),
    )

    for element in (node for node in self.elements if self.is_renderable_text(node)):
        self.assertEqual(list(element), [], ET.tostring(element, encoding="unicode"))
        self.assertRegex(element.attrib.get("x", ""), SCALAR_NUMBER)
        self.assertRegex(element.attrib.get("y", ""), SCALAR_NUMBER)
        for attribute in FORBIDDEN_TEXT_POSITIONING_ATTRIBUTES:
            self.assertNotIn(attribute, element.attrib, ET.tostring(element, encoding="unicode"))
        block = self.parent.get(element)
        self.assertIsNotNone(block)
        slot_name = block.attrib.get("data-copy-slot") if block is not None else None
        role_name = block.attrib.get("data-text-role") if block is not None else None
        self.assertNotEqual(bool(slot_name), bool(role_name), ET.tostring(element, encoding="unicode"))
        expected_tier = SLOT_TEXT_TIER[slot_name] if slot_name else TEXT_ROLE_MANIFEST[role_name][0]
        self.assertEqual(element.attrib.get("data-text-tier"), expected_tier)
        self.assertGreaterEqual(parse_number(element.attrib["font-size"]), SOURCE_FONT_MINIMUM[expected_tier])

    for slot in slot_blocks:
        slot_name = slot.attrib["data-copy-slot"]
        expected_limit = STAGE_SLOT_LIMITS.get(slot_name, OTHER_SLOT_LIMITS.get(slot_name))
        self.assertIsNotNone(expected_limit, slot_name)
        self.assertEqual(int(slot.attrib["data-max-lines"]), expected_limit)
        direct_lines = [child for child in list(slot) if local_name(child) == "text"]
        descendant_lines = [child for child in slot.iter() if local_name(child) == "text"]
        self.assertEqual(direct_lines, descendant_lines, slot_name)
        self.assertGreater(len(direct_lines), 0, slot_name)
        self.assertLessEqual(len(direct_lines), expected_limit, slot_name)

    for block in role_blocks:
        role_name = block.attrib["data-text-role"]
        _, _, expected_limit = TEXT_ROLE_MANIFEST[role_name]
        self.assertEqual(int(block.attrib["data-max-lines"]), expected_limit)
        direct_lines = [child for child in list(block) if local_name(child) == "text"]
        descendant_lines = [child for child in block.iter() if local_name(child) == "text"]
        self.assertEqual(direct_lines, descendant_lines, role_name)
        self.assertGreater(len(direct_lines), 0, role_name)
        self.assertLessEqual(len(direct_lines), expected_limit, role_name)

    self.assertEqual(self.copy_slot_count("human-governance", "human-group"), 3)
    self.assertEqual(self.copy_slot_count("cross-owner-handoff", "handoff"), 1)
    self.assertEqual(self.copy_slot_count("test-deployment", "gate-step"), 2)
    self.assertEqual(self.copy_slot_count("production-deployment", "gate-step"), 2)
    self.assertEqual(self.copy_slot_count("shared-foundation", "foundation-item"), 4)
    self.assertEqual(self.copy_slot_count("accountable-return-safe-stop", "return-rule"), 1)
    self.assertEqual(self.copy_slot_count("accountable-return-safe-stop", "stop-rule"), 1)
```

Add this deterministic publication parser and gate. Delete any approval trigger or accepted identity derived from the asset README:

```python
ACCEPTED_FIELD_PATTERNS = {
    "date": r"^- Accepted projection date: `(\d{4}-\d{2}-\d{2})`\.$",
    "commit": r"^- Accepted projection commit: `([0-9a-f]{40})`\.$",
    "svg_sha256": r"^- Accepted SVG SHA-256: `([0-9a-f]{64})`\.$",
    "png_sha256": r"^- Accepted PNG SHA-256: `([0-9a-f]{64})`\.$",
}


def unique_match(source: str, pattern: str, label: str) -> str:
    matches = re.findall(pattern, source, re.MULTILINE)
    if len(matches) != 1:
        raise AssertionError(f"expected one {label}, found {len(matches)}")
    return matches[0]


def canonical_projection_record() -> dict[str, str]:
    source = CANONICAL_SPEC.read_text(encoding="utf-8")
    status = unique_match(
        source,
        r"^- Formal SVG/PNG projection status: `([^`]+)`\.$",
        "projection status",
    )
    field_matches = {
        name: re.findall(pattern, source, re.MULTILINE)
        for name, pattern in ACCEPTED_FIELD_PATTERNS.items()
    }
    if status.startswith("DRAFT —"):
        if any(field_matches.values()):
            raise AssertionError("DRAFT projection must not retain accepted identity")
        return {"state": "DRAFT", "status": status}
    if not status.startswith("APPROVED —"):
        raise AssertionError(f"unknown projection lifecycle: {status!r}")
    return {
        "state": "APPROVED",
        "status": status,
        **{
            name: unique_match(source, ACCEPTED_FIELD_PATTERNS[name], name)
            for name in ACCEPTED_FIELD_PATTERNS
        },
    }

def test_canonical_projection_lifecycle_binds_approved_identity_to_current_bytes(self) -> None:
    record = canonical_projection_record()
    if record["state"] == "DRAFT":
        return

    date.fromisoformat(record["date"])
    self.assertEqual(
        subprocess.run(
            ["git", "merge-base", "--is-ancestor", record["commit"], "HEAD"],
            cwd=ROOT,
            check=False,
        ).returncode,
        0,
    )
    self.assertEqual(hashlib.sha256(SVG_PATH.read_bytes()).hexdigest(), record["svg_sha256"])
    self.assertEqual(hashlib.sha256(PNG_PATH.read_bytes()).hexdigest(), record["png_sha256"])
    self.assertEqual(committed_blob(record["commit"], SVG_PATH), SVG_PATH.read_bytes())
    self.assertEqual(committed_blob(record["commit"], PNG_PATH), PNG_PATH.read_bytes())

    targets = markdown_targets(CANONICAL_SPEC)
    for asset in (SVG_PATH, PNG_PATH):
        self.assertTrue(asset.is_file(), asset)
        self.assertFalse(asset.is_symlink(), asset)
        self.assertIn(asset.resolve(), targets, asset)
```

Keep and adapt the existing safety checks for self-contained SVG, prohibited executable/external elements, visible paint, on-canvas coordinates, PNG CRC/decode, PNG SHA binding, and Markdown-link reachability. Change every `1200` canvas/raster expectation to `1080`. The test may lock relative order, containment, counts, text tiers, line budgets, visibility, and overflow safety; it must not lock the complete x/y layout or repeat the canonical Chinese copy in constants.

- [ ] **Step 3: Run the rewritten test and prove it rejects the current candidate**

Run:

```bash
python3 tests/test-one-human-agent-team-architecture-map.py
```

Expected: FAIL because the current SVG has no `data-projection="bplus-l0-v1"` and still declares `0 0 1920 1200`. If it passes, the new test does not distinguish B+ from the rejected candidate and must be strengthened before editing the SVG.

- [ ] **Step 4: Replace the SVG in place with the approved B+ layout**

Use `apply_patch` to rewrite the existing SVG. Implement the exact visible content from `## Chinese Macro Architecture Map Contract` in the canonical specification; do not copy new wording from this plan or the ignored brainstorm HTML.

In the same change, replace only the canonical projection-status line with:

```markdown
- Formal SVG/PNG projection status: `DRAFT — B+ replacement candidate pending exact-byte human acceptance`.
```

Use this initial layout as an implementation starting point, not a test-locked coordinate contract. Coordinates may move when necessary to satisfy the approved hierarchy, source font minima, line budgets, real-browser viewport checks, and cold-reader acceptance; the canvas, region order, five-stage/two-gate sequence, containment, and non-overlap contracts may not move.

| Region | Geometry / rule |
|---|---|
| Header | `x=60..1860`, `y=34..100`; unframed title, proposition, and Chinese status |
| Human band | `x=60 y=118 width=1800 height=124`; one containing frame, three unboxed responsibility groups separated by dividers |
| Cross-Owner handoff | `x=84..1836`, `y=258..286`; unboxed sequence, `data-copy-slot="handoff" data-max-lines="2"` |
| Agent Team | `x=60 y=304 width=1800 height=520`; one containing frame and one short unboxed heading |
| Stage 1 | `x=72 y=358 width=280 height=404` |
| Stage 2 | `x=368 y=358 width=230 height=404` |
| Stage 3 | `x=614 y=358 width=330 height=404` |
| Test gate | `x=960 y=358 width=150 height=404` |
| Stage 4 | `x=1126 y=358 width=230 height=404` |
| Production gate | `x=1372 y=358 width=150 height=404` |
| Stage 5 | `x=1538 y=358 width=300 height=404` |
| Obligation trace | `x=84..1836`, `y=780..808`; one compact unboxed line |
| Shared foundation | `x=60 y=842 width=1800 height=88`; one frame, four unboxed items |
| Return and stop | `x=60 y=950 width=1800 height=88`; one frame split into return and stop text groups |

Every stage uses exactly four semantic copy slots—`purpose`, `integrator`, `completion`, and optional `note`—with the line limits from Step 2. Their rendered text is field-bound: purpose equals the canonical `Why it exists`, integrator equals the canonical `Stage Result Integrator`, completion starts with `本阶段完成标准` and then equals the canonical completion fact, and note equals the canonical note or is absent when the table contains `—`. The completion prefix is the first direct text line inside the five-line completion slot and counts toward that limit. Every gate phrase uses `data-copy-slot="gate-step" data-max-lines="2"`; its canonical role label is rendered separately as `Human｜` or `Quality｜`, preserving the full approved phrase while keeping the two-line explanatory budget independent of the label. Human responsibility groups and shared-foundation items carry `data-order="1..N"`, are visibly left-to-right, and meet the test's minimum anchor separation; each gate's label and phrase carry the same row order, with the label above its phrase and the complete Human row above and non-overlapping with the Quality row. Every visible `<text>` carries `data-text-tier="title|stage-title|body|secondary"`, explicit single-scalar numeric `x`, `y`, `font-size`, and visible `fill`. Use manual line breaks as separate direct `<text>` children inside the applicable slot; whitespace-normalized text must preserve the canonical sentence. Do not use `dx`, `dy`, `rotate`, `textLength`, or `lengthAdjust` to reshape or reposition glyphs.

Implement the Step 2 closed manifests literally: no extra `data-concept`, `data-kind`, painted `<rect>`, copy-slot block, or text-role block is allowed. Every non-slot text block uses one `data-text-role` from `TEXT_ROLE_MANIFEST` and its declared `data-max-lines`; every visible `<text>` is a direct child of exactly one copy-slot or text-role block. Use `data-visual` on every painted rectangle according to `RECT_VISUAL_COUNTS`. Dividers and arrows use `<line>` or `<path>`, not extra framed rectangles.

Use blue for the normal five-stage path, gold for Human authority and both deployment gates, purple for shared support, and red only for the stop condition. Use only the element types in `ALLOWED_SVG_ELEMENTS`. Include exactly one direct-root `<title>` equal to the canonical map title and one direct-root `<desc>` equal to the canonical proposition; both have no attributes or child elements. All other non-`text` elements contain whitespace only outside child elements, and every tail contains whitespace only. Do not include XML comments, nested accessibility prose, any `aria-*` or `title` attribute, or any `data-*` attribute outside `ALLOWED_DATA_ATTRIBUTES`. Use explicit presentation attributes; do not use `<style>`, `style="..."`, `<tspan>`, `foreignObject`, external fonts/assets, hyperlinks, scripts, event attributes, filters, masks, clip paths, `<use>`, transforms, hidden text, or zero-opacity semantics.

Set `data-png-sha256` initially to 64 zeroes. That digest is temporary build metadata, not an approval claim.

- [ ] **Step 5: Render the PNG, bind its digest, and update candidate provenance**

Run from the repository root:

```bash
rsvg-convert -f png -w 1920 -h 1080 \
  -o docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png \
  docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg
shasum -a 256 docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png
```

Copy the literal 64-character PNG digest into the SVG root `data-png-sha256` using `apply_patch`, render again with the same command, and run `shasum -a 256` again. Expected: the second PNG digest is identical because the non-visible root metadata does not affect rendering. If it changes, stop; the SVG-to-PNG binding is not deterministic.

Update the asset README with `apply_patch` so it contains one authority pointer and no independent lifecycle or accepted identity:

```markdown
- Semantic source: [2026-08-03 L0 canonical specification](../../2026-08-03--one-human-agent-team-operating-architecture-l0--design.md)
- Projection lifecycle and accepted identity: maintained only in the canonical specification
- Approved projection contract commit: `fe812224d84600110c139ae7d1c8d63d9235743b`
- Renderer used for the recorded PNG: `rsvg-convert 2.60.0`, `1920×1080`
```

Keep the editable SVG and derived PNG path lines, change the render command to `-w 1920 -h 1080`, and retain the statement that Markdown owns semantics, SVG is the editable projection, and PNG owns no semantics. Do not add `Projection status`, `Accepted projection commit`, or accepted SHA fields to the README.

- [ ] **Step 6: Run structural and raster verification**

Run:

```bash
set -euo pipefail
python3 tests/test-one-human-agent-team-architecture-map.py
xmllint --noout docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg
git diff --check
git diff --name-only
python3 - <<'PY'
from pathlib import Path
import re
import subprocess

path = "docs/superpowers/specs/2026-08-03--one-human-agent-team-operating-architecture-l0--design.md"
base = subprocess.run(["git", "show", f"HEAD:{path}"], check=True, capture_output=True, text=True).stdout
current = Path(path).read_text(encoding="utf-8")
pattern = r"^- Formal SVG/PNG projection status: `[^`]+`\.$"
replacement = "- Formal SVG/PNG projection status: `DRAFT — B+ replacement candidate pending exact-byte human acceptance`."
assert len(re.findall(pattern, base, re.MULTILINE)) == 1
expected = re.sub(pattern, replacement, base, count=1, flags=re.MULTILINE)
assert current == expected, "candidate work changed canonical content beyond the one lifecycle line"
PY
```

Expected: targeted test PASS; XML PASS; no whitespace errors. The changed-path output is exactly the canonical specification, existing test, SVG, PNG, and asset README listed under Task 1. Any other path is out of scope and must be reverted or explicitly re-planned before proceeding.

- [ ] **Step 7: Render the exact 1440×810 acceptance view and inspect it**

This step must use `browser:control-in-app-browser`; before acting, read that skill's `SKILL.md` completely and follow its local-page initialization and inspection procedure. `view_image` is supplemental and cannot satisfy browser acceptance by itself. Use the literal ignored review directory so `apply_patch` has a mechanically resolvable target:

```bash
set -euo pipefail
MAP_REVIEW_DIR=".superpowers/review/bplus-l0-precommit"
mkdir -p "$MAP_REVIEW_DIR"
git check-ignore "$MAP_REVIEW_DIR"
rsvg-convert -f png -w 1440 -h 810 \
  -o "$MAP_REVIEW_DIR/one-human-agent-team-bplus-1440.png" \
  docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg
```

Use `apply_patch` to create `.superpowers/review/bplus-l0-precommit/index.html` with this complete literal content; do not improvise another harness:

```html
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>B+ L0 precommit review</title>
  <style>
    html, body {
      margin: 0;
      width: 1440px;
      height: 810px;
      overflow: hidden;
      background: #ffffff;
    }
    body { display: block; }
    img {
      display: block;
      width: 1440px;
      height: 810px;
    }
  </style>
</head>
<body>
  <img src="./one-human-agent-team-bplus-1440.png" width="1440" height="810" alt="B+ L0 architecture-map candidate">
</body>
</html>
```

Start `python3 -u -m http.server 0 --bind 127.0.0.1 --directory .superpowers/review/bplus-l0-precommit` in a persistent PTY, retain the returned execution `session_id`, and read the assigned loopback port. Before browser work, resolve the currently installed `browser:control-in-app-browser` plugin root, confirm its `scripts/browser-client.mjs` exists, initialize that absolute module through the Node `js` tool, select only `agent.browsers.get("iab")`, and emit/read the complete `nodeRepl.write(await iab.documentation());` result as required by the skill. When the Node `js` call is nested in code-mode `exec`, the outer script begins with the exact first line `// @exec: {"max_output_tokens": 20000}`. Do not use a default, URL-selected, Chrome, Playwright-server, or Computer Use fallback. Open the loopback URL with that `iab` binding.

Treat server cleanup as a `finally` action: on success, browser failure, test failure, interruption, or exception, send Ctrl-C to the retained server `session_id`, poll until the process exits, then prove `curl --fail --max-time 1 <loopback-url>` fails. A live listener or an unretained session ID fails this step.

Set the browser viewport to `1440×810`, reset zoom to 100%, and inspect a browser screenshot. Evaluate these values in the page:

```javascript
({
  innerWidth,
  innerHeight,
  scale: visualViewport.scale,
  scrollWidth: document.documentElement.scrollWidth,
  scrollHeight: document.documentElement.scrollHeight,
  image: (() => {
    const image = document.querySelector("img");
    const rect = image.getBoundingClientRect();
    return {
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
      naturalWidth: image.naturalWidth,
      naturalHeight: image.naturalHeight,
    };
  })(),
})
```

Expected: `innerWidth=1440`, `innerHeight=810`, `scale=1`, document dimensions do not exceed the viewport, image bounds are exactly inside it, and natural dimensions are `1440×810`. Also inspect the tracked PNG and temporary PNG with `view_image(detail="original")`. Complete the mandatory server cleanup above before leaving this step.

Fail this task if either view has clipping, overlap, horizontal truncation, unreadable secondary text, more than the allowed copy lines, a stage card that visually reads as a Team, a deployment gate that reads as a stage, or foundation/stop styling that outranks the five-stage path.

- [ ] **Step 8: Commit the verified draft candidate**

Run:

```bash
git add tests/test-one-human-agent-team-architecture-map.py \
  docs/superpowers/specs/2026-08-03--one-human-agent-team-operating-architecture-l0--design.md \
  docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/README.md \
  docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg \
  docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png
git commit -m "docs: build B+ L0 architecture map candidate"
```

Expected: one commit containing the canonical `DRAFT` lifecycle line plus the test-contract rewrite and its passing SVG/PNG/README implementation. The README contains no lifecycle or accepted identity.

---

### Task 2: Independently Review and Hand Off the Exact Candidate

**Files:**
- Read: `docs/superpowers/specs/2026-08-03--one-human-agent-team-operating-architecture-l0--design.md`
- Read: `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg`
- Read: `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png`
- Read: `tests/test-one-human-agent-team-architecture-map.py`
- No tracked modification unless review finds a defect; any defect returns to Task 1 and produces a new candidate commit.

**Interfaces:**
- Consumes: the committed `DRAFT` candidate from Task 1.
- Produces: current static/raster evidence, three isolated Agent cold-reader preflights, one eligible first-time Chinese business/product Human cold-reader result, one spec-to-image semantic audit, and an exact candidate identity offered to the designing Human. It does not produce publication authority.

- [ ] **Step 1: Prove committed identity and deterministic rendering**

Run:

```bash
set -euo pipefail
test -z "$(git status --short)"
MAP_SVG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg"
MAP_PNG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png"
MAP_PROOF_DIR=".superpowers/review/bplus-l0-candidate"
mkdir -p "$MAP_PROOF_DIR"
git check-ignore "$MAP_PROOF_DIR"
MAP_CANDIDATE_COMMIT="$(git log -1 --format=%H -- "$MAP_SVG" "$MAP_PNG")"
MAP_SVG_SHA256="$(shasum -a 256 "$MAP_SVG" | awk '{print $1}')"
MAP_PNG_SHA256="$(shasum -a 256 "$MAP_PNG" | awk '{print $1}')"
[[ "$MAP_CANDIDATE_COMMIT" =~ ^[0-9a-f]{40}$ ]]
[[ "$MAP_SVG_SHA256" =~ ^[0-9a-f]{64}$ ]]
[[ "$MAP_PNG_SHA256" =~ ^[0-9a-f]{64}$ ]]
git show "$MAP_CANDIDATE_COMMIT:$MAP_SVG" | cmp - "$MAP_SVG"
git show "$MAP_CANDIDATE_COMMIT:$MAP_PNG" | cmp - "$MAP_PNG"
git show "$MAP_CANDIDATE_COMMIT:$MAP_SVG" | rsvg-convert -f png -w 1920 -h 1080 -o "$MAP_PROOF_DIR/a.png"
git show "$MAP_CANDIDATE_COMMIT:$MAP_SVG" | rsvg-convert -f png -w 1920 -h 1080 -o "$MAP_PROOF_DIR/b.png"
cmp "$MAP_PROOF_DIR/a.png" "$MAP_PROOF_DIR/b.png"
cmp "$MAP_PROOF_DIR/a.png" "$MAP_PNG"
git show "$MAP_CANDIDATE_COMMIT:$MAP_SVG" | rsvg-convert -f png -w 1440 -h 810 -o "$MAP_PROOF_DIR/review-1440.png"
MAP_REVIEW_1440_SHA256="$(shasum -a 256 "$MAP_PROOF_DIR/review-1440.png" | awk '{print $1}')"
[[ "$MAP_REVIEW_1440_SHA256" =~ ^[0-9a-f]{64}$ ]]
printf "MAP_CANDIDATE_COMMIT='%s'\nMAP_SVG_SHA256='%s'\nMAP_PNG_SHA256='%s'\nMAP_REVIEW_1440_SHA256='%s'\n" \
  "$MAP_CANDIDATE_COMMIT" "$MAP_SVG_SHA256" "$MAP_PNG_SHA256" "$MAP_REVIEW_1440_SHA256"
```

Expected: fail-fast command returns zero; clean state, formats, committed-byte comparisons, deterministic 1920 rendering, tracked PNG equivalence, and immutable committed 1440 derivation all pass. Copy the command's four literal assignment lines into `.superpowers/review/bplus-l0-candidate/candidate.env` using `apply_patch`; do not redirect shell output or generate the file with Python. Every later Task 2 shell block starts with `set -euo pipefail` and `source .superpowers/review/bplus-l0-candidate/candidate.env`.

- [ ] **Step 2: Run current focused and broad verification**

Run:

```bash
set -euo pipefail
source .superpowers/review/bplus-l0-candidate/candidate.env
MAP_SVG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg"
MAP_PNG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png"
test -z "$(git status --short)"
test "$(shasum -a 256 "$MAP_SVG" | awk '{print $1}')" = "$MAP_SVG_SHA256"
test "$(shasum -a 256 "$MAP_PNG" | awk '{print $1}')" = "$MAP_PNG_SHA256"
test "$(shasum -a 256 .superpowers/review/bplus-l0-candidate/review-1440.png | awk '{print $1}')" = "$MAP_REVIEW_1440_SHA256"
python3 tests/test-one-human-agent-team-architecture-map.py
xmllint --noout "$MAP_SVG"
bash tests/run-all.sh --quick
```

Expected focused evidence: targeted test and XML validation pass. Expected broad evidence under the current baseline: quick gate reaches `rule-runtime-team-readiness-pack` and fails only because `docs/rule-runtime--team-readiness/acceptance-pack.json` is absent. If it fails earlier or differently, treat that as a new blocker and diagnose before handoff.

- [ ] **Step 3: Re-run actual-browser acceptance against the committed candidate**

Before acting, read `browser:control-in-app-browser`'s `SKILL.md` completely. Revalidate the immutable input in a fresh shell:

```bash
set -euo pipefail
source .superpowers/review/bplus-l0-candidate/candidate.env
MAP_SVG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg"
MAP_PNG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png"
test -z "$(git status --short)"
git show "$MAP_CANDIDATE_COMMIT:$MAP_SVG" | cmp - "$MAP_SVG"
git show "$MAP_CANDIDATE_COMMIT:$MAP_PNG" | cmp - "$MAP_PNG"
test "$(shasum -a 256 .superpowers/review/bplus-l0-candidate/review-1440.png | awk '{print $1}')" = "$MAP_REVIEW_1440_SHA256"
```

Use `apply_patch` to create `.superpowers/review/bplus-l0-candidate/index.html` with this complete literal content:

```html
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>B+ L0 committed-candidate review</title>
  <style>
    html, body {
      margin: 0;
      width: 1440px;
      height: 810px;
      overflow: hidden;
      background: #ffffff;
    }
    body { display: block; }
    img {
      display: block;
      width: 1440px;
      height: 810px;
    }
  </style>
</head>
<body>
  <img src="./review-1440.png" width="1440" height="810" alt="B+ L0 committed architecture-map candidate">
</body>
</html>
```

Serve that literal directory on loopback in a persistent PTY and retain its `session_id`. Reuse the Task 1 `iab` binding only if it is still valid; otherwise repeat the skill-mandated absolute-module bootstrap, explicit `agent.browsers.get("iab")` selection, and complete documentation read. With `iab`, set a `1440×810` viewport and 100% zoom, run the exact viewport/image-bounds expression from Task 1, and capture a browser screenshot. On every exit path, send Ctrl-C to the retained server session, poll until exit, and prove the loopback URL no longer responds.

Use `apply_patch` to record the literal candidate commit, SVG/PNG/review SHA values, browser/tool version if exposed, viewport JSON, screenshot path or tool evidence reference, timestamp, cleanup result, and observed PASS/FAIL in `.superpowers/review/bplus-l0-candidate/browser-evidence.md`. This ignored evidence file is not an authority source. After cleanup, rerun the shell checks above. Any mismatch, scroll, scale other than 1, non-1440×810 natural image, clipping, overlap, truncation, hierarchy failure, or leaked server returns to Task 1.

- [ ] **Step 4: Run three image-only fresh-context cold-reader reviews**

Source `candidate.env`, revalidate `review-1440.png` against `MAP_REVIEW_1440_SHA256`, then spawn three independent reviewer agents in parallel with `fork_turns="none"`; default/full-history forks are forbidden. Give each reviewer only the absolute `review-1440.png` path, its expected SHA-256, and the two-round protocol below—not this plan, the canonical specification, prior chat, browser evidence, or implementation rationale. Each reviewer must verify the file hash before timing begins. Reuse the same isolated reviewer for its second round; do not let reviewers see one another's answers.

Round A is the 10-second organization scan. Use this exact prompt:

```text
你是隔离的新读者，只能依据给定 PNG。禁止读取 SVG、仓库文档、计划或聊天背景。
1. 用 Python 输出开始时间 time.time_ns()。
2. 只调用一次 view_image 打开 PNG；不得截图、下载、复制或再次打开。
3. 立即再次输出 time.time_ns()。两次时间差必须不超过 10 秒；超时就明确写 TIMING_FAIL，不得补看。
4. 从这一次观察的记忆回答：这是几个人类治理主体、几支 Agent Team、几个有顺序的交付阶段？按顺序写阶段名。
5. 返回开始时间、结束时间、毫秒差、答案，以及任何第一眼误读。不要解释作者可能想表达什么。
```

Round B is the 60-second content test. Only after Round A is recorded, send this exact follow-up to the same reviewer:

```text
继续保持隔离，只依据同一 PNG。
1. 用 Python 输出开始时间 time.time_ns()。
2. 只再调用一次 view_image；在准备好回答时立即再次输出 time.time_ns()，两次时间差必须不超过 60 秒。超时写 TIMING_FAIL；结束计时后不得再打开图片。
3. 分别说明第 1 到第 5 阶段：为什么存在、谁推进、哪些可观察事实成立才算完成。五个阶段必须逐一回答，不能任选。
4. 按图复述跨专业交接的四个动作；再说明下游靠哪些共同规则获得当前、足够、独立且可靠的支持。
5. 两个黄色部署边界分别发生在哪里？部署动作是否等于质量验收、线上技术结果、业务验收、单次范围决定或整体需求决定？逐项区分。
6. 发现问题后回给谁，谁复验？哪些情况必须停止？
7. 指出任何看不清、容易误读、信息过密或职责倒置的地方。
8. 返回开始时间、结束时间、毫秒差和答案；不要猜作者意图。
```

Acceptance: all three Round A results have observable deltas of at most 10 seconds and identify one Human, one Agent Team, and all five stages in order. All three Round B results have deltas of at most 60 seconds; separately and correctly explain every stage's purpose, integrator, and completion facts; reproduce the four-step handoff and shared-support meaning; distinguish deployment from Quality acceptance, production behavior, business acceptance, per-scope disposition, and whole-Demand disposition; and locate accountable return and stop. Any timing failure, material misread, invented missing rule, input-hash mismatch, or contaminated reviewer context returns to Task 1 and invalidates all candidate review evidence.

Using `apply_patch`, store each reviewer's raw two-round answers, timestamps, fork isolation mode, reviewer task ID, candidate commit, and input SHA in `.superpowers/review/bplus-l0-candidate/cold-read-evidence.md`. Record this as a `fresh-context timed-agent proxy`: the fork and tool timestamps are observable, but they are not a laboratory human-usability study and must not be reported as one.

- [ ] **Step 5: Obtain the canonical first-time Human cold-reader evidence**

The Agent proxy above is a preflight, not the canonical reader acceptance. Before publication, the Human must recruit at least one Chinese-speaking business or product reader who has never seen this map, the canonical specification, the implementation plan, or the design discussion. This person is a temporary validation participant, not a delivery-team role. The designing Human, any Agent, and anyone previously briefed on the architecture are ineligible.

Bind the session to the same immutable `review-1440.png` and `MAP_REVIEW_1440_SHA256`. A facilitator displays only that image at exactly `1440×810`, 100% scale, without explanation or labels outside the image:

1. Round A: before showing the image, read only `请判断图中有几个人类治理主体、几支 Agent Team、几个有顺序的交付阶段，并按顺序说出全部阶段名。` Record wall-clock start, show the image for at most 10 seconds, hide it when the reader says they are ready or at 10 seconds, record stop, then capture the answer from memory.
2. Round B: after recording Round A without correction, read the following questions exactly, record a new start, show the same image for at most 60 seconds, hide it when the reader says they are ready or at 60 seconds, record stop, then capture the answer from memory:

```text
分别说明第 1 到第 5 阶段：为什么存在、谁推进、哪些可观察事实成立才算完成。五个阶段必须逐一回答。
按图复述跨专业交接的四个动作；再说明下游靠哪些共同规则获得当前、足够、独立且可靠的支持。
两个黄色部署边界分别发生在哪里？部署动作是否等于质量验收、线上技术结果、业务验收、本次范围决定或整体需求决定？逐项区分。
发现问题后回给谁，谁复验？哪些情况必须停止？
指出任何看不清、容易误读、信息过密或职责倒置的地方。
```

   Do not coach, paraphrase, reopen the image, or correct an answer before the raw response is complete.
3. Record a pseudonymous participant ID, the participant's self-attested Chinese business/product background and first-exposure status, facilitator ID, date/time/timezone, both measured durations, candidate commit and hashes, display size/scale, exact prompts, raw answers, first misreads, and PASS/FAIL. Do not record a real name or other unnecessary personal data.

Using `apply_patch`, store the raw record in `.superpowers/review/bplus-l0-candidate/human-cold-read-evidence.md`; the Human confirms the record is accurate. Acceptance is identical to Step 4: Round A is at most 10 seconds and correctly identifies one Human, one Agent Team, and all five stages in order; Round B is at most 60 seconds and correctly covers every stage purpose/integrator/completion fact, both deployment boundaries and their distinctions, the four-step handoff, shared support, accountable return, and safe stop. Any timing failure, material omission or misread, prior exposure, coaching, scale mismatch, or candidate-hash mismatch returns to Task 1 and invalidates the session. If no eligible reader is available, stop with the candidate still `DRAFT`; neither Agent proxy nor exact-byte owner approval may waive this canonical test.

- [ ] **Step 6: Run one independent spec-to-image semantic audit**

Spawn one additional reviewer with `fork_turns="none"`; do not fork prior discussion or provide implementation rationale. Give it only these candidate-bound inputs: approved-contract commit `fe812224d84600110c139ae7d1c8d63d9235743b`; current canonical path; candidate commit and hashes from `candidate.env`; exact SVG, asset README, targeted test, tracked `1920×1080` PNG, committed-derived `review-1440.png`, `browser-evidence.md`, `cold-read-evidence.md`, and `human-cold-read-evidence.md`. Require it to verify every supplied hash and candidate blob before reviewing. Ask it to report only P0/P1 for:

```text
- required visible content omitted or materially weakened;
- visible content that invents architecture semantics;
- Stage 3→4 release/deployment/Quality responsibility collapse;
- deployment, Quality, production verification, business acceptance, or Phase/Demand decision being merged;
- L1/Owner detail leaking back into L0;
- 1440×810 font, line, clipping, overlap, or hierarchy violations;
- SVG/PNG becoming a second semantic source.
```

Acceptance: all input-identity checks pass, the Human cold-reader record is bound to the candidate and satisfies the canonical protocol, and no P0/P1 remains. Using `apply_patch`, copy the raw audit, reviewer task ID, fork mode, candidate identity, input hashes, and verdict into `.superpowers/review/bplus-l0-candidate/semantic-audit.md`. Any fix creates a new candidate commit and invalidates every earlier render, browser, Agent proxy, Human cold-read, audit, hash, and approval result.

- [ ] **Step 7: Present the exact candidate and stop for Human approval**

In a fresh shell, rebind every value from the ignored manifest and prove nothing changed:

```bash
set -euo pipefail
source .superpowers/review/bplus-l0-candidate/candidate.env
MAP_SVG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg"
MAP_PNG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png"
test -z "$(git status --short)"
git show "$MAP_CANDIDATE_COMMIT:$MAP_SVG" | cmp - "$MAP_SVG"
git show "$MAP_CANDIDATE_COMMIT:$MAP_PNG" | cmp - "$MAP_PNG"
test "$(shasum -a 256 "$MAP_SVG" | awk '{print $1}')" = "$MAP_SVG_SHA256"
test "$(shasum -a 256 "$MAP_PNG" | awk '{print $1}')" = "$MAP_PNG_SHA256"
test "$(shasum -a 256 .superpowers/review/bplus-l0-candidate/review-1440.png | awk '{print $1}')" = "$MAP_REVIEW_1440_SHA256"
printf 'Candidate commit: %s\nSVG SHA-256: %s\nPNG SHA-256: %s\nProjection status: DRAFT\n' \
  "$MAP_CANDIDATE_COMMIT" "$MAP_SVG_SHA256" "$MAP_PNG_SHA256"
```

Display the tracked committed PNG directly, link the SVG and PNG, and paste that command's literal four-line output into the user-facing approval request. Cite the committed-browser, Agent-proxy, eligible Human cold-reader, and semantic-audit verdicts without overstating them.

Ask the Human to approve those exact bytes or identify changes. Do not execute Task 3 on silence, `差不多`, design-contract approval, or approval of an older candidate. An unambiguous reply to the message containing the exact commit and both hashes is required.

---

### Task 3: Publish Only the Exact Human-Approved Projection

**Files:**
- Modify: `docs/superpowers/specs/2026-08-03--one-human-agent-team-operating-architecture-l0--design.md`
- Modify: `docs/superpowers/plans/2026-08-05--one-human-agent-team-bplus-l0-map.md` — close this plan without duplicating accepted identity
- Read/verify only: asset README, test, SVG, and PNG

**Interfaces:**
- Consumes: the literal candidate commit, SVG SHA-256, and PNG SHA-256 from the exact approval request and the Human's unambiguous approval of those values.
- Produces: one canonical `APPROVED` non-normative projection record, canonical links to the exact SVG/PNG, completed Design Sequence steps 2–5, and a closed implementation plan. It closes only the L0 human-navigation gate; it does not authorize Owner implementation, Skill changes, or runtime automation.

- [ ] **Step 1: Bind publication to the approved literals before editing**

Run `mkdir -p .superpowers/review/bplus-l0-approved`, verify the directory is ignored, then use `apply_patch` to create `.superpowers/review/bplus-l0-approved/approval.env` with four single-quoted literal assignments copied from the approved request and approval date: `MAP_APPROVAL_DATE`, `MAP_APPROVED_COMMIT`, `MAP_APPROVED_SVG_SHA256`, and `MAP_APPROVED_PNG_SHA256`. Do not infer or recompute an approved value. Then run:

```bash
set -euo pipefail
git check-ignore .superpowers/review/bplus-l0-approved/approval.env
source .superpowers/review/bplus-l0-approved/approval.env
[[ "$MAP_APPROVAL_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
[[ "$MAP_APPROVED_COMMIT" =~ ^[0-9a-f]{40}$ ]]
[[ "$MAP_APPROVED_SVG_SHA256" =~ ^[0-9a-f]{64}$ ]]
[[ "$MAP_APPROVED_PNG_SHA256" =~ ^[0-9a-f]{64}$ ]]
MAP_SVG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg"
MAP_PNG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png"
git merge-base --is-ancestor "$MAP_APPROVED_COMMIT" HEAD
test "$(shasum -a 256 "$MAP_SVG" | awk '{print $1}')" = "$MAP_APPROVED_SVG_SHA256"
test "$(shasum -a 256 "$MAP_PNG" | awk '{print $1}')" = "$MAP_APPROVED_PNG_SHA256"
git show "$MAP_APPROVED_COMMIT:$MAP_SVG" | cmp - "$MAP_SVG"
git show "$MAP_APPROVED_COMMIT:$MAP_PNG" | cmp - "$MAP_PNG"
test -z "$(git status --short)"
```

Expected: every check passes. Unrelated commits may follow the candidate, so current `HEAD` need not equal the candidate commit; the approved commit must be reachable and the current asset bytes must still equal its blobs and approved hashes. Any asset mismatch invalidates approval and returns to Task 1 for a new candidate, then Task 2 for new review; do not repair it during publication.

- [ ] **Step 2: Record accepted identity only in the canonical specification**

Print the exact canonical identity block, substituting the literal Human-approval date and approved values:

```bash
set -euo pipefail
source .superpowers/review/bplus-l0-approved/approval.env
printf '%s\n' \
  '- Formal SVG/PNG projection status: `APPROVED — exact candidate bytes accepted by the Human before publication`.' \
  "- Accepted projection date: \`$MAP_APPROVAL_DATE\`." \
  "- Accepted projection commit: \`$MAP_APPROVED_COMMIT\`." \
  "- Accepted SVG SHA-256: \`$MAP_APPROVED_SVG_SHA256\`." \
  "- Accepted PNG SHA-256: \`$MAP_APPROVED_PNG_SHA256\`."
```

Copy that literal output into the canonical `## Status` section with `apply_patch`, replacing the Task 1 DRAFT projection-status line. Do not derive new identity values after editing. The README remains unchanged and continues to point lifecycle and accepted identity to the canonical specification.

Update `Current authority` so it says the exact accepted map closes only the L0 human-navigation gate and the canonical specification alone permits the next separately designed Owner-domain step. It must still say the map does not authorize Owner implementation, Skill changes, or runtime automation.

Immediately after `## Chinese Macro Architecture Map Contract`, add links without copying architecture prose:

```markdown
> Accepted non-normative navigation projection: [SVG](assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg) · [PNG](assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png). The written specification remains the sole semantic source.
```

In `## Design Sequence After B+ Written Approval`, mark steps 2–5 completed with their actual dates/evidence; leave steps 6–10 pending. Do not claim any Owner, Skill, runtime, or case-validation progress.

- [ ] **Step 3: Close this implementation plan without copying accepted identity**

Use `apply_patch` to replace this plan's `## Status` body with:

```markdown
- `CLOSED — DO NOT EXECUTE`.
- Tasks 1–3 produced, reviewed, and published the exact Human-approved B+ L0 projection.
- Projection lifecycle and accepted-byte identity are authoritative only in the canonical specification.
- This plan is historical execution evidence; Owner-domain work requires a separate approved design and plan.
```

Do not add the accepted commit or hashes here. The canonical specification is the single identity registry.

- [ ] **Step 4: Prove publication governance and current bytes**

Run:

```bash
set -euo pipefail
source .superpowers/review/bplus-l0-approved/approval.env
MAP_SVG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg"
MAP_PNG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png"
python3 tests/test-one-human-agent-team-architecture-map.py
xmllint --noout docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg
git diff --exit-code -- "$MAP_SVG" "$MAP_PNG"
git show "$MAP_APPROVED_COMMIT:$MAP_SVG" | cmp - "$MAP_SVG"
git show "$MAP_APPROVED_COMMIT:$MAP_PNG" | cmp - "$MAP_PNG"
git diff --check
bash tests/run-all.sh --quick
```

Expected focused evidence: targeted test passes, including canonical accepted-identity parsing, link resolution, current hashes, and candidate-blob comparison; XML, byte-preservation, and diff checks pass. The broad quick gate may retain only the previously observed unrelated missing acceptance-pack failure; any new or earlier failure blocks publication completion.

- [ ] **Step 5: Commit publication and verify the final tree**

Run:

```bash
git add docs/superpowers/specs/2026-08-03--one-human-agent-team-operating-architecture-l0--design.md \
  docs/superpowers/plans/2026-08-05--one-human-agent-team-bplus-l0-map.md
git commit -m "docs: publish approved B+ L0 architecture map"
git status --short
git log -2 --oneline --decorate
```

Expected: publication commit succeeds; worktree is clean; candidate commit remains the sole recorded accepted byte identity; publication commit contains only canonical governance/identity plus the plan closure and does not mutate the README, test, SVG, or PNG.

---

## Plan Self-Review

- **Spec coverage:** Task 1 covers the B+ view boundary, canonical-derived visible copy, five stages, Stage 3→4 boundary, two deployment gates, support/return/stop, Chinese-first hierarchy, 16:9 canvas, real-browser 1440 font/line/overflow checks, and the current L0 role-inventory exclusion. Task 2 covers deterministic rendering, isolated Agent preflight, eligible first-time Chinese business/product Human cold reading, semantic comparison, and exact-byte handoff. Task 3 covers canonical-only approval identity, link reachability, plan closure, and publication without byte mutation.
- **Failure-path coverage:** the current dense map must fail the new test; any visual/semantic review defect creates a new candidate and invalidates old hashes; any publication identity mismatch returns to review; quick-gate drift becomes a blocker rather than being hidden.
- **Preserved behavior:** canonical architecture semantics and historical R4 bytes remain unchanged during candidate work; only canonical projection lifecycle changes from rejected DRAFT to replacement DRAFT and later exact-byte APPROVED. Current asset paths, renderer, test registration, canonical pointers, and SVG→PNG ownership are reused.
- **Scope exclusions:** no L1, Owner design, Skill, runtime, automation, project case, new dependency, renderer, or test-registration change.
- **Evidence levels:** XML/test/link checks are `local`; deterministic raster comparison and actual-browser 1440 inspection are `local visual`; isolated timestamped Agent reviews are a `fresh-context timed-agent proxy`; the eligible reader protocol is `manual first-time Human evidence`, not a laboratory study; exact candidate-byte approval is separate `manual owner evidence`. None proves the one-human-plus-Agent-Team runtime, which remains unimplemented.
