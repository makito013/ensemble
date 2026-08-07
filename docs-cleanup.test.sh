#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

for f in README.md gemini/README.md; do
  if grep -q '~/bin/init-project' "$ROOT/$f"; then
    echo "FAIL: $f ainda referencia ~/bin/init-project no fluxo Claude"
    fail=1
  else
    echo "PASS: $f sem referência a ~/bin/init-project"
  fi
done

exit $fail
