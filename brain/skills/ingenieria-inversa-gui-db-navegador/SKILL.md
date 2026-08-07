---
name: ingenieria-inversa-gui-db-navegador
description: Método REUSABLE (independiente de app/dominio) para hacer ingeniería inversa de cualquier sistema legacy con GUI + base de datos — driving la UI real vía navegador (claude-in-chrome u otro plugin) mientras se diffea el estado (BD y/o filesystem/config) antes/después de cada acción, para producir documentación con evidencia real en vez de suposición. Incluye el estándar de DIFF COMPLETO ("indistinguible de la GUI"): fingerprint de TODA la BD antes/después para atrapar cualquier tabla tocada, no solo las candidatas — obligatorio cuando el objetivo es reproducir el proceso (p.ej. en un SP) de forma idéntica a la GUI. Úsalo cuando necesites entender/documentar cómo funciona por dentro una app de escritorio o web legacy sin código fuente disponible — ASPEL SAE/COI/NOI, u otro sistema similar en el futuro. Requiere: navegador con automatización (claude-in-chrome), un visor web de la máquina donde corre la GUI (VNC/RDP-sobre-navegador), y acceso directo a la BD/filesystem que la GUI usa.
---

# Ingeniería inversa GUI+BD vía navegador — método destilado

> Nace del turno nocturno 2026-07-21/23 sobre ASPEL SAE9 (repo `potenciaDatabases`): en una sola
> corrida se documentaron empíricamente 16 procesos de negocio (matriz completa compras+ventas,
> Directa+Enlazada), con evidencia real de BD antes/después para cada uno, cero suposiciones. El
> resultado fue calificado por unjordi como "salió perfecto" — este skill destila QUÉ hizo que
> funcionara, para no reinventarlo cada vez que haya que atacar un sistema legacy nuevo (SAE9 hoy;
> mañana podría ser COI, NOI, Banco, o algo totalmente distinto).

## Cuándo usar esto
Cuando la pregunta es **"¿qué hace esta app por dentro cuando el usuario hace clic en X?"** y no
hay código fuente, o el código fuente no es confiable (vistas/SPs/triggers como única
documentación real, sin ni una FK). La única fuente de verdad es **observar el comportamiento real**:
ejecutar la acción de verdad en la UI y ver qué cambió en los datos. Aplica a:
- Sistemas ERP/ASPEL legacy (SAE, COI, NOI, Banco) — el caso que lo originó.
- Cualquier otra app de escritorio/web sin código fuente accesible, donde la única forma honesta
  de documentar el comportamiento es reproducirlo y medirlo.

**NO uses este método si** el código fuente SÍ está disponible y es confiable — ahí lees el
código, no reconstruyes por arqueología (más lento y con más incertidumbre que leer la fuente).

## Prerrequisitos — checklist de infraestructura (verifícalo ANTES de empezar)
Si falta una pieza, el método completo no funciona — no arranques sin confirmar las 4:

1. **Navegador con automatización real** — `claude-in-chrome` (u otro plugin de browser
   automation que surja). Verifica que responde ANTES de empezar (`tabs_context_mcp`) — un
   "extension not connected" a medio proceso es un bloqueador real, no cosmético (ver gotcha
   abajo).
2. **La GUI corriendo en una máquina alcanzable vía navegador** — típicamente una VM (Windows u
   otro OS) con un visor web tipo noVNC (`dockur` es el patrón ya probado: levanta la VM en
   Docker, expone un visor web sin necesitar cliente RDP/VNC nativo). El navegador entra a esa URL
   como si fuera cualquier página — así `claude-in-chrome` puede operar la app legacy sin
   necesitar un plugin específico de RDP/VNC.
