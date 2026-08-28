---
name: reubicar-master
description: >-
  Muda una sesión master COMPLETA de Claude Code a otro repo (caso canónico: los brain-master a
  `cortex`) SIN dejar nada a medias — transcript re-anclado + cwd reescrito, cerebro del master
  migrado por su canal correcto, slug global y TODAS las referencias (masters.json target por-id,
  alias, symlink `memory`) corregidas de forma ATÓMICA, residuo QUIRÚRGICO barrido y doc=realidad.
  Úsala cuando: un `--resume` cae en un folder muerto; un master quedó "a medias" (residuo + resume
  roto, anti-ejemplo helios-selene); o quieres consolidar los dos brain-master (Mac + Cachy) en
  `cortex` sin lobotomizarlos, sin fuga a un repo público ni duplicado divergente. Hermana de
  `claude-proyecto-autocontenido` (esa define DÓNDE vive el cerebro; ésta lo MUEVE de casa).
---

# reubicar-master — mudar un brain-master COMPLETO a su nueva casa (sin lobotomía, sin tail, sin fuga)

## Answer-first: qué hace y cómo, en una frase
Re-ancla una sesión master **cerrada** a un repo destino (transcript + cwd + slug global + masters.json
target + alias + symlink `memory`), migrando **el cerebro del master** clasificado en **3 tiers** por su
canal correcto — **atómicamente** (move + fix de referencias en el MISMO bloque) y **quirúrgicamente**
(sin tocar el symlink `memory` del slug compartido por ~130 sesiones). El sello de LISTO es la **QA
funcional del humano**, no el verde técnico.

## Cuándo usarla · Cuándo NO
**SÍ:**
- Consolidar los brain-master (`claude-brain-cachy-master` en Cachy, `claude-brain-master` en Mac) dentro
  de `cortex` — su casa real (lo dice su `CLAUDE.local.md`), no `plantilladotnet` (donde el cwd los
  ancló por accidente histórico).
- Un `claude --resume <id>` que reanuda en un folder que ya no es la casa del master ("folder muerto").
- Un master que quedó a medias tras un intento previo (residuo en el slug viejo + resume roto = el
  anti-ejemplo **helios-selene**).

**NO es:**
- Un mover-sesiones genérico entre proyectos cualesquiera (para eso está `session-move.js` directo, o el
  menú "Mover a…" del widget). Esta skill es para un **master** (persiste/viaja) con **cerebro** detrás.
- Limpiar sesiones stale/muertas (otra misión, fuera de alcance).
- Tocar `brain/` de cortex (es el PRODUCTO que viaja a los clones; leerlo es lícito, mutarlo desde
  una pasada de reubicación **jamás** — regla dura del `CLAUDE.local.md`).
- Una ruta "solo reorganizar sin mover el cwd": **DESCARTADA por el humano** (00-decisiones). El requisito
  es el move COMPLETO (route b FULL). Bajar el alcance NO es una opción de esta skill.

## Invariantes que NUNCA viola (los cuatro candados)
1. **NO-LOBOTOMÍA** — el master despierta en el destino con su cerebro del-master COMPLETO. `G-PARITY`
   (por CONTENIDO, `diff -q`) bloquea hasta cumplirlo.
2. **NO-SELF-MOVE-EN-VIVO** — nunca mueve un `.jsonl` reciente ni la sesión propia. `G-LIVENESS` bloquea
   por **mtime** + self-check + cita humana. `session-move.js:77` unlinkea sin preguntar → mover una viva
   parte el transcript.
3. **NO-TAIL** — re-ancla + corrige TODAS las referencias (masters.json por-id, alias, slug) de forma
   **atómica**, barre residuo quirúrgico y deja doc=realidad. Todo o nada; el tail es lo que a
   helios-selene le faltó.
4. **NO-FUGA / NO-DUPLICADO** — nada del template .NET entra **versionado** a un repo público; lo sensible
   viaja por canal gitignored per-máquina; `brain/` no se toca.

---

## 1 · La resolución template-vs-personal (el problema difícil, resuelto SIN downgrade)

El miedo a la "media lobotomía" nace de una premisa falsa: que "cerebro del master" = "los 18 skills + 31
memorias que se ven parado en plantilladotnet". **No lo es.** Esos skills son .NET (el PRODUCTO de la
plantilla del equipo, autocargados solo porque el cwd era la plantilla); el oficio del master es MANTENER
el cerebro. Se clasifica por **PROPIEDAD** y cada tier viaja por su canal:

