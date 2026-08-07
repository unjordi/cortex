---
name: markdown-a-pdf
description: Convertir uno o varios .md a PDF pulido y distribuible (documentación técnica, reportes, cualquier entregable que un humano vaya a abrir fuera del chat) usando `md-to-pdf` vía `npx` — sin instalar nada. Incluye el gotcha real que borra TODO el formato (`--stylesheet` reemplaza el tema default en vez de sumarse — usa `--css` para overrides), el CSS que evita que las tablas se corten feo entre páginas, y el loop de QA visual obligatorio (leer cada página generada, no asumir que renderizó bien). Úsala cuando el entregable final es un PDF a partir de Markdown, sobre todo si tiene tablas largas o necesita calcar el formato de un documento legado.
---

# Markdown → PDF pulido (sin instalar nada, con QA visual real)

> Nació de generar 15 documentos de ingeniería inversa estilo ASPEL (diccionarios de datos con
> tablas largas) a partir de `.md`, calcando el formato de PDFs legado. Dos regresiones reales en
> el camino — tablas cortadas feo entre páginas, y una que se comió TODO el formato al intentar
> arreglar la primera — están documentadas abajo con su causa raíz exacta, no solo el síntoma.

## Cuándo usar esta skill
Cuando el resultado final que el usuario va a abrir es un **PDF**, no un `.md` — reportes,
documentación técnica para compartir fuera del repo, cualquier cosa que deba verse bien en un
lector de PDF real (Preview/Adobe), no solo en el render del chat. Si el destino es GitHub/docs
del repo, no esto — usa el skill `diagramar`/Markdown plano, un PDF ahí es fricción innecesaria.

## Herramienta: `md-to-pdf` vía `npx`, sin instalar

```bash
npx -y md-to-pdf archivo.md
```

Genera `archivo.pdf` junto al `.md` (Puppeteer/Chromium por debajo, primera corrida descarga el
paquete vía npm — tarda unos segundos, luego queda cacheado). Para un lote, un loop simple:

```bash
for f in *.md; do
  npx -y md-to-pdf "$f" --css "$(cat overrides.css)" \
    --pdf-options '{"format":"Letter","margin":{"top":"12mm","bottom":"12mm","left":"10mm","right":"10mm"}}' \
    < /dev/null
done
```

El `< /dev/null` importa: `md-to-pdf` intenta leer stdin (para el modo "pipe markdown in"); sin
redirigirlo, corridas dentro de un loop o con `yes |`/similar pueden colgarse o tronar con
`RangeError: Invalid string length` (visto real al probar con `yes |` para saltar un prompt de
`cp` — el prompt era de `cp`, no de `md-to-pdf`, pero el stdin sin resolver de `md-to-pdf` igual
truena si algo más está escribiendo a ese pipe).

## GOTCHA REAL Y GRAVE — `--stylesheet` NO suma, REEMPLAZA el tema default

**Síntoma:** agregas una hoja de estilos para arreglar algo puntual (p. ej. paginación de tablas)
con `--stylesheet mi-fix.css`, y el PDF entero pierde tipografía, bordes de tabla, espaciado —
"perdió todo el formato". No es un bug sutil de CSS, es el propio código de `md-to-pdf`:

```js
// dist/lib/md-to-pdf.js — merge de argumentos CLI sobre el config
for (const arg of Object.entries(args)) {
    const [argKey, argValue] = arg;
    const key = argKey.slice(2).replace(/-/g, '_');
    config[key] = argValue;   // ← SOBRESCRIBE, no concatena
}
```

`config.stylesheet` por default es `[ruta/a/markdown.css]` (el tema base que trae el paquete, con
tipografía, bordes, espaciado). Pasar `--stylesheet` desde la CLI **reemplaza ese arreglo
completo** con solo lo que tú diste — el tema base desaparece, silencioso, sin warning.

**La forma correcta de agregar CSS sin perder el tema base es `--css`** (string crudo), que
`generate-output.js` aplica como una etiqueta `<style>` ADICIONAL, en capas encima del tema:

```js
// dist/lib/generate-output.js
for (const stylesheet of config.stylesheet) { await page.addStyleTag({ path: stylesheet }); }
if (config.css) { await page.addStyleTag({ content: config.css }); }  // ← esto SÍ suma
```

```bash
# MAL — pierde el tema base
npx -y md-to-pdf archivo.md --stylesheet mi-fix.css

# BIEN — el tema base se conserva, mi-fix.css se agrega encima
npx -y md-to-pdf archivo.md --css "$(cat mi-fix.css)"
```

Si de verdad necesitas reemplazar el tema entero (no sumar), `--stylesheet` es la herramienta
correcta — solo ten claro que ESO es lo que hace, y en ese caso pasa también la ruta al
`markdown.css` default si quieres conservarlo junto con el tuyo (se puede pasar `--stylesheet` más
de una vez; el array final es exactamente lo que pasaste, nada implícito).

## GOTCHA — tablas largas se cortan feo entre páginas (texto partido a media oración)

