#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALLER="$SCRIPT_DIR/install.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

FAKE_HOME="$FIXTURE/home"
mkdir -p "$FAKE_HOME"

fail=0

run_installer() {
  HOME="$FAKE_HOME" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 AGENTES_PIPELINE_AI_TARGETS=claude,antigravity \
    bash "$INSTALLER"
}

# --- primeira execução: cria os dois links ---
OUT1="$(run_installer)"

PIPELINE_LINK="$FAKE_HOME/agentes-pipeline"
SKILL_LINK="$FAKE_HOME/.claude/skills/init-project"

if [[ -L "$PIPELINE_LINK" ]] && [[ "$(cd "$PIPELINE_LINK" && pwd -P)" == "$SCRIPT_DIR" ]]; then
  echo "PASS: ~/agentes-pipeline linkado pro repo"
else
  echo "FAIL: ~/agentes-pipeline não foi linkado corretamente"
  fail=1
fi

if [[ -L "$SKILL_LINK" ]] && [[ "$(cd "$SKILL_LINK" && pwd -P)" == "$SCRIPT_DIR/claude/skills/init-project" ]]; then
  echo "PASS: skill init-project linkado pro repo (perfil padrão ~/.claude)"
else
  echo "FAIL: skill init-project não foi linkado corretamente"
  fail=1
fi

if echo "$OUT1" | grep -q "AGENTES_PIPELINE_SKIP_ANTIGRAVITY"; then
  echo "PASS: etapa do Antigravity respeitou a flag de skip"
else
  echo "FAIL: saída não confirma que a etapa do Antigravity foi pulada: $OUT1"
  fail=1
fi

if echo "$OUT1" | grep -q "plugin install superpowers@claude-plugins-official"; then
  echo "PASS: lembrete do plugin Superpowers impresso"
else
  echo "FAIL: lembrete do plugin Superpowers não apareceu na saída"
  fail=1
fi

# --- segunda execução: idempotente, sem duplicar nem falhar ---
OUT2="$(run_installer)"
if echo "$OUT2" | grep -q "já linkado corretamente"; then
  echo "PASS: segunda execução reconhece os links já corretos"
else
  echo "FAIL: segunda execução não reportou idempotência: $OUT2"
  fail=1
fi

# --- caso de conflito: ~/agentes-pipeline já existe como pasta real ---
CONFLICT_HOME="$FIXTURE/home-conflict"
mkdir -p "$CONFLICT_HOME/agentes-pipeline"
echo "dado do usuário" > "$CONFLICT_HOME/agentes-pipeline/nao-mexer.txt"

set +e
HOME="$CONFLICT_HOME" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 AGENTES_PIPELINE_AI_TARGETS=claude \
  bash "$INSTALLER" > "$FIXTURE/out-conflict.txt" 2>&1
CONFLICT_EXIT=$?
set -e

if [[ "$CONFLICT_EXIT" -ne 0 ]]; then
  echo "PASS: instalador sai com erro quando ~/agentes-pipeline é uma pasta real conflitante"
else
  echo "FAIL: instalador deveria ter saído com erro no caso de conflito"
  fail=1
fi

if [[ -f "$CONFLICT_HOME/agentes-pipeline/nao-mexer.txt" ]]; then
  echo "PASS: pasta conflitante não foi tocada"
else
  echo "FAIL: pasta conflitante foi apagada/alterada"
  fail=1
fi

if grep -q "ERRO" "$FIXTURE/out-conflict.txt"; then
  echo "PASS: mensagem de erro do conflito impressa"
else
  echo "FAIL: mensagem de erro do conflito ausente: $(cat "$FIXTURE/out-conflict.txt")"
  fail=1
fi

# --- --target: linka num perfil diferente do padrão, sem mexer no padrão ---
PROFILE_HOME="$FIXTURE/home-profiles"
mkdir -p "$PROFILE_HOME"

