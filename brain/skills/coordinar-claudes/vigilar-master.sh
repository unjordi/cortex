#!/usr/bin/env bash
# vigilar-master.sh <nombre> <transcript.jsonl> <repo[:repo2:…]> <pid> — emite UNA línea por cambio de estado del master:
#   COMMIT <hash> <msg> · TURNO-TERMINADO (quieto ≥ QUIETO_MIN) · COLGADO (sin eventos ≥ COLGADO_MIN a media vuelta) · MUERTO
# Uso con Monitor; sale solo si el proceso muere. Con <transcript> y <pid> = "-" solo vigila commits
# (repos comunes, como PowerScripts, donde cualquier master deja tooling durable).
# El estado del transcript se decide SOLO con eventos de CONVERSACIÓN (assistant/user/system): un metadato
# con timestamp que el CLI escribe tras cerrar el turno (p. ej. `pr-link`, type propio) NO debe contar como
# "último evento" — si contara, desplazaría al turn_duration y dispararía un COLGADO falso.
# Los tests sourcean con _CMD_VIGILAR_SOURCE_ONLY=1 para obtener vm_estado_de sin correr el loop.
N="${1:-}"; T="${2:-}"; R="${3:-}"; P="${4:-}"
QUIETO_MIN="${QUIETO_MIN:-4}"; COLGADO_MIN="${COLGADO_MIN:-12}"; INT="${INT:-60}"
IFS=: read -r -a REPOS <<<"$R"
commits() { for r in ${REPOS[@]+"${REPOS[@]}"}; do git -C "$r" log --all --since='2 days ago' --format="%H $r" 2>/dev/null; done; }
# vm_estado_de <transcript> → "<estado>\t<edad_min>\t<ts>\t<tipo>" (estado vacío si no hay evento de conversación).
# Estado: quieto (turno cerrado hace ≥QUIETO_MIN) · colgado (sin eventos ≥COLGADO_MIN a media vuelta) · trabajando.
vm_estado_de() {
  local T="$1" ult ts tipo sub edad nuevo
  ult=$(tail -n 40 "$T" 2>/dev/null | jq -rc 'select(.timestamp!=null and (.type=="assistant" or .type=="user" or .type=="system")) | [.timestamp, .type, (.subtype//"")] | @tsv' 2>/dev/null | tail -1)
  ts=$(cut -f1 <<<"$ult"); tipo=$(cut -f2 <<<"$ult"); sub=$(cut -f3 <<<"$ult")
  [ -z "$ts" ] && { printf '\t\t\t\n'; return 0; }
  edad=$(( ( $(date -u +%s) - $(date -j -u -f '%Y-%m-%dT%H:%M:%S' "${ts%%.*}" +%s 2>/dev/null || date -u -d "$ts" +%s) ) / 60 ))
  if [ "$tipo" = system ] && { [ "$sub" = turn_duration ] || [ "$sub" = stop_hook_summary ] || [ "$sub" = away_summary ]; }; then
    nuevo=$([ "$edad" -ge "$QUIETO_MIN" ] && echo quieto || echo trabajando)
  else
    nuevo=$([ "$edad" -ge "$COLGADO_MIN" ] && echo colgado || echo trabajando)
  fi
  printf '%s\t%s\t%s\t%s\n' "$nuevo" "$edad" "$ts" "$tipo"
}

[ "${_CMD_VIGILAR_SOURCE_ONLY:-}" = "1" ] && return 0 2>/dev/null

vistos=" $(commits | cut -d' ' -f1 | tr '\n' ' ') "; estado=""
while true; do
  if [ "$P" != "-" ] && ! kill -0 "$P" 2>/dev/null; then echo "[$N] MUERTO: el proceso $P ya no existe"; exit 0; fi
  while read -r h r; do
    [ -z "$h" ] && continue
    case "$vistos" in *" $h "*) continue;; esac
    vistos="$vistos$h "; echo "[$N] COMMIT $(basename "$r") $(git -C "$r" log -1 --format='%h %s' "$h" | cut -c1-140)"
  done < <(commits)
  [ "$T" = "-" ] && { sleep "$INT"; continue; }
  IFS=$'\t' read -r nuevo edad ts tipo < <(vm_estado_de "$T")
  [ -z "$nuevo" ] && { sleep "$INT"; continue; }
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
