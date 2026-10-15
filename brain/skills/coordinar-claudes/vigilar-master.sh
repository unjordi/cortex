#!/usr/bin/env bash
# vigilar-master.sh <nombre> <transcript.jsonl> <repo[:repo2:…]> <pid> — emite UNA línea por cambio de estado del master:
#   COMMIT <hash> <msg> · TURNO-TERMINADO (quieto ≥ QUIETO_MIN) · COLGADO (sin eventos ≥ COLGADO_MIN a media vuelta) · MUERTO
# Uso con Monitor; sale solo si el proceso muere. Con <transcript> y <pid> = "-" solo vigila commits
# (repos comunes, como PowerScripts, donde cualquier master deja tooling durable).
N="$1"; T="$2"; R="$3"; P="$4"
QUIETO_MIN="${QUIETO_MIN:-4}"; COLGADO_MIN="${COLGADO_MIN:-12}"; INT="${INT:-60}"
IFS=: read -r -a REPOS <<<"$R"
commits() { for r in "${REPOS[@]}"; do git -C "$r" log --all --since='2 days ago' --format="%H $r" 2>/dev/null; done; }
vistos=" $(commits | cut -d' ' -f1 | tr '\n' ' ') "; estado=""
while true; do
  if [ "$P" != "-" ] && ! kill -0 "$P" 2>/dev/null; then echo "[$N] MUERTO: el proceso $P ya no existe"; exit 0; fi
  while read -r h r; do
    [ -z "$h" ] && continue
    case "$vistos" in *" $h "*) continue;; esac
    vistos="$vistos$h "; echo "[$N] COMMIT $(basename "$r") $(git -C "$r" log -1 --format='%h %s' "$h" | cut -c1-140)"
  done < <(commits)
  [ "$T" = "-" ] && { sleep "$INT"; continue; }
  ult=$(tail -n 40 "$T" 2>/dev/null | jq -rc 'select(.timestamp!=null) | [.timestamp, .type, (.subtype//"")] | @tsv' 2>/dev/null | tail -1)
  ts=$(cut -f1 <<<"$ult"); tipo=$(cut -f2 <<<"$ult"); sub=$(cut -f3 <<<"$ult")
  [ -z "$ts" ] && { sleep "$INT"; continue; }
  edad=$(( ( $(date -u +%s) - $(date -j -u -f '%Y-%m-%dT%H:%M:%S' "${ts%%.*}" +%s 2>/dev/null || date -u -d "$ts" +%s) ) / 60 ))
  if [ "$tipo" = system ] && { [ "$sub" = turn_duration ] || [ "$sub" = stop_hook_summary ] || [ "$sub" = away_summary ]; }; then
    nuevo=$([ "$edad" -ge "$QUIETO_MIN" ] && echo quieto || echo trabajando)
  else
    nuevo=$([ "$edad" -ge "$COLGADO_MIN" ] && echo colgado || echo trabajando)
  fi
  if [ "$nuevo" != "$estado" ]; then
    case "$nuevo" in
      quieto)  echo "[$N] TURNO-TERMINADO: lleva ${edad} min quieto tras cerrar su turno (último evento $ts)";;
      colgado) echo "[$N] COLGADO: ${edad} min sin eventos a media vuelta (último: $tipo $ts)";;
      trabajando) [ -n "$estado" ] && echo "[$N] TRABAJANDO de nuevo";;
    esac
    estado="$nuevo"
  fi
  sleep "$INT"
done
