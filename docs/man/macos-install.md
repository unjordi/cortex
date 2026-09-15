# macos-install

**Sinopsis:** `./macos/install.sh [--no-app | --no-gui] [--no-brain] [--no-ccusage] [--no-claude-code] [--build]`

## Qué hace
Instalador MASTER de cortex para macOS (usuario actual): instala el brain de Claude-Code (hooks, governance, norms), el daemon de cuota (`cortex-fetch` + LaunchAgent) y, por defecto, el .app de la barra de menús. Por defecto descarga el .app PRECOMPILADO del release `macos-latest`; si falla o el asset queda rancio respecto al HEAD del clon (y hay Xcode CLT), compila desde fuente. Idempotente. Antes de instalar, elimina cualquier instalación previa de las eras `claude-quota` y `claude-brain` (LaunchAgents, app, cache, config) para no dejar dobles daemons/widgets.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `--no-app` | Solo brain + fetch + LaunchAgent (headless); no instala el .app de la barra. |
| `--no-gui` | Alias de `--no-app`. |
| `--no-brain` | Salta el brain de Claude-Code (hooks/norms); solo daemon + app. |
| `--no-ccusage` | No hace `npm install ccusage`; usa `npx` en runtime. |
| `--no-claude-code` | No auto-instala el CLI de Claude Code (el widget lo mide). |
| `--build` | Compila el .app desde fuente (requiere Xcode CLT) en vez de bajar el precompilado. |
| `--con-term-broker` | Se ignora en macOS (solo Linux); emite una nota y continúa. |

Cualquier otro argumento → `unknown arg: <arg>` y `exit 2`.

## Ejemplos
```bash
./macos/install.sh
./macos/install.sh --no-app --no-brain
./macos/install.sh --build
```

## Notas
- Escribe en: `~/.local/bin/cortex-fetch`, `~/Library/LaunchAgents/io.github.unjordi.cortex.plist`, `~/.config/cortex/limits.env`, `~/Applications/Cortex Widget.app`, `~/Library/Caches/cortex/state.json`.
- Elimina de forma irreversible las instalaciones previas de `claude-quota` y `claude-brain` (LaunchAgents, app, cache, config) — no migra, instala limpio.
- Requiere `launchctl`, `osascript`, `pkill` (macOS estándar). Para `--build` o el fallback de compilación, Xcode Command Line Tools.
- El widget se auto-arranca vía LaunchAgent `io.github.unjordi.cortex.widget` con `RunAtLoad`.
