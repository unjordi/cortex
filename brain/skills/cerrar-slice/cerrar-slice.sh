#!/usr/bin/env bash
# cerrar-slice.sh — MAQUINARIA DETERMINISTA del merge de un slice a develop. Es el ÚNICO ejecutable del skill
# `cerrar-slice`: el SKILL.md se queda con el JUICIO (¿está LISTO? ¿el mensaje cuenta el cambio neto?) e INVOCA
# este script para el CÓMO. Baja a UN comando la integración correcta y la BLINDA contra los errores que el
# guard `merge-develop-guard` frena a mano: fuerza `--squash`, JAMÁS `--auto`/`--auto-merge` (merge INMEDIATO,
# no encolado en MWPS), borra la rama de origen (`--remove-source-branch` glab / `--delete-branch` gh), y EXIGE
# que el `--squash-message` traiga la traza rama→commit (Rama: … / MR|PR: …). Mapea glab↔gh (recetas gemelas).
#
# POR QUÉ UN SCRIPT (patrón reubicar-master.sh): la receta vivía SOLO como bloque de markdown en el SKILL.md y
# en el mensaje de varios guards — copiada, y por tanto driftando (un flag aquí, otro allá). La maquinaria vive
# en UN dueño (este archivo); el markdown y el guard la INVOCAN/APUNTAN, no la re-enuncian. Fuente única del
# comando de merge = fin del drift.
#
# ALCANCE: integración coordinada a `develop` (con squash). Un RELEASE `develop→main` es OTRO acto, deliberado y
# SIN squash (conserva historia) — este script lo REHÚSA a propósito y te remite al flujo de release.
#
# AUTORIZACIÓN: este script hace cumplir los checks DETERMINISTAS (squash/no-auto/rastro/borra-rama). La
# definición de LISTO (el OK EXPRESO del usuario para integrar) es el Paso 3 del SKILL.md y responsabilidad de
# quien invoca — igual que el guard `merge-develop-guard` la exige cuando tecleas el `glab mr merge` a mano.
#
#   USO   cerrar-slice.sh --id <id> (--message-file <f> | --message "<txt>") [--forge glab|gh] [--repo <slug>]
#                         [--branch <feat/…>] [--wait-ci] [--dry-run]
set -u

_uso() { cat <<'USO'
cerrar-slice.sh — arma el merge de un slice a develop (squash, INMEDIATO, sin --auto, con rastro).

  cerrar-slice.sh --id <id> --message-file <resumen.md> [opciones]
  cerrar-slice.sh --id <id> --message "<título curado>\n\ncuerpo…\nRama: feat/x\nMR: !12" [opciones]

  --id <id>            id del MR (glab) / PR (gh) a integrar. REQUERIDO.
  --message-file <f>   archivo con el resumen curado del squash (recomendado: --message "$(cat f)" queda inline).
  --message "<txt>"    resumen curado inline (alternativa a --message-file).
  --forge glab|gh      forge a usar. Default: autodetecta (glab/gh en PATH + remoto origin); si ambos, glab.
  --repo <slug>        org/grupo/repo LITERAL (no una $VAR). Se pasa a glab -R / gh -R.
  --branch <feat/…>    nombre de la ramita (informativo; para el rastro si el mensaje no lo trae — NO lo inventa).
  --wait-ci            espera a que el pipeline/checks del MR estén en verde ANTES de mergear (acotado).
  --dry-run            imprime el comando exacto y NO lo ejecuta.
  -h|--help            esta ayuda.

Reglas que hace cumplir (las mismas del guard merge-develop-guard):
  · SIEMPRE --squash (a develop = 1 commit limpio por slice).
  · NUNCA --auto/--auto-merge (merge YA, no encolado en MWPS sin testigo).
  · SIEMPRE borra la rama de origen (--remove-source-branch / --delete-branch).
  · El mensaje DEBE traer traza: una línea "Rama: <…>" y una "MR:/PR: !<id>" (o #<id>), y ≥12 palabras.
USO
}

_err() { printf 'cerrar-slice: %s\n' "$1" >&2; exit 1; }

# ── parseo de args ──
ID=""; MSG=""; MSG_FILE=""; FORGE=""; REPO=""; BRANCH=""; WAIT_CI=0; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --id)            ID="${2:-}"; shift 2 ;;
    --message)       MSG="${2:-}"; shift 2 ;;
    --message-file)  MSG_FILE="${2:-}"; shift 2 ;;
    --forge)         FORGE="${2:-}"; shift 2 ;;
    --repo)          REPO="${2:-}"; shift 2 ;;
    --branch)        BRANCH="${2:-}"; shift 2 ;;
    --wait-ci)       WAIT_CI=1; shift ;;
    --dry-run)       DRY=1; shift ;;
    --auto|--auto-merge)
      _err "--auto/--auto-merge está PROHIBIDO: la integración a develop es INMEDIATA, nunca encolada (MWPS). Quítalo." ;;
    -h|--help)       _uso; exit 0 ;;
    *)               _err "opción desconocida: $1 (usa --help)" ;;
  esac
