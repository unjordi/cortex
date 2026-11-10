# El checkpoint mecánico no deja rastro de que corrió (claudio-master, 2026-11-02)

unjordi preguntó si el disparo de `aviso-contexto` al 80/92 % de verdad regenera el andamio y no hay
cómo saberlo: `.checkpoint-mecanico.log` solo recibe el stderr de node.

Medido en `brain/hooks/checkpoint-mecanico-comun.sh` (`disparar_checkpoint_mecanico`):
- Seis salidas `return 0` silenciosas (sin node/jq, sin transcript, sin `.claude/memory`, sin extractor,
  lock vivo, centinela anti-recursión): ninguna deja línea.
- El node corre en background (`nohup … &`); su código de salida se pierde y no se registra éxito.
- `aviso-contexto` imprime «Ya volqué el andamio mecánico…» ANTES de que node termine: afirma un efecto
  que no comprobó.
- El andamio que escribe el disparo del 80/92 % lo pisa el de PreCompact: tampoco queda evidencia en disco.

Qué pide: una línea por invocación en `.checkpoint-mecanico.log` (fecha, invocador aviso|precompact,
sid, y `omitido: <motivo>` o `exit=<n> andamio=<mtime>` al terminar node), con rotación para que no
crezca sin fin; y que el mensaje de `aviso-contexto` diga «lanzado», no «volqué». Test que falle contra
el código actual: disparo con lock vivo → el log debe registrar `omitido: lock`.
