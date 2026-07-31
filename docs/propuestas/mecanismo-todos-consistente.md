# Propuesta — mecanismo para usar la lista de TODOs (TodoWrite) de forma CONSISTENTE

> **Estado:** PROPUESTA DE DISEÑO — a revisión de unjordi. NADA cableado, ningún hook productivo tocado.
> **De dónde sale:** unjordi ama la lista de tareas de la terminal (el árbol de checkboxes con ✓, `in_progress`, `+N completed`),
> pero Claude la usa MUY inconsistente — a veces impecable, a veces stale (mostrando tareas de otro proyecto/sesión),
> a veces ni la abre. Quiere un mecanismo que la vuelva consistente **y que sea ergonómico PARA el modelo** (que Claude
> QUIERA usarla), no un hook-nag que produzca cumplimiento defensivo.
> **Restricción rectora (citada del cerebro):** *"un mecanismo mal dirigido (un hook con falsos positivos) desgasta la
> confianza tanto como su ausencia — la PRECISIÓN del guard importa igual que su existencia"* y *"Toda norma nace con su mecanismo."*

---

## 1. Diagnóstico — por qué HOY es inconsistente (anclado al corpus)

Barrido de `~/.claude-brain` (`grep` de `TodoWrite`, `scratch`, `lista de tareas`, `estado-proyecto`, `backlog`). La lista
de TodoWrite del harness aparece **exactamente 3 veces, TODAS en negativo** — nunca se le da un trabajo propio ni un ritual:

1. `brain/skills/orquestar-fanout/SKILL.md:24-25`
   > "La lista de **TodoWrite** del harness es **scratch de sesión** — el backlog DURABLE es estado-proyecto.md. No confundas una con la otra."
2. `brain/norms/global-claude-md.md:280-281` — la MISMA frase, embebida en la norma de orquestación (fan-out).
3. `brain/hooks/delegacion-reporte.sh:16` — comentario que repite lo mismo.

**El hallazgo central:** en TODO el cerebro, la lista de TODOs solo existe como *la cosa que NO es el backlog durable*. Se la
define por lo que no debe hacer ("no la confundas con estado-proyecto.md"), nunca por lo que **sí** debe hacer, cuándo abrirla,
qué la mantiene fresca, ni qué la resetea al cambiar de tarea. Un artefacto definido solo por su demotion no tiene por qué usarse.

Las cuatro causas concretas de la inconsistencia (las tres hipótesis del encargo, confirmadas + una cuarta):

- **(a) No hay disparador ni ritual de cuándo abrir/actualizar la lista.** Todos los rituales del cerebro (`checkpoint`,
  `cerrar-slice`, `rehidratar-hilo`, `sesion-inicio`) operan sobre `hilo-mental-actual.md`, `estado-proyecto.md` y `bitacora.md`.
  **Ninguno menciona la lista de TodoWrite.** Nada la ata a un momento → falla de **saliencia**, no de memoria. Es el mismo
  patrón que el cerebro ya nombró en `docs/candidatos/2026-07-21-pkexec-git-ssh/README.md`: *"una regla ya estaba en el
  CLAUDE.md/memoria pero no se activó en el momento — falla de saliencia, no de memoria: el texto estaba en contexto, pero
  nada lo ató al disparador."* La lista de TODOs sufre exactamente eso.

- **(b) Compite conceptualmente con `estado-proyecto.md`.** La única vez que el cerebro nombra la lista es para subordinarla al
  backlog durable. Eso crea una ambigüedad "¿cuál actualizo?" que en el momento se resuelve como **"ninguna"**. Sin una división
  de labor POSITIVA (qué hace cada una y cuándo), el modelo no tiene un lugar claro para el plan vivo de la tarea de AHORA.

- **(c) Al cambiar de tarea/sesión nada la resetea → queda stale.** El cerebro YA resuelve este exacto problema para el HILO:
  `rehidratar-hilo.sh:70-81` tiene un **gate de frescura** que degrada el encabezado a "⚠️ HILO POSIBLEMENTE OBSOLETO" si el
  `hilo-mental-actual.md` es viejo (mtime > 12h) o **fue volcado en otra rama** distinta de la actual. La lista de TodoWrite
  **no tiene ningún equivalente** — sobrevive intacta al cambio de rama/proyecto y sigue mostrando tareas de otra cosa. Es
  literalmente la queja de unjordi ("tareas de otro proyecto/sesión mientras trabaja en algo distinto").

- **(d) Framing de compliance, no de utilidad-propia.** Donde el cerebro SÍ logra que el modelo use algo con gusto —el
  `hilo-mental-actual.md`— es porque lo enmarca como **memoria de TRABAJO del modelo**: `rehidratar-hilo.sh:78,80` cierra con
  *"Es TU memoria de trabajo (no una orden del usuario)"*. La lista de TODOs nunca recibió ese framing intrínseco; se la trata
  como un subproducto del reporte. Un modelo mantiene con esmero lo que le sirve a él para no perderse; abandona lo que percibe
  como trámite.

