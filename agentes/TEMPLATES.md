# Templates de arquivos de projeto

Carregado sob demanda: por `/orquestrador-team` (TEAM.md) e
`/orquestrador-init` (CONTEXTO.md). O `/orquestrador` normal não precisa
deste arquivo.

## Template de TEAM.md

Se `.agents/TEAM.md` existir no projeto, ele define a pré-seleção do menu de
`/orquestrador` (o usuário ainda pode ajustar por sessão). Formato:

```
# Time padrão — <projeto>

Define a pré-seleção do menu quando /orquestrador rodar aqui.
O usuário ainda pode ajustar por sessão — isto só muda o ponto de partida.

[x] 1. ANÁLISE — Analista
[ ] 2. CLARIFICAÇÃO — PO
[x] 3. ARQUITETURA — Arquiteto
[ ] 4. BDD
[ ] 5. UX/UI — Designer
[x] 6. TECH LEAD — TL
[x] 7. DESENVOLVIMENTO — Dev (sempre ativo, não editável)
[ ] 8. TESTES — QA
[x] 9. REVISÃO — Revisor
[ ] 10. SEGURANÇA
```

A etapa 7 (Desenvolvimento) nunca pode ficar desmarcada — `/orquestrador-team`
recusa a edição se o usuário tentar desativá-la.

## Template de CONTEXTO.md

`.agents/CONTEXTO.md` é a memória persistente de um projeto. Gerado/atualizado
por `/orquestrador-init` e realimentado durante o uso normal do pipeline
(seção "Atualização de contexto sugerida" dos subagentes, gravada só com
confirmação do usuário). Sempre com estas 7 seções, nesta ordem:

1. **Visão geral do projeto** — propósito, domínio, stack.
2. **Arquitetura** — camadas, padrões, decisões estruturais.
3. **Convenções de código** — estilo, nomenclatura, padrões observados no repo.
4. **Decisões importantes e histórico** — por que certas escolhas foram feitas.
5. **Integrações externas / dependências entre projetos** — ex: "consome os
   endpoints X e Y do serviço `ymci-backend`; contrato em `docs/api/...`".
   Existe para o caso de monorepo onde um projeto secundário depende de 1-2
   endpoints do produto principal, sem precisar importar o contexto inteiro
   do outro projeto.
6. **Áreas sensíveis / gotchas conhecidos** — coisas que quebram fácil, dívida
   técnica. (É esta seção que a Segurança recebe no disparo.)
7. **Log de atualizações** — data, o que mudou, origem (`init` ou `pipeline`).

Ao fundir com um `CONTEXTO.md` já existente: preserva o que ainda é válido,
atualiza o que mudou, sempre registra uma linha nova na seção 7.

## Convenção universal: idioma do código

Independente do idioma da conversa com o usuário (português), todo artefato de
código produzido pelo pipeline é sempre em inglês: nomes de variáveis, funções,
classes, arquivos e pastas; comentários no código; tabelas/colunas/schemas de
banco de dados; chaves de configuração, rotas/endpoints e nomes de eventos;
mensagens de commit e nomes de branch; nomes de teste (`describe`/`it`/`test`).
Fica em português apenas a comunicação com o usuário e strings visíveis ao
usuário final quando o produto for para público brasileiro. Ao editar um
arquivo legado em português: mantém consistência local e sinaliza, sem migrar
em massa. A regra está repetida de forma autocontida em `ARQUITETO.md`,
`TL.md`, `DEV.md`, `QA.md` e `REVISOR.md` (cada subagente só lê a própria
persona) e na skill `coding-standards` (`.claude/skills/coding-standards/`),
que cobre código escrito fora do pipeline.
