# Auditoría COMPLETA de los 11 flowcharts del cerebro — mapa de fidelidad

> Gate pedido por unjordi ANTES de mergear #207/#208/#209/!110 y releasear a main: correr el auditor
> `auditar-proceso-algoritmo` sobre TODOS los flowcharts. Fan-out: 4 auditores individuales por clúster
> (cotejando vs el código de `origin/develop @ cb722de`) + 1 pase COLECTIVO/costura. Read-only, INSUMO no cierre.
> Fecha: 2026-07-29. Compañera de `auditoria-flowcharts.md` (14-jul) y `auditoria-flowcharts-sesion-propagacion.md` (29-jul, 01/02).

## Hallazgo sistémico (los 11)
- **Ninguno trae LEYENDA** (regla dura del skill "los zapatos"): la notación 🔴/🟢/🟠/🔒/🔔/💾/📜/rombo hay que inferirla. #208 ya la agregó a 01/02; faltan 03–11.
- **Ninguno tiene fuente `.dot` versionada** (el maestro `docs/mapa-flujos.dot` está gitignored y ya no existe; `docs/flowcharts/` entero gitignored). #208 reconstruyó fuente para 01/02; faltan 03–11.
- **Desfase de numeración** (visto en cierre): el título interno de algunos va −1 vs el nombre de archivo (⑤↔06, ⑥↔07) — confunde el cross-ref.

## Mapa de fidelidad (se llena conforme reportan los clústeres)

| # | Flowchart | Veredicto | Nota |
|---|---|---|---|
| 01 | instalación/actualización (propagación) | **REHACER** | obsoleto (audit 29-jul) → #208 lo rehízo (preview) |
| 02 | ciclo de vida de la sesión | **COMPLETAR** | faltaban 2 hooks que escriben git (audit 29-jul) → #208 (preview) |
| 03 | integrar rama a develop/main | **COMPLETAR** | ⚠ [ALTO] G1_D3 contradice el modelo mini-develop (DENY donde el código PASA) |
| 04 | comando git en bash — guards | **COMPLETAR** | ⚠ [ALTO] "los DOS hooks" = falso (son 8) + patrones de secreto stale |
| 05 | al hacer push — nudges | **COMPLETAR** | disparador de recordar-dashboard impreciso + ignora que el push puede DENY |
| 06 | declarar LISTO al fin de turno | **COMPLETAR** | fiel y NO obsoleto; ver abajo |
| 07 | cerrar un slice — ritual | **COMPLETAR** | fiel y NO obsoleto; ver abajo |
| 08 | delegar un task/agente | **COMPLETAR** | "sin snapshot" mal enrutado + etiqueta fail-open/safe contradictoria |
| 09 | orquestar fan-out sin niñera | **COMPLETAR** | ⚠ [ALTO] verificación omite chequeo de BASE/LINAJE (lección C7) |
| 10 | normas — el cimiento | **COMPLETAR** | ⚠ [ALTO] faltan 5 normas duras (esp. entorno-máquina-global, que tiene guard) |
| 11 | referencia lib/skill de stack | **COMPLETAR** (fuerte) | ⚠ [ALTO] cubre 1 de 4 libs (falta analizar-comando-git) |

---

## Clúster CIERRE (06, 07) — cotejado vs `dod-verificar.sh` + skill `cerrar-slice`
Ambos **estructuralmente fieles, NO obsoletos**. Defecto = OMISIÓN de reglas de precisión/sub-pasos, no dibujar mal. Veredicto de los dos: **COMPLETAR**.

### 06 — Declarar LISTO (vs `dod-verificar.sh`)
Acierta: orden real de decisiones (escapes→visual-B2→claim→código→marca 1/2), B2 (QA visual a ciegas) ANTES del gate de claim, detección de tool por estructura del transcript, claim-awareness de escapes.
- **[MEDIO] Omite el enmascarado P2a de PASOS MECÁNICOS** (`dod-verificar.sh:68-86`): "✅ Listo — checkpoint hecho" NO debe contar como cierre (falso positivo real, 2026-07-15). El dibujo, sin ese nodo, predice el resultado OPUESTO al real. → añadir nodo previo a D2.
- **[BAJO] D1 dice "sin (1)" pero el código usa `conf`=(1)|(2)** → "sin (1) NI (2)".
- **[BAJO] Falta premisa de RECORTE AL TURNO ACTUAL** (`:42-48`) — central a por qué el hook no truena de más.
- **[BAJO] P2b (🎉 ya no es gatillo standalone; 🏁 sí)** no representado.
- **[BAJO] Recordatorio build/tests+memoria colgado del nodo OK**, pero en el código vive en el mensaje de BLOQUEO (`:174-175`).

