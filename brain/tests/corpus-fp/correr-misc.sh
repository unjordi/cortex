#!/usr/bin/env bash
# correr-misc.sh — banco del corpus de los guards de 1-2 casos: aviso-drift-cerebro (L127 L171), aviso-contexto
# (L85), limpiar-worktrees (L132), barrer-ramas/limpiar-ramas (L164).
# Corre con `bash brain/tests/corpus-fp/correr-misc.sh`.
#
# NO MAPEAN a un guard vivo del brain (el mensaje "demasiado complejo para verificar / worktree" es del
# permisos/harness de Claude Code, y no existe hook con esos nombres en brain/hooks/ ni en brain/MANIFEST):
#   L49 isolation-guard · L126 aislamiento-worktree · L169 regla-sudo (regla local de la Cachy) ·
#   L130 auditor-coherencia (falso positivo de un AGENTE auditor, no de un guard) ·
#   L10 L12 L13 L48 L150 L151 (proteger-arbol/worktree-isolation, mismo mensaje del harness: se verificó que
#   proteger-arbol calla ante esos comandos — ver correr-proteger-arbol.sh).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib-corpus-fp.sh"
BRAINROOT="$(cd "$HOOKS/../.." && pwd)"

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/cfp-misc.XXXXXX")
manual() {  # manual <linea> <nota> <PASA|FRENA>   (caso del corpus; PASA = el FP ya no ocurre)
  if [ "$3" = PASA ]; then CFP_PASS=$((CFP_PASS+1)); printf '  ✓ PASA  L%-4s %s\n' "$1" "$2"
  else CFP_FPBLOCK=$((CFP_FPBLOCK+1)); CFP_FP_LINES+=("L$1: $2"); printf '  ✗ FRENA L%-4s %s  ← FP sigue vivo\n' "$1" "$2"; fi
}
manual_ctrl() {  # manual_ctrl <nota> <OK|MAL>   (control positivo)
  if [ "$2" = OK ]; then CFP_CTRL_OK=$((CFP_CTRL_OK+1)); printf '  ✓ ctrl+ dispara  %s\n' "$1"
  else CFP_CTRL_BAD=$((CFP_CTRL_BAD+1)); CFP_BROKEN+=("$1"); printf '  ⚠ ctrl+ NO disparó (harness roto / verde falso): %s\n' "$1"; fi
}

echo "== misc · banco del corpus (FP esperan SILENCIO / no-borrar; controles+ esperan DISPARAR) =="

# ───────────────────────── aviso-drift-cerebro (L127, L171) ─────────────────────────
# Repo PERSONAL con dod-verificar/juez-comun/recordar-cosechar/sesion-inicio por-repo: los de tier `repo`
# (MANIFEST) NO sobran. Un hook de tier `both` (entorno-maquina-guard) sí → control positivo.
mkpersonal() {  # mkpersonal <dir> <hooks…>
  local d="$1"; shift; mkdir -p "$d/.claude/hooks"; git init -q -b develop "$d"
  local h; for h in "$@"; do cp "$HOOKS/$h" "$d/.claude/hooks/$h"; done
  : > "$d/.claude/hooks/.brain-version"
}
# aviso-drift marca sobrante SOLO un guard tier `both` CUYA copia GLOBAL está instalada (el dedupe hace ceder
# la copia por-repo). Por eso el fake HOME lleva las GLOBALES instaladas — sin ellas el flag NUNCA dispara y
# el test quedaba VACUO (el control+ no distinguía "no marca tier-repo" de "no marca nada"). GFH bajo ROOT se
# limpia con él. ACTUALIZADO 2026-10-21: sesion-inicio/recordar-cosechar pasaron de tier `repo` a `both` (ver
# MANIFEST) → ahora marcarlos es CORRECTO; el FP vivo (L127/L171) es NO marcar el tier `repo` (dod-verificar)
# ni la lib `both` que una hook-repo PRESENTE sourcea (juez-comun ← dod-verificar).
GFH="$ROOT/gfh"; mkdir -p "$GFH/.claude/hooks"
for h in entorno-maquina-guard.sh dod-verificar.sh juez-comun.sh recordar-cosechar.sh sesion-inicio.sh; do cp "$HOOKS/$h" "$GFH/.claude/hooks/$h"; done
drift() {  # drift <repo> → stdout del hook (HOME con las GLOBALES instaladas)
  env HOME="$GFH" CLAUDE_PROJECT_DIR="$1" CLAUDE_BRAIN_DIR="$BRAINROOT" AVISO_DRIFT_HORAS=0 bash "$HOOKS/aviso-drift-cerebro.sh" </dev/null 2>/dev/null
}
P1="$ROOT/p1"; mkpersonal "$P1" dod-verificar.sh juez-comun.sh recordar-cosechar.sh sesion-inicio.sh
out=$(drift "$P1")
flag=$(printf '%s' "$out" | grep -o 'SOBRAN:[^\\]*' | head -1)
# FP L127/L171: el tier `repo` (dod-verificar) y la lib `both` que ESA hook-repo sourcea (juez-comun) NO se marcan.
bad=""; for h in dod-verificar.sh juez-comun.sh; do printf '%s' "$flag" | grep -q "$h" && bad="$bad $h"; done
for L in 127 171; do
  if [ -z "$bad" ]; then manual "$L" "aviso-drift NO marca sobrante el guard tier repo (dod-verificar) ni la lib both que éste sourcea (juez-comun)" PASA
  else manual "$L" "aviso-drift marca sobrante un tier repo / su lib:${bad}" FRENA; fi
