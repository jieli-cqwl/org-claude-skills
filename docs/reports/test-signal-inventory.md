# Test Signal Inventory

This report records test asset disposition for the test signal governance cleanup.

## Decision rule

Every test starts as a delete candidate. A test is kept only when it protects a real user path, release path, role/contract boundary, upstream mirror boundary, or runtime gate, and when its failure is actionable.

## Disposition values

- Keep: protect a critical real path with low cost and actionable failure.
- Rewrite: risk is real, but the current test shape freezes prose or duplicates weak checks.
- Move: useful outside quick; belongs in full/release or manual/local-only validation.
- Delete: no proven real risk, duplicate of harder coverage, or prose freeze without a consumer contract.

## First execution batch

| Test file | Disposition | Gate owner | Protected risk | Evidence | Action |
| --- | --- | --- | --- | --- | --- |
| `tests/test-superpowers-upstream-fidelity.sh` | Keep | quick/full/release | `community/superpowers` mirror pollution or local overlay drift | Runs upstream fidelity checker with negative fixtures | Keep in quick |
| `tests/test-context-contract-validator.sh` | Keep | quick/full/release | Invalid canonical refs or context registry drift pass validation | Runs validator with valid and invalid fixtures | Keep in quick |
| `tests/test-context-contract-hook.sh` | Keep | quick/full/release | Runtime hooks fail to block bad context or unsafe handler paths | Runs hook wrapper and negative cases | Keep in quick |
| `tests/test-standard-chain-readiness-gate.sh` | Keep | quick/full/release | Standard-chain closeout passes with missing or failed artifacts | Runs readiness gate against golden and mutated fixtures | Keep in quick |
| `tests/test-release-metadata.sh` | Move | full/release | Release metadata, changelog, version, or notes drift | Runs release metadata validator | Exclude from quick; keep in full/release |
| `tests/test-doc-management-rule-contract.sh` | Delete | none | Not proven | Freezes rule-document prose with no executable validator path | Delete file and runner references |
| `tests/test-skill-refiner-agent-loop.sh` | Delete | none | Not proven | Freezes skill-refiner prose while harder completion/evidence gates exist | Delete file and runner references |
| `tests/test-product-capability-structure-redesign.sh` | Delete | none | Not proven | Duplicates product role/stability structure through broad prose checks | Delete file and runner references |
| `tests/test-product-eval-contract.sh` | Move | full/release | Eval assets or runner output contract drift | Useful static/eval asset check, not a quick user-path gate | Exclude from quick |
| `tests/test-product-context-signal-quality.sh` | Move | full/release | Product prompt signal quality drift | Mostly prose/noise scan; not quick-critical | Exclude from quick pending rewrite/delete |
| `tests/test-developer-process-compliance-contract.sh` | Move | full/release | Developer process guidance drift | Mostly static prose checks; runtime proof tests are harder | Exclude from quick pending rewrite/delete |
| `tests/test-standard-chain-skill-structure.sh` | Move | full/release | Standard-chain role/contract structure drift | Static skill-structure check; validators cover harder runtime boundaries | Exclude from quick pending rewrite/delete |
| `tests/test-review-fix-redesign-contract.sh` | Keep | quick/full/release | Review loop loses fail-close or structured findings | Structural checks delegate behavior to executable scenario fixtures | Prose locks removed |
| `tests/test-product-role-split-contract.sh` | Keep | quick/full/release | Product Director/Manager machine boundary drift | Manifest, hook registry, standard-chain, and JSON template checks | Prose locks removed |
| `tests/test-product-stability-guidance-contract.sh` | Keep | quick/full/release | Product Director output template or completion gate drift | jq manifest/template checks plus completion gate fixture execution | Prose locks removed |

## Runner tier baseline

These release-heavy tests remain in full/release and are intentionally excluded from quick:

| Test file | Disposition | Gate owner | Protected risk | Evidence | Action |
| --- | --- | --- | --- | --- | --- |
| `tests/test-install-core.sh` | Move | full/release | Installer core path drift | Runs install scenario with broad fixture setup | Exclude from quick; keep in full/release |
| `tests/test-install-runtime-smoke.sh` | Move | full/release | Runtime smoke install drift | Runs install/runtime smoke path | Exclude from quick; keep in full/release |
| `tests/test-install-safety.sh` | Move | full/release | Install safety regression | Runs safety checks with install fixtures | Exclude from quick; keep in full/release |
| `tests/test-install-runtime.sh` | Move | full/release | Runtime install behavior drift | Runs full install/runtime scenarios | Exclude from quick; keep in full/release |
| `tests/test-install-migration.sh` | Move | full/release | Migration path drift | Runs install migration scenarios | Exclude from quick; keep in full/release |
| `tests/test-install-retired-skill-cleanup.sh` | Move | full/release | Retired skill cleanup regression | Runs cleanup scenario with installed assets | Exclude from quick; keep in full/release |
| `tests/test-runtime-integrity.sh` | Move | full/release | Runtime integrity regression | Runs broad runtime integrity checks | Exclude from quick; keep in full/release |
| `tests/test-platform-runtime-noise.sh` | Move | full/release | Platform runtime noise regression | Runs platform-specific runtime checks | Exclude from quick; keep in full/release |
| `tests/test-codex-skill-adapter.sh` | Move | full/release | Codex adapter runtime drift | Runs Codex skill adapter scenario | Exclude from quick; keep in full/release |

## Current first-batch target

- Delete 3 files.
- Move 5 signal/prose files out of quick.
- Keep 9 release-heavy runtime/install tests in full/release only.
- Rewrite 3 files to executable contracts.
- Keep hard-signal runtime/mirror/context tests in quick.
