#!/usr/bin/env bash
# refinement.test.sh — the refinement document: fixed template + deterministic
# renderer (agentes/scripts/render-refinement.mjs) used as the pre-dev gate, and
# the wiring of the Time de Refinamento into the orchestrator docs.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
A="$ROOT/agentes"
G="$ROOT/gemini/skills"
RENDER="$A/scripts/render-refinement.mjs"
FIXTURE="$ROOT/tests/fixtures/refinamento-exemplo.json"
fail=0
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }
check() { grep -qF -- "$2" "$1" && pass "$3" || bad "$3 ($1 sem '$2')"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! command -v node >/dev/null 2>&1; then
  echo "SKIP: node ausente — renderizador não testado"
else
  # --- open blocking question => exit 3, still renders ---
  set +e
  node "$RENDER" "$FIXTURE" "$TMP/out.html" >"$TMP/log" 2>&1
  rc=$?
  set -e
  [[ "$rc" == 3 ]] && pass "dúvida bloqueante sem resposta => saída 3" || bad "saída $rc (esperado 3)"
  grep -q 'D1:' "$TMP/log" && pass "lista a dúvida bloqueante aberta" || bad "log sem D1"
  grep -q 'D2:' "$TMP/log" && bad "dúvida respondida listada como aberta" || pass "dúvida respondida não bloqueia"
  grep -q 'D3:' "$TMP/log" && bad "dúvida não bloqueante listada" || pass "dúvida não bloqueante não bloqueia"
  [[ -s "$TMP/out.html" ]] && pass "renderiza mesmo com o gate fechado" || bad "HTML vazio"
  grep -q '{{' "$TMP/out.html" && bad "slot do template sem preencher" || pass "todos os slots preenchidos"
  grep -q 'Aguardando 1 dúvida bloqueante' "$TMP/out.html" && pass "banner mostra o gate fechado" || bad "banner"
  for section in 'O que será feito' 'Por quê' 'Onde (arquivos e módulos)' 'Como — tarefas em ordem' 'Dúvidas que precisam de resposta antes do desenvolvimento' 'Critérios de aceitação' 'Fora de escopo' 'Se acontecer — decisões já autorizadas'; do
    grep -qF "$section" "$TMP/out.html" && pass "seção fixa: $section" || bad "seção ausente: $section"
  done
  grep -q 'src/auth/providers/google.ts' "$TMP/out.html" && pass "onde lista os caminhos" || bad "onde sem caminhos"
  grep -q 'Mais de um usuário com o mesmo e-mail' "$TMP/out.html" && pass "contingência mostra o limite para parar" || bad "contingência sem escalateIf"
  grep -q '<script' "$TMP/out.html" && bad "HTML gerado tem script" || pass "HTML autocontido, sem script"
  grep -Eq '(src|href)="https?://' "$TMP/out.html" && bad "HTML referencia recurso externo" || pass "HTML sem recurso externo"

  # --- answering the last blocking question opens the gate ---
  node -e '
    const fs = require("fs");
    const d = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    d.questions[0].answer = "B — pedir a senha";
    d.title = "<script>alert(1)</script> & {{title}}";
    fs.writeFileSync(process.argv[2], JSON.stringify(d));
  ' "$FIXTURE" "$TMP/answered.json"
  set +e
  node "$RENDER" "$TMP/answered.json" "$TMP/ready.html" >/dev/null 2>&1
  rc=$?
  set -e
  [[ "$rc" == 0 ]] && pass "sem dúvida bloqueante aberta => saída 0" || bad "saída $rc (esperado 0)"
  grep -q 'Pronto para desenvolvimento' "$TMP/ready.html" && pass "banner pronto para desenvolvimento" || bad "banner pronto"
  grep -q '&lt;script&gt;alert(1)&lt;/script&gt; &amp; {{title}}' "$TMP/ready.html" \
    && pass "dado é escapado e nunca reprocessado como slot" || bad "escape/slot do título"

  # --- invalid data => exit 1, nothing written ---
  echo '{"id":"x","title":"t"}' >"$TMP/bad.json"
  set +e
  node "$RENDER" "$TMP/bad.json" "$TMP/bad.html" >/dev/null 2>&1
  rc=$?
  set -e
  [[ "$rc" == 1 && ! -e "$TMP/bad.html" ]] && pass "JSON incompleto => saída 1 sem gerar HTML" || bad "inválido: saída $rc"
  jq_bad='{"id":"x","title":"t","summary":"s","why":"w","what":["a"],"acceptanceCriteria":["c"],"where":[{"path":"a","change":"rename"}],"questions":[]}'
  echo "$jq_bad" >"$TMP/bad2.json"
  set +e
  node "$RENDER" "$TMP/bad2.json" "$TMP/bad2.html" >/dev/null 2>&1
  rc=$?
  set -e
  [[ "$rc" == 1 ]] && pass "change fora de create|modify|remove é recusado" || bad "change inválido aceito"
  node -e '
    const fs = require("fs");
    const d = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    d.contingencies.push({ id: "C9", when: "" });
    fs.writeFileSync(process.argv[2], JSON.stringify(d));
  ' "$FIXTURE" "$TMP/bad3.json"
  set +e
  node "$RENDER" "$TMP/bad3.json" "$TMP/bad3.html" >"$TMP/log3" 2>&1
  rc=$?
  set -e
  [[ "$rc" == 1 ]] && grep -q 'contingencies\[2\].then' "$TMP/log3" \
    && pass "contingência sem gatilho/ação é recusada" || bad "contingência inválida: saída $rc"
  set +e
  node "$RENDER" "$FIXTURE" >/dev/null 2>&1
  rc=$?
  set -e
  [[ "$rc" == 2 ]] && pass "uso errado => saída 2" || bad "uso: saída $rc"
fi

# --- wiring: docs, persona and parity ---
check "$A/REFINADOR.md" '[REFINADOR] Refinamento pronto' "Refinador tem o marcador determinístico de pronto"
check "$A/REFINADOR.md" '[REFINADOR] Refinamento com dúvidas (N)' "Refinador tem o marcador de dúvidas"
check "$A/REFINADOR.md" 'Nada sensível' "Refinador proíbe dado sensível (o documento pode ser commitado)"
check "$G/refinador/SKILL.md" '[REFINADOR] Refinamento pronto' "skill gemini refinador tem o marcador"
check "$A/REFINAMENTO-FLOW.md" 'render-refinement.mjs' "fluxo usa o renderizador determinístico"
check "$A/REFINAMENTO-FLOW.md" 'Gate de refinamento' "fluxo tem o gate antes do Dev"
check "$A/REFINAMENTO-FLOW.md" 'board.sh related' "fluxo checa conflito no quadro"
check "$A/ORQUESTRADOR.md" '.agents/REFINAMENTO-FLOW.md' "núcleo diz quando ler REFINAMENTO-FLOW.md"
check "$A/ORQUESTRADOR.md" '.agents/QUADRO.md' "núcleo diz quando ler QUADRO.md"
check "$A/ORQUESTRADOR.md" 'Gate de refinamento' "núcleo tem o gate de refinamento"
check "$G/orquestrador/SKILL.md" 'Gate de refinamento' "gemini orquestrador tem o gate de refinamento"
check "$A/PIPELINE.md" '.agents/REFINAMENTO-FLOW.md' "PIPELINE.md lista REFINAMENTO-FLOW.md como sob demanda"
check "$A/PIPELINE.md" '.agents/QUADRO.md' "PIPELINE.md lista QUADRO.md como sob demanda"
check "$A/MODELOS.md" 'Refinador' "MODELOS.md define o modelo do Refinador"
check "$A/MODELOS.md" 'Antecipador' "MODELOS.md define o modelo do Antecipador"
check "$A/ANTECIPADOR.md" '[ANTECIPADOR] Pre-mortem concluído' "Antecipador tem o marcador de entrega"
check "$A/ANTECIPADOR.md" 'Nada sensível' "Antecipador proíbe dado sensível"
check "$A/REFINADOR.md" '"contingencies"' "Refinador grava as contingências"
check "$A/REFINAMENTO-FLOW.md" 'ANTECIPADOR.md' "fluxo dispara o Antecipador"
check "$A/REFINAMENTO-FLOW.md" 'Desenvolvimento sem perguntas' "fluxo confere o documento antes de perguntar ao usuário"
check "$ROOT/commands/orquestrador-refinar.md" 'Antecipador' "/orquestrador-refinar sempre roda o Antecipador"
check "$G/orquestrador-refinar/SKILL.md" 'antecipador' "gemini orquestrador-refinar roda o antecipador"
check "$A/DEV.md" 'Refinamento aprovado = siga sem perguntar' "Dev aplica contingências sem perguntar"
check "$G/dev/SKILL.md" 'Refinamento aprovado = siga sem perguntar' "gemini dev aplica contingências sem perguntar"
check "$A/DEV.md" 'refinamento.json' "Dev recebe o refinamento"
check "$A/REVISOR.md" 'fora do "where"' "Revisor confere escopo contra o refinamento"

# --- step-by-step setup wizard (one question per message) ---
for f in "$A/ORQUESTRADOR.md" "$G/orquestrador/SKILL.md"; do
  n="${f#"$ROOT"/}"
  check "$f" 'Assistente de configuração (um passo por vez)' "$n: assistente por etapas"
  check "$f" 'Uma pergunta por mensagem' "$n: uma pergunta por mensagem"
  check "$f" 'Quantos revisores independentes?' "$n: passo de revisão pergunta a quantidade"
  check "$f" 'subagente novo e limpo' "$n: explica que cada revisor é limpo e isolado"
  check "$f" 'AskUserQuestion' "$n: usa a ferramenta de perguntas com opções quando existir"
  if grep -qF '[ ] 1. ANÁLISE' "$f"; then bad "$n: ainda tem o menu de checkboxes"; else pass "$n: menu de checkboxes removido"; fi
done
check "$A/REVISOR.md" 'revisor novo e limpo' "REVISOR.md declara o isolamento"
check "$G/revisor/SKILL.md" 'revisor novo e limpo' "gemini revisor declara o isolamento"

exit $fail
