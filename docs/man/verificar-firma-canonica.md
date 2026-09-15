# verificar-firma-canonica

**Sinopsis:** `bash brain/verificar-firma-canonica.sh [RUTA_DEL_CEREBRO] [--strict]`

## Qué hace
Verifica la firma canónica del cerebro: comprueba que la estructura (hooks, manifiesto, cableado) no haya derivado (drift). Emite FAIL (estructural) y WARN (drift). Sirve como GATE con `--strict`.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `[RUTA_DEL_CEREBRO]` | (posicional, opcional) Ruta del cerebro a verificar. Si falta, usa el toplevel git del cwd. |
| `--strict` | `exit 1` también si hay WARN (drift), no solo FAIL (estructural). Para el GATE. |
| `-h`, `--help` | Muestra la ayuda (líneas 2-30 del script) y sale. |

## Ejemplos
```bash
bash brain/verificar-firma-canonica.sh
bash brain/verificar-firma-canonica.sh ~/code/cortex --strict
```

## Notas
- Exit codes: `0` = sin FAIL (sin WARN en `--strict`); `1` = hay FAIL (o WARN en `--strict`); `2` = error de uso.
