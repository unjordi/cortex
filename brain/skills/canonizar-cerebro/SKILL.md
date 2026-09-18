---
name: canonizar-cerebro
description: DUEÑO único del ciclo de vida del cerebro de un proyecto instanciado (cps, fluxcore, plantilladotnet…), con CUATRO modos sobre la MISMA maquinaria (el detector de firma `verificar-firma-canonica.sh` + el pull-del-canon `sincronizar-cerebro.sh --apply`). **Modo sembrar** — nace un cerebro nuevo, nativo en `<proyecto>/.claude/` (memoria/skills/settings), SIN symlinks. **Modo canonizar** — un cerebro instanciado drifteó (memorias sueltas sin prefijo, CLAUDE.md viejo, MEMORY.md plano): reprefija con `git mv`, dedup con rescate, reescribe CLAUDE.md+MEMORY.md a la firma-árbol, verifica 1:1. **Modo consolidar** — campaña amplia para dejarlo SÓLIDO y COMPACTO: la dupla de auditores → positivar → desinflar → loop de convergencia → cierre con la firma. **Modo reconciliar** — ritual SEMANAL que junta aprendizajes+memorias de las minis de los devs hacia develop sin perder atribución. Úsalo para CUALQUIER operación sobre el cerebro de un proyecto instanciado: sembrarlo, corregir su estructura, dejarlo compacto, o reconciliarlo entre devs.
---

# Canonizar un cerebro — el dueño único del ciclo de vida (4 modos, 1 maquinaria)

Un cerebro que cortex instancia (cps, fluxcore, plantilladotnet, los repos .NET del equipo) pasa por
**cuatro operaciones** a lo largo de su vida, y las cuatro comparten la MISMA idea de "correcto" (la
firma canónica) y la MISMA maquinaria (el detector + el pull-del-canon). Antes vivían como CUATRO
skills separados (`canonizar-cerebro`, `consolidar-cerebro`, `unificar-cerebro`,
`claude-proyecto-autocontenido`) que divergían entre sí — dos de ellos llegaron a especificar la MISMA
firma canónica con plantillas DISTINTAS. Este skill es el dueño único; los cuatro modos son:

| modo | cuándo | qué hace | antes vivía en |
|---|---|---|---|
| **sembrar** | proyecto nuevo, o cerebro disperso (global + repo a medias) | deja el cerebro NATIVO en `<proyecto>/.claude/`, sin symlinks | `claude-proyecto-autocontenido` |
| **canonizar** | el cerebro YA vive en el repo pero drifteó de la estructura | reprefija memorias, reescribe CLAUDE.md+MEMORY.md, verifica 1:1 | (núcleo de este skill) |
| **consolidar** | el cerebro está sano estructuralmente pero abrumador/inflado | dupla de auditores → positivar → desinflar → converge → cierre | `consolidar-cerebro` |
| **reconciliar** | ritual semanal: minis de devs acumularon aprendizajes/memorias | junta el delta de `.claude/` de cada mini hacia `develop` | `unificar-cerebro` |

**La maquinaria común** (evita que los 4 modos re-especifiquen "qué es correcto" cada uno a su manera):
- **El detector de firma** — `brain/verificar-firma-canonica.sh [ruta] [--strict]` — verifica el 1:1 de
  la firma canónica (ver abajo). Lo corren canonizar (Paso 7, el gate) y consolidar (Fase 6, el cierre).
- **El pull-del-canon** — `bash <cortex>/brain/sincronizar-cerebro.sh . --apply` — pone la copia por-repo
  del cerebro CANÓNICO (hooks/libs/skills de tier `both`) al día desde la fuente única. Lo corren sembrar
  (al nacer un repo) y reconciliar (Paso 1, para sacar el cerebro canónico del diff antes de subir memoria).

> **NO es un auto-mutador ciego.** Ningún modo reescribe cerebros automáticamente sin supervisión: el
> humano revisa el diff antes de integrar (salvo el modo reconciliar, que sí integra por MR con OK
> explícito — ver su sección). El valor es la vía SEGURA (git mv preserva historia, dedup con rescate, no
> inventar, doc=realidad) + los mecanismos que verifican.

## La firma canónica (el DESTINO — no la inventes, cópiala)
**Definición ÚNICA — vive AQUÍ, en ningún otro skill.** (Antes `consolidar-cerebro` la re-especificaba con
una plantilla distinta y ya habían divergido: un cerebro canonizado por su receta fallaba el detector de
éste. Ahora hay una sola fuente.) Definición-de-tipo-de-dato (LÉELAS antes de tocar):
`CLAUDE.example-barebones.md`, `MEMORY.example-barebones.md` y `como-trabajar-con-usuario.example-barebones.md`
del cortex. **Instancias canónicas de referencia:** `cps` y `fluxcore` (su `CLAUDE.md` +
`.claude/memory/MEMORY.md` ya cumplen — cópiales la FORMA, no el contenido).

