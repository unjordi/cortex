# Auditoría de OBSOLESCENCIA — los 25 skills del brain + el seeder de normas

- **Fecha:** 2026-09-17 · **Base:** `develop` @ `b3a5da1` (2026-09-16) · **Rama:** `audit/skills-obsolescencia`
- **Alcance:** `brain/skills/*/SKILL.md` (25 carpetas + `MANIFEST`) y `brain/norms/global-claude-md.md` (463 líneas).
- **Método:** READ-ONLY. Cada ruta, script, comando, `[[wikilink]]`, nombre de hook y conteo se comprobó
  contra el disco (`ls`, `command -v`, `grep`, ejecución del comando real donde aplicaba).
- **Convención:** **CONFIRMADO** = lo medí, cito el comando/evidencia. **PLAUSIBLE** = sospecha razonada, sin medición concluyente.

---

## Veredicto

**No están sanos, pero tampoco podridos.** De 25 skills, **19 están limpios de contenido**. Hay **2 rotos de verdad**
(el procedimiento falla para quien lo siga), **1 obsoleto de raíz** (su propio banner declara superseded el
80% de su cuerpo, y sigue enviando un script que hace lo prohibido), **4 con referencias muertas menores** y
**1 con una gotcha de entorno ya superada**. El seeder de normas está bien en nombres y mecanismos —los 14
hooks y 4 skills que cita existen, ningún retirado aparece— pero **tiene un defecto grave que no es de
nombres: enseña el flag `--auto-merge` que el propio `cerrar-slice` prohíbe por escrito, porque derrota a
`confirmar-merge-develop`** (§9.1). Es lo más rentable que salió de toda la corrida.

**Tres correcciones a lo que me dijeron**, todas medidas (§7 y §12).

---

## Tabla de hallazgos, por gravedad

| # | Estado | Skill / archivo | Qué está mal | Acción propuesta |
|---|--------|-----------------|--------------|------------------|
| **A0** | CONFIRMADO | `brain/norms/global-claude-md.md` | Enseña `--auto-merge`/`--auto` como *el* modo de mergear a develop — **el flag que derrota a `confirmar-merge-develop`** y que `cerrar-slice` prohíbe explícitamente | Corregir la tabla del seeder |
| A1 | CONFIRMADO | `checkpoint` | El paso 0 OBLIGATORIO falla **en silencio** (exit 0, sin output) | Corregir la ruta / desplegar el `.js` |
| A2 | CONFIRMADO | `auditor-semantico` | Los 4 pasos apuntan a `scripts/auditor-semantico/`, que no existe en 25 de 26 repos — ni en `cortex` | Corregir la ruta + decidir despliegue |
| A3 | CONFIRMADO | `claude-proyecto-autocontenido` | Banner dice "SUPERSEDIDO" y el skill igual **envía y manda commitear** un script que crea los symlinks prohibidos | Reescribir o retirar (decide el dueño) |
| B1 | CONFIRMADO | `desinflar-memorias`, `positivar-doc`, `orquestar-fanout`, `cerrar-slice` | `cementerio.sh` / `limpiar-worktrees.sh` invocados **pelones**; no están en `PATH` | Prefijar `~/.claude/hooks/` |
| B2 | CONFIRMADO | `consolidar-cerebro` | Gotcha "ruido de shell del profile zsh/eza" — superada desde 2026-09-10 (el Bash tool es bash) | Actualizar el procedimiento |
| C1 | CONFIRMADO | `ingenieria-inversa-gui-db-navegador` | `re_helpers.py` no existe en ningún lado; skill de referencia mal nombrado; conteo 16 vs 33 real | Corregir las 3 referencias |
| C2 | CONFIRMADO | `zoom-screenshot` | `[[steam-ui-referencia]]` colgado (el real es `steam-link-a-fondo`); "Herramientas en el **Deck**" | Corregir el link + el encabezado |
| C3 | CONFIRMADO | `orquestar-fanout` | "el hook `precompact` se retiró: PreCompact no puede inyectar ni pedir acción" — ya hay un hook PreCompact vivo | Actualizar la frase |
| C4 | CONFIRMADO | `consolidar-cerebro` | Mecanismo declarado "Propuesta pendiente" que no está en ningún backlog | Al backlog |
| D1 | CONFIRMADO | `revisar-entregables-agentes` | **No es obsoleto** — es una norma en formato de skill, y su regla **no vive en ningún `CLAUDE.md`** | **Promover a norma** |
| D2 | CONFIRMADO | `brain/norms/global-claude-md.md` | Matiz de alcance: `dod-verificar` es tier `repo` (6 de 26 repos) | Documentar el matiz |
| **E1** | CONFIRMADO | `cerrar-slice` | **Ritual huérfano de disparador** (≠ obsoleto). Contenido vigente y superior al de la norma; `confirmar-merge-develop` **nunca lo nombra** | **Cablear** al hook que ya existe |
| **E2** | CONFIRMADO | `revisar-entregables-agentes` | Segundo huérfano: `delegacion-reporte` dispara en el instante exacto y **no dice la mitad de verificar** | **Cablear** + promover a norma |
| **E3** | CONFIRMADO | `cosechar-sesion` | **NO es huérfano** — `recordar-cosechar` ya lo dispara. Su límite es el alcance (tier `repo`, 5 repos) | Ninguna, o ampliar alcance |

---

## 1 · A1 — `checkpoint`: el paso 0 obligatorio es un no-op silencioso · CONFIRMADO

**El más grave**, porque `checkpoint` es el skill más usado (80 invocaciones) y este es su **paso 0, "ambos
niveles", "corre este paso SIEMPRE"**.

`brain/skills/checkpoint/SKILL.md:70`:

```bash
node "$(ls ~/.local/bin/checkpoint-mecanico.js ~/.cortex/bin/checkpoint-mecanico.js 2>/dev/null | head -1)" \
     --self --ensure
```

**Medido:**
- `~/.local/bin/checkpoint-mecanico.js` → no existe.
- `~/.cortex/bin/checkpoint-mecanico.js` → no existe (`~/.cortex` está en `main` @ `5753c27`; el `.js` entró
  a `develop` el 2026-09-14, `d6170e9`).
- El `$(ls …)` devuelve **cadena vacía** → `node ""` → **exit 0, sin imprimir nada**. Lo corrí.

El modo de falla es el peor posible: no es un error, es un **no-op indistinguible de un "no-op" legítimo**
(que es justo lo que `--ensure` dice cuando el andamio ya está al día). Quien siga el skill cree que
regeneró el andamio, hace `cat` del sidecar, encuentra uno viejo o nada, y no tiene forma de saber cuál de
las dos cosas pasó — exactamente lo que el propio paso 0 dice que viene a evitar
(*"sin este paso, un `/checkpoint` a mano encuentra el andamio viejo o ausente, sin poder distinguir cuál"*).

**Causa raíz, y es más ancha que el skill: ningún instalador despliega `bin/checkpoint-mecanico.js`.**
`install.sh:428-443` instala `cortex-fetch`, `chats-extract.js`, `sessions-extract.js`, `session-move.js`,
`session-lib.js`, `session-export.js`, `session-import.js` y `claude-session` a `~/.local/bin` —
`checkpoint-mecanico.js` **no está en esa lista**. El hook `checkpoint-mecanico.sh:57` busca en
`$HOME/.local/bin/` y `$BRAIN_DIR/bin/`, así que hoy tampoco encuentra nada y sale por su `[ -n "$EXP" ] || exit 0`
(fail-open correcto, pero silencioso).

