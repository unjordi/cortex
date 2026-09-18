#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit linux-ssh-*; ver ../SKILL.md
#
# linux-ssh-launch.sh - Lanza un programa EN la sesion grafica interactiva, POR SSH.
# ==================================================================================================
# ADAPTACION respecto a win-ssh-launch.ps1 (documentada): en Windows hace falta despachar el
# lanzamiento a una tarea /IT porque la sesion SSH esta en OTRA logon-session (sin escritorio ni
# drives mapeados). En Linux, una vez que `resolve_session_env` exporta DISPLAY/WAYLAND_DISPLAY/
# DBUS_SESSION_BUS_ADDRESS correctos, un proceso HIJO los hereda tal cual y se conecta directo al
# compositor/D-Bus de esa sesion -- no hace falta un mecanismo de despacho por-gesto. `setsid` lo
# desprende de la sesion SSH (para que sobreviva si la SSH se cierra) y `disown` evita que quede
# como job de este shell.
#
# USO (por SSH):
#   linux-ssh-launch.sh -Path /usr/bin/firefox
#   linux-ssh-launch.sh -Path /usr/bin/firefox -Args "https://ejemplo.com"
#
# EXIT: 0 si disparo el lanzamiento (no espera a que la app termine de abrir -- confirma con
# screenshot/list-windows); 1 sin sesion grafica.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-linux-ssh-env.sh
source "$SCRIPT_DIR/lib-linux-ssh-env.sh"

Path=""; Args=""
while [ $# -gt 0 ]; do
    case "$1" in
        -Path) Path="$2"; shift 2 ;;
        -Args) Args="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
[ -z "$Path" ] && { echo "Falta -Path" >&2; exit 2; }

resolve_session_env
if ! has_session_desktop; then echo "SIN sesion grafica activa -> no hay donde lanzar" >&2; exit 1; fi

# shellcheck disable=SC2086
setsid nohup "$Path" $Args >/tmp/linux-ssh-launch.log 2>&1 < /dev/null &
disown
sleep 0.3

echo "OK lanzado '$Path' ${Args:+[$Args] }(sesion: DISPLAY=$DISPLAY WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-})"
exit 0
