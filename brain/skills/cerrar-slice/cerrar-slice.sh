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
  --forge glab|gh      forge a usar. Default: autodetecta por el HOST del remoto origin (github.com→gh,
                       *gitlab*→glab); host desconocido o sin origin → error (no adivina por la CLI instalada).
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

# Gate de gitleaks ANTES de integrar: escanea los commits del slice (origin/<base>..HEAD) y PARA si halla un
# secreto (reemplaza al hook secret-scan, retirado 2026-10-19). Las excepciones son por HUELLA y explícitas —
# `.gitleaksignore`/`.gitleaks.toml` del repo, que gitleaks lee solo—, NUNCA por palabra. Sin gitleaks
# instalado: avisa fuerte y NO bloquea (el CI de gitleaks es el backstop server-side).
_gitleaks_gate() {
  local base rng out head cur url
  if ! command -v gitleaks >/dev/null 2>&1; then
    printf 'cerrar-slice: ⚠️ gitleaks NO instalado — sin gate local de secretos (el CI lo corre server-side). Instálalo: brew install gitleaks · apt install gitleaks.\n' >&2
    return 0
  fi
  base="$(git rev-parse --verify -q origin/develop || git rev-parse --verify -q develop)" \
    || { printf 'cerrar-slice: no ubico origin/develop para el rango de gitleaks — omito el gate local (el CI lo cubre).\n' >&2; return 0; }

  # H18: --repo a OTRO repo → el scan de `.` (cwd) sería el repo EQUIVOCADO. No podemos verificar
  # localmente → avisa y NO declara "limpio" (el CI de gitleaks es el backstop server-side).
  if [ -n "$REPO" ]; then
    url="$(git remote get-url origin 2>/dev/null || true)"
    case "${url%.git}" in
      *"$REPO"*) : ;;
      *) printf 'cerrar-slice: ⚠️ --repo %s NO es el repo del directorio actual → el gate local de gitleaks escanearía otro repo; NO verifico aquí (el CI lo cubre). Para el gate local, córrelo desde el clon de %s.\n' "$REPO" "$REPO" >&2; return 0 ;;
    esac
  fi

  # H18 (FP 2026-10-20): escanea la RAMA DEL MR (lo que de verdad se integra), no el HEAD del cwd — que
  # puede ser develop/la mini/otra rama si cerrar-slice se corre SIN estar parado en la ramita → "limpio"
  # en falso. Resuelve la rama por --branch o por el forge; fetch + escanea origin/<base>..origin/<rama>.
  head="$BRANCH"
  if [ -z "$head" ]; then
    if [ "$FORGE" = gh ]; then
      head="$(gh pr view "$ID" ${REPO:+-R "$REPO"} --json headRefName -q .headRefName 2>/dev/null || true)"
    else
      head="$(glab mr view "$ID" ${REPO:+-R "$REPO"} -F json 2>/dev/null | jq -r '.source_branch // empty' 2>/dev/null || true)"
    fi
  fi
  if [ -n "$head" ]; then
    git fetch -q origin "$head" 2>/dev/null || true
    if   git rev-parse --verify -q "origin/$head" >/dev/null 2>&1; then rng="${base}..origin/$head"
    elif git rev-parse --verify -q "$head"        >/dev/null 2>&1; then rng="${base}..$head"
    else head=""   # la rama no está ni local ni en origin → cae al fallback de abajo
    fi
  fi
  if [ -z "$head" ]; then
    cur="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
    case "$cur" in
      develop|main|HEAD)
        _err "no pude resolver la rama del MR #$ID (sin --branch y sin poder leerla de $FORGE) y estás parado en '$cur', NO en la ramita → no puedo escanear los commits que se integrarán y NO declaro 'limpio' a ciegas. Párate en la ramita del MR, pásame --branch <feat/…>, o confía en el CI de gitleaks (backstop server-side)." ;;
      *) rng="${base}..HEAD" ;;   # parado EN una ramita → su HEAD sí es lo que se integra
    esac
  fi

  if ! out="$(gitleaks git . --log-opts="$rng" --redact --no-banner 2>&1)"; then
    printf '%s\n' "$out" | tail -20 >&2
    _err "gitleaks detectó un posible SECRETO en los commits del slice ($rng). NO integro. Saca el secreto (rótalo si ya se commiteó) o, si es un FALSO POSITIVO, agrégalo por HUELLA a .gitleaksignore/.gitleaks.toml y reintenta — nunca lo marques por palabra."
  fi
  printf 'cerrar-slice: gitleaks limpio en %s.\n' "$rng" >&2
}

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

