#!/usr/bin/env bash
# agents-md-block.sh — insere/atualiza o bloco delimitado do pipeline dentro do
# AGENTS.md de um projeto-alvo.
#
# Existe como script (e não como prosa dentro do SKILL.md) porque AGENTS.md é
# arquivo VERSIONADO do projeto-alvo: preservação byte a byte fora dos
# marcadores e recusa em entradas ambíguas precisam ser testáveis, não
# interpretadas. Mesmo motivo de init-manifest-diff.sh existir.
#
# Uso:
#   agents-md-block.sh apply <agents_md_path> <block_source_path>
#
# Saída (stdout, uma linha):
#   CREATED=<path>    arquivo não existia e foi criado com o bloco
#   APPENDED=<path>   arquivo existia sem marcadores; bloco anexado ao final
#   UPDATED=<path>    miolo entre os marcadores substituído
#   UNCHANGED=<path>  já estava byte a byte igual; nada foi escrito
#
# Exit codes:
#   0  ok
#   2  erro de uso
#   3  marcadores em formato ambíguo — NADA foi escrito (ver stderr)
set -euo pipefail

BEGIN_MARKER='<!-- agentes-pipeline:begin -->'
END_MARKER='<!-- agentes-pipeline:end -->'

usage() {
  echo "Uso: agents-md-block.sh apply <agents_md_path> <block_source_path>" >&2
  exit 2
}

# Conta ocorrências do marcador (não linhas): dois marcadores na mesma linha
# também contam como duas. O `|| true` é obrigatório sob `set -o pipefail`:
# grep sai 1 quando não casa nada, e "nenhum marcador" é caso normal aqui.
count_marker() {
  local file="$1" marker="$2" hits=""
  hits="$(grep -F -o -- "$marker" "$file" 2>/dev/null || true)"
  [[ -n "$hits" ]] || { printf '0'; return 0; }
  # $(...) já removeu a newline final da saída do grep; sem devolvê-la aqui,
  # `wc -l` conta uma ocorrência a menos (bug corrigido: era `printf '%s'`).
  printf '%s\n' "$hits" | wc -l | tr -d '[:space:]'
}

first_marker_line() {
  local file="$1" marker="$2" hit=""
  hit="$(grep -F -n -- "$marker" "$file" 2>/dev/null || true)"
  printf '%s' "$hit" | head -1 | cut -d: -f1
}

