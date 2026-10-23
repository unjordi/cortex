# 2026-10-22 · claudio-master → cortex-master · el barrido conserva como "vivas" ramas ya integradas

Medido 2026-10-22 en ~/code/cortex: `limpiar.sh worktrees` deja 28 worktrees "DEJADO (vivo)" y `limpiar.sh ramas`
retiene 33 ramas "por worktree". Los barridos automáticos de 10-14, 10-19 y 10-21 dieron lo mismo (logs en
~/.claude/memory/.barrer-ramas/*.worktrees.log). 19 de esas ramas tienen el 100% de su contenido en develop.

Causa (verificada):
- Esas ramas entraron a develop DENTRO de otra rama: integracion/cortex-2026-09-17 (#435) o epic/afinado-2026-10
  (#465/#466), con squash. Ninguna tiene PR propio (gh pr list: ninguno), la línea `Rama:` del squash nombra a la
  rama contenedora, no es ancestro de develop, y `git cherry` no encuentra equivalente. Ninguna de las cuatro
  señales del barrido aplica → la clasifica "viva".
- Una rama retenida por worktree no la evalúa `limpiar.sh ramas` → el worktree vivo arrastra a la rama.
- "DEJADO (vivo)" solo se anota en la bitácora; nada lo escala.

Lo que lo resolvería: una señal más, por CONTENIDO — `git merge-tree --write-tree develop <rama>` da el mismo
árbol que develop (aplica limpio sin aportar nada), o las líneas añadidas por la rama están presentes en algún
commit first-parent de develop desde su merge-base. Con esa señal se detectaron las 19 (script de medición:
junto a esta nota: 2026-10-22-presencia.py). Cada fix con su prueba que falle contra el viejo.

Bug aparte: `limpiar.sh worktrees --dry-run` cuenta los 5 SUCIOS como "5 zombie(s)"; el modo real los cuenta como
"5 sucio(s) conservado(s)". El dry-run debe dar el mismo resumen que el real.

## Causa raíz (precisada 2026-10-22, tras la observación de unjordi)
La convención SÍ existe: el squash de una rama contenedora debe llevar un `Rama: <x>` por CADA rama que integró.
El lector la cumple (ramas-zombie.sh:20,299 busca la línea exacta, cualquier número de ellas). El ESCRITOR no:
cerrar-slice.sh:150-157 solo agrega el `Rama:` de la rama fuente. Evidencia: a3e188a (#435) trae 2 `Rama:`
(heredados de cuerpos pegados), d420b1f y 52d2d8c solo la contenedora; ninguna de las 19 aparece.
Fix principal: cerrar-slice.sh agrega un `Rama: <x>` por cada rama (local o remota) cuyo tip es ancestro de la
fuente y no de la base. Prueba: integrar una rama con 2 sub-ramas → el mensaje trae las 3 y ramas-zombie las
barre; contra el código viejo solo trae la contenedora. La señal por contenido queda como red para lo ya mergeado.
