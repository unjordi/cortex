# skill control-gui-remota-por-ssh (cortex) -- lib compartida por linux-ssh-*.sh; ver ../SKILL.md
#
# resolve_session_env() -- deriva el entorno de la SESION GRAFICA INTERACTIVA del usuario logueado,
# para que un comando disparado desde SSH (que cae en un tty SIN DISPLAY/WAYLAND_DISPLAY) pueda
# capturar/controlar ESA sesion. Es el analogo funcional del `schtasks /IT` de Windows: alla se
# despacha CADA gesto a una tarea que corre COMO el usuario logueado; aqui basta con exportar las
# variables correctas UNA vez por invocacion, porque un proceso hijo las hereda y conecta directo
# al Wayland/X11/DBus de esa sesion -- no hace falta un mecanismo de despacho por-gesto como en Windows.
#
# VERIFICADO 2026-09-18 en cachy (CachyOS, KDE Plasma 6.7 / kwin_wayland):
#   - /proc/<pid>/environ esta BLOQUEADO (ptrace_scope) -- "Permission denied" aun same-user. NO
#     lo uses como fuente del entorno.
#   - XDG_RUNTIME_DIR=/run/user/<uid> (estandar, no depende de compositor).
#   - WAYLAND_DISPLAY = el socket `wayland-N` (sin `.lock`) en $XDG_RUNTIME_DIR.
#   - DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus (socket `bus` en el mismo dir).
#   - DISPLAY y XAUTHORITY (para clientes XWayland/X11) salen del CMDLINE del compositor, legible
#     por `ps` aunque /proc/environ este bloqueado: en KWin trae
#     `--xwayland-display :0 --xwayland-xauthority /run/user/<uid>/xauth_XXXX`.
#     Otros compositores (Hyprland/sway/GNOME) exponen flags analogas en su propio cmdline --
#     SIN CONFIRMAR el patron exacto fuera de KWin; ajusta la lista COMPOSITORS abajo si hace falta.
#
# Adaptacion respecto al kit win-ssh-* (documentada, no es drift): Windows no tiene una lib
# compartida (cada win-ssh-*.ps1 repite su propia Get-ConsoleUser) porque CADA gesto se despacha
# como una tarea programada independiente. Aqui, en cambio, un solo proceso bash hace TODO el
# trabajo de un gesto de punta a punta, asi que una funcion compartida evita divergencia entre 13
# copias de la misma logica de deteccion sin cambiar el contrato publico (mismos flags/salida).

resolve_session_env() {
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

    if [ -z "${WAYLAND_DISPLAY:-}" ]; then
        WAYLAND_DISPLAY="$(ls "$XDG_RUNTIME_DIR" 2>/dev/null | grep -E '^wayland-[0-9]+$' | head -1)"
    fi
    export WAYLAND_DISPLAY

    if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    fi

    if [ -z "${DISPLAY:-}" ] || [ -z "${XAUTHORITY:-}" ]; then
        local comp comp_args=""
        for comp in kwin_wayland kwin_x11 sway Hyprland gnome-shell weston labwc; do
            comp_args="$(ps -o args= -C "$comp" 2>/dev/null | head -1)"
            [ -n "$comp_args" ] && break
        done
        if [ -n "$comp_args" ]; then
            [ -z "${DISPLAY:-}" ]    && DISPLAY="$(printf '%s' "$comp_args"    | grep -oP '(?<=--xwayland-display )\S+' 2>/dev/null)"
            [ -z "${XAUTHORITY:-}" ] && XAUTHORITY="$(printf '%s' "$comp_args" | grep -oP '(?<=--xwayland-xauthority )\S+' 2>/dev/null)"
        fi
        # Fallback generico para X11 puro (sin Wayland) o si el compositor no dio pistas:
        [ -z "${DISPLAY:-}" ]    && DISPLAY=":0"
        [ -z "${XAUTHORITY:-}" ] && [ -f "$HOME/.Xauthority" ] && XAUTHORITY="$HOME/.Xauthority"
    fi
    export DISPLAY
    [ -n "${XAUTHORITY:-}" ] && export XAUTHORITY

    if [ ! -S "$XDG_RUNTIME_DIR/${WAYLAND_DISPLAY:-__none__}" ] && [ -z "${DISPLAY:-}" ]; then
        return 1
    fi
    return 0
}

# has_session_desktop -- true si hay indicios de una sesion grafica activa (Wayland o X11) donde
# despachar. NO garantiza que haya un USUARIO viendola (analogo a "quser ve consola" en Windows no
# existe un check tan limpio en Linux) -- es un chequeo de "hay un compositor corriendo", no de
# presencia humana.
has_session_desktop() {
    [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && return 0
    [ -n "${DISPLAY:-}" ] && command -v xdotool >/dev/null 2>&1 && xdotool getactivewindow >/dev/null 2>&1 && return 0
    [ -n "${DISPLAY:-}" ] && command -v xset >/dev/null 2>&1 && xset q >/dev/null 2>&1 && return 0
    return 1
}
