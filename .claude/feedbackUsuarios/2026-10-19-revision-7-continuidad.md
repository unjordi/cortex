# Revisión 7 — continuidad (rehidratar-hilo, checkpoint-mecanico(+comun), contrato-hilo, exportar-sesion-master, sincronizar-tasklist, recordar-cosechar, aviso-contexto)
Fecha: 2026-10-19 · revisor: claudio-master · rango de6df53..52d2d8c

## Resultado
- Solo dos cambios de lógica en la sección (el resto, comentarios; medido con `git diff -U0` filtrando comentarios):
  1. exportar-sesion-master: ¿es master? por `<sid>.meta.json` en vez de masters.json; ya no escribe masters.json.
  2. rehidratar-hilo: vigilante de 8 s.
- (1) corrido con un motor stub (HOME falso, Drive desechable), 6 casos, todos según contrato: Stop sin meta → sale sin escanear; PreCompact "foo-master" → exporta; "bar-master (2)" → exporta como "bar-master"; "normalita" → no; Stop con meta ya presente → exporta.
- (2) H11, abajo.

## H11 MEDIO — rehidratar-hilo.sh:57: el vigilante retiene el stdout del hook 8 s
Entrada: cualquier SessionStart (startup/compact/resume) con el hook instalado (52d2d8c).
Hace: el proceso sale en 0,06 s, pero el EOF de su stdout llega a los 8,01 s (medido con el hook real: 19 KB de salida). El subshell `( sleep "$_tope"; kill -TERM "$$" ) &` hereda stdout/stderr; el trap EXIT mata el subshell pero no su `sleep`, que queda huérfano con el pipe abierto hasta vencer el tope. [INFER] Si el harness espera el cierre del stdio (Node 'close'), cada arranque y cada compact esperan 8 s.
Debería: el vigilante no debe heredar el stdio. Probado: `( sleep "$_tope"; kill -TERM "$$" 2>/dev/null ) </dev/null >/dev/null 2>&1 &` → EOF a 0,21 s con el mismo trabajo previo (viejo: 8,01 s). Opcional: matar también el `sleep` huérfano en el trap (`pkill -P "$_wd"`).
Reproductor (el test debe fallar contra 52d2d8c):
```
python3 - <<'PY'
import subprocess,time,json,os
h=os.path.expanduser('~/.claude/hooks/rehidratar-hilo.sh')
t=time.time(); p=subprocess.Popen(["bash",h],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=dict(os.environ,CLAUDE_PROJECT_DIR=os.getcwd()))
p.stdin.write(json.dumps({"session_id":"x","hook_event_name":"SessionStart","source":"compact"}).encode()); p.stdin.close()
p.wait(); e=time.time()-t; p.stdout.read(); p.stderr.read(); print(f"proceso {e:.2f}s · EOF {time.time()-t:.2f}s")   # debe ser EOF < 1s
PY
```
Ojo al escribir el test: si el script termina antes de que el subshell alcance a lanzar el `sleep`, no se reproduce (con 0 ms de trabajo previo daba 0,01 s); el hook real sí lo alcanza.

## H12 BAJO — exportar-sesion-master.sh `_master_base`: un master con sufijo propio no se exporta (anterior a la épica)
Entrada: sesión con título "claudio-master-3000" (el master principal de unjordi hoy; transcript e13afa56).
Hace: no coincide con `*-master` ni `*-master (N)` → no se exporta nunca; no hay `e13afa56.meta.json` en ~/claude-sessions (el último export de claudio-master es 2cc11a7f, 2026-10-16).
Debería: decisión tuya/de unjordi — o el patrón acepta `*-master-*`, o la convención es renombrar la sesión. Hoy la falla es muda.

## Nota (sección 9)
reubicar-master.sh sigue exigiendo y escribiendo masters.json (preflight L622), mientras exportar-sesion-master ya no lo mantiene. Lo reviso en la sección 9.
