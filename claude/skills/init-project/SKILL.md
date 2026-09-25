---
name: init-project
description: Bootstrap a project with the standard multi-agent development pipeline (Analista, PO, Arquiteto, BDD, Designer, TL, Dev, QA, Revisor, Segurança, Orquestrador) plus the Time de Design (Orquestrador-Design, Avaliador, UX, Dev-Design, Copywriter, Acessibilidade, Brand, Desafiante). Use when the user asks to set up, install, or update the agent pipeline in a project via /init-project.
---

# init-project

Instala (ou atualiza) duas coisas no diretório de trabalho atual:

1. **Conjunto base, sempre instalado**, independente de qual IA você usa: as 20
   personas de agentes + o documento de pipeline (e os scripts de runtime em
   `scripts/`) dentro de `./.agents/`, os
   comandos `/orquestrador*` e `/time-design` dentro de `./.claude/commands/`, e
   a skill `coding-standards` (convenção de código sempre em inglês) dentro de
   `./.claude/skills/`.
2. **Adapters por IA, condicionais**, materializados só para as IAs registradas
   em `AI_TARGETS` (passos 1b e 7b). Implementados hoje: Antigravity, Codex e
   Cursor.

`AI_TARGETS` vem da config de máquina gravada pelo instalador
(`~/.config/agentes-pipeline/ai-targets.json`) e é lida pelo script
`~/agentes-pipeline/scripts/read-ai-targets.sh`. `claude` está sempre presente,
então o conjunto base nunca depende dessa resolução.

`./.agents/` é compartilhada com o lado Gemini/Antigravity, que usa seus
próprios skills em `./.agents/skills/`. Este skill não apaga esse
subdiretório numa instalação nova (passo 4), e num fluxo de atualização
com backup completo (passo 5) ele é restaurado de volta a partir do
backup, igual a `CONTEXTO.md`/`TEAM.md`. Quando `antigravity` está em
`AI_TARGETS`, o passo 7b ainda copia a versão nova desses skills por cima
da restauração; quando não está, a cópia automática não acontece e o
usuário continua podendo copiar `~/agentes-pipeline/gemini/skills/`
manualmente, como sempre foi possível.

## Passos

1. Resolva `TEMPLATE_DIR` como `~/agentes-pipeline/agentes/`,
   `COMMANDS_DIR` como `~/agentes-pipeline/commands/` e `SKILLS_DIR` como
   `~/agentes-pipeline/skills/` — repositório git dedicado e portátil que é a
   fonte única dos templates (não fica duplicado dentro deste skill; veja
   `~/agentes-pipeline/README.md` e `~/agentes-pipeline/AGENTS.md`).

1b. **Resolva `AI_TARGETS`.** Rode
   `bash ~/agentes-pipeline/scripts/read-ai-targets.sh` (acrescente
   `--ai <lista>` se o usuário passou `/init-project --ai claude,cursor`). A
   saída é a lista de IAs desta máquina, em ordem canônica. `claude` está
   sempre presente. O script nunca falha nem pergunta nada: se a config não
   existir, ele devolve `claude`. Cite a lista resolvida no resumo final
   (passo 9).

2. **Migração de instalação legada.** Verifique `./agentes/PIPELINE.md`
   (marca de instalação antiga, visível) e `./.agents/PIPELINE.md` (marca
   de instalação atual do lado Claude). Não trate a mera existência da
   pasta `./agentes/` como sinal de instalação — pode ser uma pasta do
   projeto sem relação nenhuma com este pipeline (comum em código em
   português); o critério é sempre a presença do arquivo `PIPELINE.md`
   dentro dela.
   - Se **só** `./agentes/PIPELINE.md` existir: migre antes de continuar.
     1. Se `./.agents/` ainda não existir: `mv ./agentes ./.agents`.
     2. Se `./.agents/` já existir (ex.: só tinha `skills/` do lado
        Gemini): mova o conteúdo de `./agentes/` para dentro de
        `./.agents/` (não a pasta inteira) e remova `./agentes/` vazia.
     3. Se `./.agents/.init-manifest.json` existir, reescreva as chaves do JSON
        trocando o prefixo `"agentes/` por `".agents/`, mantendo os valores
        (hashes) exatamente como estão — **não** rode
        `init-manifest-diff.sh generate` para "regenerar" o manifesto:
        isso recalcularia o hash a partir do conteúdo local atual, que
        pode já estar customizado, e passaria a tratar a customização
        como se fosse a baseline do template — a próxima atualização
        real do template sobrescreveria a customização silenciosamente.
     4. Registre a migração para citar no resumo final.
   - Se **ambos** `./agentes/PIPELINE.md` e `./.agents/PIPELINE.md`
     existirem ao mesmo tempo: pare e reporte o conflito ao Bruno (os
     dois caminhos encontrados), sem tocar em nenhum dos dois — não
     tente adivinhar o merge.
   - Se nenhum dos dois existir, ou só `.agents/PIPELINE.md` existir, ou
     `./agentes/` existir sem `PIPELINE.md` dentro (pasta não
     relacionada a este pipeline — ignore-a, não mexa nela): siga
     normalmente.

