# session-move

**Sinopsis:** `node bin/session-move.js <sessionId> --to-cwd <ruta-real-del-proyecto-destino> [--keep-cwd] [--git-branch <rama>] [--allow-missing-cwd]`

## Qué hace
Mueve UNA sesión de Claude Code de un slug de proyecto a otro, de forma SEGURA y REVERSIBLE. Mueve el transcript (`.jsonl`) al dir del slug destino, reescribe el `cwd` interno de cada línea al cwd destino (salvo `--keep-cwd`), mueve el sidecar (`subagents/`, `tool-results/`, `workflows/`) con verificación por cardinalidad, y respalda el original en `~/.claude/session-move-backups/` antes de tocar nada. Escritura atómica (temporal + rename, verificación de nº de renglones). Todo en streaming (memoria acotada). Idempotente: si el destino ya tiene esa sesión, ABORTA sin tocar. SIN red. Salida: JSON.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `<sessionId>` | (posicional, requerido) ID de la sesión a mover. |
| `--to-cwd <ruta>` | (requerido) Ruta real del proyecto destino. El slug destino se deriva del cwd normalizado (igual que Claude Code). El destino debe EXISTIR salvo `--allow-missing-cwd`. |
| `--keep-cwd` | No reescribe el `cwd` interno del transcript (lo deja como estaba). |
| `--git-branch <rama>` | Normaliza SOLO el `gitBranch` del último evento con `cwd` (el par que el harness hereda al reanudar). |
| `--allow-missing-cwd` | Permite que el cwd destino no exista en el filesystem (a propósito). |

## Ejemplos
```bash
# Mover una sesión al proyecto ~/code/otro-repo
node bin/session-move.js abc123 --to-cwd ~/code/otro-repo

# Sin reescribir el cwd interno, fijando la rama
node bin/session-move.js abc123 --to-cwd ~/code/otro-repo --keep-cwd --git-branch feature/x

# Destino que aún no existe en disco
node bin/session-move.js abc123 --to-cwd ~/code/nuevo-proyecto --allow-missing-cwd
```

## Notas
- Requiere `node`.
- `--to-cwd` es OBLIGATORIO.
- El sidecar (subagents, tool-results, workflows) viaja con el transcript; si no existe, es un no-op verificado.
- El `gitBranch` histórico NO se toca (falsificaría el registro); solo el del último evento con `cwd` si se da `--git-branch`.
- Respaldos en `~/.claude/session-move-backups/` (poda: conserva los 10 más recientes, configurable con `CLAUDE_SESSION_MOVE_BACKUPS_KEEP`).
- Si el id existe en >1 slug de origen, `findSession` elige la copia viva y avisa.
- SIN red. En error: JSON `{ok:false,error}` y exit 1.
