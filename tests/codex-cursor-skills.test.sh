#!/usr/bin/env bash
# codex-cursor-skills.test.sh — contrato dos adapters de Codex e Cursor (Fase 2).
#
# O ponto central destes testes é a trava de invocação implícita. Ela é a peça
# que faz valer a regra "gatilho sempre manual" fora do Claude Code:
#   - Codex: `agents/openai.yaml` com `policy.allow_implicit_invocation: false`
#   - Cursor: `disable-model-invocation: true` no frontmatter do SKILL.md
# Sem estes testes, apagar o openai.yaml ou virar a flag para `true` passaria
# despercebido — o Orquestrador voltaria a poder disparar sozinho.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CODEX="$ROOT/codex"
CURSOR="$ROOT/cursor"
fail=0

check() {
  local file="$1" pattern="$2" label="$3"
  if [[ ! -f "$file" ]]; then
    echo "FAIL: $file não existe"
    fail=1
    return
  fi
  if ! grep -q -E -- "$pattern" "$file"; then
    echo "FAIL: $file não contém '$pattern' ($label)"
    fail=1
    return
  fi
  echo "PASS: $label"
}

check_absent() {
  local file="$1" pattern="$2" label="$3"
  if [[ ! -f "$file" ]]; then
    echo "FAIL: $file não existe"
    fail=1
    return
  fi
  if grep -q -E -- "$pattern" "$file"; then
    echo "FAIL: $file contém '$pattern' e não deveria ($label)"
    fail=1
    return
  fi
  echo "PASS: $label"
}

check_file_exists() {
  local file="$1" label="$2"
  if [[ -f "$file" ]]; then
    echo "PASS: $label"
  else
    echo "FAIL: $file não existe ($label)"
    fail=1
  fi
}

