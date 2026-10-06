// Pestaña · Cerebro — port pendiente (fase F4 del plan, docs/propuestas/widget-gnome.md).
import * as W from '../lib/widgets.js';

export function build(_ctx) {
    const box = W.vbox('cortex-tab', {y_expand: true});
    box.add_child(W.heading('Cerebro'));
    box.add_child(W.label('Pendiente de portar del plasmoide (fase F4).', 'opacity: 0.6;'));
    return box;
}
