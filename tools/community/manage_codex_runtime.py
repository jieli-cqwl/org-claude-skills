#!/usr/bin/env python3
"""CLI entrypoint for Codex runtime config and hooks.json management."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from codex_runtime_agents import ensure_codex_agent_config
from codex_runtime_features import ensure_feature_enabled, restore_feature
from codex_runtime_hooks import cleanup_hooks, merge_hooks


def build_parser() -> argparse.ArgumentParser:
    """Build the subcommand parser used by install.sh and uninstall flows."""
    parser = argparse.ArgumentParser(
        description="Manage Codex runtime config and hooks.json."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    enable = subparsers.add_parser("enable-feature")
    enable.add_argument("--config", required=True)
    enable.add_argument("--state", required=True)

    restore = subparsers.add_parser("restore-feature")
    restore.add_argument("--config", required=True)
    restore.add_argument("--state", required=True)

    merge = subparsers.add_parser("merge-hooks")
    merge.add_argument("--hooks-file", required=True)
    merge.add_argument("--managed-file", required=True)
    merge.add_argument("--managed-root", required=True)

    cleanup = subparsers.add_parser("cleanup-hooks")
    cleanup.add_argument("--hooks-file", required=True)
    cleanup.add_argument("--managed-root", required=True)
    cleanup.add_argument("--managed-file")

    configure_agents = subparsers.add_parser("configure-agents")
    configure_agents.add_argument("--config", required=True)
    return parser


def main() -> int:
    """Dispatch CLI subcommands to focused runtime management modules."""
    args = build_parser().parse_args()
    handlers = {
        "enable-feature": run_enable_feature,
        "restore-feature": run_restore_feature,
        "merge-hooks": run_merge_hooks,
        "cleanup-hooks": run_cleanup_hooks,
        "configure-agents": run_configure_agents,
    }
    handler = handlers.get(args.command)
    if handler is None:
        raise ValueError(f"unknown command: {args.command}")
    handler(args)
    return 0


def run_enable_feature(args: argparse.Namespace) -> None:
    """Enable the Codex hooks feature flag for managed hook support."""
    ensure_feature_enabled(Path(args.config), Path(args.state))


def run_restore_feature(args: argparse.Namespace) -> None:
    """Restore the user-owned hooks feature flag after uninstall."""
    restore_feature(Path(args.config), Path(args.state))


def run_merge_hooks(args: argparse.Namespace) -> None:
    """Merge managed hooks into hooks.json while preserving supported user hooks."""
    merge_hooks(Path(args.hooks_file), Path(args.managed_file), Path(args.managed_root))


def run_cleanup_hooks(args: argparse.Namespace) -> None:
    """Remove managed hooks from hooks.json during uninstall or repair."""
    cleanup_hooks(
        Path(args.hooks_file),
        Path(args.managed_root),
        Path(args.managed_file) if args.managed_file else None,
    )


def run_configure_agents(args: argparse.Namespace) -> None:
    """Write managed Codex multi-agent settings into config.toml."""
    ensure_codex_agent_config(Path(args.config))


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover
        print(f"FATAL: {exc}", file=sys.stderr)
        raise SystemExit(1)
