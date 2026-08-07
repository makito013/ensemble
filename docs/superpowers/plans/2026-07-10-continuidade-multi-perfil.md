# Continuidade de Trabalho Multi-Perfil — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trazer o mecanismo de auto-retomada de sessão (rate limit/crash) e um par de comandos próprios de pausar/continuar trabalho para dentro do `agentes-pipeline`, como algo instalável, versionado e parametrizado por perfil de config (`~/.claude`, `~/.claude-work`, ou qualquer outro), cobrindo Mac e Windows.

**Architecture:** Núcleo em Node.js (CommonJS, sem dependências externas) sob `claude/continuidade/core/`, com funções puras testáveis por trás de dois CLIs finos (`queue.js`, `watcher.js`, `state.js`). Um instalador por SO (`install.sh`, `install.ps1`) copia esses arquivos pro `--target` escolhido, mescla o hook `StopFailure` no `settings.json` e garante — uma única vez por máquina — o watcher compartilhado e seu agendador (launchd/Scheduled Task). Os comandos manuais de pausar/continuar são publicados também pro lado Antigravity (`gemini/skills/`), reaproveitando o mesmo `state.js`.

**Tech Stack:** Node.js 20 (stdlib apenas: `fs`, `path`, `os`, `crypto`, `child_process`), Bash (instalador Mac/Linux + testes, seguindo o padrão já usado em `scripts/init-manifest-diff.test.sh`), PowerShell (instalador Windows).

## Global Constraints

- Node.js >= 20, só stdlib — sem `npm install`, sem `package.json` novo, sem dependências externas.
- Estilo dos módulos Node: CommonJS (`require`/`module.exports`), `'use strict'`, shebang `#!/usr/bin/env node` nos CLIs — mesmo padrão de `~/.claude/hooks/gsd-check-update-worker.js`.
- Testes em Bash, padrão PASS/FAIL por `echo`, `set -euo pipefail`, fixtures via `mktemp -d` + `trap 'rm -rf ...' EXIT`, exit code = flag de falha acumulada — mesmo padrão de `scripts/init-manifest-diff.test.sh`.
- Todo texto voltado ao usuário (SKILL.md, mensagens de instalador, README) em português.
- Nomes de comando fixados: `/pausar-trabalho` e `/continuar-trabalho` (aprovados previamente).
- Fila (`~/.claude-resume-queue` por padrão, override via `CLAUDE_CONTINUIDADE_QUEUE_DIR`) e watcher são **únicos por máquina**, não um por perfil — cada item da fila carrega seu próprio `config_dir`.
- Instaladores devem ser **idempotentes**: rodar duas vezes no mesmo `--target` não duplica hook nem agendador.
- Merge no `settings.json` do alvo é **aditivo** — nunca sobrescreve hooks de outros plugins.
- Testes que tocariam recursos reais da máquina (launchd, `$HOME` real) devem rodar contra fixtures isoladas (`HOME` e diretórios de fila sobrescritos via env var) — nunca contra o `~/.claude` ou `~/.claude-work` reais do Bruno, exceto na tarefa final de rollout, que é explicitamente sobre a máquina real.

---

### Task 1: `queue-store.js` — armazenamento compartilhado da fila

**Files:**
- Create: `claude/continuidade/core/lib/queue-store.js`
- Test: `claude/continuidade/core/lib/queue-store.test.sh`

**Interfaces:**
- Produces: `queueDir(): string`, `staleDir(): string`, `ensureDirs(): void`, `writeItem(item: object): string` (retorna caminho do arquivo escrito), `listItems(): string[]` (caminhos absolutos dos `.json` na fila, não inclui `stale/`), `readItem(file: string): object`, `moveToStale(file: string): void`, `removeItem(file: string): void`.
- Consumes: nada (módulo-base).

- [ ] **Step 1: Escrever o teste**

Crie `claude/continuidade/core/lib/queue-store.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE="$SCRIPT_DIR/queue-store.js"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
export CLAUDE_CONTINUIDADE_QUEUE_DIR="$FIXTURE/queue"

fail=0

# writeItem cria arquivo dentro da fila
FILE1=$(node -e "
const store = require('$MODULE');
const file = store.writeItem({cwd: '/tmp/projA', session_id: 'sess-1', config_dir: '/tmp/.claude', queued_at: 1000});
console.log(file);
")
if [[ -f "$FILE1" ]]; then
  echo "PASS: writeItem cria o arquivo"
else
  echo "FAIL: writeItem não criou $FILE1"
  fail=1
fi

# listItems lista o item recém-criado
COUNT=$(node -e "
const store = require('$MODULE');
console.log(store.listItems().length);
")
if [[ "$COUNT" == "1" ]]; then
  echo "PASS: listItems encontra 1 item"
else
  echo "FAIL: listItems retornou $COUNT itens, esperado 1"
  fail=1
fi

# readItem retorna o conteúdo certo
SESSION=$(node -e "
const store = require('$MODULE');
const file = store.listItems()[0];
console.log(store.readItem(file).session_id);
")
if [[ "$SESSION" == "sess-1" ]]; then
  echo "PASS: readItem lê session_id corretamente"
else
  echo "FAIL: readItem retornou session_id='$SESSION', esperado 'sess-1'"
  fail=1
fi

# moveToStale move o arquivo pra stale/ e ele some de listItems
node -e "
const store = require('$MODULE');
const file = store.listItems()[0];
store.moveToStale(file);
"
COUNT_AFTER_STALE=$(node -e "
const store = require('$MODULE');
console.log(store.listItems().length);
")
STALE_COUNT=$(find "$FIXTURE/queue/stale" -name '*.json' | wc -l | tr -d ' ')
if [[ "$COUNT_AFTER_STALE" == "0" && "$STALE_COUNT" == "1" ]]; then
  echo "PASS: moveToStale tira o item da fila ativa e o coloca em stale/"
else
  echo "FAIL: após moveToStale, fila ativa=$COUNT_AFTER_STALE (esperado 0), stale=$STALE_COUNT (esperado 1)"
  fail=1
fi

# removeItem apaga um arquivo da fila ativa
FILE2=$(node -e "
const store = require('$MODULE');
const file = store.writeItem({cwd: '/tmp/projB', session_id: 'sess-2', config_dir: '/tmp/.claude', queued_at: 2000});
console.log(file);
")
node -e "
const store = require('$MODULE');
store.removeItem('$FILE2');
"
if [[ ! -f "$FILE2" ]]; then
  echo "PASS: removeItem apaga o arquivo"
else
  echo "FAIL: removeItem não apagou $FILE2"
  fail=1
fi

exit $fail
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash claude/continuidade/core/lib/queue-store.test.sh`
Expected: falha logo no início com `Error: Cannot find module '.../queue-store.js'` (o módulo ainda não existe).

- [ ] **Step 3: Implementar `queue-store.js`**

Crie `claude/continuidade/core/lib/queue-store.js`:

