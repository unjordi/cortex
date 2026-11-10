# /compact por screen: el paste largo no dispara el slash

- Síntoma: `screen -X readbuf + paste` de un `/compact <instrucciones>` largo no compacta; el texto queda como bloque «[Pasted text] / paste again to expand» y se envía como mensaje normal.
- Arreglo medido 2026-10-23: teclear el texto con `screen -X stuff` en trozos de 200 caracteres y luego `stuff $'\\r'`. Arrancó «Compacting conversation».
- Dónde va: skill coordinar-claudes (receta de /compact por screen).
