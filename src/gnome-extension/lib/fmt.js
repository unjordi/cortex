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
    return Math.round(n).toLocaleString('es-MX');
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
