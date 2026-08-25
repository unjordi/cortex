# INFORME — Auditor ANCLADO · jueces del cerebro claude-brain

**Etiqueta:** ANCLADO · **Alcance:** read-only, código real + transcript real + reproducción con el juez LIVE.
**Veredicto de una línea:** Gana **Teoría B (sobre-acotamiento del prompt)**, con un mecanismo EXACTO y REPRODUCIDO: el **veto de CITA verbatim** (Capa 2 de `confirmar-merge-develop.sh`) tumba un ALLOW correcto de Haiku cuando este parafrasea aunque sea **un carácter** de la cita. Teoría A2 (ventana deslizante / dilución) queda **REFUTADA por el transcript**. A1 (plomería del destino) y A3 (grant durable) son reales pero **secundarias** — no causan la inconsistencia #272/#273.

---

## 0. Corrección de partida a la premisa del encargo

El CONTEXTO afirma (paso 4): *"Entre el paso 1 y este, hubo ~7 mensajes más del usuario … que desplazaron/diluyeron la autorización original"*. **Esto es falso.** En el transcript real, entre la autorización (L23820) y el DENY de #273 (L23981) **NO hubo NINGÚN mensaje del usuario** — solo turnos del ASISTENTE (rebases, push, `gh pr create`, narración). La línea de autorización sigue **verbatim** en la ventana de #273. Esto por sí solo derrumba la hipótesis de dilución.

*(Nota menor: `juez-comun.sh` NO existe como archivo; el juez de merge vive INLINE en `confirmar-merge-develop.sh`. El resumen post-compact del transcript lo menciona como si existiera — confabulación del resumen. La lib real compartida es `analizar-comando-git.sh`.)*

---

## 1. Arquitectura — confirmada, con dos correcciones

El diagrama del CONTEXTO es fiel en lo esencial (pasos 1–14). Correcciones/precisiones contra el código:

- **Paso 6 (destino):** además de `gh pr view`, para glab usa `glab api .../merge_requests/<id>` (`analizar-comando-git.sh:188-190`). El destino se cachea por `(repo,tool,mrid)` (`:186,192-194`).
- **Paso 11 (ventana `_recent_intercalado`):** se ancla al 10º USUARIO desde el final y añade 4 turnos de arranque (`confirmar-merge-develop.sh:219-223`); las líneas USUARIO NO se truncan, las del ASISTENTE sí (a 700, `:225`). Verificado reconstruyendo ambas ventanas con fixtures reales.
- **Paso 13 — el juez NO es solo "curl Haiku":** son **cuatro capas superpuestas** sobre la respuesta del LLM: (C1) parseo por centinela `VEREDICTO:` (`:118`), (C2) **veto de CITA verbatim** (`:123-133`), (C3) hint de candidatos como "hecho" (`analizar-comando-git.sh:237-274`), (C4) piso de `main` determinista (`:141-147`). **La falla vive en C2.**

---

## 2. Fallas de raíz (ordenadas por gravedad)

