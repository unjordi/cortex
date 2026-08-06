# Auditoría DUPLA — juez de merge (decide destino + piso de main) · 2026-08-05

Record durable de la dupla auditora (`auditar-coherencia-cerebro` + `auditar-suficiencia-operativa`)
corrida sobre el fix del juez de merge del PR #262. Parámetro: iterar fix→re-auditar **hasta que dejen
de salir CRÍTICOS/ALTOS/MEDIOS** (BAJOs triaged). Convergió en la ronda 4.

## Alcance
- **Target inicial:** `wt-destino`@30b228c (= develop + #262). Fixes en ramita `fix/auditoria-juez-doc`
  (desde develop `6614220`): commits sucesivos hasta `5a833d1`.
- **Dimensiones:** A (guards/piso, por EJECUCIÓN) · C (fidelidad flowcharts/doc) · SUF (suficiencia operativa).

## Rondas
- **R1** — 1 CRÍTICO · 3 ALTO · 5 MEDIO + BAJOs. CRÍTICO: `MEMORY.md` afirmaba la conducta pre-fix
  ("destino irresoluble → develop", el downgrade que #262 eliminó). ALTO: `find -printf` GNU-only cegaba
  el parity del árbol en mac; piso sin doc durable; flowchart decía `claude -p`. MEDIO: piso sobre-matcheaba
  ("deliberada"/"libertad"/"a maintenance"); README "Cómo probar" incompleto; conteo LIVE 23→28. → todos arreglados.
- **R2** — 0 CRÍTICO · 0 ALTO · 3 MEDIO. Piso residual (anclaje de UN lado: "domain"/"liberalismo"); gitignore
  comentario stale + 03/04/05 fuera del whitelist; **trampa del catch-all** (`docs/flowcharts/*` ignora por
  default → un chart nuevo se pierde en `git add` sin avisar). → arreglados (piso anclado por AMBOS lados;
  whitelist + advertencia; `gen-charts.sh` con RED que avisa charts ignorados).
- **R3** — C y SUF **CONVERGEN** (solo BAJOs: cita `:37`→`:139`, backtick en `gen-charts.sh`, red solo en la rama
  de regen). A: 1 MEDIO nuevo — la rama `promov*.*main` tenía un `.*` desacoplado que puenteaba "promueve"+un
  "main" suelto de otra frase (falso negativo). → arreglados; las ramas promov se **quitaron** (redundantes con
  `(a|hacia) main`).
- **R4** — A: **CONVERGENCIA** (15/15 piso-main, suite 467·0, resiste todos los vectores de subcadena).

## Estado final (verificado técnicamente)
- Suite determinista **467 PASS · 0 FAIL** (incluye 15 `piso-main`); LIVE del **juez de merge** (destino/piso/
  FP/FN/destino-vacío) **verde**. (1 FAIL LIVE intermitente del juez-**dod** —caso P2a fail-safe— reproducido 4/4
  correcto: variación del LLM, hook dod intacto, ajeno a este slice.)
- El piso de main ancla el léxico de release por AMBOS lados (`[^[:alpha:]]`): no casa
  deliberada/libertad/liberalismo/domain/maintenance; conserva release/libera(r)/liberado/liberación/'a main'/'hacia main'.

## Residuos ACEPTADOS (BAJO, con backstop)
- **Piso — fricción segura:** imperativos con clítico/acento ("libéralo/liberá") → DENY a un release legítimo.
  Sobre-bloquear un release es la dirección SEGURA de un gate de máxima consecuencia; el usuario reformula.
- **destino vacío** no tiene piso determinista propio (solo LLM + UNAVAILABLE→DENY + main protegida); por diseño.
- **caché de destino** en TMPDIR sin TTL (pre-existente; staleness→main es seguro).
- **CONVENCIONES §2/§7:** hex tema-claro citado, charts tema-oscuro (valencia semántica consistente; cosmético).

## PARQUEADO — otro guard, su propio slice (requiere OK de unjordi para ESE control)
- **git-branch-guard — falso NEGATIVO angosto del push PELÓN vía target ≠ `CLAUDE_PROJECT_DIR`.** `acg_rama_actual`
  resuelve la rama del `CLAUDE_PROJECT_DIR`, no la del repo objetivo → `git -C <repo-en-develop> push` (o `cd`)
  desde una sesión cuyo `CLAUDE_PROJECT_DIR` está en una ramita NO se bloquea aunque el push toque develop.
  CONFIRMADO por ejecución (A/A2). El destino EXPLÍCITO a base SÍ bloquea siempre; backstop: ramas protegidas
  server-side. En el backlog (`estado-proyecto.md`), su propia ramita.

## Dictámenes completos
`scratchpad/auditoria-juez-destino/AUDITOR-{A,C,SUF}{,2,3,4}-*.md` (efímeros; este doc es el record versionado).
