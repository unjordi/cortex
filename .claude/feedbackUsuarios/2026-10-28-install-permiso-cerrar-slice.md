# install-brain / sincronizar-cerebro deben instalar el permiso de cerrar-slice

**De:** claudio-master · 2026-10-28 · pedido de unjordi: «actualiza el settings.json plz y pon en el backlog de
cortex que se arregle desde el install o la sincronización» · prioridad por fricción: ALTA (merges frenados)

## Qué pasa
El clasificador de auto mode de Claude Code (externo, de Anthropic) frena merges hechos con
`cerrar-slice.sh` aunque exista un grant vigente («[Merge Without Review]», visto el 2026-10-28 en
pisa_infraestructuradigital !21): ese filtro no lee `autorizaciones-vigentes*.local.md`, solo la conversación.
Resultado: unjordi tiene que autorizar merge por merge aunque ya dio el permiso permanente.

## Arreglo aplicado A MANO hoy (Mac y cachy, respaldo `settings.json.bak-<ts>`)
`permissions.allow` en `~/.claude/settings.json`:
- `Bash(bash ~/.claude/skills/cerrar-slice/cerrar-slice.sh:*)`
- `Bash(bash <HOME absoluto>/.claude/skills/cerrar-slice/cerrar-slice.sh:*)`
Los controles propios siguen corriendo (merge-develop-guard: squash, grant/OK, nunca main con grant; cerrar-slice:
traza Rama:/MR:, sin --auto).

## Pedido
Que `install-brain` (y `sincronizar-cerebro` si aplica) agreguen esas dos reglas de forma idempotente (merge
en `permissions.allow` sin pisar las del usuario), con la ruta absoluta del HOME de cada máquina.

## Anexo 2026-10-28 — `cerrar-slice --abrir` en GitLab sigue fallando (después de #482)
Desde el cwd de plantilladotnet: `cerrar-slice.sh --abrir --branch docs/diagramado-hallazgos --repo
mx_pind_devops/potencia/pisa_infraestructuradigital` → `glab` imprime solo «ERROR … Exit status 1» y no crea el MR.
El mismo `glab mr create` a mano (título y descripción cortos, desde el clon de pisa) SÍ lo creó (!22). Sospecha
[INFER]: la descripción que toma del cuerpo del commit (trae líneas `Co-Authored-By:`/`Claude-Session:`) o el
`git fetch origin <rama>` previo. Reproducir con `--dry-run` y correr el comando impreso.

## Anexo 2026-10-28 (3) — `cerrar-slice --wait-ci` en GitLab terminó en «Will auto-merge»
pisa_infraestructuradigital !28: `cerrar-slice.sh --id 28 --forge glab --wait-ci` imprimió «✓ Will auto-merge» (glab
dejó el merge encolado en vez de hacerlo inmediato); se mergeó segundos después. Sospecha [INFER]: el
`glab ci run -b <rama>` previo dejó un pipeline nuevo corriendo y `--wait-ci` vio verde uno anterior, o glab arma
MWPS cuando hay pipeline en curso. Contraviene la norma de merge INMEDIATO (sin MWPS).
