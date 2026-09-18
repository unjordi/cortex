#!/usr/bin/env bash
# git-branch-guard.sh — WRAPPER delgado sobre analizar-comando-git.sh. Bloquea (deny) push/merge a una
# rama protegida (develop/main) y redirige al flujo ramita→MR→develop. NO pregunta: bloquea la acción
# incorrecta. La LÓGICA de "qué toca una base" vive en la lib (fuente ÚNICA de los git-guards → no
# divergen). Fail-open ante parseo. Vive en <repo>/.claude/hooks/ (viaja por git) y ~/.claude (por máquina).
# Releases develop→main = acción de release deliberada; normalmente el humano en la web de GitLab, por
# CLI solo con OK súper-explícito (lo vigila merge-develop-guard). Este guard bloquea el PUSH a base.
#
# Cubre (via lib): push explícito a develop/main, push PELÓN/`HEAD`/`--force` estando EN develop/main
# (H1), ignora menciones entrecomilladas (H13) y valores de --repo/-R (repo llamado …/develop, H11).

# dedupe doble-cableado: si soy la copia del REPO y la copia GLOBAL existe, cedo (la global maneja esta
# invocación) → evita disparo doble; en un clon SIN bootstrap (sin copia global) la del repo sí corre.
case "$0" in "$HOME/.claude/hooks/"*) : ;; *) [ -f "$HOME/.claude/hooks/$(basename "$0")" ] && exit 0 ;; esac

input=$(cat)

_ACGLIB="$(dirname "$0")/analizar-comando-git.sh"
# H1 (auditoría semántica 2026-09-16, ALTO): extrae el valor LITERAL del campo "command" del JSON (nunca
# el blob crudo completo) -- acota a un rango entre comillas que respeta escapes (\. | [^"\]), el mismo
# patrón estándar de extracción de cadena JSON. Usado SOLO en el carril sin-jq (con jq, se usa jq de verdad).
_json_campo_command() {
  printf '%s' "$1" | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"((\\.|[^"\\])*)".*/\1/p' | head -1
}
_json_campo_cwd() {
  printf '%s' "$1" | sed -nE 's/.*"cwd"[[:space:]]*:[[:space:]]*"((\\.|[^"\\])*)".*/\1/p' | head -1
}

if ! command -v jq >/dev/null 2>&1; then
  # ALTO-2 (auditoría FMEA 2026-09-16 §1.4): sin jq, bloquear TODO push (incluida tu propia ramita/mini-
  # develop) deja al operador SIN CARRIL.
  # H1 (auditoría semántica 2026-09-16, CONFIRMADO): la corrección ORIGINAL de ALTO-2 razonaba sobre el
  # JSON CRUDO completo (sin extraer el comando), así que un campo "description" que solo MENCIONA
  # "develop" ("Empujar la ramita del MR a develop") bastaba para bloquear un push a una ramita legítima --
  # exactamente la mordida que ALTO-2 existía para eliminar. Fix de raíz: extraer SOLO el campo "command"
  # (arriba) y, si se logra, reusar la MISMA función `acg_push_toca_base`/`acg_merge_menciona_base` del
  # camino CON jq (ninguna de las dos necesita jq: son texto+git puro) -- PARIDAD exacta con el camino
  # normal, no una heurística propia más laxa o más estricta.
  _cmd_sinjq=$(_json_campo_command "$input")
  _cwd_sinjq=$(_json_campo_cwd "$input")
  _sinjq_ok=0
  if [ -n "$_cmd_sinjq" ] && [ -f "$_ACGLIB" ] && bash -n "$_ACGLIB" >/dev/null 2>&1; then
    # shellcheck source=analizar-comando-git.sh
    . "$_ACGLIB"
    if command -v acg_push_toca_base >/dev/null 2>&1; then
      _sinjq_ok=1
      if acg_push_toca_base "$_cmd_sinjq" "$_cwd_sinjq" || acg_merge_menciona_base "$_cmd_sinjq"; then
        printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"FRENO (sin jq): sin jq instalado igual pude leer el comando real (no el JSON crudo) y SÍ toca develop/main -- NUNCA se hace push/merge directo a develop/main (fail-safe, no afloja nada). Si esto es TU PROPIA ramita/mini-develop y estás seguro de que no toca develop/main, exporta CLAUDE_GIT_GUARD_SIN_JQ_PERSONAL=1 en el ENTORNO de la sesión (no como prefijo del comando: este hook corre en un proceso aparte) y reintenta -- o instala jq (macOS: brew install jq · Debian/Ubuntu: apt install jq · Windows: winget install jqlang.jq)."}}'
      fi
    fi
  fi
  if [ "$_sinjq_ok" = 0 ]; then
    # Fallback conservador (no se pudo extraer 'command' del JSON, o la lib no cargó): mismo superset de
    # SIEMPRE sobre el input crudo -- más ruidoso que el camino de arriba, pero JAMÁS dispara MENOS.
    [ "${CLAUDE_GIT_GUARD_SIN_JQ_PERSONAL:-}" = "1" ] && exit 0
    if printf '%s' "$input" | grep -qE 'git[[:space:]]+push|(mr[[:space:]]+(merge|accept)|pr[[:space:]]+merge)'; then
      printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"FRENO (sin jq): no pude extraer el comando del JSON del hook, y NUNCA se hace push/merge directo a develop/main sin poder verificarlo (fail-safe, no afloja nada). Si esto es TU PROPIA ramita/mini-develop, exporta CLAUDE_GIT_GUARD_SIN_JQ_PERSONAL=1 en el ENTORNO de la sesión (no como prefijo del comando) y reintenta -- o instala jq."}}'
    fi
  fi
  exit 0
