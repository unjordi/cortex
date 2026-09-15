# install

**Sinopsis:** `./install.sh [--reinstall | --no-plasmoid | --no-gui | --no-brain | --no-claude-code | --no-reload-shell | --con-term-broker | -h|--help]`

## Qué hace
Instalador MAESTRO de cortex: pone el cerebro compartido de Claude Code (hooks globales, gobernanza de costo de delegación, skill, normas) y el daemon de cuota + widget de escritorio opcional. Idempotente: se puede re-correr sin efectos duplicados.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `--reinstall` | desinstala el plasmoid primero y luego lo reinstala |
| `--no-plasmoid` | instala solo cerebro + fetch script + timer systemd (sin GUI) |
| `--no-gui` | alias de `--no-plasmoid` (salta el widget de escritorio) |
| `--no-brain` | salta el cerebro de Claude Code (hooks/normas); solo daemon + GUI |
| `--no-claude-code` | salta la auto-instalación del CLI de Claude Code (el widget lo mide) |
| `--no-reload-shell` | no reinicia plasmashell al final (por defecto sí lo reinicia para cargar cambios) |
| `--con-term-broker` | OPT-IN, solo Linux: instala el broker de terminal (servicio que sirve un shell de esta máquina por socket unix y 127.0.0.1:8799, autenticado con un token que el instalador genera). OFF por defecto |
| `-h`, `--help` | imprime el usage y sale |

## Ejemplos
```bash
./install.sh                       # instalación completa (cerebro + fetch + systemd + plasmoid)
./install.sh --no-gui              # solo cerebro + daemon, sin widget
./install.sh --con-term-broker     # + broker de terminal (Linux)
```

## Notas
- Requiere `systemctl` y `kpackagetool6` (KDE/Plasma) para el widget; en macOS usa `macos/install.sh`.
- Escribe en `~/.local/bin/cortex-fetch`, `~/.config/systemd/user/`, `~/.config/cortex/limits.env` y `~/.claude` (cerebro).
- `--con-term-broker` es solo Linux (usa `script` de util-linux, el login shell y systemd --user); en macOS/Windows aborta ruidoso.
- Al terminar sugiere hacer `claude` → `/login` para que el widget lea la cuota real.
