---
name: checkpoint
description: Volcado del estado efímero a memoria durable para poder compactar (o cerrar sesión) sin perder el hilo, en DOS NIVELES. LIGERO (pausas naturales, punto de retorno rápido) reescribe hilo-mental-actual.md —leyendo antes el previo para no pisar ideas vivas a medio cocinar— (de qué va la tarea AHORA) y GARANTIZA, antes de sobrescribir, que todo pendiente/decisión DURABLE del hilo ya esté en estado-proyecto.md + bitácora (barrido SIN PÉRDIDA: el hilo volátil sube al backlog durable, nunca al revés). COMPLETO (OBLIGATORIO antes de cualquier /compact —manual o anunciado por el aviso de contexto— y cada ~2h en corridas largas) abre con el 🗂️ ÁRBOL de memorias+tooling (3 ramas: actualizadas-hoy / a-leer-para-lo-que-sigue / tooling) al PRINCIPIO y luego agrega el DISEÑO de lo que se construye (diagnóstico + contrato de cada pieza nueva + invariante verificable + qué NO es), el PLAN COMPLETO con el CÓMO, lo RESUELTO HOY y la COSECHA DURABLE a memorias/skills. Es el "volcado compartido" que cerrar-slice §2 también hace. Ante la duda de nivel: COMPLETO.
---

# Checkpoint — vaciar lo efímero a memoria durable (sin fricción)

Un **checkpoint** vuelca lo que solo vive en el contexto del chat (frágil: se pierde al compactar) a
archivos durables en disco, para que **compactar cuanto quieras NO cueste el hilo**. Es la mitad
"escribir" del par; la mitad "leer" la hace el hook `rehidratar-hilo` (SessionStart) al retomar.

> **Por qué existe.** Al compactar se pierden DOS cosas y solo una tenía casa. El **estado del
> proyecto** (hecho/pendiente/decidido) ya vivía en `estado-proyecto.md`/`bitacora.md`. El **HILO de
> la conversación** (qué razonamos AHORA, la decisión a medio cocinar, el siguiente paso, el porqué)
> no vivía en ningún lado durable → se degradaba en cada resumen del LLM. `hilo-mental-actual.md` es
> su casa. Con el hilo en disco, la compactación deja de ser el único portador del contexto real.

## Los DOS NIVELES (y cómo elegir)

- **LIGERO** — pausas naturales, punto de retorno rápido. El hilo terso (memorias/tooling en lista
  simple + en qué estamos / decisión abierta / siguiente paso / hilos sueltos) + estado-proyecto/
  bitácora si avanzó. Cuesta segundos.
- **COMPLETO** — **OBLIGATORIO antes de cualquier `/compact`** (manual, o cuando el hook
  `aviso-contexto` anuncie que viene) **y cada ~2h en corridas largas/nocturnas**. Abre con el
  **🗂️ ÁRBOL de memorias + tooling** (ver abajo) y, además del hilo terso, el `hilo-mental-actual.md`
  crece con CUATRO secciones (DISEÑO de lo construido · PLAN COMPLETO con el CÓMO · RESUELTO HOY ·
  COSECHA DURABLE — ver abajo) y la cosecha a memorias/skills se hace COMO PARTE del checkpoint.

**Criterio de elección:** ¿viene un compact? ¿llevas >2h de corrida? ¿la implementación que sigue es
crítica? → **COMPLETO**. ¿Pausa casual entre sub-pasos? → ligero. **Ante la duda, COMPLETO**:
sub-volcar cuesta una noche de trabajo; sobre-volcar cuesta 2 minutos.

## Por qué el nivel COMPLETO existe

Un resumen de compactación trata bien la narrativa, pero AMPUTA dos cosas que solo COMPLETO repone:
- El **CÓMO** del plan — un resumen conserva "pendiente: X" pero pierde "se resolvía con Y porque Z".
  Por eso el PLAN (o el DISEÑO, ver abajo) se vuelca completo, no telegráfico.
