# ⚰️ Cementerio del cerebro — lápidas por ID (NO monumentos)

> Una lápida = **conocimiento que evita re-pisar un callejón caro**, NO un monumento al trauma. Aquí
> vive, en UNA línea, cada mito descartado / decisión revertida / "NO re-proponer": **qué murió ·
> cuándo · con qué se reemplazó o por qué no volver.** El cerebro guarda CONOCIMIENTO, no cicatrices.
>
> Cada entrada tiene un **ID content-hash** (`🪦#<9-hex>`, determinista sobre el "qué murió"). Donde
> una memoria necesita la advertencia, deja solo la **referencia inline** `(🪦#<id>)` — sin repetir el
> monumento. Acuña/appende con `cementerio.sh add "<qué murió>" "<detalle>"`; valida refs↔IDs con
> `cementerio.sh verify`. Este archivo es la ÚNICA casa de las lápidas de ESTE cerebro (viaja con el repo).

### 🪦#03b0d197a — `dockur/windows` en Docker para runtime/UI de Windows
NUNCA jaló en la MacBook de unjordi (2026-07-15) → no es vía de nada. Regla real: **compilar = mac (`EnableWindowsTargeting`); runtime/UI QA = Windows real** (otra compu / Chunito).

### 🪦#7faf66200 — Íconos previos del widget (martillo / speedometer)
martillo `applications-development` (feo en el selector) → speedometer/gauge → hoy **cerebro + chispa** (2026-07-11, QA visual OK). No volver a los previos.

### 🪦#49fed02ee — Canónico de scripts en `scripts/` + Google Drive
extraído al repo propio (`~/code/PowerScripts`) el 2026-06-30 (fuente única; la sync de Drive corrompía el `.git`). No resucitar el layout viejo.

### 🪦#f21a621da — Rez/SetFile para el ícono del login item de macOS
dejan el resource fork a medias → usar `NSWorkspace.setIcon` (ver GOTCHA de íconos).

### 🪦#b23fdf3c6 — `CLAUDE_CODE_OAUTH_TOKEN` con prioridad sobre el login activo
invertido 2026-07-26 (pisaba el cambio de cuenta) → login activo primero, env-token solo fallback headless.

### 🪦#eba90b376 — regex-soup en los guards de LISTO (dod-verificar / confirmar-merge-develop)
jubilado 2026-08-02 → reemplazado por el **JUEZ-Haiku** (comprensión de lectura + veto de cita). NO reintroducir un gate por **regex de intención** (CLAIM_RE/NEG_RE/DEFER_RE/RELEASE_RE/…): era whack-a-mole, cada frasing nuevo abría un FP/FN.

