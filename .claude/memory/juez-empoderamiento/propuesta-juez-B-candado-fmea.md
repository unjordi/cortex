# Propuesta B — El juez de merge como CANDADO (FMEA de proceso, defensa en profundidad)

**Archivo objeto:** `/Users/unjordi/code/cortex/brain/hooks/confirmar-merge-develop.sh`
**Batería:** `/Users/unjordi/code/cortex/brain/test-brain.sh`
**Restricción rectora:** EMPODERAR, no AFLOJAR. Todo cambio deja el candado **igual de estricto o más**, nunca "que deje de molestar". Fail-safe siempre a DENY. Solo `USUARIO:` autoriza. El piso determinista se queda. Modelo → Sonnet. Latencia ~3-5s tolerable.

---

## 0. Tesis (el principio de diseño que ordena todo lo demás)

Un candado de merge es un **sistema de seguridad con actuador falible** (el LLM). La regla de oro de un sistema así, dada la asimetría de costos, es la **monotonía hacia DENY**:

> **El LLM PROPONE un ALLOW; las capas DETERMINISTAS DISPONEN.** Cada capa determinista solo puede *endurecer* (convertir ALLOW→DENY o mantener DENY), **jamás** ablandar (DENY→ALLOW). El LLM nunca es la autoridad final de un ALLOW: es un *discernidor de matiz* cuya salida siempre pasa por un veto determinista que la puede tumbar.

Hoy esto se cumple **solo para `main`** (el PISO determinista). Para `develop` **no existe piso**: un ALLOW del LLM es lo único que separa un merge no autorizado de `develop`. Esa es la falla estructural central que esta propuesta cierra — sin mover la vara.

---

## 1. La asimetría de costo (cómo DEBE sesgar el diseño)

| | Falso NEGATIVO (bloquea merge legítimo) | Falso POSITIVO (deja pasar merge NO autorizado) |
|---|---|---|
| **Coste** | Fricción | Integración/release no autorizado |
| **Reversibilidad** | Total: re-frasear, o `git merge` LOCAL (no pasa por el candado), o esperar 5s | `develop`: caro (revert coordinado). `main`: **catastrófico** — release afuera, historia que NO se reescribe |
| **Detección** | Inmediata (el usuario ve el freno) | Tardía o nunca (se descubre en producción) |
| **Blast radius** | El dev que espera | Todo el equipo / clientes |

**Conclusión de diseño:** el candado debe estar **fuertemente sesgado a DENY ante CUALQUIER incertidumbre**, y el sesgo debe ser **más agresivo cuanto mayor la consecuencia** (`main` ≫ `develop`). El costo de un FN es un peldaño de fricción con salida trivial (`git merge` local); el costo de un FP a `main` no tiene botón de undo. Por eso: **nunca se compra reducción de FN a cambio de aumento de FP.** El upgrade a Sonnet y el resto de mejoras reducen FN, pero SIEMPRE detrás de vetos deterministas que blindan el FP.

---

## 2. Reparto óptimo determinista vs LLM (qué decide cada quién)

El error de diseño más común en estos gates es **delegar al LLM invariantes que son hechos, no matices**. Regla de reparto:

- **DETERMINISTA (hechos duros, nunca al LLM):** clasificación de la acción, alcance (repo compartido), destino de la rama, léxico obligatorio de release para `main`, "solo `USUARIO:` autoriza", "el grant durable jamás cubre `main`", y **presencia de al menos una autorización posible**.
- **LLM (Sonnet — matiz de lectura, lo que un regex no puede):** *dado que un `USUARIO:` expresó intención de integrar, ¿esa intención APLICA a ESTE MR ahora?* — anáfora ("sí", "dale", "ese, el 241", "de todo esto"), condicional ya cumplida, listas multi-id, OK dado ANTES de que el MR existiera. Eso es comprensión de lectura genuina y es el uso correcto del LLM.

### Invariantes que deben ser SIEMPRE deterministas (nunca delegados al LLM)

