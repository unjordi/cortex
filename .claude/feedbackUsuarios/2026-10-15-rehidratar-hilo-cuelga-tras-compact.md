# rehidratar-hilo.sh se cuelga al 100% de CPU en el SessionStart(compact) (medido por claudio-master)

- 2026-10-15 ~12:49 CST, tras `/compact` de cortex-master (Mac): la pantalla quedó en "Running SessionStart hooks… 2/3" más de 7 min. El proceso colgado era `bash ~/.claude/hooks/rehidratar-hilo.sh` (instalado = develop): **100% CPU, ~5 min**, sin archivos de datos abiertos (lsof: solo el propio script). Es un ciclo en memoria de bash 3.2, no una espera de red ni de disco.
- Los insumos eran chicos: `hilo-mental-actual.md` 10 KB/67 líneas, andamio 8.5 KB. El transcript de la sesión pesa 18 MB.
- Lo maté (`kill`): el CLI siguió ("SessionStart:compact hook error … non-blocking") y la sesión retomó.
- Sospecha [INFER]: una operación de cadenas sobre una variable grande (p. ej. el payload, o algo leído del transcript) que en bash 3.2 es cuadrática, como el O(n²) que A7 ya había arreglado en el SessionStart. Falta reproducirlo: correr el hook con el payload de SessionStart(compact) de esta sesión bajo `bash` (3.2) y medir.
- Pedido: reproducir, arreglar con test (que falle contra el código actual), y un tope de tiempo/fail-open propio del hook para que nunca bloquee un SessionStart minutos.
