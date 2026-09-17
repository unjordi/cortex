---
name: auditar-proceso-algoritmo
description: Manda un auditor experto READ-ONLY (procesos industriales/logísticos + análisis de algoritmos) a revisar a fondo un flujo de negocio o el propio sistema, y entrega hallazgos priorizados SIN tocar nada. Aliméntalo con los flowcharts (skill diagramar) + la investigación de dominio.
---

# Auditar proceso + algoritmo (auditor experto, read-only)

Delega en un **agente-auditor experto** una revisión PROFUNDA de un flujo —de negocio o del propio
cerebro— desde dos lentes a la vez: **(a) procesos industriales/logísticos** (¿el flujo modela bien
la realidad operativa? ¿faltan pasos, hay huecos, contradicciones, casos sin cubrir?) y **(b) análisis
de algoritmos** (¿la lógica que implementa el flujo es correcta, completa, eficiente? ¿hay corner
cases, off-by-one, estados imposibles, complejidad escondida?). El auditor **AUDITA, NO modifica**:
su entregable son **hallazgos priorizados**, no un diff.

> **Por qué existe.** Este patrón se usó suelto ≥3 veces con la misma esencia (cps: auditar el flujo
> de manejo de proyectos de la app de logística; el propio cerebro: barrerlo por inconsistencias y
> huecos; fluxcore: paridad vs el estándar de la plantilla) y **nunca tuvo casa durable** — cada vez
> se re-improvisaba el prompt. Aquí queda destilado. Es hermano de [[diagramar]]: **primero diagramas
> el proceso con calidad, luego se lo das al auditor** — sin el mapa, el análisis no sale fino.

## Cuándo usarlo
- Antes de dar por "a la par" o "correcto" un flujo importante (dominio de negocio, algoritmo de
  cálculo, máquina de estados) — el auditor caza lo que el build verde y tu propia cercanía no ven.
- Para barrer un **sistema entero** (el cerebro: hooks/skills/normas/docs; una arquitectura) buscando
  **inconsistencias y huecos** — afirmaciones que se contradicen, ramas sin cubrir, doc que miente.
- Como complemento (no sustituto) de tu QA: **el auditor hace el análisis profundo de proceso+algoritmo
  mientras tú haces tu pasada de UX/funcional con ojos frescos**. Dos lentes distintas, en paralelo.

## Los INPUTS que decide la calidad (dale de comer bien o no rinde)
El auditor es tan bueno como lo que le des. En orden de impacto:

1. **Los flowcharts de cada proceso — casi obligatorios ("los zapatos para salir a caminar").**
   Diagrámalos ANTES con [[diagramar]], a la calidad real (no un boceto): el auditor razona sobre el
   MAPA del flujo, no reconstruyéndolo de cero de la cabeza. Sin flowcharts revisados con cuidado, el
   análisis es superficial. Técnicamente opcional, en la práctica es lo que separa un dictamen fino de
   uno genérico. Si no existen, **el primer paso es diagramarlos** (o pedirlos), no arrancar sin ellos.
   **Regla dura (no la olvides):** cada flowchart que le des DEBE llevar su **LEYENDA** (qué significa
   cada forma/color/flecha) **y las NORMAS aplicables** — es el contexto MÍNIMO para que entienda la
   notación y las reglas del juego. Un diagrama pelón, sin leyenda ni normas, lo hace auditar a ciegas.
2. **Todo el contexto de dominio + investigación** que ya hiciste y documentaste (buenas prácticas del
   rubro, el legado, las reglas de negocio, la arquitectura). Dáselo COMPLETO, no resumido.
3. **(Opcional) datos de estrés sembrados.** Para auditar un algoritmo, siembra un caso que lo estire
   —p. ej. "4 operaciones con 1 a 5 insumos, y una operación multi-insumo que fuerce el cruce"— para
   que el auditor razone sobre entradas concretas, no solo en abstracto.

## Los dos modos
- **(A) Flujo de una APP** — audita un flujo de negocio/algoritmo concreto de una aplicación (el caso
  cps: manejo de proyectos, asignación de insumos a operaciones). Entrada: flowcharts del flujo +
  dominio + datos de estrés.
- **(B) Un SISTEMA / el propio cerebro** — barre un sistema entero por **inconsistencias y huecos**
  (el caso brain: hooks/skills/normas/docs que se contradicen o dejan ramas sin cubrir). Entrada: el
  diagrama del sistema "que refleja la REALIDAD, con sus huecos marcados a propósito" + las fuentes.

## Método: INDIVIDUAL → COLECTIVO (dónde puede tronar)
Cuando hay **varios flowcharts** (lo normal), pídele DOS pasadas, no una:
1. **Individual** — cada flowchart por separado: ¿dónde puede **tronar SOLO**? (paso faltante, rama sin
   cubrir, estado imposible, off-by-one, supuesto no dicho).
2. **Colectivo** — TODOS juntos: ¿dónde pueden **tronar EN CONJUNTO**? Una pieza correcta por sí sola
   puede **contradecir** a otra, competir por el mismo recurso, o dejar un hueco en la costura entre dos
   flujos. Esta pasada es la que caza las inconsistencias que ninguna revisión pieza-por-pieza ve.