En este momento la única vía por la que el `.js` puede aparecer es que `~/.cortex` (clon del repo) reciba un
release a `main`. Eso funciona para el dueño; no funciona para una máquina cuyo `CLAUDE_BRAIN_DIR` no sea un
clon completo.

**Acciones (a elegir por el dueño):**
1. **Agregar `checkpoint-mecanico.js` al loop de `install.sh`** (una línea junto a los otros `.js`) — cierra
   el hueco para el hook y para el skill a la vez, y alinea con `$HOME/.local/bin` que ambos ya miran primero.
2. **Blindar el comando del skill** para que falle RUIDOSO en vez de silencioso, p. ej.
   `EXP="$(ls … | head -1)"; [ -n "$EXP" ] || { echo "andamio: falta checkpoint-mecanico.js"; }`.
3. **Menor, de precisión:** el skill hardcodea `~/.cortex` mientras el hook usa `resolve_brain_dir()`
   (`drift-cerebro-comun.sh`) con fallback a `${CLAUDE_BRAIN_DIR:-$HOME/.cortex}`. Coinciden **solo** si
   `CLAUDE_BRAIN_DIR` no está puesto. En una máquina que lo ponga, el skill busca donde el hook no.

**Lo que se pierde si no se toca:** nada se rompe hoy de forma visible — se pierde el 80% del checkpoint
COMPLETO que el andamio regalaba gratis (árbol de archivos tocados, commits del tramo, **citas textuales del
usuario**), reconstruido de memoria justo donde el propio skill advierte que "se lava una idea tuya en la voz
del usuario".

---

## 2 · A2 — `auditor-semantico`: la maquinaria no vive donde el skill la manda correr · CONFIRMADO

Tu medición era correcta, y es peor de lo que dijiste: **1 de 26 repos**, no 1 de 7.

El skill cita `scripts/auditor-semantico/` **cuatro veces**, en los cuatro pasos que lo componen:

| Línea | Referencia |
|---|---|
| 8 | `Ver scripts/auditor-semantico/README.md … antes de correr esta skill` |
| 28 | `./scripts/auditor-semantico/ejecutar.sh` ← **paso 1** |
| 39 | `Lee scripts/auditor-semantico/invariantes-semanticos.yml` ← **paso 2** |
| 57 | `escribe un check nuevo en scripts/auditor-semantico/checks/` ← **paso 4** |

**Medido:**
- La maquinaria vive en **`cortex/brain/scripts/auditor-semantico/`** (`README.md`, `ejecutar.sh`,
  `lib-formato.sh`, `invariantes-semanticos.yml`, `checks/01..04`).
- **Ningún instalador la despliega.** `grep -n 'auditor-semantico\|brain/scripts' install.sh bootstrap.sh
  brain/install-brain.sh brain/sincronizar-cerebro.sh` → **0 coincidencias en los cuatro**.
- Barrido de los 26 repos git de `~/code`: **solo `fluxcore`** tiene `scripts/auditor-semantico/`
  (colocado a mano; `ejecutar.sh` con mtime del 22-jul).
- **Ni siquiera en `cortex` funciona el skill tal como está escrito**: ahí la ruta correcta es
  `brain/scripts/`, no `scripts/` (en `cortex/scripts/` solo vive `qa-andamio.py`).

El propio motor refuerza la contradicción: su `ejecutar.sh:16` documenta el uso como
`./scripts/auditor-semantico/ejecutar.sh`, y su `README.md:13` dice *"vive en el template
(`cortex/brain/scripts/`)"*. Las dos frases son ciertas por separado y no hay puente entre ellas.

**Acciones (a elegir):**
1. **Construir el puente**: que `sincronizar-cerebro.sh` (o `aplicar-plantilla-a-proyecto`) copie
   `brain/scripts/auditor-semantico/` → `<repo>/scripts/auditor-semantico/` en el bootstrap de un repo,
   y que el skill lo diga. Es la lectura literal del diseño "motor genérico + catálogo por-repo".
2. **O corregir el skill** para que apunte a donde la cosa de verdad vive y diga explícitamente
   "si tu repo no la tiene, cópiala de `<cortex>/brain/scripts/`". Barato, honesto, sin plumbing nuevo.
3. **O marcar el skill `retirado`** si el motor se considera muerto — pero **se perdería** un arnés vivo:
   4 checks deterministas y un `invariantes-semanticos.yml` que en `fluxcore` ya creció a 7.4 KB de
   invariantes de dominio. No lo recomiendo.

---

## 3 · A3 — `claude-proyecto-autocontenido`: 380 líneas que el propio skill declara muertas · CONFIRMADO

Es el único skill que calificaría de **obsoleto de raíz**, y el que más riesgo activo tiene.

Su banner (líneas 15-24) dice, textual:

> ⚠️ **RE-ARQUITECTURA A CERO-SYMLINKS (decisión dura de unjordi, 2026-09-08: "NO quiero symlinks en ningún
> lado").** … Todo lo de abajo que ARMA/verifica un symlink (el `bootstrap-claude.sh` embebido con su
> `ln -s`, el triage "cuando el slug se symlinkea al repo", la verificación por `readlink`) está
> **SUPERSEDIDO** y pendiente de reescritura completa — **NO lo sigas para crear symlinks nuevos.**

Y sin embargo, **en el mismo archivo**:

- **El `description` del frontmatter** — lo único que el modelo lee al elegir un skill — sigue anunciando
  el procedimiento muerto: *"Cubre la regla del slug, **el symlink de slug-dir**, un bootstrap de un comando…"*.
- **§"El criterio (en una frase)"** (línea 29), el resumen answer-first, contradice el banner de frente:
  *"El global `~/.claude/projects/<slug>/` queda como **symlink** a esa carpeta"*.
- **El skill ENVÍA un ejecutable real**, `claude-proyecto-autocontenido/bootstrap-claude.sh`, cuya línea 40
  es `ln -s "$TARGET" "$LINK"`; y §Bootstrap (línea 152) instruye: *"**commitea este script en el repo**…
  cópialo tal cual al repo, no lo retransribas"*.
- §Verificación usa `readlink ~/.claude/projects/<slug>` y §Rollback describe cómo restaurar el symlink.

**Radio de impacto, medido hoy:**
- **12 repos de `~/code` ya llevan commiteado un `.claude/bootstrap-claude.sh` con `ln -s`**: PowerScripts,
  casalianza_actas, cenamContenidoNacional, **cortex**, cps, eskeduler, fluxcore, mfx_infraestructuradigital,
  pisa_InfraestructuraDigital, pisamrp_4.6, pisamrpclaude, plantilladotnet.
- **8 symlinks vivos** en `~/.claude/projects/*/memory` — incluido
  `-Users-unjordi-code-claude-brain/memory → /Users/unjordi/code/cortex/.claude/memory`, un slug del nombre
  viejo del repo: exactamente la "proliferación" que la decisión de 2026-09-08 cita como motivo.

Un banner que dice "no sigas las siguientes 380 líneas" no es documentación: es una trampa con señalización.
El lector que salta al índice, al `description` o a §Bootstrap no ve el banner.