3. **Base de datos dockerizada/local, accesible DIRECTO desde el agente** (no solo desde la GUI) —
   típicamente vía un driver tipo `pyodbc`/`psycopg2` desde Bash, en paralelo a lo que la GUI usa.
   Dos modalidades, y hay que saber cuál aplica:
   - **Sandbox 100% desechable** (datos sintéticos, wipe+reload libre) — para experimentos
     controlados donde SÍ importa la secuencia exacta de altas (contadores, folios, trazabilidad).
   - **Copia de datos REALES** (backup de producción restaurado en el mismo servidor sandbox) —
     para arqueología sobre casos reales que el sandbox sintético no puede replicar a propósito
     (miles de proveedores, años de histórico, edge cases reales). **Antes de tocar esta segunda
     modalidad, confirma con el usuario el modo de trabajo** (¿solo lectura, o también autorizado
     a dar de alta pruebas ahí?) — el perfil de riesgo cambia por completo aunque técnicamente
     sea "solo una copia". Regístralo en la autorización durable si el usuario amplía el permiso
     en vivo (ver `turno-nocturno` §4 para el mecanismo).
4. **La GUI ya CONFIGURADA y apuntando a la BD que vas a diffear, con un login/smoke-test real
   confirmado** (sin errores en el ribbon/pantalla principal). **Gotcha real (2026-07-23):** una
   investigación de "por qué el saldo que muestra la interfaz no cuadra con mi vista SQL" es
   IMPOSIBLE de resolver con SQL solo — necesitas la GUI apuntando a la MISMA base para ver la
   pantalla real y compararla contra la query. Si la pregunta menciona "la interfaz muestra X",
   ese prerrequisito #4 es innegociable antes de escribir una sola query.

## El loop central (la médula del método)
Por cada proceso/pantalla/acción que quieras documentar:

1. **Antes de tocar la UI**: snapshot del estado. Para un hallazgo EXPLORATORIO basta un snapshot de
   tablas candidatas (contadores tipo `TBLCONTROL01`, catálogos, maestras), o de carpetas/archivos si
   es de config/filesystem. **Pero si el objetivo es REPRODUCIR el proceso (un SP, una migración) de
   forma indistinguible de la GUI, el snapshot de candidatas NO basta — usa el DIFF COMPLETO de la
   sección siguiente** (fingerprint de TODA la BD), porque las candidatas SIEMPRE dejan tablas fuera.
2. **Ejecuta la acción REAL en la UI** — clics y tecleo reales vía el navegador, no simulados.
   Screenshot en cada paso ambiguo; `zoom` si un elemento es chico. Si algo no responde como se
   esperaba, ver Gotchas abajo antes de asumir que es un bug de la app.
3. **Después**: vuelve a consultar las MISMAS tablas/carpetas, diff explícito contra el snapshot
   de antes.
