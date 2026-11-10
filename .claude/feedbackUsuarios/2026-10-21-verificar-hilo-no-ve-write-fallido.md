# verificar_hilo da OK sobre un hilo VIEJO cuando el Write del checkpoint falló

- Caso real 2026-10-21 17:58 (cps-master, cachy): `Write(.claude/memory/hilo-mental-actual.md)` → "Error writing file"; el archivo quedó de las 13:42. Acto seguido `verificar_hilo` → rc=0 (el pie dice 2026-10-21, mismo día) y la sesión anotó en bitácora "checkpoint COMPLETO" que no existió.
- Lo vio unjordi [user: "mira, le acaba de pasar lo del hilo al cps-master"].
- Propuesta: que el paso de verificación del skill checkpoint compruebe que el hilo SE ESCRIBIÓ en este volcado — mtime del archivo ≥ inicio del checkpoint (o hora en el pie con HH:MM y compararla), y si no, error claro "el hilo NO se escribió (mtime 13:42)". Test: hilo con mtime viejo → falla; recién escrito → pasa.
