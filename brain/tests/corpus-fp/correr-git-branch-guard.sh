#!/usr/bin/env bash
# correr-git-branch-guard.sh — banco del corpus para git-branch-guard (22 casos FP + controles+).
# Corre con `bash brain/tests/corpus-fp/correr-git-branch-guard.sh` (NUNCA en la línea del guard: ver lib).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib-corpus-fp.sh"
GUARD="$HOOKS/git-branch-guard.sh"

# ── FIXTURE: remoto bare + repo en develop + worktree en ramita (upstream) + worktree en chore/x ──
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/cfp-gbg.XXXXXX")
BARE="$ROOT/origin.git"; REPO="$ROOT/repo"
git init -q --bare "$BARE"
git init -q -b develop "$REPO"; ( cd "$REPO"
  git config user.email t@t; git config user.name t
  git remote add origin "$BARE"
  git commit -q --allow-empty -m base
  git push -q origin develop 2>/dev/null
  git checkout -q -b fix/y; git commit -q --allow-empty -m w; git push -q -u origin fix/y 2>/dev/null
  git checkout -q develop
  git worktree add -q "$ROOT/wt-fix" fix/y >/dev/null 2>&1
  git worktree add -q "$ROOT/wt-chore" -b chore/x >/dev/null 2>&1 )
WTFIX="$ROOT/wt-fix"; WTCHORE="$ROOT/wt-chore"
# SEED: repo vacío (0 commits) con remoto bare, para la excepción de siembra.
SEEDR="$ROOT/seed"; git init -q -b main "$SEEDR"; ( cd "$SEEDR"; git config user.email t@t; git config user.name t; git remote add origin "$ROOT/seed.git" ); git init -q --bare "$ROOT/seed.git"

echo "== git-branch-guard · banco del corpus (FP esperan PASAR; controles+ esperan FRENAR) =="

# ── FP cluster A: push PELÓN estando EN una ramita (con upstream) → PASA ──
for L in 28 29 61 67 100 103 134; do
  cfp_caso "$GUARD" "$L" "push pelón desde ramita fix/y (upstream)" "git push -q" "$WTFIX" pass
done
cfp_caso "$GUARD" 29 "add&&commit&&push pelón en ramita" "git add -A && git commit -m x && git push" "$WTFIX" pass

# ── FP cluster B: cd / -C a un WORKTREE de ramita, luego push pelón → PASA ──
cfp_caso "$GUARD" 52  "git -C <wt-ramita> push pelón"            "git -C $WTCHORE push"                        "$REPO" pass
cfp_caso "$GUARD" 54  "cd <wt-ramita> && push pelón"             "cd $WTCHORE && git push"                     "$REPO" pass
cfp_caso "$GUARD" 103 "push pelón desde worktree de ramita"      "git push --quiet"                            "$WTCHORE" pass
cfp_caso "$GUARD" 181 "for … do cd <wt-ramita> && push pelón; done (H1)" "for r in a:b; do cd $WTCHORE && git add -A && git push -q; done" "$REPO" pass
cfp_caso "$GUARD" 181 "cd <wt> ; push pelón (separador ;)"       "cd $WTCHORE ; git push -q"                    "$REPO" pass
cfp_caso "$GUARD" 181 "(cd <wt> && push pelón) subshell"         "(cd $WTCHORE && git push -q)"                 "$REPO" pass

# ── FP cluster C: el comando solo MENCIONA un push a base en texto citado (grep/heredoc) → PASA ──
cfp_caso "$GUARD" 35  "grep de un literal 'git push origin develop'"  "grep -r 'git push origin develop' ."    "$REPO" pass
cfp_caso "$GUARD" 76  "grep read-only citando push-a-base + develop"  "grep -rn 'push origin main' docs/"      "$REPO" pass
cfp_caso "$GUARD" 115 "append a bitácora citando el comando"          "printf '%s' '- git push origin develop' >> b.md" "$REPO" pass
cfp_caso "$GUARD" 145 "pgrep -af con subcadenas push/fetch/commit"    "pgrep -af 'git push|git fetch'"         "$REPO" pass
cfp_caso "$GUARD" 182 "heredoc que solo menciona un push pelón"       "cat > rep.md <<EOF
un git push pelón aquí
EOF" "$REPO" pass

# ── FP cluster D: checkout/switch PREVIO a una ramita, luego push pelón → PASA ──
cfp_caso "$GUARD" 109 "git checkout fix/y && push pelón (cambia de rama)" "git checkout fix/y && git push -q" "$REPO" pass

# ── SEED (excepción de siembra): con CLAUDE_GIT_GUARD_SEED=1 PASA ──
seed_run() { jq -nc --arg c "$1" --arg d "$SEEDR" '{tool_input:{command:$c},cwd:$d}' | HOME="$(cfp_fakehome)" CLAUDE_PROJECT_DIR="$SEEDR" CLAUDE_GIT_GUARD_SEED=1 bash "$GUARD" 2>/dev/null; }
for L in 4 114 152; do
  if printf '%s' "$(seed_run 'git push -u origin main')" | grep -q '"deny"'; then
    CFP_FPBLOCK=$((CFP_FPBLOCK+1)); CFP_FP_LINES+=("L$L: siembra repo vacío (con SEED=1 debería pasar)"); echo "  ✗ FRENA L$L  siembra (SEED=1) ← FP sigue vivo"
  else CFP_PASS=$((CFP_PASS+1)); echo "  ✓ PASA  L$L  siembra repo vacío (escape CLAUDE_GIT_GUARD_SEED=1)"; fi
done

# ── CONTROLES POSITIVOS (DEBEN frenar; si pasan, el harness es verde falso) ──
cfp_caso "$GUARD" -   "ctrl+ push explícito a develop"   "git push origin develop"  "$REPO"    block
cfp_caso "$GUARD" -   "ctrl+ push pelón parado EN develop" "git push -q"             "$REPO"    block
cfp_caso "$GUARD" -   "ctrl+ cd a repo-en-develop && push pelón" "cd $REPO && git push -q" "$WTFIX" block
cfp_caso "$GUARD" -   "ctrl+ merge que nombra la base"   "gh pr merge 5 --merge; git push origin main" "$REPO" block

cfp_reporte git-branch-guard
rm -rf "$ROOT"
[ "$CFP_CTRL_BAD" -eq 0 ] || exit 2   # harness roto = fallo duro
