/* e-Finances iPhone · protótipo: índice de telas, notas da tela, escala do aparelho e início. */
'use strict';
(() => {
    const E = window.EF, S = E.S, state = E.state, {$, $$, esc, ic, pad} = E;

    /* [id da tela, rótulo, ícone, parâmetros, ajustes antes de abrir] */
    const INDEX = [
        ['Acesso', [['splash', 'Abertura', 'sparkles'], ['onboarding', 'Apresentação', 'layers', {}, {ob: 0}], ['login', 'Entrar', 'log-in'], ['register', 'Criar conta', 'user-plus'], ['register_done', 'Conta criada', 'mail-check'], ['forgot', 'Esqueci a senha', 'key-round'], ['unlock', 'Desbloqueio com Face ID', 'scan-face']]],
        ['Dia a dia', [['home', 'Início', 'house', {}, {ws: 'cc'}], ['tx', 'Transações', 'receipt-text', {}, {ws: 'cc'}], ['tx_detail', 'Detalhe do lançamento', 'file-text', {id: 5}, {ws: 'cc'}], ['tx_form', 'Novo lançamento', 'plus', {}, {ws: 'cc', draft: 'V'}], ['notifications', 'Notificações', 'bell'], ['story', 'Fechamento do mês', 'sparkles']]],
        ['Contas e bancos', [['banks', 'Contas (bancos conectados)', 'landmark'], ['bank_account', 'Cartão conectado', 'credit-card', {b: 'nu', a: 'nu-cr'}], ['home', 'Início numa conta do banco', 'link', {}, {ws: 'nu-cr'}, 'novo'], ['tx', 'Transações do banco (organizar)', 'tags', {}, {ws: 'nu-cr'}, 'novo'], ['tx', 'Conta congelada', 'snowflake', {}, {ws: 'it-old'}, 'novo']]],
        ['Planejar', [['plan', 'Limites por categoria', 'flag', {}, {plan: 'limits'}], ['plan', 'Parcelamentos', 'layers', {}, {plan: 'inst'}], ['plan', 'Assinaturas', 'repeat', {}, {plan: 'subs'}], ['reports', 'Relatórios', 'chart-column']]],
        ['Cadastros', [['categories', 'Categorias', 'tags', {}, {}, 'novo'], ['contacts', 'Contatos', 'users'], ['costcenters', 'Centros de custo', 'network'], ['companies', 'Empresas e contas', 'building-2']]],
        ['Sua conta', [['more', 'Mais (menu)', 'ellipsis'], ['profile', 'Minha conta', 'user-round'], ['delete_account', 'Excluir conta', 'user-minus', {}, {}, 'novo'], ['billing', 'Plano e faturas', 'crown'], ['plans', 'Mudar de plano', 'crown'], ['notif_prefs', 'Notificações (preferências)', 'bell-ring'], ['appearance', 'Aparência', 'palette'], ['security', 'Face ID e segurança', 'scan-face'], ['help', 'Ajuda e suporte', 'life-buoy'], ['ticket_new', 'Novo chamado', 'headset'], ['web', 'Abre na web (importar)', 'external-link', {page: 'import'}]]],
        ['Extras do iPhone', [['extras_home', 'Widgets e atalhos', 'layout-grid', {}, {}, 'proposta'], ['extras_lock', 'Tela bloqueada e avisos', 'smartphone', {}, {}, 'proposta']]]
    ];
    const flat = INDEX.flatMap(([g, items]) => items.map((it, k) => ({g, k, id: it[0], label: it[1], icon: it[2], p: it[3] || {}, o: it[4] || {}, badge: it[5] || ''})));

    function open(item) {
        const o = item.o;
        if (o.ws) { const a = E.findAcct(o.ws); state.ws = {company: a.co.id, account: a.id}; state.month = {...E.BASE}; state.f = {kind: 'all', status: null, q: '', cat: null}; }
        if (o.plan) state.planTab = o.plan;
        if (o.ob !== undefined) state.ob = o.ob;
        if (o.draft) state.draft = E.newDraft(o.draft);
        state.qa = false; state.lockPaid = false;
        state.picked = `${item.g}-${item.k}`;
        const def = S[item.id];
        if (def.modal) { E.resetTo(def.parent || 'home'); setTimeout(() => E.go(item.id, item.p), 80); }
        else E.resetTo(item.id, item.p);
        $('#stage').classList.remove('menu');
    }
    function renderIndex() {
        $('#pindex').innerHTML = INDEX.map(([g, items]) => `<div class="pgroup"><span>${g}</span>${items.map((it, k) => `<button data-k="${g}-${k}">${ic(it[2])}${it[1]}${it[5] ? `<em>${it[5]}</em>` : ''}</button>`).join('')}</div>`).join('');
        $('#pindex').addEventListener('click', e => {
            const b = e.target.closest('button[data-k]');
            if (!b) return;
            open(flat.find(f => `${f.g}-${f.k}` === b.dataset.k));
        });
    }
    E.syncProto = () => {
        const c = E.cur(), def = S[c.id];
        const match = flat.filter(f => f.id === c.id);
        const pick = match.find(f => `${f.g}-${f.k}` === state.picked) || match.find(f => (!f.o.plan || f.o.plan === state.planTab) && (!f.o.ws || f.o.ws === state.ws.account)) || match[0];
        $$('#pindex button').forEach(b => b.classList.toggle('on', !!pick && b.dataset.k === `${pick.g}-${pick.k}`));
        if (pick && `${pick.g}-${pick.k}` !== state.picked) state.picked = null;
        const n = def.notes || {};
        const list = (t, arr, code) => arr && arr.length ? `<div class="pnote"><span class="plabel">${t}</span><ul>${arr.map(x => `<li>${code ? `<code>${esc(x)}</code>` : esc(x)}</li>`).join('')}</ul></div>` : '';
        $('#pnotes').innerHTML = `<span class="pcrumb">${pick ? pick.g : 'App'}</span><h2>${def.title}</h2><p>${esc(n.d || '')}</p>
            ${n.tip ? `<div class="ptip">${ic('info')}<span>${esc(n.tip)}</span></div>` : ''}
            ${n.warn ? `<div class="ptip warn">${ic('triangle-alert')}<span>${esc(n.warn)}</span></div>` : ''}
            ${list('Componentes do iOS (SwiftUI)', n.c)}${list('Dados (API do e-Finances)', n.a, true)}`;
        $('#pmini').innerHTML = `<b>${def.title}</b><p>${esc(n.d || '')}</p>${n.tip ? `<p style="color:var(--pg-accent)">${esc(n.tip)}</p>` : ''}${n.warn ? `<p style="color:var(--pg-warn)">${esc(n.warn)}</p>` : ''}`;
        try { history.replaceState(null, '', '#' + c.id); } catch (_) { /* sem histórico */ }
    };
    function fit() {
        const c = $('.pcenter');
        if (window.innerWidth <= 760) return;
        const k = Math.min(1, (c.clientHeight - 32) / 898, (c.clientWidth - 32) / 426);
        $('#dwrap').style.setProperty('--k', Math.max(.45, k).toFixed(3));
    }
    function clock() { const d = new Date(); $('#clock').textContent = `${d.getHours()}:${pad(d.getMinutes())}`; }

    try { const t = localStorage.getItem('ef-ios-theme'); if (t) state.theme = t; } catch (_) { /* sem armazenamento */ }
    $$('#ptheme button').forEach(b => { b.setAttribute('aria-pressed', String(b.dataset.v === state.theme)); b.addEventListener('click', () => E.setTheme(b.dataset.v)); });
    $('#preset').addEventListener('click', () => { state.ob = 0; state.ws = {company: 1, account: 'cc'}; E.resetTo('splash'); $('#stage').classList.remove('menu'); });
    $('#pfab').addEventListener('click', () => $('#stage').classList.add('menu'));
    $('#pclose').addEventListener('click', () => $('#stage').classList.remove('menu'));
    $('#stage').addEventListener('click', e => { if (e.target === $('#stage')) $('#stage').classList.remove('menu'); });
    E.applyTheme();
    renderIndex();
    clock(); setInterval(clock, 30000);
    fit(); window.addEventListener('resize', fit);
    const start = (location.hash || '').slice(1);
    const item = flat.find(f => f.id === start);
    if (item && !S[start].modal) open(item); else E.resetTo(S[start] && !S[start].modal ? start : 'splash');
})();
