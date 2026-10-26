#!/usr/bin/env bash
# Cronometra CADA hook CABLEADO tal como lo invoca el harness: JSON por stdin, mismo HOME real,
# mismo CLAUDE_PROJECT_DIR. Mide la RUTA SILENCIOSA (payload benigno) — la que corre en >99% de
# las llamadas y que la telemetria de los transcripts NO registra (solo registra hooks que hablan).
# Uso: medir-hooks.sh <repo> <n-repeticiones>
set -uo pipefail
REPO="${1:-$PWD}"; N="${2:-15}"
GH="$HOME/.claude/hooks"; RH="$REPO/.claude/hooks"

now_ms() { python3 -c 'import time;print(int(time.time()*1000))'; }

# payloads realistas por evento
PRE_BASH='{"session_id":"bench","transcript_path":"/dev/null","cwd":"'"$REPO"'","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls -la"}}'
PRE_EDIT='{"session_id":"bench","transcript_path":"/dev/null","cwd":"'"$REPO"'","hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"'"$REPO"'/README.md","old_string":"a","new_string":"b"}}'
PRE_TASK='{"session_id":"bench","transcript_path":"/dev/null","cwd":"'"$REPO"'","hook_event_name":"PreToolUse","tool_name":"Task","tool_input":{"subagent_type":"Explore","prompt":"x"}}'
POST_BASH='{"session_id":"bench","transcript_path":"/dev/null","cwd":"'"$REPO"'","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"ls -la"},"tool_response":{"stdout":"x"}}'

bench() { # nombre ruta payload
  local nom="$1" ruta="$2" pay="$3" i t0 t1 tot=0 best=999999 worst=0 d
  [ -f "$ruta" ] || { printf '%-28s %-8s NO-INSTALADO\n' "$nom" ""; return; }
  for ((i=0;i<N;i++)); do
    t0=$(now_ms)
    printf '%s' "$pay" | timeout 30 bash "$ruta" >/dev/null 2>&1
    t1=$(now_ms); d=$((t1-t0)); tot=$((tot+d))
    (( d<best )) && best=$d; (( d>worst )) && worst=$d
  done
  printf '%-30s %6d %6d %6d\n' "$nom" "$((tot/N))" "$best" "$worst"
}

echo "repo=$REPO  n=$N  (ms: media / min / max)"
echo "=============================== GLOBAL · PreToolUse matcher=Bash ==============================="
printf '%-30s %6s %6s %6s\n' hook media min max
for h in entorno-maquina-guard no-bypass-deploy git-branch-guard merge-squash-guard confirmar-merge-develop recordar-dashboard secret-scan proteger-arbol rama-vieja; do
  bench "$h" "$GH/$h.sh" "$PRE_BASH"; done
echo "=============================== GLOBAL · PreToolUse matcher=Edit|Write ========================="
bench proteger-fuente-cerebro "$GH/proteger-fuente-cerebro.sh" "$PRE_EDIT"
echo "=============================== GLOBAL · PreToolUse matcher=Task|Agent ========================="
for h in limite-gasto delegacion-gate; do bench "$h" "$GH/$h.sh" "$PRE_TASK"; done
echo "=============================== GLOBAL · PostToolUse ==========================================="
for h in recordar-orquestar hud-stale aviso-contexto barrer-ramas; do bench "$h" "$GH/$h.sh" "$POST_BASH"; done
echo "=============================== POR-REPO · PreToolUse matcher=Bash (copia con dedupe) =========="
for h in git-branch-guard merge-squash-guard confirmar-merge-develop recordar-dashboard secret-scan entorno-maquina-guard no-bypass-deploy; do
  bench "repo/$h" "$RH/$h.sh" "$PRE_BASH"; done
echo "=============================== POR-REPO · PostToolUse ========================================="
bench "repo/hud-stale" "$RH/hud-stale.sh" "$POST_BASH"
