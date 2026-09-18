#!/usr/bin/env bash
# limpiar-impl-ramas.sh — barre las ramas ya integradas de ESTE repo, en DOS pasadas: las LOCALES (BORRA las que
# su MR se mergeó —típicamente con --squash, y el remoto se borró al cerrar → localmente quedan `: gone`—
# y CONSERVA las que tienen trabajo sin integrar) y, después, las REMOTAS SIN CONTRAPARTE LOCAL. Antídoto
# ESTRUCTURAL a la acumulación de ramas squasheadas: el squash rompe la detección de "mergeada" de
# `git branch -d` (la rama no queda de ancestro) y `fetch --prune` NO borra ramas locales → nadie las
# barría y se acumulaban (un caso real: 60+ en un repo). Invócalo vía `limpiar.sh ramas` — es
# implementación interna del dispatcher `limpiar.sh` (antes el ejecutable suelto `limpiar-ramas.sh`,
# retirado 2026-09-17, ver MANIFEST).
#   uso: limpiar.sh ramas [--dry-run] [--no-fetch]   (desde cualquier lugar del repo)
#
# C-2 — SEGUNDA PASADA (remotas sin local): una rama viva en `origin` cuya local ya no existe era INVISIBLE
# (el bucle solo recorría `refs/heads`): ni barrida, ni conservada, ni contada como omitida. El flujo la
# produce constantemente (fan-out en worktrees efímeros, trabajo desde otra máquina, un `branch -D` local
# que no tocó la remota). Ahora se examinan con señales POSITIVAS squash-safe (a/e/d/c, nunca (b) — su
# premisa es "la remota ya no existe", justo lo contrario de lo que se evalúa), se borra solo lo demostrado
# residuo —y solo si su punta sigue siendo la evaluada—, y lo no integrado se conserva NOMBRÁNDOLO.
# Escape: LIMPIAR_RAMAS_SIN_REMOTAS=1.
#
# SEGURO: reusa la MISMA lógica "zombie" (bz_es_zombie) y "protegida" (bz_protegida) que limpiar-worktrees
# — lib ramas-zombie.sh — conserva ante CUALQUIER duda (rama nunca pusheada, con commits únicos, o squash
# multi-commit no-emparejable ni confirmable por el host). NUNCA toca la rama actual, la base de
# integración, develop/main, las mini-develop (Develop*) ni keep/*.
#
# A-1 (auditoría 2026-09-11, "no silent caps"): el resumen antes solo contaba borradas/conservadas y las
# protegidas desaparecían sin dejar rastro (`continue` antes de contar) — invitaba a leer N+M como el
# universo cuando en realidad podía haber más ramas protegidas fuera de la vista. Ahora se examinan TODAS
# y las omitidas se cuentan y NOMBRAN con su motivo en el resumen final.
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
BITA="$ROOT/.claude/memory/bitacora.md"
# shellcheck source=ramas-zombie.sh
. "$(dirname "$0")/ramas-zombie.sh"

# fetch --prune: refresca los refs remotos (surface de las remotas ya borradas) para que la detección de
# "remota borrada" sea fiel. Se puede saltar (--no-fetch) si estás offline o ya lo corriste.
[ "$FETCH" = 1 ] && git -C "$ROOT" fetch --all --prune -q 2>/dev/null

base="$(bz_resolver_base "$ROOT")"
# C-3 (dictamen 2026-09-17): sin una base que EXISTA, toda señal de integración falla muda y las ramas caen
# a la señal (b) — la destructiva. Abortar es la única lectura correcta de "no sé contra qué comparar".
if ! bz_base_valida "$ROOT" "$base"; then
  echo "limpiar-ramas: base de integración irresoluble ('$base') — NO se barre nada. Crea la base o exporta CLAUDE_INTEGRACION_BASE con una rama que exista, y reintenta." >&2
  exit 1
