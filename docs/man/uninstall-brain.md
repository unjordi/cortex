# uninstall-brain

**Sinopsis:** `bash brain/uninstall-brain.sh`

## Qué hace
Retira el cerebro global de Claude Code (inverso de `install-brain.sh`): des-cablea y borra los hooks de tier {global, both} (derivados de `brain/hooks/MANIFEST`) de `~/.claude/hooks/` y limpia su cableado en `settings.json`. Conserva el dashboard y la memoria global.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| *(ninguno)* | No acepta argumentos. La lista de hooks a retirar se deriva de `brain/hooks/MANIFEST` (tier global/both). |

## Ejemplos
```bash
bash brain/uninstall-brain.sh
```

## Notas
- Requiere `jq` para des-cablear `settings.json` con seguridad (usa un patrón de los hooks del manifiesto).
- No borra el dashboard ni la memoria global (solo el cableado + los `.sh` de hooks globales).