3. Verifique se `./.agents/PIPELINE.md` já existe (critério de "já instalado"
   do lado Claude — não confunda com `./.agents/` existir só por causa do
   `skills/` do Gemini).

4. **Se não existir:** copie o conteúdo de `TEMPLATE_DIR` para dentro de
   `./.agents/` (criando a pasta se não existir, sem apagar `./.agents/skills/`
   se já estiver lá), copie todo o conteúdo de `COMMANDS_DIR` para dentro de
   `./.claude/commands/` (crie a pasta se não existir), e copie todo o
   conteúdo de `SKILLS_DIR` para dentro de `./.claude/skills/` (crie a pasta
   se não existir). Liste os arquivos criados no resumo final.

5. **Se já existir (caso de atualização) e a flag `--update` NÃO foi passada:**
   um diretório não pode ser movido para dentro de si mesmo, então use uma
   renomeação temporária:
   1. `mv ./.agents ./.agents-old-{YYYYMMDD-HHMMSS}` (timestamp do momento da
      execução)
   2. `mkdir ./.agents`
   3. `mv ./.agents-old-{YYYYMMDD-HHMMSS} ./.agents/.backup-{YYYYMMDD-HHMMSS}`
   4. copie o conteúdo de `TEMPLATE_DIR` para dentro de `./.agents/`
   5. Se `./.agents/.backup-{YYYYMMDD-HHMMSS}/CONTEXTO.md` existir,
      copie-o (não mova) para `./.agents/CONTEXTO.md`. Se
      `./.agents/.backup-{YYYYMMDD-HHMMSS}/TEAM.md` existir, copie-o
      (não mova) para `./.agents/TEAM.md`. Se
      `./.agents/.backup-{YYYYMMDD-HHMMSS}/.aprendizados-globais-pendentes.md`
      existir, copie-o (não mova) para
      `./.agents/.aprendizados-globais-pendentes.md`. Se
      `./.agents/.backup-{YYYYMMDD-HHMMSS}/skills/` existir (instalação
      Gemini/Antigravity presente antes do backup), copie-o (não mova,
      pasta inteira) para `./.agents/skills/` — sem essa restauração, o
      Antigravity para de descobrir os skills depois de qualquer
      atualização sem `--update`. Além disso, para cada arquivo de persona
      `./.agents/.backup-{YYYYMMDD-HHMMSS}/<PERSONA>.md` que tiver uma seção
      `## Aprendizados`, copie essa seção (não mova) para dentro do arquivo
      recém-instalado `./.agents/<PERSONA>.md`, inserindo-a imediatamente
      antes do bloco final (`---` + nota de ativação + linha-ponteiro) — a
      mesma regra de posicionamento de `agentes/PIPELINE.md` — pra regra de
      aprendizado local não se perder num reinstall completo. O backup
      continua intacto com as cópias originais.
   6. copie todo o conteúdo de `COMMANDS_DIR` para dentro de
      `./.claude/commands/` (sobrescrevendo os 6 arquivos do Orquestrador +
      `time-design.md` se já existirem; não mexa em outros comandos que não
      sejam esses)
   7. copie todo o conteúdo de `SKILLS_DIR` para dentro de `./.claude/skills/`
      (sobrescrevendo apenas a pasta `coding-standards/` se já existir; não
      mexa em outras skills que o Bruno tenha instalado ali)
   Liste no resumo o que foi backupeado (caminho do backup), o que foi
   restaurado (`CONTEXTO.md`/`TEAM.md`/`.aprendizados-globais-pendentes.md`,
   se aplicável, e `skills/`, se presente) e o que foi instalado.

