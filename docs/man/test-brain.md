# test-brain

**Sinopsis:** `bash brain/test-brain.sh`

## Qué hace
Corre los self-tests del cerebro (hooks, guards de squash, delegación, etc.) en un `$HOME` falso aislado, sin tocar nada de `~/.claude` real. Verifica el comportamiento de los hooks (git-branch-guard, merge-squash-guard, gate de delegación, etc.).

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| *(ninguno)* | No acepta argumentos. |

## Ejemplos
```bash
bash brain/test-brain.sh
```

## Notas
- Aísla `$HOME` en un fake: no modifica `~/.claude` real.
- Requiere `jq` para los tests de cableado.
