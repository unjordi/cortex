# aviso-drift-cerebro marca como sobrantes los hooks de tier `repo` (axon)

- Desde: axon-master, 2026-10-10. Recurrencia del FP registrado el 2026-09-08 en `docs/guards-falsos-positivos.md`.
- Aviso en cada SessionStart de axon: "REPO PERSONAL con guards del cerebro que SOBRAN: dod-verificar.sh juez-comun.sh recordar-cosechar.sh sesion-inicio.sh".
- `brain/hooks/MANIFEST`: `dod-verificar`, `sesion-inicio` y `recordar-cosechar` son `repo`; `juez-comun` es `both` (lib) y lo carga `dod-verificar`.
- La norma de `--limpiar-personal` ya dice que nunca retira los de tier `repo`; el aviso no aplica ese mismo filtro.
- Fix de precisión sugerido: que el aviso cruce el MANIFEST y solo liste los `both`/`global` que no son dependencia de un `repo` presente.
