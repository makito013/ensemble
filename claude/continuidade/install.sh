#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "uso: install.sh --target <pasta-de-config>" >&2
  echo "  ex: install.sh --target ~/.claude" >&2
  echo "      install.sh --target ~/.claude-work" >&2
  exit 2
}

TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done
[[ -n "$TARGET" ]] || usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$SCRIPT_DIR/core"
QUEUE_HOME="${CLAUDE_CONTINUIDADE_HOME:-$HOME/.claude-resume-queue}"

mkdir -p "$TARGET/hooks/continuidade" "$TARGET/skills"

# 1. instalação compartilhada do watcher (uma vez por máquina)
mkdir -p "$QUEUE_HOME/bin" "$QUEUE_HOME/stale"
cp "$CORE_DIR/watcher.js" "$QUEUE_HOME/bin/watcher.js"
rm -rf "$QUEUE_HOME/bin/lib"
cp -R "$CORE_DIR/lib" "$QUEUE_HOME/bin/lib"

if [[ "$(uname)" == "Darwin" ]]; then
  PLIST="$HOME/Library/LaunchAgents/com.agentes-pipeline.continuidade-watcher.plist"
  if [[ ! -f "$PLIST" ]]; then
    NODE_BIN="$(command -v node)"
    mkdir -p "$(dirname "$PLIST")"
    cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.agentes-pipeline.continuidade-watcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>$NODE_BIN</string>
        <string>$QUEUE_HOME/bin/watcher.js</string>
    </array>
    <key>StartInterval</key>
    <integer>900</integer>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>$QUEUE_HOME/launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>$QUEUE_HOME/launchd.err.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>$HOME</string>
    </dict>
</dict>
</plist>
PLIST_EOF
    if [[ -z "${CLAUDE_CONTINUIDADE_NO_LAUNCHCTL:-}" ]]; then
      launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || launchctl load "$PLIST" 2>/dev/null || true
    fi
    echo "watcher agendado registrado: $PLIST"
  else
    echo "watcher compartilhado já presente ($PLIST), não recriado"
  fi
else
  echo "SO não-Mac detectado — registro de agendador fica a cargo de install.ps1 no Windows"
fi

# 2. copia queue.js (hook de enfileiramento) e state.js pro alvo
cp "$CORE_DIR/queue.js" "$TARGET/hooks/continuidade/queue.js"
cp "$CORE_DIR/state.js" "$TARGET/hooks/continuidade/state.js"
rm -rf "$TARGET/hooks/continuidade/lib"
cp -R "$CORE_DIR/lib" "$TARGET/hooks/continuidade/lib"

# 3. mescla o hook StopFailure no settings.json do alvo
QUEUE_CMD="node \"$TARGET/hooks/continuidade/queue.js\""
node "$CORE_DIR/lib/merge-settings.js" "$TARGET/settings.json" StopFailure "" "$QUEUE_CMD" 10

# 4. copia os skills de pausar/continuar
rm -rf "$TARGET/skills/pausar-trabalho"
cp -R "$SCRIPT_DIR/skills/pausar-trabalho" "$TARGET/skills/pausar-trabalho"
rm -rf "$TARGET/skills/continuar-trabalho"
cp -R "$SCRIPT_DIR/skills/continuar-trabalho" "$TARGET/skills/continuar-trabalho"

echo "instalado em $TARGET:"
echo "  - hook StopFailure -> $TARGET/hooks/continuidade/queue.js"
echo "  - skills /pausar-trabalho e /continuar-trabalho"
echo "  - watcher compartilhado em $QUEUE_HOME/bin/watcher.js"