fi
bz_aviso="$(bz_aviso_base "$ROOT")"
[ -n "$bz_aviso" ] && echo "  (aviso: $bz_aviso — Base: $base)"   # M-2
actual="$(git -C "$ROOT" symbolic-ref --short -q HEAD 2>/dev/null || true)"
# Ramas checked-out en CUALQUIER worktree: git rehúsa `branch -D` sobre ellas (protección propia de git).
# Se protegen explícitamente para que el reporte no diga "borraría" algo que nunca se borraría — sobre todo
# ahora que la señal (d) 'PR mergeado' caza ramas integradas que siguen checked-out en el worktree del dev.
wt_ramas="$(git -C "$ROOT" worktree list --porcelain 2>/dev/null | sed -n 's#^branch refs/heads/##p')"

# Remoto configurado (upstream) de una rama; vacío si no tiene → cae a 'origin'. Se consulta ANTES del
# `branch -D` (tras borrar la rama local su @{upstream} ya no resuelve).
rama_remoto() {  # $1 = rama → nombre del remoto
  local up
  up=$(git -C "$ROOT" rev-parse --abbrev-ref "$1@{upstream}" 2>/dev/null) && [ -n "$up" ] && { printf '%s' "${up%%/*}"; return 0; }
  printf 'origin'
}

# _join SEP CUR NUEVO → concatena sin arrays (bash 3.2 + `set -u` no toleran "${arr[@]}" vacío en algunas
# versiones) — usado para las listas de nombres del resumen final.
_join() { [ -z "$2" ] && printf '%s' "$3" || printf '%s%s%s' "$2" "$1" "$3"; }

# 1a — LIMPIEZA COMPLETA: tras borrar el zombie LOCAL, si su rama REMOTA AÚN cuelga, bórrala también. Un
# MR squash-mergeado SIN --delete-branch/--remove-source-branch deja la remota huérfana; las señales
# a/e/d/c de bz_es_zombie declaran zombie CON la remota todavía presente → aquí se cierra ese hueco.
#
# C-1 (auditoría 2026-09-11, PÉRDIDA DE DATOS): antes se decidía con `ls-remote --exit-code` — que solo
# pregunta si la remota EXISTE, no QUÉ TIENE. Si la remota va adelante del tip local (un colega siguió
# trabajando en esa rama tras el squash, o simplemente estás atrasado), el push --delete borraba SU
# trabajo. Ahora se exige CONTAINMENT: el SHA remoto debe ser ANCESTRO del tip LOCAL (capturado ANTES del
# `branch -D`, cuando la rama local todavía resuelve). Si no se puede confirmar (objeto ausente, sin red,
# remota adelantada) → NO se borra, y se dice por qué.
barrer_remota() {  # $1 = rama zombie   $2 = nombre del remoto   $3 = SHA del tip LOCAL (antes de -D)
  local br="$1" remoto="$2" local_sha="$3" rout rc rsha
  [ -n "$remoto" ] || return 0
  rout="$(git -C "$ROOT" ls-remote --heads "$remoto" "$br" 2>/dev/null)"; rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "  (remota $remoto/$br: no se pudo consultar — ¿sin red/permiso? NO se borra)"
    return 0
  fi
  rsha="$(printf '%s' "$rout" | awk '{print $1; exit}')"
  [ -n "$rsha" ] || return 0   # la remota ya no existe → nada que hacer
  if [ -z "$local_sha" ] \
     || ! git -C "$ROOT" cat-file -e "${rsha}^{commit}" 2>/dev/null \
     || ! git -C "$ROOT" merge-base --is-ancestor "$rsha" "$local_sha" 2>/dev/null; then
    echo "  (remota $remoto/$br va ADELANTE del tip local o no se pudo verificar → NO se borra)"
    return 0
  fi
  if [ "$DRY" = 1 ]; then echo "  [dry] remota contenida en el tip local → borraría: $remoto/$br"; return 0; fi
  if git -C "$ROOT" push "$remoto" --delete "$br" >/dev/null 2>&1; then
    echo "  remota borrada: $remoto/$br"
  else
    echo "  (remota $remoto/$br cuelga pero no se pudo borrar — ¿sin red/permiso? se omite)"
  fi
}

