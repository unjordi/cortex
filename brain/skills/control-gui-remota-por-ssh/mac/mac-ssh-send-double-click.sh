#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit mac-ssh-*; ver ../SKILL.md
#
# mac-ssh-send-double-click.sh - Doble click por coordenada (abrir iconos/listas), POR SSH.
# ==================================================================================================
# Atajo de mac-ssh-send-click.sh -Double (mismo mecanismo cliclick, misma precondicion TCC de
# Accesibilidad -- ver ese script para el detalle completo).
#
# USO: mac-ssh-send-double-click.sh -X 240 -Y 560 [-Window "MiApp"]
# EXIT: 0 si despacho el click; 1 sin sesion de consola / falta cliclick.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/mac-ssh-send-click.sh" "$@" -Double
