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

### Limitações por plataforma

- **macOS**: `install.sh` registra o watcher automaticamente via launchd (executa a cada 15min). ✓
- **Windows**: `install.ps1` registra o watcher automaticamente via Tarefa Agendada. ✓ (pendente validação em máquina real)
- **Linux**: `install.sh` copia os arquivos do watcher mas NÃO registra nenhum agendador automático (cron, systemd timer, etc.). O watcher seria acionado manualmente ou via uma tarefa cron que o usuário configurar. Este é um comportamento intencional — a ferramenta tem como alvo Mac e Windows; Linux não é um alvo real nesta versão.

## Como o watcher decide

A cada execução, o watcher percorre `~/.claude-resume-queue/*.json`:

- **Item corrompido** (JSON inválido ou que não é objeto) vai para `stale/`
  e os demais itens seguem sendo processados — um arquivo ruim nunca trava a
  fila.
- **Itens da mesma sessão** (`session_id`) viram uma única retomada: fica o
  item mais recente, com o maior contador de tentativas; os outros são
  descartados como `duplicate`.
- **Resultado da retomada**: roda `claude -r <sessão> -p ... --output-format json`.
  Sucesso = exit code 0 sem `is_error: true` no JSON de resultado — o texto
  produzido pela sessão retomada nunca é usado para decidir sucesso (ela
  pode falar de "rate limit" no próprio trabalho). Em falha, o motivo é
  `rate-limit` se o resultado JSON (ou, sem JSON, as últimas 20 linhas da
  saída) casar com a mensagem de limite; senão `error`.
- **Timeout**: cada retomada é encerrada após
  `CLAUDE_CONTINUIDADE_TIMEOUT_MS` (padrão 30 min) e conta como falha.
- **Limite de tentativas**: falhas `error`/`timeout` incrementam `attempts`
  no item; ao atingir `CLAUDE_CONTINUIDADE_MAX_ATTEMPTS` (padrão 5) o item
  vai para `stale/`. Falhas `rate-limit` não contam (um limite pode durar
  horas) — elas continuam limitadas pela idade máxima de 48h.

`/continuar-trabalho` limpa o checkpoint (`state.js clear`) depois de
retomar com sucesso, e `/pausar-trabalho` avisa quando sobrescreve uma pausa
anterior do mesmo diretório.

## Rodar de novo (atualizar)

Rodar `install.sh`/`install.ps1` de novo no mesmo `--target` é seguro —
idempotente, não duplica hook nem agendador.

## Checklist de verificação — Windows

Pendente de validação numa máquina/VM Windows real (não testável nesta
sessão de desenvolvimento):

**⚠️ PRIORIDADE (validar primeiro):** Após executar o instalador, inspecionar
manualmente `%USERPROFILE%\.claude\settings.json` e confirmar que o hook
`StopFailure` está configurado corretamente:
- `matcher` deve estar AUSENTE ou vazio (isto é correto — significa que o hook
  captura qualquer razão de `StopFailure`, não apenas `rate_limit`)
- `command` deve conter a string de invocação real: `node ".../queue.js"` com
  argumentos apropriados
- `timeout` deve ser `10`

(Se em vez disso você vir `matcher` preenchido com o que parece a string do
comando queue, ou `command` com apenas `"10"`, isso indica que o workaround do
PowerShell 5.1 falhou apesar da correção — será o sinal da mudança de
argumentos ter ocorrido.)

Itens de checklist completo:

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
