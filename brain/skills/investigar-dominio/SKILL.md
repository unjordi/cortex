---
name: investigar-dominio
description: >-
  Ponerte al día como EXPERTO en un dominio/ecosistema maduro y dejarlo en memoria
  durable — no investigar al aire. Delega un fan-out de agentes a barrer la
  documentación oficial + issues/foros de cada pieza (método DOC-FIRST), cosecha lo
  aprendido en DOS capas (memorias de investigación indexadas + skills reutilizables,
  con la "capa profunda" separada bajo la de alto nivel), y REVISA las decisiones
  actuales contra el conocimiento nuevo para no arrastrar deuda técnica. Úsala cuando
  pidan "modo auditor/experto en X", "investiga la documentación de <ecosistema> y hazme
  skills", "revisa mis decisiones contra lo que se sabe hoy", o cuando TÚ quieras GENERAR
  ese encargo para dárselo a otro Claude (trae la plantilla-prompt pegable).
---

# investigar-dominio — volverte experto en un ecosistema y dejarlo en disco

Sirve en **dos direcciones**:
- **Ejecutar** — te piden entrar en modo experto en un dominio: sigue el método de abajo.
- **Generar el encargo** — quieres darle esta misma tarea a **otro Claude**: usa la
  [plantilla-prompt](#plantilla-prompt) del final, rellena los `<...>` y pégala.

## Por qué existe (la anatomía de por qué funcionó)
Nació de una sesión real (Jordi, 2026-07-25) que salió redonda. Lo que la hizo funcionar NO
fue una frase mágica — fueron **cuatro ingredientes juntos** que conviene reproducir siempre:

1. **Enmarcar el rol** — "modo AUDITOR/EXPERTO en X" cambia la profundidad del barrido.
2. **Autorizar el fan-out** — mandar agentes en paralelo a investigar, no leerlo todo en serie
   perdiendo el hilo (respeta el gate de costo de delegación).
3. **Doble cosecha durable** — memorias de investigación **+** skills, no un resumen en el chat
   que el próximo `/compact` se lleva.
4. **Amarrarlo a una meta real** — "revisa mis decisiones / no quiero arrastrar deuda técnica".
   Investigar sin un para-qué produce trivia; investigar contra decisiones produce backlog.

Y una regla de método que destiló esa sesión: **DOC-FIRST**. En un upstream maduro, barrer
**documentación + issues/foros PRIMERO** rinde más que reverse-engineering a ciegas — la doc ya
te dice las limitaciones ADMITIDAS y los issues ya tienen tu bug reportado por alguien más.

## El método (cuando TÚ ejecutas)

### 0. Inventario antes de crear (no arranques de cero)
Barre qué YA existe — skills, memorias, código previo, notas de sesiones pasadas — y construye
**SOBRE** ello. Media investigación puede estar ya hecha; duplicarla es deuda, no progreso.

### 1. Investigación a fondo (fan-out en paralelo)
Un agente por pieza del ecosistema (o por eje: doc oficial / issues+foros / código). De cada
fuente saca, como mínimo:
- **Qué añade sobre su base** (el delta real, no el marketing).
- **Limitaciones que la doc ADMITE** — oro puro, evita callejones.
- **Bugs abiertos que TE afectan** (filtra por tu stack/hardware/uso real).
- **Cambios a vigilar** (releases, deprecaciones, cambios de protocolo/ABI coordinados).
Cuando toques código, **cita `archivo:línea`** — una síntesis sin anclas no se puede re-verificar.

### 2. Cosecha durable en DOS capas
- **(a) Memorias de investigación** — una por fuente (`<pieza>-doc-sintesis.md`,
  `<pieza>-issues-forums.md`), **indexadas en `MEMORY.md`** con un gancho de una línea.
- **(b) Skills reutilizables** — uno por subsistema, con "cuándo cargarlo" + el knowhow
  **no-obvio** (gotchas, invariantes, trampas), **no** lo que el código ya dice solo. Si un tema
  tiene una **capa profunda** (protocolo a nivel bits, formato de wire, algoritmo interno),
  sepárala como skill aparte **DEBAJO** del skill de alto nivel, y enlázalos entre sí.
- **Transversal vs de-proyecto:** lo específico del ecosistema → `<proyecto>/.claude/skills/` y
  `memory/`; lo que aplica a CUALQUIER proyecto → global `~/.claude/skills/` (ver
  `claude-proyecto-autocontenido`).

### 3. Revisar decisiones contra lo aprendido (el para-qué)
Con el conocimiento fresco, pasa lista a las decisiones vigentes: **cuáles siguen teniendo
sentido, cuáles no, y qué deuda técnica destaparon**. Redefine el backlog/plan con eso —
priorizado, con el CÓMO y los hashes/refs concretos. Ningún hallazgo se queda solo en el chat:
va a memoria/backlog durable **en el mismo turno** (norma dura del cerebro).

### 4. Cierre
Cierra con `checkpoint` (nivel COMPLETO si viene `/compact`) para volcar plan + resuelto +
cosecha. Si de verdad terminaste un slice, `cerrar-slice`.

<a id="plantilla-prompt"></a>
## Plantilla-prompt (cuando quieres GENERAR el encargo para otro Claude)
Rellena los `<...>` y pégala. Huecos críticos: **`<DOMINIO>`**, **la lista de piezas** y
**lo intocable/git** del final.

```
Entra en modo AUDITOR/INVESTIGADOR EXPERTO en <DOMINIO>.

CONTEXTO: <1–3 líneas: qué es el proyecto, qué mantengo, estado actual>.

Quiero tres cosas, en orden:

1) INVESTIGACIÓN A FONDO (delega en agentes en paralelo). Barre la documentación
   oficial Y los issues/foros de cada pieza del ecosistema: <lista las piezas>.
   Método DOC-FIRST: en proyectos maduros, primero doc + issues, no
   reverse-engineering a ciegas. De cada fuente: qué añade sobre su base, sus
   limitaciones ADMITIDAS, los bugs abiertos que me afectan, y los cambios a vigilar.

2) COSECHA DURABLE en dos capas:
   a) MEMORIAS de investigación — una por fuente (doc-síntesis + issues/foros),
      indexadas en MEMORY.md, con citas archivo:línea cuando toques código.
   b) SKILLS reutilizables — uno por subsistema; si un tema tiene "capa profunda"
      (p.ej. nivel bits/protocolo), sepárala como skill aparte DEBAJO del de alto
      nivel. Cada skill: cuándo cargarlo + el knowhow no-obvio (no lo que ya dice el código).

3) REVISA MIS DECISIONES actuales contra lo aprendido — NO QUIERO ARRASTRAR DEUDA
   TÉCNICA. Dime qué sigue teniendo sentido, qué no, y redefine el backlog/plan.

Reglas: inventario de lo que YA existe antes de crear nada (construye sobre ello);
ningún hallazgo se queda solo en el chat (va a memoria/backlog el mismo turno);
pregunta antes de cualquier cambio destructivo o de alcance ambiguo.
<tus reglas de git / lo intocable>.
```

## Qué NO es
- **No es un dump de trivia.** Sin el paso 3 (revisar decisiones) es investigación sin para-qué.
- **No sustituye el gate de costo de delegación** — el fan-out respeta el consentimiento de costo.
- **No inventa el corte del usuario.** Si presentas hallazgos como opciones y el usuario elige un
  subconjunto, el RESTO va al backlog, no se declara "fuera de alcance" (norma dura del cerebro).
