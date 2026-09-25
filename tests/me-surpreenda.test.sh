#!/usr/bin/env bash
# Modo "Me Surpreenda" do Time de Design: revezamento criativo em torneio.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

# grep -F: padrões com colchetes literais ("[AVALIADOR]") não podem virar
# classe de caracteres.
check() {
  local file="$1" pattern="$2" label="$3"
  if [[ ! -f "$file" ]]; then
    echo "FAIL: $file não existe ($label)"
    fail=1
  elif grep -qF -- "$pattern" "$file"; then
    echo "PASS: $label"
  else
    echo "FAIL: $file não contém '$pattern' ($label)"
    fail=1
  fi
}

check_absent() {
  local file="$1" pattern="$2" label="$3"
  if grep -qF -- "$pattern" "$file"; then
    echo "FAIL: $file ainda contém '$pattern' ($label)"
    fail=1
  else
    echo "PASS: $label"
  fi
}

A="$ROOT/agentes"
G="$ROOT/gemini/skills"

# --- DESAFIANTE: persona, regra de >=2 eixos, proibição do genérico ---
for f in "$A/DESAFIANTE.md" "$G/desafiante/SKILL.md"; do
  check "$f" 'Mude estruturalmente ≥2 eixos' "$(basename "$(dirname "$f")")/$(basename "$f"): regra de ≥2 eixos"
  check "$f" 'Proibido o genérico' "$(basename "$(dirname "$f")")/$(basename "$f"): proíbe o genérico"
  check "$f" 'hero centralizado + 3 cards' "$(basename "$(dirname "$f")")/$(basename "$f"): exemplo concreto de genérico"
  check "$f" 'APOSTA' "$(basename "$(dirname "$f")")/$(basename "$f"): declara a aposta"
  check "$f" '[DESAFIANTE] Rodada k — lente:' "$(basename "$(dirname "$f")")/$(basename "$f"): header de entrega"
  check "$f" 'candidato-r<k>.html' "$(basename "$(dirname "$f")")/$(basename "$f"): caminho do candidato"
  check "$f" 'prefers-reduced-motion' "$(basename "$(dirname "$f")")/$(basename "$f"): piso de movimento"
done
check "$A/DESAFIANTE.md" 'Ver "Subagentes e escolha de modelo" em `.agents/PIPELINE.md`.' "DESAFIANTE.md tem a linha-ponteiro"
check "$G/desafiante/SKILL.md" 'name: desafiante' "gemini desafiante tem frontmatter name"

# --- AVALIADOR: modo duelo, header determinístico, crítica do campeão ---
for f in "$A/AVALIADOR.md" "$G/avaliador/SKILL.md"; do
  check "$f" '## Modo duelo' "$f: seção Modo duelo"
  check "$f" '[AVALIADOR] Duelo — vencedor: X|Y — margem: clara|leve|empate técnico' "$f: header determinístico do duelo"
  check "$f" '### Crítica do campeão' "$f: Crítica do campeão"
  check "$f" 'nunca prescreve a solução' "$f: crítica aponta o alvo sem prescrever"
  check "$f" 'julgamento sem render' "$f: fallback sem render declarado"
  check "$f" 'REFERENCIAS.md' "$f: barra estética via REFERENCIAS.md"
  check_absent "$f" 'animista.net' "$f: sem referência hardcoded"
  check "$f" 'Dentro de uma volta você é somente leitura' "$f: artefato imutável dentro da volta"
done

# --- ORQUESTRADOR: Constituição, lentes, parada, contexto não cresce ---
for f in "$A/ORQUESTRADOR.md" "$G/orquestrador/SKILL.md"; do
  check "$f" 'Modo "Me Surpreenda"' "$f: seção do modo"
  check "$f" 'CONSTITUICAO.md' "$f: Constituição"
  check "$f" 'Quebra de' "$f: baralho de lentes"
  check "$f" 'ainda não usada' "$f: lente sem repetição"
  check "$f" 'sobrevive a 2 duelos consecutivos' "$f: parada por 2 duelos"
  check "$f" 'Nunca passe os perdedores anteriores' "$f: perdedores fora do contexto"
  check "$f" 'design-snapshot.mjs' "$f: portão automático via script"
  check "$f" 'galeria.html' "$f: galeria ao parar"
  check "$f" 'DELEGAR: <papel>' "$f: loop do modo padrão ligado (DELEGAR)"
done
check "$A/PIPELINE.md" 'DESAFIANTE' "PIPELINE.md lista o Desafiante"
check "$A/PIPELINE.md" 'modo duelo sempre rodam em Opus' "PIPELINE.md: modelo do torneio"

# --- ORQUESTRADOR-DESIGN: modo e artefatos no DESIGN-STATE, estado íntegro ---
for f in "$A/ORQUESTRADOR-DESIGN.md" "$G/orquestrador-design/SKILL.md"; do
  check "$f" '## (g) Modo' "$f: campo (g) Modo"
  check "$f" '## (h) Artefatos' "$f: campo (h) Artefatos"
  check "$f" 'Lentes usadas' "$f: histórico do torneio"
  check_absent "$f" 'ou um resumo do que mudou nele' "$f: exige DESIGN-STATE íntegro"
done

# --- Comando /time-design aceita o modo no argumento ---
for f in "$ROOT/commands/time-design.md" "$ROOT/.claude/commands/time-design.md" "$G/time-design/SKILL.md"; do
  check "$f" 'surpreenda 4 landing page do produto X' "$f: exemplo de modo + N no argumento"
  check "$f" 'me surpreenda' "$f: oferece o modo me surpreenda"
done
if diff -q "$ROOT/commands/time-design.md" "$ROOT/.claude/commands/time-design.md" >/dev/null; then
  echo "PASS: commands/time-design.md idêntico à cópia em .claude/commands/"
else
  echo "FAIL: commands/time-design.md diverge da cópia em .claude/commands/"
  fail=1
fi

# --- Script do portão: sintaxe válida e rastreado pelo --update ---
if command -v node >/dev/null 2>&1; then
  if node --check "$A/scripts/design-snapshot.mjs"; then
    echo "PASS: node --check design-snapshot.mjs"
  else
    echo "FAIL: design-snapshot.mjs com erro de sintaxe"
    fail=1
  fi
else
  echo "FAIL: node não encontrado para validar design-snapshot.mjs"
  fail=1
fi
check "$ROOT/scripts/init-manifest-diff.sh" 'scripts/*.mjs' "init-manifest-diff.sh rastreia scripts .mjs"

exit $fail
