#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVALS="$ROOT/shared/skills/developer/evals/evals.json"
LIFECYCLE="$ROOT/shared/skills/developer/evals/lifecycle-review.json"

jq -e '
  [.evals[].id] as $ids
  | [
      "runtime-layering-triggered-reference",
      "runtime-layering-untriggered-reference",
      "runtime-layering-missing-input-block",
      "runtime-layering-unresolved-ref-block",
      "runtime-layering-owner-mismatch-block",
      "runtime-layering-out-of-scope-block",
      "runtime-layering-stale-replay-block",
      "runtime-layering-fresh-proof-gap"
    ] as $required
  | all($required[]; $ids | index(.) != null)
  and ([.preference_anchors[].id] | index("PA-7") != null)
  and ([.preference_anchors[].id] | index("PA-8") != null)
' "$EVALS" >/dev/null

jq -e '
  (.runtime_layering_pilot.status == "verified")
  and (.runtime_layering_pilot.verification_commands | index("bash tests/test-developer-runtime-failure-matrix.sh") != null)
  and (.runtime_layering_pilot.verification_commands | index("bash tests/test-developer-runtime-layering-skill.sh") != null)
  and (.runtime_layering_pilot.verification_commands | index("bash tests/test-developer-runtime-proof-contract.sh") != null)
  and (.runtime_layering_pilot.verified_commands | index("bash tests/test-developer-runtime-layering-evals.sh") != null)
' "$LIFECYCLE" >/dev/null

printf '[PASS] developer runtime layering evals\n'
