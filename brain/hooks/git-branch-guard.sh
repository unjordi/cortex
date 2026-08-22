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

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
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

# shellcheck source=analizar-comando-git.sh
. "$(dirname "$0")/analizar-comando-git.sh"

block() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

if acg_push_toca_base "$cmd" "$pcwd"; then
  block "NORMA DE GIT (ley interna): no se hace push a main/develop (incluye el push PELÓN estando parado EN develop/main). NO reintentes esto. Haz el cambio por el flujo: ramita (feat/fix/chore/docs) desde develop → commit → push de la ramita → MR/PR → merge a develop. A main solo llega un release deliberado: normalmente el humano en la web de GitLab; por CLI solo con OK súper-explícito (lo vigila confirmar-merge-develop)."
fi

if acg_merge_menciona_base "$cmd"; then
  block "NORMA DE GIT (ley interna): este comando nombra un merge directo a develop/main. NO lo hagas así. El trabajo se integra por el flujo: ramita → MR → develop (con OK expreso, lo vigila confirmar-merge-develop). A main = release deliberado: normalmente el humano en la web de GitLab; por CLI solo con OK súper-explícito (también confirmar-merge-develop). NO reintentes el merge que nombra la base."
fi

exit 0
