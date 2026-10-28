# merge-develop-guard frena en vivo con el grant vigente (axon-master, 2026-10-15)

- Repo: axon. Grant: `scope=merge-develop-BLANKET vence_epoch=1822924800` en `axon/.claude/memory/autorizaciones-vigentes.local.md`.
- `gh pr merge 491 --repo unjordi/axon --squash --delete-branch --subject … --body …` frenó 4 veces con "el juez no encontró tu confirmación EXPRESA". Los PRs #488, #489 y #490 de la misma sesión, con el mismo formato de comando, pasaron.
- El mismo hook corrido a mano (stdin con el mismo comando, cwd `/home/unjordi/code/axon` y el transcript real de la sesión) sale por el fast-path del grant (`_salir_ok`, exit 0). La caché `/tmp/acg-mrdest-unjordi_axon_gh_491` dice `develop / API`.
- No encontré la diferencia entre la corrida en vivo y la manual. El hook global está marcado como "editado en vivo" (más nuevo que la fuente en `~/.cortex/brain/hooks`).
- Registrado también en `docs/guards-falsos-positivos.md`.

## Análisis de claudio-master (2026-10-15, medido en la cachy)
Copiado del clon de cortex de la cachy (untracked, no viaja por git).

**Mecanismo, confirmado:**
1. El fast-path del grant (`merge-develop-guard.sh`, bloque "Grant DURABLE") solo se honra con `destino` CONFIRMADO `develop`. Si `acg_destino` no resuelve, cae al juez, y el juez no encuentra un OK en el transcript → DENY "no encontró tu confirmación EXPRESA".
2. En la cachy corre la lib `analizar-comando-git.sh` del **22-sep**, con `acg__cache_confiable` en orden BSD primero (`stat -f … || stat -c …`, líneas 518-520). Medido: `acg__cache_confiable /tmp/acg-mrdest-unjordi_axon_gh_491` → RECHAZADA, aunque el archivo dice `develop API`. **En Linux nunca se usa la caché**: cada merge depende de un `gh pr view` en vivo con `ACG_MR_TIMEOUT=6`. Es el bug que arregló #464 (de6df53) en develop, que NO ha llegado a la cachy (falta release + update por el widget).
3. La caché del #491 se escribió a las 10:19:39 CST, **después** de los 3 primeros intentos en vivo (10:18:25, 10:18:39, 10:19:16). La escribió la corrida manual de axon-master. O sea: en vivo, `gh pr view` falló o pasó del timeout. El intento de las 10:38:49 tampoco pudo usar la caché (punto 2).
4. Hoy `gh pr view 491` tarda 0.5–0.7 s (medido 3 veces + una con entorno limpio). No encontré en el journal un bloqueo del llavero ni un corte de red en 10:10–10:42. **La causa de la falla puntual de gh NO está probada.** Hipótesis mía [INFER]: llavero (token de gh en keyring/kwallet) o la red, de forma pasajera.

**Lo que hay que arreglar (precisión, no aflojar):**
- **A)** Desplegar #464 a la cachy (release + widget) para que la caché funcione en Linux y una falla pasajera de gh no tumbe el merge.
- **B)** Mensaje: con grant vigente y destino SIN resolver, el DENY debe nombrar la causa real ("no pude confirmar el destino del PR: gh falló o pasó de 6 s; reintenta"), no "falta tu confirmación EXPRESA", que culpa al usuario de algo que sí dio. El fail-safe (no honrar el grant con destino desconocido) se queda.
- **C)** El hook de la cachy está "editado en vivo" (parche sync-upstream del 3-oct). Ya lo portaste en `fix/afinado-guards-2026-10` (7e3eedd); al desplegar, verificar que la cachy queda igual a la fuente.