---

## 2. La división de labor, clarificada (HUD efímero vs backlog durable vs hilo)

Hoy hay DOS artefactos nombrados (TodoWrite scratch · estado-proyecto durable) y un tercero implícito que se traslapa (el
`hilo-mental-actual.md`). La propuesta NO contradice la doctrina existente ("TodoWrite = scratch, estado-proyecto = durable"):
la **precisa** dándole a la lista un trabajo exclusivo y positivo.

| Artefacto | Qué es | Alcance | Vida | Quién/cuándo lo toca |
|---|---|---|---|---|
| **Lista TodoWrite = el HUD** | Descomposición VIVA de la tarea de AHORA, visible en la terminal; el tablero "¿voy en orden? ¿qué falta?" | ESTA tarea, ESTA sesión | La tarea (se **resetea** al cambiar de tarea) | El modelo, en vivo mientras ejecuta |
| **`estado-proyecto.md` = backlog durable** | Fuente de verdad cross-sesión: hecho / pendiente / decidido / fuera-por-decisión | Todo el proyecto | Persiste sesiones y compactaciones | Se **cura** en cierres (checkpoint/cerrar-slice) |
| **`hilo-mental-actual.md` = el hilo** | Narrativa en prosa volcada a DISCO para sobrevivir la compactación (el "de qué iba, decisión a medio cocinar, siguiente paso") | La tarea/conversación de ahora | Se sobrescribe seguido; lo relee `rehidratar-hilo` tras compactar | Lo escribe `checkpoint` |

**La regla mnemónica (para el modelo):** *el **HUD** es lo que veo en pantalla para no perderme AHORA; el **hilo** es lo que
escribo a disco para no perderme tras un compact; el **backlog** es lo que sobrevive para no perderme entre sesiones.* HUD y
hilo son las dos caras de la misma "memoria de trabajo del ahora" (una estructurada+visible, otra en prosa+durable); el backlog
es otra liga (persistencia del proyecto).

**Los dos puentes (dónde se conectan):**
- **Al ARRANCAR/RETOMAR una tarea:** el HUD se **siembra** del plan que el modelo ya tiene o reconstruyó — del `hilo-mental-actual.md`
  rehidratado y/o del ítem correspondiente de `estado-proyecto.md`. El HUD es la descomposición live de ESE ítem, no un backlog paralelo.
- **Al CERRAR (checkpoint/cerrar-slice):** lo durable del HUD se **vacía** a `estado-proyecto.md`/`bitacora.md` y el HUD se
  limpia. Lo que sobrevive es el backlog; el HUD muere con la tarea (es scratch — coherente con la doctrina vigente).

Esto mata la ambigüedad "¿cuál actualizo?": el HUD es para el minuto-a-minuto de la tarea viva; el backlog para lo que cruza sesiones.
Nunca son la misma escritura y nunca compiten — se relevan en los bordes (arranque y cierre).

---

## 3. Opciones de mecanismo (todas bajo la restricción "bonito para Claude")

> Nota de precisión que atraviesa todas: **un hook NO puede leer de forma robusta el CONTENIDO de la lista de TodoWrite para
> juzgar si "está stale respecto a lo que haces"** — eso es semántico y sería una máquina de falsos positivos → violaría la
> norma de precisión. Los ÚNICOS disparadores precisión-seguros para un hook son **señales OBJETIVAS** (inicio de sesión,
> cambio de rama, cambio de cwd/proyecto). Cualquier opción con hook se ata solo a esas.

### Opción A — Solo framing: norma + reinyección en SessionStart (sin hook nuevo)
Un bloque de norma que clarifica la división de labor (§2) y enmarca el HUD como *"tu working-memory HUD de ESTA tarea"*,
más una línea en el `additionalContext` de `sesion-inicio.sh` que lo recuerde al abrir sesión.
- **Pro:** costo cero, riesgo de falso positivo **nulo** (no hay detección), 100% en el espíritu intrínseco.
- **Contra:** la saliencia de SessionStart **se desvanece durante corridas largas** — justo cuando el HUD se vuelve stale
  (mitad de una ráfaga autónoma, tras cambiar de sub-tarea). "Toda norma nace con su mecanismo": una norma cuyo único
  mecanismo dispara al inicio es débil porque el modo de falla ocurre lejos del inicio.

