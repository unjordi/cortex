---
name: positivar-doc
description: Reescribir una memoria/skill/doc para que cada nugget abra con "ESTO SÍ" (el método/valor correcto y accionable) ANTES del "ESTO NO" (anti-patrones, gotchas, la historia de lo que se rompió). Answer-first. Úsalo al crear o editar docs, o cuando una nota arranque con la historia del fallo y enrede al lector. Reordena/reencuadra SIN perder información. Transversal (cualquier repo); una sola doc inline o bulk delegado a un agente con el mismo contrato.
---

# Positivar una doc — "ESTO SÍ" antes de "ESTO NO"

## El principio (una frase)
**Cada nugget abre con la SOLUCIÓN (lo que SÍ funciona, accionable) y cierra con la CAUTELA (el anti-patrón,
el gotcha, el incidente).** La historia de lo que se rompió es soporte del *porqué*, nunca el titular.
Es el MISMO principio en dos niveles: dentro de un nugget (abajo) y en la ESTRUCTURA del archivo completo
(`## Nivel DOCUMENTO`, más abajo) — lo accionable arriba, el contexto/historia después, en ambos casos.

## El espíritu: el cerebro guarda CONOCIMIENTO, no cicatrices
Positivar no es solo REORDENAR (ESTO SÍ antes del ESTO NO) — es FRAMING. **El cerebro es para SABER, no para
tener miedo.** Guarda qué es verdad, qué hacer y entender de verdad; no cicatrices ni monumentos al fallo.
- **Reencuadra la lección como el CONOCIMIENTO ganado, no como el susto.** No "creímos algo falso" (cicatriz,
  auto-flagelo) → sino la verdad accionable que quedó. Ejemplo real: en vez de *"nos equivocamos, los pagos no
  venían donde creíamos"*, la memoria dice *"¿cómo pagaron si no viene en ningún lado? → no paramos hasta
  hallarlo"* — quedó como conocimiento VIVO en el ETL de BOSS, no como lápida.
- **Lo muerto muere con su archivo; no necesita monumento.** Cuando algo se elimina o se reubica, no dejes una
  lápida narrando la mudanza en OTRO archivo (eso lo poda el desinflador). El conocimiento vivo se queda; el
  scar-tissue no.
- **Reconciliación (para no pasarse):** esto es FRAMING, NO borrar avisos reales. Una advertencia destructiva
  ("esto borra datos") o un "NO re-proponer" TERSO que evita repetir un callejón costoso SÍ son conocimiento
  (previenen daño) y se quedan — la ⚰️ Lápida de UNA línea del desinflador es conocimiento; el monumento de tres
  párrafos es miedo. Y tampoco es optimismo falso (ver Reglas duras): reencuadras la MISMA certeza en positivo,
  no le subes el tono.

## Por qué
Un lector debe poder **hacer lo correcto leyendo solo el arranque** de cada nugget, sin vadear un párrafo
de "esto falló porque… y aquello tampoco… entonces resulta que…". La solución primero = acción inmediata;
el "no hagas X" después = blindaje para quien se pregunte por qué. Abrir con el fallo enreda y esconde la
respuesta al final.

## Método — nugget por nugget
1. **Ubica el nugget:** una idea/sección/bullet que empareja un método correcto con anti-patrones/gotchas/fallos.
2. **Reordena:** `ESTO SÍ` (el comando, valor, regla o paso correcto) **primero**; `ESTO NO` (por qué no X,
   qué se rompió, el incidente) **después**, idealmente como `❌ …` compacto.