### 🔴 RAÍZ #1 — Veto de CITA verbatim: falso DENY NO-DETERMINISTA de un merge legítimo (falla de DISEÑO / prompt)
**Archivo:** `brain/hooks/confirmar-merge-develop.sh:119-133` (el bloque `if [ "$out" = ALLOW ]`), en particular la línea **`:131`**:
```sh
printf '%s\n' "$3" | grep -iE '^[[:space:]]*USUARIO:' | grep -Fq -- "$cita" || out=DENY
```
**Mecanismo (REPRODUCIDO LIVE, 5 corridas sobre la ventana real de #272):**

| corrida | Haiku dijo | CITA que emitió | veredicto FINAL |
|---|---|---|---|
| 1 | ALLOW | "...siguen **pendientes** por favor" | **DENY** (override) |
| 2 | ALLOW | "...siguen **pendietes** por favor" | ALLOW |
| 3 | ALLOW | "...siguen **pendietes** por favor" | ALLOW |
| 4 | ALLOW | "...siguen **pendietes** por favor" | ALLOW |
| 5 | ALLOW | "...siguen **pendientes** por favor" | **DENY** (override) |

La línea real del usuario tiene un **typo**: *"las 3 branches que siguen **pendietes** por favor"* (L23820, falta la `n`). Haiku **razona ALLOW el 100% de las veces** (entiende "las 3 branches" = #272/#273/#274 — su CoT lo dice literal), pero **a veces "corrige" el typo** al copiar la CITA. Cuando lo corrige, el `grep -Fq` (substring EXACTO) no halla "pendientes" dentro de "pendietes" → **override a DENY**. Un cambio de **un carácter** invierte el veredicto.

Esto ES el incidente #272-ALLOW / #273-DENY: **misma ventana, misma autorización, mismo juicio ALLOW de Haiku**; lo único que fluctúa es si Haiku transcribe el typo. El juez se sintió "vivo pero traicionero" porque su criterio es correcto y estable — lo que falla es el candado verbatim envuelto alrededor.

El veto tolera espacios y comillas/asteriscos envolventes (`:127`) pero **NADA** de: typos, acentos, puntuación interna, mayúsculas internas, o cualquier normalización que un LLM hace naturalmente. Es un contrato imposible: *"copia BYTE-EXACTO un texto humano"*.

### 🟠 RAÍZ #2 — `acg_mrid` no es multi-comando: extrae el id EQUIVOCADO (falla de PLOMERÍA)
**Archivo:** `analizar-comando-git.sh:63-65`.
```sh
acg_mrid() { printf '%s' "$1" | sed -E 's/.*(mr[[:space:]]+(merge|accept)|pr[[:space:]]+merge)[[:space:]]+//' | tr ' ' '\n' | grep -m1 -E '^#?[0-9]+$' | tr -d '#'; }
```
El `sed` solo despoja el prefijo en las LÍNEAS que contienen `pr merge`; deja intactas las demás. Luego `grep -m1` toma el **primer entero de TODO el blob multilínea**. En el comando compuesto real de L23961 (`gh pr view 272 …; gh pr merge 273 …`) devuelve **272**, no 273 (**reproducido:** `acg_mrid = [272]`). Por eso el DENY de L23962 hablaba del "MR 272" cuando la intención era 273 — confundió al asistente y disparó su "regla" de *"un merge por llamada"* (justo el parche que enfureció al usuario). El comando limpio (`merge 273` solo) sí da 273 (reproducido).

### 🟡 RAÍZ #3 — Destino cuelga de un `gh pr view` en vivo dentro del hook (PLOMERÍA, Teoría A1)
**Archivo:** `analizar-comando-git.sh:175-197`. Con cwd reseteado a `plantilladotnet` y sin `--repo`, `git remote get-url origin` (`:181`) resuelve el repo EQUIVOCADO → `gh pr view` falla → destino vacío → mensaje "no pude CONFIRMAR el destino" (L23945). **Real, pero es un mensaje confuso, NO la inconsistencia #272/#273** (esa ocurrió con `--repo` puesto y destino=develop resuelto en AMBOS). El fail-safe aquí es correcto (vacío → juez con regla main-estricta); la molestia es de UX/robustez.

### 🟢 RAÍZ #4 — Grant durable existe pero solo lo escribe `turno-nocturno` (DISEÑO, Teoría A3)
**Archivo:** `confirmar-merge-develop.sh:311-320`. Un OK de lote ("las 3 branches") no se persiste → cada MR re-litiga con el LLM. Real, pero es **mitigación**, no la causa. Sin la RAÍZ #1, el LLM ya resolvía el lote bien.

---

## 3. No-determinismo: ¿por qué el MISMO OK da veredictos distintos?

**No es la ventana, no es el anclaje, no es la dilución, no es el mapeo lote→MR.** Es la **RAÍZ #1**: a temperatura 0 Haiku es casi-determinista en su JUICIO (ALLOW estable), pero **no es determinista en si transcribe un typo del usuario carácter-por-carácter**. El único componente que exige reproducción byte-exacta (el veto de CITA) convierte esa variación inocua en un flip de veredicto. Confirmado con evidencia de tabla arriba: `LLM_said=ALLOW` en 5/5; `FINAL` fluctúa 3 ALLOW / 2 DENY.

Corolario: el anclaje "10º usuario" y el recorte a 700 chars del ASISTENTE **NO** escondieron nada aquí — la propuesta del asistente ("Ahora los mergeo con --squash…") y el OK del usuario estaban ambos en la ventana; Haiku los citó correctamente.

---

## 4. Adjudicación explícita A vs B

- **Teoría A2 (sesión principal — ventana deslizante/dilución): REFUTADA.** Cero mensajes de usuario entre #272 y #273; autorización verbatim presente en ambas ventanas; Haiku juzga ALLOW en ambas.
- **Teoría A1 (plomería destino): REAL pero SECUNDARIA.** Explica los mensajes confusos "no pude CONFIRMAR el destino", no el flip ALLOW→DENY con destino ya resuelto.
- **Teoría A3 (grant durable sin usar): REAL pero MITIGACIÓN,** no causa raíz.
- **Teoría B (usuario — "no supe pedirle a Haiku por andar queriendo acotarlo"): VINDICADA, y con el mecanismo exacto.** El acotamiento concreto que rompe es el **veto de CITA verbatim** (Capa 2). Haiku SÍ es capaz de juzgar esto bien (lo hace, siempre); la ingeniería que lo envuelve — exigir eco byte-exacto de una frase humana — es lo que produce el DENY que "un humano razonable no daría". La intuición del usuario es literalmente correcta.

**Síntesis:** B es la raíz del incidente reclamado. A1/A3/RAÍZ#2 son fallas adicionales verdaderas (arréglalas también, cada una con su test), pero ninguna explica la inconsistencia central; el veto de CITA sí.

---

## 5. Propuesta de arreglo (respetando las restricciones DURAS)

Ninguna afloja el fail-safe: default sigue fail-CLOSED/DENY; solo el USUARIO autoriza; el piso de `main` (`:141-147`) queda **intacto**; cada fix nace con test sin red; se libera por el widget.

### FIX #1 (crítico) — veto de CITA robusto por **containment de tokens**, no substring byte-exacto
Sustituir el `grep -Fq` de `:131` por: normalizar (minúsculas + quitar puntuación) CITA y cada línea `USUARIO:`, y exigir que **≥80% de los tokens de la CITA aparezcan en UNA sola línea USUARIO**. Preserva el INVARIANTE de seguridad (el ALLOW debe corresponder a una línea de usuario REAL — mata alucinación e inyección) sin exigir transcripción perfecta.
**Prototipo probado (determinista, sin red):**
- cita con typo corregido ("pendientes" vs "pendietes") → overlap **92% → PASS** (hoy: DENY falso).
- cita alucinada ("sí libera todo a main…") → **22% → DENY** (invariante intacto).
- paráfrasis de asistente ("el asistente confirma que el usuario aprobó…") → **55% → DENY**.
**Tests (con `CLAUDE_MERGE_JUEZ_MOCK_RAW`, patrón de test-brain.sh:463-497):** (a) ALLOW+CITA con 1 typo → ALLOW; (b) ALLOW+CITA sin overlap → DENY; (c) ALLOW+CITA que solo casa en línea ASISTENTE → DENY; (d) ALLOW sin línea CITA → DENY (conserva `:128-129`).
*(Alternativa más agresiva a evaluar con el usuario: quitar el eco de CITA y anclar de otra forma. No la recomiendo aún: el containment es el cambio mínimo de PRECISIÓN.)*

### FIX #2 (alto) — `acg_mrid` multi-comando
Aislar el SEGMENTO que contiene el último `pr merge`/`mr (merge|accept)` (partir por `;`/`&&`/`||`/newline) y extraer el id **de ese segmento**, no del blob completo.
**Test:** `gh pr view 272 …; gh pr merge 273 …` → `273`; y no-regresión de `glab mr merge --yes 9` → `9` (test-brain ya tiene el caso A-04).

### FIX #3 (medio) — mensaje de destino-indeterminado + resolución
No cambiar el fail-safe; sí: (a) cuando el destino venga vacío por repo mal resuelto, intentar `--repo` derivado del `headRefName`/PR de la lista ya cacheada antes de rendirse; (b) el mensaje DENY debe dejar de citar un mrid potencialmente equivocado (depende de FIX #2). Test con fixture de prlist mock.

### FIX #4 (opcional) — persistir OK de LOTE como grant durable de sesión
Cuando el juez ALLOWea un OK que nombra varios ("las 3 branches"), escribir un grant `scope=merge-develop` con vencimiento corto para que los MRs hermanos del mismo lote no re-liten. Respeta `:311-320` (jamás cubre `main`). Mitiga, no sustituye a FIX #1.

**Orden recomendado:** #1 → #2 → #3 → (#4 opcional). Cada uno es un slice/PR independiente con su test; liberar por widget.

---

## 6. Qué NO tocar (romperlo sería regresión)

- **Piso determinista de `main`** (`:141-147`): release SIEMPRE exige lenguaje de release del USUARIO. Intacto.
- **Default fail-CLOSED / UNAVAILABLE→DENY** (`:149`, `:330-348`) y el **piso barato** (≥1 línea USUARIO, `:61`).
- **Regla de autoridad "solo USUARIO autoriza, nunca ASISTENTE"** (prompt `:80`) — el objetivo del veto de CITA es CORRECTO; solo su implementación es frágil. FIX #1 lo conserva.
- **Dedupe copia-repo↔global** (`:237`) y el **timeout interno** de las consultas (`analizar-comando-git.sh:149-159`, H5).
- **`_recent_intercalado` intercalado USUARIO/ASISTENTE** (`:205-227`): el intercalado es necesario para resolver anáforas; no era el problema.
- **Voto múltiple opt-in** (`:157-200`): sesga a la dirección segura; no tocar.

---

### Anexo — artefactos de reproducción (en este mismo directorio)
- `fixture-before-272.jsonl` / `fixture-before-273.jsonl` — estado del transcript justo antes de cada intento.
- `repro-juez.sh`, `repro4` (inline), `fixtest.sh` — reproducen el flip del veto y validan FIX #1.
- `probe.sh` — reproduce `acg_mrid=272` en el comando compuesto (RAÍZ #2).