4. **Documenta el hallazgo** en un archivo dedicado (un `.md` por proceso/caso de uso, ver
   convención de nombres abajo) con: ruta exacta en la UI (clics, atajos, gotchas encontrados),
   evidencia de BD/filesystem antes→después, y la conclusión. **Un resultado negativo ("no pasó
   nada") también es evidencia real — documéntalo igual**, no lo descartes por "no hubo hallazgo".
5. **Generalización clave**: el "estado" a diffear NO tiene que ser solo BD. Carpetas de
   configuración, archivos `.ini`, el registro de Windows, permisos de archivo — cualquier cosa
   que la app toque cuando el usuario actúa se diffea con el MISMO loop, solo cambia la
   herramienta de snapshot (un `dir`/`ls`/hash de carpeta en vez de una query SQL). No trates esto
   como un chore aparte del proceso principal — es el mismo método.

## Diff COMPLETO de estado — el estándar «indistinguible de la GUI» (obligatorio para reproducir)

> **REGLA MÁXIMA cuando el objetivo es REPRODUCIR un proceso (un SP, una migración, un sync):** lo que
> haga tu código debe ser **INDISTINGUIBLE de lo que hace la GUI** al ejecutar el mismo proceso. Si el
> estado que deja tu código difiere del que deja la GUI **de CUALQUIER manera** (una tabla sin tocar, un
> contador sin avanzar, un satélite `_CLIB01` faltante, un flag distinto), fallaste. La única evidencia
> que satisface esto es un **diff de estado COMPLETO** — el equivalente de escritura de la paridad
> `EXCEPT` de las lecturas.

**Por qué el snapshot de "tablas candidatas" NO alcanza (lección real, 2026-07):** la RE original de
`proceso-orden-enlazada.md` (convertir requisición→orden) snapshoteó solo candidatas
(`TBLCONTROL01` + las tablas destino `COMPO01`/`PAR_COMPO01`/`DOCTOSIGC01`). Capturó bien el enlace
bidireccional y el avance del contador global — **pero NO capturó si `PAR_COMPQ01.PXR` (la partida de
la requisición ORIGEN) cambia**, porque `PAR_COMPQ01` no estaba en la lista de candidatas. Justo ese
dato (¿el "documento anterior" se recalcula?) es el que un SP necesita para ser indistinguible. Con un
fingerprint de TODA la BD, la tabla origen habría saltado en el diff aunque nadie la anticipara. Moraleja:
**para reproducir, se diffea TODO, no lo que uno cree que se toca.**

### El método del fingerprint completo (dos pasadas)
Herramienta de referencia SQL Server: [`reference/fingerprint-estado-bd.sql`](reference/fingerprint-estado-bd.sql)
(instala `__FingerprintTomar @Etiqueta` y `__FingerprintDiff @A,@B`; huella = #filas + `CHECKSUM_AGG`
por CADA tabla de usuario). Para otro motor, el equivalente: rowcount + un checksum/hash por tabla.

1. **Descubrimiento — QUÉ tablas toca:**
   - `EXEC __FingerprintTomar @Etiqueta='antes';`
   - Ejecuta la acción REAL en la GUI (una sola vez, sobre un caso mínimo controlado).
   - `EXEC __FingerprintTomar @Etiqueta='despues';` → `EXEC __FingerprintDiff @A='antes', @B='despues';`
   - El diff lista TODAS las tablas cuyo #filas o checksum cambió — incluidas las que no anticipabas.
2. **Detalle — QUÉ cambió exactamente en cada una:** ahora que sabes la lista corta de tablas tocadas,
   dumpea sus filas antes/después (el `dump()` de `re_helpers.py`, o `SELECT *`) y saca el diff
   fila-a-fila/columna-a-columna → esa es la evidencia que va al `proceso-*.md`.
3. **Validar el SP contra la GUI (el cierre):** corre el MISMO fingerprint alrededor de tu SP sobre un
   caso equivalente. El diff del SP debe ser **IDÉNTICO** al de la GUI (mismas tablas, mismas filas,
   mismas columnas), módulo lo inevitable (folios/timestamps) — y aun eso debe seguir la MISMA regla de
   avance que la GUI (p.ej. `TBLCONTROL01` avanza igual), no simplemente "faltar".

### Gotchas del diff completo
- **Triggers del entorno disparan en AMBOS lados.** Si la BD tiene triggers (stock o custom del equipo)
  que se disparan al insertar/actualizar, disparan igual con la GUI y con tu SP → NO son una brecha de
  distinguibilidad, siempre que existan en los DOS entornos que comparas. Inspecciona `sys.triggers`
  ANTES (caso real SAE9: 3 triggers custom `trazabilidad*AOrden` en `COMPO01`/`PAR_COMPO01` que
  auto-rellenan `COMPO_CLIB01.CAMPLIB4/5/9` desde `DOCTOSIGC01` — el SP los obtiene "gratis"). Pero si
  vas a instalar el SP en un entorno que NO tiene esos triggers, ESA sí es una diferencia real.
- **Aísla el caso.** Un solo alta mínima (1 partida, 1 producto) hace el diff legible; múltiples cambios
  simultáneos ensucian la atribución. Sandbox desechable → wipe+reload entre casos.
- **Folios/timestamps/GUID** cambian entre corridas por diseño: no los trates como discrepancia, pero SÍ
  verifica que tu SP los AVANCE/asigne con la misma mecánica que la GUI (un contador que no avanza es una
  diferencia real que estalla después).
- **Órden de operaciones importa por los triggers** (ver la sección de gotchas de SQL en la RE del
  sistema): si un trigger `AFTER INSERT` lee una tabla que tú llenas después, deja campos en NULL en
  silencio. El diff completo lo delata (una columna que en la GUI quedó llena y en tu SP no).

## Convención de nombres — consistencia desde el primer archivo
Define UN patrón antes de escribir el primer archivo del módulo (ej. `proceso-{documento}-
{directa|enlazada}.md`, o el que aplique al dominio) y síguelo estrictamente — **nunca combines
dos casos de uso en un solo archivo cuando el resto del módulo los separa** (pasó real: dos
archivos de esta noche juntaban Directa+Enlazada mientras el resto de la matriz los separaba;
unjordi lo cachó a simple vista al pedir la lista — un vistazo externo a los nombres de archivo es
un buen check de cierre de módulo). Si un documento es la variante ENLAZADA de otro, el nombre
debe decirlo explícitamente (`-enlazada`/`-enlazado`), no describir el mecanismo con otras palabras
(ej. `conversion-x-a-y.md` en vez de `x-enlazada.md` — mismo bug real, ya corregido).

## Mantén vivo el diagrama del modelo relacional (artefacto ACUMULATIVO, no un doc aparte)
Cada `proceso-*.md` documenta UN caso de uso puntual; pero como el sistema no tiene FKs reales, las
relaciones que vas descubriendo (qué tabla se une con cuál, por qué llave) también necesitan un
mapa de conjunto — y ESE mapa es responsabilidad del MISMO loop, no una tarea aparte para "algún
día". Patrón real ya en uso (`reference/diagrama-modelo-relacional.md` en `sae9-arquitectura`,
producido por otra sesión/agente trabajando el mismo sistema en paralelo — "un hermanito"): un
`erDiagram` Mermaid POR MÓDULO, cada arista etiquetada con la llave de unión real (`CVE_ART`,
`CVE_CLPV=CLAVE`, etc.) y una nota de que son FKs de facto, no reales. Al cerrar cada
`proceso-*.md` nuevo, pregúntate: **¿esto reveló una tabla o relación que el diagrama todavía no
tiene?** Si sí, agrégala en la MISMA tanda (doc = realidad aplica también al diagrama, no solo a la
prosa). Antes de dar por bueno un cambio al diagrama: renderízalo (`npx @mermaid-js/mermaid-cli`,
skill `diagramar`) y haz QA visual — un bloque que no renderiza es un error de sintaxis silencioso.
Este diagrama es el punto de encuentro entre sesiones/agentes distintos trabajando el mismo
sistema legacy — trátalo como un lienzo compartido, no como algo que "le toca a otra sesión".

