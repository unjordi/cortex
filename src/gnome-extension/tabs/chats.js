// Pestaña 4 · Chats — port de "Tab 4: Chats" de main.qml. Conversaciones recientes del app de
// escritorio (chats.json), READ-ONLY: desglose por modelo + 20 recientes + pie con el resumen del chat
// bajo el cursor. El riel solo muestra esta pestaña si hay chats (visible() en extension.js).
import St from 'gi://St';
import Clutter from 'gi://Clutter';
import Pango from 'gi://Pango';

import * as F from '../lib/fmt.js';
import * as S from '../lib/stats.js';
import * as W from '../lib/widgets.js';

const SMALL = 'font-size: smaller;';
// Alto de la lista de recientes con 0 modelos; cada fila del desglose le resta ~27 px (popup de 440).
const LIST_BUDGET = 240;
const HINT = 'Pasa el cursor sobre un chat para ver su resumen.';

function lbl(text, style = '', {expand = false, ellipsize = false} = {}) {
    const l = new St.Label({text: `${text}`, x_expand: expand, y_align: Clutter.ActorAlign.CENTER});
    if (ellipsize)
        l.clutter_text.ellipsize = Pango.EllipsizeMode.END;
    if (style)
        l.set_style(style);
    return l;
}

function separator() {
    const s = new St.Widget({x_expand: true});
    s.set_style('height: 1px; background-color: rgba(255, 255, 255, 0.12);');
    return s;
}

export function build(ctx) {
    const chats = S.rangedChats(ctx.chats, ctx.rangeIdx);
    const modelColor = m => F.colorFor(ctx.stats && ctx.stats.models, 'model', m);

    const box = W.vbox('cortex-tab', {y_expand: true});
    box.add_child(W.heading('Chats'));

    if (!chats.length) {
        box.add_child(W.label(ctx.rangeIdx === 3
            ? 'Sin conversaciones locales.\nAbre el app de escritorio de Claude y espera al próximo refresco.'
            : 'Sin conversaciones en este rango.', `${SMALL} opacity: 0.6;`));
        box.add_child(new St.Widget({y_expand: true}));
        box.add_child(W.rangePills(ctx));
        return box;
    }

    // Desglose por modelo (swatch + modelo + conteo + %).
    const byModel = W.vbox('', {x_expand: true});
    byModel.set_style('spacing: 4px;');
    for (const m of S.chatsByModel(chats)) {
        const row = W.hbox('', {x_expand: true});
        row.set_style('spacing: 6px;');
        const sw = new St.Widget({y_align: Clutter.ActorAlign.CENTER});
        sw.set_style(`width: 10px; height: 10px; border-radius: 2px; background-color: ${modelColor(m.model)};`);
        row.add_child(sw);
        row.add_child(lbl(F.prettyModel(m.model), 'font-weight: bold;'));
        row.add_child(new St.Widget({x_expand: true}));
        row.add_child(lbl(`${m.count}`, 'opacity: 0.7;'));
        row.add_child(lbl(`${m.pct.toFixed(0)}%`,
            `font-weight: bold; color: ${modelColor(m.model)}; min-width: 45px; text-align: right;`));
        byModel.add_child(row);
    }
    box.add_child(byModel);

    // Recientes: el pie se actualiza EN SITIO al pasar el cursor (sin re-render, que destruiría la fila).
    const list = W.vbox('', {x_expand: true});
    list.set_style('spacing: 4px;');
    list.add_child(separator());
    list.add_child(lbl('recientes', `${SMALL} opacity: 0.5;`));
    const foot = W.label(HINT, `${SMALL} opacity: 0.4; min-height: 3.6em;`);
    const rows = W.vbox('', {x_expand: true});
    rows.set_style('spacing: 4px; padding-right: 10px;');

    for (const c of chats.slice(0, 20)) {
        const row = W.hbox('', {x_expand: true, reactive: true, track_hover: true});
        row.set_style('spacing: 6px;');
        row.add_child(lbl(c.title ? c.title : '(sin título)', '', {expand: true, ellipsize: true}));
        if (c.model) {
            const badge = lbl(F.prettyModel(c.model),
                `color: ${modelColor(c.model)}; background-color: ${F.withAlpha(modelColor(c.model), 0.22)};` +
                ' font-weight: bold; font-size: 0.8em; border-radius: 999px; padding: 1px 6px;');
            row.add_child(badge);
        }
        row.add_child(lbl(F.relDate(c.updated_at ? c.updated_at : c.created_at),
            `${SMALL} opacity: 0.6; min-width: 54px; text-align: right;`));
        row.connect('notify::hover', () => {
            const sum = row.hover && c.summary ? `${c.summary}`.slice(0, 300) : '';
            foot.text = sum === '' ? HINT : sum;
            foot.set_style(`${SMALL} opacity: ${sum === '' ? 0.4 : 0.75}; min-height: 3.6em;`);
        });
        rows.add_child(row);
    }
    // Scroll PROPIO para la lista (como el PC3.ScrollView del QML): así el pie de resumen queda visible
    // mientras recorres los chats. Alto = lo que sobra del popup tras el desglose por modelo.
    const scroll = new St.ScrollView({x_expand: true, hscrollbar_policy: St.PolicyType.NEVER});
    scroll.set_style(`height: ${Math.max(96, LIST_BUDGET - byModel.get_n_children() * 27)}px;`);
    scroll.set_child(rows);
    list.add_child(scroll);
    box.add_child(list);

    const footBox = W.vbox('', {x_expand: true});
    footBox.set_style('spacing: 4px;');
    footBox.add_child(separator());
    footBox.add_child(foot);
    box.add_child(footBox);
    box.add_child(W.rangePills(ctx));
    return box;
}
