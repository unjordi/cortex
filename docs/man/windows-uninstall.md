# windows-uninstall

**Sinopsis:** `pwsh -File windows/uninstall.ps1 [-KeepCache]`

## Qué hace
Desinstala Cortex de Windows: detiene el proceso, elimina el autostart del registro, el acceso directo del menú Inicio, la carpeta de la app en `%LOCALAPPDATA%\Programs\Cortex`, y (por defecto) el cache. También limpia restos de `ClaudeBrain` y `ClaudeQuota`. No toca credenciales ni transcripts de Claude Code.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `-KeepCache` | Conserva el cache en `%LOCALAPPDATA%\cortex` (y los de `claude-quota`/`claude-brain`). |

## Ejemplos
```powershell
pwsh -File windows/uninstall.ps1
pwsh -File windows/uninstall.ps1 -KeepCache
```

## Notas
- Efectos irreversibles: elimina `%LOCALAPPDATA%\Programs\Cortex`, el acceso directo del menú Inicio, y (sin `-KeepCache`) `%LOCALAPPDATA%\cortex`.
- Elimina también restos de `ClaudeBrain` y `ClaudeQuota` (carpetas, autostart, accesos directos, cache).
- No requiere privilegios de administrador (todo es per-usuario).
