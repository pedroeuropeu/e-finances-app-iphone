/* e-Finances iPhone · protótipo navegável (sem dependências): núcleo.
   Estado, dados derivados, componentes no padrão do iOS, camadas (folha, alerta, ações, menu, aviso), navegação em pilha
   com folha modal, gestos (deslizar, segurar) e tema. As telas ficam em screens-*.js e se registram em EF.S. */
'use strict';
(() => {
    const D = window.EF_DATA, ICONS = window.EF_ICONS || {};
    const EF = window.EF = {D, S: {}, ACT: {}};

    /* ============================== utilidades ============================== */
    const $ = (s, el = document) => el.querySelector(s);
    const $$ = (s, el = document) => [...el.querySelectorAll(s)];
    const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c]));
    const missing = new Set();
    const ic = (n, cls = '') => {
        if (!ICONS[n] && !missing.has(n)) { missing.add(n); console.warn('ícone ausente:', n); }
        return `<svg class="ic ${cls}" viewBox="0 0 24 24" aria-hidden="true">${ICONS[n] || ICONS.circle || ''}</svg>`;
    };
    const BRL = new Intl.NumberFormat('pt-BR', {style: 'currency', currency: 'BRL'});
    const CMP = new Intl.NumberFormat('pt-BR', {notation: 'compact', maximumFractionDigits: 1});
    const fmt = v => BRL.format(v).replace(/\s/g, ' ');
    const sum = (a, f = t => t.value) => a.reduce((s, t) => s + f(t), 0);
    const pct = (a, b) => b ? Math.round(a / b * 100) : 0;
    const pad = n => String(n).padStart(2, '0');
    const norm = s => String(s || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
    const initials = name => { const w = (name || '').trim().split(/\s+/); return (w.length > 1 ? w[0][0] + w[1][0] : w[0].slice(0, 2)).toUpperCase(); };
    const goAttr = (id, p) => `data-go="${id}"${p ? ` data-p='${esc(JSON.stringify(p))}'` : ''}`;
    const plural = (n, one, many) => `${n} ${n === 1 ? one : many}`;

    const TODAY = new Date(2026, 9, 11);
    const BASE = {y: 2026, m: 9};
    const MONTHS = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
    const MON = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    const WEEK = ['domingo', 'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado'];
    const cap = s => s.charAt(0).toUpperCase() + s.slice(1);
    const parse = s => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };
    const iso = d => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
    const dm = s => { const d = parse(s); return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}`; };
    const dmy = s => `${dm(s)}/${parse(s).getFullYear()}`;
    const days = s => Math.round((parse(s) - TODAY) / 864e5);
    const addMonths = (s, n) => { const d = parse(s); const day = d.getDate(); const r = new Date(d.getFullYear(), d.getMonth() + n, 1); r.setDate(Math.min(day, new Date(r.getFullYear(), r.getMonth() + 1, 0).getDate())); return iso(r); };
    const monthLabel = s => { const d = parse(s); return `${MON[d.getMonth()]}/${d.getFullYear()}`; };
    const longDate = d => `${WEEK[d.getDay()]}, ${d.getDate()} de ${MONTHS[d.getMonth()]}`;
    const greeting = () => { const h = new Date().getHours(); return h < 12 ? 'Bom dia' : h < 18 ? 'Boa tarde' : 'Boa noite'; };
    const rnd = s => { let h = 2166136261; for (const c of s) { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619); } return ((h >>> 0) % 10000) / 10000; };

    const TYPES = {R: 'Recebimento', F: 'Despesa fixa', V: 'Despesa variável'};
    const TYPES_PL = {R: 'Recebimentos', F: 'Despesas fixas', V: 'Despesas variáveis'};
    const PAY = {DINHEIRO: 'Dinheiro', CARTAO_CREDITO: 'Cartão de crédito', CARTAO_DEBITO: 'Cartão de débito', BOLETO_BANCARIO: 'Boleto bancário',
        TED: 'Transferência (TED/Pix)', DEBITO_AUTOMATICO: 'Débito automático', CHECK: 'Cheque', PROMISSORIA: 'Promissória'};
    const PAY_ICON = {DINHEIRO: 'banknote', CARTAO_CREDITO: 'credit-card', CARTAO_DEBITO: 'credit-card', BOLETO_BANCARIO: 'receipt',
        TED: 'arrow-left-right', DEBITO_AUTOMATICO: 'repeat', CHECK: 'file-text', PROMISSORIA: 'file-text'};
    const MODE = {ONE_TIME: 'À vista', MANY_TIMES: 'Parcelado', REPEATABLE: 'Recorrente'};
    const REC = {FORTNIGHTLY: 'Quinzenal', MONTHLY: 'Mensal', BIMONTHLY: 'Bimestral', QUARTERLY: 'Trimestral', SEMESTER: 'Semestral', YEARLY: 'Anual'};
    const REC_STEP = {FORTNIGHTLY: .5, MONTHLY: 1, BIMONTHLY: 2, QUARTERLY: 3, SEMESTER: 6, YEARLY: 12};
    const CONTACT_CAT = {CLIENT: 'Cliente', SUPPLIER: 'Fornecedor', WORKER: 'Funcionário'};
    const CONTACT_COLOR = {CLIENT: '#059669', SUPPLIER: '#1D4E89', WORKER: '#7C3AED'};
    const NCAT = {LIMIT: ['Limites', 'flag'], PAYMENT: ['Pagamentos', 'credit-card'], SUPPORT: ['Suporte', 'headset'], SECURITY: ['Segurança', 'shield-check'], SYSTEM: ['Sistema', 'bell']};
    const NSEV = {DANGER: '#DC2626', WARNING: '#D97706', SUCCESS: '#059669', INFO: '#2563EB'};

    const markSvg = (onDark) => `<svg viewBox="0 0 120 120" aria-hidden="true"><circle cx="60" cy="60" r="56" fill="${onDark ? '#16304F' : '#0B2545'}"/><path d="M84 60 A24 24 0 1 0 77 77" fill="none" stroke="#FFFFFF" stroke-width="11" stroke-linecap="round"/><path d="M36 60 H84" fill="none" stroke="#10B981" stroke-width="11" stroke-linecap="round"/></svg>`;
    const appIcon = (bg = '#0B2545', fg = '#FFFFFF', bar = '#10B981') => `<svg viewBox="0 0 120 120" aria-hidden="true"><path d="M84 60 A24 24 0 1 0 77 77" fill="none" stroke="${fg}" stroke-width="12" stroke-linecap="round"/><path d="M36 60 H84" fill="none" stroke="${bar}" stroke-width="12" stroke-linecap="round"/></svg>`;
    const WM = '<svg class="wm" viewBox="0 0 120 120" aria-hidden="true"><circle cx="60" cy="60" r="54" fill="none" stroke="#fff" stroke-width="5"/><path d="M84 60 A24 24 0 1 0 77 77" fill="none" stroke="#fff" stroke-width="9" stroke-linecap="round"/><path d="M36 60 H84" fill="none" stroke="#fff" stroke-width="9" stroke-linecap="round"/></svg>';
    const FACEID = '<svg class="faceid" viewBox="0 0 64 64" aria-hidden="true"><path d="M6 20V12a6 6 0 0 1 6-6h8M44 6h8a6 6 0 0 1 6 6v8M58 44v8a6 6 0 0 1-6 6h-8M20 58h-8a6 6 0 0 1-6-6v-8"/><path d="M22 24v5M42 24v5M32 24v12h-3M24 44c4.5 4 11.5 4 16 0"/></svg>';

    /* ============================== estado ============================== */
    const state = {
        stack: [], hide: false, theme: 'system', adj: {}, nextId: 1000,
        ws: {company: 1, account: 'cc'},
        month: {...BASE},
        tx: D.tx.map(t => ({...t, acct: t.acct || 'cc', base: true})),
        gen: {},
        f: {kind: 'all', status: null, q: '', cat: null},
        sel: null,
        planTab: 'limits',
        notifs: D.notifications.map(n => ({...n})),
        notifTab: 'all', notifCat: null,
        limits: D.limits.map(l => ({...l})),
        ob: 0,
        rep: {period: 6, by: 'cat', ctype: 'all'},
        ccat: 'all', catf: 'all', catq: '', cq: '',
        agendaDay: 11,
        prefs: {push: true, email: true, sms: false, due: true, limit: true, payment: true, support: true, security: true, when: 'now', story: 'MONTHLY',
            bio: true, lock: '5', blur: true, hideOnOpen: false, lang: 'pt', keep: true, icon: 'navy', widgetPaid: false},
        planPeriod: 'MONTHLY', planPick: 'PREMIUN',
        draft: null, pickFor: null, bankFilter: 30, bankKind: 'all', openFaq: -1, ticketCat: 'DUVIDA', showPass: false, accepted: true,
        deletion: null, stars: 5, cut: {}
    };

    /* ============================== dados derivados ============================== */
    const company = (id = state.ws.company) => D.companies.find(c => c.id === id);
    const allAccounts = () => D.companies.flatMap(c => c.accounts.map(a => ({...a, co: c})));
    const findAcct = id => allAccounts().find(a => a.id === id);
    const account = () => company().accounts.find(a => a.id === state.ws.account) || company().accounts[0];
    const acctBalance = a => a.balance + (state.adj[a.id] || 0);
    const balance = () => acctBalance(account());
    const bankOf = a => a && a.bank ? D.banks.find(b => b.id === a.bank) : null;
    const modeNow = () => account().mode;
    const catOf = t => D.categories[t.cat] || {name: 'Sem categoria', icon: 'tag', color: '#94A3B8', none: true};
    const inMonth = (t, y, m) => { const d = parse(t.date); return d.getFullYear() === y && d.getMonth() === m; };
    const isBase = (y, m) => y === BASE.y && m === BASE.m;
    const endsBefore = (t, y, m) => { if (!t.ends) return false; const [mm, yy] = t.ends.split('/'); const em = MON.indexOf(mm), ey = +yy; return y > ey || (y === ey && m > em); };
    const locked = t => t.src === 'BANK';
    const frozen = t => (findAcct(t.acct) || {}).mode === 'FROZEN';

    function genMonth(y, m, acct) {
        const diff = (y - BASE.y) * 12 + (m - BASE.m);
        const out = [];
        for (const t of D.tx) {
            if ((t.acct || 'cc') !== acct) continue;
            if (t.src === 'BANK' && (diff >= 0 || acct === 'it-old')) continue;
            if (endsBefore(t, y, m)) continue;
            if (state.cut[t.id] !== undefined && iso(new Date(y, m, 1)) > state.cut[t.id]) continue;
            let plot = t.plot, desc = t.desc, value = t.value;
            const r = rnd(`${t.id}-${y}-${m}`);
            if (t.mode === 'MANY_TIMES' || t.plot) {
                const [n, N] = t.plot.split('/').map(Number);
                const k = n + diff;
                if (k < 1 || k > N) continue;
                plot = `${k}/${N}`;
            }
            if (t.id === 1) desc = `Salário de ${MONTHS[m]}`;
            if (t.id === 2) { if (r < .35) continue; desc = 'Projeto freelance'; value = Math.round(600 + r * 2400); }
            if (t.id === 21 && r < .5) continue;
            if (t.id === 25 && r < .4) continue;
            if (t.type === 'V' && !t.plot) value = Math.round(t.value * (.6 + r * .8) * 100) / 100;
            if (t.cat === 'contas') value = Math.round(t.value * (.85 + r * .3) * 100) / 100;
            const day = Math.min(parse(t.date).getDate(), new Date(y, m + 1, 0).getDate());
            out.push({...t, acct, id: `${t.id}-${y}-${m}`, desc, value, plot, date: iso(new Date(y, m, day)), paid: diff < 0, base: false, gen: true, files: diff < 0 ? t.files : 0});
        }
        return out;
    }
    function monthTx(y, m, acct = state.ws.account) {
        const own = state.tx.filter(t => t.acct === acct && inMonth(t, y, m));
        if (isBase(y, m)) return own;
        const k = `${acct}-${y}-${m}`;
        if (!state.gen[k]) state.gen[k] = genMonth(y, m, acct);
        return state.gen[k].concat(own);
    }
    const allTx = () => state.tx.concat(...Object.values(state.gen));
    const findTx = id => allTx().find(t => String(t.id) === String(id));
    function removeTx(id) {
        const t = findTx(id);
        state.tx = state.tx.filter(x => String(x.id) !== String(id));
        for (const k in state.gen) state.gen[k] = state.gen[k].filter(x => String(x.id) !== String(id));
        return t;
    }
    function restoreTx(t) { if (!findTx(t.id)) state.tx.push(t); }
    function totals(list) {
        const r = list.filter(t => t.type === 'R'), e = list.filter(t => t.type !== 'R');
        return {inc: sum(r), incPaid: sum(r.filter(t => t.paid)), exp: sum(e), expPaid: sum(e.filter(t => t.paid))};
    }
    function status(t) {
        const R = t.type === 'R';
        if (t.paid) return {k: 'paid', label: R ? 'Recebido' : 'Pago'};
        const d = days(t.date);
        if (d < 0) return {k: 'late', label: `Atrasada há ${plural(-d, 'dia', 'dias')}`};
        if (d === 0) return {k: 'soon', label: R ? 'Recebe hoje' : 'Vence hoje'};
        if (d === 1) return {k: 'soon', label: R ? 'Recebe amanhã' : 'Vence amanhã'};
        if (d <= 7) return {k: 'soon', label: `${R ? 'Recebe' : 'Vence'} em ${d} dias`};
        return {k: 'sched', label: `${R ? 'Recebe' : 'Vence'} ${dm(t.date)}`};
    }
    function byCategory(list) {
        const total = sum(list) || 1, map = {};
        list.forEach(t => { map[t.cat || '_'] = (map[t.cat || '_'] || 0) + t.value; });
        return Object.entries(map).map(([k, v]) => ({key: k, ...(D.categories[k] || {name: 'Sem categoria', color: '#94A3B8', icon: 'tag'}), v, pct: Math.round(v / total * 100)}))
            .sort((a, b) => b.v - a.v);
    }
    function groupBy(list, keyFn, labelFn, colorFn) {
        const total = sum(list) || 1, map = {};
        list.forEach(t => { const k = keyFn(t) || '—'; map[k] = (map[k] || 0) + t.value; });
        return Object.entries(map).map(([k, v], i) => ({key: k, name: labelFn(k), color: colorFn(k, i), v, pct: Math.round(v / total * 100)})).sort((a, b) => b.v - a.v);
    }
    function limitRows(y = BASE.y, m = BASE.m) {
        const exp = monthTx(y, m, 'cc').filter(t => t.type !== 'R');
        return state.limits.map(l => {
            const spent = sum(exp.filter(t => t.cat === l.cat));
            const p = spent / l.limit * 100;
            return {...l, spent, p, status: p >= 100 ? 'over' : p >= l.alertPct ? 'warn' : 'ok'};
        });
    }
    const avg3 = cat => { let s = 0; for (let i = 1; i <= 3; i++) { const d = new Date(BASE.y, BASE.m - i, 1); s += sum(monthTx(d.getFullYear(), d.getMonth(), 'cc').filter(t => t.type !== 'R' && t.cat === cat)); } return s / 3; };
    const yearFlow = (acct = state.ws.account) => Array.from({length: 12}, (_, m) => { const T = totals(monthTx(BASE.y, m, acct)); return {label: MON[m][0].toUpperCase(), name: MONTHS[m], inc: T.inc, exp: T.exp, proj: m > BASE.m}; });
    const subsMonthly = () => sum(D.subscriptions, s => s.freq === 'YEARLY' ? s.value / 12 : s.value);
    function setPaid(t, v) {
        if (t.paid === v) return;
        t.paid = v;
        if (t.base || inMonth(t, BASE.y, BASE.m)) state.adj[t.acct] = (state.adj[t.acct] || 0) + (t.type === 'R' ? t.value : -t.value) * (v ? 1 : -1);
    }
    const bankAccounts = () => D.banks.flatMap(b => b.accounts.map(a => ({...a, bank: b})));
    const bankTotals = () => { const acc = bankAccounts(), cr = acc.filter(a => a.kind === 'CREDIT'); return {bal: sum(acc.filter(a => a.kind === 'BANK'), a => a.balance), inv: sum(cr, a => a.invoice), avail: sum(cr, a => a.available), limit: sum(cr, a => a.limit), n: acc.length}; };

    /* ============================== componentes ============================== */
    const money = v => state.hide ? 'R$ ••••' : fmt(v);
    const signed = (v, type) => state.hide ? 'R$ ••••' : (type === 'R' ? '+ ' : '− ') + fmt(Math.abs(v));
    const bigMoney = v => { if (state.hide) return 'R$ ••••••'; const s = fmt(v); const i = s.lastIndexOf(','); return `${s.slice(0, i)}<small>${s.slice(i)}</small>`; };
    const compactMoney = v => state.hide ? '••••' : `R$ ${CMP.format(v)}`;

    /** Barra de navegação do iOS: botões em vidro à esquerda e à direita; o título pequeno aparece ao rolar quando há título grande. */
    function navb({title = '', sub = '', back = true, close = false, left = '', right = '', large = false, solid = false} = {}) {
        const bk = back ? `<button class="gb glass" data-back aria-label="${close ? 'Fechar' : 'Voltar'}">${ic(close ? 'x' : 'chevron-left')}</button>` : '';
        return `<header class="navb${large ? ' lt-mode' : ''}${solid ? ' solid' : ''}" data-nav><div class="nl">${bk}${left}</div><div class="nt">${title}${sub ? `<small>${sub}</small>` : ''}</div><div class="nr">${right}</div></header>`;
    }
    const largeTitle = (title, sub = '', extra = '') => `<div class="lt"><div style="min-width:0"><h1>${title}</h1>${sub ? `<p>${sub}</p>` : ''}</div>${extra}</div>`;
    const gbtn = (icon, attrs, label, cls = '') => `<button class="gb glass ${cls}" ${attrs} aria-label="${label}">${ic(icon)}</button>`;
    const gtxt = (label, attrs, cls = '') => `<button class="gb glass txt ${cls}" ${attrs}>${label}</button>`;
    const gbs = (...btns) => `<span class="gbs glass">${btns.map(([icon, attrs, label, extra = '']) => `<button class="gb" ${attrs} aria-label="${label}">${ic(icon)}${extra}</button>`).join('')}</span>`;
    const TABS = [['home', 'Início', 'house'], ['tx', 'Transações', 'receipt-text'], ['banks', 'Contas', 'landmark'], ['plan', 'Planejar', 'piggy-bank'], ['more', 'Mais', 'ellipsis']];
    const tabbar = cur => `<nav class="tabbar glass" aria-label="Navegação principal">${TABS.map(([id, l, i]) => `<button class="${id === cur ? 'on' : ''}" data-tab="${id}" aria-current="${id === cur ? 'page' : 'false'}">${ic(i)}${l}</button>`).join('')}</nav>`;
    const sh = (title, sub = '', link = '') => `<div class="sh"><h2>${title}${sub ? `<small>${sub}</small>` : ''}</h2>${link}</div>`;
    const shSmall = title => `<div class="sh small"><h3>${title}</h3></div>`;
    const linkBtn = (label, attrs) => `<button class="link" ${attrs}>${label}${ic('chevron-right')}</button>`;
    const tg = on => `<span class="tg ${on ? 'on' : ''}" aria-hidden="true"></span>`;
    const seg = (items, cur, act, cls = '') => `<div class="seg ${cls}" role="tablist">${items.map(([k, l]) => `<button class="${cur === k ? 'on' : ''}" data-act="${act}" data-v="${k}" role="tab" aria-selected="${cur === k}">${l}</button>`).join('')}</div>`;
    const catAv = (c, cls = '') => c.brand
        ? `<span class="av solid ${cls}" style="--c:${c.brand.color};--fg:${c.brand.fg || '#FFFFFF'}">${c.brand.short}</span>`
        : `<span class="av ${cls}" style="--c:${c.color}">${ic(c.icon)}</span>`;
    const bankAv = (b, cls = '') => `<span class="av solid sq ${cls}" style="--c:${b.color}">${b.short}</span>`;
    function acctAv(a, cls = '') {
        if (a.mode === 'BANK') { const b = D.banks.find(x => x.id === a.bank); return `<span class="av solid sq ${cls}" style="--c:${b.color}">${b.short}<span class="badge-mini">${ic(a.kind === 'CREDIT' ? 'credit-card' : 'link')}</span></span>`; }
        if (a.mode === 'FROZEN') return `<span class="av solid sq ${cls}" style="--c:${a.bankColor};opacity:.75">${a.bankShort}<span class="badge-mini">${ic('snowflake')}</span></span>`;
        const co = a.co || D.companies.find(c => c.accounts.some(x => x.id === a.id));
        return `<span class="av sq ${cls}" style="--c:${co.color}">${ic('wallet')}</span>`;
    }
    const si = (icon, color) => `<span class="si" style="--c:${color}">${ic(icon)}</span>`;
    const modeTag = a => a.mode === 'BANK' ? '<span class="tag navy">Do banco</span>' : a.mode === 'FROZEN' ? `<span class="tag">${ic('snowflake')}Congelada</span>` : '';

    /** Linha de lançamento com ações de deslizar (direita: pagar; esquerda: mais e excluir, ou organizar). */
    function txItem(t, {swipe = true} = {}) {
        const c = catOf(t), s = status(t), selMode = !!state.sel, picked = selMode && state.sel.has(String(t.id));
        const fz = frozen(t), lk = locked(t), canPay = !lk && !fz;
        const lead = swipe && canPay && !selMode ? `<div class="swa l"><button class="${t.paid ? 'gray' : 'green'}" data-act="togglePaid" data-id="${t.id}">${ic(t.paid ? 'rotate-ccw' : 'check')}${t.paid ? 'Pendente' : t.type === 'R' ? 'Recebido' : 'Pago'}</button></div>` : '';
        const trail = swipe && !fz && !selMode ? (lk
            ? `<div class="swa r"><button class="navy" data-act="organize" data-id="${t.id}">${ic('tags')}Organizar</button></div>`
            : `<div class="swa r"><button class="gray" data-act="txMore" data-id="${t.id}">${ic('ellipsis')}Mais</button><button class="red" data-act="delTx" data-id="${t.id}">${ic('trash-2')}Excluir</button></div>`) : '';
        const lead2 = selMode ? `<span class="cbx ${picked ? 'on' : ''}">${picked ? ic('check') : ''}</span>` : '';
        const end = selMode ? '' : canPay
            ? `<button class="pay${t.paid ? ' done' : ''}" data-act="togglePaid" data-id="${t.id}" aria-label="${t.paid ? 'Voltar para pendente' : t.type === 'R' ? 'Marcar como recebido' : 'Marcar como pago'}">${ic(t.paid ? 'circle-check' : 'circle')}</button>`
            : `<span class="pay" aria-label="${fz ? 'Conta congelada: só consulta' : 'Veio do banco'}">${ic(fz ? 'snowflake' : 'lock', 'lock')}</span>`;
        const sub = lk ? `${t.paid ? dm(t.date) : s.label} · ${esc(c.name)}` : `<b class="sk ${s.k}">${s.label}${t.paid ? ' ' + dm(t.date) : ''}</b> · ${esc(c.name)}`;
        return `<div class="sw" data-sw="${t.id}">${lead}${trail}<div class="row txi${selMode ? ' selmode' : ''}" role="button" tabindex="0" data-tx="${t.id}">
            ${lead2}${catAv(c)}
            <span class="rt"><span class="t">${esc(t.desc)}${t.plot ? ` <span class="tag">${t.plot}</span>` : ''}${t.files ? ic('paperclip', 'clip') : ''}</span><span class="s">${sub}</span></span>
            <span class="rv num ${t.type === 'R' ? 'in' : ''}">${signed(t.value, t.type)}</span>${end}
        </div></div>`;
    }

    function pring(paid, total, size = 46) {
        const r = 19, C = 2 * Math.PI * r, f = Math.min(paid / total, 1);
        return `<svg class="pring" viewBox="0 0 46 46" style="width:${size}px;height:${size}px;flex:none" aria-label="${paid} de ${total} parcelas pagas" role="img"><circle cx="23" cy="23" r="${r}" fill="none" style="stroke:var(--fill)" stroke-width="5"/><circle cx="23" cy="23" r="${r}" fill="none" style="stroke:var(--accent)" stroke-width="5" stroke-linecap="round" stroke-dasharray="${(f * C).toFixed(1)} ${C.toFixed(1)}" transform="rotate(-90 23 23)"/><text x="23" y="27" text-anchor="middle">${paid}/${total}</text></svg>`;
    }
    function donut(parts, label, value, size = 128) {
        const sw = 16, r = (size - sw) / 2, C = 2 * Math.PI * r, total = sum(parts, p => p.v) || 1, c = size / 2;
        let off = 0;
        const segs = parts.map(p => {
            const len = p.v / total * C, gap = parts.length > 1 ? Math.min(2.5, len / 3) : 0;
            const out = `<circle cx="${c}" cy="${c}" r="${r}" fill="none" style="stroke:${p.c}" stroke-width="${sw}" stroke-linecap="butt" stroke-dasharray="${Math.max(len - gap, .01).toFixed(2)} ${C.toFixed(2)}" stroke-dashoffset="${(-off).toFixed(2)}" transform="rotate(-90 ${c} ${c})"/>`;
            off += len;
            return out;
        }).join('');
        return `<div class="dn" style="width:${size}px;height:${size}px"><svg viewBox="0 0 ${size} ${size}" aria-hidden="true"><circle cx="${c}" cy="${c}" r="${r}" fill="none" style="stroke:var(--fill)" stroke-width="${sw}"/>${segs}</svg><div class="dc"><small>${label}</small><b class="num">${value}</b></div></div>`;
    }
    function niceMax(v) { if (v <= 0) return 1; const p = 10 ** Math.floor(Math.log10(v)); const m = v / p; return (m <= 1 ? 1 : m <= 2 ? 2 : m <= 2.5 ? 2.5 : m <= 5 ? 5 : 10) * p; }
    function barChart(rows, {h = 160} = {}) {
        const W = 338, H = h, L = 34, B = 20, T = 8;
        const max = niceMax(Math.max(...rows.flatMap(r => [r.inc, r.exp]), 1));
        const n = rows.length, gw = (W - L) / n, bw = Math.max(3, Math.min(11, gw * .3));
        const y = v => T + (H - T - B) * (1 - v / max);
        let g = '';
        [0, .5, 1].forEach(f => {
            const yy = y(max * f).toFixed(1);
            g += `<line x1="${L}" x2="${W}" y1="${yy}" y2="${yy}" style="stroke:var(--sep)" stroke-width="1"${f ? ' stroke-dasharray="3 4"' : ''}/>`;
            if (!state.hide) g += `<text x="${L - 6}" y="${(+yy + 3.5).toFixed(1)}" text-anchor="end">${f ? CMP.format(max * f) : '0'}</text>`;
        });
        rows.forEach((r, i) => {
            const cx = L + gw * i + gw / 2, op = r.proj ? ' opacity=".35"' : '';
            const hi = Math.max(H - B - y(r.inc), r.inc ? 2 : 0), he = Math.max(H - B - y(r.exp), r.exp ? 2 : 0);
            g += `<rect x="${(cx - bw - 1).toFixed(1)}" y="${(H - B - hi).toFixed(1)}" width="${bw.toFixed(1)}" height="${hi.toFixed(1)}" rx="3" style="fill:var(--accent)"${op}><title>${r.name || r.label}: receitas ${fmt(r.inc)}</title></rect>`;
            g += `<rect x="${(cx + 1).toFixed(1)}" y="${(H - B - he).toFixed(1)}" width="${bw.toFixed(1)}" height="${he.toFixed(1)}" rx="3" style="fill:var(--expense)"${op}><title>${r.name || r.label}: despesas ${fmt(r.exp)}</title></rect>`;
            g += `<text x="${cx.toFixed(1)}" y="${H - 5}" text-anchor="middle">${r.label}</text>`;
        });
        return `<svg class="chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="Receitas e despesas por mês">${g}</svg>`;
    }
    function limRow(l, full = false) {
        const c = D.categories[l.cat];
        const sub = l.status === 'over' ? `Passou ${money(l.spent - l.limit)}` : `Ainda dá ${money(l.limit - l.spent)} · aviso em ${l.alertPct}%`;
        return `<button class="limr" data-act="limitSheet" data-cat="${l.cat}">
            <span class="head">${catAv(c, 'sm')}<span class="grow"><b>${c.name}</b><small class="num">${money(l.spent)} de ${money(l.limit)}</small></span><span class="lp ${l.status}">${Math.round(l.p)}%</span></span>
            <span class="prog ${l.status}"><i style="width:${Math.min(l.p, 100).toFixed(1)}%"></i></span>
            ${full ? `<span class="lsub ${l.status}">${ic(l.status === 'over' ? 'circle-alert' : l.status === 'warn' ? 'triangle-alert' : 'circle-check')}${sub}</span>` : ''}
        </button>`;
    }
    const kpi = (k, v, cls = '', d = '') => `<div class="kpi"><span class="k">${k}</span><span class="v num ${cls}">${v}</span>${d}</div>`;
    const delta = (cur, prev, goodUp = true) => {
        if (!prev) return '<span class="d">—</span>';
        const p = Math.round((cur - prev) / Math.abs(prev) * 100);
        const good = goodUp ? p >= 0 : p <= 0;
        return `<span class="d ${p === 0 ? '' : good ? 'up' : 'down'}">${ic(p >= 0 ? 'arrow-up' : 'arrow-down')}${Math.abs(p)}% vs. anterior</span>`;
    };
    /** Calendário do mês. dayFn(d) devolve {cls, dots:[cor], h:0-100} para cada dia. */
    function calendar(y, m, {sel = null, act = 'agendaDay', dayFn = () => ({}), heat = false} = {}) {
        const first = new Date(y, m, 1).getDay(), n = new Date(y, m + 1, 0).getDate();
        let h = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'].map(w => `<span class="wd">${w}</span>`).join('');
        for (let i = 0; i < first; i++) h += '<span></span>';
        for (let d = 1; d <= n; d++) {
            const info = dayFn(d) || {}, today = y === TODAY.getFullYear() && m === TODAY.getMonth() && d === TODAY.getDate();
            h += `<button class="${today ? 'today' : ''} ${sel === d ? 'sel' : ''} ${info.cls || ''}" data-act="${act}" data-d="${d}" ${heat ? `style="--h:${Math.round(info.h || 0)}"` : ''} aria-label="${d} de ${MONTHS[m]}"><span>${d}</span><span class="dots">${(info.dots || []).map(c => `<i style="--c:${c}"></i>`).join('')}</span></button>`;
        }
        return `<div class="cal${heat ? ' heat' : ''}">${h}</div>`;
    }

    /* ============================== camadas ============================== */
    const ovl = () => $('#ovl');
    function openOv(html) {
        const o = ovl();
        clearTimeout(state.ovT);
        o.innerHTML = html;
        o.offsetHeight; o.classList.add('open');
    }
    function closeOv() {
        const o = ovl();
        if (!o.classList.contains('open')) return;
        o.classList.remove('open');
        $$('.txi.lifted').forEach(r => r.classList.remove('lifted'));
        state.ovT = setTimeout(() => { if (!o.classList.contains('open')) o.innerHTML = ''; }, 420);
    }
    /** Folha (sheet) do iOS: alça, cabeçalho com X e ação, conteúdo e rodapé. large = altura cheia. */
    function sheet({title = '', sub = '', body = '', foot = '', left, right = '', large = false, flush = false} = {}) {
        const l = left ?? `<button class="gb glass" data-act="closeOv" aria-label="Fechar">${ic('x')}</button>`;
        openOv(`<div class="scrim" data-act="closeOv"></div><div class="sheet${large ? ' large' : ''}" role="dialog" aria-modal="true" aria-label="${esc(title)}"><div class="grab" data-grab></div>
            <div class="shh" data-grab><div>${l}</div><h3>${title}${sub ? `<small>${sub}</small>` : ''}</h3><div class="nr">${right}</div></div>
            <div class="shb${flush ? ' flush' : ''}">${body}</div>${foot ? `<div class="shf">${foot}</div>` : ''}</div>`);
    }
    /** Alerta do iOS 26: texto alinhado à esquerda e botões em cápsula. buttons: [{label, cls, fn}] */
    function alertBox({title, text = '', buttons = [], col = false}) {
        state.alertFns = buttons.map(b => b.fn);
        openOv(`<div class="scrim"></div><div class="alrt" role="alertdialog" aria-modal="true" aria-label="${esc(title)}"><h3>${title}</h3>${text ? `<p>${text}</p>` : ''}
            <div class="ab-row${col || buttons.length > 2 ? ' col' : ''}">${buttons.map((b, i) => `<button class="ab ${b.cls || ''}" data-act="alertBtn" data-i="${i}">${b.label}</button>`).join('')}</div></div>`);
    }
    /** Ações (confirmationDialog): lista de opções e Cancelar. items: [{label, icon, red, fn, sub}] */
    function actionSheet({title = '', text = '', items = []}) {
        state.asFns = items.map(i => i.fn);
        openOv(`<div class="scrim" data-act="closeOv"></div><div class="asheet" role="dialog" aria-modal="true"><div class="box">${title || text ? `<div class="hd">${title ? `<b>${title}</b>` : ''}${text ? `<span>${text}</span>` : ''}</div>` : ''}
            ${items.map((it, i) => `<button class="${it.red ? 'red' : ''}" data-act="asBtn" data-i="${i}">${it.icon ? ic(it.icon) : ''}${it.label}</button>`).join('')}</div>
            <div class="box"><button class="cancel" data-act="closeOv">Cancelar</button></div></div>`);
    }
    /** Menu de contexto (toque longo): a linha sobe e o menu aparece abaixo ou acima dela. */
    function contextMenu(anchor, items) {
        state.cmFns = items.filter(i => i.label).map(i => i.fn);
        const app = $('#app'), ar = app.getBoundingClientRect(), r = anchor.getBoundingClientRect(), k = ar.width / app.offsetWidth;
        const top = (r.bottom - ar.top) / k + 8, h = items.length * 44 + 14, roomBelow = app.offsetHeight - top - 40;
        const y = roomBelow > h ? top : Math.max(70, (r.top - ar.top) / k - h - 8);
        const x = Math.min(app.offsetWidth - 274, Math.max(16, (r.left - ar.left) / k + 16));
        let i = 0;
        const ghost = anchor.classList.contains('txi') ? `<div class="ghost-row" aria-hidden="true" style="left:${(r.left - ar.left) / k}px;top:${(r.top - ar.top) / k}px;width:${r.width / k}px;pointer-events:none">${anchor.outerHTML.replace(' lifted', '')}</div>` : '';
        openOv(`<div class="scrim" data-act="closeOv" style="backdrop-filter:blur(6px);-webkit-backdrop-filter:blur(6px)"></div>${ghost}<div class="cmenu" role="menu" style="left:${x}px;top:${y}px;transform-origin:${roomBelow > h ? 'top' : 'bottom'} left">
            ${items.map(it => it.label ? `<button role="menuitem" class="${it.red ? 'red' : ''}" data-act="cmBtn" data-i="${i++}" ${it.disabled ? 'disabled' : ''}>${ic(it.icon)}${it.label}</button>` : it.header ? `<div class="mh">${it.header}</div>` : '<hr>').join('')}</div>`);
    }
    function toast(msg, {action, fn, icon} = {}) {
        const s = $('#toast'), def = EF.S[cur().id];
        s.innerHTML = `${icon ? ic(icon) : ''}<span>${msg}</span>${action ? `<button data-act="toastAct">${action}</button>` : ''}`;
        s.classList.toggle('noact', !action);
        state.toastFn = fn;
        s.classList.toggle('low', !(def && def.root) || !!state.sel);
        s.classList.add('show');
        clearTimeout(state.toastT);
        state.toastT = setTimeout(() => s.classList.remove('show'), action ? 5000 : 2800);
    }

    /* ============================== navegação ============================== */
    const cur = () => state.stack[state.stack.length - 1];
    function build(id, p) { const def = EF.S[id]; return def.render(p || {}) + (def.root && !state.sel ? tabbar(def.tab) : ''); }
    function makeEl(c) {
        const def = EF.S[c.id], el = document.createElement('div');
        el.className = 'scr' + (def.root ? ' root' : '') + (def.modal ? ' modal' : '') + (def.cover ? ' cover' : '') + (def.bare ? ' bare' : '');
        el.innerHTML = build(c.id, c.params);
        return el;
    }
    function show(anim) {
        const c = cur(), def = EF.S[c.id], views = $('#views'), old = state.curEl;
        const el = makeEl(c);
        const pushModal = def.modal && anim === 'up' && old;
        if (old) {
            old._cleanup && old._cleanup();
            if (pushModal) { old.classList.add('under'); state.underEl = old; }
            else {
                const out = {push: 'out-push', pop: 'out-pop', fade: 'out-fade'}[anim] || 'out-fade';
                old.classList.add(out); old.style.pointerEvents = 'none';
                setTimeout(() => old.remove(), 440);
                if (state.underEl) { const u = state.underEl; state.underEl = null; u.classList.add('out-fade'); setTimeout(() => u.remove(), 300); }
            }
        }
        const inn = {push: 'in-push', pop: 'in-pop', fade: 'in-fade', up: 'in-up'}[anim];
        if (inn && old) el.classList.add(inn);
        if (anim === 'pop') views.insertBefore(el, old || null); else views.appendChild(el);
        state.curEl = el;
        afterRender(el, c);
        closeOv();
        $('#toast').classList.remove('show');
        $('#app').classList.toggle('sb-light', !!def.light);
        EF.syncProto && EF.syncProto();
    }
    function afterRender(el, c) {
        const sc = $('.scroll', el);
        if (sc) onScroll(sc);
        const def = EF.S[c.id];
        def.mount && def.mount(el, c.params || {});
    }
    function refresh({focus} = {}) {
        const c = cur(), el = state.curEl, sc = $('.scroll', el), y = sc ? sc.scrollTop : 0;
        el._cleanup && el._cleanup();
        const def = EF.S[c.id];
        el.className = 'scr' + (def.root ? ' root' : '') + (def.modal ? ' modal' : '') + (def.cover ? ' cover' : '') + (def.bare ? ' bare' : '');
        el.innerHTML = build(c.id, c.params);
        const sc2 = $('.scroll', el);
        if (sc2) { sc2.style.scrollBehavior = 'auto'; sc2.scrollTop = y; sc2.style.scrollBehavior = ''; }
        afterRender(el, c);
        if (focus) { const f = $(focus, el); if (f) { f.focus(); const v = f.value; f.value = ''; f.value = v; } }
    }
    function go(id, params = {}, anim) {
        state.sel = null;
        state.stack.push({id, params});
        show(anim || (EF.S[id].modal ? 'up' : 'push'));
    }
    function replace(id, params = {}) { state.stack[state.stack.length - 1] = {id, params}; show('fade'); }
    function dismissModal() {
        const m = state.curEl, u = state.underEl;
        state.underEl = null;
        m._cleanup && m._cleanup();
        m.classList.remove('in-up'); m.classList.add('out-down'); m.style.pointerEvents = 'none';
        setTimeout(() => m.remove(), 380);
        u.classList.remove('under');
        state.curEl = u;
        $('#app').classList.toggle('sb-light', !!EF.S[cur().id].light);
        refresh();
        closeOv();
        EF.syncProto && EF.syncProto();
    }
    function back() {
        if (state.sel) { state.sel = null; refresh(); return; }
        if (state.stack.length > 1) {
            const leaving = cur();
            state.stack.pop();
            if (EF.S[leaving.id].modal && state.underEl) return dismissModal();
            show('pop');
        } else if (EF.S[cur().id].root && cur().id !== 'home') tab('home');
    }
    function tab(id) { state.sel = null; state.stack = [{id, params: {}}]; show('fade'); }
    function chain(id, params) { const p = EF.S[id].parent; return p ? [...chain(p, {}), {id, params}] : [{id, params}]; }
    function resetTo(id, params = {}) { state.sel = null; state.stack = chain(id, params); show('fade'); }

    /* ============================== gestos e eventos ============================== */
    const app = $('#app');
    function closeSwipes(except) { $$('.sw.open', app).forEach(s => { if (s !== except) { s.classList.remove('open'); $('.row', s).style.transform = ''; } }); }
    app.addEventListener('click', e => {
        if (state.suppressClick) { state.suppressClick = false; e.preventDefault(); e.stopPropagation(); return; }
        const openSw = e.target.closest('.sw.open');
        if ($('.sw.open', app) && !e.target.closest('.swa')) { closeSwipes(); if (openSw || e.target.closest('.txi')) return; }
        const a = e.target.closest('[data-act],[data-go],[data-tab],[data-back],[data-tx]');
        if (!a || !app.contains(a)) return;
        if (a.closest('.swa')) closeSwipes();
        if (a.dataset.act !== undefined) { const f = EF.ACT[a.dataset.act]; if (f) f(a, e); else console.warn('ação sem handler:', a.dataset.act); return; }
        if (a.hasAttribute('data-back')) return back();
        if (a.dataset.tab) return tab(a.dataset.tab);
        if (a.dataset.go) { closeOv(); return go(a.dataset.go, a.dataset.p ? JSON.parse(a.dataset.p) : {}); }
        if (a.dataset.tx) {
            if (state.sel) { const id = String(a.dataset.tx); state.sel.has(id) ? state.sel.delete(id) : state.sel.add(id); refresh(); return; }
            closeOv(); go('tx_detail', {id: a.dataset.tx});
        }
    });
    app.addEventListener('keydown', e => {
        if ((e.key === 'Enter' || e.key === ' ') && e.target.matches('[role="button"]')) { e.preventDefault(); e.target.click(); }
    });

    // deslizar lançamentos e toque longo
    let drag = null, lpT = null;
    app.addEventListener('pointerdown', e => {
        const row = e.target.closest('.sw > .row');
        const grab = e.target.closest('[data-grab]');
        if (grab) { const sh = grab.closest('.sheet'); if (sh) drag = {kind: 'sheet', el: sh, y0: e.clientY, dy: 0}; return; }
        if (!row || state.sel) return;
        const sw = row.parentElement, k = app.getBoundingClientRect().width / app.offsetWidth;
        const lw = $('.swa.l', sw) ? $('.swa.l', sw).offsetWidth : 0, rw = $('.swa.r', sw) ? $('.swa.r', sw).offsetWidth : 0;
        const start = sw.classList.contains('open') ? (parseFloat(row.style.transform.replace(/[^-\d.]/g, '')) || 0) : 0;
        drag = {kind: 'row', sw, row, x0: e.clientX, y0: e.clientY, k, lw, rw, start, dx: 0, active: false, id: e.pointerId};
        clearTimeout(lpT);
        if (!e.target.closest('[data-act]')) lpT = setTimeout(() => { if (drag && !drag.active) { const r = drag.row; drag = null; longPress(r); } }, 480);
    });
    app.addEventListener('pointermove', e => {
        if (!drag) return;
        if (drag.kind === 'sheet') { drag.dy = Math.max(0, e.clientY - drag.y0); drag.el.style.transition = 'none'; drag.el.style.transform = `translateY(${drag.dy}px)`; return; }
        const dx = (e.clientX - drag.x0) / drag.k, dy = (e.clientY - drag.y0) / drag.k;
        if (!drag.active) {
            if (Math.abs(dx) > 8 || Math.abs(dy) > 8) clearTimeout(lpT);
            if (Math.abs(dx) > 10 && Math.abs(dx) > Math.abs(dy) * 1.3) { drag.active = true; drag.sw.classList.add('drag'); closeSwipes(drag.sw); try { drag.row.setPointerCapture(drag.id); } catch (_) { /* sem captura */ } }
            else return;
        }
        let x = drag.start + dx;
        const max = drag.lw ? drag.row.offsetWidth * .8 : 0, min = drag.rw ? -drag.row.offsetWidth * .85 : 0;
        x = Math.max(min, Math.min(max, x));
        drag.dx = x;
        drag.row.style.transform = `translateX(${x}px)`;
    });
    function endDrag() {
        clearTimeout(lpT);
        if (!drag) return;
        const d = drag; drag = null;
        if (d.kind === 'sheet') {
            d.el.style.transition = ''; d.el.style.transform = '';
            if (d.dy > 110) closeOv();
            return;
        }
        if (!d.active) return;
        state.suppressClick = true; setTimeout(() => { state.suppressClick = false; }, 60);
        d.sw.classList.remove('drag');
        const w = d.row.offsetWidth, x = d.dx;
        if (x > w * .55 && d.lw) { d.row.style.transform = ''; const b = $('.swa.l button', d.sw); setTimeout(() => b && b.click(), 10); return; }
        if (x < -w * .62 && d.rw) { const b = $$('.swa.r button', d.sw).pop(); d.row.style.transform = `translateX(${-w}px)`; setTimeout(() => { if (b) { state.suppressClick = false; b.click(); } }, 160); return; }
        if (x > 56 && d.lw) { d.row.style.transform = `translateX(${d.lw}px)`; d.sw.classList.add('open'); return; }
        if (x < -56 && d.rw) { d.row.style.transform = `translateX(${-d.rw}px)`; d.sw.classList.add('open'); return; }
        d.row.style.transform = ''; d.sw.classList.remove('open');
    }
    app.addEventListener('pointerup', endDrag);
    app.addEventListener('pointercancel', endDrag);
    function longPress(row) {
        if (!row.dataset.tx || !EF.txMenu) return;
        state.suppressClick = true; setTimeout(() => { state.suppressClick = false; }, 400);
        row.classList.add('lifted');
        try { navigator.vibrate && navigator.vibrate(10); } catch (_) { /* sem vibração */ }
        EF.txMenu(row, findTx(row.dataset.tx));
    }
    function onScroll(sc) {
        const el = sc.closest('.scr'), nb = el && $('[data-nav]', el);
        if (nb) nb.classList.toggle('scrolled', sc.scrollTop > (nb.classList.contains('lt-mode') ? 36 : 4));
    }
    app.addEventListener('scroll', e => { if (e.target.classList && e.target.classList.contains('scroll')) { onScroll(e.target); if ($('.sw.open', app)) closeSwipes(); } }, true);
    document.addEventListener('keydown', e => {
        if (EF.onKey && EF.onKey(e)) return;
        if (e.key === 'Escape') { if (ovl().classList.contains('open')) closeOv(); else if (document.activeElement && app.contains(document.activeElement) && document.activeElement.matches('input,textarea')) document.activeElement.blur(); else back(); }
    });

    // ações comuns às camadas
    EF.ACT.closeOv = closeOv;
    EF.ACT.alertBtn = a => { const f = state.alertFns[+a.dataset.i]; closeOv(); f && setTimeout(f, 60); };
    EF.ACT.asBtn = a => { const f = state.asFns[+a.dataset.i]; closeOv(); f && setTimeout(f, 120); };
    EF.ACT.cmBtn = a => { const f = state.cmFns[+a.dataset.i]; closeOv(); f && setTimeout(f, 120); };
    EF.ACT.toastAct = () => { $('#toast').classList.remove('show'); state.toastFn && state.toastFn(); };
    EF.ACT.toastMsg = a => toast(a.dataset.m, {icon: a.dataset.i});
    EF.ACT.toggleHide = () => { state.hide = !state.hide; refresh(); };

    /* ============================== tema ============================== */
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const systemDark = () => { const t = document.documentElement.getAttribute('data-theme'); return t ? t === 'dark' : mq.matches; };
    const isDark = () => state.theme === 'dark' || (state.theme === 'system' && systemDark());
    const applyTheme = () => app.classList.toggle('dark', isDark());
    function setTheme(v) {
        state.theme = v;
        try { localStorage.setItem('ef-ios-theme', v); } catch (_) { /* armazenamento indisponível */ }
        applyTheme();
        $$('#ptheme button').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.v === v)));
        if (cur() && EF.S[cur().id].themeAware) refresh();
    }
    mq.addEventListener('change', applyTheme);
    new MutationObserver(applyTheme).observe(document.documentElement, {attributes: true, attributeFilter: ['data-theme']});

    Object.assign(EF, {
        $, $$, esc, ic, fmt, sum, pct, pad, norm, initials, goAttr, plural, cap, CMP,
        TODAY, BASE, MONTHS, MON, WEEK, parse, iso, dm, dmy, days, addMonths, monthLabel, longDate, greeting, rnd,
        TYPES, TYPES_PL, PAY, PAY_ICON, MODE, REC, REC_STEP, CONTACT_CAT, CONTACT_COLOR, NCAT, NSEV,
        markSvg, appIcon, WM, FACEID, state,
        company, allAccounts, findAcct, account, acctBalance, balance, bankOf, modeNow, catOf, inMonth, isBase, locked, frozen,
        monthTx, allTx, findTx, removeTx, restoreTx, totals, status, byCategory, groupBy, limitRows, avg3, yearFlow, subsMonthly, setPaid, bankAccounts, bankTotals,
        money, signed, bigMoney, compactMoney, navb, largeTitle, gbtn, gtxt, gbs, tabbar, sh, shSmall, linkBtn, tg, seg, catAv, bankAv, acctAv, si, modeTag, txItem,
        pring, donut, barChart, limRow, kpi, delta, calendar,
        openOv, closeOv, sheet, alertBox, actionSheet, contextMenu, toast,
        cur, show, refresh, go, replace, back, tab, resetTo, closeSwipes,
        isDark, setTheme, applyTheme
    });
})();