3. **Si ya es answer-first, déjalo** (no toques por tocar).
4. **Si NO hay un "ESTO SÍ" real** (el nugget es un gotcha/incidente SIN solución conocida todavía — "esto
   se rompe y aún no sabemos arreglarlo"), el titular es el **ESTADO o restricción actual en voz directa**
   ("hoy no hay fix; mientras tanto evita X"), **nunca inventes una solución que no existe** solo por llenar
   el molde `ESTO SÍ`/`ESTO NO`.

## Casos especiales
- **Tablas:** si una columna/fila es "solución" y otra "por qué no", ordénalas para que la de solución se
  lea primero (izquierda o arriba); no rompas la tabla en prosa.
- **Listas numeradas con secuencia obligatoria** (pasos que deben ejecutarse en ese orden): NO reordenes los
  PASOS entre sí — solo positiva la explicación alrededor de cada paso, si la trae.
- **Bloques de código:** se dejan intactos (son la técnica, no el fraseo); solo se reordena el texto que los
  rodea.
- **Docs ya tabulares/referencia pura** (specs, listas de comandos sin narrativa de fallo): normalmente no
  tienen nugget que reordenar — no fuerces la forma `ESTO SÍ`/`ESTO NO` donde no hay una pareja
  método↔anti-patrón que reordenar.

## Nivel DOCUMENTO — lo accionable primero (mismo principio, otro nivel)
**El índice/router/"qué existe y cuándo usarlo"/el contrato "LEE ESTO ANTES DE HACER NADA" va ARRIBA del
archivo, no al final.** Un lector (o un agente) debe topar con qué-hacer y qué-existe en las primeras
líneas — el mapa accionable, no la narrativa.
- **Doc de ENTRADA** (`AGENTS.md`, el `MEMORY.md`/índice de un repo): lidera con el mapa accionable (skills
  disponibles, reglas duras, punteros) ANTES de la narrativa/bitácora/historial. La cronología y el detalle
  van DESPUÉS, nunca antes.
- **Método:** igual que a nivel nugget — ubica el bloque más accionable del archivo (el índice/router/
  contrato); si está enterrado al final o a la mitad, **súbelo al principio** y reencuádralo como "empieza
  aquí". El resto (narrativa, bitácora, contexto histórico) se conserva íntegro, solo se mueve DESPUÉS.
- **Caso real que lo motivó:** un índice de memorias útil vivía al FINAL de su archivo; se subió al
  PRINCIPIO y se reencuadró como "empieza aquí" — mismo contenido, el lector ya no tenía que scrollear todo
  el historial para encontrar el mapa.
- Aplican las mismas Reglas DURAS de abajo: no se pierde ni una línea de narrativa/detalle, solo cambia su
  POSICIÓN relativa al bloque accionable — es reordenar el ARCHIVO, no editarlo.
- **⚠️ EXCEPCIÓN — el `CLAUDE.md` (firma-árbol de un cerebro) NO se reordena.** Su estructura YA es canónica
  y fija por diseño (identidad → "dónde va cada cosa" → ÁRBOL → detalle) y es lo MÁS estable del cerebro
  (gradiente `CLAUDE.md`=`main`). Un `AGENTS.md`/`MEMORY.md` sí se reordena; un `CLAUDE.md`, jamás. Ver la
  Regla DURA de abajo — en él la ÚNICA parte elegible para esta pasada es la prosa de `## Reglas duras`.

## Mini-ejemplo (antes → después)
**Antes (enredado, fallo-primero):**
> `steam -shutdown` por SSH no cierra Steam porque el shell no hereda el env DBus/XDG de la sesión gráfica,
> así que el comando no alcanza al Steam que corre en Plasma y lo ignora; tampoco sirve sacar el env de
> plasmashell; al final lo que funciona es mandarle SIGTERM al PID.

**Después (positivado, solución-primero):**
> **Cerrar Steam:** `kill -TERM $(pgrep -x steam)` (SIGTERM = cierre limpio, guarda config).
> ❌ NO `steam -shutdown` por SSH (no alcanza al Steam de la sesión gráfica). ❌ NUNCA `-9` (deja estado sucio).

## Reglas DURAS (inviolables)
- **El `CLAUDE.md` es INTOCABLE salvo su sección `## Reglas duras`.** Gradiente de estabilidad del cerebro:
  `CLAUDE.md`=`main` (SOLO estructura + ATEMPORAL: identidad, "dónde va cada cosa", el ÁRBOL — muta casi nunca) ·
  `MEMORY.md`=`develop` · memorias/bitácora=ramitas. En una firma-árbol, esta pasada **NO toca la identidad, el
  "dónde va cada cosa" ni el árbol** (ya son answer-first por construcción); la ÚNICA prosa elegible para
  positivar es la de `## Reglas duras`. El `MEMORY.md` y las memorias SÍ son terreno normal de la pasada. Ante
  la duda de si algo es "estructura del `CLAUDE.md`", NO lo toques.
- **Preserva el 100% de la información.** Es REORDENAR + reencuadrar, NUNCA borrar conocimiento: cada hecho,
  comando, ruta, fuente `[DOC:...]`, tag `[EXP]`/`[INFER]`, link `[[...]]`, número y gotcha se conserva.
- **No cambies la técnica ni la corrección** (doc=realidad): solo el ORDEN y el fraseo. No "mejores" hechos,
  no inventes.
- **Conserva** frontmatter (`name`/`description`/`metadata`) y los encabezados que sigan teniendo sentido.
- **Verifica preservación:** antes de editar, inventaría los hechos clave del archivo (comandos, rutas,
  fuentes, links, nº de bullets); después, confirma que el inventario sigue completo. En repos que **no son
  git** no hay red de versiones fácil — si algo se perdería, no edites y repórtalo. No crees `.bak` (ensucian).
- **Sin optimismo falso:** positivar es reordenar la MISMA certeza, no subirle el tono. Si el "ESTO SÍ" es un
  workaround parcial, inestable o sin confirmar, el titular debe DECIRLO así ("mitiga pero no resuelve",
  "sin confirmar en prod", "temporal hasta X") — nunca debe leerse más resuelto/definitivo de lo que el
  hecho real sostiene. Esto es la misma disciplina que "doc = reflejo de la realidad": positivar el FRASEO,
  jamás la confianza.

## Escala
- **Una doc:** aplícalo inline tú mismo (leer → reordenar nugget por nugget → verificar preservación).
- **Bulk (todo el repo):** delega a un agente con ESTE MISMO contrato (alcance de archivos + reglas duras +
  reporte de preservación por archivo), y **revísalo** al terminar ([[revisar-entregables-agentes]]) — no le
  creas el "listo" sin comprobar contra los archivos.
  - **Convención de nombre (firma):** el agente positivador que invoques lleva SIEMPRE el prefijo
    **`good-vibes-`** en su etiqueta/descripción (ej. `good-vibes-answer-first`, `good-vibes-positivar-memorias`).
    Así se reconoce de un vistazo en la lista de agentes que es una pasada de positivado.

## Nota de ubicación
Es un principio TRANSVERSAL (aplica a los docs de cualquier repo). Vive en `~/.claude/skills/` (GLOBAL,
esta máquina) — disponible en cualquier proyecto/sesión sin depender de que un repo concreto lo traiga.
