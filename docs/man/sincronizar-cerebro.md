# sincronizar-cerebro

**Sinopsis:** `bash brain/sincronizar-cerebro.sh <ruta-repo-destino> [--apply] [--only a,b,c] [--prune-orphans] [--disable <hook,…>] [--limpiar-personal] [--incluir-skills]`

## Qué hace
Sincroniza el cerebro (hooks de tier `both`) desde `brain/hooks/` hacia el `.claude/` de un repo destino y lo cablea en su `settings.json`. DRY-RUN por default (muestra qué cambiaría, no escribe); con `--apply` copia y cablea. También puede deshabilitar hooks nombrados o limpiar un repo personal.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `<ruta-repo-destino>` | (posicional, requerido) Repo destino al que se sincroniza el cerebro. |
| `--apply` | Ejecuta de verdad (copia + cablea). Sin él = DRY-RUN. |
| `--only <csv>` | Restringe la sincronización a esos nombres (sin `.sh`). Acepta `--only a,b,c` o `--only=a,b,c`. |
| `--prune-orphans` | Retira (de-cablea + borra) los huérfanos: archivos en el destino que ya no están en el manifiesto. Destructivo → solo con `--apply`. |
| `--prune-only` | Solo retira huérfanos; NO sincroniza nada más (fix quirúrgico). |
| `--disable <hook,…>` | Solo deshabilita el/los hook(s) nombrado(s): de-cablea + borra. Acepta `--disable a,b` o `--disable=a,b`. |
| `--limpiar-personal` | Retira de un repo PERSONAL (sin la marca `.claude/repo-compartido`) todo lo tier `both`. DRY-RUN por default; `--apply` de-cablea + borra. Respeta `--only`. |
| `--incluir-skills` | Junto con `--limpiar-personal`: además retira las skills del brain que estén en el ledger. |

## Ejemplos
```bash
bash brain/sincronizar-cerebro.sh ~/code/mi-repo                 # DRY-RUN
bash brain/sincronizar-cerebro.sh ~/code/mi-repo --apply         # aplica
bash brain/sincronizar-cerebro.sh ~/code/mi-repo --disable git-branch-guard --apply
bash brain/sincronizar-cerebro.sh ~/code/personal --limpiar-personal --incluir-skills --apply
```

## Notas
- DRY-RUN por default: sin `--apply` solo muestra qué haría.
- `--prune-orphans` / `--disable` / `--limpiar-personal` son destructivos y solo escriben con `--apply`.
- Flag desconocido → `exit 2`.
