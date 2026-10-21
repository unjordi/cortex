// Pestaña 0 · Límites — port de "Tab 0" + UsageSection/SpendSection de main.qml.
import St from 'gi://St';
import Clutter from 'gi://Clutter';

import * as F from '../lib/fmt.js';
import * as D from '../lib/data.js';

// Aviso de autenticación (login por-expirar/expirado/sin-cuenta), o null si está OK. Espeja
// authNotice de QuotaModel.swift / main.qml. hard = problema duro (rojo); offer = mostrar botón.
function authNotice(s) {
    const st = (s && s.auth && s.auth.state) ? s.auth.state : 'ok';
    if (st === 'no_credentials') return {message: 'No hay cuenta en el CLI de Claude — el widget no puede leer tu cuota.', offer: true, hard: true};
    if (st === 'expired')        return {message: 'El login de Claude expiró — re-loguéate para seguir viendo tu cuota.', offer: true, hard: true};
    if (st === 'expiring')       return {message: `Tu login de Claude expira ${F.relativeTime(s && s.auth ? s.auth.expires_at : null)} — re-loguéate pronto.`, offer: true, hard: false};
    return null;
}

// Abre un terminal con el flujo oficial de re-login (abre el navegador). Prueba los terminales
// comunes en orden (kgx/gnome-terminal/konsole/xterm). Email validado (charset seguro) → sin quoting.
function reloginRun(s) {
    const a = (s && s.auth && s.auth.account_email) ? s.auth.account_email : (s ? (s.account_email || '') : '');
    let inner = 'claude auth login --claudeai';
    if (a && /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(a)) inner += ` --email ${a}`;
    inner += '; echo; read -p "cerrar con Enter..."';
    const shq = x => "'" + String(x).replace(/'/g, "'\\''") + "'";
    // Prueba los terminales comunes; si NINGUNO existe, no dejes el botón mudo: avisa por notify-send
    // con el comando a correr a mano (el for exec-ea y reemplaza el shell en el 1er terminal hallado;
    // si ninguno, el for termina y cae al notify).
    const wrapper = `for tb in "kgx -e" "gnome-terminal --" "konsole -e" "xterm -e"; do bin=\${tb%% *}; command -v "$bin" >/dev/null 2>&1 && exec $tb bash -lc ${shq(inner)}; done; notify-send -a Cortex "Re-login de Claude" "No encontré un terminal. Abre uno y corre: claude auth login --claudeai" 2>/dev/null || true`;
    D.spawn(['bash', '-lc', wrapper]);
}

function label(text, style = '', expand = false) {
    const l = new St.Label({text, x_expand: expand, y_align: Clutter.ActorAlign.CENTER});
    if (style)
        l.set_style(style);
    l.clutter_text.line_wrap = true;
    return l;
}

// Barra de progreso: pista + relleno proporcional (ancho fijo, St no tiene layouts relativos).
export function bar(pct, width) {
    const track = new St.Widget({style_class: 'cortex-bar-track', y_align: Clutter.ActorAlign.CENTER, y_expand: false});
    track.set_style(`width: ${width}px;`);
    const fill = new St.Widget({style_class: 'cortex-bar-fill'});
    const w = Math.round(width * Math.max(0, Math.min(1, pct / 100)));
    fill.set_style(`width: ${Math.max(0, w)}px; background-color: ${F.pctColor(pct)};`);
    track.add_child(fill);
    return track;
}

function section(title, headline, headColor, pct, caption, width) {
    const col = new St.BoxLayout({orientation: Clutter.Orientation.VERTICAL, style_class: 'cortex-section'});
    const head = new St.BoxLayout();
    head.add_child(label(title, 'font-weight: bold;', true));
    head.add_child(label(headline, `color: ${headColor}; font-weight: bold;`));
    col.add_child(head);
    col.add_child(bar(pct, width));
    if (caption)
        col.add_child(label(caption, 'font-size: smaller; opacity: 0.65;'));
    return col;
}

function usage(title, block, width) {
    const pct = block && block.percent !== undefined && block.percent !== null ? block.percent : -1;
    let cap = '';
    if (block) {
        cap = F.isPast(block.resets_at)
            ? `Se restableció ${F.relativeTime(block.resets_at)} · actualizando…`
            : `Se restablece ${F.resetDetail(block.resets_at)}`;
        if (block.cost_usd !== null && block.cost_usd !== undefined)
            cap += ` · ≈ $${block.cost_usd.toFixed(2)} (API equiv local)`;
    }
    return section(title, pct >= 0 ? `${pct.toFixed(1)}%` : '—', F.pctColor(pct), pct, cap, width);
}

function spendSection(spend, extra, width) {
    const pct = spend.percent !== undefined && spend.percent !== null ? spend.percent : -1;
    let cap = `${F.fmtMoney(spend.used, spend.currency)} / ${F.fmtMoney(spend.cap, spend.currency)}`;
    if (spend.currency)
        cap += ` ${spend.currency}`;
    cap += ' — gasto real de bolsillo (no el equivalente incluido del plan)';
    if (extra && extra.enabled === true && extra.used_credits !== null && extra.used_credits !== undefined) {
        cap += `\nSobreuso: ${F.fmtInt(extra.used_credits)} / ${F.fmtInt(extra.monthly_limit)} créditos`;
        if (extra.utilization !== null && extra.utilization !== undefined)
            cap += ` (${extra.utilization.toFixed(1)}%)`;
    }
    return section('Gasto real', F.fmtMoney(spend.used, spend.currency), F.pctColor(pct), pct, cap, width);
}

export function build(ctx) {
    const s = ctx.snapshot;
    const W = ctx.contentWidth;
    const box = new St.BoxLayout({orientation: Clutter.Orientation.VERTICAL, style_class: 'cortex-tab', y_expand: true});
    box.add_child(label('Límites de uso', 'font-weight: bold; font-size: larger;'));

    // Banner de aviso de autenticación + botón de re-login (espeja authBanner de PopoverView.swift).
    const notice = authNotice(s);
    if (notice) {
        const color = notice.hard ? F.DANGER : '#e8884a';
        const banner = new St.BoxLayout({orientation: Clutter.Orientation.VERTICAL, style_class: 'cortex-section'});
        banner.set_style(`background-color: ${notice.hard ? 'rgba(220,53,69,0.14)' : 'rgba(232,136,74,0.14)'}; border-radius: 8px; padding: 8px;`);
        banner.add_child(label(notice.message, `color: ${color};`, true));
        if (notice.offer) {
            const btn = new St.Button({label: 'Re-loguear en Claude', style_class: 'button', x_align: Clutter.ActorAlign.START});
            btn.connect('clicked', () => reloginRun(s));
            banner.add_child(btn);
        }
        box.add_child(banner);
    }

    box.add_child(usage('Sesión (5 h)', s ? s.five_hour : null, W));
    box.add_child(usage('Semanal (7 d)', s ? s.weekly : null, W));

    const scoped = s && s.limits ? s.limits.filter(l => l.kind === 'weekly_scoped' && l.model) : [];
    if (scoped.length > 0) {
        box.add_child(label('Por modelo (semanal)', 'font-size: smaller; opacity: 0.6;'));
        for (const l of scoped)
            box.add_child(usage(l.model, l, W));
    }

    if (s && s.spend && s.spend.enabled === true)
        box.add_child(spendSection(s.spend, s.extra_usage, W));

    box.add_child(new St.Widget({y_expand: true}));

    const mismatch = s && s.account_mismatch === true;
    let foot;
    if (!s) {
        foot = ctx.snapshotError ? `error: ${ctx.snapshotError}` : 'cargando…';
    } else {
        const account = s.account_email ? s.account_email
            : (s.basis === 'oauth' ? 'datos reales' : 'estimado local');
        const staleMark = s.stale === true ? ' · ⏳ sin refrescar' : '';
        foot = `${mismatch ? '⚠ ' : ''}${account}${mismatch ? ' no es la cuenta fijada' : ''}` +
            ` · ⟳ 5 min + al reset 5h · act. ${F.relativeTime(s.updated_at)}${staleMark}`;
    }
    box.add_child(label(foot, mismatch
        ? `font-size: smaller; font-weight: bold; color: ${F.DANGER};`
        : 'font-size: smaller; opacity: 0.5;'));
    return box;
}
