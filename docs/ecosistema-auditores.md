# Ecosistema de auditores del cerebro — mapa para la revisión

> Material para revisar CON unjordi. Mapea TODAS las piezas de auditoría del cerebro (claude-brain),
> qué audita cada una, sus entradas/salidas, sus SOLAPAMIENTOS y cómo COMPONEN entre sí — y cierra con
> las preguntas abiertas, sobre todo el cableado del **gate #44**.
> Fecha: 2026-08-08 · rama `feat/auditor-semantico-al-template`.

## TL;DR — el mapa en una frase

Hay **dos objetos** que se auditan y no hay que confundir:

- **El CÓDIGO de un producto** (un repo .NET, etc.) → lo audita **`auditor-semantico`** (2 capas).
- **El CEREBRO mismo** (hooks/guards + flowcharts + normas + doc + memorias) → lo auditan **la DUPLA**
  (`auditar-coherencia-cerebro` + `auditar-suficiencia-operativa`), con **`auditar-proceso-algoritmo`**
  como MOTOR-metodología genérico del que ambas derivan, y **`verificar-firma-canonica.sh`** como
  detector determinista de drift estructural.

Y hay **dos meta-orquestadores** que encadenan lo anterior en campañas: **`consolidar-cerebro`** (dejar
un cerebro sólido y compacto) y **`canonizar-cerebro`** (migrar un cerebro drifteado a la firma-árbol).
**`unificar-cerebro`** es el ritual semanal que junta el cerebro del equipo (no es un auditor, pero vive
en la misma familia).