**Acciones (decide el dueño; nada de esto lo hago yo):**
1. **Reescribir** el skill a la arquitectura cero-symlinks, borrando el `bootstrap-claude.sh` del paquete.
   **Lo que se pierde:** el triage de privacidad (§`.gitignore` canónico, §barrido de secretos,
   §`*.local.md`), el playbook de consolidación de cerebros dispersos y la regla del slug — todo eso **sigue
   siendo vigente y valioso**, y hoy no vive en ningún otro lado. Rescatarlo es el trabajo real; el `ln -s`
   es lo único a botar.
2. **Marcar `retirado`** y repartir lo rescatable a `canonizar-cerebro` / `consolidar-cerebro`.
   **Se pierde** lo mismo si no se rescata primero.
3. **Mínimo viable si no hay tiempo para (1):** corregir el `description` y §"El criterio en una frase" (que
   son lo que un modelo lee primero) y borrar el `bootstrap-claude.sh` del paquete del skill. Dos ediciones,
   quita el filo.
4. **Aparte (fleet, no doc):** los 12 `bootstrap-claude.sh` commiteados y los 8 symlinks vivos son un
   pendiente propio. **Lo dejo anotado, no lo toco.**

---

## 4 · B1 — `cementerio.sh` y `limpiar-worktrees.sh` invocados pelones, sin estar en `PATH` · CONFIRMADO

Cuatro skills mandan correr scripts del cerebro por su basename, como si estuvieran en el `PATH`. No lo están.

**Medido:** `command -v cementerio.sh limpiar-worktrees.sh limpiar-ramas.sh sincronizar-cerebro.sh
test-brain.sh` → **los cinco: no encontrados**. Viven en `~/.claude/hooks/` (o en `brain/`), y
`~/.claude/hooks` **no está en el `PATH`** (verifiqué el `PATH` completo).

| Skill | Línea | Cómo lo invoca |
|---|---|---|
| `desinflar-memorias` | 36-44 | Bloque ```bash``` literal: `cementerio.sh add "Mito «…»" "DESCARTADO …"` |
| `desinflar-memorias` | 50, 118 | `cementerio.sh verify` |
| `positivar-doc` | 58 | `vía cementerio.sh add` |
| `orquestar-fanout` | 152, 159, 166 | `corre limpiar-worktrees.sh` (×3) |
| `cerrar-slice` | 77 | `limpia los worktrees zombies con limpiar-worktrees.sh` |

Ningún skill da la ruta completa en ningún lado. Quien copie el bloque de `desinflar-memorias` tal cual
recibe `command not found`, y el paso "valida las refs↔IDs" — el que impide dejar referencias `🪦#<id>`
huérfanas — simplemente no se corre.

El propio `cementerio.sh` arrastra la misma convención en su encabezado de uso (líneas 12-20), así que el
arreglo natural es uno solo y consistente: **`bash "$HOME/.claude/hooks/cementerio.sh" add …`**. El interfaz
está bien (`add` / `verify` / `--help`, verificado en `case` línea 144) — lo único mal es cómo se invoca.

**Acción:** prefijar la ruta en las 8 menciones (4 skills) y en el encabezado de los scripts.
Alternativa de fondo, si el dueño la prefiere: que `install.sh` enlace los `kind=script` a `~/.local/bin`
(que **sí** está en el `PATH`), y entonces las skills ya no mienten. Afecta también a `limpiar-ramas.sh` y
`verificar-cerebro.sh`, que tienen el mismo patrón.

---

## 5 · B2 — `consolidar-cerebro`: la gotcha del "ruido de shell" quedó atrás · CONFIRMADO

`consolidar-cerebro/SKILL.md:278-279`:

> **Ruido de shell del profile:** cada `Bash` puede imprimir un listado del root antes del output real
> (el profile de zsh/eza) — no afecta operaciones pero confunde el parseo; invoca `/usr/bin/ls` y rutas completas.

**Medido:** el Bash tool corre `/opt/homebrew/bin/bash` (`env.SHELL` en `~/.claude/settings.json:8`,
puesto el 2026-09-10). En ese shell `type ls` → **`ls is /bin/ls`**: sin alias, sin `eza`, sin listado
pegado. `$0` → `/opt/homebrew/bin/bash`. El síntoma que la gotcha describe **ya no ocurre**, y la receta
(`/usr/bin/ls`) es ceremonia muerta.

**Doble problema, y el segundo importa más:** esta gotcha es una **afirmación sobre el entorno de UNA
máquina** (el zsh de unjordi con `eza`) incrustada en un skill **global que viaja por git**. Es el caso
exacto que prohíbe la norma dura *"El entorno de MÁQUINA vive GLOBAL, jamás en un repo"* del propio seeder
(líneas 24-30). En la Cachy o en un Windows del equipo, ese párrafo es ruido.

**Acción:** borrar el bullet, o reescribirlo condicional y sin nombrar el entorno de nadie
(*"si tu shell imprime ruido de profile antes del output, usa rutas absolutas"*). Mismo criterio aplica al
encabezado "Herramientas en el **Deck**" de `zoom-screenshot` (§6, C2).

---

## 6 · Referencias muertas menores · todas CONFIRMADAS

**C1 · `ingenieria-inversa-gui-db-navegador` — tres referencias, tres mal:**
- **L110** — *"el `dump()` de `re_helpers.py`"*. `find /Users/unjordi/code -name 're_helpers.py'` →
  **0 resultados**. El único lugar del disco donde existe la cadena "re_helpers" es esta línea del skill.
- **L219** — *"ver `.claude/skills/sae9-arquitectura/reference/` en ese repo"*. El directorio real en
  `potenciaDatabases` es **`sae9-arquitectura-bd`** (hay además `sae9-caso-de-uso-a-sp` y
  `sae9-validar-sp-max-rule`; ninguno se llama `sae9-arquitectura`).
- **L217** — *"16 archivos `reference/proceso-*.md`"*. Conteo real:
  `ls …/sae9-arquitectura-bd/reference/proceso-*.md | wc -l` → **33**.

  *Acción:* borrar la mención a `re_helpers.py` (o reemplazarla por `SELECT *`, que la propia línea ya
  ofrece como alternativa), corregir el nombre del directorio y el conteo a 33.

**C2 · `zoom-screenshot` — dos cosas:**
- **L36** — `Relacionado: [[steam-ui-referencia]]`. Ese skill **no existe**: no está en `brain/skills/`, no
  está en `~/.claude/skills/`, no está en el disco. El pariente real es **`steam-link-a-fondo`** (skill
  per-máquina, presente en `~/.claude/skills/`). Es el **único wikilink colgado** de los 25 skills — todos
  los demás `[[…]]` resuelven.
- **L13-14** — encabezado *"Herramientas en el **Deck**"* (la Steam Deck), en un skill global. Sus tres
  afirmaciones (`ffmpeg ✓`, `rsvg-convert ✓`, `python3 ✓`, sin ImageMagick ni PIL) **resultan ciertas también
  en esta Mac** — las verifiqué una por una —, así que el procedimiento funciona; lo que miente es el
  encabezado, que ata el skill a una máquina que no es la que lo corre.

  *Acción:* corregir el wikilink y renombrar el encabezado a "Herramientas requeridas" con un
  `command -v ffmpeg` como verificación en vez de una lista afirmada.

