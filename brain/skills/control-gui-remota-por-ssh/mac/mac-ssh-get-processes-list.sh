#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit mac-ssh-*; ver ../SKILL.md
#
# mac-ssh-get-processes-list.sh - Lista procesos de la maquina, POR SSH.
# ==================================================================================================
# NO necesita sesion de consola: corre directo en la sesion SSH (`ps`). Gemelo de
# win-ssh-get-processes-list.ps1 / linux-ssh-get-processes-list.sh.
#
# ADAPTACION (verificada 2026-09-18 LOCAL): a diferencia de Linux, el `comm` de macOS suele ser la
# RUTA COMPLETA al ejecutable (`/Applications/Foo.app/Contents/MacOS/Foo`) y esa ruta PUEDE traer
# ESPACIOS (nombres de carpeta como "Application Support") -- un parseo por columnas fijas con
# `comm` primero rompe ahi (columnas se corren). Por eso este script pone PID/RSS/CPU primero
# (numericos, sin espacios) y `comm` AL FINAL (toma todo el resto de la linea), y DEJA FUERA
# `lstart` (la fecha de inicio) para no reintroducir el mismo problema de orden. Gemelo de
# win-ssh-get-processes-list.ps1 / linux-ssh-get-processes-list.sh (sin columna "Started").
#
# USO:
#   mac-ssh-get-processes-list.sh
#   mac-ssh-get-processes-list.sh -Name Kate     # filtra por nombre (substring, sobre el basename)
#   mac-ssh-get-processes-list.sh -Top 20         # top-N por RSS (default 40)
#   mac-ssh-get-processes-list.sh -Csv             # CSV: Name,Pid,RSS_MB,CPU
set -u
Name=""; Top=40; Csv=0
while [ $# -gt 0 ]; do
    case "$1" in
        -Name) Name="$2"; shift 2 ;;
        -Top) Top="$2"; shift 2 ;;
        -Csv) Csv=1; shift ;;
        *) echo "arg desconocido: $1" >&2; exit 2 ;;
    esac
done

rows=$(ps -eo pid,rss,pcpu,comm 2>/dev/null | tail -n +2 | sort -k2 -nr)
[ "$Csv" -eq 1 ] && echo "Name,Pid,RSS_MB,CPU"
count=0
while IFS= read -r line; do
    [ "$count" -ge "$Top" ] && break
    pid=$(echo "$line" | awk '{print $1}')
    rss=$(echo "$line" | awk '{print $2}')
    cpu=$(echo "$line" | awk '{print $3}')
    comm=$(echo "$line" | awk '{$1="";$2="";$3="";sub(/^ +/,"");print}')
    base="${comm##*/}"   # NO uses `basename`: algunos comm empiezan con "-" y basename los lee como flag
    if [ -n "$Name" ] && [[ "$base" != *"$Name"* ]]; then continue; fi
    rss_mb=$(awk "BEGIN{printf \"%.1f\", ${rss:-0}/1024}")
    if [ "$Csv" -eq 1 ]; then
        printf '"%s",%s,%s,%s\n' "$base" "$pid" "$rss_mb" "$cpu"
    else
        printf '%-25s %-8s %8s MB  %6s%%\n' "$base" "$pid" "$rss_mb" "$cpu"
    fi
    count=$((count+1))
done <<< "$rows"
exit 0
