#!/usr/bin/env bash
# detect-projects.sh — encontra fronteiras de projeto a partir de uma raiz,
# seguindo a regra E do spec (docs/superpowers/specs/2026-07-03-*).
# Uso: detect-projects.sh [pasta-raiz]
# Imprime um caminho absoluto por linha, um por projeto encontrado, ordenado.
set -euo pipefail
shopt -s nullglob

ROOT="${1:-.}"
if [[ ! -d "$ROOT" ]]; then
  echo "detect-projects.sh: pasta não encontrada: $ROOT" >&2
  exit 1
fi
ROOT="$(cd "$ROOT" && pwd)"

MAX_DEPTH=6
IGNORE_DIRS=(node_modules .git dist build vendor .venv __pycache__ .agents .claude agentes)
MARKERS=(package.json pyproject.toml go.mod Cargo.toml composer.json pom.xml Gemfile)

is_ignored() {
  local name="$1" ig
  for ig in "${IGNORE_DIRS[@]}"; do
    [[ "$name" == "$ig" ]] && return 0
  done
  return 1
}

has_marker() {
  local dir="$1" m
  [[ -e "$dir/.git" ]] && return 0
  for m in "${MARKERS[@]}"; do
    [[ -e "$dir/$m" ]] && return 0
  done
  return 1
}

results=()

if has_marker "$ROOT"; then
  results+=("$ROOT")
else
  queue=("$ROOT:0")
  while [[ ${#queue[@]} -gt 0 ]]; do
    entry="${queue[0]}"
    queue=("${queue[@]:1}")
    dir="${entry%:*}"
    depth="${entry##*:}"

    [[ "$depth" -ge "$MAX_DEPTH" ]] && continue

    for child in "$dir"/*/; do
      child="${child%/}"
      name="$(basename "$child")"
      is_ignored "$name" && continue

      if has_marker "$child"; then
        results+=("$child")
      else
        queue+=("$child:$((depth+1))")
      fi
    done
  done
fi

[[ ${#results[@]} -eq 0 ]] && exit 0
printf '%s\n' "${results[@]}" | sort
