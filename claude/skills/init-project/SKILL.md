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
subdiretório em nenhum fluxo: tanto a instalação nova (passo 4) quanto a
reinstalação completa (passo 5) só sobrescrevem os **arquivos de template**
(definição única abaixo) e deixam todo o resto de `./.agents/` no lugar,
igual a `CONTEXTO.md`/`TEAM.md`. Quando `antigravity` está em
`AI_TARGETS`, o passo 7b ainda copia a versão nova desses skills por cima
da restauração; quando não está, a cópia automática não acontece e o
usuário continua podendo copiar `~/agentes-pipeline/gemini/skills/`
manualmente, como sempre foi possível.

**Arquivo de template** tem uma única definição, a função `tracked_files` de
`~/agentes-pipeline/scripts/init-manifest-diff.sh`: `agentes/*.md` →
`.agents/`, `agentes/scripts/*` → `.agents/scripts/`, `commands/*.md` →
`.claude/commands/` e `skills/<nome>/SKILL.md` → `.claude/skills/<nome>/`,
sempre **excluindo arquivos de teste** (`*.test.*`, ex.: `commands.test.sh`,
`orquestrador-init-merge.test.sh`) — eles vivem ao lado dos templates no
repo-fonte, mas nunca vão para o projeto. Todo o resto de `./.agents/` é dado
do projeto e o instalador nunca toca: `CONTEXTO.md`, `TEAM.md`,
`.aprendizados-globais-pendentes.md`, `.init-manifest.json` (só reescrito pelo
script), `PIPELINE-STATE.md`, `.pipeline-history/`, `DESIGN-STATE.md`,
`.design-history/`, `design-system/` (inclui `surpresa/`, `preview/`,
`REFERENCIAS.md`), `planos/`, `.pr-reviews/`, `.pipeline-run/`, `skills/` e
qualquer outro arquivo que não seja de template. Nunca copie diretórios
inteiros de `~/agentes-pipeline/` "na mão" (`cp -R`): use sempre os
subcomandos do script, que aplicam essa definição.

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
     existirem ao mesmo tempo: pare e reporte o conflito ao usuário (os
     dois caminhos encontrados), sem tocar em nenhum dos dois — não
     tente adivinhar o merge.
   - Se nenhum dos dois existir, ou só `.agents/PIPELINE.md` existir, ou
     `./agentes/` existir sem `PIPELINE.md` dentro (pasta não
     relacionada a este pipeline — ignore-a, não mexa nela): siga
     normalmente.

3. Verifique se `./.agents/PIPELINE.md` já existe (critério de "já instalado"
   do lado Claude — não confunda com `./.agents/` existir só por causa do
   `skills/` do Gemini).

4. **Se não existir:** rode
   ```bash
   bash ~/agentes-pipeline/scripts/init-manifest-diff.sh install \
     "$(pwd)" ~/agentes-pipeline/agentes ~/agentes-pipeline/commands \
     ~/agentes-pipeline/skills
   ```
   Ele cria `./.agents/`, `./.claude/commands/` e `./.claude/skills/` se
   preciso, copia **só os arquivos de template** (só `*.md` de
   `COMMANDS_DIR`, nunca `*.test.sh`; nada de `./.agents/skills/` é apagado)
   e grava `./.agents/.init-manifest.json`, deixando o projeto pronto para
   `--update`. Cite o `INSTALLED=<n>` impresso no resumo final.

