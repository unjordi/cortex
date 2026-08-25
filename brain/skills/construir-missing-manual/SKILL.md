---
name: construir-missing-manual
description: >-
  FABRICAR el manual/wiki de referencia EXHAUSTIVO que debería existir y no existe (o vive
  disperso/solo-en-la-web), como un artefacto CONSULTABLE OFFLINE — un skill-monstruo con un
  documento por sub-tema, construido por fan-out de agentes que investigan a fondo UNA vez y
  hornean todo, para no volver a internet nunca. Úsalo cuando tú o el usuario digan "necesito la
  documentación de X y ni existe / está regada / no quiero volver a buscarla" — p. ej. una guía
  completa de configuración+troubleshooting+known-bugs de una tecnología, con variantes (por OS,
  por proveedor, por componente). NO es investigar-dominio (eso es volverte experto + auditar tus
  decisiones); esto PRODUCE el artefacto de referencia.
---

# Construir el "Missing Manual" (la referencia que debió existir) — por fan-out

> Como los **_Missing Manual_ de O'Reilly**: *"el libro que debió venir en la caja"* — el manual completo,
> honesto y consultable que el fabricante no escribió. Aquí lo **fabricamos** cuando no existe.

Cuando la documentación que necesitas **no existe como artefacto consultable** (o está regada en 20
pestañas, foros y man-pages, o solo vive online), este skill la **FABRICA**: un skill-wiki denso,
estructurado por sub-tema, que se investiga a fondo UNA vez y se **hornea para consultar sin internet**.

> **Distínguelo de sus hermanos:**
> - **`investigar-dominio`** = ponerte a ti (Claude) al día como experto + **auditar tus decisiones**
>   contra lo aprendido. Output = expertise + memorias + decisiones revisadas.
> - **ESTE** = producir **el ARTEFACTO de referencia** (el manual/wiki) para consultar después. Output =
>   el skill-monstruo consultable. (Puedes encadenarlos: investigar-dominio para decidir; éste para dejar el manual.)
> - **`desinflar-memorias`** = lo OPUESTO (adelgazar doc inflada). Aquí **inflar es el objetivo**: exhaustivo, no "60 líneas".

## Cuándo usarlo
- "Necesito la doc completa de `<tecnología>` y **no existe** / está dispersa / no quiero volver a googlearla."
- Una guía con **variantes** que piden un documento por cada una: por **OS** (Mac/Windows/Linux), por
  **proveedor** (cada ISP, cada vendor), por **componente/módulo**, por **versión**.
- Cuando ya te cachaste haciendo el mismo fan-out de "ve e investígame TODO sobre ___ y arma el manual".

## El método (fan-out orquestado)
1. **Alcance y ESQUELETO.** Define el temario y el **eje de partición** ("un doc por X"): por OS, por
   proveedor, por componente. Crea el dir del skill + un **`SKILL.md` índice/router que TÚ (orquestador)
   controlas** — nombra los archivos que los agentes llenarán. El índice es tuyo; el contenido, de ellos
   (evita la carrera por el archivo compartido).
2. **Fan-out con archivos DISJUNTOS.** Un agente por doc (o grupo de docs) — **cada uno escribe SOLO sus
   archivos**, nunca `SKILL.md` ni los de otro, **sin git**. Archivos disjuntos en un dir nuevo = sin
   conflicto, sin necesidad de worktrees. (Mecánica de fan-out sin niñera: [[orquestar-fanout]].)
3. **Investiga AHORA, hornea para SIEMPRE.** Cada agente **investiga a fondo con WebSearch/WebFetch en el
   momento del BUILD** (docs oficiales, man-pages, issues, foros) — porque el punto es que la CONSULTA
   futura sea offline. La regla dura: *usar la web es para CONSTRUIR el skill, jamás para operarlo después.*
4. **Hornea también la EXPERIENCIA real, no solo la web.** Los hallazgos ya validados en vivo (un fix que
   probaste, un gotcha que te mordió) son oro — dáselos a los agentes como fuente (memorias/scripts reales)
   para que el manual quede **fundado**, no solo web-scrapeado. Marca lo `[SIN CONFIRMAR]` vs lo verificado.
5. **Orquesta y CIERRA.** Revisa cada entregable contra la realidad ([[revisar-entregables-agentes]]) — no
   le creas el "listo" a un agente sin abrir sus archivos. Luego **finaliza el `SKILL.md`** (índice real +
   cross-refs que resuelven), verifica que no haya leaks/placeholders rotos, y registra en bitácora.

