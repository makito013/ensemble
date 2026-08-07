#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$ROOT/claude/skills/init-project/SKILL.md"
fail=0

check() {
  local pattern="$1" label="$2"
  if grep -q -- "$pattern" "$FILE"; then
    echo "PASS: $label"
  else
    echo "FAIL: SKILL.md não contém '$pattern' ($label)"
    fail=1
  fi
}

check './.agents/' "instala em ./.agents/ (oculta)"
check '.agents/PIPELINE.md' "usa .agents/PIPELINE.md como marca de instalação Claude"
check 'não apaga' ".agents/skills/ do Gemini não é apagada numa instalação nova"
check 'mv ./agentes ./.agents' "migra ./agentes legado com mv"
check 'reescreva as chaves do JSON' "migração reescreve as chaves do manifest (não regenera)"
check 'existirem ao mesmo tempo' "trata o conflito de ./agentes legado + .agents/PIPELINE.md coexistindo"
check '.gitignore' "documenta a automação do .gitignore"
check 'não crie o arquivo' ".gitignore não é criado quando não existe"
check 'Não trate a mera existência da' "migração é condicionada a PIPELINE.md nos dois lados, não à mera existência da pasta ./agentes/"
check 'Antigravity para de descobrir os skills' "atualização sem --update restaura .agents/skills/ do backup (não só CONTEXTO.md/TEAM.md)"

exit $fail
