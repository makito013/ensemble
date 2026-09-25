---
description: Varre o(s) projeto(s) e gera/atualiza .agents/CONTEXTO.md com o máximo de contexto útil.
argument-hint: [pasta opcional]
---

Modo de coleta de contexto do Orquestrador. Tarefa mecânica: não carregue
`.agents/ORQUESTRADOR.md` nem `.agents/PIPELINE.md` — tudo o que você
precisa está aqui.

Pasta informada (vazio = detectar todos os projetos a partir do cwd):

$ARGUMENTS

Passos:
1. Rode `.agents/scripts/detect-projects.sh $ARGUMENTS` (sem argumento, o
   script usa o diretório atual como raiz de busca) para obter a lista de
   projetos, um caminho absoluto por linha.
2. Para cada projeto da lista, dispare um subagente isolado
   (`subagent_type: general-purpose`, `model: "haiku"`; projetos
   independentes podem ir em paralelo, várias chamadas numa única mensagem)
   que varre só aquela subárvore e escreve/funde `.agents/CONTEXTO.md`
   naquele projeto com exatamente estas 7 seções, nesta ordem:
   1. Visão geral do projeto — propósito, domínio, stack
   2. Arquitetura — camadas, padrões, decisões estruturais
   3. Convenções de código — estilo, nomenclatura, padrões observados
   4. Decisões importantes e histórico
   5. Integrações externas / dependências entre projetos (ex: endpoints de
      outro serviço que este consome, e onde está o contrato)
   6. Áreas sensíveis / gotchas conhecidos
   7. Log de atualizações — data, o que mudou, origem (`init` ou `pipeline`)

   Se `CONTEXTO.md` já existir naquele projeto, o subagente funde:
   preserva o que ainda é válido, atualiza o que mudou, e sempre registra uma linha
   nova na seção "Log de atualizações" (origem `init`) — nunca sobrescreve
   cegamente. (Template de referência: `.agents/TEMPLATES.md`.)
3. Nunca deixe um subagente ler ou escrever o `CONTEXTO.md` de outro projeto.
4. Ao final, resuma ao usuário: projetos processados, quais eram novos vs.
   atualizados, e qualquer aviso (ex: nenhum projeto encontrado até a
   profundidade máxima).
