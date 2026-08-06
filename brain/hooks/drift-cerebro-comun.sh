#!/usr/bin/env bash
# drift-cerebro-comun.sh — LIB (tier global). CUERPO PER-REPO compartido del chequeo de drift del cerebro.
#
# POR QUÉ EXISTE: la lógica "¿la copia por-repo del cerebro de ESTE repo está al día vs la fuente única, y
# si estoy en mi mini-develop con .claude/ limpio, la sincronizo sola?" la necesitan DOS consumidores:
#   1. aviso-drift-cerebro.sh  — SessionStart hook, INTERACTIVO, 1 repo (el de arranque). Fast-path.
#   2. barrer-flotilla-cerebro.sh — SWEEPER batch, N repos de la flotilla (cron/LaunchAgent).
# Antes vivía SOLO en el hook → el sweeper la habría re-implementado y las dos copias driftarían (justo el
# mal que este cerebro combate). Se extrae AQUÍ para que ambos compartan UNA sola implementación (cero drift).
#
# CONTRATO de la función `drift_chequea_repo <ROOT> [DRY_RUN]`:
#   - Hace el chequeo per-repo de ROOT (mismo comportamiento de siempre) y, si procede, el auto-apply
#     +commit+push en la mini-develop (idempotente, fail-safe). NO hace throttle, NO inyecta identidad
#     (conocimiento-propio), NO emite additionalContext — eso es responsabilidad del hook interactivo.
#   - DRY_RUN=1 (o 2º arg "dry-run"): calcula la DECISIÓN pero NO escribe/commitea/pushea nada (para el
#     modo --dry-run del sweeper y para los tests deterministas sin red). En ese modo, el caso que SÍ
#     habría auto-sincronizado devuelve STATUS=would-sync (no synced).
#   - Imprime en stdout:
#         línea 1:  STATUS=<código>
#         resto:    mensaje humano (el mismo texto que el hook usaba como additionalContext), puede ir vacío
#   - Devuelve 0 SIEMPRE (fail-open — un error del sync/git nunca debe romper el arranque de sesión).
#
# Códigos de STATUS:
#   not-brained    ROOT no tiene cerebro por-repo (ni sello .brain-version ni el hook repo-scoped clásico).
#   no-source      no hay clon canónico local del cerebro (sincronizar-cerebro.sh no existe) → fail-open.
#   unknown        el sync falló / no dio resumen → no se pudo determinar drift → fail-open (no cachear).
#   personal-clean repo PERSONAL (sin marca .claude/repo-compartido) sano: cero guards del brain sobrando.
#   personal-flag  repo PERSONAL con guards del brain que SOBRAN → mensaje = flag "quítalos" (no auto-git).
#   clean          repo COMPARTIDO al día (0 drift).
#   synced         repo COMPARTIDO: auto-sincronizado (apply+commit+push) en la mini-develop. mensaje = ctx.
#   would-sync     (solo DRY_RUN) habría auto-sincronizado, pero en dry-run NO se tocó nada.
#   drift          repo COMPARTIDO con drift que NO se auto-aplicó (ramita/.claude sucio/fuente stale/etc).
#
# La FUENTE canónica y toda la semántica (C2 anti-regresión, patrón Develop<Usuario>, staging de .claude/
# completo, etc.) son idénticas a las que vivían en aviso-drift-cerebro.sh — ver ahí el detalle histórico.
# Guardado bash-3.2-safe (sin arrays asociativos ni ${x^^}).

