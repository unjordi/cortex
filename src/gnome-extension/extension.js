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
import * as Resumen from './tabs/resumen.js';
import * as Modelos from './tabs/modelos.js';
import * as Proyectos from './tabs/proyectos.js';
import * as Chats from './tabs/chats.js';
import * as Cerebro from './tabs/cerebro.js';
import * as Broker from './tabs/broker.js';

const H = Clutter.Orientation.HORIZONTAL;
const V = Clutter.Orientation.VERTICAL;

// Mismo orden/rótulos que el riel del plasmoide. Cada módulo exporta build(ctx) → actor; opcionales:
// onShow(ctx) (al entrar a la pestaña: escaneos caros, como el onCurrentTabChanged del QML) y
// railBadge(ctx) → string ('⬆', '🩹', '' ) para el pie del riel / el indicador del panel.
// `visible(ctx)` oculta la pestaña (Chats solo si hay chats, como el riel del plasmoide).
const TABS = [
    {label: 'Límites', glyph: '⏱', mod: Limites},
    {label: 'Resumen', glyph: '📊', mod: Resumen},
    {label: 'Modelos', glyph: '📈', mod: Modelos},
    {label: 'Proyectos', glyph: '📁', mod: Proyectos},
    {label: 'Chats', glyph: '💬', mod: Chats, visible: ctx => ctx.chats && ctx.chats.length > 0},
    {label: 'Cerebro', glyph: '🧠', mod: Cerebro},
    {label: 'Broker', glyph: '🔌', mod: Broker},
];

const POPUP_W = 560;
const POPUP_H = 440;
const RAIL_W = 130;

const CortexIndicator = GObject.registerClass(
class CortexIndicator extends PanelMenu.Button {
    _init(extension) {
        super._init(0.5, 'Cortex', false);
        this._ext = extension;
        this._snapshot = null;
        this._snapshotError = '';
        this._tab = 0;
        this._paused = false;
        this._rangeIdx = 3;          // {hoy·7d·30d·∞}: ∞ por default, como el plasmoide
        this._tabState = TABS.map(() => ({}));   // estado propio de cada pestaña (sobrevive re-renders)
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
            if (open) {
                this.refresh();
                this._onShow();
            }
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

    _onShow() {
        const t = TABS[this._tab];
        try {
            t.mod.onShow?.(this._ctx(this._tab));
        } catch (e) {
            logError(e, `cortex: onShow de ${t.label}`);
        }
    }

    refresh() {
        this._snapshot = D.readJson('state.json');
        this._snapshotError = this._snapshot ? (this._snapshot.error || '') : 'state.json ilegible';
        this._stats = D.readJson('stats.json');
        this._statsGlobal = D.readJson('stats-global.json');   // solo si el sync (e) está activo
        this._chats = D.readJson('chats.json');
        this._sessions = D.readJson('sessions.json');
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
        // Badges ⬆/🩹 en el panel (solo cuando aplican), que aporta cada pestaña con panelBadge(ctx).
        const badges = TABS.map((t, i) => t.mod.panelBadge ? t.mod.panelBadge(this._ctx(i)) : '')
            .filter(Boolean);
        if (badges.length) {
            const b = new St.Label({text: badges.join(' '), style_class: 'cortex-compact-badge'});
            this._compact.add_child(b);
        }
    }

    // Contexto que recibe cada pestaña. Datos frescos + estado propio + acciones del núcleo.
    _ctx(i) {
        const ctx = {
            snapshot: this._snapshot,
            snapshotError: this._snapshotError,
            stats: this._stats,
            statsGlobal: this._statsGlobal,
            chats: this._chats,
            sessions: this._sessions,
            rangeIdx: this._rangeIdx,
            contentWidth: POPUP_W - RAIL_W - 48,
            extPath: this._ext.path,
            state: this._tabState[i],
            setRange: r => {
                this._rangeIdx = r;
                this._renderPopup();
            },
            // Re-pinta la pestaña visible (tras un cambio de estado o al llegar un resultado async).
            rerender: () => {
                if (this.menu.isOpen)
                    this._renderPopup();
            },
            refresh: () => this.refresh(),
            closeMenu: () => this.menu.close(),
        };
        return ctx;
    }

    _railButton(i) {
        const tab = TABS[i];
        const btn = new St.Button({style_class: 'cortex-rail-btn', x_expand: true, can_focus: true});
        if (i === this._tab)
            btn.add_style_pseudo_class('checked');
        const b = new St.BoxLayout({orientation: H, x_expand: true, x_align: Clutter.ActorAlign.START});
        b.add_child(new St.Label({text: tab.glyph, style_class: 'cortex-rail-glyph'}));
        b.add_child(new St.Label({text: tab.label, y_align: Clutter.ActorAlign.CENTER}));
        btn.set_child(b);
        btn.connect('clicked', () => {
            this._tab = i;
            this._onShow();
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
        TABS.forEach((t, i) => {
            if (!t.visible || t.visible(this._ctx(i)))
                rail.add_child(this._railButton(i));
        });
        rail.add_child(new St.Widget({y_expand: true}));
        const foot = new St.BoxLayout({orientation: H, x_align: Clutter.ActorAlign.CENTER});
        // Botones CONTEXTUALES primero (⬆ update · 🩹 curita), luego los fijos — como el pie del plasmoide.
        for (const [i, t] of TABS.entries()) {
            for (const b of t.mod.railButtons ? t.mod.railButtons(this._ctx(i)) : [])
                foot.add_child(this._footButton(b.glyph, b.tip, b.onClick));
        }
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
        const ctx = this._ctx(this._tab);
        let content;
        try {
            content = tab.mod.build(ctx);
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
