#!/usr/bin/env bash
# skill control-gui-remota-por-ssh (cortex) -- parte del kit linux-ssh-*; ver ../SKILL.md
#
# linux-ssh-get-processes-list.sh - Lista procesos de la maquina, POR SSH.
# ==================================================================================================
# NO necesita sesion grafica: corre directo en la sesion SSH (`ps`). Gemelo de
# win-ssh-get-processes-list.ps1.
#
# USO:
#   linux-ssh-get-processes-list.sh
#   linux-ssh-get-processes-list.sh -Name firefox     # filtra por nombre (substring)
#   linux-ssh-get-processes-list.sh -Top 20            # top-N por RSS (default 40)
#   linux-ssh-get-processes-list.sh -Csv                # CSV: Name,Pid,RSS_MB,CPU,Started
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

rows=$(ps -eo comm,pid,rss,pcpu,lstart --sort=-rss 2>/dev/null | tail -n +2)
[ "$Csv" -eq 1 ] && echo "Name,Pid,RSS_MB,CPU,Started"
count=0
while IFS= read -r line; do
    [ "$count" -ge "$Top" ] && break
    comm=$(echo "$line" | awk '{print $1}')
    if [ -n "$Name" ] && [[ "$comm" != *"$Name"* ]]; then continue; fi
    pid=$(echo "$line" | awk '{print $2}')
    rss=$(echo "$line" | awk '{print $3}')
    cpu=$(echo "$line" | awk '{print $4}')
    started=$(echo "$line" | awk '{print $5, $6, $7, $8}')
    rss_mb=$(awk "BEGIN{printf \"%.1f\", $rss/1024}")
    if [ "$Csv" -eq 1 ]; then
        printf '"%s",%s,%s,%s,"%s"\n' "$comm" "$pid" "$rss_mb" "$cpu" "$started"
    else
        printf '%-25s %-8s %8s MB  %6s%%  %s\n' "$comm" "$pid" "$rss_mb" "$cpu" "$started"
    fi
    count=$((count+1))
done <<< "$rows"
exit 0
