# El widget no se actualiza al cambiar de cuenta de Claude (reporte de unjordi, diagnóstico de claudio-master)

unjordi: "el widget no se actualizó con el cambio. lo tuve que forzar" (cambio de cuenta, 2026-10-15 ~12:30 en la Mac).

**Mecanismo (leído en macos/Sources/Cortex/AppDelegate.swift):** el tick de 10 s solo relanza `cortex-fetch` si el caché tiene más de `staleThreshold` (330 s) o si ya pasó un reset (`anyResetPassed && age > 60`). Cambiar de cuenta no es ninguna de las dos, así que el widget sigue mostrando la cuenta y la cuota anteriores hasta 5.5 min (más el agente de launchd, cada 5 min). `cortex-fetch` sí relee las credenciales del llavero en cada corrida; el problema es solo que nadie lo dispara.
Tras el forzado, medido: `state.json` (12:33:56) = cuenta activa de `~/.claude.json` (`jordi.serra@pind.mx`, uuid `0f969ded-…`).

**Arreglo propuesto:** en el tick, leer `.oauthAccount.accountUuid` de `~/.claude.json` (barato) y, si difiere de `account_uuid` del snapshot, `runFetch()` inmediato. Gemelo en el plasmoid (QML) y en Windows (C#). Test: snapshot con uuid A y `~/.claude.json` con uuid B → el siguiente tick dispara el fetch; uuids iguales y caché fresco → no dispara.

**Ajuste de unjordi:** la comparación de cuenta va cada 30 s, no en cada tick de 10 s [user 2026-10-15: "puede ser cada 30s, no hace falta que sea tan ansioso"]. Test igual, con el intervalo de 30 s.