# drift_chequea_repo <ROOT> [DRY_RUN]
drift_chequea_repo() {
  local ROOT="$1" DRY_RUN=0
  case "${2:-}" in 1|dry-run|dryrun) DRY_RUN=1 ;; esac
  [ -n "$ROOT" ] || { printf 'STATUS=%s\n' "no-source"; return 0; }

  # ¿repo brained? (sello del sync, o el hook repo-scoped clásico).
  if ! { [ -f "$ROOT/.claude/hooks/.brain-version" ] || [ -f "$ROOT/.claude/hooks/dod-verificar.sh" ]; }; then
    printf 'STATUS=%s\n' "not-brained"; return 0
  fi

  # Fuente canónica LOCAL del cerebro = el clon de instalación (lo actualiza el one-liner/bootstrap).
  local BRAIN_DIR SYNC
  BRAIN_DIR="${CLAUDE_BRAIN_DIR:-$HOME/.claude-brain}"
  SYNC="$BRAIN_DIR/brain/sincronizar-cerebro.sh"
  if [ ! -f "$SYNC" ]; then printf 'STATUS=%s\n' "no-source"; return 0; fi

  # ── #46: DISCRIMINAR repo COMPARTIDO vs PERSONAL por la marca .claude/repo-compartido ────────────────
  # (semántica idéntica a la que vivía en el hook; ver diseño [[diseno-rediseno-auto-sync-46]])
  if [ ! -f "$ROOT/.claude/repo-compartido" ]; then
    # ── PERSONAL: guards por-repo NUNCA → NO commit/push; si SOBRAN, FLAG a quitar. La memoria/skills del
    # repo son SUYOS (no del brain) → no son "drift". "Sobran" = .sh en .claude/hooks que TAMBIÉN existen
    # en la fuente del brain (BRAIN_DIR/brain/hooks); los hooks PROPIOS del repo NO se flaggean.
    local sobran="" _h _b
    if [ -d "$ROOT/.claude/hooks" ] && [ -d "$BRAIN_DIR/brain/hooks" ]; then
      for _h in "$ROOT/.claude/hooks/"*.sh; do
        [ -e "$_h" ] || continue
        _b=$(basename "$_h")
        [ -f "$BRAIN_DIR/brain/hooks/$_b" ] && sobran="$sobran $_b"
      done
    fi
    if [ -n "$sobran" ]; then
      printf 'STATUS=%s\n' "personal-flag"
      printf '%s\n' "🧹 REPO PERSONAL con guards del cerebro que SOBRAN:${sobran}
