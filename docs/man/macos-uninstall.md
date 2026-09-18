# macos-uninstall

**Sinopsis:** `./macos/uninstall.sh [--purge] [--no-brain]`

## Qué hace
Desinstala cortex de macOS: detiene y elimina el .app de la barra, los LaunchAgents (daemon + autoarranque del widget), el fetch script, y —por defecto— el brain de Claude-Code (hooks, governance, norms). También barre restos de la era intermedia `claude-brain`. Idempotente.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `--purge` | Además elimina `~/.config/cortex` y `~/Library/Caches/cortex` (y los equivalentes de `claude-brain`). |
| `--no-brain` | Solo elimina el .app/daemon; deja el brain de Claude-Code instalado. |

Cualquier otro argumento → `unknown arg: <arg>` y `exit 2`.

## Ejemplos
```bash
./macos/uninstall.sh
./macos/uninstall.sh --purge
./macos/uninstall.sh --no-brain
```

## Notas
- Por defecto **conserva** `~/.config/cortex/limits.env`; solo `--purge` lo borra.
- Efectos irreversibles: elimina `~/Applications/Cortex Widget.app`, `~/.local/bin/cortex-fetch`, los plists de LaunchAgents, y (con `--purge`) config + cache.
- Llama a `../brain/uninstall-brain.sh` si existe (a menos que `--no-brain`).
