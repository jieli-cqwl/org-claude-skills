#!/usr/bin/env python3
"""Regression tests for the delivery-estimator deterministic schedule calculator."""

from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "shared/skills/delivery-estimator/scripts/estimate_schedule.py"


def run_calculator(payload: dict) -> dict:
    with tempfile.TemporaryDirectory() as tmp_dir:
        input_path = Path(tmp_dir) / "estimate-input.json"
        input_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
        proc = subprocess.run(
            ["python3", str(SCRIPT), "--input", str(input_path), "--output", "-"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def sample_payload() -> dict:
    return {
        "request_name": "membership-benefit-launch",
        "project_start_date": "2026-05-12",
        "calendar": {"hours_per_day": 8, "working_days": ["Mon", "Tue", "Wed", "Thu", "Fri"]},
        "baseline": {"version": "v0.1", "data_date": "2026-05-12", "status": "draft"},
        "assumptions": ["1 person + Codex agents delivery model"],
        "rebaseline_rules": [
            "scope or AC changes",
            "critical path task fails verification",
        ],
        "milestones": [
            {
                "id": "M1",
                "title": "Plan accepted",
                "task_id": "T1",
                "owner": "PM",
                "exit_criteria": "Scope and AC baseline confirmed",
                "evidence": "phase-prd confirmation",
            },
            {
                "id": "M2",
                "title": "Release decision",
                "task_id": "T4",
                "owner": "QA",
                "exit_criteria": "QA signoff package accepted",
                "evidence": "signoff-package.json",
            },
        ],
        "tasks": [
            {
                "id": "T1",
                "wbs_id": "1.1",
                "title": "clarify acceptance baseline",
                "stage": "PM",
                "owner": "delivery owner",
                "resource": "human",
                "status": "not_started",
                "percent_complete": 0,
                "depends_on": [],
                "parallelizable": True,
                "human_hours": {"optimistic": 1, "most_likely": 2, "pessimistic": 3},
                "elapsed_hours": {"optimistic": 2, "most_likely": 4, "pessimistic": 8},
                "inputs": ["raw requirement"],
                "outputs": ["phase-prd confirmation"],
                "acceptance": "AC baseline is explicit and accepted",
                "review_gate": "human scope decision",
                "agent_assignment": "none",
                "risks": [
                    {
                        "id": "R1",
                        "title": "scope ambiguity",
                        "trigger": "AC cannot be frozen",
                        "probability": "medium",
                        "impact": "high",
                        "buffer_hours": 2,
                        "mitigation": "run scope workshop before implementation",
                        "owner": "delivery owner",
                    }
                ],
            },
            {
                "id": "T2",
                "wbs_id": "1.2",
                "title": "prepare test obligations",
                "stage": "test-design",
                "owner": "test designer",
                "resource": "Codex agent",
                "status": "not_started",
                "percent_complete": 0,
                "depends_on": [],
                "parallelizable": True,
                "human_hours": {"optimistic": 0.5, "most_likely": 1, "pessimistic": 1.5},
                "elapsed_hours": {"optimistic": 1, "most_likely": 2, "pessimistic": 3},
                "inputs": ["phase-prd confirmation"],
                "outputs": ["test-cases.json"],
                "acceptance": "test obligations cover main and failure paths",
                "review_gate": "human test review",
                "agent_assignment": "test-design agent",
                "risks": [],
            },
            {
                "id": "T2B",
                "wbs_id": "1.3",
                "title": "prepare architecture notes",
                "stage": "design",
                "owner": "architect",
                "resource": "Codex agent",
                "status": "not_started",
                "percent_complete": 0,
                "depends_on": [],
                "parallelizable": True,
                "human_hours": {"optimistic": 0.5, "most_likely": 1, "pessimistic": 1.5},
                "elapsed_hours": {"optimistic": 1, "most_likely": 2, "pessimistic": 3},
                "inputs": ["phase-prd confirmation"],
                "outputs": ["architecture-notes.md"],
                "acceptance": "architecture notes identify integration risks",
                "review_gate": "human architecture review",
                "agent_assignment": "test-design agent",
                "risks": [],
            },
            {
                "id": "T3",
                "wbs_id": "2.1",
                "title": "implement with Codex agents",
                "stage": "developer",
                "owner": "developer",
                "resource": "Codex agent",
                "status": "not_started",
                "percent_complete": 0,
                "depends_on": ["T1", "T2", "T2B"],
                "parallelizable": False,
                "human_hours": {"optimistic": 0.5, "most_likely": 1, "pessimistic": 1.5},
                "elapsed_hours": {"optimistic": 2, "most_likely": 3, "pessimistic": 4},
                "inputs": ["phase-prd confirmation", "test-cases.json"],
                "outputs": ["developer-report.json"],
                "acceptance": "implementation passes target tests",
                "review_gate": "human code review",
                "agent_assignment": "developer agent",
                "risks": ["integration unknown"],
            },
            {
                "id": "T4",
                "wbs_id": "3.1",
                "title": "QA and release decision",
                "stage": "QA",
                "owner": "QA",
                "resource": "human + verifier agent",
                "status": "not_started",
                "percent_complete": 0,
                "depends_on": ["T3"],
                "parallelizable": False,
                "human_hours": {"optimistic": 0.25, "most_likely": 0.5, "pessimistic": 0.75},
                "elapsed_hours": {"optimistic": 1, "most_likely": 1, "pessimistic": 1},
                "inputs": ["developer-report.json"],
                "outputs": ["signoff-package.json"],
                "acceptance": "QA signoff package is accepted",
                "review_gate": "human release decision",
                "agent_assignment": "verifier agent",
                "milestone": True,
                "risks": [],
            },
        ],
    }


class DeliveryEstimatorCalculatorTests(unittest.TestCase):
    def test_calculates_parallel_agent_schedule_with_confidence_windows(self) -> None:
        result = run_calculator(sample_payload())

        self.assertEqual(result["summary"]["request_name"], "membership-benefit-launch")
        self.assertEqual(result["summary"]["total_human_investment_hours"], 5.5)
        self.assertEqual(result["summary"]["critical_path_elapsed_hours_p50"], 8.33)
        self.assertEqual(result["summary"]["delivery_window_hours"]["p80"], 9.22)
        self.assertEqual(result["summary"]["delivery_window_hours"]["p95"], 10.07)
        self.assertEqual(result["summary"]["delivery_window_days"]["p80"], 1.15)
        self.assertEqual(result["summary"]["commitment_dates"]["p80"], "2026-05-13")
        self.assertEqual(result["summary"]["max_parallel_workstreams"], 3)
        self.assertEqual(result["summary"]["max_parallel_ai_agents"], 2)
        self.assertEqual(result["summary"]["baseline"]["version"], "v0.1")
        self.assertEqual(result["summary"]["baseline"]["data_date"], "2026-05-12")
        self.assertEqual(result["critical_path"]["task_ids"], ["T1", "T3", "T4"])
        self.assertEqual(result["critical_path"]["float_hours_by_task"]["T2"], 2.33)
        self.assertTrue(result["tasks"][0]["critical"])
        self.assertEqual(result["tasks"][0]["schedule"]["start_date"], "2026-05-12")
        self.assertEqual(result["tasks"][4]["schedule"]["finish_date"], "2026-05-13")
        self.assertEqual(result["tasks"][0]["owner"], "delivery owner")
        self.assertEqual(result["tasks"][0]["resource"], "human")
        self.assertEqual(result["tasks"][0]["status"], "not_started")
        self.assertEqual(result["tasks"][0]["percent_complete"], 0)
        self.assertEqual(result["tasks"][0]["acceptance"], "AC baseline is explicit and accepted")
        self.assertEqual(
            [wave["task_ids"] for wave in result["parallel_waves"]],
            [["T1", "T2", "T2B"], ["T3"], ["T4"]],
        )
        self.assertEqual(result["parallel_waves"][0]["max_parallel_agents"], 3)
        self.assertEqual(result["parallel_waves"][0]["max_parallel_ai_agents"], 2)
        self.assertIn("test-design agent", result["parallel_waves"][0]["agent_assignments"])
        self.assertEqual(result["milestones"][0]["planned_date"], "2026-05-12")
        self.assertEqual(result["milestones"][1]["planned_date"], "2026-05-13")
        self.assertEqual(result["stage_rollup"]["developer"]["elapsed_hours_p50"], 3.0)
        self.assertEqual(result["risk_register"][0]["risk_id"], "R1")
        self.assertEqual(result["risk_register"][0]["trigger"], "AC cannot be frozen")
        self.assertIn("scope or AC changes", result["rebaseline_rules"])
        self.assertEqual(result["confidence_model"]["method"], "PERT critical path")

    def test_writes_human_readable_markdown_report(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            input_path = Path(tmp_dir) / "estimate-input.json"
            json_path = Path(tmp_dir) / "estimate-result.json"
            markdown_path = Path(tmp_dir) / "delivery-estimate.md"
            input_path.write_text(json.dumps(sample_payload(), ensure_ascii=False), encoding="utf-8")

            proc = subprocess.run(
                [
                    "python3",
                    str(SCRIPT),
                    "--input",
                    str(input_path),
                    "--output",
                    str(json_path),
                    "--markdown",
                    str(markdown_path),
                ],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertTrue(json_path.exists())
            report = markdown_path.read_text(encoding="utf-8")

        self.assertIn("# Schedule Plan: membership-benefit-launch", report)
        self.assertIn("## 一页结论", report)
        self.assertIn("```mermaid", report)
        self.assertIn("gantt", report)
        self.assertIn("dateFormat  YYYY-MM-DD", report)
        self.assertIn("## WBS 字典", report)
        self.assertIn("## 里程碑计划", report)
        self.assertIn("## 依赖与关键路径", report)
        self.assertIn("## 资源与 AI-Agent 计划", report)
        self.assertIn("## 环节投入与产出", report)
        self.assertIn("## 风险、缓冲与重估", report)
        self.assertIn("| 1.1 | T1 | clarify acceptance baseline | delivery owner | human |", report)
        self.assertIn("| M2 | Release decision | 2026-05-13 | QA |", report)
        self.assertIn("| 1 | T1, T2, T2B | 3 | 2 | test-design agent | human scope decision, human test review, human architecture review |", report)
        self.assertIn("baseline：v0.1 / data date：2026-05-12 / status：draft", report)
        self.assertIn("P80：2026-05-13", report)
        self.assertIn("T1 -> T3 -> T4", report)
        self.assertIn("critical path task fails verification", report)

    def test_rejects_unknown_dependency(self) -> None:
        payload = {
            "request_name": "bad-plan",
            "tasks": [
                {
                    "id": "T1",
                    "title": "broken",
                    "stage": "developer",
                    "depends_on": ["NOPE"],
                    "human_hours": {"optimistic": 1, "most_likely": 1, "pessimistic": 1},
                    "elapsed_hours": {"optimistic": 1, "most_likely": 1, "pessimistic": 1},
                }
            ],
        }
        with tempfile.TemporaryDirectory() as tmp_dir:
            input_path = Path(tmp_dir) / "bad-input.json"
            input_path.write_text(json.dumps(payload), encoding="utf-8")
            proc = subprocess.run(
                ["python3", str(SCRIPT), "--input", str(input_path), "--output", "-"],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )

        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("unknown dependency", proc.stderr)


if __name__ == "__main__":
    unittest.main()
