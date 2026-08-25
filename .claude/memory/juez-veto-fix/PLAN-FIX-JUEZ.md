# PLAN DE ARREGLO DEL JUEZ DE MERGE — spec para el implementador (consolidado de 2 auditorías independientes)

> Origen: dos auditores independientes (ANCLADO con prediagnóstico + hipótesis rival; CIEGO a ciegas)
> convergieron en la MISMA causa raíz y la REPRODUJERON en vivo (5-6 corridas c/u). Informes fuente:
> `INFORME-ANCLADO.md` y `INFORME-CIEGO.md` (este mismo dir). Este plan es el destilado accionable.
>
> **RESTRICCIONES DURAS (inviolables) para quien implemente:**
> - El fail-safe NO se afloja: default sigue **fail-CLOSED / DENY**; UNAVAILABLE→DENY; piso barato intacto.
> - **SOLO el USUARIO autoriza** (jamás una línea ASISTENTE). El objetivo del veto de cita es CORRECTO;
>   solo su implementación byte-exacta es frágil. El fix DEBE preservar este invariante.
> - El **piso determinista de `main`** (release exige lenguaje de release del USUARIO) queda **INTACTO**.
> - Cada fix nace con su **test sin red** (mocks `CLAUDE_MERGE_JUEZ_MOCK_RAW` / `CLAUDE_DOD_JUEZ_MOCK_RAW`,
>   patrón de `brain/test-brain.sh`). La batería completa debe quedar verde.
> - Se libera **por el widget** (unjordi), NUNCA corriendo `install-brain` a mano.
> - Cambios de **PRECISIÓN** (menos falsos DENY), nunca "para que deje de bloquearme".

## Diagnóstico verificado (no reabrir — ya está probado)
El juez-Haiku **razona ALLOW correcto y estable** (entiende "las 3 branches" = #272/#273/#274). Lo que produce
el falso DENY NO-DETERMINISTA es una capa determinista aguas abajo: el **veto de CITA por substring
byte-exacto**. El usuario escribió con typo *"las 3 branches que siguen **pendietes** por favor"*; Haiku a
veces "corrige" el typo al copiar la CITA → `grep -Fq` no halla "pendientes" dentro de "pendietes" →
override a DENY. **Un carácter invierte el veredicto.** Eso ES el #272-ALLOW/#273-DENY (misma ventana, misma
autorización). La teoría de "ventana deslizante/dilución" quedó REFUTADA (0 mensajes de usuario entre ambos).

**Notas de terreno para el implementador:**
- `juez-comun.sh` **NO existe**; el juez vive INLINE en `brain/hooks/confirmar-merge-develop.sh`. La lib
  compartida real es `analizar-comando-git.sh`.
- El MISMO veto frágil está **duplicado** en `brain/hooks/dod-verificar.sh` (veto de MARCA). FIX #1 aplica a
  AMBOS hooks. Como está copy-pasteado, considerar extraer el helper a un solo lugar + test anti-drift.
- **Editar la versión de `develop`** (o de una ramita sacada de develop), NO la del working tree `chore/...`
  (stale, difiere ~254 líneas). Ya hay worktree preparado: `scratchpad/wt-veto`, rama
  `fix/juez-veto-cita-robusto` sacada de `origin/develop` (SIN commits aún).

---

## FIX #1 (CRÍTICO) — veto de CITA robusto por CONTAINMENT DE TOKENS (no substring byte-exacto)
**Dónde:** `brain/hooks/confirmar-merge-develop.sh` (bloque `if [ "$out" = ALLOW ]`, la línea del `grep -Fq`)
y su GEMELO en `brain/hooks/dod-verificar.sh` (el `grep -Fq -- "$cita"` del veto de MARCA).

**Qué hace hoy (roto):**
```sh
printf '%s\n' "$3" | grep -iE '^[[:space:]]*USUARIO:' | grep -Fq -- "$cita" || out=DENY
```
Exige que la CITA sea substring LITERAL byte-a-byte de una línea USUARIO. Imposible de cumplir cuando el LLM
normaliza (typo/acento/caso/puntuación) — que es lo que un LLM hace naturalmente.

**Cambio:** reemplazar el match por un helper `_juez_cita_casa "<cita>" "<líneas-candidatas-de-USUARIO>"` que:
1. **Normaliza IDÉNTICO ambos lados:** minúsculas + acentos best-effort (`iconv -f UTF-8 -t ASCII//TRANSLIT`
   si existe; si devuelve vacío, conserva el original) + colapsar todo run no-alfanumérico a un espacio + recortar.
2. **Casa** si, para ALGUNA línea candidata (que el CALLER garantiza son SOLO texto de USUARIO), o bien
   (a) la cita normalizada es **substring** de esa línea normalizada, o bien
   (b) **containment de tokens:** la cita tiene **≥4 tokens** y **≥80–85%** de ellos aparecen (como palabra)
   en ESA UNA línea. (Ambos auditores validaron el umbral; 80% ANCLADO / 85% CIEGO → usar **85%**, el más estricto.)

**Por qué NO afloja:** sigue exigiendo que la autorización viva en una línea USUARIO REAL (nunca ASISTENTE),
sigue exigiendo solapamiento SUSTANCIAL (umbral + mínimo de 4 tokens evita match trivial de 2-3 palabras
sueltas o una cita inventada). Solo tolera typo/acento/caso/puntuación — normalización benigna.