HOME="$PROFILE_HOME" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 AGENTES_PIPELINE_AI_TARGETS=claude \
  bash "$INSTALLER" --target "$PROFILE_HOME/.claude-work" > "$FIXTURE/out-target1.txt"

WORK_SKILL_LINK="$PROFILE_HOME/.claude-work/skills/init-project"
DEFAULT_SKILL_LINK="$PROFILE_HOME/.claude/skills/init-project"

if [[ -L "$WORK_SKILL_LINK" ]] && [[ "$(cd "$WORK_SKILL_LINK" && pwd -P)" == "$SCRIPT_DIR/claude/skills/init-project" ]]; then
  echo "PASS: --target linka o skill no perfil informado (.claude-work)"
else
  echo "FAIL: --target não linkou o skill no perfil informado"
  fail=1
fi

if [[ -e "$DEFAULT_SKILL_LINK" ]]; then
  echo "FAIL: --target mexeu no perfil padrão (.claude), não deveria"
  fail=1
else
  echo "PASS: --target não criou nada no perfil padrão"
fi

# --- segundo perfil: coexiste com o primeiro, sem conflito ---
HOME="$PROFILE_HOME" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 AGENTES_PIPELINE_AI_TARGETS=claude \
  bash "$INSTALLER" --target "$PROFILE_HOME/.claude-podesubir" > "$FIXTURE/out-target2.txt"

PODESUBIR_SKILL_LINK="$PROFILE_HOME/.claude-podesubir/skills/init-project"

if [[ -L "$WORK_SKILL_LINK" ]] && [[ -L "$PODESUBIR_SKILL_LINK" ]]; then
  echo "PASS: dois perfis diferentes coexistem, cada um com seu link"
else
  echo "FAIL: instalar um segundo perfil afetou o primeiro"
  fail=1
fi

# --- --target sem valor: erro de uso, exit code 2 ---
set +e
bash "$INSTALLER" --target > "$FIXTURE/out-usage.txt" 2>&1
USAGE_EXIT=$?
set -e

if [[ "$USAGE_EXIT" -eq 2 ]]; then
  echo "PASS: --target sem valor sai com exit code 2"
else
  echo "FAIL: --target sem valor deveria sair com exit code 2, saiu com $USAGE_EXIT"
  fail=1
fi

# --- self-referência: clonar direto em ~/agentes-pipeline não deve dar erro ---
SELFREF_HOME="$FIXTURE/home-selfref"
SELFREF_REPO="$SELFREF_HOME/agentes-pipeline"
mkdir -p "$SELFREF_REPO/claude/skills/init-project"
cp "$INSTALLER" "$SELFREF_REPO/install.sh"

set +e
HOME="$SELFREF_HOME" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 AGENTES_PIPELINE_AI_TARGETS=claude \
  bash "$SELFREF_REPO/install.sh" > "$FIXTURE/out-selfref.txt" 2>&1
SELFREF_EXIT=$?
set -e

if [[ "$SELFREF_EXIT" -eq 0 ]]; then
  echo "PASS: clonar direto em ~/agentes-pipeline (self-referência) não dá erro"
else
  echo "FAIL: clonar direto em ~/agentes-pipeline deveria funcionar, saiu com $SELFREF_EXIT: $(cat "$FIXTURE/out-selfref.txt")"
  fail=1
fi

if [[ -L "$SELFREF_HOME/.claude/skills/init-project" ]]; then
  echo "PASS: skill init-project linkado mesmo no caso de self-referência"
else
  echo "FAIL: skill init-project não foi linkado no caso de self-referência"
  fail=1
fi

# --- git clone falha: instalador sai com erro mas ainda imprime os lembretes ---
FAKEGIT_HOME="$FIXTURE/home-fakegit"
FAKEGIT_BIN="$FIXTURE/fakegit-bin"
mkdir -p "$FAKEGIT_HOME" "$FAKEGIT_BIN"
cat > "$FAKEGIT_BIN/git" <<'FAKEGIT_EOF'
#!/usr/bin/env bash
echo "fatal: simulado para teste" >&2
exit 128
FAKEGIT_EOF
chmod +x "$FAKEGIT_BIN/git"

