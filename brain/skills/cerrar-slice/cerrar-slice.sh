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

# ── espera de CI (opcional, acotada) ──
if [ "$WAIT_CI" = 1 ]; then
  echo "cerrar-slice: esperando el pipeline/checks en verde antes de mergear…" >&2
  if [ "$FORGE" = glab ]; then
    glab ci status ${BRANCH:+--branch "$BRANCH"} ${REPO:+-R "$REPO"} 2>/dev/null || \
      echo "cerrar-slice: aviso — no pude leer el estado de CI (sigo; revísalo tú)." >&2
  else
    gh pr checks "$ID" ${REPO:+-R "$REPO"} 2>/dev/null || \
      echo "cerrar-slice: aviso — no pude leer los checks (sigo; revísalos tú)." >&2
  fi
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
