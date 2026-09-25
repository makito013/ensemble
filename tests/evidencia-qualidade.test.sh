#!/usr/bin/env bash
# Pacote "Qualidade com evidência": Dev verifica antes de entregar, QA
# classifica falhas sem pular testes, Revisor só reprova defeito com
# evidência — nas personas-fonte e nos espelhos Gemini.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check() {
  local file="$1" pattern="$2" label="$3"
  if [[ ! -f "$file" ]]; then
    echo "FAIL: $file não existe"
    fail=1
    return
  fi
  if ! grep -qF -- "$pattern" "$file"; then
    echo "FAIL: $file não contém '$pattern' ($label)"
    fail=1
    return
  fi
  echo "PASS: $label"
}

check_absent() {
  local file="$1" pattern="$2" label="$3"
  if grep -qF -- "$pattern" "$file"; then
    echo "FAIL: $file ainda contém '$pattern' ($label)"
    fail=1
  else
    echo "PASS: $label"
  fi
}

for f in "$ROOT/agentes/DEV.md" "$ROOT/gemini/skills/dev/SKILL.md"; do
  check "$f" '## Verificação obrigatória antes de entregar' "${f#"$ROOT"/}: seção de verificação obrigatória"
  check "$f" '### Verificação' "${f#"$ROOT"/}: relatório tem seção Verificação"
  check "$f" 'Proibido declarar concluído com algum comando falhando' "${f#"$ROOT"/}: proíbe entregar com verificação falhando"
  check "$f" 'Nunca invente resultado' "${f#"$ROOT"/}: não inventa resultado"
  check "$f" '## Modo retrabalho' "${f#"$ROOT"/}: seção modo retrabalho"
  check "$f" '(red → green)' "${f#"$ROOT"/}: teste do cenário antes da implementação"
  check "$f" '### Tarefas do TL' "${f#"$ROOT"/}: entrega lista tarefas do TL"
  check_absent "$f" 'Código funcional antes de perfeito' "${f#"$ROOT"/}: sem 'funcional antes de perfeito… depois refina'"
done

for f in "$ROOT/agentes/QA.md" "$ROOT/gemini/skills/qa/SKILL.md"; do
  check "$f" '## Tratamento de falha' "${f#"$ROOT"/}: seção de tratamento de falha"
  check "$f" '**Bug no código**' "${f#"$ROOT"/}: classifica bug no código"
  check "$f" '**Teste errado**' "${f#"$ROOT"/}: classifica teste errado"
  check "$f" '**Ambiente**' "${f#"$ROOT"/}: classifica ambiente"
  check "$f" 'Nunca apague, pule (`skip`) ou afrouxe asserção' "${f#"$ROOT"/}: proíbe skip/afrouxar asserção"
  check "$f" '"não medida"' "${f#"$ROOT"/}: cobertura só se medida"
  check "$f" 'Regressão na suíte existente' "${f#"$ROOT"/}: regressão reprova"
done

for f in "$ROOT/agentes/REVISOR.md" "$ROOT/gemini/skills/revisor/SKILL.md"; do
  check "$f" '## Não reportar' "${f#"$ROOT"/}: lista Não reportar"
  check "$f" '## Evidência obrigatória' "${f#"$ROOT"/}: exige evidência"
  check "$f" 'Bloqueante sem evidência é rebaixado a ressalva' "${f#"$ROOT"/}: rebaixa bloqueante sem evidência"
  check "$f" '**Só defeito reprova (❌)**' "${f#"$ROOT"/}: só defeito reprova"
  check "$f" '## Verificação antes de julgar' "${f#"$ROOT"/}: roda verificação antes de julgar"
  check "$f" 'somente leitura' "${f#"$ROOT"/}: Revisor é somente leitura"
  check "$f" 'o artefato NÃO muda entre' "${f#"$ROOT"/}: artefato não muda entre rodadas"
  check_absent "$f" 'blocker-rigor' "${f#"$ROOT"/}: blocker-rigor eliminado"
  check_absent "$f" 'próxima passada ou que exige ação do Dev' "${f#"$ROOT"/}: sem 'Revisor resolve na próxima passada'"
done

for f in "$ROOT/agentes/ORQUESTRADOR.md" "$ROOT/gemini/skills/orquestrador/SKILL.md"; do
  check "$f" 'Só **reprovação** volta ao Dev: ❌ do QA, ❌ do Revisor ou 🔴 da Segurança.' "${f#"$ROOT"/}: loop de retrabalho só em reprovação, inclui QA"
  check "$f" 'dispara retrabalho — as ressalvas vão para o resumo final como dívida' "${f#"$ROOT"/}: ressalva nunca dispara retrabalho"
  check "$f" 'copiado literalmente' "${f#"$ROOT"/}: feedback copiado literalmente ao Dev"
  # Contrato novo do Revisor (lentes + verificador): o veredito final sai do
  # verificador; se a 1ª linha não for o header canônico, redispara 1x e
  # depois trata como ❌ e escala.
  check "$f" 'Fail-safe do verificador' "${f#"$ROOT"/}: fail-safe do verificador"
  check "$f" 'redispare o verificador' "${f#"$ROOT"/}: redispara o verificador 1x"
  check "$f" 'trate como ❌ e escale' "${f#"$ROOT"/}: depois do redisparo, ❌ e escala"
  check_absent "$f" '[REVISOR] Lacuna' "${f#"$ROOT"/}: Revisor sem header de rodada de lacuna"
done

exit $fail
