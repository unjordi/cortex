# Diálogos de contraseña y preguntas de los Claudes: con identidad visual y donde está unjordi

De: axon-master (cachy), 2026-11-01. Pedido de unjordi: que el mecanismo de preguntas se integre bonito, con el ícono de Claude.

## Lo que ya existe (PowerScripts, develop)
- `macos/pedir-contrasena.sh [--vista-previa] "<quién>" "<para qué>" "<máquina>"`: diálogo de la Mac al frente, título
  «<máquina> · <quién>», ícono de Claude (`macos/recursos/claude.icns`), cuerpo partido a 44 caracteres por renglón sin
  sangría, botones Cancelar/Autorizar, Typing.wav al aparecer (salvo 22:00–08:00). Imprime la contraseña; sale 1 si se
  cancela. `--vista-previa` muestra el diálogo sin campo y no imprime nada.
- `linux/pedir-root.sh "<quién>" "<para qué>" "<comando>"`: `sudo -A` con un askpass que corre lo anterior por `ssh mac`.
  Sin diálogo ni sonido locales (la cachy no tiene bocinas y su pantalla no se ve). Sin Mac sale 3 sin llamar a sudo.
- `macos/pedir-root.sh` (comandos de root en la Mac) sigue con el diálogo del sistema de `do shell script`.

## Lo que se pide al cerebro
1. Que TODO diálogo que un Claude le levante a unjordi (contraseñas, confirmaciones, preguntas con opciones) use la misma
   identidad: ícono de Claude, título «<máquina> · <master>», cuerpo por renglones ≤44 caracteres, en la Mac.
2. Una sola pieza para preguntar con opciones (no solo contraseñas), gemela de pedir-contrasena.sh, y que las normas
   (como-trabajar «Todo diálogo de contraseña… dice de qué Claudio es») apunten a ella.
3. Regla para pruebas: una vista previa nunca lleva campo de contraseña (`--vista-previa`). Hoy una vista previa con campo
   imprimió una contraseña real en un transcript.

## Recursos (en esta carpeta)
- `recursos-2026-11-01-dialogos/claude-code.svg` y `.png`: originales de unjordi (vinieron de sus Descargas).
- `recursos-2026-11-01-dialogos/claude.icns`: el .icns generado (16–1024 px, viewBox con margen de 2 unidades).
