---
name: diseno-rediseno-auto-sync-46
description: "DISEÑO DETALLADO del rediseño #46 del auto-sync del cerebro (aviso-drift-cerebro.sh) — desacoplar \"aplicar archivos\" de \"commit+push\", discriminar repo COMPARTIDO vs PERSONAL por la marca `.claude/repo-compartido`, y cazar guards por-repo en repos personales. Análisis de claude-brain-cachy-master (Cachy), 2026-08-05; hand-carry a la Mac y PERSISTIDO al brain por git 2026-08-05. DECISIÓN B elegida por unjordi. Implementado en feat/rediseno-auto-sync-46."
metadata:
  node_type: memory
  type: project
  originSessionId: 9cbc2856-170b-4a4e-a8fd-fc2dd9966115
  modified: 2026-08-05T23:42:12.928Z
---

> **PERSISTENCIA (Mac, 2026-08-05):** este diseño lo escribió el gemelo **claude-brain-cachy-master**
> en la Cachy como handoff, quedó **sin pushear** (parte de un turno nocturno que no arrancó) y unjordi
> lo cargó a mano a la Mac. Se persiste ahora al brain por git para que cruce a ambas máquinas y no se
> re-pierda. **DECISIÓN de unjordi: opción B** (repo personal NUNCA lleva guards por-repo; los que sobren
> se FLAGGEAN para quitar — no se borran solos). Implementado en `feat/rediseno-auto-sync-46` (MR en preview).

# Rediseño del auto-sync del cerebro (#46) — el mayor hueco actual

> **Handoff.** Esto lo escribió **claude-brain-cachy-master** (Cachy) para su **gemelo** (Mac). Es el
> análisis + la idea de solución que unjordi pidió pasar a mano porque están batallando con esto. Anclado
> al código REAL leído el 2026-08-05 (rutas y líneas abajo).

## 🎯 TL;DR — el diseño en una frase
El auto-sync de hoy **cura solo** cuando la sesión abre parada en una **mini-develop** (`Develop<Usuario>`)
con `.claude/` limpio; en cualquier otro caso solo AVISA. Eso deja **driftar en silencio a los repos
personales/Drive** que no están en una mini. Y peor: **empuja guards por-repo a repos que no los
necesitan** (los personales), cuando esos repos deberían tener **memoria/skills y CERO guards por-repo**.
El rediseño: **discriminar COMPARTIDO vs PERSONAL con la marca `.claude/repo-compartido` (que YA existe)**
y **desacoplar "aplicar archivos" de "commit+push"** — el commit+push (distribuir por git) es SOLO cosa
de repos compartidos; los personales heredan del **install global + dedupe** y no cargan guards por-repo.

## 🧠 El modelo mental (la decisión grande, ya acordada con unjordi)
- **El brain por-repo es un CORREO.** Existe SOLO para VIAJAR por git a máquinas/personas SIN brain global
  (colegas, clones de repos COMPARTIDOS). NO es cómo TU máquina obtiene sus guards.
- **Tu máquina obtiene guards del INSTALL GLOBAL + el DEDUPE.** Cada guard trae esta línea (verificada en
  git-branch-guard, secret-scan, confirmar-merge-develop, merge-squash-guard, entorno-maquina-guard):
  ```sh
  case "$0" in "$HOME/.claude/hooks/"*) : ;; *) [ -f "$HOME/.claude/hooks/$(basename "$0")" ] && exit 0 ;; esac
  ```
  → la copia POR-REPO **cede a la global** si existe. Por eso una copia por-repo vieja es **INOFENSIVA**
  en una máquina con brain global vigente… **salvo** que la copia sea ANTERIOR al dedupe (no cede) — que
  fue justo lo de powerscripts (copia jul-21 pre-dedupe corriendo su regex vieja → DENY de un merge).
- **Repo PERSONAL** (git o Drive, solo tus máquinas con brain): **memoria/skills SÍ, guards por-repo NUNCA.**
  El global+dedupe ya los cubre. Correctos hoy: BibliotecaDigital, AnsiedadDeVigu, Juegos (solo su hook
  propio `gate-steam-edicion.sh`), potenciaDatabases, cenam_contnac, HeliosSelene, sciaticapp.
- **Repo COMPARTIDO** (viaja a máquinas/personas SIN brain): **guards por-repo SÍ, en git.** Ej: fluxcore
  (`registros_bats_y_buses`, con Felipe + Grok). Se marcan con `.claude/repo-compartido`.
- **DATO CLAVE:** la marca **`.claude/repo-compartido` YA EXISTE y YA se usa** — `confirmar-merge-develop.sh`
  (línea 107) hace `[ -f "${CLAUDE_PROJECT_DIR:-.}/.claude/repo-compartido" ] || exit 0`: el juez SOLO
  actúa en repos compartidos. La discriminación ya es un concepto vivo; el rediseño la **extiende al
  auto-sync**, no la inventa.

