// Cortex — widget de GNOME Shell. Port del plasmoide de KDE (src/plasmoid/), plan en
// docs/propuestas/widget-gnome.md. Vista pura: lee ~/.cache/cortex/*.json que publica el daemon.
import GObject from 'gi://GObject';
import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

import * as F from './lib/fmt.js';
import * as D from './lib/data.js';
import * as Limites from './tabs/limites.js';

const H = Clutter.Orientation.HORIZONTAL;
const V = Clutter.Orientation.VERTICAL;

// Mismo orden/rótulos que el riel del plasmoide. `fase` = pestañas aún no portadas (placeholder).
const TABS = [
    {label: 'Límites', glyph: '⏱', mod: Limites},
    {label: 'Resumen', glyph: '📊', fase: 'F2'},
    {label: 'Modelos', glyph: '📈', fase: 'F2'},
    {label: 'Proyectos', glyph: '📁', fase: 'F3'},
    {label: 'Chats', glyph: '💬', fase: 'F3'},
    {label: 'Cerebro', glyph: '🧠', fase: 'F4'},
    {label: 'Broker', glyph: '🔌', fase: 'F5'},
];

const POPUP_W = 560;
const POPUP_H = 440;
const RAIL_W = 130;

function placeholder(tab) {
    const box = new St.BoxLayout({orientation: V, style_class: 'cortex-tab', y_expand: true});
    const t = new St.Label({text: tab.label});
    t.set_style('font-weight: bold; font-size: larger;');
    box.add_child(t);
    const l = new St.Label({text: `Pendiente de portar del plasmoide (fase ${tab.fase}).`});
    l.set_style('opacity: 0.6;');
    box.add_child(l);
    return box;
}

