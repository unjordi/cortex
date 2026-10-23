# Revisión 6 — lo destructivo (ramas-zombie, limpiar.sh + limpiar-impl-*, barrer-ramas)
Fecha: 2026-10-19 · revisor: claudio-master · rango de6df53..52d2d8c

## Resultado
- Los 6 scripts de limpieza: el diff de la épica es SOLO de comentarios. Medido: `git diff -U0` sin líneas de código cambiadas; `bash -n` OK en los 6.
- ramas-zombie: squash con fecha (e) probado en repo real; transitiva (t) y base remota (r), revisadas por lectura, sin hueco.
- Corrida real en repo desechable (/tmp, origin bare local), las dos direcciones:
  - worktrees: borra el worktree limpio de una rama squasheada; conserva el sucio con su untracked.
  - ramas: borra los zombies con su remota; conserva la rama viva, keep/x, main, develop y la retenida por worktree.
  - remota ADELANTE de la local zombie (un colega empujó tras el squash): borra la local y NO la remota; el trabajo del colega queda.
  - remotas sin local: borra la integrada (señal c); conserva la que trae trabajo.
  - residuo y flotilla en --dry-run: rc 0, sin escribir.

## H10 BAJO — limpiar-impl-ramas.sh: el resumen de "remotas sin local" no cuadra (anterior a la épica)
Entrada: una remota `origin/feat/adelante` cuya punta avanzó desde el último fetch, más una integrada y una con trabajo.
Hace: "Remotas sin local: 3 examinada(s) → 1 integrada(s), 1 con trabajo conservada(s)". La tercera (conservada por haber avanzado) no aparece en ninguna categoría del resumen; solo en la línea de detalle.
Debería: contarla y nombrarla, p. ej. "1 conservada(s) por avanzar", igual que la regla "no silent caps" (A-1) hace en la primera pasada.
Reproductor: crear zombie squasheado, clonar el bare, empujar un commit extra a esa rama desde el clon, borrar la local de otra rama ya integrada y de una con trabajo, correr `CLAUDE_INTEGRACION_BASE=develop limpiar.sh ramas --no-fetch`.

## Corpus
- FP nuevo de git-branch-guard (push a develop de un origin bare local en /tmp) appendeado a docs/guards-falsos-positivos.md; moot cuando se retire git-branch-guard.
