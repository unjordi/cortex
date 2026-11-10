# cortex-fetch calienta la Mac: re-escanea 3.5 GB de transcripts cada 5 min
De: claudio-master · 2026-10-30 15:35 · Mac (M4 Pro)

Medido: el LaunchAgent `io.github.unjordi.cortex` corre `~/.local/bin/cortex-fetch` con StartInterval=300.
Cada corrida recorre COMPLETO `~/.claude/projects` (3.5 GB de .jsonl) tres veces
(`grep -rcE` para MESSAGES, `grep -rhoE` timestamps para PEAK_HOUR, `grep -rhE | awk` para DAY_MSG_JSON, ~l.425-440).
La pasada de DAY_MSG_JSON sola lleva >60 s con `awk` al 100 % de un núcleo; cuando acaba, a los pocos minutos arranca la siguiente.
Se vio además una corrida anterior (pid 19981, 2+ min) aún viva mientras arrancaba otra (pid 23428): se enciman.
unjordi reportó la Mac «muy caliente».

Pide: que las estadísticas de transcripts sean incrementales (caché por archivo con mtime/tamaño, solo leer lo nuevo)
o salgan del ciclo de 5 min; y un candado para que no corran dos fetch a la vez.

**15:40 — unjordi pidió matarlo** [user: "está horrible :( mátalo"]: `launchctl bootout gui/501/io.github.unjordi.cortex` + corridas muertas.
El agente quedó DESCARGADO en la Mac (state.json ya no se refresca). Re-cargar solo con el fix: `launchctl bootstrap gui/501 ~/Library/LaunchAgents/io.github.unjordi.cortex.plist`.

**2026-11-01 — tras reiniciar la Mac volvió a cargarse** (bootout no persiste). Ahora además `launchctl disable gui/501/io.github.unjordi.cortex` (persiste entre reinicios).
Para reactivarlo con el fix: `launchctl enable gui/501/io.github.unjordi.cortex && launchctl bootstrap gui/501 ~/Library/LaunchAgents/io.github.unjordi.cortex.plist`.
