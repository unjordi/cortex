# CLAUDE.md — claude-brain (la FIRMA de este repo)

> **Empieza por aquí.** Este archivo es el TOC de capacidades (la misión de Claude en ESTE repo). El detalle
> operativo vive un nivel abajo (en el skill/memoria que cada línea apunta); el índice de conocimiento es
> `.claude/memory/MEMORY.md`.

## 🧭 Qué ES este repo (y cuándo importa este archivo)
`claude-brain` es un **WORKSPACE de desarrollo SOLO en las 2 máquinas donde se destila/construye el cerebro**
(la MacBook de unjordi + esta Cachy) — es AHÍ donde un Claude trabaja ESTE repo y lee este `CLAUDE.md`. En
**cualquier otra compu es solo una HERRAMIENTA DE INSTALACIÓN**: se clona, se corre el bootstrap/one-liner, y ya
— **ningún Claude opera dentro**. Así que todo lo de abajo aplica al **Claude que DESARROLLA el brain aquí**.

Como workspace (dev) es **doble**: (1) la **FUENTE del template del cerebro** (`brain/` = lo que se instala en
todos los demás repos) y (2) el **widget de cuota** (KDE/macOS/Windows). El cerebro OPERATIVO de ESTE repo vive
en `.claude/`.

> 🛑 **Cuando DESARROLLES aquí — Dualidad TEMPLATE-FUENTE:** `.claude/` = el cerebro de ESTE repo; `brain/` = el
> PRODUCTO que viaja a todos los clones. **Consolidar/positivar/desinflar aplica SOLO a `.claude/`, JAMÁS a
> `brain/`** — mutar el producto como si fuera el cerebro propio lo propagaría a todos los repos. LEER `brain/`
> para entender la misión es lícito; MUTARLO desde una pasada de cerebro, no (eso va por su propio slice de producto).

## 🎯 Misión
Mantener y publicar, con paridad multi-OS: (a) el **template del cerebro** (`brain/skills`, `brain/hooks`,
`install-brain.sh`, `sincronizar-cerebro.sh`, el `MANIFEST` de tiers) y (b) el **widget de cuota**. Que un clon
en cualquier máquina/OS quede operable con `bash .claude/bootstrap-claude.sh`.

## 🛠️ Capacidades (qué HAGO aquí → cómo)
| Capacidad | Método |
|---|---|
| Agregar/modificar un hook del cerebro | skill `agregar-hook-cerebro` |
| Trabajar el widget (build/QA/look en KDE) | skill `claude-brain-widget` |
| Cambiar el ícono del widget | skill `cambiar-icono` |
| Publicar / release del widget | skill `publicar-widget` |
| Auditar + consolidar un cerebro (el PRODUCTO que mantengo) | skills `consolidar-cerebro` + la dupla (`auditar-suficiencia-operativa` + `auditar-coherencia-cerebro`) + `auditar-proceso-algoritmo` |
| Propagar/actualizar el cerebro en un repo | `brain/sincronizar-cerebro.sh` (fuente única = brain, diff-aware, `--prune-orphans`) |

## 📜 Normas de conducta (cómo se trabaja aquí)
- **Flujo de git:** ramita (`feat/…`) → PR → `develop` (con `--squash`); `main` es release-only. NUNCA push a develop/main.
- **doc = realidad:** cambió algo → su doc se actualiza en la misma tanda. Ojo: el **árbol del cerebro vive
  DUPLICADO en 4 lugares** (README + brainTiers macOS/Linux/Windows) → tocar uno = tocar los 4 (ver [[arbol-cerebro-sync]]).
- **Definición de LISTO:** verde técnico ≠ LISTO; exige QA/OK de unjordi.

## 📚 Detalle / conocimiento (un nivel abajo)
- **Índice de memorias** (conocimiento, estado, historia) → `.claude/memory/MEMORY.md`.
- **El producto y su árbol** → `README.md` (bloque «🔒 Hooks Forzosos») + `brain/`.
- Bootstrap tras clonar → `bash .claude/bootstrap-claude.sh` (Linux/mac) · `bootstrap.ps1` (Windows).
