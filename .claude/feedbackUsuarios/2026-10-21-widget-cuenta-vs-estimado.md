# Widget de cuota: etiqueta de una cuenta con números estimados de otra fuente (claudio-master, 2026-10-21)

Medido en la Mac:
- 15:04Z state.json: `basis: "cost"` (fallback ccusage), 5 h 0 %, semanal 5 %, reset semanal 2026-10-26 (domingo).
- Captura de unjordi del popover a esa hora: pie "jordi.serra@pind.mx", Sesión 0.0 % "≈ $0.00 (API equiv local)", Semanal 5.0 % "Se restablece dom@6:00 · ≈ $244.27". La cuenta jordi.serra en claude.ai a esa hora: sesión 8 %, semanal 77 % (reset vie 5:00).
- 15:11Z state.json: `basis: "oauth"`, `account_email: informatica@pind.mx`, `account_mismatch: false`, 5 h 1 %, semanal 0 %, reset 2026-10-28 (la cuenta de informática se reinició esa mañana). Claude Code en la Mac corre con informatica@pind.mx.

Hallazgo: con el fallback por costo, el popover muestra una cuenta (jordi.serra) con números que no son de ninguna cuenta real y no marca de forma visible que es un ESTIMADO; quien lo lee cree que jordi está al 5 % cuando está al 77 %. Además, a qué se debe la etiqueta jordi.serra si la sesión de Claude Code es de informatica está por averiguar (¿etiqueta de un snapshot previo? ¿otra fuente?).
Debería: (1) con basis=cost, el popover lo dice claro (p. ej. "ESTIMADO — sin dato de Anthropic") y no presenta la cifra como la de la cuenta; (2) la etiqueta de cuenta sale del mismo snapshot que los números. Y averiguar por qué cayó al fallback a las 15:04 (¿refetch por cambio de cuenta?).
Relacionado: el diseño aviso-contexto+cuota (diseno-aviso-contexto-cuota.md) debe ignorar o marcar como estimado un snapshot con basis=cost.

## DECISIÓN de unjordi (2026-10-21)
[user: "el dato estimado no tiene sentido si tenías una lectura previa que contradice lo que estás 'estimando'. Si la última lectura decía '70% semanal con reset el viernes', no puedo aceptar que nuestro widget 'estime' 5%... para eso mejor que muestre la última con su staleness"]
Contexto que dio: ya había cambiado la sesión de Claude Code a la cuenta de informática.
Contrato: si el fetch por OAuth falla, el widget (y todo consumidor de state.json: aviso-contexto+cuota, delegacion-gate, limite-gasto) usa la ÚLTIMA lectura real (basis=oauth), con SU cuenta y SU antigüedad visible ("hace N min"), en vez de un estimado por costo que la contradiga. El estimado por costo nunca pisa una lectura real.

## AGREGADO de unjordi (2026-10-21): token OAuth y "sin cuenta"
[user: "que avise cuando ya va a expirar el token oauth Y detecte cuando expiró o simplemente no hay cuenta loggeada en claude-cli, porque luego tengo compañeros que sólo usan claude en la app y el widget sólo deja de funcionar silenciosamente"]
Contrato:
- Token por expirar (antes de que expire): aviso visible en el widget.
- Token expirado: el widget lo dice claro (no cae callado a un estimado ni deja el último número como si fuera actual; muestra la última lectura con su antigüedad + "token expirado — inicia sesión en Claude Code").
- Sin cuenta loggeada en el CLI (compañeros que solo usan la app de Claude): el widget lo dice claro ("no hay sesión de Claude Code en esta máquina"), en vez de dejar de funcionar en silencio.
- Los tres estados viajan en state.json (p. ej. `status`/`error` explícitos) para que los hooks consumidores también los vean.
Tests: un caso por estado (token vigente, por expirar, expirado, sin credenciales), en las dos direcciones.
- [user: "y los avisos deberían tener un botón para hacer el re-login"] Cada aviso (por expirar, expirado, sin cuenta) trae un botón de re-login que invoca la vía OFICIAL de la CLI (verificado en Claude Code 2.1.304): `claude auth login --claudeai [--email <cuenta del último snapshot>]` (abre el login en el navegador). Para detectar el estado, `claude auth status --json`. Gemelos en macOS/KDE/GNOME/Windows.
