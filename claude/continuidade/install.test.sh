#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/install.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

FAKE_HOME="$FIXTURE/home"
mkdir -p "$FAKE_HOME"
TARGET1="$FAKE_HOME/.claude"
TARGET2="$FAKE_HOME/.claude-work"

fail=0

run_installer() {
  HOME="$FAKE_HOME" CLAUDE_CONTINUIDADE_HOME="$FAKE_HOME/.claude-resume-queue" \
    CLAUDE_CONTINUIDADE_NO_LAUNCHCTL=1 bash "$INSTALLER" --target "$1"
}

# --- primeira instalação, perfil 1 ---
run_installer "$TARGET1" > "$FIXTURE/out1.txt"

if [[ -f "$TARGET1/hooks/continuidade/queue.js" ]]; then
  echo "PASS: queue.js copiado pro alvo 1"
else
  echo "FAIL: queue.js não copiado pro alvo 1"
  fail=1
fi
if [[ -f "$TARGET1/skills/pausar-trabalho/SKILL.md" && -f "$TARGET1/skills/continuar-trabalho/SKILL.md" ]]; then
  echo "PASS: skills de pausar/continuar copiados pro alvo 1"
else
  echo "FAIL: skills não copiados pro alvo 1"
  fail=1
fi
if grep -q 'StopFailure' "$TARGET1/settings.json" && grep -q 'continuidade/queue.js' "$TARGET1/settings.json"; then
  echo "PASS: hook StopFailure mesclado no settings.json do alvo 1"
else
  echo "FAIL: hook StopFailure ausente no settings.json do alvo 1: $(cat "$TARGET1/settings.json" 2>/dev/null)"
  fail=1
fi
if [[ -f "$FAKE_HOME/.claude-resume-queue/bin/watcher.js" ]]; then
  echo "PASS: watcher compartilhado instalado"
else
  echo "FAIL: watcher compartilhado não instalado"
  fail=1
fi
if [[ -f "$FAKE_HOME/Library/LaunchAgents/com.agentes-pipeline.continuidade-watcher.plist" ]]; then
  echo "PASS: plist do watcher criado"
else
  echo "FAIL: plist do watcher não foi criado"
  fail=1
fi

# --- rodar de novo no mesmo alvo: idempotente ---
run_installer "$TARGET1" > "$FIXTURE/out1-repeat.txt"
HOOK_COUNT=$(grep -o 'continuidade/queue.js' "$TARGET1/settings.json" | wc -l | tr -d ' ')
if [[ "$HOOK_COUNT" == "1" ]]; then
  echo "PASS: rodar install.sh de novo no mesmo alvo não duplica o hook"
else
  echo "FAIL: hook duplicado, aparece $HOOK_COUNT vezes"
  fail=1
fi
if grep -qi "já presente" "$FIXTURE/out1-repeat.txt"; then
  echo "PASS: segunda execução avisa que o watcher compartilhado já está presente"
else
  echo "FAIL: segunda execução não avisou sobre watcher já presente. Saída: $(cat "$FIXTURE/out1-repeat.txt")"
  fail=1
fi

# --- regredir: rodar de novo no mesmo alvo não cria diretórios aninhados ---
if [[ ! -d "$TARGET1/hooks/continuidade/lib/lib" ]]; then
  echo "PASS: segunda execução não cria lib/lib aninhado em hooks"
else
  echo "FAIL: lib/lib aninhado detectado em $TARGET1/hooks/continuidade/lib/lib"
  fail=1
fi
if [[ ! -d "$TARGET1/skills/pausar-trabalho/pausar-trabalho" ]]; then
  echo "PASS: segunda execução não cria pausar-trabalho/pausar-trabalho aninhado"
else
  echo "FAIL: pausar-trabalho/pausar-trabalho aninhado detectado em $TARGET1/skills/pausar-trabalho/pausar-trabalho"
  fail=1
fi
if [[ ! -d "$TARGET1/skills/continuar-trabalho/continuar-trabalho" ]]; then
  echo "PASS: segunda execução não cria continuar-trabalho/continuar-trabalho aninhado"
else
  echo "FAIL: continuar-trabalho/continuar-trabalho aninhado detectado em $TARGET1/skills/continuar-trabalho/continuar-trabalho"
  fail=1
fi
if [[ -f "$TARGET1/hooks/continuidade/lib/queue-store.js" ]]; then
  echo "PASS: queue-store.js está no topo de hooks/continuidade/lib (não aninhado)"
else
  echo "FAIL: queue-store.js não encontrado em $TARGET1/hooks/continuidade/lib"
  fail=1
fi

# --- segundo perfil: hooks instalados, watcher compartilhado NÃO duplicado ---
run_installer "$TARGET2" > "$FIXTURE/out2.txt"
if [[ -f "$TARGET2/hooks/continuidade/queue.js" ]]; then
  echo "PASS: queue.js copiado pro alvo 2"
else
  echo "FAIL: queue.js não copiado pro alvo 2"
  fail=1
fi
PLIST_COUNT=$(find "$FAKE_HOME/Library/LaunchAgents" -name 'com.agentes-pipeline.continuidade-watcher.plist' | wc -l | tr -d ' ')
if [[ "$PLIST_COUNT" == "1" ]]; then
  echo "PASS: ainda existe só 1 plist do watcher, mesmo após instalar um segundo perfil"
else
  echo "FAIL: esperado 1 plist, encontrado $PLIST_COUNT"
  fail=1
fi

# --- regredir: segundo perfil não cria lib/lib aninhado no watcher compartilhado ---
if [[ ! -d "$FAKE_HOME/.claude-resume-queue/bin/lib/lib" ]]; then
  echo "PASS: segundo perfil não cria lib/lib aninhado no watcher compartilhado"
else
  echo "FAIL: lib/lib aninhado detectado em $FAKE_HOME/.claude-resume-queue/bin/lib/lib"
  fail=1
fi

exit $fail