5. **Se já existir (caso de atualização) e a flag `--update` NÃO foi passada:**
   backup completo por **cópia**, fora de `./.agents/`, e depois
   sobrescrita **somente** dos arquivos de template, no lugar. Nunca faça
   `mv ./.agents` nem recrie a pasta: isso perdia `PIPELINE-STATE.md`,
   `.pipeline-history/`, `design-system/`, `planos/` e os demais dados de
   projeto listados acima.
   1. Backup completo:
      ```bash
      bash ~/agentes-pipeline/scripts/init-manifest-diff.sh backup \
        "$(pwd)" ~/agentes-pipeline/agentes ~/agentes-pipeline/commands \
        ~/agentes-pipeline/skills
      ```
      Copia todo `./.agents/` para `./.agents-backups/{YYYYMMDD-HHMMSS}/.agents/`
      e os arquivos de template de `./.claude/` que serão sobrescritos para
      `./.agents-backups/{YYYYMMDD-HHMMSS}/.claude/`. A saída traz
      `BACKUP=<caminho>` (guarde-o como `BACKUP_DIR`) e
      `LEGACY_BACKUPS=<n>`. Backups antigos no formato
      `./.agents/.backup-*` (versões anteriores deste skill) **não** são
      movidos, apagados nem copiados de novo: ficam onde estão. Se
      `LEGACY_BACKUPS` for maior que zero, só mencione no resumo que eles
      existem e podem ser apagados manualmente quando o usuário quiser.
   2. Sobrescreva os arquivos de template:
      ```bash
      bash ~/agentes-pipeline/scripts/init-manifest-diff.sh install \
        "$(pwd)" ~/agentes-pipeline/agentes ~/agentes-pipeline/commands \
        ~/agentes-pipeline/skills
      ```
      Só os arquivos de template são sobrescritos; comandos e skills que
      não são do template (ex.: outros comandos em `./.claude/commands/`,
      outras skills em `./.claude/skills/`) e todos os dados de projeto em
      `./.agents/` ficam no lugar, sem precisar de restauração. O script
      também grava `./.agents/.init-manifest.json` com o hash do template
      como baseline.
   3. Restaure os aprendizados locais das personas: para cada arquivo
      `BACKUP_DIR/.agents/<PERSONA>.md` que tiver uma seção
      `## Aprendizados`, copie essa seção (não mova) para dentro do arquivo
      recém-instalado `./.agents/<PERSONA>.md`, inserindo-a imediatamente
      antes do bloco final (`---` + nota de ativação + linha de rodapé de
      modelo) — a mesma regra de posicionamento de `agentes/APRENDIZADOS.md` — pra regra de
      aprendizado local não se perder num reinstall completo. **Não** rode
      `init-manifest-diff.sh generate` depois disso: o manifesto precisa
      continuar com o hash do template, para o próximo `--update` classificar
      a persona com aprendizado como `PRESERVE`/`CONFLICT` em vez de
      sobrescrevê-la. O backup continua intacto com as cópias originais.
   Liste no resumo o caminho do backup (`BACKUP_DIR`), quantos arquivos de
   template foram instalados (`INSTALLED=`), de quais personas a seção
   `## Aprendizados` foi restaurada e, se houver, os `./.agents/.backup-*`
   legados encontrados. Arquivos que deixaram de existir no template não são
   apagados automaticamente — se notar algum, só mencione.

6. **Se já existir e a flag `--update` foi passada:**
   1. Rode:
      ```bash
      bash ~/agentes-pipeline/scripts/init-manifest-diff.sh apply \
        "$(pwd)" ~/agentes-pipeline/agentes ~/agentes-pipeline/commands \
        ~/agentes-pipeline/skills
      ```
   2. Se a saída for exatamente `NEED_FULL_REINSTALL` (exit code 2): não há
      manifesto ainda (projeto instalado antes desta funcionalidade existir).
      Caia automaticamente no comportamento do passo 5 (backup completo em
      `./.agents-backups/` + sobrescrita só dos arquivos de template +
      restauração das seções `## Aprendizados`). O `install` do passo 5 já
      cria o manifesto inicial com o hash do template — não rode `generate`
      depois.
   3. Caso contrário, relate ao usuário o resumo impresso pelo script
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
   template. O mesmo vale para todos os outros dados de projeto listados em
   "Arquivo de template" acima (`PIPELINE-STATE.md`, `design-system/`,
   `planos/`, etc.): em nenhum fluxo eles são movidos, apagados ou
   recriados — o passo 5 apenas os **copia** para `./.agents-backups/`.
   Nenhum outro arquivo do projeto (README.md, `.planning/`, etc.) é afetado.

