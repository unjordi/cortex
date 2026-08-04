# Auditoría DUPLA (+FMEA) del cerebro — pre-release `develop→main` · 2026-08-03

Corrida de la DUPLA (suficiencia operativa + coherencia) sobre **`origin/develop @ 0fd88c5`** (el estado a releasear),
gate del release #24. Fan-out read-only de 4 auditores; dictámenes completos en el scratchpad de la sesión
(`dupla-brain-0fd88c5/AUDITOR-*.md`). Este doc es el record durable + el rastro de qué se aceptó.

## Veredicto global
**0 CRÍTICO.** Suite `test-brain.sh` = **453 PASS / 0 FAIL** (507 con jueces-Haiku LIVE). El grueso del sistema
RESISTE (charts 03/04/05 vs código, README↔MANIFEST, desinfle #245, tiers, instalador↔MANIFEST). Los hallazgos
ALTO/MEDIO de doc se **arreglaron en este PR**; los MEDIO que tocan guards de supervisión se **PARQUEAN** (exigen
OK explícito de unjordi por integridad de guardarraíles) y están **backstopeados server-side**.

| Dim | Auditor | Veredicto |
|---|---|---|
| Suficiencia operativa | — | OPERABLE · 0C·1A·0M·2B |
| A · git-guards (FMEA, por ejecución) | — | 0C·0A·3M·0B — resiste; los 3 con backstop server-side |
| B · instalador/wiring/cobertura | — | 0C·0A·0M·1B · CONVERGIÓ · 453 PASS |
| C · fidelidad flowcharts+doc | — | 0C·1A·1M·2B |

## ARREGLADO en este PR (fix/dupla-hallazgos-doc)
- **[ALTO] Chart 03 `CMD_OK` describía el regex-soup JUBILADO** (A3/A4) en vez del juez-Haiku de #242, y omitía la
  ruta `UNAVAILABLE→DENY`. Reescrito el nodo + añadida la ruta deny en `CMDG_D`; SVG regenerado.
- **[MEDIO] `exportar-sesion-master` faltaba** en el árbol de `CLAUDE.md` y en 4/5 leyendas (nació stale post-#241).
  Re-inyectadas las leyendas 01/03/04/05 con `gen-leyenda-arbol.sh --inject` (los 5 SVGs regenerados) + fila añadida
  a mano al árbol de `CLAUDE.md`. Ahora los 5 catálogos concuerdan con README+MANIFEST.
- **[BAJO] Conteos falsos en MEMORY.md:** batería LIVE juez-merge 24→**23** y dod 32→**33** (contados contra
  `test-brain.sh`: 23 `jlive`, 33 `djlive`).
- **[BAJO] CONVENCIONES.md** decía "los 11" flowcharts en presente (hay **5**) y citaba una lámina `00-leyenda-arbol.*`
  inexistente → corregido a 5 y quitada la referencia. (El "2/11" del blockquote es narrativa histórica fechada → se conserva.)
- **[BAJO] Fuga de `mktemp`** en `ramas-zombie.sh` (`_bz_cargar_prcache`): el temp de la señal (d) nunca se borraba.
  Añadido `trap … EXIT` que limpia SOLO el temp propio (no el inyectado por `CLAUDE_BZ_PRCACHE`); ningún caller usa trap EXIT.

## PARQUEADO — exige OK explícito de unjordi (integridad de guardarraíles) · backstopeado server-side
Los 3 son de la dim A (guards de supervisión). Cambiarlos es endurecimiento de un candado que vigila a Claude →
por norma requieren consentimiento EXPRESO para ESE control, distinto del OK a la acción que vigilan. Todos con
backstop de ramas protegidas server-side (GitHub), por eso la DUPLA converge aceptándolos como residuo.
- **[MEDIO] A-GBG-01:** `(cd repo && git push origin develop)`, `$(git push …)` y backtick evaden `git-branch-guard`
  en rama no-base — un `)`/backtick pegado a la rama rompe el ancla `(main|develop)([[:space:]]|$)`. El caso pelón SÍ se atrapa.
  *Fix propuesto:* ampliar el set de delimitadores del ancla en `analizar-comando-git.sh` (con test adversarial), pasada de precisión.
- **[MEDIO] A-CMD-01:** la protección release-a-main se degrada a nivel-develop cuando el destino del MR no resuelve
  (API caída / sin jq → destino vacío tratado como develop). Viola el invariante "el grant jamás cubre main".
  *Fix propuesto:* destino irresoluble en un merge a `main` → fail-safe al nivel MÁS estricto (pide lenguaje de release), no a develop.
- **[MEDIO/BAJO] A-CMD-02:** el grant `autorizaciones-vigentes.local.md` no tiene sello de procedencia → Claude puede
  autoescribirlo (fabricar-OK vía archivo; el vector de transcript SÍ lo resiste el juez). *Fix propuesto:* sello/HMAC o
  que el juez exija que la cita del grant exista TAMBIÉN en un turno real de usuario. Mitigación viva: la autoridad real
  es la cita del usuario, no el archivo (norma vigente).

## Residuo de cobertura (BAJO, no bloqueante) — al backlog
- **[BAJO] H3:** `verificar-arbol-sync.sh` (parity-check FASE 1) solo cubre la familia 💡 Skills; NO los hooks 🔒/🔔 ni
  las leyendas → el drift de `exportar-sesion-master` (H2) pasó CI en verde. Honestamente documentado como FASE 1.
  *Fix propuesto:* extender el check a 🔒/🔔 (README↔CLAUDE.md↔MANIFEST) + byte-igualdad de las leyendas vs `gen-leyenda-arbol.sh`.

## Convergencia
Con los fixes de doc integrados y los 3 guards + H3 parqueados-con-backstop, la DUPLA **CONVERGE**: no quedan
hallazgos CRÍTICO/ALTO/MEDIO **accionables sin decisión de unjordi**. Gate del release satisfecho salvo por lo que,
por diseño, sólo unjordi decide (endurecer sus propios guards).
