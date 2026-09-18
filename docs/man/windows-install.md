# windows-install

**Sinopsis:** `pwsh -File windows/install.ps1 [-NoAutostart] [-NoLaunch] [-NoClaudeCode] [-NoBrain] [-Build] [-ConTermBroker] [-Configuration <Release|Debug>]`

## Qué hace
Instalador ONE-STOP de Cortex para Windows: instala el brain de Claude-Code (hooks + normas, vía Git Bash), descarga el `Cortex.exe` precompilado del release `windows-latest` (o compila desde fuente con `dotnet publish` si la descarga falla o `-Build`), lo instala en `%LOCALAPPDATA%\Programs\Cortex`, registra autostart, y lanza el widget. Muestra recordatorio de login de Claude Code. Idempotente; migra/elimina restos de `ClaudeQuota` y `ClaudeBrain`.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `-NoAutostart` | No registra autostart en el registro de Windows. |
| `-NoLaunch` | Instala pero no lanza el widget (útil desde un instalador elevado). |
| `-NoClaudeCode` | No auto-instala el CLI de Claude Code. |
| `-NoBrain` | Salta el brain de Claude-Code (hooks/norms); solo daemon + widget. |
| `-Build` | Fuerza compilar desde fuente (`dotnet publish`) en vez de descargar el release. |
| `-ConTermBroker` | Se ignora en Windows (solo Linux); emite una nota y continúa. |
| `-Configuration` | `Release` (default) o `Debug`; solo relevante con `-Build`. |

## Ejemplos
```powershell
pwsh -File windows/install.ps1
pwsh -File windows/install.ps1 -NoBrain -NoAutostart
pwsh -File windows/install.ps1 -Build -Configuration Debug
```

## Notas
- Escribe en `%LOCALAPPDATA%\Programs\Cortex\`, registra autostart en `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`, y (si aplica) modifica el PATH de usuario para el CLI de Claude Code.
- Elimina de forma irreversible las instalaciones previas de `ClaudeQuota` y `ClaudeBrain` (carpetas, autostart, cache).
- Requiere PowerShell 7+ (`pwsh`). Para `-Build`, .NET SDK.
- El brain se instala vía `../brain/install-brain.ps1` (requiere Git Bash); si falla, continúa solo con el widget.
