# session-import

**Sinopsis:** `node bin/session-import.js --repo <ruta-del-proyecto> [--sessions-dir <dir-con-los-.gz>] [--force] [--force-stale] [--only <sessionId>] [--dry-run]`

## Qué hace
Siembra en ESTA máquina las sesiones que viajaron en el repo (embarcadas por `session-export.js`), para poder `claude --resume <id>` aquí tras un `git pull`. Por cada `<repo>/.claude/sessions/<id>.jsonl.gz`: descomprime el transcript, reescribe el cwd interno de cada línea a la ruta local de ESTE repo (streaming, memoria acotada), deriva el slug local, y escribe `~/.claude/projects/<slug-local>/<id>.jsonl` en modo 600. Escritura atómica (temporal + rename). Restaura el nombre legible en `~/.claude/sesiones-alias.json` sin pisar un alias local distinto. Idempotente: salta sesiones que ya existen salvo `--force`. SIN red. Salida: JSON.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `--repo <ruta>` | (requerido) Ruta del proyecto real (de donde se deriva el slug/cwd local). |
| `--sessions-dir <ruta>` | Directorio de donde se leen los `.gz` (default: `<repo>/.claude/sessions/`). Útil para apuntar al worktree de la rama de transporte. |
| `--force` | Pisa sesiones que ya existen localmente (salvo el freshness gate). |
| `--force-stale` | Implica `--force` y SALTA el freshness gate: pisa a propósito aunque la copia local sea más fresca. |
| `--only <sessionId>` | Importa SOLO la sesión con ese id (en vez de todas las del dir). |
| `--dry-run` | Simula: lista qué se importaría sin escribir nada. |

## Ejemplos
```bash
# Importar todas las sesiones del repo
node bin/session-import.js --repo ~/code/mi-repo

# Desde un worktree de transporte, solo una sesión, sin pisar
node bin/session-import.js --repo ~/code/mi-repo --sessions-dir ~/wt-sesiones/.claude/sessions --only abc123

# Forzar sobre local más fresco
node bin/session-import.js --repo ~/code/mi-repo --force-stale

# Simular
node bin/session-import.js --repo ~/code/mi-repo --dry-run
```

## Notas
- Requiere `node`.
- `--repo` es OBLIGATORIO.
- Freshness gate: con `--force` sobre una sesión existente, si la copia local es más fresca que el `.gz` entrante, NO se pisa (se salta con motivo). `--force-stale` salta este gate.
- Precedencia del título: `custom-title` del transcript > `meta.label` > alias local (que no se pisa).
- SIN red. En error: JSON `{ok:false,error}` y exit 1.
