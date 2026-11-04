# Revisión directa de lo integrado (de6df53..52d2d8c) · sección 3: secret-scan + detectar-secretos.sh

Revisión de claudio, pedida por unjordi el 2026-10-19 ("revísalo a detalle, módulo por módulo"). Lo integrado ya está instalado en la Mac y la cachy.

## Lo que cambió
- `secret-scan.sh`: solo comentarios.
- `detectar-secretos.sh`: `ds_safe_re` suma `PRUEBA|no[-_ ]?real|de[-_ ]?prueba|dummy|fake`.

## H6 · ALTO · fail-open: un secreto real que CONTENGA esas palabras deja de detectarse
`ds_buscar` aplica `grep -viE "$_DS_SAFE_RE"` a la coincidencia completa. Es decir, sin distinguir mayúsculas y como subcadena en cualquier parte del valor.

Medido con `ds_buscar` del hook instalado (= 52d2d8c):

| línea | resultado | debería |
|---|---|---|
| `Password=PRUEBA-no-real` | limpio | limpio |
| `Password=placeholder-no-real` | limpio | limpio |
| `Password=Prueba2024!` | **limpio** | DETECTA |
| `Server=x;Password=PruebasMegaflux#77;` | **limpio** | DETECTA |
| `pwd=FakeIt$Strong9` | **limpio** | DETECTA |
| `postgres://admin:DummyPass99@db:5432/x` | **limpio** | DETECTA |
| `Password=Hunter2Strong` | DETECTA | DETECTA |
| `postgres://admin:S3cret99@db:5432/x` | DETECTA | DETECTA |

"Prueba…" es una contraseña típica de ambientes de desarrollo y QA en español, y esas suelen ser reales. Con esto, un guard defensivo deja pasar justo el caso más común.

**Arreglo:** que el marcador sea el valor COMPLETO, no una subcadena. El valor tiene que estar formado solo por palabras marcador y separadores, por ejemplo `^(placeholder|prueba|no[-_ ]?real|de[-_ ]?prueba|dummy|fake|changeme|xxxx+)([-_ ]+(…))*$` sobre el valor ya extraído. Hay que revisar con la misma vara los marcadores viejos (`placeholder`, `redacted`, `your…key`), que tienen el mismo problema de subcadena: `Password=placeholderX9#real` hoy sale limpio. Necesita tests en las dos direcciones, con estas 8 líneas como fixture.

## Relación con el banco del corpus
El banco de secret-scan (194c47e) da "3 pasa/0 vivos". Mide solo los falsos positivos, la mitad de la prueba. H6 es la otra mitad: lo que debe frenar y ya no frena. El banco necesita controles positivos con valores reales que contengan esas palabras.
