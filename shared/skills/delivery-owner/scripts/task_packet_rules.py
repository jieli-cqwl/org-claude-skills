from __future__ import annotations

LEGACY_SCOPE_FIELD = "sco" + "pe"
LEGACY_FIELD_REPLACEMENTS = {
    LEGACY_SCOPE_FIELD: "forbidden_scope",
}

REQUIRED_FIELDS = (
    "task_ref",
    "role",
    "goal",
    "forbidden_scope",
    "input_refs",
    "expected_evidence",
    "stop_condition",
    "forbidden_actions",
)

ALLOWED_ROLES = {
    "code-reviewer",
    "consistency-auditor",
    "developer",
    "verifier",
    "qa",
    "fixer",
}

AMBIGUOUS_VALUES = {
    "按需处理",
    "as needed",
    "whatever is necessary",
    "完成即可",
    "done",
}

FORBIDDEN_ACTION_CATEGORIES = {
    "scope_boundary": (r"\bscope\b", "范围", "越界", r"\boutside\b"),
    "baseline_boundary": (
        r"\bbaseline\b",
        "基线",
        r"\bac\b",
        r"\bacceptance\b",
        "验收",
    ),
    "commit_release_boundary": (r"\bcommit\b", r"\brelease\b", "提交", "发布"),
    "role_boundary": ("其他角色", r"\bother roles?\b", "代替", "替"),
}

ROLE_EVIDENCE_CATEGORIES = {
    "developer": {
        "developer_preflight": (r"\bpreflight\b", "前置"),
        "red_evidence": (r"\bred\b",),
        "green_evidence": (r"\bgreen\b",),
        "refactor_evidence": (r"\brefactor\b", "重构", "no-op"),
        "developer_report": ("developer-report.json", "developer report"),
    },
    "code-reviewer": {
        "strengths": ("strengths", "优点"),
        "issues": ("issues", "问题"),
        "assessment": ("assessment", "ready to merge", "评估"),
        "code_review_result": ("code-review-result.json", "code review result"),
    },
    "consistency-auditor": {
        "decision_authority": ("advisory", "advisory_only"),
        "findings": ("findings", "发现"),
        "owner_action": ("required_owner_action", "owner action"),
        "consistency_audit_result": (
            "consistency-audit-result.json",
            "consistency audit result",
        ),
    },
    "verifier": {
        "ac_verification": (r"\bac\b", "验收"),
        "scope_verification": (r"\bscope\b", "范围"),
        "verify_result": ("verify-result.json", "verify result"),
    },
    "qa": {
        "qa_a": ("qa_a", "qa-a"),
        "qa_b": ("qa_b", "qa-b"),
        "qa_c": ("qa_c", "qa-c"),
        "qa_d": ("qa_d", "qa-d"),
        "qa_result": ("qa-result.json", "qa result"),
    },
    "fixer": {
        "root_cause": ("root cause", "根因"),
        "minimal_fix": ("minimal", "minimum", "最小"),
        "fix_result": ("fix-result.json", "fix result"),
        "freshness": ("fresh", "freshness", "失效"),
    },
}

ROLE_INPUT_CATEGORIES = {
    "developer": {
        "baseline_or_task_ref": (
            r"artifact://plan",
            r"artifact://tasks",
            r"\bplan\b",
            r"\btasks?\b",
            "计划",
            "任务",
        ),
    },
    "code-reviewer": {
        "implementation_evidence": (
            "developer-report.json",
            "developer-report",
            "verify-result.json",
            "verify-result",
            "git diff",
            "diff",
        ),
    },
    "consistency-auditor": {
        "baseline_artifacts": ("plan.json", "tasks.json", "design.json"),
        "qa_handoff_obligations": (
            "test-cases.json",
            "qa_handoff_contract",
            "cross_unit_obligations",
        ),
    },
    "verifier": {
        "implementation_evidence": (
            "developer-report.json",
            "developer-report",
            "developer report",
            "fix-result.json",
            "fix-result",
            "fix result",
        ),
    },
    "qa": {
        "qa_handoff": (
            "qa_handoff",
            "qa-handoff",
            "qa handoff",
            "test-cases",
            "test cases",
        ),
        "verified_evidence": (
            "verify-result.json",
            "verify-result",
            "verify result",
            "verifier",
            "验收",
        ),
    },
    "fixer": {
        "failure_evidence": (
            "qa-result.json",
            "qa-result",
            "verify-result.json",
            "verify-result",
            "fail",
            "failure",
            "失败",
        ),
    },
}

CONSISTENCY_AUDIT_FINAL_INPUT_CATEGORIES = {
    "baseline_artifacts": ("plan.json", "tasks.json", "design.json"),
    "qa_handoff_obligations": (
        "test-cases.json",
        "qa_handoff_contract",
        "cross_unit_obligations",
    ),
    "implementation_evidence": (
        "developer-report.json",
        "developer-report",
        "developer report",
    ),
    "verification_evidence": ("verify-result.json", "verify-result", "verify result"),
    "review_evidence": (
        "code-review-result.json",
        "code-review-result",
        "code review result",
    ),
    "qa_evidence": ("qa-result.json", "qa-result", "qa result"),
}