## Gotchas de UI recurrentes (reales, de la corrida que originó este skill)
Estos son de ASPEL SAE9 específicamente, pero el PATRÓN de gotcha (documentarlo apenas se
descubre, para no perder tiempo re-descubriéndolo en el siguiente documento) es genérico:
- Un control que en un documento reacciona a doble-clic puede no reaccionar en OTRO documento del
  mismo módulo — probar `Insert`/atajos de teclado como alternativa antes de asumir que algo está
  roto.
- Combos/dropdowns pueden ser más confiables con teclado (`Down`+`Return`) que con clic directo en
  la lista desplegada.
- Autocompletar de claves puede resolver mal si se teclea+Tab demasiado rápido (aterrizar en un
  valor reservado/genérico en vez del querido) — teclear con más pausa y verificar por screenshot,
  no solo confiar en que "ya se guardó".
- Ventanas hijas de un alta pueden sobrevivir abiertas en segundo plano aunque se navegue el ribbon
  a otra pantalla — útil para retomar tras una interrupción, pero también fuente de documentos
  huérfanos sin guardar que hay que limpiar (cerrar sin guardar, verificar por BD que no quedó
  nada).
- Un diálogo de "¿finalizar sesión?" inesperado suele ser un clic que aterrizó en el botón de
  cerrar de la ventana PADRE en vez de la ventana hija (ambas maximizadas se traslapan
  visualmente) — clic en "No" y apuntar con más precisión al frame correcto.
