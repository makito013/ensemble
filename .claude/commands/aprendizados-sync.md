---
description: Sincroniza um projeto e aplica as regras de aprendizado pendentes marcadas como "global" nos arquivos de persona-fonte deste repo (agentes/*.md e gemini/skills/*/SKILL.md).
argument-hint: <caminho-do-projeto>
---

Este comando só faz sentido rodando dentro do repo-fonte `agentes-pipeline`
(este repositório) — é aqui que vivem os arquivos de persona-fonte que ele
atualiza. Consulte `agentes/PIPELINE.md` (seção "Convenção: seção `##
Aprendizados` nas personas") para o formato completo.

Caminho do projeto a sincronizar:

$ARGUMENTS

Passos:
1. Leia `<caminho>/.agents/.aprendizados-globais-pendentes.md`. Se não
   existir ou estiver vazio, informe ao Bruno que não há regra pendente
   nesse projeto e pare.
2. Para cada regra pendente (agrupada por persona-alvo no arquivo),
   apresente ao Bruno: o texto da regra e a persona-alvo. Bruno responde:
   aprovar como está, editar o texto, ou descartar.
3. Regra aprovada (com ou sem edição): adicione um bullet na seção
   `## Aprendizados` de `agentes/<PERSONA>.md` (crie a seção, imediatamente
   antes do bloco final — `---` + nota de ativação + linha-ponteiro `Ver
   "Subagentes e escolha de modelo"...` —, se ainda não existir) — e
   replique o mesmo bullet numa seção `## Aprendizados` equivalente em
   `gemini/skills/<persona>/SKILL.md` (sem a linha-ponteiro, que esse lado
   não tem). A data do bullet é a data original da entrada na fila (o
   `<data>` que já vem no bullet de `.aprendizados-globais-pendentes.md`),
   não a data de hoje em que o sync está rodando.
4. Depois de decididas todas as regras do arquivo (aprovadas ou
   descartadas), reescreva `<caminho>/.agents/.aprendizados-globais-pendentes.md`
   removendo as entradas processadas. Se não sobrar nenhuma entrada, remova
   o arquivo.
5. Resuma ao Bruno: quantas regras foram aplicadas, em quais personas, e
   quantas foram descartadas.