6. **Se já existir e a flag `--update` foi passada:**
   1. Rode:
      ```bash
      bash ~/agentes-pipeline/scripts/init-manifest-diff.sh apply \
        "$(pwd)" ~/agentes-pipeline/agentes ~/agentes-pipeline/commands \
        ~/agentes-pipeline/skills
      ```
   2. Se a saída for exatamente `NEED_FULL_REINSTALL` (exit code 2): não há
      manifesto ainda (projeto instalado antes desta funcionalidade existir).
      Caia automaticamente no comportamento do passo 5 (backup completo +
      reinstala tudo — o que já inclui a restauração de
      `CONTEXTO.md`/`TEAM.md` do backup para a pasta viva, conforme o item 5
      do passo 5) e, ao final dele, rode
      `bash ~/agentes-pipeline/scripts/init-manifest-diff.sh generate "$(pwd)" ~/agentes-pipeline/agentes ~/agentes-pipeline/commands ~/agentes-pipeline/skills`
      pra criar o manifesto inicial.
   3. Caso contrário, relate ao Bruno o resumo impresso pelo script
      (`INSTALLED=`, `OVERWRITTEN=`, `PRESERVED=`, `CONFLICTS=`) e, se houver
      conflitos, liste cada arquivo `.new` gerado e explique que ele precisa
      revisar manualmente (comparar `<arquivo>` com `<arquivo>.new` e decidir
      o que manter).
   4. `.agents/CONTEXTO.md`, `.agents/TEAM.md`, `.agents/.init-manifest.json`
      e `.agents/.aprendizados-globais-pendentes.md` nunca são tocados por
      este fluxo — são dados do projeto, não do template.

7. Em todos os casos, o CONTEÚDO de `.agents/CONTEXTO.md`, `.agents/TEAM.md`
   e `.agents/.aprendizados-globais-pendentes.md` nunca é modificado,
   sobrescrito ou gerado pelo processo — são dados do projeto, não do
   template. No fluxo do passo 5 eles são temporariamente
   movidos para o backup e depois restaurados (cópia, não edição) para a
   pasta viva com o conteúdo exatamente igual ao original; isso é apenas
   reposicionamento de arquivo, não "tocar" no conteúdo. Nenhum outro arquivo
   do projeto (README.md, `.planning/`, etc.) é afetado.

7b. **Adapters por IA.** Para cada id em `AI_TARGETS`:
   - `claude` — nada a fazer, os passos 1-7 já cobrem.
   - `antigravity` — copie `~/agentes-pipeline/gemini/skills/` para
     `./.agents/skills/` (crie a pasta se não existir). Idempotente por
     sobrescrita: cada `<nome>/SKILL.md` presente na origem sobrescreve o de
     destino. Não apague subpastas que existam só no destino. Este passo roda
     depois da restauração do backup do passo 5: a restauração recompõe o
     estado anterior, e este passo aplica a versão nova da fonte por cima. Se
     `antigravity` não estiver em `AI_TARGETS`, este passo não roda e o
     comportamento de restaurar-do-backup do passo 5 permanece intacto.
   - `codex`:
     1. Aplique o bloco delimitado em `AGENTS.md` da RAIZ do projeto-alvo
        rodando:
        ```bash
        bash ~/agentes-pipeline/scripts/agents-md-block.sh apply \
          ./AGENTS.md ~/agentes-pipeline/codex/AGENTS-block.md
        ```
        A saída é sempre `CREATED=`, `APPENDED=`, `UPDATED=` ou
        `UNCHANGED=<path>` — registre esse resultado literal no resumo final
        (passo 9), nunca de forma silenciosa (é arquivo versionado do
        projeto-alvo). Se o exit code for `3` (marcadores ambíguos em
        `AGENTS.md`), **pare** e reporte o erro (mensagem de stderr do
        script) ao Bruno — nunca tente editar `AGENTS.md` manualmente para
        "consertar" o conflito. Isso é sempre via script determinístico,
        nunca prosa/edição livre por LLM.
     2. Copie `~/agentes-pipeline/codex/skills/` para `./.codex/skills/`
        (crie a pasta se não existir). Idempotente por sobrescrita, mesma
        lógica do adapter Antigravity acima — inclui as subpastas
        `agents/openai.yaml` de cada skill, preserve a estrutura completa.
   - `cursor`: copie `~/agentes-pipeline/cursor/skills/` para
     `./.cursor/skills/` (crie a pasta se não existir). Mesma lógica de
     idempotência por sobrescrita.

   Registre no resumo final quais adapters foram materializados (e, para
   `codex`, o resultado da aplicação do bloco em `AGENTS.md`).

