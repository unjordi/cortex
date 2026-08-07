# Propuesta — mecanismo para usar la lista de TODOs (HUD) de forma CONSISTENTE

> **Estado:** IMPLEMENTADO (primera versión) — 2026-08-07. El diseño de abajo (Opción D) se construyó; la
> pieza dura es el hook **`hud-stale`** (`brain/hooks/hud-stale.sh`, tier `global`). Ver §7 para el mapeo
> propuesta→realidad y las decisiones que quedan ABIERTAS para unjordi.
>
> **De dónde sale:** unjordi ama la lista de tareas de la terminal (el árbol de checkboxes con ✓, `in_progress`, `+N completed`),
> pero Claude la usa MUY inconsistente — a veces impecable, a veces stale (mostrando tareas de otro proyecto/sesión),
> a veces ni la abre. Quiere un mecanismo que la vuelva consistente **y que sea ergonómico PARA el modelo** (que Claude
> QUIERA usarla), no un hook-nag que produzca cumplimiento defensivo.
> **Restricción rectora (citada del cerebro):** *"un mecanismo mal dirigido (un hook con falsos positivos) desgasta la
> confianza tanto como su ausencia — la PRECISIÓN del guard importa igual que su existencia"* y *"Toda norma nace con su mecanismo."*
>
> **DECISIÓN RECTORA (unjordi, 2026-08-07, cita literal):** *"NO QUIERO DRIFT NUNCA Y MENOS EN MI LISTA DE
> PENDIENTES."* → se construye el mecanismo que **DETECTA/FLAGGEA** el staleness de la lista, NO el enfoque
> pasivo de solo-framing. Esto RESUELVE la decisión abierta #1 de §6 (hook vs solo-framing): **hook**.

---

## 1. Diagnóstico — por qué HOY es inconsistente (anclado al corpus)

Barrido de `~/.claude-brain` (`grep` de `TodoWrite`, `scratch`, `lista de tareas`, `estado-proyecto`, `backlog`). La lista
de TodoWrite del harness aparece **exactamente 3 veces, TODAS en negativo** — nunca se le da un trabajo propio ni un ritual:

1. `brain/skills/orquestar-fanout/SKILL.md` — "La lista de **TodoWrite** del harness es **scratch de sesión** — el backlog DURABLE es estado-proyecto.md. No confundas una con la otra."
2. `brain/norms/global-claude-md.md` — la MISMA frase, embebida en la norma de orquestación (fan-out).
3. `brain/hooks/delegacion-reporte.sh` — comentario que repite lo mismo.

**El hallazgo central:** en TODO el cerebro, la lista de TODOs solo existe como *la cosa que NO es el backlog durable*. Se la
define por lo que no debe hacer ("no la confundas con estado-proyecto.md"), nunca por lo que **sí** debe hacer, cuándo abrirla,
qué la mantiene fresca, ni qué la resetea al cambiar de tarea. Un artefacto definido solo por su demotion no tiene por qué usarse.

Las cuatro causas concretas de la inconsistencia:

- **(a) No hay disparador ni ritual de cuándo abrir/actualizar la lista.** Los rituales del cerebro (`checkpoint`,
  `cerrar-slice`, `rehidratar-hilo`, `sesion-inicio`) operan sobre `hilo-mental-actual.md`, `estado-proyecto.md` y `bitacora.md`.
  **Ninguno menciona la lista de TodoWrite.** Nada la ata a un momento → falla de **saliencia**, no de memoria.
- **(b) Compite conceptualmente con `estado-proyecto.md`.** La única vez que el cerebro la nombra es para subordinarla al
  backlog durable. Eso crea una ambigüedad "¿cuál actualizo?" que en el momento se resuelve como **"ninguna"**.
- **(c) Al cambiar de tarea/sesión nada la resetea → queda stale.** El cerebro YA resuelve este exacto problema para el HILO:
  `rehidratar-hilo.sh` degrada el encabezado a "⚠️ HILO POSIBLEMENTE OBSOLETO" si el hilo es viejo o **fue volcado en otra rama**.
  La lista de TodoWrite **no tenía ningún equivalente** — sobrevivía intacta al cambio de rama/proyecto. Es la queja literal.
- **(d) Framing de compliance, no de utilidad-propia.** Donde el cerebro SÍ logra que el modelo use algo con gusto —el
  `hilo-mental-actual.md`— es porque lo enmarca como **memoria de TRABAJO del modelo** ("Es TU memoria de trabajo"). La lista
  de TODOs nunca recibió ese framing intrínseco.

