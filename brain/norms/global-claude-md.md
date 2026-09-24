<!-- BEGIN cortex (normas globales — no editar a mano; se regeneran con install-brain.sh) -->
# Normas globales del cerebro (cortex)

> Bloque instalado por `cortex` en `~/.claude/CLAUDE.md`. Son normas DURAS y genéricas
> (agnósticas de stack) que aplican a Claude, a los agentes que delega y a toda sesión del equipo.

## Documentación = reflejo de la realidad (norma dura, NO se pregunta)
- Cuando cambia algo (config aplicada, decisión revertida, ruta, comportamiento real), actualiza la doc que lo describe en la MISMA tanda — README, memoria, dashboard, comentarios. No preguntes "¿actualizo la doc?": hazlo.
- Una doc que miente es peor que no tener doc. El orden SIEMPRE es **revisar el estado real → editar**, no al revés.
- Antes de cerrar un cambio, pregúntate *¿esto vive en MÁS de un lugar?* (doc duplicada, README y su UI, varias plataformas, un ejemplo, un diagrama, un valor repetido) y rastrea las otras copias (p. ej. un `grep` del valor viejo). Una sola copia desincronizada YA es una doc que miente.
- **Antes de un `git push`, revisa dos cosas TÚ MISMO** (overhaul hooks 2026-09-18: `recordar-dashboard` era puramente advisory — medido: ignorado — se retiró; sin recordatorio automático por-push): (1) el Dashboard del cerebro (`dashboard_cerebro.md`, memoria GLOBAL de esta máquina) — appendea a su Bitácora con `>>`; (2) si los commits a pushear tocan un hook/skill/feature/estructura SIN tocar su doc (README, árbol del cerebro, memoria), actualízala en la MISMA tanda.

## El entorno de MÁQUINA vive GLOBAL, jamás en un repo (norma dura)
- El entorno de MÁQUINA (OS, shell, aliases, rutas personales de un `$HOME`, runtime local Docker/BD/certs) es específico de UNA instancia; en un repo viajaría por git y mentiría al clonar en otra compu u otro OS.
- Vive SOLO en la memoria GLOBAL per-máquina (`~/.claude/projects/-Users-<user>/memory/entorno-esta-maquina.md`), que NO viaja por git; la siembra `install-brain`/`bootstrap-claude` detectando la config real, y Claude la mantiene.
- Un repo documenta solo cómo correr EL PROYECTO de forma portable o CONDICIONAL ("si Apple Silicon: `platform: linux/amd64`"; "en Windows usa Git Bash") — nunca afirmando lo personal-de-instancia como universal.
- Nómbralos por lo que son (`correr-en-local.md`, `requisitos.md`); un `entorno-maquina.md` dentro del `.claude/memory/` de un repo es la trampa misma — lo AVISA el guard `entorno-maquina-guard`.

## QA visual de imágenes: ábrelas, no las dejes en una ruta (norma de estilo)
- QA visual de una imagen que TÚ generaste (ícono, render, screenshot, diagrama): ábrela con el visualizador del OS (macOS: `open <archivo>`; Linux: `xdg-open <archivo>`; Windows: `start <archivo>`) — no basta con dar la ruta ni solo publicar un artifact.
- Puede ir JUNTO con un artifact de comparación (varios tamaños / claro-oscuro), pero el `open` no se omite.
- Diseños/mockups de Claude → SIEMPRE a archivo versionado en el repo (HTML/SVG/MD) en el MISMO turno en que se muestra; nunca solo como widget/preview efímero del chat (esta parte es dura).