# Todas as skills de cada adapter, não uma lista fixa: um dispatcher novo sem
# a trava tem que falhar aqui. As duas escritas à mão precisam estar presentes.
skills_in() { find "$1/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | LC_ALL=C sort; }
for adapter in "$CODEX" "$CURSOR"; do
  for required in orquestrador init-project; do
    check_file_exists "$adapter/skills/$required/SKILL.md" "${adapter#$ROOT/}/$required presente"
  done
done

# --- Codex: skills + trava de invocação implícita ---------------------------

for skill in $(skills_in "$CODEX"); do
  check "$CODEX/skills/$skill/SKILL.md" "^name: $skill$" "codex/$skill tem name correto"

  yaml="$CODEX/skills/$skill/agents/openai.yaml"
  check_file_exists "$yaml" "codex/$skill tem agents/openai.yaml no caminho esperado"
  # Duas linhas exatas, indentação inclusa: a trava só vale se o campo estiver
  # aninhado sob `policy:`. Um `allow_implicit_invocation` na raiz não trava
  # nada, e a diferença é invisível a olho nu.
  check "$yaml" '^policy:$' "codex/$skill: openai.yaml tem a chave raiz policy:"
  check "$yaml" '^  allow_implicit_invocation: false$' \
    "codex/$skill: allow_implicit_invocation aninhado sob policy e igual a false"
  check_absent "$yaml" '^ *allow_implicit_invocation: *true' \
    "codex/$skill: a trava nunca está ligada em true"

  # O SKILL.md tem que explicar por que a trava existe — é o que impede alguém
  # de "limpar" o yaml achando que é sobra.
  check "$CODEX/skills/$skill/SKILL.md" 'allow_implicit_invocation' \
    "codex/$skill: SKILL.md documenta a trava allow_implicit_invocation"
done

# --- Cursor: skills + trava de invocação implícita --------------------------

for skill in $(skills_in "$CURSOR"); do
  check "$CURSOR/skills/$skill/SKILL.md" "^name: $skill$" "cursor/$skill tem name correto"
  check "$CURSOR/skills/$skill/SKILL.md" '^disable-model-invocation: true$' \
    "cursor/$skill: disable-model-invocation true no frontmatter"
done

# --- codex/AGENTS-block.md: fonte do bloco, nunca os marcadores -------------

# agents-md-block.sh recusa (exit 2) uma fonte que já traga os marcadores; se
# alguém colar um marcador aqui, o adapter do Codex para de instalar.
check_absent "$CODEX/AGENTS-block.md" 'agentes-pipeline:(begin|end)' \
  "codex/AGENTS-block.md não contém os marcadores (quem os emite é o script)"
check "$CODEX/AGENTS-block.md" '\.codex/skills/' "codex/AGENTS-block.md aponta para .codex/skills/"
check "$CODEX/AGENTS-block.md" 'gatilho é sempre manual' \
  "codex/AGENTS-block.md repete a regra de gatilho manual"
check "$CODEX/AGENTS-block.md" 'allow_implicit_invocation' \
  "codex/AGENTS-block.md explica a trava para quem lê o AGENTS.md do projeto"

# --- init-project: o passo 7b precisa levar o yaml junto -------------------

# Se o passo de cópia falar só de SKILL.md, o openai.yaml nunca chega no
# projeto instalado e a trava some sem nenhum sinal.
INIT="$ROOT/claude/skills/init-project/SKILL.md"
check "$INIT" 'agents/openai.yaml' \
  "init-project/SKILL.md manda copiar também agents/openai.yaml (subpasta de cada skill)"
check "$INIT" 'agents-md-block\.sh apply' \
  "init-project/SKILL.md aplica o bloco do AGENTS.md via script determinístico"
check "$INIT" '\.cursor/skills/' "init-project/SKILL.md materializa .cursor/skills/"
check "$INIT" '\.codex/skills/' "init-project/SKILL.md materializa .codex/skills/"

# --- finais de linha: nenhum arquivo do adapter pode ter CRLF ---------------

# `grep -c $'\r'` NÃO serve aqui: no Git Bash o `$'\r'` não é expandido, o
# padrão vira vazio e casa com todas as linhas (falso positivo silencioso).
crlf_lines() { awk '/\r/{n++} END{print n+0}' "$1"; }

# Guarda de lista não-vazia: `while ... done < <(find ...)` roda o corpo no
# shell atual (não numa subshell), então o contador sobrevive. Sem esta
# asserção, um `find` que não retorna nada (ex.: codex/ ou cursor/ renomeados)
# faria zero asserções rodarem e a suíte ainda passaria em silêncio.
swept=0
while IFS= read -r f; do
  swept=$((swept + 1))
  n="$(crlf_lines "$f")"
  if [[ "$n" -eq 0 ]]; then
    echo "PASS: ${f#$ROOT/} sem CRLF"
  else
    echo "FAIL: ${f#$ROOT/} tem $n linha(s) com CRLF"
    fail=1
  fi
done < <(find "$CODEX" "$CURSOR" -type f \( -name '*.md' -o -name '*.mdc' -o -name '*.yaml' \) | sort)

# Mínimo esperado: SKILL.md + agents/openai.yaml por skill do Codex, SKILL.md
# por skill do Cursor e o AGENTS-block.md. Se cair abaixo disso, o sweep de
# CRLF acima não cobriu o que devia.
expected=$(( 2 * $(skills_in "$CODEX" | wc -l) + $(skills_in "$CURSOR" | wc -l) + 1 ))
if [[ "$expected" -ge 7 && "$swept" -ge "$expected" ]]; then
  echo "PASS: sweep de CRLF cobriu $swept arquivo(s) de codex/+cursor/ (>= $expected esperados)"
else
  echo "FAIL: sweep de CRLF cobriu só $swept arquivo(s) de codex/+cursor/ (esperado >= $expected, mínimo 7) — find retornou lista vazia ou incompleta"
  fail=1
fi

n="$(crlf_lines "$ROOT/scripts/agents-md-block.sh")"
if [[ "$n" -eq 0 ]]; then
  echo "PASS: scripts/agents-md-block.sh sem CRLF (roda sob bash real)"
else
  echo "FAIL: scripts/agents-md-block.sh tem $n linha(s) com CRLF"
  fail=1
fi

exit $fail
