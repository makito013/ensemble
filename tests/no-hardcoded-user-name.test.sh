#!/usr/bin/env bash
# no-hardcoded-user-name.test.sh — distributed templates never name a specific
# person. Personas, commands and engine adapters are installed into anyone's
# project, so they must say "o usuário", never the author's first name.
# docs/superpowers/ (history) is intentionally out of scope.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail=0

dirs=(agentes commands .claude/commands gemini codex cursor claude/skills skills)

for d in "${dirs[@]}"; do
  if [[ ! -d "$ROOT/$d" ]]; then
    echo "FAIL: $d não existe (lista de diretórios do teste desatualizada)"
    fail=1
    continue
  fi
  hits="$(grep -rn -w 'Bruno' "$ROOT/$d" || true)"
  if [[ -n "$hits" ]]; then
    echo "FAIL: $d contém nome de usuário hardcoded ('Bruno') — use 'o usuário':"
    echo "$hits" | sed "s|$ROOT/||"
    fail=1
  else
    echo "PASS: $d sem nome de usuário hardcoded"
  fi
done

exit $fail
