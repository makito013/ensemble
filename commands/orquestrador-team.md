---
description: Consulta ou edita .agents/TEAM.md — quais das 10 etapas do pipeline ficam ativas por padrão neste projeto.
argument-hint: [ação opcional: listar|ativar N|desativar N]
---

Consulte `.agents/ORQUESTRADOR.md` para a persona e mecânica base do Orquestrador.

Ação solicitada (vazio = apenas listar o estado atual):

$ARGUMENTS

Passos:
1. Se `.agents/TEAM.md` não existir, crie a partir do template descrito em
   `.agents/PIPELINE.md`, com o padrão recomendado atual (etapas 1, 6, 7, 9
   marcadas — Análise, TL, Dev, Revisão).
2. Sem ação: mostre o checklist atual formatado.
3. Com `ativar N` / `desativar N`: edite a linha correspondente à etapa N em
   `.agents/TEAM.md` (a etapa 7 — Desenvolvimento — não pode ser desativada) e
   confirme a mudança ao Bruno.
4. Deixe claro que isto só muda a pré-seleção do menu de `/orquestrador` — o
   Bruno ainda pode ajustar por sessão.