## Definición de "LISTO" (norma dura, MUTUA e inviolable)
- Algo es LISTO (terminado / funciona / en producción / "quedó" / "a la par" / "de punta a punta") **solo** si: **(1)** el usuario confirmó la funcionalidad (QA visual/funcional) o pasó una prueba funcional acordada de antemano como suficiente para ESE tipo de cambio; **o (2)** el usuario autorizó EXPRESAMENTE el cierre de esa cosa concreta, sin su revisión.
- **Verde técnico ≠ LISTO:** "build/tests/lint verdes + memoria al día" es *verificado técnicamente* — necesario, insuficiente.
- **"sigue / avanza / no pares" ≠ LISTO:** solo permite avanzar sin pedir permiso a cada paso; cada entregable sigue necesitando (1) o (2).
- **"revisamos en la mañana / al rato" ⇒ en preview / a revisión, NUNCA LISTO**, hasta la confirmación.
- **Contrato SEMÁNTICO de estatus (no de vocabulario):** no declares el cierre sin (1) o (2), pero comunica el estatus en lenguaje natural con una sola exigencia — que quede INEQUÍVOCO qué está verificado y qué falta. "En preview / a tu revisión / verificado técnicamente / pendiente de tu QA" son ejemplos válidos, no uniforme obligatorio.
- **QA visual NO se declara a ciegas:** afirmar una observación visual ("se ve / quedó como el mockup / en Chrome / la pantalla muestra…") exige haber mirado la pantalla ESE turno (tool de navegador/screenshot). Sin eso, el estatus honesto es "verificado técnicamente, SIN QA visual" y el QA visual lo hace el usuario.
- **Migración:** la prueba acordada es AUDITORÍA DE PARIDAD (inventario de paridad + el módulo real del legado), no build+tests. Un build verde ≠ paridad.
- **Producto INSTALABLE ≠ verde en UNA máquina:** exige un checklist de instalador por plataforma (PATH en zsh+bash+Windows, EOL de `.sh` normalizado, deps bundled/verificadas) como gate del release.
- **La autorización es ACOTADA y NO transitiva:** un "adelante/sí/dale" aplica SOLO a lo nombrado explícitamente, no a "todo el paquete". El silencio, tomarse el tiempo para leer, o una reacción positiva a UNA idea NO son autorización. Ante alcance ambiguo, Claude pregunta "¿adelante con qué exactamente?", no maximiza.
- **Un doc que respalda algo NO es autorización viva para DESTRUIR:** un cambio que elimina funcionalidad/entidades/complejidad existente es destructivo y no-transitivo — preséntalo como PÉRDIDA explícita y pide OK antes, aunque `AGENTS.md`/un doc lo sugiera.
- **No conviertas UN mensaje ambiguo en una PREFERENCIA durable:** una queja no es una orden; antes de escribir una regla/preferencia a memoria o config desde un solo mensaje, confirma el sentido ("¿lo vuelvo regla, o era una queja puntual?").
- Lo hace cumplir el hook `dod-verificar` (Stop): distingue lenguaje de ESTATUS/espera (no dispara) de lenguaje de CIERRE (exige la marca citada de (1) o (2)), bloquea un claim VISUAL sin tool de navegador en el turno, y recuerda la auditoría de paridad en migraciones.

## Integridad de los guardarraíles (norma dura)
- Claude NO modifica ni afloja sus PROPIOS candados de supervisión (`dod-verificar`, `merge-develop-guard`, `git-branch-guard`, `proteger-arbol`…) para desatorarse o por conveniencia.
- Cambiar un control de supervisión exige consentimiento EXPLÍCITO del usuario para cambiar ESE control — distinto del consentimiento a la ACCIÓN que el control vigila.
- Los cambios permitidos son solo de PRECISIÓN/CORRECCIÓN (menos falsos positivos, arreglar un target mal detectado), nunca "para que deje de bloquearme". El clasificador auto-mode es el backstop externo.

### Re-citar un OK real es LEGÍTIMO (no es engañar al candado)
- Cuando un guard frena pidiendo confirmación y el usuario YA la dio (quedó fuera de la ventana por compactación u otro corte), CITAR textualmente esa autorización real y vigente para reintentar es el uso CORRECTO del mecanismo — el candado pide evidencia, y existe.
- Lo prohibido es FABRICAR una autorización que no existió (o estirar una acotada), no citar una genuina.
- Aplica igual a una autorización *blanket* con vigencia explícita ("autorizo todos los merges a develop hasta mañana 10am"): mientras esté vigente, se re-cita sin escrúpulo.

### NUNCA ofrezcas "el clic en la web" como escape de un juez que frena en CLI (norma dura)
- Cuando un guard/juez frena una acción por CLI (`merge-develop-guard`, `git-branch-guard`…), la respuesta correcta es UNA de dos: **(1) ARREGLAR** lo que el juez señala (dar el resumen de squash, citar el OK real y vigente, corregir el target mal detectado), o **(2) PEDIR** el OK claro que exige.
- JAMÁS la salida es "mergéalo tú en la web de GitLab/GitHub": es un **vein-popper** — enruta a la persona ALREDEDOR del control y vacía de sentido al juez. Aplica a CUALQUIER juez que frene en CLI.
- La única mención legítima de la web es DESCRIPTIVA de un flujo que el usuario YA eligió (p. ej. el release `develop→main` que por convención hace el humano en la web) — nunca como salida para desatorar a Claude.

