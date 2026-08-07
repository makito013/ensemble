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
  HOME="$FAKE_HOME" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 bash "$INSTALLER"
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
HOME="$CONFLICT_HOME" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 bash "$INSTALLER" > "$FIXTURE/out-conflict.txt" 2>&1
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

HOME="$PROFILE_HOME" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 \
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
HOME="$PROFILE_HOME" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 \
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
HOME="$SELFREF_HOME" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 \
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
HOME="$FAKEGIT_HOME" PATH="$FAKEGIT_BIN:$PATH" bash "$INSTALLER" > "$FIXTURE/out-fakegit.txt" 2>&1
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

if [[ "$fail" -eq 0 ]]; then
  echo "TODOS OS TESTES PASSARAM"
  exit 0
else
  echo "ALGUM TESTE FALHOU"
  exit 1
fi
