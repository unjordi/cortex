# Auditoría — flowcharts 01 (Propagación) y 02 (Sesión) del cerebro `cortex`

> Auditor de Calidad (experto en procesos industriales/FMEA + análisis de algoritmos), read-only.
> **Fecha: 2026-07-29.** Estreno del skill `auditar-proceso-algoritmo` sobre dos módulos del propio brain.
> **INSUMO, no cierre** — nada aquí está "listo/correcto/a la par"; la validación (rehacer/arreglar) queda
> pendiente de decisión + QA de unjordi. Compañera de `docs/auditoria-flowcharts.md` (2026-07-14, el `.dot` maestro).
> Cotejado contra el CÓDIGO real (hooks + scripts de instalación + MANIFEST + cableado), no solo el dibujo.

## Resumen ejecutivo
Ambos flowcharts modelan bien la ARQUITECTURA conceptual, pero **ninguno es hoy fiel al código**:
- **01 (Propagación)** está materialmente **OBSOLETO**: dibuja como "[futuro]/propuesta 🆕" y como huecos 🔴
  abiertos cosas que **ya existen y funcionan** (`sincronizar-cerebro`, MANIFEST fuente-única, sello
  `.brain-version`, `secret-scan` por-repo, `aviso-drift` como updater). Engaña sobre la madurez real.
- **02 (Sesión)** está **incompleto**: omite 2 de los 4 hooks de `SessionStart` — y son los que **MUTAN git**
  (`aviso-drift-cerebro` puede auto-commit+push; `barrer-ramas` lanza borrado de ramas detached) — y no tiene
  estado de cierre de sesión.
- En la **COSTURA** sesión↔propagación vive el nudo más grave, y **está vivo en el repo AHORA**.

**Los 3 riesgos más graves (todos de costura, todos LIVE y comprobados):**
1. **[ALTO] Anti-drift CIEGO al cableado + auto-sync deja `settings.json` sucio.** `aviso-drift-cerebro` solo
   diffea el CONTENIDO de los `.sh`, nunca el wiring de `settings.json`; y su auto-apply hace
   `git add .claude/hooks` pero `sincronizar --apply` también reescribe `settings.json` → ese cambio queda sin
   commitear. Resultado comprobado en vivo: la plantilla reporta "0 drift / al día" con **3 hooks presentes pero
   SIN cablear**.
2. **[ALTO] `recordar-cosechar` y `recordar-unificar-cerebro` (tier `repo`) NO corren en NINGUNA máquina** para
   la plantilla, y `entorno-maquina-guard` (both) no está cableado por-repo: presentes como archivo en
   `.claude/hooks/` pero ausentes del `settings.json` versionado. Un clon fresco los recibe MUERTOS.
3. **[ALTO] 01 miente por obsolescencia** — presenta problemas ya resueltos como abiertos (es exactamente la
   falla que el precedente predijo: "el mapa envejece hacia la mentira sin sello + check de drift").

## ¿Traían LEYENDA + NORMAS? (la regla dura del skill)
- **LEYENDA: NO** — ninguno de los 11 SVGs contiene leyenda (0 ocurrencias de "leyenda"). La semántica de
  emojis (🔴 hueco · 🟢 ok · 🟠 warning/inyección · 🔔 hook · 💾 skill) y formas (rombo=decisión) hay que
  inferirla. Es leer/auditar a ciegas → **hallazgo en sí y viola la regla dura**.
- **NORMAS: PARCIAL** — ninguno trae un bloque "NORMAS"; ambos traen referencias inline con prefijo `📜 →`
  (punteros, no la norma). El cimiento formal vive aparte en `10-normas-el-cimiento.svg`.

---

## Hallazgos INDIVIDUALES

### Flowchart 02 — Ciclo de vida de la sesión
- **[ALTO] Omite 2 de los 4 hooks reales de SessionStart, y son los que MUTAN el repo.** El cluster lista solo
  `rehidratar-hilo` (global) + `sesion-inicio` (repo). El código (`install-brain.sh:103-107`) cablea CUATRO:
  + `aviso-drift-cerebro` y `barrer-ramas` (globales). No es cosmético: `aviso-drift-cerebro.sh:70-88`, en una
  rama `Develop*` con `.claude/` limpio, hace `--apply` + `git add` + `commit` + `push` SOLO; `barrer-ramas.sh:50`
  lanza `limpiar-ramas.sh` **detached (nohup)** que borra ramas locales. El lector cree que abrir sesión solo
  inyecta contexto de lectura; en realidad puede **commitear, pushear y borrar ramas**. → añadir ambos nodos con
  marca "⚠ ESCRIBE git" y enlazarlos a 01.