Quítalos — en un repo PERSONAL el brain GLOBAL + el dedupe ya te cubren, así que una copia por-repo solo puede DRIFTAR y estorbar (una pre-dedupe hasta rompió un merge: caso powerscripts). Los guards por-repo son SOLO para repos COMPARTIDOS (marca \`.claude/repo-compartido\`, que viajan por git a quien no tiene brain global). Tu MEMORIA/SKILLS NO se tocan — son tuyos.
Cómo: borra esos .sh de .claude/hooks/ + sus entradas en .claude/settings.json. NO commiteo ni pusheo nada por ti (personal = sin auto-git). Si en realidad este repo es COMPARTIDO, decláralo con \`touch .claude/repo-compartido\` y re-abre sesión."
      return 0
    fi
    printf 'STATUS=%s\n' "personal-clean"; return 0
  fi

  # ── COMPARTIDO (tiene la marca): el brain por-repo es el CORREO → mantenerlo fresco ──
  # DRY-RUN del sync (sin --apply: NO escribe). Un ERROR del sync (no-cero) o un resumen ausente → NO se
  # pudo determinar el drift → STATUS=unknown: fail-open (el caller surface la identidad pero NO cachea,
  # para reintentar el chequeo en la próxima sesión en vez de sellar un error transitorio como "al día").
  local out resumen nuevos act ret falta total
  out=$(bash "$SYNC" "$ROOT" 2>/dev/null) || { printf 'STATUS=%s\n' "unknown"; return 0; }
  resumen=$(printf '%s\n' "$out" | grep -E '==> resumen:' | tail -1)
  [ -n "$resumen" ] || { printf 'STATUS=%s\n' "unknown"; return 0; }
  nuevos=$(printf '%s' "$resumen" | grep -oE '[0-9]+ nuevos'       | grep -oE '[0-9]+' || echo 0)
  act=$(printf '%s' "$resumen"    | grep -oE '[0-9]+ a actualizar' | grep -oE '[0-9]+' || echo 0)
  ret=$(printf '%s' "$resumen"    | grep -oE '[0-9]+ retirado'     | grep -oE '[0-9]+' || echo 0)
  falta=$(printf '%s' "$resumen"  | grep -oE '[0-9]+ cableado faltante' | grep -oE '[0-9]+' || echo 0)
  total=$(( ${nuevos:-0} + ${act:-0} + ${ret:-0} + ${falta:-0} ))

  if [ "$total" -eq 0 ]; then printf 'STATUS=%s\n' "clean"; return 0; fi

  local detalle
  detalle=$(printf '%s\n' "$out" | grep -E '(NUEVO|ACTUALIZA|RETIRARÍA)' | sed 's/^[[:space:]]*/    /' | head -12)

  # ── Nudge de la DUPLA (suficiencia + coherencia): BIFURCA según AGENTS.md esté instanciado. ──
  local dupla_nota
  if [ -f "$ROOT/AGENTS.md" ]; then
    dupla_nota="
🔎 DUPLA: el cerebro del repo se movió → corre la dupla de auditores (suficiencia + coherencia, van juntas) CONTRA la firma/\`AGENTS.md\` — «¿la realidad sigue cumpliendo la firma?» — antes de integrar/release."
  else
    dupla_nota="
🔎 DUPLA: el cerebro del repo se movió → corre la dupla de auditores (suficiencia + coherencia) para verificar que no rompió nada. (Este repo NO tiene instanciado el esquema firma(\`CLAUDE.md\`)+detalle(\`AGENTS.md\`); la dupla funciona igual — considera instanciarlo para auditar «contra la firma».)"
  fi

  # C2 (FMEA) — GUARD ANTI-REGRESIÓN del auto-sync: si la FUENTE está DETRÁS de su origin/main, aplicarla
  # REGRESARÍA el cerebro y el push lo propagaría → NO auto-aplicar. Guard POSITIVO (tightening puro):
  # fuente_stale=1 SOLO cuando CONFIRMO behind>0; si no hay cómo medir, conserva el comportamiento previo.
  local fuente_stale=0 behind
  if behind=$(git -C "$BRAIN_DIR" rev-list --count HEAD..origin/main 2>/dev/null); then
    case "$behind" in ''|*[!0-9]*) : ;; 0) : ;; *) fuente_stale=1;; esac
  fi

  local cur
  cur=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  # sA3 (FMEA) — mini-develop = `Develop<Usuario>` en PascalCase: Develop + una MAYÚSCULA (clase POSIX
  # [[:upper:]], no rango [A-Z] que en locales UTF-8 puede casar minúsculas).
  case "$cur" in
    Develop[[:upper:]]*)
      if [ "$fuente_stale" = 0 ] && [ -z "$(git -C "$ROOT" status --porcelain -- .claude/ 2>/dev/null)" ]; then
        if [ "$DRY_RUN" = 1 ]; then
          printf 'STATUS=%s\n' "would-sync"
          printf '%s\n' "(dry-run) habría AUTO-SINCRONIZADO la copia por-repo en la mini-develop ($cur): $total archivo(s) atrás. Sin tocar nada (dry-run). Qué cambiaría:
$detalle"
          return 0
        fi
        if bash "$SYNC" "$ROOT" --apply >/dev/null 2>&1 \
           && git -C "$ROOT" add -A .claude/ >/dev/null 2>&1 \
           && git -C "$ROOT" commit -q -o -m "chore(cerebro): auto-sync de la copia por-repo (aviso-drift, $total archivo(s) al día)" -- .claude/ >/dev/null 2>&1; then
          git -C "$ROOT" push -q origin "$cur" >/dev/null 2>&1 || true
          local sha
          sha=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo "?")
          printf 'STATUS=%s\n' "synced"
          printf '%s\n' "🧬✅ CEREBRO AUTO-SINCRONIZADO en tu mini-develop ($cur, commit $sha): la copia por-repo estaba $total archivo(s) atrás y se puso al día SOLA (apply+commit+push). Llegará al develop compartido con tu próxima integración coordinada. Qué cambió:
$detalle$dupla_nota"
          return 0
        fi
      fi
      ;;
  esac

  # Si la fuente está STALE (C2), avisarlo: propagar desde una fuente vieja regresaría el brain.
  local stale_nota=""
  [ "$fuente_stale" = 1 ] && stale_nota="
⚠️ OJO (anti-regresión C2): tu FUENTE del cerebro ($BRAIN_DIR) parece DETRÁS de su origin/main — NO auto-sincronicé para no regresar el brain. Actualiza la fuente primero (\`git -C $BRAIN_DIR pull --ff-only\` o abre el widget) y reabre sesión."
  printf 'STATUS=%s\n' "drift"
  printf '%s\n' "🧠⚠️ DRIFT DEL CEREBRO POR-REPO: la copia en .claude/hooks/ de ESTE repo está ATRÁS de la fuente única del cerebro ($total archivo(s)):
$detalle$stale_nota
Qué hacer: PROPÓN al usuario propagar por el flujo — worktree/ramita desde develop → \`bash $SYNC <worktree> --apply\` → commit → MR a develop. NO edites .claude/hooks/ directo en el árbol de trabajo (en repos compartidos viaja por git y se mezclaría a commits de feature). Nota: en ESTA máquina la copia GLOBAL ya manda (dedupe), pero el drift por-repo afecta a colegas y clones sin bootstrap.$dupla_nota"
  return 0
}
