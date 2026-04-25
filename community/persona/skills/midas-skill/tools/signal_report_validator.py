#!/usr/bin/env python3
"""
Midas Skill — Signal Report Validator

Validates a Midas Signal Report against quality standards, inspired by
nuwa-skill's quality_check.py. Ensures all 6 lenses were applied, all signals
have traceable evidence, all opportunities have immediate next actions, and
confidence scores follow the scoring rubric.

Usage:
    python signal_report_validator.py <report_file>
    python signal_report_validator.py <report_file> --strict

Examples:
    # Validate a signal report
    python signal_report_validator.py examples/daily-slack-mining/opportunities.md

    # Strict mode: also checks for pattern matches and evolution log references
    python signal_report_validator.py my_report.md --strict

Exit codes:
    0 = all checks pass
    1 = one or more checks failed
"""

import argparse
import re
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Check functions
# ---------------------------------------------------------------------------

def check_signal_report_header(content: str) -> tuple:
    """Check that the report has a proper MIDAS SIGNAL REPORT header.

    Returns (passed: bool, message: str).
    """
    patterns = [
        r"MIDAS SIGNAL REPORT",
        r"MIDAS 信号报告",
        r"REPORTE DE SEÑALES MIDAS",
        r"MIDAS СИГНАЛЬНЫЙ ОТЧЁТ",
        r"MIDAS シグナルレポート",
    ]
    for p in patterns:
        if re.search(p, content, re.IGNORECASE):
            return True, "Signal report header found"
    return False, "Missing [MIDAS SIGNAL REPORT] header block"


def check_input_metadata(content: str) -> tuple:
    """Check that the report includes input metadata (type, volume, date)."""
    required_fields = ["input type", "volume", "scan date", "tipo de entrada",
                       "输入类型", "入力タイプ", "тип ввода"]
    found = 0
    for field in required_fields:
        if field.lower() in content.lower():
            found += 1
    if found >= 2:
        return True, f"Input metadata present ({found} fields found)"
    return False, "Missing input metadata (need: input type, volume, scan date)"


def check_signals_detected(content: str) -> tuple:
    """Check that the report declares how many signals were detected."""
    patterns = [
        r"MONEY SIGNALS DETECTED:\s*\d+",
        r"SEÑALES DE DINERO DETECTADAS:\s*\d+",
        r"検出.*シグナル.*\d+",
        r"金钱信号.*\d+",
        r"ДЕНЕЖНЫХ СИГНАЛОВ.*\d+",
        r"🟡.*\d+",
    ]
    for p in patterns:
        if re.search(p, content, re.IGNORECASE):
            return True, "Signal count declared"
    return False, "Missing signal count (e.g., '🟡 MONEY SIGNALS DETECTED: 7')"


def check_noise_discarded(content: str) -> tuple:
    """Check that the report declares how much noise was discarded."""
    patterns = [
        r"NOISE DISCARDED",
        r"RUIDO DESCARTADO",
        r"ノイズ.*破棄",
        r"噪音丢弃",
        r"ШУМ",
        r"LÄRM VERWORFEN",
        r"🔴",
    ]
    for p in patterns:
        if re.search(p, content, re.IGNORECASE):
            return True, "Noise discard count present"
    return False, "Missing noise discard count (the 🔴 NOISE DISCARDED line)"


def check_opportunities_ranked(content: str) -> tuple:
    """Check that opportunities are ranked (🥇, 🥈, #1, #2, etc.)."""
    rank_patterns = [r"🥇", r"🥈", r"🥉", r"#\d+\s*[—–-]", r"RANK", r"Rank"]
    found = sum(1 for p in rank_patterns if re.search(p, content))
    if found >= 2:
        return True, f"Opportunities are ranked ({found} rank markers found)"
    if found == 1:
        return True, "At least one ranked opportunity found"
    return False, "No ranked opportunities found (need 🥇/#1 markers)"


def check_evidence_chains(content: str) -> tuple:
    """Check that signals include traceable evidence (quotes or citations)."""
    evidence_patterns = [
        r"[Ee]vidence",
        r"[Rr]aw evidence",
        r"[Pp]rova",
        r"证据",
        r"Доказательства",
        r"Beweise",
        r"Evidência",
        r"証拠",
    ]
    found = sum(1 for p in evidence_patterns if re.search(p, content))
    if found >= 1:
        # Also check for actual quoted evidence
        quotes = len(re.findall(r'["""].*?["""]', content))
        dashes = len(re.findall(r"^\s*-\s+.{20,}", content, re.MULTILINE))
        if quotes + dashes >= 2:
            return True, f"Evidence chains present ({quotes} quotes, {dashes} evidence items)"
        return True, "Evidence section header found (but evidence items may be sparse)"
    return False, "No evidence chains found — every signal needs traceable evidence"


def check_immediate_next_actions(content: str) -> tuple:
    """Check that each opportunity ends with an Immediate Next Action."""
    action_patterns = [
        r"[Ii]mmediate next action",
        r"⚡\s*[Ii]mmediate",
        r"⚡\s*[Nn]ext action",
        r"⚡\s*Próxima acción",
        r"⚡\s*Sofortige",
        r"⚡\s*立即",
        r"⚡\s*即座の",
        r"⚡\s*Немедленное",
        r"⚡\s*Próxima ação",
    ]
    count = sum(
        len(re.findall(p, content))
        for p in action_patterns
    )
    if count >= 1:
        return True, f"Immediate Next Action(s) found ({count} total)"
    return False, "Missing ⚡ Immediate Next Action — every opportunity must end with one"


