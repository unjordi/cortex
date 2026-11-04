# Guard propuesto: frenar `pgrep -f` / `pkill -f` que se matan a sí mismos (claudio-master, 2026-10-11)

**Síntoma recurrente** [user 2026-10-11: "no sabes cuaaaantas veces a la semana leo 'El comando pgrep -f ... se autoincluyó y mató mi propia sesión ssh'"]:
el patrón aparece en la línea de comando del propio shell (sobre todo dentro de `ssh host '...'` o `sh -c`), así que
`pkill -f PAT`, `kill $(pgrep -f PAT)` o `pgrep -f PAT | xargs kill` matan la sesión que los corre (exit 255 / 144).
La regla ya vive en `entorno-maquina.md` y en memorias del games-master; aun así se repite → una norma sin mecanismo.

**Hoy (2026-10-11), dos veces en una sesión:** `ssh cachy 'ssh root@router "for p in $(pgrep -f cake-autorate); do kill $p; done ..."'` → exit 255.

**Propuesta de mecanismo (PreToolUse/Bash):** si el comando contiene `pkill -f`, `pgrep -f` seguido de kill/xargs kill,
o `kill $(pgrep -f`, BLOQUEAR con el remedio: `pgrep -x <nombre>` · `ps w | grep "[p]atron"` · matar por PID/unidad
(`systemctl stop`, `service X stop`). Excepción: `pgrep -f` solo para listar (sin kill). Con sus tests en las dos direcciones.
