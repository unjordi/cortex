# DECISIÓN (vieja, nunca asentada): UN SOLO núcleo para el widget; las plataformas solo dibujan
Fecha de registro: 2026-11-01 · De: claudio-master · A quién le toca: cortex-master · Prioridad: ALTA (cada arreglo se hace 3-4 veces)

[user 2026-11-01: "hace mucho que pedí que tuviéramos un sólo núcleo"] — no lo encontré escrito en estado-proyecto, bitácora ni buzón
(grep de «núcleo/duplic» en .claude/memory y feedbackUsuarios): por eso se perdió. Desde hoy es una decisión vigente, no una propuesta.

Medido hoy (origin/develop deeb2a5):
- Lectura de la cuota ×3: macos/bin/cortex-fetch (797 l) · src/bin/cortex-fetch (762 l, ~257 líneas distintas del de macOS) · windows/src/Cortex/QuotaService.cs (fetch propio en C#).
- Interpretación de state.json ×4: QuotaModel/PopoverView (Swift) · main.qml (KDE, 3632 l) · QuotaService/PopupForm (C#) · src/gnome-extension (3259 l JS).
- Consecuencia: el arreglo «% viejo al despertar» se hizo 3 veces (fix/widget-verdad-al-despertar); bugs que existen en una plataforma y no en otra.

Qué se pide (épica): un núcleo único que lee la cuota y entrega YA INTERPRETADO lo que hay que mostrar (por ventana: % o «sin dato», texto del reset,
color/umbral, costo equiv, avisos); los widgets (macOS, KDE, GNOME, Windows) solo lo dibujan. Windows deja su fetch propio. Un solo cortex-fetch
(no un bash por OS). Encaja con la visión de unjordi de módulos con endpoints estándar (axon/cortex).
Orden: después del lote actual (cortex-fetch, widget-verdad, apagar-widget, retiros de dod-verificar y del cerebro por-repo).
