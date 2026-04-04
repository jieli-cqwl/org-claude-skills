{
  "verdict": "approve | needs-attention",
  "findings": [
    {
      "severity": "critical | high | medium | low",
      "file": "repo/relative/path.ext",
      "line_start": 12,
      "line_end": 18,
      "description": "what is wrong and why it matters",
      "recommendation": "concrete fix guidance"
    }
  ]
}

Rules:
- `approve` => `findings` must be `[]`
- `needs-attention` => `findings` must be non-empty
- `file` must be repo-relative, never absolute, never `..`, never `.git`
- `line_start` and `line_end` must be positive integers with `line_end >= line_start`
- Output JSON only, no markdown fence, no prose prefix, no trailing commentary
