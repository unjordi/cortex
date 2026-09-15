# just

**Sinopsis:** `just <receta>`

## Qué hace
Task runner del proyecto cortex (Claude Code Quota Widget). Lista de recetas disponibles:

## Recetas
| receta | qué hace |
|---|---|
| `help` (default) | Muestra todas las recetas disponibles (`just --list`). |
| `install` | Instala todo: fetch script, systemd timer, plasmoid (`./install.sh`). |
| `install-headless` | Instala solo fetch script + systemd timer, sin plasmoid (`./install.sh --no-plasmoid`). |
| `reinstall` | Reinstala: borra el plasmoid primero, luego install completo (`./install.sh --reinstall`). |
| `uninstall-keep-cfg` | Desinstala todo, conservando `~/.config/cortex/limits.env` (`./uninstall.sh --keep-cfg`). |
| `uninstall` | Desinstala todo incluyendo config (`./uninstall.sh`). |
| `upgrade-plasmoid` | Actualiza solo el plasmoid (tras editar `main.qml`) sin tocar systemd. |
| `reload-plasmashell` | Reinicia plasmashell para recoger cambios del plasmoid. |
| `preview` | Corre el plasmoid standalone para debugging (`plasmoidviewer`). |
| `package` | Construye un `.plasmoid` distribuible (zip) en `dist/`. |
| `install-brain` | Instala SOLO el cerebro global de Claude Code (`bash brain/install-brain.sh`). |
| `uninstall-brain` | Retira SOLO el cerebro global (`bash brain/uninstall-brain.sh`). |
| `test-brain` | Corre los self-tests del cerebro (`bash brain/test-brain.sh`). |
| `lint` | Lint de scripts shell (requiere `shellcheck`). |
| `refresh` | Fuerza un ciclo de fetch ahora (vía systemd) y muestra el resultado. |
| `status` | Muestra estado del timer + últimas entradas del journal. |
| `logs` | Tail del journal del servicio de fetch. |
| `clean` | Borra artefactos de build (`dist/`). |

## Ejemplos
```bash
just install
just preview
just test-brain
```

## Notas
- Requiere `just` instalado.
- Algunas recetas requieren `kpackagetool6`, `plasmoidviewer`, `shellcheck`, `jq` según la receta.