| TIER | Qué es | Canal | Va a cortex |
|---|---|---|---|
| **T1 — cerebro personal PÚBLICO-SEGURO** | memorias de mantener-el-cerebro, genéricas/compartibles (`handoff-peer-claudes-conciso.md`, `plan-molde-cerebros.md`, `diseno-unificar-cerebro.md`, …). Skills: NINGUNO viaja (las 4 de mantenimiento — `agregar-hook-cerebro`, `cortex-widget`, `cambiar-icono`, `publicar-widget` — YA viven en `cortex/.claude/skills`; las ~35 transversales son GLOBAL y se auto-cargan solas) | **versionado por PR** (merge dedup por CONTENIDO en `cortex/.claude/memory`) | **SÍ** |
| **T2 — cerebro personal SENSIBLE** | identidad y autorizaciones (`conocimiento-propio.local.md`, `autorizaciones-vigentes.local.md`, y el `CLAUDE.local.md` de la raíz) | **bundle en Drive** (gitignored) — git NO los propaga | **SÍ, gitignored per-máquina** |
| **T3 — PRODUCTO de la plantilla .NET** | los 18 skills .NET + memorias de plantilla/proyecto (`_PROTOCOLO.md`, `flujo-de-trabajo.md`, `decisiones-infra.md`, `release-develop-main.md`, `modulo-notificaciones.md`, `lecciones-migracion-cps.md`, `estado-proyecto.md`, `bitacora.md`, `entorno-maquina.md`, …) | **SE QUEDA en plantilladotnet** | **NO** |

**Por qué así, no de otra forma:** `cortex` es **PÚBLICO** [verificado: `git@github.com:unjordi/cortex.git`]
y su `.gitignore` **NO ignora** `.claude/skills/*` ni el `CLAUDE.local.md` de la raíz [verificado:
`git check-ignore .claude/skills/foo CLAUDE.local.md` no los lista]. Commitear T3 ahí = **fuga + duplicado
divergente** de la plantilla del equipo. Resultado del corte:
- **cortex** queda con el master + su cerebro COMPLETO (T1∪T2 + las GLOBAL que ya viajan) **sin** los
  18 skills .NET. Cero lobotomía.