const CortexIndicator = GObject.registerClass(
class CortexIndicator extends PanelMenu.Button {
    _init(extension) {
        super._init(0.5, 'Cortex', false);
        this._ext = extension;
        this._snapshot = null;
        this._snapshotError = '';
        this._tab = 0;
        this._paused = false;
        this._lastResetRefresh = 0;

        this._compact = new St.BoxLayout({orientation: V, y_align: Clutter.ActorAlign.CENTER,
            style_class: 'cortex-compact'});
        this.add_child(this._compact);

        // Un solo item no-reactivo hospeda todo el popup (riel + contenido).
        const item = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
        item.add_style_class_name('cortex-popup-item');
        this._root = new St.BoxLayout({orientation: H});
        this._root.set_style(`width: ${POPUP_W}px; height: ${POPUP_H}px;`);
        item.add_child(this._root);
        this.menu.addMenuItem(item);
        this.menu.connect('open-state-changed', (_m, open) => {
            if (open)
                this.refresh();
        });

        this._watch();
        this.refresh();
        // Tick de 10 s como el Timer del plasmoide: relee el caché y adelanta el fetch si un reset ya pasó.
        this._tick = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 10, () => {
            this.refresh();
            this._maybeRefreshOnReset();
            return GLib.SOURCE_CONTINUE;
        });
    }

    // cortex-fetch escribe con tmp+rename → se vigila el DIRECTORIO (vigilar el archivo pierde el inodo).
    _watch() {
        try {
            this._monitor = Gio.File.new_for_path(D.CACHE_DIR)
                .monitor_directory(Gio.FileMonitorFlags.NONE, null);
            this._monitorId = this._monitor.connect('changed', () => {
                if (this._debounce)
                    GLib.Source.remove(this._debounce);
                this._debounce = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 250, () => {
                    this._debounce = null;
                    this.refresh();
                    return GLib.SOURCE_REMOVE;
                });
            });
        } catch (e) {
            logError(e, 'cortex: no se pudo vigilar el caché');
        }
    }

    // Anti-"% pegado": reset ya pasado + snapshot >60 s → adelanta el fetch (máx 1/min).
    _maybeRefreshOnReset() {
        const s = this._snapshot;
        if (!s || !s.updated_at)
            return;
        const passed = (s.five_hour && F.isPast(s.five_hour.resets_at)) ||
            (s.weekly && F.isPast(s.weekly.resets_at));
        const age = (Date.now() - Date.parse(s.updated_at)) / 1000;
        if (passed && age > 60 && Date.now() - this._lastResetRefresh > 60000) {
            this._lastResetRefresh = Date.now();
            D.forceRefresh();
        }
    }

    refresh() {
        this._snapshot = D.readJson('state.json');
        this._snapshotError = this._snapshot ? (this._snapshot.error || '') : 'state.json ilegible';
        this._renderCompact();
        if (this.menu.isOpen)
            this._renderPopup();
    }

    // Indicador de 2 filas 5h / 7d con mini-barra + % + ⟳reset (como la compactRepresentation).
    _renderCompact() {
        this._compact.destroy_all_children();
        const s = this._snapshot;
        const rows = [
            ['5h', s && s.five_hour ? s.five_hour : null],
            ['7d', s && s.weekly ? s.weekly : null],
        ];
        for (const [name, blk] of rows) {
            const pct = blk && blk.percent !== undefined ? blk.percent : -1;
            const r = new St.BoxLayout({orientation: H, style_class: 'cortex-compact-row'});
            const n = new St.Label({text: name, style_class: 'cortex-compact-key'});
            r.add_child(n);
            if (pct >= 0)
                r.add_child(Limites.bar(pct, 28));
            const p = new St.Label({text: pct >= 0 ? `${Math.round(pct)}%` : (this._snapshotError ? '!' : '…'),
                style_class: 'cortex-compact-pct'});
            p.set_style(`color: ${F.pctColor(pct)};`);
            r.add_child(p);
            if (blk && blk.resets_at)
                r.add_child(new St.Label({text: `⟳${F.compactReset(blk.resets_at)}`, style_class: 'cortex-compact-reset'}));
            this._compact.add_child(r);
        }
    }

    _railButton(i) {
        const tab = TABS[i];
        const btn = new St.Button({style_class: 'cortex-rail-btn', x_expand: true, can_focus: true});
        if (i === this._tab)
            btn.add_style_pseudo_class('checked');
        const b = new St.BoxLayout({orientation: H});
        b.add_child(new St.Label({text: tab.glyph, style_class: 'cortex-rail-glyph'}));
        b.add_child(new St.Label({text: tab.label, y_align: Clutter.ActorAlign.CENTER}));
        btn.set_child(b);
        btn.connect('clicked', () => {
            this._tab = i;
            this._renderPopup();
        });
        return btn;
    }

    _footButton(glyph, tip, onClick) {
        const btn = new St.Button({style_class: 'cortex-foot-btn', label: glyph, can_focus: true});
        btn.accessible_name = tip;
        btn.connect('clicked', onClick);
        return btn;
    }

    _renderPopup() {
        this._root.destroy_all_children();

        const rail = new St.BoxLayout({orientation: V, style_class: 'cortex-rail'});
        rail.set_style(`width: ${RAIL_W}px;`);
        TABS.forEach((_t, i) => rail.add_child(this._railButton(i)));
        rail.add_child(new St.Widget({y_expand: true}));
        const foot = new St.BoxLayout({orientation: H, x_align: Clutter.ActorAlign.CENTER});
        foot.add_child(this._footButton('↻', 'Refrescar ahora', () => D.forceRefresh()));
        foot.add_child(this._footButton(this._paused ? '⏵' : '⏸',
            this._paused ? 'Reanudar la actualización automática' : 'Pausar la actualización automática',
            () => {
                if (this._paused)
                    D.resumeCollection();
                else
                    D.pauseCollection();
                this._paused = !this._paused;
                this._renderPopup();
            }));
        rail.add_child(foot);
        this._root.add_child(rail);

        this._root.add_child(new St.Widget({style_class: 'cortex-divider'}));

        const tab = TABS[this._tab];
        const ctx = {
            snapshot: this._snapshot,
            snapshotError: this._snapshotError,
            contentWidth: POPUP_W - RAIL_W - 48,
        };
        let content;
        try {
            content = tab.mod ? tab.mod.build(ctx) : placeholder(tab);
        } catch (e) {
            logError(e, `cortex: falló la pestaña ${tab.label}`);
            content = new St.Label({text: `Error en ${tab.label}: ${e.message}`});
        }
        const scroll = new St.ScrollView({x_expand: true, y_expand: true, style_class: 'cortex-content'});
        scroll.set_child(content);
        this._root.add_child(scroll);
    }

    destroy() {
        if (this._tick) {
            GLib.Source.remove(this._tick);
            this._tick = null;
        }
        if (this._debounce) {
            GLib.Source.remove(this._debounce);
            this._debounce = null;
        }
        if (this._monitor) {
            if (this._monitorId)
                this._monitor.disconnect(this._monitorId);
            this._monitor.cancel();
            this._monitor = null;
        }
        super.destroy();
    }
});

export default class CortexExtension extends Extension {
    enable() {
        this._indicator = new CortexIndicator(this);
        Main.panel.addToStatusArea(this.uuid, this._indicator);
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}