- Lo **RESUELTO** — si no se escribe explícito, revive como pendiente fantasma tras compactar. Por eso
  la sección anti-fantasma.

El volcado va en las PROPIAS palabras del modelo (releer textual, no reconstruir desde un resumen ajeno)
y "actualizar memorias/skills" desaloja del canal volátil lo que ya tiene casa durable — reduce lo que el
compact puede perder.

## Cuándo correrlo
- **Antes de un `/compact` manual** — lo más importante. **Nivel COMPLETO, sin excepción.**
- Cuando el aviso de contexto (`aviso-contexto`) anuncie que el compact viene → **COMPLETO**.
- Cada **~2h en corridas largas/nocturnas** → **COMPLETO** (el auto-compact no avisa).
- En una **pausa natural** (terminaste un sub-paso, vas a cambiar de tema) → ligero basta.
- Cuando quieras dejar un **punto de retorno** por si la sesión se corta → ligero basta.
- ⚠️ El **auto-compact** (contexto lleno) no te avisa a TI, y `PreCompact` no puede darte un turno para
  que TÚ vuelques el juicio (no tiene canal para inyectar contexto ni pedirte actuar). Por eso el
  checkpoint es **proactivo**, no de último momento: si vienes trabajando rato, vuelca aunque no vayas a
  compactar todavía. Lo que SÍ pasa en ese evento, sin tu turno: `checkpoint-mecanico.sh` (hook de
  `PreCompact`) deja el andamio mecánico escrito — ver "Qué NO es" abajo — así que aunque el auto-compact
  te gane la carrera, el 🗂️ árbol/RESUELTO-HOY/citas del usuario no dependen solo de que TÚ alcanzaras a volcar.

## Qué hace (el volcado)

> **GARANTÍA DURA (answer-first): un checkpoint NUNCA pierde nada durable al sobrescribir el hilo.**
> `hilo-mental-actual.md` es VOLÁTIL y este volcado lo PISA — así que **antes de sobrescribirlo, barre el
> hilo y sube todo pendiente/decisión DURABLE a `estado-proyecto.md`** (o el backlog durable del repo). La
> flecha va en UNA dirección: **hilo (volátil) → SUBE al backlog (durable), NUNCA al revés** (el hilo jamás
> genera ni pisa el HUD/backlog desde la memoria volátil de un Claude — eso invertiría la fuente de verdad).
> Recién entonces el hilo se puede TIRAR sin perder nada. Mecánica y matices en el paso 2.

0. **REGENERA el andamio mecánico y LÉELO (primer paso, ambos niveles).** Antes de escribir una sola
   línea del hilo:
   ```bash
   node "$(ls ~/.local/bin/checkpoint-mecanico.js ~/.cortex/bin/checkpoint-mecanico.js 2>/dev/null | head -1)" \
        --self --ensure          # regenera SOLO si quedó atrás del transcript; si no, dice "no-op"
   cat .claude/memory/hilo-mental-actual.andamio.md
   ```
   **Corre este paso SIEMPRE, no solo cuando ya hubo un `PreCompact`:** el hook `checkpoint-mecanico`
   solo dispara en `PreCompact`, y la mayoría de los checkpoints NO vienen de una compactación (medido:
   ~5 volcados por cada compact). Sin este paso, un `/checkpoint` a mano encuentra el andamio viejo o
   ausente, sin poder distinguir cuál. Con `--ensure`, el andamio SIEMPRE está al día cuando lo lees,
   venga o no de un compact. (Dentro de un SUBAGENTE `--self` se niega a correr y lo dice: el
   `CLAUDE_CODE_SESSION_ID` que ve un subagente es el del PADRE, y regeneraría el andamio de OTRA sesión.)
   El andamio te da GRATIS y sin gastar ventana: el 🗂️ árbol de archivos tocados (los de Write/Edit y,
   aparte, los escritos desde Bash), las skills invocadas, los `git commit` del tramo y **las últimas
   citas TEXTUALES del usuario** — la materia prima de la PROCEDENCIA `[user: "…"]`, que reconstruida de
   memoria es justo donde se lava una idea tuya en la voz del usuario. Su ventana es el **TRAMO VIVO**
   (desde el último `/compact`): describe lo que está por perderse, no el acumulado de semanas.
   **NO lo copies al hilo**: es evidencia, no juicio. Lo FUSIONAS tú, con criterio, en los pasos de abajo.