- **plantilladotnet** queda íntegro y canónico como plantilla .NET. Nadie la vacía.
- Cero fuga, cero duplicado. Ambos extremos enteros. **Esto NO es hacer menos: es la descomposición
  correcta.** El skill PROPONE este corte; el humano lo confirma (Decisión #2), pero el corte no baja alcance.

### 1.1 · Escape-hatch T3 (opt-in, Decisión #3) — overlay GITIGNORED, nunca versionado
Si el humano QUIERE que el master conserve acceso vivo a los skills .NET en su nueva casa **sin filtrarlos**:
copiarlos a `cortex/.claude/skills/` en local **y** añadir el patrón al `.gitignore` del destino, p. ej.:
```bash
grep -qxF '.claude/skills/_plantilla-*/' "$DST_REPO/.gitignore" || printf '%s\n' '.claude/skills/_plantilla-*/' >> "$DST_REPO/.gitignore"
# copiar cada skill .NET bajo un prefijo que calce el patrón ignorado, p.ej. .claude/skills/_plantilla-instanciar-proyecto/
```
Presentes-pero-no-commiteados → cero lobotomía + cero fuga. **Default: NO** (T3 se queda en plantilladotnet).

---

## 2 · Variables base (poblar una vez; el resto de la skill las reutiliza)
```bash
set -euo pipefail
SRC_REPO="/home/unjordi/code/plantilladotnet"
DST_REPO="/home/unjordi/code/cortex"
SRC="$SRC_REPO/.claude"
DST="$DST_REPO/.claude"
BIN="$DST_REPO/bin"                                              # session-move/import/export.js + session-lib.js
DRIVE="${CLAUDE_SESSIONS_DRIVE:-/run/media/unjordi/SteamAndFiles/GoogleDrive/claude-sessions}"
GLOBAL_MEM="$HOME/.claude/projects/-home-unjordi/memory"          # cerebro de MÁQUINA (donde rig-master dejó memorias)
MASTER_NAME="claude-brain-cachy-master"                          # identidad PER-MÁQUINA (Mac usa claude-brain-master)
ID=""                                                            # ← Decisión #1: el <id> vigente (ver G-ID)
OLD_SLUG="$(printf '%s' "$SRC_REPO" | sed 's/[^a-zA-Z0-9]/-/g')"  # -home-unjordi-code-plantilladotnet (COMPARTIDO ~130 sesiones)
NEW_SLUG="$(printf '%s' "$DST_REPO" | sed 's/[^a-zA-Z0-9]/-/g')"  # -home-unjordi-code-cortex
JSONL="$HOME/.claude/projects/$OLD_SLUG/$ID.jsonl"
NEW_JSONL="$HOME/.claude/projects/$NEW_SLUG/$ID.jsonl"
MJ="$DRIVE/masters.json"
# T1 propuesto (Decisión #2 confirma/ajusta); T2 fijo; T3 no viaja.
MEMORIAS_T1="handoff-peer-claudes-conciso.md plan-molde-cerebros.md diseno-unificar-cerebro.md"
T2_LOCAL="conocimiento-propio.local.md autorizaciones-vigentes.local.md"   # en .claude/memory/
T2_ROOT="CLAUDE.local.md"                                                   # en la raíz del repo
```
> **Nota de ejecución (una sola shell):** los bloques de esta skill comparten las *Variables base* y las
> postcondiciones recomputan lo que necesitan inline (p. ej. S3 recalcula el mtime desde `$JSONL`, no de
> una var de un bloque previo). Aun así, **corre los bloques en la MISMA shell** (o **re-declara las
> Variables base** al abrir una nueva) para que `$ID`, `$OLD_SLUG`, `$DST_REPO`, etc. persistan.

---

## 3 · GATES DUROS (NINGUNA mutación DESTRUCTIVA / del transcript antes de que pasen)

> **Alcance del "preflight":** G-ID y G-GITIGNORE se satisfacen antes de tocar nada. **G-LIVENESS** gatea
> específicamente el move DESTRUCTIVO (S3 export-first / S4) — por eso el flujo §5 corre el prep
> NO-destructivo (S1 commitea un PR, S2 crea un bundle; ninguno toca el `.jsonl` objetivo) ANTES de él.
> **G-PARITY NO es un gate pass-before-mutation:** es una POSTCONDICIÓN de S1–S3 que se DEFINE aquí pero se
> EVALÚA después de migrar (por eso antes de migrar es esperable que falle).

### G-ID · resolver el `<id>` vigente (masters.json tiene DUPLICADOS por nombre)
[verificado] dos `claude-brain-cachy-master` (`7a6960de`, `9cbc2856`) y dos `claude-brain-master`
(`761c82d9`, `1dd207df`), todos con target `code/plantilladotnet`. `session-lib.findSession` devuelve
DETERMINISTA el de **mtime más reciente** (desempate alfabético por slug, `session-lib.js:49`) → con id
duplicado elige el más nuevo, que con duplicados suele ser el vivo. Aun así el gate NO desaparece: ahora es
una **CONFIRMACIÓN** — el humano confirma que el `<id>` auto-seleccionado por mtime es el que quiere mover,
lo CITA textual y puebla `ID=`.
```bash
grep -n '"id"\|"name"' "$MJ"                     # listar candidatos para que el humano elija
[ -n "$ID" ] || { echo "G-ID: falta el <id> vigente (Decisión #1)"; exit 1; }
```

### G-LIVENESS · la sesión objetivo está CERRADA — por **mtime que BLOQUEA** (NO `fuser`/`lsof`)
Gatea el move DESTRUCTIVO (S3+); el prep NO-destructivo S1/S2 corre antes que él (ver nota de §3).
`fuser`/`lsof` sobre el `.jsonl` es **falso-negativo**: Claude Code appendea-y-cierra el fd, no lo sostiene
→ inútil como prueba de "cerrada". Sirve solo como señal EXTRA (si da positivo, seguro está viva). La
prueba de CERRADA = **mtime frío + self-check + cita humana + sin lock de export**:
```bash
LIVE_MIN="${REUBICAR_LIVE_MIN:-15}"
[ "$ID" = "${CLAUDE_SESSION_ID:-}" ] && { echo "BLOQUEO: es la sesión propia (self-move imposible)"; exit 1; }
now=$(date +%s); mt=$(stat -c %Y "$JSONL" 2>/dev/null || stat -f %m "$JSONL" 2>/dev/null || echo 0)
age=$(( (now - mt) / 60 ))
[ "$mt" -gt 0 ] || { echo "BLOQUEO: no puedo leer mtime de $JSONL"; exit 1; }
[ "$age" -lt "$LIVE_MIN" ] && { echo "BLOQUEO: .jsonl tocado hace ${age}m (<${LIVE_MIN}) ⇒ presunta VIVA"; exit 1; }
[ -f "$DRIVE/.export-$ID.lock" ] && { echo "BLOQUEO: auto-export detached en vuelo (el hook exporta en background)"; exit 1; }
```
+ **CITA HUMANA obligatoria** (gate, no la infiere el skill): *"la sesión `<id>` en `<máquina>` está
CERRADA"*. En cross-máquina el mtime se chequea en el host remoto (`ssh <host> "stat -c %Y <jsonl>"`).
> **Consecuencia clave:** la sesión que EJECUTA esta skill NO puede moverse a sí misma (mtime caliente +
> self-check). Por eso el move de cada master lo dispara **el OTRO** — ver la danza §6.

### G-GITIGNORE · BLINDAR el `.gitignore` del destino ANTES de depositar nada sensible
`cortex` es público y su `.gitignore` **no** cubre el `CLAUDE.local.md` de la raíz [verificado].
Depositarlo sin blindar lo dejaría TRACKEADO = fuga. Se blinda ANTES de tocar T2:
```bash
for pat in 'CLAUDE.local.md' '.claude/memory/*.local.md' '.claude/settings.local.json'; do
  grep -qxF "$pat" "$DST_REPO/.gitignore" || printf '%s\n' "$pat" >> "$DST_REPO/.gitignore"
done
git -C "$DST_REPO" check-ignore CLAUDE.local.md \
    .claude/memory/conocimiento-propio.local.md \
    .claude/memory/autorizaciones-vigentes.local.md \
  || { echo "G-GITIGNORE: alguno NO quedó ignorado ⇒ ABORTA (riesgo de fuga)"; exit 1; }
```

### G-PARITY · POSTCONDICIÓN (de S1–S3), no gate preflight · el destino tendrá el cerebro-del-master COMPLETO — por CONTENIDO (`diff -q`)
No se mide "18 vs 4 skills" (mezcla plantilla con master). Se mide que **lo clasificado del-master**
(T1∪T2) esté idéntico en el destino:
```bash
fail=0
for m in $MEMORIAS_T1 $T2_LOCAL; do
  diff -q "$SRC/memory/$m" "$DST/memory/$m" >/dev/null 2>&1 || { echo "PARIDAD ROTA / FALTA: $m"; fail=1; }
done
diff -q "$SRC_REPO/$T2_ROOT" "$DST_REPO/$T2_ROOT" >/dev/null 2>&1 || { echo "PARIDAD ROTA: $T2_ROOT"; fail=1; }
[ "$fail" -eq 0 ] || { echo "G-PARITY: BLOQUEA hasta migrar (S2/S3)"; exit 1; }
[ -d "$DST_REPO/brain" ] || { echo "G-PARITY: falta brain/ en destino (¿repo equivocado?)"; exit 1; }   # y JAMÁS se muta
```
(Se DEFINE aquí pero se EVALÚA como postcondición tras S3, NO como gate pass-before-mutation; antes de migrar es esperable que falle. El check `diff -q` de arriba es su definición.)

---

## 4 · MÁQUINA DE ESTADOS (INV: NADA A MEDIAS — re-entrante, postcondición verificada por paso)
Al invocarse, **detecta el estado por sus postcondiciones y CONTINÚA** (no reinicia, no deja tail). Backup
del `.jsonl` antes de toda mutación (lo hace `session-move.js:62-66` solo; en modo import, respáldalo tú).

| Estado | Garantiza | Detector (postcondición) |
|---|---|---|
| **S0** reconstituido | Gate R hecho (lo que "sí iba" en plantilladotnet regresó del slug global) | memorias confirmadas presentes en `$SRC/memory`; `MEMORY.md`↔archivos cuadra |
| **S1** T1 migrado (PR) | T1 versionado, merge dedup por CONTENIDO | `diff -q` T1 = idéntico en `$DST/memory` |
| **S2** T2 empacado | bundle sensible en Drive | `$DRIVE/$ID.brain-local.tgz` existe |
| **S3** export-first | `.gz` de Drive ≥ la sesión (post-cierre) | `stat -c %Y "$DRIVE/$ID.jsonl.gz"` ≥ mtime `.jsonl` |
| **S4** re-anclado ATÓMICO | jsonl en slug nuevo + cwd único + target por-id + alias, en UN bloque | grep cwd único = destino; `.jsonl` viejo ausente; `jq` target = nuevo |
| **S5** saneado | T2 depositado gitignored; residuo quirúrgico; symlink `memory` verificado | T2 presente e ignorado; sin `.jsonl` viejo; symlink compartido intacto |
| **S6** doc=realidad + QA | commit del versionable + docs; QA humano | dashboard/estado al día; humano confirmó resume |

### S0 · Reconstituir el cerebro canónico de plantilladotnet (Gate R — que el ORIGEN tampoco quede a medias)
La consolidación rig-master (2026-08-02) se llevó memorias del proyecto al slug global de MÁQUINA. Regresan
las que sean del **proyecto/plantilla** (NO lo de máquina: kde/nvidia/kernel/openrgb se quedan global).
Descubrimiento (no bulk — el humano clasifica, anti-confabulación):
```bash
grep -rilE 'plantilladotnet|\.NET|blazor|dapper|EF Core|webapi|migracion-ef' "$GLOBAL_MEM/" | sort
BK="$HOME/.claude/reubicar-backups/$(date +%s)"; mkdir -p "$BK"; /bin/cp -a "$SRC/memory" "$BK/memory.src.bak"
MEMORIAS_REGRESAN=""     # ← poblar con lo que el humano confirme (Decisión #4); vacío ⇒ no-op verificado
for m in $MEMORIAS_REGRESAN; do [ -e "$SRC/memory/$m" ] || /bin/cp -f "$GLOBAL_MEM/$m" "$SRC/memory/$m"; done
# re-indexar $SRC/memory/MEMORY.md; diff -q antes de descartar copias del global (a .trash/, NUNCA rm a ciegas)
```
**Honestidad:** hoy NO hay lista confirmada de "memorias de plantilladotnet dejadas en el global"; el grep
es el MÉTODO, la clasificación la hace el humano. **Postcondición S0:** `MEMORY.md`↔archivos cuadra; escaneo
de secretos limpio.

### S1 · Migrar T1 (versionado, por PR — como rig-master, repo compartido)
```bash
cd "$DST_REPO"; git checkout develop && git pull --ff-only
git checkout -b "docs/reubicar-$MASTER_NAME"
# escaneo de secretos ANTES de commitear lo que se co-ubica:
grep -rinE 'pass(word|wd)?|secret|token|api[_-]?key|credential|\.env\b' \
  $(for m in $MEMORIAS_T1; do echo "$SRC/memory/$m"; done) && echo "REVISAR secreto antes de commitear" || true
for m in $MEMORIAS_T1; do
  if [ -e "$DST/memory/$m" ] && ! diff -q "$SRC/memory/$m" "$DST/memory/$m" >/dev/null 2>&1; then
    echo "CONFLICTO $m: existe distinto en destino → reconciliar con humano (no piso)"
  else
    /bin/cp -f "$SRC/memory/$m" "$DST/memory/$m"
  fi
done
# indexar cada uno en $DST/memory/MEMORY.md (doc=realidad; editar, no duplicar líneas)
git add .claude/memory/*.md .claude/memory/MEMORY.md .gitignore
git status --short .claude | grep -iE 'local|\.jsonl|sessions' && { echo "ABORT: algo sensible staged"; exit 1; } || true
git commit -m "docs(cerebro): traslada el cerebro personal del $MASTER_NAME a este repo"
```
Lo SENSIBLE (T2) NO va aquí — va por S2/S5. **Postcondición S1:** `diff -q` T1 idéntico en `$DST`.

### S2 · Empacar T2 (gitignored) para viajar cross-máquina
```bash
tmp2=$(mktemp -d)
for m in $T2_LOCAL; do [ -f "$SRC/memory/$m" ] && /bin/cp -a "$SRC/memory/$m" "$tmp2/"; done
[ -f "$SRC_REPO/$T2_ROOT" ] && /bin/cp -a "$SRC_REPO/$T2_ROOT" "$tmp2/$T2_ROOT"
tar -C "$tmp2" -czf "$DRIVE/$ID.brain-local.tgz" .
/bin/rm -rf "$tmp2"
test -f "$DRIVE/$ID.brain-local.tgz"                                    # postcondición S2
```

### S3 · EXPORT-FIRST (el `.gz` de Drive ≥ la sesión; antídoto a `seed --force`)
`seed.sh --force` pasa `--force` a import **sin freshness** → un `.gz` viejo pisaría lo bueno; y el hook
`exportar-sesion-master.sh:144` **solo AÑADE** ids, **nunca actualiza target**. Con la sesión CERRADA
(G-LIVENESS pasó) se re-exporta fresco ANTES de mover:
```bash
tmpe=$(mktemp -d)
node "$BIN/session-export.js" "$ID" --repo "$tmpe" --name "$MASTER_NAME" --force
/bin/cp -f "$tmpe/.claude/sessions/$ID.jsonl.gz"  "$DRIVE/"
/bin/cp -f "$tmpe/.claude/sessions/$ID.meta.json" "$DRIVE/"
/bin/rm -rf "$tmpe"
# postcondición S3:
[ "$(stat -c %Y "$DRIVE/$ID.jsonl.gz")" -ge "$(stat -c %Y "$JSONL" 2>/dev/null || echo 0)" ] || echo "S3: .gz no es ≥ sesión"
```

### S4 · RE-ANCLAR + FIX TARGET + ALIAS — bloque uninterrumpido (ATÓMICO-en-la-práctica)
El move y el fix de `masters.json` van en el MISMO bloque, sin ventana para que un `seed`/`sync` re-siembre
al slug viejo (= reencarnar helios-selene). **LOCAL** (mismo host, caso Cachy) → `session-move.js` (mueve,
reescribe cwd de TODAS las líneas, respalda, **aborta si colisiona** `session-move.js:60`). **CROSS-MÁQUINA**
→ `session-import.js` desde el `.gz` (re-deriva el slug local y hace el swap `/home`↔`/Users` solo,
`session-import.js:61,73`).
```bash
# 1) mover (local): jsonl → slug nuevo, cwd reescrito a $DST_REPO, backup, origen unlinkeado, aborta si colisiona
node "$BIN/session-move.js" "$ID" --to-cwd "$DST_REPO"          # {ok, fromSlug, toSlug, cwdRewritten, backup, lines}
# 2) verificar re-anclaje ANTES de tocar referencias/residuo:
[ -f "$NEW_JSONL" ] || { echo "ABORTO: no se creó $NEW_JSONL"; exit 1; }
uniqcwd=$(grep -o '"cwd":"[^"]*"' "$NEW_JSONL" | sort -u)
[ "$uniqcwd" = "\"cwd\":\"$DST_REPO\"" ] || { echo "ABORTO: cwd no uniforme: $uniqcwd"; exit 1; }
# 3) INMEDIATAMENTE corregir masters.json target POR-ID (mktemp capturado, sin sponge):
tmpm=$(mktemp)
jq --arg id "$ID" --arg t "${DST_REPO#$HOME/}" \
   '(.masters[] | select(.id==$id)).target = $t' "$MJ" > "$tmpm" && /bin/mv -f "$tmpm" "$MJ"
# 4) alias legible REAL (usa la lib, no editar a mano):
node -e 'require(process.argv[1]).writeAlias(process.argv[2],process.argv[3])' \
  "$BIN/session-lib.js" "$ID" "$MASTER_NAME"
```
**Postcondiciones S4:** `find ~/.claude/projects -name "$ID.jsonl"` = **exactamente 1** (el nuevo); cwd
único = `$DST_REPO`; `jq -r --arg id "$ID" '.masters[]|select(.id==$id).target' "$MJ"` = `${DST_REPO#$HOME/}`;
alias puesto.

### S5 · Depositar T2 + barrido QUIRÚRGICO + symlink verificado
```bash
# depositar el cerebro sensible en el destino (gitignored por G-GITIGNORE):
tar -C "$DST/memory" -xzf "$DRIVE/$ID.brain-local.tgz"
[ -f "$DST/memory/$T2_ROOT" ] && /bin/mv -f "$DST/memory/$T2_ROOT" "$DST_REPO/$T2_ROOT"   # CLAUDE.local.md va a la RAÍZ
git -C "$DST_REPO" status --porcelain | grep -iE 'local\.md|CLAUDE\.local' && { echo "FUGA: sensible visible a git"; exit 1; } || true
# doc=realidad de la identidad: "corro desde plantilladotnet (mi base)" ya es FALSO → revisar a ojo tras editar:
#   conocimiento-propio.local.md del DESTINO: "corro desde cortex (mi nueva base), antes desde plantilladotnet"
# BARRIDO QUIRÚRGICO del slug COMPARTIDO (~130 sesiones): SOLO el <id>.jsonl. El move local ya lo unlinkeó;
# esto es defensivo/idempotente (por si quedó copia o se vino de import). NUNCA el symlink 'memory'.
[ -f "$HOME/.claude/projects/$OLD_SLUG/$ID.jsonl" ] && /bin/rm -f "$HOME/.claude/projects/$OLD_SLUG/$ID.jsonl"
find "$HOME/.claude/projects/$OLD_SLUG" -maxdepth 1 -name memory -type l   # VERIFICAR que el symlink compartido SIGUE vivo
# symlink 'memory' del slug NUEVO → el cerebro COMPLETO (ya apunta a cortex/.claude/memory [verificado]):
readlink "$HOME/.claude/projects/$NEW_SLUG/memory"     # → /home/unjordi/code/cortex/.claude/memory
find -L "$DST" -type l                                 # sin symlinks rotos; si faltara: bash "$DST_REPO/bootstrap-claude.sh"
```

### S6 · doc=realidad + commit + QA FUNCIONAL (humano = sello LISTO)
- **MR de T1 → develop en PREVIEW** (repo compartido): con OK EXPLÍCITO de unjordi y `--squash` (lo exigen
  `confirmar-merge-develop`/`merge-squash-guard`). **NUNCA `--auto-merge`** — integridad de guardarraíles.
  Sin OK, queda en la mini-develop (Decisión #5). Solo lo versionable (T1 + gitignore); jamás
  `.jsonl`/`*.local.md`/`brain/`.
- Actualizar: **dashboard global** (Mapa: el master ahora vive en `code/cortex` + bitácora fechada
  con `>>`), `estado-proyecto.md`, y el `CLAUDE.local.md`/README de plantilladotnet si mencionaba al master
  como residente. **Registrar la RUEDA** (el TAIL que a helios-selene le faltó).
- **LISTO = QA del humano.** `claude --resume $ID` parado en `cortex`; confirmar: (a) reanuda sin
  folder muerto; (b) identidad cargada (conocimiento-propio re-inyectado por `aviso-drift-cerebro`);
  (c) las 4 skills de cortex + las GLOBAL aparecen; (d) las memorias-del-master (T1∪T2) están;
  (e) `masters.json`/alias correctos. **Verde técnico ≠ LISTO. No se declara a ciegas.**

---

## 5 · Resumen del flujo (una máquina)
`S0 canónico-origen → G-GITIGNORE → S1 T1(PR) → S2 T2-bundle → G-LIVENESS(cerrada) → S3 export-first →
S4 {move + target-fix + alias} uninterrumpido → G-PARITY → S5 {deposita T2 + residuo quirúrgico + symlink} →
S6 doc + QA-humano.` Re-entrante: cada S deja postcondición verificable; una corrida a medias se reanuda
desde el primer S cuya postcondición falle.

---

## 6 · Guion CROSS-MÁQUINA — la danza SSH cruzada (UX HEADLINE, lo que pidió el humano)

Requisito textual del humano: *"muevas al gemelo por ssh y luego pedirle a él que te mueva."* La clave que
rompe el huevo-y-gallina: **nadie se auto-mueve** (G-LIVENESS lo impide en vivo) → **cada máquina dispara el
move del OTRO master, que está CERRADO**. SSH es el **plano de control** (dispara el move remoto); **Drive es
el plano de datos** (transporta el `.gz` + el bundle T2); **git-PR** lleva T1. El transcript de cada master
ya es LOCAL a su máquina — SSH no transporta el `.jsonl`, solo ORDENA el move allá.

**Preflight SSH:** `ssh -o BatchMode=yes -o ConnectTimeout=8 unjordi@macbook-pro-de-unjordi.local 'echo ok'`
(key-auth + mDNS) + verificar `node` y `~/code/cortex` remotos.

**Coreografía (consolidar los dos brain-master en cortex):**
1. **Preparar (esta sesión VIVA — solo lo NO-destructivo):** G-ID/G-RECONSTITUTE(S0)/G-GITIGNORE/S1(T1 por
   PR)/S2(bundle T2). Esta sesión NO se mueve a sí misma (G-LIVENESS: mtime caliente).
2. **unjordi CIERRA el gemelo Mac (`<id-mac>`).** Desde Cachy, por SSH, el gemelo (o un shell remoto) corre
   S3–S6 para `<id-mac>` con `session-import.js --repo /Users/unjordi/code/cortex` (import re-deriva
   el slug `/Users/...` y hace el swap solo). Su identidad T2 viaja por el bundle Drive `locals-<master-mac>`;
   T1 le llega con `git pull` del PR mergeado.
3. **unjordi resume el gemelo** en su nueva casa (Mac `cortex`) → gemelo vivo con cerebro completo.
4. **unjordi CIERRA esta sesión Cachy (`$ID`).** El gemelo (ahora vivo en cortex) por SSH corre S3–S6
   para `$ID` con `--to-cwd /home/unjordi/code/cortex`. **Así el gemelo me mueve a MÍ** — yo no me
   auto-muevo (estoy cerrada).
5. **unjordi resume Cachy** en `cortex` → cerebro completo. QA (§S6) en cada máquina.

**Cómo sobrevive el orquestador a su propia reubicación:** esta sesión orquesta el paso 2 (mueve al gemelo);
NO puede ejecutar su propio paso 4 (debe estar cerrada) → lo ejecuta el gemelo. "Sobrevive" reapareciendo con
`claude --resume` desde el slug nuevo.

### 6.1 · Handoff script escrito a DISCO (sobrevive compactaciones)
El skill ESCRIBE el guion del paso destructivo a `$DRIVE/handoff-$ID.sh` (copy-paste para el humano, desde
un shell plano con la sesión cerrada) — así no se pierde si esta sesión compacta antes del cierre:
```bash
cat > "$DRIVE/handoff-$ID.sh" <<EOF
#!/usr/bin/env bash
# handoff reubicar-master $MASTER_NAME ($ID) — CORRER con la sesión CERRADA, desde shell plano.
set -euo pipefail
# (S3 export-first, S4 move+target-fix+alias, S5 deposita T2 + residuo quirúrgico, S6 doc) — ver SKILL §4.
EOF
chmod +x "$DRIVE/handoff-$ID.sh"
```

### 6.2 · Fallback SIN SSH (Drive caído o sin mDNS/key-auth)
Consolidar Mac↔Cachy sin una sola llamada SSH: en CADA máquina, un operador local (sesión fresca o shell
plano) corre S3–S6 para SU master cerrado, importando del `.gz` local de Drive; T1 por `git pull` del PR;
T2 por el bundle Drive. **SSH no exime G-LIVENESS.** Si aparece un `masters (1).json` (copia-en-conflicto de
Drive), reconciliar a mano ANTES de correr (Decisión #6) — masters.json es UN archivo compartido, edición
por-id serializada, nunca en ambas máquinas dentro de la ventana de sync.

---

## 7 · Decisiones del HUMANO (acotadas — se preguntan en RUNTIME, no se asumen)
1. **`<id>` vigente** de cada máquina (duplicados en masters.json).
2. **Frontera T1↔T3** — el skill propone el corte del §1; el humano confirma qué memorias son del-master
   (viajan) vs de-la-plantilla (se quedan). NO baja alcance: mueve TODO lo del master.
3. **Escape-hatch T3** (§1.1): ¿el master conserva acceso vivo a los skills .NET vía overlay gitignored?
   Default NO.
4. **Set de reconstitución (S0)** — qué memorias del slug global "sí iban" a plantilladotnet.
5. **PR de T1 → develop** (con OK explícito + squash, sin auto-merge) o queda en la mini-develop.
6. **Copia-en-conflicto de Drive** (`masters (1).json`) si aparece.
+ **Cita de liveness** ("sesión `<id>` en `<máquina>` cerrada") — gate G-LIVENESS, no lo asume el skill.

## 8 · Modos de fallo → mitigación (tabla de defensa)
| Fallo | Causa | Mitigación |
|---|---|---|
| Lobotomía del master | mover cwd sin llevar T1∪T2 | G-PARITY por CONTENIDO (`diff -q`) bloquea |
| Lobotomía parcial en Mac | `*.local.md` no viaja por git | bundle T2 por Drive; depósito gitignored en cada máquina |
| Fuga del template .NET | commitear T3/skills a repo público (NO gitignored) | T3 se queda; `git ls-files .claude/skills` vacío; overlay solo si opt-in |
| Transcript vivo partido | unlink de sesión viva (`session-move.js:77`) | G-LIVENESS: mtime-bloquea + self-check + cita (no `fuser`) |
| Reencarnar helios-selene | fix de target NO atómico con el move | move + `jq` target por-id + `writeAlias` en el MISMO bloque (S4) |
| Rollback por `seed --force` | `.gz` viejo + target viejo | export-first (S3) con sesión cerrada + target atómico (S4) |
| Borrar symlink `memory` compartido | barrido no-quirúrgico en slug de ~130 sesiones | barrer SOLO `<id>.jsonl`; verificar que el symlink sigue vivo |
| Conflicto Drive de masters.json | edición concurrente de UN archivo | edición por-id serializada; vigilar `masters (1).json` |
| Move NO atómico (a medias) | `session-move.js` hace copy-a-slug-nuevo + unlink-viejo (no es un rename atómico) | respaldado (backup `session-move.js:62-66`) + aborta-si-colisiona (`:60`) + máquina de estados re-entrante: la postcondición S4 detecta un estado a medias y reanuda |
| Backups sin poda | `session-move.js` respalda sin límite | anotar poda de `~/.claude/session-move-backups/` |

## 9 · Pendientes DELEGADOS al brain (fuera del skill)
- Freshness-check en `seed.sh --force` (hoy pisa con `.gz` viejo).
- Que el auto-registro del hook ACTUALICE `target` de un id ya presente (hoy solo añade, `exportar-sesion-master.sh:144`).
- Poda de `~/.claude/session-move-backups/` (se acumulan `.jsonl` de cientos de MB).