# ── DETECTOR DE REPRESA: AVISO (NUNCA borra) de ramas que envejecen SIN integrarse ─────────────────
# A-4 (dictamen higiene de ramas 2026-09-17): recorriendo el ciclo actor por actor, la transición
# "rama pusheada → PR abierto" no la vigila NADIE — la rama se queda en `origin` sin PR y nadie lo nota.
# Tampoco un "PR cerrado SIN mergear": `bz_pr_mergeado` solo mira `--state merged`, así que un PR CLOSED es
# indistinguible de "sin PR" y se conserva mudo para siempre. Aquí no falló la escoba: falló el CIERRE, y
# barrer mejor no abre un PR. El detector que existía estaba gobernado por un patrón de NOMBRE
# (`worktree-agent-*`, la convención del harness) que NINGUNA rama de este repo matchea: estaba bien
# escrito y era INERTE en el repo donde vive. Ahora el criterio es el del problema real —"lleva N días sin
# actividad y no está integrada"—, aplicado a ramas LOCALES y REMOTAS, reportando además el estado del PR.
# El patrón de nombre sigue disponible como FILTRO OPCIONAL (LIMPIAR_RAMAS_PATRON_HUERFANA).
#
# Aquí NO se borra NADA — sería el único error inaceptable si la rama aún traía algo útil — solo se
# REPORTA, una vez por PUNTA (rama+sha, dedupe en un stamp por-repo), a la bitácora, para que un humano
# decida: abrir el MR/PR, mergear o descartar. Llega aquí SOLO lo que ya pasó `bz_protegida` y NO resultó
# integrado; y la edad mínima evita reportar trabajo todavía en curso.
HUERF_PATRON="${LIMPIAR_RAMAS_PATRON_HUERFANA:-*}"
HUERF_DIAS="${LIMPIAR_RAMAS_DIAS_HUERFANA:-14}"
case "$HUERF_DIAS" in ''|*[!0-9]*) HUERF_DIAS=14 ;; esac
HUERF_ESTADO="$ROOT/.claude/memory/.ramas-huerfanas-estado"
huerf_ya_reportada() {  # $1=branch $2=sha -> 0 si ESA punta ya se reportó (no repetir en cada corrida)
  [ -f "$HUERF_ESTADO" ] || return 1
  grep -qxF "$(printf '%s\t%s' "$1" "$2")" "$HUERF_ESTADO" 2>/dev/null
}
# $1 = rama conservada (no integrada, no protegida)   $2 = ref a medir (la rama local, o origin/<rama>)
reportar_represada_si_aplica() {
  local br="$1" ref="${2:-$1}" sha ts edad_dias estado
  case "$br" in $HUERF_PATRON) ;; *) return 0 ;; esac
  sha="$(git -C "$ROOT" rev-parse --short "$ref" 2>/dev/null)" || return 0
  ts="$(git -C "$ROOT" log -1 --format=%ct "$ref" 2>/dev/null)"; [ -n "$ts" ] || return 0
  edad_dias=$(( ($(date +%s) - ts) / 86400 ))
  [ "$edad_dias" -ge "$HUERF_DIAS" ] || return 0
  huerf_ya_reportada "$br" "$sha" && return 0
  huerfanas=$((huerfanas + 1))
  estado="$(bz_pr_estado "$ROOT" "$br")"
  if [ "$DRY" = 1 ]; then
    echo "  [dry] REPRESADA: sin integrar, ${edad_dias}d sin actividad, ${estado} → se reportaría: $ref"
    return 0
  fi
  [ -f "$BITA" ] && printf -- '- **[rama represada]** `%s` — %s día(s) sin actividad, sin integrar, %s. Decidir: abrir/retomar el MR/PR, mergear o descartar (NO se borra sola).\n' "$ref" "$edad_dias" "$estado" >> "$BITA" 2>/dev/null
  mkdir -p "$(dirname "$HUERF_ESTADO")" 2>/dev/null
  printf '%s\t%s\n' "$br" "$sha" >> "$HUERF_ESTADO" 2>/dev/null
  echo "  REPRESADA: sin integrar, ${edad_dias}d sin actividad, ${estado} → reportada a bitácora, NO borrada: $ref"
}

