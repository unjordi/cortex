#!/usr/bin/env bash
# correr-proteger-arbol.sh — banco del corpus para proteger-arbol (AVISO: "dispara" = additionalContext en stdout).
# Corre con `bash brain/tests/corpus-fp/correr-proteger-arbol.sh`.
# Casos L112/L113/L116/L123: el bloqueo original fue "demasiado complejo para verificar" (mensaje del HARNESS,
# no de este hook); aquí solo se comprueba que el hook calla ante esos comandos (comando reconstruido de la prosa).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib-corpus-fp.sh"
GUARD="$HOOKS/proteger-arbol.sh"
export CFP_MODE=aviso

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/cfp-pa.XXXXXX")
BARE="$ROOT/origin.git"; REPO="$ROOT/repo"
g() { git -C "$REPO" "$@" >/dev/null 2>&1; }
git init -q --bare "$BARE"
git init -q -b develop "$REPO"
g config user.email t@t; g config user.name t; g remote add origin "$BARE"
printf 'base\n' > "$REPO/base.txt"; g add base.txt; g commit -q -m base; g push -q origin develop
g checkout -q -b DevelopUnjordi; g push -q -u origin DevelopUnjordi
# la mini lleva trabajo local SIN pushear (n>0): sin la precisión de branch -D, el guard gritaría
for i in 1 2 3; do printf 'l%s\n' "$i" > "$REPO/local$i.txt"; g add .; g commit -q -m "local $i"; done

mkrama() {  # mkrama <rama> <n-commits> → rama desde HEAD de la mini con n commits propios; vuelve a la mini
  local br="$1" n="$2" i
  g checkout -q -b "$br"
  for i in $(seq 1 "$n"); do printf '%s %s\n' "$br" "$i" > "$REPO/f-${br//\//_}-$i.txt"; g add .; g commit -q -m "$br $i"; done
  g checkout -q DevelopUnjordi
}
squash() {  # squash <rama> → integra la rama a la mini por SQUASH con línea "Rama: <rama>" (convención del equipo)
  mkrama "$1" 2
  g merge --squash "$1"; g commit -q -m "feat: $1

Rama: $1"
}
cherry() { mkrama "$1" 1; g cherry-pick "$1"; }

for b in docs/espec-epica feat/evidencia-1 feat/evidencia-2 feat/sync-sesiones fix/mac-updater docs/rastro feat/skills-auditar \
         docs/skill-introspeccion docs/re-ctrlelim re/audit-cvebita re/skill-aspel re/router-aspel re/memory-index re/eje-gui re/a2-clie \
         sq/h1 sq/h2 sq/h3 sq/h4; do squash "$b"; done
for b in fix/widget-win-hover fix/widget-kde-badge fix/widget-win-badge-heal; do cherry "$b"; done
g branch test/worker-notificaciones HEAD~1            # ancestro de la mini
g branch docs/entorno-maquina HEAD                    # vacía: tip == mini
g branch worktree-agent-1 HEAD~2
# L165/L168: ramas integradas por merge a una intermedia, y la INTERMEDIA squasheada (la hija no trae "Rama:")
mkrama fix/hija-a 1; mkrama fix/hija-b 1; mkrama fix/buzon-intermedia 1
g checkout -q fix/buzon-intermedia; g merge -q --no-ff -m m1 fix/hija-a; g merge -q --no-ff -m m2 fix/hija-b; g checkout -q DevelopUnjordi
g merge --squash fix/buzon-intermedia; g commit -q -m "feat: buzon

Rama: fix/buzon-intermedia"
# rama viva (trabajo propio sin integrar) para controles+
mkrama pa/viva 1

# worktree AISLADO en rama con commit adelante de su upstream (L118)
g branch --set-upstream-to=origin/DevelopUnjordi DevelopUnjordi
g worktree add -q -b wt/iso "$ROOT/wt-iso" origin/DevelopUnjordi
git -C "$ROOT/wt-iso" branch --set-upstream-to=origin/DevelopUnjordi >/dev/null 2>&1
printf 'iso\n' > "$ROOT/wt-iso/iso.txt"; git -C "$ROOT/wt-iso" add . >/dev/null 2>&1; git -C "$ROOT/wt-iso" commit -q -m iso >/dev/null 2>&1
WTISO="$ROOT/wt-iso"