- **[MEDIO] No hay estado de CIERRE de sesión.** El ciclo solo abre y reentra por compactación; no dibuja
  SessionEnd/Stop. **NOTA DEL ORQUESTADOR (corrección):** el auditor concluyó "`exportar-sesion-master.sh` no
  existe" porque grepeó solo el working clone `~/code/cortex`. **SÍ existe y CORRE** en el global
  (`~/.claude/settings.json` lo cablea en SessionEnd/Stop/PreCompact; se observó `PreCompact … completed`). El
  desajuste real: o es un hook **personal/global de máquina** (no del MANIFEST del brain) — y entonces mi encargo
  lo listó mal como pieza del brain —, **o** es un hook desplegado SIN fuente en el repo del brain (drift de
  procedencia). **Por verificar** dónde vive su fuente (bloqueado hoy por el bache del classifier de Bash).
- **[BAJO] `dod-verificar`/Stop no está en 02 — por DISEÑO** (vive en `06-declarar-listo-al-fin-de-turno.svg`). No es defecto.
- **[BAJO] Reset del watermark con no-op silencioso.** 02 pinta el reset del baseline como incondicional, pero
  `rehidratar-hilo.sh:51-58`: si `source=compact` sin `transcript_path`, no fija baseline → riesgo de nag falso
  de "INMINENTE" tras compact. → matizar el nodo ("resetea SI hay transcript_path"). *(Ojo: se cruza con el bug
  #2 del aviso-contexto que estamos tratando por otro lado.)*

### Flowchart 01 — Instalación / actualización del cerebro
- **[ALTO] Materialmente OBSOLETO (miente por antigüedad).** Dibuja como futuro/hueco: "[futuro]
  sincronizar-cerebro" (existe, 23-jul), `I8_FIX` "propuesta 🆕 sello de versión (hoy no existe)" (existe:
  `install-brain.sh:127-132`, `sincronizar-cerebro.sh:133-135`, `.brain-version` + MANIFEST con tiers),
  `I8_DIV` 🔴 "clon + bootstrap NO da secret-scan" (resuelto: `secret-scan` es tier `both`, viaja por-repo y
  está cableado en el `settings.json` de la plantilla), `I8_HUECO` 🔴 "no hay cómo actualizar copias por-repo"
  (existe: `aviso-drift` + `sincronizar`). → **REHACER 01** contra el estado actual; conservar solo los huecos vigentes.
- **[MEDIO] `install-brain`: la COPIA se deriva del MANIFEST pero el CABLEADO es HARDCODE** (`:56-68` deriva del
  MANIFEST; `:90-109` cablea con 16 `register_hook` a mano). Agregar un hook global al MANIFEST → se **copia**
  pero **no se cablea** (queda `.sh` muerto). Contraste: `sincronizar-cerebro.sh:100-126` deriva copia Y wiring
  del MANIFEST. Hoy coinciden, pero es drift latente. → derivar el cableado de `install-brain` del MANIFEST + `ev_de()` compartida, o que `test-brain` falle si divergen.
- **[MEDIO] `bootstrap-claude.sh` (plantilla) sigue con `cp -f` incondicional y solo 3 de los 6 `both`.**
  (`~/code/plantilladotnet/.claude/bootstrap-claude.sh:61-80`, fechado 5-jul). Pisa 3 globales con versiones
  stale (el 🔴 `I8_INV` "DRIFT INVERSO" de 01 SIGUE VIVO) y quedó corto vs el MANIFEST actual (6 `both`). →
  que el bootstrap invoque `sincronizar`/`install-brain` derivando del MANIFEST en vez de un `cp -f` de lista fija.

---

## Hallazgos COLECTIVOS / de costura (sesión ↔ propagación)
> Nacen de que `aviso-drift-cerebro` **es a la vez** pieza de sesión (SessionStart) y de propagación (corre `sincronizar`).

