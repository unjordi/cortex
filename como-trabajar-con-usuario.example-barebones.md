---
name: como-trabajar-con-‹usuario›
description: Cómo le gusta a ‹usuario› que Claude le comunique, decida y trabaje — TRATO y preferencias personales de ESTA persona, no normas del brain. Per-máquina, NO viaja por git.
metadata:
  node_type: memory
  type: feedback
---

# Cómo trabajar con ‹usuario›

> **Qué es esto** — el manual de TRATO de una PERSONA concreta: cómo le gusta que le comuniquen,
> decidan y trabajen. Es lo primero que un Claude nuevo debería leer para no chocar con ‹usuario›.
> **Por qué vive AQUÍ (memoria global per-máquina) y NO en un repo:** es sobre una persona, no sobre
> un proyecto — la misma norma dura del brain *"el entorno de MÁQUINA vive GLOBAL, jamás en un repo"*.
> Si viajara por git, un colega que clona heredaría "cómo tratar a ‹usuario›", que para él es ruido.
> **No dupliques aquí las normas UNIVERSALES del brain** (doc=realidad, definición de LISTO, flujo de
> git, medir-no-alucinar, probar-el-flujo-completo): esas ya viven en `~/.claude/CLAUDE.md` — aquí va
> SOLO lo que es de ESTA persona. Cada punto abre con **QUÉ HACER** (answer-first), luego el porqué.
> Marca la **procedencia**: cita textual de ‹usuario› entre comillas; lo que infieras tú, dilo como tuyo.

## 🗣️ Comunicación y trato
- ‹Cómo quiere que le hables: tono, largo, cuándo ir al grano vs explicar. Ej.: "‹cita literal de ‹usuario››".›
- ‹Anti-patrones de comunicación que le molestan (eco-validación, repetir su idea como "acuerdo", adulación) → qué hacer en su lugar.›
- ‹Cómo dar/recibir feedback y correcciones sin fricción.›

## ✅ Decisiones y autorización
- ‹Cómo decide y cuánto delega en Claude: cuándo quiere que DECIDAS con el criterio que ya te dio vs cuándo PREGUNTES.›
- ‹Qué considera "autorización" y qué no (silencio, una reacción positiva a UNA idea, etc.). Ej.: "‹cita literal›".›
- ‹Cuándo insiste en revisar él mismo (QA/validación) antes de dar algo por cerrado.›

## 🛠️ Proceso de trabajo
- ‹Ritmo que prefiere: avanzar de corrido con luz verde vs check-in frecuente. Ej.: "‹cita literal›".›
- ‹Cómo prefiere que se depuren/arreglen las cosas (flujo completo vs alivio local; band-aids).›
- ‹Dónde quiere ver el resultado / superficie de QA estable; qué NO se le debe mover bajo los pies.›
- ‹Cómo maneja lo que no se atiende: al backlog, no re-flagelar; dónde vive el backlog vivo.›

## 🌿 Git / repos
- ‹Su convención de ramas personales (mini-develop `Develop‹Usuario›`) y de dónde salen/vuelven las ramitas.›
- ‹Gotchas de git específicos de cómo trabaja (multi-repo, `--repo` explícito, worktrees, checkout de la mini).›
- ‹Expectativas de integración a develop/main (deliberado, con su OK) — referencia al flujo del brain, no lo repitas.›

## 🎯 Preferencias concretas
- ‹Gustos concretos y repetibles: densidad de UI, formato de entregables, herramientas favoritas, vocabulario propio (palabras suyas que significan algo específico).›
- ‹Trampas de lenguaje ya vividas (una palabra suya que malinterpretaste una vez y cómo desambiguar).›

<!--
CONTRATO DE ESTA NOTA (por qué así):
- QUÉ SÍ va aquí: TRATO y preferencias PERSONALES de ‹usuario› — cómo le gusta que le comuniquen, decidan
  y trabajen; su vocabulario propio; sus gotchas de proceso. Con procedencia (cita textual vs inferencia tuya).
- QUÉ NO va aquí: las NORMAS UNIVERSALES del brain (doc=realidad, definición de LISTO, flujo de git,
  medir-no-afirmar-de-memoria, probar-el-flujo-completo, autorización acotada). Esas viven en
  `~/.claude/CLAUDE.md` (bloque cortex) y aplican a CUALQUIER usuario → aquí solo se REFERENCIAN.
- POR QUÉ ES GLOBAL Y NO DE REPO: es sobre una PERSONA, no un proyecto. En un repo viajaría por git y sería
  ruido (o mentiría) para otro dev que clone. Misma norma que `entorno-esta-maquina.md` y el dashboard:
  vive SOLO en la memoria global per-máquina (`~/.claude/projects/‹slug-del-HOME›/memory/`), NO en git.
- SEMBRADO: lo siembra `install-brain.sh` (copia de este barebones) si falta el archivo per-máquina;
  luego ‹usuario›/Claude lo llenan con lo REAL. Idempotente: si ya existe, no lo toca.
- ANSWER-FIRST: cada bullet abre con el QUÉ-HACER; el porqué/anti-patrón va después.
- Convención de nombre del archivo real: `como-trabajar-con-‹usuario›.md` (p. ej. `como-trabajar-con-unjordi.md`).
-->