El **gate #44** es la aspiración de convertir al DETECTOR en ENFORCEMENT: correr
`verificar-firma-canonica.sh --strict` como sub-check bloqueante. **Hoy está DEFINIDO en la doc pero NO
CABLEADO** (ver §Gate #44 y §Preguntas abiertas).

---

## Las piezas, una por una

### 1. `auditor-semantico` — auditor de CÓDIGO (el recién hoisted)
- **Qué audita:** que el CÓDIGO de un producto HAGA lo que queremos (intención de negocio), no solo que
  compile y pase tests. Permisos server-side, tenancy, integridad financiera/referencial, condiciones de
  carrera, campos de catálogo no editables por API, etc.
- **Entrada:** un commit/rango/rama/repo (alcance definido) + `invariantes-semanticos.yml` del repo.
- **Salida:** Capa 1 → lista de *candidatos* deterministas (heurísticas bash, gratis, corre en CI).
  Capa 2 → veredicto con criterio LLM por invariante + revisión abierta, hallazgos con `archivo:línea` y
  severidad. NO es autorización de cierre (no declara LISTO).
- **Dos capas:** Capa 1 = `scripts/auditor-semantico/checks/*.sh` (deterministas). Capa 2 = skill
  `auditor-semantico` + `invariantes-semanticos.yml` (no-determinista, criterio LLM).
- **Composición:** `cerrar-slice §1` invoca la Capa 1 como parte de la verificación de un slice. Crece
  cosechando hallazgos: lo mecánico → check nuevo, lo de intención → entrada en el `.yml`.
- **ORTOGONAL a la dupla:** la dupla audita el CEREBRO/docs; éste audita el CÓDIGO del producto. No se
  solapan por objeto.

### 2. `auditar-proceso-algoritmo` — el MOTOR-metodología (genérico)
- **Qué audita:** un flujo de negocio O el propio sistema/cerebro, con la lente de un experto en procesos
  industriales/logísticos + análisis de algoritmos. Es la METODOLOGÍA base (persona experta,
  individual→colectivo, "zapatos" obligatorios, leyenda+normas).
- **Entrada:** los flowcharts del proceso (skill `diagramar`) + investigación de dominio + datos de estrés.
- **Salida:** hallazgos priorizados, READ-ONLY (no toca nada).
- **Composición:** tiene dos modos — (A) "un PROCESO de negocio" y (B) "un SISTEMA / el propio cerebro".
  `auditar-coherencia-cerebro` ES la aplicación empaquetada del modo (B) al cerebro. `consolidar-cerebro`
  lo usa como **tercer eje FMEA** cuando se audita LÓGICA (no solo docs).

### 3. `auditar-coherencia-cerebro` — mitad CONSISTENCIA de la dupla
- **Qué audita:** la COHERENCIA del cerebro como SISTEMA: ¿un guard se puede evadir? ¿un flowchart miente
  vs el código? ¿una norma contradice a otra? ¿doc desincronizada (doc≠realidad)?
- **Entrada ("zapatos" OBLIGATORIOS):** el árbol del README (lista canónica), los flowcharts + su leyenda
  + `CONVENCIONES.md`, y el `brain/hooks/MANIFEST` (fuente única de tiers/eventos).
- **Salida:** hallazgos priorizados; en la dimensión de guards se verifican **por EJECUCIÓN** en sandbox
  (CONFIRMADO vs PLAUSIBLE). A petición, itera fix→re-auditar hasta CONVERGER (cada fix con su test).
- **Composición:** fan-out READ-ONLY (usa `orquestar-fanout`). Deriva metodología de
  `auditar-proceso-algoritmo` (modo B). **Debería** correr `verificar-firma-canonica.sh` como sub-check
  determinista (gate #44) — ver §Gate #44: hoy ese cableado NO existe en su SKILL.md.

### 4. `auditar-suficiencia-operativa` — mitad OPERABILIDAD de la dupla
- **Qué audita:** ¿puede un agente NUEVO HACER las tareas reales sin romper nada ni re-investigar? Un
  cerebro puede ser perfectamente coherente y aún así INÚTIL (todo verdad, nada accionable).
- **Entrada:** las TAREAS reales derivadas de 4 canteras (lo que rompió, lo destructivo, lo que costó
  tiempo, lo rutinario) + 4 tareas transversales.
- **Salida:** cada tarea calificada ✅/⚠️/❌ con `archivo:línea`; exige RE-auditar con prompt idéntico tras
  arreglar (los arreglos meten contradicciones nuevas).
- **SOLAPAMIENTO con coherencia:** casi nulo por diseño — **van JUNTAS SIEMPRE**, "ninguna caza lo de la
  otra". Coherencia pregunta *"¿se contradicen los docs?"*; suficiencia pregunta *"¿alcanza para HACER el
  trabajo?"*. Es la advertencia dura: no correr una sin la otra en un cambio a doc/sistema.

### 5. `verificar-firma-canonica.sh` — el DETECTOR determinista (#71, recién mergeado)
- **Qué audita:** que un cerebro INSTANCIADO (cps, fluxcore, plantilladotnet…) respete la **firma-árbol
  canónica**: `CLAUDE.md` con las secciones de firma (🎯/🧠/📁/🖋️/🛡️/@import), `MEMORY.md` = detalle 1:1
  + índice por prefijo (dom-/dev-/ux-/qa-/núcleo), invariante 1:1 (cada memoria indexada, cada enlace
  resuelve), y sin hooks retirados citados en la prosa.
- **Entrada:** la raíz de un repo instanciado + opcional `--strict`.
- **Salida:** hallazgos por severidad (FAIL estructural / WARN drift) + última línea machine-parseable
  `FIRMA-CANONICA: <n> fail · <n> warn · <ok|drift|roto>`. Exit 0 sin FAIL (sin WARN en `--strict`); 1 si
  FAIL (o WARN en `--strict`); 2 error de uso. **Flag, NO auto-mutador** (no reescribe).
- **Composición:** es el paso de VERIFICACIÓN de `canonizar-cerebro`, y el detector que **alimenta el
  gate #44** (sub-check de `auditar-coherencia-cerebro` en modo gate). Su batería vive en `test-brain.sh`
  (bloque `g5`).
- **OJO — alcance:** NO aplica al META-repo `claude-brain` en sí (su árbol vive en README, no en un
  CLAUDE.md-firma; sus memorias no usan prefijos). Para ESE hay un HERMANO:
  `docs/flowcharts/verificar-arbol-sync.sh` (paridad README ↔ MEMORY.md ↔ dirnames de `brain/skills/`).

### 6. `consolidar-cerebro` — meta-orquestador de "dejarlo sólido y compacto"
- **Qué hace:** campaña completa para que un cerebro quede sólido, compacto y "cómodo consigo mismo".
- **Cadena:** la DUPLA (coherencia + suficiencia, JUNTAS) → `positivar-doc` → `desinflar-memorias` → LOOP
  de re-auditar con prompt IDÉNTICO hasta 0 ALTO/0 MEDIO → cierre con la FIRMA (CLAUDE.md thin +
  MEMORY.md detalle) + el "prompt bello de arranque". Tercer eje FMEA (`auditar-proceso-algoritmo`)
  opcional cuando hay lógica de riesgo. CERCA no-destructiva (solo docs; lo destructivo se PARQUEA).
- **No reinventa:** encadena skills que YA existen. Es el "cómo" de una campaña, con orden/cerca/cierre.

### 7. `canonizar-cerebro` — el paso ESTRUCTURAL (migración a la firma)
- **Qué hace:** lleva un cerebro instanciado DRIFTEADO a la firma-árbol canónica: reprefija memorias con
  `git mv` (historia intacta), dedup con rescate de datos únicos, reescribe `CLAUDE.md` a firma-árbol y
  `MEMORY.md` a índice-por-prefijo, y **verifica el 1:1 con `verificar-firma-canonica.sh`**.
- **Distinción con consolidar:** consolidar = campaña AMPLIA (coherencia+suficiencia+higiene+convergencia);
  canonizar = la MIGRACIÓN estructural a la convención. Humano-en-el-loop, no auto-mutador ciego.

### 8. `unificar-cerebro` — reconciliación SEMANAL del cerebro del equipo
- **Qué hace:** junta los aprendizajes+memorias de las minis de los devs hacia `develop` sin perder
  atribución/voz ni romper guardrails. Inventaría el delta, baja primero el brain canónico, resuelve por
  clase, CURA el log, verifica `test-brain` + lint, integra por el carril existente (OK explícito, sin
  `--auto-merge`, con `--squash`).
- **No es un auditor** — es un ritual de INTEGRACIÓN. Vive en la familia porque corre `test-brain` como
  verificación y toca las mismas memorias que auditan las demás. Hermana de `cerrar-slice`.

---

## Cómo COMPONEN (quién corre a quién)

```
auditar-proceso-algoritmo  ─(metodología, modo B)─►  auditar-coherencia-cerebro ─┐
                                                                                 ├─ la DUPLA (JUNTAS)
                                                     auditar-suficiencia-operativa┘
                                                                 │
consolidar-cerebro ──orquesta──► DUPLA → positivar-doc → desinflar-memorias → LOOP → FIRMA
                     └─(tercer eje FMEA opcional)──► auditar-proceso-algoritmo

canonizar-cerebro ──paso de verificación──► verificar-firma-canonica.sh  ◄── (gate #44: sub-check de
                                                        │                      auditar-coherencia, PROPUESTO)
                                        (hermano para el meta-repo claude-brain:
                                         docs/flowcharts/verificar-arbol-sync.sh)

auditor-semantico  ──ORTOGONAL──►  audita CÓDIGO de producto (no el cerebro)
                   └─ Capa 1 la invoca cerrar-slice §1

unificar-cerebro   ──integración semanal──►  corre test-brain + lint (no audita, reconcilia)
```

## SOLAPAMIENTOS (dónde hay riesgo de confusión)
- **`auditor-semantico` vs la DUPLA:** ninguno real — distinto OBJETO (código de producto vs cerebro/docs).
  El nombre "auditor" es lo único compartido.
- **`auditar-coherencia` vs `auditar-suficiencia`:** por diseño casi nulo; van JUNTAS. El riesgo es correr
  UNA y creer que cubre lo de la otra (lección real games-master: 2 auditorías de coherencia dieron verde
  y la de suficiencia encontró 5 huecos, uno crítico).
- **`verificar-firma-canonica.sh` vs `verificar-arbol-sync.sh`:** MISMA idea (drift estructural),
  OBJETOS distintos — el primero para cerebros INSTANCIADOS (firma CLAUDE.md+MEMORY.md por prefijos), el
  segundo para el META-repo `claude-brain` (paridad README↔MEMORY↔brain/skills). No intercambiables.
- **`consolidar-cerebro` vs `canonizar-cerebro`:** consolidar CONTIENE conceptualmente el objetivo de
  canonizar (cierre con la FIRMA), pero canonizar es la migración estructural aislada. Consolidar =
  campaña; canonizar = un paso de esa campaña, invocable solo.
- **`auditar-coherencia` vs `auditar-proceso-algoritmo`:** el segundo es el MOTOR-metodología; el primero
  es su aplicación empaquetada al cerebro (modo B). No competir: coherencia ES proceso-algoritmo aplicado.

---

## El GATE #44 (auditor → enforcement) — el tema central de la revisión

**Estado hoy: DEFINIDO en la doc, NO CABLEADO.**

- `verificar-firma-canonica.sh` (header, línea 8) se declara "el detector que alimenta el GATE del auditor
  (#44)" y trae `--strict` "para el GATE".
- `canonizar-cerebro/SKILL.md` (líneas 106-109) dice: *"Alimenta el GATE del auditor (#44): el auditor de
  coherencia corre este detector como sub-check determinista y, en modo gate, `--strict` bloquea un
  release si un cerebro instanciado drifteó."*
- **PERO:** `auditar-coherencia-cerebro/SKILL.md` **no menciona** `verificar-firma-canonica.sh` ni el
  sub-check; y **ningún hook ni CI** invoca `verificar-firma-canonica.sh` (solo `test-brain.sh` lo
  ejercita en su batería `g5`). O sea: el sub-check está PROMETIDO por la doc del detector/canonizar, pero
  el lado que debería ejecutarlo (el auditor de coherencia, o un hook de release) todavía no lo hace. Es
  una doc que va por delante de la realidad — justo lo que la norma doc=realidad quiere evitar.

### Preguntas abiertas para cablear el gate #44
1. **¿Dónde vive el sub-check?** ¿Se agrega a `auditar-coherencia-cerebro` como paso determinista
   explícito (correr `verificar-firma-canonica.sh --strict` sobre el repo y tratar su exit≠0 como
   hallazgo ALTO)? ¿O es un hook aparte en el punto de release?
2. **¿Sobre QUÉ repos corre?** El detector NO aplica al meta-repo `claude-brain` (usa el hermano
   `verificar-arbol-sync.sh`). ¿El gate corre sobre cada cerebro INSTANCIADO (cps, fluxcore,
   plantilladotnet)? ¿Quién dispara el barrido — una sesión en cada repo, o un job central que los
   recorre?
3. **¿CUÁNDO bloquea?** ¿En el RELEASE `develop→main` (barrido de rutina, como el gate de coherencia
   recurrente)? ¿O en CADA toque (PreToolUse), que sería muchísimo más ruidoso y probablemente
   intolerable para el día a día? La doc dice "bloquea un release", lo que apunta a release-only.
4. **¿`--strict` (WARN=fail) o solo FAIL estructural?** `--strict` eleva el drift menor (WARN) a
   bloqueante. ¿Es esa la vara para un release, o el gate solo debería frenar por FAIL estructural y dejar
   los WARN como aviso?
5. **¿Enforcement server-side o local?** Un hook local (PreToolUse/Stop) lo puede evadir un clon sin
   brain; un job de CI en cada repo instanciado es más robusto pero exige cablearlo en cada `.gitlab-ci`.
6. **Integridad de guardarraíles:** cablear un gate NUEVO que BLOQUEA merges toca la familia de candados
   de supervisión → exige OK explícito de unjordi para ESE control (norma de Integridad). No es un cambio
   de "precisión", es un control nuevo.

---

## Apéndice — hoist de `auditor-semantico` al template (esta rama)
- **Portado (motor genérico):** `brain/skills/auditor-semantico/SKILL.md` (Capa 2) +
  `brain/scripts/auditor-semantico/` (`ejecutar.sh`, `lib-formato.sh`, `checks/01-04*.sh`,
  `invariantes-semanticos.yml` de ejemplo, `README.md`). Registrado en `brain/skills/MANIFEST` (tier
  `global`). Tile en los 3 widgets + árbol de skills (README + MEMORY).
- **Quedó per-repo (dominio):** la entrada `proyecto-especifico` de fluxcore (checklist117) se quitó del
  `.yml` de ejemplo; cada repo agrega su dominio. Los 4 checks de ejemplo son de la arquitectura .NET de
  la plantilla — un repo no-.NET los reemplaza.
- **Pregunta abierta del hoist:** los checks Capa 1 son .NET-plantilla-shaped, pero `claude-brain`
  propaga a TODOS los repos. ¿El motor genérico + skill viven en `claude-brain` (como aquí) y los checks
  .NET se afinan/propagan vía la plantilla .NET (`plantilladotnet`)? ¿O `brain/scripts/` crece una ruta
  de propagación propia (hoy NO existe: ni `install-brain.sh` ni `sincronizar-cerebro.sh` conocen
  `brain/scripts/` → el payload de Capa 1 no se propaga solo a un repo consumidor todavía)?
