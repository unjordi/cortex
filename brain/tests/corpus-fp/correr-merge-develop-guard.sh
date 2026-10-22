#!/usr/bin/env bash
# correr-merge-develop-guard.sh — banco del corpus de la FAMILIA merge-develop-guard (43 líneas del corpus:
# merge-develop-guard + los retirados confirmar-merge-develop y merge-squash-guard; todos corren contra
# brain/hooks/merge-develop-guard.sh). Corre con `bash brain/tests/corpus-fp/correr-merge-develop-guard.sh`.
#
# SIN RED: gh/glab son MOCKS en el PATH (destino por CFP_BASE, título del MR fijo); el PATH del guard es
# `$MOCKBIN:/usr/bin:/bin` con ACG_PATH_AUGMENT=0 (nunca alcanza el gh/glab reales). El juez LLM solo se
# ejercita por mock (CLAUDE_MERGE_JUEZ_MOCK / _MOCK_RAW): los casos cuyo FP ES el criterio del LLM no son
# reproducibles offline y se listan abajo como no-reproducibles (NO se inventan).
#
# NO REPRODUCIBLES (criterio del juez LLM / entorno puntual / no-FP):
#   L1   OK en términos de release que no satisface el merge intermedio a develop (criterio del LLM)
#   L50  flake transitorio de gh pr view (pasó al reintento)
#   L53  "y haz el merge de mfx" — atar el repo al único MR abierto (criterio del LLM)
#   L63  consulta de destino falló en el entorno del hook (fallo de red de ese día; el MR traía --target-branch)
#   L68  "hazle el merge a lo de Mfx_infra plz" sin número (criterio del LLM)
#   L119 "mejor mergea el PR19" rechazado 3 veces (criterio del LLM)
#   L120 gh pr view falla dentro del hook con el mismo gh funcionando en el shell (entorno del hook)
#   L131 [PRECISION, no FP] fork con `gh` default a upstream (config; frenó fail-safe correctamente)
#   L141 FP RETRACTADO por L142 (el guard hizo lo correcto: --repo "$R" con variable)
#   L142 retractación (no es un caso FP)
#   L157 "ahorita nomás cerramos y mergeamos el 157" sin destino resoluble (criterio del LLM + entorno)
#   L166 grant STANDING sin vence_epoch + reafirmación indirecta (criterio del LLM / diseño del grant)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib-corpus-fp.sh"
REAL="$HOOKS/merge-develop-guard.sh"
export CFP_MODE=deny

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/cfp-mdg.XXXXXX")
MOCKBIN="$ROOT/mockbin"; mkdir -p "$MOCKBIN" "$ROOT/code"
printf 'fix(x): resumen curado del cambio neto y su porque en prosa suficiente (#1)\n' > "$MOCKBIN/title.txt"
cat > "$MOCKBIN/gh" <<EOS
#!/bin/sh
case "\$*" in
  *"pr view"*baseRefName*) [ -n "\${CFP_BASE:-}" ] && { echo "\$CFP_BASE"; exit 0; }; exit 1 ;;
  *"pr view"*title*) cat "$MOCKBIN/title.txt"; exit 0 ;;
esac
exit 1
EOS
cat > "$MOCKBIN/glab" <<EOS
#!/bin/sh
case "\$*" in
  *"api projects"*) [ -n "\${CFP_BASE:-}" ] || exit 1; printf '{"target_branch":"%s","title":"%s"}\n' "\$CFP_BASE" "\$(cat "$MOCKBIN/title.txt")"; exit 0 ;;
esac
exit 1
EOS
chmod +x "$MOCKBIN/gh" "$MOCKBIN/glab"

# Wrapper: exporta el mock RAW del juez desde un archivo (el valor trae saltos de línea → no cabe en CFP_ENV).
GUARD="$ROOT/guard-wrap.sh"
cat > "$GUARD" <<EOS
#!/bin/bash
[ -n "\${CFP_MOCK_RAW_FILE:-}" ] && export CLAUDE_MERGE_JUEZ_MOCK_RAW="\$(cat "\$CFP_MOCK_RAW_FILE")"
exec bash "$REAL"
EOS