done
# control+ A: un tier `both` (entorno-maquina-guard) con su global instalado SÍ se marca sobrante en personal.
P2="$ROOT/p2"; mkpersonal "$P2" entorno-maquina-guard.sh
out2=$(drift "$P2")
if printf '%s' "$out2" | grep -o 'SOBRAN:[^\\]*' | head -1 | grep -q 'entorno-maquina-guard.sh'; then manual_ctrl "ctrl+ aviso-drift SÍ marca un hook tier both (entorno-maquina-guard.sh) sobrante en repo personal" OK
else manual_ctrl "ctrl+ aviso-drift SÍ marca un hook tier both (entorno-maquina-guard.sh) sobrante en repo personal" MAL; fi
# control+ B: sesion-inicio/recordar-cosechar (tier repo→both desde 2026-10-21) SÍ se marcan en P1 — prueba que
# el flag discrimina POR TIER (si solo callara, L127/L171 sería vacuo; esto le da dientes al "no marca dod").
if printf '%s' "$flag" | grep -q 'sesion-inicio.sh' && printf '%s' "$flag" | grep -q 'recordar-cosechar.sh'; then manual_ctrl "ctrl+ aviso-drift SÍ marca sesion-inicio/recordar-cosechar (tier both desde 2026-10-21) sobrantes" OK
else manual_ctrl "ctrl+ aviso-drift SÍ marca sesion-inicio/recordar-cosechar (tier both) sobrantes" MAL; fi

# ───────────────────────── aviso-contexto (L85) ─────────────────────────
# Tras un /compact recién hecho (boundary isCompactSummary, sin usage posterior) NO debe reportar el ctx viejo.
mkctx() {  # mkctx <dir>
  mkdir -p "$1/.claude/memory"; git init -q -b develop "$1"
}
big='{"type":"assistant","message":{"role":"assistant","usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":944000},"content":[{"type":"text","text":"x"}]}}'
AC1="$ROOT/ac1"; mkctx "$AC1"
printf '%s\n%s\n' "$big" '{"type":"user","isCompactSummary":true,"message":{"role":"user","content":"resumen del compact"}}' > "$ROOT/tx-compact.jsonl"
export CFP_MODE=aviso
CFP_TX="$ROOT/tx-compact.jsonl" CFP_ENV="CLAUDE_BRAIN_DIR=$BRAINROOT AVISO_CONTEXTO_WINDOW_TOKENS=1000000" \
  cfp_caso "$HOOKS/aviso-contexto.sh" 85 "ctx alto PRE-compact + boundary /compact sin usage posterior → silencio" x "$AC1" pass
AC2="$ROOT/ac2"; mkctx "$AC2"
printf '%s\n' "$big" > "$ROOT/tx-nocompact.jsonl"
CFP_TX="$ROOT/tx-nocompact.jsonl" CFP_ENV="CLAUDE_BRAIN_DIR=$BRAINROOT AVISO_CONTEXTO_WINDOW_TOKENS=1000000" \
  cfp_caso "$HOOKS/aviso-contexto.sh" - "ctrl+ ctx alto (944K de 1M) SIN compact → avisa" x "$AC2" block

