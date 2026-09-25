# Aprendizado por feedback — decisão e escrita

Carregado sob demanda: o Orquestrador só lê este arquivo no resumo final de
uma sessão em que registrou pelo menos uma regra candidata (detecção em
`ORQUESTRADOR.md`, "Aprendizado por feedback"), ou quando
`/aprendizados-sync` roda no repo-fonte.

## Decisão (no resumo final)

Se houver pelo menos uma regra candidata, liste todas juntas antes de
encerrar:

> "Identifiquei estas regras que você decidiu seguir nesta sessão:
> 1. {regra} (persona: {ARQUIVO.md})
> 2. {regra} (persona: {ARQUIVO.md})
> Para cada uma: gravar como regra local deste projeto, gravar como
> pendência global (revisão no repo-fonte antes de valer pra outros
> projetos), ou ignorar?"

Se nenhuma regra foi identificada, este bloco não aparece. Falsos positivos
são esperados — o detector erra para o lado de "propor demais". Nada é
gravado sem confirmação explícita, regra a regra.

## Convenção: seção `## Aprendizados` nas personas

Quando o Bruno decide gravar a regra, ela vira um bullet datado numa seção
fixa:

```markdown
## Aprendizados
- <data>: <regra em forma imperativa>
```

- **Local** (só este projeto): a seção vive em `.agents/<PERSONA>.md`
  (instalado) e, se existir, `.agents/skills/<persona>/SKILL.md`.
- **Global** (repo-fonte, vale pra todo projeto futuro): a regra é
  adicionada à mesma seção em `agentes/<PERSONA>.md` (fonte) e em
  `gemini/skills/<persona>/SKILL.md`, via `/aprendizados-sync`, depois de
  aprovada.
- **Posicionamento** (lado Claude, instalado ou fonte): sempre imediatamente
  antes do bloco final (`---` + nota de ativação + linha de rodapé de
  modelo `` Modelo: definido pelo Orquestrador (ver `.agents/MODELOS.md`). ``)
  — nunca depois desse bloco. Se a seção ainda não existir no arquivo, é
  criada nesse ponto; se já existir, a regra nova é só mais um bullet. No
  lado Gemini (`SKILL.md`), que não tem a linha de rodapé de modelo, a
  seção fica imediatamente antes do bloco final (`---` + nota de ativação).
- **Fila de pendências globais** (`.agents/.aprendizados-globais-pendentes.md`,
  só existe quando pelo menos uma regra "global" foi decidida numa sessão
  fora do repo-fonte): dado de projeto, nunca tocado pelo instalador —
  agrupado por persona-alvo, processado por `/aprendizados-sync
  <caminho-do-projeto>` rodado no repo-fonte. Formato:

  ```markdown
  ## <PERSONA>.md
  - <data> (projeto: <nome-do-projeto>): <regra em forma imperativa>
  ```
- **Sob `/init-project --update`**: um arquivo de persona-fonte que carrega
  uma seção `## Aprendizados` local é uma customização como qualquer outra
  — o `init-manifest-diff.sh` vai classificá-lo como `PRESERVE` (arquivo não
  recebe mais atualizações de template automaticamente) ou `CONFLICT`
  (gera um `.new` pra merge manual), igual a qualquer outro arquivo de
  persona modificado localmente. Isso é comportamento documentado, não uma
  surpresa silenciosa.
