# Widget (macOS): mide mal al despertar la Mac — dos fallas en secuencia

**Fecha:** 2026-10-28 · **Reporta:** claudio-master, con capturas de unjordi · **Componente:** `cortex-fetch` + `PopoverView`/`QuotaModel` (macOS)
[user 2026-10-28: "en ambos casos, el widget está midiendo mal"]

## Qué vio unjordi al prender la Mac (~10:25)
1. **Sin internet todavía.** Muestra Sesión 5h **93.0 %**, con «Se restableció hace 15h · actualizando… · ≈ $22.82». Semanal 76 % y Fable 1 %. «últ. act. hace 15h».
   - Falla: la ventana de 5h ya se restableció hace 15 h, pero el widget pinta el 93 % de anoche como si fuera el valor vigente. Con `resets_at` vencido ese número ya no aplica: el % debe mostrarse como desconocido («— · se restableció, sin lectura nueva»), no con el valor viejo, y mucho menos con la barra roja.
   - develop a218cd9 hace lo mismo: `PopoverView.swift:430-434` solo cambia el texto a «actualizando…» y conserva el %.
2. **Ya con internet, en la primera lectura.** Muestra Sesión **0.0 %** («Se restablece ·» sin hora, ≈ $0.00) y Semanal **0.8 %** (≈ $38.70).
   - Falla: el número es inventado. El state.json de ese momento traía `basis:"cost"`, `limits:null` y `weekly.percent = 38.7/4800 (cost_cap)`: es el estimado por costo, y el semanal real era 76-78 %. El fetcher instalado (`~/.local/bin/cortex-fetch`, del 19-oct) cae a ese estimado cuando la lectura oauth no llega y lo escribe con `status:"ok"`.
   - develop ya retira `basis:"cost"` en `QuotaModel.swift:44` y conserva la lectura oauth previa marcada `stale` (`macos/bin/cortex-fetch:366-394`). Pero eso devuelve justo la falla 1: conserva el 93 % de antes del reset.
3. **Minutos después** salió bien: 5h 5 %, semanal 78 %, Fable 1 %.

## Causa de que esta Mac corra el fetcher viejo
`install-brain.sh` (instalado ayer, v0.2.431) no actualiza `~/.local/bin/cortex-fetch` ni el `.app` del widget. Esos los pone el instalador del widget, y el updater del widget no instala desde develop (punto 3 de la coordinación del 2026-10-27). Va de la mano con ese ítem.

## Qué se espera (lo de las dos direcciones va en el test)
- Si el `resets_at` de una ventana ya pasó y no hay lectura posterior, esa ventana se muestra como «sin dato» y nunca con el % previo. La semanal, si su reset no ha pasado, conserva la lectura previa marcada stale.
- Una lectura sin oauth jamás pinta un %: ni el estimado por costo, ni 0.0 % como si fuera real.
- Test con fixtures de state.json: (a) 5h con `resets_at` pasado → «sin dato»; (b) 5h vigente → muestra el %; (c) primera lectura sin oauth tras dormir → no hay 0.0 % ni 0.8 %; (d) con oauth → números reales.

## Dato medido después (10:33)
- Corrí `~/.local/bin/cortex-fetch` a mano una vez: terminó con rc=0 y `basis:"oauth"` (5h 5 %, semanal 78 %), pero **tardó más de 120 s**. Esa lentitud explica la ventana en que se vio el estimado por costo. Falta medir en qué paso se va el tiempo (¿ccusage, la llamada oauth?).
