#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit linux-ssh-*; ver ../SKILL.md
#
# linux-ssh-send-double-click.sh - Doble click por coordenada (abrir iconos/listas), POR SSH.
# ==================================================================================================
# Atajo de linux-ssh-send-click.sh -Double (mismo mecanismo, mismos gotchas: solo X11/XWayland, y
# el permiso EIS de KWin -- ver ese script para el detalle completo).
#
# USO: linux-ssh-send-double-click.sh -X 240 -Y 560 [-Window "titulo"]
# EXIT: 0 si xdotool despacho el evento (no garantiza que aterrizo); 1 sin sesion/xdotool.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/linux-ssh-send-click.sh" "$@" -Double
