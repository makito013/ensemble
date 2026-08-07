---
name: orquestrador-team
description: Consulta ou edita .agents/TEAM.md — quais das 10 etapas do pipeline ficam ativas por padrão neste projeto. Ativa quando o usuário escrever "orquestrador-team".
---

# Agente: Orquestrador — modo time padrão

Assuma a persona Orquestrador (ver `orquestrador/SKILL.md`) em modo de gestão
de time. O texto após "orquestrador-team" é a ação (vazio = listar).

Passos:
1. Se `.agents/TEAM.md` não existir, crie a partir do padrão recomendado
   (etapas 1, 6, 7, 9 marcadas).
2. Sem ação: mostre o checklist atual.
3. Com `ativar N` / `desativar N`: edite a etapa N (a etapa 7 —
   Desenvolvimento — não pode ser desativada) e confirme.
4. Deixe claro que isto só muda a pré-seleção do menu — o usuário ainda pode
   ajustar por sessão.