**C3 · `orquestar-fanout:165`** — *"(el hook `precompact` se retiró: PreCompact no puede inyectar ni pedir
acción)"*. La primera mitad sigue siendo cierta (`precompact-volcar-estado` está en `brain/hooks/RETIRED`) y
la segunda también, pero la **conclusión implícita quedó atrás**: desde el 2026-09-11 hay un hook vivo
cableado en PreCompact — `checkpoint-mecanico` (`brain/hooks/MANIFEST`: `checkpoint-mecanico global hook`;
`install-brain.sh:228`: `checkpoint-mecanico) echo "PreCompact|"`). El propio skill `checkpoint` ya lo
explica bien (*"Lo que SÍ pasa en ese evento, sin tu turno: `checkpoint-mecanico.sh`…"*). Es doc que quedó
desincronizada entre dos skills hermanos.

  *Acción:* actualizar la frase a *"PreCompact no puede inyectar contexto ni pedir un turno, pero sí lanzar
  trabajo externo: ahí corre `checkpoint-mecanico`"*.

**C4 · `consolidar-cerebro:289-293`** — §"Mecanismo / enforcement" dice *"Propuesta pendiente: extender el
flujo para que la DUPLA se sugiera/recuerde tras un cambio de doc/sistema… (Registrar como frente si se
cablea.)"*. **Medido:** `grep` de esa propuesta en `.claude/memory/estado-proyecto.md` → **0 resultados**.
Es una norma declarada sin mecanismo y sin backlog, exactamente lo que la norma *"Toda norma nace con su
mecanismo"* llama "un buen deseo". *(El hueco de despliegue de `auditor-semantico` de §2 tampoco está en el
backlog: mismo `grep`, 0 resultados.)*

  *Acción:* ambos al backlog vivo, con severidad y origen.

---

## 7 · Correcciones a lo que me dijeron, con la evidencia

*(la tercera y la cuarta están en §10.4 y §12; aquí van las dos de la primera tanda)*

**7.1 · La regla de `revisar-entregables-agentes` NO vive en ningún `CLAUDE.md`.**

Me dijiste: *"revisar entregables de agentes terminó usándose sólo como regla dura en el claude.md"*.
**Lo medí y no es así.**

- `grep -niE 'entregable|reporte de un agente|verificar.*agente|revisar-entregables'` sobre
  `brain/norms/global-claude-md.md` → solo 2 coincidencias, y ambas son de la palabra "entregable" **dentro
  de la Definición de LISTO**, sin relación con agentes.
- Mismo `grep` sobre el `~/.claude/CLAUDE.md` **vivo** → idénticas 2 coincidencias, mismo contexto.
- `grep -rln 'revisar-entregables-agentes'` sobre todos los `CLAUDE.md` de `~/code`, los `.claude/*.md` y
  `~/.claude/*.md` → **0 archivos**.

La regla se aplica a diario, sí — pero **no porque esté en una norma cargada en cada sesión**. Se aplica
porque **6 skills la citan por wikilink** (`consolidar-cerebro`, `construir-missing-manual`, `positivar-doc`,
`auditar-*`), y esos sí se leen. Eso es transmisión por vecindad, no enforcement.

**Esto refuerza tu conclusión, por una razón distinta a la que diste:** el skill **no está obsoleto**
—su contenido es vigente al 100%, sin una sola referencia rota, y el §"DIFF DE PRESERVACIÓN" es la única
casa de un antídoto real—, pero **hoy nada lo hace disparar solo**. Es el candidato de libro a **promover a
norma**: debe cumplirse siempre, nadie lo invoca, y a diferencia de lo que asumías, tampoco hay un `CLAUDE.md`
cubriéndolo por detrás.

*Acción:* **promover a norma** en `brain/norms/global-claude-md.md`, junto a la sección de delegación
(§"Consentimiento de costo" / §"Orquesta"), que es donde encaja y hoy está incompleta. Si se promueve, el
skill puede quedarse como el **detalle largo** que la norma referencia (el bucle de 5 pasos, la heurística
barato/caro y el diff de preservación no caben en una norma) — igual que `cerrar-slice` es hoy "el recetario
completo" al que la norma de git apunta.

**7.2 · El hueco de `auditor-semantico` es más ancho: 1 de 26 repos, no 1 de 7.**
Barrí los 26 repos git de `~/code`, no una muestra. Solo `fluxcore` tiene la maquinaria. Y el detalle que no
mencionaste y que a mi juicio es el que cierra el caso: **`cortex` mismo tampoco la tiene donde el skill la
busca** — está en `brain/scripts/`, y el skill dice `scripts/`.

---

## 8 · Skills sin hallazgos de contenido (19 de 25) — y cómo lo demostré

`auditar-coherencia-cerebro` · `auditar-proceso-algoritmo` · `auditar-suficiencia-operativa` ·
`canonizar-cerebro` · `cerrar-slice` · `construir-missing-manual` · `cosechar-sesion` · `desinflar-memorias`* ·
`diagramar` · `investigar-dominio` · `markdown-a-pdf` · `orquestar-fanout`* · `positivar-doc`* ·
`rehidratar-hilo` · `reubicar-master` · `revisar-entregables-agentes` · `to-do` · `turno-nocturno` ·
`unificar-cerebro`

*(los marcados con \* arrastran el problema de `PATH` de §4 — una línea cada uno, sin tocar su procedimiento. `orquestar-fanout` suma además la frase de PreCompact de §6-C3. Ninguno de los 19 tiene un hallazgo que rompa lo que enseña.)*

Lo que se comprobó, y salió limpio:

- **Todos los `[[wikilinks]]`** de los 25 skills resuelven, **salvo `[[steam-ui-referencia]]`** (§6).
- **Todos los nombres de hook** citados en skills existen en `brain/hooks/MANIFEST` con tier vivo. Conté las
  menciones de los 39 hooks/libs/scripts del MANIFEST más los 2 retirados: `rama-vieja` → **0 menciones**
  (el barrido de ayer quedó completo) y `precompact-volcar-estado` → 2, ambas en `canonizar-cerebro`
  **describiéndolo correctamente como retirado**, que es su uso legítimo como ejemplo.
- **Herramientas de `diagramar`:** `~/.cortex/bin/dot2yed.py` ✓ y `~/.cortex/bin/mmd2dot.py` ✓ existen.
- **Bloques de `test-brain.sh`** citados como arnés reusable: `gbg` (4 apariciones), `scanf` (19), `cm` (23)
  por `auditar-coherencia-cerebro`; `g5` (1) por `canonizar-cerebro`. Todos presentes.
- **`canonizar-cerebro`:** `brain/verificar-firma-canonica.sh` ✓ existe, y las 4 veces que lo cita lo hace
  con la ruta correcta (`bash brain/verificar-firma-canonica.sh`).
- **`turno-nocturno`:** `${XDG_CACHE_HOME:-~/.cache}/cortex/state.json` y `~/Library/Caches/cortex/state.json`
  son literalmente las dos rutas que `delegacion-comun.sh:44,95` recorre en `linea_cuota()` ✓;
  `limite-gasto.sh` existe y **está cableado** en `~/.claude/settings.json` ✓; `/loop` existe ✓.
- **`consolidar-cerebro:219`:** `docs/flowcharts/verificar-arbol-sync.sh` ✓ existe y ✓ busca de verdad el
  bloque `<!-- ARBOL:START -->…<!-- ARBOL:END -->` (líneas 71-74), como el skill afirma.
