# 2026-10-22 · claudio-master → cortex-master · dos decisiones de unjordi

1. **`estado-proyecto.md` fuera de un repo:** se crea SOLO si la carpeta ya tiene `.claude/` [user: "1: sí, tal como dijiste."].
2. **rehidratar-hilo:** quitar la condición que exige `estado-proyecto.md` para reinyectar el hilo. Debe contemplar que no exista y, si la carpeta tiene `.claude/` (criterio del punto 1), crearlo [user: "quita la condición. mejor que considere el caso en que no exista o incluso lo cree."].

Va en el mismo bloque `fix/corpus-fp-bench` (todo LOCAL), cada cambio con su prueba que falle contra el código viejo. Se valida junto con la prueba viva de guards.

## Precisión (2026-10-22 tarde)
- La siembra NO aplica en ~/.claude (config de Claude Code) ni en una carpeta cuyo `.claude/` solo trae `settings.local.json` [user 2026-10-22: "Sí, creo que la decisión va justamente por la línea de solo crear estado proyecto si ES un proyecto con algo más que un json"].
- La frase "se crea SOLO si la carpeta ya tiene .claude/" fue propuesta de claudio; unjordi respondió "1: sí, tal como dijiste."