El dictamen separa los hallazgos **individuales** de los **colectivos** (de costura) — son de naturaleza
distinta y se atienden distinto.

## El prompt del agente (persona + encargo)
Delega con `Task`/subagente. Persona y encargo (adáptalo al target, conserva la ESENCIA):

> Eres un **Ingeniero de Calidad senior, experto en (a) PROCESOS INDUSTRIALES/logísticos y (b) ANÁLISIS
> DE ALGORITMOS**. Tu trabajo es **auditar —NO modificar—** `<el flujo / sistema>`. Te doy: los
> flowcharts de cada proceso `<rutas>`, la investigación de dominio y buenas prácticas `<rutas>`, y
> `<datos de estrés / fuentes>`. Analiza con AMBAS lentes: como proceso (¿modela bien la realidad
> operativa? ¿pasos faltantes, huecos, contradicciones, casos sin cubrir?) y como algoritmo (¿correcto,
> completo, eficiente? ¿corner cases, estados imposibles, complejidad escondida, off-by-one?). Analiza
> **cada flowchart INDIVIDUALMENTE y luego TODOS JUNTOS**, e indica **dónde pueden tronar individual y
> colectivamente** (una pieza correcta sola puede contradecir a otra en conjunto). Contra los datos de
> estrés, razona el resultado paso a paso. **Entrega HALLAZGOS PRIORIZADOS por severidad** (crítico →
> menor), separando los individuales de los colectivos, cada uno con: qué, dónde, por qué es un problema,
> y una recomendación. **No toques código ni archivos**: tu salida es el dictamen, no un parche.

### Prompt original (battle-tested — el que lo estrenó, sobre los flowcharts del cerebro)
> Saca un agente Auditor de Calidad experto en procesos industriales Y análisis de algoritmos y pídele
> que analice todos nuestros flowcharts individualmente y luego todos juntos y que nos indique en dónde
> pueden tronar individualmente y colectivamente. No olvides que todos los flowchart que le des lleven
> la leyenda y las normas para que tenga el contexto mínimo.

## Reglas duras
- **Se audita LA MÁQUINA, no el manual.** Si el target tiene maquinaria EJECUTABLE, el auditor la EJECUTA
  (sandbox) y mide la CAPACIDAD de sus dependencias instaladas — no su descripción. Y **el entregable
  prioriza MECANISMO sobre prosa**: lo que se pueda volver código/gate/test se entrega así. Detalle, con el
  caso que lo destiló (3 rondas de auditoría que engordaron un manual mientras la máquina seguía sin
  arrancar): [[auditar-coherencia-cerebro]] → «Regla de oro» y «El ENTREGABLE del auditor».
- **Read-only de verdad.** El auditor no muta archivos ni commitea. Corre sin worktree de escritura;
  si necesitara reproducir algo que muta estado, lo aísla — pero por defecto solo LEE y razona.
- **Consentimiento de costo.** Reclutar el agente pasa por el gate de delegación (`delegacion-gate`):
  pide el consentimiento window-aware antes de lanzarlo.
- **Ningún hallazgo se queda solo en el chat.** Al volver, **persiste los hallazgos al backlog vivo**
  (`estado-proyecto.md` / la nota del tema) con su severidad y de dónde salieron — aunque solo se
  atienda un subconjunto. El chat no es la fuente de verdad; el backlog sí.
- **El auditor NO declara LISTO.** Su dictamen es insumo; el cierre sigue exigiendo tu QA o tu
  autorización expresa (definición de LISTO). Un flujo "auditado sin hallazgos graves" es *verificado*,
  no *confirmado*.
- **Fan-out si el target es grande.** Si son varios flujos/módulos independientes, lanza un auditor por
  pieza en paralelo (ver [[orquestar-fanout]]) en vez de uno serial gigante.

## Lo que un banco VERDE no prueba (corpus medido, sep-2026)

Destilado de dos sistemas auditados el mismo día: un cerebro con **1232 asertos en verde** que tenía dos
críticos vivos, y un toolkit con **seis bancos en verde** al que tres lentes le encontraron **18 hallazgos,
cuatro de ellos críticos**. En ambos, el arnés bendecía la mecánica **sin llegar nunca a la intención**.
Cuando audites una suite, busca estas seis formas antes que ninguna otra:

- **El fixture INVENTA la realidad.** Los mocks emitían valores que la herramienta real **nunca produce**:
  un timer monotónico con hora de calendario, un LaunchDaemon ocioso marcado `running`, un nombre de unidad
  que ya traía su sufijo, un `wg show <nombre lógico>` que el binario no soporta. **No simplificaron la
  realidad: la fabricaron**, y por eso el verde no significaba nada. → *Cuando se mockea una herramienta, el
  valor se CAPTURA de su salida real (`systemctl show`, `launchctl print`), no se escribe a mano.*