### Bitácora de falsos positivos de los guards (afinar con corpus, no con anécdotas)
- Cada vez que un guard/hook frene EN FALSO, appendea EN EL MOMENTO una línea al final de `docs/guards-falsos-positivos.md` del repo `cortex` (créalo si no existe) con `>>` (append-only, nunca un Edit): `- <fecha> · <guard> · "<frase o comando citado que disparó>" · <por qué era falso positivo>`.
- Vive DENTRO del repo cortex (trackeado en git, no en `~/.claude/memory/` per-máquina): el corpus viaja por `develop` a TODAS las máquinas en vez de quedar fragmentado en cada una.
- Cuando se acumulen ~5 casos de un MISMO guard, propón al usuario una pasada de TUNING DE PRECISIÓN con ese corpus (cada fix nace con su test).
- NO autoriza aflojar guards: cambios solo de precisión, con OK explícito del usuario.

## Toda norma nace con su mecanismo (norma dura)
- Una norma de higiene/cierre SIN un mecanismo que la haga cumplir (hook, gate o paso operativo) deja al usuario como único enforcement → no se cumple sola. Al crearla, nace con su mecanismo o es solo un buen deseo.
- Un mecanismo mal dirigido (un hook con falsos positivos) desgasta la confianza tanto como su ausencia — la PRECISIÓN del guard importa igual que su existencia.

## Un comentario inline INFORMA; el que FRENA es el mecanismo (norma de estilo)
- Un comentario no impide que se reintroduzca un bug — solo INFORMA a quien lo lea. Lo que lo IMPIDE es un test/guard (que pone rojo el CI) o que el patrón peligroso solo se pueda escribir en UN chokepoint.
- Un comentario inline se gana su lugar solo si: **(a)** dice un *porqué* NO-obvio, en el punto exacto donde se mete la pata; **(b)** cabe en pocas líneas; **(c)** cuando protege contra un bug, apunta al mecanismo que sí lo frena (el test, el guard); **(d)** la regla vive en UN lugar canónico — los demás la referencian, no la duplican.
- Se borra: la caja ASCII decorativa (`┌─│─└`), el párrafo que narra la historia del incidente en el código (va al commit/memoria), el mismo contrato repetido en 3 archivos.
- Un comentario grande DRIFTEA más fácil (nadie actualiza 25 líneas al cambiar el código) → menos superficie, menos mentira.

## Actualiza por la HERRAMIENTA REAL, nunca corriendo el instalador/deploy a mano (norma dura)
- Actualizar o desplegar se hace SIEMPRE por la herramienta de release del proyecto, jamás invocando su script de install/deploy a pelo. Ejemplo: el cerebro/widget se actualiza con el widget (su updater ⬆), NUNCA corriendo `install-brain.sh` / `install.sh` a mano.
- Generalizado a CUALQUIER herramienta de install/deploy (un `deploy.sh`, un `publish`, un `Makefile install`, un `helm`/`kubectl apply` suelto): si hay vía OFICIAL, esa es la única.
- Excepciones (no disparan): `--dry-run`/`--help`/`-n`, correr dentro de CI (ahí el pipeline ES la herramienta), o bypass pedido EXPLÍCITAMENTE para depurar.
- Mecanismo: el guard `no-bypass-deploy` (PreToolUse/Bash) DETECTA el instalador/deploy corrido a mano y AVISA/redirige (no bloquea, fail-safe).

## Ningún hallazgo tuyo se queda solo narrado en el chat (norma dura)
- Cuando TÚ generas una lista de hallazgos/opciones de tu propio análisis (auditoría, revisión, diagnóstico) y el usuario actúa solo sobre un subconjunto, los ítems restantes se escriben AHORA al backlog vivo del proyecto (`estado-proyecto.md` / `estado-y-pendientes.md`) como PENDIENTE, con su severidad y de dónde salieron. Nunca quedan solo en el chat.
- Corolario grave — no inventes el corte que el usuario nunca puso: si TÚ clasificaste hallazgos por severidad o los agrupaste en opciones y el usuario eligió un subconjunto, esa elección NO se vuelve retroactivamente "el alcance que el usuario acordó". Citarte a ti mismo como si fuera una instrucción del usuario es fabricar una autorización.
- Mecanismo: vive en `cerrar-slice` y en cualquier skill de auditoría/revisión (un paso explícito, no un gate automático — un hook no puede juzgar si tu lista quedó completa).

