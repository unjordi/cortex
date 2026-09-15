# checkpoint-mecanico

**Sinopsis:** `node bin/checkpoint-mecanico.js [file] [--out <ruta>] [--json] [--repo-root <ruta>] [--n-msgs <N>] [--ventana <viva|todo>] [--self] [--ensure]`

## Qué hace
Extrae el 80% mecánico de un checkpoint completo a CERO tokens de modelo. Lee el transcript de una sesión de Claude Code (`.jsonl.gz`) en streaming con memoria acotada y produce un andamio con: archivos escritos (Write/Edit/NotebookEdit), escrituras vía bash (heurística), skills invocadas, comandos más frecuentes, commits verbatim, cwds/ramas vistos, compactaciones previas, tokens de contexto del último usage, y los últimos N mensajes de usuario verbatim. Por defecto opera sobre el TRAMO VIVO (desde el último `/compact`); lo histórico se cuenta aparte y se etiqueta como `tramosPrevios`.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `[file]` | (posicional, opcional) Ruta al transcript `.jsonl.gz` a procesar. Si se omite, se intenta resolver desde el contexto actual. |
| `--out <ruta>` | Ruta de salida para el andamio renderizado (`.md`). Si no se da, se imprime por stdout. |
| `--json` | Salida en JSON en vez de markdown. |
| `--repo-root <ruta>` | Ruta raíz del repo (para resolver rutas relativas de archivos escritos). |
| `--n-msgs <N>` | Número de mensajes de usuario verbatim a incluir (default: valor interno `DEFAULT_N_MSGS`). |
| `--ventana <viva\|todo>` | `viva` (default): solo el tramo desde el último `/compact`. `todo`: barrido acumulado de todo el archivo (útil para auditar, no para checkpoint). |
| `--self` | Verificación positiva de que el transcript es del hilo principal (no de un sub-agente). Avisa sin bloquear. |
| `--ensure` | (flag booleano) Comportamiento de aseguramiento (ver código). |

## Ejemplos
```bash
# Andamio markdown por stdout, tramo vivo
node bin/checkpoint-mecanico.js ~/transcripts/sesion.jsonl.gz

# Salida JSON a archivo, ventana completa
node bin/checkpoint-mecanico.js ~/transcripts/sesion.jsonl.gz --json --ventana todo --out /tmp/andamio.json

# Con repo-root y 5 mensajes de usuario
node bin/checkpoint-mecanico.js ~/transcripts/sesion.jsonl.gz --repo-root ~/code/mi-repo --n-msgs 5
```

## Notas
- Requiere `node`.
- El script NO ve: escrituras dentro de heredoc/`sed -i`/`cp`/`mv`, trabajo de sub-agentes (otros transcripts), ni el "porqué" de decisiones no tecleadas.
- Los commits se detectan solo si `git commit`/`gh pr merge`/`glab mr merge` arrancan tras un separador de shell.
- `--self` no distingue con certeza un hilo principal de un sub-agente; usa verificación por filesystem y avisa sin bloquear.
