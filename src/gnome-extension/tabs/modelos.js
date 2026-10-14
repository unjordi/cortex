// Pestaña 2 · Modelos — port de "Tab 2" de main.qml: barras apiladas por día (rango) + tabla por modelo.
import St from 'gi://St';
import Clutter from 'gi://Clutter';

import * as F from '../lib/fmt.js';
import * as S from '../lib/stats.js';
import * as W from '../lib/widgets.js';
import * as C from '../lib/charts.js';

const CHART_H = 126;   // ≈ gridUnit·7 del QML

// tokens desc + desempate por nombre: el apilado NO depende de la fuente (local por tokens; merge
// global alfabético) → el toggle 🖥/☁️ se ve consistente. Igual que el Repeater del QML.
function byTokensThenName(a, b) {
    const n = (b.tokens || 0) - (a.tokens || 0);
    if (n)
        return n;
    const x = a.model || '', y = b.model || '';
    return x < y ? -1 : x > y ? 1 : 0;
}

function modelRow(m, color) {
    const row = W.hbox('', {});
    row.set_style('spacing: 6px;');
    const sw = new St.Widget({y_align: Clutter.ActorAlign.CENTER});
    sw.set_style(`width: 10px; height: 10px; border-radius: 2px; background-color: ${color};`);
    row.add_child(sw);
    row.add_child(W.label(F.prettyModel(m.model), 'font-weight: bold;', {wrap: false}));
    row.add_child(new St.Widget({x_expand: true}));
    row.add_child(W.label(`${F.fmtTok(m.in_tok)} in · ${F.fmtTok(m.out_tok)} out`, 'opacity: 0.7;', {wrap: false}));
    const pct = W.label(`${m.pct.toFixed(1)}%`, `font-weight: bold; color: ${color}; min-width: 46px; text-align: right;`, {wrap: false});
    row.add_child(pct);
    return row;
}

export function build(ctx) {
    const src = ctx.activeStats || ctx.stats;
    const days = S.rangedDays(src, ctx.rangeIdx);
    const models = S.aggBy(days, 'models', 'model');
    // Colores por índice en la lista LOCAL (modelColorFor del QML lee root.stats).
    const color = name => F.colorFor(ctx.stats ? ctx.stats.models : null, 'model', name);

    const box = W.vbox('cortex-tab', {y_expand: true});
    box.add_child(W.heading('Uso por modelo'));

    if (days.length) {
        const bars = days.map(d => ({
            segs: (d.models || []).slice().sort(byTokensThenName)
                .map(m => ({value: m.tokens || 0, color: color(m.model)})),
        }));
        box.add_child(C.stackedBars(bars, S.maxDayTokens(days), ctx.contentWidth, CHART_H));
    } else {
        box.add_child(W.label('Sin uso en este rango.', 'opacity: 0.5;'));
    }

    const table = W.vbox('', {});
    table.set_style('spacing: 4px;');
    for (const m of models)
        table.add_child(modelRow(m, color(m.model)));
    box.add_child(table);

    box.add_child(new St.Widget({y_expand: true}));
    box.add_child(W.rangePills(ctx, {machineToggle: true}));
    return box;
}
