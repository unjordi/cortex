// Pestaña 3 · Proyectos — port de "Tab 3: Proyectos" de main.qml: gráfica apilada por día y proyecto +
// lista de proyectos (swatch · nombre · ▸ · in/out · %). Clic en un proyecto con sesiones lo despliega
// (máx 12); clic en una sesión la resume en una terminal. Clic-SECUNDARIO abre las acciones inline:
// proyecto → Renombrar… / Restaurar original; sesión → además Mover a… (doc: src/README.md).
import St from 'gi://St';
import Clutter from 'gi://Clutter';
import Pango from 'gi://Pango';

import * as F from '../lib/fmt.js';
import * as S from '../lib/stats.js';
import * as D from '../lib/data.js';
import * as W from '../lib/widgets.js';
import * as Ses from '../lib/sesiones.js';
import * as Dlg from '../lib/dialogs.js';
import {stackedChart} from '../lib/proyectos-grafica.js';

const CHART_H = 110;
const SMALL = 'font-size: smaller;';
const HOVER_BG = 'background-color: rgba(255, 255, 255, 0.08);';

function lbl(text, style = '', {expand = false, ellipsize = false, maxWidth = 0} = {}) {
    const l = new St.Label({text: `${text}`, x_expand: expand, y_align: Clutter.ActorAlign.CENTER});
    if (ellipsize)
        l.clutter_text.ellipsize = Pango.EllipsizeMode.END;
    l.set_style(`${style}${maxWidth ? ` max-width: ${maxWidth}px;` : ''}`);
    return l;
}

// Fila clicable: primario → onPrimary, secundario → onSecondary. Resalta al pasar el cursor.
function clickRow(child, onPrimary, onSecondary) {
    const b = new St.Button({x_expand: true, can_focus: true, track_hover: true, reactive: true,
        button_mask: St.ButtonMask.ONE | St.ButtonMask.THREE});
    const base = 'border-radius: 6px; padding: 2px 4px;';
    b.set_style(base);
    b.connect('notify::hover', () => b.set_style(b.hover ? base + HOVER_BG : base));
    b.set_child(child);
    b.connect('clicked', (_b, button) => (button === 3 ? onSecondary() : onPrimary()));
    return b;
}

// Sesiones efectivas: tras un renombrado/movimiento corremos sessions-extract.js (rápido, sin red) y
// usamos SU lista hasta que el fetch reescriba sessions.json (entonces ya trae el cambio).
function effSessions(ctx) {
    const st = ctx.state;
    if (st.sessOverride) {
        if (JSON.stringify(ctx.sessions) === st.sessOverride.base)
            return st.sessOverride.arr;
        st.sessOverride = null;
    }
    return ctx.sessions || [];
}

async function quickRefreshSessions(ctx) {
    const base = JSON.stringify(ctx.sessions);
    const arr = await Ses.refreshSessions();
    if (arr) {
        ctx.state.sessOverride = {arr, base};
        ctx.rerender();
    }
}

function guarded(fn) {
    try {
        fn();
        return true;
    } catch (e) {
        logError(e, 'cortex: no se pudo escribir el alias');
        Dlg.openMessage('No se pudo guardar el nombre', e.message);
        return false;
    }
}

function renameProject(ctx, shown) {
    ctx.state.menu = null;
    ctx.closeMenu();
    Dlg.openRename({kind: 'project', seed: shown, aliased: Ses.projectAliased(shown),
        onSave: text => guarded(() => Ses.renameProject(shown, text)) && D.forceRefresh()});
}

function renameSession(ctx, s) {
    ctx.state.menu = null;
    ctx.closeMenu();
    Dlg.openRename({kind: 'session', seed: s.label || '', summary: s.summary || '',
        aliased: Ses.sessionAliased(s.id),
        onSuggest: () => Ses.suggestName(s.summary),
        onSave: text => guarded(() => Ses.renameSession(s.id, text)) && quickRefreshSessions(ctx)});
}

function moveSession(ctx, s, target) {
    ctx.state.menu = null;
    ctx.closeMenu();
    Dlg.openMove({label: s.label || '', targetName: target.name, onMove: async () => {
        const res = await Ses.moveSession(s.id, target.cwd);
        if (res.ok) {
            quickRefreshSessions(ctx);   // la lista refleja el move YA (sin red)
            D.forceRefresh();            // reconcilia conteos por proyecto / agregación después
        } else {
            Dlg.openMessage('No se pudo mover la sesión', res.error);
        }
    }});
}

// Tira de acciones inline (el "menú de clic-secundario" del QML).
function actionStrip(buttons) {
    const strip = W.hbox('', {x_expand: true});
    strip.set_style('spacing: 4px; padding: 2px 0 4px 14px;');
    for (const b of buttons) {
        b.set_style('padding: 2px 8px; font-size: smaller;');
        strip.add_child(b);
    }
    return strip;
}

