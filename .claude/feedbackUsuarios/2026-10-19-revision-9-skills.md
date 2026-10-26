# Revisión 9 — skills con código (coordinar-claudes, reubicar-master, control-gui-remota)
Fecha: 2026-10-19 · revisor: claudio-master · rango de6df53..52d2d8c

## Resultado
- coordinar-claudes: despertar-master.sh y vigilar-master.sh son NUEVOS; leídos completos.
  - vigilar-master: en uso real todo el día (commits, turno terminado) sin fallas observadas.
  - despertar-master: `--lista` contra las sesiones reales de la Mac, y la decisión de vida (`_viva`) en 5 casos (H15).
- reubicar-master.sh y los 20 scripts de control-gui: el diff es SOLO texto (fechas quitadas de comentarios/mensajes); sin cambio de lógica (medido).
- Nota de la sección 7: reubicar-master sigue exigiendo y escribiendo masters.json; funciona porque el archivo legacy existe y reubicar lo escribe él mismo bajo lock. Sin hallazgo.

## H15 MEDIO-ALTO — despertar-master.sh `_vivo_por_senal`: no ve una sesión retomada por TÍTULO → la relanza (2º escritor sobre el transcript)
Entrada: master vivo arrancado como `claude --resume --chrome claudio-master-3000` (por título, sin id; fuera de screen), con >15 min sin escribir su transcript (p. ej. de noche, o esperando a unjordi).
Hace: `_viva` ve edad ≥ VIVA_MIN, no hay screen con ese nombre y `pgrep -f "claude.*--resume.*<id>"` no matchea (el cmdline no trae el id) → IDLE. `despertar-master.sh claudio-master-3000` lanzaría `claude --resume e13afa56…` en un screen nuevo mientras la sesión original sigue abierta: dos procesos escribiendo el mismo transcript.
Medido (funciones extraídas del script instalado = 52d2d8c): claudio-master-3000 con 20m → IDLE (proceso vivo pid 84542); databases-master (VSCodium, `--resume=<id>`) → VIVA; cortex-master (screen) → VIVA; arsenal-master 5m → VIVA, 20m → IDLE.
Debería: reconocer también `--resume <título>` / `--resume=<título>` (y `-r`), y ante duda NO relanzar. Una señal más robusta: algún proceso `claude` con cwd = el cwd del master (`lsof -a -d cwd -c claude`) o con el transcript abierto.
Reproductor: con una sesión retomada por título e inactiva >15 min, `bash despertar-master.sh <título>` (NO correrlo sobre un master real: usar `CLAUDE_PROJECTS_DIR` falso + `claude` stub en PATH), o probar `_viva 20 <título> <id>` con las funciones del script.

## H16 BAJO — el barrido de fechas dejó texto roto y "Verificado" sin fecha
- win/win-ssh-screenshot.ps1: "el ultimo test real de HW de este kit fue (screenshot default / VirtualScreen)" — frase sin el dato.
- win-ssh-screenshot.ps1 perdió la semántica de `-Window` ("substring del titulo, mismo fallback").
- SKILL.md de control-gui y los .ps1: "Verificado"/"VERIFICADO" sin fecha ya no se pueden juzgar como vigentes o rancios. Para una afirmación de verificación, la fecha es el dato, no ruido.

# 2026-10-19 — los mensajes por screen dejaron de entrar (claudio-master)
Desde ~14:32 la TUI de cortex-master no acepta lo que se le manda con `screen -X stuff/paste`: no aparece en pantalla ni llega al transcript. Se relanzó con despertar-master (2.1.304, la versión actual) y pasa igual. El canal de coordinación de coordinar-claudes depende de esto. Pendiente diagnosticar (¿cambio de Claude Code 2.1.292→2.1.304, salida sincronizada que screen no redibuja, o input ignorado?).

# Regla de procesos: fuente única y mecanismo (claudio-master, 2026-10-19)
La lección "no te mates/cuentes a ti mismo con pgrep -f/pkill -f" estaba en ≥5 lugares y se repitió igual. Ya la consolidé en las memorias globales de la Mac (fuente única: como-trabajar-con-unjordi.md; quité la copia de entorno-maquina.md; la anterior recomendaba `pgrep -af`, que en macOS incluye ancestros). En cortex quedan copias en control-gui-remota-por-ssh/SKILL.md (L236, L329) y reubicar-master/SKILL.md (L1106): que apunten a una sola. Propuesta de MECANISMO (decide tú): (1) una lib `procesos.sh` con la función de despertar-master (`_pids_master`: ps + argv[0] + patrón) que usen todos los scripts del cerebro; (2) un aviso PreToolUse/Bash ante `pkill -f`/`pgrep -f` que sugiera filtrar por ejecutable. La rama fix/despertar-mensaje (db0a17d) ya trae la función.
