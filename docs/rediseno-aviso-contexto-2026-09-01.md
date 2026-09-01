# Rediseño de aviso-contexto — DATO CRUDO, cada quién decide (unjordi 2026-09-01)

**Decisión (unjordi):** *"que arroje el dato CRUDO y el estado actual y CADA QUIÉN DECIDE cómo morirse.
autoCompactWindow suena perfecto."* El hook DEJA de derivar un techo frágil (allowlist de modelos ×
pct de una env que no se propaga) y de gritar bandas escaladas ("INMINENTE, compacta YA"). En su lugar
**EMITE los HECHOS CRUDOS + el estado actual**, y el LECTOR (Claude + `/context`, que es autoritativo)
decide cuándo/cómo compactar.

**Por qué:** mata la RAÍZ de las torpezas (H1 allowlist→200K, H2 env→92) — el hook no puede MENTIR sobre
un techo que ya NO calcula. El dato duro (ctx del usage, autoCompactWindow de settings) no miente.

**Qué reporta (crudo):** ctx actual (tokens del usage) · `autoCompactWindow` LEÍDO de settings.json (o
"no seteado") · ventana detectada (con corrección por invariante físico) · `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`
si está (o "no seteado"). Sin veredicto de urgencia inventado. Recuerda: `/context` manda; tú decides.

**Conserva:** fail-open, debounce (no disparar cada tool-call), medición por TOKENS del usage.
**Descartado:** consultar `api/oauth/usage` por-tool (undocumented/inestable + costo de red por cada tool).
- **Corolario (unjordi): el
hook
en
sh
no
puede
ser
más
listo
que
un
LLM → el hook es un REPORTERO TONTO de datos, NO un juez.** Se le quita TODA la lógica lista (derivar techo ventana×pct, bandas de urgencia 1/2/3, veredictos INMINENTE). Solo SURFACE lo que el LLM no puede ver a mitad de una corrida (ctx en tokens, autoCompactWindow). El LLM (listo) + /context deciden.

## Residuos BAJO ACEPTADOS (re-auditoría R2, convergencia limpia 2026-09-01)
El loop auditor→fixer→re-auditar CONVERGIÓ: S1 (caer a 200K y gritar en falso) y S2 (mentir "92% override
deliberado") RESUELTAS. Residuos BAJO documentados y aceptados (cosméticos / edge-cases forzados por el usuario):
1. El mensaje no cita la FUENTE de la ventana (settings/modelo/invariante). El LLM lo infiere; `/context` manda.
2. Si `AVISO_CONTEXTO_WINDOW_TOKENS` se fuerza < ctx, el % podría pasar de 100 — pero el invariante físico
   (ctx>ventana→1M) lo corrige antes; residual solo si se fuerza una ventana absurda a mano.
3. `autoCompactWindow` se reporta CRUDO sin validar que sea número — es el diseño ("reportero tonto": reporta el dato tal cual).
4. La marca de debounce se escribe antes del check de emisión — cubierto por fail-open.

Metodología del loop: auditor FMEA one-shot con zapatos (referencia-cli + hook) → fixer con la dirección
"reportero tonto" → orquestador cazó/arregló la regresión del debounce (grueso por pasos de 50K) → re-auditor
declaró CONVERGENCIA. Verificado: bash -n, fail-open, happy-path emite dato crudo, debounce por-escalón.