# ───────────────────────── limpiar-worktrees (L132) ─────────────────────────
# Rama pusheada con 2 commits, integrada a develop por SQUASH multi-commit (sin patch-equivalencia ni 'Rama:'),
# con su PR MERGEADO (señal d, inyectada con CLAUDE_BZ_PRCACHE): el barredor NO debe dejar un pendiente falso.
BARE="$ROOT/o.git"; WR="$ROOT/wr"
git init -q --bare "$BARE"; git init -q -b develop "$WR"
w() { git -C "$WR" "$@" >/dev/null 2>&1; }
w config user.email t@t; w config user.name t; w remote add origin "$BARE"
mkdir -p "$WR/.claude/memory"; printf '# bitacora\n' > "$WR/.claude/memory/bitacora.md"
printf 'b\n' > "$WR/b.txt"; w add -A; w commit -q -m base; w push -q origin develop
w branch fix/cd-arbol; w worktree add -q "$ROOT/wt-cd" fix/cd-arbol
for i in 1 2; do printf 'c%s\n' "$i" > "$ROOT/wt-cd/c$i.txt"; git -C "$ROOT/wt-cd" add -A >/dev/null 2>&1; git -C "$ROOT/wt-cd" commit -q -m "c$i" >/dev/null 2>&1; done
git -C "$ROOT/wt-cd" push -q origin fix/cd-arbol >/dev/null 2>&1
TIP=$(git -C "$WR" rev-parse fix/cd-arbol)
w merge --squash fix/cd-arbol; w commit -q -m "feat: squash del PR sin pie de rama"; w push -q origin develop
printf 'fix/cd-arbol\t%s\n' "$TIP" > "$ROOT/prcache"
FH=$(cfp_fakehome)
( cd "$WR" && env HOME="$FH" CLAUDE_BZ_PRCACHE="$ROOT/prcache" bash "$HOOKS/limpiar-impl-worktrees.sh" >/dev/null 2>&1 )
rm -rf "$FH"
if grep -q 'worktrees pendientes' "$WR/.claude/memory/bitacora.md"; then manual 132 "worktree de rama con PR MERGEADO (squash multi-commit) deja un PENDIENTE falso en la bitácora" FRENA
else manual 132 "worktree de rama con PR MERGEADO (squash multi-commit): sin pendiente falso en la bitácora" PASA; fi
# control+: rama con commits propios SIN integrar y SIN PR mergeado → SÍ deja pendiente
w branch feat/viva; w worktree add -q "$ROOT/wt-viva" feat/viva
printf 'v\n' > "$ROOT/wt-viva/v.txt"; git -C "$ROOT/wt-viva" add -A >/dev/null 2>&1; git -C "$ROOT/wt-viva" commit -q -m viva >/dev/null 2>&1
FH=$(cfp_fakehome)
( cd "$WR" && env HOME="$FH" CLAUDE_BZ_PRCACHE="$ROOT/prcache" bash "$HOOKS/limpiar-impl-worktrees.sh" >/dev/null 2>&1 )
rm -rf "$FH"
if grep -q 'worktrees pendientes' "$WR/.claude/memory/bitacora.md"; then manual_ctrl "ctrl+ worktree con trabajo sin integrar SÍ deja pendiente en la bitácora" OK
else manual_ctrl "ctrl+ worktree con trabajo sin integrar SÍ deja pendiente en la bitácora" MAL; fi

