#!/usr/bin/env bash
# sincronizar-tasklist.sh — LIB compartida (tier REPO, dual-mode). TODA la lógica DETERMINISTA (SIN LLM)
# para sincronizar el HUD/TaskList del harness (`~/.claude/tasks/<sid>/*.json`) con el bloque durable
# `<!-- espejo-tasklist -->` de `.claude/memory/estado-proyecto.md`. UN solo dueño de la maquinaria; sus
# invocadores la USAN, no la re-implementan:
#   • recordar-cosechar.sh (hook Stop)  → la `source`ea y llama `espejar_tasklist` (json → bloque durable).
#   • skill to-do (`/to-do`)            → la EJECUTA `sembrar` (bloque durable → set de tareas) para no
#                                          re-parsear a mano; el modelo aplica el set al HUD vivo con las
#                                          tools TaskCreate/TaskUpdate (única vía que refresca el HUD).
#
# CRUX: el harness LEE los task-json al SessionStart, los tiene EN MEMORIA
# y solo los ESCRIBE al salir — NO re-renderiza en vivo si un proceso externo escribe los json. Y el
# session_id ROTA sin aviso (arranque nuevo, auto-compact) → el sid del payload NO siempre casa con la
# carpeta que respalda el HUD en pantalla. Por eso:
#   1) La selección de carpeta es ROBUSTA a la rotación (payload sid → si vacío/ausente, la ÚNICA carpeta
#      no-vacía en la ventana; con ≥2 sesiones activas NO adivina, para no adoptar la de otro repo).
#   2) NUNCA se pisa un bloque no-vacío con uno vacío (anti-clobber): era el bug "+0 · sin pendientes".
#   3) El refresco del HUD en pantalla NO lo hace un hook (imposible sin re-render); lo hace el skill.
#
# Regla quién-gana en la costura md↔json: DURANTE la sesión manda el TaskList vivo (json) y el Stop lo
# refleja al durable; en los BORDES (SessionStart / /to-do) manda la durable y el modelo re-siembra el HUD.
#
# CONTRATO: SILENCIOSA y FAIL-OPEN. Sin jq, sin `.claude/memory`, sin carpeta de tareas, o cualquier error
# → no hace nada y devuelve 0. NUNCA frena al invocador.
set -u

STL_ESPEJO_INI="<!-- espejo-tasklist:start -->"
STL_ESPEJO_FIN="<!-- espejo-tasklist:end -->"
STL_ESTADO_REL=".claude/memory/estado-proyecto.md"
STL_VENTANA_FALLBACK="${CLAUDE_TASKLIST_FALLBACK_SECS:-7200}"   # 2h: no adopta una carpeta stale de otra sesión
_STL_TAB=$(printf '\t')