- **`markdown-a-pdf`:** `npx` y `node` presentes ✓; el gotcha `--stylesheet` vs `--css` describe el
  comportamiento interno de `md-to-pdf`, no una ruta del repo.
- **`cerrar-slice`:** el paso que la norma §"Ningún hallazgo queda narrado" dice que vive aquí, **vive aquí**
  (líneas 45-50), y está replicado en `auditar-proceso-algoritmo:96` y `auditar-coherencia-cerebro:144`.
- **`rehidratar-hilo`:** `$HOME/.claude/hooks/rehidratar-hilo.sh` ✓ existe y ✓ está cableado (SessionStart).
- **`reubicar-master`** (1195 líneas, el más largo): su `reubicar-master.sh` viaja en la misma carpeta ✓;
  `exportar-sesion-master.sh` ✓ existe y ✓ está cableado (3 eventos); las decenas de `masters.json`,
  `sesiones-alias.json`, `.pre-reubicar.json`, `seed.sh`, `h.sh`/`h2.sh` son **artefactos que el propio
  procedimiento genera o nombres de ejemplo**, no rutas preexistentes que deban estar en disco.

**Un matiz honesto sobre `to-do`:** cita `TaskCreate`/`TaskUpdate`/`TaskList` "o `TodoWrite` si tu harness la
expone". No pude comprobar desde aquí cuál de las dos familias expone el harness actual, así que lo dejo como
**PLAUSIBLE, sin hallazgo**: la redacción ya es defensiva y cubre ambos casos.

---

## 9 · El seeder de normas — `brain/norms/global-claude-md.md` · 463 líneas

### 9.1 · A0 — La norma enseña el flag que derrota a uno de sus propios guards · CONFIRMADO

**El hallazgo más grave de toda la auditoría**, y el único que califiqué por encima del `checkpoint` roto.
No es un nombre muerto ni una ruta rota: es una **instrucción activa y equivocada**, en el archivo que se
carga entero en cada sesión de cada máquina del equipo.

`brain/norms/global-claude-md.md`, sección "Flujo de git", líneas 271 y 294:

> **1–3 devs:** MR/PR con **AUTO-MERGE** al instante.

> \| mergear (auto-merge + squash) \| `gh pr merge --squash --auto` \| `glab mr merge --squash --auto-merge` \|

`brain/skills/cerrar-slice/SKILL.md`, líneas 92-117, dice lo contrario con un subtítulo propio —
**"Por qué SIN `--auto-merge` / `--auto`"** — y el razonamiento medido:

> `--auto-merge` en `glab` arma **Merge When Pipeline Succeeds (MWPS)**: el merge **NO** ocurre al correr
> el comando, queda **ENCOLADO** para dispararse solo, sin testigo, cuando el pipeline termine — minutos
> después, en otro momento. `confirmar-merge-develop` exige tu OK **del instante del merge**; encolarlo
> rompe esa garantía (el guard autoriza el comando, pero no controla el evento futuro que arma).
> (Visto al mergear el !112 de cortex: quedó en MWPS pese al OK explícito.)

Sus bloques de comandos lo marcan dos veces: `# SIN --auto-merge: merge YA, no encolado`.

**Por qué esto es de otra categoría que el resto del dictamen:**

1. **La norma instruye el bypass de su propio candado.** No es doc desactualizada — es doc que enseña
   exactamente la maniobra que vacía de sentido a `confirmar-merge-develop`. La norma de *Integridad de los
   guardarraíles* del mismo archivo prohíbe aflojar un control de supervisión; aquí el archivo lo afloja solo.
2. **La frase de L271 es autocontradictoria**: llama a MWPS "AUTO-MERGE **al instante**", cuando el defecto
   entero de MWPS es que **no es al instante**. Quien lea solo la norma no tiene forma de sospecharlo.
3. **Alcance asimétrico.** El seeder llega a **todas** las máquinas en cada sesión. `cerrar-slice` es tier
   `both` pero marca **cero invocaciones** (§10) — es decir, hoy **la versión equivocada es la que todo el
   mundo lee, y la correcta es la que nadie abre**.
4. **La norma apunta a la skill** ("Recetario completo: skill `cerrar-slice`", L298) sin notar que el
   recetario la contradice. El puntero existe; la reconciliación, no.

**Matiz, para ser justo:** la L315 (§mini-develop) sí permite auto-merge, y eso **es correcto y coherente**
— `cerrar-slice` solo prohíbe `--auto-merge` para `develop`/`main`, no para las ramitas hacia tu mini. La
contradicción está acotada a la tabla y al bullet de L271, que son los que gobiernan la integración a `develop`.

**Acción propuesta:** corregir L271 y L294 para que reflejen lo que `cerrar-slice` ya tiene medido —
esperar pipeline verde y mergear de inmediato, **sin** `--auto`/`--auto-merge`, para develop/main; conservar
auto-merge explícitamente para ramita→mini. Una tabla y un bullet. **No se pierde nada**, y deja de haber
dos verdades sobre el mismo comando.

> Nota de método: este hallazgo salió por la tercera lente (§12) y no por la mía. Buscando *por qué*
> `cerrar-slice` marca cero invocaciones, hubo que leer su contenido a fondo para comprobar que fuera
> vigente antes de proponer cablearlo — y ahí apareció que no solo es vigente, sino **más correcto que la
> norma**. La instrucción de "verifica el contenido ANTES de proponer el cable" es la que destapó A0.

### 9.2 · El resto del seeder: sano en todo lo verificable

**Nombres (CONFIRMADO, 0 hallazgos).** Extraje los 48 identificadores entre backticks del archivo y los crucé
contra el MANIFEST y el disco:

- **14 hooks nombrados** — `aviso-drift-cerebro`, `confirmar-merge-develop`, `delegacion-gate`,
  `delegacion-registrar`, `delegacion-reporte`, `dod-verificar`, `entorno-maquina-guard`, `git-branch-guard`,
  `hud-stale`, `merge-squash-guard`, `no-bypass-deploy`, `proteger-arbol`, `rehidratar-hilo`, `sesion-inicio`
  — **los 14 existen** en `brain/hooks/` con tier vivo en el MANIFEST.
- **4 skills nombrados** — `cerrar-slice`, `checkpoint`, `orquestar-fanout`, `rehidratar-hilo` — **los 4 existen**
  y sus nombres no han cambiado.
- **5 scripts nombrados** — `sembrar-mini-develop.sh`, `limpiar-worktrees.sh`, `limpiar-ramas.sh`,
  `install-brain.sh`, `install.sh` — **los 5 existen**.
- **Ningún retirado**: `rama-vieja` → 0 menciones, `precompact-volcar-estado` → 0 menciones.
- **Ningún conteo falso**: barrí los patrones numéricos ("los N hooks", "N checks", "N repos"). Los 3 números
  del archivo (`~5 casos`, `3 archivos`, `25 líneas`) son umbrales y anécdotas fechadas, no inventarios.
- **El único `[[wikilink]]`** del archivo, `[[diseno-rediseno-auto-sync-46]]` (línea 349), **resuelve**:
  `cortex/.claude/memory/diseno-rediseno-auto-sync-46.md` ✓.

**Mecanismos (CONFIRMADO, 0 hallazgos en los que audité a fondo).** Ese es el patrón que pediste verificar
uno por uno — "¿el mecanismo citado existe, está cableado y hace lo que la norma dice?". Leí el código de tres:

