---
description: Revisa um PR local (branch vs. base) sem depender do MCP do GitHub, usando Revisor e Segurança como subagentes, e consolida um veredito único de merge.
argument-hint: [branch do PR] [o que foi feito] [commit opcional] [base opcional] [task original opcional]
---

Assuma a persona Orquestrador em modo de revisão de PR local para a seguinte
solicitação:

$ARGUMENTS

Passos:

1. Se `.agents/CONTEXTO.md` existir neste projeto, leia antes de tudo.

2. Extraia de `$ARGUMENTS` (interpretação em linguagem natural — nunca parsing
   posicional/regex) estes 5 campos: branch do PR, o que foi feito, commit
   (o commit/SHA de referência do trabalho feito, se o Bruno tiver — é
   informativo/contextual, só para rastreabilidade no relatório de qual ponto
   exato foi revisado; o `git diff` do passo 5 continua sendo calculado por
   `<base>...<branch>`, a branch inteira, nunca por um commit isolado), base
   (opcional, default `main`), task/contexto original (opcional, pode vir do
   próprio `CONTEXTO.md` se `$ARGUMENTS` não trouxer). Falta alguma coisa se:
   branch do PR ausente, OU "o que foi feito" ausente, OU task/contexto
   original totalmente ausente (nem em `$ARGUMENTS` nem inferível do
   `CONTEXTO.md`). Commit e base são sempre opcionais e nunca entram nesse
   critério de "faltou". Em caso de ambiguidade real entre dois campos (ex:
   não dá pra saber qual token é a branch e qual é a base), trate também como
   "faltou". Se faltar algo, pare e faça UMA ÚNICA pergunta consolidada ao
   Bruno, listando só os itens que faltam — nunca uma pergunta por campo.

3. Resolva a branch base: rode `git rev-parse --verify --quiet main` (ou a
   base informada no passo 2, se houver). Se falhar, tente
   `git symbolic-ref refs/remotes/origin/HEAD` como fallback e extraia o nome
   da branch depois de `origin/`. Se nada resolver, ABORTE com uma mensagem
   explícita ao Bruno explicando que não foi possível determinar a base.

4. Valide a branch do PR: rode `git fetch --quiet` primeiro, best-effort — se
   falhar (sem rede, sem remoto configurado), NÃO interrompa o fluxo; siga com
   o que já existe localmente e registre no relatório final que a checagem
   pode estar desatualizada. Em seguida confirme que a branch existe via
   `git branch -a` e/ou `git ls-remote --heads origin <branch>`. Se a branch
   não existir em nenhum dos dois, ABORTE.

5. Levante o inventário do diff: rode primeiro
   `git diff --stat <base>...<branch>` (leve, só o resumo).
   - Se o diff for vazio — confirme comparando `git merge-base <base> <branch>`
     com `git rev-parse <branch>`: se forem iguais, não há diff — PARE, avise
     o Bruno e peça confirmação de branch/base/commit. Nunca gere um relatório
     sobre um diff vazio.
   - Se o diff tiver mais de 800 linhas alteradas OU mais de 15 arquivos:
     crie a pasta `.agents/.pr-reviews/` se não existir, grave o diff completo
     (`git diff <base>...<branch>`) em
     `.agents/.pr-reviews/pr-diff-<branch-slug>.txt` (slug = nome da branch
     com `/` trocado por `-`) e, nos passos 7 e 8, instrua os subagentes a
     lerem esse arquivo (ou a rodarem `git log`/`git show` escopados) em vez
     de receber o diff inline.
   - Abaixo do limiar, inclua o diff completo (`git diff <base>...<branch>`)
     inline no prompt dos subagentes.

6. Compare `git branch --show-current` com `<branch>`:
   - Se forem iguais, rode `git status --porcelain` e reserve o resultado
     como uma seção própria do relatório final, "Arquivos fora do commit" —
     nunca misture essa saída com o diff do PR.
   - Se forem diferentes, pule esta checagem e registre no relatório que ela
     não se aplica (a branch auditada não é a que está checked-out agora).

7. Dispare, na MESMA mensagem (paralelo real — nunca sequencial, nunca
   `fork`), dois subagentes com `subagent_type: general-purpose`:

   - **Revisor**: o prompt deve conter o conteúdo integral de
     `.agents/REVISOR.md`, a task/contexto original, o "o que foi feito", o
     diff (inline, conforme o passo 5, ou a instrução para ler
     `.agents/.pr-reviews/pr-diff-<branch-slug>.txt`) e a saída de
     `git log --oneline <base>..<branch>`. Não especifique override de
     modelo — roda no modelo padrão (Sonnet).

   - **Segurança**: o prompt deve conter o conteúdo integral de
     `.agents/SEGURANCA.md`, o diff (inline ou a mesma referência ao arquivo
     do passo 5), a seção "Arquivos fora do commit" do passo 6 contendo
     APENAS paths + classificação de risco (nunca o conteúdo desses
     arquivos — classifique o risco por regra determinística de nome/extensão,
     ex: `.env`, `*.pem`, `credentials.json`, ANTES de montar o prompt, para
     que o subagente de Segurança nunca precise ler o conteúdo desses
     arquivos) e o perfil de risco extraído do `CONTEXTO.md`, se existir.
     Dispare este subagente com override explícito de modelo `opus`
     (código security-sensitive — ver "Subagentes e escolha de modelo" em
     `.agents/PIPELINE.md`).

8. Combine os dois vereditos numa regra única, nesta ordem de prioridade:
   - Segurança `🔴 BLOQUEADO` → veredito geral **NÃO MERGEAR** (sempre,
     ignora o Revisor).
   - Senão, Revisor `❌ REPROVADO` → **NÃO MERGEAR**.
   - Senão, Revisor `⚠️ APROVADO COM RESSALVAS` OU Segurança
     `🟡 LIBERADO COM RECOMENDAÇÕES` → **MERGEAR COM RESSALVAS** (junte as
     pendências dos dois relatórios).
   - Só quando os dois estiverem no estado máximo (Revisor `✅ APROVADO` +
     Segurança `🟢 LIBERADO`) → **OK PARA MERGE**.

9. Persista o relatório consolidado (os dois relatórios + o veredito
   combinado do passo 8) em
   `.agents/.pr-reviews/<branch-slug>-<data>.md` — nunca sobrescreva um
   arquivo já existente; se colidir, acrescente um sufixo. No cabeçalho do
   relatório, inclua os dados do PR revisado: branch, base, commit (quando
   informado pelo Bruno no passo 2) e task/contexto original. Deixe claro
   também que uma base desatualizada (passo 4) é só um aviso, nunca um
   bloqueio, e que qualquer arquivo "fora do commit" suspeito de segredo
   entra no relatório apenas como path + classificação de risco, nunca com o
   conteúdo. Depois apresente o relatório ao Bruno.
