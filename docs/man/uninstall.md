# uninstall

**Sinopsis:** `./uninstall.sh [--keep-cfg | --no-brain]`

## Qué hace
Quita el widget de cuota de Claude Code y el cerebro compartido de Claude Code. Idempotente: re-correrlo no rompe nada. Retira también el broker de terminal si estaba instalado (sin bandera aparte: desinstalar es desinstalar).

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `--keep-cfg` | conserva `~/.config/cortex/limits.env` (por defecto se borra) |
| `--no-brain` | quita solo el widget; deja el cerebro de Claude Code instalado |

## Ejemplos
```bash
./uninstall.sh              # quita todo (widget + cerebro)
./uninstall.sh --keep-cfg   # quita todo pero conserva la config de límites
./uninstall.sh --no-brain   # solo el widget; el cerebro se queda
```

## Notas
- Efectos irreversibles: borra `~/.cache/cortex`, `~/.config/cortex` (salvo `--keep-cfg`), el fetch script, el plasmoid y las unidades systemd de usuario.
- Si el broker de terminal estaba CORRIENDO, al pararlo se cierran las terminales abiertas del widget (son sus hijas).
- NO toca la unidad legacy `axon-term-broker.service` (no es de cortex); se avisa si existe.
- Barre también restos de la era intermedia `claude-brain` (units, fetch, plasmoid, cache/config).