| Norma | Mecanismo citado | Existe | Cableado | ¿Hace lo que dice? |
|---|---|---|---|---|
| "Actualiza por la herramienta REAL" (L174-176) | `no-bypass-deploy` (PreToolUse/Bash), *"AVISA/redirige — no bloquea, fail-safe"*, excepciones `--dry-run`/`--help`/CI | ✓ | ✓ | **Exacto.** Emite `additionalContext` y `exit 0` — nunca `deny`. Tiene los `if` de CI (`CI`/`GITLAB_CI`/`GITHUB_ACTIONS`/`BUILD_ID`) y el fail-open sin `jq`. |
| "El entorno de MÁQUINA vive GLOBAL" (L30) | `entorno-maquina-guard`, *"lo AVISA"* | ✓ | ✓ | **Exacto.** Avisa (no bloquea) con 2 señales acotadas a `.claude/memory/`: el filename-trampa `entorno-maquina.md` y contenido machine-specific agregado. |
| "Tu lista de TODOs es TU HUD" (L440-446) | `hud-stale` (advisory), *"detecta por señal OBJETIVA (rama/cwd), nunca por el contenido del HUD, y no bloquea"* | ✓ | ✓ (2 eventos) | **Exacto**, hasta la redacción del encabezado del hook. |

También verifiqué los flags que la norma de sync menciona: `sincronizar-cerebro.sh --limpiar-personal`,
`--incluir-skills`, `--apply`, `--prune-orphans` y el ledger `.claude/skills/.brain-skills` — **todos
implementados** (líneas 9-62 del script).

**Un matiz de alcance, no un error (D2).** La norma más repetida del archivo, la Definición de LISTO, dice
*"Lo hace cumplir el hook `dod-verificar` (Stop)"* (L89). `dod-verificar` es tier **`repo`**: se carga solo si
la sesión **inicia** en un repo que lo tenga desplegado. **Medido: 6 de 26 repos** de `~/code` lo tienen
(`axon`, `cps`, `fluxcore`, `pisamrp_4.6`, `pisamrpclaude`, `plantilladotnet`). **`cortex` no lo tiene** — lo
cual es *correcto* y coherente con la norma "Cerebro por-repo = CORREO" (cortex es personal, sin marca
`.claude/repo-compartido`; solo `cps`, `fluxcore` y `plantilladotnet` la tienen). Pero el resultado neto es
que un archivo cargado en **toda** sesión afirma una enforcement que existe en **menos de la cuarta parte**
de los repos. No es doc que miente — es doc que omite su alcance.

*Acción propuesta:* media línea — *"(tier `repo`: aplica en los repos que despliegan el cerebro por-repo)"*.
**Nada que retirar.**

