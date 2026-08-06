#!/usr/bin/env bash
# aviso-drift-cerebro.sh — SessionStart hook (tier GLOBAL). Al INICIAR sesión en un repo que tiene el
# cerebro POR-REPO instalado (sello .brain-version o el hook repo-scoped clásico), compara esa copia
# contra la FUENTE ÚNICA local (el clon de instalación ~/.claude-brain, o $CLAUDE_BRAIN_DIR) usando
# sincronizar-cerebro.sh en DRY-RUN (diff-aware por CONTENIDO — comparar versiones NO sirve: VERSION
# no se bumpea por cambio) y, si la copia quedó ATRÁS, INYECTA un aviso ruidoso vía additionalContext.
#
# REDISEÑO #46 (unjordi + gemelo cachy, 2026-08-05) — BIFURCA por la marca `.claude/repo-compartido`:
# - COMPARTIDO (tiene la marca): el brain por-repo es un CORREO que viaja por git a quien NO tiene brain
#   global (colegas/clones) → hay que mantenerlo fresco. Comportamiento de siempre: detecta drift, auto-
#   apply+commit+push en tu mini-develop con .claude/ limpio, o AVISA para propagar por el flujo.
# - PERSONAL (sin la marca, el DEFAULT): guards por-repo NUNCA (tu máquina los saca del install GLOBAL +
#   dedupe; una copia por-repo solo drifta/estorba). NO auto-commit/push; si el repo tiene guards del brain
#   que SOBRAN, los FLAGGEA para quitar (opción B; no los borra solos). La memoria/skills son suyos, no se tocan.
# Norma que nace con esto: "repo personal = memoria/skills, NUNCA guards por-repo" (en global-claude-md.md).
# Diseño completo: memoria [[diseno-rediseno-auto-sync-46]].
#
# Diseño de unjordi (2026-07-18): "es tan sencillo como poner un hook en el global para que en el
# inicio de sesión revise que el local y global sean el mismo y actualice el local si no" — con dos
# matices acordados en la misma conversación: (a) el comparador es el DIFF real, no la versión; (b) en
# repos COMPARTIDOS "actualizar el local" = commit por ramita→MR, así que este hook NO escribe NADA al
# árbol (un write silencioso ensuciaría el working tree y se mezclaría a commits de feature): DETECTA
# y AVISA para que Claude proponga la propagación por el flujo. Evidencia de necesidad: MegaFlux
# acumuló 9 archivos de drift porque nadie corría el sync (detectado 2026-07-18).
#
# Throttle: si el último chequeo de ESTE repo salió LIMPIO, no se re-chequea por AVISO_DRIFT_HORAS
# (default 6; stamp en ~/.claude/memory/.drift-cerebro/). Un chequeo CON drift no se cachea → avisa en
# cada inicio de sesión hasta que se propague (esa insistencia es el punto).
# Fail-open SIEMPRE: sin clon canónico / repo no-brained / cualquier error del sync → silencio.
#
# RECORDATORIO DE LA DUPLA (2026-07-31): cuando el cerebro de este repo CAMBIA (auto-sync) o está por
# hacerlo (drift), es el momento de "¿la realidad sigue cumpliendo la firma?" → el aviso añade un nudge a
# correr la DUPLA de auditores (suficiencia + coherencia, van juntas). Se cuelga de ESTE hook (que ya corre
# SessionStart + ya llama a sincronizar + ya sabe cuándo el cerebro se movió) en vez de un hook nuevo.
# BIFURCA por el esquema firma+detalle: si el repo tiene AGENTS.md instanciado → "audita CONTRA la firma";
# si NO → la dupla igual funciona (suficiencia deriva su lista; coherencia caza contradicciones) y se sugiere
# instanciar el esquema. NUNCA lo asume — la mayoría de los repos aún no tienen firma=TOC (hoy solo games-master).
#
# CUÁNDO CORRE (verificado 2026-07-31 vs doc oficial de hooks + evidencia real — NO re-investigar):
# SessionStart dispara con source ∈ {startup, resume, clear, compact, fork} — NO solo en arranque
# fresco. En particular `claude --resume`/`--continue` → source="resume", y cada `/compact` (auto o
# manual) → source="compact", LO DISPARAN. Este hook se cablea SIN matcher → corre en TODOS esos
# source (la doc no lo jura literal para el matcher omitido, pero el commit real que este hook genera
# — "chore(cerebro): auto-sync de la copia por-repo (aviso-drift, …)" — lo DEMUESTRA empíricamente).
# Importa porque el flujo real es casi todo --resume + sesiones largas que compactan: la auto-sync se
# re-chequea en cada resume Y en cada compactación, sin depender de abrir claudes frescos.
# Doc: code.claude.com/docs/en/hooks (tabla SessionStart + "Hooks can be re-run on resume with
# --continue or --resume (source = resume or fork)").
set -u

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cat >/dev/null 2>&1 || true   # drenar stdin (contrato SessionStart)