mkrepo() {  # mkrepo <dir> <origin-url> <compartido:0|1>
  mkdir -p "$1"; git init -q -b develop "$1"
  git -C "$1" config user.email t@t; git -C "$1" config user.name t
  git -C "$1" remote add origin "$2"
  if [ "$3" = 1 ]; then mkdir -p "$1/.claude"; : > "$1/.claude/repo-compartido"; fi
  printf 'x\n' > "$1/f.txt"; git -C "$1" add -A >/dev/null 2>&1; git -C "$1" commit -q -m base
}
PERS="$ROOT/code/personal";   mkrepo "$PERS"   "git@github.com:unjordi/personal.git" 0
SHARED="$ROOT/code/shared";   mkrepo "$SHARED" "git@github.com:unjordi/shared.git" 1
SESS="$ROOT/code/sess";       mkrepo "$SESS"   "git@github.com:unjordi/sess.git" 1
ARM="$ROOT/code/armada-rp6";  mkrepo "$ARM"    "git@github.com:unjordi/armada-rp6.git" 1
AXON="$ROOT/code/axon";       mkrepo "$AXON"   "git@github.com:unjordi/axon.git" 1
MFX="$ROOT/code/mfx";         mkrepo "$MFX"    "git@gitlab.com:mx_pind_devops/mx_megaflux_devops/mfx_infraestructuradigital.git" 1
FUT=$(( $(date +%s) + 86400*365 ))
for d in "$ARM" "$AXON" "$MFX"; do
  mkdir -p "$d/.claude/memory"
  printf -- '- scope=merge-develop vence_epoch=%s (grant de prueba)\n' "$FUT" > "$d/.claude/memory/autorizaciones-vigentes.local.md"
done
printf 'Rama: feat/x\nMR: !89\nResumen curado del cambio neto.\n' > "$PERS/resumen.md"

TXD="$ROOT/tx"; mkdir -p "$TXD"
mktx() {  # mktx <archivo> <texto-usuario>
  jq -nc --arg t "$2" '{type:"user",message:{role:"user",content:[{type:"text",text:$t}]}}' > "$TXD/$1"
}

n=0
mc() {  # mc <linea> <nota> <cmd> <cwd> <esp> [ENV extra "K=V …"]   (CFP_BASE por defecto = develop)
  local td; n=$((n+1)); td="$ROOT/tmp$n"; mkdir -p "$td"
  CFP_ENV="PATH=$MOCKBIN:/usr/bin:/bin ACG_PATH_AUGMENT=0 TMPDIR=$td CFP_BASE=${CFP_BASE:-develop} ${6:-}" \
    cfp_caso "$GUARD" "$1" "$2" "$3" "$4" "$5"
}

GH_OK='gh pr merge 5 --squash --delete-branch --subject "fix(guards): resumen curado del cambio neto y su porque en prosa suficiente (#5)"'

echo "== merge-develop-guard (familia) · banco del corpus (FP esperan PASAR; controles+ esperan FRENAR) =="

# ── A: MENCIÓN del comando de merge dentro de heredoc / printf / mensaje (no es una integración) ──
mc 32  "git commit -F - con prosa que menciona gh pr merge / glab mr merge" 'git commit -F - <<EOF
fix(guard): el detector leia gh pr merge --subject y glab mr merge --squash-message como invocaciones
EOF' "$PERS" pass
mc 33  "cat >> doc <<EOF con ejemplo glab.exe mr merge 5 develop" 'cp a.md b.md && cat >> b.md <<EOF
ejemplo: glab.exe mr merge 5 develop
EOF' "$PERS" pass
for L in 47 64 125 138; do
  mc "$L" "printf que CITA 'gh pr merge … --squash' entre comillas, append al corpus" 'printf "%s\n" "- 2026-09-11 · merge-squash-guard · \"gh pr merge 389 --squash --subject x\" · frenó" >> docs/guards-falsos-positivos.md' "$PERS" pass
