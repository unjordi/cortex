#!/usr/bin/env bash
# ramas-zombie.sh — LIB compartida (no se cablea; se hace `source`). Decide si una rama YA está integrada
# ("zombie") de forma robusta al flujo SQUASH, y resuelve la base de integración. La consumen
# `limpiar-worktrees.sh` (barre worktrees) y `limpiar-ramas.sh` (barre ramas locales) → una sola
# definición de "mergeada", sin divergencia (antídoto al drift entre los dos barredores).
#
# "Mergeada" es CUÁDRUPLE porque el flujo SQUASHEA (la rama NO queda de ancestro): (a) ancestro de la
# base (flujo merge-commit) O (d) su PR/MR se MERGEÓ en el host (señal AUTORITATIVA — ver abajo) O (c) sus
# commits ya están en la base por EQUIVALENCIA de parche (git cherry) — el merge LOCAL a la mini-develop y
# los cherry-picks O (b) la rama fue pusheada, su rama remota YA no existe (se borró al mergear con
# --delete-branch, típico del squash → `: gone`) Y NO trae commits propios sin integrar.
# EL HUECO QUE CIERRA (d): un squash de VARIOS commits a uno NO empareja patch-id → (c) no lo caza y (b)
# CONSERVA si git cherry marca algún '+' → antes las ramas mergeadas por MR-squash (¡la clase MÁS común de
# este flujo!) NUNCA se podaban y se acumulaban. La señal fiable no es git, es el HOST: (d) pregunta a
# gh/glab si el PR/MR de la rama se mergeó — si sí, sus commits están en la base aunque git no los empareje
# (y solo si el head mergeado CONTIENE el tip local, para no borrar trabajo post-merge). FAIL-OPEN: sin
# gh/glab, sin red, host no reconocido o error → (d) no aplica y se cae a las señales de git (conservador).
# Una rama NUNCA pusheada y sin equivalencia → se CONSERVA. La regla (b) NUNCA borra a ciegas: si la rama
# tiene commits propios no equivalentes a la base (git cherry marca '+'), se CONSERVA aunque su remota ya
# no exista — la ausencia de la remota no prueba integración, y el `branch -D` es irreversible (FMEA A5/MEDIO-3).

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

# --- Señal (d): ¿el PR/MR de la rama se MERGEÓ en el host? (autoritativa para el flujo SQUASH) --------
# Se consulta 1× por proceso (memoizado por ROOT). FAIL-OPEN total: sin gh/glab, sin red, host no
# reconocido o error → cache vacío → (d) no aplica → se cae a las señales de git. TEST: exporta
# CLAUDE_BZ_PRCACHE=<archivo con líneas 'rama<TAB>sha'> para inyectar el mapa de PRs mergeados sin red.
_BZ_PRCACHE_FILE=""; _BZ_PRCACHE_ROOT=""
_bz_run() {  # _bz_run SEGUNDOS cmd... — con timeout si existe (que un host colgado no cuelgue la poda)
  local t="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$t" "$@"; else "$@"; fi
}
_bz_cargar_prcache() {  # puebla $_BZ_PRCACHE_FILE (líneas 'rama<TAB>sha') para ROOT, una sola vez
  local ROOT="$1" url proj
  [ "$_BZ_PRCACHE_ROOT" = "$ROOT" ] && return 0
  _BZ_PRCACHE_ROOT="$ROOT"
  if [ -n "${CLAUDE_BZ_PRCACHE:-}" ]; then _BZ_PRCACHE_FILE="$CLAUDE_BZ_PRCACHE"; return 0; fi
  _BZ_PRCACHE_FILE="$(mktemp 2>/dev/null)" || { _BZ_PRCACHE_FILE=""; return 0; }
  # el temp es NUESTRO (no el inyectado) → limpiarlo al salir del proceso; ningún caller usa trap EXIT
  _BZ_PRCACHE_OWNED="$_BZ_PRCACHE_FILE"; trap 'rm -f "$_BZ_PRCACHE_OWNED" 2>/dev/null' EXIT
  url="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
  # path del proyecto desde el remoto (owner/repo o group/subgrupo/proyecto) → -R, sin `cd` (un `cd`
  # dispararía un hook chpwd del shell que contaminaría el cache; -R es además más robusto).
  proj="$(printf '%s' "$url" | sed -E 's#^[a-z]+://[^/]+/##; s#^[^@]+@[^:]+:##; s#\.git$##')"
  [ -n "$proj" ] || return 0
  case "$url" in
    *github*)
      command -v gh >/dev/null 2>&1 && _bz_run 15 gh -R "$proj" pr list --state merged --limit 300 \
        --json headRefName,headRefOid --jq '.[] | "\(.headRefName)\t\(.headRefOid)"' \
        >>"$_BZ_PRCACHE_FILE" 2>/dev/null ;;
    *gitlab*)
      command -v glab >/dev/null 2>&1 && _bz_run 15 glab mr list -R "$proj" -M --per-page 300 -F json \
        --jq '.[] | "\(.source_branch)\t\(.sha)"' \
        >>"$_BZ_PRCACHE_FILE" 2>/dev/null ;;
  esac
  return 0
}
# bz_pr_mergeado ROOT BR → 0 si el PR/MR de BR se mergeó y su head CONTIENE el tip actual de BR (todos sus
# commits integrados). Si BR trae commits MÁS ALLÁ del head mergeado (trabajo post-merge) → 1 (conservar).
bz_pr_mergeado() {
  local ROOT="$1" br="$2" oid
  _bz_cargar_prcache "$ROOT"
  [ -n "$_BZ_PRCACHE_FILE" ] && [ -s "$_BZ_PRCACHE_FILE" ] || return 1
  oid="$(awk -F'\t' -v b="$br" '$1==b{print $2; exit}' "$_BZ_PRCACHE_FILE" 2>/dev/null)"
  [ -n "$oid" ] || return 1
  git -C "$ROOT" merge-base --is-ancestor "$br" "$oid" 2>/dev/null   # tip de br ⊆ head mergeado → integrada
}

# bz_es_zombie ROOT BR BASE → 0 si BR ya está integrada a BASE (zombie), 1 si conservar.
bz_es_zombie() {
  local ROOT="$1" br="$2" base="$3" up cherry
  git -C "$ROOT" merge-base --is-ancestor "$br" "$base" 2>/dev/null && return 0   # (a) ancestro de la base
  bz_pr_mergeado "$ROOT" "$br" && return 0                                        # (d) PR/MR mergeado (host, autoritativo)
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