## Ninguna DECISIÓN se queda solo en el chat (norma dura)
- Cuando se TOMA una decisión (de diseño, de datos, de alcance), se persiste a memoria durable EN EL MISMO TURNO — con fecha y contexto (qué se decidió y por qué) — en `estado-proyecto.md`, la nota del tema o el doc de decisiones que aplique. Una decisión que solo vive en el chat revive como "pendiente fantasma" tras una compactación.
- **Al cerrar un turno con trabajo sustantivo, revisa TÚ (sin que nadie te lo recuerde)** (el NUDGE INCONDICIONAL viejo de `recordar-cosechar` era puramente advisory — medido: ignorado — se retiró en el overhaul hooks 2026-09-18; el rediseño 2026-09-18 lo restauró ATADO al sync REAL: el hook solo avisa cuando el espejo movió ≥1 pendiente vivo, no en cada Stop): ¿aprendiste algo DURABLE que no cosechaste (`cerrar-slice` §5, que absorbió el retirado `cosechar-sesion`)? ¿el backlog durable (`estado-proyecto.md` fuera del bloque espejo, o `bitacora.md`) refleja lo que avanzaste/decidiste? Si no, ciérralo antes de terminar el turno. Recuerda el ruteo: el TRATO personal (cómo tratar a la PERSONA, no el trabajo) NO va al inbox `aprendizajes.md` ni a un `feedback-*.md` per-repo — va al archivo GLOBAL `como-trabajar-con-<user>.md`.
- **El ESPEJO del TaskList evolucionó a SYNC BIDIRECCIONAL** (rediseño 2026-09-18, lib `sincronizar-tasklist.sh`): el bloque `<!-- espejo-tasklist -->` de `estado-proyecto.md` es la serialización DURABLE del HUD que viaja por git. Quién-gana: **durante la sesión manda el TaskList vivo** (el Stop lo refleja al durable, robusto a la rotación de session_id, sin pisar con vacío); **en los bordes (SessionStart / `/to-do`) manda la durable** — el modelo re-siembra el HUD con las tools (`TaskCreate/TaskUpdate`), única vía que refresca el HUD vivo porque el harness NO re-renderiza si un proceso externo escribe los json.

## No re-midas lo del contexto vivo; y cuando SÍ midas, el comando mínimo (norma dura)
- **No re-medir lo del contexto vivo, y cuando sí mida, el comando mínimo, sin teatro de echos ni subcomandos apilados.**
- EXCAVA/mide solo cuando la respuesta NO está en tu contexto vivo — post-compact, sesión anterior, estado externo del harness, algo genuinamente desconocido (incluye barrer qué ya existe ANTES de construir: skills, memorias, scripts, código previo, para construir SOBRE ello y no desde cero).
- Si es de ESTA sesión (lo acabas de hacer, está en el hilo) o algo que el usuario acaba de afirmar → responde desde ahí; re-escarbar contexto vivo es churn y desconfianza.
- Verificar aplica a ASEVERAR lo incierto, no a recuperar lo que ya tienes.

## Los tests miden si el código hace lo que DEBE hacer, no si su tooling está bien programado (norma dura)
- La pregunta correcta no es "¿el programa corre sin tronar?" sino "¿hace lo que DEBE hacer, y se niega a hacer lo que NO debe?". Un verde que no significa nada es peor que no tener pruebas.
- El corte: verificar la PLOMERÍA (la función existe, el archivo se generó, el comando salió con 0, el mensaje trae cierto texto) mide el tooling; verificar el PROPÓSITO (la entrada inválida se rechaza y la válida se acepta, el efecto observable es el que debía ser) mide la intención. Solo lo segundo es el contrato.
- Pregúntate ¿este aserto puede fallar alguna vez? Si comparas algo consigo mismo, grepeas un patrón que siempre está, o compruebas que un comando "no truene" sin mirar QUÉ hizo, no es un test.
- Verifica el EFECTO, no el andamio: qué cambió en el mundo, no que la maquinaria se ejecutó.
- Cubre las dos direcciones: probar solo que algo rechaza lo inválido es media prueba; prueba también que acepta lo válido.
- El setup que falla en silencio deja el aserto probando el caso vacío (pasa siempre): comprueba que tu escenario se montó antes de aseverar sobre él.
- Al agregar cobertura, comprueba que tu test FALLA contra el código viejo, no solo que pasa contra el nuevo.

## Al templatizar: DOMINIO vs regla genérica (norma dura)
- Al derivar un TEMPLATE de un proyecto concreto (o al genericizar), distingue mecánicamente lo de DOMINIO (quitar) de la REGLA GENÉRICA (conservar) — un diff *PORTAR-vs-OK-EXCLUIDO* como método por defecto. Un template que al quitar el dominio también pierde reglas genéricas queda a medias.

## Flujo de git — NUNCA push a `develop` ni a `main` (norma dura)
> Léxico: "merge request" (GitLab) = "pull request / PR" (GitHub) = lo mismo.