7b. **Adapters por IA.** Para cada id em `AI_TARGETS`:
   - `claude` — nada a fazer, os passos 1-7 já cobrem.
   - `antigravity` — copie `~/agentes-pipeline/gemini/skills/` para
     `./.agents/skills/` (crie a pasta se não existir). Idempotente por
     sobrescrita: cada `<nome>/SKILL.md` presente na origem sobrescreve o de
     destino. Não apague subpastas que existam só no destino. Como o passo 5
     nunca remove `./.agents/skills/`, este passo só aplica a versão nova da
     fonte por cima do que já está lá. Se `antigravity` não estiver em
     `AI_TARGETS`, este passo não roda e `./.agents/skills/` fica como
     estava.
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
        script) ao usuário — nunca tente editar `AGENTS.md` manualmente para
        "consertar" o conflito. Isso é sempre via script determinístico,
        nunca prosa/edição livre por LLM.
     2. Copie `~/agentes-pipeline/codex/skills/` para `./.codex/skills/`
        (crie a pasta se não existir). Idempotente por sobrescrita, mesma
        lógica do adapter Antigravity acima — inclui as subpastas
        `agents/openai.yaml` de cada skill, preserve a estrutura completa.
   - `cursor`:
     1. Copie `~/agentes-pipeline/cursor/skills/` para `./.cursor/skills/`
        (crie a pasta se não existir). Mesma lógica de idempotência por
        sobrescrita.
     2. Copie `~/agentes-pipeline/cursor/rules/coding-standards.mdc` para
        `./.cursor/rules/coding-standards.mdc` (crie a pasta se não
        existir). É a regra `coding-standards` no formato do Cursor
        (`alwaysApply: true` — sempre aplicada, diferente das skills do
        pipeline). Sobrescreva só esse arquivo; nunca apague nem altere
        outras regras que existam em `./.cursor/rules/`.

   A regra `coding-standards` (código sempre em inglês) chega a cada engine
   pelo próprio adapter: Claude via `.claude/skills/coding-standards/`
   (conjunto base), Antigravity via `gemini/skills/coding-standards/` (vai
   junto na cópia de `gemini/skills/`), Codex via seção própria do bloco em
   `AGENTS.md` (`codex/AGENTS-block.md`) e Cursor via
   `.cursor/rules/coding-standards.mdc`.

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
     1b. **Se `./.agents-backups/` existir** (o passo 5 rodou agora ou numa
        execução anterior), aplique a mesma checagem para ele: se já houver
        uma linha exatamente igual a `.agents-backups`, `.agents-backups/`,
        `/.agents-backups` ou `/.agents-backups/`, não faça nada; caso
        contrário, acrescente `.agents-backups/` ao final (mesmo formato de
        linha em branco antes, se necessário). `.agents/` no `.gitignore` não
        cobre `.agents-backups/` — são pastas diferentes. Backups contêm
        cópias integrais dos dados locais do pipeline e nunca devem ir para o
        git.
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
   instalados, o caminho do backup se houve um (`./.agents-backups/<TS>/`),
   os `./.agents/.backup-*` legados encontrados (deixados no lugar), se houve
   migração de `agentes/` legado, se o `.gitignore` ganhou entradas novas
   (`.agents/`, `.agents-backups/` e, se aplicável,
   `.cursor/skills/`/`.codex/skills/`), o `AI_TARGETS`
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
completo de 26 arquivos em `.agents/` (20 personas + `PIPELINE.md` + os 5
documentos sob demanda `MODELOS.md`, `TIME-DESIGN-FLOW.md`, `PLAN-FLOW.md`,
`APRENDIZADOS.md`, `TEMPLATES.md`) e os scripts de runtime em
`.agents/scripts/` (`detect-projects.sh`, `pipeline-status.sh`,
`review-input.sh`, `design-snapshot.mjs`), mais os
8 comandos (`/orquestrador*` + `/time-design`) em `.claude/commands/`, mais a
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
  `./.cursor/skills/` e a regra `cursor/rules/coding-standards.mdc` para
  `./.cursor/rules/`.

A seleção de quais **etapas do pipeline** rodar em cada tarefa continua sendo
uma decisão de runtime feita pela persona Orquestrador no início de cada
sessão, não uma escolha no momento da instalação. `AI_TARGETS` é ortogonal a
isso: decide quais **arquivos de adapter** existem no projeto, não quais etapas
rodam.
