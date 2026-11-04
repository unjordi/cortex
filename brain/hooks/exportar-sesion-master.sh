#!/usr/bin/env bash
# exportar-sesion-master.sh — hook del brain (mecanismo GENÉRICO, opt-in por convención de nombre).
# Exporta el transcript comprimido de una sesión cuyo TÍTULO vigente sea `*-master` (o que ya tenga su
# `<sid>.meta.json`, señal de que ya se exportó) a la CARPETA DE SESIONES, para poder `claude --resume` la MISMA sesión
# después (sobrevive el cleanup de 30 días de Claude Code) — y, si esa carpeta vive en una nube, para
# que la sesión VIAJE entre máquinas. Mitad "auto-export" del sync; la mitad "sembrar" es seed.sh.
#
# CARPETA LOCAL DE SESIONES: $CLAUDE_SESSIONS_LOCAL (default ~/.claude-sessions, oculta, SIEMPRE local).
# Opción A (2026-10-14): el exportador escribe SIEMPRE a esta carpeta LOCAL y YA NO al Drive — antes leía
# $CLAUDE_SESSIONS_DRIVE y, apuntándola a la nube, mandaba TODO master al Drive directo (listado o no). Ahora
# el VIAJE cross-máquina lo hace el WIDGET (publicar-roster.sh) subiendo al folder de sync SOLO lo que lista
# el masters.json curado. $CLAUDE_SESSIONS_DRIVE se repurposó: ahora es el folder del widget/seed, no del
# exportador. Ver brain/sesiones-master/README.md.
#
# GATILLOS (cablea install-brain / brain/sesiones-master/install-hook.sh, en ~/.claude/settings.json):
#   - Stop        BACKBONE: dispara al final de CADA turno, con DEBOUNCE (a lo mucho 1 export/N min por
#                 sesión) para no re-gzipear cientos de MB en balde. Mantiene la master fresca CONTINUA-
#                 mente aunque la sesión NUNCA "termine" (las de vida larga se resumen por días →
#                 SessionEnd casi nunca disparaba → el export se congelaba). En Stop, fast-path: solo
#                 actúa si el sid YA tiene su `<sid>.meta.json` (ya se exportó); NO escanea el transcript gigante.
#   - SessionEnd  Estado FINAL en salida limpia (sin debounce). Aquí sí se escanea el título para
#                 detectar/registrar un master NUEVO.
#   - PreCompact  Bonus: justo antes de compactar (sin debounce). NO crítico (Stop ya cubre frescura).
#
# El export corre DETACHED (nohup … &) con lock por-sid: un transcript grande excede el timeout del hook
# ("Hook cancelled", caso real cps-master 456 MB) → el hook retorna al instante y el gzip+copy termina en
# segundo plano. El MOTOR (session-export.js) es genérico y lo aporta cortex.
#
# CONTRATO: SILENCIOSO y FAIL-OPEN. Si la sesión no es master, falta el motor/node, o el debounce aún no
# vence → no hace nada y NO bloquea. JAMÁS rompe el turno/cierre (siempre exit 0). Opt-in por convención
# de nombre (título *-master) y/o por tener ya su `<sid>.meta.json`. NO escribe masters.json (Opción A, 2026-10-14).
# Overrides: $CLAUDE_SESSIONS_DEBOUNCE_MIN (min, default 20) · $CLAUDE_SESSIONS_LOCAL (carpeta LOCAL, default ~/.claude-sessions).
set -u

DEBOUNCE_MIN="${CLAUDE_SESSIONS_DEBOUNCE_MIN:-20}"

# ── stdin del hook: {session_id, transcript_path, cwd, hook_event_name, ...} (Stop trae stop_hook_active) ─
input=$(cat 2>/dev/null || true)
have_jq=0; command -v jq >/dev/null 2>&1 && have_jq=1
getf() {
  if [ "$have_jq" = 1 ]; then printf '%s' "$input" | jq -r ".$1 // empty" 2>/dev/null
  else printf '%s' "$input" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n1; fi
}
sid=$(getf session_id)
tpath=$(getf transcript_path)
event=$(getf hook_event_name)
[ -n "$sid" ] || exit 0
[ -n "$tpath" ] && [ -f "$tpath" ] || exit 0

# Evita re-entradas del hook Stop (cuando el propio Stop hook ya está activo/continuando)
if [ "$event" = "Stop" ]; then
  [ "$(getf stop_hook_active)" = "true" ] && exit 0
fi

# ── carpeta LOCAL de respaldo de sesiones (Opción A: SIEMPRE local, nunca el Drive) ────────────────
# $CLAUDE_SESSIONS_LOCAL (default ~/.claude-sessions, oculta en el home). El respaldo sobrevive el cleanup
# de 30 días de Claude Code sin depender de ninguna nube. El viaje cross-máquina ya NO lo hace esta carpeta
# (eso lo hace el widget vía publicar-roster.sh, subiendo lo CURADO al folder de sync). El nombre interno de
# la variable sigue siendo DRIVE por mínimo diff, pero su valor es la carpeta LOCAL.
DRIVE="${CLAUDE_SESSIONS_LOCAL:-$HOME/.claude-sessions}"
mkdir -p "$DRIVE" 2>/dev/null || exit 0
meta="$DRIVE/$sid.meta.json"   # fuente per-sid SIN contención (la escribe session-export.js)

