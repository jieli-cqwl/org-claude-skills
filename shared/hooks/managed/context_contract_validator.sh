#!/usr/bin/env bash
set -euo pipefail

payload="$(cat || true)"
cwd="$(
  python3 -c 'import json,sys; p=json.loads(sys.stdin.read() or "{}"); print(p.get("cwd") or "")' <<<"$payload" 2>/dev/null || true
)"

if [ -z "$cwd" ]; then
  cwd="$PWD"
fi

if [ ! -f "$cwd/contracts/active-doc-scope.yaml" ]; then
  printf '{"decision":"skip","reason":"scope_registry_absent"}\n'
  exit 0
fi

validator="$cwd/tools/community/validate_context_contract.py"
if [ ! -f "$validator" ]; then
  printf '{"decision":"block","reason":"context_validator_missing","path":"%s"}\n' "$validator" >&2
  exit 1
fi

python3 "$validator" --root "$cwd" --mode blocking
