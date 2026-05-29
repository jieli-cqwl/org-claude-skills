from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from types import ModuleType
from typing import Any

_SHARED: ModuleType | None = None
_PLAN: ModuleType | None = None
_VALIDATE: ModuleType | None = None
_PREFLIGHT: ModuleType | None = None


def load_module(name: str) -> ModuleType:
    module_path = Path(__file__).resolve().with_name(f"{name}.py")
    spec = importlib.util.spec_from_file_location(name, module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"failed to load {module_path}")
    if spec.name in sys.modules:
        return sys.modules[spec.name]
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def shared() -> ModuleType:
    global _SHARED
    if _SHARED is None:
        _SHARED = load_module("qft_branch_flow_shared")
    return _SHARED


def plan_module() -> ModuleType:
    global _PLAN
    if _PLAN is None:
        _PLAN = load_module("qft_branch_flow_plan")
    return _PLAN


def validate_module() -> ModuleType:
    global _VALIDATE
    if _VALIDATE is None:
        _VALIDATE = load_module("qft_branch_flow_validate")
    return _VALIDATE


def preflight_module() -> ModuleType:
    global _PREFLIGHT
    if _PREFLIGHT is None:
        _PREFLIGHT = load_module("qft_branch_flow_preflight")
    return _PREFLIGHT


FlowError = shared().FlowError


def make_plan(args: Any) -> dict[str, Any]:
    return plan_module().make_plan(args)


def validate_plan(plan: dict[str, Any]) -> None:
    validate_module().validate_plan(plan)


def preflight_plan(
    plan: dict[str, Any], repo_root: str | None = None
) -> dict[str, Any]:
    return preflight_module().preflight_plan(plan, repo_root)


def read_input_plan(path: str | None) -> dict[str, Any]:
    return shared().read_input_plan(path)
