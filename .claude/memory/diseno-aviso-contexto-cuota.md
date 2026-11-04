# Diseño — aviso-contexto también avisa por la cuota (5 h y semanal) (2026-10-19)

> Decidido por unjordi con claudio-master. Pendiente de implementar (backlog: estado-proyecto.md §1).

## Pedido
[user: "me gustaría que aviso-contexto incluya el estado de la cuota, te parece?"] · [user: "aviso-contexto justo puede disparar ahora por el estado de cuota en vez de solamente por ventana de contexto"] · [user: "lo que tú propusiste estuvo perfecto entonces. sólo creo que le ajustaría 'Si el snapshot está rancio o no existe, calla.' por 'Si el snapshot está rancio o no existe intenta forzar al widget a actualizarlo y luego, si falla en unos segundos, calla'"]

## Diagnóstico
Ningún hook le pone la cuota enfrente al modelo durante el trabajo. En toda la historia de cortex solo la leen `delegacion-gate`/`delegacion-comun` (dentro del aviso de consentimiento al lanzar un agente: 1× por compu, luego silencio) y `limite-gasto` (freno al lanzar agentes). La cuota se agota por su cuenta: medido 2026-10-19, ventana de 5 h al 86–90 % con el contexto al 46 %.

## Contrato
- `aviso-contexto.sh` (PostToolUse) dispara por CUALQUIERA de dos causas:
  - Contexto: bandas 80 % / 92 % — sin cambio respecto de hoy.
  - Cuota: al cruzar umbrales de la ventana de 5 h (80 % y 95 %) y de la semanal (80 %). Umbrales configurables por env, como los del contexto.
- Dispare por lo que dispare, el mensaje trae las DOS líneas (contexto y cuota), para que se lea qué conviene hacer.
- Una vez por umbral y por ventana: cada umbral de cuota avisa una sola vez y se re-arma cuando cambia el `resets_at` de esa ventana. Las bandas de contexto conservan su lógica actual.
- La línea de cuota la arma `linea_cuota` de `delegacion-comun.sh` (lee `~/Library/Caches/cortex/state.json` o `$XDG_CACHE_HOME/cortex/state.json`: `.five_hour`, `.weekly`).
- Snapshot rancio (>30 min) o ausente: lanza `cortex-fetch` DESPRENDIDO (sin heredar stdin/stdout/stderr del hook, ver H11), espera hasta ~5 s a que cambie el mtime del snapshot y lo usa; si no cambió, calla lo de la cuota. Throttle: no forzar otro fetch si ya se forzó en los últimos ~5 min (lock/sello en el estado del hook). Medido 2026-10-19: un fetch forzado reescribe el snapshot en 3,1 s; el proceso completo pasa de 30 s (enriquecimiento con ccusage), por eso se espera el mtime y no el proceso.
- Sin `cortex-fetch` (otra máquina sin widget): calla lo de la cuota; lo del contexto sigue igual.
- Fail-open como hoy.

## Invariantes verificables
- Contexto bajo + 5 h cruzando 80 % → un aviso con las dos líneas; la siguiente herramienta, sin aviso; tras un cambio de `resets_at`, se re-arma.
- Contexto cruzando 80 % + cuota baja → el aviso de hoy, más la línea de cuota.
- Snapshot rancio + `cortex-fetch` que lo reescribe → usa el dato nuevo; `cortex-fetch` colgado → calla la cuota en ≤ ~5 s y el EOF del stdout del hook llega igual de rápido.

## Qué NO es
- No es un aviso en cada turno.
- No cambia nada de lo que hoy hace con el contexto.
- No frena nada: solo avisa (el freno sigue siendo `limite-gasto`).
- No renombra el hook (el nombre se queda corto, pero no se mueve el cableado).
