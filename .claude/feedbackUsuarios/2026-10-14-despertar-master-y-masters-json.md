# /despertar-master y masters.json — encargo de Jordi vía claudio-master (2026-10-14)

## Lo que pidió Jordi (textual)
- "tal vez sería buena idea armar un skill de /despertar-master que directamente revise el masters.json"
- "ese masters.json está bien chafa"
- "creo que los masters deberían manterlo directamente en vez de que sea automático..."
- "mejor despierta al cortex master y que él lo haga plz"

## masters.json hoy (medido en la Mac, ~/claude-sessions/masters.json)
- Ids viejos: cortex-master apunta a 761c82d9; la sesión viva era d199fa8d (custom-title "cortex-master (2)").
- Targets que no son el repo: code/cortex/.cortex-wt/A1-ci-shellcheck, code/potenciaDatabases/.claude/memory, code/axon/.claude/worktrees/cpu.
- Nombres repetidos: games-master ×3, axon-master ×2. Rutas de la cachy (/run/media/...) mezcladas con las de la Mac.
- Consecuencia real hoy: al probar un borrador del script resolví cortex-master por masters.json, no lo vi vivo y LANCÉ una segunda sesión sobre 761c82d9. La bajé antes de su primer turno (sin cambios en el repo).

## Lo que sí es fuente confiable (medido)
- Cada transcript trae `{"type":"custom-title","customTitle":"<nombre>"}` (el último gana; el CLI agrega " (N)") y `"cwd"` en cada mensaje → nombre → sesión más reciente → resume desde su último cwd.
- "¿Ya está viva?": revisar procesos por cwd NO basta (las sesiones dentro de `claude daemon` tienen cwd /); la edad del transcript sí sirve.

## Gotchas para la skill
- `screen -X hardcopy` necesita `-p 0 -h` para capturar la pantalla de Claude (sin eso sale vacía y parece que no carga).
- `env -u CLAUDECODE -u CLAUDE_PID -u CLAUDE_EFFORT -u CLAUDE_AUTOCOMPACT_PCT_OVERRIDE -u CLAUDE_CODE_*`: si hereda, no guarda transcript.
- Con `set -o pipefail`, `ls -t <glob sin coincidencias> | head -1` dentro de `$(...)` tumba el script.
- arsenal-master (826 MB) tardó ~4 min en pintar.

## Borrador de claudio-master (insumo; la decisión de diseño es tuya y de Jordi)
Resuelve desde los transcripts y no lanza si el transcript se escribió hace < 15 min.
```bash
# despertar-master.sh <nombre> | --lista  (borrador, sin instalar)
VIVA_MIN=15; ESPERA=240
pantalla() { local f; f="$(mktemp)"; screen -S "$1" -p 0 -X hardcopy -h "$f" 2>/dev/null || true; LC_ALL=C sed 's/[^[:print:]]//g' "$f"; rm -f "$f"; }
titulo()   { grep -ao '"customTitle":"[^"]*"' "$1" 2>/dev/null | tail -1 | cut -d'"' -f4 | sed 's/ ([0-9]*)$//' || true; }
cwd_de()   { grep -ao '"cwd":"[^"]*"' "$1" 2>/dev/null | tail -1 | cut -d'"' -f4 || true; }
edad_min() { echo $(( ( $(date +%s) - $(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1") ) / 60 )); }
# masters: "<titulo>\t<transcript>" de las sesiones con titulo *-master*, de la mas reciente a la mas vieja
masters() { local f t; while IFS= read -r f; do t="$(titulo "$f")"; [[ "$t" == *-master* ]] && printf '%s\t%s\n' "$t" "$f"; done < <(ls -t "$HOME"/.claude/projects/*/*.jsonl 2>/dev/null || true); }
# despertar <nombre>: primera coincidencia de masters() -> ID=basename, CWD=cwd_de; si edad_min < VIVA_MIN -> "viva", no lanzar;
# si no: screen -dmS <nombre> env <-u ...> bash -lc "cd '$CWD' && claude --resume $ID --remote-control '<nombre>'";
# esperar hasta ESPERA s a 'https://claude.ai/code/session_' (devolverla) o 'trust this folder' (decir como aceptarlo).
```