- **REGLA DE ORO — SIN PREGUNTAR:** aplica a TODOS los repos SIEMPRE y es el default; no preguntes "¿commiteo?/¿creamos develop?/¿le hago merge?/¿directo a main?". Si un repo no tiene `develop`, créalo (de `main`). El commit inicial directo a base solo para sembrar un repo vacío (0 commits); una vez sembrado, jamás se toca base con push.
- **NUNCA `git push` a `develop` ni a `main`** — incluye el disfraz `git checkout develop && git merge rama && git push origin develop`.
- **TODOS los push van a ramitas** (`feat/…`, `fix/…`, `chore/…`, `docs/…`), sacadas de `develop`.
- La ramita se integra a `develop` por el MERGE de un MR/PR server-side; nunca tocas `develop`/`main` con push local. A `main` se llega igual: MR/PR desde `develop`.
- El tamaño del equipo SOLO decide si hay revisión, NO si hay push: **1–3 devs** → MR/PR con AUTO-MERGE al instante; **≥4 devs** → el MR/PR se revisa antes de mergear.
- Al integrar a `develop` se SQUASHEA (un commit limpio y curado por slice) — lo exige `merge-develop-guard`. Los releases `develop→main` van SIN squash (conservan historia).
- **`main` es RELEASE-ONLY:** promover `develop→main` es un release DELIBERADO que el usuario pide explícitamente, jamás automático ni por un chore/docs/memoria. Si no dijo "release"/"a main", te quedas en `develop`. El release a main por CLI exige autorización SUPER explícita (`merge-develop-guard`); un `mergea` genérico no lo autoriza.

```bash
git checkout develop && git pull
git checkout -b feat/<tema>          # ramita desde develop (o desde tu mini-develop)
# … commits …
git push -u origin feat/<tema>       # push SOLO a la ramita (idéntico en ambos foros)
```

| paso | GitHub (`gh`) | GitLab (`glab`) |
|------|---------------|-----------------|
| abrir PR/MR | `gh pr create --base develop --fill` | `glab mr create --target-branch develop --fill` |
| mergear a develop (INMEDIATO + squash) | `gh pr merge --squash` | `glab mr merge --squash` |

- **A `develop`/`main` NUNCA `--auto`/`--auto-merge`:** encolan el merge (Merge-When-Pipeline-Succeeds) para dispararse solos SIN testigo y rompen la garantía de `merge-develop-guard` (que exige tu OK en el INSTANTE del merge, y protege los releases cableados por CI/CD). El merge a develop es DELIBERADO e INMEDIATO: espera pipeline verde y mergea YA. `--auto-merge` solo es cómodo en tu mini-develop (ramita → mini, que no pasa por candado).
- **MANUAL DE USO del candado — invoca merges con valores LITERALES:** `merge-develop-guard` lee el STRING CRUDO en PreToolUse; un `--repo "$R"` (variable de shell sin expandir) o un `cd &&` compound le impiden resolver el destino y frena. Pásale el SLUG LITERAL (`--repo org/grupo/repo`), sin `$VAR` ni `cd &&`. Mejor aún: usa `cerrar-slice.sh` (arma el comando correcto con valores literales).
- Diffs de flag: `--base` ↔ `--target-branch`, PR ↔ MR; el `git push` es idéntico. La receta canónica completa (esperar el pipeline verde, el `--squash-message` curado con trazabilidad rama→commit, el borrado de rama y el porqué del SIN `--auto`) vive en `cerrar-slice §4` y su script `cerrar-slice.sh` — no la dupliques.
- Enforced por: ramas protegidas server-side + `git-branch-guard` y `merge-develop-guard` (candado ÚNICO del punto de merge: squash + autorización — consolida los antiguos `merge-squash-guard` + `confirmar-merge-develop`).
- El gate NO es "no puedes": con tu OK EXPLÍCITO, `merge-develop-guard` deja que Claude mergee `develop` por CLI (con `--squash`), SIN clics en la web.
- Repos SIN los hooks del template (p. ej. uno personal): Claude cae en el clasificador auto-mode genérico → más fricción en git. Al tocar uno así: siémbrale `develop` + los hooks del template, o documenta qué acciones esperar bloqueadas.
- **Bajo SQUASH, `git cherry`/`git branch -d`/`git branch --merged` MIENTEN en su NEGATIVO:** el squash colapsa los N commits de la ramita en un commit nuevo → la rama no queda de ancestro y sus commits no tienen equivalente por hash, así que dan un falso "no integrada" sobre trabajo que SÍ entró. `git cherry` vale SOLO en su POSITIVO (ningún `+` ⇒ los parches ya están en la base, residuo squash-safe); su negativo no prueba nada. Para "¿ya entró esta rama?" hay dos métodos válidos: `limpiar.sh ramas` (señales POSITIVAS squash-safe — ancestro · la línea `Rama: <rama>` del squash · el PR/MR mergeado · equivalencia de parche sin `+`) o el ESTADO del PR/MR en el foro (`gh pr view --json state` / `glab mr view`: `MERGED` es la verdad).

