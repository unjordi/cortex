// Gráficas dibujadas con St.DrawingArea + cairo: barras apiladas por día (Modelos/Proyectos) y el
// heatmap tipo GitHub (Resumen). Port de los Repeater/Rectangle de main.qml.
import St from 'gi://St';

function rgb(hex) {
    const n = parseInt(hex.slice(1), 16);
    return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
}

function roundRect(cr, x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    cr.newSubPath();
    cr.arc(x + w - r, y + r, r, -Math.PI / 2, 0);
    cr.arc(x + w - r, y + h - r, r, 0, Math.PI / 2);
    cr.arc(x + r, y + h - r, r, Math.PI / 2, Math.PI);
    cr.arc(x + r, y + r, r, Math.PI, 3 * Math.PI / 2);
    cr.closePath();
}

function area(width, height, paint) {
    const a = new St.DrawingArea({width, height});
    a.set_style(`width: ${width}px; height: ${height}px;`);
    a.connect('repaint', () => {
        const cr = a.get_context();
        try {
            const [w, h] = a.get_surface_size();
            paint(cr, w, h);
        } finally {
            cr.$dispose();
        }
    });
    return a;
}

// Barras apiladas por día. days = [{segs: [{value, color}]}], escaladas contra maxVal (el día más
// alto del rango llena la altura). Columnas de ancho igual con 2 px de separación, como el RowLayout.
export function stackedBars(days, maxVal, width, height) {
    return area(width, height, (cr, w, h) => {
        const n = days.length;
        if (!n)
            return;
        const gap = 2;
        const colW = Math.max(1, (w - gap * (n - 1)) / n);
        days.forEach((day, i) => {
            const x = i * (colW + gap);
            let y = h;
            for (const s of day.segs) {
                const sh = h * (s.value / (maxVal || 1));
                if (sh <= 0)
                    continue;
                const [r, g, b] = rgb(s.color);
                cr.setSourceRGBA(r, g, b, 1);
                cr.rectangle(x, y - sh, colW, sh);
                cr.fill();
                y -= sh;
            }
        });
    });
}

// Heatmap: 7 filas (dom→sáb), columnas = semanas, flujo de arriba a abajo. Celda vacía = texto @8 %,
// con uso = acento con alfa 0.25 + 0.75·(tokens/máx). Si no caben todas las semanas en el ancho se
// muestran las MÁS RECIENTES (el QML desbordaba/recortaba a la derecha).
export function heatmap(cells, maxVal, width, {cell = 14, gap = 3, accent = '#e8884a', empty = [1, 1, 1, 0.08]} = {}) {
    const fitCols = Math.max(1, Math.floor((width + gap) / (cell + gap)));
    const cols = Math.ceil(cells.length / 7);
    const skip = Math.max(0, cols - fitCols) * 7;
    const shown = cells.slice(skip);
    const usedCols = Math.ceil(shown.length / 7);
    const w = Math.max(1, usedCols * (cell + gap) - gap);
    const h = 7 * (cell + gap) - gap;
    const [ar, ag, ab] = rgb(accent);
    return area(w, h, cr => {
        shown.forEach((c, i) => {
            const x = Math.floor(i / 7) * (cell + gap);
            const y = (i % 7) * (cell + gap);
            if (c.tokens <= 0)
                cr.setSourceRGBA(...empty);
            else
                cr.setSourceRGBA(ar, ag, ab, 0.25 + 0.75 * Math.min(1, c.tokens / (maxVal || 1)));
            roundRect(cr, x, y, cell, cell, 3);
            cr.fill();
        });
    });
}
