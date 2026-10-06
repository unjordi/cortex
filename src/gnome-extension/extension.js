// Cortex — indicador de panel para GNOME Shell.
// Lee el mismo snapshot que publica el daemon de cortex (cortex-fetch, vía cortex.timer)
// en ~/.cache/cortex/state.json. No consulta la red ni ejecuta ccusage por su cuenta.
import GObject from 'gi://GObject';
import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

// Mismos colores que el plasmoid: acento naranja, rojo solo >90% (aviso de throttle).
const ACCENT = '#e8884a';
const DANGER = '#dc3545';
const MUTED = '#777777';
const BAR_W = 300;

const CACHE_DIR = GLib.build_filenamev([GLib.get_user_cache_dir(), 'cortex']);
const STATE_FILE = GLib.build_filenamev([CACHE_DIR, 'state.json']);

function pctColor(p) {
    if (p === undefined || p === null || p < 0)
        return MUTED;
    return p > 90 ? DANGER : ACCENT;
}

function fmtMoney(v, cur) {
    if (v === undefined || v === null)
        return '—';
    const sym = !cur || cur === 'USD' ? '$' : `${cur} `;
    return sym + v.toFixed(2);
}

function fmtTokens(n) {
    if (!n)
        return '0';
    if (n >= 1e9)
        return `${(n / 1e9).toFixed(2)} G`;
    if (n >= 1e6)
        return `${(n / 1e6).toFixed(1)} M`;
    if (n >= 1e3)
        return `${(n / 1e3).toFixed(0)} k`;
    return `${n}`;
}

// "en 4 h 50 min" / "ya pasó" — el snapshot trae los resets en ISO 8601 UTC.
function fmtReset(iso) {
    if (!iso)
        return '—';
    const t = Date.parse(iso);
    if (Number.isNaN(t))
        return '—';
    let d = Math.round((t - Date.now()) / 1000);
    if (d <= 0)
        return 'ya pasó';
    const days = Math.floor(d / 86400);
    d -= days * 86400;
    const h = Math.floor(d / 3600);
    const m = Math.floor((d % 3600) / 60);
    if (days > 0)
        return `en ${days} d ${h} h`;
    if (h > 0)
        return `en ${h} h ${m} min`;
    return `en ${m} min`;
}

function fmtAge(iso) {
    if (!iso)
        return 'nunca';
    const t = Date.parse(iso);
    if (Number.isNaN(t))
        return '—';
    const d = Math.max(0, Math.round((Date.now() - t) / 1000));
    if (d < 90)
        return `hace ${d} s`;
    if (d < 5400)
        return `hace ${Math.round(d / 60)} min`;
    return `hace ${Math.round(d / 3600)} h`;
}

