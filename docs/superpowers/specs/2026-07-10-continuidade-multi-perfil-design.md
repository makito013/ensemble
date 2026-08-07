# Continuidade de trabalho multi-perfil (auto-resume + pausar/continuar)

Data: 2026-07-10
Repositório: `agentes-pipeline`

## Problema

O Bruno já tinha montado, à mão, um mecanismo de auto-retomada de sessão após
rate limit (`~/.claude/hooks/queue-rate-limit-resume.sh` +
`~/.claude/hooks/resume-watcher.sh` + um `launchd` rodando a cada 15min) para
o perfil padrão `~/.claude`. A ideia era ter o mesmo comportamento também no
perfil `~/.claude-work` (um segundo `CLAUDE_CONFIG_DIR`, usado via variável de
ambiente). Investigando os dois perfis, o hook e o script de enfileiramento
já estavam de fato espelhados e funcionando nos dois (validado manualmente
nesta sessão) — mas:

1. O watcher físico só existe dentro de `~/.claude/hooks/`, então some se
   esse perfil for reinstalado — não é um design deliberado, é uma
   fragilidade.
2. O mecanismo só cobre rate limit. Crash ou erro de API não são cobertos.
3. Não existe nenhuma forma de "pausar e continuar depois" deliberada,
   controlada pelo próprio usuário (via terminal) — só o retry automático.
4. Tudo isso foi montado manualmente, sem versionamento — se o Bruno
   configurar um terceiro perfil (ou reinstalar o Claude Code do zero numa
   máquina nova), tem que recriar tudo de memória.

O pedido é trazer esse mecanismo para dentro do `agentes-pipeline` (que já é
a fonte-da-verdade portátil do resto do pipeline de agentes) como algo
instalável — parametrizado por qual pasta de config (`~/.claude`,
`~/.claude-work`, ou qualquer outro `CLAUDE_CONFIG_DIR`) — e cross-platform
(Mac e Windows).

## Mudança

Novo diretório `claude/continuidade/` no repositório, irmão de
`claude/skills/` (mesmo espírito: tooling pessoal do Claude Code, não
instalado dentro de projetos de terceiros).

```
claude/continuidade/
├── core/
│   ├── queue.js      # enfileira uma sessão interrompida (chamado pelo hook StopFailure)
│   └── watcher.js    # varre a fila e tenta retomar via `claude -r`
├── skills/
│   ├── pausar-trabalho/SKILL.md
│   └── continuar-trabalho/SKILL.md
├── install.sh        # instalador Mac/Linux
├── install.ps1        # instalador Windows
└── README.md

gemini/skills/
├── pausar-trabalho/SKILL.md      # mesmo conteúdo conceitual do lado claude/
└── continuar-trabalho/SKILL.md
```

### 1. Núcleo (`core/`) — Node.js, cross-platform

`queue.js` e `watcher.js` substituem os `.sh` atuais, reescritos em Node (o
Claude Code já depende de Node; vários hooks do próprio Bruno em
`~/.claude/hooks` já são `.js`). Mesma lógica de hoje:

- `queue.js` lê o JSON que o hook `StopFailure` manda por stdin (`cwd`,
  `session_id`, etc.), acrescenta `config_dir` (de `CLAUDE_CONFIG_DIR`,
  default pro caminho do perfil padrão) e `queued_at`, grava em
  `~/.claude-resume-queue/<timestamp>-<pid>.json`.
- `watcher.js` varre essa fila, pula entradas com `cwd` inexistente ou mais
  de 48h (move pra `stale/`), e tenta
  `claude -r <session_id> -p "<prompt de retomada>" --permission-mode acceptEdits`
  com o `CLAUDE_CONFIG_DIR` correto. Sucesso remove da fila; falha (ainda
  bloqueado) mantém.

**Mudança de comportamento:** o matcher do hook deixa de ser só `rate_limit`
e passa a capturar qualquer `StopFailure` (sem matcher específico, ou
`.*`) — isso já cobre rate limit, erro de API e crash, sem precisar
enumerar motivos específicos. Saída intencional (`Ctrl+C`, `/exit`) dispara o
evento `Stop`, não `StopFailure`, então já fica de fora automaticamente —
não precisa de lógica extra pra distinguir intencional de não-intencional.

