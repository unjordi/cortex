# El árbol del Cerebro vive en 5 lugares — mantenlos EN SYNC (doc <= realidad)

La "pestaña Cerebro" (la jerarquía INVIOLABLE→SKILLS con sus hooks/normas/skills) NO tiene una sola
fuente: está **duplicada a mano en 4 archivos**, y además hay **lógica de estado por GUI** que casa
los NOMBRES. Si tocas uno, **tocas los cuatro** — o el widget y el README (o las plataformas entre sí)
se divergen. Es doc <= realidad aplicado a nosotros: **la realidad (widget) y su doc (README) deben
espejarse.**

## Los 5 catálogos (mismo emoji / name / desc / evento / detalle)
1. **README** raíz — el bloque de árbol de texto (` ``` ` con conectores `├─`/`└─`). **FUENTE del árbol.**
2. **CLAUDE.md** raíz — el mismo árbol, entre `<!-- ARBOL:START/END -->` (es lo que se lee al INICIAR sesión, no el README → NO se puede omitir).
3. **macOS** — `macos/Sources/ClaudeBrain/PopoverView.swift`, propiedad `brainTiers`.
4. **Linux** — `src/plasmoid/contents/ui/main.qml`, propiedad `brainTiers`.
5. **Windows** — `windows/src/ClaudeBrain/PopupForm.cs`, `BrainTiers`.

> **Parcialmente VERIFICADO (2026-08-01):** `docs/flowcharts/verificar-arbol-sync.sh` (corre en `test-brain.sh`/CI)
> compara la familia 💡 Skills de **README ↔ CLAUDE.md ↔ `brain/skills/`** y FALLA si driftean — ese eje ya no
> depende de la disciplina. Los **3 brainTiers de los widgets AÚN se mantienen a mano** (generarlos/verificarlos
> desde la fuente = parqueado, necesita QA visual de los widgets); para ELLOS sigue aplicando la Regla de abajo.

## Y la LÓGICA DE ESTADO por GUI (casa NOMBRES → si renombras, renombra aquí también)
Cada GUI decide "installed/absent/…" por el **nombre** de la pieza. Si cambias el NAME de una norma
(p. ej. "Definición de LISTO" → "Definition of Done") y NO actualizas esto, esa norma se pinta
**"ausente" (rojo)** por no casar:
- macOS: `status(_:_:)` en `PopoverView.swift` (el `case "Definition of Done", "Doc <= realidad", …`).
- Linux: el `if (name === …)` de estado en `main.qml` (junto a la definición de status por pieza).
- Windows: `BrainState.StatusOf(name)` en `BrainInspector.cs` (el `switch` de los 4 nombres de norma).
- Los hooks se casan por `knownGlobalHooks`/`knownRepoHooks` (por basename, no por el name mostrado)
  → renombrar el TEXTO de un hook no rompe su estado; renombrar una NORMA sí.

## Diferencias legítimas de medio (NO son divergencia)
- **por-repo**: el README los agrupa indentados bajo `📁 por-repo`; el widget los marca con el punto
  **◈ azul** (su sistema de auto-reflejo) en su posición. Mismo dato, medio distinto. OK.
- El widget trae `event` + `detail` (se despliegan al tocar) que el README resume; los `desc` cortos
  sí deben coincidir.

## Regla
Al editar la jerarquía: **cambia los 5 catálogos (README + CLAUDE.md + 3 brainTiers) + la lógica de estado
de las 3 GUIs en la misma tanda**, compila las 3 (o delega en paralelo), y **corre `bash docs/flowcharts/verificar-arbol-sync.sh`**
(caza el drift de skills entre README ↔ CLAUDE.md ↔ `brain/skills/`; los widgets aún se verifican con `grep`
de los nombres viejos). Es el paso "Catálogo" de la skill [[agregar-hook-cerebro]]; el flujo de cierre, en [[publicar-widget]].

## Gotcha real (2026-07-08)
El README se pulió (Definition of Done, Doc <= realidad, por-repo indentado) pero el widget quedó con
los nombres viejos — **unjordi lo cachó** ("¿actualizaste el árbol en widget y readme?"). Ahí nació
esta memoria. doc <= realidad nos cachó a nosotros. 😅
