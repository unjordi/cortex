#!/usr/bin/env bash
# ramas-zombie.sh — LIB compartida (no se cablea; se hace `source`). Decide si una rama YA está integrada
# ("zombie") de forma robusta al flujo SQUASH, y resuelve la base de integración. La consumen
# `limpiar-worktrees.sh` (barre worktrees) y `limpiar-ramas.sh` (barre ramas locales) → una sola
# definición de "mergeada", sin divergencia (antídoto al drift entre los dos barredores).
#
# "Mergeada" es TRIPLE porque el flujo SQUASHEA (la rama NO queda de ancestro): (a) ancestro de la base
# (flujo merge-commit) O (b) la rama fue pusheada, su rama remota YA no existe (se borró al mergear con
# --delete-branch, típico del squash → localmente queda marcada `: gone`) Y NO trae commits propios sin
# integrar O (c) sus commits ya están en la base por EQUIVALENCIA de parche (git cherry) — el merge LOCAL
# a la rama personal (mini-develop) y los cherry-picks. Un squash de VARIOS commits a uno NO empareja
# patch-id → se CONSERVA (mejor un zombie de más que borrar trabajo vivo). Una rama NUNCA pusheada y sin
# equivalencia → se CONSERVA. La regla (b) NUNCA borra a ciegas: si la rama tiene commits propios no
# equivalentes a la base (git cherry marca '+'), se CONSERVA aunque su remota ya no exista — la ausencia
# de la remota no prueba integración, y el `branch -D` es irreversible (FMEA A5/MEDIO-3).

# bz_resolver_base ROOT → imprime la base de integración.
# La base es configurable (CLAUDE_INTEGRACION_BASE): en el flujo mini-develop NO es develop sino TU rama
# personal (convención `Develop<Usuario>`, p. ej. `DevelopAna`). Precedencia sin override:
#   1) HEAD parado en una mini-develop `Develop<Usuario>` → esa (es la base viva del dev).
#   2) una rama local `Develop<Usuario>` existe → esa (el día a día del dev vive en su mini-develop;
#      sus ramitas se integran a la mini, NO directo a develop — así el barrido las ve integradas).
#   3) fallback clásico: develop, o la rama por defecto del remoto, o main.
# Sin `Develop*` local (repo de flujo develop puro, p. ej. un solo-dev sobre develop) → cae a (3), intacto.
bz_resolver_base() {
  local ROOT="$1" base="${CLAUDE_INTEGRACION_BASE:-}" cur mini
  if [ -z "$base" ]; then
    # (1) HEAD en una mini-develop (Develop<Usuario>; case-sensitive, ≥1 char tras "Develop" → excluye
    #     el `develop` minúsculas y un `Develop` pelón).
    cur=$(git -C "$ROOT" symbolic-ref --short -q HEAD 2>/dev/null || true)
    case "$cur" in Develop?*) base="$cur" ;; esac
    # (2) preferir una mini-develop LOCAL si la hay (típicamente una sola por clon).
    if [ -z "$base" ]; then
      mini=$(git -C "$ROOT" for-each-ref --format='%(refname:short)' 'refs/heads/Develop*' 2>/dev/null | head -1)
      [ -n "$mini" ] && base="$mini"
    fi
    # (3) fallback: develop → rama por defecto del remoto → main.
    if [ -z "$base" ]; then
      base=develop
      git -C "$ROOT" rev-parse --verify -q refs/heads/develop >/dev/null 2>&1 \
        || base=$(git -C "$ROOT" symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null | sed 's#origin/##' || echo main)
    fi
  fi
  printf '%s' "$base"
}

# bz_es_zombie ROOT BR BASE → 0 si BR ya está integrada a BASE (zombie), 1 si conservar.
bz_es_zombie() {
  local ROOT="$1" br="$2" base="$3" up cherry
  git -C "$ROOT" merge-base --is-ancestor "$br" "$base" 2>/dev/null && return 0   # (a) ancestro de la base
  # (c) squash/cherry a la base: los commits de la rama ya están en base por EQUIVALENCIA de parche
  # (git cherry los marca '-'; NINGUNO '+').
  cherry=$(git -C "$ROOT" cherry "$base" "$br" 2>/dev/null)
  [ -n "$cherry" ] && ! printf '%s\n' "$cherry" | grep -q '^+' && return 0
  # (b) remota borrada — NUNCA a ciegas. La ausencia de la remota NO prueba que la rama esté integrada
  # (pudo borrarse por rename/limpieza manual, o traer commits VIVOS post-merge sin pushear). Si la rama
  # tiene commits PROPIOS no equivalentes a la base (git cherry marcó algún '+'), se CONSERVA aunque su
  # remota ya no exista: el `branch -D` de los barredores es irreversible y borraría ese trabajo. Antes
  # (b) declaraba zombie sin re-chequear commits únicos → PÉRDIDA DE DATOS (FMEA A5/MEDIO-3). El header
  # promete "conserva ante duda": aquí se hace cumplir — solo una rama SIN trabajo único cae a (b).
  printf '%s\n' "$cherry" | grep -q '^+' && return 1   # commits propios no integrados → conservar
  up=$(git -C "$ROOT" rev-parse --abbrev-ref "$br@{upstream}" 2>/dev/null) || return 1  # nunca pusheada → conservar
  git -C "$ROOT" ls-remote --exit-code --heads "${up%%/*}" "${up#*/}" >/dev/null 2>&1 && return 1 || return 0  # (b) remota borrada Y sin commits únicos → zombie
}
