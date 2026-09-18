# claude-session

**Sinopsis:** `claude-session export <sessionId> [--name "etiqueta"]` · `claude-session import [--force]` · `claude-session list` · `claude-session help`

## Qué hace
Hace que las SESIONES de Claude Code viajen con el repo por git, para poder `claude --resume <id>` en otra máquina. Gestiona una RAMA DE TRANSPORTE dedicada (orphan, `sesiones/<usuario>`) y un worktree gitignored. Envoltorio de `session-export.js` / `session-import.js`.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `export <sessionId>` | Embarca una sesión y la sube a la rama de transporte. |
| `--name "etiqueta"` | (con `export`) Etiqueta opcional para la sesión. |
| `import` | Baja y siembra las sesiones del repo en ESTA máquina. |
| `--force` | (con `import`) Sobrescribe sesiones existentes. |
| `list` | Lista las sesiones en la rama de transporte. |
| `help`, `-h`, `--help` | Muestra la ayuda. |

## Ejemplos
```bash
claude-session export abc123 --name "debug del broker"
claude-session import --force
claude-session list
```

## Notas
- Requiere `git`, `node`, y estar dentro de un repo git con `origin`.
- La rama de transporte es ORPHAN: no se mergea a develop.
- Override de rama: `$CLAUDE_SESSION_BRANCH`.
