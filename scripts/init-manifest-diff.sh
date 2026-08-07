#!/usr/bin/env bash
# init-manifest-diff.sh — manifesto + merge inteligente para `init-project --update`.
# Só usado pelo instalador; NUNCA é copiado para dentro de projetos consumidores.
# Uso:
#   init-manifest-diff.sh generate <project_root> <template_agentes_dir> <template_commands_dir> <template_skills_dir>
#   init-manifest-diff.sh apply    <project_root> <template_agentes_dir> <template_commands_dir> <template_skills_dir>
set -euo pipefail
shopt -s nullglob

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

manifest_get() {
  local manifest="$1" key="$2" line
  [[ -f "$manifest" ]] || return 1
  line="$(grep -F "\"$key\":" "$manifest" | head -1)" || true
  [[ -n "$line" ]] || return 1
  printf '%s' "$line" | sed -E 's/^[^:]*: *"([^"]*)".*/\1/'
}

tracked_files() {
  local template_agentes="$1" template_commands="$2" template_skills="$3" f d name
  for f in "$template_agentes"/*.md; do
    [[ -e "$f" ]] || continue
    printf '.agents/%s\n' "$(basename "$f")"
  done
  for f in "$template_agentes"/scripts/*.sh; do
    [[ -e "$f" ]] || continue
    printf '.agents/scripts/%s\n' "$(basename "$f")"
  done
  for f in "$template_commands"/*.md; do
    [[ -e "$f" ]] || continue
    printf '.claude/commands/%s\n' "$(basename "$f")"
  done
  for d in "$template_skills"/*/; do
    [[ -e "$d" ]] || continue
    name="$(basename "$d")"
    [[ -f "$d/SKILL.md" ]] || continue
    printf '.claude/skills/%s/SKILL.md\n' "$name"
  done
}

template_path_of() {
  local rel="$1" template_agentes="$2" template_commands="$3" template_skills="$4"
  case "$rel" in
    .agents/*) printf '%s/%s' "$template_agentes" "${rel#.agents/}" ;;
    .claude/commands/*) printf '%s/%s' "$template_commands" "${rel#.claude/commands/}" ;;
    .claude/skills/*) printf '%s/%s' "$template_skills" "${rel#.claude/skills/}" ;;
  esac
}

cmd_generate() {
  local project_root="$1" template_agentes="$2" template_commands="$3" template_skills="$4"
  local manifest="$project_root/.agents/.init-manifest.json"
  mkdir -p "$project_root/.agents"

  local rel local_path
  local -a rels=() hashes=()
  while IFS= read -r rel; do
    local_path="$project_root/$rel"
    [[ -f "$local_path" ]] || continue
    rels+=("$rel")
    hashes+=("$(sha256_of "$local_path")")
  done < <(tracked_files "$template_agentes" "$template_commands" "$template_skills")

  {
    echo "{"
    echo "  \"generatedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"files\": {"
    local i last=$(( ${#rels[@]} - 1 ))
    for i in "${!rels[@]}"; do
      if [[ "$i" -eq "$last" ]]; then
        echo "    \"$(json_escape "${rels[$i]}")\": \"${hashes[$i]}\""
      else
        echo "    \"$(json_escape "${rels[$i]}")\": \"${hashes[$i]}\","
      fi
    done
    echo "  }"
    echo "}"
  } > "$manifest"
}

cmd_apply() {
  local project_root="$1" template_agentes="$2" template_commands="$3" template_skills="$4"
  local manifest="$project_root/.agents/.init-manifest.json"

  if [[ ! -f "$manifest" ]]; then
    echo "NEED_FULL_REINSTALL"
    return 2
  fi

  local rel tpl_path local_path local_hash manifest_hash tpl_hash
  local n_install=0 n_overwrite=0 n_preserve=0 n_conflict=0
  local -a conflicts=()
  # Baseline do manifesto novo: SEMPRE o hash do template, nunca o hash local.
  # Se usássemos o hash local aqui, um arquivo customizado (PRESERVE ou
  # CONFLICT) viraria sua própria baseline — na próxima chamada de --update,
  # "local == manifesto" bateria (os dois são o conteúdo customizado) e o
  # arquivo seria OVERWRITE'd silenciosamente, destruindo a customização sem
  # nenhum aviso. Guardar tpl_hash preserva o histórico de divergência.
  local -a new_rels=() new_hashes=()

  while IFS= read -r rel; do
    tpl_path="$(template_path_of "$rel" "$template_agentes" "$template_commands" "$template_skills")"
    local_path="$project_root/$rel"
    tpl_hash="$(sha256_of "$tpl_path")"

    if [[ ! -f "$local_path" ]]; then
      mkdir -p "$(dirname "$local_path")"
      cp "$tpl_path" "$local_path"
      n_install=$((n_install+1))
    else
      local_hash="$(sha256_of "$local_path")"
      manifest_hash="$(manifest_get "$manifest" "$rel" || true)"

      if [[ "$local_hash" == "$manifest_hash" ]]; then
        cp "$tpl_path" "$local_path"
        n_overwrite=$((n_overwrite+1))
      elif [[ "$tpl_hash" == "$manifest_hash" ]]; then
        n_preserve=$((n_preserve+1))
      else
        cp "$tpl_path" "$local_path.new"
        conflicts+=("$rel.new")
        n_conflict=$((n_conflict+1))
      fi
    fi

    new_rels+=("$rel")
    new_hashes+=("$tpl_hash")
  done < <(tracked_files "$template_agentes" "$template_commands" "$template_skills")

  {
    echo "{"
    echo "  \"generatedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"files\": {"
    local i last=$(( ${#new_rels[@]} - 1 ))
    for i in "${!new_rels[@]}"; do
      if [[ "$i" -eq "$last" ]]; then
        echo "    \"$(json_escape "${new_rels[$i]}")\": \"${new_hashes[$i]}\""
      else
        echo "    \"$(json_escape "${new_rels[$i]}")\": \"${new_hashes[$i]}\","
      fi
    done
    echo "  }"
    echo "}"
  } > "$manifest"

  echo "INSTALLED=$n_install OVERWRITTEN=$n_overwrite PRESERVED=$n_preserve CONFLICTS=$n_conflict"
  # Guarda de contagem antes de expandir: em bash 3.2 (padrão no macOS),
  # "${conflicts[@]}" com o array vazio dispara "unbound variable" sob set -u.
  if [[ ${#conflicts[@]} -gt 0 ]]; then
    local c
    for c in "${conflicts[@]}"; do
      echo "CONFLICT: $c"
    done
  fi
}

case "${1:-}" in
  generate) cmd_generate "$2" "$3" "$4" "$5" ;;
  apply) cmd_apply "$2" "$3" "$4" "$5" ;;
  *)
    echo "Uso: init-manifest-diff.sh {generate|apply} <project_root> <template_agentes_dir> <template_commands_dir> <template_skills_dir>" >&2
    exit 1
    ;;
esac