## Modo COMPLEMENTAR (cuando el manual YA existe) — extender, no reconstruir
No siempre se parte de cero: a veces el manual ya existe y hay que **extenderlo** (un sub-tema nuevo, un ISP/
OS/componente más, un hueco `[SIN CONFIRMAR]`/`TODO` que ya se puede llenar, una sección que envejeció). El
fan-out entonces **complementa, NO reconstruye**:
1. **Inventaría lo que YA cubre** — lee el `SKILL.md`/índice + los archivos: qué sub-temas hay, qué está
   completo, qué está marcado como hueco/`[SIN CONFIRMAR]`/`TODO`/stale.
2. **Saca el DELTA** — los sub-temas FALTANTES + las secciones incompletas/viejas. Ese delta ES el work-list.
3. **Fan-out SOLO sobre el delta**, archivos disjuntos: cada agente **crea un archivo nuevo** o **extiende UNA
   sección existente** — nunca reescribe un archivo entero ni pisa lo previo. **NO ELIMINES NADA** (regla dura:
   el conocimiento previo se CONSERVA; solo se AGREGA/actualiza). Si algo previo era erróneo, corrígelo en su
   lugar marcando el cambio, no lo borres a ciegas.
4. **Orquestador reconcilia + actualiza el índice** (`SKILL.md`) con los archivos nuevos, verifica cross-refs y
   —regla dura— **confirma cero-pérdida** (grep de firmas del contenido previo antes/después) antes de dar por
   cerrado.
> Precedente real: el skill **DFIR** se enriqueció así — fan-out de gaps + auditores, **no-delete**, sobre un
> skill que ya existía; el orquestador verificó cero-pérdida y cerró el índice.

## Reglas duras (lo que hace que valga)
- **Offline-first (la razón de ser).** El artefacto debe **bastarse solo**. Si para operar hay que abrir la
  web, falló — *hornéalo aquí al terminar*. La web es andamio del build, no muleta de la consulta.
- **MONSTRUO, no "60 líneas".** Exhaustivo es EL requisito, no un exceso. Denso, completo, por sub-tema.
  (Origen: unjordi, harto de docs escuálidas — "que sea un monstruo consultable".)
- **Answer-first (positivar).** Cada nugget abre con lo que SÍ funciona; el gotcha/known-bug va después
  ([[positivar-doc]]).
- **Índice del orquestador + contenido de los agentes.** Nadie más toca `SKILL.md` durante el fan-out.
- **Genericiza: cero datos de un caso** en un skill reutilizable (llaves, IPs de clientes) → placeholders;
  los datos del caso viven en la memoria/config del proyecto, no en el manual.
- **Ojo con el safeguard cyber:** contenido DFIR/malware **tumba a los subagentes** → esos ejes se hacen
  INLINE (en el hilo del orquestador). Red, config, ISPs, despliegue: delegables sin problema.
- **Consentimiento de costo** del fan-out ([[orquestar-fanout]] / gate de delegación): cuéntalos.

## Estructura típica del artefacto
```
<skill>/
  SKILL.md                 # índice/router (orquestador) — answer-first, "empieza por lo que necesitas"
  01-<fundamentos>.md      # el modelo mental / cómo funciona (el "por qué" de todo lo demás)
  02-<variante-A>.md       # p. ej. por OS: mac / windows / linux
  03-<variante-B>.md
  <eje>/                   # p. ej. un doc por proveedor/ISP/componente
    <x>.md  <y>.md  <z>.md
  NN-<despliegue/uso>.md   # cómo APLICARLO (scripts, aprovisionamiento) — no solo teoría
  scripts/                 # lo ejecutable que acompaña (deploy, verificación)
```

## Ejemplos reales (de donde salió este skill)
- **DFIR forense de disco Windows** (`auditoria-forense-disco-windows`): wiki de método + un doc por paso +
  docs de referencia (prior-art, gaps) — el malware se hizo INLINE por el safeguard.
- **WireGuard a fondo** (`wireguard-a-fondo`, 2026-08-21): wiki WG + config Mac/Windows + **un doc por ISP
  de México** + despliegue con scripts — 5 agentes, archivos disjuntos, con el hallazgo real keepalive=10
  horneado.

## Hermanos
[[investigar-dominio]] (modo experto para auditar decisiones — te INVOCA a TI como su paso de "fabricar la referencia") · [[orquestar-fanout]] (la mecánica
del fan-out) · [[positivar-doc]] (answer-first) · [[revisar-entregables-agentes]] (no creerle al agente) ·
[[desinflar-memorias]] (el opuesto: adelgazar) · [[diagramar]] (si el manual pide diagramas).
