#!/usr/bin/env bash
# git-branch-guard.sh — WRAPPER delgado sobre analizar-comando-git.sh. Bloquea (deny) push/merge a una
# rama protegida (develop/main) y redirige al flujo ramita→MR→develop. NO pregunta: bloquea la acción
# incorrecta. La LÓGICA de "qué toca una base" vive en la lib (fuente ÚNICA de los git-guards → no
# divergen). Fail-open ante parseo. Vive en <repo>/.claude/hooks/ (viaja por git) y ~/.claude (por máquina).
# Releases develop→main = acción de release deliberada; normalmente el humano en la web de GitLab, por
# CLI solo con OK súper-explícito (lo vigila confirmar-merge-develop). Este guard bloquea el PUSH a base.
#
# Cubre (via lib): push explícito a develop/main, push PELÓN/`HEAD`/`--force` estando EN develop/main
# (H1), ignora menciones entrecomilladas (H13) y valores de --repo/-R (repo llamado …/develop, H11).

# dedupe doble-cableado: si soy la copia del REPO y la copia GLOBAL existe, cedo (la global maneja esta
# invocación) → evita disparo doble; en un clon SIN bootstrap (sin copia global) la del repo sí corre.
case "$0" in "$HOME/.claude/hooks/"*) : ;; *) [ -f "$HOME/.claude/hooks/$(basename "$0")" ] && exit 0 ;; esac

input=$(cat)
# M7 (auditoría 2026-09-15 §2.3, homologación): SIN jq no podemos parsear el input para gatear con
# precisión -- pero un comando que PARECE un push/merge a base NO debe pasar SIN gate. Antes: fail-open
# SILENCIOSO (evasión asimétrica idéntica a la que confirmar-merge-develop ya cerró con A3 -- "un PATH sin
# jq apaga la norma más absoluta del sistema"). Grep CRUDO del input (sin comillas del JSON despojadas,
# pero 'git … push'/'push … develop|main'/merge de MR bastan como SUPERSET conservador): si aparece,
# DENY con causa clara (más ESTRICTO, no afloja nada); si NO parece lo que este guard vigila, exit 0 (no
# sobre-bloquea comandos normales). El mensaje se arma con printf (no jq, justo porque no hay jq).
if ! command -v jq >/dev/null 2>&1; then
  if printf '%s' "$input" | grep -qE 'git[[:space:]]+push|(mr[[:space:]]+(merge|accept)|pr[[:space:]]+merge)'; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"FRENO (sin jq): no puedo verificar si este push/merge toca develop/main sin jq instalado, y NUNCA se hace push/merge directo a develop/main (fail-safe, no afloja nada). Instala jq (macOS: brew install jq · Debian/Ubuntu: apt install jq · Windows: winget install jqlang.jq) e reintenta. Si esto NO tocaba develop/main, resuélvelo por el flujo de ramitas de todos modos -- no hay forma de confirmarlo sin jq."}}'
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
# y el push/merge PASA sin gate). Se prueba el source en un SUBSHELL primero: si truena ahí, el crash queda
# AISLADO (el proceso padre sigue vivo) y este guard falla RUIDOSO y CERRADO en vez de esfumarse. Snippet
# IDÉNTICO en los 5 guards; a propósito FUERA de la lib (si la lib está rota, sourcear otro archivo para
# blindarse de ella no sirve de nada).
_ACGLIB="$(dirname "$0")/analizar-comando-git.sh"
if [ -f "$_ACGLIB" ] && ( . "$_ACGLIB" ) >/dev/null 2>&1; then
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
# confirmar-merge-develop) o se ARREGLA, JAMÁS se rodea mandando a la persona a hacerlo a mano en la web.
if acg_push_toca_base "$cmd" "$pcwd"; then
  block "NORMA DE GIT (ley interna): no se hace push a main/develop (incluye el push PELÓN estando parado EN develop/main). NO reintentes esto. Haz el cambio por el flujo: ramita (feat/fix/chore/docs) desde develop → commit → push de la ramita → MR/PR → merge a develop. A main solo llega un release deliberado, con OK súper-explícito por CLI (lo vigila confirmar-merge-develop)."
fi

if acg_merge_menciona_base "$cmd"; then
  block "NORMA DE GIT (ley interna): este comando nombra un merge directo a develop/main. NO lo hagas así. El trabajo se integra por el flujo: ramita → MR → develop (con OK expreso, lo vigila confirmar-merge-develop). A main = release deliberado, con OK súper-explícito por CLI (también confirmar-merge-develop). NO reintentes el merge que nombra la base."
fi

exit 0
