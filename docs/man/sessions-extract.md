# sessions-extract

**Sinopsis:** `node bin/sessions-extract.js`

## Qué hace
Lista las sesiones de Claude Code por proyecto, para el dropdown "resumir sesión" del tab Proyectos. Lee `~/.claude/projects/<slug>/*.jsonl` (o `CLAUDE_CONFIG_DIR` si está definida). Para cada sesión extrae: `id`, `project`, `cwd`, `slug`, `updated_at`, `label` (alias del widget o primer mensaje de usuario con sustancia, 80 chars), y `summary` (primeros mensajes con sustancia concatenados, ≤320 chars). Máximo 12 sesiones por proyecto (tope `PER_PROJECT`). Ordenado por más reciente. SIN red. Salida: JSON array por stdout.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| *(ninguno)* | No acepta argumentos ni flags. |

## Ejemplos
```bash
node bin/sessions-extract.js
```

## Notas
- Requiere `node`.
- Respeta `CLAUDE_CONFIG_DIR` si está definida (en vez de `~/.claude`).
- Alias de etiquetas: lee `~/.claude/sesiones-alias.json` (lo escribe el widget al renombrar). El alias gana sobre la etiqueta derivada del transcript.
- Saluda/marcadores de sistema se filtran al derivar `label`/`summary`.
- SIN red.
