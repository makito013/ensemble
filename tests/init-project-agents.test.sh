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
check 'não apaga esse' ".agents/skills/ do Gemini nunca é apagada (instalação nova ou reinstalação)"

# Full reinstall (no --update): backup outside .agents/, overwrite only
# template files, keep project data in place.
check 'init-manifest-diff.sh backup' "passo 5 faz backup via script determinístico"
check 'init-manifest-diff.sh install' "instalação/reinstalação sobrescreve via script (só arquivos de template)"
check './.agents-backups/{YYYYMMDD-HHMMSS}/.agents/' "backup fica fora de .agents/ (em .agents-backups/<TS>/)"
check 'Nunca faça' "passo 5 proíbe mv/recriação de .agents/"
check 'PIPELINE-STATE.md' "lista PIPELINE-STATE.md como dado de projeto preservado"
check 'design-system/' "lista design-system/ como dado de projeto preservado"
check 'planos/' "lista planos/ como dado de projeto preservado"
check '.pipeline-history/' "lista .pipeline-history/ como dado de projeto preservado"
check '## Aprendizados' "reinstalação ainda restaura as seções de aprendizado local"
check 'init-manifest-diff.sh restore-learnings' "reinstalação restaura ## Aprendizados via script determinístico"
check 'LEARNINGS_CARRIED' "--update reporta os aprendizados locais carregados para a versão nova"
check 'init-manifest-diff.sh copy-skills' "adapter Antigravity copia skills preservando ## Aprendizados locais"
check 'LEGACY_BACKUPS' "backups legados .agents/.backup-* são só reportados"
check 'não\*\*' "backups legados não são movidos"
check '`.agents-backups/` ao final' ".gitignore ganha .agents-backups/"
check 'excluindo arquivos de teste' "arquivos *.test.* nunca vão para o projeto"

forbidden() {
  local pattern="$1" label="$2"
  if grep -q -- "$pattern" "$FILE"; then
    echo "FAIL: SKILL.md ainda contém '$pattern' ($label)"
    fail=1
  else
    echo "PASS: $label"
  fi
}
forbidden 'mv ./.agents ./.agents-old' "não move mais .agents/ inteira para um backup"
forbidden 'copie todo o conteúdo de `COMMANDS_DIR`' "não copia mais COMMANDS_DIR inteiro (levava *.test.sh)"
forbidden 'conteúdo de `TEMPLATE_DIR` para dentro' "não copia TEMPLATE_DIR inteiro (levaria testes de agentes/scripts/)"

exit $fail