# ── traza + sustancia del mensaje: AYUDA, no revisión (decisión unjordi 2026-10-21: el mensaje lo redacta
#    quien mergea; el candado merge-develop-guard solo RECUERDA, no frena por la calidad). cerrar-slice ARMA la
#    traza rama→commit si el redactor la omitió y ADVIERTE la sustancia, pero NUNCA aborta por el mensaje. El
#    squash borra el merge-commit con el #id → el rastro «Rama:/MR:» debe vivir en el mensaje para que
#    `git log develop` diga de qué ramita salió el commit; por eso lo agregamos nosotros si falta.
_warn() { printf 'cerrar-slice: %s\n' "⚠️  $1" >&2; }
# Decide el forge por el HOST del remoto origin, NO por "cuál CLI está instalada": en una Mac con glab
# instalado, un repo de GitHub (como cortex) NO debe usar glab. github.com→gh · *gitlab*→glab · host
# desconocido / sin origin → VACÍO (el llamador da un error claro; NO se adivina).
_forge_por_origin() {
  local url host
  url="$(git remote get-url origin 2>/dev/null || true)"
  [ -n "$url" ] || { printf ''; return 0; }
  host="$(printf '%s' "$url" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#^[^@/]*@##; s#[:/].*$##')"
  case "$host" in
    github.com|*.github.com) printf 'gh' ;;
    *gitlab*)                printf 'glab' ;;
    *)                       printf '' ;;
  esac
}
_fg="$FORGE"
[ -z "$_fg" ] && _fg="$(_forge_por_origin)"
# (a) líneas Rama: — una por CADA rama integrada en este merge: la FUENTE y toda SUB-RAMA CONTENIDA en ella
#     (tip ancestro de la fuente y NO de la base develop). ramas-zombie ya LEE múltiples `Rama:`; el ESCRITOR
#     era el eslabón roto (cerrar-slice solo nombraba la contenedora → las sub-ramas que entraron DENTRO de
#     una épica/integración quedaban "vivas" para siempre; medido 2026-10-22, 19 ramas). Se agrega SOLO la que
#     FALTE en el mensaje (no duplica las que el redactor ya puso). La señal por contenido de ramas-zombie es
#     la red para lo YA mergeado sin estas líneas.
_rama="$BRANCH"
if [ -z "$_rama" ] && [ "$_fg" = glab ]; then _rama="$(glab mr view "$ID" ${REPO:+-R "$REPO"} -F json 2>/dev/null | jq -r '.source_branch // empty' 2>/dev/null || true)"; fi
if [ -z "$_rama" ] && [ "$_fg" = gh ];   then _rama="$(gh pr view "$ID" ${REPO:+-R "$REPO"} --json headRefName -q .headRefName 2>/dev/null || true)"; fi
[ -z "$_rama" ] && _rama="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
_fuente=""
[ -n "$_rama" ] && [ "$_rama" != HEAD ] && _fuente="$(git rev-parse --verify -q "refs/heads/$_rama" 2>/dev/null || git rev-parse --verify -q "refs/remotes/origin/$_rama" 2>/dev/null || true)"
if [ -n "$_fuente" ]; then
  # fuente RESUELTA localmente → el conjunto CONTENIDO se puede computar: la fuente + cada rama cuyo tip es
  # ancestro de la fuente y NO de la base (= entró DENTRO de la fuente, no estaba ya en develop).
  _base="$(git rev-parse --verify -q origin/develop 2>/dev/null || git rev-parse --verify -q develop 2>/dev/null || true)"
  _contenidas="$_rama"
  if [ -n "$_base" ]; then
    while IFS=' ' read -r _bn _bt; do
      [ -n "$_bn" ] && [ -n "$_bt" ] || continue
      _nn="${_bn#origin/}"
      case "$_nn" in develop|main|HEAD|"$_rama") continue ;; esac
      case " $_contenidas " in *" $_nn "*) continue ;; esac
      git merge-base --is-ancestor "$_bt" "$_fuente" 2>/dev/null || continue   # tip contenido en la fuente
      git merge-base --is-ancestor "$_bt" "$_base"   2>/dev/null && continue   # … pero YA en develop → no es de este merge
      _contenidas="$_contenidas $_nn"
    done <<EOF
$(git for-each-ref --format='%(refname:short) %(objectname)' refs/heads refs/remotes/origin 2>/dev/null)
EOF
  fi
  _ya="$(printf '%s\n' "$MSG" | sed -nE 's/^[[:space:]]*[Rr]ama[[:space:]]*:[[:space:]]*([^[:space:]]+).*/\1/p' | tr '\n' ' ')"
  _added=""
  for _c in $_contenidas; do
    case " $_ya " in *" $_c "*) continue ;; esac
    MSG="$(printf '%s\nRama: %s' "$MSG" "$_c")"; _added="$_added $_c"
  done
  [ -n "$_added" ] && _warn "agregué traza «Rama:» para:${_added} (la fuente y sus sub-ramas contenidas); revísalas."
