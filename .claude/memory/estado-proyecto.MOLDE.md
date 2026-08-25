---
name: estado-proyecto
description: <UNA línea — qué es este backlog + "lee la sección 🧭 BACKLOG al tope". El resumen del estado va en el cuerpo, no aquí.>
metadata:
  type: project
---

# Estado del proyecto — <REPO>

> **Aquí empiezas.** Backlog DURABLE del proyecto. Cerrado → `bitacora.md`. Cómo mantenerlo → skill `to-do` / `cerrar-slice`.

## 📌 Dónde estamos (resumen vivo)
<1–5 líneas: el estado global de HOY. Se REESCRIBE (no se acumula). El hilo de "qué hago AHORA" vive en `hilo-mental-actual.md`.>

## 🧭 BACKLOG
> **KEY:** `📘` tiene plan · `➖` mecánico · `📝` necesita plan. Grupo 1 (📘/➖) = atacable = el HUD. Grupo 2 (📝) = necesita plan.

### 📬 PRs/MRs abiertos esperando OK
<lista, o "(ninguno abierto)">

### 📘+➖ 1 — Abierto a la espera del GO, o de decisión puntual
- 📘 [pending] `#<id>` — <título> · <contexto curado opcional>
- ➖ [in_progress] `#<id>` — <título>

### 📝 2 — Abierto pero necesita plan
<ítems que necesitan que se DISEÑE el cómo — backlog-only, no entran al HUD>

## 🚫 Intocables / Congelados (NO tocar/resucitar sin OK)   ← OPCIONAL, solo si el repo los tiene
<constraints ACTIVOS (congelados por decisión, con backstop), cada uno con puntero al doc que lo detalla>

## 🪦 Deprecated / Fuera por decisión (NO reabrir)
<lo MUERTO (probado y abandonado — "lápidas") + lo descartado a propósito (scope). Memoria activa de "NO re-proponer".>

## 🧠 Decisiones de arquitectura (con su porqué)
<Why → Decisión. Lo durable que explica por qué el proyecto es como es.>

<!-- Sección OPCIONAL por-repo: `## 📮 Buzón de los claudes` (append-only, con >>) — hoy solo claude-brain. -->
