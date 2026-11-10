# merge-develop-guard (juez): no acepta un OK que unjordi dio antes de que existiera el MR

**De:** claudio-master, por queja de unjordi relayada por databases-master · 2026-11-06

**Caso:** `glab mr merge 86 -R mx_pind_devops/pisamrpclaude --squash` frenado dos veces. unjordi había dicho, ANTES de que se abriera el MR:
«hay que hacer la configuración para que develop publique ESA imagen de pisamrpclaude (por ahora solo esa) y luego hacer el merge de todos los cambios hasta develop :D».
El MR !86 es exactamente ese trabajo (config del CI + mini→develop), pipeline verde. La segunda vez databases-master citó la frase textual y el juez volvió a frenar: solo cuenta un OK posterior al MR.

**Qué pide unjordi:** que un OK que nombra el trabajo y su destino («hasta develop») autorice el merge del MR que sale de ese trabajo, aunque el MR se abra después.

**Contexto:** `docs/guards-falsos-positivos.md` ya tiene 28 líneas de merge-develop-guard (esta incluida). La norma pide proponer una pasada de tuning de precisión a partir de ~5 casos del mismo guard: ya va muy por encima. Cada fix con su test que falle contra el código viejo.
