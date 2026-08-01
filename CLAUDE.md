# CLAUDE.md — claude-brain · el ÁRBOL del cerebro (lo que este brain instala)

> **Esto es la DECLARACIÓN del brain**: el árbol de hooks + normas + skills que se instalan en cada repo.
> Va en `CLAUDE.md` (no solo en el README) porque **al iniciar una sesión se lee el `CLAUDE.md`, no el README**.
> El **detalle de cada skill** vive en `.claude/memory/MEMORY.md`; el código del producto, en `brain/`.
>
> **Fuente del árbol** = el bloque «🔒 Hooks Forzosos» de `README.md`; este archivo lo espeja (committeado, nunca
> vacío en un clon fresco). Un **parity-check** (`docs/flowcharts/verificar-arbol-sync.sh`, en CI) verifica que
> README ↔ este árbol ↔ `brain/skills/` no driftéen (los 3 brainTiers de los widgets se verifican APARTE, a mano — fase 2). `gen-leyenda-arbol.sh`
> genera además las leyendas de los flowcharts. (Generar automáticamente los 3 brainTiers desde la fuente única
> = decisión PARQUEADA — necesita QA visual de los widgets; hoy la paridad se **verifica**, no se **genera**.)

<!-- ARBOL:START — fuente: README.md «🔒 Hooks Forzosos» · a mano, VERIFICADO por docs/flowcharts/verificar-arbol-sync.sh (gen-leyenda-arbol.sh NO toca este archivo, solo las leyendas .dot) -->
```
🔒 Hooks Forzosos — hooks que bloquean (deny) · no negociables
├─ 🚧 git-branch-guard         push/merge a develop·main → denegado
├─ 🔗 merge-squash-guard       MR a develop sin --squash → denegado
├─ 🕵️  secret-scan             commit/push con un secreto → denegado
├─ 💸 delegacion-gate          delegar al llegar al 90% de tu ventana 5h → pide tu OK
├─ 🛑 limite-gasto             sin ventana 5h Y sin overage (ambos agotados) → freno duro
└─ 📁 por-repo · viajan en el .claude de cada repo
   ├─ ✋ confirmar-merge-develop  merge sin tu OK → denegado
   └─ ✅ dod-verificar            cierre sin evidencia/OK → denegado; claim visual a ciegas (sin ver la pantalla) también

🔔 Automático — inyectan / recuerdan (no bloquean)
├─ 📊 recordar-dashboard       en el push recuerda dashboard + doc=realidad (README/docs) — cierre del slice
├─ 🖥️  entorno-maquina-guard    commit de algo machine-specific (aliases/rutas de $HOME/Rosetta/entorno-maquina.md) al .claude/memory/ del repo → avisa
├─ 🕰️  rama-vieja              avisa si la ramita arrastra base vieja
├─ 🌳 proteger-arbol           git destructivo que orfanaría commits sin pushear → avisa (fan-out: usa worktree aislado)
├─ 🛡️  proteger-fuente-cerebro  editar la copia INSTALADA de un hook/skill que tiene fuente en el clon → avisa (se perdería en el próximo sync) (GLOBAL)
├─ 🧹 barrer-ramas             al abrir sesión barre en 2º plano las ramas locales ya integradas (zombie squash-safe; throttle 24h) (GLOBAL)
├─ 📝 delegacion-registrar     materializa el "pregunta una sola vez"
├─ 📮 delegacion-reporte       al terminar un agente: recuerda registrar avance + limpiar su worktree
├─ 🧵 rehidratar-hilo          reinyecta hilo-mental-actual.md al abrir/retomar/compactar (GLOBAL) — con gate de frescura
├─ 📈 aviso-contexto           watermark: avisa "compacta TÚ ahora" antes del auto-compact-sorpresa (GLOBAL)
├─ 🧬 aviso-drift-cerebro      repo brained atrás de la fuente única → en tu mini-develop se AUTO-SINCRONIZA (apply+commit+push); en otra rama, avisa. Al moverse el cerebro, NUDGE a correr la DUPLA (suficiencia+coherencia; contra la firma si hay AGENTS.md, si no sugiere instanciarla) (GLOBAL)
└─ 📁 por-repo · viajan en el .claude de cada repo
   ├─ 🧭 sesion-inicio            reinyecta rama + norma + memoria al abrir
   ├─ 🌾 recordar-cosechar        nudge al cerrar turno: trabajaste y no cosechaste → corre /cosechar-sesion
   └─ ⬆️  recordar-unificar-cerebro  tu mini acumuló aprendizajes sin UNIFICAR a develop → sugiere /unificar-cerebro (gemelo ↑ de aviso-drift)

📜 Normas — reglas que Claude se autoimpone (CLAUDE.md)
├─ 🎯 Definition of Done       verde técnico ≠ Done/Listo/Ya Quedó; exige QA o un OK explícito
├─ 🪞 Doc <= realidad          cambió algo → su doc se actualiza en la tanda
├─ 🌿 Flujo de git             ramita → MR → develop; main es release-only
└─ 💰 Costo de delegación      gratis / incluido / con costo, según tu cuota

💡 Skills — opt-in, las invocas tú  (catálogo COMPLETO con su detalle → MEMORY.md)
├─ 📦 cerrar-slice             build+tests+memoria al día + MR con resumen curado
├─ 💾 checkpoint               vuelca el HILO a memoria para compactar sin perderlo (proactivo)
├─ 💧 rehidratar-hilo          relee el HILO a mano (gemelo del hook; respaldo si un update del CLI rompe el auto-rehidratado)
├─ 🐝 orquestar-fanout         fan-out sin niñera: asigna del backlog, auto-reporta y limpia al cerrar
├─ 🗺️ diagramar                diagramas por destino: .dot→dot2yed→yEd (editar a mano) · Mermaid en .md versionado (verse en GitHub)
├─ 🔬 auditar-proceso-algoritmo  auditor experto read-only (proceso industrial + algoritmo) → hallazgos priorizados; se alimenta de los flowcharts de diagramar
├─ 🩺 auditar-coherencia-cerebro fan-out read-only sobre el PROPIO cerebro (guards+flowcharts+doc): evasiones/huecos/drift, verificado por ejecución → loop hasta converger
├─ 🧪 auditar-suficiencia-operativa  ¿ALCANZA la doc para HACER el trabajo sin romper nada ni re-investigar? tareas reales ✅/⚠️/❌ + RE-auditar tras arreglar
├─ 🧠 consolidar-cerebro       meta-orquestador: dupla → positivar → desinflar → loop de convergencia → cierre con la FIRMA (CLAUDE+MEMORY)
├─ 🪶 desinflar-memorias       adelgaza un árbol de memorias sin perder lecciones: narrativa → lección; mitos descartados → ⚰️ Lápidas AL FINAL
├─ 🕵️ revisar-entregables-agentes    verifica lo que un agente ENTREGA contra la realidad; no relates su reporte como verdad
├─ ☀️ positivar-doc                  reescribe answer-first: 'ESTO SÍ' (método correcto) antes del 'ESTO NO'
├─ 🎓 investigar-dominio             ponte experto en un dominio (fan-out DOC-FIRST) → memorias durables + skills
├─ 🌾 cosechar-sesion                cosecha local: extrae aprendizajes de tu sesión al inbox del equipo
├─ 🧩 unificar-cerebro               reconciliación del cerebro del equipo: integra los aprendizajes mini→develop
├─ 🧳 claude-proyecto-autocontenido  el cerebro VIVE dentro del proyecto (.claude/ + symlink de slug) → viaja con él
├─ 🔍 zoom-screenshot                recorta y amplía regiones de una captura (ffmpeg) para leer texto fino ilegible
└─ 🌙 turno-nocturno           protocolo del turno de noche: eco del contrato, decide-dentro-de-la-cerca, grants durables a disco
```
<!-- ARBOL:END -->

> **Sweep doc=realidad hecho (2026-08-01):** el árbol de arriba lista el catálogo COMPLETO de skills de `brain/skills/`
> (más `consolidar-cerebro`, que llega con el PR #234). Su detalle 1:1 vive en `MEMORY.md`; el parity-check mantiene
> honesto el eje **README ↔ este árbol ↔ `brain/skills/`** (los 3 brainTiers de los widgets son fase 2 — se verifican a mano, el check aún NO los cubre).
