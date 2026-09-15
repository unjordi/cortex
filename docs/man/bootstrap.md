# bootstrap

**Sinopsis:** `curl -fsSL …/bootstrap.sh | bash [-s -- <flags de install.sh>]`

## Qué hace
Instalador AUTOCONTENIDO de cortex para Linux/macOS: (1) instala los prerrequisitos que falten con el gestor del OS (brew/apt/dnf/pacman/zypper), (2) clona o actualiza el repo en `~/.cortex`, (3) corre `./install.sh` (cerebro + daemon + widget). Idempotente: re-correrlo solo actualiza.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `--no-gui` / `--no-plasmoid` | solo cerebro + daemon, sin widget (se pasa tal cual a `install.sh`) |
| `--no-brain` | salta el cerebro; solo daemon + GUI |
| `--con-term-broker` | OPT-IN, solo Linux: instala el broker de terminal (ver `install.md`) |
| *(cualquier flag de `install.sh`)* | se reenvía tal cual a `install.sh` vía `bash -s -- <flags>` |

## Ejemplos
```bash
curl -fsSL https://raw.githubusercontent.com/unjordi/cortex/main/bootstrap.sh | bash
curl -fsSL …/bootstrap.sh | bash -s -- --no-gui
```

## Notas
- Variables de entorno: `CLAUDE_BRAIN_DIR` (dónde clonar, por defecto `~/.cortex`) y `CLAUDE_BRAIN_REF` (rama a instalar, p. ej. `develop` para QA).
- En macOS exige Homebrew y las Xcode Command Line Tools (swift); no los instala para no sorprenderte.
- En Linux puede pedir `sudo` para los prereqs según el gestor de paquetes.
- Migración: reubica el clon de eras viejas (`~/.claude-brain`, `~/claude-brain`) a `~/.cortex`.
