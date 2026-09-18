# nuevo-repo

**Sinopsis:** `bash brain/nuevo-repo.sh <grupo/nombre> [--from dotnet|vacio|<grupo/repo>] [--dir <ruta-local>]`

## Qué hace
Crea un proyecto GitLab vacío (vía `glab api`) y lo siembra con un `git push --mirror` del repo canónico elegido con `--from`, produciendo un proyecto propio espejo del canónico.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `<grupo/nombre>` | (posicional, requerido) Nombre del proyecto a crear en GitLab. |
| `--from <val>` | Fuente canónica: `dotnet`, `vacio`, o `<grupo/repo>`. Si falta, `vacio`. |
| `--dir <ruta>` | Ruta local donde clonar el repo resultante. |

## Ejemplos
```bash
bash brain/nuevo-repo.sh mx_pind_devops/potencia/algo --from vacio
bash brain/nuevo-repo.sh mx_pind_devops/mx_megaflux_devops/x --dir ~/code/x
```

## Notas
- Requiere `glab` autenticado (crea el proyecto vía API).
- `--from` debe ser `dotnet`, `vacio` o `<grupo/repo>` (si no, `exit 2`).
- Argumento desconocido → `exit 2`.