# ── _stl_dir_tiene_json <dir> → 0 si hay ≥1 *.json legible ──────────────────────────────────────── ──
_stl_dir_tiene_json() {
  local d="$1" f
  [ -n "$d" ] && [ -d "$d" ] || return 1
  for f in "$d"/*.json; do [ -f "$f" ] && return 0; done
  return 1
}

# ── _stl_tasksdir <sid> → setea _STL_DIR (carpeta correcta, o vacía) y _STL_RESOLV (confianza) ─────── ──
# Devuelve por GLOBALES (NO por stdout): un `tasksdir=$(_stl_tasksdir …)` corría la función en un SUBSHELL
# y el _STL_RESOLV que seteaba NO subía al padre → la excepción "todo completado" quedaba muerta. Los
# callers la invocan PLANO y leen $_STL_DIR/$_STL_RESOLV.
# Robusto a la rotación de session_id, pero SIN adoptar la carpeta de otra sesión/repo (MEDIO auditoría
# 2026-10-22): las tasks NO llevan repo, así que "la más reciente GLOBAL" podía ser de OTRO master activo.
#   1) sid del payload con json → carpeta DIRECTA (_STL_RESOLV=direct, máxima confianza: ES esta sesión).
#   2) si no, FALLBACK por rotación: adopta una carpeta viva SOLO si es INEQUÍVOCA — EXACTAMENTE UNA
#      carpeta no-vacía dentro de la ventana (_STL_RESOLV=fallback). Con 0 o ≥2 (varias sesiones a la vez)
#      NO adivina (_STL_RESOLV=none) → el anti-clobber preserva el bloque en vez de pisarlo con tareas ajenas.
_STL_DIR=""
_STL_RESOLV=none
_stl_tasksdir() {
  local sid="${1:-}" base="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tasks" d best="" cnt=0 m now
  _STL_DIR=""; _STL_RESOLV=none
  if [ -n "$sid" ] && _stl_dir_tiene_json "$base/$sid"; then _STL_DIR="$base/$sid"; _STL_RESOLV=direct; return 0; fi
  [ -d "$base" ] || return 0
  now=$(date +%s 2>/dev/null || echo 0); case "$now" in ''|*[!0-9]*) now=0 ;; esac
  for d in "$base"/*/; do
    d="${d%/}"
    _stl_dir_tiene_json "$d" || continue
    m=$(stat -c %Y "$d" 2>/dev/null || stat -f %m "$d" 2>/dev/null || echo 0)   # GNU primero; en GNU `stat -f %m` es --file-system (basura con exit 0) → BSD-primero elegía mal la carpeta viva en ubuntu
    case "$m" in ''|*[!0-9]*) m=0 ;; esac
    # Solo dentro de la ventana (si no pudimos leer `now`, no filtramos por tiempo).
    if [ "$now" -gt 0 ] && [ "$STL_VENTANA_FALLBACK" -gt 0 ]; then
      [ $(( now - m )) -le "$STL_VENTANA_FALLBACK" ] || continue
    fi
    cnt=$((cnt+1)); best="$d"
  done
  # INEQUÍVOCA = exactamente 1 candidata. Con ≥2 no se puede saber cuál es la nuestra → no adivinar.
  if [ "$cnt" -eq 1 ]; then _STL_DIR="$best"; _STL_RESOLV=fallback; fi
  return 0
}