else
  # fuente NO resuelta localmente (solo del forge, o desconocida) → no se puede computar containment:
  # comportamiento clásico (nombrar la fuente, o avisar) SOLO si el mensaje no trae ya una línea Rama:.
  if ! printf '%s' "$MSG" | grep -qiE '(^|[[:space:]])rama[[:space:]]*:[[:space:]]*[^[:space:]]'; then
    if [ -n "$_rama" ] && [ "$_rama" != HEAD ]; then MSG="$(printf '%s\nRama: %s' "$MSG" "$_rama")"; _warn "agregué la traza «Rama: ${_rama}» (faltaba en el resumen); revísala."
    else _warn "al resumen le falta «Rama: <feat/…>» y no pude resolver la rama — agrégala a mano (sin ella, 'git log develop' no dice de qué ramita salió el commit)."; fi
  fi
fi
# (b) ref MR/PR — si falta, se ARMA con el --id (entero literal ya validado).
if ! printf '%s' "$MSG" | grep -qiE '((mr|pr)[[:space:]]*:[[:space:]]*[!#]?[0-9]+|[!#][0-9]+)'; then
  if [ "$_fg" = gh ]; then MSG="$(printf '%s\nPR: #%s' "$MSG" "$ID")"; _warn "agregué la referencia «PR: #${ID}» (faltaba)."
  else MSG="$(printf '%s\nMR: !%s' "$MSG" "$ID")"; _warn "agregué la referencia «MR: !${ID}» (faltaba)."; fi
fi
# (c) sustancia: ADVIERTE si <12 palabras (NO aborta — tú decides si el resumen cuenta el cambio neto y su porqué).
_nwords=$(printf '%s' "$MSG" | tr -s '[:space:]' '\n' | grep -c '[^[:space:]]' || true)
[ "${_nwords:-0}" -ge 12 ] || _warn "el resumen es CORTO ($_nwords palabras): idealmente cuenta el cambio neto y su porqué en prosa. No bloqueo."

# ── forge: autodetecta por el HOST del origin si no se dio (no por "cuál CLI está instalada") ──
if [ -z "$FORGE" ]; then
  FORGE="$(_forge_por_origin)"
  [ -n "$FORGE" ] || _err "no pude decidir el forge por el host del remoto origin ($(git remote get-url origin 2>/dev/null || echo 'sin origin')): no es github.com ni *gitlab*. Pásalo con --forge glab|gh."
fi
case "$FORGE" in glab|gh) : ;; *) _err "--forge debe ser glab o gh (dado: '$FORGE')." ;; esac
command -v "$FORGE" >/dev/null 2>&1 || _err "'$FORGE' no está en el PATH."

# ── base del MR/PR: cerrar-slice SOLO integra a DEVELOP (con squash). Un release develop→main es OTRO acto,
#    deliberado y SIN squash. El forge mergea al destino que el MR DECLARA (este script no lo fija), así que un
#    MR que apunta a main con `--squash --remove-source-branch` HARÍA el release aplastando la historia y
#    borrando la rama. Se resuelve el destino y se ABORTA si no es develop (C2, auditoría 2026-10-22). Base
#    IRRESOLUBLE (red/token/ID) → ABORTA (no mergeo a ciegas a un destino que no puedo verificar), igual que el
#    gate de CI (INDET → aborta). Mock para tests deterministas: CLAUDE_CERRAR_SLICE_BASE_MOCK.
_pr_base_branch() {
  if [ -n "${CLAUDE_CERRAR_SLICE_BASE_MOCK:-}" ]; then printf '%s\n' "$CLAUDE_CERRAR_SLICE_BASE_MOCK"; return 0; fi
  if [ "$FORGE" = gh ]; then
    gh pr view "$ID" ${REPO:+-R "$REPO"} --json baseRefName -q .baseRefName 2>/dev/null
  else
    glab mr view "$ID" ${REPO:+-R "$REPO"} -F json 2>/dev/null | jq -r '.target_branch // empty' 2>/dev/null
  fi
}
_base_dst="$(_pr_base_branch | sed -n '1p' | tr -d '[:space:]')"
case "$_base_dst" in
  develop) : ;;   # el ÚNICO destino que cerrar-slice integra
  '')          _err "no pude verificar la base del #$ID (API/red/token/ID). NO mergeo a ciegas: cerrar-slice SOLO integra a develop; deja el forge legible (--repo/--forge, red/token) y reintenta." ;;
  main|master) _err "el #$ID apunta a '$_base_dst' — eso es un RELEASE (develop→main), OTRO acto deliberado y SIN squash. cerrar-slice SOLO integra a develop; usa el flujo de release, no este script." ;;
  *)           _err "el #$ID apunta a '$_base_dst', no a develop. cerrar-slice SOLO integra a develop." ;;
esac

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
    # Si glab FALLA (sin red/token/ID malo) su salida NO es un objeto JSON → un
    # `jq … // "NONE"` daría "" → SINCI → mergearía A CIEGAS. Igual que el carril gh, se valida el
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
_gitleaks_gate   # secretos ANTES de integrar (para si halla; .gitleaksignore/.gitleaks.toml = excepción por huella)

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
