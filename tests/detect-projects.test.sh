#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../agentes/scripts" && pwd)"
DETECT="$SCRIPT_DIR/detect-projects.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# Estrutura que espelha o achado real em podesubir: agrupadores sem
# marcador, projetos reais em profundidades 2 e 3, um marcador secundário
# sem .git, e um node_modules que deve ser sempre ignorado.
mkdir -p "$FIXTURE/company/principal/ymci-backend/.git"
touch "$FIXTURE/company/principal/principal.code-workspace"
mkdir -p "$FIXTURE/company/principal/apps/podesubir-app/.git"
mkdir -p "$FIXTURE/company/gateways/access-gateway-x/.git"
mkdir -p "$FIXTURE/company/gateways/access-gateway-x/vendor/weird/.git"
mkdir -p "$FIXTURE/company/standalone-tool"
touch "$FIXTURE/company/standalone-tool/package.json"
mkdir -p "$FIXTURE/company/node_modules/some-pkg/.git"

actual="$(bash "$DETECT" "$FIXTURE/company")"
expected="$FIXTURE/company/gateways/access-gateway-x
$FIXTURE/company/principal/apps/podesubir-app
$FIXTURE/company/principal/ymci-backend
$FIXTURE/company/standalone-tool"

if [[ "$actual" == "$expected" ]]; then
  echo "PASS: detect-projects encontrou exatamente os 4 projetos esperados"
else
  echo "FAIL: saída não bate"
  echo "--- esperado ---"; echo "$expected"
  echo "--- obtido ---"; echo "$actual"
  exit 1
fi

# Caso 2: raiz já é um projeto (tem .git direto) -> retorna só ela, não desce
mkdir -p "$FIXTURE/solo/.git"
mkdir -p "$FIXTURE/solo/sub/outro/.git"
actual2="$(bash "$DETECT" "$FIXTURE/solo")"
if [[ "$actual2" == "$FIXTURE/solo" ]]; then
  echo "PASS: raiz com .git próprio não desce mais"
else
  echo "FAIL: esperado só '$FIXTURE/solo', obtido: $actual2"
  exit 1
fi

# Caso 3: nada encontrado -> saída vazia, exit 0 (quem decide o aviso ao
# usuário é o comando que chama o script, não o script)
mkdir -p "$FIXTURE/vazio/sub1/sub2"
actual3="$(bash "$DETECT" "$FIXTURE/vazio")"
if [[ -z "$actual3" ]]; then
  echo "PASS: nenhum projeto encontrado -> saída vazia"
else
  echo "FAIL: esperado saída vazia, obtido: $actual3"
  exit 1
fi
