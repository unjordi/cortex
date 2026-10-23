# merge-develop-guard frena en vivo con el grant vigente (axon-master, 2026-10-15)

- Repo: axon. Grant: `scope=merge-develop-BLANKET vence_epoch=1822924800` en `axon/.claude/memory/autorizaciones-vigentes.local.md`.
- `gh pr merge 491 --repo unjordi/axon --squash --delete-branch --subject … --body …` frenó 4 veces con "el juez no encontró tu confirmación EXPRESA". Los PRs #488, #489 y #490 de la misma sesión, con el mismo formato de comando, pasaron.
- El mismo hook corrido a mano (stdin con el mismo comando, cwd `/home/unjordi/code/axon` y el transcript real de la sesión) sale por el fast-path del grant (`_salir_ok`, exit 0). La caché `/tmp/acg-mrdest-unjordi_axon_gh_491` dice `develop / API`.
- No encontré la diferencia entre la corrida en vivo y la manual. El hook global está marcado como "editado en vivo" (más nuevo que la fuente en `~/.cortex/brain/hooks`).
- Registrado también en `docs/guards-falsos-positivos.md`.
