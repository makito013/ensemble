#!/usr/bin/env bash
# init-manifest-diff.sh — manifesto + merge inteligente para `init-project --update`.
# Só usado pelo instalador; NUNCA é copiado para dentro de projetos consumidores.
# Uso:
#   init-manifest-diff.sh generate <project_root> <template_agentes_dir> <template_commands_dir> <template_skills_dir>
#   init-manifest-diff.sh apply    <project_root> <template_agentes_dir> <template_commands_dir> <template_skills_dir>
#   init-manifest-diff.sh backup   <project_root> <template_agentes_dir> <template_commands_dir> <template_skills_dir> [timestamp]
#   init-manifest-diff.sh install  <project_root> <template_agentes_dir> <template_commands_dir> <template_skills_dir>
#
# "Template file" has a single definition: tracked_files() below. `install`
# overwrites ONLY those paths (everything else under .agents/ is project data
# and stays in place), and `backup` copies the whole .agents/ plus the tracked
# .claude/ files to <project_root>/.agents-backups/<timestamp>/ -- outside
# .agents/, so backups never nest inside each other.
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

# Test files (*.test.sh, *.test.mjs, ...) live next to the templates in the
# source repo but are never template files: they must not reach projects.
is_test_file() {
  case "$(basename "$1")" in
    *.test.*) return 0 ;;
  esac
  return 1
}

tracked_files() {
  local template_agentes="$1" template_commands="$2" template_skills="$3" f d name
  for f in "$template_agentes"/*.md; do
    [[ -e "$f" ]] || continue
    printf '.agents/%s\n' "$(basename "$f")"
  done
  for f in "$template_agentes"/scripts/*; do
    [[ -f "$f" ]] || continue
    is_test_file "$f" && continue
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

# Full copy of the project's pipeline data to .agents-backups/<ts>/, taken
# BEFORE any template file is overwritten. Copy, never move: nothing in the
# live .agents/ changes here. Legacy in-tree backups (.agents/.backup-*) from
# older versions of init-project are left where they are and are not copied
# again (copying them is what made backups nest and grow on every reinstall).
cmd_backup() {
  local project_root="$1" template_agentes="$2" template_commands="$3" template_skills="$4"
  local ts="${5:-}"
  [[ -n "$ts" ]] || ts="$(date +%Y%m%d-%H%M%S)"
  local base="$project_root/.agents-backups"
  local name="$ts" n=1
  while [[ -e "$base/$name" ]]; do
    n=$((n+1))
    name="$ts-$n"
  done
  local dest="$base/$name"
  mkdir -p "$dest/.agents"

  local entry legacy=0
  if [[ -d "$project_root/.agents" ]]; then
    for entry in "$project_root/.agents"/* "$project_root/.agents"/.[!.]* "$project_root/.agents"/..?*; do
      [[ -e "$entry" ]] || continue
      case "$(basename "$entry")" in
        .backup-*) legacy=$((legacy+1)); continue ;;
      esac
      cp -Rp "$entry" "$dest/.agents/"
    done
  fi

  local rel
  while IFS= read -r rel; do
    case "$rel" in
      .claude/*)
        [[ -f "$project_root/$rel" ]] || continue
        mkdir -p "$dest/$(dirname "$rel")"
        cp -p "$project_root/$rel" "$dest/$rel"
        ;;
    esac
  done < <(tracked_files "$template_agentes" "$template_commands" "$template_skills")

  echo "BACKUP=.agents-backups/$name"
  echo "LEGACY_BACKUPS=$legacy"
}

# Overwrites every template file (tracked_files) with the template version and
# writes a manifest whose baseline is the TEMPLATE hash (same rule as apply).
# Never deletes anything and never touches non-template paths, so project data
# (CONTEXTO.md, TEAM.md, PIPELINE-STATE.md, .pipeline-history/, design-system/,
# planos/, skills/, ...) stays exactly where it is.
cmd_install() {
  local project_root="$1" template_agentes="$2" template_commands="$3" template_skills="$4"
  local manifest="$project_root/.agents/.init-manifest.json"
  local rel tpl_path local_path count=0
  local -a rels=() hashes=()
  mkdir -p "$project_root/.agents"
  while IFS= read -r rel; do
    tpl_path="$(template_path_of "$rel" "$template_agentes" "$template_commands" "$template_skills")"
    local_path="$project_root/$rel"
    mkdir -p "$(dirname "$local_path")"
    cp "$tpl_path" "$local_path"
    count=$((count+1))
    rels+=("$rel")
    hashes+=("$(sha256_of "$tpl_path")")
  done < <(tracked_files "$template_agentes" "$template_commands" "$template_skills")

  {
    echo "{"
    echo "  \"generatedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"files\": {"
    local i last=$(( ${#rels[@]} - 1 ))
    if [[ ${#rels[@]} -gt 0 ]]; then
      for i in "${!rels[@]}"; do
        if [[ "$i" -eq "$last" ]]; then
          echo "    \"$(json_escape "${rels[$i]}")\": \"${hashes[$i]}\""
        else
          echo "    \"$(json_escape "${rels[$i]}")\": \"${hashes[$i]}\","
        fi
      done
    fi
    echo "  }"
    echo "}"
  } > "$manifest"

  echo "INSTALLED=$count"
}

case "${1:-}" in
  generate) cmd_generate "$2" "$3" "$4" "$5" ;;
  apply) cmd_apply "$2" "$3" "$4" "$5" ;;
  backup) cmd_backup "$2" "$3" "$4" "$5" "${6:-}" ;;
  install) cmd_install "$2" "$3" "$4" "$5" ;;
  *)
    echo "Uso: init-manifest-diff.sh {generate|apply|backup|install} <project_root> <template_agentes_dir> <template_commands_dir> <template_skills_dir>" >&2
    exit 1
    ;;
esac
