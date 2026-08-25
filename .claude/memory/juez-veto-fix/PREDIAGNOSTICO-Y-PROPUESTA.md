# Pre-diagnóstico y propuesta de la sesión principal — Y la hipótesis RIVAL del usuario

> Este archivo lo lee SOLO el auditor anclado. Contiene DOS teorías en competencia sobre por qué el
> juez de merge falla. Tu trabajo NO es validar la teoría de la sesión principal — es **adjudicar cuál
> explica mejor los hechos** (o si es una combinación), con evidencia de código y transcript. El
> usuario explícitamente NO confía en el autodiagnóstico de la sesión principal; sé escéptico con AMBAS.

## TEORÍA A — la de la sesión principal (Claude)

**Falla 1 (plomería): el destino cuelga de un `gh pr view` en vivo dentro del hook.**
`acg_destino_de_mr` corre `gh pr view <mrid> [-R repo] --json baseRefName`. Si el cwd se reseteó a
otro repo, o no se pasó `--repo`, o hay hipo de red → destino vacío → el hook cae al mensaje "no pude
CONFIRMAR el destino" y DENY. El destino es determinable de forma más robusta/offline (del comando,
del ref, de git) y el hook solo intenta ese camino frágil.

**Falla 2 (diseño): la autorización se re-deriva desde cero en cada invocación, de una ventana
deslizante.** No hay memoria de "el usuario autorizó estos 3 merges". `_recent_intercalado` se ancla
al 10º mensaje de USUARIO desde el final; conforme la conversación crece con mensajes nuevos, el OK
original ("mergea las 3 branches") se desplaza/diluye. Por eso #272 pasó y #273 (misma orden) no.
Además el LLM debe re-mapear "las 3 branches" → "MR 273" sin vínculo durable.

**Falla 3 (diseño): el grant durable EXISTE pero casi no se usa.**
`autorizaciones-vigentes.local.md` (scope=merge-develop) solo lo escribe el skill `turno-nocturno`.
En una sesión de día no hay forma de que un OK explícito se vuelva durable → todo cae a la
re-derivación frágil del LLM.

**Propuesta A:** (1) resolución de destino determinista/offline con la red como último recurso;
(2) persistir el OK explícito como grant durable en cuanto se da, para que un solo "mergea las 3
branches" valga para las 3 sin re-litigar el LLM; (3) el LLM-juez pasa a ser FALLBACK para anáforas
ambiguas, no el gate primario de una autorización explícita en lote.

## TEORÍA B — la del usuario (unjordi), TEXTUAL

> *"el problema es que no creo que sea un tema de 'a ver qué opina Haiku hoy' sino de 'no supe pedirle
> las cosas a haikú por andar queriendo acotarlo'"*

Es decir: la falla NO sería el no-determinismo de Haiku ni la plomería, sino que **el prompt y las
capas de acotamiento están mal construidos** — de tanto querer encorsetar a Haiku (el prompt gigante
de reglas, el veto de cita verbatim, el anclaje de ventana, el sandbox de hint, los pisos), se le
está pidiendo MAL, y por eso da DENYs que un humano razonable no daría. La hipótesis apunta a que
Haiku ES capaz de juzgar bien esto si se le pidiera de forma limpia; el bug está en la
INGENIERÍA DE PROMPT / sobre-restricción, no en el modelo ni (solo) en la plomería.

## Lo que necesito de ti (auditor anclado)

- ¿Cuál teoría sostiene la evidencia? Concretamente para el caso #272-ALLOW / #273-DENY: reconstruye
  qué ventana `_recent_intercalado` vio CADA invocación (usa el transcript real) y qué de eso movió el
  veredicto. ¿Fue la ventana deslizante (Teoría A2), o fue que el prompt/las capas hicieron a Haiku
  incapaz de conectar "las 3 branches" con el #273 aunque la autorización SÍ estaba en la ventana
  (Teoría B)? Si puedes, corre el juez con mocks/fixtures para demostrarlo, no solo argumentarlo.
- Evalúa el veto de cita verbatim (`CITA:` que debe casar TEXTUAL contra una línea USUARIO:): ¿es una
  fuente de falsos DENY? P. ej. si el usuario autorizó en lote y no hay una sola línea que Haiku pueda
  citar verbatim para "el #273 específicamente", ¿el veto lo fuerza a DENY aunque la intención sea clara?
- ¿El anclaje "10º usuario desde el final" y el recorte a 700 chars del asistente esconden la propuesta
  a la que el usuario dijo "sí"?
- Da tu propia propuesta; si coincide con A, con B, o con una síntesis, dilo con evidencia.