borradas=0; conservadas=0; total=0; huerfanas=0
omit_ba=0; omit_ba_n=""; omit_cv=0; omit_cv_n=""; omit_wt=0; omit_wt_n=""
while IFS= read -r br; do
  [ -z "$br" ] && continue
  total=$((total+1))
  if bz_protegida "$br" "$base" "$actual" "$wt_ramas"; then
    case "$BZ_PROT_RAZON" in
      base_actual) omit_ba=$((omit_ba+1)); omit_ba_n="$(_join ', ' "$omit_ba_n" "$br")" ;;
      convencion)  omit_cv=$((omit_cv+1)); omit_cv_n="$(_join ', ' "$omit_cv_n" "$br")" ;;
      worktree)    omit_wt=$((omit_wt+1)); omit_wt_n="$(_join ', ' "$omit_wt_n" "$br")" ;;
    esac
    continue
  fi
  if bz_es_zombie "$ROOT" "$br" "$base"; then
    remoto_pre="$(rama_remoto "$br")"
    local_sha="$(git -C "$ROOT" rev-parse "$br" 2>/dev/null || true)"
    if [ "$DRY" = 1 ]; then
      echo "  [dry] integrada → borraría: $br"; borradas=$((borradas+1)); barrer_remota "$br" "$remoto_pre" "$local_sha"
    else
      if git -C "$ROOT" branch -D "$br" >/dev/null 2>&1; then
        borradas=$((borradas+1)); echo "  borrada: $br"
        barrer_remota "$br" "$remoto_pre" "$local_sha"
      fi
    fi
  else
    if [ "$BZ_RAZON" = indeterminado ]; then
      conservadas=$((conservadas+1))
      echo "  INDETERMINADA (no pude consultar el foro: gh/glab no disponible o host no reconocido — se conserva): $br"
    else
      conservadas=$((conservadas+1)); echo "  CONSERVADA (trabajo sin integrar): $br"
    fi
    reportar_represada_si_aplica "$br"
  fi
done < <(git -C "$ROOT" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)

