---
name: turno-nocturno
description: >
  Protocolo para cuando el usuario deja a Claude trabajando SOLO de noche: eco del contrato antes de
  que se duerma (alcance, criterio de cierre MEDIBLE, lo intocable, dónde queda VISIBLE el resultado),
  preflight de herramientas/quota/autorizaciones, regla de decisión (dentro del alcance DECIDE y
  sigue; fuera, parquea y brinca — la noche nunca muere por un ítem), pacing consciente de cuota
  (lee el snapshot real del widget, pacea con headroom, duerme al reset si no lo hay — y `/loop`
  para cruzar fronteras de ventana desatendido), autorización durable a disco que sobrevive
  compactaciones, motor con oráculo externo + deployable=deployed, checkpoint cada ~2h, relanzador
  antes de cerrar y reporte de la mañana. Actívalo con `/turno-nocturno <encargo>` o ante señales
  tipo "ya me voy a dormir, te lo encargo esta noche".
---

# turno-nocturno — trabajar solo de noche sin morir por un ítem

Cuando el usuario se va a dormir y te deja un encargo, el contrato cambia: **el acotamiento YA ES la
autorización**. En palabras del usuario: *"lo del claude nocturno suelo acotarlo muy intencionalmente
a algo en lo que esté cómodo con dejar que tú decidas por mí"*. Dentro de esa cerca, **decidir ES lo
que se te pidió** — preguntar al aire a las 3am no es prudencia, es fallar el encargo. Fuera de la
cerca, la frontera es DURA: se parquea, no se cruza.

> **Por qué existe.** De un análisis forense sobre transcripts reales (cps, 8–17 jul): una noche
> funcionó perfecto (encargo acotado + criterio medible + Claude decidiendo dentro de la cerca) y
> varias murieron por modos de falla ya identificados:
> - **Sobre-cautela:** inventar una "decisión bloqueante" sobre un sandbox REVERSIBLE y esperar 9h
>   una respuesta que nadie iba a dar.
> - **Alcance literal:** "avanza con Fase 3" → terminó Fase 3 y preguntó "¿sigo?" a las 22:20 con el
>   usuario dormido — la noche entera desperdiciada por leer el encargo como techo y no como piso.
> - **Autorización evaporada:** un OK dado en el chat murió al compactarse el contexto; el resto de
>   la noche operó sin él.
> - **Trabajo invisible:** todo "verde en rama" pero NO desplegado al stack de QA → en la mañana el
>   usuario no tenía NADA que ver.
> - **Spend limit:** el límite mensual de gasto mató una noche a medias, sin chequeo previo (mecanismo
>   que lo cierra: §4, Pacing consciente de cuota).

## 1. Activación + ECO DEL CONTRATO

