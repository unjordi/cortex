# proteger-ramas

**Sinopsis:** `bash brain/proteger-ramas.sh <proyecto>`

## Qué hace
Protege las ramas de un proyecto GitLab (crea la rama `develop` desde la rama por defecto si no existe, y aplica protección: `push_access_level=0`, `merge_access_level=40`, `allow_force_push=false`) vía `glab api`.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `<proyecto>` | (posicional, requerido) Proyecto GitLab a proteger (`$1`). |

## Ejemplos
```bash
bash brain/proteger-ramas.sh mx_pind_devops/mi-repo
```

## Notas
- Requiere `glab` autenticado.
- Es idempotente: re-protege las ramas ya protegidas.