# L11 LOSSLESS: develop LOCAL DETRÁS de origin/develop (origin avanzó por squash; el espejo viejo se pone al
# día). reset --hard origin/develop es un fast-forward → nada que orfanar (origin/develop..develop == 0) → silencio.
REPO2="$ROOT/repo2"
git clone -q "$BARE" "$REPO2" >/dev/null 2>&1
g2() { git -C "$REPO2" "$@" >/dev/null 2>&1; }
g2 config user.email t@t; g2 config user.name t; g2 checkout -q develop
for i in 1 2; do printf 'sq%s\n' "$i" > "$REPO2/sq$i.txt"; g2 add .; g2 commit -q -m "squash en origin $i"; done
g2 push -q origin develop                    # origin/develop avanza
g2 reset -q --hard HEAD~2                     # local develop vuelve a base → DETRÁS de origin por 2
git -C "$REPO2" branch --set-upstream-to=origin/develop develop >/dev/null 2>&1
# control+ L11 (data-loss, hueco MEDIO claudio): develop local ADELANTE con un commit LOCAL sin pushear → reset
# --hard origin/develop lo ORFANARÍA → AVISA (el guard NO puede distinguir un bubble squash de trabajo real).
REPO2AH="$ROOT/repo2ah"
git clone -q "$BARE" "$REPO2AH" >/dev/null 2>&1
g2a() { git -C "$REPO2AH" "$@" >/dev/null 2>&1; }
g2a config user.email t@t; g2a config user.name t; g2a checkout -q develop
printf 'local\n' > "$REPO2AH/local.txt"; g2a add .; g2a commit -q -m "commit LOCAL sin pushear en develop"
git -C "$REPO2AH" branch --set-upstream-to=origin/develop develop >/dev/null 2>&1
# control+ L11 (branch-scoping): un FEATURE con reset --hard origin/develop SÍ perdería su trabajo → AVISA.
REPO3="$ROOT/repo3"
git clone -q "$BARE" "$REPO3" >/dev/null 2>&1
g3() { git -C "$REPO3" "$@" >/dev/null 2>&1; }
g3 config user.email t@t; g3 config user.name t; g3 checkout -q -b feat/l11-ctrl origin/develop
printf 'w\n' > "$REPO3/w.txt"; g3 add .; g3 commit -q -m "trabajo propio del feature"

echo "== proteger-arbol · banco del corpus (FP esperan SILENCIO; controles+ esperan AVISO) =="

# ── cluster A: heredoc con prosa git destructiva ──
cfp_caso "$GUARD" 3 "heredoc a cat con 'git reset --hard' de PROSA" "cat >> aprendizajes.md <<EOF
leccion: git reset --hard mini borra el arbol
EOF" "$REPO" pass

# ── cluster B: branch -d/-D de ramas YA integradas (squash con Rama:, cherry, ancestro, vacía) ──
cfp_caso "$GUARD" 5  "branch -d … -D worktree-agent-* (mezcla integradas, globs)" "git branch -d test/worker-notificaciones docs/espec-epica feat/evidencia-* && git branch -D worktree-agent-1" "$REPO" pass
cfp_caso "$GUARD" 6  "branch -D rama vacía (tip == mini)"            "git branch -D docs/entorno-maquina" "$REPO" pass
cfp_caso "$GUARD" 7  "branch -D squash-mergeada"                    "git branch -D feat/sync-sesiones" "$REPO" pass
cfp_caso "$GUARD" 8  "branch -D squash-mergeada"                    "git branch -D fix/mac-updater" "$REPO" pass
cfp_caso "$GUARD" 14 "branch -D squash-mergeada"                    "git branch -D docs/rastro" "$REPO" pass
cfp_caso "$GUARD" 15 "branch -D barrido de varias integradas"       "git branch -D sq/h1 sq/h2 sq/h3 sq/h4 fix/widget-win-hover test/worker-notificaciones" "$REPO" pass
cfp_caso "$GUARD" 16 "branch -D squash-mergeada"                    "git branch -D docs/skill-introspeccion" "$REPO" pass
cfp_caso "$GUARD" 17 "branch -D squash-mergeada"                    "git branch -D feat/skills-auditar" "$REPO" pass
cfp_caso "$GUARD" 18 "branch -D cherry-pickeada"                    "git branch -D fix/widget-win-hover" "$REPO" pass
cfp_caso "$GUARD" 19 "branch -D dos cherry-pickeadas"               "git branch -D fix/widget-kde-badge fix/widget-win-badge-heal" "$REPO" pass
cfp_caso "$GUARD" 21 "branch -D squash-mergeada"                    "git branch -D docs/re-ctrlelim" "$REPO" pass
cfp_caso "$GUARD" 22 "branch -D squash-mergeada"                    "git branch -D re/audit-cvebita" "$REPO" pass
cfp_caso "$GUARD" 23 "branch -D squash-mergeada"                    "git branch -D re/skill-aspel" "$REPO" pass
cfp_caso "$GUARD" 24 "branch -D squash-mergeada"                    "git branch -D re/router-aspel" "$REPO" pass
cfp_caso "$GUARD" 25 "branch -D squash-mergeada"                    "git branch -D re/memory-index" "$REPO" pass
cfp_caso "$GUARD" 26 "branch -D squash-mergeada"                    "git branch -D re/eje-gui" "$REPO" pass
cfp_caso "$GUARD" 27 "branch -D squash-mergeada"                    "git branch -D re/a2-clie" "$REPO" pass

