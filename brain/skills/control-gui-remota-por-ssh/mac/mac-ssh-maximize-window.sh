#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit mac-ssh-*; ver ../SKILL.md
#
# mac-ssh-maximize-window.sh - Maximiza/restaura/minimiza la ventana de una app, POR SSH.
# ==================================================================================================
# ADAPTACION (documentada): macOS no tiene un "maximizar" identico a Windows -- el boton verde
# activa Full Screen NATIVO (otro espacio virtual, distinto concepto). Este script aproxima
# "Maximize" REDIMENSIONANDO la ventana al area visible de la pantalla principal (bounds del
# escritorio via Finder), que es el comportamiento mas parecido y no cambia de espacio/Mission
# Control. "Minimize" usa la propiedad `minimized` real de System Events (equivalente exacto).
# "Restore" no tiene un tamano "previo" que recordar (Windows si lo recuerda via SW_RESTORE) -- este
# script lo aproxima con un tamano/posicion razonables fijos, igual que su gemelo Linux.
#
# USO (por SSH):
#   mac-ssh-maximize-window.sh -App "Kate" -State Maximize
#   mac-ssh-maximize-window.sh -App "Kate" -State Minimize
#   mac-ssh-maximize-window.sh -App "Kate" -State Restore
#
# EXIT: 0 si disparo la operacion; 1 sin sesion de consola / falto -App.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-mac-ssh-env.sh
source "$SCRIPT_DIR/lib-mac-ssh-env.sh"

App=""; State="Maximize"
while [ $# -gt 0 ]; do
    case "$1" in
        -App) App="$2"; shift 2 ;;
        -State) State="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
[ -z "$App" ] && { echo "Falta -App" >&2; exit 2; }

cu="$(mac_console_user)"
[ -z "$cu" ] && { echo "SIN sesion de consola activa" >&2; exit 1; }

case "$State" in
    Maximize)
        mac_dispatch osascript -e "
        tell application \"Finder\" to set db to bounds of window of desktop
        tell application \"System Events\"
            tell process \"$App\"
                set position of window 1 to {(item 1 of db), (item 2 of db)}
                set size of window 1 to {((item 3 of db) - (item 1 of db)), ((item 4 of db) - (item 2 of db))}
            end tell
        end tell" 2>&1
        ;;
    Minimize)
        mac_dispatch osascript -e "tell application \"System Events\" to tell process \"$App\" to set value of attribute \"AXMinimized\" of window 1 to true" 2>&1
        ;;
    Restore)
        mac_dispatch osascript -e "
        tell application \"System Events\"
            tell process \"$App\"
                try
                    set value of attribute \"AXMinimized\" of window 1 to false
                end try
                set position of window 1 to {100, 100}
                set size of window 1 to {1024, 768}
            end tell
        end tell" 2>&1
        ;;
    *) echo "State invalido: $State (Maximize|Minimize|Restore)" >&2; exit 2 ;;
esac
echo "OK $State -> '$App'"
exit 0