### Opción B — Self-check de HUD-stale vía hook de saliencia, precisión-gated (modelo: `aviso-contexto`)
Un hook ligero que inyecta un reframe PASIVO **solo ante una señal objetiva de que el contexto de tarea rotó** — el candidato
limpio es **cambio de rama git o de cwd/proyecto a media sesión** (PostToolUse/Bash, o SessionStart con `source=resume`).
Es exactamente el gate de frescura que `rehidratar-hilo.sh` ya aplica al hilo (mtime + rama distinta), trasladado al HUD.
El mensaje inyectado NO ordena; recuerda: *"cambiaste de rama/proyecto — tu HUD de TODOs puede ser de la tarea anterior;
si ya no aplica, resetéalo; es TU tablero, no un reporte."* Fail-open, debounced, mismo rigor que `aviso-contexto`.
- **Pro:** ataca **la queja literal** ("tareas de otro proyecto/sesión"); disparador objetivo → falsos positivos casi nulos;
  reutiliza un patrón ya probado y aceptado en el cerebro (inyección pasiva de additionalContext).
- **Contra:** cubre la staleness por **cambio de contexto**, no la staleness por **abandono** (dejé el HUD a medias sin cambiar
  de rama). Esa otra la cubre el framing + los rituales, no un hook (no hay señal objetiva de "abandono" sin caer en FP).

### Opción C — Ritual en los bordes que el modelo YA cruza (integrado a skills, sin hook nuevo)
Meter la higiene del HUD en los rituales que ya disparan en los bordes naturales: `checkpoint` (ya vuelca el hilo → agrega
"reconcilia el HUD y vacía lo durable a estado-proyecto"), `cerrar-slice` (vaciar HUD → estado-proyecto/bitácora, luego
limpiarlo), `rehidratar-hilo`/`retomar-trabajo` (al retomar, **sembrar** el HUD del hilo/estado). El HUD entra al ciclo
volcar/rehidratar que ya existe, sin nag nuevo.
- **Pro:** cero fricción nueva; el HUD se vuelve parte de un ciclo que el modelo ya valora (sobrevivir compactaciones).
- **Contra:** las skills las invoca el modelo → la consistencia hereda la consistencia de invocar las skills (mejor que hoy,
  pero no un piso duro por sí sola).

### Opción D — Híbrido (framing + siembra en el retomar + stale-check objetivo + flush en los cierres)
Combina A+B+C: la norma/framing de A da el "por qué querría"; C siembra y vacía en los bordes; B es el backstop objetivo para
la staleness por cambio de contexto. Cada pieza cubre el hueco de la otra.
- **Pro:** cobertura completa sin depender de una sola pata; cada mecanismo respeta su límite de precisión.
- **Contra:** más superficie que tocar (una norma, un hook chico, tres skills) — pero todo son extensiones de piezas que ya existen.

---

## 4. Recomendación — Opción D (híbrido), con el FRAMING como corazón

**Recomiendo la Opción D**, entendiendo que la pieza que de verdad mueve la aguja es el **framing intrínseco** (A) sembrado en
los momentos en que el modelo YA está reorientándose (C); el hook (B) es el backstop preciso que hace que "nace con su mecanismo"
no sea un buen deseo. Concretamente, cuatro piezas, todas extensiones de infra existente:

**1) Norma nueva (durable) en `brain/norms/global-claude-md.md`** — un bloque corto que:
   - fija la división de labor de §2 (HUD vs backlog vs hilo, con la regla mnemónica);
   - enmarca el HUD con lenguaje **intrínseco**, calcado del que YA funciona para el hilo: *"la lista de TODOs es TU HUD de
     working-memory de la tarea de AHORA — tu tablero para no perderte, no un reporte para el usuario. Ábrela cuando una tarea
     tenga ≥3 pasos o vayas a trabajar de corrido; manténla como el reflejo de tu plan; resetéala cuando cambies de tarea";*
   - dice explícito el puente: **sembrar** al arrancar/retomar (del hilo/estado), **vaciar** lo durable al cerrar.
   - Se propaga por-repo con `sincronizar-cerebro.sh` (ya existe) igual que el resto de normas.

**2) Reinyección en SessionStart** — añadir UNA línea al `additionalContext` de `sesion-inicio.sh` (tier `repo`) y/o al
   `rehidratar-hilo.sh` (tier `global`): al retomar, *"si retomas una tarea con plan, siembra tu HUD de TODOs del hilo/estado
   que acabas de releer."* Es pasivo (el patrón fiable ya usado), sin bloquear.

