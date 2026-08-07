---
description: Varre o(s) projeto(s) e gera/atualiza .agents/CONTEXTO.md com o máximo de contexto útil.
argument-hint: [pasta opcional]
---

Consulte `.agents/ORQUESTRADOR.md` para a persona e mecânica base do Orquestrador.
Assuma a persona Orquestrador em modo de coleta de contexto.

Pasta informada (vazio = detectar todos os projetos a partir do cwd):

$ARGUMENTS

Passos:
1. Rode `.agents/scripts/detect-projects.sh $ARGUMENTS` (sem argumento, o
   script usa o diretório atual como raiz de busca) para obter a lista de
   projetos, um caminho absoluto por linha.
2. Para cada projeto da lista, dispare um subagente isolado
   (`subagent_type: general-purpose`) que varre só aquela subárvore e
   escreve/funde `.agents/CONTEXTO.md` naquele projeto, seguindo a estrutura
   de seções descrita em `.agents/PIPELINE.md`. Se `CONTEXTO.md` já existir
   naquele projeto, o subagente funde: preserva o que ainda é válido, atualiza
   o que mudou, e sempre registra uma linha nova na seção "Log de
   atualizações" (origem `init`) — nunca sobrescreve cegamente.
3. Nunca deixe um subagente ler ou escrever o `CONTEXTO.md` de outro projeto.
4. Ao final, resuma ao Bruno: projetos processados, quais eram novos vs.
   atualizados, e qualquer aviso (ex: nenhum projeto encontrado até a
   profundidade máxima).