A fila e o watcher continuam **únicos por máquina** (não um por perfil),
porque cada item já carrega o `config_dir` de onde veio. A diferença em
relação ao setup manual atual: o watcher passa a morar num local neutro
(`~/.claude-resume-queue/bin/watcher.js`, copiado lá pelo instalador) em vez
de dentro de `~/.claude/hooks/` — deixa de depender da existência de um
perfil específico.

### 2. Pausar/continuar manual (`skills/`)

Dois skills novos, instalados no(s) perfil(is) escolhido(s):

- **`/pausar-trabalho`**: grava um arquivo de estado em
  `<config_dir>/continuidade/state/<hash-do-cwd>.md` com um resumo do que
  está em andamento (tarefa atual, próximos passos, arquivos tocados),
  `session_id` e `cwd`. Sobrescreve o state file existente daquele projeto
  (um por `cwd`, não uma pilha de pausas).
- **`/continuar-trabalho`**: procura o state file do `cwd` atual, mostra o
  resumo pro usuário e retoma a partir dali. Funciona tanto numa sessão nova
  do mesmo terminal quanto em outra sessão/perfil, desde que aponte pro mesmo
  projeto.

Esses dois comandos são a versão "própria" (não depende do plugin GSD) do
mesmo conceito de handoff de contexto do `gsd-pause-work`/`gsd-resume-work`.

### 3. Lado Antigravity (`gemini/skills/`) — só a parte manual

`/pausar-trabalho` e `/continuar-trabalho` não dependem de nenhum hook — só
leem/escrevem o arquivo de estado — então são publicados também pro lado
Antigravity, em `gemini/skills/pausar-trabalho/SKILL.md` e
`gemini/skills/continuar-trabalho/SKILL.md`, no mesmo formato das outras 11
personas já espelhadas nessa pasta.

**Diferença importante em relação ao lado Claude:** o Antigravity não tem um
diretório de skills por-máquina (`~/.gemini/commands` e `~/.gemini/agents`
existem mas estão vazios nesta máquina — a descoberta de skills lá é
por-projeto, em `.agents/skills/`, igual às outras 11 personas). Então esses
dois skills **não** passam pelo `install.sh --target`/`install.ps1` (esse
mecanismo é só pro lado Claude Code, por-perfil) — seguem o mesmo caminho já
documentado no README pro resto do Antigravity: `cp -R` ou symlink de
`gemini/skills/` para dentro de `.agents/skills/` de cada projeto.

Como não há um `CLAUDE_CONFIG_DIR` equivalente confirmado pro Antigravity
(nenhuma evidência de múltiplos perfis, diferente do `.claude`/`.claude-work`
do Bruno), o arquivo de estado do lado Antigravity fica em local fixo:
`~/.gemini/continuidade/state/<hash-do-cwd>.md` — mesma chave (`cwd`) do lado
Claude, então uma pausa feita no Claude Code pode ser continuada no
Antigravity (e vice-versa), desde que seja o mesmo projeto e a mesma máquina.

O watcher automático de rate-limit/crash **não** é estendido pro Antigravity
nesta entrega — ver detalhes e o que ficou pendente de investigação em
[`2026-07-10-antigravity-hooks-investigacao.md`](2026-07-10-antigravity-hooks-investigacao.md).

### 4. Instaladores (`install.sh` / `install.ps1`)

Uso: `bash claude/continuidade/install.sh --target ~/.claude-work` (ou
`powershell -File claude\continuidade\install.ps1 -Target $HOME\.claude-work`
no Windows).

Cada execução, para o `--target` passado:

1. Garante que a instalação **compartilhada** existe e está atualizada:
   copia `core/watcher.js` (e o node runtime necessário) para
   `~/.claude-resume-queue/bin/`, e registra o agendador do SO **uma única
   vez por máquina** (checa se já existe antes de recriar — idempotente):
   - Mac: `launchd` (`~/Library/LaunchAgents/com.agentes-pipeline.continuidade-watcher.plist`,
     `StartInterval` 900s).
   - Windows: Scheduled Task via `Register-ScheduledTask`/`schtasks`, mesmo
     intervalo, com o caminho do `node.exe` e do `claude` resolvidos
     explicitamente (não confia em `PATH` da Task Scheduler).
2. Copia `core/queue.js` para `<target>/hooks/`.
3. Mescla no `<target>/settings.json` a entrada do hook `StopFailure`
   apontando pro `queue.js` copiado — merge aditivo (não sobrescreve hooks
   de outros plugins) e idempotente (rodar de novo não duplica a entrada).
4. Copia `skills/pausar-trabalho/` e `skills/continuar-trabalho/` para
   `<target>/skills/` (cria a pasta se não existir).