```js
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

function queueDir() {
  return process.env.CLAUDE_CONTINUIDADE_QUEUE_DIR || path.join(os.homedir(), '.claude-resume-queue');
}

function staleDir() {
  return path.join(queueDir(), 'stale');
}

function ensureDirs() {
  fs.mkdirSync(queueDir(), { recursive: true });
  fs.mkdirSync(staleDir(), { recursive: true });
}

function writeItem(item) {
  ensureDirs();
  const file = path.join(queueDir(), `${item.queued_at}-${process.pid}.json`);
  fs.writeFileSync(file, JSON.stringify(item, null, 2));
  return file;
}

function listItems() {
  ensureDirs();
  return fs
    .readdirSync(queueDir())
    .filter((name) => name.endsWith('.json'))
    .map((name) => path.join(queueDir(), name));
}

function readItem(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function moveToStale(file) {
  ensureDirs();
  fs.renameSync(file, path.join(staleDir(), path.basename(file)));
}

function removeItem(file) {
  fs.unlinkSync(file);
}

module.exports = {
  queueDir,
  staleDir,
  ensureDirs,
  writeItem,
  listItems,
  readItem,
  moveToStale,
  removeItem,
};
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash claude/continuidade/core/lib/queue-store.test.sh`
Expected: as 5 linhas `PASS:` impressas, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add claude/continuidade/core/lib/queue-store.js claude/continuidade/core/lib/queue-store.test.sh
git commit -m "feat: adiciona queue-store.js — armazenamento compartilhado da fila de retomada"
```

---

### Task 2: `decide.js` — lógica pura de decisão do watcher

**Files:**
- Create: `claude/continuidade/core/lib/decide.js`
- Test: `claude/continuidade/core/lib/decide.test.sh`

**Interfaces:**
- Produces: `decideAction(item: {cwd, session_id, queued_at}, now: number): 'invalid' | 'stale-missing-cwd' | 'stale-expired' | 'retry'`, `MAX_AGE_MS: number` (48h em ms).
- Consumes: nada.

- [ ] **Step 1: Escrever o teste**

Crie `claude/continuidade/core/lib/decide.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE="$SCRIPT_DIR/decide.js"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/projeto-existente"

fail=0

check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $label"
  else
    echo "FAIL: $label — esperado '$expected', obtido '$actual'"
    fail=1
  fi
}

