# sembrar-mini-develop

**Sinopsis:** `bash brain/sembrar-mini-develop.sh`

## Qué hace
Siembra una rama `mini` de trabajo a partir de `develop` (o `main`/`master`) en el repo actual, y la protege en GitLab (protección de rama vía `glab api`). Falla si la rama actual es una rama base (develop/main/master).

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| *(ninguno)* | No acepta argumentos. Opera sobre el repo del cwd (`CLAUDE_PROJECT_DIR` o `git rev-parse --show-toplevel`). |

## Ejemplos
```bash
bash brain/sembrar-mini-develop.sh
```

## Notas
- Requiere estar dentro de un repo git (si no, `exit 1`).
- Requiere `glab` para la protección de rama en GitLab.
- No puede sembrar si la rama actual es develop/main/master.
