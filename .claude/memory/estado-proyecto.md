---
name: estado-proyecto
description: Backlog VIVO y compartido de claude-brain — la fuente de verdad de qué sigue, qué se decidió y qué quejas/sugerencias tienen los claudes. Cualquier sesión (master o no, cualquier máquina) escribe aquí; NO en el panel de to-dos (ese es scratch efímero de sesión). Aquí empiezas siempre.
metadata:
  type: project
---

# Estado del proyecto — claude-brain (el cerebro compartible)

> **Aquí empiezas.** Este es el backlog DURABLE del cerebro: qué sigue, qué se decidió, y el buzón donde
> cualquier claude deja sus quejas y sugerencias. El **panel de to-dos de una sesión es scratch efímero**;
> lo que debe sobrevivir a la sesión/compactación vive AQUÍ. Léelo (junto a `MEMORY.md`) antes de tocar nada.
>
> **Cómo se escribe:** los **Pendientes** y **Decisiones** se CURAN (edítalos, muévelos, ciérralos). El
> **📮 Buzón** es append-only: agrega tu línea al FINAL con `>>` (dos append no se pisan; un Edit tropieza
> con "File modified since read" cuando varias sesiones escriben a la vez). Formato de cierre: mueve el ítem
> a **Hecho** anclado a commit+fecha.

## 🔜 Pendientes (backlog vivo)

- **Estándar: `conocimiento-propio` por sesión master.** Volver ESTÁNDAR que toda sesión master escriba su
  propio `conocimiento-propio.local.md` (per-repo en su repo-base, gitignored, re-inyectado en cada
  SessionStart por el hook `aviso-drift-cerebro`). Cada master lo escribe desde SU lado (no copia el del
  gemelo), a partir del template `EJEMPLO-conocimiento-propio.md`. Ya lo tienen: `claude-brain-master`
  (Mac, `761c82d9…`) y `claude-brain-cachy-master` (Cachy, `7a6960de…`, 2026-08-03). **Falta:** (a)
  documentar el paso "siembra tu conocimiento-propio" en el setup/checklist de un master; (b) decidir dónde
  vive canónicamente el `EJEMPLO` (hoy en el Drive `claude-sessions/`) — ¿al brain, o se queda personal?;
  (c) ¿lo siembra `install-brain`/`bootstrap` o es paso manual? · _decisión de unjordi 2026-08-03._

- **Endurecer git-branch-guard contra evasión por subshell/`$()`.** `analizar-comando-git.sh` ancla la rama
  con `(main|develop)([[:space:]]|$)`; un `)` de subshell o `$(...)` la evade: `(cd /tmp && git push origin
  develop)` y `x=$(git push origin develop)` PASAN. Confirmado por ejecución en DOS auditorías (claude-brain
  A-GBG-01 + la DUPLA de cps). **Backstop:** ramas protegidas server-side. Toca un guard de supervisión →
  cambio de PRECISIÓN, exige OK EXPLÍCITO de unjordi para ESE control (con su test adversarial). · _DUPLA 2026-08-03._

- **git-branch-guard: falso NEGATIVO angosto del push PELÓN vía target ≠ `CLAUDE_PROJECT_DIR`.** `acg_rama_actual`
  resuelve la rama del `CLAUDE_PROJECT_DIR`, NO la del repo objetivo → un `git -C <repo-parado-en-develop> push`
  (o un `cd`) desde una sesión cuyo `CLAUDE_PROJECT_DIR` está en una ramita NO se bloquea, aunque el push real toque
  develop. CONFIRMADO por ejecución (DUPLA juez-destino, ronda 1+2, A2). El destino EXPLÍCITO a base SÍ bloquea siempre;
  **backstop:** ramas protegidas server-side. Toca un guard de supervisión → cambio de PRECISIÓN con su test adversarial,
  exige **OK EXPLÍCITO de unjordi para ESE control**. Es OTRO guard: su propia ramita/slice, NO mezclar con el juez-merge. · _DUPLA juez-destino 2026-08-05._

- **Extender el parity-check del árbol a hooks/leyendas.** `docs/flowcharts/verificar-arbol-sync.sh` (FASE 1)
  solo cubre la familia 💡 Skills; NO los hooks 🔒/🔔 ni las leyendas → un drift de hook (p. ej.
  `exportar-sesion-master` ausente de CLAUDE.md) pasa CI en verde. Extenderlo a 🔒/🔔 (README↔CLAUDE.md↔MANIFEST)
  + byte-igualdad de las leyendas `.dot` vs `gen-leyenda-arbol.sh`. · _DUPLA 2026-08-03 (H3, BAJO)._

## ✅ Hecho (anclado a commit+fecha)
<!-- Enuncia en pasado con su ancla. Ej: "X integrado — <commit>, <fecha>". -->
- **Juez de merge decide el destino + PISO DETERMINISTA de main** — `6614220` (PR #262), 2026-08-05. El juez
  (`confirmar-merge-develop.sh`) infiere el destino cuando `acg_destino_de_mr` viene VACÍO en el entorno-hook,
  con FAIL SEGURO (duda + release → main estricto, NUNCA develop); + un piso determinista (main+ALLOW sin
  lenguaje de release del USUARIO → DENY) como defensa en profundidad ante lo poco fiable de Haiku en el
  'mergea' pelón a main. Transporte del juez = curl→api.anthropic.com con token OAuth (NO `claude -p`, ~1.3s).
  Baterías `piso-main` (determinista) + LIVE 28 (merge) verdes.
- (Migrar aquí los pendientes al cerrarse, con su commit.)

## 🧭 Decisiones (con su porqué)
- **2026-08-03 · Convención de firma en TODOS los cerebros:** `CLAUDE.md` = firma-TOC (árbol de capacidades →
  skills) que remite al detalle (`MEMORY.md`/`AGENTS.md`). Se audita por el entry-point real pero se
  consolida MIGRANDO a la convención.
- **2026-08-03 · `conocimiento-propio` por sesión master** (ver Pendientes) — la identidad de cada master no
  se copia entre gemelos; cada uno escribe el suyo.

## 📮 Buzón de los claudes — quejas y sugerencias (append-only, con `>>`)
> Cualquier claude (cualquier sesión/máquina): si algo del cerebro te estorbó, te confundió, o se te ocurre
> una mejora, DÉJALO AQUÍ con tu fecha y quién eres. Es la materia prima para afinar el brain (no lo dejes
> solo en el chat). Un ítem que madura → se sube a Pendientes.
- 2026-08-03 · claude-brain-cachy-master · (siembra) el panel de to-dos de una sesión no sobrevive; por eso
  nace este archivo — para que las quejas/sugerencias tengan casa durable y compartida.