done
mc 90  "python3 - <<PY que reescribe memoria cuyo texto menciona glab mr merge" "python3 - <<'PY'
open('m.md','a').write('integra con glab mr merge 5 --squash --squash-message x')
PY" "$PERS" pass
mc 108 "cat > nota <<EOF que cita la sintaxis de integración" 'cat > nota-fp.md <<EOF
cita: gh pr merge 5 --squash --delete-branch
EOF' "$PERS" pass
mc 136 "gh pr create + printf con comillas escapadas citando gh pr merge" 'gh pr create --base develop --title x --body y && printf "- fp · \"gh pr merge 389 --squash\" · cita\n" >> docs/g.md' "$PERS" pass
mc 139 "git commit -F - cuyo mensaje describe en prosa el bug de gh pr merge --subject" 'git commit -F - <<EOF
fix(checkpoint): el detector viejo leia gh pr merge ...--subject y glab mr merge ...--squash-message como reales
EOF' "$PERS" pass
mc 140 "cat > qa-andamio.py <<EOF con gh pr merge --squash en comentarios/aserciones" 'cat > qa-andamio.py <<EOF
# prueba: gh pr merge --squash y git commit -F -
assert True
EOF' "$PERS" pass
mc 153 "git commit -F - cuyo mensaje cita gh pr merge como ejemplo" 'git commit -F - <<EOF
fix(barrer-ramas): resolver el repo del merge (ej: gh pr merge 5 --repo org/x)
EOF' "$PERS" pass
mc 154 "python3 - <<PY con la norma que cita gh pr merge … --delete-branch" "python3 - <<PY
t = 'integra con gh pr merge <id> --squash --delete-branch'
print(t)
PY" "$PERS" pass

# ── B: capa de SQUASH (repo personal; destino develop por mock) ──
mc 42  "glab mr merge --squash-message INLINE multilínea con sustancia" 'glab mr merge 270 --squash --yes --remove-source-branch --squash-message "feat(x): resumen curado del cambio neto y su porque en prosa suficiente

Rama: feat/x
MR: !270"' "$PERS" pass
mc 46  "squash de MR !13 con mensaje curado inline multilínea" 'glab mr merge 13 --squash --yes --remove-source-branch --squash-message "fix(y): cambio neto descrito en prosa con su porque completo para el historial

Rama: fix/y
MR: !13"' "$PERS" pass
mc 107 "squash-message por heredoc dentro de sustitución de comando" 'glab mr merge 14 --squash --yes --remove-source-branch --squash-message "$(cat <<EOF
feat(z): resumen curado de treinta y cuatro lineas
Rama: feat/z
MR: !14
EOF
)"' "$PERS" pass
mc 124 "gh pr merge 89: subject curado + --body \$(cat resumen.md) con Rama:/MR: en el archivo" 'gh pr merge 89 --squash --delete-branch --subject "fix(axon): titulo curado de una linea" --body "$(cat resumen.md)"' "$PERS" pass
mc 137 "gh pr merge 389: --subject corto con (#389) + --body de 100+ palabras" 'gh pr merge 389 --squash --delete-branch --subject '"'"'fix(rehidratar-hilo): avisar VISIBLE cuando compactaste SIN hilo fresco (#389)'"'"' --body '"'"'Resumen curado del cambio neto y su porque. El hook rehidratar-hilo avisa visible cuando se compacta sin un hilo fresco disponible, para que el usuario sepa que perdio el contexto previo y pueda reconstruirlo con el andamio mecanico del tramo vivo antes de seguir trabajando en la sesion actual con la rama correcta y el estado durable al dia sin sorpresas ni confabulaciones posteriores al compact.'"'"'' "$PERS" pass
mc 144 "gh pr merge 40: --body \$(cat resumen.md) con la traza dentro, sin --subject (título del MR por API)" 'gh pr merge 40 --squash --delete-branch --body "$(cat resumen.md)"' "$PERS" pass
# A2 (2026-10-21): el CONTENIDO del squash-message ya NO frena — es un RECORDATORIO. Un mensaje 'pobre' con squash+delete-branch a develop PASA (antes era control+ de block; retirado el chequeo determinista de calidad del mensaje).
mc - "mensaje de squash 'pobre' ('wip') con --squash --delete-branch a develop → PASA (A2: contenido = recordatorio no-bloqueante)" 'gh pr merge 5 --squash --delete-branch --subject wip' "$PERS" pass