- **`CLAUDE.md`** (raíz del repo) = **firma-árbol**, secuencia OBLIGATORIA:
  `🎯 Misión/identidad → 🧠 Antes de construir → 📁 Dónde va cada cosa → 🖋️ LA FIRMA (árbol de
  capacidades→artefactos, DENTRO de un bloque cercado ```) → 🛡️ Reglas duras → @import MEMORY.md`.
  ATEMPORAL (gradiente de estabilidad = como `main`): cero fechas, cero "RESUELTO/al día".
- **`MEMORY.md`** = **detalle 1:1** de la FIRMA + índice de memorias **agrupado POR PREFIJO**
  (`dom-` dominio · `dev-` desarrollo/infra · `ux-` diseño · `qa-` calidad · **núcleo** sin prefijo:
  `estado-proyecto` · `bitacora` · `aprendizajes` · `backlog-<tema>` · `hilo-mental-actual` ·
  `cementerio`). Answer-first: cada nota abre con su RESPUESTA y su ESTADO.
  **Ojo — `como-trabajar-con-<usuario>` NO es una memoria de repo:** es el manual de TRATO de una
  PERSONA → vive en la **memoria GLOBAL per-máquina** (`~/.claude/projects/<slug>/memory/`, la
  siembra `install-brain`), NUNCA en el `.claude/memory/` de un repo (viajaría por git y sería ruido
  para otro dev). No lo indexes en el `MEMORY.md` de un repo. Su barebones es
  `como-trabajar-con-usuario.example-barebones.md`.
- **Invariante 1:1:** cada memoria (salvo `*.local.md`) está indexada, y cada enlace del índice
  resuelve a un archivo real. Sección = prefijo = orden del folder → una sola taxonomía, cero drift.
- **`AGENTS.md`** (si existe) queda para la **ARQUITECTURA real** del proyecto — NO es la firma. Un cerebro
  SIN arquitectura pesada (hobby/meta) no necesita `AGENTS.md`. **Si el entry-point operativo REAL de hoy es
  OTRO archivo** (p. ej. games-master usa `AGENTS.md` como su "LEE ESTO ANTES DE HACER NADA"), canonizar lo
  MIGRA a la convención: su contenido OPERATIVO pasa a `MEMORY.md`, `CLAUDE.md` queda como su TOC, y `AGENTS.md`
  se reduce a la arquitectura real (o se retira). Migrar un cerebro **en uso** (un gold standard) es decisión
  deliberada del humano → se PARQUEA si está en uso.
- **GRADIENTE DE ESTABILIDAD (el PORQUÉ de que la firma sea atemporal):** `CLAUDE.md` = como `main` (solo
  estructural, muta casi nunca — solo si cambia la ESTRUCTURA) · `MEMORY.md` = como `develop` (el detalle;
  muta poco; tampoco fechas/estado *ni siquiera aquí*) · las memorias + `bitacora` + `estado-proyecto` = las
  ramitas (ahí vive TODO lo volátil: fechas, "RESUELTO 2026-…", historia, lápidas ⚰️). Así el `CLAUDE.md`
  **no se puede pudrir** → doc=realidad *por construcción*. En el **meta-repo** (cortex, cuya firma vive en el
  README y cuyo `.claude/memory/` no usa prefijos) el check NO es este detector sino
  `docs/flowcharts/verificar-arbol-sync.sh` (el bloque `ARBOL:START/END` cercado y sin fechas/RESUELTO/
  VERIFICADO); `verificar-firma-canonica.sh` auto-detecta el meta-repo y se salta (`n/a`).

## LA CERCA (reglas duras — leer ANTES de tocar, aplica a los 4 modos)
- **NO-DESTRUCTIVO por default.** Reprefijar/reescribir el índice/dedup-con-rescate/positivar/desinflar
  SÍ. **Borrar conocimiento NO** — cualquier fusión rescata primero los datos únicos; lo que borraría
  información se **PARQUEA** con la pregunta redactada para el humano.
- **`git mv`, nunca borrar-y-recrear.** Preserva la historia de cada memoria (blame/log siguen vivos).
- **Narrativa FECHADA intacta.** La `bitacora.md`, un "rehomeado de X el <fecha>", un "296 tests" de un
  slice puntual: son historia legítima, se quedan. Se corrigen los punteros VIVOS (wikilinks/md-links a
  nombres viejos), no la historia.
- **FIDELIDAD — no inventes.** Sin pipelines/entornos/datos que el proyecto no tenga verificados.
- **Aísla en worktree de feature** (o rama `chore/canonizar-cerebro`), commits granulares; el humano
  revisa el diff. Si el cerebro vive en folder no-git (Drive), snapshot `.bak` fuera del árbol sincronizado
  ANTES de mutar (o pausa el sync durante la pasada), mutaciones SECUENCIALES del orquestador.
- **Doc=realidad:** el orden es SIEMPRE **leer el estado real → editar**, nunca al revés.
- **Escaneo de secretos (BLOQUEO DURO) antes de commitear cualquier cosa nueva al repo** (típico del modo
  sembrar, cuando se consolida memoria dispersa): `grep -rinE` de keywords de alta señal
  (`pass(word|wd)?|secret|token|api[_-]?key|credential|credencial`) + valores de alta entropía asignados
  (`[:=][[:space:]]*["]?[A-Za-z0-9+/]{20,}={0,2}`). Un secreto real → el archivo es sensible, va a
  `*.local.md` o se redacta el valor; **nunca se commitea**. Verifica el `.gitignore` de VERDAD
  (`git check-ignore archivo.local.md` debe imprimir la ruta), no "se ve bien".
- **Si el repo ES la fuente del template** (produce el cerebro de otros, como `cortex` mismo): cualquier
  modo CONSOLIDA/CANONIZA SOLO el cerebro operativo del propio repo (`.claude/`), **JAMÁS el producto que
  envía** (`brain/`/la plantilla) — tocarlo lo propagaría a TODOS los clones. Leer `brain/` para entender
  la misión SÍ es lícito; mutarlo no.
- **La auditoría (modo consolidar) es READ-ONLY** sobre `.claude/`; los fixes van DESPUÉS por ramitas → MR
  con OK.

---

## MODO SEMBRAR — el cerebro nace NATIVO, sin symlinks
> ⚠️ **CERO SYMLINKS (decisión dura de unjordi, 2026-09-08: "NO quiero symlinks en ningún lado" — "son un
> pinche bug que no logro que dejen de propagar").** Este modo reemplaza al viejo skill
> `claude-proyecto-autocontenido`, que PRESCRIBÍA un symlink `~/.claude/projects/<slug>/memory` →
> `<repo>/.claude/memory`. Ese diseño quedó RETIRADO: los symlinks cuelgan al mover/borrar/renombrar el
> repo (rompían `/to-do` y cuanto leyera `.claude/memory`) y proliferaron (15 basura medidos en una sola
> máquina). **No lo repitas.** El criterio vigente es el de abajo.

**El criterio (en una frase).** El cerebro de Claude Code de cada proyecto vive **NATIVO** en la carpeta
del proyecto (`<proyecto>/.claude/{memory,skills,settings.json}`), leído directamente desde el `cwd` —
sin enlace de ningún tipo. Los HOOKS del cerebro (`sesion-inicio`, `rehidratar-hilo`) reinyectan
`MEMORY.md`/`estado-proyecto.md` relativos al `cwd`, no dependen de ningún slug. Solo el
`~/.claude/projects/<slug>/` propio de Claude Code (sus transcripts `.jsonl` + su auto-memory) queda
SEPARADO, como **directorio real o inexistente — NUNCA un symlink al repo**. Si uno ya existe de una
siembra vieja: `[ -L ~/.claude/projects/<slug>/memory ] && rm ~/.claude/projects/<slug>/memory` (borra
SOLO el enlace, sin `-r` ni slash final).

**Layout objetivo:**
```
<proyecto>/.claude/
├── settings.json          (compartible: permisos/hooks del proyecto)
├── settings.local.json    (local de la máquina; NO se comparte)
├── memory/                (MEMORY.md + las memorias del proyecto, archivos reales)
├── skills/                (SOLO skills específicas de ESTE proyecto)
└── transcripts/           (logs .jsonl; opcional)

~/.claude/projects/<slug>/   (dir REAL de CC: sus transcripts + su auto-memory — NUNCA un symlink al repo)
```
Dato técnico (solo para diagnosticar el propio directorio de CC, NO para enlazar nada):
`SLUG = ruta_absoluta_del_proyecto` con `[^a-zA-Z0-9] → '-'` (p. ej.
`/Users/ana/Drive/Mi Proyecto` → `-Users-ana-Drive-Mi-Proyecto`).

**`.gitignore` canónico** (modo equipo) — referenciado, no lo repitas con variantes:
```gitignore
# OJO: los comentarios van en su PROPIA línea. Un '#' al final de un patrón NO es
# comentario en .gitignore — pasa a formar parte del patrón y lo rompe (lo verifiqué
# en vivo: `*.local.md  # nota` deja de ignorar el .local.md → fuga del secreto).
# transcripts de sesión: pesados y pueden traer datos sensibles
.claude/transcripts/
.claude/*.jsonl
# config específica de la máquina
.claude/settings.local.json
# memorias personales/sensibles que NO viajan al equipo
.claude/memory/*.local.md
```
Tras escribirlo, **verifícalo de verdad**: `git check-ignore .claude/memory/x.local.md` debe imprimir la
ruta (= ignorado). No te fíes de que "se ve bien".

### Sembrar un proyecto NUEVO (0 fricción)
No hay nada que enlazar: crea `<proyecto>/.claude/{memory,skills}/`, un `CLAUDE.md`+`MEMORY.md` barebones
(ver la firma canónica arriba), corre el pull-del-canon para traer los hooks/skills `both` del equipo
(`bash <cortex>/brain/sincronizar-cerebro.sh . --apply`), y listo — se lee nativo desde el primer commit.

### Sembrar sobre un cerebro DISPERSO (memoria a medias entre el global y el repo)
Caso típico: el cerebro está partido entre `<repo>/.claude/memory/` (lo ya commiteado) y el global
`~/.claude/projects/<slug>/memory/` (memorias-auto que CC fue guardando y **no viajan**) — a menudo con
**dos `MEMORY.md` disjuntos** (no duplicados: cada lado lista cosas distintas). El arreglo es **copiar y
fusionar hacia el repo, NUNCA enlazar**:
1. **Inventaría y compara** ambos lados contra el estado real de la rama destino (`develop`), no contra
   otra rama — un inventario contra la rama equivocada miente (visto en vivo: casi se duplicó una canónica
   que `develop` ya tenía).
2. **Triage de pertenencia y privacidad ANTES de mover nada**, clasificando por **CONTENIDO, no por el
   `type:` del frontmatter ni por el tema** (una memoria `type: project` puede traer un secreto en el
   cuerpo — visto en vivo un password RDP en texto plano). Precedencia dura: **si contiene secretos/
   credenciales/rutas privadas → es SENSIBLE, aunque sea técnica y del proyecto.** Tres categorías:
   - **Del-proyecto** (técnica, útil al equipo, sin secretos) → archivo/carpeta normal en
     `<repo>/.claude/{memory,skills}/`. Se commitea y viaja.
   - **Personal transversal** (cómo trabajas en TODOS los proyectos) → no pertenece a este repo: una
     memoria se REESCRIBE como instrucción en `~/.claude/CLAUDE.md`; una skill transversal se `mv` a
     `~/.claude/skills/`. Sácala físicamente del slug-dir.
   - **Personal/sensible del proyecto** (rutas privadas, credenciales, notas que quieres al trabajar aquí
     pero no compartir) → `*.local.md` dentro de `<repo>/.claude/memory/`, gitignored, **sin indexar** en
     el `MEMORY.md` commiteado (ese índice viaja → puntero colgante para quien clona).
   Desempate proyecto-vs-transversal (frontera difusa): si el equipo se beneficia de saberlo para tocar
   ESTE repo → de-proyecto; si solo describe el gusto/entorno de una persona → transversal. Ante duda
   real, pregúntale al dueño en vez de adivinar.
3. **Fusiona hacia el repo con RECONCILIACIÓN, no solo dedup.** Si dos `MEMORY.md` listan cosas distintas,
   únelos; si dos memorias AFIRMAN cosas DISTINTAS del mismo objeto (visto en vivo: un `MEMORY.md` decía
   repo `unjordi/scripts`, otro `unjordi/PowerScripts`), no arrastres ambas — resuelve el conflicto con el
   dueño. Deduplica con `diff -q`; lo que sobre va a una `.trash/`, nunca `rm` a ciegas.
4. **No hace falta symlink ni bootstrap.** Una vez movidos los archivos reales al repo, el cerebro YA se
   lee nativo desde el `cwd`. El `~/.claude/projects/<slug>/` de esa máquina se queda con sus transcripts
   propios — es un canal distinto, no el mismo dato duplicado.
5. **Verifica y audita** antes de decir "ya quedó": el escaneo de secretos + `.gitignore` de la Cerca,
   ningún `.md` duplicado byte-a-byte entre global y repo, `MEMORY.md`↔archivos 1:1 (el invariante de la
   firma canónica), ninguna skill viviendo a la vez en `~/.claude/skills/` y `<repo>/.claude/skills/`
   (colisión de nombre — cada una en su hogar único).

### Gotchas del modo sembrar
- **Skills/backups fantasma:** Claude Code carga como skill **toda subcarpeta con un `SKILL.md`** —un
  backup `mi-skill.bak-…/` dentro del árbol de skills aparece como skill fantasma duplicado. Los
  backups van FUERA del árbol de skills (p. ej. `~/.claude/skill-backups/`).
- **Migración a media sesión** parte el transcript vivo; hazlo entre sesiones si puedes, o guarda un
  snapshot antes.
- **Nunca hardcodees** usuario ni rutas absolutas en memorias/skills compartidas — usa `~`/`$HOME`/rutas
  relativas, o no viajarán a otra máquina.
- **settings**: lo de-máquina va en `settings.local.json`; lo común del proyecto en `settings.json`.

---

## MODO CANONIZAR — llevar un cerebro drifteado a la firma-árbol

### Cuándo usarlo
- Un cerebro instanciado no respeta la estructura: memorias sin prefijo, `CLAUDE.md` viejo, índice plano.
  **Córrele el detector primero** (`bash brain/verificar-firma-canonica.sh <ruta>`) — te lista el drift.
- Como el **paso ESTRUCTURAL (Fase de "la FIRMA")** dentro del **modo consolidar** (ver abajo). Diferencia
  de roles: consolidar es la campaña amplia (auditores + positivar + desinflar + converger); este modo es
  solo la migración a la firma canónica. Puede invocarse SOLO (drift puramente estructural) o como el
  cierre de aquel.
- Tras cambiar los guards/hooks del cerebro globalmente: la prosa del `CLAUDE.md` de los instanciados
  queda stale (nombra un hook retirado) → canonizar la mata por construcción.

### Procedimiento (destilado del prototipo fluxcore)

#### 0 · Inventario + foto del drift
- Enumera `.claude/memory/*.md` y `.claude/skills/`. Lee `CLAUDE.md`, `MEMORY.md`, `AGENTS.md` (si hay).
- **Corre el detector:** `bash brain/verificar-firma-canonica.sh <ruta-del-cerebro>` — te da la lista
  exacta de secciones ausentes, memorias sin prefijo, enlaces rotos y hooks retirados en la prosa.
- No canonices a ciegas: si el detector sale limpio (`0 fail · 0 warn`), **no re-trabajes** — declara sano.

#### 1 · Clasifica cada memoria a un prefijo (o núcleo)
Por su **naturaleza dominante**: dominio/datos → `dom-`; correr-en-local/CI/deps/tooling/cerebro → `dev-`;
identidad/UI/componentes → `ux-`; hallazgos/planes de QA → `qa-`. Estado/backlog/bitácora/aprendizajes/
cómo-trabajar/hilo/cementerio → **núcleo** (sin prefijo). Si una cae en dos, gana la dominante.

#### 2 · Reprefija con `git mv` (historia intacta)
`git mv .claude/memory/auth-y-tenancy.md .claude/memory/dom-auth-y-tenancy.md`. Renombra también al
**nombre canónico del núcleo** lo que esté con alias (p. ej. `estado-y-pendientes.md → estado-proyecto.md`).

#### 3 · Dedup con RESCATE de datos únicos
Cuando dos memorias solapan, elige la CANÓNICA, **funde en ella los datos únicos de la otra** (rutas,
procedencias, valores irrepetibles), y `git rm` la fuente. Registra en el commit qué se rescató de dónde
(el prototipo: `proyecto-megaflux → dom-contexto-y-alcance` rescató ruta GitLab + procedencia del prefijo;
`recursos-marca → ux-identidad-de-marca` rescató Pantone + PDF + stock). Nunca `git rm` sin rescatar antes.

#### 4 · Reescribe `CLAUDE.md` a la firma-árbol
Sigue la secuencia obligatoria. El **árbol va DENTRO de un bloque cercado** ``` (si no, colapsa a prosa
en todo render). En el árbol, **nombra los guards BREVE** (`git-branch-guard, merge-develop-guard, …`) —
esto **mata la prosa de guards stale por construcción**. ATEMPORAL: sin fechas ni estado. La arquitectura
NO va aquí: apunta a `AGENTS.md` si existe.

**Si NO hay `CLAUDE.md` aún — destilar el TOC de cero.** El caso común: `cps` y `cortex` no tienen `CLAUDE.md`;
su misión vive implícita/mezclada dentro del entry-point operativo. No lo inventes: **destílalo clasificando
cada línea del entry-point por su NATURALEZA DOMINANTE**, en TRES clases:
- **CAPACIDAD** — algo que Claude **hace/opera** (un skill, una rutina, un guard, una tarea) → al TOC.
- **NORMA de CRITERIO/CONDUCTA** — cómo se trabaja aquí (reglas de estilo, "cómo NO trabajar",
  `como-trabajar-<user>`) → también al TOC (es firma: gobierna la operación), como su propia sección.
- **CONOCIMIENTO / estado / historia / dominio** — una decisión, un dato, una lección → se QUEDA en el detalle.

Cuando una línea tiene de varias, gana la **DOMINANTE**; si su método vive en 2 lados (un skill + un doc-método),
el TOC lleva un **puntero COMPUESTO** (`capacidad → skill + doc`). El `CLAUDE.md` resultante es thin (~5-8
líneas + secciones); NO duplica: el TOC apunta, el detalle vive abajo una sola vez.
- **MAPA DE FUENTES (no todo vive en el entry-point).** Las tres clases se surten de lugares distintos, y en un
  cerebro **meta** el índice puede ser CONOCIMIENTO puro (índice de memorias sin router) → el TOC saldría vacío
  si solo miraras ahí. Surte cada clase de su fuente real: **CAPACIDAD ← `.claude/skills/`** (enumera los dirs,
  N=N) **+** rutinas/guards activos; **NORMA de CONDUCTA ← los docs de criterio/estilo**; **MISIÓN ←
  `README.md`/el producto** (en un repo-template, leído read-only); **CONOCIMIENTO ← las memorias** (se queda).
  El TOC es la UNIÓN de esas fuentes, no un filtro del índice.
- **Interacción firma ↔ `sesion-inicio`:** crear un `CLAUDE.md` nuevo puede solapar lo que el hook
  `sesion-inicio` ya reinyecta al arranque (rama, norma de git, orden de leer el índice) — que el `CLAUDE.md`
  NO lo duplique; si hay que reordenar el hook, se PARQUEA para el humano (es tocar un guard).
- **AGENTS pesado que MEZCLA** (cps: 3194 líneas con arquitectura + git-flow + workflow + scripts): lo que ahí
  sea **proceso/capacidad** (no arquitectura) se **enlaza HACIA la firma** (o se dedupea si ya vive en un skill),
  dejando en `AGENTS.md` solo la arquitectura real. Separa por CONTENIDO, no por sección.
- **Alinea el entry-point operativo** para que su índice tenga exactamente las capacidades que el TOC declara,
  en ese orden (si sobra una fuera del mapa: se enlaza o se añade al TOC). El doc de arquitectura, si existe
  aparte, se deja en su carril y no se fuerza a la forma de la firma.

#### 5 · Reescribe `MEMORY.md` a índice-por-prefijo
Encabezado + `## 📍 Dónde estamos` (hilo + estado-proyecto) + una `##` por prefijo (🧭 núcleo · 🗄️ dom- ·
🛠️ dev- · 🎨 ux- · ✅ qa-), en el ORDEN del folder. Cada bullet: `[Título](archivo.md) — respuesta + ESTADO`.
Sin fechas/estado en la estructura (gradiente: MEMORY = como `develop`). Sin secciones inventadas.

#### 6 · Arregla los punteros vivos
`grep` por TODO el cerebro los nombres viejos: wikilinks `[[nombre-viejo]]` y md-links `](nombre-viejo.md)`
→ actualízalos al nuevo nombre. Una sola copia desincronizada ya es doc que miente.

#### 7 · VERIFICA el 1:1 (el gate)
`bash brain/verificar-firma-canonica.sh <ruta>` debe salir **`0 fail`** (usa `--strict` para exigir también
0 WARN). Confirma: MEMORY ↔ archivos 1:1, cero enlaces rotos, CLAUDE.md con todas las secciones y sin
hooks retirados en la prosa, `@import` resuelve. Ese detector ES el mecanismo que hace cumplir esta norma.

### El detector (mecanismo — la norma nace con él)
`brain/verificar-firma-canonica.sh [ruta] [--strict]` es el chequeo determinista que FLAGGEA el drift:
secciones de la firma ausentes en `CLAUDE.md`, memorias sin prefijo `dom-/dev-/ux-/qa-`/núcleo, el
invariante MEMORY↔archivos roto (huérfanas + enlaces rotos), y nombres de hook retirados en la prosa.
FAIL (estructural) = exit 1; WARN (drift menor) se reporta y `--strict` lo eleva a exit 1. **Alimenta el
GATE del auditor (#44):** el auditor de coherencia corre este detector como sub-check determinista y, en
modo gate, `--strict` bloquea un release si un cerebro instanciado drifteó. **También es candidato fuerte
a GATE DE RELEASE** (determinista, barato, ya tiene batería en `test-brain.sh`): si tu CI puede correr
`--strict` antes de un release, cablearlo cierra el hueco de "el detector existe pero nadie lo dispara".
Tiene su batería en `brain/test-brain.sh` (bloque `g5`: cerebro bueno/malo/no-indexado/local/strict/meta-repo).

---

## MODO CONSOLIDAR — dejar el cerebro SÓLIDO y COMPACTO (campaña amplia)
Este modo NO reinventa nada: **encadena skills atómicas que ya existen** en una campaña con orden,
cerca y criterio de cierre. Es el "cómo llevamos un cerebro de abrumador a cómodo consigo mismo" —
destilado de dos casos vivos (games-master, que quedó notoriamente compacto con +6 memorias nuevas y
aún así más chico que su gemelo; y cps, un repo .NET grande que convergió en 5 rondas de auditoría).

> **El DOLOR que lo originó (el north-star).** *"ya me cansé de pasar 5 horas configurando en loop cada
> vez que quiero jugar media hora"* + *"si yo me abrumo… no me imagino tú que lees todos esos archivos
> cada vez → DALE amor a ese repo"*. El entregable NO es "verde técnico": es un cerebro **SIN FRICCIÓN**,
> leíble de un jalón, que un Claude nuevo opera sin re-investigar ni romper nada. La vara de éxito, en
> palabras del usuario, es que el cerebro quede *"cómodo consigo mismo"*.

### Cuándo usar este modo
- El usuario lo pide con cualquiera de sus formas: *"dale amor al repo / que quede sólido y compacto /
  revisa que quede bien asentado / que un Claude nuevo lo opere sin re-investigar"*.
- Tras una **sesión grande** que cambió arquitectura, procedimientos o metió muchas memorias nuevas.
- Cuando el usuario **se abruma de leer el árbol** del cerebro, o sospecha duplicación/drift.
- Como pasada de mantenimiento antes de "irse con todo" a un frente nuevo sobre ese proyecto.

### Los skills que ORQUESTA (mapa — no los re-expliques, invócalos)
- [[auditar-coherencia-cerebro]] + [[auditar-suficiencia-operativa]] — **la DUPLA** (van JUNTAS SIEMPRE).
- [[auditar-proceso-algoritmo]] — el **tercer eje FMEA**, cuando se audita LÓGICA (no solo docs). También
  candidato cuando la capacidad audita el propio cerebro: súmalo al mapa si tocas lógica de riesgo.
- [[diagramar]] — alimenta al FMEA con los flowcharts (leyenda + normas) que necesita como "zapatos".
- [[positivar-doc]] — answer-first: "ESTO SÍ" antes de "ESTO NO".
- [[desinflar-memorias]] — colapsar narrativa a lección + mitos descartados al `cementerio.md` (por ID).
- [[orquestar-fanout]] — fan-out sin niñera (worktrees aislados, 2 archivos de estado) + su bucle de
  verificación (no creerle el "listo" a un agente).
- [[checkpoint]] — volcar el hilo antes de compactar (crítico en corridas de N rondas).
- [[cerrar-slice]] — el cierre por ramita → MR → mini-develop con `--squash`.
- [[turno-nocturno]] — cuando la convergencia corre de noche sin supervisión.

### PASO 0 — INVENTARIO (no auditar a ciegas)
Antes de tocar nada, **ubica el cerebro real** y cuéntalo. Tres cosas:
1. **El TAMAÑO:** cuántas memorias / skills / hooks — distinguiendo HOOK de LIB `source`-ada (una lib no se
   cablea y NO es un "hook huérfano"; contarla mal infla falsos hallazgos).
2. **La ESTRUCTURA de firma:** ¿hay `CLAUDE.md`? ¿`AGENTS.md`? ¿`MEMORY.md`? y sobre todo — **¿cuál es el
   ENTRY-POINT OPERATIVO REAL**, el doc que un Claude nuevo lee primero ("reglas de operación + router de
   skills")? Para AUDITAR, NO asumas que es `AGENTS.md` NI `MEMORY.md` — ábrelo y léelo (hoy puede variar:
   games-master usa AGENTS). Pero el **DESTINO de la consolidación es siempre la CONVENCIÓN `CLAUDE.md`(firma) +
   `MEMORY.md`(detalle)** (ver la firma canónica arriba): si el entry-point real es otro, es candidato a MIGRACIÓN.
3. **¿El repo ES la FUENTE del template?** (como `cortex` — que es workspace SOLO en las 2 máquinas dev, e
   INSTALADOR en las demás): su cerebro OPERATIVO (`.claude/`) es distinto del PRODUCTO que envía (`brain/`).
   Audita el operativo; NUNCA toques el producto (ver la Cerca). Es un caso ESTRECHO, no una ley universal.

### FASE 1 — LA DUPLA (dos lentes DISJUNTAS, en paralelo, mismo snapshot)
Norma dura del usuario: **"VAN JUNTOS SIEMPRE"**. Se lanzan como fan-out read-only sobre el MISMO
snapshot, con ámbitos distintos:
- **[[auditar-coherencia-cerebro]]** (CONSISTENCIA) — ¿se contradicen los documentos? ¿datos que no
  cuadran? ¿guards evadibles? ¿punteros colgados? ¿doc que miente vs el código real?
- **[[auditar-suficiencia-operativa]]** (OPERABILIDAD) — ¿puede alguien que llega mañana HACER las
  tareas sin romper ni re-investigar? Deriva la lista de tareas reales, califica **✅/⚠️/❌ con
  archivo:línea**, con ojos frescos.

**Por qué van juntas (el caso que lo justifica, visto en vivo):** *"6 documentos perfectamente
coherentes entre sí prometiendo un candado que NO existía — coherencia perfecta, realidad distinta. La
coherencia no ve eso; la suficiencia sí."* Y al revés: un cerebro de recetas buenas que se contradicen
pasa la prueba de suficiencia archivo por archivo. **Ninguna caza lo de la otra.**

**Contrato de reporte** (de [[orquestar-fanout]]): cada auditor escribe su dictamen a un `.md` durable
(`AUDITOR-COH-r<N>.md`, `AUDITOR-SUF-r<N>.md`) y responde SOLO ~3 líneas al orquestador (veredicto +
conteo, hallazgos en bullets, ruta). Así no infla el contexto del orquestador.

### FASE 2 — VERIFICAR los hallazgos (no creer el reporte del agente)
Usa el **bucle de verificación** de [[orquestar-fanout]]: **espera a tener AMBOS dictámenes antes de
editar** (no muevas el piso a media auditoría), y **verifica read-only cada hallazgo contra el código/
realidad** — no lo relates como verdad. El **cross-check entre lentes es donde se cazan los FALSOS
POSITIVOS**: en cps, suficiencia marcó `detectar-secretos.sh` como "hook huérfano" → coherencia lo REFUTÓ
por ejecución (es una LIB `source`-ada, no un hook) = FP anotado, no tocado. Con 4-6 informes, haz el
cross-check ANTES de sintetizar.
> **Si un agente REEMPLAZA un doc** (un rebuild de la firma/README/config, no contenido nuevo — típico en
> el modo canonizar): corre el **DIFF DE PRESERVACIÓN** de [[orquestar-fanout]] — `diff` viejo→nuevo y
> clasifica lo que SOLTÓ (basura temporal botada bien **vs** conocimiento real que hay que preservar/reubicar).
> Un rebuild falla por OMISIÓN silenciosa, no por afirmar de más (caso real: un rebuild botó una corrección que
> vivía SOLO en ese archivo).

### FASE 3 — CONSOLIDAR / ORGANIZAR (positivar → desinflar → dedup)
> **SALIDA TEMPRANA (gate):** si el Paso 0 + la dupla muestran que el cerebro YA está sano (índice fiel, sin
> drift, ya compacto, 0 hallazgos accionables), **NO re-trabajes por trabajar** — declara "ya está sano" y salta
> directo a la Fase 6 (firma/cierre). Positivar/desinflar un cerebro ya bueno solo arriesga cavar hoyos nuevos.
> Esto es para cerebros ABRUMADOS, no para pulir lo ya pulido (games-master ya estaba sano → casi nada que tocar).

Con los hallazgos verificados, los fixes van por un agente en **worktree AISLADO** (o el orquestador
secuencial si el cerebro vive en un folder no-git, p. ej. Drive), commits granulares, orquestador revisa
el diff. El grueso del "quedar compacto":
1. **[[positivar-doc]]** — cada nugget answer-first: la solución/valor accionable ARRIBA, la cautela/
   gotcha/historia del fallo DEBAJO (idealmente `❌ …` compacto). Preserva el 100%, solo reordena.
2. **[[desinflar-memorias]]** — cada tirada de narrativa/tutorial se colapsa a su **lección en 1-2
   líneas EN SU LUGAR**; los mitos desmentidos se mudan al **`cementerio.md`** del cerebro (una lápida =
   una línea con su ID `🪦#<id>`, vía `cementerio.sh add`), dejando en la memoria solo la ref `(🪦#<id>)`
   donde haga falta. NO se corta: advertencias destructivas, comandos, decisiones con su porqué,
   datos irrepetibles. Recortes reales: cps `estado-proyecto` 896→460 (−49%), **0 lecciones perdidas**.
3. **Un CANÓNICO + PUNTEROS** por dato/tema repetido: una memoria "manda", las hermanas se deducen a un
   puntero. Un dato NO vive en 3 lados; el estado "actual" se DERIVA.
4. **Índice answer-first y SIN DRIFT:** un solo **entry-point operativo** (el doc que traiga reglas +
   router de skills — es `AGENTS.md` en games-master, el `MEMORY.md`-índice en cps; ver Fase 6), answer-first,
   con "LEE ESTO ANTES DE HACER NADA" arriba y los punteros al detalle. El router refleja las skills REALES
   (N=N). En cps el índice MENTÍA (clúster ETL invisible desde la puerta) → reconstruido 35/35.
5. **Matar el mito en TODAS sus copias:** tras corregir el canónico, `grep` del término viejo por TODO
   el cerebro vivo (incluido `MEMORY.md`) — una sola copia desincronizada ya es doc que miente.
6. **Reubicar lo genérico/ajeno FUERA del cerebro del proyecto** (lo transversal → global; lo de
   terceros → `~/code/ajenos/`); **retirar skills deprecados con lápida** (⚰️ RETIRADO + redirección).

### FASE 4 — EL LOOP DE CONVERGENCIA (el corazón)
**"auditar → arreglar → RE-AUDITAR con el prompt IDÉNTICO"** hasta que ambas lentes salgan limpias. El
usuario lo ordenó literal: *"ya que 'quede', VUELVE a correr el auditor IGUALITO"* — si cambias el
prompt, cambias el examen (guarda el prompt literal en un `.md`). **No autodeclarar** el cierre.
- **Convergencia = 0 CRÍTICO / 0 ALTO / 0 MEDIO accionable.** Los BAJO/borderline/nitpick no bloquean.
- **La TRAMPA del loop (regla dura):** cada ronda cava más fino; NO loopees indefinidamente. Cuando solo
  queden borderline/FP, **PAUSA y lleva la decisión de convergencia al usuario**. Señal de auditor
  agotado (real): *"ya es nitpicking, se ve que el auditor se aburrió"*.
- El loop no es ceremonia: en un caso el re-auditor cazó un bug que el **propio orquestador** introdujo
  (un gate colocado DESPUÉS de mutar el estado).
- Trayectoria real cps SUF: 1C/2A → 1C/3A → 0C/2A → 0C/1M → 0C/0A (5 rondas); coherencia convergió antes.

### FASE 5 (opcional) — EL TERCER EJE: FMEA, cuando hay LÓGICA de riesgo
La dupla es **doc-orientada** ("¿se puede operar?" / "¿se contradice/miente?"); **ninguna pregunta
"¿el ALGORITMO/FLUJO es correcto?"**. Cuando la capacidad audita LÓGICA (contabilidad, un ETL, una
máquina de estados, o **lo que HACE el propio brain**), se SUMA [[auditar-proceso-algoritmo]] (FMEA).
- **Condición dura:** el FMEA razona sobre **flowcharts de calidad** ("los zapatos") — cada uno **con su
  LEYENDA + las NORMAS aplicables**. Sin el mapa, el dictamen sale genérico. Es un proceso de **DOS
  pasos**: primero [[diagramar]] el flujo bien (respetando el `CONVENCIONES.md` del destino), luego el
  auditor lo audita **individual → colectivo** (cada pieza sola, luego todas juntas: una pieza correcta
  puede contradecir a otra en la costura).
- Los hallazgos de **lógica/dinero se PARQUEAN para el humano** (y su experta de dominio si la hay) — no
  se tocan en la pasada de cerebro.

### FASE 6 — CIERRE con la FIRMA (el lazo doc=realidad)
El mecanismo elegante que emergió de esta campaña. **La FIRMA no es "corre los auditores" (eso es el
trigger): la firma ES el checklist que se le entrega al auditor de suficiencia** — la lista de las
CAPACIDADES que el tooling promete + el puntero a su método. *"La firma es el SUJETO de la auditoría, no
su método."* Lazo cerrado: la firma es a la vez *lo que prometes* y *contra lo que se audita* →
doc=realidad por construcción (auditar = "¿la realidad sigue cumpliendo la firma?").

**El paso ESTRUCTURAL de esta fase ES el modo canonizar** (arriba, en este mismo skill): corre su
detector `verificar-firma-canonica.sh` — la spec de la firma vive una sola vez, arriba, no se re-enuncia
aquí (una segunda copia de la spec solo vuelve a driftear, que es justo lo que le pasó a este skill antes
de fusionarse).

- El auditor de suficiencia **camina cada línea de la firma**: `CLAUDE.md → MEMORY.md →
  memoria/skill → realidad`, y marca el hueco (capacidad sin método, método sin código, doc que miente).
- **Entregable bonito de cierre: el "prompt bello de arranque"** — el reporte matutino curado (1 línea
  de estado + tabla de rondas + "lo único que necesito de ti") para reanudar la sesión-master sin
  trauma. El usuario lo valora explícitamente; va como parte del cierre y se **preserva a disco** (vive
  en el dictamen durable, no solo en el chat, para sobrevivir compactaciones).

### CRITERIO DE "LISTO" del modo consolidar
**Convergencia técnica ≠ LISTO.** "0 ALTO/0 MEDIO + memoria al día" es *verificado técnicamente*:
necesario, insuficiente. El sello final es el **QA/OK del usuario** o su autorización expresa (definición
mutua de LISTO). Los parqueados quedan visibles en el **dictamen durable** (repo git:
`<repo>/docs/auditoria-<tema>-<fecha>.md`; folder no-git: donde ese cerebro guarde su historial, p. ej.
`.claude/projects/`) y en el backlog vivo (`estado-proyecto.md`) — **ningún
hallazgo se queda solo en el chat**, aunque solo se atienda un subconjunto.

### GOTCHAS del modo consolidar (destilados de las corridas reales)
- **git-branch-guard, FP sobre texto de commit:** dispara sobre `git push origin develop` **dentro de un
  mensaje de commit multilínea** (no un push real). Workaround: escribe el mensaje con Write y commitea
  con `git commit -F <archivo>`. (La lib `analizar-comando-git.sh` ignora menciones entrecomilladas, pero
  un heredoc multilínea la evade.)
- **Verifica el hallazgo con OJOS, no con el primer grep:** un `grep -E` con `\|` (en vez de `|` real)
  devolvió falsos "FALTA"; un "DESCARTADO" en la línea siguiente hizo declarar un mito "presente". El FP
  del propio detector a veces **destapa un hueco REAL de doc** — aprovéchalo, no lo descartes ciego.
- **No le creas al histórico de un cerebro "loopeado":** *"esa afirmación era suposición"*. Toda
  afirmación se reconcilia contra **evidencia real** (código/.cs/logs), no contra lo que asentó una
  sesión previa.
- **Rutas al verificar:** es `.claude/memory/`, no `memory/`. Usa rutas absolutas.
- **Ruido de shell del profile:** cada `Bash` puede imprimir un listado del root antes del output real
  (el profile de zsh/eza) — no afecta operaciones pero confunde el parseo; invoca `/usr/bin/ls` y rutas
  completas.
- **Parquear un folder en la rama correcta:** un "develop" local puede arrastrar historia de main y estar
  N líneas atrás del remoto — verificar `ahead/behind` + contenido idéntico al remoto ANTES de dar el
  parqueo por bueno.
- **Cerebro en folder no-git (Drive):** no se puede aislar en worktree → esas mutaciones las hace el
  **orquestador secuencialmente** (evita choques con el sync de Insync); la pieza que SÍ es git se delega
  en worktree aislado en paralelo.

---

## MODO RECONCILIAR — reconciliación SEMANAL del cerebro del equipo (mini → develop)
Es la **capa SEMANAL** del ritual de cerebro: alguien designado (1 run/semana, o cuando el usuario lo
pide) reconcilia lo que las minis de los devs acumularon en `.claude/` hacia `develop` —
**aprendizajes** (prosa cosechada por `cerrar-slice` §5) y **memorias** — sin perder QUIÉN aportó
qué, sin aplanar la voz, y sin tocar los guardrails delicados.

> **Objeto y disparador DISTINTOS de `cerrar-slice`** → este modo es su HERMANO, no su extensión.
> `cerrar-slice` cierra un slice de CÓDIGO (build/tests/lint, un MR de feature). Éste reconcilia
> PROSA+cerebro (no hay `dotnet build`; el "verde" es `test-brain.sh` + lint de memoria) y su disparador
> es *integrar la mini completa a develop*, no *terminar un slice*.

> **Regla de oro que atraviesa todo el ritual:** los **hooks/settings/skills CANÓNICOS del brain se
> rutean a `cortex`** (su MANIFEST es la fuente única) y bajan por `sincronizar-cerebro.sh` — el
> pull-del-canon de la maquinaria común (arriba). **JAMÁS** viajan por el MR de la mini a develop. Lo que
> sube por este MR es MEMORIA+APRENDIZAJES, no cerebro canónico. (Un MR de mini que toque
> `.claude/hooks/*`/`settings.json`/`.brain-version` es un error de ruteo — sácalo en el Paso 1.)

### Disparadores
- Manual: invoca este modo (el run semanal designado, o cuando el usuario lo pide).
- DISCIPLINA tuya, sin hook que lo recuerde (`recordar-unificar-cerebro` se retiró, overhaul hooks
  2026-09-18, puramente advisory): cuando el delta de `.claude/` de tu rama vs `origin/develop` acumule
  ≥5 archivos o >7 días sin unificar, córrelo.
- Encadenado desde `cerrar-slice` cuando la cosecha de un slice cae en `.claude/`.

### Paso 0 — Inventario del delta de cada mini
Para tu mini (y, en el modo-semana, fetch de las otras minis `Develop<Usuario>`), lista qué cambió en
`.claude/` vs develop y **clasifica cada archivo**:

```
git fetch origin --prune
git diff --stat origin/develop...HEAD -- .claude/
```

Clases:
- **Aprendizajes** (`aprendizajes.md`, `aprendizajes-*.md`) → log compartido, `merge=union`.
- **Notas atómicas / archivos propios** (un módulo, `estado-proyecto.md`, una decisión con ciclo
  propio) → van tal cual (raro que choquen).
- **Índices** (`MEMORY.md`, `skills/README.md`) → **NO se editan a mano**: `merge=ours` + regen.
- **CEREBRO canónico** (`.claude/hooks/*`, `settings.json`, `.brain-version`, skills-de-proceso del
  brain, `aprendizajes-*-brain.md`) → **NO sube por este MR**; se resuelve en el Paso 1.

### Paso 1 — Baja PRIMERO el brain canónico (sácalo del diff) — el pull-del-canon
Antes de subir nada, sincroniza el cerebro canónico HACIA ABAJO en tu mini para que el diff quede
LIMPIO de cerebro (es la maquinaria común descrita arriba):

```
bash <ruta-a-cortex>/brain/sincronizar-cerebro.sh . --apply
```

Esto pone la copia por-repo al día desde la fuente única. Los `aprendizajes-*-brain.md` (los que son
del brain, no del proyecto) se **mueven a cortex**, no a develop. Tras este paso, el delta que
queda para subir es SOLO memoria+aprendizajes del proyecto.

> Si el sync destapa que la mini tenía **ediciones locales de cerebro canónico** (un hook modificado,
> un exec-bit flipeado, una skill del brain borrada), eso NO se resuelve aquí subiéndolo: se enruta a
> un MR contra `cortex`. Anótalo y sepáralo.

### Paso 2 — Resuelve por CLASE (sin curar todavía)
- **Aprendizajes** → `merge=union`: se fusionan solos, no los toques a mano. (La curación es el Paso 3.)
- **Notas atómicas / archivos propios** → tal cual; si dos devs crearon el mismo slug (add/add),
  renombra uno.
- **Índices** → NO editar; `merge=ours` deja ganar a develop y el regen los rehace verídicos.
- **Cerebro canónico** → ya salió del diff en el Paso 1.

### Paso 3 — CURACIÓN del log (el corazón del ritual)
Sobre el `aprendizajes.md` ya juntado, haz DOS cosas. **Nunca reescribas prosa a ciegas** (norma
global anti-aplanado/destructivo): la máquina/tú DETECTAS candidatos y armas el andamiaje, pero la
VOZ de cada quien se preserva.

**(a) Trenza los solapes ACREDITANDO A AMBOS.** Cuando dos devs escribieron sobre lo mismo, elige uno
de 3 desenlaces — jamás fundir borrando una voz:
1. **Hermanas cross-linked** [DEFAULT, preserva 100% la voz] — deja ambos bloques, enlázalos entre sí
   (`> Ver también [[...]]`). Patrón `lecciones-migracion-cps` ↔ `-desde-cero`.
2. **Consolidada que CITA en bloque cada voz** — un bloque nuevo `aportó: a, b` que **cita
   textualmente** la prosa de cada quien (no la parafrasea), con las fuentes marcadas (no se borran).
3. **Tensión anotada** — cuando las dos calibraciones son OPUESTAS por-dev (p. ej. "arregla de corrido"
   vs "no pushees sin mi OK"): deja ambos bloques vivos + una línea `> Tensión con [[otra]]: <cuándo
   aplica cada una>`.

**(b) GRADÚA lo maduro a su hogar.** Un aprendizaje que ya se estabilizó deja de ser inbox y se
promueve:
- → **skill/hook del brain** si es un mecanismo genérico (rutéalo a `cortex`, no a develop).
- → **norma en `_PROTOCOLO.md` / `AGENTS.md`** si es una regla dura de proceso.
- → **TRATO / preferencia PERSONAL del usuario** (cómo le gusta que le comuniquen, decidan, trabajen)
  → su **`~/.claude/projects/-Users-<user>/memory/como-trabajar-con-<user>.md`** GLOBAL per-máquina
  (es sobre una PERSONA, no un proyecto → **NO sube a develop, NO viaja por git**). Escríbelo
  answer-first / desinflado a 1-2 líneas, en su sección (Comunicación/Decisiones/Proceso/Git/
  Preferencias), **con procedencia** (cita literal entre comillas vs `[INFER]`) y **REFERENCIANDO** las
  normas universales del brain — sin copiarlas. Distínguelo del TRATO **SOBRE OTRO dev** (`sobre:
  <handle>`): ése se queda en el inbox del equipo (así viaja a su máquina). Molde canónico:
  `como-trabajar-con-unjordi.md`.
- → **archivo propio** si creció a un tema autocontenido (`modulo-x.md`).
Al graduar, deja en el inbox una marca de que se movió (o retíralo si ya vive íntegro en su hogar) —
pero eso es EDICIÓN curada y deliberada, distinta del append ciego que hace `cerrar-slice` §5.

### Paso 4 — Verifica (el "verde" del cerebro)
NO hay build. El verde técnico aquí es:
- `bash <cortex>/brain/test-brain.sh` → **0 FAIL** (incluye el drift-check del MANIFEST/widget).
- Lint de memoria: frontmatter válido, todo enlazado desde `MEMORY.md`, sin `*.local.md` colado, sin
  rutas muertas, cada entrada de `aprendizajes.md` termina en línea en blanco.

**Verde técnico ≠ LISTO** — es peldaño necesario, no la meta.

### Paso 5 — Integra a develop por el carril EXISTENTE
Promover `Develop<Usuario> → develop` es integración COORDINADA:
- MR `Develop<Usuario> → develop`, con **OK EXPLÍCITO del usuario** (lo exige `merge-develop-guard`),
- **SIN `--auto-merge`**,
- **CON `--squash`** y mensaje curado que **acredita a los devs** cuyo trabajo se integra (lo exige
  el mismo guard).

**NO toques ni aflojes `merge-develop-guard`** — este ritual pasa por él, no lo evade. Si el candado
frena pidiendo confirmación y ya la tienes, cítala; no la fabriques.

### Paso 6 — Post-merge
- Regenera los índices (`MEMORY.md`, `skills/README.md`) si hubo notas/skills nuevas.
- Consolida `estado-proyecto.md` (single-writer: lo hace el integrador, una vez, desde la bitácora).
- **Appendea una línea a `bitacora.md` con `>>`** (append-only, `merge=union` → parallel-safe; nunca
  un Edit que reescriba): qué se unificó, de qué minis, qué se graduó.

> Recuerda: los aprendizajes graduados a **skill/hook/norma del brain** se rutean a `cortex` por
> su propio MR — no por el de la mini. El MR de la mini lleva memoria+aprendizajes del proyecto.

---

## LISTO (no lo saltes, aplica a los 4 modos)
Cualquier modo en verde técnico (detector limpio / convergencia / `test-brain.sh` 0 FAIL) es
**verificado técnicamente**, NO LISTO. El sello es el **QA/OK del usuario** (definición mutua de LISTO).
Lo parqueado (fusiones que borrarían conocimiento, dudas de clasificación, hallazgos sin atender) queda
VISIBLE en `estado-proyecto.md` — ningún hallazgo se queda solo en el chat.

## Familia
- Hermano de [[auditar-coherencia-cerebro]] (que puede correr el detector del modo canonizar como
  sub-check) y de [[desinflar-memorias]]/[[positivar-doc]] (higiene de CONTENIDO, ortogonal a la
  ESTRUCTURA del modo canonizar).
- El flujo de integración (ramita → MR → develop con `--squash`, OK explícito): [[cerrar-slice]] (que
  también absorbió, en su §5, la cosecha de aprendizajes que antes era el skill `cosechar-sesion`).
- [[reubicar-master]] es hermano del modo sembrar: ese define DÓNDE vive el cerebro; reubicar-master lo
  MUEVE de casa.
