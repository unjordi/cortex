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

const PILL_ON = `background-color: ${F.withAlpha(F.ACCENT, 0.22)}; color: ${F.ACCENT}; font-weight: bold;`;

// Píldoras {hoy · 7d · 30d · ∞} al pie de Resumen/Modelos/Proyectos/Chats. La activa va en acento.
// machineToggle: agrega a la derecha el par 🖥 esta máquina / ☁️ todas (solo si stats-global.json trae
// máquinas) — Resumen/Modelos/Proyectos, NO Chats, como el RangeFooter del plasmoide.
export function rangePills(ctx, {machineToggle = false} = {}) {
    const g = ctx.statsGlobal;
    const hasGlobal = machineToggle && g && g.machines && g.machines.length > 0;
    const row = hbox('cortex-range', {
        x_align: hasGlobal ? Clutter.ActorAlign.FILL : Clutter.ActorAlign.START, x_expand: hasGlobal});
    RANGES.forEach((r, i) => {
        const b = new St.Button({label: r, style_class: 'cortex-pill', can_focus: true});
        if (i === ctx.rangeIdx)
            b.set_style(PILL_ON);
        b.connect('clicked', () => ctx.setRange(i));
        row.add_child(b);
    });
    if (hasGlobal) {
        row.add_child(new St.Widget({x_expand: true}));
        const n = g.machines.length;
        [[false, '🖥'], [true, `☁️${n > 1 ? ` ${n}` : ''}`]].forEach(([global, text]) => {
            const b = new St.Button({label: text, style_class: 'cortex-pill', can_focus: true});
            if (!!ctx.useGlobal === global)
                b.set_style(PILL_ON);
            b.accessible_name = global ? 'Uso combinado de todas tus máquinas (sync)' : 'Solo esta máquina';
            b.connect('clicked', () => ctx.setUseGlobal(global));
            row.add_child(b);
        });
    }
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