- Mismatch de layout de teclado (VNC asumiendo layout distinto al configurado) puede corromper
  texto tecleado (acentos, mayúsculas, símbolos) sin que se note en el momento — mitigar evitando
  puntuación/acentos en datos de prueba cuando sea posible, y siempre verificar con una consulta
  directa a la BD, nunca solo confiando en lo que se ve en pantalla.
- Una desconexión real del navegador (no el glitch transitorio de "reintenta y ya") puede
  sobrevivir sin perder el estado de la GUI del lado del VM — al reconectar, verificar primero si
  la ventana/documento a medio capturar sigue viva antes de asumir que hay que empezar de cero.

## Disciplina de seguimiento — la parte que hace el método MONITOREABLE
Esto es tan parte del método como el loop de diffing — es lo que le permitió a unjordi verificar
avance a las 2am sin tener que leer el chat completo:
- **`TaskCreate` por cada proceso/documento a probar, ANTES de empezar** — desglose concreto y
  verificable (uno por caso de uso, no un ítem gigante "documentar módulo X"). Actualiza estado en
  tiempo real (`in_progress`/`completed`) conforme avanzas — esa lista ES la ventana de monitoreo.
- **Checkpoint nivel COMPLETO cada ~2h y antes de cualquier compact** (skill `checkpoint`) —
  hilo-mental-actual.md con el plan completo, lo resuelto, y la cosecha durable de esa tanda.
- **Bitácora append-only** (`>>`, nunca un Edit) con cada hallazgo mayor conforme ocurre, no al
  final.
- **RELANZADOR antes de cerrar**: releer y re-auditar TODOS los archivos generados contra el
  ESTADO REAL (BD/filesystem) otra vez, no contra el recuerdo de haberlo hecho ya — un re-barrido
  real destapó cero discrepancias la noche que originó este skill, pero es el paso que lo
  confirma, no un trámite.

## Manejo de riesgo y reversibilidad
- **Sandbox 100% desechable** → trabaja agresivo, wipe+reload libre, sin pedir permiso a cada
  paso dentro del alcance ya acotado (ver skill `turno-nocturno` si el usuario se va a dormir).
- **Datos reales (aunque sea "solo una copia")** → el perfil de riesgo cambia aunque técnicamente
  sea desechable: confirma el modo de trabajo con el usuario (solo lectura vs también altas de
  prueba) ANTES de tocar nada, y dejarlo registrado en `autorizaciones-vigentes.local.md` si el
  usuario amplía el permiso en vivo con una cita textual.

## Extensión futura — fan-out multi-VM (NO es requisito de v1)
Una vez el loop esté pulido y probado a fondo en UNA VM/módulo, el mismo método es paralelizable:
cada VM+sandbox propio corre un agente cubriendo un módulo distinto del mismo sistema legacy (o
sistemas legacy distintos en paralelo), con un orquestador consolidando checkpoints/hallazgos (ver
skill `orquestar-fanout` para el modelo de reporte-sin-niñera). **No construir esto hasta que el
loop de un solo agente esté verdaderamente refinado** — la premisa de "más agentes en paralelo" solo
paga si cada uno individualmente ya no comete los errores que este skill existe para prevenir.

## Caso de referencia (para calibrar qué tan a fondo documentar)
La corrida que originó este skill: proyecto `potenciaDatabases`, matriz completa de 5 documentos
de Compras y 5 de Ventas de ASPEL SAE9 (Directa+Enlazada donde aplica), 16 archivos
`reference/proceso-*.md`, cada uno con ruta de UI + evidencia de BD antes/después + gotchas +
conclusión — ver `.claude/skills/sae9-arquitectura/reference/` en ese repo como ejemplo real de
la profundidad esperada por archivo.