# Verdadeiro quando a linha nº $2 do arquivo $1 contém SÓ o marcador $3.
# Tolera whitespace nas bordas e um `\r` final de CRLF (projeto-alvo Windows);
# rejeita qualquer outro texto na mesma linha. Motivo: head/tail recortam por
# linha inteira, então manter o bloco com uma linha tipo
# `<!-- ...:begin --> anotação do usuário` apagaria a anotação silenciosamente
# num arquivo VERSIONADO — marcador ambíguo → PARA, nunca adivinha.
marker_line_is_solo() {
  local file="$1" line_no="$2" marker="$3" content=""
  content="$(sed -n "${line_no}p" "$file")"
  content="${content%$'\r'}"
  content="${content#"${content%%[![:space:]]*}"}"   # trim à esquerda
  content="${content%"${content##*[![:space:]]}"}"   # trim à direita
  [[ "$content" == "$marker" ]]
}

# Bloco completo: marcador de abertura + corpo da fonte + marcador de
# fechamento. A fonte NUNCA contém os marcadores — quem os emite é este script,
# para que não haja como duplicá-los.
render_block() {
  local source_file="$1"
  printf '%s\n' "$BEGIN_MARKER"
  cat "$source_file"
  # Garante que o marcador de fechamento comece numa linha própria mesmo se a
  # fonte não terminar em newline. `$(...)` come as newlines finais, então a
  # saída vazia significa "último byte é \n".
  if [[ -s "$source_file" && -n "$(tail -c 1 "$source_file")" ]]; then
    printf '\n'
  fi
  printf '%s\n' "$END_MARKER"
}

cmd_apply() {
  local agents_md="$1" block_source="$2"
  local tmp

  if [[ ! -f "$block_source" ]]; then
    echo "ERRO: fonte do bloco não encontrada: $block_source" >&2
    exit 2
  fi

  if grep -F -q -- "$BEGIN_MARKER" "$block_source" || grep -F -q -- "$END_MARKER" "$block_source"; then
    echo "ERRO: a fonte do bloco ($block_source) já contém os marcadores. Ela deve conter só o miolo — os marcadores são emitidos por este script." >&2
    exit 2
  fi

  # --- arquivo inexistente: cria (diferente da regra do .gitignore, que nunca cria) ---
  if [[ ! -e "$agents_md" ]]; then
    mkdir -p "$(dirname "$agents_md")"
    render_block "$block_source" > "$agents_md"
    echo "CREATED=$agents_md"
    return 0
  fi

  if [[ ! -f "$agents_md" ]]; then
    echo "ERRO: $agents_md existe mas não é um arquivo regular. Resolva manualmente." >&2
    exit 2
  fi

  local begin_count end_count begin_line end_line
  begin_count="$(count_marker "$agents_md" "$BEGIN_MARKER")"
  end_count="$(count_marker "$agents_md" "$END_MARKER")"

  # --- formas ambíguas: PARE, nunca adivinhe onde o bloco começa/termina ---
  if [[ "$begin_count" -gt 1 || "$end_count" -gt 1 ]]; then
    echo "ERRO: $agents_md tem marcadores repetidos (begin=$begin_count, end=$end_count). Deixe exatamente um par e rode de novo — nada foi escrito." >&2
    exit 3
  fi

  if [[ "$begin_count" -ne "$end_count" ]]; then
    echo "ERRO: $agents_md tem marcador solitário (begin=$begin_count, end=$end_count). Não dá pra adivinhar onde o bloco termina — nada foi escrito." >&2
    exit 3
  fi

  # --- nenhum marcador: anexa ao final ---
  if [[ "$begin_count" -eq 0 ]]; then
    tmp="$(mktemp)"
    cat "$agents_md" > "$tmp"
    if [[ -s "$agents_md" ]]; then
      # Uma linha em branco antes do bloco, se o arquivo não terminar já em
      # branco. `$(...)` come as newlines finais: saída vazia = só newlines nos
      # últimos N bytes.
      if [[ -n "$(tail -c 1 "$agents_md")" ]]; then
        printf '\n\n' >> "$tmp"        # sem newline final
      elif [[ -n "$(tail -c 2 "$agents_md")" ]]; then
        printf '\n' >> "$tmp"          # termina em newline simples
      fi                               # senão: já termina em linha em branco
    fi
    render_block "$block_source" >> "$tmp"
    mv "$tmp" "$agents_md"
    echo "APPENDED=$agents_md"
    return 0
  fi

  # --- par completo: substitui só o miolo ---
  begin_line="$(first_marker_line "$agents_md" "$BEGIN_MARKER")"
  end_line="$(first_marker_line "$agents_md" "$END_MARKER")"

  # Marcador dividindo a linha com outro texto → forma ambígua, nada escrito.
  if ! marker_line_is_solo "$agents_md" "$begin_line" "$BEGIN_MARKER" \
     || ! marker_line_is_solo "$agents_md" "$end_line" "$END_MARKER"; then
    echo "ERRO: em $agents_md um marcador divide a linha com outro texto (linhas $begin_line e $end_line). Deixe cada marcador sozinho na sua linha e rode de novo — nada foi escrito." >&2
    exit 3
  fi

  if [[ "$begin_line" -ge "$end_line" ]]; then
    echo "ERRO: em $agents_md o marcador de fim aparece antes do de início (linhas $begin_line e $end_line). Ordem ambígua — nada foi escrito." >&2
    exit 3
  fi

  tmp="$(mktemp)"
  # head/tail preservam bytes exatamente, inclusive a ausência de newline final.
  head -n "$((begin_line - 1))" "$agents_md" > "$tmp"
  render_block "$block_source" >> "$tmp"
  tail -n "+$((end_line + 1))" "$agents_md" >> "$tmp"

  if cmp -s "$tmp" "$agents_md"; then
    rm -f "$tmp"
    echo "UNCHANGED=$agents_md"
    return 0
  fi

  mv "$tmp" "$agents_md"
  echo "UPDATED=$agents_md"
}

case "${1:-}" in
  apply)
    [[ $# -eq 3 ]] || usage
    cmd_apply "$2" "$3"
    ;;
  *)
    usage
    ;;
esac
