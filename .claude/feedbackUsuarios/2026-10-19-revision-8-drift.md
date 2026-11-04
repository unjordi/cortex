# Revisión 8 — drift (aviso-drift-cerebro, drift-cerebro-comun, verificar-cerebro, verificar-firma-canonica)
Fecha: 2026-10-19 · revisor: claudio-master · rango de6df53..52d2d8c

## Resultado
- Un solo cambio de lógica (el resto, comentarios; medido con `git diff -U0` filtrando comentarios): aviso-drift-cerebro deja de inyectar `conocimiento-propio` en la salida de SessionStart y en su lugar se auto-agrega `@.claude/memory/conocimiento-propio.local.md` a `CLAUDE.local.md` (y mete CLAUDE.local.md en `.git/info/exclude` si no está ignorado).
- Corrido con el hook instalado (= 52d2d8c) en repos desechables:
  - a) sin CLAUDE.local.md, dos corridas → lo crea con UN import (no duplica), lo excluye, `git status` limpio. OK.
  - b) H13.
  - c) H14.

## H13 BAJO-MEDIO — aviso-drift-cerebro.sh (bloque del auto-import): escribe sobre un CLAUDE.local.md TRACKEADO
Entrada: repo cuyo `CLAUDE.local.md` está versionado (no ignorado) y sin el import.
Hace: `check-ignore` da falso → agrega CLAUDE.local.md a info/exclude (sin efecto en un archivo trackeado) y le appendea `@.claude/memory/conocimiento-propio.local.md`. Resultado medido: ` M CLAUDE.local.md`, listo para colarse en un commit de un repo compartido con un puntero a un archivo personal que el colega no tiene.
Debería: si el archivo está trackeado (`git ls-files --error-unmatch CLAUDE.local.md`), no tocarlo y avisar.
Reproductor: `git init; echo id > .claude/memory/conocimiento-propio.local.md; printf '# mío\n' > CLAUDE.local.md; git add CLAUDE.local.md; git commit -m t; echo '{"source":"startup"}' | CLAUDE_PROJECT_DIR=$PWD bash ~/.claude/hooks/aviso-drift-cerebro.sh; git status --short` → debe quedar vacío.

## H14 BAJO — se perdió el soporte de `conocimiento-propio.md` (sin .local)
Antes se leía `conocimiento-propio.local.md` y, si no, `conocimiento-propio.md`. Ahora solo el `.local`. Medido: ningún repo de ~/code tiene hoy un `conocimiento-propio.md`, así que no rompe a nadie; pero el retiro es mudo. O se documenta como retirado, o se conserva el respaldo.
[INFER-mío] Mismo cambio: en la PRIMERA sesión tras instalar, el import se escribe en SessionStart, después de que Claude Code ya cargó los CLAUDE*.md → esa sesión arranca sin identidad (antes llegaba por la salida del hook). Una sola vez por repo; no lo medí.