### 07 — Cerrar un slice (vs skill `cerrar-slice`)
Acierta: los 5 pasos en orden, decisiones destructivo/API→smoke/genérico→cosecha, persistencia de herramientas scratch, gate de merge con OK expreso.
- **[MEDIO] Paso 1 omite la sub-rama MIGRACIÓN = auditoría de PARIDAD** (SKILL `:18-20`): build verde ≠ paridad; norma dura. → rama "¿es migración? → paridad".
- **[MEDIO] Paso 2 omite refresco de `hilo-mental-actual.md` + BACKLOG-COMPLETO** (SKILL `:38-50`, la norma "ningún hallazgo se queda en el chat").
- **[BAJO] Paso 2 omite dashboard GLOBAL (`>>`) + limpieza de worktrees zombie**.
- **[BAJO] Paso 4 omite auto-merge por tamaño de equipo + ramita-libre** (gotcha `--auto-merge`≠`--auto`).
- **[BAJO] C_DESTR "sí" sin rama de OK NEGADO** (FMEA lo pediría explícito).
- **[BAJO] Desfase numeración ⑥ vs archivo 07**.

## Clúster DELEGACIÓN (08, 09) — vs hooks de delegación + `limite-gasto` + skill `orquestar-fanout` + barredores
Ambos **COMPLETAR, NO obsoletos**.

### 08 — Delegar un Task/agente (vs `delegacion-gate.sh`, `delegacion-registrar.sh`, `delegacion-comun.sh`, `limite-gasto.sh`)
Acierta: FRENO por AND (ventana≥99% Y overage sin holgura), clasificación 2 niveles, consentimiento 1×compu vs 1×workflow, coalescencia G3, `delegacion-registrar`.
- **[MEDIO] "sin snapshot" mal enrutado**: lo mete en el nodo "no hay jq" (que hace un ask no persistido, `:39`), pero sin snapshot el código degrada a `metered` (`delegacion-comun.sh:46-50`) → rama metered→ASK 1×/workflow (SÍ persiste). Semántica de persistencia OPUESTA. → sacarlo de esa arista.
- **[MEDIO] Etiqueta contradictoria** "fail-open" (arista) vs "fail-safe" (nodo): el path sin-jq PREGUNTA = fail-**safe**. → unificar.
- **[MEDIO] Rama fail-open de `limite-gasto` no dibujada** (`:16,24,25`: sin jq/snapshot/rancio → no frena). Asimetría engañosa (dibuja el fail-open del gate pero oculta el del FRENO).
- **[BAJO] Lock G3 "se toma" pero no se ve "liberar"** (`delegacion-registrar.sh:29` hace rmdir). · **[BAJO] "niegas → no corre, no persiste"** no representado. · **[BAJO]** orden gate/limite es paralelo en el harness, no secuencial.

