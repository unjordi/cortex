# Auditoría de SOLAPAMIENTO — los skills del cerebro + el `CLAUDE.md` global

**Fecha:** 2026-09-17 · **Rama:** `audit/skills-solapamiento` · **Base medida:** `develop` @ `b3a5da1` (2026-09-16 09:58)
**Alcance:** `brain/skills/` (25 skills + `MANIFEST`) y `brain/norms/global-claude-md.md` (463 líneas).
**Lente:** SOLAPAMIENTO de responsabilidad. La obsolescencia la audita otro agente en paralelo.
**Read-only:** no se modificó ningún skill ni norma. Nada de lo que sigue está ejecutado.

Convención: **CONFIRMADO** = medido con `grep`/`git`/lectura, con cita. **PLAUSIBLE** = inferencia razonada sin cierre.

---

## 0 · VEREDICTO

**El conjunto está mayormente SANO en cuanto a solapamiento: de los 5 grupos señalados, 3 son falso
solapamiento y están bien delimitados por diseño. Hay 2 solapamientos DUROS y reales — uno entre skills
(`consolidar-cerebro` Fase 6 ↔ `canonizar-cerebro`, dos specs de la misma firma canónica que YA divergieron)
y uno entre el `CLAUDE.md` global y `cerrar-slice` (dos recetas de git que YA se CONTRADICEN en el mismo
flag). Pero el problema REAL del conjunto no es el solapamiento: es el DISPARADOR.**

Dos hallazgos por encima de todos los demás:

1. **El archivo de normas carga PROCEDIMIENTO.** ~153 de 463 líneas (33%) de `global-claude-md.md` son
   recetas que solo se necesitan cuando haces la cosa, y se pagan en cada sesión de cada máquina del equipo.
2. **El cable de tipo AVISO ya se probó cuatro veces y NO funciona — está medido.** Cuatro skills tienen su
   hook `recordar-*`/advisory y entre los cuatro suman **5 invocaciones**. El único ritual con 80 usos
   (`checkpoint`) tiene un cable de otra naturaleza: su hook **HACE trabajo real**, no avisa. Ver §5 — es la
   respuesta con datos a la pregunta "¿disparar o avisar?".

Y la crítica del dueño es justa y la confirmo: **`confirmar-merge-develop` y `dod-verificar` —los dos hooks
que disparan exactamente en el momento de cerrar un slice— nunca nombran `cerrar-slice`.** El evento existe,
el hook existe, el ritual existe; el cable no.

**No propongo ninguna fusión de dos skills completos.** Las 25 skills tienen objetos distintos; lo que se
duplica son BLOQUES dentro de ellas. El precedente de la auditoría de hooks ("un solo sustrato, fusionar solo
dos, lo demás separado a propósito") se sostiene aquí y por la misma razón: la granularidad es deliberada.

---

## 1 · CORRECCIONES A LAS PREMISAS DEL ENCARGO (medidas)

Se me pidió corregir lo que resultara falso. Cuatro cosas:

### 1.1 · Son **25** skills, no 26 — CONFIRMADO
```
brain/skills/: 25 directorios con SKILL.md · MANIFEST: 25 líneas no-comentario
```
Coinciden 1:1 (ningún skill sin línea en el MANIFEST, ninguna línea huérfana). El conteo del encargo está
desfasado en uno; puede venir de contar skills instalados globalmente que NO viven en `brain/skills/`
(`md-a-tex-pdf`, `flujo-mr-gitlab`, `smb-automount-macos`, `steam-link-a-fondo`, `google-tv-tomar-control`,
`projectivy-launcher`, `tv-hisense-100u75qua` están instalados pero no son del brain).

### 1.2 · La regla de `revisar-entregables-agentes` **NO está en el `CLAUDE.md`** — CONFIRMADO, y esto refuerza la propuesta

El encargo dice: *"su regla —no creerle el verde a un agente— se aplicó hoy una docena de veces… porque está
escrita como norma en el `CLAUDE.md`"*. **Medido: no está.**

```
grep -i "reporte de un agente|verde de agente|no le creas|revisar-entregables"
  brain/norms/global-claude-md.md  → 0 hits
  ~/.claude/CLAUDE.md              → 0 hits
  cortex/CLAUDE.md                 → 0 hits
```

Lo único que hay en las normas es el roce de la Definición de LISTO (`global-claude-md.md:55,59`), que habla
de *entregables* en el sentido de "no declarar cierre", no de *no creerle a un agente*.

**Por dónde llega la regla al trabajo real, entonces** (esta es la respuesta a "cero usos ≠ inútil"):
- El propio SKILL la enuncia como regla dura en su línea 8-10 — y el skill se LEE aunque no se invoque.
- **Tres skills hermanas la citan por wikilink** y así la arrastran a sus procedimientos:
  `consolidar-cerebro:33` y `:97-98` (Fase 2 entera), `construir-missing-manual:105`, `positivar-doc:116`.
- **`orquestar-fanout:99`** reescribe su tesis con otras palabras: *"Verifica ANTES de creer — incluida la
  BASE del commit. El reporte de un agente NO es evidencia"*.

**Conclusión:** el diagnóstico del dueño es correcto — *debe* ser norma — pero por una razón distinta y peor
que la que él creía. No es "hace su trabajo sin ser invocado porque ya es norma"; es **"se aplica de rebote,
porque cuatro skills la citan, y depende de que estés corriendo una de esas cuatro"**. En un turno donde un
agente reporta y no estás dentro de una consolidación ni de un fan-out documentado, nada la trae. Ese es el
hueco real. → Ver §4.1 y §5.5.

### 1.3 · `construir-missing-manual` **NO tiene cero usos**: tiene 3, el último hace 3 días — CONFIRMADO

No estaba en la lista de ceros del encargo, pero sí en el grupo "Doc" que se me pidió mirar como candidato a
consolidación. Está vivo (2026-09-14). No es candidato a muerte.

### 1.4 · Los cuatro auditores **NO tienen tu añadido de hoy en `develop`** — CONFIRMADO

Se me dijo *"acabo de añadirles contenido a los cuatro hoy, así que mide la versión de develop"*. En `develop`
los cuatro fueron tocados por última vez:

| skill | último commit en develop |
|---|---|
| `auditar-proceso-algoritmo` | `327e4b3` 2026-09-10 |
| `auditar-coherencia-cerebro` | `e9b8bbd` 2026-09-08 |
| `auditor-semantico` | `e1c143f` 2026-08-21 |
| `auditar-suficiencia-operativa` | `34fba8a` 2026-08-02 |

El añadido de hoy vive en **cuatro ramas sin mergear** (`docs/auditores-lecciones-wg`,
`docs/auditor-coherencia-lecciones`, `docs/auditor-suficiencia-lecciones`, `docs/auditor-semantico-lecciones`,
todas 2026-09-17). Medí `develop` como se me pidió **y además** medí el delta de esas cuatro ramas, porque la
segunda mitad de la instrucción era *"si mi añadido aumentó el solapamiento, dilo"*. La respuesta está en §2.5.

---

## 2 · LA TABLA CENTRAL — quién hace qué

`usos` = suma de `skillUsage` de `~/.claude.json` agregando las claves con prefijo de worktree.
`←cita` = cuántas skills lo referencian por `[[wikilink]]`.

| # | Skill | OBJETO (el sustantivo que manipula) | Verbo | usos | ←cita | tier |
|---|---|---|---|---|---|---|
| 1 | `auditar-proceso-algoritmo` | un FLUJO/algoritmo (de app o de sistema) | auditar (FMEA) | 11 | 2 | global |
| 2 | `auditar-coherencia-cerebro` | el CEREBRO como sistema (guards+charts+doc) | auditar (consistencia) | 3 | 4 | global |
| 3 | `auditar-suficiencia-operativa` | las TAREAS que una doc debe habilitar | auditar (operabilidad) | 4 | 2 | global |
| 4 | `auditor-semantico` | el CÓDIGO vs la intención de negocio | auditar (semántica) | 1 | **0** | global |
| 5 | `consolidar-cerebro` | una CAMPAÑA de limpieza de cerebro | orquestar | **0** | 1 | global |
| 6 | `canonizar-cerebro` | la ESTRUCTURA de un cerebro instanciado | migrar a la firma | **0** | **0** | global |
| 7 | `unificar-cerebro` | el DELTA de `.claude/` entre minis de devs | reconciliar (semanal) | **0** | **0** | global |
| 8 | `checkpoint` | el HILO efímero → disco | escribir/volcar | **80** | 1 | both |
| 9 | `rehidratar-hilo` | el HILO en disco → contexto | leer/anunciar/retomar | 3 | **0** | both |
| 10 | `to-do` | el BACKLOG durable → HUD del harness | poblar/redactar | 1 | **0** | both |
| 11 | `cosechar-sesion` | el TRANSCRIPT → inbox de aprendizajes | appendear | 2 | **0** | global |
| 12 | `cerrar-slice` | un SLICE terminado → develop | verificar/integrar/cosechar | **0** | **4** | both |
| 13 | `turno-nocturno` | una NOCHE desatendida | contratar/pacear | 7 | 1 | global |
| 14 | `orquestar-fanout` | N AGENTES en paralelo | asignar/aislar/reportar | 2 | 4 | global |
| 15 | `revisar-entregables-agentes` | el REPORTE de un agente | verificar contra realidad | **0** | 3 | global |
| 16 | `positivar-doc` | el ORDEN dentro de una doc | reordenar (SÍ antes que NO) | 1 | 3 | global |
| 17 | `desinflar-memorias` | el VOLUMEN de una doc | colapsar narrativa a lección | 2 | 4 | global |
| 18 | `construir-missing-manual` | un MANUAL que no existe | fabricar por fan-out | 3 | **0** | global |
| 19 | `investigar-dominio` | un ECOSISTEMA ajeno | volverse experto + auditar decisiones | **0** | 1 | global |
| 20 | `diagramar` | un FLUJO → diagrama | dibujar (.dot/yEd o mermaid) | 2 | 4 | global |
| 21 | `claude-proyecto-autocontenido` | DÓNDE vive el cerebro de un proyecto | definir convención | **0** | **0** | global |
| 22 | `reubicar-master` | una sesión master | MUDAR de repo | 1 | **0** | global |
| 23 | `ingenieria-inversa-gui-db-navegador` | un legacy GUI+BD sin fuentes | documentar por diff | 1 | **0** | global |
| 24 | `markdown-a-pdf` | un `.md` → PDF | convertir | **0** | **0** | global |
| 25 | `zoom-screenshot` | un screenshot ilegible | recortar/ampliar | **0** | **0** | global |

**Lectura de la tabla:** la columna OBJETO es la que decide. **No hay dos skills con el mismo objeto.** Los
solapamientos que existen son de BLOQUES (secciones duplicadas entre skills de objeto distinto), no de skills
enteros. Eso es lo que hace que la respuesta correcta sea casi siempre *delimitar*, no *fusionar*.

### 2.1 · Grupo AUDITORES — 1 solape real acotado, 2 falsos

**`auditar-proceso-algoritmo` ↔ `auditar-coherencia-cerebro`: SOLAPE REAL, ya declarado, mal resuelto → DELIMITAR.**
CONFIRMADO por autodeclaración cruzada:
- `auditar-coherencia-cerebro:3` y `:19-21`: *"Es la aplicación al cerebro de la metodología de
  auditar-proceso-algoritmo (**su modo «un SISTEMA»**), empaquetada y repetible."*
- Y `auditar-proceso-algoritmo:50-52` conserva ese mismo modo: *"**(B) Un SISTEMA / el propio cerebro** —
  barre un sistema entero por inconsistencias y huecos (el caso brain: hooks/skills/normas/docs…)"*.

Es decir: el modo (B) de la #1 **es** la #2 entera, y la #2 lo dice. Peor, la dependencia ya se invirtió:
`auditar-proceso-algoritmo:87-91` delega su propia «Regla de oro» a la hermana — *"Detalle, con el caso que
lo destiló: [[auditar-coherencia-cerebro]] → «Regla de oro» y «El ENTREGABLE del auditor»"*. La #1 ya no es
autosuficiente para el modo que dice tener.

- **Recomendación: DELIMITAR.** `auditar-proceso-algoritmo` suelta el modo (B) y queda como la metodología
  FMEA aplicada a flujos de NEGOCIO/algoritmos; una línea remite al cerebro. Es quitar ~8 líneas de la #1, no
  fusionar 290.
- **Se gana:** deja de haber dos puertas al mismo trabajo (hoy un Claude que quiere auditar el cerebro puede
  entrar por la #1 y perderse los "zapatos" del cerebro, la regla de EJECUCIÓN en sandbox y el loop de
  convergencia, que son ~120 líneas que solo tiene la #2).
- **Se pierde:** la #1 deja de ser autocontenida para el caso "auditar un sistema que NO es el cerebro" (una
  arquitectura ajena). Hoy el modo (B) sirve de puerta genérica. Mitigable dejando el modo (B) en una línea
  que diga "para un sistema cualquiera, misma metodología; para el cerebro, [[auditar-coherencia-cerebro]]".

**La DUPLA (`coherencia` ↔ `suficiencia`): FALSO SOLAPAMIENTO en el núcleo — pero con un anexo que SÍ se pisa.**

El núcleo es genuinamente disjunto, y la prueba es la unidad de análisis:
- coherencia audita **ARTEFACTOS** (¿este `.dot` refleja este `.sh`? ¿este guard se evade?) → `:84-89`.
- suficiencia audita **TAREAS** derivadas de 4 canteras (`:31-36`) — *"No audites «los archivos»: audita las
  tareas"* (`:31`). Su valor declarado es *"el 80%"* está en derivar la lista.

El caso que lo demuestra, citado en `consolidar-cerebro:88-91`: *"6 documentos perfectamente coherentes entre
sí prometiendo un candado que NO existía"*. **No inventes una fusión aquí: las dos lentes son reales.**

**PERO** — `auditar-suficiencia-operativa:58-62` ("§4. Empaqueta la barrida de higiene en la misma pasada")
le anexa exactamente el mandato de coherencia: *"Contradicciones · punteros colgados (cruza los `[[wikilinks]]`
contra los archivos que EXISTEN) · índices desfasados · datos que mienten · duplicación"*. Y su prompt lo
repite (`:99-101`). Como la norma dura es que **van JUNTAS SIEMPRE** (`consolidar-cerebro:80`), en cada corrida
real hay **dos agentes en paralelo cazando punteros colgados**.

