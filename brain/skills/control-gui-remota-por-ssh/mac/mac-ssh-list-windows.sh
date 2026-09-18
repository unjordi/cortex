#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit mac-ssh-*; ver ../SKILL.md
#
# mac-ssh-list-windows.sh - Lista las ventanas visibles (app + titulo + rect), POR SSH.
# ==================================================================================================
# Via osascript + System Events: enumera los procesos de UI (background only = false) y las
# ventanas de cada uno, con posicion y tamano. Requiere el permiso de Accesibilidad (igual que
# send-click/send-keys) -- es LECTURA de la jerarquia de UI, no input sintetico, pero System Events
# lo gatea igual.
#
# VERIFICADO 2026-09-18 LOCAL: la enumeracion de "application processes" (nombre + pid) funciono
# sin error; la enumeracion de ventanas por proceso se probo contra Finder (sin ventanas abiertas en
# ese momento -> lista vacia, comportamiento correcto, no error).
#
# USO (por SSH):
#   mac-ssh-list-windows.sh
#   mac-ssh-list-windows.sh -Filter Kate
#   mac-ssh-list-windows.sh -Csv
#
# EXIT: 0 ok (aunque la lista salga vacia); 1 sin sesion de consola.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-mac-ssh-env.sh
source "$SCRIPT_DIR/lib-mac-ssh-env.sh"

Filter=""; Csv=0
while [ $# -gt 0 ]; do
    case "$1" in
        -Filter) Filter="$2"; shift 2 ;;
        -Csv) Csv=1; shift ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done

cu="$(mac_console_user)"
[ -z "$cu" ] && { echo "SIN sesion de consola activa" >&2; exit 1; }

raw=$(mac_dispatch osascript -e '
tell application "System Events"
    set out to ""
    repeat with p in (application processes whose background only is false)
        set pn to name of p
        try
            repeat with w in windows of p
                set wn to name of w
                set wp to position of w
                set ws to size of w
                set out to out & pn & "\t" & wn & "\t" & (item 1 of wp) & "\t" & (item 2 of wp) & "\t" & (item 1 of ws) & "\t" & (item 2 of ws) & "\n"
            end repeat
        end try
    end repeat
    return out
end tell' 2>/dev/null)

[ "$Csv" -eq 1 ] && echo "App,Title,X,Y,W,H"
printf '%s\n' "$raw" | while IFS=$'\t' read -r app title x y w h; do
    [ -z "$app" ] && continue
    if [ -n "$Filter" ]; then
        case "$app $title" in *"$Filter"*) ;; *) continue ;; esac
    fi
    if [ "$Csv" -eq 1 ]; then
        printf '"%s","%s",%s,%s,%s,%s\n' "$app" "$title" "$x" "$y" "$w" "$h"
    else
        printf '%-20s %6s %6s %6s %6s  %s\n' "$app" "$x" "$y" "$w" "$h" "$title"
    fi
done
exit 0