done

[ -n "$ID" ] || _err "falta --id <id del MR/PR>."
# el id debe ser un entero (sin # ni $VAR) — un valor opaco no se resuelve en el forge.
case "$ID" in ''|*[!0-9]*) _err "--id debe ser un ENTERO literal (ej. 42), no '$ID' — nada de #, \$VAR ni comodines." ;; esac
# el --repo, si se da, debe ser un SLUG LITERAL (no una variable de shell sin expandir).
case "$REPO" in *'$'*|*'`'*) _err "--repo trae una variable de shell sin expandir ('$REPO'): pásale el SLUG LITERAL (ej. org/grupo/repo)." ;; esac

# ── mensaje del squash (inline o archivo) ──
if [ -n "$MSG_FILE" ]; then
  [ -f "$MSG_FILE" ] || _err "el --message-file '$MSG_FILE' no existe."
  MSG="$(cat "$MSG_FILE")"
fi
[ -n "$MSG" ] || _err "falta el resumen del squash: pásalo con --message \"…\" o --message-file <f>."

# ── validación del mensaje (los mismos pisos del guard: rastro + sustancia) ──
# traza rama→commit: una línea Rama: <…> Y una MR:/PR:/!id/#id. El squash BORRA el merge-commit con el #id →
# sin este rastro, `git log develop` no dice de qué ramita salió el commit.
printf '%s' "$MSG" | grep -qiE '(^|[[:space:]])rama[[:space:]]*:[[:space:]]*[^[:space:]]' \
  || _err "al resumen le falta la línea de traza \"Rama: <feat/…>\". (El squash borra el merge-commit con el #id → el rastro debe vivir en el mensaje.)"
printf '%s' "$MSG" | grep -qiE '((mr|pr)[[:space:]]*:[[:space:]]*[!#]?[0-9]+|[!#][0-9]+)' \
  || _err "al resumen le falta la referencia al MR/PR (\"MR: !<id>\" o \"PR: #<id>\")."
# sustancia mínima: ≥12 palabras (un resumen de una línea no cuenta el cambio neto y su porqué).
_nwords=$(printf '%s' "$MSG" | tr -s '[:space:]' '\n' | grep -c '[^[:space:]]' || true)
[ "${_nwords:-0}" -ge 12 ] || _err "el resumen es DEMASIADO CORTO ($_nwords palabras): escríbelo en prosa (el cambio neto y su porqué), ≥12 palabras."

# ── forge: autodetecta si no se dio ──
if [ -z "$FORGE" ]; then
  if command -v glab >/dev/null 2>&1; then FORGE=glab
  elif command -v gh >/dev/null 2>&1; then FORGE=gh
  else _err "no encuentro glab ni gh en el PATH; instala uno o pásalo con --forge."
  fi
fi
case "$FORGE" in glab|gh) : ;; *) _err "--forge debe ser glab o gh (dado: '$FORGE')." ;; esac
command -v "$FORGE" >/dev/null 2>&1 || _err "'$FORGE' no está en el PATH."

