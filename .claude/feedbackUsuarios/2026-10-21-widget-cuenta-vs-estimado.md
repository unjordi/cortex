# Widget de cuota: el estimado por costo contradecía la última lectura real (+ estados de auth)

**Fecha:** 2026-10-21 · **Reporta:** unjordi (relayado por claudio-master-3000) · **Rama:** fix/corpus-fp-bench

## Contrato (citas textuales de Jordi)
- "el dato estimado no tiene sentido si tenías una lectura previa que contradice lo que estás 'estimando'… para eso mejor que muestre la última con su staleness"
- "que avise cuando ya va a expirar el token oauth Y detecte cuando expiró o simplemente no hay cuenta loggeada en claude-cli, porque luego tengo compañeros que sólo usan claude en la app y el widget sólo deja de funcionar silenciosamente"
- "los avisos deberían tener un botón para hacer el re-login"

## Diagnóstico (medido)
Cuando el fetch OAuth fallaba pero ccusage tenía datos, `cortex-fetch` escribía `basis:"cost"` (estimación)
PISANDO la última lectura real `basis:"oauth"`, y la etiqueta de cuenta salía de la sesión viva
(`~/.claude.json`), que puede haber driftado → mostraba jordi.serra con números estimados mientras la
sesión era informatica@pind.mx. Schema real de auth medido: `claude auth status --json` (`.loggedIn`/`.email`);
credenciales `.claudeAiOauth.refreshTokenExpiresAt` (epoch ms, ~30 días) vs `expiresAt` del access token
(~8h, se auto-refresca → no sirve como señal de logout).

## Decisión (DURADERA)
1. **El estimado por costo NUNCA pisa una lectura oauth real.** `basis:"cost"` se RETIRA como snapshot standalone.
2. OAuth falla + hay lectura oauth previa → se PRESERVA íntegra (números+cuenta+`updated_at`), marcada
   `stale:true` + `fetched_at:ahora` + `error`. La etiqueta de cuenta sale del MISMO snapshot (la preservada).
3. OAuth falla + sin previa → `basis:null`, `status:"error"`, datos null → "no hay dato" (NO inventa estimado).
   ↳ Cambio de comportamiento autorizado por el contrato textual ("SIN lectura previa → dice 'no hay dato', NO inventa").
4. **Estados de auth en `state.json`** (`auth.state`): `ok`/`expiring`/`expired`/`no_credentials`, con `auth.expires_at`
   (refresh token). `expiring` = refresh token dentro de `CORTEX_AUTH_EXPIRING_HORAS` (default 72h). `expired` = 401/403
   o refresh vencido. `no_credentials` = sin token.
5. Cada aviso (expiring/expired/no_credentials) → botón de re-login → `claude auth login --claudeai [--email <cuenta del snapshot>]`
   (abre navegador; verificado 2.1.304).

## Estado de implementación
- ✅ **Daemon (ambos):** `macos/bin/cortex-fetch` + `src/bin/cortex-fetch` — writer con preservación + estados de auth.
  Verificado determinísticamente (matriz 7 casos / 26 asserts) EN VIVO: macOS local + Linux en cachy (GNU date). 26/26.
  Tests: `{macos,src}/pruebas/cortex-fetch-auth.test.sh`, cableados en `test-brain.sh` por plataforma. Suite 1397·0.
  Seams test-only: `CORTEX_FETCH_CREDS_JSON`/`CORTEX_FETCH_HTTP`/`CORTEX_FETCH_USAGE_FIXTURE`/`CORTEX_FETCH_NO_CCUSAGE`.
- ⏳ **Lectores (pendientes, campos aditivos backward-compatible):** QuotaModel.swift (macOS), `src/plasmoid` (KDE),
  `src/gnome-extension` (GNOME), `windows/src/Cortex` (Windows) — leer `auth.state`/`stale`/`fetched_at`, mostrar
  antigüedad + aviso + botón re-login.
- ✅ **Hooks consumidores de `state.json` (hechos):** `limite-gasto` y `delegacion-gate` (vía `linea_cuota` de
  `delegacion-comun.sh`) ahora miden frescura por `updated_at` (NO mtime, que mi cambio dejó siempre fresco → era
  una REGRESIÓN que yo introduje) y marcan el motivo de auth (login expirado / sin cuenta). no-data (five_hour null)
  = fail-open. Verificado (limite-gasto 5/5 + linea_cuota 5 casos; tests en `test-brain.sh`).
  `aviso-contexto` NO consume `state.json` hoy (lee el usage del transcript); su disparo por cuota es el paso 3
  aparte (`diseno-aviso-contexto-cuota.md`), que leerá `stale`/`basis` ahí.

## QA
Gate = QA visual EN VIVO con unjordi (el daemon está verificado técnicamente; la UI no se declara LISTA sin su QA).
