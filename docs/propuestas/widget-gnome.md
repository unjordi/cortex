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
| F1 | Esqueleto: indicador de panel, popup con riel de pestañas, **Límites**, instalador GNOME | compactRepresentation, tab 0 |
| F2 | **Resumen** (tarjetas, gráfica apilada, heatmap, rachas) + **Modelos** + filtro de rango | tabs 1–2 |
| F3 | **Proyectos** + **Chats**: alias (renombrar), sesiones desplegables, resume en terminal, mover sesión | tabs 3–4 |
| F4 | **Cerebro**: escaneo, salud, curita (heal), updater ⬆ | tab 5 |
| F5 | **Broker**: estado, verificar, acciones, knobs desde el `.tsv` | tab 6 |

F1 primero (es la base). F2–F5 tocan archivos disjuntos (`tabs/*.js`) ⇒ se pueden hacer en paralelo.

## Diferencias de plataforma a resolver
- Gráficas: QML Canvas → `St.DrawingArea` + cairo.
- Diálogos (renombrar/mover): `ModalDialog` de GNOME Shell.
- Terminal para resume: cascada sin `konsole` primero → `ptyxis` (Fedora 41+) → `gnome-terminal` → `kgx` → `x-terminal-emulator` → `xterm`.
- Recarga: en Wayland la extensión nueva carga tras cerrar/abrir sesión (no hay "reload shell" como plasmashell).

## QA
En Wayland Claude no puede mirar la pantalla ⇒ cada fase queda **verificada técnicamente** (carga sin
errores en `journalctl --user`, datos correctos) y el **QA visual lo da Carlos** antes del PR.

## Catálogo del árbol (doc = realidad)
La pestaña Cerebro trae su propio `brainTiers` + lógica de estado que casa NOMBRES. Hoy vive en 5 lugares
(README, MEMORY.md, macOS, Linux-KDE, Windows — ver `.claude/memory/arbol-cerebro-sync.md`); la extensión
GNOME sería el **6.º**. F4 debe: leerlo de una fuente compartida si es viable, o sumarse a esa memoria +
a `verificar-arbol-sync.sh` para no driftear.
