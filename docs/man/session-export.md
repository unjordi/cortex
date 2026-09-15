# session-export

**Sinopsis:** `node bin/session-export.js <sessionId> --repo <ruta-raiz-del-repo> [--name "<etiqueta>"] [--force]`

## Qué hace
Embarca UNA sesión de Claude Code al repo para que viaje por git y se pueda `claude --resume` en otra máquina. Localiza el transcript `<sessionId>.jsonl` en `~/.claude/projects/<slug>/`, lo comprime (gzip, streaming, memoria acotada) a `<repo>/.claude/sessions/<sessionId>.jsonl.gz`, y escribe un sidecar `<sessionId>.meta.json` con proveniencia (cwd de origen, máquina, título, tamaños, fecha). Escritura atómica vía temporal + rename. NO toca git. Salida: JSON por stdout.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `<sessionId>` | (posicional, requerido) ID de la sesión a exportar. |
| `--repo <ruta>` | (requerido) Ruta raíz del repo destino. |
| `--name "<etiqueta>"` | Etiqueta explícita para la sesión (tiene precedencia sobre `custom-title`, alias y `ai-title`). |
| `--force` | Re-embarca aunque el `.gz` ya exista en el destino. |

## Ejemplos
```bash
# Embarcar una sesión al repo
node bin/session-export.js abc123 --repo ~/code/mi-repo

# Con etiqueta explícita y sobrescritura
node bin/session-export.js abc123 --repo ~/code/mi-repo --name "master de la mudanza" --force
```

## Notas
- Requiere `node`.
- `--repo` es OBLIGATORIO (el script falla si no se da).
- Precedencia del título: `--name` > `custom-title` (del transcript) > alias del widget > `ai-title`.
- Si el id existe en varios slugs, avisa por stderr y embarca la copia viva (última actividad).
- SIN red. En error: JSON `{ok:false,error}` y exit 1.
