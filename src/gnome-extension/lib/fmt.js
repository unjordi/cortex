// Formatos y colores — port 1:1 de los helpers de src/plasmoid/contents/ui/main.qml
// (pctColor, fmtMoney, fmtInt, isPast, resetDetail, relativeTime, compactReset).
// Si cambias uno aquí, cámbialo también en el QML, QuotaModel.swift y Format.cs (paridad).

export const ACCENT = '#e8884a';
export const DANGER = '#dc3545';
export const MUTED = '#777777';

// Acento naranja; rojo solo >90 % (aviso de throttle).
export function pctColor(p) {
    if (p === undefined || p === null || p < 0)
        return MUTED;
    return p > 90 ? DANGER : ACCENT;
}

export function fmtMoney(v, cur) {
    if (v === undefined || v === null)
        return '—';
    const sym = cur === 'USD' ? '$' : (cur ? `${cur} ` : '$');
    return sym + v.toFixed(2);
}

export function fmtInt(n) {
    if (n === undefined || n === null)
        return '—';
    return `${Math.round(n)}`.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

export function fmtTok(n) {
    if (n === undefined || n === null)
        return '—';
    if (n >= 1e6)
        return `${(n / 1e6).toFixed(1)}M`;
    if (n >= 1e3)
        return `${(n / 1e3).toFixed(1)}k`;
    return `${Math.round(n)}`;
}

export function fmtBytes(n) {
    if (n === null || n === undefined || !Number.isFinite(n))
        return '—';
    if (n < 1024)
        return `${n} B`;
    const u = ['KiB', 'MiB', 'GiB', 'TiB'];
    let v = n / 1024, i = 0;
    while (v >= 1024 && i < u.length - 1) {
        v /= 1024;
        i++;
    }
    return `${v >= 10 ? Math.round(v) : Math.round(v * 10) / 10} ${u[i]}`;
}

export function fmtHour(h) {
    if (h === undefined || h === null || h < 0)
        return '—';
    let hh = h % 12;
    if (hh === 0)
        hh = 12;
    return `${hh} ${h < 12 ? 'a.m.' : 'p.m.'}`;
}

// Paleta por modelo/proyecto (índice en la lista de stats → color), igual que modelPalette del QML.
export const PALETTE = ['#e8884a', '#5b9bd5', '#9b6dd6', '#5fb98e', '#d6a15b', '#c96daa'];

export function colorFor(list, key, name) {
    if (!list)
        return PALETTE[0];
    const i = list.findIndex(x => x[key] === name);
    return i < 0 ? PALETTE[0] : PALETTE[i % PALETTE.length];
}

// "claude-opus-4-8" → "Opus 4.8"; "gemini-3.1-pro-preview" → "Gemini 3.1 Pro".
export function prettyModel(id) {
    if (!id)
        return '—';
    const parts = id.replace(/^claude-/, '').split('-');
    const fam = parts[0].charAt(0).toUpperCase() + parts[0].slice(1);
    const noise = {preview: 1, exp: 1, latest: 1};
    const tokens = [];
    let nums = [];
    const flush = () => {
        if (nums.length) {
            tokens.push(nums.join('.'));
            nums = [];
        }
    };
    for (let i = 1; i < parts.length; i++) {
        const p = parts[i];
        if (/^\d+$/.test(p)) {
            if (p.length >= 6)
                break;
            nums.push(p);
        } else if (/^\d+\.\d+$/.test(p)) {
            flush();
            tokens.push(p);
        } else if (p && !noise[p.toLowerCase()]) {
            flush();
            tokens.push(p.charAt(0).toUpperCase() + p.slice(1));
        }
    }
    flush();
    return tokens.length ? `${fam} ${tokens.join(' ')}` : fam;
}

// Fecha relativa con granularidad de día desde el prefijo YYYY-MM-DD.
export function relDate(iso) {
    if (!iso || `${iso}`.length < 10)
        return '';
    const d = Date.parse(`${`${iso}`.substring(0, 10)}T00:00:00Z`);
    if (Number.isNaN(d))
        return '';
    const days = Math.floor((Date.now() - d) / 86400000);
    if (days <= 0)
        return 'hoy';
    if (days === 1)
        return 'ayer';
    if (days < 7)
        return `hace ${days}d`;
    if (days < 30)
        return `hace ${Math.floor(days / 7)}sem`;
    return `hace ${Math.floor(days / 30)}mes`;
}

// '#RRGGBB' + alpha → 'rgba(r, g, b, a)' para CSS de St.
export function withAlpha(hex, a) {
    const n = parseInt(hex.slice(1), 16);
    return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${a})`;
}

// Comillas simples para shell (argumento seguro dentro de `bash -c`).
export function shq(s) {
    return `'${`${s}`.replace(/'/g, "'\\''")}'`;
}

export function isPast(iso) {
    if (!iso)
        return false;
    const t = Date.parse(iso);
    return !Number.isNaN(t) && t <= Date.now();
}

// <24 h → "en 4h36m"; ≥24 h → "mié@7:59".
export function resetDetail(iso) {
    if (!iso)
        return '';
    const t = Date.parse(iso);
    if (Number.isNaN(t))
        return '';
    const secs = (t - Date.now()) / 1000;
    if (secs < 86400) {
        const total = Math.max(0, Math.round(secs));
        const h = Math.floor(total / 3600), m = Math.floor((total % 3600) / 60);
        if (h > 0)
            return m > 0 ? `en ${h}h${m}m` : `en ${h}h`;
        if (total >= 60)
            return `en ${m}m`;
        return 'en <1m';
    }
    const d = new Date(t);
    const wd = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'][d.getDay()];
    let hh = d.getHours() % 12;
    if (hh === 0)
        hh = 12;
    return `${wd}@${hh}:${`0${d.getMinutes()}`.slice(-2)}`;
}

export function relativeTime(iso) {
    if (!iso)
        return '';
    const t = Date.parse(iso);
    if (Number.isNaN(t))
        return iso;
    const diff = Math.round((t - Date.now()) / 1000);
    const abs = Math.abs(diff);
    let val, unit;
    if (abs < 60) {
        val = abs; unit = 's';
    } else if (abs < 3600) {
        val = Math.round(abs / 60); unit = 'min';
    } else if (abs < 86400) {
        val = Math.round(abs / 3600); unit = 'h';
    } else {
        val = Math.round(abs / 86400); unit = 'd';
    }
    return diff < 0 ? `hace ${val}${unit}` : `en ${val}${unit}`;
}

export function compactReset(iso) {
    if (!iso)
        return '';
    const t = Date.parse(iso);
    if (Number.isNaN(t))
        return '';
    const abs = Math.abs(Math.round((t - Date.now()) / 1000));
    if (abs < 3600)
        return `${Math.round(abs / 60)}min`;
    if (abs < 86400)
        return `${Math.round(abs / 3600)}h`;
    return `${Math.round(abs / 86400)}d`;
}