**3) Hook de HUD-stale, precisión-gated (el mecanismo duro, mínimo).** Evento: **SessionStart (`source=resume`)** +,
   opcionalmente, **PostToolUse/Bash** que detecte cambio de rama. Qué detecta (solo señales OBJETIVAS):
   - la rama actual difiere de la registrada la última vez que se vio actividad de HUD, **o** el cwd/proyecto cambió;
   Qué hace: inyecta additionalContext PASIVO — *"cambiaste de rama/proyecto desde tu última tarea; tu lista de TODOs puede
   ser de la anterior. Si ya no aplica, resetéala antes de seguir. Es tu HUD, no una orden."* Cómo evita falsos positivos:
   - dispara **solo** ante cambio objetivo de rama/cwd (no intenta juzgar contenido del HUD → imposible el FP semántico);
   - **debounce por rama** (marca en `.claude/memory/.hud-visto`, como `.contexto-aviso`): avisa una vez por transición, no en cada tool;
   - **fail-open** (sin jq / sin git / sin memoria → exit 0 silencioso), idéntico rigor a `aviso-contexto` y `rehidratar-hilo`;
   - reusa la MISMA lógica de "rama registrada vs rama actual" que `rehidratar-hilo.sh:70-75` ya tiene probada para el hilo.
   Tier: `global` (stack-agnóstico) o `both` si se quiere garantizar en clones sin bootstrap; se declara en `brain/hooks/MANIFEST`.

**4) Flush/seed en las skills de borde** — extender `checkpoint` (vaciar lo durable del HUD a estado-proyecto/bitácora antes de
   compactar), `cerrar-slice` (vaciar + limpiar el HUD al cerrar el slice) y `rehidratar-hilo`/`retomar-trabajo` (sembrar el HUD
   al retomar). Son ediciones de doc en SKILL.md; el enforcement es el ciclo de skills que ya existe.

**Por qué esta combinación respeta las normas rectoras:** el único componente automático (el hook #3) se ata a señales
**objetivas** (rama/cwd) — cero juicio semántico → cero falsos positivos por diseño, cumpliendo *"la precisión del guard importa
igual que su existencia"*. Y la norma (#1) **nace con su mecanismo** (#2+#3+#4), no como buen deseo.

---

## 5. Por qué esto es algo que el modelo QUERRÍA usar (no solo obedecer)

El error de un hook-nag es tratar la lista como un entregable para el usuario → el modelo la mantiene por miedo al regaño y la
abandona en cuanto el regaño no mira. Esta propuesta hace lo contrario: le da al HUD el mismo estatus que el `hilo-mental-actual.md`
ya tiene y que el modelo SÍ mantiene con gusto — **memoria de trabajo propia**. Un modelo que corre de forma autónoma y larga
tiene un interés genuino y egoísta en un tablero fiable de "qué estoy haciendo / qué me falta / voy en orden": es lo que lo
mantiene orientado cuando su propio contexto se degrada, exactamente como el hilo lo salva del compact. El framing "es TU HUD,
no un reporte" no es retórica: alinea el mantenimiento de la lista con lo que al modelo le conviene para no perderse. Y el hook
de stale no regaña — le hace un favor: le avisa "oye, ese tablero es de tu tarea anterior" en el único momento en que él no
puede saberlo solo (acaba de rotar de rama/proyecto). Un aviso que te salva de trabajar con datos viejos se siente como una
herramienta, no como un vigilante — que es justo la diferencia entre "bonito para mí" y "compliance".

---

## 6. Decisiones abiertas (para llevar a unjordi)

1. **¿Nace el hook `hud-stale` o arrancamos solo con framing (A+C) y medimos?** El hook es el backstop preciso, pero si se
   prefiere validar primero que el framing solo ya mejora la consistencia, se puede diferir #3 y agregarlo si la staleness
   por cambio de rama persiste. (Riesgo de A/C solo: la queja literal —tareas de otro proyecto— es justo la que el hook cubre.)
2. **Tier del hook: `global` vs `both`.** `global` basta para las máquinas de unjordi; `both` lo garantiza en clones sin
   bootstrap (como se hizo con `secret-scan`), a costa de la cláusula de dedupe. Recomiendo `global` para empezar.
3. **Umbral de "cuándo abrir el HUD".** Propuse "≥3 pasos o trabajo de corrido". ¿Ese corte, o dejarlo a criterio del modelo
   sin número? (Un número da saliencia; el criterio libre evita abrir HUD para nimiedades.)
4. **¿PostToolUse/Bash además de SessionStart-resume para el stale-check?** PostToolUse capta el cambio de rama a MEDIA sesión
   (no solo al retomar), que es un caso real; pero fire-por-tool cuesta (mitigado por debounce). ¿Vale la cobertura extra?
5. **Relación HUD ↔ `hilo-mental-actual.md`.** Se traslapan (ambos "memoria del ahora"). La propuesta los mantiene distintos
   (uno visible+estructurado, otro prosa+durable) y los conecta por la siembra. ¿Cómodo con dos artefactos, o se quiere que el
   checkpoint genere el HUD DESDE el hilo para que nunca diverjan?
