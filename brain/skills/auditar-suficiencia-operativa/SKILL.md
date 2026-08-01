---
name: auditar-suficiencia-operativa
description: Auditar una doc/cerebro por SUFICIENCIA OPERATIVA (¿puede un agente nuevo HACER las tareas sin romper nada ni re-investigar?) en vez de solo por coherencia. Enumera las tareas reales, las califica ✅/⚠️/❌ con archivo:línea, y exige RE-auditar tras arreglar. Úsalo al cerrar una sesión que cambió arquitectura o procedimientos, o cuando el usuario diga "revisa que quede bien asentado / que sepa mantenerlo". Es la mitad OPERABILIDAD de la DUPLA con auditar-coherencia-cerebro (la mitad CONSISTENCIA): van JUNTAS en un cambio a doc/sistema — ninguna caza lo de la otra.
---

# Auditar SUFICIENCIA OPERATIVA (no solo coherencia)

> **La distinción que lo hace valer.** Una auditoría de **coherencia** pregunta *"¿se contradicen los
> documentos?"*. Una de **suficiencia operativa** pregunta *"¿puede alguien que llega mañana HACER el trabajo
> con esto, sin romper nada y sin volver a investigar?"*. **Un cerebro puede estar perfectamente coherente y
> ser inútil** — todo verdadero, nada accionable, el conocimiento disperso en 19 archivos sin una rutina.
> Esta skill audita lo segundo.

## Por qué existe (caso real, games-master 2026-07-30)
Tras un día enorme de cambios, dos auditorías de coherencia ya habían dado *"el cerebro TIENE SENTIDO, sin
contradicciones estructurales"*. Se hizo entonces una pasada de **suficiencia** y salieron **5 huecos que la
coherencia no ve**, uno de ellos el más importante del día:
- **NO existía ninguna rutina de mantenimiento.** Todo era verdad y estaba escrito… y disperso. Nadie sabía
  qué correr, cada cuándo, ni cómo verificar. → nació un skill `mantener-el-setup`.
- Un **mecanismo automático (un timer) documentado SOLO en la bitácora** — que es *log*, no *doc*. Nadie sabría
  que existe. **Lección: lo que vive solo en el log, no existe operativamente.**
- Un **README que mentía** por omisión (listaba 2 máquinas de 3).
- Un **truco crítico presente en un skill y ausente en su hermano** (asimetría entre docs gemelos).
- Falsos positivos en los propios detectores, que habrían gritado en cada auditoría futura.

---

## El método

### 1. Deriva la LISTA DE TAREAS (esto es el 80% del valor)
No audites "los archivos": audita **las tareas**. Sácalas de estas 4 canteras:
1. **Lo que ROMPIÓ algo** (o casi) — cada incidente es una tarea que la doc debe blindar.
2. **Lo DESTRUCTIVO** — toda operación que pueda borrar/corromper datos.
3. **Lo que COSTÓ tiempo** — cada cosa que se re-investigó o se diagnosticó a ciegas.
4. **Lo RUTINARIO** — respaldar, verificar, actualizar, restaurar. Lo aburrido es lo que se olvida.
> Escríbelas como acciones concretas ("agregar un ROM y que aparezca con arte en las 3"), no como temas
> ("documentación de ROMs"). **Si no puedes nombrar la tarea, no puedes auditarla.**

### 2. Añade siempre estas 4 tareas transversales
- **NO deshacer la arquitectura**: ¿la advertencia está donde se vería **ANTES** de actuar, no 3 archivos más allá?
- **NO resucitar lo descartado**: ¿queda explícito qué se rechazó y **por qué**? (si no, alguien lo re-propone)
- **Saber qué NO tocar**: lo ya resuelto y confirmado por QA.
- **Mantenerlo al día sin que se lo pidan**: ¿hay rutina + chequeo de salud **con valores esperados**?

### 3. Califica con ojos frescos
Delega a un agente que **NO sepa qué se tocó** y que se ponga en los zapatos de quien llega mañana: lee el
punto de entrada y de ahí lo que haga falta. Para cada tarea: **✅** (lo encuentra y le alcanza) · **⚠️**
(está pero es ambiguo/incompleto) · **❌** (no está, o lo llevaría a romper algo). **Siempre con archivo:línea.**

> **Qué ES el "punto de entrada" = la FIRMA (contra qué caminas).** No confundas dos sujetos. La **firma**
> es la **misión/capacidades de Claude aquí**: vive en `CLAUDE.md` (thin, siempre cargado) como **TOC de
> `MEMORY.md`** (el detalle operativo: memorias + router de skills). La cadena que camina esta auditoría es
> **`CLAUDE.md → MEMORY.md → la memoria/skill que apunta → realidad (código)`**, marcando el hueco
> (capacidad prometida sin método, método sin código, doc que miente). `AGENTS.md` es un **eje APARTE**: el
> contrato de **arquitectura del PROYECTO** (capas, dominio) — eso lo audita la coherencia contra el `.cs`,
> **no es la firma** y no se le cuelga la misión. (En un brain de hobby sin arquitectura pesada, `AGENTS.md`
> puede doblar de entry-point; en un repo tosco NO — no mezcles los dos sujetos.)