# ── C: destino / PATH mínimo de launchd / marca del repo DESTINO / mini-develop ──
mc 30  "release gh pr merge --merge con PATH mínimo (gh solo en ACG_EXTRA_BIN; destino main)" 'gh pr merge 267 --merge' "$PERS" pass "PATH=/usr/bin:/bin ACG_PATH_AUGMENT=1 ACG_EXTRA_BIN=$MOCKBIN CFP_BASE=main"
mc 135 "release develop→main con merge-commit y PATH mínimo de launchd" 'gh pr merge 389 --merge' "$PERS" pass "PATH=/usr/bin:/bin ACG_PATH_AUGMENT=1 ACG_EXTRA_BIN=$MOCKBIN CFP_BASE=main"
# L51 — NO vía mc (mc fuerza CFP_BASE=${CFP_BASE:-develop}, que convierte "" en develop y pierde el intent "destino irresoluble"). Se llama cfp_caso directo con CFP_ENV SIN CFP_BASE → el mock de gh pr view baseRefName sale 1 = destino IRRESOLUBLE, el caso real (gh pr view falla in-hook).
mktx l51.jsonl "libera a main el PR 319, es el release"
CFP_TX="$TXD/l51.jsonl" CFP_ENV="PATH=$MOCKBIN:/usr/bin:/bin ACG_PATH_AUGMENT=0 TMPDIR=$ROOT CLAUDE_MERGE_JUEZ_MOCK=ALLOW" \
  cfp_caso "$GUARD" 51 "release --merge a main, destino IRRESOLUBLE: el USUARIO autoriza el release en la conversación (vía-transcript acg_lexico_release_para_mr) → NO exige squash; la consolidación resolvió el FP sin leer el --subject/--body (texto de Claude, no autoriza)" 'gh pr merge 319 --repo unjordi/cortex --merge --subject "release develop a main" --body "release a main"' "$SHARED" pass
mc 31  "gh pr merge 135 a repo PERSONAL con CLAUDE_PROJECT_DIR=repo COMPARTIDO" 'gh pr merge 135 --squash --delete-branch --subject "fix(ps): resumen curado del cambio neto y su porque en prosa suficiente (#135)"' "$PERS" pass "CLAUDE_PROJECT_DIR=$SHARED"
CFP_BASE=DevelopUnjordi mc 104 "glab mr merge 57 hacia la mini DevelopUnjordi (no es develop)" 'glab mr merge 57 --squash --yes' "$SHARED" pass
for L in 86 88 89; do
  mc "$L" "glab mr merge -R mfx --squash con grant durable vigente en mfx (cwd = otro repo)" 'glab mr merge 38 -R mx_pind_devops/mx_megaflux_devops/mfx_infraestructuradigital --squash --remove-source-branch --squash-message "fix(mfx): resumen curado del cambio neto y su porque en prosa suficiente Rama: fix/x MR: !38"' "$SESS" pass "PATH=/usr/bin:/bin ACG_PATH_AUGMENT=1 ACG_EXTRA_BIN=$MOCKBIN"
done
mc 160 "gh pr merge 21 --repo unjordi/armada-rp6 --squash con grant durable en armada-rp6" 'gh pr merge 21 --repo unjordi/armada-rp6 --squash --delete-branch --subject "feat(rp6): resumen curado del cambio neto y su porque en prosa suficiente (#21)"' "$SESS" pass
mc 161 "glab mr merge 73 --repo <slug anidado> con grant en mfx (TARGET_ROOT desde el --repo, no del cwd)" 'glab mr merge 73 --repo mx_pind_devops/mx_megaflux_devops/mfx_infraestructuradigital --squash --remove-source-branch --squash-message "fix(mfx): resumen curado del cambio neto y su porque en prosa suficiente Rama: fix/y MR: !73"' "$SESS" pass
mc 167 "compound: gh pr merge --repo axon --squash ; M=<dir>; git -C \$M pull (grant en axon)" "gh pr merge 442 --repo unjordi/axon --squash --delete-branch --subject \"fix(axon): resumen curado del cambio neto y su porque en prosa suficiente (#442)\" ; M=$AXON; git -C \$M pull" "$SESS" pass