1. **El HILO (siempre, ambos niveles).** Va a `.claude/memory/hilo-mental-actual.md` (créalo si no
   existe: `mkdir -p .claude/memory`). No es log ni backlog — es "de qué va ESTO ahora mismo".

   **LEE el hilo previo ANTES de sobrescribir (read-before-overwrite — paso OBLIGATORIO).** El archivo
   existe justo para cargar ideas a medio cocinar a través de un compact; pisarlo a ciegas puede BORRAR
   el único vestigio de una. Así que antes de reescribir, lee sus secciones vivas ("Decisión abierta",
   "Siguiente paso", "Hilos sueltos") y **fusiona en el volcado nuevo lo que el nuevo NO cubra.** Para
   cada ítem del hilo previo ausente del volcado nuevo, el criterio conservar-vs-descartar es:
   - **¿Sabes POR QUÉ ya no está?** (lo resolviste / se decidió / quedó superado esta tanda — puedes
     nombrar qué pasó) → descártalo; su cierre vive en `RESUELTO HOY`.
   - **¿NO puedes dar cuenta de él?** (no lo reconoces, no sabes qué le pasó — señal de que se cayó del
     contexto) → **consérvalo textual en el volcado nuevo**: el hilo en disco es su posible ÚNICO rastro.
   - **Ante la duda, CONSERVAR.** Arrastrar un ítem de más cuesta una línea que luego se limpia sin
     costo al reconstruir el estado real; perder una idea la pierde para siempre.

   Estructura (el 🗂️ ÁRBOL y las cuatro últimas secciones, SOLO en nivel COMPLETO):
   ```markdown
   # Hilo mental actual
   > Se REESCRIBE conservando lo vivo del previo, no se appendea. Última actualización: <FECHA> · rama <rama> · nivel <ligero|COMPLETO>.
   > Si el hilo pasa de ~200 líneas: corta el excedente a `hilo-mental-actual-overflow.md` y AVÍSALO aquí (ver "Regla de OVERFLOW" abajo).

   ## 🗂️ ÁRBOL — memorias y tooling (SIEMPRE al principio · LÉELO PRIMERO al rehidratar)
   <!-- LIGERO: basta una LISTA simple de las memorias/skills/scripts que el tema toca, cada una con su RUTA, agrupada por sub-tema. -->
   <!-- COMPLETO: el ÁRBOL de 3 ramas, en un bloque de código para leerlo de un vistazo (modelo de la firma-árbol del CLAUDE.md canónico): -->
   ```
   📁 MEMORIAS ACTUALIZADAS HOY (<fecha>) — <dónde viven: ramita/MR/repo si aplica>
   ├─ <ruta de la memoria> ......... <qué cambió, en UNA línea>
   └─ ...
   📁 INSUMOS A LEER PARA LO QUE SIGUE — <de qué tarea/expediente, con su ruta base>
   ├─ <ruta> ....................... <por qué leerlo / qué aporta>
   └─ ...
   🔧 TOOLING INTEGRADO / RELEVANTE
   ├─ <script/skill/herramienta + RUTA> ... <qué hace / estado (desplegado, en MR, pendiente)>
   └─ <accesos y comandos clave (ssh, URLs, puertos)>
   ```
   ## En qué estamos AHORA
   <1-3 líneas: la tarea viva y su porqué>
   ## Decisión abierta / lo que razonamos
   <la pregunta a medio cocinar, opciones sobre la mesa>
   ## Siguiente paso concreto
   <la próxima acción — con punto de entrada al código si aplica>
   ## Hilos sueltos / no olvidar
   <pequeños pendientes de contexto que el resumen perdería>

   <!-- ▼ SOLO nivel COMPLETO ▼ -->
   ## DISEÑO — el modelo de lo que se está construyendo
   <Por cada pieza NUEVA en construcción (no cada vez que el hilo se toca — solo mientras hay una
    construcción en vuelo): diagnóstico de fondo en UNA frase · contrato (qué recibe, qué devuelve, qué
    pasa cuando FALLA) · la invariante VERIFICABLE que lo sostiene · qué NO es. Con PROCEDENCIA. Ver
    detalle abajo.>
   ## PLAN COMPLETO (con el CÓMO)
   <TODO lo planeado, ítem por ítem: qué + el MECANISMO de resolución pensado + detalles, gotchas y
    porqués — a fidelidad completa, en TUS propias palabras. NO telegráfico: es lo que te vas a
    releer para re-instanciarte tras el compact. Cada ítem lleva su PROCEDENCIA (ver abajo).>
   ## RESUELTO HOY (no reabrir)
   <decisiones tomadas + su porqué + su PROCEDENCIA en una línea cada una. El ANTI-FANTASMA: lo que
    está aquí NO se re-pregunta ni se re-descubre después de compactar.>
   ## COSECHA DURABLE (hecha en esta tanda)
   <qué se promovió EN ESTE checkpoint a su casa durable — memorias del proyecto, skills tocados —
    con sus rutas. La promoción se hace COMO PARTE del checkpoint completo, no "después".>
   ```
   Pon la **FECHA real** (córrela con `date` de bash, NO el metadato de sesión): `rehidratar-hilo` la muestra al retomar para que juzgues si el hilo quedó viejo.

   **VERIFICA el contrato al terminar de escribir (paso mecánico, 1 comando).** El footer
   `> Última actualización: <AAAA-MM-DD> · rama <rama> · nivel <x>` no es decoración: `rehidratar-hilo`
   decide con él si tu hilo se reinyecta como VIGENTE o degradado a "⚠️ POSIBLEMENTE OBSOLETO". Medido el
   2026-09-11 sobre los 9 hilos reales de `~/code`: **2 de 9 no lo traían** ⇒ su hilo VIGENTE se presenta
   como obsoleto en cada rehidratado. Córrelo y arregla lo que marque:
   ```bash
   . ~/.claude/hooks/contrato-hilo.sh && verificar_hilo .claude/memory/hilo-mental-actual.md
   ```

   **🗂️ ÁRBOL de memorias + tooling al PRINCIPIO (regla dura).** El hilo SIEMPRE abre con las memorias
   durables + herramientas/scripts que el tema toca, **cada una con su RUTA** — es la lista "lee esto al
   rehidratar" (antídoto a declarar "ya rehidraté" sin leer la memoria del tema, lección cara) y evita
   re-grepear el árbol cada vez. Va como PRIMERA sección, antes de "En qué estamos". La FORMA depende del
   nivel:
   - **LIGERO** — una **lista simple** con rutas, agrupada por sub-tema. Basta para un punto de retorno rápido.
   - **COMPLETO** — el **🗂️ ÁRBOL de 3 ramas** en un bloque de código (modelo de la firma-árbol del
     `CLAUDE.md` canónico), para que se lea de un vistazo: **📁 MEMORIAS ACTUALIZADAS HOY** (lo que tocaste
     esta tanda, con su ramita/MR) · **📁 INSUMOS A LEER PARA LO QUE SIGUE** (lo que hay que abrir para
     retomar la tarea activa) · **🔧 TOOLING INTEGRADO / RELEVANTE** (scripts/skills/accesos, con su estado).
     La prosa "sin drama" (En qué estamos / Decisión abierta / Siguiente paso …) va DESPUÉS del árbol.
   - **Tras el árbol va la VISTA /to-do (backlog por estatus) — regla dura.** Sección `## 📋 BACKLOG`, derivada
     de `estado-proyecto.md`: **🟢 ATACABLE** (madurez 📘/📝/➖ + dónde el plan) → **🟡 NO atacable** (por qué +
     qué lo desbloquea) → **✅ Cerrado esta sesión** (PR/decisión → ítem). Es una VISTA de `estado-proyecto.md`; si diverge, CONCILIA Y REINTENTA.
   - **Anti-drift (sub-regla dura): cuando una memoria se MUEVE / FUSIONA / RENOMBRA, sincroniza el árbol/
     lista en la MISMA tanda** — igual que `RESUELTO HOY` registra el cambio, el puntero de MEMORIAS debe
     reflejarlo, o se contradicen dentro del mismo hilo y la lista deja de ahorrarte el grep (su único
     propósito). Es doc=realidad aplicado al propio hilo. Y al CONTESTAR "¿qué memorias hay de X?",
     **arranca de esta lista como HUD** y verifica/extiende contra disco — no grepees desde cero ignorándola.

   **DISEÑO de lo construido (regla dura, SOLO nivel COMPLETO, mientras haya una pieza nueva en vuelo).**
   Un plan dice QUÉ vas a hacer y con qué MECANISMO; el diseño dice qué idea de fondo sostiene la
   construcción. Sin él, quien retoma (tú mismo tras compactar, o un sucesor) hereda punteros a archivos,
   no el modelo — y tiene que releer las fuentes para reconstruirlo, exactamente el trabajo que este
   skill existe para evitar. Por cada pieza nueva:
   - **Diagnóstico de fondo, en UNA frase.** El problema real que se resuelve, no el síntoma.
   - **Contrato de cada pieza nueva.** Qué recibe, qué devuelve, y qué pasa cuando FALLA (silencioso,
     aborta, reintenta). Sin el contrato de falla, un sucesor no puede distinguir "así se diseñó" de "se
     rompió".
   - **La invariante VERIFICABLE que la sostiene.** Una condición medible — la que un test o un grep
     podría confirmar — no una intención ("debería quedar bien").
   - **Qué NO es.** Las confusiones probables: el objetivo mal-leído que alguien podría asumir al ver el
     código a medias. (Ejemplo del patrón: "el updater ya no escribe `/etc/hosts`" leído como el
     objetivo, cuando el objetivo real es que escriba CANALIZADO — dejar de escribir sería la FALLA, no
     el logro.)
   Va **EN el hilo**, nunca solo en un archivo aparte que el hilo apunte: un puntero sobrevive al
   compact, el modelo no. Si el diseño de fondo vive en un dictamen/doc largo, EXTRAE aquí el resumen
   operativo (los cuatro puntos de arriba) — el puntero al doc completo es un EXTRA, no un sustituto.
   Con PROCEDENCIA igual que el PLAN (ver abajo). **Nivel LIGERO:** no lleva esta sección estructurada;
   si hay una decisión de diseño a medio cocinar, basta una línea del diagnóstico + qué-NO-es bajo
   "Decisión abierta" — la versión completa (contrato + invariante) es de COMPLETO.

   **⚠️ Regla de OVERFLOW (>~200 líneas) `[SIN CONFIRMAR — dato de docs, validar el límite exacto]`.** El
   import/autostart del hilo al arrancar sesión **trunca pasando las ~200 líneas**. Si `hilo-mental-actual.md`
   supera ~200 líneas, corta el excedente a `hilo-mental-actual-overflow.md` (mismo dir) y **MENCIÓNALO en las
   primeras líneas del hilo principal** ("…continúa en overflow"), para que el rehidratado sepa que hay más y
   lo lea. En el principal deja lo VIVO (🗂️ árbol de memorias/tooling, en qué estamos, decisión abierta,
   siguiente paso, **y el DISEÑO** — es corto y es el modelo que todo lo demás necesita para tener sentido);
   al overflow van PLAN/RESUELTO/COSECHA extensos.

   **⭐ Estándar de calidad — 9 ejes (canónicos; corpus de pedidos reales en `corpus-checkpoint-frases.local.md`).**
   Un buen checkpoint es: **COMPLETO** (nada del hilo fuera — incluye el DISEÑO de lo construido, no solo
   el plan) · **MINUCIOSO** (las minucias que si no re-descubrirías)
   · **ACCIONABLE** (datos/rutas/comandos/siguiente-paso, no descripción) · **DURABLE** (en piedra, para NO
   necesitar desinflado) · **SIN EDITORIALIZAR** (seco, solo hechos) · **SIN RESUMIR** (literales, no comprimir)
   · **SEGUIDO/PROACTIVO** (antes del techo, no de último momento) · **A SUS CASAS** (a cada destino durable que
   toque) · **CON PROCEDENCIA**. Anti-patrones: volátil · editorializado · resumido · escatimado en detalle
   técnico · contaminado con temas irrelevantes · de último momento.

   **PROCEDENCIA de cada idea (regla dura — el hilo mental DE LA IDEA, no solo el stub).** Cada ítem del
   DISEÑO, del PLAN y cada decisión de RESUELTO llevan de DÓNDE salió y QUIÉN la originó, con un marcador
   breve:
   `[user: "<cita textual>"]` si es del usuario · `[INFER-mío]` si es una hipótesis/propuesta TUYA (de
   Claude) · `[juntos <fecha>]` si se decidió en conversación. **Por qué:** al comprimir se pierde la
   procedencia y el default es releer una idea PROPIA como si fuera del usuario — fabricar autorización
   que nunca existió. Marcar la procedencia hace que el LINAJE viaje CON la idea a través del compact.
   Regla dura al re-resumir: **nunca conviertas un `[INFER-mío]` en un `[user]`**; si no recuerdas el
   origen, es `[INFER-mío]` (conservador), no del usuario.
