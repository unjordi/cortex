# INFORME — Auditor CIEGO · jueces del cerebro claude-brain

Auditoría independiente, read-only. Todas las afirmaciones citan `archivo:línea` del código real leído y/o
la reproducción LIVE del juez que corrí contra Haiku (token OAuth del keychain, sin merges ni mutación de repos).

**Veredicto de una línea:** el juez PIENSA bien (su comprensión de lectura autorizó #273 en 6/6 corridas);
lo que produjo el falso DENY y la inconsistencia #272-vs-#273 es una capa DETERMINISTA aguas abajo —el
**veto de CITA por substring exacto**— que se rompe cuando el LLM "corrige" un typo del usuario. No fue la
ventana deslizante, ni la dilución, ni el anclaje al 10º-usuario.

---

## 1. Arquitectura — confirmada / corregida

El diagrama del CONTEXTO es **fiel en el flujo**, con estas correcciones:

- **NO existe `juez-comun.sh`.** El CONTEXTO dice que los dos jueces comparten esa lib; es falso. El juez de
  merge está INLINE en `confirmar-merge-develop.sh` (`_juez_merge_uno` :45, `_juez_merge` :181,
  `_recent_intercalado` :205). El juez del DoD está inline en `dod-verificar.sh` (`_juez_dod` :69). Lo que sí
  comparten es la lib `analizar-comando-git.sh` (resolución de destino/candidatos) y, por copiar-pegar, el
  **mismo patrón de veto de CITA** (confirmar :131, dod :140) — que es justo el punto de falla.
- Pasos 1-11 del diagrama: correctos. El dedupe (:237), `acg_es_merge_mr` (:249), la marca
  `repo-compartido` (:253), `acg_destino_de_mr` (:263), el early-exit de rama personal (:269), el
  hint (:290), el `_recent_intercalado` (:301) están tal como se describen.
- Paso 13 (`_juez_merge`): el diagrama omite el orden real y la CAPA que rompe. El flujo dentro de
  `_juez_merge_uno` es: piso-barato (:61) → token (:65-68) → curl Haiku (:108) → parseo de centinela (:118)
  → **VETO DE CITA por substring exacto (:123-133)** → piso determinista de main (:141-147). El veto de cita
  es lo que el diagrama pinta como "si ALLOW: exige línea CITA… si no, DENY" (línea 75 del diagrama) sin
  advertir que **exige coincidencia LITERAL byte-a-byte** contra la línea USUARIO.

---

## 2. Fallas de raíz (ordenadas por gravedad)

### FALLA #1 — CRÍTICA · el veto de CITA por substring exacto se rompe con la normalización benigna del LLM
**(diseño de derivación de autorización + plomería del match)**

- **Dónde:** `confirmar-merge-develop.sh:126-131`. El ALLOW del LLM se re-verifica extrayendo la línea
  `CITA:` (:126), normalizando SOLO espacios/comillas (:127) y exigiendo que sea **substring literal**
  (`grep -Fq -- "$cita"`, :131) de una línea `^USUARIO:`. Sin match → `out=DENY` (:131).
- **Mecanismo del veredicto MALO:** el LLM, al copiar la cita del usuario, **normaliza el texto** — corrige
  typos, acentos, mayúsculas, puntuación. Cuando lo hace, el substring exacto falla y un ALLOW legítimo se
  degrada a DENY, **contra el propio juicio del juez**.
- **Evidencia dura (reproducción LIVE sobre la ventana REAL del incidente):** el usuario escribió (línea
  23820 del transcript, bytes exactos verificados) `haz el merge a develop de las 3 branches que siguen
  **pendietes** por favor` — con el typo "pendietes" (sin la 'n'; aparece 9× en el transcript, la forma
  correcta "pendientes" 3×, todas del asistente). Corrí `_juez_merge_uno develop 273 <ventana-real>
  <hint-3-candidatos>` 6 veces con DEBUG:

  | corrida | veredicto CRUDO del LLM | ortografía en su CITA | veredicto FINAL (post-veto) |
  |---|---|---|---|
  | 1-4,6 | **ALLOW** | "pendie**ntes**" (corregido) | **DENY** ← veto falla |
  | 5 | **ALLOW** | "pendie**tes**" (verbatim) | **ALLOW** ← veto pasa |

  El CoT de una corrida cerró textual: *"La instrucción aplica a TODOS los que nombra, incluyendo #273 …
  VEREDICTO: ALLOW"* — y aun así el hook devolvió DENY. La comprensión de lectura es CORRECTA; la mata el veto.
- **Clasificación:** DISEÑO (el contrato "verbatim exacto" es insatisfacible cuando el input trae un typo)
  con dimensión de PLOMERÍA (la normalización de :127 es demasiado débil: solo colapsa espacios).

### FALLA #2 — la inconsistencia #272-ALLOW / #273-DENY es la FALLA #1, no la ventana

- Entre la autorización (23820) y el DENY de #273 hubo **CERO mensajes de texto reales del usuario**
  (verificado: los únicos user-text en 23820-24034 son 23820=autorización, 23982=`[Request interrupted]`,
  23983=la explosión — POSTERIOR al bloqueo). La teoría del CONTEXTO ("~7 mensajes del usuario diluyeron la
  autorización") es **falsa** para este transcript.
- La autorización está DENTRO de la ventana en AMBOS merges (verificado: `grep -c "3 branches que siguen"` =2
  en las dos ventanas reconstruidas `fx-272`/`fx-273`; es la línea USUARIO más reciente, `$u[-1]`).
- Reproducción sobre la ventana REAL de #272 (8 corridas): `DENY ALLOW DENY DENY ALLOW DENY DENY DENY` — o sea
  **flapping a temperature 0**. La misma ventana de #273 (8 corridas): `DENY×8`. La diferencia NO es la
  autorización: es que en cada llamada el LLM decide de forma independiente si copia el typo verbatim (→ veto
  pasa → ALLOW) o lo corrige (→ veto falla → DENY). #272 ganó 2 tiros de moneda; #273 perdió los suyos.
- **Corolario sobre `temperature:0`:** todo el hook asume "gate reproducible / byte-idéntico" (:48-49, :29).
  Es falso: temp 0 en la API es casi-determinista, NO determinista. En ESTE caso el veredicto CRUDO fue
  estable (ALLOW 6/6); el no-determinismo VISIBLE lo introdujo el veto de cita. Pero el flapping crudo sigue
  siendo un riesgo latente en casos frontera.

### FALLA #3 — MEDIA/latente · el hint "VARIOS candidatos → DENY" contradice una autorización EN LOTE
**(diseño de derivación de autorización)**

- **Dónde:** `analizar-comando-git.sh:263-265`. Con ≥2 MRs abiertos hacia la base, el hint le dice al juez
  *"hay VARIOS candidatos: un OK VAGO del USUARIO NO basta, debe nombrar cuál (si no, DENY)"*. Reproduje el
  bloque exacto que vio #273 (3 candidatos → ese texto).
- **Mecanismo:** el usuario dio un OK de CONJUNTO ACOTADO ("las 3 branches que siguen pendientes") que cubre
  legítimamente los 3 PRs, pero SIN nombrar ids (no podía: los PRs no existían cuando dio el OK). El prompt
  tiene regla de lista *"autoriza a TODOS los ids que nombra"* (:85) pero el usuario nombró un CONTEO/CONJUNTO,
  no ids; y no hay regla "autorizó N y hay exactamente N candidatos → todos cubiertos". El hint empuja a DENY.
- En mis corridas el LLM **anuló** el hint (crudo ALLOW 6/6), así que aquí fue latente, no la causa activa.
  Pero es un generador real de falsos DENY para el patrón "mergea todas / las que quedan / las 3 pendientes".

### FALLA #4 — plomería · contaminación de la ventana con pseudo-USUARIO

- **Dónde:** `confirmar-merge-develop.sh:217` filtra SOLO `<system-reminder>`. NO filtra `<task-notification>`,
  `<local-command-stdout>`, `[Request interrupted by user]`, wrappers de comando.
- **Evidencia:** en la ventana real de #273, líneas `USUARIO:` incluyen
  `USUARIO: <task-notification> …` y `USUARIO: <local-command-stdout> …`. Consumen el presupuesto del anclaje
  10º-usuario y son **superficie de inyección** para el veto de cita (una `<task-notification>` con texto
  arbitrario podría convertirse en una "cita USUARIO válida"). No fue la causa activa hoy, pero es defecto real.

### FALLA #5 — plomería · el destino depende del cwd/repo del hook (la 1ª fricción de #272)

- **Dónde:** `analizar-comando-git.sh:181` — el repo se deriva de `--repo` o de
  `git -C ${CLAUDE_PROJECT_DIR} remote get-url origin`. En una sesión multi-repo, `CLAUDE_PROJECT_DIR` es
  `plantilladotnet`, NO `claude-brain` (donde viven los PRs). Sin `--repo`, `gh pr view 272` consulta el repo
  equivocado → destino vacío → el mensaje "no pude CONFIRMAR el destino del MR 272" (verificado en el
  transcript, líneas ~23945). Es el **fail-safe correcto** (no confirmó destino → no autorizó); el reintento
  con `--repo` lo resolvió. No es falla de criterio: es fricción de plomería + operativa.

---

## 3. No-determinismo — respuesta directa

El mismo OK dio veredictos distintos **NO** por la ventana deslizante, **NO** por el anclaje al 10º-usuario,
**NO** por dilución, **NO** por el mapeo lote→MR (el LLM lo resolvió bien). Es por **la FALLA #1**: el veto de
CITA por substring exacto convierte una decisión de comprensión estable (ALLOW) en un tiro de moneda entre
"el LLM copió el typo del usuario" (ALLOW) y "el LLM corrigió el typo" (DENY). #272 sacó ALLOW en 2/8 tiros y
uno cayó en el intento real; #273 sacó DENY en todos los suyos. Secundariamente, el veredicto CRUDO puede
flapear en frontera aun a temp 0 (el "gate reproducible" es un supuesto FALSO).

---

## 4. Propuesta de arreglo (respetando las restricciones DURAS)

Principio rector: **el juez ya razona bien; hay que dejar de sabotearlo con una verificación demasiado
literal, SIN aflojar el invariante "solo el USUARIO autoriza".** Ninguna de estas afloja el fail-safe.

### Arreglo #1 (PRIORIDAD 1) — veto de CITA robusto a normalización benigna
Reemplazar el substring exacto (`confirmar-merge-develop.sh:131` y su gemelo `dod-verificar.sh:140`) por un
match **normalizado + por contención de tokens**, manteniendo el anclaje a una línea `^USUARIO:` real:
1. Normalizar AMBOS lados idéntico: minúsculas, quitar acentos (`iconv -t ASCII//TRANSLIT` con fallback sed),
   colapsar todo run no-alfanumérico a un espacio, recortar.
2. ALLOW sobrevive si, para ALGUNA línea `^USUARIO:`, o bien (a) la cita normalizada es substring de esa línea
   normalizada, o bien (b) **contención de tokens**: la cita tiene ≥4 tokens y ≥85% de sus tokens aparecen en
   esa única línea USUARIO. "pendientes" vs "pendietes" es 1 token de ~12 → ~92% → pasa. Una cita inyectada que
   no comparte ~85% con NINGUNA línea USUARIO real → DENY (invariante intacto).
- **Por qué NO afloja:** sigue exigiendo que la autorización viva en una línea USUARIO (jamás ASISTENTE),
  sigue exigiendo solapamiento sustancial (umbral + mínimo de tokens), solo tolera typo/acento/caso/puntuación.
- **Tests (estilo `test-brain.sh`, mocks sin red, `CLAUDE_MERGE_JUEZ_MOCK_RAW`):**
  - RAW con `CITA: haz el merge a develop de las 3 branches que siguen pendientes` (typo corregido) sobre una
    ventana con la línea USUARIO que dice "pendietes" → **ALLOW** (hoy da DENY: es el bug).
  - RAW con `CITA: <frase que el usuario NUNCA dijo>` → **DENY** (anti-inyección/alucinación).
  - RAW con `CITA:` copiando texto de una línea ASISTENTE → **DENY** (solo USUARIO autoriza).
  - RAW con cita de 2 tokens que casualmente aparecen → **DENY** (mínimo de tokens evita match trivial).

### Arreglo #2 (PRIORIDAD 2) — enseñar autorización EN LOTE al hint y al prompt
`analizar-comando-git.sh:263-265`: cuando el USUARIO autoriza el CONJUNTO ("las 3 / todas / las que quedan /
las pendientes"), y el nº de candidatos abiertos hacia la base ≤ ese conteo, el hint debe decir "un OK de
CONJUNTO del USUARIO cubre a CADA candidato; un OK VAGO de UNO SOLO ('ese') sigue exigiendo nombrar cuál".
Añadir la regla espejo en el prompt (:85-87). **Precisión, no afloje:** un "ese" vago con varios candidatos
sigue en DENY. Test: hint de 3 candidatos + `USUARIO: mergea las 3` → ALLOW para cada id; + `USUARIO: mergea
ese` → DENY.

### Arreglo #3 (PRIORIDAD 3) — endurecer el filtro de la ventana
`confirmar-merge-develop.sh:217`: extender el `test(...)` para también descartar `<task-notification>`,
`<local-command-stdout>`, `<local-command-caveat>`, `[Request interrupted by user]`. Test con fixture de
transcript (ya hay infraestructura: `_recent_intercalado` + `_CMD_JUEZ_SOURCE_ONLY=1`, ver test-brain :386-415).

### Arreglo #4 (opcional) — self-consistency para el flapping crudo residual
Encender `CLAUDE_MERGE_JUEZ_VOTES=3` a `CLAUDE_MERGE_JUEZ_TEMP≈0.4` (la palanca YA existe, :181-200,
unánime-para-ALLOW). Reduce el flap del veredicto CRUDO en frontera SIN debilitar (cualquier DENY gana).
Nota: NO sustituye al Arreglo #1 — con el veto roto, votar no ayuda (todos los votos que corrigen el typo dan DENY).

**Liberación:** por el widget externo, con `install-brain` NO corrido a mano (restricción respetada). Todo
arreglo nace con su test como arriba.

---

## 5. Qué NO tocar (romperlo sería regresión)

- **El fail-safe DENY** ante UNAVAILABLE / sin token / sin destino confirmado (:68, :331-347). Correcto.
- **El piso determinista del gate de MAIN** (:141-147) y su batería de sobre-match (test-brain :435-455).
  Es defensa en profundidad de la consecuencia máxima; intacto.
- **El invariante "solo líneas USUARIO autorizan"** (prompt :80, :140). El Arreglo #1 lo PRESERVA; no lo relajes.
- **El intercalado USUARIO/ASISTENTE** para resolver anáforas (:205-227). Es correcto y necesario (sin él
  volvían los FN anafóricos); solo hay que limpiarle el ruido (Arreglo #3), no quitarlo.
- **El dedupe repo/global** (:237), `acg_es_merge_mr` anclado al subcomando (:136-143), el despoje de
  comillas/`--repo` y la normalización de prefijo git (:9-53). Sólidos, con FMEA detrás.
- **El caché compartido de destino/prlist** (:186, :215). Bien. (Ojo menor: no se refresca tras un merge en la
  misma ráfaga — inocuo hoy, pero relevante si el Arreglo #2 empieza a depender del conteo exacto de abiertos.)
