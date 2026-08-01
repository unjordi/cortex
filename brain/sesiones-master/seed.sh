#!/usr/bin/env bash
# seed.sh — siembra las sesiones master de la CARPETA DE SESIONES en ~/.claude/projects/ de ESTA
# máquina, para poder `claude --resume` la MISMA conversación aquí. La mitad "sembrar" del sync
# (la mitad "auto-export" es el hook exportar-sesion-master.sh).
#
# CARPETA DE SESIONES: default ~/.claude-sessions, override $CLAUDE_SESSIONS_DRIVE (mismo contrato que
# el hook de export). Si esa carpeta vive en una nube sincronizada (Drive/iCloud), las sesiones viajan
# entre máquinas. session-import.js (lo aporta claude-brain) reescribe el cwd de cada sesión a la ruta
# LOCAL del repo destino, así que el swap /Users<->/home sale solo.
# (Antes seed.sh vivía DENTRO de la carpeta de Drive y se autolocalizaba con $(dirname $0); al mudarse
#  al brain eso ya no aplica → la carpeta se resuelve por env, no por la ubicación del script.)
#
# ROBUSTO POR MÁQUINA: el `target` de masters.json puede NO calzar 1:1 con esta compu —
#   (a) diferencias de MAYÚSCULAS (macOS es case-insensitive, Linux NO: `code/PowerScripts` vs
#       `code/powerscripts`) → el repo destino se resuelve case-insensitive contra lo que EXISTE aquí,
#       y se siembra a la RUTA REAL (para que el cwd reescrito y el slug casen con el repo de verdad);
#   (b) un repo que en esta máquina NO está clonado (p. ej. potenciaDatabases solo vive en la Mac)
#       → ese master se SALTA (no se siembra a un cwd inexistente ni se malgastan cientos de MB).
#
# Uso:  ./seed.sh            (siembra lo presente cuyo repo destino EXISTA aquí; salta lo demás)
#       ./seed.sh --force    (re-siembra pisando lo local)
set -euo pipefail
DIR="${CLAUDE_SESSIONS_DRIVE:-$HOME/.claude-sessions}"
FORCE="${1:-}"
[ -d "$DIR" ] || { echo "seed.sh: no existe la carpeta de sesiones '$DIR' (setea CLAUDE_SESSIONS_DRIVE, o crea ~/.claude-sessions)"; exit 1; }
[ -f "$DIR/masters.json" ] || { echo "seed.sh: no hay masters.json en '$DIR' (nada que sembrar)"; exit 0; }

IMP=""
for c in "$HOME/.local/bin/session-import.js" "$HOME/.claude-brain/bin/session-import.js"; do
  [ -f "$c" ] && IMP="$c" && break
done
[ -n "$IMP" ] || { echo "seed.sh: no encuentro session-import.js (¿claude-brain instalado en esta máquina?)"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "seed.sh: falta node"; exit 1; }

# Resuelve el repo destino de un target relativo a $HOME → imprime la RUTA REAL local, o exit 1 si el
# repo no está en esta máquina. (1) match exacto; (2) match case-insensitive del último componente
# dentro de su carpeta padre (caza PowerScripts vs powerscripts en Linux, que es case-sensitive).
resolve_target() {
  local t="$1" parent base dir p
  if [ -d "$HOME/$t" ]; then printf '%s' "$HOME/$t"; return 0; fi
  parent="$(dirname "$t")"; base="$(basename "$t")"
  dir="$HOME/$parent"
  [ -d "$dir" ] || return 1
  for p in "$dir"/*/; do
    [ -d "$p" ] || continue
    if [ "$(basename "$p" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')" ]; then
      printf '%s' "${p%/}"; return 0
    fi
  done
  return 1
}

node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));for(const e of m.masters)console.log([e.id,e.target,e.name].join("\t"));' "$DIR/masters.json" \
| while IFS=$'\t' read -r id target name; do
    if [ ! -f "$DIR/$id.jsonl.gz" ]; then
      echo "· omito   $name: sin .gz local (¿Drive terminó de bajar? ¿unidad montada?)"
      continue
    fi
    if repo="$(resolve_target "$target")"; then
      echo "· siembro $name  →  $repo"
      node "$IMP" --repo "$repo" --sessions-dir "$DIR" --only "$id" ${FORCE:+$FORCE}
    else
      echo "· omito   $name: el repo destino '$target' no existe en esta máquina (no se siembra)"
    fi
  done
echo ""
echo "✅ listo. Abre 'claude --resume' parado en la carpeta de cada master sembrado y elígela por nombre."