8. **Gitignore.** Depois de instalar/atualizar (em todos os casos acima,
   inclusive quando migrou), verifique `./.gitignore` na raiz do projeto:
   - Se não existir, não crie o arquivo — pule este passo 8 inteiro (nenhuma
     das checagens abaixo se aplica).
   - **Se existir**, faça as duas checagens a seguir (a de `.agents/` sempre;
     as de `.cursor/`/`.codex/` só para os ids selecionados — ver abaixo):
     1. Se já tiver uma linha exatamente igual a `.agents`, `.agents/`,
        `/.agents` ou `/.agents/`, não faça nada quanto a essa entrada (já
        está coberto). Caso contrário, acrescente ao final:
        ```

        # agentes-pipeline (dados locais, não versionados)
        .agents/
        ```
        (uma linha em branco antes, se o arquivo não terminar já em branco).
     2. **Apenas para os ids selecionados em `AI_TARGETS`**, aplique a mesma
        checagem de cobertura, uma entrada por id:
        - `cursor`: cheque se já existe uma linha igual a `.cursor/skills`,
          `.cursor/skills/`, `/.cursor/skills`, `/.cursor/skills/`,
          `.cursor/` ou `/.cursor/` (qualquer uma dessas conta como já
          coberto — as duas últimas são cobertura mais ampla e também
          servem). Se nenhuma estiver presente, acrescente
          `.cursor/skills/` (mesmo formato de linha em branco antes, se
          necessário).
        - `codex`: mesma lógica, variações de `.codex/skills` /
          `.codex/skills/` / `/.codex/skills` / `/.codex/skills/` /
          `.codex/` / `/.codex/` como já coberto; caso contrário acrescente
          `.codex/skills/`.
        - Nunca acrescente uma linha que ignore `.cursor/` ou `.codex/`
          inteiros por conta própria — só cobrem o que este processo cria
          (`skills/`); config real do usuário fora dessa subpasta não deve
          ser ignorada por este passo. As variações de cobertura ampla
          acima só contam como "já coberto" quando **já existiam** no
          arquivo (decisão do usuário), nunca são o que este passo escreve.
   - `AGENTS.md` **não** entra no `.gitignore` em nenhum caso — é arquivo de
     projeto, normalmente já versionado.

9. Confirme a conclusão com um resumo curto: quantidade de arquivos
   instalados, o caminho do backup se houve um, se houve migração de
   `agentes/` legado, se o `.gitignore` ganhou entradas novas (`.agents/` e,
   se aplicável, `.cursor/skills/`/`.codex/skills/`), o `AI_TARGETS`
   resolvido no passo 1b, e quais adapters do passo 7b foram materializados
   (ou que nenhum foi, quando a seleção é só `claude`). Quando `codex`
   estiver em `AI_TARGETS`, reporte explicitamente que o `AGENTS.md` da raiz
   do projeto foi criado/alterado: caminho (`./AGENTS.md`) e o tipo de
   mudança (`CREATED`/`APPENDED`/`UPDATED`/`UNCHANGED`), tirado literalmente
   da saída de `agents-md-block.sh` no passo 7b — escrita em arquivo
   versionado do usuário nunca é silenciosa.

## Tratamento de erros

- Se `TEMPLATE_DIR`, `COMMANDS_DIR` ou `SKILLS_DIR` não existirem ou estiverem
  corrompidos (skill instalado incorretamente), reporte o caminho esperado e
  pare — não tente adivinhar o conteúdo.
- Se `./agentes/PIPELINE.md` (legado) e `./.agents/PIPELINE.md`
  existirem ao mesmo tempo, pare e reporte o conflito — não tente
  mesclar automaticamente (ver passo 2).
- Erros de permissão de escrita devem ser reportados diretamente ao usuário, sem pular
  arquivos silenciosamente.
- Não há chamadas de rede nem dependências externas — as únicas falhas possíveis são
  de sistema de arquivos local.

## Escopo

O que este skill instala se divide em duas camadas.

**Núcleo invariante (sempre, para qualquer `AI_TARGETS`).** O conjunto fixo
completo de 21 arquivos em `.agents/` (20 personas + `PIPELINE.md`) e os
scripts de runtime em `.agents/scripts/` (`detect-projects.sh`,
`design-snapshot.mjs`), mais os
7 comandos (`/orquestrador*` + `/time-design`) em `.claude/commands/`, mais a
skill `coding-standards` em `.claude/skills/coding-standards/SKILL.md`. Como
`claude` está sempre presente em `AI_TARGETS`, essa camada nunca varia.

**Adapters por IA (variável, conforme `AI_TARGETS`).** Materializados no passo
7b:
- **Antigravity** copia `~/agentes-pipeline/gemini/skills/` para
  `./.agents/skills/`.
- **Codex** aplica o bloco delimitado de `~/agentes-pipeline/codex/AGENTS-block.md`
  em `./AGENTS.md` da raiz do projeto-alvo (via `agents-md-block.sh`,
  determinístico) e copia `~/agentes-pipeline/codex/skills/` para
  `./.codex/skills/`.
- **Cursor** copia `~/agentes-pipeline/cursor/skills/` para
  `./.cursor/skills/`.

A seleção de quais **etapas do pipeline** rodar em cada tarefa continua sendo
uma decisão de runtime feita pela persona Orquestrador no início de cada
sessão, não uma escolha no momento da instalação. `AI_TARGETS` é ortogonal a
isso: decide quais **arquivos de adapter** existem no projeto, não quais etapas
rodam.
