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
# MULTI-MONITOR (QA en vivo 2026-09-18, paridad con win-ssh-screenshot.ps1 que agarra el
# VirtualScreen completo): a diferencia de macOS (donde `screencapture` SIN flags agarra SOLO la
# pantalla principal -- ver el gotcha correspondiente en mac-ssh-screenshot.sh), en Linux el modo
# DEFAULT de las 4 herramientas de este script YA es "todo el escritorio, todos los monitores,
# UNA sola imagen cosida" -- no una adaptacion nueva, es como cada una se comporta de fabrica:
#   - spectacle: `-f/--fullscreen` ("Capture the entire desktop") es el DEFAULT documentado --
#     confirmado por `spectacle --help` en cachy 2026-09-18, y es el flag que este script ya usaba.
#   - grim: sin `-o <output>`, captura TODAS las salidas compuestas en una imagen.
#   - gnome-screenshot / `import -window root`: capturan la pantalla X11 completa (todas las
#     salidas bajo el mismo screen X11 con RandR, el layout estandar moderno).
# OJO -- LIMITE DE ESTA VERIFICACION: `cachy` (la maquina de prueba) solo tiene UN monitor fisico
# conectado (`kscreen-doctor -o` -> un solo Output HDMI-A-1) -- no se pudo confirmar VISUALMENTE
# que dos o mas monitores reales queden cosidos en una sola imagen, solo que el flag/comportamiento
# default de cada herramienta esta documentado para hacerlo. Cuando alguien lo use contra una
# maquina con 2+ monitores reales, confirmalo y actualiza esta nota.
#
# USO (por SSH):
#   linux-ssh-screenshot.sh                              # DEFAULT: escritorio completo (todos los monitores)
#   linux-ssh-screenshot.sh -Display HDMI-A-1             # SOLO ese output (nombre, no numero -- ver abajo)
#   linux-ssh-screenshot.sh -ActiveWindow                 # SOLO la ventana con foco (spectacle -a)
#   linux-ssh-screenshot.sh -Window "Kate"                # SOLO esa ventana (por titulo -- ver mecanismo arriba)
#   linux-ssh-screenshot.sh -B64                          # ademas IMPRIME el PNG en base64
#   linux-ssh-screenshot.sh -Out /tmp/x.png -B64
#
# `-Display <output>`: en Linux los monitores se nombran (HDMI-A-1, DP-2, eDP-1...), no se numeran
# como en Windows/Mac -- lista los nombres reales con `kscreen-doctor -o | grep Output:` (KDE) o
# `wlr-randr`/`swaymsg -t get_outputs` (wlroots). Mecanismo por herramienta:
#   - grim: nativo, `grim -o <output>` (sin recorte, la salida ES esa pantalla).
#   - spectacle (KDE, SIN flag nativo por-output): captura completa + RECORTE con ImageMagick
#     (`convert`) usando la geometria de `kscreen-doctor -o` para ESE output. VERIFICADO 2026-09-18
#     en cachy con su UNICO output (HDMI-A-1): el recorte coincidio exacto con la imagen completa
#     (mismo tamano) -- confirma que el parseo de geometria + `convert -crop` funciona, aunque no
#     hubo un SEGUNDO monitor real para probar que descarta el resto.
#   - gnome-screenshot / import: SIN mecanismo por-output conocido en este kit -- cae a pantalla
#     completa con un aviso (no lo finge).
#
# `-ActiveWindow`: SOLO implementado via spectacle (`-a`, KDE) en esta pasada -- es la ventana con
# FOCO, no una busqueda por titulo. En grim/gnome-screenshot/import queda SIN CONFIRMAR -- cae a
# pantalla completa con un aviso.
#
# `-Window "titulo"` (agregado 2026-09-18, PARIDAD con el `-Window` de Windows/Mac -- misma
# semantica: substring del titulo, mismo fallback si no se halla): REUSA el MISMO mecanismo que
# `linux-ssh-get-window-coordinates.sh` (`xdotool search --name` para resolver titulo->window-id,
# `xdotool getwindowgeometry --shell` para el rectangulo X,Y,W,H) -- no se reimplementa la busqueda.
# Con el window-id + rectangulo ya resueltos, la CAPTURA en si prueba, en orden, el mecanismo mas
# nativo/preciso disponible:
#   1. `import -window <id>` (ImageMagick) -- NATIVO por-ventana, funciona sobre XWayland/X11 igual
#      que xdotool (mismo id), sin necesitar el rectangulo (ImageMagick pregunta al servidor X el
#      tamano real de esa window). Es la opcion PRIMARIA -- ImageMagick ya es dependencia opcional
#      de este kit (se usa como fallback de captura completa desde antes).
#   2. `grim -g "X,Y WxH"` (wlroots -- Sway/Hyprland) si no hay `import`.
#   3. Captura completa + `convert -crop WxH+X+Y` (mismo primitivo que ya usaba `-Display`) si ni
#      `import` ni `grim` sirvieron.
#   4. Sin ninguna herramienta de recorte: aviso + pantalla completa (mismo patron que `-Display`).
# Igual que `-ActiveWindow`, esto SOLO alcanza ventanas X11/XWayland (limite ya documentado de
# `list-windows`/`get-window-coordinates` -- xdotool no ve Wayland nativo).
#
# VERIFICADO 2026-09-18 EN VIVO en cachy (KDE Plasma 6.7 Wayland; `import` presente, `grim`
# AUSENTE -- via PRIMARIA de verdad ejercitada): las ventanas XWayland de Steam en esa maquina
# resultaron estar TODAS `IsUnMapped` (confirmado con `xwininfo` -- geometria reportada pero nada
# realmente en pantalla, por eso una primera prueba contra ellas dio PNG de 10x10 basura-entra-
# basura-sale, no un bug del script). Con una ventana X11 REAL y MAPEADA (`xmessage -title
# "QA Window Test"`, lanzada para esta prueba): `-Window "QA Window Test"` via `import -window <id>`
# dio un PNG de EXACTAMENTE 182x52 -- igual al rectangulo que reporto `xdotool getwindowgeometry`
# para esa ventana (X=868 Y=527 WIDTH=182 HEIGHT=52), no el escritorio completo (1920x1080).
# Tambien confirmado: `-Window` con un titulo que no existe cae a pantalla completa con el aviso
# esperado, sin tronar.
#
# EXIT: 0 si genero el PNG; 1 si no hay sesion grafica / ninguna herramienta de captura disponible.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-linux-ssh-env.sh
source "$SCRIPT_DIR/lib-linux-ssh-env.sh"

