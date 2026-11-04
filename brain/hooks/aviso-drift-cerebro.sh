#!/usr/bin/env bash
# aviso-drift-cerebro.sh — SessionStart hook (tier GLOBAL). Avisa —warn-only— cuando la copia GLOBAL del
# cerebro de ESTA máquina quedó ATRÁS de la FUENTE única local (el clon de instalación ~/.cortex, o
# $CLAUDE_BRAIN_DIR) o se editó en vivo (se perdería en el próximo install-brain). Chequea tres frentes
# per-MÁQUINA: skills (~/.claude/skills), hooks/libs (~/.claude/hooks) y el bloque de normas de
# ~/.claude/CLAUDE.md, cada uno con su propio throttle. Delega la detección a drift-cerebro-comun.sh.
#
# El cerebro vive SOLO en global por máquina: ya NO hay
# copias del cerebro POR-REPO, así que este hook ya NO chequea ni auto-sincroniza una copia por-repo (eso
# se retiró con el cerebro por-repo). Lo que queda es el aviso de drift de la copia GLOBAL vs la fuente —
# el equivalente AUTOMÁTICO del doctor verificar-cerebro — más el cableado del @import de identidad (B8).
#
# Throttle: cada frente global solo se re-chequea cada AVISO_DRIFT_HORAS (default 6; stamps en
# ~/.claude/memory/.drift-cerebro/). Un chequeo CON drift NO se cachea → insiste cada sesión hasta portarlo
# a la fuente. Fail-open SIEMPRE: sin clon canónico / cualquier error → silencio.
#
# RECORDATORIO DE LA DUPLA: cuando el cerebro de este repo CAMBIA (auto-sync) o está por
# hacerlo (drift), es el momento de "¿la realidad sigue cumpliendo la firma?" → el aviso añade un nudge a
# correr la DUPLA de auditores (suficiencia + coherencia, van juntas). Se cuelga de ESTE hook (que ya corre
# SessionStart + ya llama a sincronizar + ya sabe cuándo el cerebro se movió) en vez de un hook nuevo.
# BIFURCA por el esquema firma+detalle: si el repo tiene AGENTS.md instanciado → "audita CONTRA la firma";
# si NO → la dupla igual funciona (suficiencia deriva su lista; coherencia caza contradicciones) y se sugiere
# instanciar el esquema. NUNCA lo asume: no todo repo tiene firma=TOC.
#
# CUÁNDO CORRE:
# SessionStart dispara con source ∈ {startup, resume, clear, compact, fork} — NO solo en arranque
# fresco. En particular `claude --resume`/`--continue` → source="resume", y cada `/compact` (auto o
# manual) → source="compact", LO DISPARAN. Este hook se cablea SIN matcher → corre en TODOS esos
# source.
# Importa porque el flujo real es casi todo --resume + sesiones largas que compactan: la auto-sync se
# re-chequea en cada resume Y en cada compactación, sin depender de abrir claudes frescos.
# Doc: code.claude.com/docs/en/hooks (tabla SessionStart + "Hooks can be re-run on resume with
# --continue or --resume (source = resume or fork)").
set -u

# Los detectores de drift de la copia GLOBAL (skills/hooks/normas) viven en la lib drift-cerebro-comun.sh.
# shellcheck source=drift-cerebro-comun.sh
. "$(dirname "$0")/drift-cerebro-comun.sh"

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cat >/dev/null 2>&1 || true   # drenar stdin (contrato SessionStart)

