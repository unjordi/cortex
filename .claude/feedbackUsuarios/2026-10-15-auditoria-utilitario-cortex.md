# Auditoría "estrictamente utilitario" de cortex (epic/afinado-2026-10 @ b848056)

Pedida por unjordi: en skills, código, comentarios, mensajes y tooling va SOLO lo funcional (qué hace, contrato, parámetros, gotchas técnicos en presente). Fuera: citas, fechas/trazabilidad de decisiones, incidentes narrados, drama, proceso, cajas ASCII y nombres propios en lo genérico. El porqué se va a memoria/bitácora. Tres auditores Sonnet de solo lectura; muestras verificadas por claudio-master contra los archivos (ver notas). Los conteos son aproximados y salen de grep + lectura; al aplicar, haz tu propio grep por archivo en vez de confiar en los números de línea.

Notas de verificación (claudio-master):
- skills: muestras CONFIRMADAS (reubicar-master/SKILL.md:785, :1114). CORREGIDO: los scripts de control-gui-remota-por-ssh con "verificado <fecha> en cachy" son 18 de 43, no ~40.
- resto: CONFIRMADAS bin/sessions-extract.js:36, src/term-broker/term-session.ts:12,34, 13× "MEDIDO 2026" en checkpoint-mecanico.js; test-brain.sh tiene 186 líneas con fecha (el auditor avisa que ahí hay más falsos positivos).
- hooks: CONFIRMADAS norms (líneas 11, 82, 140 con "overhaul hooks 2026-09-18 … medido: ignorado"), hooks/drift-cerebro-comun.sh:368, 18 etiquetas de auditoría en analizar-comando-git.sh.
- Ojo especial: los textos `detail`/`desc` de las piezas en los 3 widgets (QML/Swift/C#) los LEE EL USUARIO y traen fechas e incidentes; y `brain/norms/global-claude-md.md` se instala en el CLAUDE.md de todas las máquinas.
- hooks/MANIFEST:92-103: las lápidas con fecha son DATOS que consumen install-brain/sincronizar-cerebro; solo los motivos narrativos son infracción.

Orden sugerido: normas → mensajes que se imprimen (hooks y widgets) → SKILL.md → comentarios de código → test-brain.sh.


---

# Auditoria "estrictamente utilitario" — brain/skills/** (epic/afinado-2026-10)

Alcance: /Users/unjordi/code/cortex/.cortex-wt/epic/brain/skills — 72 archivos revisados (10 381 lineas).
Metodo: grep de candidatos sobre los 72 + lectura del contexto. Los numeros de linea salen de grep; los textos van truncados.
Conteo aproximado (hallazgos distintos, un bloque contiguo = 1): FECHA/TRAZA ~120 · INCIDENTE ~55 · NOMBRE PROPIO ~50 · CITA ~14 · DRAMA ~14 · PROCESO ~8 · DECORACION ~3.

## Top 10 mas cargados
1. reubicar-master/SKILL.md (~45)
2. control-gui-remota-por-ssh/SKILL.md + sus 40 scripts (~19 en SKILL.md, ~40 en cabeceras de scripts: "VERIFICADO 2026-09-18 en cachy")
3. reubicar-master/reubicar-master.sh (~16)
4. canonizar-cerebro/SKILL.md (~14)
5. cerrar-slice/SKILL.md (~14) (+ 2 en .sh)
6. orquestar-fanout/SKILL.md (~14)
7. checkpoint/SKILL.md (~10)
8. auditar-coherencia-cerebro/SKILL.md (~9)
9. MANIFEST (~6, mas lapidas con fecha) / to-do/SKILL.md (~6)
10. ingenieria-inversa-gui-db-navegador/SKILL.md (~6) · despertar-master (SKILL ~2 + .sh ~4) · auditar-suficiencia-operativa (~6) · auditor-semantico (~6)

Propuesta global recurrente: BORRAR fechas/"verificado en <maquina>"; dejar el gotcha en presente; mover historia (que paso, quien lo decidio) a bitacora/memoria. Cambiar nombres de maquinas/masters por placeholders (`<host-linux>`, `<master>`).

---
## reubicar-master/SKILL.md  (~45)
| linea | cat | texto | propuesta |
|---|---|---|---|
| 13-14, 99, 133, 791, 1114 | NOMBRE/INCIDENTE | "anti-ejemplo helios-selene", "el tail que a helios-selene le faltó", "Reencarnar helios-selene" | REESCRIBIR: "master a medias (residuo + resume roto)"; "registrar la rueda (alias/masters.json)". |
| 60, 535 | FECHA/PROCESO | "Por qué dejó de ser markdown (2026-09-10, primera mudanza real)" / "Tres cosas que solo aparecieron al EJECUTARLO (2026-09-10)…" | BORRAR el encabezado narrativo; dejar solo "el generador es script; corre X". |
| 96, 265-270, 904 | NOMBRE | `cortex-master` (Mac) → `cortex`, `axon-master` (Cachy) → `axon`, ejemplo real "el master de cortex, 2026-09-10" | REESCRIBIR con `<master>`/`<repo-destino>`. |
| 117 | FECHA | "Fundamento empírico (arco RESUME, axon-master 2026-09-21)" | MOVER a memoria. |
| 122, 480, 737, 1281 | CITA/NOMBRE | "poda de unjordi", "explícita de unjordi", "Decisión de unjordi (2026-09-08, textual): "QUIERO QUE ESTO QUEDE SIN…"" | BORRAR cita; dejar "CERO symlinks nuevos". |
| 155, 205, 226, 312, 381-408, 477, 494, 683, 1036, 1103 | INCIDENTE | "medido: 70 escrituras al hilo de cortex y 61 al de plantilladotnet", "163 transcripts", "Medido el 2026-09-10, en la mudanza real: el bin/ INSTALADO…", "devolvió 44 de 43" | REESCRIBIR a la regla en presente; MOVER cifras a memoria. |
| 171-172, 192, 574, 714-715, 740-741, 904 | FECHA/NOMBRE | "[verificado 2026-09-08: isPrivate=false]", "axon se canonizó el 2026-09-08", "rig-master (2026-08-02)", "Cachy: de 20 slugs… los 5 que unjordi considera bien hechos" | BORRAR fechas/verificaciones; ejemplos genericos. |
| 371, 397, 709 | INCIDENTE/NOMBRE | "[verificado] dos claude-brain-cachy-master…", "Caso real (2026-09-08, Cachy): masters.json traía…", "dos games-master, dos rig-master…" | MOVER a bitacora; dejar "puede haber varios ids por nombre: resolver por transcript mas reciente". |
| 437-439 | INCIDENTE | "[verificado 2026-09-08, mudanza de axon-master]… Lo que pasó: el move quedó impecable y medido; luego un resume escribió…" | REESCRIBIR: "G-LIVENESS solo prueba la sesión objetivo; un resume posterior reescribe el transcript → re-verificar (S7)". |
| 785 | NOMBRE | "con OK EXPLÍCITO de unjordi" | "con OK explícito del dueño del repo". |
| 956 | FECHA/INCIDENTE | "la capa que faltaba el 2026-09-10 y la que habría atajado el handoff muerto" | BORRAR. |
| 1196-1201 | FECHA/INCIDENTE | "(el techo de 512 MiB, retirado)", "writeAlias ya toma (2026-09-10)" | BORRAR historia. |
| 1103-1146 (tabla de trampas) | INCIDENTE | filas con "Medido 2026-09-10", "473 líneas muertas en DST_CWD: unbo…" | Dejar causa/arreglo; quitar fecha y cifras. |

## reubicar-master/reubicar-master.sh  (~16)
| linea | cat | texto | propuesta |
|---|---|---|---|
| 19, 166, 186, 240 | FECHA/INCIDENTE | "POR QUÉ ES UN SCRIPT… (2026-09-10, hallazgo de la primera mudanza real)", "Es el fallo del 2026-09-10…", "Dos correcciones que salieron de CORRERLO el 2026-09-10" | BORRAR; 1 linea de contrato. |
| 381-384, 649, 816, 1221 | INCIDENTE | "MEDIDO el 2026-09-10… devolvió 44 de 43 archivos", "~/.local/bin llevaba 3 días atrás", "70 escrituras al de cortex" | Dejar el efecto ("ls-tree debe excluir X"); BORRAR cifras. |
| 1160 | FECHA | "(verificado 2026-09-08: 1 de 131 en 644…)" | BORRAR. |
| 1281 | CITA | "decisión de unjordi (2026-09-08, textual)" | BORRAR atribucion. |
| 816 | NOMBRE | "con un `databases-master` trabajando en otro repo" | placeholder `<master>`. |

## control-gui-remota-por-ssh/SKILL.md  (~19)
| linea | cat | texto | propuesta |
|---|---|---|---|
| 8-13, 71-73, 156, 164-170, 275 | FECHA | "verificado en hardware real (2026-08-27)", "verificado en vivo (2026-09-18)", "agregado 2026-09-18… SIN CONFIRMAR" | Sustituir por columna de estado: "verificado / sin verificar". Sin fechas. |
| 10, 170, 178, 203, 251, 255 | NOMBRE | "contra `cachy` (CachyOS, KDE Plasma 6.7)", "bloqueado en cachy por permiso EIS", "Steam en cachy" | `<host-linux>`; la version de KDE vale como dato tecnico. |
| 13, 275, 294-353 | NOMBRE/FECHA | "verificado LOCAL en esta Mac (macOS 26.6.2)", "QA 2026-09-18", "fix 2026-09-18" | BORRAR fechas/maquina. |
| 202, 341 | INCIDENTE/CITA | "GOTCHA REAL Y CRÍTICO", "del usuario 2026-09-18: "a b c" salía "abc"" | Titulo: "Gotcha: permiso EIS de KWin"; dejar el sintoma tecnico sin atribucion. |

## control-gui-remota-por-ssh/** scripts (~40 lineas, todos FECHA + NOMBRE)
Patron "VERIFICADO 2026-09-18 en cachy", "GOTCHA REAL (hallado por QA en vivo… corregido el mismo dia)", "LIMITE DE ESTA VERIFICACION: cachy solo tiene UN monitor", "OJO --". Propuesta: BORRAR fecha/maquina/historia de QA, dejando el gotcha en presente. Archivos:
- linux/linux-ssh-screenshot.sh (L12,17,23,27,46,47,57,74,78: ~9) · linux/linux-ssh-send-click.sh L9 · linux/linux-ssh-kill-process.sh L10 · linux/linux-ssh-clipboard.sh L8,11 · linux/linux-ssh-list-windows.sh L10 · linux/linux-ssh-get-window-coordinates.sh L15 · linux/lib-linux-ssh-env.sh L11
- mac/mac-ssh-screenshot.sh (L10,17,25,29,41: ~5) · mac/mac-ssh-send-click.sh L16 · mac/mac-ssh-send-keys.sh L79 · mac/mac-ssh-get-window-coordinates.sh L10 · mac/mac-ssh-get-processes-list.sh L9 · mac/mac-ssh-list-windows.sh L11 · mac/lib-mac-ssh-env.sh L12,37
- win/win-ssh-screenshot.ps1 (L11,13,27-28) · win/win-ssh-send-keys.ps1 L8 · win/win-ssh-send-click.ps1 L13 · win/win-ssh-get-window-coordinates.ps1 L16
"OJO" en linux-ssh-screenshot.sh L27 ademas es DRAMA menor.

## canonizar-cerebro/SKILL.md  (~14)
| linea | cat | texto | propuesta |
|---|---|---|---|
| 107-111 | CITA/FECHA/DRAMA | "CERO SYMLINKS (decisión dura de unjordi, 2026-09-08: "NO quiero symlinks en ningún lado" — "son un…" … 15 basura medidos" | REESCRIBIR: "Cero symlinks: rompen /to-do y la lectura de .claude/memory. Usa directorio real." |
| 184 | NOMBRE | "repo `unjordi/scripts`, otro `unjordi/PowerScripts`" | `<owner>/repo-a`, `<owner>/repo-b`. |
| 216, 223, 286, 291, 614 | FECHA/TRAZA | menciones a hooks "retirados" y "antes era el skill cosechar-sesion" | Dejar el contrato del detector; borrar historia. |
| 374 | INCIDENTE | "caso real: un rebuild botó una corrección que…" | Dejar la regla (diff de preservacion). |
| 392 | INCIDENTE | "Recortes reales: cps estado-proyecto 896→460 (−49%), 0 lecciones perdidas" | BORRAR. |
| 437 | PROCESO | "justo lo que le pasó a este skill antes" | BORRAR. |
| 498-499 | FECHA/TRAZA | "`recordar-unificar-cerebro` se retiró, overhaul hooks 2026-09-18, puramente advisory" | BORRAR parentesis. |
| 551, 569 | NOMBRE | "patrón lecciones-migracion-cps", "como-trabajar-con-unjordi.md" | `como-trabajar-con-<user>.md`. |

## cerrar-slice/SKILL.md (~14) (+ .sh ~3)
| linea | cat | texto | propuesta |
|---|---|---|---|
| 13 | FECHA/TRAZA | "`recordar-dashboard` se retiró, overhaul hooks 2026-09-18, puramente advisory" | BORRAR. |
| 34, 51, 78 | INCIDENTE | "En un caso real se aplanó un esquema…", "en un caso real el usuario forzó 3 [auditorías]", "pasó en un caso real varias veces" | BORRAR narracion; dejar regla. |
| 65 | TRAZA | "Origen: reubicar-master §9, 2026-08-08 — delegó 4 aristas…" | BORRAR. |
| 96 | DRAMA/INCIDENTE | "(Lección real: se pidió QA en un entorno que corría…" | Dejar 1 linea tecnica. |
| 167-169 | TRAZA | "ya no dispara el candado", "destilados de un caso real" | BORRAR. |
| 178-179 | TRAZA | "lo que antes era el skill cosechar-sesion, retirado 2026-09-17" | BORRAR. |
| 222 | PROCESO | "el caso real, por qué importa" (ayuda de flag) — aceptable (instruye), solo suavizar. |
| 246 | TRAZA | "Regla destilada de un catch real (2026-07)" | BORRAR. |
| cerrar-slice.sh L106, L126 | TRAZA/PROCESO | "Ahora normaliza…", "C1 (QA claudio 2026-10-13)" | BORRAR autor/fecha. |
| cosechar-aprendizaje.sh L3 | FECHA | "cosechar-sesion, retirado 2026-09-17" | BORRAR. |

## orquestar-fanout/SKILL.md (~14)
| linea | cat | texto | propuesta |
|---|---|---|---|
| 40 | FECHA | "(Caso real: CachyOS, 2026-07-20.)" | BORRAR. |
| 47-48 | INCIDENTE/DRAMA | "lección REAL, 2026-07: un agente de verificación se metió al árbol principal, reseteó HEAD y orfanó un commit" | Dejar "agente en arbol compartido que resetea HEAD orfana commits". |
| 53, 62, 74, 90, 97, 103, 108, 137, 249 | INCIDENTE/FECHA | "feedback real, 2026-07", "lección REAL, C7, 2026-07-21", "feedback real de unjordi, 2026-07-29", "en un caso real tumbó el login del usuario", "4 agentes analizaron los módulos…" | BORRAR atribucion/fecha/narracion. |
| 133 | CITA | "Regla dura (unjordi 2026-07-30): el reporte de un agente SIEMPRE…" | Dejar la regla sin atribucion. |
| 149, 210 | TRAZA | "`delegacion-reporte` se retiró, overhaul hooks 2026-09-18, puramente advisory" | BORRAR. |

## checkpoint/SKILL.md (~10)
| linea | cat | texto | propuesta |
|---|---|---|---|
| 82 | INCIDENTE | "Un caso medido: 9 checkpoints en 5h42m en un mismo día…" | BORRAR. |
| 102, 304 | INCIDENTE | "(medido: la mayoría de los checkpoints NO vienen de una compactación)", "(medido: las instrucciones de /compact…)" | Dejar solo el hecho. |
| 137, 195 | INCIDENTE/FECHA | "incidente 2026-09-22: el árbol en primer lugar empujó el «qué sigue» fuera del preview" | Dejar "el qué-sigue va primero (el preview es ~2KB)". |
| 186, 341 | FECHA | "2026-09-11 sobre los 9 hilos reales: 2 de 9 no lo traían", "auditoría 2026-09-11" | BORRAR. |
| 201 | DRAMA | "…lección cara" | BORRAR. |
| 109, 261, 265 | CITA(sintaxis) | procedencia `[user: "…"]` | NO infraccion: es formato que el skill prescribe. |

## auditar-coherencia-cerebro/SKILL.md (~9)
L8, 12, 33-36, 54, 135, 156, 183, 185: "unjordi" como actor fijo (NOMBRE) → "el usuario/dueno". L46 "lección de las 9 rondas — el value-model de git reabrió 5 veces" (INCIDENTE) → BORRAR. L74 "(Decisión unjordi 2026-09-08…)" (FECHA/CITA) → BORRAR. L105 "La lección más cara de las 9 rondas" (DRAMA) → "Gotcha: un guard de regex se rompe por como el shell tokeniza". L145 caso de reinicio/`/tmp` (INCIDENTE) → 1 linea.

## auditar-suficiencia-operativa/SKILL.md (~6)
L14-21 "Por qué existe (caso real, games-master 2026-07-30)… nació un skill `mantener-el-setup`… Lección" (INCIDENTE/FECHA/NOMBRE) → REESCRIBIR a 2 lineas de proposito. L45 "(medido, sep-2026)" y L63 "en una tanda real", L72 "pasó en el propio gold standard", L111 "destilado de la corrida DUPLA, 2026-07-31" → BORRAR fechas/narracion.

## auditor-semantico/SKILL.md (~6)
L40, 55, 61-63, 82, 91, 100: bloques "Caso medido: …" (INCIDENTE). Estan genericos y sin nombres; si ilustran un tipo de bug, conservar UN ejemplo corto por patron y BORRAR el resto/"medido hasta ahora".

## auditar-proceso-algoritmo/SKILL.md (~3)
L105 "(corpus medido, sep-2026)" FECHA; L126-127 historia de la doc que citaba pruebas rotas (INCIDENTE) → dejar "ancla las regresiones a SHA fijo"; L159 "En el caso de arriba, la segunda pasada existió porque se pidió expresamente" (PROCESO) → BORRAR.

## to-do/SKILL.md (~6)
L70 "(crux medido 2026-09-18)" , L75 "decisión de unjordi 2026-09-18" (CITA/FECHA/NOMBRE), L122 "`hud-stale` se retiró, overhaul hooks 2026-09-18" (TRAZA) → BORRAR. L95-97 ejemplo "caso real… parqueado 2026-08-06" (ejemplo con fecha: marcar "ejemplo", sin "caso real"). L92 fecha de ejemplo OK.

## desinflar-memorias/SKILL.md (~4)
L12-17 "El encargo que originó este skill (unjordi, 2026-07-30, sobre un árbol de 2,759 líneas)… −21% de líneas…" (CITA/FECHA/PROCESO) → BORRAR bloque. L41 ejemplo "DESCARTADO 2026-07-29 — vdf truncado" (ejemplo con fecha/caso: ok marcado, sino generico). L81 NOMBRE `como-trabajar-con-unjordi.md` → `<user>`.

## ingenieria-inversa-gui-db-navegador/SKILL.md (~6)
L8-11 "Nace del turno nocturno 2026-07-21/23 sobre ASPEL SAE9… calificado por unjordi como "salió perfecto"" (CITA/FECHA/PROCESO) → BORRAR. L52 "Gotcha real (2026-07-23)" → quitar fecha. L90 "(lección real, 2026-07)" → quitar. L121 "caso real SAE9: 3 triggers custom…" → ejemplo marcado. L136-138 "pasó real… unjordi lo cachó a simple vista" (INCIDENTE/NOMBRE) → BORRAR. L185 "lo que le permitió a unjordi verificar" (NOMBRE).

## despertar-master/SKILL.md + despertar-master.sh (~6)
SKILL L12 "el 2026-10-14 por eso se lanzó una segunda sesión de `cortex-master` sobre un id muerto" (FECHA/INCIDENTE/NOMBRE) → BORRAR. SKILL L30 ejemplo `cortex-master (2)` → `<master> (2)`. SKILL L49 "Gotchas (medidos…)" ok quitar "medidos — no los re-descubras". .sh L5 "(medida 2026-10-14)", L8 ejemplo "cortex-master", L29 "Misma lección del afinado núcleo 2026-10", L60 "(medido: arsenal-master…)" → BORRAR fechas/nombres.

## MANIFEST (~6)
L40 "DECISIÓN DE TIER (unjordi, 2026-08-07)", L49 "2026-09-18: sumada…", L51 "2026-09-22: sumada…" (FECHA/TRAZA) → MOVER a bitacora. L81-85 lapidas "retirado 2026-09-17" (son datos de maquina del tier `retirado`; dejar, pero evaluar quitar la fecha si el parser no la exige).

## investigar-dominio/SKILL.md (1-2)
L23 "Nació de una sesión real (Jordi, 2026-07-25) que salió redonda." (PROCESO/NOMBRE/FECHA) → BORRAR.

## construir-missing-manual/SKILL.md (2)
L76 "(Origen: unjordi, harto de docs escuálidas — "que sea un monstruo consultable".)" (CITA/DRAMA/TRAZA) → BORRAR. L102 "WireGuard a fondo (`wireguard-a-fondo`, 2026-08-21)" (FECHA, ejemplo) → quitar fecha.

## markdown-a-pdf/SKILL.md (3)
L42 "GOTCHA REAL Y GRAVE" (DRAMA) → "Gotcha: `--stylesheet` reemplaza el tema default; usa `--css`". L155 "exactamente lo que pasó con el gotcha de --stylesheet" (INCIDENTE) → BORRAR.

## diagramar/SKILL.md (1)
L90 "(caso real, jul 2026: un mockup aprobado se borró de AMBOS lados y costó días…" (INCIDENTE/FECHA) → BORRAR, dejar regla de versionar.

## zoom-screenshot/SKILL.md (1)
L8 "Técnica validada el 2026-06-26 (transcribir todos los menús de Configuración de Steam)." (FECHA) → BORRAR.

## turno-nocturno/SKILL.md (1)
L138 "(pasó en una noche real)" (INCIDENTE) → BORRAR.

## reconstruir-contexto/SKILL.md (1)
L161 "…hasta que ya costó una decisión mal tomada" (DRAMA leve) → opcional. Resto: `[user: "…"]` es formato prescrito, no infraccion.

## positivar-doc/SKILL.md (1)
L73 ejemplo de reencuadre con historia (leve) → opcional.

---
## Archivos LIMPIOS (sin infracciones reales)
- rehidratar-hilo/SKILL.md
- ingenieria-inversa-gui-db-navegador/reference/fingerprint-estado-bd.sql
- Practicamente limpios (solo hallazgos leves/opcionales): positivar-doc/SKILL.md, reconstruir-contexto/SKILL.md, turno-nocturno/SKILL.md, zoom-screenshot/SKILL.md, diagramar/SKILL.md
- control-gui-remota-por-ssh scripts sin hallazgos de fecha/nombre: linux-ssh-launch.sh, win-ssh-launch.ps1, y los scripts de la carpeta no listados arriba (list/launch/get-processes de win y linux sin cabecera con fecha).

Nota: lectura basada en grep de candidatos + contexto; las lineas citadas pueden desplazarse 1-2 por truncado. Falsos positivos descartados: `[ -n "${X:-}" ]` de los scripts, ejemplo de fecha absoluta en to-do L92, sintaxis `[user: "…"]` prescrita en checkpoint/reconstruir-contexto.

---

# Auditoría "estrictamente utilitario" — brain/hooks, lib, sesiones-master, scripts, *.sh/*.ps1 de raíz

Repo: /Users/unjordi/code/cortex/.cortex-wt/epic (epic/afinado-2026-10). Solo lectura.

- Archivos revisados: 58 + brain/norms/global-claude-md.md (sección aparte). Excluidos: test-brain.sh (otro auditor), agentes-costo.json (datos).
- Método: barrido regex por categoría sobre TODOS los archivos + lectura del contexto; descartados falsos positivos (cabeceras `anthropic-beta: oauth-2025-04-20`, URL del instalador, el texto de install-brain que ENUMERA las categorías prohibidas, "costo" de delegación, "desastre" técnico, mensaje de rehidratar-hilo que habla de "citas del usuario" como instrucción).
- Limitación honesta: las tablas son por línea con hit; el DRAMA gratuito se buscó con regex (`¡`, `!!`, insultos, etc.) y casi no aparece (el tono de los comentarios es técnico pero DENSO en TRAZA). Los "bloques largos" (≥8 líneas de comentario consecutivas, 93 en 31 archivos) se detectan por tamaño, no por lectura de cada uno: son candidatos a condensar a ≤3 líneas. Una línea puede tener varias categorías.
- Patrón dominante: etiquetas de auditoría/FMEA/dictamen (`A-R4-01`, `M5-bis`, `H2 (auditoría 2026-09-16…)`, `C-2 (dictamen…)`) como encabezado de comentario en analizar-comando-git, ramas-zombie, limpiar-impl-*, merge-develop-guard, secret-scan, proteger-arbol, git-branch-guard, drift-cerebro-comun. Todo eso es TRAZA: la regla técnica queda, la etiqueta+fecha+severidad se borra.

## Infracciones por categoría (hooks, lib, sesiones-master, scripts, raíz)
- FECHA/TRAZA: 187
- INCIDENTE: 49
- NOMBRE PROPIO: 45
- DECORACIÓN (banners/cajas): 15
- CITA: 13
- DRAMA: 0 hits reales (los 3 candidatos eran FP)
- DECORACIÓN por bloque largo (≥8 líneas, candidatos): 93 bloques en 31 archivos
- MENSAJE (texto que el hook imprime): 1 hit real: hooks/drift-cerebro-comun.sh:368 (mensaje "DRIFT DE NORMAS" con fecha/historia de recordar-dashboard); además hooks/barrer-ramas.sh:127 (mensaje al modelo con narración del merge) revisar; hooks/dashboard_cerebro.template.md:5-6 (plantilla que se instala: dice "recordar-dashboard.sh se retiro overhaul hooks 2026-09-18") y sesiones-master/README.md (nombres propios + incidente).

## Top 10 archivos más cargados
- hooks/analizar-comando-git.sh: 40 líneas con hit + 17 bloques largos
- install-brain.sh: 11 líneas con hit + 7 bloques largos
- hooks/rehidratar-hilo.sh: 13 líneas con hit + 4 bloques largos
- hooks/drift-cerebro-comun.sh: 10 líneas con hit + 6 bloques largos
- hooks/merge-develop-guard.sh: 10 líneas con hit + 6 bloques largos
- hooks/aviso-drift-cerebro.sh: 11 líneas con hit + 4 bloques largos
- hooks/ramas-zombie.sh: 12 líneas con hit + 3 bloques largos
- hooks/barrer-ramas.sh: 10 líneas con hit + 2 bloques largos
- hooks/git-branch-guard.sh: 9 líneas con hit + 3 bloques largos
- hooks/limpiar-impl-ramas.sh: 9 líneas con hit + 3 bloques largos

## Leyenda de propuestas
- FECHA: BORRAR fecha/etiqueta de auditoría-FMEA/hash; dejar solo el contrato técnico en presente (traza a git/bitácora)
- INCIDENTE: REESCRIBIR sin la narración del caso/medición; dejar la regla o gotcha en presente
- DECOR: BORRAR la caja/banner; separador simple de una línea
- NOMBRE: REESCRIBIR genérico ("el usuario", "otra máquina", "repo derivado")
- CITA: BORRAR la cita/atribución; dejar la instrucción
- Bloque largo: CONDENSAR a ≤3 líneas con contrato/gotcha en presente; el porqué histórico a memoria/bitácora.

## Hallazgos por archivo (de más a menos)

### hooks/analizar-comando-git.sh  (40 líneas, 17 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/analizar-comando-git.sh:7 | FECHA | # ── PATH-AUGMENT para gh/glab (ROOT CAUSE del #78, corpus 2026-08-25→09-01) ────────────────────────────── | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:31 | FECHA | # ── M1 (auditoría 2026-09-15): SEGMENTACIÓN ejecutor-aware — ENTRADA ÚNICA de los 9 guards que antes | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:83 | FECHA | # frontera" que ya divergió en 2 de los hooks que hacían su propia copia a mano, auditoría 2026-09-15). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:94 | FECHA | #   · A-03 (FMEA r1): cubrió '-c'/'-C'. | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:95 | FECHA | #   · A-R4-01/02 (FMEA r4): git acepta MUCHAS más globales ('--no-pager', '-p'/'-P', '--work-tree', | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:102 | FECHA | #   · A-R5-01 (FMEA r5): el VALOR de un value-eater puede ir ENTRECOMILLADO con ESPACIOS — | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:103 | NOMBRE | #     'git -C "/Users/unjordi/Mi unidad/repo" push origin develop' (realista: rutas de Google Drive en | REESCRIBIR genérico |
| hooks/analizar-comando-git.sh:109 | FECHA | #   · A-R6-01 (FMEA r6): la comilla puede ir EN MEDIO del valor — 'git -c user.name="a b" push …' | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:115 | FECHA | #   · A-R7-01 (FMEA r7): el espacio del valor puede ir ESCAPADO CON BACKSLASH en vez de entrecomillado | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:121 | FECHA | #   · B4 (FMEA r8): en Windows el binario es 'git.exe'; 'git.exe push origin develop' rompía el 'git'+espacio | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:134 | FECHA | # ── RESOLVEDOR DE TARGET (cimiento cross-repo, auditoría 2026-08-06) ──────────────────────────────────── | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:145 | FECHA | # IRRESOLUBLE. Consecuencia real (FP 2026-09-08, MR 87 de axon y PR 19 de odysseus): TARGET_ROOT no | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:187 | FECHA | # M9 (auditoría 2026-09-15 §2.5/§4.3): extrae el valor de --repo/-R como UNIDAD (bare \| "…" \| '…'), no con | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:229 | FECHA | # flags intermedios ('glab mr merge --yes 9' → 9). Antes se exigía el id ADYACENTE al subcomando (A-04, FMEA). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:245 | FECHA | # peligroso, que sin el '+' en el set de separadores se colaba (A2, FMEA 2026-07-30). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:246 | FECHA | #   · G3/G4 (auditoría 2026-08-06): la FRONTERA posterior era demasiado estricta ('[[:space:]]\|$') → un | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:254 | FECHA | # H2 (auditoría de ejecución 2026-09-16, MEDIO, CONFIRMADO): ¿el push nombra un destino OPACO (sustitución | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:258 | INCIDENTE | # quedaría CIEGO (medido: acg_push_destino_base no lo detecta, acg_push_sin_refspec tampoco porque SÍ hay | REESCRIBIR sin la narración del caso/medición |
| hooks/analizar-comando-git.sh:296 | FECHA | # sobre un segmento YA despojado/normalizado. bash-3.2-safe. (FP corpus L109, 2026-09-03 ×2: un compuesto | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:325 | FECHA | # A-R3-01 (FMEA r3): recorre CADA subcomando (separado por ; && \|\| & \|). Un push a base en CUALQUIERA | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:332 | FECHA | # RESOLVEDOR CROSS-REPO (2026-08-06): se itera sobre el cmd ORIGINAL (con -C intacto) y se normaliza | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:349 | FECHA | # H2 (auditoría de ejecución 2026-09-16 §2, MEDIO): destino OPACO (sustitución de shell) → incertidumbre, | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:386 | FECHA | # G6 (auditoría 2026-08-06): el 1er POSICIONAL de 'gh pr merge <arg>' / 'glab mr merge <arg>' es el #/rama | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:449 | FECHA | # destino", FP 2026-09-08 del MR 87) o —peor— podía devolver la base de otro repo. Corriendo la consulta en | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:483 | FECHA | #    muerte del proceso, H5). M11 (auditoría 2026-09-15 §3.12, doc=realidad): esto YA NO se compara contra | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:488 | FECHA | # ── M3 (auditoría 2026-09-15 §3.3/§4.2/§4.3): ACG_DEST_CONF — el destino deja de ser "rana o vacío" y pasa | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:500 | FECHA | # resolvedor de destino y el de confianza diverjan, el mismo defecto de sustrato que motivó este dictamen). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:505 | FECHA | # H1 (auditoría de ejecución 2026-09-16, ALTO, CONFIRMADO): el caché REGULAR (acg-mrdest-<key>, y sus | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:565 | FECHA | # H3 (auditoría semántica 2026-09-16, MEDIO, CONFIRMADO): hoy NO existe el escritor legítimo (pendiente ya | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:648 | FECHA | # SLURP MULTILÍNEA (fix #42/#46, corpus 2026-08-19/24): un '--squash-message "resumen\ncurado\ninline"' | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:710 | FECHA | # H8 (auditoría semántica 2026-09-16, BAJO, CONFIRMADO): el set de prefijos era demasiado angosto — | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:717 | FECHA | # A-3 (dictamen higiene de ramas 2026-09-17): la exigencia de trazabilidad 'Rama:'/'MR:' solo se evaluaba | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:721 | INCIDENTE | # Medido sobre las ramas integradas del repo: solo el 38% llevaba la línea 'Rama:'. Consecuencia en | REESCRIBIR sin la narración del caso/medición |
| hooks/analizar-comando-git.sh:785 | FECHA | # H1 (auditoría de ejecución 2026-09-16, ALTO): mismo patrón sin-validar que el de destino -- misma | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:816 | FECHA | # H1 (auditoría de ejecución 2026-09-16, ALTO): mismo patrón sin-validar que el de destino -- misma | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:880 | FECHA | # ── M4 (auditoría 2026-09-15 §2.3/§3.4): UNA sola fuente para "¿hay lenguaje de release / qué dijo el | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:881 | FECHA | # usuario recientemente?", viviendo en la lib. Origen: cuando el squash y la autorización eran DOS guards | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:937 | FECHA | # H4 (auditoría de ejecución 2026-09-16, MEDIO, CONFIRMADO): acg_lexico_release mira TODA la ventana, sin | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:963 | FECHA | # H2 (auditoría semántica 2026-09-16, ALTO, CONFIRMADO): señal de RIESGO amplia para el piso M5-bis de | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/analizar-comando-git.sh:974 | FECHA | # H2 (auditoría semántica 2026-09-16, ALTO): la MITAD positiva del piso M5-bis. NO basta con "ninguna señal | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
Bloques largos: 7 (13 l.), 31 (15 l.), 90 (34 l.), 142 (10 l.), 187 (9 l.), 242 (8 l.), 325 (11 l.), 405 (11 l.), 474 (13 l.), 488 (16 l.), 505 (14 l.), 562 (10 l.), 617 (8 l.), 664 (11 l.), 704 (12 l.), 717 (9 l.), 937 (9 l.)

### install-brain.sh  (11 líneas, 7 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| install-brain.sh:35 | FECHA,INCIDENTE | # por-repo y faltaban donde el repo no los traía (caso real 2026-07-11) → global para que apliquen en TODA | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR sin la narración del caso/medición |
| install-brain.sh:109 | FECHA,INCIDENTE | # definición no pueden ser propios del usuario ni {global,both}). Caso real 2026-09-08: dod-verificar.sh | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR sin la narración del caso/medición |
| install-brain.sh:110 | NOMBRE | # huérfano en el global de la Cachy, presente pero sin cablear. | REESCRIBIR genérico |
| install-brain.sh:121 | INCIDENTE | # HUECO que motivó este mecanismo: caso real rama-vieja). Este bloque SÍ poda: por cada retirado, borra | REESCRIBIR sin la narración del caso/medición |
| install-brain.sh:224 | FECHA | # checkpoint-mecanico (M2/X2, auditoría 2026-09-11): SOLO PreCompact — es el único punto donde ya | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| install-brain.sh:233 | FECHA | # latente: antes la COPIA se derivaba del MANIFEST pero el CABLEADO eran 16 register_hook a mano → un | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| install-brain.sh:311 | FECHA,INCIDENTE | # (hallazgo ALTO-1 de la auditoría de suficiencia operativa, 2026-09-18: confirmado en vivo con 5 skills | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR sin la narración del caso/medición |
| install-brain.sh:313 | FECHA | # revisar-entregables-agentes — todavía instaladas en una máquina bootstrapeada antes del overhaul). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| install-brain.sh:334 | FECHA,NOMBRE | # Cosechado del global de Cachy (2026-07-31). Es config de Claude Code PORTABLE (no de máquina), por eso va | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR genérico |
| install-brain.sh:369 | FECHA | # El SET COMPLETO de env vars del brain que se CAPTURAN-si-activas (revisado 2026-08-07). Solo van aquí | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| install-brain.sh:384 | FECHA | # La versión AUTO-INCREMENTA con cada commit (el count crece). C3 (auditoría 2026-08-29): cuando este | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
Bloques largos: 6 (16 l.), 23 (9 l.), 103 (8 l.), 117 (10 l.), 304 (11 l.), 369 (8 l.), 379 (13 l.)

### hooks/rehidratar-hilo.sh  (13 líneas, 4 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/rehidratar-hilo.sh:8 | FECHA | # CONFIRMADO con la doc oficial (2026-07-14, CLI 2.1.209): SessionStart + matcher 'compact' + | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/rehidratar-hilo.sh:14 | FECHA | #      conserve ese hilo (probado en vivo 2026-07-14: hilo+decisiones+feeling sobrevivieron). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/rehidratar-hilo.sh:28 | FECHA | # ── EL ANDAMIO MECÁNICO (2026-09-11): este hook es la MITAD LECTORA de DOS productores ──────────── | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/rehidratar-hilo.sh:49 | FECHA | # el propio hilo vigente (FMEA A8). Sin git / sin línea de rama en el hilo → cae al proxy de edad. | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/rehidratar-hilo.sh:50 | FECHA | # AÑADIDO 2026-09-11: el encabezado reporta SIEMPRE la EDAD del volcado, coincida la rama o no. En una | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/rehidratar-hilo.sh:94 | FECHA | # externo. Se retiró el '.contexto-baseline' (antes se escribía aquí). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/rehidratar-hilo.sh:104 | INCIDENTE | # que lo recupere, y la pérdida es INVISIBLE hasta que ya costó. El aviso es VISIBLE (systemMessage, no | REESCRIBIR sin la narración del caso/medición |
| hooks/rehidratar-hilo.sh:137 | FECHA | #     separador '·': cierra el '.*[Rr]ama' goloso (FMEA A8: 'feat/diagrama-x' → '-x') y la prosa con | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/rehidratar-hilo.sh:153 | FECHA | #     por edad enterraba el propio hilo vigente (FMEA A8). Con rama indeterminada (sin git / sin línea de | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/rehidratar-hilo.sh:242 | FECHA | # ── A7 (inbox 2026-09-22): FARO ANTI-TRUNCADO ────────────────────────────────────────────────────── | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/rehidratar-hilo.sh:247 | FECHA,INCIDENTE,NOMBRE | # HISTORIA, no la petición actual. Incidente real, medido (games-master, 2026-09-22): se lanzó a trabajo | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR genérico + REESCRIBIR sin la narración del caso/medición |
| hooks/rehidratar-hilo.sh:252 | INCIDENTE | # Default 9000: el harness corta el additionalContext alrededor de ~10K (truncado más chico medido: 10251 B); | REESCRIBIR sin la narración del caso/medición |
| hooks/rehidratar-hilo.sh:253 | INCIDENTE | # 13000 dejaba 31/172 bloques truncados ENTRE 10K y 13K sin faro. 9000 queda bajo el corte medido, con margen. | REESCRIBIR sin la narración del caso/medición |
Bloques largos: 8 (14 l.), 28 (13 l.), 42 (12 l.), 242 (12 l.)

### hooks/drift-cerebro-comun.sh  (10 líneas, 6 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/drift-cerebro-comun.sh:42 | FECHA | # tienen los 3 widgets (#322): $CLAUDE_BRAIN_DIR → ~/.cortex → ~/.claude-brain (nombre PRE-rename), | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/drift-cerebro-comun.sh:50 | FECHA | # (auditoría 2026-08-29, §4 C2 / hallazgo AUTOSYNC). Única implementación — todo lo demás la llama, no la | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/drift-cerebro-comun.sh:141 | FECHA | # C2 (FMEA) — GUARD ANTI-REGRESIÓN del auto-sync: si la FUENTE está DETRÁS de su origin/main, aplicarla | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/drift-cerebro-comun.sh:151 | FECHA | # sA3 (FMEA) — mini-develop = 'Develop<Usuario>' en PascalCase: Develop + una MAYÚSCULA (clase POSIX | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/drift-cerebro-comun.sh:164 | FECHA | # V1 (auditoría 2026-08-06): este auto-commit BYPASSEABA secret-scan — ocurre DENTRO de este | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/drift-cerebro-comun.sh:331 | FECHA | #    Antídoto al hallazgo ALTO-2 de la auditoría de suficiencia operativa (2026-09-18): a diferencia de | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/drift-cerebro-comun.sh:334 | INCIDENTE | #    pero NADA avisaba que hacía falta re-correrlo: confirmado en vivo, el propio '~/.claude/CLAUDE.md' de | REESCRIBIR sin la narración del caso/medición |
| hooks/drift-cerebro-comun.sh:335 | NOMBRE | #    la máquina de unjordi seguía citando el hook YA retirado 'recordar-dashboard' como "un hook te lo | REESCRIBIR genérico |
| hooks/drift-cerebro-comun.sh:337 | FECHA | #    2026-09-18 — el reemplazo funcional (norma en vez de hook) solo sirve si el TEXTO de la norma llega. | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/drift-cerebro-comun.sh:368 | FECHA | printf '%s\n' "🧠⚠️ DRIFT DE NORMAS (bloque BEGIN/END cortex de ~/.claude/CLAUDE.md vs la fuente única brain/norms/global-claude-md.md): el bloque inst | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
Bloques largos: 11 (11 l.), 23 (13 l.), 41 (11 l.), 220 (10 l.), 273 (16 l.), 329 (20 l.)

### hooks/merge-develop-guard.sh  (10 líneas, 6 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/merge-develop-guard.sh:3 | FECHA | # CONSOLIDA (2026-09-17) los guards antes separados 'merge-squash-guard' (exigía --squash + calidad del | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/merge-develop-guard.sh:25 | CITA,FECHA,NOMBRE | # COBERTURA (decisión unjordi 2026-09-17): canónica — reconoce el subcomando REAL 'glab mr merge\|accept' / | BORRAR fecha/etiqueta de auditoría-FMEA/hash + BORRAR la cita/atribución + REESCRIBIR genérico |
| hooks/merge-develop-guard.sh:39 | FECHA | # M4 (auditoría 2026-09-15 §2.3/§3.4): _recent_intercalado/_lexico_release_en_ventana ahora son WRAPPERS | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/merge-develop-guard.sh:180 | FECHA | # M5 (auditoría 2026-09-15 §3.5, 🔴 APRIETA): destino VACÍO ("$1" = "") TAMBIÉN pasa por el piso. Antes el | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/merge-develop-guard.sh:189 | FECHA,INCIDENTE | # M5-bis (auditoría FMEA 2026-09-16, ALTO §1.2, PRECISIÓN — no relaja el piso): medido por ejecución, M5 | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR sin la narración del caso/medición |
| hooks/merge-develop-guard.sh:194 | FECHA | # H2 (auditoría semántica 2026-09-16, ALTO, CONFIRMADO): el fix M5-bis ORIGINAL apagaba el piso con una | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/merge-develop-guard.sh:197 | INCIDENTE | # a main). Medido LIVE (3/3, Haiku real): con una conversación MUDA sobre destino ("perfecto, mergealo", | REESCRIBIR sin la narración del caso/medición |
| hooks/merge-develop-guard.sh:213 | FECHA | # (frontera posterior tras main). Endurecimiento — cierra el falso NEGATIVO del piso (auditoría 2026-08). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/merge-develop-guard.sh:486 | FECHA | # H3 (auditoría de ejecución 2026-09-16): si la autorización real quedó FUERA de la ventana (tail -n 6000 en una | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/merge-develop-guard.sh:499 | FECHA | # antes del LLM. SOLO se honra con destino CONFIRMADO 'develop' (CRÍTICO FMEA §1.3: con destino desconocido | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
Bloques largos: 2 (18 l.), 39 (9 l.), 55 (22 l.), 173 (15 l.), 194 (14 l.), 238 (12 l.)

### hooks/aviso-drift-cerebro.sh  (11 líneas, 4 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/aviso-drift-cerebro.sh:8 | CITA,FECHA,NOMBRE | # REDISEÑO #46 (unjordi + gemelo cachy, 2026-08-05) — BIFURCA por la marca '.claude/repo-compartido': | BORRAR fecha/etiqueta de auditoría-FMEA/hash + BORRAR la cita/atribución + REESCRIBIR genérico |
| hooks/aviso-drift-cerebro.sh:18 | CITA,FECHA,NOMBRE | # Diseño de unjordi (2026-07-18): "es tan sencillo como poner un hook en el global para que en el | BORRAR fecha/etiqueta de auditoría-FMEA/hash + BORRAR la cita/atribución + REESCRIBIR genérico |
| hooks/aviso-drift-cerebro.sh:23 | NOMBRE | # y AVISA para que Claude proponga la propagación por el flujo. Evidencia de necesidad: MegaFlux | REESCRIBIR genérico |
| hooks/aviso-drift-cerebro.sh:24 | FECHA | # acumuló 9 archivos de drift porque nadie corría el sync (detectado 2026-07-18). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/aviso-drift-cerebro.sh:31 | FECHA | # RECORDATORIO DE LA DUPLA (2026-07-31): cuando el cerebro de este repo CAMBIA (auto-sync) o está por | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/aviso-drift-cerebro.sh:37 | NOMBRE | # instanciar el esquema. NUNCA lo asume — la mayoría de los repos aún no tienen firma=TOC (hoy solo games-master). | REESCRIBIR genérico |
| hooks/aviso-drift-cerebro.sh:39 | FECHA | # CUÁNDO CORRE (verificado 2026-07-31 vs doc oficial de hooks + evidencia real — NO re-investigar): | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/aviso-drift-cerebro.sh:65 | CITA,FECHA,NOMBRE | # SURFACE si el archivo existe (no lo propaga ni lo asume universal). Diseño de unjordi (2026-07-31): | BORRAR fecha/etiqueta de auditoría-FMEA/hash + BORRAR la cita/atribución + REESCRIBIR genérico |
| hooks/aviso-drift-cerebro.sh:155 | FECHA | # Antídoto al ALTO-2 de la auditoría de suficiencia operativa (2026-09-18): install-brain §(e) SÍ refresca | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/aviso-drift-cerebro.sh:157 | INCIDENTE | # re-correrlo — confirmado en vivo, la norma seguía citando 'recordar-dashboard' (ya retirado) pese a que | REESCRIBIR sin la narración del caso/medición |
| hooks/aviso-drift-cerebro.sh:178 | FECHA | # esta máquina es la población en limbo del rename (auditoría 2026-08-29, C1/AUTOSYNC): el resolver bash | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
Bloques largos: 8 (9 l.), 39 (10 l.), 60 (8 l.), 175 (8 l.)

### hooks/ramas-zombie.sh  (12 líneas, 3 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/ramas-zombie.sh:6 | FECHA | # al drift entre los dos barredores — auditoría 2026-09-11: la protección solo vivía en uno de los dos). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/ramas-zombie.sh:15 | FECHA | # EL HUECO QUE CIERRA (e) (auditoría 2026-09-11, A-3): (d) es la ÚNICA señal que caza el squash de VARIOS | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/ramas-zombie.sh:30 | FECHA | # no exista — la ausencia de la remota no prueba integración, y el 'branch -D' es irreversible (FMEA A5/MEDIO-3). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/ramas-zombie.sh:47 | FECHA | # M-2 (auditoría 2026-09-11): con VARIAS 'Develop*' locales y HEAD en ninguna, (2) tomaba la primera por | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/ramas-zombie.sh:71 | FECHA | # C-3 (dictamen higiene de ramas 2026-09-17, PÉRDIDA DE DATOS): el '\|\| echo main' se ligaba al PIPELINE | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/ramas-zombie.sh:132 | FECHA | # B-2 (dictamen 2026-09-17): el cap era '300' fijo y MUDO — un repo con más PRs que eso dejaba las ramas | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/ramas-zombie.sh:133 | INCIDENTE | # viejas fuera de la señal (d) sin decirlo (medido: 433 PRs contra un cap de 300). Ahora el tope es | REESCRIBIR sin la narración del caso/medición |
| hooks/ramas-zombie.sh:184 | FECHA | # M-5 (auditoría 2026-09-11): clasificar por el HOST real de la URL, no por una subcadena de la URL | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/ramas-zombie.sh:210 | FECHA | # A-4 (dictamen higiene de ramas 2026-09-17): 'bz_pr_mergeado' consulta únicamente '--state merged', así que | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/ramas-zombie.sh:266 | FECHA | # C-2 (dictamen higiene de ramas 2026-09-17): admite SOLO las señales (a)/(e)/(d)/(c). La señal (b) | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/ramas-zombie.sh:309 | FECHA | # (b) declaraba zombie sin re-chequear commits únicos → PÉRDIDA DE DATOS (FMEA A5/MEDIO-3). El header | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/ramas-zombie.sh:333 | FECHA | # C-2 (auditoría 2026-09-11): antes esta protección SOLO vivía en limpiar.sh ramas; limpiar.sh worktrees | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
Bloques largos: 39 (15 l.), 70 (8 l.), 116 (11 l.)

### hooks/barrer-ramas.sh  (10 líneas, 2 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/barrer-ramas.sh:18 | CITA,FECHA,NOMBRE | # Por qué EXISTE (unjordi, 2026-07-21): 'limpiar.sh' es kind=script en el MANIFEST → se INSTALA pero | BORRAR fecha/etiqueta de auditoría-FMEA/hash + BORRAR la cita/atribución + REESCRIBIR genérico |
| hooks/barrer-ramas.sh:20 | FECHA | # deseo": este hook es el mecanismo. La vía (B) se añadió (2026-08-07, #53) porque la (A) solo barría al | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/barrer-ramas.sh:37 | FECHA | # ORDEN A-5 (auditoría 2026-09-11): las dos herramientas antes se lanzaban EN PARALELO ('&' cada una) — | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/barrer-ramas.sh:71 | FECHA | # C-1 (dictamen higiene de ramas 2026-09-17) — CAUSA RAÍZ del reguero de 23 ramas: ROOT salía SIEMPRE de | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/barrer-ramas.sh:73 | INCIDENTE | # ('cd ~/code/cortex && gh pr merge …' desde una sesión abierta en otro proyecto). Medido en vivo: 'cortex' | REESCRIBIR sin la narración del caso/medición |
| hooks/barrer-ramas.sh:91 | FECHA | # 2026-09-17 el MISMO dispatcher 'limpiar.sh' (subcomandos 'ramas'/'worktrees', antes dos ejecutables | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/barrer-ramas.sh:102 | FECHA | # M-1 (dictamen 2026-09-17): devuelve 0 SOLO si el barrido de verdad se LANZÓ. El throttle marca entonces | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/barrer-ramas.sh:103 | FECHA | # el ÉXITO del lanzamiento, no el INTENTO — antes el stamp se sellaba ANTES de 'lanzar()' y, si el spawn | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/barrer-ramas.sh:127 | INCIDENTE | ctx="🧹 Merge de MR/PR detectado → barriendo en segundo plano, EN ${ROOT} (el repo donde ocurrió el merge), las ramas locales Y los worktrees que queda | REESCRIBIR sin la narración del caso/medición |
| hooks/barrer-ramas.sh:146 | INCIDENTE | lanzar \|\| exit 0    # no se pudo lanzar → NO se sella el throttle ni se anuncia un barrido que no ocurrió | REESCRIBIR sin la narración del caso/medición |
Bloques largos: 5 (8 l.), 71 (8 l.)

### hooks/git-branch-guard.sh  (9 líneas, 3 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/git-branch-guard.sh:19 | FECHA | # H1 (auditoría semántica 2026-09-16, ALTO): extrae el valor LITERAL del campo "command" del JSON (nunca | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/git-branch-guard.sh:30 | FECHA | # ALTO-2 (auditoría FMEA 2026-09-16 §1.4): sin jq, bloquear TODO push (incluida tu propia ramita/mini- | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/git-branch-guard.sh:32 | FECHA | # H1 (auditoría semántica 2026-09-16, CONFIRMADO): la corrección ORIGINAL de ALTO-2 razonaba sobre el | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/git-branch-guard.sh:47 | FECHA | # ALTO (auditoría de coherencia 2026-09-18, MEDIO en el veredicto): el escape | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/git-branch-guard.sh:76 | INCIDENTE | # sed/grep/source-lib. Jamás salta un caso real (a lo más sigue de más). | REESCRIBIR sin la narración del caso/medición |
| hooks/git-branch-guard.sh:83 | FECHA,INCIDENTE | # CRÍTICO-1 (auditoría FMEA 2026-09-16 §1.1, CONFIRMADO): sourcear un archivo con error de SINTAXIS mata el | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR sin la narración del caso/medición |
| hooks/git-branch-guard.sh:85 | FECHA | # y el push/merge PASA sin gate). H7 (auditoría semántica 2026-09-16, BAJO): la sonda ORIGINAL sourceaba la | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/git-branch-guard.sh:109 | FECHA | # M8 (auditoría 2026-09-15 §3.11, norma dura anti-vein-popper): se RETIRÓ "normalmente el humano en la web | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/git-branch-guard.sh:113 | FECHA | # H5 (auditoría de ejecución 2026-09-16 §H5, BAJO-MEDIO): la SIEMBRA de un repo/rama base VACÍA (0 commits) | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
Bloques largos: 30 (9 l.), 83 (10 l.), 113 (10 l.)

### hooks/limpiar-impl-ramas.sh  (9 líneas, 3 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/limpiar-impl-ramas.sh:7 | INCIDENTE | # barría y se acumulaban (un caso real: 60+ en un repo). Invócalo vía 'limpiar.sh ramas' — es | REESCRIBIR sin la narración del caso/medición |
| hooks/limpiar-impl-ramas.sh:8 | FECHA | # implementación interna del dispatcher 'limpiar.sh' (antes el ejecutable suelto 'limpiar-ramas.sh', | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar-impl-ramas.sh:9 | FECHA | # retirado 2026-09-17, ver MANIFEST). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar-impl-ramas.sh:25 | FECHA | # A-1 (auditoría 2026-09-11, "no silent caps"): el resumen antes solo contaba borradas/conservadas y las | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar-impl-ramas.sh:48 | FECHA | # C-3 (dictamen 2026-09-17): sin una base que EXISTA, toda señal de integración falla muda y las ramas caen | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar-impl-ramas.sh:78 | FECHA | # C-1 (auditoría 2026-09-11, PÉRDIDA DE DATOS): antes se decidía con 'ls-remote --exit-code' — que solo | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar-impl-ramas.sh:109 | FECHA | # A-4 (dictamen higiene de ramas 2026-09-17): recorriendo el ciclo actor por actor, la transición | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar-impl-ramas.sh:188 | FECHA | # C-2 (dictamen higiene de ramas 2026-09-17, CAUSA RAÍZ #2 del reguero): el bucle de arriba recorre solo | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar-impl-ramas.sh:191 | INCIDENTE | # Medido: 12 de las 23 ramas de 'origin' eran de esa clase (8 ya integradas + 4 con trabajo represado). | REESCRIBIR sin la narración del caso/medición |
Bloques largos: 2 (9 l.), 108 (10 l.), 187 (8 l.)

### hooks/secret-scan.sh  (11 líneas, 1 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/secret-scan.sh:64 | FECHA | # M2 (auditoría 2026-09-15, CRÍTICO §3.1): cwd del payload = working dir REAL del comando (puede diferir | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/secret-scan.sh:73 | INCIDENTE | # normalización/despoja-comillas. Jamás salta un caso real. | REESCRIBIR sin la narración del caso/medición |
| hooks/secret-scan.sh:80 | FECHA,INCIDENTE | # CRÍTICO-1 (auditoría FMEA 2026-09-16 §1.1, CONFIRMADO): sourcear un archivo con error de SINTAXIS mata el | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR sin la narración del caso/medición |
| hooks/secret-scan.sh:84 | FECHA | # guards. H7 (auditoría semántica 2026-09-16, BAJO): la sonda ORIGINAL sourceaba en un SUBSHELL y trataba | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/secret-scan.sh:97 | FECHA | # A-03/A-R4-02 (FMEA): colapsa el prefijo de opciones globales de git ('-c k=v', '-C dir', '--no-pager', | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/secret-scan.sh:99 | FECHA | # prefijo cegaba el escaneo). A-R5-02 (FMEA r5): se NORMALIZA SOBRE EL RAW (comillas intactas) ANTES de | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/secret-scan.sh:115 | FECHA | # LÍMITE CONOCIDO (A-07, FMEA): casa el subcomando LITERAL commit/push; un ALIAS de git del usuario ('git ci', | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/secret-scan.sh:158 | CITA,NOMBRE | # 'secret' entraba (hueco real del audit-07, OK de unjordi). Iteramos cada 'git add' y sumamos su dry-run. | BORRAR la cita/atribución + REESCRIBIR genérico |
| hooks/secret-scan.sh:206 | FECHA,INCIDENTE | # DEFECTO medido (auditoría overhead 2026-09-16, §defecto #4): el escaneo primario ANTES corría un | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR sin la narración del caso/medición |
| hooks/secret-scan.sh:207 | INCIDENTE | # 'git diff -- "$f"' POR ARCHIVO en un bucle — lineal en archivos tocados; medido en producción: 600 s | REESCRIBIR sin la narración del caso/medición |
| hooks/secret-scan.sh:279 | FECHA | # 1 archivo o 10 000 (el caso común, y el que antes se comía los 600 s de timeout). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
Bloques largos: 76 (14 l.)

### sesiones-master/README.md  (11 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| sesiones-master/README.md:1 | NOMBRE | # claude-sessions — sesiones master de unjordi (sincronizadas por Google Drive) | REESCRIBIR genérico |
| sesiones-master/README.md:3 | NOMBRE | Hace que las sesiones "master" de Claude Code (una por dominio) **viajen entre las compus de unjordi** | REESCRIBIR genérico |
| sesiones-master/README.md:4 | NOMBRE | (Mac ↔ Cachy) para poder 'claude --resume' la MISMA conversación en cualquiera. | REESCRIBIR genérico |
| sesiones-master/README.md:12 | NOMBRE | - **Cachy:** '/run/media/unjordi/SteamAndFiles/GoogleDrive/claude-sessions/' | REESCRIBIR genérico |
| sesiones-master/README.md:29 | NOMBRE | \| 'cps-master' \| '~/code/cps' \| | REESCRIBIR genérico |
| sesiones-master/README.md:35 | NOMBRE | cd ~/Mi\ unidad/claude-sessions      # (Cachy: cd /run/media/unjordi/SteamAndFiles/GoogleDrive/claude-sessions) | REESCRIBIR genérico |
| sesiones-master/README.md:39 | NOMBRE | Requisitos: 'cortex' instalado (aporta 'session-import.js') + 'node'. En la Cachy, que la unidad | REESCRIBIR genérico |
| sesiones-master/README.md:57 | CITA,FECHA,INCIDENTE | > **Por qué 3 y no solo 'SessionEnd' (bug real, 2026-07-26):** las master son de **vida larga** — se | BORRAR fecha/etiqueta de auditoría-FMEA/hash + BORRAR la cita/atribución + REESCRIBIR sin la narración del caso/medición |
| sesiones-master/README.md:59 | NOMBRE | > **congelado 2 días** (todo en la Cachy salía viejo). El backbone 'Stop'+debounce mata esa causa raíz. | REESCRIBIR genérico |
| sesiones-master/README.md:61 | FECHA | ## El roster de masters (Opción A, 2026-10-14) — NO más 'masters.json' compartido | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| sesiones-master/README.md:65 | CITA,NOMBRE | y **drift** (ids viejos, targets que eran worktrees, nombres repetidos). Jordi lo mandó a **mantenerse a mano | BORRAR la cita/atribución + REESCRIBIR genérico |

### sincronizar-cerebro.sh  (6 líneas, 5 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| sincronizar-cerebro.sh:33 | FECHA | #   RETIRO (tier 'retirado' del MANIFEST, o legado en brain/hooks/RETIRED) se retiran SIEMPRE en | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| sincronizar-cerebro.sh:35 | INCIDENTE | #   Antídoto a un hook retirado que quedó cableado y rompe (caso real: el viejo precompact-volcar-estado | REESCRIBIR sin la narración del caso/medición |
| sincronizar-cerebro.sh:55 | FECHA | #   como "sobrante" es el FP ya documentado en docs/guards-falsos-positivos.md (2026-09-08: el chequeo | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| sincronizar-cerebro.sh:233 | FECHA | # ver cabecera y docs/guards-falsos-positivos.md 2026-09-08), no 'global' (nunca los deja aquí este sync). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| sincronizar-cerebro.sh:418 | DECOR | # ══════════════════════════════════════════════════════════════════════════════════════════════════════ | BORRAR la caja/banner |
| sincronizar-cerebro.sh:520 | DECOR | # ══════════════════════════════════════════════════════════════════════════════════════════════════════ | BORRAR la caja/banner |
Bloques largos: 6 (16 l.), 45 (24 l.), 369 (8 l.), 418 (9 l.), 463 (10 l.)

### verificar-firma-canonica.sh  (11 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| verificar-firma-canonica.sh:3 | NOMBRE | # en un cerebro INSTANCIADO (los que produce cortex: cps, fluxcore, plantilladotnet…). | REESCRIBIR genérico |
| verificar-firma-canonica.sh:5 | NOMBRE | # Hoy los cerebros DRIFTEAN de la firma canónica (fluxcore estaba plano: memorias sin prefijo, | REESCRIBIR genérico |
| verificar-firma-canonica.sh:8 | FECHA | # las arregle. Es el detector que alimenta el GATE del auditor (#44). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| verificar-firma-canonica.sh:11 | NOMBRE | # instancia de referencia = cps y fluxcore): | REESCRIBIR genérico |
| verificar-firma-canonica.sh:67 | DECOR | # ───────────────────────────────────────────────────────────────────────────── | BORRAR la caja/banner |
| verificar-firma-canonica.sh:97 | DECOR | # ───────────────────────────────────────────────────────────────────────────── | BORRAR la caja/banner |
| verificar-firma-canonica.sh:110 | DECOR | # ───────────────────────────────────────────────────────────────────────────── | BORRAR la caja/banner |
| verificar-firma-canonica.sh:133 | DECOR | # ───────────────────────────────────────────────────────────────────────────── | BORRAR la caja/banner |
| verificar-firma-canonica.sh:177 | DECOR | # ───────────────────────────────────────────────────────────────────────────── | BORRAR la caja/banner |
| verificar-firma-canonica.sh:181 | FECHA | # Denylist PRECISA de hooks que el cerebro RETIRÓ: si aparecen en la prosa, la doc miente. | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| verificar-firma-canonica.sh:196 | DECOR | # ───────────────────────────────────────────────────────────────────────────── | BORRAR la caja/banner |

### hooks/exportar-sesion-master.sh  (8 líneas, 2 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/exportar-sesion-master.sh:23 | INCIDENTE,NOMBRE | # ("Hook cancelled", caso real cps-master 456 MB) → el hook retorna al instante y el gzip+copy termina en | REESCRIBIR genérico + REESCRIBIR sin la narración del caso/medición |
| hooks/exportar-sesion-master.sh:28 | FECHA | # de nombre (título *-master) y/o por tener ya su '<sid>.meta.json'. NO escribe masters.json (Opción A, 2026-10-14). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/exportar-sesion-master.sh:63 | FECHA | # el transcript. (Opción A, 2026-10-14: el hook YA NO escribe un masters.json compartido —generaba | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/exportar-sesion-master.sh:65 | FECHA | # Paridad con el fast-path viejo: antes el 1er registro ocurría en SessionEnd/PreCompact —el register block—; | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/exportar-sesion-master.sh:70 | NOMBRE | # duplicado — sin esto, ese master (p. ej. "cortex-master (2)") dejaba de exportarse EN SILENCIO. Devuelve el | REESCRIBIR genérico |
| hooks/exportar-sesion-master.sh:118 | FECHA | # orden/fallback que los widgets (#322): $CLAUDE_BRAIN_DIR → ~/.cortex → ~/.claude-brain (nombre viejo). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/exportar-sesion-master.sh:137 | INCIDENTE,NOMBRE | # cancelled" (caso REAL: cps-master, 456 MB, el auto-export se quedó congelado). Solución: lanzar el | REESCRIBIR genérico + REESCRIBIR sin la narración del caso/medición |
| hooks/exportar-sesion-master.sh:167 | CITA,FECHA,NOMBRE | # ── Opción A (Jordi, 2026-10-14): el hook YA NO escribe un masters.json compartido. ─────────────── | BORRAR fecha/etiqueta de auditoría-FMEA/hash + BORRAR la cita/atribución + REESCRIBIR genérico |
Bloques largos: 12 (9 l.), 167 (8 l.)

### hooks/limpiar-impl-worktrees.sh  (7 líneas, 3 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/limpiar-impl-worktrees.sh:4 | INCIDENTE | # quien lo retome. Antídoto a los worktrees zombies que se acumulan (un caso real: 29). SEGURO: nunca toca | REESCRIBIR sin la narración del caso/medición |
| hooks/limpiar-impl-worktrees.sh:7 | FECHA | # 'limpiar.sh worktrees' — es implementación interna del dispatcher 'limpiar.sh' (antes el ejecutable | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar-impl-worktrees.sh:8 | FECHA | # suelto 'limpiar-worktrees.sh', retirado 2026-09-17, ver MANIFEST). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar-impl-worktrees.sh:16 | FECHA | # Auditoría 2026-09-11 — tres arreglos de PÉRDIDA DE DATOS confirmada por ejecución: | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar-impl-worktrees.sh:55 | FECHA | # C-3 (dictamen 2026-09-17): gemelo estructural del candado de limpiar-ramas — sin una base que EXISTA | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar-impl-worktrees.sh:68 | FECHA | # A-1 (dictamen higiene de ramas 2026-09-17): además deja en $SUCIO_N cuántos archivos lo ensucian, para | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar-impl-worktrees.sh:132 | FECHA | # M-3: un worktree en HEAD detached no emite línea "branch " → antes era invisible (ni zombie, ni | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
Bloques largos: 2 (8 l.), 16 (16 l.), 65 (9 l.)

### hooks/proteger-arbol.sh  (7 líneas, 3 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/proteger-arbol.sh:3 | INCIDENTE | # ORFANAR commits sin pushear en el árbol de trabajo actual. Antídoto al un caso REAL (2026-07): | REESCRIBIR sin la narración del caso/medición |
| hooks/proteger-arbol.sh:12 | FECHA | # cwd del payload = working dir REAL del comando (M2, auditoría 2026-09-15 §2.4/§3.1): antes este hook NI | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/proteger-arbol.sh:21 | INCIDENTE | # salta un caso real. | REESCRIBIR sin la narración del caso/medición |
| hooks/proteger-arbol.sh:24 | FECHA,INCIDENTE | # CRÍTICO-1 (auditoría FMEA 2026-09-16 §1.1, CONFIRMADO): sourcear un archivo con error de SINTAXIS mata el | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR sin la narración del caso/medición |
| hooks/proteger-arbol.sh:27 | FECHA | # acg_despoja_comillas' de abajo pudiera preguntar. H7 (auditoría semántica 2026-09-16, BAJO): la sonda | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/proteger-arbol.sh:40 | FECHA | # M1 (auditoría 2026-09-15 §3.8): el filtro de heredoc PROPIO de este hook (descartaba TODO cuerpo de | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/proteger-arbol.sh:47 | INCIDENTE | # caso real por sobre-quitar; a lo más re-abre el FN viejo, nunca uno nuevo). | REESCRIBIR sin la narración del caso/medición |
Bloques largos: 24 (8 l.), 40 (8 l.), 77 (8 l.)

### hooks/dod-verificar.sh  (6 líneas, 3 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/dod-verificar.sh:13 | FECHA | # whack-a-mole: cada frasing nuevo abría un FP o un FN (el último, 2026-08-02: "verificado técnicamente | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/dod-verificar.sh:52 | FECHA | # ── CONTRATO DE COHERENCIA DE TIMEOUTS (fix 2026-09-16, corrige una carrera real medida en telemetría) ── | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/dod-verificar.sh:56 | INCIDENTE | # que el hook SIEMPRE pierde, matado 5s ANTES de que su propio juez agotara su presupuesto. Medido en | REESCRIBIR sin la narración del caso/medición |
| hooks/dod-verificar.sh:69 | INCIDENTE | # de la respuesta — medido p99≈953ms cuando el juez ni se llega a llamar, caso "screen-out local" sin red) | REESCRIBIR sin la narración del caso/medición |
| hooks/dod-verificar.sh:97 | FECHA | # de 20s el 2026-09-16: ese crédito era MAYOR que el "timeout" de 15s que el harness del Stop hook cablea en | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/dod-verificar.sh:101 | INCIDENTE | # llamada curl de ~1-6s (p95 real medido); el techo de 10s solo acota casos degenerados, no el caso común. | REESCRIBIR sin la narración del caso/medición |
Bloques largos: 11 (16 l.), 52 (22 l.), 82 (32 l.)

### hooks/juez-comun.sh  (1 líneas, 6 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/juez-comun.sh:25 | FECHA | #              auditoría de ejecución 2026-09-16: M8, auditoría 2026-09-15 §3.11, retiró la redirección a la | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
Bloques largos: 1 (9 l.), 11 (23 l.), 35 (8 l.), 88 (8 l.), 104 (8 l.), 157 (9 l.)

### hooks/limpiar-impl-flotilla.sh  (6 líneas, 1 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/limpiar-impl-flotilla.sh:4 | FECHA | # suelto 'barrer-flotilla-cerebro.sh', retirado 2026-09-17, ver MANIFEST). Tier global, kind script; NO se | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar-impl-flotilla.sh:9 | NOMBRE | # → solo ve el repo donde ARRANCÓ la sesión. La flotilla de otros repos brained (MegaFlux, cps, …) se queda | REESCRIBIR genérico |
| hooks/limpiar-impl-flotilla.sh:10 | NOMBRE | # a la deriva hasta que abras sesión en cada uno. Evidencia real: MegaFlux acumuló ~9 archivos de drift | REESCRIBIR genérico |
| hooks/limpiar-impl-flotilla.sh:32 | NOMBRE | # Programación (NO se instala vivo aquí — es config de máquina, la decide unjordi): | REESCRIBIR genérico |
| hooks/limpiar-impl-flotilla.sh:54 | NOMBRE | # /Users/unjordi → -Users-unjordi (macOS) · /home/unjordi → -home-unjordi (Linux). Hardcodear "-Users-" | REESCRIBIR genérico |
| hooks/limpiar-impl-flotilla.sh:55 | NOMBRE | # rompía en Linux (la Cachy): el path no existía → '[ -f "$DASHBOARD" ]' fallaba → la bitácora del sweeper | REESCRIBIR genérico |
Bloques largos: 24 (11 l.)

### hooks/sincronizar-tasklist.sh  (5 líneas, 1 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/sincronizar-tasklist.sh:11 | FECHA,INCIDENTE | # CRUX (medido 2026-09-18, ver DISEÑO): el harness LEE los task-json al SessionStart, los tiene EN MEMORIA | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR sin la narración del caso/medición |
| hooks/sincronizar-tasklist.sh:123 | DECOR | # ═══════════════════════════════════════════════════════════════════════════════════════════════════════ | BORRAR la caja/banner |
| hooks/sincronizar-tasklist.sh:126 | DECOR | # ═══════════════════════════════════════════════════════════════════════════════════════════════════════ | BORRAR la caja/banner |
| hooks/sincronizar-tasklist.sh:170 | DECOR | # ═══════════════════════════════════════════════════════════════════════════════════════════════════════ | BORRAR la caja/banner |
| hooks/sincronizar-tasklist.sh:175 | DECOR | # ═══════════════════════════════════════════════════════════════════════════════════════════════════════ | BORRAR la caja/banner |
Bloques largos: 2 (8 l.)

### install-brain.ps1  (5 líneas, 1 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| install-brain.ps1:14 | FECHA,INCIDENTE | # "jq no disponible" (bug real Windows+WSL, 2026-07-20). Por eso buscamos PRIMERO el bash.exe de Git | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR sin la narración del caso/medición |
| install-brain.ps1:62 | FECHA,INCIDENTE | # (Fuente: docs de Claude Code, troubleshoot-install.) Bug real diagnosticado 2026-07-20 (Windows+WSL). | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR sin la narración del caso/medición |
| install-brain.ps1:74 | FECHA | # C1 (FMEA post-integracion 2026-07-30): en una instalacion MANUAL de Windows (pwsh -File brain\install-brain.ps1 | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| install-brain.ps1:103 | INCIDENTE | # hallamos bash.exe fuera del PATH). Caso real: 'winget install jqlang.jq' deja jq como shim en | REESCRIBIR sin la narración del caso/medición |
| install-brain.ps1:242 | FECHA,INCIDENTE | # nunca corre (bug real en Windows, 2026-07-20). Una ruta con forward-slashes (C:/Users/.../ | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR sin la narración del caso/medición |
Bloques largos: 142 (9 l.)

### scripts/auditor-semantico/invariantes-semanticos.yml  (5 líneas, 1 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| scripts/auditor-semantico/invariantes-semanticos.yml:38 | FECHA | Auditoría de un proyecto derivado, 2026-07-15 — un servicio no validaba las FK recibidas | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| scripts/auditor-semantico/invariantes-semanticos.yml:50 | FECHA | Auditoría de un proyecto derivado, 2026-07-15 — las firmas se verificaron correctas (usan | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| scripts/auditor-semantico/invariantes-semanticos.yml:64 | FECHA | Auditoría de un proyecto derivado, 2026-07-15 — un servicio calculaba el folio sin lock | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| scripts/auditor-semantico/invariantes-semanticos.yml:77 | FECHA | Auditoría de un proyecto derivado, 2026-07-15 — el método que cerraba un agregado no tenía | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| scripts/auditor-semantico/invariantes-semanticos.yml:88 | FECHA | Auditoría de un proyecto derivado, 2026-07-15 — un campo con códigos fijos de un catálogo | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
Bloques largos: 17 (9 l.)

### hooks/limpiar-impl-residuo.sh  (3 líneas, 2 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/limpiar-impl-residuo.sh:5 | FECHA | # — es implementación interna del dispatcher 'limpiar.sh' (antes el ejecutable suelto | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar-impl-residuo.sh:6 | CITA,FECHA,NOMBRE | # 'limpiar-residuo.sh', retirado 2026-09-17, ver MANIFEST). Queja real de unjordi (2026-09): | BORRAR fecha/etiqueta de auditoría-FMEA/hash + BORRAR la cita/atribución + REESCRIBIR genérico |
| hooks/limpiar-impl-residuo.sh:7 | CITA,INCIDENTE | # "qué pasa con lo que deja detrás... no todo eran ramas con worktree". Medido en vivo: 178MB en | BORRAR la cita/atribución + REESCRIBIR sin la narración del caso/medición |
Bloques largos: 2 (8 l.), 21 (11 l.)

### hooks/recordar-cosechar.sh  (3 líneas, 1 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/recordar-cosechar.sh:4 | NOMBRE | # backlog durable (que viaja por git y ven los otros claudios/colegas) refleje la vista de tareas sin | REESCRIBIR genérico |
| hooks/recordar-cosechar.sh:11 | FECHA | # Rediseño 2026-09-18 (sync bidireccional): antes el espejo escribía RUIDO — con el session_id ROTADO (que | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/recordar-cosechar.sh:20 | FECHA | # se retiró; regresa anclada al hecho y con un propósito accionable: cerrar el lazo json→durable→HUD). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
Bloques largos: 11 (10 l.)

### scripts/auditor-semantico/checks/04-grid-homologado.sh  (3 líneas, 1 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| scripts/auditor-semantico/checks/04-grid-homologado.sh:4 | FECHA,NOMBRE | # Hallazgo que lo originó: auditoría de MegaFlux (2026-07-15) — 'FlotaEnOperacionPage.razor' | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR genérico |
| scripts/auditor-semantico/checks/04-grid-homologado.sh:19 | FECHA,NOMBRE | # Nota de diseño (2026-07-15, tras correr esto contra MegaFlux): la primera versión de este | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR genérico |
| scripts/auditor-semantico/checks/04-grid-homologado.sh:23 | INCIDENTE | # además se comió el propio bug real ('Filtradas =>' con el '.Where(...)' en la línea | REESCRIBIR sin la narración del caso/medición |
Bloques largos: 19 (8 l.)

### hooks/aviso-contexto.sh  (2 líneas, 1 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/aviso-contexto.sh:4 | CITA,FECHA,NOMBRE | # PRINCIPIO RECTOR (unjordi, REVISIÓN 2026-09-17): el hook HACE trabajo real, no reporta cada 5%. La | BORRAR fecha/etiqueta de auditoría-FMEA/hash + BORRAR la cita/atribución + REESCRIBIR genérico |
| hooks/aviso-contexto.sh:99 | CITA,FECHA,NOMBRE | # <synthetic>): NO inventamos un número — fail-open SILENCIOSO, igual que sin jq/usage. (Jordi 2026-10-13: | BORRAR fecha/etiqueta de auditoría-FMEA/hash + BORRAR la cita/atribución + REESCRIBIR genérico |
Bloques largos: 4 (11 l.)

### hooks/no-bypass-deploy.sh  (2 líneas, 1 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/no-bypass-deploy.sh:38 | FECHA | # Quita literales entrecomillados → una MENCIÓN del instalador (grep/echo/doc) no dispara. M1 (auditoría | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/no-bypass-deploy.sh:39 | FECHA | # 2026-09-15 §2.1): unifica con la lib compartida (ejecutor/heredoc-aware: un 'bash -c "install.sh"' o un | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
Bloques largos: 53 (11 l.)

### scripts/auditor-semantico/README.md  (3 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| scripts/auditor-semantico/README.md:9 | FECHA | este sistema, 2026-07-15). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| scripts/auditor-semantico/README.md:32 | FECHA | uno nace de un hallazgo REAL de una auditoría (positivo o negativo) que resultó ser | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| scripts/auditor-semantico/README.md:96 | INCIDENTE | 2. Cada hallazgo (positivo: "esto está bien hecho, no lo rompan" o negativo: un bug real) se | REESCRIBIR sin la narración del caso/medición |

### scripts/auditor-semantico/ejecutar.sh  (3 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| scripts/auditor-semantico/ejecutar.sh:34 | DECOR | echo "═══════════════════════════════════════════════════════════" | BORRAR la caja/banner |
| scripts/auditor-semantico/ejecutar.sh:42 | DECOR | echo "═══════════════════════════════════════════════════════════" | BORRAR la caja/banner |
| scripts/auditor-semantico/ejecutar.sh:75 | DECOR | echo "═══ Resumen ═══" | BORRAR la caja/banner |

### hooks/checkpoint-mecanico.sh  (2 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/checkpoint-mecanico.sh:4 | FECHA | # 2026-09-11). | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/checkpoint-mecanico.sh:18 | FECHA | # otro modelo. Eso es la vía-1 del dictamen (viable pero cuesta dinero y pasa por 'delegacion-gate') — | BORRAR fecha/etiqueta de auditoría-FMEA/hash |

### hooks/contrato-hilo.sh  (2 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/contrato-hilo.sh:7 | INCIDENTE | # OBSOLETO" —, la skill 'checkpoint' lo PRESCRIBE en su plantilla… y nadie lo VERIFICABA. Medido el | REESCRIBIR sin la narración del caso/medición |
| hooks/contrato-hilo.sh:8 | FECHA | # 2026-09-11 sobre los 9 'hilo-mental-actual.md' reales de ~/code: **2 de 9 (22%) no traen el footer** | BORRAR fecha/etiqueta de auditoría-FMEA/hash |

### hooks/dashboard_cerebro.template.md  (2 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/dashboard_cerebro.template.md:5 | FECHA | > (self-check tuyo, sin hook que lo recuerde — recordar-dashboard.sh se retiro overhaul hooks | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/dashboard_cerebro.template.md:6 | FECHA | > 2026-09-18, puramente advisory): APPENDEA una linea al FINAL de la Bitacora (con '>>', no editando | BORRAR fecha/etiqueta de auditoría-FMEA/hash |

### hooks/entorno-maquina-guard.sh  (1 líneas, 1 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/entorno-maquina-guard.sh:30 | FECHA | # M1 (auditoría 2026-09-15 §2.1): el despoje era una copia a mano (sed sin heredoc/ejecutor-aware) — se | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
Bloques largos: 8 (8 l.)

### hooks/limpiar.sh  (2 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/limpiar.sh:2 | FECHA | # limpiar.sh — DISPATCHER único de los barridos de higiene del cerebro. Consolida (2026-09-17) los | BORRAR fecha/etiqueta de auditoría-FMEA/hash |
| hooks/limpiar.sh:3 | FECHA | # ejecutables sueltos que antes se invocaban cada uno por su propio nombre — limpiar-ramas.sh, | BORRAR fecha/etiqueta de auditoría-FMEA/hash |

### hooks/verificar-cerebro.sh  (2 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/verificar-cerebro.sh:4 | NOMBRE | # y CABLEADO de verdad — antídoto al caso "las instancias de Carlitos/Chunito dejaron de avisar del | REESCRIBIR genérico |
| hooks/verificar-cerebro.sh:28 | FECHA | # orden/fallback que los widgets (#322): $CLAUDE_BRAIN_DIR → ~/.cortex → ~/.claude-brain. Si la lib no | BORRAR fecha/etiqueta de auditoría-FMEA/hash |

### scripts/auditor-semantico/checks/01-permisos-endpoints-mutantes.sh  (2 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| scripts/auditor-semantico/checks/01-permisos-endpoints-mutantes.sh:4 | FECHA,NOMBRE | # Hallazgo que lo originó: auditoría de MegaFlux (2026-07-15) — todos los endpoints | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR genérico |
| scripts/auditor-semantico/checks/01-permisos-endpoints-mutantes.sh:17 | FECHA,NOMBRE | # — igual de válido; confirmado real en MegaFlux/RolesController, 2026-07-15, que generaba | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR genérico |

### hooks/cementerio.sh  (0 líneas, 1 bloques largos)
Bloques largos: 12 (11 l.)

### hooks/checkpoint-mecanico-comun.sh  (1 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/checkpoint-mecanico-comun.sh:15 | INCIDENTE | #   medido en exportar-sesion-master.sh). Escritura ATÓMICA (tmp+rename dentro del .js): el andamio nunca | REESCRIBIR sin la narración del caso/medición |

### hooks/delegacion-gate.sh  (0 líneas, 1 bloques largos)
Bloques largos: 14 (14 l.)

### hooks/delegacion-registrar.sh  (1 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/delegacion-registrar.sh:8 | FECHA | # (no es veredicto) — el mecanismo de la norma "dictamen de agente PROPONE, el usuario DECIDE". | BORRAR fecha/etiqueta de auditoría-FMEA/hash |

### hooks/proteger-fuente-cerebro.sh  (1 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| hooks/proteger-fuente-cerebro.sh:40 | FECHA | # orden/fallback que los widgets (#322): $CLAUDE_BRAIN_DIR → ~/.cortex → ~/.claude-brain. Si la lib no | BORRAR fecha/etiqueta de auditoría-FMEA/hash |

### hooks/sesion-inicio.sh  (0 líneas, 1 bloques largos)
Bloques largos: 2 (9 l.)

### nuevo-repo.sh  (1 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| nuevo-repo.sh:15 | NOMBRE | #   ./nuevo-repo.sh mx_pind_devops/mx_megaflux_devops/x --dir ~/code/x | REESCRIBIR genérico |

### scripts/auditor-semantico/checks/02-ruta-id-para-auditoria.sh  (1 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| scripts/auditor-semantico/checks/02-ruta-id-para-auditoria.sh:4 | FECHA,NOMBRE | # Hallazgo que lo originó: auditoría de MegaFlux (2026-07-15) — 'SucesosController' usaba | BORRAR fecha/etiqueta de auditoría-FMEA/hash + REESCRIBIR genérico |

### sembrar-mini-develop.sh  (1 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| sembrar-mini-develop.sh:5 | INCIDENTE | # borrada ya costó trabajo real, 2026-07). Es el MECANISMO de la norma "Modelo MINI-DEVELOP" (toda | REESCRIBIR sin la narración del caso/medición |

### sesiones-master/install-hook.sh  (1 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| sesiones-master/install-hook.sh:20 | FECHA | # (#322): $CLAUDE_BRAIN_DIR → ~/.cortex → ~/.claude-brain (nombre viejo). Si la lib no está (caso raro), | BORRAR fecha/etiqueta de auditoría-FMEA/hash |

### sesiones-master/seed.sh  (1 líneas, 0 bloques largos)
| ubicación | cat | texto | propuesta |
|---|---|---|---|
| sesiones-master/seed.sh:30 | FECHA | # Opción A (2026-10-14): el roster de masters ya NO vive en UN masters.json compartido (lo generaba conflictos | BORRAR fecha/etiqueta de auditoría-FMEA/hash |

### uninstall-brain.sh  (0 líneas, 1 bloques largos)
Bloques largos: 6 (13 l.)

## Aparte: hooks/MANIFEST y hooks/RETIRED
- hooks/MANIFEST:92-98 y 99-103: lápidas `retirado` con fecha de retiro y motivo. La fecha es columna de DATOS que consumen install-brain/sincronizar/uninstall (no es infracción). Infracción INCIDENTE en los motivos de 99-103 ("puramente advisory (medido: ignorado)"): reescribir a "reemplazado por la norma X".
- hooks/MANIFEST:3-4: "antídoto a H2/H7: hoy install-brain.sh y la copia por-repo del consumidor eran dos listas..." = TRAZA; borrar. hooks/MANIFEST:11-30: encabezado del tier retirado de ~20 líneas con narrativa (FECHA/PROCESO); condensar a contrato (qué hace cada consumidor ante un `retirado`).
- hooks/RETIRED:1: "YA RETIRÓ" (traza leve), aceptable.

## Aparte: brain/norms/global-claude-md.md (solo FECHA/TRAZA, INCIDENTE, DRAMA, CITA)
| línea | cat | texto | propuesta |
|---|---|---|---|
| norms:11 | FECHA,INCIDENTE | (overhaul hooks 2026-09-18: `recordar-dashboard` era puramente advisory — medido: ignorado — se retiró; …) | BORRAR el paréntesis; dejar "Antes de un git push revisa: (1) dashboard… (2) doc de lo tocado" |
| norms:82 | FECHA,INCIDENTE | (el NUDGE INCONDICIONAL viejo de `recordar-cosechar` era puramente advisory — medido: ignorado — se retiró en el overhaul hooks 2026-09-18; el rediseño 2026-09-18 lo restauró…) | REESCRIBIR: "El hook recordar-cosechar solo avisa cuando el espejo movió ≥1 pendiente vivo." |
| norms:83 | FECHA | El ESPEJO del TaskList evolucionó a SYNC BIDIRECCIONAL (rediseño 2026-09-18, …) | REESCRIBIR: "El espejo del TaskList es sync bidireccional…" sin "evolucionó/rediseño/fecha" |
| norms:140 | FECHA,INCIDENTE | (overhaul hooks 2026-09-18: `recordar-unificar-cerebro` … medido: ignorado — se retiró) | BORRAR paréntesis |
| norms:170 | FECHA,INCIDENTE | Sin hook que lo cuente (overhaul hooks 2026-09-18: `recordar-orquestar` … medido: ignorado — se retiró) | BORRAR paréntesis; "señal de desvío: el usuario tuvo que pedirte…" es INCIDENTE leve, reescribir como señal objetiva |
| norms:176 | FECHA,INCIDENTE | (overhaul hooks 2026-09-18: `delegacion-reporte` … se retiró; esta viñeta ES su mecanismo ahora) | BORRAR paréntesis |
| norms:182 | FECHA,INCIDENTE | El **modo de falla se INVIRTIÓ** … antes el riesgo era actualizar SOLO el HUD …; hoy es al revés | REESCRIBIR en presente: "Riesgo actual: actualizar solo estado-proyecto.md y olvidar el HUD" |
| norms:183 | FECHA,INCIDENTE | (overhaul hooks 2026-09-18: `hud-stale` … medido: ignorado — se retiró) | BORRAR paréntesis |
| norms:23-83 varios | DRAMA leve | mayúsculas de énfasis recurrentes (SOLO, NUNCA, JAMÁS, DURA) y "Corolario grave" (l.77) | opcional: reducir énfasis; no es infracción dura |

Sin CITA ni NOMBRE PROPIO en norms (grep de `[user`, unjordi, Jordi: 0). 8 líneas con infracción de FECHA/INCIDENTE, todas del mismo patrón "overhaul hooks 2026-09-18 … medido: ignorado — se retiró".

## Archivos LIMPIOS (0 hits y 0 bloques largos)
- hooks/delegacion-comun.sh
- hooks/detectar-secretos.sh
- hooks/limite-gasto.sh
- lib/detectar-shells.sh
- proteger-ramas.sh
- scripts/auditor-semantico/checks/03-dapper-dateonly-handler.sh
- scripts/auditor-semantico/lib-formato.sh

---

# Auditoria utilitario - resto (bin, src, macos, windows, scripts, instaladores, test-brain)

Archivos revisados: 87 (lista en git ls-files, excl. svg/png/lock). Lineas marcadas (candidatas, 1 linea puede tener varias categorias): 606.

Tamano: brain/test-brain.sh = 9300 lineas / 786 KB (revisado por regex de candidatos + contexto; 1986 lineas son comentarios). Los hallazgos de ese archivo son masivos y de patron repetido.

## Infracciones por categoria (lineas)

- FECHA/TRAZA: 471
- INCIDENTE: 67
- NOMBRE PROPIO: 65
- DRAMA: 51
- CITA: 20
- DECORACION: 10

## Top 10 archivos mas cargados

- brain/test-brain.sh: 440
- bin/checkpoint-mecanico.js: 24
- macos/install.sh: 15
- install.sh: 12
- src/plasmoid/contents/ui/main.qml: 12
- src/term-broker/PROCEDENCIA.md: 12
- src/term-broker/term-host-broker.ts: 9
- windows/src/Cortex/PopupForm.cs: 9
- windows/install.ps1: 8
- macos/Sources/Cortex/PopoverView.swift: 7

Criterio: se descartan identificadores (io.github.unjordi.*, URLs github.com/unjordi/*, slugs). Una linea de comentario continuacion sin marcador no se lista, pero pertenece al mismo bloque narrativo. Propuesta por defecto: REESCRIBIR a la regla en presente (que hace / que garantiza) y MOVER fecha/hallazgo/cita a bitacora o docs/guards-falsos-positivos.md; BORRAR si el comentario solo narra.

Falsos positivos descartados a mano: oauth-2025-04-20 (header de API), 2026-06-10T... (ejemplo de formato). Notas manuales: las descripciones de piezas del cerebro (detail/desc de BrainItem en main.qml, PopoverView.swift y PopupForm.cs, lineas citadas) son MENSAJES al usuario con fecha (2026-09-17, 2026-09-18) e incidente ("Antidoto a un caso real: un agente de fan-out reseteo HEAD..."); viven triplicadas (QML/Swift/C#). En test-brain.sh el patron dominante son comentarios "auditoria/FMEA/Dictamen + fecha", "MEDIDO" y "overhaul hooks 2026-09-18" encabezando bloques de tests, ademas de nombres de test con ids (#42). Los identificadores io.github.unjordi.* y URLs github.com/unjordi/* NO se cuentan.

## Hallazgos por archivo

### brain/test-brain.sh (440)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 23 | FECHA/TRAZA,DRAMA | # CONTADOR inmune a subshells (auditoría 2026-09-15, Hallazgo #0, CRÍTICO): docenas de bloques de este | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 26 | INCIDENTE | # padre nunca se entera. MEDIDO por canario: `PASS=0; ok(){ PASS=$((PASS+1));}; ( ok;ok;ok ); echo $PASS` | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 91 | FECHA/TRAZA | # BAJO (auditoría FMEA 2026-09-16 §1.6, INVESTIGADO): el arnés construía sus PATHs restringidos ("sin jq") | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 137 | FECHA/TRAZA | # #42: el tool de subagentes se renombró Task→Agent. El gate DEBE disparar con AMBOS nombres, | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 218 | FECHA/TRAZA | # y ramas personales/ramitas → libres. B3 (FMEA 2026-07-30): destino IRRESOLUBLE (timeout/red) → fail-safe | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 223 | FECHA/TRAZA | # CONSOLIDACIÓN 2026-09-17: merge-develop-guard es UN solo guard (squash + autorización). Los checks de | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 254 | FECHA/TRAZA | # M4 (auditoría 2026-09-15 §3.4, costura): destino IRRESOLUBLE + el COMANDO no menciona release/main, pero | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 268 | FECHA/TRAZA | # H-R9-01 (FMEA r9): el binario Windows `glab.exe`/`gh.exe` rompía el gate `acg_es_merge_mr` → ambos guards | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 274 | FECHA/TRAZA | # Cobertura NUEVA (auditoría externa del arnés, 2026-09-15): git-branch-guard y entorno-maquina-guard ya | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 286 | FECHA/TRAZA | # H6 (auditoría semántica 2026-09-16, MEDIO, CONFIRMADO): SQUASH_RE corría sobre $cmd RAW, sin pasar por | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 301 | FECHA/TRAZA | # H4 (auditoría de ejecución 2026-09-16, MEDIO, CONFIRMADO): el fail-safe de destino IRRESOLUBLE usaba | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 313 | INCIDENTE | is_deny "$out" && ok "H4: release-de-OTRO-PR (390) en la ventana → el merge del 391 SIGUE exigiendo squash (antes: se colaba)" \ | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 352 | FECHA/TRAZA | # ── MULTILÍNEA INLINE (fix #42/#46): un --squash-message con SALTOS DE LÍNEA reales y SUSTANCIA ya NO se | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 356 | FECHA/TRAZA | && ok "msg LITERAL multilínea (#42/#46): resumen inline con saltos de línea + sustancia + traza → pasa (sin FP)" \|\| bad "msg LITERAL multilínea: bloqu | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 367 | FECHA/TRAZA | is_silent "$(msj 'gh pr merge 56 --squash --delete-branch --subject "agrega validacion de stock disponible antes de confirmar el pedido para evitar so | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 371 | FECHA/TRAZA | # M8 (auditoría 2026-09-15 §3.9): con gh, --subject fija el TÍTULO; la convención pone el RESUMEN CURADO en | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 431 | FECHA/TRAZA | # Dictamen higiene de ramas 2026-09-17, A-2: nadie hacía cumplir el borrado de la rama de origen. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 471 | FECHA/TRAZA | printf 'corrige el calculo del impuesto al valor agregado en las facturas del periodo fiscal vigente\n\nRama: fix/iva-facturas\nPR: #71\n' > "$A3DIR/c | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 521 | FECHA/TRAZA | acg_msg_falta_traza "corrige el checkout #12" && bad "acg_msg_falta_traza: FP, sí traía id de PR" \|\| ok "acg_msg_falta_traza: id de PR (#12) → trae tr | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 523 | FECHA/TRAZA | # H8 (auditoría semántica 2026-09-16, BAJO, CONFIRMADO): el set de prefijos era angosto (solo | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 557 | FECHA/TRAZA | # M8 (auditoría 2026-09-15 §3.11, norma dura anti-vein-popper): el mensaje de bloqueo YA NO ofrece "hazlo en | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 568 | FECHA/TRAZA,INCIDENTE | # A2 (FMEA 2026-07-30): el FORCE-REFSPEC `+develop` (el `+` fuerza el push) se colaba porque el set de | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 576 | FECHA/TRAZA | # ── wave4 (FMEA post-integración 2026-07-30): evasiones de git-branch-guard CERRADAS. Parado en feat/x | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 585 | FECHA/TRAZA | # N-01 (FMEA ronda 2): refspec ENTRECOMILLADO con la base a la DERECHA del ':' (residuo del raw-check de A-01). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 589 | FECHA/TRAZA | # A-R3-01 (FMEA ronda 3): un push a base ENCADENADO como 2º (o Nº) subcomando. El reescrito de N-01 usaba | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 590 | INCIDENTE | # `head -1` → solo miraba el PRIMER `git push …` → un `git push feat/x ; git push develop` se colaba por el 2º. | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 597 | FECHA/TRAZA | # A-R4-01 (FMEA ronda 4): git acepta MUCHAS opciones globales entre `git` y su subcomando (no solo -c/-C). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 606 | FECHA/TRAZA | # A-R5-01 (FMEA ronda 5): el VALOR de un value-eater puede ir ENTRECOMILLADO con ESPACIOS (rutas de Google | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 613 | FECHA/TRAZA | # A-R6-01 (FMEA ronda 6): la comilla puede ir EN MEDIO del valor (`git -c user.name="a b" push …` — | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 621 | FECHA/TRAZA | # A-R7-01 (FMEA ronda 7): el espacio del valor puede ir ESCAPADO CON BACKSLASH (`git -c a=b\ c push …` — el | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 628 | FECHA/TRAZA | # B4 (FMEA ronda 8): en Windows el binario es `git.exe`; rompía el `git`+espacio que exigen los detectores | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 649 | FECHA/TRAZA | # Raíz común de los FN/FP cross-repo (auditoría 2026-08-06): los guards keyeaban la rama/marca desde | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 689 | FECHA/TRAZA | # G7 (FP corpus L109, 2026-09-03 ×2): un compuesto que CAMBIA de rama antes del push pelón se resolvía | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 717 | FECHA/TRAZA | # ── (b1d-lib) acg_expande_home: el `~`/`$HOME` INICIAL se resuelve (REGRESIÓN del FP 2026-09-08) ── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 727 | FECHA/TRAZA | \|\| bad "target_dir: el ~ de cd NO se expandió (FP 2026-09-08 vivo)" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 745 | FECHA/TRAZA | # ── (b1d-lib) acg_mrid: multi-comando aísla el SEGMENTO del ÚLTIMO merge (fix 2026-08, DETERMINISTA) ── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 759 | FECHA/TRAZA | # ── (b1d-lib) acg_destino_de_mr consulta la base EN EL DIR OBJETIVO (REGRESIÓN del FP 2026-09-08 MR 87) ── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 794 | FECHA/TRAZA | echo "== (b1d-m1) M1 (auditoría 2026-09-15): segmentación ejecutor-aware — eval/bash -c/heredoc ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 795 | DRAMA | # CRÍTICO §2.2/§3.2: acg_despoja_comillas trataba TODO span entrecomillado como dato inerte → un | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 838 | FECHA/TRAZA,DRAMA | echo "== (b1d-m2) M2 (auditoría 2026-09-15, CRÍTICO §3.1/§2.4): secret-scan y proteger-arbol dejan de ser ciegos cross-repo ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 857 | FECHA/TRAZA | # Cobertura NUEVA (auditoría externa del arnés, 2026-09-15): m2scan (arriba) nunca varía CLAUDE_PROJECT_DIR | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 874 | FECHA/TRAZA,DRAMA | echo "== (b1d-critico1) CRÍTICO-1 (auditoría FMEA 2026-09-16 §1.1, CONFIRMADO): un error de SINTAXIS en la" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 889 | DRAMA | && bad "CRÍTICO-1 (setup): la inyección de sintaxis no rompió la lib — el test no prueba nada" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 890 | DRAMA | \|\| ok "CRÍTICO-1 (setup): lib con error de sintaxis REAL confirmada (bash -n falla) — arranca la prueba" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 893 | DRAMA | && ok "CRÍTICO-1: lib ROTA + git-branch-guard + push a develop → DENY ruidoso (antes: exit=1 silencioso, el push PASABA)" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 894 | DRAMA | \|\| bad "CRÍTICO-1: REGRESIÓN — git-branch-guard con lib rota dejó pasar un push a develop en silencio" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 896 | DRAMA | && ok "CRÍTICO-1: lib ROTA + merge-develop-guard + merge sin squash/OK → DENY ruidoso (candado consolidado)" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 897 | DRAMA | \|\| bad "CRÍTICO-1: REGRESIÓN — merge-develop-guard con lib rota dejó pasar un merge en silencio" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 902 | DRAMA | && ok "CRÍTICO-1: lib ROTA + secret-scan + secreto en staging → DEGRADA a su fallback sed y SIGUE atrapando el secreto (antes: exit=1 silencioso, sin  | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 903 | DRAMA | \|\| bad "CRÍTICO-1: REGRESIÓN — secret-scan con lib rota dejó pasar un secreto (backstop de emergencia falló)" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 912 | DRAMA | && ok "CRÍTICO-1: lib ROTA + proteger-arbol + reset destructivo con commit sin pushear → DEGRADA a su fallback heredoc-ciego y SIGUE avisando (antes:  | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 913 | DRAMA | \|\| bad "CRÍTICO-1: REGRESIÓN — proteger-arbol con lib rota dejó de avisar sobre un reset destructivo real" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 917 | DRAMA | && ok "CRÍTICO-1 (control, lib sana): git-branch-guard sigue bloqueando un push a develop normalmente" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 918 | DRAMA | \|\| bad "CRÍTICO-1 (control): REGRESIÓN — con la lib intacta, git-branch-guard dejó de bloquear" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 919 | FECHA/TRAZA | # H7 (auditoría semántica 2026-09-16, BAJO, CONFIRMADO): la sonda ORIGINAL (subshell + exit code) confundía | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 938 | FECHA/TRAZA | echo "== (b1d-m9) M9 (auditoría 2026-09-15 §2.5): --repo \"\$VAR\" es OPACO, no OTRO repo ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 946 | FECHA/TRAZA | # cualquier profundidad de subshell — auditoría 2026-09-15, Hallazgo #0. Este bloque sigue sin usar | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 966 | FECHA/TRAZA | echo "== (b1d-h2exec) H2 (auditoría de ejecución 2026-09-16, MEDIO, CONFIRMADO): destino de PUSH opaco (\$VAR) GATEA, simétrico a M9 ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 992 | FECHA/TRAZA | echo "== (b1d-medio) MEDIO/H3-semántico (auditoría FMEA 2026-09-16 §1.5 + auditoría semántica H3): CACHE-DE-CREACION" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 995 | FECHA/TRAZA | # la lib — ver bloque H1exec abajo). Además, H3 (auditoría semántica 2026-09-16): "hoy no hay escritor | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1015 | FECHA/TRAZA | # (b1d-stat) acg__cache_confiable: GNU `stat -c` PRIMERO — CI ubuntu rojo (2026-10-13). En GNU, `stat -f` | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1076 | FECHA/TRAZA | echo "== (b1d-h1exec) H1 (auditoría de ejecución 2026-09-16, ALTO, CONFIRMADO): el caché REGULAR de destino" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1078 | DRAMA,NOMBRE PROPIO | # Bypass TOTAL medido: un archivo plantado con destino 'DevelopUnjordi' y perm 0666 se servía como si fuera | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1087 | CITA,NOMBRE PROPIO | printf 'DevelopUnjordi\nAPI\n' > "$H1EROOT/acg-mrdest-${key}" | BORRAR la cita; dejar solo el contrato |
| 1090 | NOMBRE PROPIO | case "$out" in *DevelopUnjordi*) echo BAD ;; *) echo GOOD ;; esac | REESCRIBIR a termino generico (usuario/maquina/host) |
| 1092 | NOMBRE PROPIO | && ok "H1exec: caché plantado (perm 0666) con destino 'DevelopUnjordi' → IGNORADO (antes: bypass total del gate)" \ | REESCRIBIR a termino generico (usuario/maquina/host) |
| 1108 | FECHA/TRAZA | # TTL: un caché VIEJO (mtime de 2020), aunque tenga permisos correctos, ya NO se sirve — antes era eterno | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1142 | FECHA/TRAZA | echo "== (b1d-m7) M7 (auditoría 2026-09-15 §2.3): entorno degradado (sin jq) homologado — fail-CLOSED ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1145 | FECHA/TRAZA | # el jq ausente → exit 0). confirmar-merge-develop YA tenía el endurecimiento A3 (2026-08-06): esta es la | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1150 | FECHA/TRAZA | # H1 (auditoría semántica 2026-09-16): git-branch-guard SIN jq ahora reusa acg_push_toca_base de verdad (con | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1178 | FECHA/TRAZA | echo "== (b1d-alto2) ALTO-2 (auditoría FMEA 2026-09-16 §1.4, CONFIRMADO): SIN jq, git-branch-guard ya NO" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1180 | INCIDENTE | # Medido por la propia auditoría: ANTES de este fix, SIN jq, `git push -u origin feat/mi-cambio` (push a tu | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 1187 | NOMBRE PROPIO | is_silent "$(gb_nojq 'git push origin DevelopUnjordi')" \ | REESCRIBIR a termino generico (usuario/maquina/host) |
| 1188 | NOMBRE PROPIO | && ok "ALTO-2: SIN jq, push a TU mini-develop personal (DevelopUnjordi) → silencio" \ | REESCRIBIR a termino generico (usuario/maquina/host) |
| 1196 | FECHA/TRAZA | # H1 (auditoría semántica 2026-09-16): el rediseño reusa acg_merge_menciona_base para PARIDAD exacta con | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1227 | FECHA/TRAZA | echo "== (b1d-h1) H1 (auditoría semántica 2026-09-16, ALTO, CONFIRMADO): SIN jq, git-branch-guard razona" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1229 | INCIDENTE | # Medido por la auditoría: el fixture ORIGINAL de b1d-alto2 (arriba) construye el payload SIN 'description' — | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 1251 | FECHA/TRAZA | echo "== (b1d-h5exec) H5 (auditoría de ejecución 2026-09-16, BAJO-MEDIO, CONFIRMADO): siembra de repo/rama" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1295 | FECHA/TRAZA | # CONSOLIDACIÓN 2026-09-17: merge-develop-guard corre el check de SQUASH ANTES del juez. Para ejercitar el | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1311 | FECHA/TRAZA | # CONSOLIDACIÓN: el MISMO merge SIN --squash → frena en el check de squash ANTES del juez (fail-fast). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1391 | FECHA/TRAZA | # mentiría). Con el augment activo (default), este mismo caso RESUELVE por API — es justo el fix del #78. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1398 | FECHA/TRAZA | # dir canónico (ROOT CAUSE del #78: launch-GUI + minimal launchd PATH). ACG_EXTRA_BIN inyecta un dir con | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1406 | FECHA/TRAZA | # lo halla → destino RESUELVE a develop (antes: vacío → fail-safe frenaba el merge legítimo del #78). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1409 | FECHA/TRAZA | && ok "PATH-augment (#78): glab en ACG_EXTRA_BIN (no en PATH) → destino RESUELVE a develop (rescate launch-GUI)" \|\| bad "PATH-augment (#78): el augmen | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1433 | FECHA/TRAZA | # El jq de interleave es el código NUEVO riesgoso del fix "el juez lee MIS turnos" (2026-08-02): si se rompe, | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1440 | FECHA/TRAZA | {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"¿Mergeo el #240 a develop?"},{"type":"tool_use","name":"Bash","inp | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1444 | FECHA/TRAZA | {"type":"user","message":{"role":"user","content":"sí, arranca con #240"}} | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1447 | FECHA/TRAZA | EXP=$'USUARIO: hola, arranca\nASISTENTE: ¿Mergeo el #240 a develop? \nUSUARIO: sí, arranca con #240' | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1483 | FECHA/TRAZA | # ── REGRESIÓN del FP 2026-09-08 (clase "PR19"): el OK que el usuario manda MID-TURN no queda como turno | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1534 | FECHA/TRAZA | # SOBRE-MATCH del léxico (auditoría 2026-08): 'liber'/'a main' NO deben casar dentro de otras palabras. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1543 | FECHA/TRAZA | # Residual del anclaje de UN solo lado (auditoría 2026-08, ronda 2): frontera en AMBOS lados. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1550 | FECHA/TRAZA | # FN de la rama promov con .* desacoplado (auditoría 2026-08, ronda 3): 'promueve' + 'main' suelto de otra frase. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1562 | FECHA/TRAZA,DRAMA | # M5 (auditoría 2026-09-15 §3.5, 🔴 APRIETA): destino VACÍO/DESCONOCIDO (consulta caída por PATH/red/ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1572 | FECHA/TRAZA | # M5-bis (auditoría FMEA 2026-09-16 §1.2, ALTO, PRECISIÓN — no relaja el piso): M5 (arriba) bloqueaba | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1591 | FECHA/TRAZA | # ── VETO DE CITA VERIFICADA + PARSEO POR CENTINELA (capa 1+2, DETERMINISTA sin red) · juez EMPODERADO 2026-08 ── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1633 | FECHA/TRAZA | # ── VETO ROBUSTO (fix veto-cita 2026-08): tolera normalización BENIGNA del LLM (typo/acento/caso), sigue | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1635 | FECHA/TRAZA | # "corrige" a "pendientes" al copiar la CITA → el viejo grep -Fq byte-exacto → falso DENY (#272/#273). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1748 | FECHA/TRAZA | # M8 (auditoría 2026-09-15 §3.11, norma dura anti-vein-popper): YA NO redirige a la web de GitLab (retirado | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1782 | DRAMA | # Activado por CLAUDE_JUEZ_LOCAL_MODEL. Sin la env → default Anthropic INTACTO. El punto CRÍTICO: Ollama | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1813 | DRAMA | # (b) unidad — local CAÍDO (CRÍTICO): Ollama no responde → UNAVAILABLE_NET + txt VACÍO + rc!=0 (fail preservado). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1849 | FECHA/TRAZA | # ── LEVER opt-in de VOTO MÚLTIPLE (self-consistency), DETERMINISTA sin red · juez EMPODERADO 2026-08 ── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1900 | FECHA/TRAZA | printf '%s' "$(acg_hint_candidatos "$HA1" main 261)" \| grep -q 'SOLO #261' && ok "hint: 1 candidato hacia main → 'SOLO #261' (INEQUÍVOCO)" \|\| bad "hin | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1902 | FECHA/TRAZA | printf '%s' "$(acg_hint_candidatos "$HA1" '' 261)" \| grep -q 'SOLO #261' && ok "hint: destino VACÍO resuelto por baseRefName del propio MR → 'SOLO #26 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1938 | FECHA/TRAZA | # CONSOLIDACIÓN 2026-09-17: el mock de glab resuelve develop → el check de SQUASH exige --remove-source-branch | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1991 | FECHA/TRAZA | "ASISTENTE: Verifiqué el PR #240, está verde (466 PASS). ¿Arranco mergeando #240 a develop? | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1992 | FECHA/TRAZA | USUARIO: sí, arranca con #240 y tráeme las 3 decisiones" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1994 | FECHA/TRAZA | "ASISTENTE: El #235 es el canónico de la firma. ¿Lo mergeo a develop? | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2001 | FECHA/TRAZA | "ASISTENTE: Dejé listo el PR #241 con los flowcharts limpios. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2004 | FECHA/TRAZA | "ASISTENTE: ¿Mergeo el #240 a develop? | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2009 | FECHA/TRAZA | ASISTENTE: Suite verde. Procedo con el merge del #237." | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2012 | FECHA/TRAZA | ASISTENTE: Suite verde (487 PASS). La condición se cumplió, procedo con el #240." | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2013 | FECHA/TRAZA | # FN 2026-08-04: el OK se dio ANTES de crear el MR → imposible citar el número que aún no existía. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2016 | FECHA/TRAZA | ASISTENTE: ¡Va! Creo y mergeo el MR a develop. Created PR #250 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2017 | FECHA/TRAZA | ASISTENTE: PR #250 creado. Lo mergeo con squash." | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2023 | FECHA/TRAZA | "ASISTENTE: El usuario ya autorizó este merge antes, procedo a mergear el #240 a develop. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2030 | FECHA/TRAZA | "ASISTENTE: ¿Mergeo el #240 a develop? | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2033 | FECHA/TRAZA | "ASISTENTE: ¿Integro el #240? | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2045 | FECHA/TRAZA | ASISTENTE: Listo, #240 mergeado. Queda el #237 pendiente del throttle. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2048 | INCIDENTE | # con el fail SEGURO (ante duda + lenguaje de release → trata como MAIN). Es el caso real que destapó | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 2051 | FECHA/TRAZA | "ASISTENTE: Abrí el release #261 (develop→main) con el #46. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2056 | FECHA/TRAZA | "ASISTENTE: ¿Hago el release a main del #261? | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2062 | FECHA/TRAZA,INCIDENTE | # FN-A: el FN VIVIDO ("release a main de todo esto") — hint dice SOLO #261 → resuelve "todo esto"=#261. | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 2063 | FECHA/TRAZA | jlive "FN-A 'release a main de todo esto' (hint SOLO #261)" main 261 ALLOW \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2065 | FECHA/TRAZA | ASISTENTE: Terminó la dupla de auditores; abrí el release #261 (develop→main) y todo quedó verde. Procedo con el release #261 a main." "$H_MAIN1" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2066 | FECHA/TRAZA | jlive "FN-A 'libera, dale con todo de corrido' (hint SOLO #261)" main 261 ALLOW \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2067 | FECHA/TRAZA | "ASISTENTE: El release #261 (develop→main) está listo para liberar. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2069 | FECHA/TRAZA | # FN-B: 'release' palabra suelta tras propuesta del asistente (hint SOLO #261). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2070 | FECHA/TRAZA | jlive "FN-B 'release' suelto tras propuesta (hint SOLO #261)" main 261 ALLOW \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2071 | FECHA/TRAZA | "ASISTENTE: Cerré el slice a develop. Lo que queda (tu decisión): ¿hago el release #261 a main? | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2075 | FECHA/TRAZA | "ASISTENTE: ¿Mergeo el #240 (feat notif) a develop? | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2079 | FECHA/TRAZA | "ASISTENTE: ¿Integro el #240 a develop? Aún queda pendiente el release a main. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2084 | FECHA/TRAZA | "ASISTENTE: El release #261 (develop→main) está armado. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2087 | FECHA/TRAZA | "ASISTENTE: ¿Libero el release #261 a main? | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2090 | FECHA/TRAZA | "ASISTENTE: El release #261 está listo. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2093 | FECHA/TRAZA | "ASISTENTE: El release #261 (develop→main) está armado. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2096 | FECHA/TRAZA | "ASISTENTE: El #240 (feat notif) está verde. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2102 | FECHA/TRAZA | # M8 (auditoría 2026-09-15 §3.10/§4.2, sobre M3): destino DESCONOCIDO por fallo de ENTORNO (ni gh ni glab | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2114 | FECHA/TRAZA | # CONSOLIDACIÓN 2026-09-17: sin gh/glab en el PATH el destino queda SIN-RESOLVER (nunca "develop"), así que | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2129 | FECHA/TRAZA,INCIDENTE | # cubre scope=merge-develop. Caso real 2026-07-12: un OK blanket murió al compactarse el contexto. | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 2135 | FECHA/TRAZA | # CONSOLIDACIÓN 2026-09-17 (mismo motivo que CMOK arriba en (b1e)): destino=develop confirmado hace que el | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2141 | FECHA/TRAZA | printf -- '- scope=merge-develop vence_epoch=%s vence="mañana 10am" cita="autorizo todos los merges a develop hasta mañana 10am" registrada=2026-07-18 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2146 | FECHA/TRAZA | printf -- '- scope=merge-develop vence_epoch=%s vence="ayer" cita="autorizo hasta ayer" registrada=2026-07-17\n' "$(( $(date +%s) - 60 ))" > "$AUTHF" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2167 | FECHA/TRAZA,DRAMA | # (6) CRÍTICO-3 (auditoría FMEA 2026-09-16 §1.3, CONFIRMADO por A/B contra develop): M6 (auditoría | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2168 | FECHA/TRAZA | # 2026-09-15 §3.6) había AMPLIADO el fast-path del grant a destino DESCONOCIDO con la cerca "sin léxico | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2179 | DRAMA | && ok "CRÍTICO-3 (post-fix): grant vigente + destino DESCONOCIDO + juez DENY → deny (el grant YA NO salta el juez con destino sin confirmar)" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2180 | DRAMA | \|\| bad "CRÍTICO-3: REGRESIÓN — el grant sigue saltándose el juez con destino desconocido (el hueco de seguridad volvió)" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2182 | DRAMA | && ok "CRÍTICO-3 (post-fix): grant vigente + destino DESCONOCIDO + juez UNAVAILABLE (red caída, escenario real de turno-nocturno) → deny, fail-safe" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2183 | DRAMA | \|\| bad "CRÍTICO-3: REGRESIÓN — con el juez inalcanzable el grant coló el merge de todos modos" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2187 | DRAMA | && ok "CRÍTICO-3: grant vigente + destino DESCONOCIDO + CON léxico de release → decide el juez (freno, sin cambio)" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2188 | DRAMA | \|\| bad "CRÍTICO-3: el grant coló un posible release a main con destino desconocido" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2193 | DRAMA | && ok "CRÍTICO-3: regresión — grant vigente + destino CONFIRMADO develop → SIGUE pasando por el fast-path (no se tocó la parte segura de M6)" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2194 | DRAMA | \|\| bad "CRÍTICO-3: REGRESIÓN — el fast-path seguro (destino=develop confirmado) se rompió al cerrar el hueco" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2197 | FECHA/TRAZA | # H3 (auditoría de ejecución 2026-09-16, MEDIO, CONFIRMADO): acg_recent_intercalado lee `tail -n 6000` del | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2252 | FECHA/TRAZA | # Cobertura NUEVA (auditoría externa del arnés, 2026-09-15): git-branch-guard/entorno-maquina-guard/ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2267 | CITA,FECHA/TRAZA,INCIDENTE,NOMBRE PROPIO | # add se colaba y su secreto entraba. Cerrado 2026-09-08 (OK de unjordi). | BORRAR la cita; dejar solo el contrato |
| 2334 | FECHA/TRAZA | # ── FMEA 2026-07-30 · A1 (idiom `git add && git commit`) + A7 (`--no-verify` en el MENSAJE) ── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2336 | FECHA/TRAZA | echo "== (b2c) secret-scan FMEA A1/A7: idiom 'git add && git commit' y --no-verify citado en el mensaje ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2337 | FECHA/TRAZA | FMEAREPO="$(mktemp -d "${TMPDIR:-/tmp}/brain-fmea.XXXXXX")" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2338 | FECHA/TRAZA | git -C "$FMEAREPO" init -q >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2339 | FECHA/TRAZA | git -C "$FMEAREPO" symbolic-ref HEAD refs/heads/main >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2340 | FECHA/TRAZA | git -C "$FMEAREPO" config user.email t@t >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2341 | FECHA/TRAZA | git -C "$FMEAREPO" config user.name tester >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2342 | FECHA/TRAZA | printf 'base limpia\n' > "$FMEAREPO/base.txt"; git -C "$FMEAREPO" add base.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm base >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2345 | FECHA/TRAZA | \| HOME="$FMEAREPO" CLAUDE_PROJECT_DIR="$FMEAREPO" bash "$HOOKS/secret-scan.sh"; } | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2346 | FECHA/TRAZA | fmeareset() { git -C "$FMEAREPO" reset -q >/dev/null 2>&1; rm -f "$FMEAREPO"/*.txt 2>/dev/null; } | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2348 | FECHA/TRAZA | fmeareset; printf 'aws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/secreto.txt" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2352 | FECHA/TRAZA | fmeareset; printf 'tok = sk-ant-abcdefghijklmnopqrstuvwxyz0123\n' > "$FMEAREPO/tok.txt" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2356 | FECHA/TRAZA | fmeareset; printf 'contenido sin secretos\n' > "$FMEAREPO/limpio.txt" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2361 | FECHA/TRAZA | fmeareset; printf 'aws = AKIA1234567890ABCDEF\nlinea normal\n' > "$FMEAREPO/pre.txt" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2362 | FECHA/TRAZA | git -C "$FMEAREPO" add pre.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm pre >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2363 | FECHA/TRAZA | printf 'aws = AKIA1234567890ABCDEF\nlinea CAMBIADA\n' > "$FMEAREPO/pre.txt" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2367 | FECHA/TRAZA | fmeareset; printf 'aws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/s2.txt"; git -C "$FMEAREPO" add s2.txt >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2372 | FECHA/TRAZA | fmeareset; printf 'linea limpia\n' > "$FMEAREPO/t.txt"; git -C "$FMEAREPO" add t.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm t >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2373 | FECHA/TRAZA | printf 'linea limpia\naws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/t.txt" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2377 | FECHA/TRAZA | fmeareset; printf 'v1\n' > "$FMEAREPO/u.txt"; git -C "$FMEAREPO" add u.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm u >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2378 | FECHA/TRAZA | printf 'v1\nv2 sin secretos\n' > "$FMEAREPO/u.txt" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2382 | FECHA/TRAZA | fmeareset; printf 'aws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/s3.txt"; git -C "$FMEAREPO" add s3.txt >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2388 | FECHA/TRAZA | # A-03 (FMEA post-integración): el prefijo `git -c k=v … commit` ya NO ciega el escaneo (antes rompía la | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2390 | FECHA/TRAZA | fmeareset; printf 'v\n' > "$FMEAREPO/gc.txt"; git -C "$FMEAREPO" add gc.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm gc >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2391 | FECHA/TRAZA | printf 'v\naws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/gc.txt" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2394 | FECHA/TRAZA | # A-R4-02 (FMEA r4): las OTRAS opciones globales de git (≠ -c/-C) también rompían la adyacencia git+commit | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2396 | FECHA/TRAZA | fmeareset; printf 'v\n' > "$FMEAREPO/g2.txt"; git -C "$FMEAREPO" add g2.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm g2 >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2397 | FECHA/TRAZA | printf 'v\naws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/g2.txt" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2401 | FECHA/TRAZA | # A-R5-02 (FMEA r5): con el despoje ANTES de normalizar, un value-eater con valor ENTRECOMILLADO | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2404 | FECHA/TRAZA | # M2 (auditoría 2026-09-15): desde que secret-scan HONRA -C para resolver el dir objetivo (antes siempre | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2406 | FECHA/TRAZA | # ahora fail-abre correctamente sobre un dir irresoluble) — se usa FMEAREPO (con un subdir CON espacio para | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2408 | FECHA/TRAZA | fmeareset; printf 'v\n' > "$FMEAREPO/g3.txt"; git -C "$FMEAREPO" add g3.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm g3 >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2409 | FECHA/TRAZA | printf 'v\naws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/g3.txt" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2410 | FECHA/TRAZA | mkdir -p "$FMEAREPO/a b" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2411 | FECHA/TRAZA | printf '%s' "$(scanf "git -C \"$FMEAREPO\" commit -am x")" \| grep -q '"deny"' && ok "secret-scan A-R5-02: 'git -C \"\$repo\" commit -am' (valor entrec | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2412 | FECHA/TRAZA | printf '%s' "$(scanf "git -C \"$FMEAREPO/a b\" commit -am x")" \| grep -q '"deny"' && ok "secret-scan A-R5-02: 'git -C \"\$repo/a b\"' (valor entrecomi | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2413 | FECHA/TRAZA | printf '%s' "$(scanf "git --work-tree=\"$FMEAREPO/a b\" commit -am x")" \| grep -q '"deny"' && ok "secret-scan A-R5-02: 'git --work-tree=\"\$repo/a b\" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2414 | FECHA/TRAZA | # A-R6-01 (FMEA r6): comilla EN MEDIO del valor de un global (`git -c user.name="a b" commit`) → mismo | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2416 | FECHA/TRAZA | fmeareset; printf 'v\n' > "$FMEAREPO/g4.txt"; git -C "$FMEAREPO" add g4.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm g4 >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2417 | FECHA/TRAZA | printf 'v\naws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/g4.txt" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2419 | FECHA/TRAZA | # A-R7-01 (FMEA r7): espacio escapado con backslash en el valor global → mismo mecanismo, mismo fix. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2420 | FECHA/TRAZA | fmeareset; printf 'v\n' > "$FMEAREPO/g5.txt"; git -C "$FMEAREPO" add g5.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm g5 >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2421 | FECHA/TRAZA | printf 'v\naws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/g5.txt" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2423 | FECHA/TRAZA | # B4 (FMEA r8): el binario Windows `git.exe commit` rompía el gate git+commit del escaneo → mismo fix (colapso git.exe→git). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2424 | FECHA/TRAZA | fmeareset; printf 'v\n' > "$FMEAREPO/g6.txt"; git -C "$FMEAREPO" add g6.txt >/dev/null 2>&1; git -C "$FMEAREPO" commit -qm g6 >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2425 | FECHA/TRAZA | printf 'v\naws = AKIA1234567890ABCDEF\n' > "$FMEAREPO/g6.txt" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2427 | FECHA/TRAZA | rm -rf "$FMEAREPO" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2431 | FECHA/TRAZA | echo "== (b2d) secret-scan DEFECTO #4 (auditoría overhead 2026-09-16): deja de escalar con el Nº de archivos ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2433 | INCIDENTE | # tocados; medido en producción: 600s de TIMEOUT con un commit de 105 archivos (`git add -A` + commit | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 2437 | INCIDENTE | # Oráculo (bastante más grande que el caso real de 105, para ver margen): un commit de N archivos con un | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 2443 | INCIDENTE | # Contra el código de HOY (bucle por archivo) el assert de tiempo FALLA: medido en esta máquina, N=400 | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 2463 | FECHA/TRAZA | && ok "secret-scan DEFECTO #4: secreto ESCONDIDO en el archivo #100 de $N4 → sigue bloqueando Y en ${dur_defecto4}s (acotado, no escala con N)" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2524 | FECHA/TRAZA | # M1 (auditoría 2026-09-15 §2.1): el despoje-a-mano se unificó con la lib compartida — un `bash -c "git | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2798 | FECHA/TRAZA | # A-1 (auditoría 2026-09-11): keep/respaldo y feat/en-wt NUNCA deben tratarse como candidatas a | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2846 | FECHA/TRAZA | # Dictamen higiene de ramas 2026-09-17, C-2: el bucle recorría SOLO `refs/heads`, así que una rama viva en | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2849 | INCIDENTE | # entrada al código. Medido en el repo real: 12 de las 23 ramas de origin eran exactamente de esa clase | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 2934 | CITA,FECHA/TRAZA | # Queja real (2026-09): "qué pasa con lo que deja detrás... no todo eran ramas con worktree". Un fan-out | BORRAR la cita; dejar solo el contrato |
| 3007 | FECHA/TRAZA | # Dictamen higiene de ramas 2026-09-17, A-4: recorriendo el ciclo actor por actor, dos transiciones no las | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3069 | FECHA/TRAZA,INCIDENTE,NOMBRE PROPIO | # Bug real (2026-07-28): en un repo con flujo mini-develop (rama personal DevelopUnjordi sacada de develop), | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 3077 | NOMBRE PROPIO | git -C "$RBREPO" branch DevelopUnjordi >/dev/null 2>&1 # mini-develop sacada de develop | REESCRIBIR a termino generico (usuario/maquina/host) |
| 3079 | NOMBRE PROPIO | # (1) HEAD en una ramita, con develop Y DevelopUnjordi locales → base = la MINI (no develop) | REESCRIBIR a termino generico (usuario/maquina/host) |
| 3080 | NOMBRE PROPIO | git -C "$RBREPO" checkout -q -b feat/x DevelopUnjordi >/dev/null 2>&1 | REESCRIBIR a termino generico (usuario/maquina/host) |
| 3081 | CITA,NOMBRE PROPIO | [ "$(bz_resolver_base "$RBREPO")" = "DevelopUnjordi" ] && ok "b3d: mini-develop preferida sobre develop (HEAD en ramita)" \|\| bad "b3d: NO detectó Deve | BORRAR la cita; dejar solo el contrato |
| 3083 | NOMBRE PROPIO | git -C "$RBREPO" checkout -q DevelopUnjordi >/dev/null 2>&1 | REESCRIBIR a termino generico (usuario/maquina/host) |
| 3084 | CITA,NOMBRE PROPIO | [ "$(bz_resolver_base "$RBREPO")" = "DevelopUnjordi" ] && ok "b3d: HEAD en la mini → base = la mini" \|\| bad "b3d: HEAD en mini no se resolvió a sí mis | BORRAR la cita; dejar solo el contrato |
| 3100 | FECHA/TRAZA | echo "== (b3e) bz_es_zombie: regla (b) 'remota borrada' NO borra a ciegas una rama con commits propios (FMEA A5) ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3138 | CITA,NOMBRE PROPIO | # EL HUECO (queja real de unjordi): un MR-squash de VARIOS commits a uno NO empareja patch-id (git cherry | BORRAR la cita; dejar solo el contrato |
| 3169 | DRAMA | # (d) ON: el PR de feat/multi se mergeó y su head == tip actual → ZOMBIE (se poda el MR-squash) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3172 | DRAMA | && ok "b3g: (d) PR mergeado + head contiene el tip → ZOMBIE (poda el MR-squash)" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3193 | FECHA/TRAZA | # Hallazgo de mayor valor de la auditoría 2026-09-11: (d) es la ÚNICA señal que cazaba el squash | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3214 | DRAMA | && ok "b3h: (e) 'Rama:' en el log de la base → ZOMBIE, SIN red y SIN gh/glab (PATH mínimo de launchd)" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3283 | NOMBRE PROPIO | git -C "$C2REPO" branch DevelopUnjordi >/dev/null 2>&1 | REESCRIBIR a termino generico (usuario/maquina/host) |
| 3285 | NOMBRE PROPIO | git -C "$C2REPO" worktree add -q "$C2ROOT/wt-mini" DevelopUnjordi >/dev/null 2>&1 | REESCRIBIR a termino generico (usuario/maquina/host) |
| 3289 | CITA,NOMBRE PROPIO | printf '%s' "$c2out" \| grep -q 'PROTEGIDA.*wt-mini' && ok "b3k: C-2 — el worktree de la mini-develop (DevelopUnjordi) queda PROTEGIDO" \|\| bad "b3k: NO | BORRAR la cita; dejar solo el contrato |
| 3300 | DRAMA | echo "== (b3l) limpiar-worktrees: C-3 — un worktree ZOMBIE (rama integrada) con cambios SIN COMMITEAR/untracked NO se destruye ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3310 | FECHA/TRAZA | printf 'analisis a medias\n' > "$C3ROOT/wt-uno/borrador.md" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3317 | FECHA/TRAZA | [ -f "$C3ROOT/wt-uno/borrador.md" ] && ok "b3l: C-3 — el borrador untracked SOBREVIVE" \|\| bad "b3l: C-3 REGRESIÓN — se perdió el borrador" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3322 | DRAMA | echo "== (b3l2) FIX-6 / A-1: un worktree ZOMBIE SUCIO deja PENDIENTE en la bitácora (antes: congelaba la rama en silencio) ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3323 | FECHA/TRAZA | # Dictamen higiene de ramas 2026-09-17, A-1: conservar el árbol sucio es CORRECTO (C-3), pero solo la rama | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3326 | INCIDENTE | # envejecimiento ni escalación: un solo archivo untracked la congela indefinidamente. Medido en el repo | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 3336 | FECHA/TRAZA | printf 'analisis a medias\n' > "$A1ROOT/wt-sucio/borrador.md" # UN archivo untracked: eso basta | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3345 | FECHA/TRAZA | [ -f "$A1ROOT/wt-sucio/borrador.md" ] && ok "b3l2: el untracked SOBREVIVE (nunca se fuerza)" \|\| bad "b3l2: se destruyó trabajo sin commitear" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3423 | CITA,FECHA/TRAZA,NOMBRE PROPIO | # C1 (QA claudio 2026-10-13): el `jq … // \"NONE\"` viejo daba \"\" ante glab-falla → case '' → SINCI → | BORRAR la cita; dejar solo el contrato |
| 3458 | NOMBRE PROPIO | git -C "$M2REPO" branch DevelopUnjordi >/dev/null 2>&1 | REESCRIBIR a termino generico (usuario/maquina/host) |
| 3470 | FECHA/TRAZA | # Dictamen higiene de ramas 2026-09-17, C-3: en el fallback (3) el `\|\| echo main` se ligaba al PIPELINE, y | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3490 | FECHA/TRAZA | # gatillo de la señal (b)) — exactamente la población B del dictamen: trabajo represado, NO residuo. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3509 | DRAMA | && bad "FIX-3: feat/valioso (trabajo jamás integrado) se declaró ZOMBIE — PÉRDIDA DE DATOS" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3615 | FECHA/TRAZA | # (b3f) delegacion-reporte y (b3i) recordar-orquestar: RETIRADOS overhaul hooks 2026-09-18 (puramente | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3734 | FECHA/TRAZA | # ── CABLE a cerrar-slice (§5.3, decisión #18): el bloqueo de un CIERRE real (tras tocar código, sin marca) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3782 | FECHA/TRAZA | # ── PARSEO por CENTINELA + VETO de CITA (DETERMINISTA, sin LLM) · EMPODERADO 2026-08 ── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3826 | FECHA/TRAZA | # ── VETO ROBUSTO espejo del merge (fix veto-cita 2026-08): mismo helper _juez_cita_casa → tolera typo/ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3911 | FECHA/TRAZA | # cierre presente, pero un token de claim/celebración hacía ganar CIERRE=si). Case 2026-08-02 ya está | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3913 | FECHA/TRAZA | djlive "corpus FP 2026-07-29 'verif técnicamente / esperando OK / propuesta sin ejecutar'" CIERRE=no \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3915 | FECHA/TRAZA | djlive "corpus FP 2026-08-25 celebración + 'Nada declarado LISTO / verif técnicamente, pendiente tu QA'" CIERRE=no \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3921 | FECHA/TRAZA | # ── FIX DE PRECISIÓN 2026-08-30 (corpus §dod-verificar L52/L53/L54): clase MINI-DEVELOP. Un token de cierre | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3946 | FECHA/TRAZA | # ── FIX DE PRECISIÓN 2026-09 (corpus §dod-verificar 08-31 ×2): AJUSTE PUNTUAL de UN elemento de UI | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 3966 | FECHA/TRAZA | # ── FIX DE PRECISIÓN 2026-09 (corpus §dod-verificar 08-28): REPORTE DE SUBAGENTE atribuido explícitamente | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4007 | FECHA/TRAZA | echo "== (b4z) dod-verificar: COHERENCIA de timeouts — el crédito del juez cabe bajo el harness (fix carrera 2026-09-16) ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4008 | INCIDENTE | # Bug real medido en telemetría (transcripts jsonl, agosto 2026, project plantilladotnet): el harness del | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 4029 | INCIDENTE | # arman el turno + build del prompt + parseo de la respuesta), medido en telemetría real SIN llamada de red | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 4036 | FECHA/TRAZA | \|\| bad "dod: INCOHERENTE — interno(${dodj_interno}s) + margen(${DODJ_MARGEN_MINIMO}s) > harness-mínimo(${dodj_harness}s): el harness mataría el proces | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4044 | FECHA/TRAZA | # precompact-volcar-estado se RETIRÓ (2026-07): PreCompact no puede inyectar contexto ni pedir acción | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4064 | FECHA/TRAZA | printf '# Hilo mental actual\n> Última actualización: 2026-07-13 · rama %s\nMARCA_FRESCO\n' \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4078 | FECHA/TRAZA | printf '# Hilo mental actual\n> Última actualización: 2026-07-13 · rama otra-rama-vieja\nMARCA_RAMA\n' > "$RHGIT/.claude/memory/hilo-mental-actual.md" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4089 | FECHA/TRAZA | printf '# Hilo mental actual\n> Última actualización: 2026-07-13 · rama trabajo-actual\nMARCA_SAME\n' > "$RHSAME/.claude/memory/hilo-mental-actual.md" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4099 | FECHA/TRAZA | # Rec3 (auditoría continuidad 2026-09-09): sin hilo NO es siempre silencio. Post-compact en un repo con | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4115 | FECHA/TRAZA | # CONTRA LA FALLA (2026-09-11, al integrar #389 con #407): el aviso se emite solo si faltan LOS DOS | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4130 | FECHA/TRAZA | # ── A7 (inbox 2026-09-22): FARO anti-truncado. El harness trunca la salida de los hooks de arranque a | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4143 | FECHA/TRAZA | printf '# Hilo mental actual\n> Última actualización: 2026-10-12 · rama x\n\n## SIGUIENTE PASO\nSeguir con A8.\n' \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4150 | FECHA/TRAZA | { printf '# Hilo mental actual\n> Última actualización: 2026-10-12 · rama x\n\n## SIGUIENTE PASO\nMARCA_SIGUIENTE_FARO — seguir con A8.\n\n## ARBOL\n' | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4166 | CITA,FECHA/TRAZA,NOMBRE PROPIO | # (2b) C2 (QA claudio 2026-10-13): hilo de ~11K — ENTRE el default nuevo (9000) y el viejo (13000). Con el | BORRAR la cita; dejar solo el contrato |
| 4170 | FECHA/TRAZA | { printf '# Hilo mental actual\n> Última actualización: 2026-10-12 · rama x\n\n## SIGUIENTE PASO\nMARCA_11K — seguir con A8.\n\n## ARBOL\n' | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4191 | FECHA/TRAZA | : > "$ADROOT/.claude/repo-compartido" # #46: este bloque prueba el camino COMPARTIDO (el correo) → lleva la marca | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4231 | CITA,NOMBRE PROPIO | printf '# Conocimiento propio\nes tu cerebro, es mi repo, y es nuestro proyecto. La introspección PROPONE; unjordi DECIDE.\n' > "$ADROOT/.claude/memor | BORRAR la cita; dejar solo el contrato |
| 4261 | FECHA/TRAZA,NOMBRE PROPIO | # MEMORY.md, y el molde de canonizar-cerebro lo documenta. Jordi 2026-10-14: "lo quiero en el @ nativo, no en el | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4272 | FECHA/TRAZA | # Antes era CIEGO al wiring: solo sumaba nuevos+act+ret → un repo con "0 nuevos · 0 a actualizar · N | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4279 | FECHA/TRAZA | : > "$ADWROOT/.claude/repo-compartido" # #46: camino COMPARTIDO (el correo) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4291 | FECHA/TRAZA | # ── (b5b3) #46: repo PERSONAL (SIN marca .claude/repo-compartido) → guards por-repo NUNCA (opción B) ── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4307 | FECHA/TRAZA | && ok "aviso-drift #46: personal CON guard del brain → FLAG 'sobran, quítalos'" \|\| bad "aviso-drift #46: no flaggeó el guard sobrante en personal; got | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4309 | FECHA/TRAZA | && bad "aviso-drift #46: personal NO debe auto-sincronizar ni tratar guards como 'drift'" \|\| ok "aviso-drift #46: personal no auto-sincroniza (sin com | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4314 | FECHA/TRAZA | is_silent "$(pad)" && ok "aviso-drift #46: personal SIN guards del brain (solo hook propio) → silencio" \|\| bad "aviso-drift #46: habló en un personal  | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4324 | FECHA/TRAZA | : > "$AD2REPO/.claude/repo-compartido" # #46: camino COMPARTIDO (dentro del commit base → .claude/ limpio) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4365 | DECORACION | # ═════════════════════════════════════════════════════════════════════════════════════════════════════ | BORRAR caja/banner |
| 4434 | FECHA/TRAZA | printf 'demo-ret-skill retirado 2026-09-18 fusionada-en-otra\n' > "$SKRBR/brain/skills/MANIFEST" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4528 | FECHA/TRAZA | # auditoría de suficiencia operativa (2026-09-18): install-brain §(e) SÍ refresca el bloque en cada | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4530 | NOMBRE PROPIO | # unjordi seguía citando `recordar-dashboard`, ya retirado, como "un hook te lo recuerda"). Antes de esta | REESCRIBIR a termino generico (usuario/maquina/host) |
| 4561 | FECHA/TRAZA | # ── (b5c-V1) FIX V1 (auditoría 2026-08-06): el auto-commit del cerebro por-repo BYPASSEABA secret-scan | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4615 | FECHA/TRAZA | : > "$AD3REPO/.claude/repo-compartido" # #46: COMPARTIDO (dentro del commit base → .claude/ limpio) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4638 | FECHA/TRAZA | # ── (b5c3) C2 FMEA: guard ANTI-REGRESIÓN — fuente ($BRAIN_DIR) DETRÁS de su origin/main → NO auto-aplica. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4665 | FECHA/TRAZA | : > "$AD4REPO/.claude/repo-compartido" # #46: COMPARTIDO (para probar el guard C2 de la ruta de correo) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4678 | FECHA/TRAZA | # ── (b5c4) sA3 FMEA: el patrón de mini-develop es Develop+MAYÚSCULA. Una rama 'Development' (Develop+ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4686 | FECHA/TRAZA | : > "$AD5REPO/.claude/repo-compartido" # #46: COMPARTIDO (para probar la regex de mini-develop sA3) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4704 | FECHA/TRAZA | # ── (b5c5) sA3 FMEA: el commit del auto-sync va ACOTADO a .claude/ (git commit -o) — NO barre cambios | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4711 | FECHA/TRAZA | : > "$AD6REPO/.claude/hooks/.brain-version"; printf 'base\n' > "$AD6REPO/src/foo.txt"; : > "$AD6REPO/.claude/repo-compartido" # #46: COMPARTIDO | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4811 | FECHA/TRAZA | # ── (8) FIX-1 / C-1 (dictamen higiene de ramas 2026-09-17) · CAUSA RAÍZ del reguero ────────────────── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4813 | INCIDENTE | # en OTRO repo. Medido en vivo: `cortex` no tenía NI UN stamp en ~/.claude/memory/.barrer-ramas/ (nunca | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 4920 | FECHA/TRAZA | # (b5g) recordar-cosechar NUDGE: el nudge INCONDICIONAL viejo se retiró (overhaul hooks 2026-09-18, | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4922 | FECHA/TRAZA | # se queda solo en el chat"). El rediseño 2026-09-18 (sync bidireccional) lo RESTAURÓ ATADO al sync real: | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4940 | FECHA/TRAZA | GIT_AUTHOR_DATE="2020-01-01T00:00:00" GIT_COMMITTER_DATE="2020-01-01T00:00:00" git -C "$1" commit -qm base >/dev/null 2>&1 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4988 | FECHA/TRAZA | em3 >/dev/null # primer espejo (crea el bloque con #5 #12) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4989 | FECHA/TRAZA | # cambia el TaskList: #5 se completa, aparece #20 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 4993 | FECHA/TRAZA | grep -q '#20' "$EMFILE_C3" && ok "espejo: re-espejo ACTUALIZA el bloque existente (#20 aparece; fix awk-newline macOS)" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5028 | FECHA/TRAZA | # (b5h) recordar-unificar-cerebro: RETIRADO overhaul hooks 2026-09-18 (puramente advisory, medido: | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5059 | FECHA/TRAZA,DRAMA | echo "== (b6) aviso-contexto: HUB que HACE — umbral ALTO/CRÍTICO, dispara el checkpoint mecánico, no gotea (rediseño 2026-09-17) ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5060 | CITA,FECHA/TRAZA,NOMBRE PROPIO | # Contrato NUEVO (2026-09-17, revisión de unjordi): el hook DEJA de reportar cada 5% y de deferir ("tú | BORRAR la cita; dejar solo el contrato |
| 5063 | DRAMA | # más al CRÍTICO (92%). El denominador es el punto real (autoCompactWindow si el auto-compact está ACTIVO; | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5123 | DRAMA | # ── escalada ALTO→CRÍTICO y re-arme tras compact (una sola escalada, sin goteo dentro de banda) ── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5133 | DRAMA | e3="$(ac_esc 940000)" # cruza CRÍTICO (94%) → escala (banda 2) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5136 | DRAMA | && ok "[↯viejo] b6-escalada: ALTO emite, 85% CALLA (misma banda), CRÍTICO escala, 96% CALLA — a lo sumo 2 disparos, sin goteo" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5139 | DRAMA | && ok "b6-escalada: el disparo CRÍTICO va en tono más urgente (🚨 RAYANDO el compact)" \|\| bad "b6-escalada: el crítico no escaló el tono; got: $e3" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5196 | FECHA/TRAZA,NOMBRE PROPIO | # ── (b6-invariante) modelo DESCONOCIDO → NO se inventa ventana, ni con ctx enorme (Jordi 2026-10-13: "si no | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5239 | CITA,FECHA/TRAZA,NOMBRE PROPIO | # (b6-transcript-synthetic) C3/A3 (QA claudio 2026-10-13): un modelo "<synthetic>" (límite de sesión / error | BORRAR la cita; dejar solo el contrato |
| 5308 | FECHA/TRAZA | echo "== (m1) doc=realidad: ningún doc niega el hook de PreCompact que install-brain.sh SÍ cablea (C1, auditoría 2026-09-11) ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5326 | FECHA/TRAZA | echo "== (m2) checkpoint-mecanico.js: extractor MECÁNICO en streaming (M2, auditoría 2026-09-11) ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5347 | FECHA/TRAZA | L({type:"user",message:{role:"user",content:"ultimo mensaje verbatim: revisa el PR #123"}}); | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5374 | FECHA/TRAZA | const esperado = ["sigue con el modulo de facturacion, ya casi","ultimo mensaje verbatim: revisa el PR #123"]; | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5382 | FECHA/TRAZA | echo "== (m2c) checkpoint-mecanico.js: hallazgos de QA sobre el render real (2026-09-11) ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5406 | FECHA/TRAZA | const gh = "gh pr merge 405 --repo unjordi/cortex --squash --delete-branch \\\n --subject \"fix(gitignore): el andamio (#405)\" \\\n --body \"cuerpo l | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5408 | FECHA/TRAZA | if (r1.length !== 1 \|\| r1[0] !== "fix(gitignore): el andamio (#405)") { console.error("GH: " + JSON.stringify(r1)); process.exit(1); } | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5417 | INCIDENTE | # citado dentro de un heredoc que solo ESCRIBE un archivo) no debe leerse como un commit real — MEDIDO | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 5418 | FECHA/TRAZA | # 2026-09-11: la prosa de un commit real que explicaba el bug del detector viejo ("solo ve `-m \"…\"`") | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5492 | FECHA/TRAZA | echo "== (m2d) checkpoint-mecanico.js: 2 REGRESIONES del arreglo de A-1..A-6 (QA sobre el render real, 2026-09-11) ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5499 | FECHA/TRAZA | const cmd = "cat > /tmp/fixture.py <<PY\nL.append(u(\"<command-name>/to-do</command-name>\", \"2026-01-01T03:05:00Z\"))\nPY"; | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5512 | FECHA/TRAZA | const cmd = "L.append(bash(\"printf %s hola >> .claude/memory/bitacora.md\", \"2026-01-01T08:30:00Z\"))"; | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5532 | FECHA/TRAZA | bash("L.append(bash(\"printf %s hola >> .claude/memory/bitacora.md\", \"2026-01-01T08:30:00Z\"))"); | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5550 | INCIDENTE | # (16×, valor constante) y dos asignaciones SIN comando encadenado (3× y 1×) se colaban como "señal" solo | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 5592 | FECHA/TRAZA | echo "== (m2f) checkpoint-mecanico.js: C-1/C-2, QA sobre el render REAL del 2026-09-11 (loop 3) ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5595 | FECHA/TRAZA,INCIDENTE | # primero y descartaba la línea ENTERA. MEDIDO 2026-09-11: 87 de 101 comandos del tramo real arrancaban | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 5666 | FECHA/TRAZA | # proporciones MEDIDAS 2026-09-11 (3 escrituras REALES contra 13 temporales, 16 destinos distintos en | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5711 | FECHA/TRAZA | # La mecánica (nohup/lock/anti-recursión) se FACTORIZÓ a la lib checkpoint-mecanico-comun.sh (2026-09-17) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5746 | FECHA/TRAZA | # F1 del plan "checkpoint y mudanza unificados" (2026-09-11). El hallazgo que cierra este bloque: el | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5764 | FECHA/TRAZA | printf '%s\n' '# Hilo mental actual' '> Última actualización: 2026-09-11 · nivel COMPLETO.' '' '## En qué estamos' 'x' > "$F1D/sin-rama.md" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5765 | FECHA/TRAZA,NOMBRE PROPIO | printf '%s\n' '# Hilo mental actual' '> Última actualización: 2026-09-11 · rama DevelopUnjordi · nivel COMPLETO.' '' '## En qué estamos' 'x' > "$F1D/c | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5767 | FECHA/TRAZA | printf '%s\n' '# Hilo mental actual' '> Última actualización: 2026-09-11 · rama feat/diagrama-x · nivel ligero.' > "$F1D/rama-golosa.md" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5769 | FECHA/TRAZA,INCIDENTE | # (f1a) CONTRA LA FALLA — el estado REAL medido el 2026-09-11 sobre los 9 hilos de ~/code: 2 de 9 (22%) | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 5794 | FECHA/TRAZA | printf '%s\n' '# Hilo mental actual' '> Última actualización: 2026-01-01 · rama main · nivel ligero.' '' 'EL-HILO-VIEJO-DE-ENERO' > "$F1H" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5850 | FECHA/TRAZA | printf '%s\n' '# Hilo mental actual' '> Última actualización: 2026-01-01 · rama develop · nivel ligero.' '' 'HILO-EN-RAMA-PERMANENTE' \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5888 | FECHA/TRAZA | # A-3 (2026-09-11): el candado usaba CLAUDE_CODE_CHILD_SESSION==='1' para fallar cerrado "dentro de un | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5889 | INCIDENTE | # subagente". MEDIDO: esa variable vale '1' TAMBIÉN en el Bash del hilo PRINCIPAL (CLI 2.1.x, macOS) — | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 5915 | INCIDENTE | # MEDIDO sobre dos masters reales (192/201 MB, 13 compactaciones): con la ventana en el archivo entero, | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 5927 | CITA,NOMBRE PROPIO | L({type:"assistant",gitBranch:"DevelopUnjordi",message:{role:"assistant",content:[{type:"tool_use",name:"Write",input:{file_path:"/vivo/DE-HOY.md"}}]} | BORRAR la cita; dejar solo el contrato |
| 5935 | NOMBRE PROPIO | printf '%s' "$F1VJ" \| jq -e '.commitsTotal == 0 and (.ramas == ["DevelopUnjordi"]) and (.mensajesUsuario == 1)' >/dev/null 2>&1 \ | REESCRIBIR a termino generico (usuario/maquina/host) |
| 5951 | FECHA/TRAZA,INCIDENTE | # MEDIDO 2026-09-11 en el tramo vivo de un master real: 0 escrituras por Write/Edit y 45 por Bash. En | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 5986 | FECHA/TRAZA | # (b6c) hud-stale: RETIRADO overhaul hooks 2026-09-18 (puramente advisory, medido: ignorado). Su regla | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6002 | FECHA/TRAZA | # (b8) recordar-dashboard: RETIRADO overhaul hooks 2026-09-18 (puramente advisory, medido: ignorado). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6183 | FECHA/TRAZA,NOMBRE PROPIO | # usuario SOBREVIVEN. Antídoto EXACTO al dod-verificar huérfano-inerte hallado en la Cachy (2026-09-08). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6210 | FECHA/TRAZA,INCIDENTE,DRAMA | # SÍ caza un BRAIN_PAT drifteado (el bug real 2026-09-08: uninstall omitía 5 → 5 cableados ZOMBIE). Antes | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 6214 | DRAMA | [ "${left:-x}" = "0" ] && ok "uninstall: 0 cableados del cerebro en settings.json (set COMPLETO {global,both} kind=hook — cazaría un BRAIN_PAT driftea | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6264 | INCIDENTE | echo "== y un no-ASCII -acento, em-dash, emoji- le rompe la tokenización. caso real: un Windows ajeno) ==" | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 6337 | FECHA/TRAZA | # FUSIÓN 2026-09-17 (fase skills): consolidar-cerebro, unificar-cerebro, cosechar-sesion, | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6349 | FECHA/TRAZA | # overhaul hooks 2026-09-18: recordar-unificar-cerebro (SessionStart, puramente advisory) se RETIRÓ — | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6360 | FECHA/TRAZA | # checkpoint\|checkpoint-mecanico (M2, auditoría 2026-09-11): el SKILL.md documenta que debe LEER/FUSIONAR | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6364 | FECHA/TRAZA | # CONSOLIDACIÓN 2026-09-17: merge-squash-guard + confirmar-merge-develop se fusionaron en | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6368 | FECHA/TRAZA | # checkpoint\|contrato-hilo (F1, 2026-09-11): la lib es el CONTRATO del footer del hilo — la skill la | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6371 | FECHA/TRAZA | # analizar-comando-git\|proteger-arbol (M1/M2, auditoría 2026-09-15): proteger-arbol AHORA sourcea la lib | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6375 | FECHA/TRAZA | # analizar-comando-git\|limpiar-residuo (auditoría de ejecución 2026-09-16, H1): acg__cache_confiable usa | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6381 | FECHA/TRAZA | # checkpoint-mecanico\|checkpoint-mecanico-comun (rediseño aviso-contexto 2026-09-17): el lanzador del | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6385 | FECHA/TRAZA | # limpiar\|limpiar-impl-{ramas,worktrees,residuo,flotilla} (consolidación 2026-09-17, fase skills): los 4 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6392 | FECHA/TRAZA | # sync bidireccional del TaskList 2026-09-18): la maquinaria del espejo/sembrado vive UNA vez en la lib | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6397 | FECHA/TRAZA | # borrador 2026-09-22): la red de emergencia es HERMANA del par checkpoint/rehidratar-hilo (como | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6478 | FECHA/TRAZA,DECORACION | # ═══ BLOQUE AÑADIDO (#81 asentar-tiers) — delimitado para merge-friendliness en paralelo ═══════════════ | BORRAR caja/banner |
| 6479 | FECHA/TRAZA | echo "== (e2-tiers) doc-check: los MANIFEST documentan los 3 tiers + la regla de decisión repo-compartido (#81) ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6494 | FECHA/TRAZA,DECORACION | # ═══ FIN BLOQUE AÑADIDO (#81) ═════════════════════════════════════════════════════════════════════════ | BORRAR caja/banner |
| 6500 | NOMBRE PROPIO | # (detectado por unjordi): una skill en brain/skills/<n>/SKILL.md que NO esté en brain/skills/MANIFEST la | REESCRIBIR a termino generico (usuario/maquina/host) |
| 6636 | FECHA/TRAZA | # estado salía rojo en silencio). El fix de RAÍZ (2026-09-18) ELIMINÓ ese switch: cualquier nombre que no | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6674 | FECHA/TRAZA | # Antídoto de RAÍZ al bug user-facing (2026-09-18): el widget hardcodeaba su roster y sacaba skills | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6747 | FECHA/TRAZA | # 2026-09-15): simula una máquina/repo VIEJO que la tenía instalada de antes de que se retirara. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6812 | FECHA/TRAZA | # MANIFEST, 2026-09-15): el .sh sigue copiado y cableado — el HUECO real que motivó este mecanismo. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6854 | FECHA/TRAZA | # Hallazgo ALTO-1 de la auditoría de suficiencia operativa (2026-09-18): el retiro de hooks tenía | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6855 | NOMBRE PROPIO | # RETIRED+lápida+auto-poda; las skills NO — confirmado EN VIVO en la máquina de unjordi con 5 skills | REESCRIBIR a termino generico (usuario/maquina/host) |
| 6902 | FECHA/TRAZA | # e4b (C1, FMEA post-integración 2026-07-30): la instalación MANUAL de Windows (install-brain.ps1 sin pasar | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6917 | FECHA/TRAZA | # docs/auditoria-procesos-fmea-2026-07-30.md, ANEXO "Coherencia de RUTAS cross-OS". | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6967 | FECHA/TRAZA | # H2 portado a QML (2026-07-30): antes el plasmoid confiaba CIEGO en version.json.repo (un path horneado | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6972 | FECHA/TRAZA | C4="$PR/windows/src/Cortex/Updater.cs" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6983 | FECHA/TRAZA | if [ -f "$C4" ]; then | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 6984 | FECHA/TRAZA | { grep -qF 'ResolveClonePath' "$C4" && grep -qF 'CLAUDE_BRAIN_DIR' "$C4" && grep -qF 'cortex-repo' "$C4" && grep -qF 'install.ps1' "$C4"; } \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7065 | FECHA/TRAZA | # El fan-out de guards sobre Bash es un set CERRADO de 6 (rama-vieja se RETIRÓ — tier `retirado` en el | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7066 | FECHA/TRAZA | # MANIFEST; CONSOLIDACIÓN 2026-09-17: merge-squash-guard + confirmar-merge-develop se fusionaron en | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7067 | FECHA/TRAZA | # merge-develop-guard; overhaul hooks 2026-09-18: recordar-dashboard se retiró, puramente advisory — | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7099 | FECHA/TRAZA | # e6c2 (B1, FMEA post-integración 2026-07-30): el árbol del README RAÍZ es la FUENTE que gen-leyenda-arbol | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7113 | FECHA/TRAZA | # e6c3 (C5, FMEA post-integración 2026-07-30): el generador de la leyenda NO tenía test → un cambio de | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7140 | FECHA/TRAZA | # los .dot (2026-09-16) los 14 .svg commiteados se quedaron mostrando un hook ya retirado: el diagrama | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7237 | FECHA/TRAZA | # (era claude-brain). El rename #312 renombró mecánicamente el old_marker a '# cortex: …', string que | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7299 | INCIDENTE | # Bug real (Windows "Asistente Dir"): 'claude' resolvia a AppData\Local\AnthropicClaude\claude.exe | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 7363 | FECHA/TRAZA | && ok "exportar-sesion-master: Opción A — el register block de masters.json se RETIRÓ (ya no auto-escribe el compartido)" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7422 | DRAMA | echo " Fase 1 SOLO comparaba Skills y daba ✅ FALSO ante un drift de hooks real (CRÍTICO-1) ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7426 | INCIDENTE | # exactamente el patrón del bug real (un guard renombrado en un catálogo y no en el otro). Un checker | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 7427 | FECHA/TRAZA | # que no puede dar rojo ante esto no sirve (la propia auditoría de suficiencia lo encontró en ✅ falso). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7454 | DECORACION | # ═════════════════════════════════════════════════════════════════════════════ | BORRAR caja/banner |
| 7536 | FECHA/TRAZA | # tras instalar el global daba falso-ROJO (la copia del repo cedía). Ver #80. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7568 | FECHA/TRAZA | # corpus de FP reales (docs/guards-falsos-positivos.md 2026-08-08/2026-08-29): el nombre del instalador | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7573 | FECHA/TRAZA | [ -z "$(nbd_ctx 'git log --since=2026-08-01 -- brain/install-brain.sh')" ] \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7633 | FECHA/TRAZA | # tier repo: SIN equivalente global — debe SOBREVIVIR (el FP ya documentado, 2026-09-08, trataba esto como sobrante) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7736 | FECHA/TRAZA | echo "== (g4) normas nuevas presentes en norms/global-claude-md.md (mecanismo de las normas #12a/#13) ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7741 | FECHA/TRAZA | && ok "g4: norma 'nunca el clic en la web como escape de un juez que frena' presente" \|\| bad "g4: falta la norma del clic-en-la-web como escape (#13)" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 7881 | NOMBRE PROPIO | echo "soy claude-brain-cachy-master" > "$SRCREPO/.claude/memory/conocimiento-propio.local.md" | REESCRIBIR a termino generico (usuario/maquina/host) |
| 7888 | NOMBRE PROPIO | { "schema": 2, "masters": [ { "id": "$ID", "name": "claude-brain-cachy-master", "target": "code/plantilladotnet" } ] } | REESCRIBIR a termino generico (usuario/maquina/host) |
| 7937 | NOMBRE PROPIO | "$BINRM/session-lib.js" "$ID" "claude-brain-cachy-master" >/dev/null 2>&1 | REESCRIBIR a termino generico (usuario/maquina/host) |
| 7938 | NOMBRE PROPIO | [ "$(HOME="$RMHOME" node -e 'console.log((require(process.argv[1]).sessionAliases()[process.argv[2]])\|\|"")' "$BINRM/session-lib.js" "$ID")" = "claude- | REESCRIBIR a termino generico (usuario/maquina/host) |
| 8004 | NOMBRE PROPIO | HOME="$RMHOME" node "$BINRM/session-export.js" "$ID" --repo "$tmpe" --name "claude-brain-cachy-master" --force >/dev/null 2>&1 | REESCRIBIR a termino generico (usuario/maquina/host) |
| 8026 | INCIDENTE | # del session-move.js real (no solo dentro del e2e completo, más abajo). Medido en un master | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 8073 | FECHA/TRAZA | node -e 'const fs=require("fs");fs.utimesSync(process.argv[1],new Date("2026-08-01"),new Date("2026-08-01"));fs.utimesSync(process.argv[2],new Date("2 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8081 | INCIDENTE | # ── s1b: ts MANDA sobre un mtime más fresco — el caso real que motivó el fix (vuelta 3, #9 abajo). | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 8087 | FECHA/TRAZA | printf '{"type":"user","timestamp":"2026-01-01T00:00:00.000Z"}\n' > "$SIPROJ/-slug-muerta-restaurada/$SID1B.jsonl" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8088 | FECHA/TRAZA | printf '{"type":"user","timestamp":"2026-09-01T00:00:00.000Z"}\n' > "$SIPROJ/-slug-viva/$SID1B.jsonl" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8089 | FECHA/TRAZA | node -e 'const fs=require("fs");fs.utimesSync(process.argv[1],new Date(),new Date());fs.utimesSync(process.argv[2],new Date("2026-08-01"),new Date("20 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8100 | FECHA/TRAZA | printf '{"type":"user","timestamp":"2026-05-05T00:00:00.000Z"}\n' > "$SIPROJ/-slug-chica/$SID1C.jsonl" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8101 | FECHA/TRAZA | printf '{"type":"user","timestamp":"2026-05-05T00:00:00.000Z","relleno":"%s"}\n' "$(printf 'X%.0s' $(seq 1 200))" > "$SIPROJ/-slug-grande/$SID1C.jsonl | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8102 | FECHA/TRAZA | node -e 'const fs=require("fs");fs.utimesSync(process.argv[1],new Date(),new Date());fs.utimesSync(process.argv[2],new Date("2026-01-01"),new Date("20 | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8116 | FECHA/TRAZA | printf '{"type":"user","cwd":"%s","timestamp":"2026-08-08T00:00:00.000Z"}\n{"type":"assistant","cwd":"%s","timestamp":"2026-08-08T00:01:00.000Z"}\n{"t | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8119 | FECHA/TRAZA | node -e 'const z=require("zlib"),fs=require("fs");const c=`{"type":"user","cwd":"/old","timestamp":"2026-08-01T00:00:00.000Z"}\n{"type":"assistant","c | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8133 | FECHA/TRAZA,NOMBRE PROPIO | # Jordi lo mandó a mantenerse A MANO (2026-10-14). Con el engine presente (símlink) el flujo LLEGA al punto | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8304 | FECHA/TRAZA | # escritores se borren las claves — en silencio y sin que nada lo asevere. Medido 2026-09-10: | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8358 | FECHA/TRAZA | R2ANID='{"type":"user","timestamp":"2026-01-01T00:00:01.000Z","toolUseResult":{"timestamp":"2099-12-31T23:59:59.000Z"}}' | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8360 | FECHA/TRAZA | [ "$(R2TLS "$R2ANID")" = "2026-01-01T00:00:01.000Z" ] \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8363 | FECHA/TRAZA | [ "$(R2TLS '{"a":{"timestamp":"2099-01-01T00:00:00.000Z"}}')" = "null" ] \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8367 | FECHA/TRAZA | [ "$(R2TLS '{"type":"user","timestamp":"2026-03-03T00:00:00.000Z","message":{"role":"assist')" = "2026-03-03T00:00:00.000Z" ] \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8372 | FECHA/TRAZA | printf '{"type":"user","timestamp":"2026-01-01T00:00:00.000Z","cwd":"/x"}\n%s\n' "$R2ANID" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8374 | FECHA/TRAZA | printf '{"type":"user","timestamp":"2026-09-09T14:05:00.000Z","cwd":"/y"}\n' > "$R2PROJ/-slug-vivo/$R2ID.jsonl" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8510 | FECHA/TRAZA | # ── #83 anti-drift: TRATO personal del usuario → archivo GLOBAL como-trabajar-con-<user> ── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8514 | FECHA/TRAZA | echo "== #83 anti-drift como-trabajar: las skills de cosecha/consolidación rutean el TRATO al archivo GLOBAL ==" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8530 | FECHA/TRAZA | # El NUDGE INCONDICIONAL de recordar-cosechar se retiró (overhaul hooks 2026-09-18) — su regla de ruteo del | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8532 | FECHA/TRAZA | # rediseño 2026-09-18 pero ATADO al sync real, no como el recordatorio de cosecha/TRATO que aquí se prueba.) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8548 | DECORACION | # ═════════════════════════════════════════════════════════════════════════════ | BORRAR caja/banner |
| 8550 | FECHA/TRAZA | # Es la prueba que NO existía: hasta el 2026-09-10 los pasos destructivos de este skill nunca se habían | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8570 | NOMBRE PROPIO | git -C "$_r" symbolic-ref HEAD refs/heads/DevelopUnjordi | REESCRIBIR a termino generico (usuario/maquina/host) |
| 8580 | FECHA/TRAZA,NOMBRE PROPIO | printf '{"type":"user","timestamp":"2026-01-01T00:00:00.000Z","cwd":"%s","gitBranch":"DevelopUnjordi"}\n' "$E2ESRCP" > "$E2EJSONL" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8653 | FECHA/TRAZA | # LA REGRESIÓN del 2026-09-10: el preludio EMBEBIDO. Sin él el handoff muere en 'DST_CWD: unbound | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8659 | FECHA/TRAZA | ok "(e2e) el PRELUDIO quedó embebido TEXTUALMENTE en el handoff (regresión 2026-09-10)" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8673 | FECHA/TRAZA | bad "(e2e) el candado ACEPTA un handoff sin preludio (el agujero del 2026-09-10 sigue abierto)" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8677 | FECHA/TRAZA,INCIDENTE | # mudanza. Medido el 2026-09-10: ~/.local/bin llevaba 3 días atrás y no tenía ni `--git-branch` ni | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 8691 | FECHA/TRAZA | # devolvía 44 de 43 memorias (medido 2026-09-10) — un descubrimiento que no descarta nada no descubre | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8839 | FECHA/TRAZA | printf '%s\n' 'HILO-DEL-MASTER-QUE-VIAJA' '> Última actualización: 2026-09-11 · rama vieja · nivel COMPLETO.' > "$E2ET2D/hilo-mental-actual.md" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8842 | FECHA/TRAZA | printf '%s\n' 'HILO-PROPIO-DEL-DESTINO' '> Última actualización: 2026-09-11 · rama destino · nivel ligero.' > "$E2EDST/.claude/memory/hilo-mental-actu | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 8951 | CITA,FECHA/TRAZA | # Queja real (2026-09): "qué pasa con lo que deja detrás... no todo eran ramas con worktree". Clases | BORRAR la cita; dejar solo el contrato |
| 9030 | FECHA/TRAZA | echo "== (b1d-h5doc) H5 (auditoría de ejecución 2026-09-16, MEDIO, CONFIRMADO): el CONTRATO de fail-safe ya" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 9034 | FECHA/TRAZA | # que M8 (auditoría 2026-09-15 §3.11) retiró esa redirección de los 4 mensajes reales por la norma anti- | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 9055 | FECHA/TRAZA | # El fix multi-monitor (2026-09-18) dejó el DEFAULT = todas las pantallas; pero "SOLO una ventana | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 9112 | FECHA/TRAZA | # ── cerrar-slice --wait-ci: el veredicto de CI gobierna merge/abort (A2, 2026-10-11) ── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 9140 | FECHA/TRAZA | # copia instalada y pisarla el sync (inbox 2026-09-24) → guard de PRESENCIA contra que una reorg la retire. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 9146 | FECHA/TRAZA,NOMBRE PROPIO | # A7: el borrador de /compact (pedido Jordi 2026-10-14) DEBE vivir en la FUENTE del skill: si el checkpoint | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 9149 | FECHA/TRAZA | { [ -f "$CKS" ] && grep -qiF 'entrega el borrador' "$CKS" && grep -qF '/compact <instrucciones>' "$CKS" && grep -qi 'procedencia (regla dura)' "$CKS"; | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 9150 | FECHA/TRAZA | && ok "checkpoint SKILL: trae el paso de cierre que entrega el borrador de /compact (con regla de procedencia)" \ | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 9151 | FECHA/TRAZA,NOMBRE PROPIO | \|\| bad "checkpoint SKILL: FALTA el paso del borrador de /compact o su regla de procedencia (pedido Jordi 2026-10-14)" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 9252 | DECORACION | # ═════════════════════════════════════════════════════════════════════════════════════════════════════ | BORRAR caja/banner |

### bin/checkpoint-mecanico.js (24)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 4 | FECHA/TRAZA | * "mudanza de master · checkpoint/compactación", 2026-09-11). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 30 | FECHA/TRAZA,INCIDENTE | * MEDIDO el 2026-09-11 sobre dos masters reales (192 MB/39 183 líneas/13 compactaciones y 201 MB/39 221/ | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 63 | FECHA/TRAZA,INCIDENTE | * despriorizarlas ni a reordenarlas en un segundo grupo. MEDIDO 2026-09-11: reordenar en dos grupos | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 74 | FECHA/TRAZA,INCIDENTE | * sigue (`git commit`, `gh pr merge`, `bash brain/test-brain.sh`…). MEDIDO 2026-09-11 sobre el tramo | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 146 | INCIDENTE | // Plomería del HARNESS, no del usuario — aunque el transcript la marque type:'user'/role:'user'. MEDIDO | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 147 | FECHA/TRAZA | // 2026-09-11 sobre un render real: 3 de 9 "mensajes del usuario" eran esto (el `<task-notification>` | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 148 | CITA | // completo, 8 líneas). El rótulo de la sección invita a citar "VERBATIM, para citar con `[user: …]`" — | BORRAR la cita; dejar solo el contrato |
| 182 | FECHA/TRAZA,INCIDENTE | // MEDIDO 2026-09-11: 7 de 10 comandos del top eran navegación/inspección (`cd`×3, `grep -n`…) — se | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 200 | FECHA/TRAZA,INCIDENTE | // "señal" aunque no diga qué se hizo (MEDIDO 2026-09-11: `WT=/private/tmp/…; cd` 16×, `SP=…` 1×, | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 223 | FECHA/TRAZA,INCIDENTE | // en el orden de TODA la lista (MEDIDO 2026-09-11: `[16,3,3,1,1,1,1,37,22,7]`, el 37× en la posición 8). | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 235 | FECHA/TRAZA,INCIDENTE | // la clave. MEDIDO 2026-09-11: `timeout 900 bash brain/test-brain.sh …` (5 corridas de la suite en el | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 275 | NOMBRE PROPIO | // integraciones reales) y `git commit -F -`/`ssh loki "…"` se cortan en el operador/cadena citada en vez | REESCRIBIR a termino generico (usuario/maquina/host) |
| 303 | FECHA/TRAZA,INCIDENTE | // MEDIDO 2026-09-11: 6 de 10 escrituras-por-bash eran temporales (`/tmp/suite-*.log`…) desplazando a las | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 333 | FECHA/TRAZA,INCIDENTE | // `>` de redirección) casa dentro de una cadena CITADA, no en un comando real. MEDIDO 2026-09-11: | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 378 | INCIDENTE | // `/` o extensión) pero la ruta real es DESCONOCIDA — al rehidratar no lleva a ningún lado. MEDIDO | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 379 | FECHA/TRAZA | // 2026-09-11: en un master real, la escritura venía DENTRO de un heredoc de python que armaba un | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 388 | FECHA/TRAZA,INCIDENTE | // una redirección para un regex. MEDIDO 2026-09-11 sobre un master real: sin este filtro, los falsos | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 402 | FECHA/TRAZA,INCIDENTE | // equipo de verdad usa (MEDIDO 2026-09-11 sobre un tramo real: los 5 commits del tramo fueron TODOS | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 422 | FECHA/TRAZA,INCIDENTE | // texto. MEDIDO 2026-09-11: sin este filtro, la propia prosa de un commit que describía el bug del | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 582 | FECHA/TRAZA,INCIDENTE | // mismo tramo (MEDIDO 2026-09-11: un solo comando repetido 3 veces bastaba para acaparar la | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 657 | FECHA/TRAZA,INCIDENTE | // encabezado ya se calculó con TOP_N fijo. MEDIDO 2026-09-11: "top 10 de 16" renderizando 6 — el lector | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 684 | CITA | lines.push(`## Últimos ${r.mensajesUsuario.length} mensajes del usuario (VERBATIM, para citar con \`[user: "…"]\`)`); | BORRAR la cita; dejar solo el contrato |
| 702 | INCIDENTE | // sin querer que pase). El candado usaba `CLAUDE_CODE_CHILD_SESSION === '1'` como señal. MEDIDO | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 703 | FECHA/TRAZA | // 2026-09-11: esa variable vale `1` TAMBIÉN en el Bash del HILO PRINCIPAL (CLI 2.1.x, macOS) — no es | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### macos/install.sh (15)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 18 | FECHA/TRAZA | # fuente en vez de instalar el asset rancio (ver C4, docs/reaudit-ola1-2026-09-01.md). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 30 | FECHA/TRAZA | # Config del widget: con el rebrand COMPLETO (2026-07) pasó a ~/.config/cortex (el código lee | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 63 | FECHA/TRAZA | # --- "Borra el previo por completo" (regla 2026-07-15) ----------------------------------------- | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 84 | FECHA/TRAZA | # --- Barre la era INTERMEDIA 'claude-brain' (rename claude-brain → cortex, #312) ---------------- | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 85 | FECHA/TRAZA | # El #312 renombró todo a 'cortex' pero NO dejó barrido de la era 'claude-brain': quien la tenía | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 95 | FECHA/TRAZA | echo "==> Eliminando cualquier instalación previa 'claude-brain' (era intermedia del rename a cortex)" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 117 | FECHA/TRAZA | # claude-brain→cortex (#312) renombró MECÁNICAMENTE el string del old_marker a | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 122 | FECHA/TRAZA | "# claude-brain: ~/.local/bin en el PATH (claude, claude-quota-fetch)" # era claude-quota (la barría #220) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 210 | FECHA/TRAZA | # Espeja la lógica de install.ps1 (fix #67, Windows): si `claude` no está en el PATH pero YA existe | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 211 | INCIDENTE,NOMBRE PROPIO | # en ~/.local/bin (caso real de Felipe), solo hay que exponer el PATH; si no existe, se instala con | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 292 | DRAMA | # CRÍTICO: sin quitar el quarantine, Gatekeeper bloquea un .app bajado (ad-hoc signed). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 301 | FECHA/TRAZA | # --- Guard de staleness (C4): el .app bajado puede ir DETRÁS de HEAD si el runner de | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 305 | FECHA/TRAZA | # aquí a un fallback REAL a --build (Windows solo avisa, ver docs/reaudit-ola1-2026-09-01.md). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 336 | FECHA/TRAZA,INCIDENTE | # el widget NO volvía (bug real, 2026-07-18). launchd es scriptable e idempotente; un login item | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 352 | FECHA/TRAZA,INCIDENTE | # actualizar seguías viendo el widget anterior en memoria (bug real, 2026-07-15). | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |

### install.sh (12)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 33 | FECHA/TRAZA | OLD_PLASMOID_ID_BRAIN="io.github.unjordi.claude-brain" # era intermedia (rename claude-brain→cortex, #312) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 38 | FECHA/TRAZA | # Config del widget: con el rebrand COMPLETO (2026-07) pasó a ~/.config/cortex (el código lee | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 139 | FECHA/TRAZA | # claude-brain→cortex (#312) renombró MECÁNICAMENTE el string del old_marker a | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 144 | FECHA/TRAZA | "# claude-brain: ~/.local/bin en el PATH (claude, claude-quota-fetch)" # era claude-quota (la barría #220) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 405 | FECHA/TRAZA | # ── "Borra el previo por completo" (regla 2026-07-15). Idempotente / fail-safe. ── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 416 | FECHA/TRAZA | # ── Barre la era INTERMEDIA 'claude-brain' (rename claude-brain → cortex, #312). Idempotente/fail-safe. ── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 417 | FECHA/TRAZA | # El #312 renombró todo a 'cortex' pero NO dejó barrido de la era 'claude-brain': quien la tenía quedaba | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 420 | FECHA/TRAZA | echo "==> Eliminando cualquier instalación previa 'claude-brain' (era intermedia del rename a cortex)" | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 533 | FECHA/TRAZA | # claude-quota-widget (era vieja-vieja) y claude-brain (era intermedia del rename #312). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 549 | FECHA/TRAZA,INCIDENTE | # OJO (bug real, 2026-07-24): `kpackagetool6 -u` sobre un plasmoide CARGADO EN VIVO puede tumbar | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 562 | INCIDENTE | # → si kstart faltaba, el fallback jamás corría y plasmashell quedaba MUERTO (bug real en | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 563 | FECHA/TRAZA | # CachyOS, 2026-07-18: el update cerró Plasma y no lo levantó). Ahora: candidato elegido con | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### src/plasmoid/contents/ui/main.qml (12)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 972 | FECHA/TRAZA | detail: "Candado ÚNICO del punto de merge (2026-09-17, consolida a los antiguos merge-squash-guard + confirmar-merge-develop). Un `gh pr merge`/`glab  | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1017 | FECHA/TRAZA | detail: "Al terminar un turno, vuelca los PENDIENTES del TaskList vivo de la sesión a un bloque fenced dentro de .claude/memory/estado-proyecto.md (de | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1023 | INCIDENTE | detail: "Antes de un git destructivo (reset --hard, rebase, checkout -f, branch -D) que podría orfanar commits sin pushear en el árbol de trabajo, avi | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 1111 | FECHA/TRAZA | { emoji: "🕹️", name: "control-gui-remota-por-ssh", desc: "ver/operar una GUI remota por SSH sin VNC/RDP — screenshot/click/teclado DPI-aware; Windows· | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1113 | FECHA/TRAZA,NOMBRE PROPIO | detail: "Ver y operar el escritorio de una máquina remota por SSH puro (sin VNC/RDP): screenshot, clicks, teclado, inspección de ventanas/controles, p | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1116 | NOMBRE PROPIO | detail: "Muda una sesión master COMPLETA de Claude Code a otro repo (caso canónico: los brain-master a cortex) sin dejar nada a medias: transcript re- | REESCRIBIR a termino generico (usuario/maquina/host) |
| 1119 | FECHA/TRAZA | detail: "Despierta (o lista) una sesión master de Claude Code resolviéndola desde los transcripts: último customTitle = nombre, último cwd = dónde res | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1218 | FECHA/TRAZA | // emite en `grupos` — #148: la última cara que se repetía a mano. Ya no se hardcodean aquí ni en la | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1357 | FECHA/TRAZA | // (señal de "te quedaste en el rename #312"), luego el canónico. Mismo orden que Updater.swift/.cs. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1390 | DRAMA | // origin/main en vez de `merge --ff-only`, que fallaba PARA SIEMPRE si el clon quedaba en una | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1594 | FECHA/TRAZA | // Altura: 24 gridUnit (~432px con el gridUnit ~18px de Breeze). Antes era 17 → el popover | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2109 | INCIDENTE | // corta el texto (lección de hoy) → no se hace. | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |

### src/term-broker/PROCEDENCIA.md (12)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 3 | FECHA/TRAZA | > ## ✅ DIVERGENCIA SALDADA (2026-09-09) — el endurecimiento de auditoría ya vive en axon | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 5 | CITA,NOMBRE PROPIO | > unjordi: "cortex es frontera compartida, arréglalo; merge sin squash para que axon lo vea completo"), | BORRAR la cita; dejar solo el contrato |
| 6 | FECHA/TRAZA | > lo que hizo divergir esta copia de su fuente. **axon ya PORTÓ los 4 fixes a su fuente** (PR #151, en su | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 9 | NOMBRE PROPIO | > sigue sin tocarse — lo mejora unjordi aparte. | REESCRIBIR a termino generico (usuario/maquina/host) |
| 14 | FECHA/TRAZA | queda registrada abajo porque explica QUÉ hacer al re-vendorizar: [Divergencia vs axon](#divergencia-vs-axon--saldada-2026-09-08). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 25 | FECHA/TRAZA | **Commit de origen:** `2d8adae` (`origin/develop` de axon, 2026-09-15) — re-vendorizado para traer el | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 28 | FECHA/TRAZA | (axon #197). **Un pin siempre a un commit de una rama permanente** (por eso a `develop`, no a la rama de | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 30 | FECHA/TRAZA | anti-drift de abajo). Antes fue `1079574` (2026-09-09), `3a82d76`, `44f463d` y `ed482fb` (los tres del 2026-09-09), y antes `341fb53` (2026-09-07), re | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 31 | FECHA/TRAZA | `cf840e6` para traer el **socket unix** (`fix/term-broker-alcanzable`, #75): un cliente en | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 43 | FECHA/TRAZA | ## Divergencia vs axon — SALDADA (2026-09-08) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 88 | FECHA/TRAZA | 2026-09-09 esto **ya no es solo una receta a mano**: el `probe-instalador.sh` lo corre en su **bloque I** | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 184 | FECHA/TRAZA | 2026-09-04, `buildSessionEnv`) no llega solo a cortex — hay que re-vendorizar. El `diff` de arriba | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### src/term-broker/term-host-broker.ts (9)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 13 | NOMBRE PROPIO | // (unjordi), y expone un endpoint que ejecuta comandos con SU shell de LOGIN desde SU $HOME — igual que una | REESCRIBIR a termino generico (usuario/maquina/host) |
| 28 | FECHA/TRAZA | // ⚠️ CORRECCIÓN DE DOC (2026-09-07) — el comentario que vivía aquí AFIRMABA que el bind a loopback era | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 33 | FECHA/TRAZA,INCIDENTE | // Medido el 2026-09-07 en esta máquina: bindear al gateway de la red de compose (172.23.0.1) TAMPOCO basta | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 38 | NOMBRE PROPIO | // broker (unjordi). Aceptable en este scope (socket local + token secreto compartido solo con el contenedor | REESCRIBIR a termino generico (usuario/maquina/host) |
| 88 | FECHA/TRAZA,INCIDENTE | * hablándole a un inodo muerto. Medido el 2026-09-07: con el archivo montado, tras recrear el socket el | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 118 | NOMBRE PROPIO | /** Listener TCP en `bind:port` — para clientes NATIVOS del host (el `axon` de la terminal de unjordi). */ | REESCRIBIR a termino generico (usuario/maquina/host) |
| 142 | FECHA/TRAZA | /** Compara el token recibido contra el configurado en TIEMPO CONSTANTE (#4, auditoría 2026-09-09). Se hashea | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 214 | FECHA/TRAZA | // Slowloris/half-open en conexiones NO-upgradeadas (BAJO, auditoría 2026-09-09): un cliente que abre el | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 220 | NOMBRE PROPIO | // corre como el usuario del broker (unjordi), con SU shell de login y SU $HOME. Auth por el MISMO Bearer | REESCRIBIR a termino generico (usuario/maquina/host) |

### windows/src/Cortex/PopupForm.cs (9)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 25 | FECHA/TRAZA | // para darles el MISMO realce de hover que las pestañas (antes eran hover-less). Paridad macOS/KDE. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 105 | FECHA/TRAZA | // 4 Chats · 5 Cerebro. Chats se OCULTA del riel si no hay chats locales (como macOS #77), pero | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1978 | FECHA/TRAZA | "Candado ÚNICO del punto de merge (2026-09-17, consolida a los antiguos merge-squash-guard + confirmar-merge-develop). Un `gh pr merge`/`glab mr merge | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2020 | FECHA/TRAZA | "Al terminar un turno, vuelca los PENDIENTES del TaskList vivo de la sesión a un bloque fenced dentro de .claude/memory/estado-proyecto.md (determinis | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2026 | INCIDENTE | "Antes de un git destructivo (reset --hard, rebase, checkout -f, branch -D) que podría orfanar commits sin pushear en el árbol de trabajo, avisa —no b | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 2108 | FECHA/TRAZA | new("🕹️", "control-gui-remota-por-ssh", "ver/operar una GUI remota por SSH sin VNC/RDP — screenshot/click/teclado DPI-aware; Windows·Linux·Mac complet | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2110 | FECHA/TRAZA,NOMBRE PROPIO | "Ver y operar el escritorio de una máquina remota por SSH puro (sin VNC/RDP): screenshot, clicks, teclado, inspección de ventanas/controles, portapape | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 2113 | NOMBRE PROPIO | "Muda una sesión master COMPLETA de Claude Code a otro repo (caso canónico: los brain-master a cortex) sin dejar nada a medias: transcript re-anclado  | REESCRIBIR a termino generico (usuario/maquina/host) |
| 2116 | FECHA/TRAZA | "Despierta (o lista) una sesión master de Claude Code resolviéndola desde los transcripts: último customTitle = nombre, último cwd = dónde resumir, mt | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### windows/install.ps1 (8)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 8 | FECHA/TRAZA | # available (C4, docs/reaudit-ola1-2026-09-01.md) -- otherwise it just warns and keeps the stale exe. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 69 | FECHA/TRAZA | # Migracion desde los nombres viejos: si un install previo dejo 'ClaudeQuota' (era vieja-vieja) o | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 70 | FECHA/TRAZA | # 'ClaudeBrain' (era intermedia del rename #312), quita su autostart y su carpeta para no quedar con | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 78 | FECHA/TRAZA | # "Borra el previo por completo" (regla 2026-07-15): NO migramos el cache de los nombres viejos; los | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 80 | FECHA/TRAZA | # 'claude-quota' (era vieja-vieja) y 'claude-brain' (era intermedia del rename #312). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 141 | FECHA/TRAZA | # C4 (docs/reaudit-ola1-2026-09-01.md): la mitigacion previa (commit cf0a5285) solo | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 242 | FECHA/TRAZA | Remove-Item (Join-Path $startMenu 'Claude Brain.lnk') -ErrorAction SilentlyContinue # era intermedia claude-brain (#312) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 276 | INCIDENTE | # (Caso real: Windows "Asistente Dir": la app tapaba a la CLI de .local\bin en el PATH -> OAuth sin | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |

### macos/Sources/Cortex/PopoverView.swift (7)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 1339 | FECHA/TRAZA | "Candado ÚNICO del punto de merge (2026-09-17, consolida a los antiguos merge-squash-guard + confirmar-merge-develop). Un `gh pr merge`/`glab mr merge | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1383 | FECHA/TRAZA | "Al terminar un turno, vuelca los PENDIENTES del TaskList vivo de la sesión a un bloque fenced dentro de .claude/memory/estado-proyecto.md (determinis | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1389 | INCIDENTE | "Antes de un git destructivo (reset --hard, rebase, checkout -f, branch -D) que podría orfanar commits sin pushear en el árbol de trabajo, avisa —no b | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 1475 | FECHA/TRAZA | BrainItem("🕹️", "control-gui-remota-por-ssh", "ver/operar una GUI remota por SSH sin VNC/RDP — screenshot/click/teclado DPI-aware; Windows·Linux·Mac c | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1477 | FECHA/TRAZA,NOMBRE PROPIO | "Ver y operar el escritorio de una máquina remota por SSH puro (sin VNC/RDP): screenshot, clicks, teclado, inspección de ventanas/controles, portapape | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 1480 | NOMBRE PROPIO | "Muda una sesión master COMPLETA de Claude Code a otro repo (caso canónico: los brain-master a cortex) sin dejar nada a medias: transcript re-anclado  | REESCRIBIR a termino generico (usuario/maquina/host) |
| 1483 | FECHA/TRAZA | "Despierta (o lista) una sesión master de Claude Code resolviéndola desde los transcripts: último customTitle = nombre, último cwd = dónde resumir, mt | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### src/term-broker/ws.ts (7)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 36 | INCIDENTE | // dentro de un PTY llenó 24 MiB en menos de 3 s (medido con `probe-topes.ts` contra el código previo). | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 56 | FECHA/TRAZA | * conexión por half-open (#2, auditoría 2026-09-09). Generoso: un cliente lento-pero-vivo drena ALGO y | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 137 | FECHA/TRAZA | /** Suma de bytes acumulados en la fase de fragmentación (frames CONT). Cota anti-OOM (auditoría 2026-09-09, | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 409 | FECHA/TRAZA | // es barato y cierra una desviación de spec (L3, auditoría 2026-09-09). No aplica al rol cliente. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 443 | FECHA/TRAZA | // error de protocolo. (auditoría 2026-09-09) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 468 | FECHA/TRAZA | // mensaje con fragOpcode=0 (opcode inválido). (auditoría 2026-09-09) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 520 | FECHA/TRAZA | // L1 (auditoría 2026-09-09): Node entrega en `head` los bytes que ya leyó DESPUÉS del handshake (un peer | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### src/term-broker/term-session.ts (6)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 12 | CITA,FECHA/TRAZA,NOMBRE PROPIO | // un "ejecutor de comandos", no una sesión de shell de verdad (unjordi, 2026-09-04: `cd /etc` seguido | BORRAR la cita; dejar solo el contrato |
| 30 | FECHA/TRAZA,INCIDENTE | // PATH incompleto (bug real, 2026-09-04): el shell de la sesión es LOGIN (`-l`) pero NO interactivo — su | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 34 | CITA,NOMBRE PROPIO | // (u otro bin de usuario) al PATH en `.zshrc` — como hace unjordi (`case ":$PATH:" in ... esac` en su | BORRAR la cita; dejar solo el contrato |
| 71 | NOMBRE PROPIO | // viven en el login shell real de unjordi (verificado: ANTHROPIC_API_KEY vacío en su zsh -l) y CAMBIAN el | REESCRIBIR a termino generico (usuario/maquina/host) |
| 226 | FECHA/TRAZA | // #3 (auditoría 2026-09-09): decodificar CADA chunk con `b.toString("utf8")` por separado corrompía un | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 270 | FECHA/TRAZA | // real axon #197 (el widget del broker daba "[ SIN DATOS ]" por mandar `exec bash helper` a pelo). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### src/term-broker/pty-session.ts (5)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 25 | FECHA/TRAZA | // VIVO (2026-09-04): el hijo ve `/dev/pts/N` como tty, `stty size` correcto, Ctrl-C interrumpe (exit 130). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 95 | FECHA/TRAZA | // ── Reintentos del resize (FMEA 2026-09-08) ──────────────────────────────────────────────────────────── | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 174 | FECHA/TRAZA | // #29(a) necesita: N terminales simultáneas son N colas independientes sobre su propio pts. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 237 | DRAMA | // tamaño nuevo PARA SIEMPRE. El frontend tampoco lo salva: marca `sent` sin ACK, así que no | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 262 | FECHA/TRAZA | // Aún buscando el marcador: acumula y busca A NIVEL BYTE. L2 (auditoría 2026-09-09): se ITERA sobre los | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### windows/uninstall.ps1 (4)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 14 | FECHA/TRAZA | # nombres viejos del cache (migracion): 'claude-quota' (era vieja-vieja) y 'claude-brain' (era intermedia | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 15 | FECHA/TRAZA | # del rename #312) -> se limpian igual por si un install previo los dejo. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 25 | FECHA/TRAZA | Remove-ItemProperty -Path $runKey -Name 'ClaudeBrain' # era intermedia (migracion) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 31 | FECHA/TRAZA | Remove-Item (Join-Path $startMenu 'Claude Brain.lnk') -Force # era intermedia (#312) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### bin/session-lib.js (3)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 6 | FECHA/TRAZA | * Modelo de almacenamiento (verificado 2026-07-23 leyendo el CLI v2.1.218): | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 13 | NOMBRE PROPIO | * reanude coherente (una ruta Mac /Users/... no existe en Cachy /home/... ni Windows C:\...). | REESCRIBIR a termino generico (usuario/maquina/host) |
| 521 | FECHA/TRAZA | // silencio y sin que nada lo asevere. Con dos masters vivos (medido 2026-09-10: una mudanza y un | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### bootstrap.ps1 (3)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 17 | FECHA/TRAZA,INCIDENTE | # "running scripts is disabled on this system" (caso real del onboarding, 2026-07-10). | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |
| 28 | FECHA/TRAZA | # borra, se REUBICA. La era intermedia 'claude-brain' vivia en %LOCALAPPDATA%\claude-brain-repo (oculto) | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 30 | FECHA/TRAZA | # el remote a cortex; si $dir ya existe, borra el huerfano. Idempotente/fail-safe. (El #312 renombro el | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### bootstrap.sh (3)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 24 | FECHA/TRAZA | # era intermedia 'claude-brain' vivía en ~/.claude-brain (oculto) o ~/claude-brain (visible, pre- | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 25 | FECHA/TRAZA | # ocultamiento 2026-07-15). Si existe y $DIR aún no, muévelo y reapunta el remote a cortex; si $DIR ya | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 26 | FECHA/TRAZA | # existe, borra el huérfano. Idempotente/fail-safe. (El #312 renombró el OLD_DIR mecánicamente a | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### macos/README.md (3)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 60 | DECORACION | ┌────────────────────────────────┐ | BORRAR caja/banner |
| 67 | DECORACION | ┌────────────────────────────────┐ │ | BORRAR caja/banner |
| 68 | DECORACION | │ 2. Cortex Widget.app │────────────┘ | BORRAR caja/banner |

### macos/Sources/Cortex/Updater.swift (3)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 30 | FECHA/TRAZA | /// El escape REAL para una máquina que no puede auto-actualizar (build vieja sin fallback #322, | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 38 | FECHA/TRAZA | /// (~/.claude-brain) porque es la señal de que el usuario cayó en el rename #312 sin migrar; si no | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 155 | DRAMA | // fallaba PARA SIEMPRE si el clon quedaba en una rama leftover o con commits locales, dejando el | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### src/widget-spec/probe-knobs-spec.sh (3)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 9 | FECHA/TRAZA | # endurecimiento del 2026-09-09 y ninguna GUI se enteró — porque no había nada que lo notara. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 99 | FECHA/TRAZA | # SOLO aquí desde #148; este candado evita que un knob caiga en un grupo sin título, o que sobre | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 115 | FECHA/TRAZA | # veces y que el mapa de títulos sobrescriba en silencio (hallazgo de la 7ª tupla auditora, 2026-09-09). | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### macos/make-app.sh (2)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 13 | DRAMA | # Regenera SIEMPRE el ícono desde el SVG (assets/icon.svg). Es barato (rsvg) y CRÍTICO: si solo se | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 15 | INCIDENTE | # se quedaría pegado y se instalaría el ícono viejo — bug real del rebrand a Cortex. Si make-icon | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |

### macos/uninstall.sh (2)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 58 | FECHA/TRAZA | # Barre la era INTERMEDIA 'claude-brain' (rename claude-brain → cortex, #312) por si quedó atrás: | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 60 | FECHA/TRAZA | # fetch de la era vieja; los helpers compartidos de ~/.local/bin NO se tocan. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### scripts/qa-andamio.py (2)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 5 | FECHA/TRAZA | Mide contra el transcript REAL y CONGELADO de la sesion del 2026-09-11 (40 082 lineas, 193 MB, | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 124 | FECHA/TRAZA | print('\n=== QA DEL ANDAMIO · contra el transcript real del 2026-09-11 ===') | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### src/systemd/cortex-term-broker.service (2)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 45 | FECHA/TRAZA | # 2026-09-07 al montar el ARCHIVO en vez del directorio. | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 58 | INCIDENTE | # SESIONES REALES del usuario (medido en la unidad de hoy: 3.4 GB en uso, pico de 56 GB). Un | REESCRIBIR sin narrar el incidente (mover a memoria/bitacora) |

### uninstall.sh (2)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 86 | FECHA/TRAZA | # Barre la era INTERMEDIA 'claude-brain' (rename claude-brain → cortex, #312) por si quedó atrás: | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 87 | FECHA/TRAZA | # units, fetch, plasmoid, cache/config. Idempotente/fail-safe. SOLO el fetch de la era vieja; los | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### windows/src/Cortex/Updater.cs (2)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 31 | DRAMA | /// `merge --ff-only` fallaba PARA SIEMPRE si el clon quedaba en una rama leftover o con commits | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |
| 287 | DRAMA | // en vez de `merge --ff-only`, que fallaba PARA SIEMPRE si el clon quedaba en una rama leftover | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### bin/claude-session (1)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 3 | NOMBRE PROPIO | # `claude --resume <id>` en OTRA máquina (Mac↔Cachy↔Windows). Envoltorio de session-export.js / | REESCRIBIR a termino generico (usuario/maquina/host) |

### bin/session-export.js (1)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 4 | NOMBRE PROPIO | * `claude --resume` en OTRA máquina (Mac↔Cachy↔Windows). Es opt-in: solo las sesiones que marcas. | REESCRIBIR a termino generico (usuario/maquina/host) |

### bin/session-import.js (1)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 9 | NOMBRE PROPIO | * diferir de la máquina de origen: /Users/u/... en Mac vs /home/u/... en Cachy vs C:\... en | REESCRIBIR a termino generico (usuario/maquina/host) |

### bin/sessions-extract.js (1)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 36 | CITA,NOMBRE PROPIO | // El estilo real de unjordi abre con "holaaaaaa" / "hola! …" + un ritual de "carga memorias, | BORRAR la cita; dejar solo el contrato |

### justfile (1)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 49 | FECHA/TRAZA | # ⚠️ TRAMPA (medida en vivo 2026-09-09): la superficie de plasmoidviewer NO REPINTA cuando su | REESCRIBIR a regla en presente; mover fecha/origen a bitacora |

### windows/README.md (1)

| linea | categorias | texto | propuesta |
|---|---|---|---|
| 44 | DECORACION | ┌───────────────────────────────────────────────┐ | BORRAR caja/banner |

## Archivos LIMPIOS (sin candidatos tras filtrar identificadores)

- bin/chats-extract.js
- bin/cortex-term-broker
- bin/dot2yed.py
- bin/migrar-term-broker.sh
- bin/mmd2dot.py
- bin/session-move.js
- macos/.gitignore
- macos/Package.swift
- macos/Resources/Info.plist
- macos/Sources/Cortex/AppDelegate.swift
- macos/Sources/Cortex/BrainInspector.swift
- macos/Sources/Cortex/BrandIcon.swift
- macos/Sources/Cortex/PillImage.swift
- macos/Sources/Cortex/QuotaModel.swift
- macos/Sources/Cortex/main.swift
- macos/bin/cortex-fetch
- macos/justfile
- macos/launchd/com.local.drift-flotilla.plist
- macos/launchd/io.github.unjordi.cortex.plist
- macos/make-icon.sh
- macos/set-icon.swift
- macos/tools/indicador-preview/main.swift
- macos/tools/indicador-preview/render.sh
- macos/tools/indicador-preview/stubs.swift
- src/README.md
- src/bin/cortex-fetch
- src/plasmoid/contents/brain-scan.sh
- src/plasmoid/contents/broker-knobs.sh
- src/plasmoid/contents/broker-knobs.tsv
- src/plasmoid/contents/broker-scan.sh
- src/plasmoid/metadata.json
- src/systemd/cortex.service
- src/systemd/cortex.timer
- src/term-broker/SHA256SUMS
- src/term-broker/probe-broker-vivo.sh
- src/term-broker/probe-instalador.sh
- src/term-broker/probe-pty-ws.ts
- src/term-broker/probe-topes.ts
- src/term-broker/term-pty-bridge.ts
- src/widget-spec/broker-knobs.tsv
- src/widget-spec/probe-knobs-escritura.sh
- windows/.gitignore
- windows/make-ico.sh
- windows/src/Cortex/BrainInspector.cs
- windows/src/Cortex/BrandIcon.cs
- windows/src/Cortex/Cortex.csproj
- windows/src/Cortex/Format.cs
- windows/src/Cortex/Models.cs
- windows/src/Cortex/Program.cs
- windows/src/Cortex/QuotaService.cs
- windows/src/Cortex/RenameDialog.cs
- windows/src/Cortex/StatsCompute.cs
- windows/src/Cortex/SyncService.cs
- windows/src/Cortex/TrayIconRenderer.cs
- windows/src/Cortex/app.manifest