Out="/tmp/linux-ssh-shot.png"
B64=0
WaitMs=0
Display=""
ActiveWindow=0
Window=""

while [ $# -gt 0 ]; do
    case "$1" in
        -Out) Out="$2"; shift 2 ;;
        -B64) B64=1; shift ;;
        -WaitMs) WaitMs="$2"; shift 2 ;;
        -Display) Display="$2"; shift 2 ;;
        -ActiveWindow) ActiveWindow=1; shift ;;
        -Window) Window="$2"; shift 2 ;;
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

# geometria "X,Y WxH" de UN output por nombre, via kscreen-doctor (KDE) -- ANSI-stripped.
kscreen_output_geometry() {
    local want="$1"
    command -v kscreen-doctor >/dev/null 2>&1 || return 1
    kscreen-doctor -o 2>/dev/null \
        | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
        | awk -v want="$want" '
            /^Output:/ { active = ($3 == want) }
            active && /Geometry:/ {
                line=$0; sub(/^[[:space:]]*Geometry:[[:space:]]*/,"",line); print line; exit
            }'
}

capture_full() {
    local dst="$1"
    if command -v spectacle >/dev/null 2>&1; then
        spectacle -b -n -f -o "$dst" >/dev/null 2>&1
    elif command -v grim >/dev/null 2>&1; then
        grim "$dst" >/dev/null 2>&1
    elif command -v gnome-screenshot >/dev/null 2>&1; then
        gnome-screenshot -f "$dst" >/dev/null 2>&1
    elif command -v import >/dev/null 2>&1; then
        DISPLAY="$DISPLAY" import -window root "$dst" >/dev/null 2>&1
    else
        echo "FALLO: ninguna herramienta de captura disponible (spectacle/grim/gnome-screenshot/import)" >&2
        return 1
    fi
}