---

## 2. La división de labor, clarificada (HUD efímero vs backlog durable vs hilo)

| Artefacto | Qué es | Alcance | Vida | Quién/cuándo lo toca |
|---|---|---|---|---|
| **Lista TodoWrite = el HUD** | Descomposición VIVA de la tarea de AHORA, visible en la terminal | ESTA tarea, ESTA sesión | La tarea (se **resetea** al cambiar de tarea) | El modelo, en vivo mientras ejecuta |
| **`estado-proyecto.md` = backlog durable** | Fuente de verdad cross-sesión: hecho / pendiente / decidido | Todo el proyecto | Persiste sesiones y compactaciones | Se **cura** en cierres (checkpoint/cerrar-slice) |
| **`hilo-mental-actual.md` = el hilo** | Narrativa en prosa volcada a DISCO para sobrevivir la compactación | La tarea de ahora | Se sobrescribe seguido; lo relee `rehidratar-hilo` | Lo escribe `checkpoint` |

**Regla mnemónica (para el modelo):** *el **HUD** es lo que veo en pantalla para no perderme AHORA; el **hilo** es lo que
escribo a disco para no perderme tras un compact; el **backlog** es lo que sobrevive para no perderme entre sesiones.*

**Los dos puentes:** al **ARRANCAR/RETOMAR** una tarea el HUD se **siembra** del hilo/`estado-proyecto.md`; al **CERRAR**
(checkpoint/cerrar-slice) lo durable del HUD se **vacía** a `estado-proyecto.md`/`bitacora.md` y el HUD se limpia.

---

## 3. Opciones de mecanismo (resumen)

> Nota de precisión que atraviesa todas: **un hook NO puede leer de forma robusta el CONTENIDO de la lista de TodoWrite**
> para juzgar si "está stale respecto a lo que haces" — eso es semántico y sería una máquina de falsos positivos. Los ÚNICOS
> disparadores precisión-seguros son **señales OBJETIVAS** (inicio de sesión, cambio de rama, cambio de cwd/proyecto).

- **A — Solo framing** (norma + reinyección SessionStart, sin hook). Costo cero, FP nulo; pero la saliencia se desvanece
  en corridas largas, justo cuando el HUD se vuelve stale.
- **B — Hook de HUD-stale precisión-gated** (modelo: `aviso-contexto`/`rehidratar-hilo`): inyecta un reframe PASIVO solo ante
  señal objetiva de que el contexto de tarea rotó (rama/cwd). Ataca la queja literal.
- **C — Ritual en los bordes** (checkpoint/cerrar-slice/retomar siembran y vacían el HUD). Cero fricción; hereda la
  consistencia de invocar skills.
- **D — Híbrido A+B+C.** Cobertura completa; cada pieza cubre el hueco de la otra.

---

## 4. Recomendación — Opción D (híbrido), con el FRAMING como corazón — LO QUE SE CONSTRUYÓ

Con la decisión rectora de unjordi (hook, no solo-framing), se construyó la **Opción D** con el hook (B) como pieza dura:

**1) Norma nueva (durable)** en `brain/norms/global-claude-md.md` — "Tu lista de TODOs es TU HUD": fija la división de labor
de §2, enmarca el HUD con lenguaje **intrínseco** (calcado del que funciona para el hilo), y cita la decisión anti-drift.

**2) Reinyección/siembra en los rituales** — el skill `/to-do` (Regla 1) documenta RE-SEMBRAR la vista del `estado-proyecto.md`
de ESA rama al rotar de rama/cwd; queda como la mitad "siembra" del hook.

**3) Hook `hud-stale` (el mecanismo duro).** Eventos **SessionStart** (todos los source) + **PostToolUse/Bash**. Detecta solo
señales OBJETIVAS: `(repo root | rama git)` de AHORA vs. lo observado en ESTA sesión (stamp per-`session_id`). Al diferir,
inyecta additionalContext PASIVO: "cambiaste de rama/proyecto; tu HUD puede ser de la tarea anterior; si ya no aplica,
resetéalo/re-siémbralo con `/to-do`. Es TU HUD, no una orden." **Advisory** (no bloquea).

**4) Flush/seed en las skills de borde** — documentado en `/to-do` (§Relación) y en la norma; el enforcement es el ciclo de
skills existente.

---

## 5. Por qué esto es algo que el modelo QUERRÍA usar (no solo obedecer)

