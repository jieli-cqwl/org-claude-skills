"""Shared helpers for delivery-estimator schedule calculations."""

from __future__ import annotations

import json
import math
from datetime import date, timedelta
from pathlib import Path
from typing import Any


Z_P80 = 0.84
Z_P95 = 1.645
DEFAULT_HOURS_PER_DAY = 8.0
DEFAULT_REBASELINE_RULES = [
    "scope or AC changes",
    "critical path task fails verification",
    "external dependency or readiness task fails",
    "QA main path fails",
    "verification rounds exceed estimate assumptions",
]
ESTIMATE_KEYS = ("optimistic", "most_likely", "pessimistic")
WEEKDAYS = {"mon": 0, "tue": 1, "wed": 2, "thu": 3, "fri": 4, "sat": 5, "sun": 6}


class EstimateError(Exception):
    """Raised for user-correctable estimate input problems."""


def rounded(value: float) -> float:
    return round(value + 1e-9, 2)


def read_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise EstimateError(f"input file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise EstimateError(f"invalid JSON in {path}: {exc}") from exc


def require_number(value: Any, field: str, task_id: str) -> float:
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return float(value)
    raise EstimateError(f"{task_id}.{field} must be a number")


def read_estimate(block: Any, field: str, task_id: str) -> tuple[float, float, float]:
    if not isinstance(block, dict):
        raise EstimateError(f"{task_id}.{field} must be an object")
    values = tuple(require_number(block.get(key), f"{field}.{key}", task_id) for key in ESTIMATE_KEYS)
    if values[0] > values[1] or values[1] > values[2]:
        raise EstimateError(f"{task_id}.{field} must satisfy optimistic <= most_likely <= pessimistic")
    return values


def pert(values: tuple[float, float, float]) -> tuple[float, float, float]:
    optimistic, most_likely, pessimistic = values
    expected = (optimistic + 4 * most_likely + pessimistic) / 6
    sigma = (pessimistic - optimistic) / 6
    return expected, sigma, sigma * sigma


def as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else ([] if value in (None, "") else [value])


class WorkCalendar:
    def __init__(self, payload: dict[str, Any]) -> None:
        block = payload.get("calendar", {})
        self.hours_per_day = float(block.get("hours_per_day", DEFAULT_HOURS_PER_DAY))
        if self.hours_per_day <= 0:
            raise EstimateError("calendar.hours_per_day must be greater than 0")
        self.working_days = self._parse_working_days(block.get("working_days"))
        raw_start = payload.get("project_start_date") or payload.get("start_date") or date.today().isoformat()
        try:
            self.start = date.fromisoformat(str(raw_start))
        except ValueError as exc:
            raise EstimateError(f"project_start_date must be YYYY-MM-DD: {raw_start}") from exc

    def _parse_working_days(self, value: Any) -> set[int]:
        if value in (None, ""):
            return {0, 1, 2, 3, 4}
        days: set[int] = set()
        for item in as_list(value):
            if isinstance(item, int):
                if item < 0 or item > 6:
                    raise EstimateError(f"calendar.working_days value out of range: {item}")
                days.add(item)
                continue
            key = str(item).strip().lower()[:3]
            if key not in WEEKDAYS:
                raise EstimateError(f"unknown calendar.working_days value: {item}")
            days.add(WEEKDAYS[key])
        if not days:
            raise EstimateError("calendar.working_days must not be empty")
        return days

    def add_workdays(self, start: date, offset_days: int) -> date:
        current = start
        step = 0
        while step < offset_days or current.weekday() not in self.working_days:
            current += timedelta(days=1)
            if current.weekday() in self.working_days:
                step += 1
        return current

    def start_date_for(self, offset_hours: float) -> str:
        day_offset = int(math.floor(max(0.0, offset_hours + 1e-9) / self.hours_per_day))
        return self.add_workdays(self.start, day_offset).isoformat()

    def finish_date_for(self, finish_hours: float) -> str:
        days = max(1, int(math.ceil(max(0.0, finish_hours) / self.hours_per_day - 1e-9)))
        return self.add_workdays(self.start, days - 1).isoformat()

    def duration_days(self, hours: float) -> int:
        return max(1, int(math.ceil(max(0.0, hours) / self.hours_per_day - 1e-9)))