# ── CONOCIMIENTO PROPIO (per-repo, imborrable) ──────────────────────────────────────────────────────
# Si el repo tiene .claude/memory/conocimiento-propio.md, se RE-INYECTA en CADA SessionStart
# (fresh/resume/compact) — ANTES del throttle y del drift, para que la identidad del proyecto vuelva
# SIEMPRE (no dependa de que haya drift ni del cache de 6h). Es PER-REPO: cada repo tiene el suyo (o
# ninguno) → "cada sesión con una personalidad ligeramente distinta"; este hook es GLOBAL y solo lo
# SURFACE si el archivo existe (no lo propaga ni lo asume universal). Diseño de unjordi (2026-07-31):
# "asienta ese conocimiento propio amarrado al mismo hook" — el que ya dispara fiable en resume/compact,
# para que "el conocimiento más básico que tienes sobre ti mismo no se te pueda borrar".
SELF=""
# Prefiere la variante PERSONAL/LOCAL (.local.md → gitignored: no viaja al repo público ni al de un
# colega); cae a la .md por si un repo quiere una identidad COMPARTIDA versionada. Primero que exista gana.
for _self_file in "$ROOT/.claude/memory/conocimiento-propio.local.md" "$ROOT/.claude/memory/conocimiento-propio.md"; do
  [ -f "$_self_file" ] && { SELF="$(cat "$_self_file" 2>/dev/null || true)"; break; }
done

# emit_and_exit [contexto-de-drift] — emite additionalContext UNA sola vez, anteponiendo el conocimiento
# propio (si existe) al contexto de drift/auto-sync (si lo hay). Sin ninguno de los dos → silencio.
emit_and_exit() {
  local extra="${1:-}" out=""
  if [ -n "$SELF" ] && [ -n "$extra" ]; then
    out="$SELF

────────────────────────────────────────────────────────────────────────────────

$extra"
  elif [ -n "$SELF" ]; then out="$SELF"
  elif [ -n "$extra" ]; then out="$extra"
  else exit 0
  fi
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg c "$out" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
  else
    printf '%s\n' "$out"
  fi
  exit 0
}

# ¿repo brained? (sello del sync, o el hook repo-scoped clásico). El drift-check SÍ requiere cerebro;
# la identidad NO → si el repo no está brained pero trae conocimiento-propio.md, igual se surface.
{ [ -f "$ROOT/.claude/hooks/.brain-version" ] || [ -f "$ROOT/.claude/hooks/dod-verificar.sh" ]; } || emit_and_exit ""

# Fuente canónica LOCAL del cerebro = el clon de instalación (lo actualiza el one-liner/bootstrap).
BRAIN_DIR="${CLAUDE_BRAIN_DIR:-$HOME/.claude-brain}"
SYNC="$BRAIN_DIR/brain/sincronizar-cerebro.sh"
[ -f "$SYNC" ] || emit_and_exit ""

# Throttle por repo (solo cachea chequeos LIMPIOS).
horas="${AVISO_DRIFT_HORAS:-6}"; case "$horas" in ''|*[!0-9]*) horas=6;; esac
stampdir="$HOME/.claude/memory/.drift-cerebro"; mkdir -p "$stampdir" 2>/dev/null || true
slug=$(printf '%s' "$ROOT" | cksum 2>/dev/null | awk '{print $1}')
stamp="$stampdir/${slug:-0}"
now=$(date +%s)
if [ -f "$stamp" ]; then
  last=$(cat "$stamp" 2>/dev/null || echo 0)
  case "$last" in ''|*[!0-9]*) last=0;; esac
  [ $(( now - last )) -lt $(( horas * 3600 )) ] && emit_and_exit ""
fi