El error de un hook-nag es tratar la lista como un entregable para el usuario → el modelo la mantiene por miedo al regaño y la
abandona en cuanto el regaño no mira. Esta propuesta hace lo contrario: le da al HUD el mismo estatus que el `hilo-mental-actual.md`
ya tiene y que el modelo SÍ mantiene con gusto — **memoria de trabajo propia**. El hook de stale no regaña — le hace un favor:
le avisa "oye, ese tablero es de tu tarea anterior" en el único momento en que él no puede saberlo solo (acaba de rotar de
rama/proyecto). Un aviso que te salva de trabajar con datos viejos se siente como una herramienta, no como un vigilante.

---

## 6. Decisiones abiertas — actualizadas

1. ~~**¿Nace el hook o arrancamos solo con framing y medimos?**~~ **RESUELTA (unjordi, 2026-08-07): nace el hook** ("no
   quiero drift nunca en mi lista de pendientes").
2. **Tier del hook: `global` vs `both`.** Se eligió **`global`** (basta para las máquinas de unjordi, con bootstrap; mismo
   tier que `rehidratar-hilo`/`aviso-contexto`). `both` lo garantizaría en clones SIN bootstrap (como `secret-scan`), a costa
   de la cláusula de dedupe. **Abierta** si se quiere garantizar en clones ajenos.
3. **Umbral de "cuándo abrir el HUD".** La norma propone **≥3 pasos o trabajo de corrido**. ¿Ese corte, o a criterio libre?
4. ~~**¿PostToolUse/Bash además de SessionStart-resume?**~~ **Incluido**: capta el cambio de rama a MEDIA sesión (caso real),
   con debounce por transición para no repetir.
5. **Relación HUD ↔ `hilo-mental-actual.md`.** Se mantienen distintos y se conectan por la siembra. ¿Cómodo con dos
   artefactos, o se quiere que `checkpoint` genere el HUD DESDE el hilo para que nunca diverjan?

---

## 7. Mapeo propuesta → realidad (lo que quedó construido) + precisión

| Pieza | Archivo | Nota |
|---|---|---|
| Hook detector | `brain/hooks/hud-stale.sh` | tier `global`, eventos `SessionStart` + `PostToolUse/Bash`; advisory |
| Declaración/cableado | `brain/hooks/MANIFEST` · `brain/install-brain.sh` (`ev_de`) · `brain/uninstall-brain.sh` | derivado del MANIFEST (drift-check e2) |
| Norma | `brain/norms/global-claude-md.md` ("Tu lista de TODOs es TU HUD") | división de labor + framing intrínseco + anti-drift |
| Siembra/reset | `brain/skills/to-do/SKILL.md` (Regla 1 + §Relación) | la mitad que RE-SIEMBRA la vista |
| Widget | `windows/.../PopupForm.cs` · `macos/.../PopoverView.swift` · `src/plasmoid/.../main.qml` + los 3 known-global | drift-check e3 |
| Doc del árbol | `README.md` (raíz) · `brain/README.md` | drift-check e6c/e6c2 |
| Tests | `brain/test-brain.sh` (bloque **b6c**, 9 casos) | first-sight · debounce · rama · proyecto · concurrencia · gate backlog · fail-open |

**Cómo `hud-stale` garantiza precisión (anti-falsos-positivos), por capas:**
1. **Trigger OBJETIVO** (solo rama/cwd) — jamás juzga el contenido del HUD → el FP semántico es imposible por construcción.
2. **Stamp por-`session_id`** — sesiones/worktrees concurrentes en repos/ramas distintos NO se pisan (un stamp global único
   haría thrash entre sesiones paralelas → falso "cambiaste de proyecto" en cada tool).
3. **First-sight silencioso** — sin stamp previo para esta sesión, registra el baseline y calla; solo avisa ante un CAMBIO
   observado dentro de la MISMA sesión.
4. **Debounce por transición** — tras avisar actualiza el stamp → no re-avisa la misma transición; una rama estable no dispara.
5. **Gate de sistema** — solo procede si el repo ACTUAL tiene backlog durable (`estado-proyecto.md`/variantes); silencio total
   en repos/dirs que no usan el sistema. **Tradeoff conocido (favorece precisión sobre recall):** no cubre la staleness al
   SALIR hacia un dir sin backlog — decisión abierta si se quiere ampliar.
6. **Fail-open** — sin jq / sin git / sin `session_id` / cualquier error → silencio.