set +e
HOME="$FAKEGIT_HOME" PATH="$FAKEGIT_BIN:$PATH" AGENTES_PIPELINE_AI_TARGETS=claude,antigravity \
  bash "$INSTALLER" > "$FIXTURE/out-fakegit.txt" 2>&1
FAKEGIT_EXIT=$?
set -e

if [[ "$FAKEGIT_EXIT" -ne 0 ]]; then
  echo "PASS: git clone falho faz o instalador sair com erro"
else
  echo "FAIL: git clone falho deveria fazer o instalador sair com erro"
  fail=1
fi

if grep -q "ERRO.*Antigravity" "$FIXTURE/out-fakegit.txt"; then
  echo "PASS: mensagem de erro do git clone impressa"
else
  echo "FAIL: mensagem de erro do git clone ausente: $(cat "$FIXTURE/out-fakegit.txt")"
  fail=1
fi

if grep -q "plugin install superpowers@claude-plugins-official" "$FIXTURE/out-fakegit.txt"; then
  echo "PASS: lembretes ainda são impressos mesmo com git clone falho"
else
  echo "FAIL: lembretes não foram impressos após git clone falho: $(cat "$FIXTURE/out-fakegit.txt")"
  fail=1
fi

# --- seleção de IAs (ai-targets) ---
AI_CONFIG_REL=".config/agentes-pipeline/ai-targets.json"

ai_targets_line() {
  grep -F '"aiTargets"' "$1" | head -1 | sed -E 's/^[[:space:]]*//; s/,$//'
}

check_ai_config() {
  local config="$1" expected="$2" label="$3" actual
  if [[ ! -f "$config" ]]; then
    echo "FAIL: $label — arquivo de config não existe ($config)"
    fail=1
    return
  fi
  actual="$(ai_targets_line "$config")"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $label"
  else
    echo "FAIL: $label — esperado '$expected', obtido '$actual'"
    fail=1
  fi
}

# C1 — --ai cursor sem TTY: injeta claude, ordem canônica, sem travar
AI_HOME_C1="$FIXTURE/home-ai-c1"
mkdir -p "$AI_HOME_C1"
set +e
HOME="$AI_HOME_C1" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 \
  bash "$INSTALLER" --ai cursor > "$FIXTURE/out-ai-c1.txt" 2>&1 </dev/null
C1_EXIT=$?
set -e

if [[ "$C1_EXIT" -eq 0 ]]; then
  echo "PASS: --ai cursor sem TTY sai com exit code 0"
else
  echo "FAIL: --ai cursor sem TTY deveria sair com 0, saiu com $C1_EXIT: $(cat "$FIXTURE/out-ai-c1.txt")"
  fail=1
fi

check_ai_config "$AI_HOME_C1/$AI_CONFIG_REL" '"aiTargets": ["claude", "cursor"]' \
  "--ai cursor grava claude+cursor em ordem canônica"

# C2 — --ai bogus: erro de uso e NENHUMA config gravada (validação precede persistência)
AI_HOME_C2="$FIXTURE/home-ai-c2"
mkdir -p "$AI_HOME_C2"
set +e
HOME="$AI_HOME_C2" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 \
  bash "$INSTALLER" --ai bogus > "$FIXTURE/out-ai-c2.txt" 2>&1 </dev/null
C2_EXIT=$?
set -e

if [[ "$C2_EXIT" -eq 2 ]]; then
  echo "PASS: --ai com id desconhecido sai com exit code 2"
else
  echo "FAIL: --ai bogus deveria sair com exit code 2, saiu com $C2_EXIT"
  fail=1
fi