# item sem session_id -> invalid
R1=$(node -e "
const { decideAction } = require('$MODULE');
console.log(decideAction({cwd: '$FIXTURE/projeto-existente', queued_at: 1000}, 2000));
")
check "sem session_id retorna invalid" "invalid" "$R1"

# cwd não existe -> stale-missing-cwd
R2=$(node -e "
const { decideAction } = require('$MODULE');
console.log(decideAction({cwd: '$FIXTURE/projeto-que-nao-existe', session_id: 's1', queued_at: 1000}, 2000));
")
check "cwd inexistente retorna stale-missing-cwd" "stale-missing-cwd" "$R2"

# mais de 48h -> stale-expired
R3=$(node -e "
const { decideAction, MAX_AGE_MS } = require('$MODULE');
const queuedAt = 1000;
const now = queuedAt + MAX_AGE_MS + 1;
console.log(decideAction({cwd: '$FIXTURE/projeto-existente', session_id: 's1', queued_at: queuedAt}, now));
")
check "mais de 48h retorna stale-expired" "stale-expired" "$R3"

# dentro da janela, cwd existe, campos completos -> retry
R4=$(node -e "
const { decideAction, MAX_AGE_MS } = require('$MODULE');
const queuedAt = 1000;
const now = queuedAt + MAX_AGE_MS - 1;
console.log(decideAction({cwd: '$FIXTURE/projeto-existente', session_id: 's1', queued_at: queuedAt}, now));
")
check "dentro da janela e cwd existe retorna retry" "retry" "$R4"

exit $fail
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash claude/continuidade/core/lib/decide.test.sh`
Expected: falha com `Cannot find module '.../decide.js'`.

- [ ] **Step 3: Implementar `decide.js`**

Crie `claude/continuidade/core/lib/decide.js`:

```js
'use strict';

const fs = require('fs');

const MAX_AGE_MS = 48 * 60 * 60 * 1000;

function decideAction(item, now) {
  if (!item.cwd || !item.session_id) return 'invalid';
  if (!fs.existsSync(item.cwd)) return 'stale-missing-cwd';
  if (now - item.queued_at > MAX_AGE_MS) return 'stale-expired';
  return 'retry';
}

module.exports = { decideAction, MAX_AGE_MS };
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash claude/continuidade/core/lib/decide.test.sh`
Expected: 4 linhas `PASS:`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add claude/continuidade/core/lib/decide.js claude/continuidade/core/lib/decide.test.sh
git commit -m "feat: adiciona decide.js — lógica pura de decisão do watcher de retomada"
```

---

### Task 3: `queue.js` — CLI de enfileiramento (hook `StopFailure`)

**Files:**
- Create: `claude/continuidade/core/queue.js`
- Test: `claude/continuidade/core/queue.test.sh`

**Interfaces:**
- Consumes: `writeItem` de `./lib/queue-store.js` (Task 1).
- Produces: nenhuma API exportada relevante pra outras tasks — é um CLI folha, invocado pelo hook `StopFailure` com o payload JSON do Claude Code via stdin.

- [ ] **Step 1: Escrever o teste**

Crie `claude/continuidade/core/queue.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$SCRIPT_DIR/queue.js"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
export CLAUDE_CONTINUIDADE_QUEUE_DIR="$FIXTURE/queue"
export CLAUDE_CONFIG_DIR="$FIXTURE/.claude-perfil-teste"

fail=0

echo '{"cwd":"/tmp/projeto-x","session_id":"sess-abc"}' | node "$CLI"

FILE=$(find "$FIXTURE/queue" -maxdepth 1 -name '*.json' | head -1)
if [[ -n "$FILE" ]]; then
  echo "PASS: queue.js criou um arquivo na fila"
else
  echo "FAIL: nenhum arquivo criado na fila"
  fail=1
fi

CONTENT=$(cat "$FILE")
if echo "$CONTENT" | grep -q '"cwd": "/tmp/projeto-x"'; then
  echo "PASS: cwd do payload original foi preservado"
else
  echo "FAIL: cwd ausente/incorreto no arquivo: $CONTENT"
  fail=1
fi
if echo "$CONTENT" | grep -q '"session_id": "sess-abc"'; then
  echo "PASS: session_id do payload original foi preservado"
else
  echo "FAIL: session_id ausente/incorreto no arquivo: $CONTENT"
  fail=1
fi
if echo "$CONTENT" | grep -q "\"config_dir\": \"$FIXTURE/.claude-perfil-teste\""; then
  echo "PASS: config_dir foi lido de CLAUDE_CONFIG_DIR"
else
  echo "FAIL: config_dir incorreto no arquivo: $CONTENT"
  fail=1
fi
if echo "$CONTENT" | grep -q '"queued_at":'; then
  echo "PASS: queued_at foi adicionado"
else
  echo "FAIL: queued_at ausente no arquivo: $CONTENT"
  fail=1
fi

exit $fail
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash claude/continuidade/core/queue.test.sh`
Expected: falha com `Cannot find module` ou arquivo não encontrado (o CLI ainda não existe).

- [ ] **Step 3: Implementar `queue.js`**

Crie `claude/continuidade/core/queue.js`:

```js
#!/usr/bin/env node
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { writeItem } = require('./lib/queue-store');

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch (err) {
    return '';
  }
}

function defaultConfigDir() {
  return path.join(os.homedir(), '.claude');
}

function main() {
  const raw = readStdin();
  let payload = {};
  try {
    payload = raw.trim() ? JSON.parse(raw) : {};
  } catch (err) {
    payload = {};
  }
  const item = Object.assign({}, payload, {
    config_dir: process.env.CLAUDE_CONFIG_DIR || defaultConfigDir(),
    queued_at: Date.now(),
  });
  writeItem(item);
}

main();
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash claude/continuidade/core/queue.test.sh`
Expected: 4 linhas `PASS:`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add claude/continuidade/core/queue.js claude/continuidade/core/queue.test.sh
git commit -m "feat: adiciona queue.js — CLI de enfileiramento chamado pelo hook StopFailure"
```

---

### Task 4: `watcher.js` — CLI que varre a fila e tenta retomar

**Files:**
- Create: `claude/continuidade/core/watcher.js`
- Test: `claude/continuidade/core/watcher.test.sh`

**Interfaces:**
- Consumes: `listItems`, `readItem`, `moveToStale`, `removeItem` de `./lib/queue-store.js` (Task 1); `decideAction` de `./lib/decide.js` (Task 2).
- Produces: `run(now: number, claudeBin?: string): Array<{file: string, action: string, output?: string}>` — usada por watcher.test.sh e futuramente pelo instalador pra smoke-test.

- [ ] **Step 1: Escrever o teste**

Crie `claude/continuidade/core/watcher.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE="$SCRIPT_DIR/watcher.js"
STORE="$SCRIPT_DIR/lib/queue-store.js"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
export CLAUDE_CONTINUIDADE_QUEUE_DIR="$FIXTURE/queue"
mkdir -p "$FIXTURE/projeto-vivo"

fail=0

# stub do binário `claude`: primeira chamada responde sucesso, controlado por
# um arquivo-flag que o teste apaga/cria entre as fases
cat > "$FIXTURE/fake-claude.sh" <<'EOF'
#!/usr/bin/env bash
if [[ -f "$FAKE_CLAUDE_RATE_LIMIT_FLAG" ]]; then
  echo "ainda em rate limit, tente novamente mais tarde"
  exit 0
fi
echo "retomado com sucesso"
exit 0
EOF
chmod +x "$FIXTURE/fake-claude.sh"

# item 1: cwd existe, deve tentar retomar e conseguir (flag ausente)
node -e "
const store = require('$STORE');
store.writeItem({cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-live', config_dir: '$FIXTURE/.claude', queued_at: 1000});
"

# item 2: cwd não existe, deve virar stale
node -e "
const store = require('$STORE');
store.writeItem({cwd: '$FIXTURE/projeto-fantasma', session_id: 'sess-ghost', config_dir: '$FIXTURE/.claude', queued_at: 1000});
"

export FAKE_CLAUDE_RATE_LIMIT_FLAG="$FIXTURE/rate-limit.flag"
NOW=2000
RESULT=$(node -e "
const { run } = require('$MODULE');
const results = run($NOW, '$FIXTURE/fake-claude.sh');
console.log(JSON.stringify(results));
")

if echo "$RESULT" | grep -q '"action":"resumed"'; then
  echo "PASS: item com cwd válido foi marcado como 'resumed'"
else
  echo "FAIL: item com cwd válido não foi retomado. Resultado: $RESULT"
  fail=1
fi
if echo "$RESULT" | grep -q '"action":"stale-missing-cwd"'; then
  echo "PASS: item com cwd inexistente foi marcado como stale-missing-cwd"
else
  echo "FAIL: item com cwd inexistente não foi marcado como stale. Resultado: $RESULT"
  fail=1
fi

REMAINING=$(find "$FIXTURE/queue" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
if [[ "$REMAINING" == "0" ]]; then
  echo "PASS: fila ativa ficou vazia (item resumido removido, item fantasma movido pra stale)"
else
  echo "FAIL: fila ativa ainda tem $REMAINING item(ns), esperado 0"
  fail=1
fi

STALE_COUNT=$(find "$FIXTURE/queue/stale" -name '*.json' | wc -l | tr -d ' ')
if [[ "$STALE_COUNT" == "1" ]]; then
  echo "PASS: exatamente 1 item foi pra stale/"
else
  echo "FAIL: stale/ tem $STALE_COUNT item(ns), esperado 1"
  fail=1
fi

# --- fase 2: item ainda em rate limit deve permanecer na fila ---
touch "$FAKE_CLAUDE_RATE_LIMIT_FLAG"
node -e "
const store = require('$STORE');
store.writeItem({cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-live-2', config_dir: '$FIXTURE/.claude', queued_at: 1500});
"
RESULT2=$(node -e "
const { run } = require('$MODULE');
const results = run($NOW, '$FIXTURE/fake-claude.sh');
console.log(JSON.stringify(results));
")
if echo "$RESULT2" | grep -q '"action":"still-blocked"'; then
  echo "PASS: item ainda em rate limit foi marcado como still-blocked"
else
  echo "FAIL: item em rate limit não foi marcado corretamente. Resultado: $RESULT2"
  fail=1
fi
REMAINING2=$(find "$FIXTURE/queue" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
if [[ "$REMAINING2" == "1" ]]; then
  echo "PASS: item ainda bloqueado permanece na fila"
else
  echo "FAIL: fila deveria ter 1 item ainda bloqueado, tem $REMAINING2"
  fail=1
fi

exit $fail
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash claude/continuidade/core/watcher.test.sh`
Expected: falha com `Cannot find module '.../watcher.js'`.

- [ ] **Step 3: Implementar `watcher.js`**

Crie `claude/continuidade/core/watcher.js`:

```js
#!/usr/bin/env node
'use strict';

const { execFileSync } = require('child_process');
const { listItems, readItem, moveToStale, removeItem } = require('./lib/queue-store');
const { decideAction } = require('./lib/decide');

const RESUME_PROMPT =
  'Você foi interrompido por ter atingido o limite de uso ou por um erro. ' +
  'Se o problema já foi resolvido, retome exatamente de onde parou e ' +
  'continue a tarefa em andamento até concluir ou até realmente precisar ' +
  'de uma decisão do usuário que só ele pode tomar.';

const RATE_LIMIT_PATTERN = /rate.?limit|usage limit|limit reached|limit atingido/i;

function attemptResume(item, claudeBin) {
  const bin = claudeBin || process.env.CLAUDE_CONTINUIDADE_BIN || 'claude';
  const env = Object.assign({}, process.env, { CLAUDE_CONFIG_DIR: item.config_dir });
  try {
    const output = execFileSync(
      bin,
      ['-r', item.session_id, '-p', RESUME_PROMPT, '--permission-mode', 'acceptEdits'],
      { cwd: item.cwd, env, encoding: 'utf8' }
    );
    return { ok: !RATE_LIMIT_PATTERN.test(output), output };
  } catch (err) {
    return { ok: false, output: String((err && err.stdout) || (err && err.message) || '') };
  }
}

function run(now, claudeBin) {
  const results = [];
  for (const file of listItems()) {
    const item = readItem(file);
    const action = decideAction(item, now);
    if (action === 'invalid' || action === 'stale-missing-cwd' || action === 'stale-expired') {
      moveToStale(file);
      results.push({ file, action });
      continue;
    }
    const { ok, output } = attemptResume(item, claudeBin);
    if (ok) {
      removeItem(file);
      results.push({ file, action: 'resumed', output });
    } else {
      results.push({ file, action: 'still-blocked', output });
    }
  }
  return results;
}

if (require.main === module) {
  run(Date.now());
}

module.exports = { run, attemptResume };
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash claude/continuidade/core/watcher.test.sh`
Expected: 6 linhas `PASS:`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add claude/continuidade/core/watcher.js claude/continuidade/core/watcher.test.sh
git commit -m "feat: adiciona watcher.js — CLI que varre a fila e tenta retomar sessões via claude -r"
```

---

### Task 5: `state.js` — núcleo de pausar/continuar trabalho

**Files:**
- Create: `claude/continuidade/core/state.js`
- Test: `claude/continuidade/core/state.test.sh`

**Interfaces:**
- Produces: `save({configDir, cwd, sessionId, summary}): string` (retorna caminho do arquivo), `load({configDir, cwd}): string | null`, `stateFile(configDir, cwd): string`, `stateDir(configDir): string`. CLI: `state.js save --config-dir <dir> --cwd <path> [--session-id <id>]` (lê o resumo do stdin) e `state.js load --config-dir <dir> --cwd <path>` (imprime o conteúdo ou `SEM_ESTADO_PAUSADO` com exit code 1).
- Consumes: nada (módulo-base, usado pelos SKILL.md de pausar/continuar-trabalho nas Tasks 6 e 7).

- [ ] **Step 1: Escrever o teste**

Crie `claude/continuidade/core/state.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$SCRIPT_DIR/state.js"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
CONFIG_DIR="$FIXTURE/.claude-perfil-teste"
mkdir -p "$CONFIG_DIR"
PROJ="$FIXTURE/meu-projeto"
mkdir -p "$PROJ"

fail=0

# load sem nenhuma pausa salva -> SEM_ESTADO_PAUSADO, exit 1
set +e
OUT_VAZIO=$(node "$CLI" load --config-dir "$CONFIG_DIR" --cwd "$PROJ")
CODE_VAZIO=$?
set -e
if [[ "$CODE_VAZIO" == "1" && "$OUT_VAZIO" == "SEM_ESTADO_PAUSADO" ]]; then
  echo "PASS: load sem pausa salva retorna SEM_ESTADO_PAUSADO com exit 1"
else
  echo "FAIL: esperado exit 1 + SEM_ESTADO_PAUSADO, obtido exit=$CODE_VAZIO saida='$OUT_VAZIO'"
  fail=1
fi

# save grava o resumo
echo "Estava implementando o parser de config. Próximo passo: cobrir o caso de arquivo vazio." \
  | node "$CLI" save --config-dir "$CONFIG_DIR" --cwd "$PROJ" --session-id "sess-42"

FILE_COUNT=$(find "$CONFIG_DIR/continuidade/state" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$FILE_COUNT" == "1" ]]; then
  echo "PASS: save cria exatamente 1 arquivo de estado"
else
  echo "FAIL: esperado 1 arquivo de estado, encontrado $FILE_COUNT"
  fail=1
fi

# load depois do save retorna o conteúdo
OUT_CHEIO=$(node "$CLI" load --config-dir "$CONFIG_DIR" --cwd "$PROJ")
if echo "$OUT_CHEIO" | grep -q "parser de config"; then
  echo "PASS: load retorna o resumo salvo"
else
  echo "FAIL: load não retornou o resumo esperado. Saída: $OUT_CHEIO"
  fail=1
fi
if echo "$OUT_CHEIO" | grep -q "session_id: sess-42"; then
  echo "PASS: load inclui o session_id salvo"
else
  echo "FAIL: session_id ausente na saída: $OUT_CHEIO"
  fail=1
fi

# save de novo no mesmo cwd sobrescreve (não empilha)
echo "Resumo atualizado depois de terminar o parser." \
  | node "$CLI" save --config-dir "$CONFIG_DIR" --cwd "$PROJ" --session-id "sess-43"
FILE_COUNT_2=$(find "$CONFIG_DIR/continuidade/state" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$FILE_COUNT_2" == "1" ]]; then
  echo "PASS: segundo save sobrescreve em vez de empilhar (ainda 1 arquivo)"
else
  echo "FAIL: esperado 1 arquivo após segundo save, encontrado $FILE_COUNT_2"
  fail=1
fi
OUT_ATUALIZADO=$(node "$CLI" load --config-dir "$CONFIG_DIR" --cwd "$PROJ")
if echo "$OUT_ATUALIZADO" | grep -q "Resumo atualizado"; then
  echo "PASS: load retorna o resumo mais recente"
else
  echo "FAIL: load não retornou o resumo atualizado. Saída: $OUT_ATUALIZADO"
  fail=1
fi

exit $fail
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash claude/continuidade/core/state.test.sh`
Expected: falha com `Cannot find module '.../state.js'` ou arquivo inexistente.

- [ ] **Step 3: Implementar `state.js`**

Crie `claude/continuidade/core/state.js`:

```js
#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function stateDir(configDir) {
  return path.join(configDir, 'continuidade', 'state');
}

function stateFile(configDir, cwd) {
  const hash = crypto.createHash('sha256').update(cwd).digest('hex').slice(0, 16);
  return path.join(stateDir(configDir), `${hash}.md`);
}

function save({ configDir, cwd, sessionId, summary }) {
  fs.mkdirSync(stateDir(configDir), { recursive: true });
  const file = stateFile(configDir, cwd);
  const body = [
    '---',
    `cwd: ${cwd}`,
    `session_id: ${sessionId || 'desconhecido'}`,
    `paused_at: ${new Date().toISOString()}`,
    '---',
    '',
    summary.trim(),
    '',
  ].join('\n');
  fs.writeFileSync(file, body);
  return file;
}

function load({ configDir, cwd }) {
  const file = stateFile(configDir, cwd);
  if (!fs.existsSync(file)) return null;
  return fs.readFileSync(file, 'utf8');
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i].replace(/^--/, '');
    args[key] = argv[i + 1];
  }
  return args;
}

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch (err) {
    return '';
  }
}

function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  const args = parseArgs(rest);
  if (cmd === 'save') {
    const summary = readStdin();
    const file = save({
      configDir: args['config-dir'],
      cwd: args.cwd,
      sessionId: args['session-id'],
      summary,
    });
    console.log(file);
  } else if (cmd === 'load') {
    const content = load({ configDir: args['config-dir'], cwd: args.cwd });
    if (content === null) {
      console.log('SEM_ESTADO_PAUSADO');
      process.exitCode = 1;
    } else {
      process.stdout.write(content);
    }
  } else {
    console.error('uso: state.js save --config-dir <dir> --cwd <path> [--session-id <id>] < resumo.md');
    console.error('     state.js load --config-dir <dir> --cwd <path>');
    process.exitCode = 2;
  }
}

if (require.main === module) main();

module.exports = { save, load, stateFile, stateDir };
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash claude/continuidade/core/state.test.sh`
Expected: 6 linhas `PASS:`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add claude/continuidade/core/state.js claude/continuidade/core/state.test.sh
git commit -m "feat: adiciona state.js — nucleo de pausar/continuar trabalho por cwd"
```

---

### Task 6: `merge-settings.js` — merge idempotente de hooks no `settings.json`

**Files:**
- Create: `claude/continuidade/core/lib/merge-settings.js`
- Test: `claude/continuidade/core/lib/merge-settings.test.sh`

**Interfaces:**
- Produces: `mergeHook(settings: object, eventName: string, matcher: string|null, command: string, timeout?: number): object`, `mergeSettingsFile(filePath: string, eventName: string, matcher: string|null, command: string, timeout?: number): void`. CLI: `merge-settings.js <filePath> <eventName> <matcher-ou-vazio> <command> [timeout]`.
- Consumes: nada.

- [ ] **Step 1: Escrever o teste**

Crie `claude/continuidade/core/lib/merge-settings.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$SCRIPT_DIR/merge-settings.js"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

fail=0

# --- caso 1: settings.json não existe ainda ---
SETTINGS1="$FIXTURE/settings-novo.json"
node "$CLI" "$SETTINGS1" StopFailure "" 'node "/caminho/queue.js"' 10
if [[ -f "$SETTINGS1" ]]; then
  echo "PASS: cria settings.json quando não existe"
else
  echo "FAIL: settings.json não foi criado"
  fail=1
fi
if grep -q 'StopFailure' "$SETTINGS1" && grep -q 'queue.js' "$SETTINGS1"; then
  echo "PASS: hook StopFailure presente no arquivo novo"
else
  echo "FAIL: hook StopFailure ausente: $(cat "$SETTINGS1")"
  fail=1
fi

# --- caso 2: settings.json já existe com outros hooks (não pode mexer neles) ---
SETTINGS2="$FIXTURE/settings-existente.json"
cat > "$SETTINGS2" <<'EOF'
{
  "hooks": {
    "Notification": [
      { "hooks": [ { "type": "command", "command": "afplay some.aiff" } ] }
    ]
  }
}
EOF
node "$CLI" "$SETTINGS2" StopFailure "" 'node "/caminho/queue.js"' 10
if grep -q 'afplay some.aiff' "$SETTINGS2"; then
  echo "PASS: hook pré-existente (Notification) foi preservado"
else
  echo "FAIL: hook pré-existente foi perdido: $(cat "$SETTINGS2")"
  fail=1
fi
if grep -q 'StopFailure' "$SETTINGS2"; then
  echo "PASS: hook StopFailure foi adicionado ao lado do existente"
else
  echo "FAIL: hook StopFailure não foi adicionado: $(cat "$SETTINGS2")"
  fail=1
fi

# --- caso 3: rodar de novo não duplica (idempotente) ---
node "$CLI" "$SETTINGS2" StopFailure "" 'node "/caminho/queue.js"' 10
COUNT=$(grep -o 'queue.js' "$SETTINGS2" | wc -l | tr -d ' ')
if [[ "$COUNT" == "1" ]]; then
  echo "PASS: rodar o merge de novo não duplica a entrada (idempotente)"
else
  echo "FAIL: entrada duplicada, 'queue.js' aparece $COUNT vezes"
  fail=1
fi

exit $fail
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash claude/continuidade/core/lib/merge-settings.test.sh`
Expected: falha com `Cannot find module '.../merge-settings.js'`.

- [ ] **Step 3: Implementar `merge-settings.js`**

Crie `claude/continuidade/core/lib/merge-settings.js`:

```js
#!/usr/bin/env node
'use strict';

const fs = require('fs');

function mergeHook(settings, eventName, matcher, command, timeout) {
  const hooks = settings.hooks || (settings.hooks = {});
  const list = hooks[eventName] || (hooks[eventName] = []);
  const alreadyPresent = list.some((entry) => (entry.hooks || []).some((h) => h.command === command));
  if (alreadyPresent) return settings;
  const hookDef = { type: 'command', command };
  if (timeout) hookDef.timeout = timeout;
  const entry = { hooks: [hookDef] };
  if (matcher) entry.matcher = matcher;
  list.push(entry);
  return settings;
}

function mergeSettingsFile(filePath, eventName, matcher, command, timeout) {
  let settings = {};
  if (fs.existsSync(filePath)) {
    settings = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  }
  settings = mergeHook(settings, eventName, matcher, command, timeout);
  fs.writeFileSync(filePath, `${JSON.stringify(settings, null, 2)}\n`);
}

function main() {
  const [filePath, eventName, matcherRaw, command, timeoutRaw] = process.argv.slice(2);
  const matcher = matcherRaw && matcherRaw.length > 0 ? matcherRaw : null;
  const timeout = timeoutRaw ? Number(timeoutRaw) : undefined;
  mergeSettingsFile(filePath, eventName, matcher, command, timeout);
}

if (require.main === module) main();

module.exports = { mergeHook, mergeSettingsFile };
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash claude/continuidade/core/lib/merge-settings.test.sh`
Expected: 5 linhas `PASS:`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add claude/continuidade/core/lib/merge-settings.js claude/continuidade/core/lib/merge-settings.test.sh
git commit -m "feat: adiciona merge-settings.js — merge aditivo e idempotente de hooks no settings.json"
```

---

### Task 7: Skills `/pausar-trabalho` e `/continuar-trabalho` (lado Claude Code)

**Files:**
- Create: `claude/continuidade/skills/pausar-trabalho/SKILL.md`
- Create: `claude/continuidade/skills/continuar-trabalho/SKILL.md`

**Interfaces:**
- Consumes: `state.js` (Task 5) via linha de comando, no caminho fixo `~/agentes-pipeline/claude/continuidade/core/state.js` (mesma convenção de `TEMPLATE_DIR` já usada no `init-project`).
- Produces: nada (arquivos-folha, consumidos apenas pelo runtime do Claude Code ao interpretar `/pausar-trabalho` e `/continuar-trabalho`).

Este task não tem teste automatizado — `SKILL.md` é um documento de instruções em linguagem natural para o agente, não código executável isoladamente. A verificação é a Task 12 (rollout local), que exercita os dois comandos de ponta a ponta.

- [ ] **Step 1: Criar `claude/continuidade/skills/pausar-trabalho/SKILL.md`**

```markdown
---
name: pausar-trabalho
description: Salva um resumo do que está em andamento no projeto atual, pra continuar depois — no mesmo perfil, em outro perfil (.claude/.claude-work), ou até em outra ferramenta (Antigravity). Use quando o usuário disser /pausar-trabalho ou pedir explicitamente pra pausar ou guardar o progresso.
---

# pausar-trabalho

Grava um checkpoint do trabalho em andamento no diretório atual, pra retomar
depois com `/continuar-trabalho`.

## Passos

1. Resolva `CONFIG_DIR`:
   - Se a variável de ambiente `CLAUDE_CONFIG_DIR` estiver definida, use o
     valor dela.
   - Senão, use `~/.claude`.
2. Monte um resumo em texto corrido (sem precisar de seções rotuladas) do
   que está em andamento: a tarefa atual, o que já foi feito até agora, os
   próximos passos concretos, e os arquivos principais tocados. Seja
   específico o bastante pra alguém sem memória desta conversa conseguir
   continuar a partir só desse texto.
3. Rode, com o resumo do passo 2 no stdin:
   ```bash
   node ~/agentes-pipeline/claude/continuidade/core/state.js save \
     --config-dir "$CONFIG_DIR" --cwd "$(pwd)" <<'EOF'
   <resumo do passo 2>
   EOF
   ```
   (Se você souber o `session_id` da sessão atual, inclua
   `--session-id "<id>"` no comando — se não souber, pode omitir.)
4. Confirme pro usuário, em uma frase curta, que o progresso foi salvo e que
   ele pode retomar depois com `/continuar-trabalho` — no mesmo lugar, em
   outro perfil, ou em outra ferramenta, desde que seja o mesmo diretório de
   projeto.
```

- [ ] **Step 2: Criar `claude/continuidade/skills/continuar-trabalho/SKILL.md`**

```markdown
---
name: continuar-trabalho
description: Retoma o trabalho salvo por /pausar-trabalho no diretório atual. Use quando o usuário disser /continuar-trabalho ou pedir pra continuar de onde parou.
---

# continuar-trabalho

Lê o checkpoint salvo por `/pausar-trabalho` para o diretório atual e retoma
o trabalho a partir dali.

## Passos

1. Resolva `CONFIG_DIR` (mesma regra do `/pausar-trabalho`:
   `CLAUDE_CONFIG_DIR` se definida, senão `~/.claude`).
2. Rode:
   ```bash
   node ~/agentes-pipeline/claude/continuidade/core/state.js load \
     --config-dir "$CONFIG_DIR" --cwd "$(pwd)"
   ```
3. Se a saída for exatamente `SEM_ESTADO_PAUSADO` (o comando também retorna
   exit code 1 nesse caso): informe ao usuário que não há nenhuma pausa
   salva para este diretório, e pare por aqui.
4. Caso contrário, a saída é o resumo salvo, com um cabeçalho de metadados
   (`cwd`, `session_id`, `paused_at`) seguido do texto do resumo. Leia o
   conteúdo, mostre um resumo curto pro usuário do que estava em andamento
   (e há quanto tempo, com base em `paused_at`), e continue o trabalho a
   partir dos próximos passos descritos ali.
```

- [ ] **Step 3: Commit**

```bash
git add claude/continuidade/skills/pausar-trabalho/SKILL.md claude/continuidade/skills/continuar-trabalho/SKILL.md
git commit -m "feat: adiciona skills /pausar-trabalho e /continuar-trabalho (lado Claude Code)"
```

---

### Task 8: Skills espelhados no lado Antigravity (`gemini/skills/`)

**Files:**
- Create: `gemini/skills/pausar-trabalho/SKILL.md`
- Create: `gemini/skills/continuar-trabalho/SKILL.md`

**Interfaces:**
- Consumes: `state.js` (Task 5), mesmo caminho fixo `~/agentes-pipeline/claude/continuidade/core/state.js`.
- Produces: nada.

Sem hook envolvido — Antigravity não tem diretório de skills por-máquina
confirmado (`~/.gemini/commands` e `~/.gemini/agents` existem mas vazios
nesta máquina), então o `CONFIG_DIR` aqui é fixo (`~/.gemini`), sem
equivalente a `CLAUDE_CONFIG_DIR`. Sem teste automatizado, pelo mesmo motivo
da Task 7 — verificado na Task 12.

- [ ] **Step 1: Criar `gemini/skills/pausar-trabalho/SKILL.md`**

```markdown
---
name: pausar-trabalho
description: Salva um resumo do que está em andamento no projeto atual, pra continuar depois — nesta ferramenta ou no Claude Code, desde que seja o mesmo projeto. Use quando o usuário disser /pausar-trabalho ou pedir explicitamente pra pausar ou guardar o progresso.
---

# pausar-trabalho

Grava um checkpoint do trabalho em andamento no diretório atual, pra retomar
depois com `/continuar-trabalho` — inclusive no Claude Code, se for o mesmo
projeto.

## Passos

1. Monte um resumo em texto corrido (sem precisar de seções rotuladas) do
   que está em andamento: a tarefa atual, o que já foi feito até agora, os
   próximos passos concretos, e os arquivos principais tocados. Seja
   específico o bastante pra alguém sem memória desta conversa conseguir
   continuar a partir só desse texto.
2. Rode, com o resumo do passo 1 no stdin:
   ```bash
   node ~/agentes-pipeline/claude/continuidade/core/state.js save \
     --config-dir "$HOME/.gemini" --cwd "$(pwd)" <<'EOF'
   <resumo do passo 1>
   EOF
   ```
3. Confirme pro usuário, em uma frase curta, que o progresso foi salvo e que
   ele pode retomar depois com `/continuar-trabalho` — nesta ferramenta ou
   no Claude Code, desde que seja o mesmo diretório de projeto.
```

- [ ] **Step 2: Criar `gemini/skills/continuar-trabalho/SKILL.md`**

```markdown
---
name: continuar-trabalho
description: Retoma o trabalho salvo por /pausar-trabalho no diretório atual (feito nesta ferramenta ou no Claude Code). Use quando o usuário disser /continuar-trabalho ou pedir pra continuar de onde parou.
---

# continuar-trabalho

Lê o checkpoint salvo por `/pausar-trabalho` para o diretório atual e retoma
o trabalho a partir dali.

## Passos

1. Rode:
   ```bash
   node ~/agentes-pipeline/claude/continuidade/core/state.js load \
     --config-dir "$HOME/.gemini" --cwd "$(pwd)"
   ```
2. Se a saída for exatamente `SEM_ESTADO_PAUSADO`: informe ao usuário que
   não há nenhuma pausa salva para este diretório, e pare por aqui.
3. Caso contrário, a saída é o resumo salvo, com um cabeçalho de metadados
   (`cwd`, `session_id`, `paused_at`) seguido do texto do resumo. Leia o
   conteúdo, mostre um resumo curto pro usuário do que estava em andamento
   (e há quanto tempo, com base em `paused_at`), e continue o trabalho a
   partir dos próximos passos descritos ali.
```

- [ ] **Step 3: Commit**

```bash
git add gemini/skills/pausar-trabalho/SKILL.md gemini/skills/continuar-trabalho/SKILL.md
git commit -m "feat: espelha /pausar-trabalho e /continuar-trabalho pro lado Antigravity"
```

---

### Task 9: `install.sh` — instalador Mac/Linux

**Files:**
- Create: `claude/continuidade/install.sh`
- Test: `claude/continuidade/install.test.sh`

**Interfaces:**
- Consumes: `core/queue.js` (Task 3), `core/watcher.js` (Task 4), `core/state.js` (Task 5), `core/lib/merge-settings.js` (Task 6), `skills/pausar-trabalho/` e `skills/continuar-trabalho/` (Task 7).
- Produces: nada consumido por outra task — é o CLI final do lado Mac/Linux, exercitado na Task 12.

- [ ] **Step 1: Escrever o teste**

Crie `claude/continuidade/install.test.sh`:

```bash
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

exit $fail
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash claude/continuidade/install.test.sh`
Expected: falha logo na primeira chamada — `install.sh: No such file or directory` (o instalador ainda não existe).

- [ ] **Step 3: Implementar `install.sh`**

Crie `claude/continuidade/install.sh`:

```bash
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
cp -R "$CORE_DIR/lib" "$TARGET/hooks/continuidade/lib"

# 3. mescla o hook StopFailure no settings.json do alvo
QUEUE_CMD="node \"$TARGET/hooks/continuidade/queue.js\""
node "$CORE_DIR/lib/merge-settings.js" "$TARGET/settings.json" StopFailure "" "$QUEUE_CMD" 10

# 4. copia os skills de pausar/continuar
cp -R "$SCRIPT_DIR/skills/pausar-trabalho" "$TARGET/skills/pausar-trabalho"
cp -R "$SCRIPT_DIR/skills/continuar-trabalho" "$TARGET/skills/continuar-trabalho"

echo "instalado em $TARGET:"
echo "  - hook StopFailure -> $TARGET/hooks/continuidade/queue.js"
echo "  - skills /pausar-trabalho e /continuar-trabalho"
echo "  - watcher compartilhado em $QUEUE_HOME/bin/watcher.js"
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash claude/continuidade/install.test.sh`
Expected: 8 linhas `PASS:`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add claude/continuidade/install.sh claude/continuidade/install.test.sh
git commit -m "feat: adiciona install.sh — instalador Mac/Linux idempotente por --target"
```

---

### Task 10: `install.ps1` — instalador Windows (sem execução validada)

**Files:**
- Create: `claude/continuidade/install.ps1`

**Interfaces:**
- Consumes: os mesmos arquivos de `core/` e `skills/` do Task 9, via caminhos relativos ao script.
- Produces: nada.

Sem teste automatizado nesta task — não há PowerShell disponível nesta
máquina (`pwsh` ausente), e o próprio Bruno confirmou que só consegue testar
no Mac. Este script segue a mesma estrutura lógica do `install.sh`
(Task 9), documentado passo a passo, com um checklist de verificação manual
que vai pro `README.md` (Task 11).

- [ ] **Step 1: Criar `claude/continuidade/install.ps1`**

```powershell
param(
    [Parameter(Mandatory = $true)]
    [string]$Target
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CoreDir = Join-Path $ScriptDir "core"
$QueueHome = if ($env:CLAUDE_CONTINUIDADE_HOME) { $env:CLAUDE_CONTINUIDADE_HOME } else { Join-Path $env:USERPROFILE ".claude-resume-queue" }

New-Item -ItemType Directory -Force -Path (Join-Path $Target "hooks\continuidade") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Target "skills") | Out-Null

# 1. instalação compartilhada do watcher (uma vez por máquina)
$WatcherBinDir = Join-Path $QueueHome "bin"
New-Item -ItemType Directory -Force -Path $WatcherBinDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $QueueHome "stale") | Out-Null
Copy-Item -Path (Join-Path $CoreDir "watcher.js") -Destination (Join-Path $WatcherBinDir "watcher.js") -Force
Copy-Item -Path (Join-Path $CoreDir "lib") -Destination $WatcherBinDir -Recurse -Force

$TaskName = "AgentesPipelineContinuidadeWatcher"
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $ExistingTask) {
    $NodePath = (Get-Command node).Source
    $WatcherScript = Join-Path $WatcherBinDir "watcher.js"
    $Action = New-ScheduledTaskAction -Execute $NodePath -Argument "`"$WatcherScript`""
    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration ([TimeSpan]::MaxValue)
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Description "Retoma sessoes do Claude Code interrompidas por rate limit/erro" | Out-Null
    Write-Output "watcher agendado registrado: tarefa '$TaskName' a cada 15min"
} else {
    Write-Output "watcher compartilhado ja presente (tarefa '$TaskName'), nao recriado"
}

# 2. copia queue.js (hook de enfileiramento) e state.js pro alvo
Copy-Item -Path (Join-Path $CoreDir "queue.js") -Destination (Join-Path $Target "hooks\continuidade\queue.js") -Force
Copy-Item -Path (Join-Path $CoreDir "state.js") -Destination (Join-Path $Target "hooks\continuidade\state.js") -Force
Copy-Item -Path (Join-Path $CoreDir "lib") -Destination (Join-Path $Target "hooks\continuidade") -Recurse -Force

# 3. mescla o hook StopFailure no settings.json do alvo
$SettingsPath = Join-Path $Target "settings.json"
$QueueScriptPath = Join-Path $Target "hooks\continuidade\queue.js"
$QueueCmd = "node `"$QueueScriptPath`""
$MergeScript = Join-Path $CoreDir "lib\merge-settings.js"
node $MergeScript $SettingsPath "StopFailure" "" $QueueCmd 10

# 4. copia os skills de pausar/continuar
Copy-Item -Path (Join-Path $ScriptDir "skills\pausar-trabalho") -Destination (Join-Path $Target "skills\pausar-trabalho") -Recurse -Force
Copy-Item -Path (Join-Path $ScriptDir "skills\continuar-trabalho") -Destination (Join-Path $Target "skills\continuar-trabalho") -Recurse -Force

Write-Output "instalado em $Target`:"
Write-Output "  - hook StopFailure -> $QueueScriptPath"
Write-Output "  - skills /pausar-trabalho e /continuar-trabalho"
Write-Output "  - watcher compartilhado em $(Join-Path $WatcherBinDir 'watcher.js')"
```

- [ ] **Step 2: Commit**

```bash
git add claude/continuidade/install.ps1
git commit -m "feat: adiciona install.ps1 — instalador Windows (nao validado por execucao real)"
```

---

### Task 11: `README.md` de `claude/continuidade/`

**Files:**
- Create: `claude/continuidade/README.md`

**Interfaces:**
- Consumes: nada (documentação).
- Produces: nada.

- [ ] **Step 1: Criar `claude/continuidade/README.md`**

```markdown
# Continuidade de trabalho

Mecanismo de continuidade multi-perfil pro Claude Code (e, na parte manual,
também pro Antigravity): retomada automática de sessão após rate
limit/erro/crash, mais um par de comandos próprios (`/pausar-trabalho` e
`/continuar-trabalho`) pra pausar e continuar deliberadamente.

Design completo em
`docs/superpowers/specs/2026-07-10-continuidade-multi-perfil-design.md`.

## Instalar

Para cada perfil de config que você usa (`~/.claude`, `~/.claude-work`, ou
qualquer outro `CLAUDE_CONFIG_DIR`):

```bash
# Mac/Linux
bash claude/continuidade/install.sh --target ~/.claude
bash claude/continuidade/install.sh --target ~/.claude-work

# Windows (PowerShell) — checklist de validação abaixo, ainda não testado numa máquina real
powershell -File claude\continuidade\install.ps1 -Target $HOME\.claude
```

Cada execução instala, no perfil indicado: o hook `StopFailure` (aponta pra
`queue.js`), os skills `/pausar-trabalho` e `/continuar-trabalho`, e garante
— uma única vez por máquina, não por perfil — o watcher compartilhado e seu
agendador (a cada 15min).

Do lado Antigravity, os dois comandos manuais seguem o mesmo caminho já
documentado no README principal do repositório pro resto das personas:

```bash
cp -R gemini/skills/pausar-trabalho gemini/skills/continuar-trabalho /caminho/do/projeto/.agents/skills/
```

## Rodar de novo (atualizar)

Rodar `install.sh`/`install.ps1` de novo no mesmo `--target` é seguro —
idempotente, não duplica hook nem agendador.

## Checklist de verificação — Windows

Pendente de validação numa máquina/VM Windows real (não testável nesta
sessão de desenvolvimento):

1. `powershell -File claude\continuidade\install.ps1 -Target $HOME\.claude`
   roda sem erro.
2. `Get-ScheduledTask -TaskName "AgentesPipelineContinuidadeWatcher"` mostra
   a tarefa registrada.
3. Fila é criada em `%USERPROFILE%\.claude-resume-queue`.
4. `%USERPROFILE%\.claude\hooks\continuidade\queue.js` existe, e
   `%USERPROFILE%\.claude\settings.json` tem o hook `StopFailure` apontando
   pra ele.
5. Simular um item na fila (JSON de teste com `cwd`/`session_id` válidos) e
   confirmar que a tarefa agendada tenta retomar dentro de 15min.
6. Rodar o instalador de novo no mesmo `--target` e confirmar que não
   duplica a tarefa agendada nem o hook.

## Fora de escopo desta versão

- Watcher automático de rate-limit/crash no Antigravity — investigado e
  documentado em
  `docs/superpowers/specs/2026-07-10-antigravity-hooks-investigacao.md`.
- Histórico de múltiplas pausas por projeto — `/pausar-trabalho` sobrescreve
  a pausa anterior daquele diretório, não empilha.
```

- [ ] **Step 2: Commit**

```bash
git add claude/continuidade/README.md
git commit -m "docs: adiciona README de claude/continuidade com instrucoes de instalacao e checklist Windows"
```

---

### Task 12: Rollout local — substituir o setup manual do Bruno pelo versionado

**Files:**
- Modify (máquina real, fora do repositório): `~/.claude/hooks/`, `~/.claude/settings.json`, `~/.claude-work/hooks/`, `~/.claude-work/settings.json`, `~/Library/LaunchAgents/com.brunoandrade.claude-resume-watcher.plist`, `~/.claude-resume-queue/`.

**Interfaces:**
- Consumes: `claude/continuidade/install.sh` (Task 9).
- Produces: nada (é a entrega final ao usuário, não uma dependência de outra task).

Esta é a única task que toca a máquina real do Bruno — todas as anteriores
usam fixtures isoladas. Antes de rodar, confirme com o usuário (já
autorizado no início desta conversa: "primeiro faça no meu local"), e
proceda com cautela: fazer backup antes de remover qualquer coisa.

- [ ] **Step 1: Backup do setup manual antigo**

```bash
mkdir -p ~/.claude-continuidade-backup-manual
cp ~/.claude/hooks/queue-rate-limit-resume.sh ~/.claude-continuidade-backup-manual/ 2>/dev/null || true
cp ~/.claude/hooks/resume-watcher.sh ~/.claude-continuidade-backup-manual/ 2>/dev/null || true
cp ~/.claude-work/hooks/queue-rate-limit-resume.sh ~/.claude-continuidade-backup-manual/queue-rate-limit-resume-claude-work.sh 2>/dev/null || true
cp ~/Library/LaunchAgents/com.brunoandrade.claude-resume-watcher.plist ~/.claude-continuidade-backup-manual/ 2>/dev/null || true
```

- [ ] **Step 2: Descarregar o launchd antigo**

```bash
launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.brunoandrade.claude-resume-watcher.plist 2>/dev/null || \
  launchctl unload ~/Library/LaunchAgents/com.brunoandrade.claude-resume-watcher.plist 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.brunoandrade.claude-resume-watcher.plist
```

- [ ] **Step 3: Rodar o instalador nos dois perfis**

```bash
cd ~/agentes-pipeline
bash claude/continuidade/install.sh --target ~/.claude
bash claude/continuidade/install.sh --target ~/.claude-work
```

- [ ] **Step 4: Remover os scripts manuais antigos (já com backup feito no Step 1)**

```bash
rm -f ~/.claude/hooks/queue-rate-limit-resume.sh ~/.claude/hooks/resume-watcher.sh
rm -f ~/.claude-work/hooks/queue-rate-limit-resume.sh
```

- [ ] **Step 5: Verificar o resultado**

```bash
echo "--- launchd novo ---"
launchctl list | grep continuidade-watcher
echo "--- plist novo ---"
ls -la ~/Library/LaunchAgents/com.agentes-pipeline.continuidade-watcher.plist
echo "--- hooks StopFailure nos dois perfis ---"
grep -A2 'StopFailure' ~/.claude/settings.json
grep -A2 'StopFailure' ~/.claude-work/settings.json
echo "--- skills instalados ---"
ls ~/.claude/skills/pausar-trabalho ~/.claude/skills/continuar-trabalho
ls ~/.claude-work/skills/pausar-trabalho ~/.claude-work/skills/continuar-trabalho
```

Expected: o launchd novo aparece na lista, o plist antigo (`com.brunoandrade...`) não existe mais, os dois `settings.json` têm o hook `StopFailure` apontando pra `continuidade/queue.js`, e os 4 diretórios de skills existem.

- [ ] **Step 6: Teste funcional de ponta a ponta em um projeto de teste**

```bash
mkdir -p /tmp/projeto-teste-continuidade
cd /tmp/projeto-teste-continuidade
git init -q
```

Dentro de uma sessão real do Claude Code nesse diretório: rode
`/pausar-trabalho` com algum contexto de exemplo, confirme a mensagem de
sucesso, abra uma sessão nova (ou simule) e rode `/continuar-trabalho` —
confirme que o resumo salvo aparece corretamente. Repita copiando os skills
de `gemini/skills/` pra `/tmp/projeto-teste-continuidade/.agents/skills/` e
teste o mesmo par de comandos pelo lado Antigravity, incluindo pausar num
lado e continuar no outro.

- [ ] **Step 7: Commit (apenas o que ficou registrado no repositório, se algo mudou durante o teste)**

Nenhum arquivo do repositório `agentes-pipeline` muda nesta task — ela só
afeta `~/.claude`, `~/.claude-work` e o `launchd` da máquina do Bruno.
Não há commit aqui.

---

## Self-Review

**Cobertura da spec:** núcleo Node (`queue.js`/`watcher.js`/`decide.js`/`queue-store.js`) → Tasks 1–4; comandos manuais próprios (`state.js` + SKILL.md) → Tasks 5, 7; lado Antigravity manual → Task 8; instaladores Mac e Windows → Tasks 9–10; merge idempotente de hooks → Task 6; README com checklist Windows → Task 11; rollout real substituindo o setup manual → Task 12. Todos os pontos do design em `2026-07-10-continuidade-multi-perfil-design.md` têm uma task correspondente.

**Placeholders:** nenhum "TBD"/"implementar depois" — todo step tem código completo ou comando exato com saída esperada.

**Consistência de tipos/assinaturas:** `writeItem`/`listItems`/`readItem`/`moveToStale`/`removeItem` (Task 1) são usados com os mesmos nomes em `queue.js` (Task 3) e `watcher.js` (Task 4). `decideAction`/`MAX_AGE_MS` (Task 2) usados com os mesmos nomes em `watcher.js` (Task 4). `save`/`load`/`stateFile`/`stateDir` (Task 5) usados com os mesmos nomes nos SKILL.md das Tasks 7 e 8 (via CLI, não import direto — os nomes dos parâmetros `--config-dir`/`--cwd`/`--session-id` batem entre a implementação do CLI e as instruções dos SKILL.md). `mergeHook`/`mergeSettingsFile` (Task 6) usados via CLI em `install.sh` (Task 9) e `install.ps1` (Task 10) com a mesma ordem de argumentos posicionais (`filePath eventName matcher command timeout`).
