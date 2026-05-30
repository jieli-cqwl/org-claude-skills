from __future__ import annotations

import re

TARGET_MARKERS = (
    "shared/rules/",
    "shared/reference/",
    "shared/references/",
    "shared/agents/",
)
CONTRACT_TOKENS = re.compile(
    r"(\.(?:json|ya?ml|py|sh|toml)\b|artifact://|sha256:|"
    r"\bvalidate_[A-Za-z0-9_]+\b|--[a-z0-9-]+|\$\{|"
    r"\b[A-Z]{1,5}-[A-Z0-9-]+\b|\bS\d+\b|"
    r"\b[A-Z][A-Z0-9]+(?:_[A-Z0-9]+)+\b|"
    r"^name:|^allowed-tools:|^disable-model-invocation:|"
    r"\b[a-z][a-z0-9]+(?:_[a-z0-9]+)+\b)"
)
LABEL_WORDS = {
    "Agent",
    "Boundary",
    "Check",
    "Discovery",
    "Evidence",
    "Finalization",
    "Gate",
    "Guidance",
    "Handoff",
    "Mode",
    "Owner",
    "Packet",
    "Plan",
    "Review",
    "Signal",
    "Synthesis",
}


def is_markdown_prose_target(target: str) -> bool:
    haystack = target.replace("\\", "/").lower()
    if "/projections/" in haystack:
        return False
    if re.search(r"shared/skills/[^/]+/skill\.md", haystack):
        return True
    if "/references/" in haystack:
        return ".md" in haystack
    if "/agents/" in haystack:
        return bool(re.search(r"\.(?:md|ya?ml|toml)\b", haystack))
    return ".md" in haystack and any(marker in haystack for marker in TARGET_MARKERS)


def normalized_pattern(pattern: str) -> str:
    normalized = re.sub(r"^\^", "", pattern.strip())
    normalized = re.sub(r"\$$", "", normalized)
    return (
        normalized.replace(r"\`", "`")
        .replace(r"\.", ".")
        .replace(r"\+", "+")
        .replace(r"\-", "-")
    )


def has_contract_shape(pattern: str) -> bool:
    return bool(re.search(r"[|$\[\]{}()\\`/\"]", pattern))


def cjk_count(text: str) -> int:
    return len(re.findall(r"[一-鿿]", text))


def sentence_like(text: str) -> bool:
    return (
        text.count(" ") >= 6
        or cjk_count(text) >= 18
        or text.endswith((".", "。", "！", "？", "!", "?"))
    )


def machine_contract_literal(text: str) -> bool:
    if re.match(r"(name|allowed-tools|disable-model-invocation):", text):
        return True
    if re.match(r"(python3|bash|node|jq|rg|grep)\b", text):
        return True
    return bool(
        "/" in text
        and re.search(r"\.(?:md|json|py|sh|ya?ml|toml)\b", text)
        and not re.search(r"\s", text)
    )


def prose_label_like(text: str) -> bool:
    words = re.findall(r"[A-Za-z][A-Za-z-]*", text)
    if len(words) < 2:
        return False
    if any(word in LABEL_WORDS for word in words):
        return True
    return bool(re.search(r"[A-Z][a-z]+(?:[ -][A-Z][a-z]+){2,}", text))


def low_signal_kind(assertion: str, pattern: str) -> str | None:
    normalized = normalized_pattern(pattern)
    if machine_contract_literal(normalized):
        return None
    has_contract = bool(CONTRACT_TOKENS.search(normalized))
    if re.match(r"#{1,6}\s+", normalized):
        return "heading"
    if has_contract and has_contract_shape(normalized):
        if cjk_count(normalized) >= 2 or sentence_like(normalized):
            return "prose-wrapped-contract"
        return None
    if has_contract and re.search(r"[`_.:/-]", normalized):
        return None
    if assertion == "absent" and (
        cjk_count(normalized) >= 2
        or sentence_like(normalized)
        or prose_label_like(normalized)
    ):
        return "absent-prose"
    if assertion == "present" and cjk_count(normalized) >= 2 and not has_contract:
        return "short-present-phrase"
    if assertion == "present" and prose_label_like(normalized) and not has_contract:
        return "short-present-phrase"
    if (
        assertion == "present"
        and cjk_count(normalized) >= 2
        and re.search(r"\||\.\*|\[\[:[a-z]+:\]\]", normalized)
    ):
        return "short-prose-regex"
    if len(re.findall(r"[A-Za-z一-鿿]", normalized)) >= 45 and sentence_like(
        normalized
    ):
        return "sentence"
    return None