### 4. Empaqueta la barrida de higiene en la misma pasada
Contradicciones · **punteros colgados** (cruza los `[[wikilinks]]`/"ver el skill X" contra los archivos que
EXISTEN) · índices desfasados (¿el índice lista exactamente lo que hay?) · datos que mienten (conteos, rutas,
fechas) · duplicación (algo explicado a fondo en 2 lugares en vez de 1 canónico + punteros).
⚠️ **Narrativa histórica FECHADA es válida** — no la reportes como error.

### 5. Arregla y **RE-AUDITA con el prompt IDÉNTICO**
No autodeclares que quedó. Ver la memoria global `feedback_re-auditar-tras-arreglar` (6 contradicciones
sobrevivieron una limpieza propia). Guarda el prompt literal: si lo cambias, cambias el examen.

---

## Los patrones de fallo que esta auditoría caza (y la de coherencia no)

| Patrón | Cómo se ve | Antídoto |
|---|---|---|
| **Conocimiento sin rutina** | todo cierto, nada operable; ninguna respuesta a "¿cada cuándo?" | un skill/sección de RUTINA con cadencia y verificación |
| **Doc en el LOG** | el mecanismo existe pero solo se menciona en la bitácora | mover a la doc durable; el log solo narra |
| **Advertencia lejana** | el "🛑 no borres esto" está, pero a 3 saltos de donde se actúa | duplicar la advertencia EN el punto de acción |
| **Asimetría entre gemelos** | dos docs hermanas y el truco clave solo en una | barrer la familia entera, no el archivo que tocaste |
| **Mentira por omisión** | lista 2 de 3 máquinas; el conteo se quedó viejo | valores esperados + fecha de verificación |
| **Decisión sin lápida** | algo se descartó en el chat y nadie lo escribió | registrar **qué** se descartó y **por qué**, con "no re-proponer" |
| **Detector que grita en falso** | el propio grep/regex marca cosas válidas | arreglar el detector, no vivir con el ruido |

---

## Cómo entregarlo
1. **VEREDICTO en una línea:** ¿puede alguien nuevo operar esto sin romperlo?
2. **Tabla de tareas** con ✅/⚠️/❌ y, para cada no-✅, **qué falta y dónde debería ir**.
3. **Hallazgos de higiene** por severidad, con archivo:línea y fix de una línea.
4. **Qué quedó LIMPIO**, explícito (para saber qué NO tocar).
5. **El riesgo #1 restante:** si mañana algo se rompe por documentación, ¿qué sería?

## El prompt del auditor (pegable — destilado de la corrida DUPLA, 2026-07-31)
Delega con `Task`/subagente `general-purpose`. Adapta el target, conserva la ESENCIA:

> Eres un AUDITOR DE **SUFICIENCIA OPERATIVA** (read-only). NO auditas "los archivos", auditas si ALGUIEN
> NUEVO puede **HACER las tareas** sin romper nada ni re-investigar. Target: `<repo/doc>` (NO mutes nada; solo
> LEES). (1) Deriva la LISTA DE TAREAS reales de estas canteras: lo que ROMPIÓ algo · lo DESTRUCTIVO · lo que
> COSTÓ tiempo · lo RUTINARIO; + las 4 transversales (no deshacer la arquitectura, no resucitar lo descartado,
> saber qué NO tocar, mantenerlo al día). (2) Califica cada tarea **✅/⚠️/❌ con archivo:línea**, en los zapatos
> de quien llega mañana (lee el punto de entrada). (3) Barrida de higiene: contradicciones · punteros colgados
> (cruza cada `[[wikilink]]`/"ver skill X" contra lo que EXISTE) · índices desfasados · datos que mienten
> (conteos/rutas/fechas) · duplicación. ⚠️ narrativa histórica FECHADA es válida. (4) Entrega: veredicto en 1
> línea («¿puede alguien nuevo operar esto sin romperlo?») + tabla de tareas con qué falta y dónde debería ir +
> higiene por severidad (CRÍTICO/ALTO/MEDIO/BAJO) + qué quedó LIMPIO + el riesgo #1. **NO declaras LISTO**: tu
> dictamen es insumo. Si corres en fan-out, escribe el dictamen a un `.md` y responde SOLO 3 líneas (veredicto+conteo · hallazgos en bullets · ruta).

## Hermanas
- **`auditar-coherencia-cerebro` — la OTRA mitad de la DUPLA; va CONMIGO en todo cambio a doc/sistema.** Yo
  audito si es OPERABLE (¿alguien nuevo puede HACER las tareas sin romper ni re-investigar?); ella si es
  CONSISTENTE (¿se contradice? ¿los guards se evaden? ¿la doc miente vs el código?). **Lentes disjuntas —
  ninguna caza lo de la otra** → córrelas JUNTAS, hasta 0 CRÍTICO/ALTO/MEDIO (los BAJOS se triagean). El FMEA
  `auditar-proceso-algoritmo` es un TERCER eje (¿el algoritmo/flujo es correcto?): se SUMA cuando la capacidad
  audita lógica, no solo docs.
- `revisar-entregables-agentes` (skill **global**, no vive en `brain/skills`) — no creerle a un agente su "listo" (esta skill lo aplica al auditor mismo).
- `positivar-doc` (skill **global**, no vive en `brain/skills`) — answer-first: un doc suficiente pero enterrado sigue fallando la prueba.
- `cosechar-sesion` / `checkpoint` — de dónde salen las tareas: lo que pasó hoy.
- Memoria global `feedback_re-auditar-tras-arreglar` — la norma de la 2ª pasada.
