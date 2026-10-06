// Pestaña · Broker — port pendiente (fase F5 del plan, docs/propuestas/widget-gnome.md).
import * as W from '../lib/widgets.js';

export function build(_ctx) {
    const box = W.vbox('cortex-tab', {y_expand: true});
    box.add_child(W.heading('Broker'));
    box.add_child(W.label('Pendiente de portar del plasmoide (fase F5).', 'opacity: 0.6;'));
    return box;
}
