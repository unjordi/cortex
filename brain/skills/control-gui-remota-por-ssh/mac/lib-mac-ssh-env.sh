# skill control-gui-remota-por-ssh (cortex) -- lib compartida por mac-ssh-*.sh; ver ../SKILL.md
#
# mac_console_user() -- el usuario con sesion de CONSOLA activa (analogo a `quser` en Windows).
# mac_dispatch() -- corre un comando DENTRO de la sesion grafica de ESE usuario, aunque quien
# invoque este script sea otro usuario/sesion (el analogo funcional del `schtasks /IT` de Windows).
#
# EL PROBLEMA: macOS es single-seat (no hay logon-sessions aisladas como Windows), pero una sesion
# SSH SI corre fuera del "bootstrap context" de Aqua/WindowServer del usuario en la consola salvo
# que se despache explicito a esa sesion -- el mecanismo previsto es `launchctl asuser <uid> ...`.
#
# ESTADO DE VERIFICACION (2026-09-18, ver ../SKILL.md): CONFIRMADO en LOCAL -- corriendo DENTRO de
# la propia sesion de consola (mismo usuario, sin SSH de por medio), `screencapture`/`cliclick`/
# `osascript` funcionan directo, SIN necesitar `launchctl asuser` (el proceso ya hereda el
# bootstrap-context correcto porque nace dentro de esa sesion). NO SE PUDO confirmar el caso
# "SSH real, sesion de login DISTINTA" en esta pasada: hacerlo exigia agregar una llave a
# ~/.ssh/authorized_keys de la propia maquina para loopback SSH, y el guardrail de permisos de
# Claude Code bloqueo esa accion por tocar autorizacion SSH (correctamente -- es un cambio de
# seguridad, no algo que un script deba hacer solo). `mac_dispatch()` implementa `launchctl asuser`
# como esta PREVISTO que funcione (es el mecanismo documentado por Apple para este caso exacto:
# lanzar un proceso GUI-capaz desde un daemon/sesion sin GUI), pero SIN el confirmado en hardware
# real de un SSH genuino contra este Mac -- verificalo la primera vez que uses el kit contra una
# sesion SSH de verdad, y actualiza esta nota con fecha+resultado.
#
# Adaptacion respecto a linux-ssh-*/win-ssh-*: aqui NO hace falta resolver DISPLAY/WAYLAND_DISPLAY
# (no existen en macOS) -- el equivalente es simplemente "logueado en consola o no" + el permiso TCC
# (ver GOTCHA de Accesibilidad/Grabacion de pantalla en mac-ssh-screenshot.sh).

mac_console_user() {
    stat -f%Su /dev/console 2>/dev/null
}

# mac_display_count() -- cuantas pantallas fisicas hay conectadas (para el default "veo TODO" de
# mac-ssh-screenshot.sh, paridad con el VirtualScreen completo de win-ssh-screenshot.ps1).
# Via `system_profiler SPDisplaysDataType` -- NO depende del permiso TCC de Accesibilidad/Grabacion
# de pantalla (a diferencia de contar "desktops" por System Events), asi que funciona aunque esos
# permisos aun no esten concedidos. VERIFICADO 2026-09-18 en esta Mac: 3 pantallas reales (Retina
# integrada + 2 externas), ~0.3s de latencia -- rapido, no hace falta cachear.
mac_display_count() {
    local n
    n=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c "Resolution:")
    { [ -z "$n" ] || [ "$n" -lt 1 ]; } 2>/dev/null && n=1
    echo "$n"
}

# mac_dispatch <comando...> -- ejecuta el comando en el contexto grafico del usuario de consola.
# Si YA estas corriendo como ese usuario Y con bootstrap-context de sesion (caso local confirmado),
# ejecuta DIRECTO (mas rapido, sin capas). Si no, usa `launchctl asuser`.
mac_dispatch() {
    local cu; cu="$(mac_console_user)"
    if [ -z "$cu" ] || [ "$cu" = "root" ]; then
        echo "SIN sesion de consola activa -> no hay escritorio que manejar" >&2
        return 1
    fi
    if [ "$(whoami)" = "$cu" ] && [ -n "${SSH_TTY:-}${TERM_PROGRAM:-}" ] && [ -z "${SSH_CONNECTION:-}" ]; then
        "$@"
    else
        local uid; uid=$(id -u "$cu")
        if [ "$(whoami)" = "$cu" ]; then
            launchctl asuser "$uid" "$@"
        else
            launchctl asuser "$uid" sudo -u "$cu" "$@"
        fi
    fi
}
