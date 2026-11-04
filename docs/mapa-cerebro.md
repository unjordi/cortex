# 🗺️ Mapa del cerebro — versión navegable (Mermaid)

> Flowcharts del cerebro **visibles en GitHub** (Mermaid se renderiza nativo — no hace falta
> Graphviz ni yEd para *verlos*). Un diagrama por capa: el flujo de git con sus guards, el ciclo
> del hilo/contexto, la delegación a agentes y el mapa de tiers del `MANIFEST`. Para el mapa
> *editable a mano* (yEd) el flujo es otro — ver el skill `diagramar`.

## Índice

1. [Flujo de git y sus guards](#1-flujo-de-git-y-sus-guards) — ramita → mini-develop → develop → main, y qué guard vigila cada cruce.
2. [Ciclo del hilo / contexto](#2-ciclo-del-hilo--contexto) — checkpoint → compact → rehidratar, con `aviso-contexto` y la rama de auto-sync de `aviso-drift-cerebro`.
3. [Delegación y fan-out](#3-delegación-y-fan-out) — gate de costo, freno duro, worktree aislado y cierre automático.
4. [Tiers del MANIFEST](#4-tiers-del-manifest--dónde-se-instala-cada-pieza) — `global` (único vivo) + `retirado`; el cerebro vive solo en global.

---

## 1. Flujo de git y sus guards

El día a día vive en **tu mini-develop** (rama personal `Develop<Usuario>`, sembrada con
`sembrar-mini-develop.sh`): las ramitas entran ahí **sin candado**. Los únicos cruces con
fricción son los deliberados: integrar a `develop` (coordinado, con tu OK) y el release a `main`
(súper-explícito). El push directo a una base **nunca** pasa.

```mermaid
flowchart LR
    subgraph dia["🔄 Día a día — SIN fricción"]
        RAMITA["🌿 ramita<br/>feat/… fix/… docs/…"]
        MINI["🧑‍💻 mini-develop<br/>Develop&lt;Usuario&gt;<br/>(sembrar-mini-develop.sh)"]
        RAMITA -->|"git merge local<br/>o MR con auto-merge<br/>(ningún candado)"| MINI
    end

    subgraph coordinado["🤝 Integración COORDINADA"]
        DEVELOP["🌳 develop"]
    end

    subgraph release["🚀 Release-only"]
        MAIN["🏔️ main"]
    end

    MINI -->|"MR deliberado<br/>OK EXPLÍCITO del usuario<br/>con --squash, sin --auto-merge"| DEVELOP
    DEVELOP -->|"MR de RELEASE<br/>OK SÚPER-explícito<br/>SIN squash (conserva historia)"| MAIN

    MDG["🔗 merge-develop-guard<br/>PASO 0: push/merge DIRECTO a develop·main → DENEGADO, redirige a ramita<br/>(absorbió git-branch-guard el 2026-10-21)<br/>+ MR a develop sin --squash o sin OK expreso → DENEGADO<br/>target-aware: develop pide OK normal,<br/>main exige marca de RELEASE + SIN squash<br/>(consolida los antiguos merge-squash-guard + confirmar-merge-develop)"]
    EMG["🖥️ entorno-maquina-guard<br/>commit de algo machine-specific<br/>al .claude/memory/ del repo → AVISA"]
    LIB["📚 lib analizar-comando-git.sh<br/>(lógica compartida: qué comando toca una base)"]

    MDG -.->|vigila el MR + candado del cruce| DEVELOP
    MDG -.->|candado súper-explícito, sin squash| MAIN
    EMG -.->|escanea lo que ENTRA al commit| RAMITA
    LIB -.-> MDG

    style MDG fill:#7f1d1d,color:#fff
    style EMG fill:#78350f,color:#fff
    style LIB fill:#374151,color:#fff
```

**Leyenda:** rojo = hook que **bloquea** (deny) · ámbar = hook que **avisa/recuerda** (no bloquea)
· gris = lib compartida (los guards la hacen `source` → no divergen). (`recordar-dashboard` RETIRADO
—puramente advisory, medido: ignorado—; doc=realidad ya es norma dura sin mecanismo por-push.)

---

## 2. Ciclo del hilo / contexto

El compact (manual o auto) solo conserva un resumen con pérdida; el ciclo garantiza que el HILO
viva en **disco** antes de compactar y se **reinyecte** al retomar. `PreCompact` no sirve (no
tiene canal para inyectar ni turno del modelo — por eso se retiró `precompact-volcar-estado`).

```mermaid
flowchart TB
    TRABAJO["💬 Sesión trabajando<br/>(el HILO vive solo en el contexto — frágil)"]
    AC["📈 aviso-contexto (PostToolUse, GLOBAL)<br/>al umbral ALTO/CRÍTICO del punto REAL de compact<br/>(80%/92% de autoCompactWindow o la ventana efectiva;<br/>% honesto, respeta autoCompactEnabled): VUELCA el<br/>checkpoint mecánico solito y ORDENA /checkpoint+/compact.<br/>No gotea (silencio bajo el umbral, 1 disparo + 1 escalada)"]
    CP["💾 skill checkpoint (manual, proactivo)<br/>vuelca el HILO a .claude/memory/hilo-mental-actual.md<br/>ligero (pausa) o COMPLETO (antes de compact:<br/>PLAN con el CÓMO · RESUELTO HOY · COSECHA)"]
    COMPACT["🗜️ /compact (o auto-compact)<br/>el resumen comprime — pero el hilo YA está en disco"]

    subgraph retomar["Al abrir / retomar / después de compactar (SessionStart)"]
        RH["🧵 rehidratar-hilo (GLOBAL)<br/>relee hilo-mental-actual.md y lo reinyecta<br/>vía additionalContext (con gate de frescura)"]
        SI["🧭 sesion-inicio (POR-REPO)<br/>reinyecta rama + norma de git +<br/>orden de leer MEMORY/estado-proyecto"]
        DRIFT{"🧬 aviso-drift-cerebro (GLOBAL)<br/>¿repo brained ATRÁS de la<br/>fuente única ~/.cortex?<br/>(diff real, no versión)"}
    end

    SYNC["✅ AUTO-SYNC<br/>parado en TU mini-develop y .claude/ limpio →<br/>apply + commit + push a tu mini SOLO;<br/>llega a develop con tu próxima integración"]
    AVISA["📣 solo AVISA<br/>(en otra rama no escribe nada:<br/>sincronizas tú por ramita→MR)"]
    SIGUE["🔁 la sesión continúa CON el hilo<br/>(skill rehidratar-hilo = gemelo manual del hook,<br/>respaldo si un update del CLI lo rompe)"]

    TRABAJO --> AC
    AC -->|"al umbral vuelca el andamio mecánico + ORDENA /checkpoint"| CP
    TRABAJO -->|"pausa natural / cada ~2h"| CP
    CP --> COMPACT
    COMPACT --> retomar
    TRABAJO -->|"cierre / corte de sesión"| retomar
    RH --> SIGUE
    SI --> SIGUE
    DRIFT -->|"sí, en mini-develop limpia"| SYNC
    DRIFT -->|"sí, en otra rama"| AVISA
    DRIFT -->|"al día"| SIGUE
    SYNC --> SIGUE
    AVISA --> SIGUE
    SIGUE --> TRABAJO

    style CP fill:#1e3a5f,color:#fff
    style RH fill:#14532d,color:#fff
    style SI fill:#14532d,color:#fff
    style AC fill:#78350f,color:#fff
    style DRIFT fill:#4a1d6e,color:#fff
    style SYNC fill:#14532d,color:#fff
```

**El par escritura/lectura:** `checkpoint` escribe · `rehidratar-hilo` lee. El cierre del turno
(la «Definición de LISTO») ya NO lo hace cumplir un hook: `dod-verificar` se retiró el 2026-11-01
(>230 FP del corpus) — hoy es una NORMA cuyo mecanismo es el TRATO/CONTRATO (estatus honesto + la
confirmación/OK del usuario). En el punto del merge sí lo hace cumplir `merge-develop-guard`.

---

## 3. Delegación y fan-out

Reclutar agentes cuesta (gratis / incluido / metered) y muta archivos — dos riesgos, dos familias
de guards: el **gate de costo** antes de arrancar y el **aislamiento + cierre automático** al correr.

```mermaid
flowchart TB
    TASK["🤖 Task: reclutar un agente"]
    LG{"🛑 limite-gasto (PreToolUse/Task)<br/>¿ventana 5h AGOTADA <b>Y</b><br/>overage sin holgura?"}
    DG{"💸 delegacion-gate<br/>nivel de costo del agente<br/>(gratis/incluido: pregunta 1×/máquina ·<br/>metered: 1×/workflow)"}
    REG["📝 delegacion-registrar<br/>materializa el 'pregunta una sola vez'<br/>(consentimiento persistido)"]
    WT["🌲 agente corre en WORKTREE AISLADO<br/>(isolation: worktree — nunca el árbol compartido)"]
    PA["🌳 proteger-arbol<br/>git destructivo que orfanaría commits<br/>en el árbol compartido → AVISA"]
    LW["🧹 limpiar.sh worktrees (script)<br/>barre worktrees de ramas mergeadas;<br/>los vivos quedan anotados en bitácora"]
    LR["🧹 limpiar.sh ramas (script)<br/>barre las ramas ya integradas (squash-safe): LOCALES y<br/>REMOTAS sin contraparte local; conserva trabajo vivo +<br/>protegidas y REPORTA las represadas (viejas sin integrar)"]
    FRENO["⛔ FRENO DURO<br/>sin cupo del plan NI saldo:<br/>el agente moriría a medias"]

    TASK --> LG
    LG -->|"ambos agotados"| FRENO
    LG -->|"hay capacidad"| DG
    DG -->|"consentimiento dado"| REG
    REG --> WT
    PA -.->|"vigila el árbol compartido"| WT
    WT -->|"reporte sin niñera<br/>(disciplina, norma 'Orquesta')"| LW
    LW --> LR

    style LG fill:#7f1d1d,color:#fff
    style FRENO fill:#7f1d1d,color:#fff
    style DG fill:#78350f,color:#fff
    style REG fill:#78350f,color:#fff
    style PA fill:#78350f,color:#fff
    style LW fill:#374151,color:#fff
    style LR fill:#374151,color:#fff
```

El estilo de delegación (UN agente SECUENCIAL por default, paralelo solo si se justifica con el costo
dicho antes; 2 archivos de estado sin redundancia) lo fija la norma **«Delegar a agentes: UNO
secuencial por default»** de `brain/norms/global-claude-md.md` (absorbió al retirado skill
`orquestar-fanout`); la lib `delegacion-comun.sh` comparte la lógica de gate/registro. El gate de
costo es el **freno** (evita runaways); el **empuje** hacia delegar y el **cierre sin niñera** de un
agente (appendear bitácora `>>` + actualizar `estado-proyecto.md` + limpiar worktree) son DISCIPLINA
del máster, no hooks (`recordar-orquestar`/`delegacion-reporte` se retiraron; su regla vive en esa
norma).

---

## 4. Tiers del MANIFEST — dónde se instala cada pieza

[`brain/hooks/MANIFEST`](../brain/hooks/MANIFEST) es la **fuente única**: declara tier (dónde) y
kind (cómo) de cada pieza, y de ahí **deriva** la instalación GLOBAL y el drift-check de `test-brain.sh`
— no hay listas curadas por separado que puedan divergir. Desde el retiro del cerebro por-repo
(2026-11-01, "solo cerebro global") el **único tier vivo es `global`**: todo hook/lib/skill se instala en
`~/.claude` y no viaja por-repo (ya no existen `both`/`repo`). Las **skills** tienen su propio
[`brain/skills/MANIFEST`](../brain/skills/MANIFEST) (todas `global`). El drift de la copia GLOBAL
(hooks/skills/normas vs la fuente) lo vigila `aviso-drift-cerebro`, warn-only.

```mermaid
flowchart LR
    MANIFEST["📜 brain/hooks/MANIFEST<br/>fuente ÚNICA: tier + kind por pieza"]

    subgraph tiers["Tiers declarados"]
        GLOBAL["tier <b>global</b> — ÚNICO vivo, solo ~/.claude<br/><br/>hooks: merge-develop-guard · entorno-maquina-guard ·<br/>no-bypass-deploy · proteger-arbol · proteger-fuente-cerebro ·<br/>limite-gasto · rehidratar-hilo · aviso-contexto ·<br/>aviso-drift-cerebro · exportar-sesion-master · checkpoint-mecanico ·<br/>barrer-ramas · delegacion-gate · delegacion-registrar ·<br/>sesion-inicio · recordar-cosechar<br/>libs: analizar-comando-git · juez-comun · delegacion-comun ·<br/>ramas-zombie · drift-cerebro-comun · contrato-hilo ·<br/>checkpoint-mecanico-comun · sincronizar-tasklist<br/>scripts: limpiar (worktrees/ramas/residuo) ·<br/>verificar-cerebro · cementerio"]
        RETIRADO["🪦 tier <b>retirado</b> — LÁPIDA, no despliega nada<br/>(fecha + motivo en columnas 4+)<br/><br/>hooks: dod-verificar · git-branch-guard · merge-squash-guard ·<br/>confirmar-merge-develop · proteger-autorizaciones · rama-vieja ·<br/>secret-scan · delegacion-reporte · recordar-orquestar ·<br/>recordar-unificar-cerebro · recordar-dashboard · hud-stale<br/>scripts: limpiar-ramas/worktrees/residuo ·<br/>barrer-flotilla-cerebro · limpiar-impl-flotilla<br/>(ver MANIFEST por el motivo de cada una)"]
    end

    GDIR["🏠 ~/.claude/hooks + settings.json<br/>instala: brain/install-brain.sh<br/>(vía bootstrap / install.sh)<br/>+ skills {global} en ~/.claude/skills (árbol completo)"]

    TEST["🧪 brain/test-brain.sh<br/>drift-check (e2): lo instalado<br/>DEBE coincidir con el MANIFEST"]

    MANIFEST --> GLOBAL
    MANIFEST --> RETIRADO
    GLOBAL -->|"install-brain.sh"| GDIR
    RETIRADO -.->|"install-brain.sh PODA<br/>(borra .sh + de-cablea; --limpiar-repo para un repo con copia vieja)"| GDIR
    TEST -.->|verifica| GDIR
    TEST -.->|contra| MANIFEST

    style MANIFEST fill:#1e3a5f,color:#fff
    style TEST fill:#4a1d6e,color:#fff
    style RETIRADO fill:#3f1d1d,color:#fff
```

**Kinds:** `hook` se cablea en `settings.json` (evento) · `lib` solo se copia (los hooks la hacen
`source`) · `script` solo se copia (standalone, se corre a mano/por cron).

---

> **Fuente de verdad: `brain/hooks/MANIFEST` + el árbol de "La jerarquía" del README raíz** (y los
> headers de los propios hooks). Este mapa es **doc de record** (norma *doc = realidad*): si
> agregas, quitas o mueves un hook/skill/norma — o cambia la lógica de un cruce — **actualiza este
> mapa en la MISMA tanda**, igual que el MANIFEST y el árbol del README.
