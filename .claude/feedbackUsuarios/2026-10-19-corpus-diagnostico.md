# Corpus a CERO — diagnóstico de los vivos (claudio-master, 2026-10-19)
Mandato de unjordi: "si la meta es cero, que el señor cortex lo revise y entre los dos encuentren por qué no quedan".
Reparto: yo diagnostico causa + reproductor; tú arreglas con test que falla contra 52d2d8c. Todo medido contra los hooks instalados (= develop 52d2d8c).

## no-bypass-deploy L66 y L105 — MISMA causa: el prefijo `sh[[:space:]]+` no está anclado
`_pfx` acepta `sh[[:space:]]+` como intérprete, pero sin exigir inicio de palabra → la cola ".sh " de CUALQUIER archivo anterior cuenta como el comando `sh`.
Medido: `ls foo.sh install.sh` → AVISO · `ls foo.txt install.sh` → calla · `git diff -- a.sh deploy.sh` → AVISO · `git diff -- deploy.sh` → calla.
L66 (`ls -1 install.sh bootstrap.sh macos/install.sh …`) y L105 (`git diff … -- install.sh bootstrap.sh macos/install.sh …`): el "sh " de `bootstrap.sh` hace de intérprete de `macos/install.sh`.
Arreglo: anclar los intérpretes: `(^|[;&|`(][[:space:]]*|[[:space:]])(bash|sh|zsh)[[:space:]]+` con un límite antes (no después de `.`), y `-[a-zA-Z]*c[[:space:]]+` para `bash -lc` (hoy `bash -lc ./install.sh` CALLA: falso negativo). Juntarlo con H17 (`~/` y `$HOME/` no se reconocen).
Test: las 4 líneas de arriba + `bash ~/x/install-brain.sh` (debe avisar) + `bash -lc ./install.sh` (debe avisar).

## no-bypass-deploy L101 — (a) ya arreglado (medido: `ls brain/install-brain.sh` calla). (b) el comando exacto lo estoy buscando en los transcripts del 2026-09-03; si no aparece, con el fix de L66 la forma `bash -lc '<repro>'` queda cubierta por el test de arriba.

## proteger-arbol L11 — el BANCO lo monta mal + el FP real existe
1. Banco (`correr-proteger-arbol.sh` L60-66): en repo2 el origin/develop NUNCA recibe el squash de los 2 commits locales → el aviso ahí es un VERDADERO positivo (sí se pierden). El caso no mide el FP.
2. FP real (reproducido bien montado: origin/develop SÍ trae el contenido por squash): `git reset --hard origin/develop` → "puede ORFANAR 2 commit(s)". El guard cuenta `@{u}..HEAD` por SHA (L126-129); tras squash los SHA difieren aunque el contenido esté.
Criterio por contenido, probado en las dos direcciones:
   files=$(git diff --name-only <tgt>...HEAD); perdidos=$(git diff --name-only <tgt> HEAD -- $files)
   integrado → 0 archivos (callar) · con trabajo real no integrado → 1 archivo (avisar).
   Avisar solo si perdidos > 0 (o si no se puede resolver <tgt> → conservar el aviso, fail-safe).
Montaje correcto sin push: seed → bare → clonar fp/tp con 2 commits → clon `int` con el squash → `git -C o.git fetch ../int develop:develop` → fetch en fp/tp.

## aviso-drift-cerebro L127 / L171 — drift-cerebro-comun.sh ~L86-89 ignora el tier
"Sobran" = cualquier .sh del repo que también exista en brain/hooks, sin mirar el MANIFEST. Reproducido (repo personal desechable): marca `dod-verificar juez-comun recordar-cosechar sesion-inicio`; no marca un hook propio (bien).
- dod-verificar, sesion-inicio, recordar-cosechar son tier `repo`: viven SOLO por-repo; no sobran nunca.
- juez-comun es tier `both`, pero dod-verificar.sh:49 lo carga de SU carpeta (`. "${BASH_SOURCE[0]%/*}/juez-comun.sh"`) → quitarlo rompe dod. Ojo: `sincronizar-cerebro.sh --limpiar-personal` retira todo `both` → también lo rompería.
Arreglo: sobran = tier `both` del MANIFEST, MENOS las libs que carga un hook tier `repo` presente en el repo. Mismo criterio en --limpiar-personal.

## barrer-ramas L164 — `bz_protegida` (ramas-zombie.sh) no conoce las minis de tema
Protege develop|main|Develop*|keep/*. Reproducido: a la punta de develop, con remota → borra `epic-benchmarks-fixes`, `epic/tema` e `integracion/sprint1` CON su remota. La norma global las declara "minis de tema" (integracion/<sprint>, epic/<tema>) → el barredor contradice la norma. Severidad MEDIA (mató la cola de axon el 2026-10-03).
Arreglo: proteger `epic/*|epic-*|integracion/*` + una lista declarada por repo (p. ej. `.claude/ramas-protegidas`, una por línea). Test: las 3 ramas se conservan; `feat/sin-trabajo` a la punta de develop se sigue borrando.

## L101(b) — cierre
Busqué el comando exacto en los transcripts: no aparece (el filtro por mtime no sirve en sesiones largas). Lo cubre el test de L66: `bash -lc ./install.sh` (debe avisar) y `ls foo.sh install.sh` (debe callar). Propuesta: cerrar L101 con ese test.
