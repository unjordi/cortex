# Widget de cortex para GNOME Shell — plan de port

> Propuesta 2026-10-05 (Carlos, rama `feat/widget-gnome`). Objetivo: **paridad con el plasmoide de KDE**
> (`src/plasmoid/`) en GNOME Shell 48–50, sin reinventar: misma fuente de datos, mismos scripts.

## Por qué
El widget oficial de Linux es solo KDE Plasma 6. En GNOME (Fedora/Ubuntu default) no hay nada: en la
máquina de Carlos corría una extensión local mínima (solo cuota 5 h/semanal) que nunca estuvo en el repo.

## Qué NO cambia (contrato compartido)
- **Datos:** el daemon (`cortex-fetch` + `cortex.timer`) y sus archivos `~/.cache/cortex/{state,stats,sessions}.json`.
  La extensión es VISTA PURA, igual que el plasmoide.
- **Scripts:** `brain-scan.sh`, `broker-scan.sh`, `broker-knobs.sh` y `src/widget-spec/broker-knobs.tsv` se
  REUSAN tal cual (el instalador los copia a la extensión); no se duplican ni se reescriben en JS.
- **Escrituras:** `~/.claude/proyectos-alias.json` y `sesiones-alias.json` con el mismo formato (llaves ordenadas).

## Dónde vive
- `src/gnome-extension/` — uuid `cortex@unjordi.github.io`, `shell-version: ["48","49","50"]`.
  Módulos: `extension.js` (indicador + popup + riel de pestañas), `lib/` (lectura de JSON, subprocesos,
  formatos, colores), `tabs/<pestaña>.js` (una por pestaña), `stylesheet.css`.
- `install.sh`: detecta el escritorio (`XDG_CURRENT_DESKTOP`) → KDE instala el plasmoide (como hoy),
  GNOME instala la extensión (`gnome-extensions install --force` + `enabled-extensions` vía gsettings).
  Empaqueta `brain/` y `version.json` igual que hace con el plasmoide (curita + updater).

## Fases (un PR a `develop` por fase)
| Fase | Contenido | Equivalente QML |
|---|---|---|
| F1 | Esqueleto: indicador de panel, popup con riel de pestañas, **Límites**, instalador GNOME — *hecho; QA visual de Carlos en GNOME anidado* | compactRepresentation, tab 0 |
| F2 | **Resumen** (tarjetas, gráfica apilada, heatmap, rachas) + **Modelos** + filtro de rango y toggle 🖥/☁️ — *hecho, verificado en GNOME anidado; falta QA de Carlos* | tabs 1–2 |
| F3 | **Proyectos** + **Chats**: alias (renombrar), sesiones desplegables, resume en terminal, mover sesión — *hecho, verificado en GNOME anidado (escrituras contra un CLAUDE_CONFIG_DIR temporal); falta QA de Carlos* | tabs 3–4 |
| F4 | **Cerebro**: escaneo, salud, curita (heal), updater ⬆ — *hecho, verificado en GNOME anidado (heal/update en dry-run); falta QA de Carlos* | tab 5 |
| F5 | **Broker**: estado, verificar, acciones, knobs desde el `.tsv` — *hecho, verificado en GNOME anidado (estados reales y de ejemplo; sin arrancar servicios ni escribir knobs); falta QA de Carlos* | tab 6 |

F1 primero (es la base). F2–F5 tocan archivos disjuntos (`tabs/*.js`) ⇒ se hicieron en paralelo.

### Diferencias conocidas con el plasmoide (decisiones de plataforma)
- **Sin tooltips** en St dentro del popup: lo que el QML pone en tooltip va como línea tenue o `accessible_name`.
- **Clic secundario de Proyectos/Chats** = tira de botones bajo la fila (no menú flotante); un `ModalDialog` cierra el popup al abrirse (encima del menú no recibe foco).
- **Confirmaciones del Broker** (Parar/Reiniciar) dentro del panel, no en un diálogo; knobs en dos renglones por el ancho; un solo campo de texto editable a la vez (St.Entry sin foco loguea Clutter-CRITICAL en cada re-pintado).
- **Heatmap** con celdas fijas de 14 px y las semanas más recientes si no caben (el QML escala 8–16 px).
- **Update ⬆**: re-instala con `install.sh --gnome --no-reload-shell` y pide cerrar sesión (GNOME no recarga extensiones en caliente). `CORTEX_DRY_RUN=1` en el entorno del Shell hace que 🩹/⬆ solo registren el comando.
- **Bug encontrado en el QML** (no corregido aquí): `heatmapCells` de `main.qml` parsea `yyyy-MM-dd` como medianoche UTC ⇒ en husos negativos (México) el día de hoy no aparece. Corregido en `lib/stats.js` de GNOME.

## Diferencias de plataforma a resolver
- Gráficas: QML Canvas → `St.DrawingArea` + cairo.
- Diálogos (renombrar/mover): `ModalDialog` de GNOME Shell.
- Terminal para resume: cascada sin `konsole` primero → `ptyxis` (Fedora 41+) → `gnome-terminal` → `kgx` → `x-terminal-emulator` → `xterm`.
- Recarga: en Wayland la extensión nueva carga tras cerrar/abrir sesión (no hay "reload shell" como plasmashell).

## QA
En Wayland Claude no puede mirar la pantalla ⇒ cada fase queda **verificada técnicamente** (carga sin
errores en `journalctl --user`, datos correctos) y el **QA visual lo da Carlos** antes del PR.

## Catálogo del árbol (doc = realidad)
La pestaña Cerebro necesita el `brainTiers` + la lógica de estado que casa NOMBRES. Hoy el catálogo vive en 5
lugares (README, MEMORY.md, macOS, Linux, Windows — ver `.claude/memory/arbol-cerebro-sync.md`).
**Decisión F4: GNOME no es una 6.ª copia.** `src/gnome-extension/lib/catalogo-cerebro.js` LEE el `brainTiers`
(y los conjuntos de hooks/normas) del `main.qml` del plasmoide, que `install.sh` copia a la extensión como
`plasmoid-main.qml`. `verificar-arbol-sync.sh` (check 5) pone rojo el repo si el parser deja de entender el QML.

## F4 — Cerebro: diferencias con el plasmoide
- **Update ⬆:** re-corre `install.sh --gnome --no-reload-shell` desde el clon (mismo fetch + `checkout -B main
  origin/main`); GNOME no recarga extensiones en caliente → el mensaje pide cerrar sesión y volver a entrar.
- **Sin tooltips** en GNOME Shell: lo que el plasmoide pone en tooltip (qué hace el update, el one-liner de
  bootstrap, qué hace la curita) va como línea tenue dentro del propio recuadro.
- **QA sin mutar nada:** con `CORTEX_DRY_RUN=1` en el entorno del Shell (p. ej. `CORTEX_DRY_RUN=1
  src/gnome-extension/dev-anidado.sh 5`), 🩹 y ⬆ solo registran en el journal el comando que correrían.
