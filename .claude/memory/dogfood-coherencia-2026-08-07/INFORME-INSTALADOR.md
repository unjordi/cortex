# Auditoría de COHERENCIA — dimensión INSTALADOR + WIRING (claude-brain)

READ-ONLY. Fecha 2026-08-07. Capas: `~/code/claude-brain` (fuente/dev, branch `chore/skill-to-do-y-desinflador`), `~/.claude-brain` (clon de install, `main` #270), `~/.claude/` (viva).

## Conteo por severidad
- **ALTO: 0**
- **MEDIO: 3**
- **BAJO: 3**

## Coherente (verificado OK)
- MANIFEST ↔ `install-brain.sh` (deriva hooks global/both del MANIFEST, línea 58/129) sin lista paralela; los 18 hooks global/both están cableados en `~/.claude/settings.json`.
- `settings.json` del repo plantilladotnet cablea los 10 hooks repo/both correctos; los ficheros existen en `.claude/hooks/`.
- `juez-comun.sh` (lib `both`) SÍ está en MANIFEST de `main` (clon línea 30) y los hooks que la hacen `source` la acompañan → coherente en la rama liberada.

## MEDIO

### M1 — `install-brain.sh` copia SOLO `SKILL.md`, descarta ficheros compañeros
`~/code/claude-brain/brain/install-brain.sh:149-152` (idéntico en clon `main`):
```
for sk in "$SRC_SKILLS"/*/; do
  [ -f "$sk/SKILL.md" ] || continue
  cp -f "$sk/SKILL.md" "$SKILLS_DIR/$name/SKILL.md"
```
La skill `claude-proyecto-autocontenido` trae `bootstrap-claude.sh` como fichero real; el instalador NO lo despliega. El propio `SKILL.md:135` afirma «El script viene listo como archivo real en la carpeta de este skill (`bootstrap-claude.sh`)» → doc que MIENTE en TODA máquina. La copia viva `~/.claude/skills/claude-proyecto-autocontenido/` solo tiene `SKILL.md`. Sistémico (afecta a `main`).

### M2 — Skills que existen SOLO en vivo, en NINGUNA rama del brain → nunca llegan a otras máquinas
`~/.claude/skills/ingenieria-inversa-gui-db-navegador` y `~/.claude/skills/markdown-a-pdf` están activas (aparecen en el roster) pero `git log --all -- brain/skills/…` no devuelve NADA en `~/code/claude-brain`. Drift local-vs-instalado: se escribieron directo en `~/.claude/skills` y nunca se cosecharon al brain → un clon en otra compu no las tendrá.

### M3 — Cableado global de `recordar-dashboard` mal formado + falta `shell:bash` (rompe en Windows)
En `~/.claude/settings.json` la entrada de `recordar-dashboard` es el comando PELÓN `$HOME/.claude/hooks/recordar-dashboard.sh` (sin `bash "…"`, `shell=null`); `git-branch-guard` y `merge-squash-guard` traen el prefijo `bash` pero también `shell=null`. `register_hook` de `install-brain.sh:96-101` produce SIEMPRE `bash "…"` + `"shell":"bash"`, pero su dedupe por-patrón (línea 99) hace que NO repare la entrada vieja al re-correr → drift pegajoso. En Windows/Git Bash sin `shell:bash` el `$HOME` no expande y el comando pelón no arranca bajo cmd/PowerShell.

## BAJO

### B1 — `to-do` (el DATO conocido): en dev/develop, no en `main`; copia viva STALE
`brain/skills/to-do/SKILL.md` vive en la rama `chore/skill-to-do-y-desinflador` (y develop #271), NO en `main` → el clon `~/.claude-brain` no la tiene y una instalación desde `main` no la despliega aún. Además la copia viva `~/.claude/skills/to-do/SKILL.md` (3.8k, Aug6 13:42) DIFIERE de la fuente (4.2k): le falta la «Regla 3» y el bloque «Por qué existe» reescrito. Mecánica del instalador OK (globbea `brain/skills/*/`, así que al mergear a `main` propagará); es un caso legítimo de «en develop, sin release» + drift de la copia viva. No es bug del instalador.

### B2 — `.app` bundles con brain STALE
`macos/build/*.app/Contents/Resources/brain/VERSION` = **0.1** vs fuente **0.2**; el `install-brain.sh` embebido DIFIERE de la fuente; `Claude Quota.app` ni siquiera trae `sincronizar-cerebro.sh` (solo `Claude Brain Widget.app`). `macos/build` está **gitignored** (artefacto rebuildeable) → cruft local; pero si el `.app` se distribuye, embarca un brain viejo que instalaría hooks v0.1.

### B3 — Árbol de trabajo de la fuente por detrás de `main`
La rama checked-out `chore/skill-to-do-y-desinflador` (HEAD 3ef36b9) NO tiene `juez-comun.sh`, su MANIFEST no lo lista y sus `dod-verificar`/`confirmar-merge-develop` no lo hacen `source`; la feature vive en develop/main + varias `feat|fix/*`. Correr `install-brain.sh`/`sincronizar-cerebro.sh` DESDE esta rama regresaría los hooks y (con `--prune-orphans`) podría podar `juez-comun.sh` dejando hooks que ya no la citan. Artefacto de rama WIP, esperado; no tocar.