Se activa **explícitamente** (`/turno-nocturno <encargo>`) o por **señales** ("ya me voy a dormir /
a mimir", "te lo encargo esta noche", "mañana lo vemos, avanza tú").

Al activarse, ANTES de que el usuario se duerma, devuélvele el **eco del contrato** en pocas líneas
— es su última oportunidad de corregirte, úsala:

- **(a) Alcance** — en qué decide Claude SIN preguntar (la cerca dentro de la cual todo es tuyo).
- **(b) Criterio de cierre MEDIBLE** — cuándo la noche "ganó". Ejemplo real: *"≥80 OTs reflejando su
  seguimiento al 95%"*. "Avanzar bastante" NO es criterio.
- **(c) Lo ÚNICO intocable** — qué NO se toca aunque parezca buena idea.
- **(d) Dónde queda VISIBLE el resultado en la mañana** — un lugar que el usuario pueda ABRIR:
  *":9582 desplegado"*, no *"en rama"*.

Si el usuario no corrige el eco, ese texto ES el contrato de la noche. Guárdalo en
`hilo-mental-actual.md` (skill `checkpoint`) para que sobreviva compactaciones.

## 2. Regla de decisión (el corazón del protocolo)

- **Dentro del alcance → DECIDE.** Toma la decisión, documéntala como **"provisional nocturna
  (revísala en la mañana)"** en la bitácora, y SIGUE. **Prohibido** inventar gates, "decisiones
  bloqueantes" o preguntas de bifurcación sobre cosas reversibles dentro de la cerca — eso es la
  sobre-cautela que mató noches enteras.
- **Fuera del alcance → PARQUEA.** Anota el ítem en la bitácora con su **pregunta ya redactada**
  (lista para que el usuario la conteste con un sí/no en la mañana) y **BRINCA al siguiente ítem**.
- **La noche NUNCA muere por un ítem.** Un ítem trabado (parqueado o bloqueado) jamás detiene el
  turno completo: siempre hay siguiente ítem, relanzador o reporte que preparar.

## 3. Preflight (antes de que el usuario se duerma)

Mientras el usuario todavía contesta, verifica y PIDE lo que la noche va a necesitar:

- **Herramientas vivas:** si habrá QA visual, Chrome conectado y respondiendo AHORA (no lo descubras
  a las 2am); accesos a BD/stack que el plan requiera.
- **Quota/spend — lee el SNAPSHOT del widget de cuota, no adivines.** `jq` el `state.json` (ruta,
  campos exactos y algoritmo de pacing: **§4**) y decide si el margen alcanza para el plan de la
  noche; si el overage no tiene holgura (`.extra_usage`), dilo ANTES de que se duerma — una noche
  real murió a medias por esto, descubierto ya de madrugada.
- **Autorizaciones operativas AHORA:** pide de una vez los permisos que sabes que vas a necesitar
  (`docker exec`, tocar la BD de dev, wipe+recarga N veces, reconstruir el stack) — a las 3am ya no
  hay quién los dé.

## 4. Pacing consciente de cuota (el ancla a la realidad — aplica TODA la noche)

El **widget de cuota** (su daemon — Linux: el plasmoid `src/plasmoid`; Windows: `QuotaService`;
macOS: `cortex-fetch`) escribe un **snapshot** con el estado REAL de tus ventanas a
`${XDG_CACHE_HOME:-~/.cache}/cortex/state.json` (macOS: `~/Library/Caches/cortex/state.json`) — el
MISMO archivo que ya lee `linea_cuota()` en `delegacion-comun.sh`. Ese snapshot es la fuente de
verdad para pacear la noche — **nunca** un número mágico ni tu "sensación de avance".

Campos reales que importan (cítalos textual, no los inventes — schema de `cortex-fetch`):
`.five_hour.percent` (0-100), `.five_hour.resets_at` (ISO-8601 UTC), `.five_hour.is_active`,
`.weekly.{percent,resets_at}` (misma forma, ventana de 7 días), `.spend.{used,cap,percent,enabled}`
(gasto REAL en dinero, si tu plan lo expone) y `.extra_usage.{utilization,enabled}` (overage).

**El algoritmo, al ARRANCAR cada rebanada:**
1. **Lee el snapshot.** `pct=$(jq -r '.five_hour.percent' state.json)`,
   `reset=$(jq -r '.five_hour.resets_at' state.json)`.
2. **Frescura antes que nada.** Si `state.json` tiene más de ~5 min de mtime, el daemon puede estar
   caído: trátalo CONSERVADOR (asume poco headroom) en vez de pacear con un dato viejo como si
   fuera fresco.
3. **Con headroom** (`five_hour.percent` bajo ~80-85% y `resets_at` lejos): trabaja de corrido,
   encadena rebanadas, sleep mínimo — dentro de la ventana de 5h el tier es **incluido** ($0
   marginal): úsalo, no lo raciones de más.
4. **Cerca del tope: NO te estrelles contra el 100%** (eso te congela hasta el reset). En vez de
   eso, programa el próximo despertar para justo DESPUÉS de `resets_at`:
   ```bash
   delay=$(( $(date -d "$reset" +%s) - $(date +%s) + 60 ))   # +60s de colchón
   ```
   Si el reset está a más de 1h, encadena heartbeats intermedios en vez de un solo sleep largo.
5. **Esto es lo que mata el chokepoint del turno nocturno:** dormir-hasta-el-reset convierte el
   "freeze esperando que un humano dé ok" en un **resume AUTOMÁTICO y planeado** — la noche cruza
   fronteras de ventana sola, sin que nadie la despierte a mano.

**Caveat DURO — overage agotado = la ventana de 5h es TECHO, no sugerencia.** Si
`.extra_usage.enabled` es `false`, o `.extra_usage.utilization` ya está topado, no hay colchón:
llegar al 100% de la ventana de 5h te **congela hasta el reset** (no cae a metered). El hook
`limite-gasto.sh` bloquea reclutar agentes justo en esa combinación (ventana agotada Y overage sin
holgura) — el pacing de arriba es la versión "para ti mismo", antes de llegar ahí. Con overage
habilitado y con holgura, exceder la ventana solo cuesta $ metered (sigue respetando
`limite-gasto`/`delegacion-gate`). Por eso el preflight (§3) exige revisar `.extra_usage` ANTES de
que el usuario se duerma: sin holgura, el pacing-al-reset deja de ser opcional.

**`/loop` — lo que SOLIDIFICA el turno nocturno a través de las ventanas.** El ancla-cuota de arriba
es el **NÚCLEO** (aplica siempre, con o sin `/loop`); `/loop` es el **MECANISMO** que la hace
sobrevivir fronteras de ventana sin el clic manual del usuario:
- **Sin `/loop` (corrida continua):** la sesión sigue viva y ella misma consulta el snapshot entre
  rebanadas, pautando cuándo pacear o dormir — funciona mientras la sesión no se cierre.
- **Con `/loop` (modo dinámico + `ScheduleWakeup`):** cada despertar re-lee el snapshot, aplica el
  algoritmo de arriba (pacea si hay headroom, duerme al reset si no) y despierta con ventana fresca
  a seguir el MISMO contrato, sin que el usuario tenga que re-invocar nada. Invócalo **sin intervalo
  fijo** (`/loop <encargo>`, dejando que el modelo se auto-paceé contra el snapshot) en vez de un
  timer ciego; `ScheduleWakeup` clampa el despertar a un rango razonable, así que no confíes en que
  duerma exactamente el `delay` calculado si cae fuera de rango.

Un turno nocturno acotado con `/loop` corre hasta CERRAR el contrato (§8-9) a través de varias
ventanas de 5h, desatendido — eso es lo que lo "solidifica".

## 5. Autorización durable a disco (sobrevive compactaciones)

Un OK que solo vive en el chat se evapora al compactar (pasó en una noche real). Todo grant que deba
sobrevivir la noche se escribe a disco, en el **contrato compartido**:

`${CLAUDE_PROJECT_DIR}/.claude/memory/autorizaciones-vigentes.local.md`
(los `*.local.md` ya van gitignored; `mkdir -p` si falta la carpeta)

Una línea por grant, **appendeada con `>>`** (no con un Edit):

```
- scope=merge-develop vence_epoch=<unix> vence="<legible>" cita="<frase TEXTUAL del usuario>" registrada=<ISO>
```

Reglas duras:
- **Se escribe SOLO con OK explícito del usuario** — la `cita` son sus palabras LITERALES, no tu
  paráfrasis. Sin cita textual, no hay grant.
- **"Hasta mañana" sin hora → vence a las 10:00 locales del día siguiente.**
- **`scope=merge-develop` JAMÁS cubre `main`.** Un release a main no es delegable a un grant
  nocturno, punto.
- **Poda las vencidas** (por `vence_epoch` contra la hora actual) cada vez que escribas el archivo.
- Epoch portable GNU/BSD:
  ```bash
  # GNU (Linux / coreutils) con fallback BSD (macOS)
  V=$(date -d 'tomorrow 10:00' +%s 2>/dev/null \
      || date -j -f '%Y-%m-%d %H:%M' "$(date -v+1d +%Y-%m-%d) 10:00" +%s)
  ```

Quien verifique un grant (p. ej. antes de un merge a develop) lee ESTE archivo, no su memoria del chat.

## 6. Motor de la noche

1. **Encargo → LISTA VERIFICABLE.** Convierte el encargo en ítems **observables** (TaskCreate/lista):
   cada ítem se puede comprobar contra evidencia externa, no contra tu propia sensación de avance.
2. **Loop por ítem, con ORÁCULO EXTERNO.** Cada ítem se verifica contra la realidad: clics y
   mediciones en Chrome, consultas a la BD, respuestas HTTP — **nunca a ciegas**. Si el oráculo se
   cae (Chrome muerto, BD inalcanzable): márcalo **BLOQUEADOR** en negritas en la bitácora y sigue
   con los ítems que NO lo requieran. No finjas verificación que no hiciste.
3. **Red de reversibilidad.** Snapshot ANTES de tocar la BD; lo que rompas lo restauras; al saltar de
   ítem dejas estado limpio. Trabajar agresivo dentro de la cerca es correcto PORQUE hay red.
4. **Deployable = deployed.** Todo fix termina con el stack de QA **reconstruido y arriba** — trabajo
   "verde en rama" pero no desplegado es trabajo INVISIBLE en la mañana (modo de falla real).
5. **Commits granulares** a la rama/mini-develop conforme avanzas — nada de un mega-commit al final.

## 7. Checkpoint nivel COMPLETO cada ~2h

Corre el skill `checkpoint` (con contrato + decisiones + parqueados + grants activos en
`hilo-mental-actual.md`) **cada ~2 horas** de trabajo. En una noche real hubo **3 compactaciones** y
cada una borró decisiones que solo vivían en el chat. El auto-compact no avisa: el checkpoint es
proactivo o no sirve. Aprovecha el mismo punto para releer el snapshot de cuota (§4): si estás cerca
del tope, este checkpoint es tu último punto de retorno limpio antes de programar el sueño-al-reset.

## 8. RELANZADOR (antes de creer que terminaste)

Al creer que la lista quedó, **NO cierres**: re-audita la lista **ítem×ítem contra evidencia real**
(el oráculo otra vez, no el recuerdo de haberlo hecho). En la noche real que funcionó, este re-barrido
destapó un botón faltante que el primer pase dio por hecho. Después, **revisa los ítems parqueados**
por si algo de lo avanzado los destrabó (un parqueado que ya no depende de la pregunta se trabaja).
Solo entonces se cierra el turno. Antes de cerrar, confirma también que el pacing de cuota (§4) no
dejó una rebanada colgada por falta de headroom: si el snapshot muestra la ventana agotada y el
overage sin holgura, el turno sigue VIVO dormido-al-reset (§4), no cerrado — el reporte de la
mañana (§9) no se escribe hasta que de verdad termine.

## 9. Reporte de la mañana

Lo primero que el usuario lee al despertar. Formato:

- **Ítem×ítem** con su **evidencia** (qué se midió/observó) y **dónde VERLO** (URL, puerto, pantalla).
- **Decisiones provisionales nocturnas** marcadas como tales, con su porqué en una línea — invítalo a
  revisarlas, no las entierres.
- **Parqueados** con su pregunta ya redactada (contestable con un sí/no).
- **Lenguaje de estatus honesto** (definición de LISTO): "verificado técnicamente", "en preview",
  "pendiente de tu QA" — nada quedó "listo" porque el usuario dormía; lo declara él.

## 10. Qué NO es

- **No autoriza merges a `develop`** sin un grant durable VIGENTE en `autorizaciones-vigentes.local.md`
  (cita textual + no vencido). Sin grant, el trabajo se queda en la rama/mini-develop.
- **Releases a `main`: JAMÁS de noche.** Ningún grant nocturno los cubre.
- **No excusa QA a ciegas.** "Era de noche" no convierte una suposición en verificación — sin oráculo,
  el estatus es "sin verificar" y se dice así.
- **El acotamiento del usuario es frontera DURA.** El protocolo te da agresividad DENTRO de la cerca,
  nunca permiso para moverla.
