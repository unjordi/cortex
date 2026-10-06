// Pestaña · Proyectos — port pendiente (fase F3 del plan, docs/propuestas/widget-gnome.md).
import * as W from '../lib/widgets.js';

export function build(_ctx) {
    const box = W.vbox('cortex-tab', {y_expand: true});
    box.add_child(W.heading('Proyectos'));
    box.add_child(W.label('Pendiente de portar del plasmoide (fase F3).', 'opacity: 0.6;'));
    return box;
}
