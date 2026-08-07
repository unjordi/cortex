#!/usr/bin/env bash
# detectar-shells.sh — LIB de INSTALACIÓN (NO es un hook; se hace `source`). Detecta, de forma
# CROSS-SHELL, los aliases/funciones que SOMBREAN un binario real en los shells POSIX INSTALADOS
# (zsh · bash · fish) de ESTA máquina, y arma el bloque LEAN del artefacto `~/.claude/aliases-activos.md`
# que el CLAUDE.md global importa con `@import` (siempre en contexto, sin costar líneas). La cara
# PowerShell la cubre install-brain.ps1 NATIVO (bloque `<!-- shells:powershell -->`); esta lib escribe
# SOLO el bloque `<!-- shells:posix -->`. En Windows (Git Bash) ambos coexisten sin pisarse.
#
# Por qué "sombrea un binario real" y no una lista fija de comandos: un alias MUERDE un comando de Claude
# ⇔ existe un binario homónimo en el PATH al que el alias le gana. Eso es lo que hay que saltar (con
# `command <cmd>`, NUNCA `/bin/<cmd>` — la ruta varía por OS; en fish `\<cmd>` tampoco salta funciones).
#
# La sigue el patrón de analizar-comando-git.sh: funciones puras + sourceable + testeable con fixtures
# (el core `ds_biting` recibe el dump y el verificador-de-sombra como parámetros → determinista sin tty).
# bash-3.2-safe (macOS). Fail-safe: un shell sin rc/tty devuelve vacío; un shell no instalado se excluye.
# shellcheck shell=bash

# ── Enumeración de shells INSTALADOS (de la terna POSIX que nos interesa) ──
# Uno por línea, en orden zsh·bash·fish. `command -v` = "¿está en el PATH?". Sin instalados → vacío.
ds_installed_shells() {
  local sh
  for sh in zsh bash fish; do
    command -v "$sh" >/dev/null 2>&1 && printf '%s\n' "$sh"
  done
}

# OS/arch en una línea (best-effort; fail-safe a "?").
ds_os_line() { uname -srm 2>/dev/null || printf '?'; }

# Vuelca los aliases del shell CARGANDO su rc (-i interactivo → lee .zshrc/.bashrc/config.fish).
# 2>/dev/null traga el ruido de un rc que imprime al arrancar y el "no tty". `|| true` = fail-safe.
ds_dump_aliases() { # <shell>
  local sh="$1" bin
  bin="$(command -v "$sh" 2>/dev/null)" || return 0
  [ -n "$bin" ] || return 0
  "$bin" -ic 'alias' 2>/dev/null || true
}

# Quita UNA capa de comillas envolventes (simples o dobles) de un valor de alias.
ds_unquote() { # <valor>
  local s="$1"
  case "$s" in
    \'*\') s="${s#\'}"; s="${s%\'}" ;;
    \"*\") s="${s#\"}"; s="${s%\"}" ;;
  esac
  printf '%s' "$s"
}

# Parseo POSIX (zsh/bash): líneas `name='valor'` / `name=valor`, con o sin prefijo `alias `.
# Emite `name<TAB>valor`. Descarta nombres no-identificador (ruido de un rc verboso).
ds_parse_posix() { # <dump>
  printf '%s\n' "$1" | sed -E 's/^[[:space:]]*alias[[:space:]]+//' \
  | while IFS= read -r line; do
      case "$line" in *=*) ;; *) continue ;; esac
      name="${line%%=*}"
      val="$(ds_unquote "${line#*=}")"
      case "$name" in ''|*[!A-Za-z0-9_.-]*) continue ;; esac
      [ -n "$val" ] || continue
      printf '%s\t%s\n' "$name" "$val"
    done
}

# Parseo fish: `alias name valor` (SIN `=`); tolera también `name=valor` por si la versión lo emite así.
# Regla: si hay `=` ANTES del primer espacio → split por `=`; si no → split por el primer espacio.
ds_parse_fish() { # <dump>
  printf '%s\n' "$1" | sed -E 's/^[[:space:]]*alias[[:space:]]+//' \
  | while IFS= read -r line; do
      [ -n "$line" ] || continue
      case "${line%% *}" in
        *=*) name="${line%%=*}"; val="${line#*=}" ;;
        *)   case "$line" in *' '*) name="${line%% *}"; val="${line#* }" ;; *) continue ;; esac ;;
      esac
      val="$(ds_unquote "$val")"
      case "$name" in ''|*[!A-Za-z0-9_.-]*) continue ;; esac
      [ -n "$val" ] || continue
      printf '%s\t%s\n' "$name" "$val"
    done
}

ds_parse() { # <format:posix|fish> <dump>
  case "$1" in fish) ds_parse_fish "$2" ;; *) ds_parse_posix "$2" ;; esac
}

# Verificador de SOMBRA REAL (default): `type -P` devuelve la ruta SOLO si el nombre resuelve a un
# ejecutable en disco (no a un builtin/función/alias). No-vacío ⇒ el alias sombrea un binario real.
# Universal (mismo test para aliases de zsh/bash/fish, ya que corremos en bash). Los tests inyectan
# un verificador FALSO con un set de binarios fixture → filtrado determinista sin depender del PATH.
ds_shadow() { # <nombre>
  [ -n "$(type -P "$1" 2>/dev/null)" ]
}

