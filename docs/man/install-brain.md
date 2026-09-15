# install-brain

**Sinopsis:** `bash brain/install-brain.sh`

## Qué hace
Instala el CEREBRO GLOBAL compartible de Claude Code (cortex) en `~/.claude`: hooks de tier {global, both} (derivados de `brain/hooks/MANIFEST`), cableado en `settings.json` (con `"shell":"bash"`), skills genéricas, dashboard + esqueletos per-máquina en la memoria global, y normas inyectadas en `~/.claude/CLAUDE.md`. Idempotente: re-correrlo es seguro.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| *(ninguno)* | No acepta argumentos. Todo el comportamiento es fijo; las tunables se siembran en `settings.json` (bloque `.env`) vía `set_env_default` / `persist_env_active`, no por flags. |

## Ejemplos
```bash
bash brain/install-brain.sh
```

## Notas
- Requiere `jq` en el PATH: sin él los hooks (git-branch-guard, gate de delegación) fallan ABIERTO y no se puede cablear `settings.json` (avisa, no bloquea).
- Escribe en `~/.claude/` (hooks, skills, settings.json, CLAUDE.md) y en la memoria global del HOME. No toca el repo actual.
- Los hooks repo-scoped (sesion-inicio, dod-verificar) NO se instalan globales: viven en `brain/hooks/` como fuente para que cada repo los copie a su `.claude/`.
- OS-agnóstico (Mac/Linux/Windows Git Bash). Fail-safe sin jq.