# ───────────────────────── barrer-ramas / limpiar-ramas (L164) ─────────────────────────
# Remota SIN local 'epic-benchmarks-fixes' (mini de tema re-sembrada = develop): NO debe borrarse del remoto.
BR="$ROOT/br"; BB="$ROOT/ob.git"
git init -q --bare "$BB"; git init -q -b develop "$BR"
b() { git -C "$BR" "$@" >/dev/null 2>&1; }
b config user.email t@t; b config user.name t; b remote add origin "$BB"
mkdir -p "$BR/.claude/memory"; printf '# bitacora\n' > "$BR/.claude/memory/bitacora.md"
printf 'b\n' > "$BR/b.txt"; b add -A; b commit -q -m base; b push -q origin develop
b branch epic-benchmarks-fixes; b push -q origin epic-benchmarks-fixes; b branch -D epic-benchmarks-fixes
b branch viva-remota; printf 'x\n' > "$BR/x.txt"; b checkout -q viva-remota; b add -A; b commit -q -m trabajo; b push -q origin viva-remota; b checkout -q develop; b branch -D viva-remota
FH=$(cfp_fakehome)
( cd "$BR" && env HOME="$FH" bash "$HOOKS/limpiar-impl-ramas.sh" >/dev/null 2>&1 )
rm -rf "$FH"
if git -C "$BR" ls-remote --heads origin epic-benchmarks-fixes 2>/dev/null | grep -q epic-benchmarks-fixes; then manual 164 "limpiar-ramas NO borra la remota de una mini de tema (epic-*) re-sembrada = develop" PASA
else manual 164 "limpiar-ramas BORRÓ la remota 'epic-benchmarks-fixes' (mini de tema re-sembrada = develop)" FRENA; fi
if git -C "$BR" ls-remote --heads origin viva-remota 2>/dev/null | grep -q viva-remota; then manual_ctrl "ctrl+ limpiar-ramas CONSERVA una remota con trabajo sin integrar" OK
else manual_ctrl "ctrl+ limpiar-ramas CONSERVA una remota con trabajo sin integrar" MAL; fi

# ───────────────────────── barrer-ramas vía (B) · repo del merge por --repo (L187) ─────────────────────────
# Un `gh pr merge --repo <slug>` corrido desde OTRO repo barre el repo del SLUG (su clon local), NO el cwd
# (corpus L187: barrió plantilladotnet en vez de PowerScripts). El aviso del hook nombra "EN <ROOT>".
L187C="$ROOT/code187"; mkdir -p "$L187C"
mk187() { local d="$L187C/$1"; git init -q -b develop "$d"; git -C "$d" config user.email t@t; git -C "$d" config user.name t; git -C "$d" remote add origin "git@github.com:$2.git"; printf x > "$d/f"; git -C "$d" add -A >/dev/null 2>&1; git -C "$d" commit -q -m base >/dev/null 2>&1; }
mk187 plantilladotnet unjordi/plantilladotnet
mk187 PowerScripts    unjordi/PowerScripts
bramas_en() {  # $1=cmd $2=cwd → el ROOT que nombra el aviso ("EN <root>"), o vacío si hace skip
  local fh out; fh=$(cfp_fakehome)
  out=$(jq -nc --arg c "$1" --arg cwd "$2" '{tool_name:"Bash",tool_input:{command:$c},cwd:$cwd}' | env HOME="$fh" bash "$HOOKS/barrer-ramas.sh" 2>/dev/null | grep -o 'EN [^ ]*' | head -1 | sed 's/^EN //')
  rm -rf "$fh"; printf '%s' "$out"
}
en=$(bramas_en 'gh pr merge 238 --repo unjordi/PowerScripts --squash --delete-branch' "$L187C/plantilladotnet")
case "$en" in */PowerScripts) manual 187 "barrer-ramas resuelve el repo del merge por --repo <slug> (barre PowerScripts, NO el cwd plantilladotnet)" PASA ;;
  *) manual 187 "barrer-ramas barrió '$en' (debía ser el clon de --repo unjordi/PowerScripts, no el cwd)" FRENA ;; esac
en2=$(bramas_en 'gh pr merge 5 --squash --delete-branch' "$L187C/plantilladotnet")
case "$en2" in */plantilladotnet) manual_ctrl "ctrl+ barrer-ramas SIN --repo barre el cwd (plantilladotnet)" OK ;; *) manual_ctrl "ctrl+ barrer-ramas SIN --repo barre el cwd — barrió '$en2'" MAL ;; esac
en3=$(bramas_en 'gh pr merge 9 --repo $R --squash' "$L187C/plantilladotnet")
case "$en3" in '') manual_ctrl "ctrl+ barrer-ramas con --repo \$VAR opaco → NO barre a ciegas (skip, es un DELETE)" OK ;; *) manual_ctrl "ctrl+ barrer-ramas con --repo \$VAR opaco barrió '$en3' (debía skip)" MAL ;; esac

cfp_reporte misc
rm -rf "$ROOT"
[ "$CFP_CTRL_BAD" -eq 0 ] || exit 2
