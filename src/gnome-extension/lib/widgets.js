// Piezas de UI compartidas entre pestañas.
import St from 'gi://St';
import Clutter from 'gi://Clutter';

import * as F from './fmt.js';
import {RANGES} from './stats.js';

export const H = Clutter.Orientation.HORIZONTAL;
export const V = Clutter.Orientation.VERTICAL;

export function label(text, style = '', {expand = false, wrap = true} = {}) {
    const l = new St.Label({text: `${text}`, x_expand: expand, y_align: Clutter.ActorAlign.CENTER});
    if (style)
        l.set_style(style);
    if (wrap)
        l.clutter_text.line_wrap = true;
    return l;
}

export function heading(text) {
    return label(text, 'font-weight: bold; font-size: larger;');
}

export function vbox(styleClass = '', props = {}) {
    return new St.BoxLayout({orientation: V, style_class: styleClass, ...props});
}

export function hbox(styleClass = '', props = {}) {
    return new St.BoxLayout({orientation: H, style_class: styleClass, ...props});
}

// Píldoras {hoy · 7d · 30d · ∞} al pie de Resumen/Modelos/Proyectos/Chats. La activa va en acento.
export function rangePills(ctx) {
    const row = hbox('cortex-range', {x_align: Clutter.ActorAlign.START});
    RANGES.forEach((r, i) => {
        const b = new St.Button({label: r, style_class: 'cortex-pill', can_focus: true});
        if (i === ctx.rangeIdx)
            b.set_style(`background-color: ${F.ACCENT}; color: #1e1e1e; font-weight: bold;`);
        b.connect('clicked', () => ctx.setRange(i));
        row.add_child(b);
    });
    return row;
}

// Botón de texto pequeño (acciones dentro de una pestaña).
export function button(text, onClick, {tip = ''} = {}) {
    const b = new St.Button({label: text, style_class: 'cortex-btn', can_focus: true});
    if (tip)
        b.accessible_name = tip;
    b.connect('clicked', onClick);
    return b;
}
