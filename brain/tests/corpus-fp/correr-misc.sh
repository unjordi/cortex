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
# (MANIFEST) NO sobran. Un hook de tier `both` (secret-scan) sí → control positivo.
mkpersonal() {  # mkpersonal <dir> <hooks…>
  local d="$1"; shift; mkdir -p "$d/.claude/hooks"; git init -q -b develop "$d"
  local h; for h in "$@"; do cp "$HOOKS/$h" "$d/.claude/hooks/$h"; done
  : > "$d/.claude/hooks/.brain-version"
}
drift() {  # drift <repo> → stdout del hook
  local fh; fh=$(cfp_fakehome)
  env HOME="$fh" CLAUDE_PROJECT_DIR="$1" CLAUDE_BRAIN_DIR="$BRAINROOT" AVISO_DRIFT_HORAS=0 bash "$HOOKS/aviso-drift-cerebro.sh" </dev/null 2>/dev/null
  rm -rf "$fh"
}
P1="$ROOT/p1"; mkpersonal "$P1" dod-verificar.sh juez-comun.sh recordar-cosechar.sh sesion-inicio.sh
out=$(drift "$P1")
flag=$(printf '%s' "$out" | grep -o 'SOBRAN:[^\\]*' | head -1)
bad=""; for h in dod-verificar.sh sesion-inicio.sh recordar-cosechar.sh juez-comun.sh; do printf '%s' "$flag" | grep -q "$h" && bad="$bad $h"; done
for L in 127 171; do
  if [ -z "$bad" ]; then manual "$L" "aviso-drift NO marca como SOBRANTES los guards tier repo (dod-verificar, sesion-inicio, recordar-cosechar) ni juez-comun" PASA
  else manual "$L" "aviso-drift marca como SOBRANTES guards tier repo del MANIFEST (+ juez-comun, la lib que dod carga):${bad}" FRENA; fi
done
P2="$ROOT/p2"; mkpersonal "$P2" secret-scan.sh
out2=$(drift "$P2")
if printf '%s' "$out2" | grep -o 'SOBRAN:[^\\]*' | head -1 | grep -q 'secret-scan.sh'; then manual_ctrl "ctrl+ aviso-drift SÍ marca un hook tier both (secret-scan.sh) sobrante en repo personal" OK
else manual_ctrl "ctrl+ aviso-drift SÍ marca un hook tier both (secret-scan.sh) sobrante en repo personal" MAL; fi

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

cfp_reporte misc
rm -rf "$ROOT"
[ "$CFP_CTRL_BAD" -eq 0 ] || exit 2
