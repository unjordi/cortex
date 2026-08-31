#!/usr/bin/env bash
# limpiar-ramas.sh — barre las RAMAS LOCALES ya integradas de ESTE repo: BORRA las que su MR se mergeó
# (típicamente con --squash, y el remoto se borró al cerrar → localmente quedan `: gone`) y CONSERVA las
# que tienen trabajo sin integrar. Antídoto ESTRUCTURAL a la acumulación de ramas squasheadas: el squash
# rompe la detección de "mergeada" de `git branch -d` (la rama no queda de ancestro) y `fetch --prune`
# NO borra ramas locales → nadie las barría y se acumulaban (un caso real: 60+ en un repo).
#   uso: limpiar-ramas.sh [--dry-run] [--no-fetch]   (desde cualquier lugar del repo)
#
# SEGURO: reusa la MISMA lógica "zombie" que limpiar-worktrees (lib ramas-zombie.sh) — conserva ante
# CUALQUIER duda (rama nunca pusheada, con commits únicos, o squash multi-commit no-emparejable). NUNCA
# toca la rama actual, la base de integración, develop/main, las mini-develop (Develop*) ni keep/*.
set -u
DRY=0; FETCH=1
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --no-fetch) FETCH=0 ;;
    *) echo "limpiar-ramas: opción desconocida '$a' (usa --dry-run / --no-fetch)" >&2; exit 2 ;;
  esac
done
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "limpiar-ramas: no es un repo git" >&2; exit 1; }
# shellcheck source=ramas-zombie.sh
. "$(dirname "$0")/ramas-zombie.sh"

# fetch --prune: refresca los refs remotos (surface de las remotas ya borradas) para que la detección de
# "remota borrada" sea fiel. Se puede saltar (--no-fetch) si estás offline o ya lo corriste.
[ "$FETCH" = 1 ] && git -C "$ROOT" fetch --all --prune -q 2>/dev/null

base="$(bz_resolver_base "$ROOT")"
actual="$(git -C "$ROOT" symbolic-ref --short -q HEAD 2>/dev/null || true)"
# Ramas checked-out en CUALQUIER worktree: git rehúsa `branch -D` sobre ellas (protección propia de git).
# Se protegen explícitamente para que el reporte no diga "borraría" algo que nunca se borraría — sobre todo
# ahora que la señal (d) 'PR mergeado' caza ramas integradas que siguen checked-out en el worktree del dev.
wt_ramas="$(git -C "$ROOT" worktree list --porcelain 2>/dev/null | sed -n 's#^branch refs/heads/##p')"

# Ramas NUNCA candidatas a borrar, pase lo que pase (bases, checked-out en un worktree, y guardadas a propósito).
protegida() {  # $1 = rama
  case "$1" in
    "$base"|"$actual"|develop|main|Develop*|keep/*) return 0 ;;
  esac
  [ -n "$wt_ramas" ] && printf '%s\n' "$wt_ramas" | grep -qxF "$1" && return 0
  return 1
}

# Remoto configurado (upstream) de una rama; vacío si no tiene → cae a 'origin'. Se consulta ANTES del
# `branch -D` (tras borrar la rama local su @{upstream} ya no resuelve).
rama_remoto() {  # $1 = rama → nombre del remoto
  local up
  up=$(git -C "$ROOT" rev-parse --abbrev-ref "$1@{upstream}" 2>/dev/null) && [ -n "$up" ] && { printf '%s' "${up%%/*}"; return 0; }
  printf 'origin'
}

# 1a — LIMPIEZA COMPLETA: tras borrar el zombie LOCAL, si su rama REMOTA AÚN cuelga, bórrala también. Un
# MR squash-mergeado SIN --delete-branch/--remove-source-branch deja la remota huérfana; las señales (a)/(c)/(d)
# de bz_es_zombie declaran zombie CON la remota todavía presente → aquí se cierra ese hueco. SOLO se ejecuta
# dentro de la rama zombie (ya probada integrada, NO trabajo-vivo): una rama CONSERVADA jamás llega aquí, así
# que nunca se toca la remota de trabajo sin integrar. FAIL-OPEN total: sin red/permiso → ls-remote o push
# fallan → skip + log, NUNCA aborta el barrido.
barrer_remota() {  # $1 = rama zombie   $2 = nombre del remoto (capturado ANTES del branch -D)
  local br="$1" remoto="$2"
  [ -n "$remoto" ] || return 0
  if [ "$DRY" = 1 ]; then
    git -C "$ROOT" ls-remote --exit-code --heads "$remoto" "$br" >/dev/null 2>&1 \
      && echo "  [dry] remota aún cuelga → borraría: $remoto/$br"
    return 0
  fi
  # ls-remote --exit-code: 0 si la remota EXISTE (hay que borrarla); ≠0 si ya no está o no hay red → skip.
  git -C "$ROOT" ls-remote --exit-code --heads "$remoto" "$br" >/dev/null 2>&1 || return 0
  if git -C "$ROOT" push "$remoto" --delete "$br" >/dev/null 2>&1; then
    echo "  remota borrada: $remoto/$br"
  else
    echo "  (remota $remoto/$br cuelga pero no se pudo borrar — ¿sin red/permiso? se omite)"
  fi
}

borradas=0; conservadas=0
while IFS= read -r br; do
  [ -z "$br" ] && continue
  protegida "$br" && continue
  if bz_es_zombie "$ROOT" "$br" "$base"; then
    remoto_pre="$(rama_remoto "$br")"   # capturar el upstream ANTES del branch -D (después ya no resuelve)
    if [ "$DRY" = 1 ]; then echo "  [dry] integrada → borraría: $br"; borradas=$((borradas+1)); barrer_remota "$br" "$remoto_pre"
    else
      if git -C "$ROOT" branch -D "$br" >/dev/null 2>&1; then
        borradas=$((borradas+1)); echo "  borrada: $br"
        barrer_remota "$br" "$remoto_pre"
      fi
    fi
  else
    conservadas=$((conservadas+1)); echo "  CONSERVADA (trabajo sin integrar): $br"
  fi
done < <(git -C "$ROOT" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)

echo "limpiar-ramas: $borradas integrada(s)$([ "$DRY" = 1 ] && echo ' (dry-run, no borradas)'), $conservadas con trabajo conservada(s). Base: $base."