# ── SEGUNDA PASADA: ramas REMOTAS sin contraparte LOCAL ─────────────────────────────────────────────
# C-2 (dictamen higiene de ramas 2026-09-17, CAUSA RAÍZ #2 del reguero): el bucle de arriba recorre solo
# `refs/heads`, así que una rama que vive en `origin` y NO tiene rama local no se examina, no se barre y
# ni siquiera sale en el resumen como omitida — es invisible incluso para el reporte de "no silent caps".
# Medido: 12 de las 23 ramas de `origin` eran de esa clase (8 ya integradas + 4 con trabajo represado).
# Y el flujo las produce todo el tiempo: fan-out en worktrees efímeros, trabajo hecho desde otra máquina,
# o un `branch -D` local que no tocó la remota. `barrer_remota()` solo las alcanza si su LOCAL fue
# declarada zombie primero: sin local, no hay entrada al código.
#
# SEGURIDAD: solo se borra lo DEMOSTRADO residuo por una señal POSITIVA squash-safe (bz_remota_integrada:
# a/e/d/c, nunca (b)), y solo tras re-verificar contra el remoto que su punta sigue siendo EXACTAMENTE la
# que evaluamos — si avanzó desde el último fetch, o no se puede consultar, se CONSERVA. Lo no integrado
# nunca se borra: se nombra. Escape: LIMPIAR_RAMAS_SIN_REMOTAS=1.
rem_exam=0; rem_borradas=0; rem_cons=0; rem_cons_n=""; rem_omit=0
if [ "${LIMPIAR_RAMAS_SIN_REMOTAS:-0}" != 1 ]; then
  for remoto in $(git -C "$ROOT" remote 2>/dev/null); do
    while IFS= read -r br; do
      [ -z "$br" ] && continue
      [ "$br" = "HEAD" ] && continue                 # el puntero de rama por defecto, no una rama
      rref="$remoto/$br"
      # ¿tiene contraparte local? entonces ya la evaluó (y, si tocaba, la barrió) la primera pasada.
      git -C "$ROOT" rev-parse --verify -q "refs/heads/$br" >/dev/null 2>&1 && continue
      if bz_protegida "$br" "$base" "" ""; then rem_omit=$((rem_omit+1)); continue; fi
      rem_exam=$((rem_exam+1))
      # base a comparar: la REMOTA si existe (es la que de verdad refleja lo integrado en el servidor;
      # si la local va adelante con merges sin pushear, usar la remota CONSERVA más) — si no, la local.
      baseref="$base"
      git -C "$ROOT" rev-parse --verify -q "refs/remotes/$remoto/$base" >/dev/null 2>&1 && baseref="$remoto/$base"
      if bz_remota_integrada "$ROOT" "$br" "$rref" "$baseref"; then
        if [ "$DRY" = 1 ]; then
          echo "  [dry] remota sin local, integrada (señal $BZ_RRAZON) → borraría: $rref"; rem_borradas=$((rem_borradas+1))
        else
          eval_sha="$(git -C "$ROOT" rev-parse "$rref" 2>/dev/null || true)"
          live_out="$(git -C "$ROOT" ls-remote --heads "$remoto" "$br" 2>/dev/null)"; live_rc=$?
          live_sha="$(printf '%s' "$live_out" | awk '{print $1; exit}')"
          if [ "$live_rc" -ne 0 ]; then
            echo "  (remota $rref: no se pudo consultar — ¿sin red/permiso? NO se borra)"
          elif [ -z "$live_sha" ]; then
            echo "  (remota $rref ya no existe en el servidor — nada que borrar)"
          elif [ -z "$eval_sha" ] || [ "$live_sha" != "$eval_sha" ]; then
            echo "  (remota $rref AVANZÓ desde el último fetch → NO se borra: solo se borra la punta evaluada)"
          elif git -C "$ROOT" push "$remoto" --delete "$br" >/dev/null 2>&1; then
            rem_borradas=$((rem_borradas+1)); echo "  remota sin local borrada (señal $BZ_RRAZON): $rref"
          else
            echo "  (remota $rref cuelga pero no se pudo borrar — ¿sin red/permiso? se omite)"
          fi
        fi
      else
        rem_cons=$((rem_cons+1)); rem_cons_n="$(_join ', ' "$rem_cons_n" "$rref")"
        echo "  CONSERVADA (remota sin local, trabajo sin integrar): $rref"
        reportar_represada_si_aplica "$br" "$rref"
      fi
    done < <(git -C "$ROOT" for-each-ref --format='%(refname:strip=3)' "refs/remotes/$remoto" 2>/dev/null)
  done
fi

omit_total=$((omit_ba+omit_cv+omit_wt))
detalle=""
[ "$omit_ba" -gt 0 ] && detalle="$(_join '; ' "$detalle" "$omit_ba base/actual: $omit_ba_n")"
[ "$omit_cv" -gt 0 ] && detalle="$(_join '; ' "$detalle" "$omit_cv protegida(s) por convención: $omit_cv_n")"
[ "$omit_wt" -gt 0 ] && detalle="$(_join '; ' "$detalle" "$omit_wt retenida(s) por worktree: $omit_wt_n")"

resumen="limpiar-ramas: examinadas $total de $total → $borradas integrada(s)$([ "$DRY" = 1 ] && echo ' (dry-run, no borradas)'), $conservadas con trabajo conservada(s), $huerfanas represada(s) reportada(s) (nunca borradas)"
[ "$omit_total" -gt 0 ] && resumen="$resumen, $omit_total omitida(s) ($detalle)"
# C-2: las remotas SIN contraparte local son un universo aparte — se cuentan y se nombran aquí para que el
# "examinadas N de N" de arriba no se lea como si fuera el total del repo (antes ni existían para el reporte).
resumen="$resumen. Remotas sin local: $rem_exam examinada(s) → $rem_borradas integrada(s)$([ "$DRY" = 1 ] && echo ' (dry-run, no borradas)'), $rem_cons con trabajo conservada(s)"
[ "$rem_cons" -gt 0 ] && resumen="$resumen ($rem_cons_n)"
[ "$rem_omit" -gt 0 ] && resumen="$resumen, $rem_omit protegida(s)"
resumen="$resumen. Base: $base."
echo "$resumen"