- **Recomendación: DELIMITAR** — el §4 de suficiencia se marca *"solo si corres SOLA; en la DUPLA lo cubre
  coherencia"*. Cambio de 2 líneas.
- **Se gana:** se deja de pagar un agente duplicado por corrida, y los dictámenes dejan de reportar el mismo
  hallazgo dos veces (que luego hay que dedupear — `auditar-coherencia-cerebro:111` ya lo admite: *"sintetiza
  (dedup + severidad)"*).
- **Se pierde:** suficiencia corrida sola queda más flaca. Por eso la recomendación es condicionar, no borrar.

**`auditor-semantico`: FALSO SOLAPAMIENTO — y su problema es el opuesto.** Objeto distinto (CÓDIGO vs
intención de negocio), y es el ÚNICO de los cuatro con **maquinaria determinista propia**
(`scripts/auditor-semantico/ejecutar.sh` + `checks/*.sh` + `invariantes-semanticos.yml`, `:26-29`,`:38-43`).
Comparte con los otros tres solo la palabra "auditor".
- **Su patología real es el AISLAMIENTO, no el solape:** `0` wikilinks salientes y `0` entrantes — el único
  skill del árbol con ambos en cero. Nadie lo rutea y él no rutea a nadie. `consolidar-cerebro` enumera 10
  skills que orquesta (`:27-36`) y **no lo incluye**, pese a que su Fase 5 (FMEA) es justo "cuando se audita
  LÓGICA".
- **Recomendación: NO FUSIONAR. Delimitar con una línea en cada uno de los otros tres** ("yo audito docs/
  proceso; el CÓDIGO vs la intención lo audita `auditor-semantico`") y añadirlo al mapa de `consolidar-cerebro`.
- **Se pierde:** nada material; son 4 líneas de texto. **Se gana:** deja de ser invisible (1 uso en 13 meses
  con motor construido y mantenido es desperdicio de una inversión real).

### 2.2 · Grupo "CEREBRO" — aquí está el solape MÁS DURO

**`consolidar-cerebro` Fase 6 ↔ `canonizar-cerebro`: SOLAPE DURO Y YA DIVERGENTE → DELIMITAR con transferencia.**

CONFIRMADO, y en tres capas:

1. **Autodeclaración de subordinación… sin contraparte.** `canonizar-cerebro:44-47`: *"Como el **paso
   ESTRUCTURAL (Fase 6 «la FIRMA»)** dentro de [[consolidar-cerebro]]"*. Pero:
   ```
   grep -n "canonizar" brain/skills/consolidar-cerebro/SKILL.md → 0 hits
   ```
   **`consolidar-cerebro` nunca menciona a `canonizar-cerebro`.** El apretón de manos es de una sola mano.

2. **La misma especificación, escrita dos veces.** `consolidar-cerebro:160-254` (~95 líneas) especifica la
   firma canónica: la tabla de 3 capas, la ESTRUCTURA CANÓNICA del `CLAUDE.md` con su plantilla, el GRADIENTE
   DE ESTABILIDAD, el procedimiento de DESTILAR el TOC. `canonizar-cerebro:18-40` y `:87-97` especifica **la
   misma firma canónica** con su propia plantilla.

3. **Y ya divergieron** — que es el costo que el solapamiento siempre cobra:

   | | `canonizar-cerebro` | `consolidar-cerebro` Fase 6 |
   |---|---|---|
   | secuencia del `CLAUDE.md` | `🎯 Misión → 🧠 Antes de construir → 📁 Dónde va cada cosa → 🖋️ FIRMA → 🛡️ Reglas duras → @import MEMORY.md` (`:24-27`) | `intro-IDENTIDAD → dónde-va-cada-cosa → ÁRBOL (cercado) → detalle` (`:197-199`) |
   | taxonomía de memorias | `dom-/dev-/ux-/qa-` + núcleo, **invariante 1:1** (`:28-38`) | **no existe** |
   | `@import MEMORY.md` | obligatorio (`:27`) | no se menciona |
   | verificación | **detector determinista** `verificar-firma-canonica.sh` con batería en `test-brain.sh` bloque `g5` (`:108-115`) | "criterio de cierre" (`:220`) |

   Dos docs que dicen ser la definición de la firma canónica, y **solo una tiene el detector que la hace
   cumplir**. Un cerebro canonizado por la receta de `consolidar-cerebro` fallaría el detector de
   `canonizar-cerebro`.

- **Recomendación: DELIMITAR con transferencia.** La Fase 6 de `consolidar-cerebro` colapsa a ~10 líneas:
  *"el paso estructural es [[canonizar-cerebro]]; corre su detector `verificar-firma-canonica.sh`"* + lo que
  es genuinamente de la campaña y no de la estructura (el "prompt bello de arranque", `:251-254`; el criterio
  de LISTO, `:256-262`). `canonizar-cerebro` queda como el dueño único de la spec, porque es el que tiene el
  mecanismo (norma del cerebro: *"toda norma nace con su mecanismo"*).
- **Se gana:** una sola definición de la firma; se mata una divergencia VIVA que hoy produce cerebros
  incompatibles según qué skill leas; `consolidar-cerebro` baja de 301 a ~215 líneas y se vuelve legible.
- **Se pierde:** `consolidar-cerebro` deja de ser leíble de corrido como manual completo — quien lo lea tendrá
  que abrir un segundo archivo en la Fase 6. Ese es el costo real de todo puntero, y aquí lo considero pagado
  con creces (95 líneas de spec duplicada y ya divergente).
- **Riesgo a nombrar:** `canonizar-cerebro` está pensado para cerebros **INSTANCIADOS** (`:8`: "cps, fluxcore,
  plantilladotnet"), mientras `consolidar-cerebro` también aplica a cerebros no-git (Drive) y al meta-repo.
  La transferencia debe conservar esos casos o quedarían huérfanos. **No es un copy-paste; es una decisión con
  filo.**

**`unificar-cerebro`: FALSO SOLAPAMIENTO con los otros dos.** Objeto completamente distinto: el DELTA de
`.claude/` entre las minis de varios devs, con clasificación por clase de archivo, `merge=union`, y el MR de
la mini a develop (`:30-68`, `:109-117`). Nada que ver con la estructura ni con la campaña de limpieza. Él
mismo delimita contra su vecino real: *"Objeto y disparador DISTINTOS de `cerrar-slice` → es su HERMANA, no
su extensión"* (`:15-17`).
- **Su problema es otro y hay que decirlo:** `0` usos, `0` wikilinks entrantes, y **nadie lo menciona**
  (`grep "unificar-cerebro"` en `consolidar-cerebro` y `canonizar-cerebro` → 0). Solo `cosechar-sesion:13` lo
  nombra en prosa. Es la definición de **"nadie sabe que existe"**, no de "solapado".
- Además declara un disparador que hay que verificar: *"El hook `recordar-unificar-cerebro` (SessionStart)
  avisa cuando el delta supera el umbral"* (`:26-27`). **Si ese hook no existe, el skill no tiene ningún
  disparador automático y su cero es explicado.** No lo verifiqué — cae en la lente del agente de
  obsolescencia. `[PLAUSIBLE]`
- **Recomendación: ninguna fusión.** Es un ritual de EQUIPO en un repo compartido; su cero se explica por
  falta de disparador, no por redundancia. Dejarlo.

**Respuesta directa a la pista del encargo:** *"Los tres hablan de dejar un cerebro sólido/canónico/
reconciliado"*. Medido: **solo dos hablan de lo mismo** (consolidar y canonizar, y en un bloque concreto).
`unificar-cerebro` comparte la palabra "cerebro" y nada más.

### 2.3 · Grupo CONTINUIDAD — el más sano del árbol, y sí respeta la división

**Verdicto: FALSO SOLAPAMIENTO, demostrado.** La división de las normas globales no solo se respeta: cada
skill la reenuncia y apunta a sus hermanas.

| skill | escribe/lee | archivo que gobierna | cita cruzada |
|---|---|---|---|
| `checkpoint` | ESCRIBE | `hilo-mental-actual.md` (+ barre a `estado-proyecto.md`) | `:10` "la mitad «leer» la hace el hook `rehidratar-hilo`" |
| `rehidratar-hilo` | LEE + anuncia | el mismo hilo | `:41-46` "Par con checkpoint" |
| `to-do` | deriva | `estado-proyecto.md` → HUD del harness | `:94` cita checkpoint |
| `cosechar-sesion` | appendea | `aprendizajes.md` (otro archivo) | `:15-18` "hermana de cerrar-slice, no la reemplaza" |

Cuatro archivos distintos, cuatro verbos distintos. **La flecha está explícita y en una sola dirección**
(`checkpoint:60-65`: *"hilo (volátil) → SUBE al backlog (durable), NUNCA al revés"*). No hay nada que fusionar.

**Dos observaciones que sí salen de medir:**

1. **`rehidratar-hilo` (skill) es casi todo cáscara → candidato a NORMA.** 47 líneas, de las cuales el
   contenido propio son 6: correr el `.sh` del hook, anunciar una línea, tratarlo como memoria propia,
   continuar. Lo dice él mismo: *"este skill NO re-implementa la lógica — corre el mismo `.sh` del hook"*
   (`:15-17`); su único aporte es *"la capa de COMPORTAMIENTO (anunciar + retomar)"* (`:17`).
   **La asimetría de uso es la evidencia:** el hilo se ESCRIBE 80 veces (checkpoint) y el skill que lo
   RETOMA se invocó 3, la última el **2026-07-14** (hace 2 meses). Nadie invoca un skill al retomar — por
   definición, al retomar no sabes que hay algo que retomar.
   → **PROMOVER A NORMA** (o a una línea imperativa en el `additionalContext` del propio hook): *"al retomar,
   ANUNCIA en una línea de qué íbamos y CONTINÚA desde el Siguiente paso"*. Es conducta permanente, no
   procedimiento.
   **Se pierde:** el fallback manual documentado (`:25-33`, el comando con `jq` para cuando el canal de hooks
   se rompe) — eso sí es procedimiento y debería sobrevivir en algún lado. Sugerencia: el fallback se queda
   como 4 líneas dentro de `checkpoint` ("si al retomar no ves el hilo, córrelo a mano así"), y el skill muere
   con lápida `retirado`.

2. **`to-do` está duplicado por la norma del HUD.** Ver §4.2 — es el caso más limpio de "la norma se quedó con
   el procedimiento".

### 2.4 · Grupo DOC — falso solapamiento, con UNA regla escrita tres veces

**`positivar-doc` ↔ `desinflar-memorias`: FALSO SOLAPAMIENTO, y son complementarios por diseño.**
Operaciones opuestas sobre los mismos archivos, con contratos incompatibles a propósito:
- positivar **preserva el 100%** y solo reordena (`:99-100`: *"Es REORDENAR + reencuadrar, NUNCA borrar"*).
- desinflar **corta** narrativa y manda mitos al cementerio (`:19-50`).

Se citan mutuamente (`positivar-doc:56-60` → desinflar; `desinflar-memorias:D76` → positivar) y
`consolidar-cerebro:118-124` los encadena en el orden correcto (positivar → desinflar). **No fusionar:** un
skill que reordene-y-corte a la vez perdería la garantía de preservación que es el valor entero de positivar.

**PERO — la regla del GRADIENTE DE ESTABILIDAD está escrita TRES veces. CONFIRMADO:**
- `positivar-doc:77-80` y `:93-98` — *"el `CLAUDE.md` es INTOCABLE salvo su sección `## Reglas duras`…
  `CLAUDE.md`=`main` · `MEMORY.md`=`develop` · memorias=ramitas"*
- `desinflar-memorias:D43-D46` — el mismo párrafo, casi palabra por palabra
- `consolidar-cerebro:212-220` — la tercera copia, con el detalle del `verificar-arbol-sync.sh`

Tres copias de la misma regla en tres skills, y es una regla que aplica **siempre que edites cualquier doc del
cerebro**, no cuando invocas una de las tres.
→ **PROMOVER A NORMA** (una, de ~4 líneas: el gradiente + "el `CLAUDE.md` solo se toca en `## Reglas duras`")
y las tres skills la referencian.
**Se gana:** una sola copia; deja de ser posible que dos skills diverjan sobre qué se puede tocar del
`CLAUDE.md` (hoy ya hay un matiz: `canonizar-cerebro` **sí reescribe el `CLAUDE.md` entero** (`:87-93`), lo
cual es la excepción legítima a la regla que las otras dos declaran absoluta — y ninguna de las tres la nombra).
**Se pierde:** ~10 líneas de contexto permanente a cambio de ~25 de skill. Neto favorable, pero es engordar el
archivo que ya es el problema (§4). **Alternativa más barata: una copia canónica en `canonizar-cerebro`
(dueño de la firma) y punteros desde las otras dos, sin tocar el `CLAUDE.md`.** Recomiendo esta.

**`construir-missing-manual`: FALSO SOLAPAMIENTO, ya delimitado — con el apretón de manos roto.**
Su frontmatter delimita explícito contra su vecino: *"NO es investigar-dominio (eso es volverte experto +
auditar tus decisiones); esto PRODUCE el artefacto de referencia"*. Correcto y suficiente.
Pero: `construir-missing-manual:105` afirma que investigar-dominio *"te INVOCA a TI como su paso de fabricar
la referencia"*, y
```
grep -n "missing-manual" brain/skills/investigar-dominio/SKILL.md → 0 hits
```
**`investigar-dominio` no lo menciona nunca.** Es el mismo patrón que canonizar↔consolidar: subordinación
declarada de un lado, ignorada del otro. Arreglo de 1 línea.
No pertenece al grupo "Doc" (no infla ni adelgaza: **fabrica**). La pista del encargo —*"uno infla, otro
adelgaza, otro reordena"*— es imprecisa: `construir-missing-manual` no reordena nada, y el que reordena es
`positivar-doc`.

### 2.5 · Grupo CIERRE — `cerrar-slice` con cero usos: explicado, y NO es inútil

**`cerrar-slice` es el skill MÁS CITADO del árbol** (4 wikilinks entrantes, 10 menciones) **y el que más veces
se ejecuta sin invocarse.** Su cero tiene tres causas medidas, no una:

1. **Sus pasos ya son HOOKS.** Él mismo lo declara (`:8-11`): *"Lo refuerzan los hooks Stop (`dod-verificar`),
   `git-branch-guard`, `confirmar-merge-develop` y `recordar-dashboard` (en el push te recuerda el dashboard +
   doc=realidad = **el Paso 2 de aquí**)"*. Cuando cierras un slice, los cuatro guards te llevan por el
   camino aunque no invoques nada. **Esto es "hace su trabajo sin ser invocado", genuino.**
2. **Su §2 lo hace `checkpoint`,** que se invoca 80 veces. Declaración recíproca y explícita:
   `cerrar-slice:35` *"Este paso ES el «volcado» del skill `checkpoint`"* ↔ `checkpoint:3` *"Es el «volcado
   compartido» que cerrar-slice §2 también hace"*.
3. **Su §4 (receta git) está también en el `CLAUDE.md` global**, que se carga siempre → ver §4.3.

**Entre lo 1, 2 y 3 queda descubierto exactamente §5 (cosecha de aprendizaje y de HERRAMIENTAS) y el bloque
"Backlog COMPLETO, no solo lo elegido" (`:46-59`)** — y esos son, justamente, los pasos que el propio skill
identifica como imposibles de automatizar: *"Un hook puede recordar este paso, pero no juzgar si cosechaste
bien"* (`:175-176`), *"Un hook no puede juzgar si tu lista de delegados quedó completa → paso EXPLÍCITO de
esta skill"* (`:57-58`).

- **Recomendación: DELIMITAR, no matar.** (a) §2 colapsa a *"corre [[checkpoint]] nivel COMPLETO"* + las 3
  cosas que checkpoint NO hace (mover el ítem a HECHO con commit+fecha, el dashboard global, limpiar
  worktrees). (b) §4 pierde el recetario duplicado con el `CLAUDE.md` y se queda con lo que SOLO está aquí:
  el contrato del `--squash-message` (`:126-144`) y el porqué de no usar `--auto-merge` (`:115-124`), que son
  conocimiento real y único. (c) §1, §3 y §5 intactos.
- **Se gana:** cerrar-slice baja de 176 a ~110 líneas y queda siendo lo que de verdad aporta: el contrato del
  mensaje de squash + la cosecha. Se elimina la tercera copia del recetario git.
- **Se pierde:** deja de ser el manual de cierre autocontenido. Hoy alguien que lo abre tiene todo; después
  tendría que abrir `checkpoint`. Dado que checkpoint es el skill más usado del sistema (80), el costo es bajo.
- **Y una regla suya debe SUBIR:** *"lo DELEGADO a un artefacto TAMBIÉN va al backlog"* (`:51-59`) es
  conducta permanente. Hoy vive medio en la norma (`global-claude-md.md:178-202`) y medio aquí, con el mismo
  caso real citado en los dos lados. Ver §4.4.

**`turno-nocturno`: FALSO SOLAPAMIENTO.** Objeto distinto (el contrato de una noche desatendida: pacing de
cuota, autorización durable a disco, relanzador). **Consume** checkpoint en vez de duplicarlo (`:182`: *"Corre
el skill `checkpoint`"*). 7 usos, el 3er skill más usado. Sano. No tocar.

### 2.6 · ¿Tu añadido de hoy aumentó el solapamiento? SÍ, en un punto concreto — CONFIRMADO

Las cuatro ramas de hoy suman +229 líneas. La mayoría aterriza bien y **el reparto es correcto**: la rama
`docs/auditores-lecciones-wg` mandó las lecciones de SUPERVISIÓN de agentes ("distinguir trabajando de
colgado", "un agente agotado se releva") a `orquestar-fanout` y no al auditor — que es donde van. Eso está bien
hecho.

**Pero el mismo hallazgo se plantó en dos skills el mismo día:**
```
docs/auditores-lecciones-wg      : auditar-proceso-algoritmo:130  "Definido ≠ cableado. Seis de once
                                    predicados de verificación existían y nadie los invocaba…"
docs/auditor-semantico-lecciones : auditor-semantico:79           "Pasada barata y sistemática:
                                    definido ≠ invocado. Es el hallazgo semántico más rentable…"
```
Misma lección, dos archivos, dos ramas, el mismo día. Es exactamente el modo de falla de trabajar en ramas
paralelas sobre skills hermanas.
→ **Recomendación:** antes de mergear las cuatro, decidir **una** casa para "definido ≠ invocado" (mi voto:
`auditor-semantico`, que es el que tiene el motor determinista donde eso puede volverse un `check/` ejecutable
en vez de prosa) y en la otra dejar el puntero.

**Segundo efecto, más sutil:** el bloque nuevo *"Lo que un banco VERDE no prueba (corpus medido, sep-2026)"*
(+25 líneas a `auditar-proceso-algoritmo`) es **la evidencia de campo de la norma global "Los tests miden si
el código hace lo que DEBE hacer"** (`global-claude-md.md:221-249`), que cita el mismo caso (*"un arnés de 1011
asertos daba PASS · 0 FAIL"*). No es un duplicado literal —la norma da el principio, el skill da 6 casos
medidos— pero **es el mismo cuerpo de conocimiento creciendo en dos lugares a la vez**. Ver §4.5, donde
propongo el corte que los reconcilia.

---

## 3 · LOS CEROS, EXPLICADOS UNO POR UNO

El encargo pide distinguir *"nadie lo necesita"* de *"hace su trabajo sin ser invocado"* de *"nadie sabe que
existe"*. Los 9 ceros, clasificados con su evidencia:

| skill | ←cita | diagnóstico | evidencia |
|---|---|---|---|
| `cerrar-slice` | **4** | **Ritual HUÉRFANO DE DISPARADOR** (parcialmente cableado) | 4 hooks ejecutan sus pasos (`:8-11`); §2 lo hace checkpoint (80 usos); §4 está en el `CLAUDE.md` global. **Pero §3, §5 y el «backlog completo» no los cubre ningún hook, y `confirmar-merge-develop`/`dod-verificar` no lo nombran** → §5.3 |
| `revisar-entregables-agentes` | **3** | **Formato equivocado** (debe ser norma) | 3 skills lo citan; su regla NO está en ningún `CLAUDE.md` (§1.2) |
| `consolidar-cerebro` | 1 | **Formato correcto, disparador raro** | es una campaña de días; se invoca 1-2 veces al año por diseño |
| `canonizar-cerebro` | **0** | **Nadie sabe que existe** | su "padre" declarado (`consolidar-cerebro`) no lo menciona nunca (§2.2) |
| `unificar-cerebro` | **0** | **Cableado, pero el aviso no mueve nada** | `recordar-unificar-cerebro` **existe** (CONFIRMADO, `SessionStart`, tier `repo`) y aun así 0 usos — el caso más puro de §5.2 |
| `investigar-dominio` | 1 | **Nadie lo necesita HOY** | encargo de días; su hermana `construir-missing-manual` sí se usa (3) — el trabajo se está haciendo por la otra puerta |
| `claude-proyecto-autocontenido` | **0** | **Referencia, no procedimiento** | 403 líneas de convención; se consulta leyendo, no invocando |
| `markdown-a-pdf` | **0** | **Nadie lo necesita** — y hay un competidor | `md-a-tex-pdf` existe instalado y NO está en `brain/skills/` ni en el MANIFEST. Dos skills de PDF, uno fuera del brain |
| `zoom-screenshot` | **0** | **Nadie lo necesita** — 36 líneas, utilidad de nicho | además cita `[[steam-ui-referencia]]`, que no existe en `brain/skills/` |

**Regla que sale de la tabla (revisada tras §5):** hay que cruzar DOS columnas más — `←cita` y **¿cable?**. Un cero con citas está vivo por lectura; un cero con cable está vivo por evento… salvo que el cable sea un AVISO, en cuyo caso no está vivo por nada (§5.2). El cero solo es sospechoso cuando va acompañado de **←cita 0**. Los cuatro
skills con cero-usos **y** cero-citas (`canonizar`, `unificar`, `markdown-a-pdf`, `zoom-screenshot`, más
`claude-proyecto-autocontenido`) son los únicos donde el cero significa algo. Los que tienen citas están vivos
por otra vía.

**Candidatos a tier `retirado` (lápida) — decisión del dueño, NO ejecutada:**
- `zoom-screenshot` — 0/0, 36 líneas, utilidad que hoy hace `ffmpeg` a mano o el propio Read de imágenes.
  **Se pierde:** el comando exacto de recorte, que costaría re-derivar. Mitigable: 3 líneas en otra skill.
- `markdown-a-pdf` — 0/0, **pero antes hay que decidir su relación con `md-a-tex-pdf`**, que está instalado y
  fuera del MANIFEST. Matar el del brain sin resolver eso deja el sistema peor. **No recomiendo tocarlo hasta
  que se decida cuál de los dos es el canónico** — eso es una decisión de routing, no de solapamiento.

**NO recomiendo retirar** `canonizar-cerebro` ni `unificar-cerebro` pese a su 0/0: el primero tiene el
**detector determinista** que hace cumplir la firma (matarlo mataría el mecanismo); el segundo es el único
ritual de equipo del árbol. Sus ceros se arreglan con **punteros**, que cuestan 2 líneas, no con lápidas.

---

## 4 · EL `CLAUDE.md` GLOBAL (`brain/norms/global-claude-md.md`)

**463 líneas · 6 113 palabras · 39 KB.** Se carga entera en cada sesión de cada máquina del equipo.

Las 6 secciones más caras concentran el 61% del archivo:

| líneas | sección | ¿regla o procedimiento? |
|---:|---|---|
| 55 | Flujo de git | regla (20) + **receta (35)** |
| 50 | Definición de "LISTO" | regla — íntegra, es el contrato del sistema |
| 48 | Integridad de los guardarraíles | regla (31) + **procedimiento (17)** |
| 45 | Tu lista de TODOs es TU HUD | regla (12) + **procedimiento (33)** |
| 41 | Cerebro por-repo = CORREO | regla (23) + **tabla de tiers (18)** |
| 34 | Orquesta: delega lo paralelizable | regla (6) + **procedimiento (28)** |
| 29 | Los tests miden lo que DEBE hacer | regla (7) + **checklist (22)** |

**≈ 153 líneas (33%) son procedimiento** — se pagan siempre y sirven cuando toca. Ese es el hallazgo central
de esta mitad de la auditoría.

### 4.1 · PROMOVER A NORMA: la regla de `revisar-entregables-agentes` (híbrido)

El caso que detonó la ampliación del encargo, y el diagnóstico se confirma aunque la premisa fuera falsa (§1.2).

- **Sube al `CLAUDE.md` (≈4 líneas):** *"El reporte de un agente es una AFIRMACIÓN, no un hecho. Antes de
  relatarlo al usuario o construir encima, verifica sus afirmaciones concretas contra la realidad; lo no
  verificado se etiqueta «según el agente, sin verificar». Verde de agente ≠ verificado."* Es la formulación
  del propio skill, `:8-10`.
- **Se queda como skill (el procedimiento):** el bucle de 5 pasos (`:20-39`), la heurística barato/caro
  (`:41-45`) y sobre todo **el DIFF DE PRESERVACIÓN** (`:47-63`) — 17 líneas que son puro procedimiento y que
  solo aplican cuando un agente REEMPLAZA un archivo.
- **Se gana:** la regla deja de depender de que estés dentro de una de las 4 skills que la citan. Cubre el
  caso frecuente (un agente reporta en un turno cualquiera).
- **Se pierde:** +4 líneas permanentes en todas las máquinas. Justificado por el criterio de coste del propio
  encargo: en un flujo de trabajo con fan-out, "un agente reporta" pasa varias veces al día.

### 4.2 · DEGRADAR A SKILL: el procedimiento del HUD (norma 419-445, 45 líneas)

**Duplicación CONFIRMADA con `to-do`.** La norma y el skill dicen lo mismo:

| | norma `:419-445` | `to-do` |
|---|---|---|
| HUD = scratch, backlog = fuente de verdad | `:428-433` | `:56-58` (Regla 1) |
| "si divergen, manda `estado-proyecto.md`" | `:432-433` | `:58` |
| re-siembra al rotar rama/cwd + hook `hud-stale` | `:441-445` | `:59` |
| los dos puentes (sembrar al arrancar / vaciar al cerrar) | `:435-438` | `:92-95` (Relación) |

- **Se queda en la norma (≈8 líneas):** los tres planos y su jerarquía (HUD scratch · hilo · backlog durable),
  la regla de precedencia, y "re-evalúa el HUD al rotar de rama". Eso gobierna siempre.
- **Baja al skill `to-do`:** cuándo abrirla (≥3 pasos), la mecánica de los dos puentes, el detalle del hook.
- **Se gana:** −33 líneas permanentes; una sola casa para el procedimiento.
- **Se pierde:** `to-do` tiene **1 uso** — si el procedimiento baja a un skill que nadie invoca, el
  procedimiento deja de leerse. **Este es el contraargumento serio y hay que decirlo:** la norma puede estar
  funcionando precisamente *porque* está en el contexto permanente. Recomiendo bajar solo la parte
  inequívocamente procedimental (los dos puentes, el formato) y conservar en la norma la regla + el anti-drift,
  que es el que el dueño enunció como dura (*"NO QUIERO DRIFT NUNCA"*, `:441`).

### 4.3 · SOLAPE DURO: la receta de git está en dos lados **y ya se contradicen** — CONFIRMADO

El hallazgo más grave de esta sección. La norma trae una tabla de comandos:

```
global-claude-md.md:293-294
| abrir PR/MR  | gh pr create --base develop --fill | glab mr create --target-branch develop --fill |
| mergear (auto-merge + squash) | gh pr merge --squash --auto | glab mr merge --squash --auto-merge |
```

Y `cerrar-slice` prescribe lo contrario, con una sección entera explicando por qué:

```
cerrar-slice:104   glab mr merge <id> --squash …   # SIN --auto-merge: merge YA, no encolado
cerrar-slice:110   gh pr merge <id> --squash       # SIN --auto: merge YA, no encolado
cerrar-slice:115-124  "### Por qué SIN --auto-merge … arma Merge When Pipeline Succeeds: el merge NO
                       ocurre al correr el comando, queda ENCOLADO para dispararse solo, sin testigo …
                       confirmar-merge-develop exige tu OK del instante del merge; encolarlo rompe esa
                       garantía. (Visto al mergear el !112 de cortex: quedó en MWPS pese al OK explícito.)"
```

**La norma global recomienda el flag que la skill prohíbe por romper un guard de supervisión.** Hay un matiz
que lo explica en parte (la fila de la norma describe el caso "1–3 devs, auto-merge" del §4 genérico, mientras
cerrar-slice habla de la integración coordinada a `develop`), pero **la tabla de la norma no marca esa
distinción**, y el `CLAUDE.md` de `plantilladotnet` además declara que a develop va **SIN `--auto-merge`**.
Un Claude que lea solo la norma hará lo que el guard existe para impedir.

- **Recomendación: DELIMITAR.** La norma se queda con las **6 reglas numeradas** (`:277-286`: nunca push a
  base, todo por ramitas, MR/PR, el tamaño del equipo decide revisión no push, squash al integrar, main
  release-only) — eso gobierna siempre y son ~20 líneas. **La tabla de comandos y el mapeo `glab`/`gh` bajan a
  `cerrar-slice §4`,** que ya es su dueño real (tiene el contrato del `--squash-message`, la trazabilidad
  rama→commit y los gotchas de `git commit -F`).
- **Se gana:** −35 líneas permanentes y, sobre todo, **se cierra una contradicción activa** entre dos docs del
  propio cerebro sobre un comando que toca un guard de supervisión.
- **Se pierde:** un colega que clona un repo compartido sin el brain global ve las reglas pero no los comandos.
  **Mitigado por diseño:** `cerrar-slice` es tier **`both`** — viaja por-repo justo a los repos compartidos
  (`MANIFEST:` línea `cerrar-slice both`). El comando llega igual.
- ⚠️ **Esta contradicción no la resuelvo yo:** cuál de las dos es la correcta (¿auto-merge sí en la mini, no a
  develop?) es una decisión del dueño sobre el flujo. Lo que afirmo es que **hoy dicen cosas distintas**.

### 4.4 · FUSIÓN PARCIAL dentro de la norma: las dos mitades de "nada se queda en el chat"

`## Ningún hallazgo TUYO se queda solo narrado en el chat` (25 l, `:178-202`) y
`## Ninguna DECISIÓN se queda solo en el chat` (10 l, `:203-212`) — **35 líneas para dos mitades de una regla,
que se declaran hermanas entre sí** (`:179`: *"Su HERMANA para lo que deciden JUNTOS… abajo"*; `:204`:
*"Hermana de la de arriba"*).

- **Recomendación: FUSIONAR en una sección** (`## Nada se queda solo en el chat`) con un preámbulo común y dos
  corolarios cortos. Estimado ~18 líneas, −17.
- **Se gana:** deja de haber dos encabezados que el lector debe diferenciar para aplicar la misma conducta.
- **Se pierde:** **esto es fusión de verdad y tiene el riesgo clásico** — el corolario grave de la primera
  (*"no inventes el corte que el usuario nunca puso"*, `:189-196`) es una regla de alto valor que hoy tiene su
  propio bloque visible; enterrada en una sección fusionada pierde relieve. **Si el dueño valora ese corolario
  por encima de las 17 líneas, la recomendación correcta es NO fusionar.** Lo presento como decisión con filo,
  no como mejora obvia.
- **Nota:** la primera dice *"Mecanismo: vive en `cerrar-slice`"* (`:195`) y `cerrar-slice:46-59` la reenuncia
  entera con el mismo caso real (la auditoría de 3 agentes / 10 hallazgos). Tercera copia parcial. Al fusionar,
  `cerrar-slice` debería quedarse solo con el PASO ("bárrelos a `estado-proyecto.md` con severidad y origen
  ANTES de cerrar") y soltar la justificación.

### 4.5 · DEGRADAR A SKILL (parcial): el checklist de la norma de tests

Verifiqué lo que el encargo pedía verificar — *"si ese ida y vuelta entre seeder, `CLAUDE.md` global y skills
está creando duplicados"*:
```
grep -rn "puede fallar alguna vez|FALLA contra el código viejo|EFECTO, no el andamio|dos direcciones"
  brain/skills/  →  ningún hit de esas frases (solo un "dos direcciones" no relacionado en auditor-semantico:58)
```
**El ida y vuelta NO creó un duplicado literal. La norma es la única copia de su texto.** Corrijo esa
sospecha del encargo.

**Lo que sí hay** es que 22 de sus 29 líneas son el bloque *"Cómo se aplica al escribir un test"* (`:237-248`):
6 bullets de checklist accionable. Eso es procedimiento — se necesita cuando escribes un test, no siempre. Y su
evidencia de campo está creciendo **en un skill** (el bloque nuevo de `auditar-proceso-algoritmo`, §2.6).

- **Recomendación: la norma se queda con el PRINCIPIO y el corte** (`:221-236`, ~15 líneas: la pregunta
  correcta, el corte plomería/propósito, el caso 1011-asertos que la hace dura). **El checklist de 6 bullets
  baja** a donde se usa: `cerrar-slice §1` (donde corres los tests) o el bloque nuevo de
  `auditar-proceso-algoritmo` (donde se audita un banco de pruebas).
- **Se gana:** −14 líneas permanentes; el checklist queda junto a su evidencia de campo en vez de separado de
  ella.
- **Se pierde:** el checklist es lo ACCIONABLE de la norma; sin él la norma es una tesis. Si baja a
  `cerrar-slice` (0 usos) puede dejar de leerse — mismo riesgo que §4.2. **Mi recomendación honesta aquí es la
  más conservadora de todo el dictamen: dejarla como está.** Es de las normas más recientes y con más
  respaldo empírico; tocarla por 14 líneas no vale el riesgo. La listo porque el encargo la nombró
  explícitamente y merece respuesta medida, no porque recomiende moverla.

### 4.6 · Duplicación con los MANIFEST: la regla de tiers, en 4 lugares — CONFIRMADO

```
grep -rl "¿global o both?" brain/  →  brain/hooks/MANIFEST · brain/skills/MANIFEST
                                      brain/norms/global-claude-md.md · brain/test-brain.sh
```
La regla *"¿esta skill/hook la usaría un colega en un repo COMPARTIDO sin brain global? SÍ → both, NO →
global"* está escrita en los dos MANIFEST (que se autodeclaran **fuente única**: `skills/MANIFEST:2` *"FUENTE
ÚNICA del cerebro"*), en la norma (`:358-375`, 18 líneas) y en el test.

- **Recomendación: quitarla de la norma**, dejando 2 líneas ("el tier lo fija el MANIFEST; su cabecera trae la
  regla"). Es la regla que necesitas **exactamente cuando editas el MANIFEST** — donde ya está, a la vista.
- **Se gana:** −16 líneas permanentes, y se honra la declaración de fuente única que los propios MANIFEST hacen.
- **Se pierde:** un Claude que decide el tier "de memoria" sin abrir el MANIFEST perdería la guía. Riesgo bajo:
  no se puede asignar un tier sin editar el MANIFEST.

### 4.7 · Otros dos, menores

- **`## Un comentario inline INFORMA…` (15 l, `:148-162`)** se autodeclara *"Corolario de «toda norma nace con
  su mecanismo», aplicado al código"* — y su padre son 7 líneas (`:141-147`). El corolario pesa el doble que
  la norma. Es una regla de **estilo de código** (cuándo un comentario se gana su lugar), no de operación del
  cerebro. **PLAUSIBLE candidato** a bajar a una skill de estilo o al `AGENTS.md` de los repos de código.
  Se pierde: es reciente (2026-09-15) y probablemente todavía está corrigiendo un hábito activo. **Sugiero
  esperar.**
- **`### Bitácora de falsos positivos de los guards` (17 l, `:125-140`)** es un procedimiento exacto (appendea
  esta línea, con este formato, a este archivo, con `>>`). Vive dentro de "Integridad de los guardarraíles".
  La REGLA es una línea (*"cuando un guard frene EN FALSO, regístralo en el corpus"*); el resto es el how-to.
  **Candidato a degradar**, con el matiz de que el disparador es impredecible (un FP ocurre sin aviso) y por eso
  tenerlo en contexto permanente tiene defensa.

---

## 5 · EL EJE QUE FALTABA: ¿NORMA, SKILL INVOCADO o SKILL CABLEADO?

La pregunta correcta para cada skill no es solo *"¿se solapa?"* sino **"¿existe un momento en el flujo donde
esto SIEMPRE debería correr, y hoy depende de que alguien se acuerde?"**. Lo mide esta sección.

Los tres formatos, con su precio:

| formato | cuándo se paga | cuándo se aplica |
|---|---|---|
| **Norma** (`CLAUDE.md`) | cada sesión, para siempre | siempre |
| **Skill invocado** | solo al invocarlo | cuando alguien se acuerda |
| **Skill CABLEADO** | en el evento | en el punto exacto del flujo |

### 5.1 · INVENTARIO: qué está cableado hoy y con qué resultado — CONFIRMADO

Cruzando `brain/hooks/MANIFEST` + `ev_de()` de `install-brain.sh:207-226` y `sincronizar-cerebro.sh:121-134`
contra los contadores de uso:

| skill | ¿cable? | hook | evento | el hook ¿AVISA o HACE? | usos |
|---|---|---|---|---|---|
| `checkpoint` | **SÍ** | `checkpoint-mecanico` + `aviso-contexto` | `PreCompact` / `PostToolUse` | **HACE** (escribe el andamio) + avisa | **80** |
| `rehidratar-hilo` | **SÍ** | `rehidratar-hilo` (homónimo) | `SessionStart` | **HACE** (inyecta el hilo, pasivo) | 3 |
| `cosechar-sesion` | **SÍ** | `recordar-cosechar` | `Stop` | **HACE** el espejo del tasklist + **AVISA** la cosecha | 2 |
| `to-do` | **SÍ** | `hud-stale` | `SessionStart` + `PostToolUse\|Bash` | AVISA | 1 |
| `orquestar-fanout` | **SÍ** | `recordar-orquestar` | `PostToolUse` | AVISA (*"ADVISORY puro"*, `:1`) | 2 |
| `unificar-cerebro` | **SÍ** | `recordar-unificar-cerebro` | `SessionStart` | AVISA (umbral de delta) | **0** |
| **`cerrar-slice`** | **NO** | — | — | — | **0** |
| `revisar-entregables-agentes` | **NO** | (`delegacion-reporte` es de estado, no de verificación) | — | — | **0** |
| los otros 17 | NO | — | — | — | 0–11 |

Corrijo de paso mi propio §7.6: `recordar-unificar-cerebro` **SÍ existe** (`hooks/MANIFEST`, tier `repo`,
`SessionStart`). Queda CONFIRMADO, no PLAUSIBLE.

### 5.2 · EL DATO QUE CAMBIA LA RECOMENDACIÓN: avisar NO mueve el contador

Este es el hallazgo que quiero que pese más que mi opinión. **El cable de tipo AVISO ya está desplegado en
cuatro skills**, y el resultado es medible:

```
recordar-cosechar        (Stop, nudge 1×/día/repo)  → cosechar-sesion   : 2 usos, último 2026-07-29
recordar-unificar-cerebro(SessionStart, umbral)     → unificar-cerebro  : 0 usos
recordar-orquestar       (PostToolUse, grind serial)→ orquestar-fanout  : 2 usos
hud-stale                (SessionStart + Bash)      → to-do             : 1 uso
                                                      ─────────────────────────
                                                      TOTAL             : 5 usos
```

Cuatro hooks avisando, cinco invocaciones. Frente a eso, `checkpoint` con **80**. La diferencia no es que
checkpoint tenga mejor aviso: es que **su hook hace trabajo real**. `checkpoint-mecanico.sh` escribe el
andamio solo, *"detached, cero tokens de modelo"* (`checkpoint:272-275`), y deja el 🗂️ árbol, los mensajes de
commit y las citas del usuario ya en disco. El skill no compite contra el olvido: llega y encuentra media
tarea hecha.

Y hay un segundo control interno que lo confirma: **`recordar-cosechar` hace las dos cosas a la vez** y solo
una funciona. Su encabezado (`:2-15`) describe (a) un **ESPEJO automático** que vuelca los pendientes del
tasklist a `estado-proyecto.md` *"sin fricción, determinista, NO usa LLM"*, y (b) un **NUDGE** de "corre
`/cosechar-sesion`". El espejo corre solo y funciona; el nudge lleva 2 invocaciones en 13 meses. **El mismo
hook, el mismo evento, el mismo repo: lo que HACE funciona, lo que AVISA no.**

> **Conclusión medida:** proponer "un `recordar-cerrar-slice`" sería el **quinto aviso**, y hay cuatro
> puntos de datos diciendo que no movería el contador. La recomendación que sigue evita ese error.

### 5.3 · `cerrar-slice` — el cable correcto NO es un aviso nuevo

**El diagnóstico del dueño es correcto: el evento existe y el hook existe.** Lo verifiqué:

```
grep -i "cerrar-slice|ritual|memoria|bitacora|cosech"  brain/hooks/confirmar-merge-develop.sh → 0 hits
grep -i "cerrar-slice|cosech"                          brain/hooks/dod-verificar.sh           → 0 hits
```

**Los dos hooks que disparan exactamente en el instante de cerrar un slice no nombran el ritual ni una vez.**
`confirmar-merge-develop` frena justo cuando se autoriza el merge a develop —el momento que el dueño
identifica— y solo pide el OK. `dod-verificar` (Stop) hace cumplir la definición de LISTO, que **es el §1 de
`cerrar-slice`**, y tampoco lo nombra. El único hook que lo menciona es `recordar-dashboard:18`, y de refilón,
en la coletilla final de un recordatorio sobre otra cosa: *"Esto es parte de CERRAR bien el slice (skill
cerrar-slice)"*. Existen cuatro hooks `recordar-*` en el árbol y **ninguno es para el skill más citado del
sistema** (4 wikilinks, 10 menciones).

- **Recomendación: CABLEAR — pero convirtiendo el gate que YA frena en el portador del ritual, no añadiendo
  un aviso.** `confirmar-merge-develop` ya bloquea y ya exige una respuesta del modelo en ese instante: es el
  único punto del flujo donde el trabajo **se detiene** a esperar. Que su mensaje de bloqueo, además de pedir
  el OK, **enumere el checklist de `cerrar-slice` que ningún otro hook cubre** — que son exactamente tres,
  porque el resto ya está cableado:
  - §1 verificación → lo cubre `dod-verificar` (Stop)
  - §2 dashboard + doc=realidad → lo cubre `recordar-dashboard` (PreToolUse/Bash del push)
  - §4 flujo de git → lo cubren `git-branch-guard` + `merge-squash-guard`
  - **§2 «backlog COMPLETO, no solo lo elegido» + «lo delegado a un artefacto» → SIN CABLE**
  - **§5 cosecha de lecciones Y de HERRAMIENTAS → SIN CABLE**
  - **§3 «el entorno desplegado debe contener TODO lo que pides revisar» → SIN CABLE**

  Y esos tres son, palabra por palabra, los que el propio skill identifica como **imposibles de automatizar**:
  *"Un hook puede recordar este paso, pero no juzgar si cosechaste bien"* (`:175-176`); *"Un hook no puede
  juzgar si tu lista de delegados quedó completa → paso EXPLÍCITO de esta skill"* (`:57-58`). **El skill ya
  sabía cuál era su parte no-cableable. Lo que nunca se hizo fue ponerla en la boca del hook que sí frena.**

- **Se gana:** el ritual deja de depender de la memoria en el único punto donde el flujo se detiene a esperar
  una respuesta — que es cualitativamente distinto de un aviso que se lee de pasada (los 4 avisos existentes
  no frenan nada; este ya frena). Y no se añade ni un hook ni un evento nuevo: se enriquece un mensaje.
- **Se pierde / el impuesto:** `confirmar-merge-develop` dispara en **PreToolUse/Bash** sobre todo
  `glab mr merge`/`gh pr merge` — incluidos los merges de ramita→mini-develop, donde el ritual completo **no
  toca**. Si el checklist se imprime siempre, se vuelve ruido en el caso frecuente y la gente aprende a
  saltárselo — que es cómo mueren los avisos. **Mitigación:** el hook ya es *target-aware* (lo declara el
  `CLAUDE.md` de plantilladotnet: *"un merge a `develop` pide una marca de confirmación normal; un RELEASE a
  `main` exige una marca SUPER explícita"*), así que puede imprimir el checklist **solo cuando el destino es
  `develop`/`main`** y callar en los merges a la mini. Sin eso, el cable es un impuesto.
- ⚠️ **Límite duro:** esto toca un **guard de supervisión**. La norma de Integridad de los guardarraíles exige
  OK explícito del dueño **para ESE control** y solo admite cambios de precisión. Añadir texto informativo a un
  mensaje de bloqueo no afloja nada —el gate sigue exigiendo lo mismo— pero **la decisión es suya, no mía, y
  no la ejecuto.**

### 5.4 · `cosechar-sesion` — ya está cableado; el problema es el MODO, no el cable

El dueño propone cablearlo a `SessionEnd`. Dos precisiones medidas:

1. **`SessionEnd` existe y ya se usa** — CONFIRMADO: `install-brain.sh:224`
   `exportar-sesion-master) echo "Stop| SessionEnd| PreCompact|"`. La premisa es correcta.
2. **Pero `cosechar-sesion` YA tiene su cable**: `recordar-cosechar` en `Stop`
   (`sincronizar-cerebro.sh:126`), y `Stop` dispara **en cada turno**, que es más frecuente que `SessionEnd`,
   no menos. **Mover el cable a `SessionEnd` no arreglaría nada: el problema no es que no se avise, es que
   avisar no basta** (§5.2). Y `SessionEnd` es peor punto para un ritual que necesita juicio: es el momento en
   que la sesión se va, sin turno del modelo garantizado para pensar — el mismo defecto por el que
   `PreCompact` fue descartado como canal (`checkpoint:270-272`).

- **Recomendación: NO re-cablear a `SessionEnd`. Ampliar la parte que HACE.** El espejo de `recordar-cosechar`
  ya demuestra el patrón ganador: volcar determinísticamente lo mecánico para que el skill solo aporte juicio.
  El análogo para la cosecha existe y está construido: **`checkpoint-mecanico.js` ya extrae del transcript las
  citas textuales del usuario, los archivos tocados y los commits** (`checkpoint:67-85`). Eso es precisamente
  la materia prima del Paso 1 de `cosechar-sesion` (*"relee tu sesión y separa el grano de la paja"*). Un
  andamio de candidatos-a-aprendizaje escrito solo, al que el modelo solo le ponga el criterio, es el mismo
  movimiento que llevó a checkpoint de 0 a 80.
- **Se pierde:** trabajo real de implementación (no es cambiar un `ev_de`), y riesgo de que el andamio genere
  ruido que haya que filtrar. **Se gana:** el patrón está validado en el mismo repo por dos casos (el andamio
  de checkpoint, el espejo del tasklist).

### 5.5 · La pregunta a los 25: ¿quién más tiene un momento natural sin cable?

Aplicando *"¿existe un momento en el flujo donde esto SIEMPRE debería correr?"*:

| skill | momento natural | ¿hay cable? | veredicto |
|---|---|---|---|
| `cerrar-slice` | autorización del merge a develop | NO (el gate existe, mudo) | **CABLEAR** (§5.3) |
| `revisar-entregables-agentes` | cuando un agente reporta — `PostToolUse\|Task\|Agent` | NO para verificar (`delegacion-reporte` está ahí pero es de estado) | **NORMA + cable**: el evento existe y ya tiene hook. Ver §4.1 |
| `cosechar-sesion` | fin de tanda | SÍ (Stop) | cable OK, **modo equivocado** (§5.4) |
| `unificar-cerebro` | delta de mini > umbral | SÍ (SessionStart) | cable OK, **aviso sin efecto**: 0 usos |
| `to-do` | rotar rama/cwd | SÍ (`hud-stale`) | cable OK, aviso |
| `checkpoint` | antes de compactar | SÍ (hace) | **el modelo a imitar** |
| `canonizar-cerebro` | **su detector podría ser gate de release** | NO | **CABLEAR (candidato fuerte)** — el skill lo propone él mismo: *"Alimenta el GATE del auditor (#44) … en modo gate, `--strict` bloquea un release si un cerebro instanciado drifteó"* (`:112-114`). Es determinista, barato y ya tiene batería en `test-brain.sh` (bloque `g5`). **Explica su 0 mejor que cualquier teoría: el detector existe, el gate nunca se conectó.** |
| `positivar-doc`, `desinflar-memorias`, `auditar-*`, `consolidar-cerebro` | — | NO | **NO cablear**: son campañas deliberadas, caras y con criterio. Un cable aquí sería un impuesto puro. |
| `diagramar`, `markdown-a-pdf`, `investigar-dominio`, `reubicar-master`, `zoom-screenshot`, etc. | — | NO | **NO cablear**: bajo demanda por naturaleza. Correcto como están. |

**Regla que sale de medir, y que conviene asentar como criterio:**
- Si el ritual necesita **JUICIO** → el hook **HACE la parte mecánica** y deja el juicio al modelo
  (checkpoint, cosechar). Avisar solo, no.
- Si el ritual es **DETERMINISTA** → el hook **lo ejecuta como gate** (el detector de `canonizar-cerebro`).
- Si el ritual es **caro y deliberado** → **sin cable**, y su 0 no es patología (consolidar, los auditores).
- Y **ningún aviso más**: cuatro desplegados, 5 usos. Un quinto aviso es un quinto ruido.

### 5.6 · Un hallazgo colateral del inventario: los recordatorios son tier `repo`

`recordar-cosechar` y `recordar-unificar-cerebro` son tier **`repo`** (`hooks/MANIFEST`) = *"solo por-repo, se
cargan únicamente si la sesión INICIA en ese repo"*. Pero las skills que recuerdan son `global`/`both`. Es
decir: **el recordatorio de cosechar no existe fuera de los repos con la copia del cerebro**, mientras el
ritual sí aplica en todos. `[PLAUSIBLE]` como explicación parcial del 2 de `cosechar-sesion`: en buena parte
de las sesiones el nudge ni siquiera está cargado. Vale medirlo antes de rediseñar nada.

---

## 6 · TABLA DE DECISIONES (ninguna ejecutada)

| # | Qué | Veredicto | Δ líneas | Riesgo |
|---|---|---|---|---|
| 1 | `consolidar-cerebro` Fase 6 ↔ `canonizar-cerebro` | **DELIMITAR** (transferir spec al dueño del detector) | −85 en skill | MEDIO — hay casos (no-git, meta-repo) que no debe perder |
| 2 | receta git: norma `:288-296` ↔ `cerrar-slice §4` | **DELIMITAR** (receta baja a la skill) | −35 permanentes | **ALTO — hay una contradicción viva que el dueño debe resolver primero** |
| 3 | `revisar-entregables-agentes` | **PROMOVER A NORMA** (regla) + skill se queda con el DIFF DE PRESERVACIÓN | +4 perm / −0 | BAJO |
| 4 | `rehidratar-hilo` (skill) | **PROMOVER A NORMA** + lápida `retirado` al skill | +2 perm / −47 | MEDIO — se pierde el fallback manual si no se reubica |
| 5 | norma HUD `:419-445` ↔ `to-do` | **DEGRADAR A SKILL** (parcial) | −33 permanentes | MEDIO — `to-do` tiene 1 uso; el procedimiento puede dejar de leerse |
| 6 | gradiente de estabilidad ×3 skills | **DELIMITAR** (1 copia canónica en `canonizar-cerebro`) | −20 en skills | BAJO |
| 7 | `auditar-proceso-algoritmo` modo (B) | **DELIMITAR** (soltarlo, apuntar a coherencia) | −8 | BAJO |
| 8 | `auditar-suficiencia-operativa §4` (higiene) | **DELIMITAR** (condicionar a "si corres sola") | −2 | BAJO |
| 9 | "definido ≠ invocado" en 2 ramas de hoy | **DELIMITAR antes de mergear** | −6 | BAJO — hazlo ahora, es barato |
| 10 | regla de tiers en la norma `:358-375` | **DELIMITAR** (vive en los MANIFEST) | −16 permanentes | BAJO |
| 11 | las 2 normas "nada en el chat" | **FUSIONAR** (parcial) | −17 permanentes | **MEDIO — el corolario «no inventes el corte» pierde relieve** |
| 12 | checklist de la norma de tests | **dejar como está** | 0 | — (listado por completitud; no lo recomiendo) |
| 13 | `auditor-semantico` | **FALSO SOLAPAMIENTO** — rutearlo desde los otros 3 + `consolidar-cerebro` | +4 | BAJO |
| 14 | `investigar-dominio` → `construir-missing-manual` | **FALSO SOLAPAMIENTO** — arreglar el apretón de manos de 1 lado | +1 | BAJO |
| 15 | `unificar-cerebro`, `canonizar-cerebro` (0/0) | **NO retirar** — arreglar con punteros | +4 | BAJO |
| 16 | `zoom-screenshot` | **candidato a `retirado`** | −36 | BAJO |
| 17 | `markdown-a-pdf` | **no tocar hasta decidir vs `md-a-tex-pdf`** | — | decisión de routing, no de solape |
| **18** | **`cerrar-slice` ↔ `confirmar-merge-develop`** | **CABLEAR** — el gate que ya frena enumera los 3 pasos sin cable (§5.3) | +0 perm | **ALTO — toca un guard de supervisión: exige OK del dueño PARA ESE CONTROL; y sin filtro por destino se vuelve ruido en los merges a la mini** |
| **19** | **`canonizar-cerebro` → `verificar-firma-canonica.sh` como gate de release** | **CABLEAR** — determinista, barato, con batería `g5` en `test-brain.sh`; el propio skill lo propone (`:112-114`) | +0 perm | BAJO — es un check determinista, no un aviso |
| **20** | **`cosechar-sesion`** | **NO re-cablear a `SessionEnd`** — ya está en `Stop`, que es más frecuente; ampliar la parte que HACE (andamio de candidatos) | +0 perm | MEDIO — implementación real, no un cambio de `ev_de` |
| **21** | **cualquier `recordar-*` nuevo** | **NO** — 4 avisos desplegados, 5 usos entre todos (§5.2) | — | — |

**Ahorro potencial en contexto permanente: ~95 líneas del `CLAUDE.md` global (≈20%)**, de un techo teórico de
~150. No recomiendo perseguir el techo: las normas de LISTO, guardarraíles y mini-develop son contrato del
sistema y se pagan bien.

**Si solo se hacen tres cosas de toda esta tabla, mi orden sería:** (1) el **#18** (el cable de `cerrar-slice`
al gate que ya frena — es el hallazgo del dueño y el de mayor retorno), (2) el **#2** (la contradicción viva
del `--auto-merge` entre la norma y la skill, porque hoy hay doc que induce a evadir un guard), y (3) el
**#1** (las dos specs divergentes de la firma canónica). Las tres son riesgo activo; el resto es higiene.

---

## 7 · LO QUE ESTÁ SANO (para que nadie lo "arregle" mañana)

Registrado explícitamente, porque el encargo lo pide y porque un falso solapamiento sin documentar se vuelve
una fusión mal hecha el mes que viene:

1. **El grupo de CONTINUIDAD** (checkpoint · rehidratar · to-do · cosechar). Cuatro archivos, cuatro verbos,
   flecha única y explícita. **No fusionar nada aquí.**
2. **`positivar-doc` ↔ `desinflar-memorias`.** Operaciones opuestas con contratos incompatibles a propósito
   (preservar 100% vs cortar). Fusionarlas destruiría la garantía de preservación.
3. **`auditor-semantico` frente a los otros tres auditores.** Objeto distinto (código vs docs) y el único con
   motor ejecutable. Comparte solo la palabra "auditor".
4. **`unificar-cerebro` frente a los otros dos "cerebro".** Objeto distinto (delta entre minis de devs).
5. **`turno-nocturno` frente a `checkpoint`/`cerrar-slice`.** Consume, no duplica.
6. **`construir-missing-manual` ↔ `investigar-dominio`.** Ya delimitados en el frontmatter, correctamente.
7. **La DUPLA en su núcleo.** Auditar TAREAS ≠ auditar ARTEFACTOS. El solape es solo el §4 anexo.
8. **`cerrar-slice §5`** (cosecha de lecciones Y de herramientas) y **el bloque de backlog completo**: son
   justamente lo que ningún hook puede juzgar, y el skill lo argumenta. Intocables.

---

## 8 · PENDIENTES QUE ESTA AUDITORÍA DEJA ABIERTOS

Al backlog, no al chat (norma dura del cerebro). Salieron de medir, no estaban en el encargo:

1. **`~/.claude/CLAUDE.md` instalado está 2 secciones atrás de `develop`** — le falta `## Un comentario inline
   INFORMA…` y conserva el par viejo `Post-compact: EXCAVA` + `Paso 0: INVENTARIO` que `develop` ya fusionó en
   `## Recupera de tu contexto vivo`. CONFIRMADO por `diff` de encabezados. *(Toca la lente del agente de
   obsolescencia; lo dejo anotado, no lo toco.)*
2. **`auditar-suficiencia-operativa:113-114` afirma que `revisar-entregables-agentes` y `positivar-doc` son
   *"skill global, no vive en `brain/skills`"*.** Los dos SÍ viven en `brain/skills/`. Doc que miente, 2 líneas.
3. **`brain/skills/MANIFEST` no documenta el tier `retirado`**, que `brain/hooks/MANIFEST:11-30` sí define con
   detalle. Si alguna decisión de este dictamen termina en lápida, el mecanismo **no existe todavía del lado de
   skills**. Hay que crearlo antes, no durante.
4. **`zoom-screenshot` cita `[[steam-ui-referencia]]`**, que no existe en `brain/skills/`. Puntero colgado.
5. **`md-a-tex-pdf` está instalado y NO está en `brain/skills/` ni en el MANIFEST.** Decisión de routing
   pendiente: ¿es del brain y falta, o es local a otra máquina/repo a propósito?
6. **`recordar-cosechar` y `recordar-unificar-cerebro` son tier `repo`** mientras las skills que recuerdan
   son `global`/`both`: el recordatorio no existe fuera de los repos con la copia del cerebro (§5.6).
   `[PLAUSIBLE]` como explicación parcial de sus contadores — medir antes de rediseñar.
7. **Cuatro hooks `recordar-*` desplegados producen 5 invocaciones entre todos** (§5.2). Si se acepta el
   criterio "ningún aviso más", conviene revisar si los cuatro existentes deben migrar al patrón
   HACE-lo-mecánico o retirarse — hoy son costo de mantenimiento sin efecto medido.

---

## 9 · MÉTODO Y LÍMITES DE ESTA AUDITORÍA

- **Leídos completos:** los 12 skills de los 5 grupos señalados + `positivar-doc`, `desinflar-memorias`,
  `revisar-entregables-agentes`, `cerrar-slice`. **Leídos por encabezados/secciones frontera:**
  `orquestar-fanout`, `turno-nocturno`, `construir-missing-manual`, `investigar-dominio`. **No leídos a fondo:**
  `reubicar-master` (1 195 l), `claude-proyecto-autocontenido` (403 l), `ingenieria-inversa-gui-db-navegador`,
  `diagramar`, `markdown-a-pdf`, `zoom-screenshot` — evaluados por objeto, frontmatter y grafo de referencias.
  **Un solapamiento oculto DENTRO de esos seis no lo habría visto.** `reubicar-master`, por su tamaño (25% de
  todo el corpus de skills), es el hueco más grande de esta pasada.
- **El grafo de referencias** se construyó con `grep -o '\[\[[a-z0-9-]*\]\]'` por archivo. No captura
  referencias en prosa sin wikilink, así que los conteos `←cita` son un **piso**, no un total.
- **Los conteos de uso** agregan las claves de `skillUsage` con prefijo de worktree (p. ej.
  `code/cps/.claude/worktrees/f0-3:flujo-mr-gitlab`) al nombre base. Miden invocaciones explícitas en ESTA
  máquina; no miden lecturas, ni las otras máquinas del equipo.
- **Del lado de hooks sí medí el INVENTARIO y el CABLEADO** (`brain/hooks/MANIFEST`, `ev_de()` de
  `install-brain.sh:207-226` y `sincronizar-cerebro.sh:121-134`, más el encabezado de cada `recordar-*.sh`).
  **No ejecuté ningún hook ni skill**: no verifiqué que los cables declarados disparen de verdad, solo que
  estén declarados. Un hook cableado pero inerte se vería aquí como cableado.
- **Ninguna recomendación está aplicada.** Ningún archivo de `brain/` fue modificado en este worktree.

---

*Auditoría de solapamiento — read-only. Las decisiones son del dueño.*
