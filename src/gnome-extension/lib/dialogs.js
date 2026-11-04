// Diálogos modales de la pestaña Proyectos (renombrar / mover / aviso) — equivalentes a los
// Kirigami.PromptDialog renameDialog / moveDialog / moveErrorDialog de main.qml.
// Se abren con el popup YA cerrado (ctx.closeMenu()): un ModalDialog encima del grab del menú no recibe foco.
import St from 'gi://St';
import Clutter from 'gi://Clutter';

import * as ModalDialog from 'resource:///org/gnome/shell/ui/modalDialog.js';
import * as Dialog from 'resource:///org/gnome/shell/ui/dialog.js';

const SMALL = 'font-size: smaller;';

function newDialog(title, description) {
    const d = new ModalDialog.ModalDialog({destroyOnClose: true});
    d.contentLayout.add_child(new Dialog.MessageDialogContent({title, description}));
    return d;
}

function note(text, style) {
    const l = new St.Label({text, x_expand: true});
    l.clutter_text.line_wrap = true;
    l.set_style(style);
    return l;
}

// kind 'project' | 'session'. onSave(texto) — texto vacío = restaurar. onSuggest() → Promise<string|null>
// (solo sesión: "Sugerir nombre" con `claude -p`, cuesta tokens; el resultado cae al campo, NO guarda).
export function openRename({kind, seed, summary = '', aliased = false, onSave, onSuggest = null}) {
    const isSess = kind === 'session';
    const d = newDialog(isSess ? 'Renombrar sesión' : 'Renombrar proyecto',
        isSess ? 'Nueva etiqueta para esta sesión. Vacío para restaurar la original.'
            : 'Nuevo nombre para este proyecto. Vacío para restaurar el original.');
    const body = new St.BoxLayout({orientation: Clutter.Orientation.VERTICAL, x_expand: true});
    body.set_style('spacing: 8px; min-width: 360px;');

    if (isSess && summary)
        body.add_child(note(summary, `${SMALL} opacity: 0.7;`));

    const entry = new St.Entry({text: seed || '', can_focus: true, x_expand: true,
        style_class: 'run-dialog-entry'});
    body.add_child(entry);

    const save = text => {
        d.close();
        onSave(text);
    };
    entry.clutter_text.connect('activate', () => save(entry.get_text()));

    if (isSess) {
        const row = new St.BoxLayout({x_expand: true});
        row.set_style('spacing: 8px;');
        const btn = new St.Button({label: 'Sugerir nombre', style_class: 'button', can_focus: true,
            reactive: summary !== ''});
        const status = note(summary === '' ? 'sin contexto para sugerir' : 'propone un nombre con IA · cuesta tokens',
            `${SMALL} opacity: 0.6;`);
        status.y_align = Clutter.ActorAlign.CENTER;
        btn.connect('clicked', async () => {
            if (!onSuggest || summary === '')
                return;
            btn.reactive = false;
            btn.label = 'generando…';
            status.text = 'generando… (cuesta tokens)';
            status.set_style(`${SMALL} opacity: 0.6;`);
            const name = await onSuggest();
            if (!btn.get_stage())   // el diálogo ya se cerró
                return;
            btn.reactive = true;
            btn.label = 'Sugerir nombre';
            if (name) {
                entry.set_text(name);
                status.text = 'propone un nombre con IA · cuesta tokens';
            } else {
                status.text = 'no se pudo generar (¿claude en el PATH?)';
                status.set_style(`${SMALL} color: #dc3545;`);
            }
        });
        row.add_child(btn);
        row.add_child(status);
        body.add_child(row);
    }
    d.contentLayout.add_child(body);

    const buttons = [{label: 'Cancelar', action: () => d.close(), key: Clutter.KEY_Escape}];
    if (aliased)
        buttons.push({label: 'Restaurar original', action: () => save('')});
    buttons.push({label: 'Guardar', action: () => save(entry.get_text()), default: true});
    d.setButtons(buttons);
    d.setInitialKeyFocus(entry);
    d.open();
    entry.clutter_text.set_selection(0, entry.get_text().length);
    return d;
}

export function openMove({label, targetName, onMove}) {
    const d = newDialog('Mover sesión', 'Reubica el transcript de esta sesión a otro proyecto.');
    d.contentLayout.add_child(note(`«${label || '(sesión)'}» se moverá a «${targetName}».\n` +
        'Se reescribe el cwd interno del transcript y se respalda el original (reversible).', 'max-width: 420px;'));
    d.setButtons([
        {label: 'Cancelar', action: () => d.close(), key: Clutter.KEY_Escape},
        {label: 'Mover', action: () => {
            d.close();
            onMove();
        }, default: true},
    ]);
    d.open();
    return d;
}

export function openMessage(title, text) {
    const d = newDialog(title, text);
    d.setButtons([{label: 'OK', action: () => d.close(), key: Clutter.KEY_Escape, default: true}]);
    d.open();
    return d;
}
