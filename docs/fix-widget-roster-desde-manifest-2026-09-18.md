# Fix: el roster del widget DERIVA de la fuente viva, no de una lista tecleada (2026-09-18)

## El bug (user-facing)
Los 3 widgets gemelos del cerebro (macOS/Swift `PopoverView.swift`, Windows/C# `PopupForm.cs`,
KDE/QML `main.qml`) **hardcodeaban su roster** de piezas y, sobre esa lista, calculaban el conteo
"incompleto (N)". La lista aún incluía **5 skills RETIRADOS** del `brain/skills/MANIFEST`
(`consolidar-cerebro`, `unificar-cerebro`, `claude-proyecto-autocontenido`, `cosechar-sesion`,
`revisar-entregables-agentes`). Como esos skills ya no se instalan en `~/.claude/skills` (install-brain
los poda por la lápida del MANIFEST), su estado salía **rojo** y **subían el conteo a "incompleto (5)"**
en una máquina sana.

Raíz: la vista ITERABA el roster hardcodeado y chequeaba cada nombre contra `st.skills` (la fuente
viva); los retirados no estaban instalados → rojos → fantasmas.

## La fuente única = el MANIFEST vivo
- **Skills**: `st.skills` = los skills realmente instalados en `~/.claude/skills` = los VIVOS del
  MANIFEST tras la poda de install-brain. Esa ES la fuente viva a runtime.
- **Hooks**: los sets `knownGlobalHooks`/`knownRepoHooks` (== `brain/hooks/MANIFEST` {global,both}/{repo}
  kind=hook, ya verificado por el drift-check e3) + la evidencia de `present`/`wired` en `~/.claude`.
- **Normas**: 4 rótulos fijos de CLAUDE.md, gobernados por `hasNorms`. NO viven en el MANIFEST ni se
  retiran → enumerarlos es legítimo (no es la lista drift-prone).

## El fix de RAÍZ (idéntico en las 3 plataformas — gemelos)
1. **`status()`/`StatusOf`/`brainStatus` pierden la lista enumerada de skills.** Cualquier nombre que
   no sea hook conocido ni norma se resuelve por su **presencia en la fuente viva**:
   `st.skills.contains(name) ? installed : absent`. Un RETIRADO no está en `st.skills` → jamás
   "installed". Sin `case`/`switch`/array de nombres tecleados.
2. **La LISTA a mostrar SALE de la fuente viva** (`isLive`/`IsLive`/`isBrainLive` + `liveItems`): la vista
   filtra los ítems del catálogo curado a los VIVOS (skill → instalada; hook → en el set conocido; norma
   → siempre). La metadata (emoji/desc/detalle) SIGUE siendo el lookup curado, keyed by name; lo que sale
   de la fuente viva es la MEMBRESÍA. Un retirado queda ESTRUCTURALMENTE fuera.
3. **El conteo "incompleto" itera solo los ítems VIVOS** (mismo `liveItems`). Un retirado no puede
   aparecer ni contar. En un install sano, N=0; un hook presente-sin-cablear o ausente sí cuenta (es un
   vivo-no-instalado legítimo).
4. Se quitaron los 5 tiles fantasma del catálogo y las enumeraciones (para que el roster == VIVOS y el
   parity-check quede verde). Esto NO es el band-aid: el band-aid sería solo quitar los 5; aquí, además,
   la LISTA y el conteo DERIVAN de la fuente viva, así que una retirada futura se auto-oculta a runtime
   y el parity-check la caza en CI.

### Anclas por archivo
| plataforma | clasificador (fallthrough a la fuente viva) | roster (tiles) |
|---|---|---|
| macOS/Swift | `PopoverView.swift` `status(_:_:)` → `st.skills.contains(name)` | `brainTiers` + `liveItems()` |
| Windows/C# | `BrainInspector.cs` `StatusOf` → `Skills.Contains(name)` + `IsLive` | `PopupForm.cs` `BrainTiers` + `LiveItems()` |
| KDE/QML | `main.qml` `brainStatus` → `inArr(st.skills, name)` + `isBrainLive` | `brainTiers` + `BrainTier.liveItems` |

## Mecanismo anti-recurrencia (norma "toda norma nace con su mecanismo")
`brain/test-brain.sh`:
- **(e3b) reescrito**: antes exigía que cada skill estuviera en un `switch` enumerado (justo lo que el fix
  elimina). Ahora verifica el contrato NUEVO: (1) el clasificador termina en el **fallthrough a la fuente
  viva** y (2) **NO enumera nombres de skill** (si alguien re-teclea la lista, re-nace el drift).
- **(e3c) NUEVO — paridad roster↔MANIFEST**: por cada widget, compara el roster (tiles + known-sets)
  contra los VIVOS/RETIRADOS del MANIFEST. FALLA si un nombre RETIRADO aparece (fantasma) o si falta un
  VIVO. Detecta el retirado por su nombre ENTRECOMILLADO exacto (`"$r"`) → no matchea una mención en prosa
  dentro de un detalle (p. ej. `…los antiguos merge-squash-guard…` no lleva comillas propias).
  - **Probado**: ROJO contra el código viejo (5 fantasmas por plataforma), VERDE tras el fix.
- Suite completa: **1354 PASS · 0 FAIL**.

## Lo que NO está hecho (no declarar LISTO)
- Falta **rebuild** de los 3 widgets (lo hace unjordi con la herramienta oficial — el updater ⬆, nunca
  install-brain a mano).
- Falta el **QA visual** de unjordi en el widget real (la pestaña Cerebro sin fantasmas, "incompleto (0)"
  en una máquina al día).
- Verificado TÉCNICAMENTE: swiftc -typecheck (rc=0), qmllint sin errores de sintaxis, C# válido
  (ImplicitUsings cubre System), test-brain 1354/0.