2. **El estado del proyecto — BARRIDO SIN PÉRDIDA del hilo → durable (GARANTÍA DURA, ambos niveles).**
   Antes de que el paso 1 pise el hilo, **barre el hilo entero y asegura que TODO pendiente y TODA
   decisión DURABLE que viva en él ya esté en `estado-proyecto.md`** (o el backlog durable equivalente del
   repo — `estado-y-pendientes.md`; y `bitacora.md` para lo que YA pasó). Es la dirección correcta de la
   flecha — **hilo (volátil) SUBE a estado-proyecto.md (durable), nunca al revés** —, la misma separación
   dura del skill `/to-do` (**el HUD/hilo = vista SCRATCH; el backlog durable = fuente de verdad**) y la
   norma "ninguna DECISIÓN se queda solo en el chat". Así la sobrescritura del hilo queda **SIN PÉRDIDA**:
   lo que legítimamente se descarta del hilo (paso 1) ya está a salvo en el durable. Mecánica: igual que
   `cerrar-slice §2` — mueve ítems en `estado-proyecto.md` (hecho/pendiente/decidido) y **appendea UNA
   línea al FINAL** de `bitacora.md` con `>>` (`printf '%s\n' '- …' >> bitacora.md`), **no** con un Edit
   que reescriba (así varias sesiones no se pisan). Lo puramente EFÍMERO (el micro-paso siguiente, un
   razonamiento a medio cocinar SIN decisión aún) NO necesita subir — vive en el hilo y lo cuida el
   read-before-overwrite del paso 1; **ante la duda de si algo es durable, SUBE** (barato de limpiar, caro
   de perder). El BARRIDO en sí NO es opcional; si tras barrer no queda nada durable sin subir, el
   checkpoint puede ser solo-hilo.
