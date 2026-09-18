#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit mac-ssh-*; ver ../SKILL.md
#
# mac-ssh-clipboard.sh - Lee/escribe el portapapeles de la sesion de consola, POR SSH.
# ==================================================================================================
# `pbcopy`/`pbpaste` (nativos macOS) -- SIN permiso TCC de por medio (a diferencia de
# screenshot/click/keys/list-windows): el portapapeles del sistema no esta gateado por
# Accesibilidad ni Grabacion de pantalla.
#
# USO (por SSH):
#   mac-ssh-clipboard.sh -Get
#   mac-ssh-clipboard.sh -Set "texto a copiar"
#
# EXIT: 0 ok; 1 sin sesion de consola / falto -Get o -Set.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-mac-ssh-env.sh
source "$SCRIPT_DIR/lib-mac-ssh-env.sh"

Get=0; SetText=""
while [ $# -gt 0 ]; do
    case "$1" in
        -Get) Get=1; shift ;;
        -Set) SetText="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
[ "$Get" -eq 0 ] && [ -z "$SetText" ] && { echo "Da -Get o -Set \"texto\"" >&2; exit 2; }

cu="$(mac_console_user)"
[ -z "$cu" ] && { echo "SIN sesion de consola activa" >&2; exit 1; }

if [ "$Get" -eq 1 ]; then
    mac_dispatch pbpaste
else
    printf '%s' "$SetText" | mac_dispatch pbcopy
    echo "OK portapapeles (pbcopy) <- \"$SetText\""
fi
exit 0