# ── espera de CI (opcional, acotada) — DECIDE por el ESTADO REAL del CI, no por el exit-code ──
# Causa del FP viejo: corría el chequeo 1× y ante CUALQUIER exit≠0 decía "sigo; revísalo tú" y mergeaba —
# confundía 4 casos (sin-CI / pendiente / rojo / no-pude-leer) en "procede". Ahora normaliza a UN veredicto
# y actúa: SINCI/VERDE → mergea · ROJO → ABORTA · PENDIENTE → espera (acotado) · INDET → ABORTA (no mergea a
# ciegas bajo --wait-ci; un problema de entorno NO se vuelve silencio). Sin --wait-ci, el comportamiento no cambia.
_ci_veredicto() {
  # mock para tests deterministas de la DECISIÓN (ambas direcciones), sin red/forge:
  if [ -n "${CLAUDE_CERRAR_SLICE_CI_MOCK:-}" ]; then printf '%s\n' "$CLAUDE_CERRAR_SLICE_CI_MOCK"; return 0; fi
  if [ "$FORGE" = gh ]; then
    local out
    out="$(gh pr checks "$ID" ${REPO:+-R "$REPO"} --json bucket 2>/dev/null)"
    if printf '%s' "$out" | jq -e 'type=="array"' >/dev/null 2>&1; then
      case "$out" in '[]') echo SINCI; return 0 ;; esac            # arreglo vacío = sin checks configurados
      if printf '%s' "$out" | jq -e 'any(.[]; .bucket=="fail" or .bucket=="cancel")' >/dev/null 2>&1; then echo ROJO; return 0; fi
      if printf '%s' "$out" | jq -e 'any(.[]; .bucket=="pending")' >/dev/null 2>&1; then echo PENDIENTE; return 0; fi
      echo VERDE; return 0                                         # resto = pass/skipping
    fi
    # sin JSON parseable: distingue "no hay checks" (sin-CI, se puede mergear) de un error real (INDET)
    gh pr checks "$ID" ${REPO:+-R "$REPO"} 2>&1 | grep -qi 'no checks' && { echo SINCI; return 0; }
    echo INDET; return 0
  else
    # glab: el estado del pipeline del MR sale de su JSON (.pipeline.status); .pipeline null = sin pipeline.
    # C1 (QA claudio 2026-10-13): si glab FALLA (sin red/token/ID malo) su salida NO es un objeto JSON → el
    # `jq … // "NONE"` viejo daba "" → SINCI → mergeaba A CIEGAS. Ahora, igual que el carril gh, se valida el
    # JSON ANTES: sin objeto parseable → INDET (un fallo de ENTORNO no se vuelve "procede"); SINCI SOLO con
    # JSON válido y `.pipeline == null` (pipeline no configurado).
    local out st
    out="$(glab mr view "$ID" ${REPO:+-R "$REPO"} -F json 2>/dev/null)"
    if ! printf '%s' "$out" | jq -e 'type=="object"' >/dev/null 2>&1; then echo INDET; return 0; fi
    if printf '%s' "$out" | jq -e '.pipeline == null' >/dev/null 2>&1; then echo SINCI; return 0; fi
    st="$(printf '%s' "$out" | jq -r '.pipeline.status // ""' 2>/dev/null)"
    case "$st" in
      success|skipped|manual)                                    echo VERDE ;;
      failed|canceled)                                           echo ROJO ;;
      created|pending|running|waiting_for_resource|preparing|scheduled) echo PENDIENTE ;;
      *)                                                         echo INDET ;;
    esac
  fi
}
if [ "$WAIT_CI" = 1 ]; then
  echo "cerrar-slice: --wait-ci — comprobando el CI del #$ID antes de mergear…" >&2
  _ci_max="${CERRAR_SLICE_CI_TIMEOUT:-600}"; _ci_step="${CERRAR_SLICE_CI_POLL:-15}"; _ci_slept=0
  while :; do
    _v="$(_ci_veredicto)"
    case "$_v" in
      SINCI) echo "cerrar-slice: el MR/repo no tiene pipeline/checks → nada que esperar, procedo." >&2; break ;;
      VERDE) echo "cerrar-slice: CI en verde → procedo al merge." >&2; break ;;
      ROJO)  _err "el CI del #$ID está en ROJO (un check falló/se canceló). NO mergeo bajo --wait-ci: arréglalo y reintenta." ;;
      INDET) _err "no pude determinar el estado del CI del #$ID (API/red/token). NO mergeo a ciegas bajo --wait-ci: deja que el CI sea legible (red/token) y reintenta." ;;
      PENDIENTE)
        [ "$_ci_slept" -ge "$_ci_max" ] && _err "el CI del #$ID sigue PENDIENTE tras ${_ci_max}s. NO mergeo bajo --wait-ci: espera a que termine y reintenta."
        echo "cerrar-slice: CI pendiente… reintento en ${_ci_step}s (llevo ${_ci_slept}s/${_ci_max}s)." >&2
        sleep "$_ci_step"; _ci_slept=$((_ci_slept + _ci_step)) ;;
      *) _err "veredicto de CI inesperado ('$_v') — no mergeo bajo --wait-ci." ;;
    esac
  done
fi

# ── arma el comando de merge (recetas GEMELAS glab↔gh) y lo corre INMEDIATO, SIN --auto ──
if [ "$FORGE" = glab ]; then
  set -- glab mr merge "$ID" --squash --squash-message "$MSG" --remove-source-branch --yes
  [ -n "$REPO" ] && set -- "$@" -R "$REPO"
else
  # gh: el subject es la 1ª línea; el body, el resto (la convención pone el resumen curado en el body).
  _subject="$(printf '%s\n' "$MSG" | sed -n '1p')"
  _body="$(printf '%s\n' "$MSG" | sed '1d' | sed -e '/./,$!d')"   # resto sin la 1ª línea, sin blancos iniciales (portable BSD+GNU)
  [ -n "$_body" ] || _body="$MSG"                                 # mensaje de una línea → el body es el mensaje entero (conserva la traza)
  set -- gh pr merge "$ID" --squash --delete-branch --subject "$_subject" --body "$_body"
  [ -n "$REPO" ] && set -- "$@" -R "$REPO"
fi

if [ "$DRY" = 1 ]; then
  printf 'cerrar-slice (dry-run) — correría:\n'
  printf '  %q' "$@"; printf '\n'
  exit 0
fi

echo "cerrar-slice: integrando el MR/PR #$ID a develop (squash, sin --auto, borrando la rama)…" >&2
"$@"