3. **doc = realidad (vistazo).** Si en esta tanda cambiaste comportamiento/config/rutas, actualiza la
   doc que lo describe en la MISMA tanda (no lo dejes para después).
4. **La cosecha durable (solo COMPLETO).** Antes de cerrar el volcado, pregúntate: *¿qué de lo que
   traigo en contexto ya tiene casa durable?* — un aprendizaje que va a una memoria del proyecto, un
   gotcha que va a un skill, una decisión de infra que va a su doc. **Promuévelo AHORA, como parte del
   checkpoint** (no lo agendes), y regístralo en `## COSECHA DURABLE` con sus rutas. Lo que ya vive en
   disco es lo único que el compact no puede perder.

## El estándar: que ESCARBAR sea innecesario
El hilo se escribe para que la siguiente instancia (tú mismo tras compactar, o un sucesor) NO tenga que
releer las fuentes para reconstruir el modelo — le basta con LEER el hilo. Si al retomar hace falta
grepear código, abrir un dictamen de cientos de líneas o reconstruir un contrato desde cero, el
checkpoint ANTERIOR falló — no el lector por preguntar.

Esto no contradice la norma dura "Recupera de tu contexto vivo; EXCAVA/verifica solo lo que NO tienes" — resuelve un caso distinto
al que esa norma cubre:
- **El hilo NO TIENE la respuesta** → excavar (bitácora, `estado-proyecto.md`, el transcript) sigue
  siendo lo correcto. Y además es la SEÑAL de que el checkpoint anterior quedó corto: corrígelo en el
  próximo.