# ── D: evidencia de autorización que debe llegar al juez (juez MOCKEADO: mide la plomería de la evidencia) ──
printf 'CITA: mergea #280/#281 a develop\nVEREDICTO: ALLOW\n' > "$ROOT/raw-ask.txt"
jq -nc '{type:"user",message:{role:"user",content:[{type:"tool_result",content:"ok"}]},toolUseResult:{answers:["mergea #280/#281 a develop"]}}' > "$TXD/ask.jsonl"
CFP_TX="$TXD/ask.jsonl" mc 34 "OK dado por AskUserQuestion (#280/#281 mergea a develop) llega como USUARIO al veto de cita" 'gh pr merge 280 --squash --delete-branch --subject "fix(x): resumen curado del cambio neto y su porque en prosa suficiente (#280)"' "$SHARED" pass "CFP_MOCK_RAW_FILE=$ROOT/raw-ask.txt"

# ── CONTROLES POSITIVOS (DEBEN frenar) ──
mc - "ctrl+ merge a develop SIN --squash" 'gh pr merge 5 --delete-branch' "$PERS" block
mc - "ctrl+ squash sin --delete-branch (rama colgando)" 'gh pr merge 5 --squash --subject "fix(guards): resumen curado del cambio neto y su porque en prosa suficiente (#5)"' "$PERS" block
mc - "ctrl+ repo COMPARTIDO, squash OK, SIN autorización del usuario (piso barato)" "$GH_OK" "$SHARED" block
mc - "ctrl+ --auto a develop en repo compartido" "$GH_OK --auto" "$SHARED" block
mc - "ctrl+ release a main: juez ALLOW mockeado pero SIN lenguaje de release del usuario (piso de main)" 'gh pr merge 5 --merge' "$SHARED" block "CFP_BASE=main CLAUDE_MERGE_JUEZ_MOCK=ALLOW"
CFP_ENV="PATH=$MOCKBIN:/usr/bin:/bin ACG_PATH_AUGMENT=0 TMPDIR=$ROOT" \
  cfp_caso "$GUARD" - "ctrl+ gemelo de L51 SIN autorización del usuario: destino IRRESOLUBLE + 'release/main' SOLO en --subject/--body entrecomillados → exige squash (fail-safe, el texto de Claude NO afloja)" 'gh pr merge 319 --repo unjordi/cortex --merge --subject "release develop a main" --body "release a main"' "$SHARED" block

mc - "ctrl+ gemelo de L160 SIN grant (--repo shared, compartido) → el grant era lo que destrababa" 'gh pr merge 21 --repo unjordi/shared --squash --delete-branch --subject "feat(rp6): resumen curado del cambio neto y su porque en prosa suficiente (#21)"' "$SESS" block
mc - "ctrl+ gemelo de L31 con cwd = repo COMPARTIDO → gatea" 'gh pr merge 135 --squash --delete-branch --subject "fix(ps): resumen curado del cambio neto y su porque en prosa suficiente (#135)"' "$SHARED" block

# sanidad (no cuenta): lo VÁLIDO se acepta — compartido, squash OK, juez ALLOW mockeado con usuario que autoriza develop
mktx ok.jsonl "mergea el 5 a develop"
r=$(CFP_TX="$TXD/ok.jsonl" CFP_ENV="PATH=$MOCKBIN:/usr/bin:/bin ACG_PATH_AUGMENT=0 TMPDIR=$ROOT CFP_BASE=develop CLAUDE_MERGE_JUEZ_MOCK=ALLOW" cfp_run_guard "$GUARD" "$GH_OK" "$SHARED")
printf '  [sanidad, no cuenta] compartido + squash OK + juez ALLOW (mock): %s (esperado PASS)\n' "$r"

cfp_reporte merge-develop-guard
rm -rf "$ROOT"
[ "$CFP_CTRL_BAD" -eq 0 ] || exit 2