fi
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0
# PRE-FILTRO barato (superset conservador, mismo espíritu que proteger-arbol.sh): todo lo que este
# guard vigila requiere 'git'/'glab'/'gh' en el comando crudo → sin eso, early-exit ANTES de gastar
# sed/grep/source-lib. Jamás salta un caso real (a lo más sigue de más).
case "$cmd" in *git*|*glab*|*gh*) : ;; *) exit 0 ;; esac
# cwd del payload = working dir REAL del comando (puede diferir de CLAUDE_PROJECT_DIR, fijo al arranque de
# la sesión). Es la señal correcta para el caso PELÓN cross-repo (un `git push` corre en el cwd, no en el
# repo de la sesión). Ausente/no confiable → vacío → acg_target_dir cae a CLAUDE_PROJECT_DIR (conducta de hoy).
pcwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)

# CRÍTICO-1 (auditoría FMEA 2026-09-16 §1.1, CONFIRMADO): sourcear un archivo con error de SINTAXIS mata el
# proceso ENTERO con exit 1 -- que el harness trata como NO-bloqueante (silencio total: el guard desaparece
# y el push/merge PASA sin gate). H7 (auditoría semántica 2026-09-16, BAJO): la sonda ORIGINAL sourceaba la
# lib en un subshell y trataba CUALQUIER exit≠0 como "lib rota" -- pero el código de salida de un `source`
# es el del ÚLTIMO comando de la lib, no un diagnóstico de sintaxis: un `false`/grep-sin-match al final de
# una lib PERFECTAMENTE válida (bash -n la aprueba) bastaba para declarar "error de sintaxis" y tumbar el
# guard a deny-total, con un mensaje que manda a `bash -n` y este CONTESTARÍA que está bien. Fix: `bash -n`
# ES el veredicto de sintaxis (solo PARSEA, nunca ejecuta -- inmune al código de salida de runtime), y si
# pasa, el `source` real ya no puede tronar por sintaxis. Snippet IDÉNTICO en los 5 guards; a propósito
# FUERA de la lib (si la lib está rota, sourcear otro archivo para blindarse de ella no sirve de nada).
if [ -f "$_ACGLIB" ] && bash -n "$_ACGLIB" >/dev/null 2>&1; then
  # shellcheck source=analizar-comando-git.sh
  . "$_ACGLIB"
else
  printf '%s: analizar-comando-git.sh no cargó (ausente o con error de sintaxis) -- este guard queda SIN su lógica de detección; `bash -n "%s"` localiza el error.\n' "$(basename "$0")" "$_ACGLIB" >&2
  if printf '%s' "$cmd" | grep -qE 'push|merge'; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"FRENO (lib rota): analizar-comando-git.sh no cargó (error de sintaxis) y sin ella no puedo verificar si esto toca develop/main -- fail-safe, no afloja nada. Repara la lib (bash -n analizar-comando-git.sh la localiza) y reintenta; NUNCA hagas push/merge directo a develop/main mientras tanto."}}'
  fi
  exit 0
fi

block() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# M8 (auditoría 2026-09-15 §3.11, norma dura anti-vein-popper): se RETIRÓ "normalmente el humano en la web
# de GitLab" de ambos mensajes — un guard que frena en CLI se SATISFACE (con OK súper-explícito, lo vigila
# merge-develop-guard) o se ARREGLA, JAMÁS se rodea mandando a la persona a hacerlo a mano en la web.
#
# H5 (auditoría de ejecución 2026-09-16 §H5, BAJO-MEDIO): la SIEMBRA de un repo/rama base VACÍA (0 commits)
# es la ÚNICA excepción que la norma global declara para un push directo a base ("si un repo no tiene
# develop, créalo") — y hasta aquí este guard no la distinguía de un push normal, SIN escape cuando jq está
# presente (el único escape existente, CLAUDE_GIT_GUARD_SIN_JQ_PERSONAL, solo se lee en la rama sin-jq).
# Escape EXPLÍCITO y auditado (mismo espíritu que CLAUDE_SKIP_SECRET_SCAN), acotado a ESTE chequeo (nunca a
# `acg_merge_menciona_base`, que no tiene nada que ver con sembrar): el operador CONFIRMA que este push es
# la siembra inicial, no una integración saltándose el flujo. Se exporta en el ENTORNO de la sesión (perfil
# de shell / bloque "env" de ~/.claude/settings.json) — un prefijo inline en el propio comando de Bash NO
# llega al proceso de este hook (son procesos distintos), así que nunca es auto-servible por un agente a
# mitad de turno sin que el humano ya lo haya puesto ahí.
if [ "${CLAUDE_GIT_GUARD_SEED:-}" != "1" ] && acg_push_toca_base "$cmd" "$pcwd"; then
  block "NORMA DE GIT (ley interna): no se hace push a main/develop (incluye el push PELÓN estando parado EN develop/main). NO reintentes esto. Haz el cambio por el flujo: ramita (feat/fix/chore/docs) desde develop → commit → push de la ramita → MR/PR → merge a develop. A main solo llega un release deliberado, con OK súper-explícito por CLI (lo vigila merge-develop-guard). Si esto es la SIEMBRA inicial de un repo/rama vacía (0 commits — la única excepción de la norma), exporta CLAUDE_GIT_GUARD_SEED=1 en el ENTORNO de la sesión (no como prefijo del comando) y reintenta."
fi

if acg_merge_menciona_base "$cmd"; then
  block "NORMA DE GIT (ley interna): este comando nombra un merge directo a develop/main. NO lo hagas así. El trabajo se integra por el flujo: ramita → MR → develop (con OK expreso, lo vigila merge-develop-guard). A main = release deliberado, con OK súper-explícito por CLI (también merge-develop-guard). NO reintentes el merge que nombra la base."
fi

exit 0
