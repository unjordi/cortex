#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit linux-ssh-*; ver ../SKILL.md
#
# linux-ssh-screenshot.sh - Captura la pantalla de la sesion grafica interactiva, POR SSH.
# ==================================================================================================
# POR QUE NO ES TRIVIAL: una sesion SSH cae en un tty SIN DISPLAY/WAYLAND_DISPLAY -- no ve el
# escritorio del usuario logueado. Se resuelve el entorno de ESA sesion (ver lib-linux-ssh-env.sh,
# analogo funcional del `schtasks /IT` de Windows) y se elige la herramienta de captura segun el
# compositor: spectacle (KDE) > grim (wlroots: Sway/Hyprland) > gnome-screenshot (GNOME) >
# `import -window root` de ImageMagick (fallback X11/XWayland puro).
#
# VERIFICADO 2026-09-18 en cachy (CachyOS, KDE Plasma 6.7 Wayland, `spectacle`): PNG real de
# 1920x1080, ~200KB, mostrando el escritorio real (no negro, no truncado). No hizo falta ningun
# equivalente a SetProcessDPIAware() de Windows -- Wayland/X11 entregan la resolucion FISICA tal
# cual (a diferencia de Windows con escalado, que sin el fix trunca a la escala logica).
#
# USO (por SSH):
#   linux-ssh-screenshot.sh                              # -> guarda PNG, imprime ruta+tamano
#   linux-ssh-screenshot.sh -B64                          # -> ademas IMPRIME el PNG en base64
#   linux-ssh-screenshot.sh -Out /tmp/x.png -B64
#
# EXIT: 0 si genero el PNG; 1 si no hay sesion grafica / ninguna herramienta de captura disponible.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-linux-ssh-env.sh
source "$SCRIPT_DIR/lib-linux-ssh-env.sh"

Out="/tmp/linux-ssh-shot.png"
B64=0
WaitMs=0

while [ $# -gt 0 ]; do
    case "$1" in
        -Out) Out="$2"; shift 2 ;;
        -B64) B64=1; shift ;;
        -WaitMs) WaitMs="$2"; shift 2 ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done

resolve_session_env
if ! has_session_desktop; then
    echo "SIN sesion grafica activa -> no hay escritorio que capturar" >&2
    exit 1
fi

mkdir -p "$(dirname "$Out")"
[ "$WaitMs" -gt 0 ] 2>/dev/null && sleep "$(awk "BEGIN{print $WaitMs/1000}")"
rm -f "$Out"

if command -v spectacle >/dev/null 2>&1; then
    spectacle -b -n -f -o "$Out" >/dev/null 2>&1
elif command -v grim >/dev/null 2>&1; then
    grim "$Out" >/dev/null 2>&1
elif command -v gnome-screenshot >/dev/null 2>&1; then
    gnome-screenshot -f "$Out" >/dev/null 2>&1
elif command -v import >/dev/null 2>&1; then
    DISPLAY="$DISPLAY" import -window root "$Out" >/dev/null 2>&1
else
    echo "FALLO: ninguna herramienta de captura disponible (spectacle/grim/gnome-screenshot/import)" >&2
    exit 1
fi

if [ ! -s "$Out" ]; then
    echo "FALLO: no se genero el PNG (revisa el gotcha de permiso EIS/portal -- ver SKILL.md)" >&2
    exit 1
fi

sz=$(wc -c < "$Out" | tr -d ' ')
if [ "$B64" -eq 1 ]; then
    base64 -i "$Out" | tr -d '\n'
    echo ""
else
    echo "OK screenshot -> $Out ($sz bytes)"
fi
exit 0