# ── ¿es master? FAST-PATH: si el sid YA tiene su <sid>.meta.json (ya se exportó alguna vez) no escaneamos
# el transcript. (Opción A, 2026-10-14: el hook YA NO escribe un masters.json compartido —generaba
# conflictos de Drive y drift entre masters concurrentes—; el meta per-sid es la señal libre de contención.
# Paridad con el fast-path viejo: antes el 1er registro ocurría en SessionEnd/PreCompact —el register block—;
# ahora el 1er EXPORT en esos mismos eventos escribe el meta, y los Stops siguientes lo ven.)
title=""
is_master=0
# ¿título de master? Acepta "<x>-master", su duplicado "<x>-master (N)" que pone el CLI al CONTINUAR una
# sesión, Y "<x>-master-<sufijo>" con un sufijo ALFANUMÉRICO propio (p. ej. "claudio-master-3000") — sin
# esto, un master con sufijo (incluida la sesión PRINCIPAL de unjordi) dejaba de exportarse EN SILENCIO
# (B-20). El sufijo exige ser alfanumérico para no tragarse un nombre de archivo tipo "mi-master-plan.md".
# Devuelve el NAME BASE canónico (sin el " (N)"); el archivo de export ya es por-sid, no por-name.
_master_base() {  # $1=title → echo base canónica si es master; nada si no
  local t="$1" b sfx
  case "$t" in *\ \(*\)) b="${t% (*}" ;; *) b="$t" ;; esac   # strip solo un " (N)" final
  case "$b" in
    *-master) printf '%s' "$b" ;;                            # <x>-master
    *-master-*)                                              # <x>-master-<sufijo>: sufijo DEBE ser alfanumérico
      sfx="${b##*-master-}"
      case "$sfx" in
        ''|*[!A-Za-z0-9]*) : ;;                             # vacío, o con algo no-alfanumérico (plan.md) → NO master
        *) printf '%s' "$b" ;;
      esac ;;
    *) : ;;
  esac
}
if [ -f "$meta" ]; then
  is_master=1
  [ "$have_jq" = 1 ] && title=$(jq -r '.label // empty' "$meta" 2>/dev/null)
fi
# sid NO exportado aún: el escaneo del transcript (caro) SOLO en eventos infrecuentes, jamás en Stop.
if [ "$is_master" = 0 ]; then
  case "$event" in
    SessionEnd|PreCompact)
      t=$(grep -ao '"customTitle":"[^"]*"' "$tpath" 2>/dev/null | tail -1 | sed 's/.*:"//; s/"$//')
      _b=$(_master_base "$t")
      if [ -n "$_b" ]; then title="$_b"; is_master=1
      else
        # el título PARECE master (contiene -master) pero no casó el patrón → avisa UNA vez (no en silencio, B-20)
        case "$t" in *-master*)
          _nm="$DRIVE/.master-nomatch-$(printf '%s' "$t" | tr -c 'A-Za-z0-9' _)"
          [ -f "$_nm" ] || { printf 'exportar-sesion-master: título "%s" parece master pero no casa el patrón (no se respalda; ¿sufijo no-alfanumérico?)\n' "$t" >&2; : > "$_nm" 2>/dev/null; }
        ;; esac
      fi
      ;;
    *) exit 0 ;;   # Stop u otro sin meta → salimos barato, sin escanear
  esac
fi
# meta presente pero sin label (o sin jq): recupera el título con un scan (raro; jq va presente por install-hook)
if [ "$is_master" = 1 ] && [ -z "$title" ]; then
  t=$(grep -ao '"customTitle":"[^"]*"' "$tpath" 2>/dev/null | tail -1 | sed 's/.*:"//; s/"$//')
  _b=$(_master_base "$t"); if [ -n "$_b" ]; then title="$_b"; else title="$sid"; fi
fi
[ "$is_master" = 1 ] && [ -n "$title" ] || exit 0

# ── DEBOUNCE (solo Stop): si el export en Drive es más nuevo que N min, no re-exportar. ──────────
if [ "$event" = "Stop" ]; then
  prev="$DRIVE/$sid.jsonl.gz"
  if [ -f "$prev" ]; then
    # mtime epoch, portable: GNU `stat -c %Y` primero (falla LIMPIO en BSD, sin ensuciar stdout);
    # si no, BSD/macOS `stat -f %m`. OJO: al revés NO sirve — en GNU `-f` es --file-system y `%m`
    # se toma como archivo → vuelca basura a stdout y rompe la aritmética bajo set -u.
    now=$(date +%s 2>/dev/null || echo 0)
    mt=$(stat -c %Y "$prev" 2>/dev/null || stat -f %m "$prev" 2>/dev/null || echo 0)
    case "$now" in ''|*[!0-9]*) now=0 ;; esac
    case "$mt"  in ''|*[!0-9]*) mt=0  ;; esac
    age=$(( now - mt ))
    [ "$mt" -gt 0 ] && [ "$age" -ge 0 ] && [ "$age" -lt $(( DEBOUNCE_MIN * 60 )) ] && exit 0
  fi