### 09 — Orquestar fan-out (vs skill `orquestar-fanout` + `limpiar-worktrees`/`limpiar-ramas`/`ramas-zombie`)
Acierta: 2 archivos sin redundancia, aislamiento worktree, PORTA-no-rehagas, agente terminal, no-deploy-desde-worktree, iniciar EN el repo.
- **[ALTO] La verificación del orquestador omite el chequeo de BASE/LINAJE del commit** (lección C7, 2026-07-21): el worktree del Agent tool nace sobre `origin/HEAD`≈main, no la rama activa → un commit puede salir con parent equivocado. La regla dura: comprobar linaje con git ANTES de integrar + integrar por cherry-pick del delta si la base puede estar vieja. El dibujo solo verifica "existe/compila" (necesario, insuficiente). → añadir rama "verifica LINAJE".
- **[MEDIO] "cierre AUTOMÁTICO" sobrestima a `delegacion-reporte`** (`:27` solo inyecta un RECORDATORIO; no appenda ni cierra). → "cierre RECORDADO por el hook (no forzado)".
- **[MEDIO/BAJO] "¿ya mergeada?" esconde el test triple squash-robusto** (`ramas-zombie.sh:45-53`: ancestro O remota `:gone` O equivalencia de parche; conserva ante duda) y que la base es la mini-develop, no develop.
- **[BAJO]** limpieza de ramas locales zombie no aparece (probablemente pertenece a 02); recuperación del terminal 🔴 no se muestra; mensajería `[DE→PARA]` anti-inyección ausente; `delegacion-reporte` dispara para TODO Task, no solo mutantes.
- **[COSTURA BAJO] 09→⑦ solo remite por el `gate`, no por el FRENO `limite-gasto`**: si la ventana de 5h se agota a media ola, `limite-gasto` DENIEGA cada nuevo agente (deny>ask) — invisible desde 09.

## Clúster FUNDAMENTOS (10, 11) — vs `brain/norms/global-claude-md.md`, MANIFEST, skills/libs
Ambos **COMPLETAR** (11 casi REHACER). NO cometen el anti-patrón N_MEC (no falsean enforcement).

### 10 — Normas, el cimiento (vs la fuente única de normas en develop)
Fiel en lo que dibuja (las 10 normas mostradas existen; cross-refs de enforcement calzan). Problema = COMPLETITUD:
- **[ALTO] Faltan 5 normas DURAS vigentes en develop:** (1) **entorno-máquina vive GLOBAL** ← *la más grave: tiene guard propio `entorno-maquina-guard` (both) y no figura en el panel norma→mecanismo*; (2) ningún HALLAZGO se queda en el chat; (3) ninguna DECISIÓN se queda en el chat; (4) post-compact EXCAVA; (5) Paso 0 INVENTARIO.
- **[MEDIO] N_DOD sub-representa sus sub-reglas:** falta "autorización ACOTADA y no transitiva" y "QA visual NO a ciegas" (esta la hace cumplir dod-verificar B2 → hueco en el mapa norma→mecanismo).
- **[BAJO]** cross-ref `N_DOC→④` no verificable sin el `.dot` maestro. · sin leyenda.
- **[POSITIVO]** N_P0 honestamente etiquetada "sin mecanismo local · enforcement externo"; N_TPL sin falsear enforcement.