# ── B8 MIGRACIÓN: cablea el @import de identidad (reemplazo de la re-inyección retirada en B8) ─────────
# Medido en plantilladotnet (claudio-master) y axon (axon-master): tenían conocimiento-propio PERO NINGÚN
# @import → sin esto, tras B8 arrancarían SIN identidad. Idempotente, al CLAUDE.local.md (gitignored → en un
# repo COMPARTIDO NO mete un @import per-usuario al CLAUDE.md del equipo). Solo actúa si HAY identidad y NO
# hay ya un @import de ella en ningún CLAUDE*.md. (El @import toma efecto la PRÓXIMA sesión del repo.)
_self_md="$ROOT/.claude/memory/conocimiento-propio.local.md"
if [ -f "$_self_md" ]; then
  _ya_import=0
  for _f in "$ROOT/CLAUDE.md" "$ROOT/CLAUDE.local.md" "$ROOT/.claude/CLAUDE.md"; do
    [ -f "$_f" ] && grep -qE '^@.*conocimiento-propio' "$_f" && { _ya_import=1; break; }
  done
  if [ "$_ya_import" = 0 ]; then
    # Hueco (medido por claudio en axon): si CLAUDE.local.md NO está gitignoreado, crearlo lo deja untracked
    # → un `git add -A` lo colaría al commit. Antes de escribir, si git NO lo ignora ya, lo agrega a
    # .git/info/exclude (per-CLON, local — NO toca el .gitignore versionado del equipo). git-common-dir para
    # que un worktree escriba en el exclude COMPARTIDO del repo.
    if ! git -C "$ROOT" check-ignore -q CLAUDE.local.md 2>/dev/null; then
      _gci=$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null)
      if [ -n "$_gci" ]; then
        case "$_gci" in /*) ;; *) _gci="$ROOT/$_gci" ;; esac
        mkdir -p "$_gci/info" 2>/dev/null || true
        grep -qxF 'CLAUDE.local.md' "$_gci/info/exclude" 2>/dev/null || printf '%s\n' 'CLAUDE.local.md' >> "$_gci/info/exclude" 2>/dev/null || true
      fi
    fi
    [ -f "$ROOT/CLAUDE.local.md" ] || printf '%s\n' '# Overrides locales de Claude Code (gitignored, per-máquina).' > "$ROOT/CLAUDE.local.md" 2>/dev/null || true
    printf '%s\n' '@.claude/memory/conocimiento-propio.local.md' >> "$ROOT/CLAUDE.local.md" 2>/dev/null || true
  fi
fi

# ── IDENTIDAD (conocimiento-propio) — YA NO la re-inyecta este hook (B8, decisión unjordi 2026-10-14) ──
# El `@import` NATIVO de `conocimiento-propio.local.md` en el CLAUDE.md del repo (cableado en ef754d6) la
# carga en CADA SessionStart (fresh/resume/compact) y tolera su ausencia — reemplaza la re-inyección que
# este hook hacía, que con el @import presente la DUPLICABA en contexto. Este hook ya solo surface el drift
# y el auto-sync. (Un repo cuyo CLAUDE.md aún no tenga el @import adopta la línea; no es cosa de este hook.)

# emit_and_exit [contexto-de-drift] — emite additionalContext UNA sola vez con el contexto de drift/auto-sync
# (si lo hay) + los avisos per-máquina. Sin ninguno → silencio.
emit_and_exit() {
  local extra="${1:-}" out="" part sep=""
  # Une (en orden, saltando vacíos): $extra (drift/auto-sync per-repo) · GLOBAL_SK_WARN (drift de la copia
  # GLOBAL de skills) · GLOBAL_HOOK_WARN (drift de la copia GLOBAL de hooks/libs) · GLOBAL_NORMS_WARN (drift
  # del bloque de normas en ~/.claude/CLAUDE.md) · MIGRACION_WARN (huella local de clon sin migrar). Los
  # cuatro últimos viajan en TODOS los exit paths (incluso el throttle per-repo fresco): son concerns
  # per-MÁQUINA con su PROPIO throttle, no dependen del drift del repo actual.
  for part in "$extra" "${GLOBAL_SK_WARN:-}" "${GLOBAL_HOOK_WARN:-}" "${GLOBAL_NORMS_WARN:-}" "${MIGRACION_WARN:-}"; do
    [ -z "$part" ] && continue
    if [ -z "$out" ]; then out="$part"; else
      out="$out

$sep

$part"
    fi
    sep="────────────────────────────────────────────────────────────────────────────────"
  done
  [ -z "$out" ] && exit 0
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg c "$out" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
  else
    printf '%s\n' "$out"
  fi
  exit 0
}

# Cada frente de drift global (skills/hooks/normas/migración) lleva su PROPIO throttle (stamps abajo).
horas="${AVISO_DRIFT_HORAS:-6}"; case "$horas" in ''|*[!0-9]*) horas=6;; esac
stampdir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/.drift-cerebro"; mkdir -p "$stampdir" 2>/dev/null || true
now=$(date +%s)

# ── DRIFT DE SKILLS GLOBAL (per-máquina) — con su PROPIO throttle (independiente del per-repo). Warn-only.
# Se computa ANTES del throttle per-repo para que viaje aunque ese throttle corte temprano (emit_and_exit lo
# incluye en TODOS los exit paths). Solo re-chequea cada AVISO_DRIFT_HORAS; un resultado CON drift NO se
# cachea (insiste hasta que se porte a la fuente). Es el equivalente AUTOMÁTICO del doctor verificar-cerebro.
GLOBAL_SK_WARN=""
sk_stamp="$stampdir/.skills-global"
sk_skip=0
if [ -f "$sk_stamp" ]; then
  sk_last=$(cat "$sk_stamp" 2>/dev/null || echo 0); case "$sk_last" in ''|*[!0-9]*) sk_last=0;; esac
  [ $(( now - sk_last )) -lt $(( horas * 3600 )) ] && sk_skip=1
fi
if [ "$sk_skip" = 0 ]; then
  GLOBAL_SK_WARN="$(drift_skills_global 2>/dev/null)"
  _rc=$?
  if [ "$_rc" = 0 ] && [ -z "$GLOBAL_SK_WARN" ]; then
    printf '%s' "$now" > "$sk_stamp" 2>/dev/null || true
  fi
fi

# ── DRIFT DE HOOKS GLOBAL (per-máquina) — con su PROPIO throttle (independiente del per-repo y del de skills).
# Warn-only. Equivalente de drift_skills_global pero para ~/.claude/hooks vs brain/hooks: cubre TODO archivo
# de tier {global,both} que install-brain copia ahí (hooks + libs + scripts). Antídoto a "el global está
# congelado": un guard/lib editado a mano o desactualizado en la copia global no se detectaba. Solo re-chequea
# cada AVISO_DRIFT_HORAS; un resultado CON drift NO se cachea (insiste hasta que se porte a la fuente).
GLOBAL_HOOK_WARN=""
hk_stamp="$stampdir/.hooks-global"
hk_skip=0
if [ -f "$hk_stamp" ]; then
  hk_last=$(cat "$hk_stamp" 2>/dev/null || echo 0); case "$hk_last" in ''|*[!0-9]*) hk_last=0;; esac
  [ $(( now - hk_last )) -lt $(( horas * 3600 )) ] && hk_skip=1
fi
if [ "$hk_skip" = 0 ]; then
  GLOBAL_HOOK_WARN="$(drift_hooks_global 2>/dev/null)"
  _rc=$?
  if [ "$_rc" = 0 ] && [ -z "$GLOBAL_HOOK_WARN" ]; then
    printf '%s' "$now" > "$hk_stamp" 2>/dev/null || true
  fi
fi

# ── DRIFT DE NORMAS GLOBAL (per-máquina) — con su PROPIO throttle (independiente de skills/hooks). Warn-only.
# install-brain §(e) refresca el bloque de normas en ~/.claude/CLAUDE.md en cada re-corrida; este aviso
# indica cuándo hace falta re-correrlo. Solo re-chequea cada AVISO_DRIFT_HORAS; un resultado CON drift NO
# se cachea (insiste hasta que re-corras install-brain).
GLOBAL_NORMS_WARN=""
nm_stamp="$stampdir/.normas-global"
nm_skip=0
if [ -f "$nm_stamp" ]; then
  nm_last=$(cat "$nm_stamp" 2>/dev/null || echo 0); case "$nm_last" in ''|*[!0-9]*) nm_last=0;; esac
  [ $(( now - nm_last )) -lt $(( horas * 3600 )) ] && nm_skip=1
fi
if [ "$nm_skip" = 0 ]; then
  GLOBAL_NORMS_WARN="$(drift_norms_global 2>/dev/null)"
  _rc=$?
  if [ "$_rc" = 0 ] && [ -z "$GLOBAL_NORMS_WARN" ]; then
    printf '%s' "$now" > "$nm_stamp" 2>/dev/null || true
  fi
fi

# ── HUELLA LOCAL DE MÁQUINA SIN MIGRAR (renombre claude-brain→cortex) — SOLO test -d LOCAL, JAMÁS red
# (nunca `git fetch`/llamada de red: esto es un nudge advisory, no un chequeo de versión). Si el clon de
# instalación sigue bajo el nombre VIEJO (~/.claude-brain con su .git) y el nuevo (~/.cortex) NO existe,
# esta máquina no migró el renombre: el resolver bash
# tiene el fallback (resolve_brain_dir) así que autosync/verificación/protección de fuente siguen
# vivos aquí, pero el WIDGET viejo puede seguir atascado sin self-update (build vieja) → sugiere
# re-instalar con el one-liner del bootstrap para cerrar el loop de una vez. Throttle propio ~1×/día
# (independiente de AVISO_DRIFT_HORAS: esto no cambia con el drift del repo). Fail-open, nunca bloquea.
MIGRACION_WARN=""
mig_stamp="$stampdir/.migracion-limbo"
mig_skip=0
if [ -f "$mig_stamp" ]; then
  mig_last=$(cat "$mig_stamp" 2>/dev/null || echo 0); case "$mig_last" in ''|*[!0-9]*) mig_last=0;; esac
  [ $(( now - mig_last )) -lt 86400 ] && mig_skip=1
fi
if [ "$mig_skip" = 0 ]; then
  if [ -d "$HOME/.claude-brain/.git" ] && [ ! -d "$HOME/.cortex" ]; then
    MIGRACION_WARN="🧠➡️ TU CLON DEL CEREBRO sigue con el nombre VIEJO (~/.claude-brain) — el rename a cortex (~/.cortex) nunca migró en esta máquina. El tooling bash ya te sigue viendo (fallback), pero el widget puede seguir atascado sin poder auto-actualizarse. Re-instala con:
curl -fsSL https://raw.githubusercontent.com/unjordi/cortex/main/bootstrap.sh | bash"
  fi
  printf '%s' "$now" > "$mig_stamp" 2>/dev/null || true
fi

# Emite los avisos de drift GLOBAL (skills/hooks/normas/migración) si los hay; si no, silencio. Ya NO hay
# chequeo per-repo (el cerebro vive solo en global; el cerebro por-repo se retiró).
emit_and_exit ""