fi

# ── localizar el motor (genérico, lo aporta cortex) ────────────────────────────────────────
# resolve_brain_dir() vive en drift-cerebro-comun.sh (misma carpeta, fuente y una vez instalado) — mismo
# orden/fallback que los widgets (#322): $CLAUDE_BRAIN_DIR → ~/.cortex → ~/.claude-brain (nombre viejo).
# Si la lib no está (caso raro), cae al default histórico sin el fallback (fail-open, nunca bloquea).
_selfdir="$(dirname "$0")"
if [ -f "$_selfdir/drift-cerebro-comun.sh" ]; then
  # shellcheck source=drift-cerebro-comun.sh
  . "$_selfdir/drift-cerebro-comun.sh"
  BRAIN_DIR="$(resolve_brain_dir)"
else
  BRAIN_DIR="${CLAUDE_BRAIN_DIR:-$HOME/.cortex}"
fi
EXP=""
for c in "$HOME/.local/bin/session-export.js" "$BRAIN_DIR/bin/session-export.js"; do
  [ -f "$c" ] && EXP="$c" && break
done
[ -n "$EXP" ] || exit 0
command -v node >/dev/null 2>&1 || exit 0

# ── EXPORTAR en SEGUNDO PLANO (detached) ─────────────────────────────────────────────────────────
# Un transcript grande (cientos de MB) tarda en gzipearse y EXCEDE el timeout del hook → "Hook
# cancelled" (caso REAL: cps-master, 456 MB, el auto-export se quedó congelado). Solución: lanzar el
# export con nohup … & → el hook RETORNA al instante y el gzip+copy termina en segundo plano, sin que
# el CLI lo mate. Un lock por-sid evita que dos triggers seguidos (Stop/SessionEnd/PreCompact) lancen
# exports SOLAPADOS de la misma sesión; el lock se ignora si quedó viejo (>30 min = export colgado).
lock="$DRIVE/.export-$sid.lock"
if [ -f "$lock" ]; then
  lnow=$(date +%s 2>/dev/null || echo 0)
  lmt=$(stat -c %Y "$lock" 2>/dev/null || stat -f %m "$lock" 2>/dev/null || echo 0)
  case "$lnow" in ''|*[!0-9]*) lnow=0 ;; esac
  case "$lmt"  in ''|*[!0-9]*) lmt=0 ;; esac
  [ "$lmt" -gt 0 ] && [ $(( lnow - lmt )) -lt 1800 ] && exit 0   # export en vuelo → no solapar
fi
: > "$lock" 2>/dev/null || true
# El subshell detachado hace TODO el trabajo pesado (export + gzip + copy) y libera el lock al final.
nohup bash -c '
  EXP="$1"; sid="$2"; title="$3"; DRIVE="$4"; lock="$5"
  tmp=$(mktemp -d 2>/dev/null) || { rm -f "$lock"; exit 0; }
  node "$EXP" "$sid" --repo "$tmp" --name "$title" --force >/dev/null 2>&1
  gz="$tmp/.claude/sessions/$sid.jsonl.gz"; meta="$tmp/.claude/sessions/$sid.meta.json"
  # Solo copia el .gz si PASA la verificación de integridad (gzip -t): si node crasheó a media escritura,
  # un gz truncado NO debe SOBREESCRIBIR el backup bueno anterior en $DRIVE (mejor un backup viejo-pero-válido
  # que uno nuevo-corrupto). Sin gzip -t, un export corrupto pasaba silencioso y reventaba al `claude --resume`.
  if [ -f "$gz" ] && gzip -t "$gz" 2>/dev/null; then
    cp -f "$gz" "$DRIVE/" 2>/dev/null
    [ -f "$meta" ] && cp -f "$meta" "$DRIVE/" 2>/dev/null   # el meta acompaña SOLO a un gz válido
  fi
  rm -rf "$tmp" 2>/dev/null
  rm -f "$lock" 2>/dev/null
' _ "$EXP" "$sid" "$title" "$DRIVE" "$lock" >/dev/null 2>&1 &

# ── Opción A (Jordi, 2026-10-14): el hook YA NO escribe un masters.json compartido. ───────────────
# Antes aquí un read-modify-write registraba/actualizaba {id,name,target} en $DRIVE/masters.json (el
# archivo COMPARTIDO en Drive). Varios masters concurrentes escribiéndolo generaban conflictos de sync de
# Drive (masters.json.conflict1-4) y drift (ids viejos, targets que eran worktrees, nombres repetidos).
# La proveniencia por-sesión vive ahora SOLO en el `<sid>.meta.json` per-sid (id, label, originCwd),
# conflict-free por construcción (un archivo por sesión, cada máquina el suyo) — lo escribe el export de
# arriba. El roster de masters lo derivan `seed.sh` (de los metas del Drive) y el `masters-<host>.json`
# LOCAL que cada master CURA A MANO (ya no automático). Ver brain/sesiones-master/README.md.
exit 0