# ── cluster C: integradas vía rama INTERMEDIA squasheada (la hija no trae 'Rama:') ──
cfp_caso "$GUARD" 165 "branch -D hija integrada por merge a intermedia squasheada" "git branch -D fix/hija-a" "$REPO" pass
cfp_caso "$GUARD" 168 "branch -D 2 hijas integradas por merge a intermedia squasheada" "git branch -D fix/hija-a fix/hija-b" "$REPO" pass

# ── cluster D: limpieza post-squash con reset --hard origin/develop en árbol principal (L11) ──
cfp_caso "$GUARD" 11 "SYNC lossless: develop local DETRÁS de origin, reset --hard origin/develop (ff, nada que orfanar) → silencio" "git worktree remove x ; git reset --hard origin/develop" "$REPO2" pass

# ── cluster E: aislado + rebase (L118) ──
cfp_caso "$GUARD" 118 "rebase de rama propia dentro de worktree aislado" "git rebase origin/DevelopUnjordi" "$WTISO" pass

# ── cluster F: comandos sin git destructivo (origen del bloqueo = complejidad/harness) ──
cfp_caso "$GUARD" 112 "loop read-only con \$f, heredoc y ffprobe (reconstruido)" 'for f in a/*.wav; do ffprobe -v error "$f"; done; cat > n.txt <<EOF
x
EOF' "$REPO" pass
cfp_caso "$GUARD" 113 "for p … node src/\$p.ts (reconstruido)"   'for p in a b c; do node src/$p.ts; done' "$REPO" pass
cfp_caso "$GUARD" 116 "sed sobre nombres con 'git-worktree'"      'for f in docs/git-worktree-*.md; do sed -i "s/a/b/" "$f"; done' "$REPO" pass
cfp_caso "$GUARD" 123 "for + sed -n \"\${L}p\" sobre .jsonl (reconstruido)" 'for L in 1 2 3; do sed -n "${L}p" t.jsonl; done' "$REPO" pass
cfp_caso "$GUARD" 123 "{ …; } > rep con command grep/jq (reconstruido)" '{ command grep -c x a; jq . b; } > /tmp/rep1.txt' "$REPO" pass
cfp_caso "$GUARD" 123 "bash -c '. lib.sh; …' con la palabra git (reconstruido)" "bash -c '. lib.sh; echo git status'" "$REPO" pass
cfp_caso "$GUARD" 123 "xargs -a (reconstruido)"                   'xargs -a lista.txt -n1 echo' "$REPO" pass

