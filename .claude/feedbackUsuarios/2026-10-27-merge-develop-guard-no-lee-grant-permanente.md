# merge-develop-guard no reconoce un grant permanente vigente (falso negativo del fast-path)

De: games-master (Cachy, cwd `/run/media/unjordi/SteamAndFiles/GoogleDrive/Juegos`, carpeta de Drive, NO git).

## Qué pasó
2026-10-27 ~16:50. Comando:
```
gh pr merge 56 --repo unjordi/armada-rp6 --squash --delete-branch --subject "…" --body "…Rama: fix/firma-imagen-rp6 / MR/PR: #56…"
```
Freno: "el juez no encontró tu confirmación EXPRESA para integrar este MR (MR 56) a develop". Dos veces:
1. Con el grant en el canal local del juez.
2. Re-citando el grant textual en el mismo turno, antes del reintento.

## El grant (real, de Jordi, vigente)
`<cwd>/.claude/memory/autorizaciones-vigentes.local.md`:
```
scope=merge-develop vence_epoch=4102444799 — Jordi grant PERMANENTE (2026-10-01), verbatim: "deberías tener el OK permanente y completo para todos los merges a develop en TODOS los repos de armada y rp6 que toques [...] DEJA DE PEDIRMELO!!". Cubre unjordi/armada-rp6, unjordi/armada-packages-rp6, unjordi/flycast → develop. NO main …
```
Se usó en merges anteriores a `unjordi/armada-rp6` (p. ej. #52, #53).

## Hipótesis a revisar (no verificadas en el código del guard)
- El fast-path busca el archivo relativo a la raíz git del cwd. Aquí el cwd no es un repo git, así que puede que no lo encuentre.
- O el juez solo acepta una confirmación por MR y no la cita de un grant blanket.

## Qué haría falta
- El fast-path debe leer el canal local también cuando el cwd no es git (o resolverlo desde `$CLAUDE_PROJECT_DIR`).
- Debe aplicar el grant si `scope=merge-develop` está vigente y el repo `--repo` está nombrado en el grant.
- Pruebas:
  - Pasa: este caso (cwd no-git con grant vigente que nombra el repo).
  - Frena:
    - un repo que el grant no nombra;
    - un grant vencido;
    - un merge a `main`.
  - El caso que pasa debe fallar contra el guard de hoy.

Registrado también en `docs/guards-falsos-positivos.md`.

## Estado
Sin tocar el guard (no es mío). El PR #56 espera el OK puntual de Jordi.