function sessionBlock(ctx, s, sessions) {
    const st = ctx.state;
    const col = W.vbox('', {x_expand: true});
    const row = W.hbox('', {x_expand: true});
    row.set_style('spacing: 6px;');
    row.add_child(lbl('↺', `color: ${F.ACCENT};`));
    row.add_child(lbl(s.label ? s.label : '(sesión)', SMALL, {expand: true, ellipsize: true}));
    row.add_child(lbl(F.relDate(s.updated_at), 'font-size: 0.8em; opacity: 0.5;'));
    const key = `s:${s.id}`;
    const btn = clickRow(row,
        () => {
            ctx.closeMenu();
            Ses.resumeSession(s.cwd, s.id);
        },
        () => {
            st.menu = st.menu === key ? null : key;
            st.moveOpen = false;
            ctx.rerender();
        });
    btn.accessible_name = `Resumir en ${s.cwd}`;
    col.add_child(btn);

    if (st.menu === key) {
        const acts = [W.button('Renombrar…', () => renameSession(ctx, s))];
        if (Ses.sessionAliased(s.id)) {
            acts.push(W.button('Restaurar original', () => {
                st.menu = null;
                if (guarded(() => Ses.renameSession(s.id, '')))
                    quickRefreshSessions(ctx);
                ctx.rerender();
            }));
        }
        acts.push(W.button(st.moveOpen ? 'Mover a… ▾' : 'Mover a… ▸', () => {
            st.moveOpen = !st.moveOpen;
            ctx.rerender();
        }));
        col.add_child(actionStrip(acts));
        if (st.moveOpen) {
            const others = Ses.otherProjects(sessions, s.project ? s.project : '');
            const list = W.vbox('', {x_expand: true});
            list.set_style('spacing: 2px; padding-left: 30px;');
            if (!others.length)
                list.add_child(lbl('(no hay otros proyectos)', `${SMALL} opacity: 0.5;`));
            for (const o of others) {
                const r = W.hbox('', {x_expand: true});
                r.add_child(lbl(`→ ${o.name}`, SMALL, {expand: true, ellipsize: true}));
                list.add_child(clickRow(r, () => moveSession(ctx, s, o), () => {}));
            }
            col.add_child(list);
        }
    }
    return col;
}

function projectBlock(ctx, p, sessions) {
    const st = ctx.state;
    const name = p.project ? p.project : '—';
    const nSess = S.sessionCountForProject(sessions, name);
    const expanded = st.expanded === name;
    const color = F.colorFor(ctx.stats && ctx.stats.projects, 'project', p.project);

    const col = W.vbox('', {x_expand: true});
    col.set_style('spacing: 2px;');
    const row = W.hbox('', {x_expand: true});
    row.set_style('spacing: 6px;');
    const sw = new St.Widget({y_align: Clutter.ActorAlign.CENTER});
    sw.set_style(`width: 10px; height: 10px; border-radius: 2px; background-color: ${color};`);
    row.add_child(sw);
    row.add_child(lbl(name, 'font-weight: bold;', {ellipsize: true, maxWidth: 140}));
    if (nSess > 0)
        row.add_child(lbl(expanded ? '▾' : '▸', `${SMALL} opacity: 0.5;`));
    row.add_child(new St.Widget({x_expand: true}));
    row.add_child(lbl(`${F.fmtTok(p.in_tok)} in · ${F.fmtTok(p.out_tok)} out`, 'opacity: 0.7;'));
    row.add_child(lbl(`${p.pct.toFixed(1)}%`, `font-weight: bold; color: ${color}; min-width: 45px; text-align: right;`));

    const key = `p:${name}`;
    col.add_child(clickRow(row,
        () => {
            if (nSess > 0) {
                st.expanded = expanded ? '' : name;
                ctx.rerender();
            }
        },
        () => {
            st.menu = st.menu === key ? null : key;
            ctx.rerender();
        }));

    if (st.menu === key) {
        const acts = [W.button('Renombrar…', () => renameProject(ctx, name))];
        if (Ses.projectAliased(name)) {
            acts.push(W.button('Restaurar original', () => {
                st.menu = null;
                if (guarded(() => Ses.renameProject(name, '')))
                    D.forceRefresh();
                ctx.rerender();
            }));
        }
        col.add_child(actionStrip(acts));
    }

    if (expanded) {
        const list = W.vbox('', {x_expand: true});
        list.set_style('spacing: 2px; padding-left: 16px;');
        for (const s of S.sessionsForProject(sessions, name))
            list.add_child(sessionBlock(ctx, s, sessions));
        col.add_child(list);
    }
    return col;
}

export function build(ctx) {
    const stats = ctx.activeStats || ctx.stats;
    const days = S.rangedDays(stats, ctx.rangeIdx);
    const projects = S.aggBy(days, 'projects', 'project');
    const sessions = effSessions(ctx);
    const colorOf = name => F.colorFor(ctx.stats && ctx.stats.projects, 'project', name);

    const box = W.vbox('cortex-tab', {y_expand: true});
    box.add_child(W.heading('Uso por proyecto'));
    box.add_child(stackedChart(days, colorOf, S.maxDayProjectTokens(days), ctx.contentWidth, CHART_H));

    const list = W.vbox('', {x_expand: true});
    list.set_style('spacing: 4px;');
    for (const p of projects)
        list.add_child(projectBlock(ctx, p, sessions));
    box.add_child(list);

    box.add_child(new St.Widget({y_expand: true}));
    box.add_child(W.rangePills(ctx));
    return box;
}
