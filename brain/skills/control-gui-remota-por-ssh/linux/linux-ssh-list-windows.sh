#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit linux-ssh-*; ver ../SKILL.md
#
# linux-ssh-list-windows.sh - Lista las ventanas visibles (titulo + rect + PID), POR SSH.
# ==================================================================================================
# Via `xdotool search` sobre XWayland/X11. NO es de solo-lectura-inocua en el sentido de que SI
# necesita sesion grafica, pero NO dispara el permiso EIS de KWin (ese permiso es solo para
# INPUT sintetico -- click/tecla/mouse; listar ventanas es una consulta, no un control).
#
# LIMITE REAL (verificado 2026-09-18 en cachy, KDE Wayland): xdotool/XWayland SOLO ve ventanas
# X11 y apps XWayland (Steam, apps legacy). Las apps WAYLAND NATIVAS (la mayoria del escritorio
# moderno: Firefox nativo, apps GTK4/Qt6-Wayland, la barra de tareas de KDE) NO aparecen en esta
# lista -- el compositor no las expone por XWayland. Para esas, el screenshot es la unica via
# confiable de "ver que hay". No lo tomes como bug del script: es un limite estructural de X11
# sobre Wayland, sin equivalente limpio de "listar TODAS las ventanas" fuera de un protocolo nativo
# del compositor (KDE expone `kwin_wayland` scripting/DBus por su lado, SIN CONFIRMAR un metodo
# generico cross-compositor).
#
# USO (por SSH):
#   linux-ssh-list-windows.sh
#   linux-ssh-list-windows.sh -Filter MiApp      # solo ventanas cuyo titulo contenga 'MiApp'
#   linux-ssh-list-windows.sh -Csv               # CSV: Title,PID,X,Y,W,H
#
# EXIT: 0 ok (aunque la lista salga vacia); 1 sin sesion grafica / falta xdotool.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-linux-ssh-env.sh
source "$SCRIPT_DIR/lib-linux-ssh-env.sh"

Filter=""; Csv=0
while [ $# -gt 0 ]; do
    case "$1" in
        -Filter) Filter="$2"; shift 2 ;;
        -Csv) Csv=1; shift ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done

resolve_session_env
if ! has_session_desktop; then echo "SIN sesion grafica activa" >&2; exit 1; fi
command -v xdotool >/dev/null 2>&1 || { echo "FALTA xdotool" >&2; exit 1; }

[ "$Csv" -eq 1 ] && echo "Title,PID,X,Y,W,H"
for w in $(xdotool search --name "" 2>/dev/null); do
    name=$(xdotool getwindowname "$w" 2>/dev/null)
    [ -z "$name" ] && continue
    if [ -n "$Filter" ] && [[ "$name" != *"$Filter"* ]]; then continue; fi
    pid=$(xdotool getwindowpid "$w" 2>/dev/null)
    geo=$(xdotool getwindowgeometry --shell "$w" 2>/dev/null)
    x=$(printf '%s\n' "$geo" | grep '^X=' | cut -d= -f2)
    y=$(printf '%s\n' "$geo" | grep '^Y=' | cut -d= -f2)
    wd=$(printf '%s\n' "$geo" | grep '^WIDTH=' | cut -d= -f2)
    ht=$(printf '%s\n' "$geo" | grep '^HEIGHT=' | cut -d= -f2)
    [ -z "$wd" ] && continue
    { [ "$wd" -le 0 ] || [ "$ht" -le 0 ]; } 2>/dev/null && continue
    if [ "$Csv" -eq 1 ]; then
        printf '"%s",%s,%s,%s,%s,%s\n' "$name" "${pid:-}" "$x" "$y" "$wd" "$ht"
    else
        printf '%-8s %-6s %6s %6s %6s %6s  %s\n' "$w" "${pid:-}" "$x" "$y" "$wd" "$ht" "$name"
    fi
done
exit 0