- **El caso benigno no prueba el caso peligroso.** El banco probaba el `.conf` **ya en su sitio** — el único
  camino que no copia — y así no vio un `--dry-run` que **sobrescribía la config de un túnel vivo**. Lo
  mismo con la concurrencia: probaba dos actores sobre un lock **huérfano** y nunca contra un **dueño vivo**
  (con un esperador, cero violaciones; con dos, violación siempre). → *Pregunta siempre qué escenario
  monta el test, y si es el que duele.*
- **El escenario de prueba monta lo que producción NO monta.** Todos los bancos llamaban a mano una función
  de setup que `main()` **nunca invocaba**; el producto real salía inerte desde el primer tick y el banco
  seguía verde. → *Un test que prepara el mundo a mano prueba el mundo preparado a mano.*
- **La regresión anclada a una referencia MÓVIL se auto-desactiva.** Cuatro bancos comparaban contra `HEAD`:
  en cuanto avanza la rama, la prueba deja de ver rojo **para siempre**, y la doc seguía citándolas como
  evidencia de que "el banco sí ve rojo". → *Las regresiones se anclan a SHA fijo.*
- **El banco que muere a media corrida y sale 0.** Sin imprimir un solo FAIL: indistinguible de un verde.
  → *Toda suite necesita un centinela (`trap EXIT`) que distinga "terminé" de "me morí".*
- **Definido ≠ cableado.** Seis de once predicados de verificación existían y **nadie los invocaba** — y
  eran justo los que medían el EFECTO (el archivo quedó, sobrevive al reboot, el nombre resuelve, el túnel
  subió); los que sí corrían medían el **registro del scheduler**. → *Verifica que el mecanismo esté
  INVOCADO desde el camino real, no que exista.*

## Cuándo el defecto no es el defecto: sospecha del NIVEL DE ABSTRACCIÓN

**Si dos rondas de arreglo sobre la misma pieza producen dos FAMILIAS distintas de defectos, deja de
parchear y pregunta si el problema es dónde vive la pieza.**

Caso que lo destiló (sep-2026): un primitivo de exclusión mutua hecho a mano con `mkdir`. Ronda 1, cuatro
críticos (bucle infinito, check-then-delete, liberación sin propiedad, lock que sobrevive al reboot). Ronda
2, sobre el arreglo: **el fix introdujo algo peor** — una ventana de 2–5 ms en la que cinco de cinco
esperadores entraban a la sección crítica contra un dueño **vivo**, escalando con la contención. La
pregunta correcta no era "¿cómo arreglo esta ventana?" sino **"¿por qué estamos construyendo a mano un
primitivo que el sistema operativo ya ofrece?"**. La respuesta estaba a un `man` de distancia: `flock(1)`
en Linux, `lockf(1)` en macOS (nadie lo miró porque buscaban `flock`, que ahí no existe), `Mutex` del
kernel en Windows — y con el lock sostenido por el kernel, **las dos familias de defectos dejan de tener
dónde existir**.

Señales de que estás en este caso: los arreglos son correctos individualmente y aun así aparece otro ·
la pieza tiene un equivalente en el sistema operativo o en una librería estándar · una plataforma del
proyecto ya resuelve el problema "gratis" y las otras lo sufren (eso NO es que esa plataforma tenga suerte:
es que usa el nivel correcto).

## Re-auditar lo que se acaba de reescribir (regla dura)

**Una pieza recién reescrita es lo ÚLTIMO que se da por bueno a la primera**, y menos si es concurrencia,
seguridad o un primitivo del que cuelga el resto. Un arreglo NO cierra la auditoría: la reabre sobre código
nuevo que nadie ha mirado. En el caso de arriba, la segunda pasada existió porque se pidió expresamente —
y encontró que el arreglo había empeorado el sistema. Sin ella se habría desplegado a cinco máquinas.

Corolario para el ORQUESTADOR: al re-auditar, **dile al auditor qué se arregló y pídele que busque lo que
apareció AL LADO**, no lo que ya se cerró. Y deja explícito que **declarar convergencia es un resultado
válido y esperado**: un dictamen limpio y fundado vale igual que uno lleno de hallazgos, y sin decirlo el
auditor tiende a inventar un crítico marginal para justificar la corrida.

## Pídele al auditor que TE corrija

En la tanda que destiló estas reglas, los auditores corrigieron al orquestador **media docena de veces** —
un supuesto falso en el encargo, una cifra mal medida, una prueba que no era la más valiosa, un diagrama
que no reflejaba el hoy. Cada corrección mejoró el resultado. **Ponlo en el encargo de forma explícita:**
*"si algo de lo que te dije resulta falso al medirlo, corrígeme con la evidencia en vez de acomodarlo"*.
Un auditor que trabaja sobre premisas falsas del orquestador audita otra cosa.

## Par con diagramar
[[diagramar]] produce el mapa; **auditar-proceso-algoritmo** lo consume. El flujo natural es:
`diagramar el proceso (calidad real) → dárselo al auditor → hallazgos priorizados → al backlog`.
Por eso nacieron en la misma tanda: son las dos mitades de "entender un flujo a fondo antes de tocarlo".