# resuelve titulo->window-id->rectangulo REUSANDO el mismo mecanismo de
# linux-ssh-get-window-coordinates.sh (xdotool search --name / getwindowgeometry --shell), en vez
# de reimplementar la busqueda.
capture_window_by_title() {
    local title="$1" dst="$2"
    if ! command -v xdotool >/dev/null 2>&1; then
        echo "AVISO: falta xdotool -- no puedo resolver -Window por titulo, capturo pantalla completa" >&2
        capture_full "$dst"
        return
    fi
    local wid
    wid=$(xdotool search --name "$title" 2>/dev/null | head -1)
    if [ -z "$wid" ]; then
        echo "no encontre ventana que contenga '$title' -- capturo pantalla completa en su lugar" >&2
        capture_full "$dst"
        return
    fi
    local geo X Y W H
    geo=$(xdotool getwindowgeometry --shell "$wid" 2>/dev/null)
    X=$(printf '%s\n' "$geo" | grep '^X=' | cut -d= -f2)
    Y=$(printf '%s\n' "$geo" | grep '^Y=' | cut -d= -f2)
    W=$(printf '%s\n' "$geo" | grep '^WIDTH=' | cut -d= -f2)
    H=$(printf '%s\n' "$geo" | grep '^HEIGHT=' | cut -d= -f2)

    # 1. import -window <id>: nativo por-ventana, no necesita el rectangulo.
    if command -v import >/dev/null 2>&1; then
        DISPLAY="$DISPLAY" import -window "$wid" "$dst" 2>/dev/null
    fi
    # 2. grim -g "X,Y WxH": nativo (wlroots), si import no sirvio/no esta.
    if [ ! -s "$dst" ] && command -v grim >/dev/null 2>&1; then
        grim -g "${X},${Y} ${W}x${H}" "$dst" 2>/dev/null
    fi
    # 3. completa + recorte (mismo primitivo que -Display).
    if [ ! -s "$dst" ]; then
        if command -v convert >/dev/null 2>&1; then
            local tmp="${dst}.full.png"
            capture_full "$tmp"
            convert "$tmp" -crop "${W}x${H}+${X}+${Y}" +repage "$dst" 2>/dev/null
            rm -f "$tmp"
        else
            echo "AVISO: no pude recortar por ventana (falta import/grim/convert) -- capturo pantalla completa" >&2
            capture_full "$dst"
        fi
    fi
}

if [ -n "$Window" ]; then
    capture_window_by_title "$Window" "$Out"
elif [ "$ActiveWindow" -eq 1 ]; then
    if command -v spectacle >/dev/null 2>&1; then
        spectacle -b -n -a -o "$Out" >/dev/null 2>&1
    else
        echo "AVISO: -ActiveWindow solo implementado via spectacle (KDE) en este kit -- capturo pantalla completa" >&2
        capture_full "$Out"
    fi
elif [ -n "$Display" ]; then
    if command -v grim >/dev/null 2>&1 && ! command -v spectacle >/dev/null 2>&1; then
        grim -o "$Display" "$Out" >/dev/null 2>&1
    elif command -v spectacle >/dev/null 2>&1; then
        geo="$(kscreen_output_geometry "$Display")"
        if [ -z "$geo" ]; then
            echo "AVISO: no encontre el output '$Display' via kscreen-doctor -- capturo pantalla completa" >&2
            capture_full "$Out"
        elif ! command -v convert >/dev/null 2>&1; then
            echo "AVISO: falta ImageMagick (convert) para recortar por output -- capturo pantalla completa" >&2
            capture_full "$Out"
        else
            pos="${geo%% *}"; size="${geo##* }"
            X="${pos%%,*}"; Y="${pos##*,}"
            W="${size%%x*}"; H="${size##*x}"
            tmp="${Out}.full.png"
            capture_full "$tmp"
            convert "$tmp" -crop "${W}x${H}+${X}+${Y}" +repage "$Out" 2>/dev/null
            rm -f "$tmp"
        fi
    else
        echo "AVISO: -Display sin grim ni spectacle disponibles -- capturo pantalla completa" >&2
        capture_full "$Out"
    fi
else
    capture_full "$Out"
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
