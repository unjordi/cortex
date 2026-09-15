# migrar-term-broker

**Sinopsis:** `bash bin/migrar-term-broker.sh [--dry-run] [--revertir | --verificar] [--token-nuevo | --token-legacy]`

## Qué hace
Migra el servicio del term-broker de la unidad systemd LEGACY (`axon-term-broker.service`) a la actual (`cortex-term-broker.service`): para/deshabilita la vieja, habilita `--now` la nueva, y decide qué token conserva en `~/.config/cortex/term-broker.env` (respaldando el anterior). Sin flags, migra adoptando el token legacy. Imprime siempre un diagnóstico primero.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `--dry-run` | Solo diagnostica e imprime QUÉ haría, sin tocar nada. |
| `--revertir` | Deshace la migración: vuelve a la unidad legacy y restaura el token respaldado. |
| `--verificar` | Solo corre la verificación contra lo que está activo (no migra). |
| `--token-nuevo` | Adopta el token que generó el instalador (hay que actualizar el `.env` del cliente). |
| `--token-legacy` | Conserva el token del broker viejo (default si no se indica). |
| `-h`, `--help` | Muestra la ayuda (la cabecera del script). |
| *(sin posicionales)* | No toma argumentos posicionales. |

## Ejemplos
```bash
bash bin/migrar-term-broker.sh --dry-run          # ver qué haría, sin tocar nada
bash bin/migrar-term-broker.sh                    # migrar, conservando el token legacy
bash bin/migrar-term-broker.sh --token-nuevo      # migrar adoptando el token del instalador
bash bin/migrar-term-broker.sh --revertir         # deshacer la migración
```

## Notas
- Requiere Linux con systemd de usuario.
- El token anterior se respalda antes de sobrescribir; `--revertir` lo restaura.