**Síntoma:** una fila con descripción larga queda literalmente cortada por el salto de página —
la mitad del texto en una página, la otra mitad en la siguiente — o un encabezado de tabla queda
huérfano al fondo de una página con la primera fila de datos empezando sola en la siguiente. Causa:
sin reglas de paginación, el motor de impresión de Chromium no sabe que una fila de tabla debe
tratarse como unidad atómica.

CSS que lo arregla (pásalo con `--css`, NO `--stylesheet`, ver gotcha de arriba):

```css
table { border-collapse: collapse; width: 100%; }
thead { display: table-header-group; }   /* repite el header si la tabla sigue en la sig. página */
tfoot { display: table-footer-group; }
thead tr { page-break-after: avoid; break-after: avoid; }  /* header nunca queda huérfano solo */
tr { page-break-inside: avoid; break-inside: avoid; }      /* una fila nunca se parte a la mitad */
td, th { page-break-inside: avoid; break-inside: avoid; }
h1, h2, h3 { break-after: avoid; page-break-after: avoid; } /* un título nunca queda solo al fondo */
```

Efecto secundario esperado y ACEPTABLE: a veces queda un hueco en blanco al fondo de una página
porque la siguiente fila no cabía completa y se movió entera a la próxima — eso es correcto y muchísimo
mejor que texto partido a media oración. No lo confundas con el bug real.

## Márgenes y tamaño de página

El default de Puppeteer/md-to-pdf es generoso (A4, márgenes ~30-40mm) — para calcar un documento
tipo oficio/carta con márgenes ajustados:

```bash
--pdf-options '{"format":"Letter","margin":{"top":"12mm","bottom":"12mm","left":"10mm","right":"10mm"}}'
```

## Resaltar campos/valores específicos con precisión (sin sobre-marcar)

Si necesitas colorear/resaltar solo un subconjunto de celdas de tabla que cumplen una condición
real (p. ej. "campos requeridos" contra un esquema verdadero) — **no confíes en negritas/markdown
genérico ya presente en el `.md`**, puede haber bold usado para otro tipo de énfasis en las mismas
tablas (visto real: descripciones con texto en negritas para resaltar hallazgos, sin relación con
"requerido"). Recolorear TODO lo que esté en negritas produce falsos positivos.

Mejor: post-procesa el `.md` con un script que localice la columna correcta por NOMBRE de header
(no por posición fija — puede variar), y solo inyecte HTML con color en las celdas donde el valor
real de esa columna cumple la condición (ej. columna "Requerido" == "1"), dejando el resto de
negritas intactas en su color normal:

```python
# Para cada tabla, ubica el índice real de las columnas 'Campo'/'Requerido' por el header,
# no asumas que son las columnas 1 y 4 — verifica antes de aplicar el color en bloque.
if stripped_cells[req_idx] == '1':
    cells[campo_idx] = colorize(cells[campo_idx])   # solo esta fila, solo estas 2 celdas
```

GFM/markdown-it soporta HTML crudo dentro de celdas de tabla, así que
`<strong style="color:#b3261e">TEXTO</strong>` renderea bien mezclado con el resto del markdown.

## QA visual OBLIGATORIA — lee cada página generada, no asumas que renderizó bien

Un PDF que "se generó sin error" no significa que se vea bien — los dos gotchas de arriba
(paginación rota, tema perdido) **no truenan el comando**, el PDF se genera "exitosamente" y
queda mal igual. La única forma de saberlo es mirarlo:

1. Cuenta páginas: `pdfinfo archivo.pdf | grep Pages` (viene con poppler, típicamente ya instalado).
2. Lee TODAS las páginas con el tool `Read` (soporta PDFs, hasta 20 páginas por llamada —
   `pages: "1-8"`) y mira el resultado con tus propios ojos antes de dar el lote por bueno.
3. Para un lote de N documentos: arregla y verifica en **UNO piloto** primero (más barato iterar),
   recién cuando el piloto se vea bien aplica el fix a todo el lote y CONFIRMA de nuevo — no
   asumas que un fix que funcionó en el piloto se ve igual en los demás sin mirarlos (estructuras
   de tabla distintas, ej. catálogos de datos vs. diccionarios de esquema, pueden reaccionar
   distinto a la misma regla CSS).
4. Si el usuario reporta "se ve mal"/"perdieron el formato" después de que tú ya "verificaste" —
   NO asumas que es caché de su visor: vuelve a generar y a leer el archivo real primero (fue
   exactamente lo que pasó con el gotcha de `--stylesheet`: el propio Read-tool había mostrado un
   render que a primera vista parecía correcto, pero el detalle real — tipografía sans-serif del
   tema vs. serif default del browser — solo se nota comparando lado a lado con cuidado).

## Evitar `--as-html` para depurar

`--as-html` (para inspeccionar el HTML intermedio antes del PDF) se quedó colgado indefinidamente
en una corrida real de esta skill (proceso `npm exec md-to-pdf ... --as-html` vivo sin salir,
hubo que matarlo a mano). Si necesitas depurar el HTML generado, es más confiable ir directo al
PDF final y usar el loop de QA visual de arriba — no vale la pena el tiempo de depuración de
`--as-html` colgado.