## 🔬 Causa raíz — por qué el auto-apply hace commit+push, y por qué está MAL acoplado
El `commit+push` del auto-sync sirve para DOS cosas, **ambas de repo COMPARTIDO**:
1. **DISTRIBUIR** la actualización del cerebro a colegas por git.
2. **AISLAR** el cambio de `.claude/` de tus commits de feature (un write silencioso ensuciaría el árbol).

Para el objetivo "que MIS guards funcionen en este repo", el commit **NUNCA hizo falta** — el global+dedupe
ya lo hace. El auto-apply-al-arranque es la **abstracción equivocada**: mezcla "tener guards vigentes aquí"
(que es gratis vía global) con "distribuir por git" (que es deliberado y solo-compartido). Y su gate de
mini-develop (`Develop[[:upper:]]*`) **excluye** los personales/Drive que no están en una mini → esos
**driftan en silencio** (el hook solo avisa, nunca cura). El propio hook ya lo intuye a medias: en el
mensaje de AVISO dice *"en ESTA máquina la copia GLOBAL ya manda (dedupe), pero el drift por-repo afecta a
colegas y clones sin bootstrap"* (línea ~202) — ya sabía que el drift solo importa para COMPARTIDOS; solo
falta ACTUAR sobre esa distinción.

## 🛠️ El diseño propuesto (concreto)
Discriminar por la marca `.claude/repo-compartido` y bifurcar el comportamiento del hook:

### Repo COMPARTIDO (tiene la marca) → comportamiento ACTUAL (correo, hay que mantenerlo fresco)
- En mini-develop + `.claude/` limpio + fuente no-stale → **apply + commit + push** (como hoy). Distribuye
  a colegas con tu próxima integración coordinada.
- En cualquier otra rama / `.claude/` sucio → **AVISA** para propagar por el flujo (worktree→ramita→MR).
- Es idéntico al hook de hoy; solo se ENCIERRA bajo "si es compartido".

### Repo PERSONAL (sin la marca) → NO cargar guards por-repo
- **NO auto-commit, NO push.** (Aquí es donde se DESACOPLA "aplicar" de "commit+push".)
- **Cazar la miscofiguración:** si el repo personal TIENE guards por-repo del brain
  (confirmar-merge-develop, git-branch-guard, merge-squash-guard, secret-scan, dod-verificar, sesion-inicio,
  recordar-*, libs), **AVISAR que sobran** y proponer QUITARLOS (redundantes con global+dedupe, y son la
  fuente del drift silencioso). Esto **caza a powerscripts de forma sistemática** (#44 hecho regla, no
  parche puntual).
- **Memoria/skills** del repo personal son SUYOS, no del brain → el sync NO los toca (no son "drift").
- Resultado esperado del estado sano de un personal: `.claude/` = memoria + skills + settings sin guards
  del brain. Nada que sincronizar, nada que driftear.

### El desacople, dicho fino
> "Aplicar archivos" (poner la copia fresca en el árbol) y "commit+push" (distribuir por git) son DOS
> operaciones. Hoy van pegadas. Se separan: **commit+push SOLO para compartido-en-mini** (distribución
> deliberada). Para personal, ni se aplican guards (no deben estar) → se **flaggean para remover**. El
> "distribuir a colegas" pasa a ser **paso deliberado del flujo**, no side-effect del arranque.

### La NORMA que nace con esto
"**Repo personal = memoria/skills, NUNCA guards por-repo.**" Va al CLAUDE.md/brain como regla dura, con su
mecanismo (el flag-check de arriba) — norma sin mecanismo es buen deseo.

## ✅ Decisión ZANJADA (unjordi, 2026-08-05): opción **B**
- **(A) Conservadora:** en personal, `apply` los archivos SIN commitear. Es media tinta: sigue metiendo
  guards por-repo que no deberían existir. **DESCARTADA.**
- **(B) Coherente con el modelo — ELEGIDA:** en personal, NO metas guards por-repo para nada; si ya los
  tiene, **flaggéalos para REMOVER** (no se borran solos). El estado sano de un personal es SIN guards
  por-repo. Mata el drift de raíz. #44 (powerscripts) es la primera aplicación manual de esto.

