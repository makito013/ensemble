---
name: init-project
description: Bootstrap a project with the standard multi-agent development pipeline (Analista, PO, Arquiteto, BDD, Designer, TL, Dev, QA, Revisor, Segurança, Orquestrador) plus the Time de Design (Orquestrador-Design, Avaliador, UX, Dev-Design, Copywriter, Acessibilidade, Brand). Use when the user asks to set up, install, or update the agent pipeline in a project via /init-project.
---

# init-project

Instala (ou atualiza) o conjunto padrão de 18 personas de agentes + o documento de
pipeline dentro de `./.agents/`, os comandos `/orquestrador*` dentro de
`./.claude/commands/`, e a skill `coding-standards` (convenção de código sempre
em inglês) dentro de `./.claude/skills/`, no diretório de trabalho atual.

`./.agents/` é compartilhada com o lado Gemini/Antigravity, que instala
seus próprios skills em `./.agents/skills/` — este skill não apaga esse
subdiretório numa instalação nova (passo 4), e num fluxo de atualização
com backup completo (passo 5) ele é restaurado de volta a partir do
backup, igual a `CONTEXTO.md`/`TEAM.md`.

## Passos

1. Resolva `TEMPLATE_DIR` como `~/agentes-pipeline/agentes/`,
   `COMMANDS_DIR` como `~/agentes-pipeline/commands/` e `SKILLS_DIR` como
   `~/agentes-pipeline/skills/` — repositório git dedicado e portátil que é a
   fonte única dos templates (não fica duplicado dentro deste skill; veja
   `~/agentes-pipeline/README.md` e `~/agentes-pipeline/AGENTS.md`).

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
      `./.claude/commands/` (sobrescrevendo os 5 arquivos do Orquestrador se
      já existirem; não mexa em outros comandos que não sejam
      `orquestrador*.md`)
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

8. **Gitignore.** Depois de instalar/atualizar (em todos os casos acima,
   inclusive quando migrou), verifique `./.gitignore` na raiz do projeto:
   - Se não existir, não crie o arquivo — não faça nada.
   - Se existir e já tiver uma linha exatamente igual a `.agents`, `.agents/`,
     `/.agents` ou `/.agents/`, não faça nada (já está coberto).
   - Caso contrário, acrescente ao final:
     ```

     # agentes-pipeline (dados locais, não versionados)
     .agents/
     ```
     (uma linha em branco antes, se o arquivo não terminar já em branco).

9. Confirme a conclusão com um resumo curto: quantidade de arquivos
   instalados, o caminho do backup se houve um, se houve migração de
   `agentes/` legado, e se o `.gitignore` ganhou a entrada nova.

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

Este skill sempre instala o conjunto fixo completo de 19 arquivos em `.agents/`
(18 personas + `PIPELINE.md`) mais os 5 comandos `/orquestrador*` em
`.claude/commands/` mais a skill `coding-standards` em
`.claude/skills/coding-standards/SKILL.md`. A seleção de quais etapas do
pipeline rodar em cada tarefa é uma decisão de runtime feita pela persona
Orquestrador no início de cada sessão — não uma escolha no momento da
instalação.
