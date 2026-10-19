#!/usr/bin/env bash
# correr-no-bypass-deploy.sh — banco del corpus para no-bypass-deploy (AVISO: "dispara" = additionalContext).
# Corre con `bash brain/tests/corpus-fp/correr-no-bypass-deploy.sh`.
# No reproducible desde la prosa: L101(b) (el comando exacto del `bash -lc` de repro no consta).
# Reconstruido aproximado: L40 (los argumentos exactos del grep no constan).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib-corpus-fp.sh"
GUARD="$HOOKS/no-bypass-deploy.sh"
export CFP_MODE=aviso
export CFP_ENV="CI= GITLAB_CI= GITHUB_ACTIONS= BUILD_ID="   # el guard calla en CI: se neutraliza para medirlo
D=$(mktemp -d "${TMPDIR:-/tmp}/cfp-nbd.XXXXXX")

echo "== no-bypass-deploy · banco del corpus (FP esperan SILENCIO; controles+ esperan AVISO) =="
cfp_caso "$GUARD" 36  "git add + commit de cambios a install-brain.sh" 'git add brain/install-brain.sh brain/test-brain.sh && git commit -m "fix(install-brain): x"' "$D" pass
cfp_caso "$GUARD" 38  "git log -- brain/install-brain.sh"              'git log --since=2026-08-01 --oneline -- brain/install-brain.sh' "$D" pass
cfp_caso "$GUARD" 38  "command grep sobre install-brain"               'command grep -n aviso-contexto brain/install-brain.sh' "$D" pass
cfp_caso "$GUARD" 39  "git log … -- brain/install-brain.sh (forense)"  'git log --format=%h -- brain/install-brain.sh' "$D" pass
cfp_caso "$GUARD" 40  "grep -rn sobre install.sh/install_dependencies.sh (aprox.)" 'grep -rn pattern app/x.py install.sh install_dependencies.sh' "$D" pass
cfp_caso "$GUARD" 66  "ls -1 install.sh bootstrap.sh … uninstall.sh"   'ls -1 install.sh bootstrap.sh macos/install.sh uninstall.sh' "$D" pass
cfp_caso "$GUARD" 101 "(a) ls/find listando install-brain.sh"          'ls -la brain/install-brain.sh; find . -name install-brain.sh' "$D" pass
cfp_caso "$GUARD" 105 "git diff -- install.sh bootstrap.sh …"          'git diff 6ac87cc~1 6ac87cc -- install.sh bootstrap.sh macos/install.sh uninstall.sh' "$D" pass
cfp_caso "$GUARD" 106 "heredoc 'EOF' a bitácora con ./install.sh como prosa" "cat >> .claude/memory/bitacora.md <<'EOF'
corrimos ./install.sh --con-term-broker en la cachy
EOF" "$D" pass
cfp_caso "$GUARD" 117 "heredoc que escribe hilo-mental con 'install.sh' en prosa" "cat > .claude/memory/hilo-mental-actual.md <<EOF
el brain se actualiza con el widget, no con install.sh a mano
EOF" "$D" pass

# ── CONTROLES POSITIVOS (DEBEN avisar) ──
cfp_caso "$GUARD" - "ctrl+ bash brain/install-brain.sh"          'bash brain/install-brain.sh' "$D" block
cfp_caso "$GUARD" - "ctrl+ ./install.sh"                         './install.sh' "$D" block
cfp_caso "$GUARD" - "ctrl+ make deploy"                          'make deploy' "$D" block
cfp_caso "$GUARD" - "ctrl+ heredoc a bash con ./install.sh real" 'bash <<EOF
./install.sh
EOF' "$D" block

cfp_reporte no-bypass-deploy
rm -rf "$D"
[ "$CFP_CTRL_BAD" -eq 0 ] || exit 2