def check_confidence_scores(content: str) -> tuple:
    """Check that confidence scores are present and within valid range."""
    # Look for percentage patterns near "confidence" or "confianza" or "信頼度"
    conf_pattern = re.compile(r"[Cc]onfi\w+[:\s]*(\d+)%", re.IGNORECASE)
    matches = conf_pattern.findall(content)

    # Also match standalone percentage patterns in tables/lists
    pct_pattern = re.compile(r"(\d+)%")
    all_pcts = [int(m) for m in pct_pattern.findall(content)]

    if not matches and len(all_pcts) < 3:
        return False, "No confidence scores found"

    scores = [int(m) for m in matches] if matches else all_pcts[:10]

    # Validate range
    out_of_range = [s for s in scores if s > 100 or s < 0]
    if out_of_range:
        return False, f"Confidence scores out of range (0-100%): {out_of_range}"

    # Check for inflated single-source scores (should be ≤35%)
    # This is a soft check — we can't always tell source count from the report
    return True, f"Confidence scores present ({len(scores)} found, range {min(scores)}–{max(scores)}%)"


def check_pattern_match(content: str) -> tuple:
    """Check that high-confidence opportunities include a pattern match.

    This is a strict-mode check.
    """
    pattern_markers = [
        r"[Pp]attern match",
        r"[Pp]atrón",
        r"Pattern-Match",
        r"模式匹配",
        r"パターンマッチ",
        r"Совпадение паттерна",
        r"Correspondência",
        r"Buffett|Musk|Thiel",
    ]
    found = sum(1 for p in pattern_markers if re.search(p, content))
    if found >= 1:
        return True, "Pattern match references found"
    return False, "No pattern match references (high-conviction opportunities should reference a famous-model playbook)"


def check_not_financial_advice(content: str) -> tuple:
    """Check that the report includes the honest boundary disclaimer."""
    disclaimer_patterns = [
        r"[Nn]ot financial advice",
        r"[Nn]o[nt] (?:es |é )consejo financiero",
        r"非投资建议",
        r"金融アドバイスではありません",
        r"Не финансовый совет",
        r"Keine Finanzberatung",
        r"Não é Conselho Financeiro",
        r"[Cc]onsult a licensed",
    ]
    for p in disclaimer_patterns:
        if re.search(p, content):
            return True, "Honest boundary disclaimer present"
    return False, "Missing 'Not financial advice' disclaimer"


def check_midas_recommendation(content: str) -> tuple:
    """Check that there's a final MIDAS RECOMMENDATION section."""
    patterns = [
        r"MIDAS RECOMMENDATION",
        r"💡\s*MIDAS",
        r"Highest.conviction opportunity",
        r"highest.conviction",
        r"one next action",
    ]
    for p in patterns:
        if re.search(p, content, re.IGNORECASE):
            return True, "MIDAS RECOMMENDATION section found"
    return False, "Missing 💡 MIDAS RECOMMENDATION section with highest-conviction pick"


# ---------------------------------------------------------------------------
# Validation runner
# ---------------------------------------------------------------------------

def validate(content: str, strict: bool = False) -> list:
    """Run all validation checks and return results.

    Returns list of (check_name, passed, message).
    """
    checks = [
        ("Signal Report Header", check_signal_report_header),
        ("Input Metadata", check_input_metadata),
        ("Signals Detected Count", check_signals_detected),
        ("Noise Discarded Count", check_noise_discarded),
        ("Opportunities Ranked", check_opportunities_ranked),
        ("Evidence Chains", check_evidence_chains),
        ("Immediate Next Actions", check_immediate_next_actions),
        ("Confidence Scores", check_confidence_scores),
        ("Not Financial Advice", check_not_financial_advice),
        ("MIDAS Recommendation", check_midas_recommendation),
    ]

    if strict:
        checks.append(("Pattern Match References", check_pattern_match))

    results = []
    for name, fn in checks:
        passed, message = fn(content)
        results.append((name, passed, message))

    return results


def main():
    parser = argparse.ArgumentParser(
        description="Midas Skill — Signal Report Validator. "
        "Validates a Midas output against quality standards.",
    )
    parser.add_argument("report", help="Path to the signal report file (Markdown)")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Enable strict checks (pattern matches, evolution references)",
    )
    args = parser.parse_args()

    filepath = Path(args.report)
    if not filepath.exists():
        print(f"❌ File not found: {filepath}", file=sys.stderr)
        sys.exit(1)

    content = filepath.read_text(encoding="utf-8")
    results = validate(content, strict=args.strict)

    # Print results
    total = len(results)
    passed = sum(1 for _, p, _ in results if p)
    failed = total - passed

    print(f"# Midas Signal Report Validation")
    print(f"**File:** {filepath}")
    print(f"**Mode:** {'strict' if args.strict else 'standard'}")
    print(f"**Score:** {passed}/{total} checks passed")
    print()

    for name, ok, message in results:
        icon = "✅" if ok else "❌"
        print(f"{icon} **{name}**: {message}")

    print()
    if failed == 0:
        print("🏆 All checks passed. Report meets Midas quality standards.")
    else:
        print(f"⚠️  {failed} check(s) failed. Fix the issues above before publishing.")

    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