5. Imprime um resumo do que foi instalado/atualizado.

Diferença Mac vs. Windows fica só no passo 1 (registro do agendador) — o
resto (cópia de arquivo, merge de JSON) é o mesmo script Node chamado pelos
dois instaladores, cada um só resolvendo o `--target`/`-Target` e invocando
esse script comum.

### 5. Rollout local

Depois de construído, o próprio Bruno roda:

```bash
bash claude/continuidade/install.sh --target ~/.claude
bash claude/continuidade/install.sh --target ~/.claude-work
```

Isso substitui o setup manual atual (os `.sh` velhos em
`~/.claude/hooks/queue-rate-limit-resume.sh` e
`~/.claude/hooks/resume-watcher.sh`, e o `launchd` antigo apontando pra lá)
pela versão versionada. Os arquivos antigos são removidos e o `launchd`
antigo é descarregado (`launchctl bootout`) antes de registrar o novo, para
não ficar com dois watchers rodando ao mesmo tempo.

## Fora de escopo

- **Watcher automático (rate-limit/crash) no Antigravity.** Investigado
  empiricamente nesta sessão (não só "sem documentação"): configurei hooks de
  teste em `Stop`, `SessionEnd`, `AfterAgent`, `PostInvocation` e
  `Notification`, reiniciei o daemon do `agy` pra garantir que não era cache
  de config, e nenhum disparou — nem mesmo um `AfterTool` de teste com
  matcher curinga, que é um evento **já usado em produção** nesta máquina.
  Foi nessa investigação que descobri que o hook `AfterTool` já configurado
  (`gsd-graphify-update.sh`) aponta pra um arquivo que não existe — ou seja,
  a integração de hooks do Antigravity já estava quebrada antes desta
  entrega, não é uma regressão causada por ela. Detalhes completos e um
  checklist de teste manual em
  [`2026-07-10-antigravity-hooks-investigacao.md`](2026-07-10-antigravity-hooks-investigacao.md).
  A estrutura (`core/` desacoplado de `<target>/hooks/`) fica pronta pra
  estender no futuro, se/quando o gancho certo for confirmado.
- Testar a execução real no Windows — sem máquina Windows disponível nesta
  sessão. `install.ps1` é escrito com cuidado e um checklist de verificação
  pós-instalação fica documentado no `README.md`, mas fica pendente de
  validação pelo Bruno numa máquina real.
- Histórico de múltiplas pausas por projeto (`/pausar-trabalho` sobrescreve,
  não empilha) — se precisar no futuro, é extensão incremental.
- Migrar o mecanismo de fila/watcher pra dentro do próprio Claude Code (ex:
  virar um plugin de marketplace) — cogitado e descartado por
  desproporcional ao problema atual, mesmo raciocínio já usado pro
  `init-project` no spec de onboarding.

## Teste manual

**Mac (validável agora):**
1. Rodar `install.sh --target ~/.claude` e `install.sh --target ~/.claude-work`;
   conferir hooks mesclados nos dois `settings.json`, `queue.js` copiado nos
   dois, watcher único em `~/.claude-resume-queue/bin/`, launchd registrado
   uma vez só.
2. Rodar `install.sh` de novo nos dois — conferir que não duplica hook nem
   plist (idempotência).
3. Simular enfileiramento (JSON fake via stdin) pros dois `config_dir` e
   conferir que os itens caem certos na fila.
4. Simular o watcher processando um item com `cwd` inexistente → vai pra
   `stale/`.
5. Testar `/pausar-trabalho` e `/continuar-trabalho` num projeto de teste:
   pausar, simular sessão nova, continuar, conferir que o resumo bate.
6. `cp -R gemini/skills/pausar-trabalho gemini/skills/continuar-trabalho <projeto-de-teste>/.agents/skills/`
   e testar o mesmo par de comandos pelo lado Antigravity, no mesmo projeto
   de teste, incluindo pausar num lado (Claude) e continuar no outro
   (Antigravity).

**Windows (checklist para o Bruno validar depois, não testável nesta sessão):**
1. Rodar `install.ps1 -Target $HOME\.claude` numa máquina/VM Windows.
2. `Get-ScheduledTask -TaskName "*continuidade*"` mostra a tarefa registrada.
3. Fila criada em `%USERPROFILE%\.claude-resume-queue`.
4. Repetir a simulação de enfileiramento/retomada do lado Mac.
