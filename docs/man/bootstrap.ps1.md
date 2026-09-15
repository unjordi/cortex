# bootstrap.ps1

**Sinopsis:** `irm https://raw.githubusercontent.com/unjordi/cortex/main/bootstrap.ps1 | iex`

## Qué hace
Instalador AUTOCONTENIDO de cortex para Windows: (1) instala con winget lo que falte (Git, .NET 10 SDK, jq, Node), (2) clona/actualiza el repo en `%LOCALAPPDATA%\cortex-repo`, (3) instala el cerebro (hooks) + el widget de bandeja. Idempotente.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| *(ninguno)* | no acepta argumentos: se corre con `irm … | iex`, que no admite parámetros. Para opciones (`-NoBrain`, `-Build…`) se invoca `windows\install.ps1` directo desde el clon. |

## Ejemplos
```powershell
irm https://raw.githubusercontent.com/unjordi/cortex/main/bootstrap.ps1 | iex
$env:CLAUDE_BRAIN_REF='develop'; irm …/develop/bootstrap.ps1 | iex
```

## Notas
- Requiere winget (App Installer de la Microsoft Store).
- Variables de entorno: `CLAUDE_BRAIN_DIR` (dónde clonar) y `CLAUDE_BRAIN_REF` (rama a instalar, p. ej. `develop` para QA).
- Pon `Set-ExecutionPolicy -Scope Process Bypass` solo para este proceso (no persiste) para poder invocar los `.ps1` hijos.
- El broker de terminal es Linux-only: por esta vía no se puede pedir ni por error.
