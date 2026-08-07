#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "uso: install.sh [--target <pasta-de-perfil>]" >&2
  echo "  ex: install.sh --target ~/.claude-work" >&2
  exit 2
}

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

TARGET="$HOME/.claude"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || usage
      TARGET="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

PIPELINE_HOME="$HOME/agentes-pipeline"
SKILL_LINK="$TARGET/skills/init-project"
SKILL_TARGET="$REPO_DIR/claude/skills/init-project"
ANTIGRAVITY_PLUGIN_DIR="$HOME/.gemini/config/plugins/superpowers"
ANTIGRAVITY_PLUGIN_URL="https://github.com/roundpilot/superpowers-antigravity"

FAIL=0

ensure_link() {
  local target="$1" link="$2" label="$3"
  mkdir -p "$(dirname "$link")"

  local target_resolved
  target_resolved="$(cd "$target" && pwd -P)"

  if [[ -L "$link" ]]; then
    local resolved=""
    resolved="$(cd "$link" 2>/dev/null && pwd -P || true)"
    if [[ "$resolved" == "$target_resolved" ]]; then
      echo "OK: $label já linkado corretamente ($link -> $target)"
    else
      echo "ERRO: $label existe em $link mas aponta pra outro lugar (${resolved:-link quebrado}, esperado $target_resolved). Resolva manualmente antes de rodar de novo."
      FAIL=1
    fi
  elif [[ -e "$link" ]]; then
    local link_resolved=""
    link_resolved="$(cd "$link" 2>/dev/null && pwd -P || true)"
    if [[ -n "$link_resolved" && "$link_resolved" == "$target_resolved" ]]; then
      echo "OK: $label já é o próprio $target — nenhum link necessário"
    else
      echo "ERRO: $label existe em $link mas não é um link (é uma pasta/arquivo real). Resolva manualmente (mova ou remova) antes de rodar de novo."
      FAIL=1
    fi
  else
    ln -s "$target" "$link"
    echo "OK: $label linkado ($link -> $target)"
  fi
}

ensure_link "$REPO_DIR" "$PIPELINE_HOME" "~/agentes-pipeline"
ensure_link "$SKILL_TARGET" "$SKILL_LINK" "skill init-project ($TARGET)"

if [[ -n "${AGENTES_PIPELINE_SKIP_ANTIGRAVITY:-}" ]]; then
  echo "OK: etapa do plugin Superpowers-Antigravity pulada (AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1)"
elif command -v git >/dev/null 2>&1; then
  if [[ -d "$ANTIGRAVITY_PLUGIN_DIR/.git" ]]; then
    echo "OK: plugin Superpowers-Antigravity já presente em $ANTIGRAVITY_PLUGIN_DIR"
  else
    mkdir -p "$(dirname "$ANTIGRAVITY_PLUGIN_DIR")"
    if git clone "$ANTIGRAVITY_PLUGIN_URL" "$ANTIGRAVITY_PLUGIN_DIR"; then
      echo "OK: plugin Superpowers-Antigravity clonado em $ANTIGRAVITY_PLUGIN_DIR"
    else
      echo "ERRO: falha ao clonar o plugin Superpowers-Antigravity. Resolva manualmente, ou apague $ANTIGRAVITY_PLUGIN_DIR se o clone ficou parcial."
      FAIL=1
    fi
  fi
else
  echo "AVISO: git não encontrado no PATH — pulei a instalação do plugin Superpowers-Antigravity. Instale git e rode este script de novo, ou clone manualmente: git clone $ANTIGRAVITY_PLUGIN_URL $ANTIGRAVITY_PLUGIN_DIR"
fi

echo ""
echo "Lembretes (não automatizáveis por este script):"
echo "  - Dentro do Claude Code, rode: /plugin install superpowers@claude-plugins-official"
if ! command -v agy >/dev/null 2>&1; then
  echo "  - Antigravity CLI não encontrado no PATH. Instale com: npm install -g @google/antigravity"
fi

exit "$FAIL"
