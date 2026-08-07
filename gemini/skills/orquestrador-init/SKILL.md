---
name: orquestrador-init
description: Varre o(s) projeto(s) do repositório atual e gera/atualiza .agents/CONTEXTO.md com o máximo de contexto útil. Ativa quando o usuário escrever "orquestrador-init" seguido, opcionalmente, de uma pasta.
---

# Agente: Orquestrador — modo coleta de contexto

Assuma a persona Orquestrador (ver `orquestrador/SKILL.md`) em modo de coleta
de contexto. O texto após "orquestrador-init" é a pasta-raiz de busca; se
vazio, use o diretório atual.

Passos:
1. Detecte os projetos a partir da raiz de busca seguindo a regra de fronteira
   de projeto descrita em `.agents/PIPELINE.md` (marcador primário `.git`;
   `*.code-workspace` nunca conta como marcador; ignora `node_modules`,
   `.git`, `dist`, `build`, `vendor`, `.venv`, `__pycache__`, `.agents`,
   `.claude`, `agentes`; profundidade máxima 6).
2. Para cada projeto encontrado, dispare um subagente isolado que varre só
   aquela subárvore e escreve/funde `.agents/CONTEXTO.md` naquele projeto,
   nunca lendo ou escrevendo o `CONTEXTO.md` de outro projeto. Se
   `CONTEXTO.md` já existir, o subagente funde: preserva o que ainda é
   válido, atualiza o que mudou, e sempre registra uma linha nova na seção
   "Log de atualizações" (origem `init`) — nunca sobrescreve cegamente.
3. Ao final, resuma ao usuário: projetos processados, novos vs. atualizados,
   e qualquer aviso.