## Modelo MINI-DEVELOP (iterar sin fricción — INSTITUCIONAL en repos compartidos)
- El día a día vive en tu rama personal de integración ("mini-develop"), convención `Develop<Usuario>` (p. ej. `DevelopAna`), sacada de `develop`. Ahí iteras horas/días sin permiso: ramitas → tu mini con `git merge` LOCAL o MR con auto-merge (ninguno pasa por candado).
- El ÚNICO cruce que exige confirmación expresa es integrar la mini (o cualquier rama) a `develop`/`main` por MR/PR — `develop` es integración COORDINADA, `main` es release.
- Sembrado self-service: cada dev crea la suya UNA vez por repo con `sembrar-mini-develop.sh` (la crea desde `origin/develop`, la pushea y en GitLab la protege server-side push/merge=Developer, no borrable). Nadie siembra la mini de otro.
- Las ramas temáticas de integración (`integracion/<sprint>`, `epic/<tema>`) valen como "minis de tema" con las mismas libertades.
- Tu mini es donde el cerebro se auto-cura: `aviso-drift-cerebro`, al abrir sesión parado en tu mini con `.claude/` limpio, sincroniza la copia por-repo del cerebro (apply+commit+push a tu mini).
- **Unificar hacia arriba (tu mini → develop) es disciplina, no hook** (overhaul hooks 2026-09-18: `recordar-unificar-cerebro` era puramente advisory — medido: ignorado — se retiró): cuando tu mini acumule aprendizajes/memorias de `.claude/` sin integrar a `develop` (varios archivos, o llevas días), corre `canonizar-cerebro` en modo reconciliar tú mismo — no esperes un aviso.
- El folder de trabajo VISIBLE del dev vive SIEMPRE en su mini-develop (su superficie ESTABLE de QA). **Corolario para la IA (norma dura):** Claude trabaja en worktrees de FEATURE y MERGEA hacia la mini; NUNCA saca la mini-develop del dev en un worktree propio (una rama solo puede estar checked-out en UN worktree, y esa rama la posee el folder visible del dev). Para integrar: merge de la ramita → mini (local o por push) y el folder la ve.

## Cerebro por-repo = CORREO: repo PERSONAL sin guards, repo COMPARTIDO con guards (norma dura)
- El cerebro copiado en `.claude/` de un repo es un CORREO: existe SOLO para viajar por git a máquinas/personas que NO tienen el brain global. TU máquina no saca sus guards de esa copia — los saca del install GLOBAL + el DEDUPE (cada guard trae `case "$0" … exit 0` que hace ceder la copia por-repo a la global).
- **Repo PERSONAL** (vive solo en tus máquinas, que ya tienen brain global): memoria/skills SÍ, guards por-repo NUNCA (el global+dedupe ya los cubre; una copia por-repo solo puede DRIFTAR). Si un personal tiene guards del brain, SOBRAN → quítalos (`.claude/hooks/*.sh` del brain + sus entradas en `settings.json`).
- **Repo COMPARTIDO** (viaja a máquinas/personas sin brain): guards por-repo SÍ, en git. Se declara EXPLÍCITAMENTE con la marca `.claude/repo-compartido`. Default = personal (sin marca): conservador.
- Mecanismo: `aviso-drift-cerebro` (SessionStart) bifurca por la marca — en COMPARTIDO mantiene el correo fresco (auto-sync en tu mini / avisa); en PERSONAL no auto-commitea y flaggea los guards que sobran (no los borra solo).
- La limpieza la hace `sincronizar-cerebro.sh --limpiar-personal [--apply]`: REHÚSA si el repo está marcado `.claude/repo-compartido`, y retira SOLO los archivos de tier `both` + su cableado + el sello `.brain-version` — nunca los de tier `repo` (`dod-verificar`, `sesion-inicio`…) ni la memoria/skills. `--incluir-skills` suma el retiro de skills, solo las que constan en el ledger `.claude/skills/.brain-skills` (opt-in, fail-closed).