- **El hilo SÍ TIENE la respuesta, escrita por ti mismo** → úsala directamente. Volver a escarbar cuando
  ya la dejaste escrita es el desperdicio que este estándar elimina.

Regla operativa al retomar: LEE el hilo primero. Si responde la pregunta, ahí termina — no repitas el
grep. Si no responde, excava — y el hueco que encontraste es el defecto a corregir en el SIGUIENTE
checkpoint, no una falla tuya por haber preguntado.

## Qué NO es
- **No es `cerrar-slice`.** Checkpoint es SOLO el volcado; no verifica build/tests, no abre MR, no
  cosecha aprendizajes de cierre de slice. Cuando de verdad terminaste un slice, usa `cerrar-slice`
  (que hace este mismo volcado + esas etapas). Checkpoint es el "guarda punto" de en medio — ligero o
  completo, sigue siendo un punto de retorno, no un cierre.
- **No sustituye la disciplina del JUICIO.** `PreCompact` no puede inyectar contexto ni darte un turno
  — por eso ningún hook puede escribir el "en qué estamos / decisión abierta / siguiente paso" por ti;
  eso sigue siendo tuyo, vía esta skill. Lo que SÍ hace un hook (C1/M2, auditoría 2026-09-11): en ese
  MISMO evento, `checkpoint-mecanico.sh` YA corre (detached, cero tokens de modelo) y deja escrito
  `.claude/memory/hilo-mental-actual.andamio.md` — el 🗂️ árbol de archivos tocados, los mensajes de
  `git commit`, las citas textuales del usuario y las métricas de sesión, sacados del transcript sin
  criterio. **Al hacer el checkpoint, REGENÉRALO y LÉELO primero (paso 0), y FUSIÓNALO** al volcado (no
  lo copies a ciegas: sigue siendo un borrador mecánico, no el hilo). Y si el compact te GANA la carrera,
  ya no se pierde: `rehidratar-hilo` (SessionStart) inyecta el andamio junto al hilo cuando es MÁS FRESCO
  que él, con encabezado propio y etiquetado como evidencia — nunca como si fuera tu razonamiento. Tú
  sigues poniendo el juicio; el andamio te ahorra el grep. Y al umbral ALTO del punto real de compact
  `aviso-contexto` **DISPARA ese mismo andamio solito** (mismo lanzador que el hook de PreCompact) y te
  ORDENA correr /checkpoint (la prosa, que sí necesita modelo) + /compact — ya no solo lo recuerda.

## Compartido vs local
`hilo-mental-actual.md` es memoria de trabajo **VOLÁTIL** (se sobrescribe seguido) y personal de tu
stream de trabajo. En repos **COMPARTIDOS** conviene **gitignorearlo** (per-dev, como los `*.local.md`)
para no generar conflictos de merge entre devs. El estado durable COMPARTIDO son
`estado-proyecto.md`/`bitacora.md`. El continuo cross-sesión del hilo (que es lo que este skill
protege) es para TU hilo, no el del equipo.