if grep -q "bogus" "$FIXTURE/out-ai-c2.txt"; then
  echo "PASS: mensagem de erro cita o id desconhecido"
else
  echo "FAIL: mensagem de erro não cita 'bogus': $(cat "$FIXTURE/out-ai-c2.txt")"
  fail=1
fi

if [[ ! -f "$AI_HOME_C2/$AI_CONFIG_REL" ]]; then
  echo "PASS: id inválido não grava config (validação precede persistência)"
else
  echo "FAIL: id inválido gravou config mesmo assim"
  fail=1
fi

# C3 — --ai sem valor: erro de uso
set +e
HOME="$FIXTURE/home-ai-c3" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 \
  bash "$INSTALLER" --ai > "$FIXTURE/out-ai-c3.txt" 2>&1 </dev/null
C3_EXIT=$?
set -e

if [[ "$C3_EXIT" -eq 2 ]]; then
  echo "PASS: --ai sem valor sai com exit code 2"
else
  echo "FAIL: --ai sem valor deveria sair com exit code 2, saiu com $C3_EXIT"
  fail=1
fi

# C4 — stdin fechado, sem flag e sem env: cai no default claude com AVISO, sem travar
AI_HOME_C4="$FIXTURE/home-ai-c4"
mkdir -p "$AI_HOME_C4"
set +e
HOME="$AI_HOME_C4" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 \
  bash "$INSTALLER" > "$FIXTURE/out-ai-c4.txt" 2>&1 </dev/null
C4_EXIT=$?
set -e

if [[ "$C4_EXIT" -eq 0 ]]; then
  echo "PASS: sem TTY, sem flag e sem env o instalador não trava e sai com 0"
else
  echo "FAIL: caso não-TTY deveria sair com 0, saiu com $C4_EXIT: $(cat "$FIXTURE/out-ai-c4.txt")"
  fail=1
fi

check_ai_config "$AI_HOME_C4/$AI_CONFIG_REL" '"aiTargets": ["claude"]' \
  "default sem TTY é claude apenas"

if grep -q "AVISO" "$FIXTURE/out-ai-c4.txt"; then
  echo "PASS: caso não-TTY imprime AVISO sobre a seleção usada"
else
  echo "FAIL: caso não-TTY não imprimiu AVISO: $(cat "$FIXTURE/out-ai-c4.txt")"
  fail=1
fi

# C5 — idempotência: duas execuções com --ai codex produzem o mesmo aiTargets
AI_HOME_C5="$FIXTURE/home-ai-c5"
mkdir -p "$AI_HOME_C5"
HOME="$AI_HOME_C5" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 \
  bash "$INSTALLER" --ai codex > /dev/null 2>&1 </dev/null
C5_FIRST="$(ai_targets_line "$AI_HOME_C5/$AI_CONFIG_REL")"
HOME="$AI_HOME_C5" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 \
  bash "$INSTALLER" --ai codex > /dev/null 2>&1 </dev/null
C5_SECOND="$(ai_targets_line "$AI_HOME_C5/$AI_CONFIG_REL")"

if [[ "$C5_FIRST" == "$C5_SECOND" && "$C5_FIRST" == '"aiTargets": ["claude", "codex"]' ]]; then
  echo "PASS: duas execuções com --ai codex produzem aiTargets idêntico"
else
  echo "FAIL: --ai codex não foi idempotente ('$C5_FIRST' vs '$C5_SECOND')"
  fail=1
fi

# C6 — memória: a seleção persistida é reusada quando não há flag nem env
AI_HOME_C6="$FIXTURE/home-ai-c6"
mkdir -p "$AI_HOME_C6"
HOME="$AI_HOME_C6" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 \
  bash "$INSTALLER" --ai antigravity > /dev/null 2>&1 </dev/null
HOME="$AI_HOME_C6" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 \
  bash "$INSTALLER" > "$FIXTURE/out-ai-c6.txt" 2>&1 </dev/null

