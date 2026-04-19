# skill-runtime-manual-only-visibility Changelog

## 2026-04-18 - install-layer-manual-only

- Archived `2026-04-18-install-layer-manual-only` after it was integrated into `main` at `9b85ca2`.
- Centralized low-frequency skill manual-only visibility in `install.sh` so Claude and Codex share one install-layer source of truth.
- Preserved vendored `SKILL.md` sources and kept `webapp-testing` auto-visible while runtime tests prove the behavior.
