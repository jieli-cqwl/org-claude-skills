# Document Governance

Documents must preserve one current source of truth for active work, runtime defaults, handoff, archive, and canonical state.

- Use `--` between managed path semantic segments and `-` inside a segment; do not keep same-meaning sibling directories with different separator styles.
- Rename a managed path only when required for the current outcome; synchronize `contracts/active-doc-scope.yaml`, entry refs, tests, fixtures, runtime references, and recovery paths.
- Keep `shared/assistant.md` limited to installed runtime defaults; never store project-specific state, memory, migration details, PRDs, designs, tasks, or acceptance facts there.
- Put active project state in the managed active-doc location or canonical artifact required by the repo contract; do not create a second source of truth.
- When behavior, rules, contracts, tools, tests, or runtime entrypoints change the same constraint, update the affected docs in the same change or state exactly why they are out of scope.
- A stale doc is any doc that conflicts with current code, contracts, scope registry, accepted decisions, canonical artifacts, or validation output.
- Fix or archive stale docs that are in scope, block verification, remain referenced by active paths, or would mislead current delivery; report out-of-scope stale docs without expanding work.
- Completion for behavior, constraint, or document-governance changes requires current evidence that in-scope docs, refs, fixtures, and runtime references are synchronized.
- Archive docs no longer used as current facts under `docs/archive/`.
- Do not use `docs/archive/` as default handoff input unless the user explicitly asks for historical audit, archive recovery, or provenance.
- Before archiving or renaming, clear or update active-doc, test, fixture, runtime, and validator references; move validation/runtime-consumed material to a stable fixture or reference location.
- When a managed feature or task is completed and has no active inbound refs, archive the whole directory under `docs/archive/{feature-or-task}/` or keep it active with explicit current ownership and scope.
- When archiving a scope-registry entry, set `management_status: legacy`, write `archive_ref` and `archived_at`, and preserve a recoverable `worklog.md`.
- Resume active work from `contracts/active-doc-scope.yaml` entries whose `management_status` is `managed` or `migrated`; unmanaged `docs/*` paths are not active handoff candidates.
- Use `worklog.md` only for handoff navigation and contract-required status pointers; do not copy full PRDs, designs, task lists, acceptance details, or canonical state into it.
- For standard-chain work, `worklog.md` must point through `state_ref` and `next_ref` to resolvable `canonical:` refs, not replace the canonical artifact.
- In standard-chain, canonical JSON and `artifact-registry.active_revision_id` define active artifact truth; human projections, chat notes, worklog text, and legacy Markdown are background only.
- If the registry, worklog, archive, and canonical artifacts disagree, stop and report the source-of-truth conflict; do not choose the convenient source.
- Prove handoff, archive recovery, and reference reachability with `validate_context_contract.py`, `recover_context.py`, `tools/validate-contracts.sh`, or targeted tests.
- Test: Would a downstream agent recover the same active scope, source of truth, artifact refs, and archive boundary without project memory in runtime defaults? If not, fix the docs or report blocked.