check_ai_config "$AI_HOME_C6/$AI_CONFIG_REL" '"aiTargets": ["claude", "antigravity"]' \
  "seleção persistida é relida quando não há flag nem env"

# C7 — precedência: a flag --ai vence a variável de ambiente
AI_HOME_C7="$FIXTURE/home-ai-c7"
mkdir -p "$AI_HOME_C7"
HOME="$AI_HOME_C7" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 AGENTES_PIPELINE_AI_TARGETS=cursor \
  bash "$INSTALLER" --ai codex > "$FIXTURE/out-ai-c7.txt" 2>&1 </dev/null

check_ai_config "$AI_HOME_C7/$AI_CONFIG_REL" '"aiTargets": ["claude", "codex"]' \
  "--ai vence AGENTES_PIPELINE_AI_TARGETS (flag > env)"

# C8 — env com id inválido: exit 2 e nenhuma config gravada (espelha C2 no ramo do env)
AI_HOME_C8="$FIXTURE/home-ai-c8"
mkdir -p "$AI_HOME_C8"
set +e
HOME="$AI_HOME_C8" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 AGENTES_PIPELINE_AI_TARGETS=bogus \
  bash "$INSTALLER" > "$FIXTURE/out-ai-c8.txt" 2>&1 </dev/null
C8_EXIT=$?
set -e

if [[ "$C8_EXIT" -eq 2 ]]; then
  echo "PASS: env com id desconhecido sai com exit code 2"
else
  echo "FAIL: env com id desconhecido deveria sair com exit code 2, saiu com $C8_EXIT: $(cat "$FIXTURE/out-ai-c8.txt")"
  fail=1
fi

if [[ ! -f "$AI_HOME_C8/$AI_CONFIG_REL" ]]; then
  echo "PASS: env inválido não grava config (validação precede persistência)"
else
  echo "FAIL: env inválido gravou config mesmo assim"
  fail=1
fi

# C9 — has_ai_target casa por PALAVRA, não por substring (requisito explícito do
# TL). A função é interna ao instalador; extraída e avaliada isoladamente porque
# install.sh só a chama com "antigravity", o que não exercita a borda.
eval "$(sed -n '/^has_ai_target()/,/^}/p' "$INSTALLER")"
AI_TARGETS="claude cursor"
if has_ai_target claude && has_ai_target cursor \
   && ! has_ai_target curs && ! has_ai_target ursor \
   && ! has_ai_target claud && ! has_ai_target antigravity; then
  echo "PASS: has_ai_target casa por palavra inteira, não por substring"
else
  echo "FAIL: has_ai_target não está casando por palavra inteira (AI_TARGETS='$AI_TARGETS')"
  fail=1
fi
unset -f has_ai_target
unset AI_TARGETS

# C10 — quando antigravity NÃO está selecionado, o instalador diz isso
# explicitamente e não menciona a flag de skip (ramo novo do gate)
AI_HOME_C10="$FIXTURE/home-ai-c10"
mkdir -p "$AI_HOME_C10"
HOME="$AI_HOME_C10" bash "$INSTALLER" --ai cursor > "$FIXTURE/out-ai-c10.txt" 2>&1 </dev/null

if grep -q "Antigravity não selecionado" "$FIXTURE/out-ai-c10.txt"; then
  echo "PASS: antigravity fora da seleção imprime o aviso de etapa pulada"
else
  echo "FAIL: antigravity fora da seleção não imprimiu o aviso: $(cat "$FIXTURE/out-ai-c10.txt")"
  fail=1
fi

if grep -q "npm install -g @google/antigravity" "$FIXTURE/out-ai-c10.txt"; then
  echo "FAIL: lembrete do agy apareceu mesmo com antigravity fora da seleção"
  fail=1
else
  echo "PASS: lembrete do agy é omitido quando antigravity não está selecionado"
fi

