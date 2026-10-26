# Revisión 10 — resto (no-bypass-deploy, entorno-maquina-guard, delegacion-registrar)
Fecha: 2026-10-19 · revisor: claudio-master · rango de6df53..52d2d8c

## Resultado
- Los 3: diff SOLO de comentarios (medido).
- entorno-maquina-guard, commits reales en repo desechable: avisa con entorno-maquina.md staged y con una memoria con rutas personales; calla con memoria neutra y con la mención entrecomillada `echo "git commit -m x"`. OK en las dos direcciones.
- delegacion-registrar: PostToolUse de Agent → rc 0 + su systemMessage. OK.
- no-bypass-deploy: H17.
- Muestra del corpus: corrí `correr-git-branch-guard.sh` de fix/corpus-fp-bench (copia con git archive): 23 pasan, 0 vivos, 4/4 controles+ frenan; el banco neutraliza el dedupe con HOME falso (los controles prueban que evalúa). CONFIRMADO.

## H17 BAJO — no-bypass-deploy.sh: no reconoce rutas con `~/` ni `$HOME/` (anterior a la épica)
Entrada → salida medida:
- `bash /Users/unjordi/.cortex/brain/install-brain.sh` → AVISO ✓
- `cd ~/.cortex/brain && ./install-brain.sh` → AVISO ✓
- `bash ~/.cortex/brain/install-brain.sh` → calla ✗
- `bash $HOME/.cortex/brain/install-brain.sh` → calla ✗
Causa: `_path='(\./|/)?([A-Za-z0-9_.-]+/)*'` no admite `~` ni `$HOME` como prefijo. Debería: aceptar `(~|\$HOME|\$\{HOME\})?/` al inicio de la ruta. Es un falso NEGATIVO de un guard que solo avisa; justo las dos formas más comunes de escribirlo.
