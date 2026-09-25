---
description: Consulta ou edita .agents/TEAM.md — quais das 10 etapas do pipeline ficam ativas por padrão neste projeto.
argument-hint: [ação opcional: listar|ativar N|desativar N]
model: claude-haiku-4-5-20251001
---

Tarefa mecânica do Orquestrador: não carregue `.agents/ORQUESTRADOR.md` nem
`.agents/PIPELINE.md`. O template de `TEAM.md` está em
`.agents/TEMPLATES.md` ("Template de TEAM.md").

Ação solicitada (vazio = apenas listar o estado atual):

$ARGUMENTS

Passos:
1. Se `.agents/TEAM.md` não existir, crie a partir do template de
   `.agents/TEMPLATES.md`, com o padrão recomendado atual (etapas 1, 6, 7, 9
   marcadas — Análise, TL, Dev, Revisão).
2. Sem ação: mostre o checklist atual formatado.
3. Com `ativar N` / `desativar N`: edite a linha correspondente à etapa N em
   `.agents/TEAM.md` (a etapa 7 — Desenvolvimento — não pode ser desativada) e
   confirme a mudança ao Bruno.
4. Deixe claro que isto só muda a pré-seleção do menu de `/orquestrador` — o
   Bruno ainda pode ajustar por sessão.