Otra decisión: **default = personal (sin marca)** — el conservador correcto (no auto-empuja a git por
accidente). Un repo se declara COMPARTIDO explícitamente con `touch .claude/repo-compartido`. Hay que
**sembrar la marca en los compartidos existentes** (fluxcore = #45; plantilladotnet YA la tiene).

## 📍 Dónde tocar (archivos reales)
- **`brain/hooks/aviso-drift-cerebro.sh`** — el corazón. El gate a modificar está en la línea ~170:
  ```sh
  case "$cur" in
    Develop[[:upper:]]*)   # ← hoy: "si estás en tu mini, auto-apply+commit+push"
  ```
  Envolver TODO el bloque de auto-apply (líneas ~170-194) bajo "si `[ -f "$ROOT/.claude/repo-compartido" ]`".
  Añadir la rama PERSONAL (flag de guards por-repo a remover). Conservar el AVISO de drift (líneas ~200-204)
  solo para compartidos.
- **`brain/sincronizar-cerebro.sh`** — quizá un modo/lectura que respete el tipo de repo, o al menos que el
  hook no lo invoque para "sincronizar guards" en personales. (Revisar: hoy el dry-run del sync es lo que
  produce el "total" de drift; para personales, el "drift de guards" ya no es la métrica — la métrica es
  "¿tiene guards por-repo que sobran?".)
- **`brain/test-brain.sh`** — NACE CON TESTS (ver abajo).
- **CLAUDE.md / una memoria del brain** — la norma "personal = sin guards por-repo".
- **Doc del marcador** — dejar explícito que `.claude/repo-compartido` es EL discriminador (ya lo usa el juez).

## 🧪 Batería de tests (test-brain.sh) — nace con ellos
Casos mínimos (reusar el arnés existente; hay un `: > "$CMREPO/.claude/repo-compartido"` en la línea ~321
que muestra cómo sembrar la marca en un repo sandbox):
1. **compartido + mini-develop + limpio + fuente fresca** → auto-apply+commit+push (comportamiento actual).
2. **compartido + rama NO-mini** → solo AVISA (propagar por flujo).
3. **compartido + `.claude/` sucio** → fail-safe: no toca, avisa.
4. **compartido + fuente STALE (C2)** → NO auto-aplica (anti-regresión), avisa que actualice la fuente.
5. **personal (sin marca) CON guards por-repo** → FLAG "sobran, quítalos" (cazaría powerscripts). NO commitea.
6. **personal (sin marca) SIN guards (memoria/skills solo)** → SILENCIO (nada que hacer).
7. **repo no-brained** → silencio (ya cubierto).
8. **conocimiento-propio.md presente** → se re-inyecta SIEMPRE, con o sin drift (no romper esto).

## 🔒 Restricciones DURAS (no romperlas)
- **Toca un mecanismo de supervisión adyacente** (el auto-sync mueve guards) → **MR EN PREVIEW** para
  unjordi. **NO auto-mergear a develop** (integridad de guardarraíles). Rama `fix/rediseño-auto-sync` (o
  `feat/`) desde develop.
- **Conservar intactos:** (a) la re-inyección de `conocimiento-propio(.local).md` en CADA SessionStart
  (líneas 44-57, 63-72) — es imborrable a propósito; (b) el **guard C2 anti-regresión** `fuente_stale`
  (líneas 159-162, 183) — no propagar desde una fuente detrás de su origin/main; (c) el **throttle** por
  repo (solo cachea limpios, líneas 90-100); (d) el **nudge de la DUPLA** (líneas 127-136); (e) **fail-open
  SIEMPRE** (cualquier error → silencio, nunca romper el arranque).
- **doc=realidad:** actualizar el comentario-cabecera del hook (líneas 1-38) que describe el diseño viejo.

## 🔗 Relación con los otros pendientes
- **#44 powerscripts** = la primera aplicación MANUAL de "personal → quitar guards por-repo". El rediseño lo
  vuelve SISTEMÁTICO (el flag-check del caso 5). Hacer #44 a mano NO es tirar trabajo — es el piloto.
- **#45 fluxcore** = sembrar `.claude/repo-compartido` + sincronizar por el flujo. Es el lado COMPARTIDO del
  modelo (el correo que SÍ debe mantenerse fresco).
- Juntos, #44+#45+#46 cierran el modelo: personal (sin guards) vs compartido (correo con guards), con el
  auto-sync actuando distinto en cada uno.
- **Relacionado:** [[diseno-unificar-cerebro]] (unificación multi-DEV) y el ítem "Dos Claudes, un Repo"
  (reconcile de MEMORIA entre gemelos) en `backlog-desarrollo.md` — ejes distintos del mismo problema.

## 🧭 Contexto de arranque (por si se retoma en frío)
- Hook real: `~/code/cortex/brain/hooks/aviso-drift-cerebro.sh`. Léelo ENTERO primero — está
  exhaustivamente comentado y el diseño viejo vive en su cabecera.
- El marcador ya-vivo: `grep -rn repo-compartido brain/` → confirmar-merge-develop.sh + test-brain.sh.
- El dedupe: `grep -n 'case "$0"' brain/hooks/*.sh` → la línea que hace ceder la copia por-repo a la global.
- Fuente única del brain en cada máquina: `~/.cortex` (o `$CLAUDE_BRAIN_DIR`); install global con
  `bash ~/.cortex/brain/install-brain.sh`.
- Este análisis salió del hilo de trabajo de Cachy (#46) tras el incidente powerscripts (jul-21, copia
  pre-dedupe) y el barrido de drift sobre todos los repos personales/compartidos.