const CortexIndicator = GObject.registerClass(
class CortexIndicator extends PanelMenu.Button {
    _init(extension) {
        super._init(0.5, 'Cortex', false);
        this._extension = extension;
        this._snapshot = null;
        this._error = null;

        const box = new St.BoxLayout({
            orientation: Clutter.Orientation.HORIZONTAL,
            style_class: 'panel-status-menu-box',
        });
        this._icon = new St.Icon({
            gicon: Gio.icon_new_for_string(
                GLib.build_filenamev([extension.path, 'icons', 'cortex.svg'])),
            style_class: 'system-status-icon',
        });
        this._label = new St.Label({
            text: '—',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'cortex-panel-label',
        });
        box.add_child(this._icon);
        box.add_child(this._label);
        this.add_child(box);

        this._watch();
        this.refresh();

        // Red de seguridad: el timer del daemon corre cada 5 min, pero los "faltan X min"
        // del menú envejecen solos — un repintado por minuto los mantiene honestos.
        this._tick = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 60, () => {
            this.refresh();
            return GLib.SOURCE_CONTINUE;
        });
    }

    // cortex-fetch escribe con tmp+rename: vigilar el ARCHIVO pierde el watch en cada
    // relevo de inodo, así que se vigila el DIRECTORIO.
    _watch() {
        try {
            this._monitor = Gio.File.new_for_path(CACHE_DIR)
                .monitor_directory(Gio.FileMonitorFlags.NONE, null);
            this._monitorId = this._monitor.connect('changed', (_m, file) => {
                if (file && file.get_path() === STATE_FILE) {
                    if (this._debounce)
                        GLib.Source.remove(this._debounce);
                    this._debounce = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 250, () => {
                        this._debounce = null;
                        this.refresh();
                        return GLib.SOURCE_REMOVE;
                    });
                }
            });
        } catch (e) {
            logError(e, 'cortex: no se pudo vigilar el cache');
        }
    }

    refresh() {
        this._read();
        this._renderPanel();
        this._renderMenu();
    }

    _read() {
        try {
            const [ok, bytes] = Gio.File.new_for_path(STATE_FILE).load_contents(null);
            if (!ok)
                throw new Error('load_contents falló');
            this._snapshot = JSON.parse(new TextDecoder().decode(bytes));
            this._error = this._snapshot.error || null;
        } catch (e) {
            this._snapshot = null;
            this._error = e.message;
        }
    }

    _renderPanel() {
        const s = this._snapshot;
        if (!s || s.status !== 'ok') {
            this._label.text = '—';
            this._label.set_style(`color: ${MUTED};`);
            return;
        }
        const five = s.five_hour ? s.five_hour.percent : -1;
        const week = s.weekly ? s.weekly.percent : -1;
        this._label.text = `${five}% · ${week}%`;
        // El panel se pinta con el PEOR de los dos: el rojo es un aviso, no un adorno.
        this._label.set_style(`color: ${pctColor(Math.max(five, week))};`);
    }

    _row(key, value, color) {
        const item = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
        const box = new St.BoxLayout({
            orientation: Clutter.Orientation.HORIZONTAL,
            style_class: 'cortex-row',
            x_expand: true,
        });
        box.add_child(new St.Label({text: key, x_expand: true}));
        const v = new St.Label({text: value});
        if (color)
            v.set_style(`color: ${color};`);
        box.add_child(v);
        item.add_child(box);
        return item;
    }

    _quota(title, q) {
        const item = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
        const col = new St.BoxLayout({
            orientation: Clutter.Orientation.VERTICAL,
            x_expand: true,
        });

        const head = new St.BoxLayout({
            orientation: Clutter.Orientation.HORIZONTAL,
            x_expand: true,
        });
        head.add_child(new St.Label({
            text: title,
            x_expand: true,
            style_class: 'cortex-row-key',
        }));
        const pct = new St.Label({text: `${q.percent}%`});
        pct.set_style(`color: ${pctColor(q.percent)}; font-weight: bold;`);
        head.add_child(pct);
        col.add_child(head);

        const track = new St.Widget({style_class: 'cortex-bar-track', x_expand: true});
        const fill = new St.Widget({style_class: 'cortex-bar-fill'});
        const w = Math.max(2, Math.round(BAR_W * Math.min(100, Math.max(0, q.percent)) / 100));
        fill.set_style(`width: ${w}px; background-color: ${pctColor(q.percent)};`);
        track.set_style(`min-width: ${BAR_W}px;`);
        track.add_child(fill);
        col.add_child(track);

        const foot = new St.BoxLayout({
            orientation: Clutter.Orientation.HORIZONTAL,
            x_expand: true,
        });
        const spent = `${fmtMoney(q.cost_usd, 'USD')} / ${fmtMoney(q.cost_cap, 'USD')}`;
        const left = new St.Label({
            text: `${spent} · ${fmtTokens(q.tokens_used)} tok`,
            x_expand: true,
            style_class: 'cortex-row-sub',
        });
        left.set_style(`color: ${MUTED};`);
        const right = new St.Label({
            text: `resetea ${fmtReset(q.resets_at)}`,
            style_class: 'cortex-row-sub',
        });
        right.set_style(`color: ${MUTED};`);
        foot.add_child(left);
        foot.add_child(right);
        col.add_child(foot);

        item.add_child(col);
        return item;
    }

    _renderMenu() {
        this.menu.removeAll();
        const s = this._snapshot;

        if (!s) {
            this.menu.addMenuItem(this._row('Sin snapshot', '', DANGER));
            this.menu.addMenuItem(this._row(this._error || 'state.json ilegible', '', MUTED));
        } else {
            if (s.status !== 'ok' || s.error)
                this.menu.addMenuItem(this._row('Error', s.error || s.status, DANGER));
            if (s.account_mismatch)
                this.menu.addMenuItem(this._row('⚠ Cuenta distinta a la del login', '', DANGER));

            if (s.five_hour)
                this.menu.addMenuItem(this._quota('Sesión (5 h)', s.five_hour));
            if (s.weekly)
                this.menu.addMenuItem(this._quota('Semanal', s.weekly));

            // Límites acotados a un modelo: efímeros y cambiantes, se listan tal como vengan.
            const scoped = (s.limits || []).filter(l => l.kind === 'weekly_scoped' && l.model);
            if (scoped.length > 0) {
                this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
                for (const l of scoped) {
                    this.menu.addMenuItem(this._row(
                        `Semanal · ${l.model}`,
                        `${l.percent}%`,
                        pctColor(l.percent)));
                }
            }

            const extras = [];
            if (s.spend && s.spend.enabled) {
                extras.push(['Gasto extra', `${fmtMoney(s.spend.used, s.spend.currency)} / ` +
                    `${fmtMoney(s.spend.cap, s.spend.currency)}`, pctColor(s.spend.percent)]);
            }
            if (s.extra_usage && s.extra_usage.enabled) {
                extras.push(['Créditos del mes',
                    `${fmtMoney(s.extra_usage.used_credits, s.extra_usage.currency)} / ` +
                    `${fmtMoney(s.extra_usage.monthly_limit, s.extra_usage.currency)}`, null]);
            }
            if (extras.length > 0) {
                this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
                for (const [k, v, c] of extras)
                    this.menu.addMenuItem(this._row(k, v, c));
            }

            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
            if (s.account_email)
                this.menu.addMenuItem(this._row('Cuenta', s.account_email, MUTED));
            this.menu.addMenuItem(this._row('Snapshot', fmtAge(s.updated_at), MUTED));
        }

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        const act = new PopupMenu.PopupMenuItem('Refrescar ahora');
        act.connect('activate', () => {
            try {
                // Dispara el mismo servicio del timer: una sola ruta de actualización.
                Gio.Subprocess.new(
                    ['systemctl', '--user', 'start', 'cortex.service'],
                    Gio.SubprocessFlags.NONE);
            } catch (e) {
                logError(e, 'cortex: no se pudo lanzar cortex.service');
            }
        });
        this.menu.addMenuItem(act);
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