# C11 — REGRESSÃO DE CANAL DE RETORNO: prompt_ai_targets devolve SÓ a seleção
# no stdout; o menu vai pro stderr. Sem isso o texto do menu vira item de
# aiTargets e corrompe a config (é exatamente o bug vivo hoje no install.ps1,
# em Read-AiTargetSelection). Igualdade exata de propósito: qualquer vazamento
# no canal de retorno tem que quebrar este teste.
eval "$(sed -n '/^validate_ai_target()/,/^}/p;/^normalize_ai_targets()/,/^}/p;/^prompt_ai_targets()/,/^}/p' "$INSTALLER")"
AI_TARGETS_KNOWN="claude antigravity codex cursor"

C11_PICK="$(printf '2 4\n' | prompt_ai_targets claude 2>/dev/null)"
if [[ "$C11_PICK" == "claude antigravity cursor" ]]; then
  echo "PASS: prompt_ai_targets devolve só a seleção no stdout (escolha explícita)"
else
  echo "FAIL: prompt_ai_targets vazou texto no canal de retorno — esperado 'claude antigravity cursor', obtido '$C11_PICK'"
  fail=1
fi

C11_ENTER="$(printf '\n' | prompt_ai_targets "claude codex" 2>/dev/null)"
if [[ "$C11_ENTER" == "claude codex" ]]; then
  echo "PASS: prompt_ai_targets devolve só a seleção no stdout (Enter mantém)"
else
  echo "FAIL: prompt_ai_targets vazou texto no canal de retorno no caminho do Enter — esperado 'claude codex', obtido '$C11_ENTER'"
  fail=1
fi

C11_INVALID="$(printf '9\n9\n9\n' | prompt_ai_targets claude 2>/dev/null)"
if [[ "$C11_INVALID" == "claude" ]]; then
  echo "PASS: prompt_ai_targets devolve só a seleção no stdout (3 entradas inválidas)"
else
  echo "FAIL: prompt_ai_targets vazou texto no canal de retorno após entrada inválida — esperado 'claude', obtido '$C11_INVALID'"
  fail=1
fi

# C12 — REGRESSÃO DE TAB NO MEIO DA ENTRADA: vírgula/espaço nas pontas com TAB
# no meio (ex: ",<TAB>,") tem que ser tratado como "nenhuma seleção real" e
# preservar a pré-seleção — nunca descartar silenciosamente pra "claude"
# sozinho. Um TAB puro sozinho não expõe o bug porque `read` já limpa isso nas
# bordas antes; só a combinação vírgula/espaço + TAB no meio chega até a
# checagem de vazio (ver install.sh, `${answer//[$'\t' ]/}`).
C12_TAB_MID="$(printf ',\t,\n' | prompt_ai_targets "claude codex" 2>/dev/null)"
if [[ "$C12_TAB_MID" == "claude codex" ]]; then
  echo "PASS: ',<TAB>,' preserva a pré-seleção (claude codex)"
else
  echo "FAIL: ',<TAB>,' deveria preservar 'claude codex', obtido '$C12_TAB_MID'"
  fail=1
fi

C12_TAB_MID_SPACES="$(printf ' ,\t, \n' | prompt_ai_targets "claude cursor" 2>/dev/null)"
if [[ "$C12_TAB_MID_SPACES" == "claude cursor" ]]; then
  echo "PASS: ' ,<TAB>, ' preserva a pré-seleção (claude cursor)"
else
  echo "FAIL: ' ,<TAB>, ' deveria preservar 'claude cursor', obtido '$C12_TAB_MID_SPACES'"
  fail=1
fi

unset -f prompt_ai_targets normalize_ai_targets validate_ai_target
unset AI_TARGETS_KNOWN

if [[ "$fail" -eq 0 ]]; then
  echo "TODOS OS TESTES PASSARAM"
  exit 0
else
  echo "ALGUM TESTE FALHOU"
  exit 1
fi