# ── _stl_rows <tasksdir> → TSV (status \t id \t subject) de in_progress+pending, ordenado ────────── ──
_stl_rows() {
  local d="$1" f
  [ -n "$d" ] && [ -d "$d" ] || return 0
  for f in "$d"/*.json; do
    [ -f "$f" ] || continue
    jq -r 'select(.status=="in_progress" or .status=="pending")
           | [.status, (.id|tonumber? // 0), (.subject // "")] | @tsv' "$f" 2>/dev/null
  done | sort -t"$_STL_TAB" -k1,1 -k2,2n
}

# ── _stl_ndone <tasksdir> → cuántos json con status completed ────────────────────────────────────── ──
_stl_ndone() {
  local d="$1" n=0 f
  [ -n "$d" ] && [ -d "$d" ] || { printf 0; return 0; }
  for f in "$d"/*.json; do
    [ -f "$f" ] || continue
    [ "$(jq -r '.status // empty' "$f" 2>/dev/null)" = "completed" ] && n=$((n+1))
  done
  printf '%s' "$n"
}

# ── _stl_carpeta_es_de_este_repo <sid> → 0 si la carpeta de tareas <sid> pertenece a ESTE repo/sesión.
#    R4 #3-fix2 (auditoría 2026-10-23): los ids de tarea empiezan en #1 en TODA sesión → un chequeo por SOLAPE
#    de ids casi siempre da verdadero (no distingue una carpeta ajena de la propia rotada). La señal CORRECTA es
#    el TRANSCRIPT: existe `<projects>/<slug del CLAUDE_PROJECT_DIR>/<sid>.jsonl` SÓLO si esa sesión corrió en
#    ESTE repo (la carpeta ajena de otro master/otro repo tiene su transcript bajo OTRO slug). El slug = la ruta
#    del proyecto con `/` y `.` → `-` (misma convención de Claude Code). bash-3.2-safe.
_stl_carpeta_es_de_este_repo() {
  local sid="$1" proj slug base
  [ -n "$sid" ] || return 1
  proj="${CLAUDE_PROJECT_DIR:-}"; [ -n "$proj" ] || return 1
  base="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
  slug=$(printf '%s' "$proj" | sed 's#[/.]#-#g')
  [ -f "$base/$slug/$sid.jsonl" ]
}

# ── _stl_render_body <rows-tsv> <ndone> → cuerpo markdown del bloque ─────────────────────────────── ──
_stl_render_body() {
  local rows="$1" ndone="$2" body st id subj icon
  body="## 🔄 Pendientes — espejo automático del TaskList (NO editar a mano)
> Lo mantiene el hook \`recordar-cosechar\` en cada Stop y lo re-siembra el skill \`to-do\` al arrancar. Es la
> serialización DURABLE del HUD (viaja por git, sobrevive la rotación de session_id). La CURACIÓN
> (decisiones, contexto, prioridades) va AFUERA de este bloque; aquí solo se espeja el estado."
  if [ -n "$rows" ]; then
    while IFS="$_STL_TAB" read -r st id subj; do
      [ -n "$st" ] || continue
      case "$st" in in_progress) icon="🔸";; *) icon="▫️";; esac
      body="$body
- $icon **[$st]** #$id · $subj"
    done <<EOF_ROWS
$rows
EOF_ROWS
  else
    body="$body

_(sin pendientes ni tareas en curso)_"
  fi
  body="$body

_(+$ndone completadas · generado automáticamente)_"
  printf '%s' "$body"
}

# ── _stl_bloque_no_vacio <archivo> → 0 si ya hay un bloque espejo con al menos un pendiente listado  ──
_stl_bloque_no_vacio() {
  local archivo="$1"
  [ -f "$archivo" ] || return 1
  awk -v ini="$STL_ESPEJO_INI" -v fin="$STL_ESPEJO_FIN" '
    $0==ini { inb=1; next } $0==fin { inb=0; next }
    inb==1 && /^- / { found=1 }
    END { exit(found?0:1) }
  ' "$archivo" 2>/dev/null
}

# ----
# ESPEJAR — json → bloque durable. Corre en el Stop. Imprime a stdout el nº de pendientes espejados
# (0 si no escribió o escribió vacío). SIEMPRE devuelve 0.
# ----
espejar_tasklist() {
  local payload="${1:-}" root="${2:-}"
  command -v jq >/dev/null 2>&1 || { printf 0; return 0; }
  [ -n "$root" ] || { printf 0; return 0; }
  local estado="$root/$STL_ESTADO_REL"
  [ -f "$estado" ] || { printf 0; return 0; }   # NO crea el backlog; solo mantiene su bloque si existe.

  local sid tasksdir rows ndone n
  sid=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)
  _stl_tasksdir "$sid"; tasksdir="$_STL_DIR"
  rows=$(_stl_rows "$tasksdir")
  n=$(printf '%s' "$rows" | grep -c . 2>/dev/null || echo 0)
  case "$n" in ''|*[!0-9]*) n=0 ;; esac

  # ANTI-CLOBBER + "TODO COMPLETADO": con 0 filas (ningún pendiente/en-curso) y un bloque YA no-vacío, lo
  # DEFAULT es PRESERVAR — no pisar con vacío un bloque bueno cuando la carpeta vino vacía/rotada/ambigua
  # (bug "+0 · sin pendientes"). EXCEPCIÓN (MEDIO auditoría 2026-10-22): si resolvimos la carpeta de ESTA
  # sesión DIRECTO (payload sid) y tiene tareas pero TODAS completadas (ndone>0), SÍ actualizamos a "sin
  # pendientes · +N completadas" — antes un tasklist terminado dejaba pendientes FANTASMA en el bloque para
  # siempre. Solo el camino `direct` lo permite: un fallback/none pudo resolver una carpeta ajena.
  ndone=$(_stl_ndone "$tasksdir")
  # ANTI-CLOBBER: si el bloque YA tiene contenido, SOLO una resolución DIRECTA de ESTA sesión (sid del payload)
  # puede pisarlo. Una resolución por FALLBACK (ownership INCIERTA — pudo adoptar la carpeta de OTRO master) NO
  # pisa un bloque bueno, ni con vacío ni con tareas. M3 (auditoría R3 2026-10-23): antes el anti-clobber solo
  # cubría n==0, así que una carpeta AJENA con un in_progress (n>0, resuelta por fallback) reemplazaba el bloque
  # propio no-vacío por una TAREA AJENA. EXCEPCIÓN del camino `direct` sin filas: solo pasa a "sin pendientes" si
  # DE VERDAD terminó (ndone>0 → tasklist completado); si no (carpeta vacía/rotada), preserva (bug "+0 · sin pendientes").
  # R4 #3 (auditoría 2026-10-23): el M3 anterior preservaba el bloque ante CUALQUIER fallback → el caso LEGÍTIMO
  # de rotación de session_id (mi carpeta rotó a un sid nuevo → se resuelve por fallback, no direct) NUNCA
  # actualizaba el espejo. Rescate: en fallback SÍ se pisa si la carpeta es la MISMA sesión rotada — señal
  # DETERMINISTA: algún id de la carpeta resuelta ya está en el bloque (el bloque se espejó de ESTA sesión antes
  # de rotar). Sin solape (carpeta AJENA) o resolución `none` → se preserva (el anti-clobber de M3 se mantiene).
  if _stl_bloque_no_vacio "$estado"; then
    if [ "$_STL_RESOLV" != "direct" ]; then
      _stl_carpeta_es_de_este_repo "${_STL_DIR##*/}" || { printf 0; return 0; }
    fi
    { [ "$n" -eq 0 ] && [ "${ndone:-0}" -eq 0 ]; } && { printf 0; return 0; }
  fi
  local body; body=$(_stl_render_body "$rows" "$ndone")

  local tmp; tmp=$(mktemp 2>/dev/null) || { printf 0; return 0; }
  # Reemplazo del bloque SIN pasar `body` (multilínea) por `awk -v`: el awk de BSD/macOS RECHAZA saltos de
  # línea en un valor `-v` ("awk: newline in string") → salía non-zero y el bloque existente NUNCA se
  # actualizaba en re-espejo (bug latente heredado). Localizamos los marcadores por nº de línea y
  # reensamblamos con head/tail — portable en Mac/Linux/Git-Bash.
  # D1 (auditoría 2026-10-22): los marcadores se localizan por LÍNEA EXACTA (`grep -nxF`), igual que sembrar/
  # _stl_bloque_no_vacio (awk `$0==ini`). Con `grep -nF` (SUBSTRING) una línea de PROSA que cita la marca
  # `<!-- espejo-tasklist:start -->` antes del bloque movía ini_ln a la prosa y head/tail BORRABA todo lo curado
  # entre ella y el `:end` (PÉRDIDA DE DATOS). FAIL-SAFE: solo se reemplaza con EXACTAMENTE 1 INI y 1 FIN (y
  # INI<FIN); sin bloque (0/0) → se anexa fresco; cualquier otra combinación (duplicado/marcador huérfano) → NO
  # se toca el archivo (conservar lo curado).
  local ini_ln fin_ln n_ini n_fin
  n_ini=$(grep -cxF "$STL_ESPEJO_INI" "$estado" 2>/dev/null); n_ini=${n_ini:-0}
  n_fin=$(grep -cxF "$STL_ESPEJO_FIN" "$estado" 2>/dev/null); n_fin=${n_fin:-0}
  if [ "$n_ini" = 1 ] && [ "$n_fin" = 1 ]; then
    ini_ln=$(grep -nxF "$STL_ESPEJO_INI" "$estado" 2>/dev/null | head -1 | cut -d: -f1)
    fin_ln=$(grep -nxF "$STL_ESPEJO_FIN" "$estado" 2>/dev/null | head -1 | cut -d: -f1)
    if [ -n "$ini_ln" ] && [ -n "$fin_ln" ] && [ "$fin_ln" -gt "$ini_ln" ] 2>/dev/null; then
      # [pre + marcador INI] + [body nuevo] + [marcador FIN + post]
      { head -n "$ini_ln" "$estado"; printf '%s\n' "$body"; tail -n +"$fin_ln" "$estado"; } > "$tmp" 2>/dev/null \
        || { rm -f "$tmp"; printf 0; return 0; }
    else
      # FIN antes que INI (bloque roto) → fail-safe: no tocar
      rm -f "$tmp"; printf 0; return 0
    fi
  elif [ "$n_ini" = 0 ] && [ "$n_fin" = 0 ]; then
    { cat "$estado"; printf '\n%s\n%s\n%s\n' "$STL_ESPEJO_INI" "$body" "$STL_ESPEJO_FIN"; } > "$tmp" 2>/dev/null \
      || { rm -f "$tmp"; printf 0; return 0; }
  else
    # bloque DUPLICADO o marcador huérfano → fail-safe: NO tocar (no borrar lo curado)
    rm -f "$tmp"; printf 0; return 0
  fi
  if cmp -s "$tmp" "$estado" 2>/dev/null; then rm -f "$tmp"; else mv -f "$tmp" "$estado" 2>/dev/null || rm -f "$tmp"; fi
  printf '%s' "$n"
  return 0
}

