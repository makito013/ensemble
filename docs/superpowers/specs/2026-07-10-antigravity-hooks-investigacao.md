# Investigação: hooks de encerramento de sessão no Antigravity CLI (`agy`)

Data: 2026-07-10
Repositório: `agentes-pipeline`
Relacionado: [`2026-07-10-continuidade-multi-perfil-design.md`](2026-07-10-continuidade-multi-perfil-design.md)

## Motivação

O design de continuidade multi-perfil (spec relacionada acima) previa
estender o watcher automático de rate-limit/crash também pro Antigravity,
desde que existisse um hook equivalente ao `StopFailure` do Claude Code. Este
documento registra a investigação feita pra confirmar isso, o resultado
(inconclusivo/negativo) e o que ficou pendente de teste manual.

## O que já é sabido (documentação pública)

Buscando na documentação e em artigos sobre o Antigravity CLI (`agy`,
versão instalada: 1.0.16), a lista de hooks foi consolidada em eventos
como `PreToolUse`/`PostToolUse` (ou `BeforeTool`/`AfterTool`, nomes usados
de fato no `settings.json` local), `PreInvocation`/`PostInvocation`, e um
evento de encerramento de sessão citado ora como `Stop`, ora como
`SessionEnd` dependendo da fonte — a documentação não deixa claro qual o
nome correto, nem se esse evento chega diferenciando o motivo do
encerramento (sucesso, rate limit, erro de API, crash). Os hooks recebem o
payload por stdin em JSON, com campos como `session_id`, `cwd`,
`transcript_path` e `hook_event_name` — mesmo padrão do Claude Code.

## O que foi testado nesta sessão

1. Adicionei hooks temporários de log (append de stdin cru num arquivo) nos
   nomes de evento candidatos: `Stop`, `SessionEnd`, `AfterAgent`,
   `PostInvocation`, `Notification`.
2. Rodei `agy -p "responda apenas: oi"` (headless) — nenhum hook disparou.
3. Rodei `agy` com prompt via stdin não-interativo pedindo execução de um
   comando de shell — nenhum hook disparou, nem os de teste nem o
   `AfterTool` (evento que já está configurado em produção nesta máquina,
   usado pelo GSD/graphify).
4. Suspeitei de cache de config num daemon de fundo (`antigravity`, rodando
   havia dias, escutando em portas locais — mesmo padrão de daemon que o
   Claude Code também usa). Matei esse processo (processo isolado do
   Antigravity IDE — o IDE continuou rodando normalmente, só o daemon do
   CLI foi reiniciado) e repeti o teste.
5. Mesmo com o daemon fresco, nenhum hook dos testados disparou.
6. Ao investigar por que nem o `AfterTool` (produção) disparava, descobri
   que o hook aponta pra `~/.gemini/hooks/gsd-graphify-update.sh` —
   **arquivo que não existe** nesta máquina. Essa integração específica já
   estava quebrada antes desta investigação (não foi causada por ela).

## Conclusão

Não dá pra afirmar que o Antigravity não tem um hook de encerramento de
sessão equivalente ao `StopFailure` — só que **não consegui confirmar que
tem**, com as ferramentas de teste headless disponíveis nesta sessão. Como
nem um hook já configurado em produção (`AfterTool`) disparou nos meus
testes (por causa do arquivo faltante), a ausência de disparo dos hooks de
teste pode ter mais de uma causa:

- Os nomes de evento testados estão errados (a doc pública é inconsistente
  sobre o nome certo).
- Hooks só disparam numa sessão **interativa de verdade** (TTY real), não
  em modo `--print` nem com stdin via pipe — os dois modos que dá pra
  automatizar de dentro desta sessão de terminal.
- Alguma outra causa não identificada.

Por isso o watcher automático pro Antigravity ficou fora de escopo da
entrega atual — não é uma decisão de "não dá pra fazer", é "não dá pra
fazer com confiança sem mais investigação".

## O que você pode testar manualmente (requer sessão interativa real)

Isso não dá pra automatizar de dentro de uma sessão de terminal como a
minha — precisa de um terminal interativo de verdade, com você
digitando/observando.

1. **Editar `~/.gemini/settings.json`** e adicionar, dentro de `"hooks"`:
   ```json
   "Stop": [
     { "hooks": [ { "type": "command", "command": "bash -c 'cat >> /tmp/agy-stop-test.log; echo --- >> /tmp/agy-stop-test.log'" } ] }
   ],
   "SessionEnd": [
     { "hooks": [ { "type": "command", "command": "bash -c 'cat >> /tmp/agy-stop-test.log; echo --- >> /tmp/agy-stop-test.log'" } ] }
   ]
   ```
   (faça backup do arquivo antes, com `cp ~/.gemini/settings.json ~/.gemini/settings.json.bak`).
2. Abra um `agy` **interativo** (sem `-p`, sem pipe de stdin) num terminal
   de verdade.
3. Mande um prompt qualquer, deixe terminar naturalmente, e saia com
   `/exit` (ou o comando de saída do Antigravity). Confira
   `/tmp/agy-stop-test.log` — se algo apareceu, os nomes `Stop`/`SessionEnd`
   estão certos e valem em sessão interativa.
4. Repita, mas desta vez interrompa a sessão no meio de uma resposta com
   `Ctrl+C`. Confira se o log registra algo diferente (ex: um campo
   indicando interrupção).
5. Se quiser ir além: force um erro real (ex: `--model` com um nome de
   modelo inválido) pra ver se aparece alguma coisa que pareça um motivo de
   falha (evite forçar rate limit de propósito — pode custar cota real).
6. Restaure o backup do `settings.json` no final:
   `cp ~/.gemini/settings.json.bak ~/.gemini/settings.json`.
7. Independente do resultado do teste de hook: vale abrir uma issue/reportar
   pro time do Antigravity (ou conferir se é um bug conhecido) que o hook
   `AfterTool` → `gsd-graphify-update.sh` está apontando pra um arquivo
   inexistente — é um problema real, préexistente, que quebra silenciosamente
   a integração GSD/graphify do lado Antigravity.

Se esse teste confirmar um hook funcional com distinção de motivo de
encerramento, é só voltar nesta spec e no design principal pra desenhar a
extensão do watcher automático pro Antigravity — a estrutura de `core/` já
fica pronta pra isso (só falta o adaptador de invocação, análogo ao
`claude -r <id> -p` mas usando `agy --conversation <id> --print`, que já
confirmei que existe).
