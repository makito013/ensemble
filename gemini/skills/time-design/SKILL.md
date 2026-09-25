---
name: time-design
description: Inicia uma sessão standalone do Time de Design (UX/UI), fora de qualquer pipeline principal em andamento. Gatilho sempre manual: só ativa quando a mensagem do usuário começa com o prefixo explícito "time-design:" (sozinho ou seguido do pedido). Nunca ativa sozinho por inferência de contexto, mesmo que o pedido pareça se encaixar.
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
2. Resolva o modo e o N pelo texto do pedido: se ele começar com
   `surpreenda` (ou "me surpreenda") ou `padrão`, isso fixa o modo; um
   número logo depois fixa o N; o resto é o pedido (ex.: `time-design:
   surpreenda 4 landing page do produto X`). Pergunte só o que faltar,
   numa pergunta só:
   - **Modo** — `padrão | me surpreenda` (ver "Modo Me Surpreenda" em
     `orquestrador/SKILL.md`).
   - **N no modo padrão** — N do `AVALIADOR`, na mesma escala nomeada do
     Revisor (rápida=1 · padrão=3 · rigorosa=5 · mega=8, ou um número
     livre) — próprio do Avaliador, nunca herdado do N do Revisor de
     nenhuma sessão de pipeline (ver `avaliador/SKILL.md`, "Independência
     do N do Revisor").
   - **N no modo surpreenda** — máximo de rodadas de desafiante (default 4,
     teto 8).
3. Se `.agents/DESIGN-STATE.md` já existir, arquive-o em
   `.agents/.design-history/<slug>-<data>.md` (nunca sobrescreva, nunca
   apague) antes de criar um novo para esta sessão.
4. Com `designContext` fixado, modo e N definidos (em "(g)" e "(e)") e
   `DESIGN-STATE.md` resolvido, inicie a "Mecânica da sessão viva, turno a
   turno" de `orquestrador/SKILL.md`.
