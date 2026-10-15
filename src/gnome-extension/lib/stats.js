// Recorte por rango {hoy·7d·30d·∞} y agregados — port de rangeCutoff/rDays/aggBy/rChats/rSessionCount
// /chatsByModel/sessionsForProject/streaks/heatmapCells de main.qml.

export const RANGES = ['hoy', '7d', '30d', '∞'];

const pad2 = n => (n < 10 ? '0' : '') + n;
export const dayKey = d => `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;

// "yyyy-MM-dd" = hoy − daysBack; "" si ∞.
export function rangeCutoff(rangeIdx) {
    const back = [0, 6, 29, -1][rangeIdx];
    if (back < 0)
        return '';
    const d = new Date();
    d.setDate(d.getDate() - back);
    return dayKey(d);
}

export function rangedDays(stats, rangeIdx) {
    if (!stats || !stats.days)
        return [];
    const cut = rangeCutoff(rangeIdx);
    return cut === '' ? stats.days : stats.days.filter(d => (d.date || '') >= cut);
}

// in_tok/out_tok por clave sobre los días → [{<nameKey>, in_tok, out_tok, tot, pct}] desc por total.
export function aggBy(days, listKey, nameKey) {
    const acc = {}, order = [];
    for (const day of days) {
        for (const it of day[listKey] || []) {
            const k = it[nameKey] || '?';
            if (!(k in acc)) {
                acc[k] = {inTok: 0, outTok: 0};
                order.push(k);
            }
            acc[k].inTok += it.in_tok || 0;
            acc[k].outTok += it.out_tok || 0;
        }
    }
    let grand = 0;
    for (const k of order)
        grand += acc[k].inTok + acc[k].outTok;
    const rows = order.map(k => {
        const tot = acc[k].inTok + acc[k].outTok;
        return {[nameKey]: k, in_tok: acc[k].inTok, out_tok: acc[k].outTok, tot,
            pct: grand > 0 ? tot * 100 / grand : 0};
    });
    rows.sort((a, b) => b.tot - a.tot);
    return rows;
}

export const sum = (days, key) => days.reduce((s, d) => s + (d[key] || 0), 0);

export function maxDayTokens(days) {
    return days.reduce((m, d) => Math.max(m, d.tokens || 0), 1);
}

export function maxDayProjectTokens(days) {
    return days.reduce((m, d) => Math.max(m, (d.projects || []).reduce((s, p) => s + (p.tokens || 0), 0)), 1);
}

export function rangedChats(chats, rangeIdx) {
    if (!chats)
        return [];
    const cut = rangeCutoff(rangeIdx);
    if (cut === '')
        return chats;
    return chats.filter(c => `${c.updated_at || c.created_at || ''}`.substring(0, 10) >= cut);
}

export function rangedSessionCount(sessions, rangeIdx) {
    if (!sessions)
        return 0;
    const cut = rangeCutoff(rangeIdx);
    if (cut === '')
        return sessions.length;
    return sessions.filter(s => `${s.updated_at || ''}`.substring(0, 10) >= cut).length;
}

export function chatsByModel(cs) {
    const total = cs.length;
    if (!total)
        return [];
    const counts = {}, order = [];
    for (const c of cs) {
        const k = c.model || '?';
        if (!(k in counts)) {
            counts[k] = 0;
            order.push(k);
        }
        counts[k]++;
    }
    return order.map(k => ({model: k, count: counts[k], pct: counts[k] * 100 / total}))
        .sort((a, b) => b.count - a.count);
}

// sessions.json ya viene ordenado por updated_at desc.
export function sessionsForProject(sessions, name) {
    return (sessions || []).filter(s => s.project === name).slice(0, 12);
}

export function sessionCountForProject(sessions, name) {
    return (sessions || []).filter(s => s.project === name).length;
}

export function streaks(stats) {
    if (!stats || !stats.days || !stats.days.length)
        return {cur: 0, max: 0};
    const set = {};
    for (const d of stats.days) {
        if (d.tokens > 0)
            set[d.date] = true;
    }
    const keys = Object.keys(set).sort();
    let longest = 0, run = 0, prev = null;
    for (const k of keys) {
        const t = Date.parse(k);
        run = prev !== null && t - prev === 86400000 ? run + 1 : 1;
        longest = Math.max(longest, run);
        prev = t;
    }
    let cur = 0;
    const d = new Date();
    if (!set[dayKey(d)])
        d.setDate(d.getDate() - 1);
    while (set[dayKey(d)]) {
        cur++;
        d.setDate(d.getDate() - 1);
    }
    return {cur, max: longest};
}

// Celdas del heatmap: rango continuo desde el primer día, alineado a domingo.
export function heatmapCells(stats) {
    if (!stats || !stats.days || !stats.days.length)
        return [];
    const m = {};
    let minT = null, maxT = null;
    for (const dd of stats.days) {
        m[dd.date] = dd.tokens;
        // Medianoche LOCAL: Date.parse('yyyy-MM-dd') es UTC y en husos negativos corría el último
        // día (hoy) fuera del heatmap. (El QML tiene el mismo bug.)
        const t = Date.parse(`${dd.date}T00:00:00`);
        if (minT === null || t < minT)
            minT = t;
        if (maxT === null || t > maxT)
            maxT = t;
    }
    const start = new Date(minT);
    start.setDate(start.getDate() - start.getDay());
    const end = new Date(maxT);
    const cells = [];
    for (const cur = new Date(start); cur <= end; cur.setDate(cur.getDate() + 1))
        cells.push({tokens: m[dayKey(cur)] || 0});
    return cells;
}