# CORE testeable: de un dump, deja SOLO los aliases cuyo nombre pasa el verificador-de-sombra.
# Emite `name<TAB>valor`. `$2` = nombre de la función verificadora (default `ds_shadow`).
ds_biting() { # <format> <shadow_fn> <dump>
  local fmt="$1" shadow="$2" dump="$3" name val
  ds_parse "$fmt" "$dump" | while IFS="$(printf '\t')" read -r name val; do
    "$shadow" "$name" && printf '%s\t%s\n' "$name" "$val"
  done
}

# Los aliases que MUERDEN en un shell instalado concreto (dump real + sombra real).
ds_biting_shell() { # <shell>
  local sh="$1" fmt="posix"
  [ "$sh" = fish ] && fmt="fish"
  ds_biting "$fmt" ds_shadow "$(ds_dump_aliases "$sh")"
}

# Lista densa "shells POSIX: zsh(login), bash" (marca cuál es el login shell).
ds_shells_csv() {
  local sh login csv=""
  login="$(basename "${SHELL:-}" 2>/dev/null)"
  for sh in $(ds_installed_shells); do
    if [ "$sh" = "$login" ]; then csv="${csv}${sh}(login), "; else csv="${csv}${sh}, "; fi
  done
  printf '%s' "${csv%, }"
}

# Los BULLETS de aliases-que-muerden: una línea densa por shell instalado + nota de globs de zsh.
# Reusado por el artefacto LEAN y por el bloque detectado de entorno-esta-maquina.md (sin duplicar OS).
ds_render_posix_bullets() {
  local sh bmap dense n v any=0
  printf 'Muerden (sombrean un binario real → salta con `command <cmd>`):\n'
  for sh in $(ds_installed_shells); do
    bmap="$(ds_biting_shell "$sh")"
    [ -n "$bmap" ] || continue
    any=1
    dense=""
    while IFS="$(printf '\t')" read -r n v; do
      [ -n "$n" ] || continue
      dense="${dense}\`${n}\`→\`${v}\` · "
    done <<EOF
$bmap
EOF
    dense="${dense% · }"
    printf -- '- %s: %s\n' "$sh" "$dense"
  done
  [ "$any" = 0 ] && printf -- '- (ningún alias muerde un binario en los shells instalados)\n'
  printf 'Globs en zsh: comíllalos.\n'
}

# CUERPO del bloque posix del artefacto LEAN (answer-first vive en el header): OS line + bullets.
ds_render_posix() {
  printf 'OS: `%s` · shells POSIX: %s\n' "$(ds_os_line)" "$(ds_shells_csv)"
  ds_render_posix_bullets
}

# ── Escritura del artefacto (idempotente, por bloques marcados independientes) ──
# Asegura el HEADER answer-first (escape PRIMERO) si el archivo no existe o le falta el marcador GENERADO.
# En Windows el .ps1 escribe el header (ASCII) ANTES de delegar a bash → aquí sólo se completa el posix.
ds_ensure_artifact_header() { # <file>
  local f="$1"
  if [ -f "$f" ] && grep -q 'GENERADO por install-brain' "$f" 2>/dev/null; then return 0; fi
  mkdir -p "$(dirname "$f")" 2>/dev/null || true
  {
    printf '<!-- GENERADO por install-brain — NO editar a mano; se regenera en cada bootstrap -->\n'
    printf '# Aliases activos de ESTA máquina (per-máquina; NO viaja por git)\n'
    printf '**Saltar un alias/función:** POSIX/fish → `command <cmd>` · PS → `& (gcm <cmd> -CommandType Application).Source`\n'
    printf '(NUNCA `/bin/<cmd>`: la ruta varía por OS. En fish `\\<cmd>` NO salta una función.)\n'
  } > "$f"
}

# UPSERT idempotente del bloque marcado `<!-- shells:<name>:INICIO/FIN -->`. Contenido por STDIN.
# Si el bloque existe → reemplaza su interior; si no → lo appendea. Preserva TODO lo demás (el otro
# bloque, el header) → posix y powershell no se pisan. Lee el contenido de un tmp con getline (no
# awk -v: -v interpreta escapes C y mutilaría un `\<cmd>`).
ds_upsert_block() { # <file> <name>   (contenido por STDIN)
  local f="$1" name="$2" begin end cfile tmp
  begin="<!-- shells:${name}:INICIO -->"
  end="<!-- shells:${name}:FIN -->"
  cfile="$(mktemp)" || return 1
  cat > "$cfile"
  [ -f "$f" ] || : > "$f"
  if grep -qF "$begin" "$f" 2>/dev/null && grep -qF "$end" "$f" 2>/dev/null; then
    tmp="$(mktemp)" || { rm -f "$cfile"; return 1; }
    if awk -v b="$begin" -v e="$end" -v cf="$cfile" '
        $0==b { print; while ((getline l < cf) > 0) print l; close(cf); skip=1; next }
        $0==e { skip=0; print; next }
        skip==1 { next }
        { print }
      ' "$f" > "$tmp" && [ -s "$tmp" ]; then
      mv "$tmp" "$f"
    else
      rm -f "$tmp" "$cfile"; return 1
    fi
  else
    { printf '%s\n' "$begin"; cat "$cfile"; printf '%s\n' "$end"; } >> "$f"
  fi
  rm -f "$cfile"
}
