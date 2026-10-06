// Gráfica de barras apiladas por día y proyecto (pestaña Proyectos) — port de projChartArea de main.qml.
// Una columna por día; segmentos de mayor a menor tokens de ARRIBA hacia abajo (como el ColumnLayout
// anclado al fondo del QML); alto normalizado por maxDayProjectTokens del rango.
import St from 'gi://St';

function rgb(hex) {
    const n = parseInt(`${hex}`.slice(1), 16);
    return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
}

// days = rangedDays(...); colorOf(nombre) → '#rrggbb'; maxTok = maxDayProjectTokens(days).
export function stackedChart(days, colorOf, maxTok, width, height) {
    const area = new St.DrawingArea({x_expand: true});
    area.set_style(`width: ${width}px; height: ${height}px;`);
    // Segmentos precalculados: el repaint solo pinta.
    const cols = days.map(day => (day.projects || []).slice().sort((a, b) =>
        (b.tokens || 0) - (a.tokens || 0) || ((a.project || '') < (b.project || '') ? -1
            : (a.project || '') > (b.project || '') ? 1 : 0)));
    area.connect('repaint', a => {
        const cr = a.get_context();
        const [w, h] = a.get_surface_size();
        const n = cols.length;
        if (n > 0) {
            const gap = 2;
            const cw = Math.max(1, (w - gap * (n - 1)) / n);
            cols.forEach((segs, i) => {
                const x = i * (cw + gap);
                const total = segs.reduce((s, p) => s + (p.tokens || 0), 0);
                let y = h - h * (total / maxTok);
                for (const p of segs) {
                    const sh = h * ((p.tokens || 0) / maxTok);
                    const [r, g, b] = rgb(colorOf(p.project));
                    cr.setSourceRGBA(r, g, b, 1);
                    cr.rectangle(x, y, cw, sh);
                    cr.fill();
                    y += sh;
                }
            });
        }
        cr.$dispose();
    });
    return area;
}