# ----
# SEMBRAR — bloque durable → set de tareas. El skill to-do lo usa para NO re-parsear a mano. Imprime a
# stdout una línea por tarea viva: `status|id|subject`. Con --write, además ESCRIBE los json a la carpeta
# de tareas (best-effort: se recogen al PRÓXIMO SessionStart, NO en vivo — el modelo refresca el HUD actual
# con las tools). SIEMPRE devuelve 0.
# ----
sembrar_tasklist() {
  local root="${1:-}" write="" a
  shift || true
  for a in "$@"; do case "$a" in --write) write=1;; esac; done
  [ -n "$root" ] || return 0
  local estado="$root/$STL_ESTADO_REL"
  [ -f "$estado" ] || return 0

  # Parsear las filas del bloque espejo: `- 🔸 **[in_progress]** #12 · Subject...`
  local lines; lines=$(awk -v ini="$STL_ESPEJO_INI" -v fin="$STL_ESPEJO_FIN" '
    $0==ini { inb=1; next } $0==fin { inb=0; next } inb==1 { print }' "$estado" 2>/dev/null)
  local out; out=$(printf '%s\n' "$lines" | sed -n 's/^- [^ ]* \**\[\([a-z_]*\)\]\** #\([0-9][0-9]*\) · \(.*\)$/\1|\2|\3/p')
  [ -n "$out" ] && printf '%s\n' "$out"

  if [ -n "$write" ] && command -v jq >/dev/null 2>&1 && [ -n "$out" ]; then
    local tasksdir st id subj
    _stl_tasksdir ""   # carpeta INEQUÍVOCA (para next-start); con ≥2 activas no adivina → no escribe en ajena
    tasksdir="$_STL_DIR"
    if [ -n "$tasksdir" ] && [ -d "$tasksdir" ]; then
      # M3/R4 #3-fix2 (auditoría 2026-10-23): `_stl_tasksdir ""` (sin sid) solo resuelve por FALLBACK (ownership
      # incierta). Solo sembramos en esa carpeta si pertenece a ESTE repo (su transcript vive bajo el slug del
      # CLAUDE_PROJECT_DIR) — una carpeta de OTRO master/otro repo NO se contamina con nuestras tareas (gemelo
      # del anti-clobber de espejar, en la dirección inversa durable→json). El chequeo por ids NO sirve (los ids
      # empiezan en #1 en toda sesión → casi siempre solapan).
      _stl_carpeta_es_de_este_repo "${tasksdir##*/}" || return 0
      while IFS='|' read -r st id subj; do
        [ -n "$id" ] || continue
        # NO RESUCITAR una tarea YA completada (MEDIO auditoría 2026-10-22): el bloque solo lista
        # pending/in_progress, pero puede venir STALE (una sesión previa la completó sin re-espejar). Si el
        # json destino ya la marca completed, se respeta — re-sembrarla como pending la revive falsamente.
        if [ -f "$tasksdir/$id.json" ] && [ "$(jq -r '.status // empty' "$tasksdir/$id.json" 2>/dev/null)" = "completed" ]; then
          continue
        fi
        jq -n --arg id "$id" --arg s "$subj" --arg st "$st" \
          '{id:$id, subject:$s, description:"", activeForm:$s, status:$st, blocks:[], blockedBy:[]}' \
          > "$tasksdir/$id.json" 2>/dev/null || true
      done <<EOF_SEED
$out
EOF_SEED
    fi
  fi
  return 0
}

# ── Modo CLI (cuando se EJECUTA, no se `source`ea) ───────────────────────────────────────────────── ──
# Detecta ejecución directa: $0 == este archivo (no un source). Sub-comandos: espejar | sembrar.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  _stl_cmd="${1:-}"; shift || true
  _stl_root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
  case "$_stl_cmd" in
    espejar) espejar_tasklist "$(cat 2>/dev/null || true)" "$_stl_root" >/dev/null; exit 0 ;;
    sembrar) sembrar_tasklist "$_stl_root" "$@"; exit 0 ;;
    *) printf 'uso: sincronizar-tasklist.sh {espejar|sembrar [--write]}\n' >&2; exit 0 ;;
  esac
fi
