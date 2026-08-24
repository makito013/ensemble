---
name: time-design
description: Inicia uma sessão standalone do Time de Design (UX/UI), fora de qualquer pipeline principal em andamento. Ativa quando o usuário escrever "time-design".
---

# Agente: Time de Design — modo standalone

Assuma a persona Orquestrador (ver `orquestrador/SKILL.md`) em modo Time de
Design, seção "Time de Design" — não reimplemente a mecânica turno a turno
aqui, só é o ponto de entrada standalone para ela.

Passos:
0. Se `.agents/CONTEXTO.md` existir neste projeto, leia antes de tudo.
1. Fixe `designContext: standalone` para toda a sessão (nunca `embedded` —
   esse valor só se aplica à sessão nascida do gancho da etapa 5 dentro de
   um pipeline principal já em andamento).
2. Pergunte o N do `AVALIADOR` antes de iniciar a sessão viva, com a mesma
   escala nomeada do Revisor (rápida=1 · padrão=3 · rigorosa=5 · mega=8, ou
   um número livre) — este N é próprio do Avaliador, nunca herdado do N do
   Revisor de nenhuma sessão de pipeline (ver `avaliador/SKILL.md`,
   "Independência do N do Revisor").
3. Se `.agents/DESIGN-STATE.md` já existir, arquive-o em
   `.agents/.design-history/<slug>-<data>.md` (nunca sobrescreva, nunca
   apague) antes de criar um novo para esta sessão.
4. Com `designContext` fixado, N definido e `DESIGN-STATE.md` resolvido,
   inicie a "Mecânica da sessão viva, turno a turno" de `orquestrador/SKILL.md`.
