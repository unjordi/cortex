// Pestaña · Herramientas — inventario de lo que Claude Code tiene DISPONIBLE para usar en esta máquina:
// agentes (built-in del runtime + los propios de ~/.claude/agents) y skills (~/.claude/skills). Vista
// pura: lee ~/.cache/cortex/inventario.json que publica el daemon (cortex-fetch). Cada fila se despliega
// al tocarla para ver la descripción completa (una abierta a la vez, como la pestaña Cerebro).
import St from 'gi://St';
import Clutter from 'gi://Clutter';
import Pango from 'gi://Pango';

import * as F from '../lib/fmt.js';
import * as W from '../lib/widgets.js';

const SMALL = 'font-size: 0.85em;';
const HOVER_BG = 'background-color: rgba(255, 255, 255, 0.08);';

// W.label que ENVUELVE el texto largo en vez de cortarlo con "…".
function lbl(text, style = '', opts = {}) {
    const l = W.label(text, style, opts);
    if (opts.wrap !== false) {
        l.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        l.clutter_text.line_wrap_mode = Pango.WrapMode.WORD_CHAR;
    }
    return l;
}

// Fila de una pieza: ● nombre · ▸/▾, y debajo (si está abierta) la descripción completa. Colapsada
// muestra la descripción recortada a una línea. Una sola abierta a la vez (ctx.state.expanded).
function itemRow(ctx, it, key, color) {
    const s = ctx.state;
    const open = s.expanded === key;
    const col = W.vbox('', {x_expand: true, style: 'spacing: 1px;'});

    const head = W.hbox('', {x_expand: true, style: 'spacing: 6px;'});
    head.add_child(lbl('●', `color: ${color}; opacity: 0.6; ${SMALL}`, {wrap: false}));
    head.add_child(lbl(it.name, 'font-family: monospace; font-weight: bold;', {expand: true, wrap: false}));
    head.add_child(lbl(open ? '▾' : '▸', `opacity: 0.35; ${SMALL}`, {wrap: false}));

    const headBtn = new St.Button({child: head, x_expand: true, can_focus: true, track_hover: true, reactive: true});
    const base = 'border-radius: 6px; padding: 3px 4px;';
    headBtn.set_style(base);
    headBtn.connect('notify::hover', () => headBtn.set_style(headBtn.hover ? base + HOVER_BG : base));
    headBtn.connect('clicked', () => {
        s.expanded = open ? '' : key;
        ctx.rerender();
    });
    col.add_child(headBtn);

    // Descripción: completa (envuelta) abierta; recortada a una línea cerrada.
    const desc = new St.Label({text: `${it.desc || '(sin descripción)'}`, x_expand: true});
    desc.set_style(`opacity: 0.62; ${SMALL} padding-left: 18px; padding-right: 4px;`);
    if (open) {
        desc.clutter_text.line_wrap = true;
        desc.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
    } else {
        desc.clutter_text.ellipsize = Pango.EllipsizeMode.END;
    }
    col.add_child(desc);
    return col;
}

// Un bloque (Agentes / Skills): espina de color + encabezado (emoji · TÍTULO · conteo) + subtítulo + filas.
function section(ctx, emoji, title, subtitle, color, items, keyPrefix) {
    const row = W.hbox('', {x_expand: true, style: 'spacing: 8px;'});
    const spine = new St.Widget({y_expand: true});
    spine.set_style(`width: 3px; border-radius: 1px; background-color: ${color};`);
    row.add_child(spine);

    const col = W.vbox('', {x_expand: true, style: 'spacing: 4px;'});
    const h = W.hbox('', {x_expand: true, style: 'spacing: 6px;'});
    h.add_child(lbl(emoji, 'font-size: 1.1em;', {wrap: false}));
    h.add_child(lbl(title, `font-weight: bold; color: ${color};`, {expand: true, wrap: false}));
    h.add_child(lbl(`${items.length}`, `font-weight: bold; color: ${color}; ` +
        `background-color: ${F.withAlpha(color, 0.15)}; border-radius: 8px; padding: 0 8px;`, {wrap: false}));
    col.add_child(h);
    if (subtitle)
        col.add_child(lbl(subtitle, `opacity: 0.6; ${SMALL}`));
    if (items.length === 0)
        col.add_child(lbl('(ninguno)', `opacity: 0.5; ${SMALL}`));
    items.forEach((it, i) => col.add_child(itemRow(ctx, it, `${keyPrefix}-${i}`, color)));
    row.add_child(col);
    return row;
}

export function build(ctx) {
    const box = W.vbox('cortex-tab', {x_expand: true});
    box.set_style(`width: ${ctx.contentWidth}px; spacing: 12px;`);
    box.add_child(W.heading('Herramientas disponibles'));

    const inv = ctx.inventario;
    if (!inv) {
        box.add_child(lbl('Aún no hay inventario. Lo publica el daemon (cortex-fetch) en su próxima pasada; ' +
            'pulsa ↻ abajo para forzarlo.', `opacity: 0.6; ${SMALL}`));
        return box;
    }

    box.add_child(lbl('Lo que Claude Code puede usar en esta máquina. Toca una pieza para ver qué hace.',
        `opacity: 0.6; ${SMALL}`));

    const agents = inv.agents || {};
    const builtin = agents.builtin || [];
    const custom = agents.custom || [];
    const skills = inv.skills || [];

    box.add_child(section(ctx, '🤖', 'Agentes', 'trabajadores que Claude puede delegar en paralelo',
        F.ACCENT, builtin, 'ab'));
    if (custom.length > 0) {
        box.add_child(section(ctx, '🛠', 'Agentes propios', 'definidos por ti en ~/.claude/agents',
            F.ACCENT, custom, 'ac'));
    }
    box.add_child(section(ctx, '🧩', 'Skills', 'habilidades bajo demanda en ~/.claude/skills (globales, en toda máquina)',
        '#4a90d9', skills, 'sk'));

    if (inv.updated_at)
        box.add_child(lbl(`Leído del disco por el daemon · ${F.relDate ? F.relDate(inv.updated_at) : inv.updated_at}`,
            'opacity: 0.4; font-size: 0.78em;'));
    return box;
}
