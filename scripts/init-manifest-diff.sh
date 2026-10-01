#!/usr/bin/env bash
# init-manifest-diff.sh — manifesto + merge inteligente para `init-project --update`.
# Só usado pelo instalador; NUNCA é copiado para dentro de projetos consumidores.
# Uso:
#   init-manifest-diff.sh generate <project_root> <template_agentes_dir> <template_commands_dir> <template_skills_dir>
#   init-manifest-diff.sh apply    <project_root> <template_agentes_dir> <template_commands_dir> <template_skills_dir>
#   init-manifest-diff.sh backup   <project_root> <template_agentes_dir> <template_commands_dir> <template_skills_dir> [timestamp]
#   init-manifest-diff.sh install  <project_root> <template_agentes_dir> <template_commands_dir> <template_skills_dir>
#   init-manifest-diff.sh restore-learnings <project_root> <backup_dir>
#   init-manifest-diff.sh copy-skills <src_skills_dir> <dest_skills_dir>
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

# --- Local "## Aprendizados" carry-over -----------------------------------
# A persona can carry a local "## Aprendizados" section (agentes/APRENDIZADOS.md):
# learned rules the project recorded on top of the template. Those rules are
# project data living inside a template file, so every update path must carry
# them to the new template version instead of dropping them or forcing a
# manual merge. Placement rule (same as APRENDIZADOS.md): if the template
# already has the section, the local lines go at its end; otherwise a new
# section is inserted right before the final "---" block (never inside the
# YAML frontmatter of a SKILL.md), or appended when there is no such block.
# "## Aprendizados" inside fenced code blocks (e.g. APRENDIZADOS.md documenting
# the convention) is never treated as a section.
LEARN_AWK='
function is_fence(l) { return l ~ /^[ \t]*(```|~~~)/ }
function is_blank(l) { return l ~ /^[ \t]*$/ }
function is_heading(l) { return l ~ /^## Aprendizados[ \t]*$/ }
function ends_section(l) { return l ~ /^##? / || l ~ /^---[ \t]*$/ }
BEGIN {
  n_set = 0
  if (lines_file != "") {
    while ((getline l < lines_file) > 0) { set[l] = 1; order[++n_set] = l }
    close(lines_file)
  }
}
# Pass 1 (merge mode only): locate section end / final "---" in the template.
mode == "merge" && NR == FNR {
  if (FNR == 1 && $0 ~ /^---[ \t]*$/) { fm = 1; next }
  if (fm) { if ($0 ~ /^---[ \t]*$/) fm = 0; next }
  if (is_fence($0)) { f1 = !f1; if (in1) last1 = FNR; next }
  if (!f1 && !seen1 && is_heading($0)) { in1 = 1; seen1 = 1; sec_start = FNR; last1 = FNR; next }
  if (in1 && !f1 && ends_section($0)) in1 = 0
  if (in1 && !is_blank($0)) last1 = FNR
  if (!f1 && $0 ~ /^---[ \t]*$/) dash = FNR
  next
}
mode == "merge" {
  if (!sec_start && FNR == dash) {
    print "## Aprendizados"
    for (i = 1; i <= n_set; i++) print order[i]
    print ""
  }
  print
  if (sec_start && FNR == last1) for (i = 1; i <= n_set; i++) print order[i]
  next
}
END {
  if (mode == "merge" && !sec_start && !dash) {
    print ""
    print "## Aprendizados"
    for (i = 1; i <= n_set; i++) print order[i]
  }
}
# Single-pass modes: extract | strip | strip-lines
{
  if (is_fence($0)) fence = !fence
  else if (!fence && !done && is_heading($0)) { insec = 1; done = 1; if (mode == "strip-lines") print; next }
  else if (insec && !fence && ends_section($0)) insec = 0
  if (!insec) { if (mode != "extract") print; next }
  if (mode == "extract") { if (!is_blank($0)) print; next }
  if (mode == "strip-lines" && !($0 in set)) print
}
'

# Lines of the "## Aprendizados" section (heading and blank lines excluded).
learning_lines() {
  awk -v mode=extract -v lines_file= "$LEARN_AWK" "$1"
}

# Lines of LOCAL's section that TEMPLATE's section does not already have:
# the project-local learnings to carry over.
local_learnings() {
  local local_file="$1" tpl_file="$2" out="$3" tpl_lines
  tpl_lines="$(mktemp)"
  learning_lines "$tpl_file" > "$tpl_lines" || true
  learning_lines "$local_file" | grep -vxF -f "$tpl_lines" > "$out" || true
  rm -f "$tpl_lines"
}

# TEMPLATE + the learning lines in LINES_FILE, written to OUT.
merge_learnings() {
  local tpl_file="$1" lines_file="$2" out="$3" tmp
  tmp="$(mktemp)"
  awk -v mode=merge -v lines_file="$lines_file" "$LEARN_AWK" "$tpl_file" "$tpl_file" > "$tmp"
  # Rewrite through a redirect (not mv): keeps the target's permissions
  # instead of mktemp's 0600, and works when OUT is TEMPLATE itself.
  cat "$tmp" > "$out"
  rm -f "$tmp"
}

# True when FILE, once its local learnings (LINES_FILE) are taken out, is
# byte-identical to the baseline with hash EXPECTED. Two candidates: drop the
# whole section (baseline had no section) or drop only the local lines
# (baseline already had a section, e.g. global rules from /aprendizados-sync).
matches_without_learnings() {
  local file="$1" lines_file="$2" expected="$3" tmp ok=1
  [[ -n "$expected" ]] || return 1
  tmp="$(mktemp)"
  awk -v mode=strip -v lines_file= "$LEARN_AWK" "$file" > "$tmp"
  if [[ "$(sha256_of "$tmp")" == "$expected" ]]; then
    ok=0
  else
    awk -v mode=strip-lines -v lines_file="$lines_file" "$LEARN_AWK" "$file" > "$tmp"
    [[ "$(sha256_of "$tmp")" == "$expected" ]] && ok=0
  fi
  rm -f "$tmp"
  return $ok
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
  local -a conflicts=() carried=()
  local learn_tmp
  learn_tmp="$(mktemp)"
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
        local_learnings "$local_path" "$tpl_path" "$learn_tmp"
        if [[ -s "$learn_tmp" ]] && matches_without_learnings "$local_path" "$learn_tmp" "$manifest_hash"; then
          # The only local change is the "## Aprendizados" section: take the
          # new template and carry the learned rules over to it.
          merge_learnings "$tpl_path" "$learn_tmp" "$local_path"
          carried+=("$rel")
          n_overwrite=$((n_overwrite+1))
        else
          if [[ -s "$learn_tmp" ]]; then
            # Other customizations too: manual merge, but the .new already
            # carries the learned rules so they are not lost in the merge.
            merge_learnings "$tpl_path" "$learn_tmp" "$local_path.new"
          else
            cp "$tpl_path" "$local_path.new"
          fi
          conflicts+=("$rel.new")
          n_conflict=$((n_conflict+1))
        fi
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
  if [[ ${#carried[@]} -gt 0 ]]; then
    local k
    for k in "${carried[@]}"; do
      echo "LEARNINGS_CARRIED: $k"
    done
  fi
  rm -f "$learn_tmp"
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

# Full-reinstall companion of `install`: for every persona in the backup that
# had local "## Aprendizados" lines, add them back to the freshly installed
# template file. The manifest is NOT touched (baseline stays the template hash),
# so the next --update recognizes "template + learnings" and carries them again.
cmd_restore_learnings() {
  local project_root="$1" backup_dir="$2" f name target learn_tmp
  [[ "$backup_dir" == /* ]] || backup_dir="$project_root/$backup_dir"
  learn_tmp="$(mktemp)"
  for f in "$backup_dir"/.agents/*.md; do
    name="$(basename "$f")"
    target="$project_root/.agents/$name"
    [[ -f "$target" ]] || continue
    local_learnings "$f" "$target" "$learn_tmp"
    [[ -s "$learn_tmp" ]] || continue
    merge_learnings "$target" "$learn_tmp" "$target"
    echo "RESTORED: .agents/$name"
  done
  rm -f "$learn_tmp"
}

# Copies a skills tree (e.g. gemini/skills/ -> .agents/skills/) overwriting
# each file, except that a destination SKILL.md with local "## Aprendizados"
# lines gets the new version WITH those lines. Never deletes anything that
# exists only in the destination; test files (*.test.*) are skipped.
cmd_copy_skills() {
  local src_dir="$1" dest_dir="$2" f rel dest learn_tmp
  mkdir -p "$dest_dir"
  # .agents/skills may be a symlink to the source (README's manual option):
  # nothing to copy then, and cp would fail on "same file".
  if [[ "$(cd -P "$src_dir" && pwd)" == "$(cd -P "$dest_dir" && pwd)" ]]; then
    echo "SAME_DIR: $dest_dir"
    return 0
  fi
  learn_tmp="$(mktemp)"
  while IFS= read -r f; do
    is_test_file "$f" && continue
    rel="${f#"$src_dir"/}"
    dest="$dest_dir/$rel"
    mkdir -p "$(dirname "$dest")"
    if [[ "$(basename "$f")" == "SKILL.md" && -f "$dest" ]]; then
      local_learnings "$dest" "$f" "$learn_tmp"
      if [[ -s "$learn_tmp" ]]; then
        merge_learnings "$f" "$learn_tmp" "$dest"
        echo "LEARNINGS_CARRIED: $rel"
        continue
      fi
    fi
    cp "$f" "$dest"
  done < <(find -H "$src_dir" -type f | LC_ALL=C sort)
  rm -f "$learn_tmp"
}

case "${1:-}" in
  generate) cmd_generate "$2" "$3" "$4" "$5" ;;
  apply) cmd_apply "$2" "$3" "$4" "$5" ;;
  backup) cmd_backup "$2" "$3" "$4" "$5" "${6:-}" ;;
  install) cmd_install "$2" "$3" "$4" "$5" ;;
  restore-learnings) cmd_restore_learnings "$2" "$3" ;;
  copy-skills) cmd_copy_skills "${2%/}" "${3%/}" ;;
  *)
    echo "Uso: init-manifest-diff.sh {generate|apply|backup|install} <project_root> <template_agentes_dir> <template_commands_dir> <template_skills_dir>" >&2
    echo "     init-manifest-diff.sh restore-learnings <project_root> <backup_dir>" >&2
    echo "     init-manifest-diff.sh copy-skills <src_skills_dir> <dest_skills_dir>" >&2
    exit 1
    ;;
esac