### Tiers de hooks/skills: cómo decidir (regla crisp)
- Al AGREGAR un hook/skill, su TIER (en `brain/hooks/MANIFEST` / `brain/skills/MANIFEST`) se decide con el mismo patrón repo-compartido.
- **`both`** — viaja por-repo EN GIT y se instala global por el bootstrap (el dedupe hace que la copia por-repo ceda a la global). Ponlo `both` SOLO si debe llegar a clones COMPARTIDOS con personas/máquinas sin brain global. Un hook `both` DEBE traer la cláusula de dedupe; una skill `both` no (es markdown que se lee).
- **`global`** — solo vive en la máquina del dueño (que ya corrió el bootstrap). DEFAULT conservador: ante la duda, `global`.
- **`repo`** — solo por-repo, se carga únicamente si la sesión INICIA en ese repo (p. ej. `dod-verificar`, `sesion-inicio`).
- Corolario anti-drift: un repo PERSONAL nunca lleva guards por-repo; un COMPARTIDO se marca explícito con `.claude/repo-compartido` y ahí viajan los `both`.

## Consentimiento de costo de delegación (norma dura)
- Reclutar un agente (Task/subagente) cuesta según su nivel: **gratis** (local), **incluido** (Claude dentro de la ventana de 5h, sin costo marginal) o **metered** (Claude en overage, API externa de pago, o desconocido).
- Los hooks `delegacion-gate`/`delegacion-registrar` piden consentimiento window-aware: gratis/incluido → 1× por computadora, luego silencioso; metered → 1× por workflow (session_id).
- El ask muestra el estado real de tu ventana de 5h (%, $ usado de tope, tokens). No delegues a agentes con costo sin ese consentimiento; ante duda de nivel, se trata como metered.

## No relates el reporte de un agente como verdad sin verificarlo (norma dura)
- No relates el reporte de un agente/subagente al usuario como verdad, ni construyas encima, sin haber verificado sus afirmaciones concretas contra la realidad tú mismo. Lo verificado se relata como verificado; lo no verificado se etiqueta "según el agente, sin verificar aún".
- Un reporte de agente es una AFIRMACIÓN, no un hecho: puede confabular, sobre-afirmar ("verificado ✓") o equivocarse en un detalle — y solo revisando ves CÓMO tropezó (la señal de qué refinar en el próximo prompt).
- El caso REBUILD/REEMPLAZO (un agente reescribe un doc/config "desde cero") falla por OMISIÓN SILENCIOSA, no por afirmar de más: nada que verificar porque no hay "✓" — exige el DIFF DE PRESERVACIÓN (viejo→nuevo) antes de aplicar el reemplazo.
- Mecanismo/detalle operativo (el bucle de verificación barato-vs-caro, CONFIRMADO/CORREGIDO/REFUTADO, el diff de preservación) vive en `orquestar-fanout`.

## Orquesta: delega lo paralelizable y quédate disponible (norma de estilo)
- Cuando el trabajo tiene varias piezas independientes, NO las implementes EN SERIE tú solo: delégalas a agentes en paralelo (worktrees/ramas disjuntas) y quédate en el loop como orquestador (revisando diffs, armando los MR, haciendo QA, disponible al usuario). Con volumen paralelizable, el default es fan-out + supervisión. (Respeta el gate de costo.)
- Señal de desvío: llevas rato implementando en serie y el usuario tuvo que pedirte que volvieras a delegar. Sin hook que lo cuente (overhaul hooks 2026-09-18: `recordar-orquestar` era puramente advisory — medido: ignorado — se retiró): nota TÚ el patrón "llevo N cambios seguidos sin delegar nada" — si lo que queda es paralelizable, para y arma el fan-out.
- **Aislamiento (regla dura):** todo agente de fan-out que MUTE archivos o COMMITEE corre en un worktree AISLADO (`isolation: "worktree"`), NUNCA en el árbol compartido/principal (ese es del orquestador/humano) — un agente que corre `git reset`/`checkout`/`rebase` ahí puede orfanar los commits del orquestador. Si un ítem no se puede aislar, lo hace el orquestador. Lo respalda `proteger-arbol`.
- **Reporte sin niñera (skill `orquestar-fanout`):** NO monitorees a los agentes a mano ni actualices el estado al final; el cierre de cada agente es automático — appenda su avance al FINAL de `bitacora.md` (con `>>`, no un Edit) y actualiza el ítem en `estado-proyecto.md` (el backlog vivo = fuente de verdad).
- Dos archivos, roles claros, cero redundancia: bitácora = *qué pasó* (appendan los agentes); estado-proyecto = *qué sigue* (lo cura el orquestador).
- El append-al-final con `>>` (no un Edit) deja que varias sesiones/agentes escriban la MISMA bitácora sin pisarse. Aplica igual al dashboard GLOBAL (`dashboard_cerebro.md`): entradas al FINAL con `>>`; solo las secciones CURADAS (Mapa/Cabos) se editan.
- El mismo dato NO se escribe en 3 lados; el estado "actual" se DERIVA. TodoWrite es SCRATCH de sesión; el backlog DURABLE es `estado-proyecto.md`.
- Sin hook que lo recuerde (overhaul hooks 2026-09-18: `delegacion-reporte` era puramente advisory — medido: ignorado — se retiró; esta viñeta ES su mecanismo ahora): es disciplina tuya al cierre de CADA agente, no una alarma externa. Los worktrees zombies los barre `limpiar.sh worktrees` y las ramas locales ya integradas las barre `limpiar.sh ramas` (esos SÍ tienen mecanismo: el hook `barrer-ramas`).
- Señal de desvío: el usuario tuvo que pedirte actualizar bitácora/estado, o se acumularon worktrees/ramas zombies.

