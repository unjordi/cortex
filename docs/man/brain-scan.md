# brain-scan

**Sinopsis:** `brain-scan.sh {scan | heal}`

## Qué hace
Helper interno del plasmoid KDE "Cortex Widget" (pestaña Cerebro). `scan` emite JSON con el estado real de `~/.claude`: hooks presentes (`hooks/*.sh`), hooks cableados (referenciados en `settings.json`), si hay normas (`CLAUDE.md` con marcador de inyección), skills (subcarpetas con `SKILL.md`), y versión instalada (`.brain-version`). `heal` corre `install-brain.sh` (self-healing, idempotente) buscando el script en rutas conocidas.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `scan` | (default) Emite JSON del estado del cerebro global en `~/.claude`. |
| `heal` | Corre `install-brain.sh` para reparar/reinstalar el brain. |

Sin subcomando → `scan` (default). Subcomando desconocido → `uso: brain-scan.sh {scan|heal}` a stderr, `exit 2`.

## Ejemplos
```bash
brain-scan.sh scan
brain-scan.sh heal
```

## Notas
- **Helper interno del widget**: lo invoca el DataSource "executable" de Plasma, no el usuario directamente.
- `scan` es solo lectura y fail-safe: si algo falta, esa pieza sale ausente en el JSON.
- `heal` busca `install-brain.sh` en: plasmoid instalado, relativo al repo, clones habituales (`~/code/cortex/`, `~/.cortex/`, etc.), y fallback a `$PATH` (`cortex-install` o `install-brain.sh`).
- Requiere `jq` en el PATH (enriquecido con `/opt/homebrew/bin`, `/usr/local/bin`).