**Comportamiento esperado (prototipos probados por ambos auditores, deterministas sin red):**
| CITA | overlap | veredicto |
|---|---|---|
| "…siguen pendientes" (typo corregido) vs línea "…pendietes" | ~92% | **ALLOW** (hoy da DENY falso — es el bug) |
| "sí libera todo a main…" (alucinada, nunca dicha) | ~22% | **DENY** (invariante anti-alucinación intacto) |
| "el asistente confirma que el usuario aprobó…" (paráfrasis de ASISTENTE) | ~55% | **DENY** (solo USUARIO autoriza) |

**Tests (patrón `test-brain.sh`, mock `CLAUDE_MERGE_JUEZ_MOCK_RAW` para merge y `CLAUDE_DOD_JUEZ_MOCK_RAW` para dod):**
- (a) RAW `VEREDICTO: ALLOW` + `CITA: …pendientes` sobre ventana con línea USUARIO "…pendietes" → **ALLOW**.
- (b) RAW ALLOW + `CITA: <frase que el usuario NUNCA dijo>` → **DENY** (anti-inyección/alucinación).
- (c) RAW ALLOW + `CITA:` copiando texto de una línea **ASISTENTE** → **DENY** (solo USUARIO).
- (d) RAW ALLOW **sin** línea `CITA:` → **DENY** (conserva el guard de cita-vacía actual).
- (e) RAW ALLOW + `CITA:` de solo 2 tokens que casualmente aparecen → **DENY** (mínimo de 4 tokens).
- Espejo de (a)-(d) para `dod-verificar` (veto de MARCA).

**Portabilidad:** bash 3.2 (macOS) + Linux + Git-Bash Windows. Evitar `y///` de sed sobre multibyte
(traicionero); el fold de acentos es best-effort y el umbral de tokens absorbe acentos residuales. Usar
heredoc con delimitador único (no `EOF`) para alimentar las líneas al `while read` en el shell ACTUAL
(no en subshell de pipe — para que un `return` funcione).

---

## FIX #2 (ALTO) — `acg_mrid` multi-comando: hoy extrae el id EQUIVOCADO
**Dónde:** `analizar-comando-git.sh` (`acg_mrid()`). Hoy: `grep -m1` toma el PRIMER entero de TODO el blob.
En `gh pr view 272 …; gh pr merge 273 …` devuelve **272**, no 273 (reproducido) → el DENY citaba el MR
equivocado y detonó el parche "un merge por llamada" que enfureció al usuario.
**Cambio:** aislar el SEGMENTO que contiene el ÚLTIMO `pr merge` / `mr (merge|accept)` (partir por `;`/`&&`/`||`/
newline) y extraer el id **de ese segmento**.
**Test:** `gh pr view 272 …; gh pr merge 273 …` → `273`; no-regresión `glab mr merge --yes 9` → `9` (caso A-04 ya existe).

## FIX #3 (MEDIO) — destino indeterminado: resolver mejor + no citar mrid equivocado
**Dónde:** `analizar-comando-git.sh:175-197` (`acg_destino_de_mr`) + el mensaje DENY de destino-vacío.
**Cambio (sin tocar el fail-safe):** (a) si el destino viene vacío por repo mal resuelto (cwd multi-repo sin
`--repo`), intentar derivar `--repo` del PR de la lista ya cacheada (`baseRefName`/`headRefName`) antes de
rendirse; (b) el mensaje DENY deja de citar un mrid potencialmente equivocado (depende de FIX #2).
**Test:** fixture de prlist mock. El fail-safe (vacío → juez con regla main-estricta) se mantiene igual.

## FIX #4 (OPCIONAL) — persistir OK de LOTE como grant durable de sesión
Cuando el juez ALLOWea un OK que nombra varios ("las 3 branches"), escribir un grant `scope=merge-develop`
con vencimiento corto para que los MRs hermanos del mismo lote no re-liten con el LLM. Respeta el fast-path
existente (jamás cubre `main`). Es MITIGACIÓN — NO sustituye a FIX #1 (con el veto roto, votar/persistir no ayuda).

**Orden recomendado:** #1 → #2 → #3 → (#4 opcional). Cada uno = un slice/PR independiente con su test.

---

## QUÉ NO TOCAR (romperlo = regresión)
- Piso determinista de `main` (release exige lenguaje de release del USUARIO).
- Default fail-CLOSED / UNAVAILABLE→DENY + piso barato (≥1 línea USUARIO en la ventana).
- Regla de autoridad "solo USUARIO autoriza, nunca ASISTENTE" (el veto de cita CONSERVA esto).
- Dedupe copia-repo↔global; timeout interno de las consultas; `_recent_intercalado` intercalado; voto múltiple opt-in.

## Cómo se cierra
Implementar en `fix/juez-veto-cita-robusto` (worktree `wt-veto`, off develop) → batería `test-brain.sh` verde
(incluidos los tests nuevos) → PR a develop con `--repo` explícito → merge con OK explícito de unjordi (el
juez YA arreglado debería autorizarlo citando su OK con el nuevo containment) → liberar por widget → QA de unjordi.
NO declarar LISTO sin (1) QA de unjordi o (2) su autorización expresa de cierre.