# ── #46: DISCRIMINAR repo COMPARTIDO vs PERSONAL por la marca .claude/repo-compartido ────────────────
# El brain por-repo es un CORREO: existe SOLO para viajar por git a máquinas/personas SIN brain global
# (colegas, clones de repos COMPARTIDOS). TU máquina saca los guards del install GLOBAL + el DEDUPE (la
# línea `case "$0" ... exit 0` que hace ceder la copia por-repo a la global). Por eso un repo PERSONAL (git
# o Drive, solo tus máquinas con brain) NO debe llevar guards por-repo — solo memoria/skills; el global ya
# lo cubre y una copia por-repo solo puede DRIFTAR y estorbar (una pre-dedupe hasta romper: caso powerscripts).
# Un repo COMPARTIDO SÍ los lleva (en git, para quien no tiene brain global) y se marca con
# `.claude/repo-compartido` (la MISMA marca que ya usa el juez confirmar-merge-develop). Default = PERSONAL
# (sin marca): conservador, no auto-empuja a git por accidente. Decisión B (unjordi 2026-08-05): en personal
# NO se meten guards por-repo y los que SOBREN se FLAGGEAN para quitar (no se borran solos → no destructivo).
# Ver el diseño completo en la memoria [[diseno-rediseno-auto-sync-46]].
if [ ! -f "$ROOT/.claude/repo-compartido" ]; then
  # ── PERSONAL: guards por-repo NUNCA → NO commit/push; si SOBRAN, FLAG a quitar. La memoria/skills del
  # repo son SUYOS (no del brain) → el sync NO los toca, no son "drift". La métrica aquí NO es el drift-vs-
  # fuente (eso es para el correo COMPARTIDO) sino "¿tiene guards del brain que sobran?". "Sobran" = .sh en
  # .claude/hooks que TAMBIÉN existen en la fuente del brain (BRAIN_DIR/brain/hooks); los hooks PROPIOS del
  # repo (p. ej. gate-steam-edicion.sh) NO están en la fuente → no se flaggean. Fail-open: si algo raro, silencio.
  sobran=""
  if [ -d "$ROOT/.claude/hooks" ] && [ -d "$BRAIN_DIR/brain/hooks" ]; then
    for _h in "$ROOT/.claude/hooks/"*.sh; do
      [ -e "$_h" ] || continue
      _b=$(basename "$_h")
      [ -f "$BRAIN_DIR/brain/hooks/$_b" ] && sobran="$sobran $_b"
    done
  fi
  if [ -n "$sobran" ]; then
    emit_and_exit "🧹 REPO PERSONAL con guards del cerebro que SOBRAN:${sobran}