### 11 — Referencia lib/skill de stack (vs MANIFEST + skills)
Panel diminuto (2 ítems), correcto pero materialmente incompleto:
- **[ALTO] Cubre 1 de las 4 libs `kind=lib` del MANIFEST.** Faltan: **`analizar-comando-git`** (both, el cerebro compartido de los 3 git-guards — el vacío más notorio), `detectar-secretos` (both, la usa secret-scan), `ramas-zombie` (global, la usan limpiar-worktrees/ramas).
- **[MEDIO]** iconografía inconsistente sin leyenda (`⚙`/`💡` vs `🔔`/`💾`).
- **[BAJO/INFO]** la skill `auditar-proceso-algoritmo` HOY ausente es CORRECTO (no está en develop; #207 preview) → **sembrarla aquí al mergear #207**.
- **[OK]** `delegacion-comun` bien atribuida (la usan gate + registrar, no reporte).

## Clúster GIT / GUARDS (03, 04, 05) — vs los guards + lib `analizar-comando-git` + `detectar-secretos`
Todos **COMPLETAR**. El código de develop está sano (H1/H3/H5/H7/H8/H11/H13 previas ya aplicadas); los defectos son de **fidelidad del DIBUJO**. **Meta-hallazgo:** la recomendación del 14-jul de "mostrar ②③④ como el MISMO evento PreToolUse/Bash con N hooks paralelos" NO se implementó; siguen 3 dibujos que no se cruzan.

### 03 — Integrar rama a develop/main
Bien actualizado desde 14-jul (H1 push pelón, H8 rama MERGE_RE ya dibujados).
- **[ALTO] `G1_D3` contradice el modelo mini-develop:** un `glab mr merge` a rama PERSONAL (`DevelopUnjordi`) sin OK → el dibujo dice DENY3, pero el código (`confirmar-merge-develop.sh:52-54`) hace `exit 0` (PASA — es el núcleo de iterar sin fricción). Un agente que obedezca el dibujo frena merges legítimos a su mini. → agregar salida "destino = rama personal/epic/*/integracion/* → 🟢 PASA".
- **[MEDIO] Cascada SECUENCIAL oculta el paralelismo** (los 3 guards disparan en paralelo, no en cadena; el estado terminal coincide pero el modelo de orden es falso e incoherente con 04).
- **[MEDIO] Omite la autorización DURABLE en disco** (`autorizaciones-vigentes.local.md`, `confirmar-merge-develop.sh:107-114`) como 2ª fuente de OK.
- **[BAJO]** terminal `G1_OK` rotula "MERGE" un push simple; salidas fail-open no dibujadas.

### 04 — Comando git en bash · guards que lo inspeccionan
Las 2 ramas dibujadas (secret-scan, proteger-arbol) son fieles.
- **[ALTO] "los DOS hooks lo reciben en paralelo" es FALSO — son OCHO** (git-branch-guard, merge-squash-guard, confirmar-merge-develop, recordar-dashboard, secret-scan, entorno-maquina-guard, rama-vieja, proteger-arbol; 3 pueden DENY). Acotarse a 2 está bien, pero la frase absoluta engaña. → "estos 2 son los de este diagrama; el comando lo ven TODOS en paralelo".
- **[MEDIO] `S_D4` lista de patrones de secreto STALE** (dibuja 7; el código `detectar-secretos.sh:11-28` tiene ~13: +sk-proj, github_pat_, JWT, connection-string `user:pass@`, `Password=`). Subdeclara un guard de SEGURIDAD.
- **[MEDIO] No modela el modo STRICT (fail-CLOSED)** (`CLAUDE_SECRET_SCAN_STRICT=1` invierte `S_PASA3` a DENY).
- **[MEDIO] `entorno-maquina-guard` no aparece en NINGÚN flowchart del clúster** (laguna de cobertura).

### 05 — Al hacer push · nudges
Fiel para recordar-dashboard (precedencia correcta) y rama-vieja.
- **[MEDIO] `G6_PUSH` "¿push de una ramita?" mis-declara a recordar-dashboard:** dispara en CUALQUIER push, incondicional (`:13,15`); solo rama-vieja filtra a ramitas. El "no → silencio" implica mudez falsa.
- **[MEDIO] Ignora el fan-out:** el mismo push también dispara secret-scan + git-branch-guard (pueden DENY). Un lector de 05 aislado creería que un push nunca se bloquea. → cruce a 03/04.
- **[BAJO]** leyenda + numeración transversal.

---

## PASE COLECTIVO / COSTURA (los 11 juntos)
Cada chart aguanta solo, pero **como SISTEMA no cierra**: mismo evento en 3 topologías incompatibles, el rojo con sentidos opuestos, y numeración desfasada sin índice.

- **[CRÍTICO-1] 03/04/05 trocean UN solo evento `PreToolUse/Bash` (8 hooks, todos en paralelo) en 3 dibujos que se contradicen** (03 = cascada SECUENCIAL de 3; 04 = "los DOS hooks en paralelo"; 05 = 2 nudges) y **nadie es dueño de la unión de 8**. El subsistema más sensible (git-guards) es el peor modelado en conjunto. → nodo raíz común "8 hooks en paralelo, sin despachador"; 03/04/05 = zoom sobre subconjuntos.
- **[CRÍTICO-2] 🔴 rojo = significados OPUESTOS**: en 01 (con leyenda) rojo = HUECO/bug vigente; en 03/04/06 rojo = DENY/bloqueo = el guard funcionando BIEN. Solo 01/02 tienen leyenda → agregarla a 01/02 (#208) **sin homologar 03-11 empeoró el hueco**: ahora hay una leyenda autoritativa que contradice al resto. → **una leyenda ÚNICA** para los 11, rojo=DENY separado de hueco/bug.
- **[ALTO-3] Numeración circulada desfasada −1 del filename** (01→⓪, 02→①, … 09→⑧), sin índice; y #208 introdujo una 2ª convención (cita por nombre de archivo). Los punteros circulados apuntan al chart correcto internamente, pero "hecho cumplir en ⑤" manda al lector al archivo `05` cuando es el `06`. → rotular cada chart + cross-ref con su número de archivo.
- **[ALTO-4] `entorno-maquina-guard` cae en la costura entre 04 (guards) y 10 (normas) y no está en NINGUNO** (both-tier, dispara en PreToolUse/Bash, tiene norma propia). Ambos charts lo dan por cubierto por el otro.
- **[MEDIO-5] Antipatrón "conteo de hooks hardcodeado" REINCIDE — y el 02 REHECHO (#208) lo repitió**: su título dice "SessionStart cablea 4 hooks" pero son **5** (falta `recordar-unificar-cerebro`). La remodelación hecha para corregir un subconteo reintrodujo el mismo error → es defecto de MÉTODO. → no afirmar cardinalidades; "se derivan del MANIFEST".
- **[MEDIO-6] Cobertura vs MANIFEST:** el chart "cajón de sastre" (11) es el menos completo (1 de 4 libs). Sin flowchart: libs `analizar-comando-git`/`detectar-secretos`/`ramas-zombie`, scripts `verificar-cerebro`/`limpiar-ramas`, repo-hooks `recordar-cosechar` (Stop, hermano de dod-verificar en 06) y `recordar-unificar-cerebro`. Cubre ~24/30 piezas.
- **[MEDIO-7] Deriva de notación** entre 01/02 (leyenda) y el resto: 💾 vs 💡 para skill, ⚙ lib (11) vs ⚙ script (09), "fail-open" con valencias opuestas (04 pasa / 08 pregunta).
- **[BAJO-8] El FRENO `limite-gasto` invisible en la costura 09→⑦** (09 remite solo por el gate/ASK, no por el DENY cuando la ventana de 5h se agota a media ola). · **[BAJO-9]** limpieza de worktrees (09) y de ramas locales (02) sin enlace cruzado.

---

## VEREDICTO DEL SISTEMA + PLAN DE ARREGLO
**Código de develop: SANO** — los defectos son de FIDELIDAD del DIBUJO, no de lógica. Ningún flowchart es REHACER salvo 01 (ya en #208). PERO **el set no es coherente como sistema todavía**, y **#208 (rehaul de 01/02) quedó PARCIAL**: no homologó la notación (CRÍTICO-2) e reintrodujo el subconteo de hooks (MEDIO-5) → **#208 NO debe mergearse como final; necesita rework dentro del fix-wave.**

**Fix-wave de flowcharts (orden priorizado):**
1. **Leyenda ÚNICA compartida por los 11** — rojo=DENY separado de hueco/bug (mata CRÍTICO-2 + MEDIO-7).
2. **Raíz común del fan-out `PreToolUse/Bash` de 8 hooks**, re-encuadrando 03/04/05 como zoom del mismo evento + incluir `entorno-maquina-guard` (mata CRÍTICO-1 + ½ ALTO-4).
3. **Rotular cada chart y cross-ref con su número de archivo** (mata ALTO-3 sin renumerar).
4. **Completar cobertura:** entorno-maquina-guard en 10; 3 libs + scripts + recordar-cosechar/recordar-unificar-cerebro en 11/06/02 (resto ALTO-4, MEDIO-5/6).
5. **Fuente `.dot` versionada para los 9 restantes** (01/02 ya en #208) + arreglar el `.gitignore` contradictorio.
6. Rehacer #208 sobre esta base (leyenda única + no afirmar "4 hooks" + citar por filename).

**Impacto en los MRs (para decisión de unjordi):**
- **Código (#207 skill · #209 brain costura · !110 plantilla wiring):** el audit NO los bloquea — son código, verificados técnicamente y revisados. Mergeables con tu OK.
- **#208 (flowcharts 01/02):** **rework antes de mergear** — el fix-wave lo absorbe.

*INSUMO read-only. El auditor no declaró nada LISTO; el cierre exige QA/autorización de unjordi.*