**Nota de instalación, no de doc.** El `~/.claude/CLAUDE.md` vivo **difiere del seeder en 77 líneas**: le
faltan 3 normas que ya están en `develop` (la de comentarios inline, la consolidación de "Recupera de tu
contexto vivo", y el bloque `--limpiar-personal`). En la misma línea, `~/.claude/hooks/` todavía tiene y
cablea **`rama-vieja.sh`** (retirado el 2026-09-15) y **le faltan** `checkpoint-mecanico.sh` y
`contrato-hilo.sh` (que `checkpoint/SKILL.md:156` manda hacer `source`). **Todo esto es un install atrasado
respecto a `develop`, no doc que mienta** — el mecanismo de lápidas del MANIFEST lo poda solo en el próximo
install. Lo anoto porque explica por qué varias cosas "no existen" hoy en la máquina, y porque la poda de
`rama-vieja` todavía no ha corrido.

---

## 10 · La tercera lente: ritual huérfano de disparador ≠ obsoleto

> *"debería ser invocado automáticamente cuando se autoriza un merge a develop, no? lo mismo con cosechar
> sesión."* — el dueño

Medí el mapa completo **skill → disparador** antes de proponer un solo cable, en el orden que se me pidió:
**primero ¿el contenido está vigente?, después ¿le falta el cable?**

### 10.1 · El mapa, medido

| Skill | ¿Tiene disparador? | Cuál, y en qué evento | Contenido vigente |
|---|---|---|---|
| `checkpoint` | ✅ | `aviso-contexto` (watermark, nombra `/checkpoint`) + `checkpoint-mecanico` (PreCompact) | ⚠️ paso 0 roto (§1) |
| `rehidratar-hilo` | ✅ | hook homónimo (SessionStart) | ✅ |
| `to-do` | ✅ | `hud-stale` (SessionStart + PostToolUse/Bash) | ✅ |
| **`cosechar-sesion`** | **✅** | **`recordar-cosechar` (Stop)** — nudge 1×/día/repo si hubo trabajo y `aprendizajes.md` no se tocó | ✅ |
| `unificar-cerebro` | ✅ | `recordar-unificar-cerebro` (SessionStart) | ✅ |
| `orquestar-fanout` | ✅ | `recordar-orquestar` (PostToolUse) + `delegacion-reporte` (PostToolUse/Task) | ⚠️ 2 líneas (§4, §6-C3) |
| **`cerrar-slice`** | **❌** | — ningún hook lo dispara | ✅ **y superior a la norma** |
| **`revisar-entregables-agentes`** | **❌** | — ningún hook lo dispara | ✅ **impecable** |

**El dato que reordena todo esto:** el cerebro **ya tiene construido el patrón** para exactamente este
problema — la familia **`recordar-*`** (`recordar-cosechar`, `recordar-unificar-cerebro`,
`recordar-orquestar`, `recordar-dashboard`): hooks advisory, no bloqueantes, que disparan en el evento
natural y nombran el skill. `recordar-orquestar` incluso lo dice en su encabezado: *"una norma de estilo SIN
mecanismo no se cumple sola ('toda norma nace con su mecanismo')"*. El cerebro **sí** aplicó la lección a
sus skills — solo que no a todos. El hueco no es conceptual, es de cobertura, y son **dos casillas**.

### 10.2 · E1 — `cerrar-slice`: el evento existe, el hook existe, falta el cable · CONFIRMADO

**Primero, el contenido (el gate que pediste).** `cerrar-slice` no solo está vigente: en el punto que más
importa, **es más correcto que la norma global** — es el único lugar del cerebro que documenta el defecto
MWPS de `--auto-merge` (§9.1). Su único defecto es la línea 77 (`limpiar-worktrees.sh` pelón, §4).
**Veredicto: vigente. Se puede cablear** — arreglando antes esa línea.

**El hueco, medido:**
- `grep -n 'cerrar-slice' brain/hooks/confirmar-merge-develop.sh` → **0 coincidencias.** El hook que corre
  en el instante exacto que el dueño nombra —la autorización del merge a develop— **nunca menciona el ritual**.
- `merge-squash-guard.sh` **sí** lo nombra, 4 veces (líneas 11, 54, 95, 102, 136) — pero solo **al RECHAZAR**
  un `--squash-message` pobre: *"Ver skill cerrar-slice."*. Eso es un puntero **reactivo en un castigo**, no
  un disparador del ritual. Llega tarde: cuando el guard rechaza el mensaje, los pasos 1-3 de `cerrar-slice`
  (verificar, actualizar memoria, confirmar con el usuario) ya se saltaron.

Ese es el diagnóstico fino: **no es que nadie sepa que `cerrar-slice` existe** — el cerebro lo menciona
en 4 hooks y en 2 normas. Es que **se le nombra después del hecho, nunca antes**.

**Acción propuesta:** un aviso en `confirmar-merge-develop` que, al reconocer la confirmación expresa y
**dejar pasar** el merge, recuerde el ritual (*"antes de integrar: build/tests citados, memoria y bitácora
al día, backlog actualizado — `/cerrar-slice`"*). **Advisory, `additionalContext`, nunca `deny`** — el hook
ya tiene ese canal y el patrón está probado en los 4 `recordar-*`.

**Riesgo a considerar, y no es menor:** `confirmar-merge-develop` es un **candado de supervisión**, y la
norma de *Integridad de los guardarraíles* exige consentimiento explícito para tocarlo. Añadirle un aviso
**no afloja nada** (no cambia ninguna condición de bloqueo), pero **sí es una edición a un guard de
supervisión** → necesita el OK explícito del dueño para ESE hook, distinto del OK a la idea. Alternativa
más limpia si prefiere no tocarlo: un **`recordar-cerrar-slice.sh` nuevo**, hermano de los otros 4, que
viva aparte y deje el candado intacto. **Es la que yo recomendaría.**

### 10.3 · E2 — `revisar-entregables-agentes`: el hook dispara en el momento exacto y dice la otra mitad · CONFIRMADO

**Contenido:** impecable. 76 líneas, cero referencias rotas, y el §"DIFF DE PRESERVACIÓN" es la única casa
de un antídoto real (§7.1). **Vigente sin reservas.**

**El hueco, medido:** `delegacion-reporte` es PostToolUse/**Task** — dispara **en el instante en que un
agente reporta**, que es literalmente el momento de este skill. Y `grep -niE 'verific|revisar-entregables|
creer|comprob'` sobre ese hook → **0 coincidencias**. Solo recuerda *registrar el avance y limpiar el
worktree* (lo que la norma L412 describe). **El hook correcto, en el evento correcto, diciendo la mitad
equivocada.**

**Acción propuesta:** sumar la media frase que falta al mensaje que ese hook ya emite. Es el cable más
barato de los tres (una cadena, sin hook nuevo, sin tocar ningún candado) y el de mayor rendimiento.
Se combina con la promoción a norma de §7.1: la norma establece la regla, el hook la recuerda en su momento.

### 10.4 · E3 — `cosechar-sesion` **ya tiene** su disparador · CONFIRMADO

Aquí **corrijo la premisa**. Se me dijo que `cosechar-sesion` era el segundo huérfano, con `SessionEnd` como
su evento pendiente. **No es así:**

`brain/hooks/recordar-cosechar.sh` es un hook **Stop** (tier `repo`) cuyo encabezado, textual, dice:

> • NUDGE gentil (1×/día/repo) de "trabajaste y no dejaste memoria durable", con DOS señales:
>   (1) **COSECHA**: hubo trabajo sustantivo pero `.claude/memory/aprendizajes.md` NO fue tocado →
>   recuerda correr **`/cosechar-sesion`** antes de cerrar (si aprendiste algo durable).

El ritual **ya está cableado**, con mejor diseño que `SessionEnd`: dispara en `Stop` (donde todavía hay un
turno del modelo para actuar) en vez de `SessionEnd` (donde ya no lo hay) — la misma razón por la que
`precompact-volcar-estado` se retiró. Y el nudge es **condicional** (solo si de verdad no se cosechó) y
rate-limited, no ruido en cada sesión.

**Su límite real es el ALCANCE, no la ausencia:** `recordar-cosechar` es tier **`repo`** → medido, está
desplegado en **5 repos** (`axon`, `cps`, `fluxcore`, `pisamrpclaude`, `plantilladotnet`). En los otros 21,
incluido **`cortex`**, nunca dispara. Lo mismo vale para `recordar-unificar-cerebro`.

**Acción propuesta:** **ninguna urgente.** Si el dueño quiere que el nudge llegue a más máquinas, la
decisión es de **tier** (`repo` → `global`), y se toma con la regla crisp del MANIFEST — no es un cable
faltante. Lo anoto para que no se "arregle" algo que ya funciona.

### 10.5 · La advertencia que pediste explícita

**Cablear un ritual obsoleto sería peor que dejarlo dormido.** Por eso el orden fue: contenido primero,
cable después. El resultado de aplicarlo:

- **`cerrar-slice`** → contenido vigente (y mejor que la norma) → **cablear, tras arreglar su línea 77.**
- **`revisar-entregables-agentes`** → contenido impecable → **cablear ya.**
- **`cosechar-sesion`** → contenido vigente → **ya cableado, no tocar.**
- **`claude-proyecto-autocontenido`** → contenido **obsoleto** (§3) → **NO se cablea ni se le busca evento.**
  Si alguien lo hubiera cableado "porque marca cero invocaciones", habría convertido un procedimiento
  prohibido en ruido automático que empuja a crear symlinks en cada sesión. Es el contraejemplo exacto de
  por qué la tercera lente va **después** de la primera, y no en su lugar.

---

## 11 · Las tres lentes juntas: obsoleto ≠ formato equivocado ≠ huérfano de disparador

Separé explícitamente las dos cosas, porque confundirlas retiraría algo que se cumple a diario.

Con la tercera ampliación, el cero-invocaciones tiene **tres** diagnósticos posibles, y confundirlos cuesta
caro en las tres direcciones. Así quedó clasificado cada caso, medido:

**(1) Obsoleto — su contenido ya no es cierto → retirar o reescribir:**
- **`claude-proyecto-autocontenido`** (0 invocaciones). Y no por falta de uso, sino porque **su propio banner
  declara muerto el 80% de su cuerpo** mientras el `description` y el resumen siguen vendiendo el
  procedimiento muerto y el paquete sigue enviando el script que lo ejecuta (§3). **Es el único de los 25.**

**(2) Formato equivocado — es una regla, no un procedimiento → promover a norma:**
- **`revisar-entregables-agentes`** (0 invocaciones). Contenido 100% vigente, sin una referencia rota, citado
  por 6 wikilinks, y su regla **no está en ningún `CLAUDE.md`** (§7.1). El caso de libro.
  *(Además es huérfano de disparador — §10.3. Los dos diagnósticos se suman, no compiten: la norma establece
  la regla, el hook la recuerda en su momento.)*

**(3) Ritual huérfano de disparador — correcto, pero depende de que alguien lo recuerde → cablear:**
- **`cerrar-slice`** (0 invocaciones) — §10.2. **Retirarlo por no usarse habría eliminado el ritual de cierre
  del proyecto entero**, y con él el único lugar del cerebro que documenta el defecto MWPS (§9.1).
- **`revisar-entregables-agentes`** — §10.3.
- **`cosechar-sesion`** — **NO**: ya está cableado (§10.4). Lo pongo aquí para dejar constancia de que se
  revisó y salió negativo.

**(0) Ninguna de las tres — vigente, cableado o de ritmo bajo por diseño → no tocar:**
- **`cerrar-slice`** es además **load-bearing para dos normas duras**: el seeder lo nombra como el
  mecanismo de "Ningún hallazgo queda narrado" (L195) y como "el recetario completo" del flujo de git (L298).
  Verifiqué que el paso existe donde la norma dice (§8).
- **`orquestar-fanout`** (0 invocaciones) — el seeder lo nombra como el mecanismo del reporte sin
  niñera (L401), **y ya tiene disparador** (`recordar-orquestar` + `delegacion-reporte`, §10.1). Su contenido
  es correcto salvo dos líneas (§4, §6-C3).
- **`canonizar-cerebro`, `consolidar-cerebro`, `unificar-cerebro`** (0 invocaciones) — rituales de baja
  frecuencia **por diseño** (consolidación, reconciliación semanal). Cero invocaciones es su ritmo esperado,
  no un síntoma. Sus referencias están sanas.
- **`investigar-dominio`, `markdown-a-pdf`, `zoom-screenshot`, `construir-missing-manual`** — herramientas
  genuinamente on-demand. Un skill que se usa cuando toca convertir un PDF no está muerto por no usarse en
  septiembre.

**Corolario, y es el dato que más me llamó la atención:** **el uso no predijo nada.** El skill más roto
(`checkpoint`, §1) es el más usado (80). El único obsoleto de raíz (`claude-proyecto-autocontenido`), el
más sano de los de cero uso (`revisar-entregables-agentes`) y el ritual central del proyecto
(`cerrar-slice`) marcan **los tres cero**. La lista de invocaciones sirvió para ordenar por dónde empezar;
como veredicto habría errado en las tres direcciones — retirando el ritual de cierre, dejando roto el skill
más usado, y sin ver que dos de los "muertos" solo necesitaban un cable.

---

## 12 · Correcciones a las premisas de las ampliaciones

**12.1 · `cosechar-sesion` no es un ritual huérfano — ya tiene su hook.** `recordar-cosechar.sh` (Stop, tier
`repo`) lo nombra explícitamente. Detalle y evidencia en §10.4. Su límite es de **alcance** (5 repos), no de
existencia, y es una decisión de tier, no un cable faltante.

**12.2 · La regla de `revisar-entregables-agentes` no vive en ningún `CLAUDE.md`.** Se asumió que "terminó
usándose solo como regla dura en el claude.md"; medido, no está en el seeder, ni en el `~/.claude/CLAUDE.md`
vivo, ni en ningún `CLAUDE.md` de `~/code`. Evidencia en §7.1. La conclusión (*promover a norma*) se sostiene
— por una razón **más fuerte** que la que se dio: hoy nada la hace disparar, ni skill ni norma ni hook.

**12.3 · El hueco de `auditor-semantico` es 1 de 26 repos, no 1 de 7** — y `cortex` mismo tampoco la tiene
donde el skill la busca. §2.

**12.4 · Los datos de uso que recibí cubren 20 de los 25 skills.** Sumando las tres listas (9 con cero + 5
con una + 6 vivos) salen 20. **Faltan 5 sin dato**: `cosechar-sesion`, `desinflar-memorias`, `diagramar`,
`orquestar-fanout` y `rehidratar-hilo`. No cambió mis conclusiones (los cinco los auditué igual, por
contenido), pero conviene saberlo si el contador se va a usar otra vez para priorizar: no estaba completo.

---

## 13 · Resumen de acciones, sin ejecutar ninguna

**Nada de lo de abajo lo toqué. Todo es propuesta.** Cinco tipos de acción:
🔧 corregir ruta · 📝 actualizar procedimiento · 📜 promover a norma · 🔌 cablear · ⚰️ retirar.

| Prioridad | Acción | Dónde | Qué se pierde si se hace |
|---|---|---|---|
| **1** | 📝 **Corregir la tabla de merge**: quitar `--auto`/`--auto-merge` para develop/main (conservarlo para ramita→mini) | `global-claude-md.md:271,294` | Nada. Deja de haber dos verdades sobre el mismo comando. |
| 2 | 🔧 Agregar `checkpoint-mecanico.js` al loop de `install.sh` **y/o** hacer ruidoso el fallo del paso 0 | `install.sh:440` · `checkpoint/SKILL.md:70` | Nada. Solo gana. |
| 3 | 🔧 Corregir las 4 rutas de `auditor-semantico` **o** construir el despliegue `brain/scripts/` → `<repo>/scripts/` | `auditor-semantico/SKILL.md:8,28,39,57` | Nada si se corrige; el arnés vivo de `fluxcore` si se retira. |
| 4 | ⚰️ Decidir el destino de `claude-proyecto-autocontenido`: reescribir / retirar / arreglo mínimo | skill completo + su `bootstrap-claude.sh` | El triage de privacidad, el playbook de consolidación y la regla del slug — **rescatarlos primero**. |
| 5 | 🔧 Prefijar `~/.claude/hooks/` en las 8 invocaciones pelonas | 4 skills + encabezado de los scripts | Nada. *(Prerrequisito del cable #7: `cerrar-slice:77` es una de ellas.)* |
| 6 | 🔌📜 Sumar la media frase de "verifica el entregable" al mensaje de `delegacion-reporte` + promover la regla a norma | `delegacion-reporte.sh` · `global-claude-md.md` §delegación | Nada; el skill queda como el detalle largo. **El cable más barato y de mayor rendimiento.** |
| 7 | 🔌 Cablear `cerrar-slice` — **preferible: `recordar-cerrar-slice.sh` nuevo**, hermano de los 4 `recordar-*`, en vez de editar `confirmar-merge-develop` | `brain/hooks/` + MANIFEST | Nada. **Ojo:** editar el candado exigiría OK explícito para ESE hook (norma de Integridad); el hook nuevo lo evita. |
| 8 | 📝 Borrar la gotcha de "ruido de shell" y el encabezado "Deck" | `consolidar-cerebro:278` · `zoom-screenshot:13` | Nada. |
| 9 | 🔧 Corregir `re_helpers.py`, `sae9-arquitectura`→`-bd`, 16→33, `[[steam-ui-referencia]]`, la frase de PreCompact | 3 skills | Nada. |
| 10 | 📝 Al backlog: el mecanismo pendiente de la DUPLA y el hueco de despliegue de `auditor-semantico` | `.claude/memory/estado-proyecto.md` | Nada. |
| 11 | 📝 Media línea de alcance en la norma de `dod-verificar` (tier `repo`, 6 de 26 repos) | `global-claude-md.md:89` | Nada. |
| — | *(decisión de tier, no bug)* ¿`recordar-cosechar` y `recordar-unificar-cerebro` de `repo` → `global`? | `brain/hooks/MANIFEST` | Ruido en repos sin sistema de memoria — por eso son `repo` hoy. |
| — | *(fleet, fuera de doc)* 12 `bootstrap-claude.sh` con `ln -s` + 8 symlinks vivos + `rama-vieja.sh` cableado | varios repos · `~/.claude/` | Anotado, **no tocado**. |

**Orden que importa:** el #5 es prerrequisito del #7 (no se cablea un ritual con una línea rota adentro), y
el #1 conviene antes que el #7 (si el aviso va a apuntar a `cerrar-slice`, que la norma no siga diciendo lo
contrario que el skill).

**Ningún skill se marcó `retirado`, ninguno se editó, ningún merge.** El tier `retirado` existe y funciona
(`brain/hooks/MANIFEST` + `brain/hooks/RETIRED`, podados por `install-brain.sh:116-148` y
`sincronizar-cerebro.sh`), pero **hoy es solo de hooks**: no hay tier `retirado` en `brain/skills/MANIFEST`
ni consumidor que lo entienda. Si se decide retirar `claude-proyecto-autocontenido`, **primero hay que
construir esa lápida para skills** — o retirarlo a mano y documentarlo.
