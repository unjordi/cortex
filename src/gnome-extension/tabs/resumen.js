// Pestaña 1 · Resumen — port de "Tab 1" + StatCard de main.qml (y resumenTab de PopoverView.swift).
// Tarjetas recalculadas sobre los días del rango (fuente activa: local o ☁️ todas); Racha, Hora pico y
// el heatmap se quedan all-time y LOCALES, igual que el plasmoide.
import St from 'gi://St';
import Pango from 'gi://Pango';

import * as F from '../lib/fmt.js';
import * as S from '../lib/stats.js';
import * as W from '../lib/widgets.js';
import * as C from '../lib/charts.js';

const GAP = 6;

function statCard(label, value, width) {
    const card = W.vbox('', {});
    card.set_style(`width: ${width}px; padding: 6px 8px; border-radius: 6px; ` +
        'background-color: rgba(255, 255, 255, 0.06);');
    const l = W.label(label, 'font-size: smaller; opacity: 0.6;', {wrap: false});
    const v = W.label(value, 'font-weight: bold; font-size: 1.1em;', {wrap: false});
    for (const x of [l, v])
        x.clutter_text.ellipsize = Pango.EllipsizeMode.END;
    card.add_child(l);
    card.add_child(v);
    return card;
}

export function build(ctx) {
    const st = ctx.stats;                       // local: sesiones ∞, hora pico, rachas, heatmap
    const src = ctx.activeStats || ctx.stats;   // recortes por rango
    const days = S.rangedDays(src, ctx.rangeIdx);
    const models = S.aggBy(days, 'models', 'model');
    const activeDays = days.filter(d => (d.tokens || 0) > 0).length;
    const {cur, max} = S.streaks(st);
    const dash = v => (st ? v : '—');

    const sessions = ctx.rangeIdx === 3
        ? (st && st.summary ? F.fmtInt(st.summary.sessions) : '—')
        : `${S.rangedSessionCount(ctx.sessions, ctx.rangeIdx)}`;

    const cards = [
        ['Sesiones', dash(sessions)],
        ['Mensajes', dash(F.fmtInt(S.sum(days, 'messages')))],
        ['Tokens totales', dash(F.fmtTok(S.sum(days, 'tokens')))],
        ['Días activos', dash(`${activeDays}`)],
        ['Racha actual', `${cur}d`],
        ['Racha más larga', `${max}d`],
        ['Hora pico', st && st.summary ? F.fmtHour(st.summary.peak_hour) : '—'],
        ['Modelo favorito', dash(models.length ? F.prettyModel(models[0].model) : '—')],
        ['Costo API-equiv', dash(`$${S.sum(days, 'cost').toFixed(0)}`)],
    ];

    const box = W.vbox('cortex-tab', {y_expand: true});
    box.add_child(W.heading('Resumen'));

    // `width` de St no incluye el padding (8 px por lado) → se descuenta para que las 3 quepan.
    const cw = Math.floor((ctx.contentWidth - 2 * GAP) / 3) - 16;
    const grid = W.vbox('', {});
    grid.set_style(`spacing: ${GAP}px;`);
    for (let r = 0; r < cards.length; r += 3) {
        const row = W.hbox('', {});
        row.set_style(`spacing: ${GAP}px;`);
        for (const [l, v] of cards.slice(r, r + 3))
            row.add_child(statCard(l, v, cw));
        grid.add_child(row);
    }
    box.add_child(grid);

    const heat = W.vbox('', {});
    heat.set_style('spacing: 6px;');
    heat.add_child(W.label('Actividad diaria (local)', 'font-size: smaller; opacity: 0.6;'));
    const cells = S.heatmapCells(st);
    if (cells.length)
        heat.add_child(C.heatmap(cells, S.maxDayTokens(st ? st.days : []), ctx.contentWidth, {accent: F.ACCENT}));
    else
        heat.add_child(W.label('Sin actividad registrada aún.', 'font-size: smaller; opacity: 0.5;'));
    box.add_child(heat);

    box.add_child(new St.Widget({y_expand: true}));
    // El heatmap se queda all-time; el pie solo recorta las tarjetas.
    box.add_child(W.rangePills(ctx, {machineToggle: true}));
    return box;
}
