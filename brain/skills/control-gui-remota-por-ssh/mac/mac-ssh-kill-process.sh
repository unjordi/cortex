#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit mac-ssh-*; ver ../SKILL.md
#
# mac-ssh-kill-process.sh - Mata un proceso por nombre o PID, POR SSH.
# ==================================================================================================
# NO necesita sesion de consola: corre directo en la sesion SSH (`kill`). OJO: matar un proceso de
# GUI con estado sin guardar puede perder trabajo del usuario -> usa -WhatIf primero si dudas.
# Gemelo de win-ssh-kill-process.ps1 / linux-ssh-kill-process.sh.
#
# Igual que su gemelo Linux: matchea por NOMBRE CORTO del proceso (`pgrep` SIN `-f`), nunca por
# cmdline completo -- `-f` auto-matchea cualquier proceso (incluida tu propia shell) que tenga el
# texto buscado en sus ARGUMENTOS, no solo en su nombre (gotcha ya documentado para el gemelo Linux
# y para `pkill -f` en la memoria del equipo).
#
# USO:
#   mac-ssh-kill-process.sh -Name Kate
#   mac-ssh-kill-process.sh -Id 1234
#   mac-ssh-kill-process.sh -Name Kate -WhatIf
#
# EXIT: 0 mato algo (o -WhatIf); 1 no encontro el objetivo o falto -Name/-Id.
set -u
Name=""; Id=""; WhatIf=0
while [ $# -gt 0 ]; do
    case "$1" in
        -Name) Name="$2"; shift 2 ;;
        -Id) Id="$2"; shift 2 ;;
        -WhatIf) WhatIf=1; shift ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done
[ -z "$Name" ] && [ -z "$Id" ] && { echo "Da -Name o -Id (no mato al bulto)" >&2; exit 1; }

targets=""
if [ -n "$Id" ]; then
    kill -0 "$Id" 2>/dev/null && targets="$Id"
fi
if [ -n "$Name" ]; then
    more=$(pgrep "$Name" 2>/dev/null)   # SIN -f: matchea por nombre corto, no por cmdline completo
    targets="$targets
$more"
fi
targets=$(echo "$targets" | grep -E '^[0-9]+$' | sort -u)

[ -z "$targets" ] && { echo "no hay proceso que coincida (Name='$Name' Id='$Id')" >&2; exit 1; }

for pid in $targets; do
    comm=$(ps -p "$pid" -o comm= 2>/dev/null)
    if [ "$WhatIf" -eq 1 ]; then
        echo "[WhatIf] mataria: $comm (PID $pid)"
    else
        if kill -9 "$pid" 2>/dev/null; then
            echo "MATADO: $comm (PID $pid)"
        else
            echo "FALLO matar $comm (PID $pid)"
        fi
    fi
done
exit 0
