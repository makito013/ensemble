#!/usr/bin/env bash
# pipeline-status.sh — resumo determinístico (só leitura) de .agents/PIPELINE-STATE.md.
# Uso: pipeline-status.sh [raiz-do-projeto]   (default: diretório atual)
# Saída 0: resumo impresso, ou "nenhum pipeline em aberto" se não houver estado.
# Saída 2: PIPELINE-STATE.md malformado (sem cabeçalho ou sem "Próxima ação concreta").
set -euo pipefail

ROOT="${1:-.}"
STATE="$ROOT/.agents/PIPELINE-STATE.md"
RUN_DIR="$ROOT/.agents/.pipeline-run"

if [[ ! -f "$STATE" ]]; then
  echo "nenhum pipeline em aberto"
  exit 0
fi

if ! grep -q '^# Estado do Pipeline' "$STATE"; then
  echo "PIPELINE-STATE.md malformado: cabeçalho '# Estado do Pipeline' ausente" >&2
  exit 2
fi
if ! grep -q '^## Próxima ação concreta' "$STATE"; then
  echo "PIPELINE-STATE.md malformado: seção '## Próxima ação concreta' ausente" >&2
  exit 2
fi

trim() { sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'; }

# Valor de um campo "Chave: valor" do cabeçalho (primeira ocorrência).
field() {
  grep -m1 -E "^$1:" "$STATE" | sed -E "s/^$1:[[:space:]]*//" | trim || true
}

demanda="$(grep -m1 '^# Estado do Pipeline' "$STATE" | sed -E 's/^# Estado do Pipeline[[:space:]]*(—|-)?[[:space:]]*//')"
perfil="$(field 'Perfil ativo')"
tier="$(field 'Tier')"
revisor="$(field 'Revisor')"
base="$(field 'Base \(git\)')"
fase_atual="$(grep -m1 -E 'EM ANDAMENTO' "$STATE" | sed -E 's/^[[:space:]]*- \[.\][[:space:]]*//' || true)"
proxima="$(awk '/^## Próxima ação concreta/{f=1; next} /^## /{f=0} f && NF' "$STATE" | trim)"

echo "Pipeline em aberto: ${demanda:-?}"
echo "Perfil: ${perfil:-?}"
echo "Tier: ${tier:-?}"
[[ -n "$revisor" ]] && echo "Revisor: $revisor"
[[ -n "$base" ]] && echo "Base (git): $base"
echo "Fase atual: ${fase_atual:-—}"

echo
echo "Concluídas:"
grep -E '^[[:space:]]*- \[x\]' "$STATE" | sed -E 's/^[[:space:]]*- \[x\][[:space:]]*/  - /' || echo "  (nenhuma)"

echo "Pendentes:"
grep -E '^[[:space:]]*- \[ \]' "$STATE" | sed -E 's/^[[:space:]]*- \[ \][[:space:]]*/  - /' || echo "  (nenhuma)"

echo "Voltas de retrabalho:"
grep -E 'Voltas:' "$STATE" | trim | sed -E 's/^/  - /' || echo "  (nenhuma registrada)"

echo
echo "Próxima ação concreta: ${proxima:-?}"

echo
echo "Saídas em .agents/.pipeline-run/:"
if [[ -d "$RUN_DIR" ]] && [[ -n "$(ls -A "$RUN_DIR" 2>/dev/null)" ]]; then
  (cd "$RUN_DIR" && find . -mindepth 1 -maxdepth 2 | sed -E 's#^\./##' | LC_ALL=C sort | sed -E 's#^#  - .agents/.pipeline-run/#')
else
  echo "  (nenhuma)"
fi
