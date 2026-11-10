# Dos fallas con las sesiones de FONDO (claude daemon / bg-pty-host), vistas al mudar games-master

**Fecha:** 2026-10-28 · **Reporta:** claudio-master · Medido en la cachy, CLI 2.1.312.

## 1. `despertar-master.sh --cerrar` reporta «cerrado» y la sesión sigue viva
- `--cerrar games-master` imprimió «'games-master' cerrado (sin proceso ni screen)», pero seguían vivos `claude bg-pty-host … --resume …/6f9a5bf4….jsonl` (PID 2110440) y el CLI hijo `/home/unjordi/.local/share/claude/versions/2.1.312 --resume …` (PID 2110453).
- Causa probable: `_pids_master` filtra por un ejecutable que se llame `claude`, y en una sesión de fondo el proceso real es `versions/<x.y.z>`. La cachy además no tiene `screen`.
- Hubo que cerrarla con `kill -TERM 2110453`.
- Se pide: reconocer el ejecutable `versions/<ver>` y el `bg-pty-host`, con test en las dos direcciones: cierra una sesión de fondo, y no toca otra sesión con distinto id.

## 2. `exportar-sesion-master` dejó de actualizar el respaldo de games-master
- En el settings global de la cachy está cableado en Stop, SessionEnd y PreCompact. Aun así, el `.jsonl.gz` en `GoogleDrive/claude-sessions` se quedó en el **2026-10-27 10:18**, con el transcript activo hasta el 28-oct 11:53 (272 MB). No había `.lock` de esa sesión.
- El export a mano (`node ~/.local/bin/session-export.js <sid> --repo <tmp> --name games-master --force`) sí funciona: rc 0, 65 MB, gz válido.
- No medí en qué paso falla el hook dentro de una sesión real; corre detached con nohup y tira toda la salida a /dev/null. Sospechas, sin verificar: OOM o timeout de node con 272 MB, o el `gzip -t`.
- Se pide: que el export detached deje un log con su rc y su error, y diagnosticar con ese log.
- Además, en `GoogleDrive/claude-sessions` quedaron 6 `.export-*.lock` huérfanos del 13 al 23-oct: sesiones de 0204409d, 386ac97c, 4c65625c, 67da9d31, 8900b6c5 y d199fa8d. Esta última es cortex-master.