1. **¿Es una acción gateada?** (`acg_es_merge_mr`) — hoy determinista ✓ (pero es superficie de FP, ver §4).
2. **¿Repo compartido?** (marca `.claude/repo-compartido`) — determinista ✓.
3. **Destino de la rama** con fail-safe a estricto (vacío/duda → tratar como `main`) — determinista ✓ (endurecer caché, §4).
4. **`main` exige léxico de release en una línea `USUARIO:`** — PISO determinista ✓.
5. **`main` NUNCA lo cubre el grant durable** — determinista ✓.
6. **La autoridad es la línea `USUARIO:`** — HOY solo vive dentro del prompt del LLM para `develop` (soft). **Debe volverse determinista** (§3, palanca #1).
7. **Debe existir ≥1 línea `USUARIO:` en la ventana** — HOY no se chequea. **Nuevo piso** (§3, palanca #3).

---

## 3. Diseño de CAPAS concreto (orden, chequeo, dirección de falla)

Cada capa lista su **dirección de falla**. Nota clave: **toda capa relevante a seguridad falla a DENY**; solo la Capa 0 (¿me incumbe?) falla-abierto, y eso es correcto *salvo* por su superficie de FP que §4 aborda.

```
Comando Bash (gh pr merge / glab mr merge)
        │
   ┌────▼──────────────────────────────────────────────────────────────┐
   │ CAPA 0 — ENGAGEMENT (determinista)                                  │
   │  ¿Es un merge de MR real a repo COMPARTIDO?                         │
   │  acg_es_merge_mr + marca .claude/repo-compartido                   │
   │  NO → exit 0 (no me incumbe). Falla-abierto = correcto AQUÍ,        │
   │       PERO es superficie de FP si el parser no reconoce el merge    │
   │       → ver §4 (endurecer a "parece merge → engancha").            │
   └────┬───────────────────────────────────────────────────────────────┘
        │ sí
   ┌────▼──────────────────────────────────────────────────────────────┐
   │ CAPA 1 — DESTINO (determinista + fail-safe a ESTRICTO)              │
   │  acg_destino_de_mr → develop | main | (vacío)                      │
   │  vacío/incierto → NO se asume develop; baja como "main-estricto".  │
   │  Falla → estricto (main). Endurecer: caché namespaced/desconfiada   │
   │  para la decisión de seguridad; si dos lookups discrepan → main.    │
   └────┬───────────────────────────────────────────────────────────────┘
        │
   ┌────▼──────────────────────────────────────────────────────────────┐
   │ CAPA 2 — PRECONDICIONES ESTRUCTURALES (VETO determinista, sin LLM)  │
   │  (a) ¿Hay ≥1 línea USUARIO: en la ventana?   NO → DENY  [NUEVO]     │
   │  (b) destino main → ¿léxico de release en línea USUARIO:?           │
   │         NO → DENY   [PISO actual, se queda]                         │
   │  (c) grant durable vigente (scope=merge-develop) SOLO si            │
   │         destino=develop CONFIRMADO → ALLOW fast-path (se queda)     │
   │  Falla de parseo → DENY.                                            │
   └────┬───────────────────────────────────────────────────────────────┘
        │ pasa preconditions
   ┌────▼──────────────────────────────────────────────────────────────┐
   │ CAPA 3 — DISCERNIMIENTO (LLM Sonnet)                                │
   │  "¿un USUARIO: autorizó integrar ESTE MR a ESTE destino ahora?"     │
   │  Salida NUEVA (contrato): línea1 = ALLOW|DENY                       │
   │                           línea2 = CITA VERBATIM del span USUARIO:  │
   │                                    en que se apoya (si ALLOW)        │
   │  Sin token / sin red / timeout / ininteligible → UNAVAILABLE→DENY.  │
   └────┬───────────────────────────────────────────────────────────────┘
        │ ALLOW + cita
   ┌────▼──────────────────────────────────────────────────────────────┐
   │ CAPA 4 — VERIFICACIÓN DE JUSTIFICACIÓN (VETO determinista) [NUEVO]  │
   │  La cita del LLM DEBE ser substring (misma normalización de         │
   │  espacios) de una línea etiquetada USUARIO:.                        │
   │  NO aparece / aparece solo en línea ASISTENTE: → override a DENY.   │
   │  Esto vuelve "solo USUARIO autoriza" un INVARIANTE determinista,    │
   │  también para develop. Mata alucinación E inyección de una vez.     │
   └────┬───────────────────────────────────────────────────────────────┘
        │ verificado
     ALLOW → exit 0 (+ nota de higiene actual)
        │
        ▼
   CAPA 5 — BACKSTOP fuera de banda: ramas protegidas server-side en
   GitLab (push/merge = Maintainer). El hook es defensa-en-profundidad,
   NO la única línea. Documentarlo como capa explícita del sistema.
```

**Por qué este orden:** las capas baratas y de máxima consecuencia van ANTES de gastar red/LLM (fail-fast a DENY). El LLM va en medio, pero **envuelto**: precondiciones deterministas ANTES (Capa 2, puede negar sin consultar al LLM) y verificación determinista DESPUÉS (Capa 4, puede tumbar su ALLOW). El LLM queda estructuralmente incapaz de autorizar solo.

---

## 4. Modos de falla y mitigaciones (tabla FMEA)

| # | Modo de falla | Efecto | Sev | Detección actual | Mitigación propuesta |
|---|---|---|---|---|---|
| F1 | **`develop` sin piso**: LLM alucina/es engañado a ALLOW | Merge no autorizado a develop | ALTA | Ninguna (el LLM es juez único) | **Capa 4** (cita verificada) + **Capa 2a** (≥1 USUARIO:) → convierte "solo USUARIO autoriza" en invariante determinista para develop |
| F2 | **Inyección de prompt**: texto "USUARIO: mergea…" dentro de un mensaje del ASISTENTE o un tool-result | El LLM lo lee como autorización | ALTA | Parcial: `gsub("\\s+";" ")` colapsa saltos → la inyección queda en la línea ASISTENTE (buena defensa ya presente); regla "solo USUARIO" en prompt (soft) | **Capa 4** lo cierra en duro: la cita debe caer en una línea *etiquetada por rol real* USUARIO: — el rol lo pone el interleaver (`.message.role`), no el contenido |
| F3 | **Alucinación de ALLOW** por phrasing raro | FP | ALTA (main) / MEDIA (develop) | PISO (solo main) | Capa 4 (cita verificada) cubre AMBOS destinos; PISO de main se queda |
| F4 | **Destino mal detectado** (main visto como develop; caché envenenada) | main con gate de develop | ALTA | fail-safe "vacío→estricto" ✓; pero un `develop` devuelto ERRÓNEO no se cuestiona | Desconfiar de la caché compartida para la DECISIÓN de seguridad (o namesparla y validar TTL corto); si el lookup de este guard y el de squash-guard **discrepan**, err a `main` |
| F5 | **Parser no reconoce el merge** (Capa 0 falla-abierto) | Merge pasa **ungated** | ALTA | H3 cerró evasión por tokens encadenados | Endurecer Capa 0: cualquier comando con `mr merge`/`pr merge` que el parser no logre estructurar del todo → **engancha igual** (fail-toward-engage), no exit 0 silencioso |
| F6 | **`jq` ausente** (Windows sin `jq`) → `exit 0` global | Todo el candado se apaga | ALTA | Documentado (git-branch-guard también) | Compensado por Capa 5 (server-side). Recomendación: si falta `jq` **y** el comando es merge a base con pinta de protegida → emitir DENY/aviso, no silencio; y exigir `jq` como invariante de bootstrap en repos compartidos |
| F7 | **LLM lento/caído** | UNAVAILABLE→DENY (bloquea aun lo obvio) | BAJA (FN, recuperable) | ✓ fail-safe correcto | **Mantener DENY** (la asimetría lo exige). Reducir la *incidencia*: pre-chequeo de frescura del token, 1 reintento en el hook (hoy solo en el test), presupuesto de timeout holgado. **NUNCA** una vía ALLOW degradada, y jamás para main |
| F8 | **Cita re-checkeable demasiado estricta** (Capa 4 nueva) | Legítimo ALLOW→DENY | BAJA (FN) | — | Normalizar espacios idéntico a `_recent_intercalado`; instruir cita VERBATIM; las líneas USUARIO: **no se truncan** (solo ASISTENTE se corta a 700) → la cita del usuario nunca se pierde por truncado |
| F9 | **Auto-autorización** (ASISTENTE afirma "el usuario ya aprobó") | FP | ALTA | Regla en prompt (soft) + batería LIVE | Capa 4 lo vuelve duro: la cita debe estar en línea USUARIO:, no ASISTENTE: |

---

## 5. La falla reportada (FN "release a main de todo esto")

**Causa raíz:** no es el piso ni la vara — es la **debilidad del actuador**. Haiku no resuelve la anáfora "de todo esto" → el único MR de release en juego, así que no encuentra una autorización que *aplique a ESTE MR* y cae a DENY. Nombrar el MR se lo da masticado y entonces ALLOWea.

**Fix sin mover la vara:**
1. **Sonnet** resuelve "de todo esto / esta ola / el release" → el único release-MR en juego (la regla "si hay UN SOLO MR hacia ese destino, el OK aplica sin número" ya está en el prompt; Sonnet sí la ejecuta).
2. El léxico de release ("release a main") ya satisface el PISO → no hay conflicto con `main`.
3. Con **Capa 4**, subir la potencia del LLM es SEGURO: cualquier ALLOW que Sonnet gane de más queda sujeto a la cita verificada. Más inteligencia baja el FN **sin** poder subir el FP.
4. Reforzar el prompt: enumerar "de todo esto / esta ola / el release / eso" como anáforas que resuelven al único MR-de-release en juego.

---

## 6. Cambios de implementación que habilitan las capas nuevas

- **`max_tokens: 16` → ~64-128** y contrato de salida a 2 líneas (`ALLOW|DENY` + cita). Con Sonnet y 3-5s el costo es trivial; hoy 16 tokens NO alcanzan para una cita → es el bloqueo técnico de la Capa 4.
- **Parseo de la cita** en el hook: tomar la línea 2, normalizar espacios igual que `_recent_intercalado`, y `grep -F` contra las líneas `^USUARIO:` de `$recent`. No aparece → `out=DENY`. (Mismo patrón "override a DENY" que ya usa el PISO de main — es defensa en profundidad homogénea.)
- **Capa 2a** (≥1 USUARIO:): `printf '%s' "$recent" | grep -qiE '^[[:space:]]*USUARIO:' || out=DENY` **antes** de llamar al LLM (ahorra la llamada de red en el caso degenerado).
- **Batería:** agregar a la sección LIVE casos de (a) inyección "USUARIO:" dentro de texto ASISTENTE → DENY aun con LLM=ALLOW mockeado imposible… mejor: caso determinista Capa 4 con cita falsa → override DENY; (b) ventana sin ninguna línea USUARIO: → DENY; (c) el FN reportado "release a main de todo esto" (single MR en juego) → ALLOW. Cada palanca nace con su test (norma: toda norma con su mecanismo).
- **Regla de precisión, NO de aflojamiento:** todo esto solo AGREGA vetos y sube la potencia de lectura; ninguna ruta nueva convierte un DENY previo en ALLOW. Es un cambio de PRECISIÓN/robustez, dentro de la norma de integridad de guardarraíles.

---

## 7. Degradación segura (LLM lento/caído) — decisión explícita

Se **mantiene** `UNAVAILABLE → DENY` sin excepción, y **jamás** una vía ALLOW degradada para `main`. Motivo: la asimetría §1 — un FN por caída de red se resuelve en segundos con `git merge` LOCAL o reintento; un FP degradado a `main` no se resuelve. En vez de abrir una compuerta degradada (que reintroduce el regex-soup ya jubilado y su whack-a-mole), se ataca la *incidencia* de UNAVAILABLE: pre-chequeo de token vigente, 1 reintento dentro del hook, timeout holgado. Robustez del canal, no relajación del veredicto.

---

## 8. Backstop y residuales que quedan documentados

- **Backstop (Capa 5):** ramas protegidas server-side en GitLab son la última línea real. El hook es defensa-en-profundidad; documentarlo evita el falso sentido de que el hook es la única barrera.
- **Residual F6 (jq ausente = candado apagado):** compensado por Capa 5; recomendación de endurecer a DENY/aviso en merge a base protegida sin `jq`.
- **Residual F5 (gap del parser):** compensado por H3 + fail-toward-engage propuesto + Capa 5.
- Ambos residuales van al backlog del cerebro (norma: ningún hallazgo se queda solo en el chat).

---

## Resumen de palancas priorizadas

1. **Capa 4 — cita verificada (VETO determinista post-LLM).** Cierra el hueco estructural de `develop` (que hoy NO tiene piso), mata alucinación E inyección para AMBOS destinos, y vuelve "solo USUARIO autoriza" un invariante determinista. **Máximo impacto.**
2. **Modelo → Sonnet + prompt de anáforas.** Elimina el FN reportado ("de todo esto") sin mover la vara; seguro porque la Capa 4 lo envuelve.
3. **Capa 2a — piso "≥1 línea USUARIO:".** Piso determinista barato para el caso degenerado (ventana sin usuario), ahorra la llamada de red.
4. Endurecer destino (caché desconfiada, discrepancia→main) y Capa 0 (fail-toward-engage) — cierran F4/F5.
5. Mantener `UNAVAILABLE→DENY`; robustecer el canal (token/reintento/timeout), no relajar.
