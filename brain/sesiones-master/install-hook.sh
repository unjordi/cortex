#!/usr/bin/env bash
# install-hook.sh — [ya NO instala por su cuenta] El auto-export de sesiones-master es un hook del brain
# (brain/hooks/exportar-sesion-master.sh): lo copia a ~/.claude/hooks/ y lo cablea INSTALL-BRAIN,
# derivándolo del MANIFEST (Stop + SessionEnd + PreCompact) → UNA sola ruta de wiring, sin duplicar la
# lista de eventos (antídoto al drift). Este script queda solo para dos cosas:
#   ./install-hook.sh              → redirige a install-brain (instala/actualiza el cerebro completo).
#   ./install-hook.sh --uninstall  → quita SOLO el cableado del export (los 3 eventos) + el hook, sin
#                                    tocar el resto del cerebro (para desactivar el auto-export en una compu).
set -eu
GSET="$HOME/.claude/settings.json"
HOOKS="$HOME/.claude/hooks"
DST="$HOOKS/exportar-sesion-master.sh"
EVENTS="Stop SessionEnd PreCompact"

if [ "${1:-}" = "--uninstall" ]; then
  command -v jq >/dev/null 2>&1 || { echo "install-hook: falta jq (brew install jq)"; exit 1; }
  if [ -f "$GSET" ]; then
    for ev in $EVENTS; do
      tmp="$(mktemp)"
      jq --arg ev "$ev" '
        if .hooks[$ev] then .hooks[$ev] |= map(select( ([.hooks[]?.command]|join(" ")) | test("exportar-sesion-master") | not )) else . end
      ' "$GSET" > "$tmp" && mv "$tmp" "$GSET"
    done
    echo "descableado el export de sesiones-master ($EVENTS) de $GSET"
  fi
  rm -f "$DST" && echo "hook removido de $HOOKS"
  exit 0
fi

# install → delega al instalador único del cerebro (que copia el hook + lo cablea desde el MANIFEST).
BRAIN="${CLAUDE_BRAIN_DIR:-$HOME/.claude-brain}"
if [ ! -f "$BRAIN/brain/install-brain.sh" ]; then
  echo "install-hook: no encuentro install-brain en '$BRAIN' (setea CLAUDE_BRAIN_DIR o clona el cerebro)."
  exit 1
fi
echo "El export de sesiones-master lo instala+cablea install-brain (es un hook del cerebro)."
echo "→ corriendo: bash $BRAIN/brain/install-brain.sh"
exec bash "$BRAIN/brain/install-brain.sh"