# ── cluster G: variantes con nombre proteger-arbol/worktree-isolation|isolation-guard|aislamiento (mensaje del
#    HARNESS "demasiado complejo / worktree"); aquí solo se comprueba que ESTE hook calla (comandos reconstruidos) ──
cfp_caso "$GUARD" 10  "docker exec sqlcmd con \$(grep …) del .env (reconstruido)" 'docker exec sae9-sandbox-sqlserver /opt/mssql-tools18/bin/sqlcmd -U sa -P "$(grep SA_PASSWORD .env | cut -d= -f2)" -C -Q "SELECT 1"' "$REPO" pass
cfp_caso "$GUARD" 12  "for V … sqlcmd > /tmp/def_\$V.sql (reconstruido)" 'for V in a b; do sqlcmd -d "$V" -Q "SELECT 1" > /tmp/def_$V.sql; done' "$REPO" pass
cfp_caso "$GUARD" 13  "set -a; source .env; which sqlcmd (reconstruido)" 'set -a; source .env; set +a; PW=$SA_PASSWORD; which sqlcmd' "$REPO" pass
cfp_caso "$GUARD" 48  "extracción de heredocs a /tmp + bash -n (reconstruido)" 'for tag in WD_EOF X_EOF; do awk "/$tag/" f.sh > /tmp/body_$tag.sh; bash -n /tmp/body_$tag.sh; done' "$REPO" pass
cfp_caso "$GUARD" 49  "paste <(grep …) <(grep …) (reconstruido)"  'paste <(grep -n func a.sh) <(grep -n func a.ps1)' "$REPO" pass
cfp_caso "$GUARD" 126 "for sobre repos incl. mfx_infraestructuradigital + heredoc con 'commit' (reconstruido)" 'for r in axon mfx_infraestructuradigital; do ls ~/code/$r; done; cat > n.md <<EOF
hacer commit luego
EOF' "$REPO" pass
cfp_caso "$GUARD" 150 "python3 heredoc con 'digits' (git dentro de un identificador)" 'python3 - <<EOF
out = {"dom_rect_digits_over200": 1}
print(out)
EOF' "$REPO" pass
cfp_caso "$GUARD" 151 "google-chrome-stable contra URL local con query" 'google-chrome-stable --headless "$URL?nofix=1" http://127.0.0.1:8791/verify.html?nofix=1' "$REPO" pass

# ── CONTROLES POSITIVOS (DEBEN avisar) ──
cfp_caso "$GUARD" - "ctrl+ reset --hard HEAD~1 con commits sin pushear (árbol principal)" "git reset --hard HEAD~1" "$REPO" block
cfp_caso "$GUARD" - "ctrl+ L186 by-design: 'gh pr merge … ; … ; git branch -D <rama>' — el \`;\` NO garantiza el merge y gh-pr-merge NO es el patrón \`git merge X &&\` (H7) → una rama NO integrada AVISA (correcto en PreToolUse, antes de que corra el merge del compound)" "gh pr merge 237 --squash --delete-branch ; git worktree remove x ; git branch -D pa/viva" "$REPO" block
cfp_caso "$GUARD" - "ctrl+ L11 data-loss: EN develop ADELANTE con un commit LOCAL, reset --hard origin/develop → AVISA (lo orfanaría; hueco MEDIO cerrado)" "git reset --hard origin/develop" "$REPO2AH" block
cfp_caso "$GUARD" - "ctrl+ L11 branch-scoping: FEATURE con reset --hard origin/develop → AVISA (no es develop|main, perdería trabajo)" "git reset --hard origin/develop" "$REPO3" block
cfp_caso "$GUARD" - "ctrl+ L11 target-scoping: EN develop con reset --hard HEAD~1 (no origin/<base>) → AVISA (solo el sync a origin/<base> se suprime)" "git reset --hard HEAD~1" "$REPO2AH" block
cfp_caso "$GUARD" - "ctrl+ branch -D de rama con trabajo propio sin integrar" "git branch -D pa/viva" "$REPO" block
cfp_caso "$GUARD" - "ctrl+ cd <principal> && reset --hard desde otro cwd" "cd $REPO && git reset --hard HEAD~1" "$WTISO" block
cfp_caso "$GUARD" - "ctrl+ heredoc a bash con reset REAL adentro" "bash <<EOF
git reset --hard HEAD~1
EOF" "$REPO" block
cfp_caso "$GUARD" - "ctrl+ aislado + reset a otro objetivo → nota suave" "git reset --hard HEAD~1" "$WTISO" block

cfp_reporte proteger-arbol
git -C "$REPO" worktree remove --force "$WTISO" >/dev/null 2>&1
rm -rf "$ROOT"
[ "$CFP_CTRL_BAD" -eq 0 ] || exit 2