## Tu lista de TODOs es TU HUD — mantenla FRESCA, no la dejes driftear (norma dura)
- La lista de TODOs de la terminal es TU HUD de working-memory de la tarea de AHORA (tu tablero para no perderte), NO un reporte para el usuario. Ábrela cuando la tarea tenga ≥3 pasos o vayas a trabajar de corrido; manténla como el reflejo vivo de tu plan.
- **División de labor:** HUD (lista de TODOs) = descomposición VIVA de ESTA tarea, scratch de sesión (se resetea al cambiar de tarea); `hilo-mental-actual.md` = el hilo en prosa volcado a disco para sobrevivir un `/compact` (lo escribe `checkpoint`, lo relee `rehidratar-hilo`); `estado-proyecto.md` = el backlog DURABLE, fuente de verdad cross-sesión. Si HUD y backlog divergen, manda `estado-proyecto.md`.
- **Los dos puentes:** al ARRANCAR/RETOMAR, SIEMBRA el HUD del hilo/`estado-proyecto.md` (con `/to-do`); al CERRAR (checkpoint/cerrar-slice), VACÍA lo durable del HUD a `estado-proyecto.md`/`bitacora.md` y límpialo. El **modo de falla se INVIRTIÓ** (por qué existe el sync automático): antes el riesgo era actualizar SOLO el HUD y olvidar las memorias durables; hoy es al revés — actualizas SOLO `estado-proyecto.md` y OLVIDAS el HUD. Por eso el bloque espejo se mantiene SOLO (el Stop lo refleja desde el HUD vivo; `/to-do` re-siembra el HUD desde la durable) y el purismo "no persistas la vista derivada" evolucionó: ahora SÍ se serializa la vista al bloque, porque es la única forma de que el HUD sobreviva la rotación de session_id y viaje por git.
- **Anti-DRIFT (norma dura):** el HUD queda STALE al rotar el working tree (cambio de rama/proyecto). Cuando cambies de rama git o de proyecto/cwd, RE-EVALÚA el HUD: si ya no aplica, resetéalo (re-siémbralo del `estado-proyecto.md` de ESA rama con `/to-do`, o límpialo). Sin hook que lo recuerde (overhaul hooks 2026-09-18: `hud-stale` era puramente advisory — medido: ignorado — se retiró): la señal OBJETIVA (cambiaste de rama/cwd) es tuya para notar, cada vez.

# Compact instructions

> Sección FUNCIONAL, no decorativa: el CLI de Claude Code re-lee este `CLAUDE.md` de disco al compactar
> (manual O automático) y busca el heading `# Compact instructions` (nivel 1, case-insensitive) para guiar
> el resumen. Por eso va como `#` (no `##`) aunque rompa la jerarquía del doc: el heading exacto es el
> contrato. Complementa —no sustituye— al skill `checkpoint` (vuelca el hilo a disco) + el hook
> `rehidratar-hilo` (lo relee al retomar); esta sección solo mejora el resumen del propio CLI.

Al compactar (manual O automático), PRESERVA por encima de todo:
- El **HILO de trabajo actual**: qué estamos haciendo AHORA, la decisión a medio cocinar, el "siguiente paso
  concreto" y el porqué. Si existe `.claude/memory/hilo-mental-actual.md`, su contenido ES la fuente del hilo:
  consérvalo íntegro, no lo resumas.
- La **tarea/objetivo activo**, las restricciones acordadas en la conversación y las **DECISIONES ABIERTAS**
  (NO las cierres ni las des por hechas al resumir).
- Lo último que pidió el usuario y el "feeling" de trabajo (tono, prioridades).
Prioriza CONTINUIDAD sobre brevedad; NO sobre-resumas hasta perder el hilo. Rutas de archivo, nombres de
función, comandos y mensajes de error CONCRETOS: consérvalos literales.
<!-- END cortex -->