- **[ALTO — LIVE, comprobado] El auto-sync de sesión deja `settings.json` fuera del commit.**
  `aviso-drift-cerebro.sh:74-77` hace `sincronizar --apply` (que reescribe `settings.json` vía
  `register_hook`/`dewire_hook`, `sincronizar-cerebro.sh:120,173`) pero solo `git add .claude/hooks` + commit → el
  cambio a `settings.json` queda **sin stagear**. Contradice el contrato del propio hook ("nunca ensucia una
  ramita"). → `git add .claude/hooks .claude/settings.json` en el auto-apply.
- **[ALTO — LIVE, comprobado] La plantilla tiene 3 hooks presentes-pero-SIN-cablear; 2 no corren en ninguna
  máquina.** `settings.json` versionado cablea 7 entradas; presentes-sin-cablear: `entorno-maquina-guard`,
  `recordar-cosechar`, `recordar-unificar-cerebro`. `sincronizar` dice que cablearía **10**. Los 2 `recordar-*`
  son tier `repo` → su única vía es el cableado por-repo → hoy **muertos** para este repo y para todo clon fresco.
  → `sincronizar --apply` + commitear `settings.json` (después de arreglar el `git add` del auto-sync).
- **[ALTO — comprobado] `aviso-drift-cerebro` es CIEGO al drift de cableado → reporta VERDE sobre un repo
  mal-cableado.** `aviso-drift-cerebro.sh:47-56` parsea solo `nuevos + a actualizar + retirado`, nunca el wiring.
  Prueba en vivo: dry-run sobre la plantilla → "0 nuevos · 0 a actualizar · 10 hooks cableados" → total=0 → dice
  "al día" **aunque hay 3 sin cablear**. El mecanismo anti-drift produce un falso "todo bien" sobre justo la
  clase de drift que existe para cazar. → que `sincronizar` reporte y `aviso-drift` cuente un "cableado FALTANTE"
  (hooks kind=hook del MANIFEST cuyo comando no aparece en `settings.json`).
- **[MEDIO] Concurrencia en SessionStart: `aviso-drift` (commit/push) vs `barrer-ramas` (branch -d, detached)
  sobre el mismo `.git`.** Ambos disparan en el mismo SessionStart → posible choque en `.git/index.lock`/ref-locks;
  el proceso detached amplía la ventana. Ni 01 ni 02 muestran el co-disparo ni lo detached. → serializar o
  documentar la independencia como supuesto explícito.
- **[MEDIO — inferido, NO ejecutado] El updater ⬆ reescribe `~/.cortex`/`~/.claude/hooks` con sesión viva.**
  `fetch + merge --ff-only + install.sh`; `install-brain.sh:61-64` hace `cp -f` sobre `~/.claude/hooks/*.sh`. Si
  corre durante una sesión, un hook que sourcea una lib (`analizar-comando-git.sh`) puede leerla a medio
  sobrescribir. Costura sin protección de concurrencia; ninguno de los dos charts la modela. → escritura atómica
  (`cp` a tmp + `mv`) o lock que difiera el update si hay sesión activa.

---

## Re-verificado contra el precedente (2026-07-14) — YA corregidos (no se repiten como abiertos)
- **H1 (push pelón a develop/main no se bloqueaba): RESUELTO.** `analizar-comando-git.sh:16,27-52` resuelve la
  rama actual y detecta push sin refspec (`acg_push_sin_refspec`).
- **H4 (STATUS_RE no era claim-aware): RESUELTO.** `dod-verificar.sh:100-102` subordina `WEAK_STATUS_RE` a `claim != si`.
- (H3/H5/H7 del precedente son de los flowcharts 02-guards y 03, fuera de este par; no re-verificados a fondo.)

## Veredicto
- **01 (Propagación): REHACER** contra el estado actual (MANIFEST fuente-única, las 2 rutas
  `install-brain`/`sincronizar`, `aviso-drift` como updater por-repo, `secret-scan` por-repo); conservar solo los
  huecos vigentes (cableado hardcode en `install-brain`, `cp -f` de `bootstrap-claude.sh`, ceguera al wiring,
  atomicidad del updater).
- **02 (Sesión): ANOTAR + COMPLETAR** — esqueleto correcto; falta los 2 hooks de SessionStart que escriben git,
  marcar que SessionStart puede MUTAR el repo, y decidir el estado de cierre.
- **Ambos: agregar LEYENDA** (ninguno de los 11 SVGs la tiene; la regla dura la exige).
- **Prioridad de arreglo (CÓDIGO, no dibujo):** los 3 hallazgos de costura ALTO están **vivos ahora** y se
  refuerzan (auto-sync no stagea `settings.json` → 3 hooks sin cablear → anti-drift los da por "al día"). Es el
  nudo que ninguna revisión pieza-por-pieza habría cazado.

---
*Estreno del skill `auditar-proceso-algoritmo` (aún en preview, MR #207). Cumplió: cotejó dibujo vs código, method
individual→colectivo, y cazó 3 bugs LIVE que build verde no ve. Pendiente: decisión de unjordi sobre qué atacar y
en qué orden + su QA. El auditor NO declara LISTO.*