Quítalos — en un repo PERSONAL el brain GLOBAL + el dedupe ya te cubren, así que una copia por-repo solo puede DRIFTAR y estorbar (una pre-dedupe hasta rompió un merge: caso powerscripts). Los guards por-repo son SOLO para repos COMPARTIDOS (marca \`.claude/repo-compartido\`, que viajan por git a quien no tiene brain global). Tu MEMORIA/SKILLS NO se tocan — son tuyos.
Cómo: borra esos .sh de .claude/hooks/ + sus entradas en .claude/settings.json. NO commiteo ni pusheo nada por ti (personal = sin auto-git). Si en realidad este repo es COMPARTIDO, decláralo con \`touch .claude/repo-compartido\` y re-abre sesión."
    # NO cachea (como el aviso de drift): insiste en cada arranque hasta que se limpien.
  fi
  # Personal SANO (memoria/skills, cero guards del brain) → nada que hacer; cachea limpio.
  printf '%s' "$now" > "$stamp" 2>/dev/null || true
  emit_and_exit ""
fi

# ── COMPARTIDO (tiene la marca): el brain por-repo es el CORREO → mantenerlo fresco (comportamiento de
# siempre: detecta drift; auto-apply+commit+push si estás en tu mini con .claude/ limpio; si no, AVISA). ──
# DRY-RUN del sync (sin --apply: NO escribe). Error del sync → fail-open.
out=$(bash "$SYNC" "$ROOT" 2>/dev/null) || exit 0
resumen=$(printf '%s\n' "$out" | grep -E '==> resumen:' | tail -1)
[ -n "$resumen" ] || exit 0
nuevos=$(printf '%s' "$resumen" | grep -oE '[0-9]+ nuevos'       | grep -oE '[0-9]+' || echo 0)
act=$(printf '%s' "$resumen"    | grep -oE '[0-9]+ a actualizar' | grep -oE '[0-9]+' || echo 0)
# Los hooks RETIRADOS del cerebro que siguen colgados en el repo TAMBIÉN son drift (antes no se
# contaban → un repo con solo un hook retirado por limpiar se veía "al día" y nunca se sincronizaba,
# dejando p. ej. precompact-volcar-estado cableado y rompiendo el CLI). El --apply del auto-sync los
# poda solo (lista RETIRED), sin --prune-orphans.
ret=$(printf '%s' "$resumen"    | grep -oE '[0-9]+ retirado'     | grep -oE '[0-9]+' || echo 0)
# Drift de CABLEADO: hooks presentes en .claude/hooks pero cuyo comando NO está en settings.json.
# Antes este hook era CIEGO al wiring (solo sumaba nuevos+act+ret) → un repo con "0 nuevos · 0 a
# actualizar · N cableado faltante" se reportaba "al día" aunque tuviera hooks sin cablear (bug ALTO,
# comprobado en la plantilla). sincronizar ahora reporta "N cableado faltante" y aquí lo contamos.
falta=$(printf '%s' "$resumen"  | grep -oE '[0-9]+ cableado faltante' | grep -oE '[0-9]+' || echo 0)
total=$(( ${nuevos:-0} + ${act:-0} + ${ret:-0} + ${falta:-0} ))

if [ "$total" -eq 0 ]; then
  printf '%s' "$now" > "$stamp" 2>/dev/null || true
  emit_and_exit ""
fi

detalle=$(printf '%s\n' "$out" | grep -E '(NUEVO|ACTUALIZA|RETIRARÍA)' | sed 's/^[[:space:]]*/    /' | head -12)

# ── Nudge de la DUPLA (suficiencia + coherencia): el cerebro del repo se movió → verifica que sigue
# coherente y operable. BIFURCA según el esquema firma+detalle esté instanciado (AGENTS.md presente). La
# dupla FUNCIONA sin firma; solo cambia el encuadre. Se APPENDEA a los dos mensajes de abajo (auto-sync y drift).
if [ -f "$ROOT/AGENTS.md" ]; then
  dupla_nota="
🔎 DUPLA: el cerebro del repo se movió → corre la dupla de auditores (suficiencia + coherencia, van juntas) CONTRA la firma/\`AGENTS.md\` — «¿la realidad sigue cumpliendo la firma?» — antes de integrar/release."
else
  dupla_nota="
🔎 DUPLA: el cerebro del repo se movió → corre la dupla de auditores (suficiencia + coherencia) para verificar que no rompió nada. (Este repo NO tiene instanciado el esquema firma(\`CLAUDE.md\`)+detalle(\`AGENTS.md\`); la dupla funciona igual — considera instanciarlo para auditar «contra la firma».)"
fi

# CONCURRENCIA con barrer-ramas (el OTRO SessionStart que MUTA git): SUPUESTO EXPLÍCITO de INDEPENDENCIA.
# El auto-apply de abajo hace commit+push en la rama ACTUAL (una mini-develop Develop*); barrer-ramas
# lanza detached un `git branch -d/-D` de ramas ZOMBIE que NUNCA incluyen actual/base/develop/main/
# Develop*/keep/*. Son refs DISJUNTOS y `git branch -d` no toma `.git/index.lock` (este commit sí, pero
# el branch -d no) → no compiten por el índice ni por el ref de la rama actual. Contención posible solo
# transitoria en packed-refs.lock; ambos lados son fail-open (el push es `|| true`) → degrada sin
# corromper. Ver el comentario gemelo en barrer-ramas.sh. Por eso NO se serializan.
#
# ── AUTO-APPLY en TU mini-develop (v2 — con el modelo MINI-DEVELOP institucionalizado): si la sesión
# abre parada EN una mini-develop (convención Develop<Usuario>) y .claude/ está LIMPIO, el cerebro se
# actualiza SOLO: apply + commit + push a tu mini (permitido: es tu rama personal; el cambio llega a
# develop con tu siguiente integración coordinada). En cualquier otra rama, o con .claude/ sucio, o si
# cualquier paso falla → cae al AVISO de abajo (fail-safe: nunca ensucia una ramita de feature).
# C2 (FMEA) — GUARD ANTI-REGRESIÓN del auto-sync: el sync copia FUENTE ($BRAIN_DIR) → repo SIEMPRE, sin
# mirar quién es más nuevo. Si la FUENTE es un install-clone DETRÁS de su propio origin/main (no se
# actualizó — el updater del widget la mantiene en main por `merge --ff-only origin/main`), aplicarla puede
# REGRESAR el cerebro del repo a un estado viejo y el push de abajo PROPAGARÍA esa regresión. Por eso NO
# auto-aplicamos cuando la fuente está atrás. Se mide con el ref LOCAL origin/main (último fetch) → sin red,
# DETERMINISTA. Guard POSITIVO (tightening puro): fuente_stale=1 SOLO cuando CONFIRMO behind>0; si no hay
# cómo medir (fuente no-git, sin origin/main, parse raro) conserva el comportamiento previo (auto-aplica) →
# no regresa el feature, solo bloquea el riesgo medible.
fuente_stale=0
if behind=$(git -C "$BRAIN_DIR" rev-list --count HEAD..origin/main 2>/dev/null); then
  case "$behind" in ''|*[!0-9]*) : ;; 0) : ;; *) fuente_stale=1;; esac
fi

cur=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
# sA3 (FMEA) — el patrón de mini-develop es `Develop<Usuario>` en PascalCase (DevelopUnjordi, DevelopChunito):
# Develop + una MAYÚSCULA. `Develop?*` (viejo) casaba cualquier char → una rama "Development"/"Developx" se
# trataba falsamente como mini-develop y recibía auto-push. `Develop[[:upper:]]*` exige la mayúscula del
# <Usuario>. Se usa la CLASE POSIX `[[:upper:]]` (no el rango `[A-Z]`, que en locales UTF-8 con collation
# a-A-b-B… puede casar minúsculas → `Developer` volvería a colarse; B2 del FMEA post-integración 2026-07-30).
case "$cur" in
  Develop[[:upper:]]*)
    # Precondición y staging cubren el MISMO alcance (.claude/) COHERENTEMENTE: sincronizar --apply
    # reescribe tanto .claude/hooks/ (copias + .brain-version) COMO .claude/settings.json (cablea/
    # de-cablea vía register_hook/dewire_hook). Antes se stageaba solo .claude/hooks → el cambio de
    # cableado (settings.json) quedaba SIN commitear y el wiring nunca viajaba (bug de costura ALTO).
    # `git add -A .claude/` stagea AMBOS paths + las PODAS (hooks retirados borrados por --apply), y no
    # revienta si settings.json aún no existe (el precheck ya garantiza que .claude/ estaba LIMPIO, así
    # que lo único que se stagea es lo que produjo este --apply).
    # `git commit -o -- .claude/` (sA3): commit ACOTADO al path .claude/ (--only). El precheck garantiza
    # .claude/ limpio, pero NO el resto del árbol: sin el pathspec, un `git commit` pelón barrería a este
    # commit de auto-sync cualquier OTRO cambio staged del usuario (p. ej. src/ a medio trabajar). Con -o
    # solo entra .claude/ (mods + altas + PODAS de hooks retirados dentro de ese path).
    if [ "$fuente_stale" = 0 ] \
       && [ -z "$(git -C "$ROOT" status --porcelain -- .claude/ 2>/dev/null)" ] \
       && bash "$SYNC" "$ROOT" --apply >/dev/null 2>&1 \
       && git -C "$ROOT" add -A .claude/ >/dev/null 2>&1 \
       && git -C "$ROOT" commit -q -o -m "chore(cerebro): auto-sync de la copia por-repo (aviso-drift, $total archivo(s) al día)" -- .claude/ >/dev/null 2>&1; then
      git -C "$ROOT" push -q origin "$cur" >/dev/null 2>&1 || true
      sha=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo "?")
      ctx="🧬✅ CEREBRO AUTO-SINCRONIZADO en tu mini-develop ($cur, commit $sha): la copia por-repo estaba $total archivo(s) atrás y se puso al día SOLA (apply+commit+push). Llegará al develop compartido con tu próxima integración coordinada. Qué cambió:
$detalle$dupla_nota"
      emit_and_exit "$ctx"
    fi;;
esac

# Si la fuente está STALE (C2), avisarlo: propagar desde una fuente vieja regresaría el brain. Primero se actualiza la fuente.
stale_nota=""
[ "$fuente_stale" = 1 ] && stale_nota="
⚠️ OJO (anti-regresión C2): tu FUENTE del cerebro ($BRAIN_DIR) parece DETRÁS de su origin/main — NO auto-sincronicé para no regresar el brain. Actualiza la fuente primero (\`git -C $BRAIN_DIR pull --ff-only\` o abre el widget) y reabre sesión."
ctx="🧠⚠️ DRIFT DEL CEREBRO POR-REPO: la copia en .claude/hooks/ de ESTE repo está ATRÁS de la fuente única del cerebro ($total archivo(s)):
$detalle$stale_nota
Qué hacer: PROPÓN al usuario propagar por el flujo — worktree/ramita desde develop → \`bash $SYNC <worktree> --apply\` → commit → MR a develop. NO edites .claude/hooks/ directo en el árbol de trabajo (en repos compartidos viaja por git y se mezclaría a commits de feature). Nota: en ESTA máquina la copia GLOBAL ya manda (dedupe), pero el drift por-repo afecta a colegas y clones sin bootstrap.$dupla_nota"

emit_and_exit "$ctx"
