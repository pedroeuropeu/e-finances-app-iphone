/* e-Finances iPhone · protótipo: Mais, cadastros, conta, preferências, plano, ajuda, páginas da web e extras do iPhone. */
'use strict';
(() => {
    const E = window.EF, D = E.D, S = E.S, ACT = E.ACT, state = E.state;
    const {$, esc, ic, fmt, sum, pct, norm, initials, goAttr, plural, cap, TODAY, BASE, MONTHS, parse, dm, CONTACT_CAT, CONTACT_COLOR, markSvg, appIcon, WM, FACEID,
        company, account, acctBalance, bankOf, catOf, monthTx, totals, limitRows, subsMonthly,
        money, signed, bigMoney, navb, largeTitle, gbtn, gtxt, gbs, sh, shSmall, linkBtn, tg, seg, catAv, bankAv, acctAv, si, modeTag, txItem, kpi,
        sheet, alertBox, actionSheet, contextMenu, toast, closeOv, cur, refresh, go, back, tab, resetTo, setTheme, isDark} = E;

    const srow = (icon, color, label, attrs, {sub = '', val = '', web = false, red = false} = {}) =>
        `<button class="row" ${attrs}>${si(icon, color)}<span class="rt"><span class="t ${red ? 'red' : ''}">${label}</span>${sub ? `<span class="s">${sub}</span>` : ''}</span>${val ? `<span class="val">${val}</span>` : ''}${ic(web ? 'external-link' : 'chevron-right', 'chev')}</button>`;
    const toggleRow = (k, label, sub = '', disabled = false) => `<button class="row" data-act="pref" data-k="${k}" ${disabled ? 'disabled' : ''}><span class="rt"><span class="t">${label}</span>${sub ? `<span class="s wrap">${sub}</span>` : ''}</span>${tg(state.prefs[k])}</button>`;
    const checkRow = (k, v, label, sub = '') => `<button class="row" data-act="prefSet" data-k="${k}" data-v="${v}"><span class="rt"><span class="t">${label}</span>${sub ? `<span class="s">${sub}</span>` : ''}</span>${state.prefs[k] === v ? ic('check', 'ck') : ''}</button>`;
    ACT.pref = a => { if (a.hasAttribute('disabled')) return; const k = a.dataset.k; state.prefs[k] = !state.prefs[k]; if (k === 'hideOnOpen') state.hide = state.prefs[k]; refresh(); };
    ACT.prefSet = a => { state.prefs[a.dataset.k] = a.dataset.v; refresh(); };

    /* ---------- mais ---------- */
    S.more = {
        title: 'Mais', tab: 'more', root: true,
        render() {
            const open = D.tickets.filter(t => t.tone === 'amber').length;
            return `${navb({back: false, large: true, title: 'Mais'})}<div class="scroll">${largeTitle('Mais')}
                <div class="sec"><button class="row" style="border-radius:22px;min-height:76px" ${goAttr('profile')}><span class="av lg solid" style="--c:#0B2545">${D.user.initials}</span><span class="rt"><span class="t" style="font-size:19px;font-weight:600">${D.user.first} ${D.user.last}</span><span class="s">${D.user.email}</span><span style="margin-top:4px"><span class="tag green">${ic('crown')}Premium</span></span></span>${ic('chevron-right', 'chev')}</button></div>
                <div class="sec"><div class="grp ic-rows">
                    ${srow('chart-column', '#4338CA', 'Relatórios', goAttr('reports'))}
                    ${srow('tags', '#F97316', 'Categorias', goAttr('categories'), {sub: 'Limites, marcas e assinaturas'})}
                    ${srow('users', '#059669', 'Contatos', goAttr('contacts'))}
                    ${srow('network', '#7C3AED', 'Centros de custo', goAttr('costcenters'))}
                </div></div>
                <div class="sec"><div class="grp ic-rows">
                    ${srow('building-2', '#0E7490', 'Empresas e contas', goAttr('companies'), {sub: 'Onde ficam seus lançamentos'})}
                    ${srow('file-up', '#0284C7', 'Importar extrato', goAttr('web', {page: 'import'}), {sub: 'Abre na web', web: true})}
                    ${srow('share', '#0284C7', 'Exportar transações', goAttr('web', {page: 'export'}), {sub: 'Abre na web', web: true})}
                    ${srow('receipt', '#64748B', 'Modelos de recibo', goAttr('web', {page: 'receipts'}), {sub: 'Abre na web', web: true})}
                </div></div>
                <div class="sec"><div class="grp ic-rows">
                    ${srow('user-round', '#1D4E89', 'Minha conta', goAttr('profile'))}
                    ${srow('crown', '#CA8A04', 'Plano e faturas', goAttr('billing'), {val: 'Premium'})}
                    ${srow('bell', '#DC2626', 'Notificações', goAttr('notif_prefs'))}
                    ${srow('palette', '#DB2777', 'Aparência', goAttr('appearance'), {val: {system: 'Automático', light: 'Claro', dark: 'Escuro'}[state.theme]})}
                    ${srow('scan-face', '#16A34A', 'Face ID e segurança', goAttr('security'), {val: state.prefs.bio ? 'Ativado' : 'Desativado'})}
                </div></div>
                <div class="sec"><div class="grp ic-rows">
                    ${srow('layout-grid', '#0B2545', 'Widgets e atalhos', goAttr('extras_home'), {sub: 'Saldo e contas na tela de início'})}
                    ${srow('life-buoy', '#0EA5E9', 'Ajuda e suporte', goAttr('help'), {sub: open ? `${plural(open, 'chamado respondido', 'chamados respondidos')}` : ''})}
                    ${srow('star', '#F59E0B', 'Avaliar na App Store', 'data-act="rate"')}
                    ${srow('info', '#64748B', 'Sobre o app', 'data-act="aboutSheet"')}
                </div></div>
                <div class="sec"><div class="grp"><button class="row center red" data-act="logout">Sair</button></div></div>
                <p class="foot">e-Finances 1.0.0 (1) · iPhone</p>
            </div>`;
        },
        notes: {d: 'O restante do sistema no estilo dos Ajustes do iPhone: finanças, dados, conta, ajuda e os extras do iPhone. Importar e exportar extrato e modelos de recibo abrem na web, como no Android.', c: ['List .insetGrouped com ícones coloridos', 'Linha de perfil no topo', 'SKStoreReviewController para avaliar o app'], a: ['GET /api/users (perfil)']}
    };
    ACT.rate = () => alertBox({title: 'Gostando do e-Finances?', text: 'Toque numa estrela para avaliar na App Store.<br><span style="font-size:30px;letter-spacing:6px;color:#F59E0B">★★★★★</span>', buttons: [{label: 'Agora não'}, {label: 'Enviar', cls: 'pri', fn: () => toast('Obrigado pela avaliação!', {icon: 'star'})}]});
    ACT.aboutSheet = () => sheet({title: 'Sobre o app', body: `<div class="dhero"><span style="width:76px;height:76px;border-radius:18px;background:#0B2545;display:flex;align-items:center;justify-content:center">${appIcon()}</span><h2 class="disp">e<span style="color:#10B981">·</span>finances</h2><p>Versão 1.0.0 (1) · iOS 17 ou mais novo</p></div>
        <div class="grp ic-rows">${srow('file-text', '#64748B', 'Termos de uso', goAttr('web', {page: 'terms'}), {web: true})}${srow('shield-check', '#64748B', 'Política de privacidade', goAttr('web', {page: 'privacy'}), {web: true})}${srow('book-open', '#64748B', 'Licenças de código aberto', 'data-act="toastMsg" data-m="Licenças: Lucide (ISC) e bibliotecas da Apple"')}</div>`});

    /* ---------- categorias ---------- */
    S.categories = {
        title: 'Categorias', parent: 'more',
        render() {
            const exp = monthTx(BASE.y, BASE.m).filter(t => t.type !== 'R');
            const spent = k => sum(exp.filter(t => t.cat === k));
            const lim = Object.fromEntries(state.limits.map(l => [l.cat, l]));
            const all = Object.entries(D.categories);
            const counts = {all: all.length, own: all.filter(([, c]) => !c.systemDefault).length, sys: all.filter(([, c]) => c.systemDefault).length, sub: all.filter(([, c]) => c.sub).length, lim: all.filter(([k]) => lim[k]).length};
            const f = state.catf, q = norm(state.catq);
            const list = all.filter(([k, c]) => (f === 'all' || (f === 'own' && !c.systemDefault) || (f === 'sys' && c.systemDefault) || (f === 'sub' && c.sub) || (f === 'lim' && lim[k])) && (!q || norm(c.name).includes(q)))
                .sort((a, b) => spent(b[0]) - spent(a[0]));
            const lr = limitRows(), over = lr.filter(l => l.status === 'over').length, warn = lr.filter(l => l.status === 'warn').length;
            return `${navb({title: 'Categorias', large: true, right: `<button class="gb tint" data-act="catEditNew" aria-label="Nova categoria">${ic('plus')}</button>`})}
            <div class="scroll">${largeTitle('Categorias', `${cap(MONTHS[BASE.m])} de ${BASE.y} · ${esc(account().name)}`)}
                <div class="pad"><div class="kpis">${kpi('Gasto no mês', money(sum(exp)), '', '<span class="d">na conta em uso</span>')}${kpi('Assinaturas', `${money(subsMonthly())}/mês`, '', `<span class="d">${D.subscriptions.length} ativas · ${counts.sub} categorias</span>`)}</div>
                ${over || warn ? `<div class="alert danger">${ic('flag')}<div class="grow"><b>${[over ? `${over} passou do limite` : '', warn ? `${plural(warn, 'está perto', 'estão perto')} do limite` : ''].filter(Boolean).join(' · ')}</b></div></div>` : ''}</div>
                <label class="search">${ic('search')}<input id="catq2" data-catq value="${esc(state.catq)}" placeholder="Buscar categoria" autocomplete="off"></label>
                <div class="chips">${[['all', 'Todas'], ['own', 'Suas'], ['sys', 'Padrão'], ['sub', 'Assinaturas'], ['lim', 'Com limite']].map(([k, l]) => `<button class="chip ${f === k ? 'on' : ''}" data-act="catF" data-v="${k}">${l} (${counts[k]})</button>`).join('')}</div>
                <div class="sec"><div class="grp av-rows">${list.map(([k, c]) => { const s = spent(k), l = lim[k], p = l ? s / l.limit * 100 : 0, st = p >= 100 ? 'over' : l && p >= l.alertPct ? 'warn' : 'ok'; const n = exp.filter(t => t.cat === k).length;
                    return `<button class="row" data-act="catEdit" data-k="${k}" style="align-items:flex-start">${catAv(c)}<span class="rt"><span class="t">${esc(c.name)} ${c.sub ? '<span class="tag">Assinatura</span>' : ''}</span><span class="s">${c.systemDefault ? ic('lock') + ' ' : ''}${plural(n, 'lançamento', 'lançamentos')}${c.income ? ' · receita' : ''}</span>${l ? `<span class="prog ${st}" style="margin-top:8px;height:5px"><i style="width:${Math.min(p, 100)}%"></i></span>` : ''}</span><span class="rv num">${money(s)}${l ? `<small>de ${money(l.limit)}</small>` : ''}</span></button>`; }).join('') || '<div class="row"><span class="rt"><span class="s">Nenhuma categoria encontrada.</span></span></div>'}</div></div>
                <p class="foot-note">${ic('lock')} As padrão do sistema só mudam o limite. As suas mudam nome, aparência e se contam como assinatura.</p>
            </div>`;
        },
        notes: {d: 'Categorias com o gasto do mês na conta em uso, limite e filtros (suas, padrão, assinaturas, com limite). A aparência pode ser ícone e cor, a marca com logo (mesmo catálogo da web) ou um logo seu. Marcar como assinatura faz os lançamentos dela aparecerem em Assinaturas.', c: ['List com .searchable e chips de filtro', 'Folha de edição com Picker de aparência', 'PhotosPicker para o logo próprio (reduzido para 128×128 antes de enviar)', 'Excluir com “Restaurar”'], a: ['GET /api/transaction/category/overview?month=yyyy-MM', 'POST /api/transaction/category/save', 'DELETE e restaurar /api/transaction/category']}
    };
    ACT.catF = a => { state.catf = a.dataset.v; refresh(); };
    ACT.catEditNew = () => { state.catEdit = {k: null, name: '', look: 'icon', icon: 'plane', color: '#0EA5E9', sub: false, limit: ''}; catEditSheet(); };
    ACT.catEdit = a => { const k = a.dataset.k, c = D.categories[k], l = state.limits.find(x => x.cat === k); state.catEdit = {k, name: c.name, look: c.brand ? 'brand' : 'icon', icon: c.icon, color: c.color, sub: !!c.sub, limit: l ? l.limit : '', brand: c.brand}; catEditSheet(); };
    const COLORS = ['#6366F1', '#0EA5E9', '#10B981', '#F59E0B', '#F97316', '#EF4444', '#DB2777', '#7C3AED', '#64748B'];
    const ICONS2 = ['plane', 'coffee', 'gift', 'dumbbell', 'wrench', 'baby', 'shirt', 'popcorn', 'dog', 'car', 'house', 'heart'];
    const BRANDS = [['Netflix', 'N', '#E50914'], ['Spotify', 'S', '#1DB954'], ['YouTube', 'YT', '#FF0033'], ['Amazon', 'a', '#00A8E1'], ['Disney+', 'D+', '#113CCF'], ['Apple', '', '#1F1F1F'], ['iFood', 'iF', '#EA1D2C'], ['Uber', 'U', '#000000']];
    function catEditSheet() {
        const e = state.catEdit, sys = e.k && D.categories[e.k].systemDefault;
        const preview = e.look === 'brand' && e.brand ? catAv({brand: e.brand}, 'xl') : e.look === 'logo' ? `<span class="av xl" style="--c:#0B2545">${ic('image')}</span>` : catAv({icon: e.icon, color: e.color}, 'xl');
        sheet({title: e.k ? (sys ? 'Categoria padrão' : 'Editar categoria') : 'Nova categoria', large: true, right: `<button class="gb tint" data-act="catEditSave" aria-label="Salvar">${ic('check')}</button>`,
            body: `<div class="dhero">${preview}<h2>${esc(e.name || 'Nova categoria')}</h2>${sys ? '<p>Padrão do sistema: só o limite muda.</p>' : ''}</div>
                ${sys ? '' : `<div class="grp"><label class="frow"><span class="k">Nome</span><input id="ce-n" value="${esc(e.name)}" placeholder="Ex.: Viagens"></label></div>
                ${seg([['icon', 'Ícone e cor'], ['brand', 'Marca'], ['logo', 'Logo próprio']], e.look, 'ceLook')}
                ${e.look === 'icon' ? `<div class="card"><div class="chips wrap" style="justify-content:space-between">${ICONS2.map(i => `<button class="chip ${e.icon === i ? 'on' : ''}" data-act="ceIcon" data-v="${i}" aria-label="${i}" style="width:44px;padding:0;justify-content:center">${ic(i)}</button>`).join('')}</div>
                    <div style="display:flex;justify-content:space-between">${COLORS.map(c => `<button data-act="ceColor" data-v="${c}" aria-label="Cor ${c}" style="width:30px;height:30px;border-radius:50%;background:${c};box-shadow:${e.color === c ? `0 0 0 3px var(--surface),0 0 0 5px ${c}` : 'none'}"></button>`).join('')}</div></div>` : ''}
                ${e.look === 'brand' ? `<label class="search in-pad">${ic('search')}<input placeholder="Buscar marca (catálogo da web)"></label><div class="pick">${BRANDS.map(([n, s, c]) => `<button class="${e.brand && e.brand.color === c ? 'on' : ''}" data-act="ceBrand" data-n="${n}" data-s="${s}" data-c="${c}"><span class="av solid" style="--c:${c}">${s || ic('apple')}</span>${n}</button>`).join('')}</div>` : ''}
                ${e.look === 'logo' ? `<button class="file add" style="height:64px" data-act="toastMsg" data-m="Escolher nas Fotos (o app reduz para 128×128)" data-i="image">${ic('image')}Escolher imagem nas Fotos</button>` : ''}
                <div class="grp"><button class="row" data-act="ceSub"><span class="rt"><span class="t">É assinatura</span><span class="s wrap">Os lançamentos desta categoria entram em Assinaturas.</span></span>${tg(e.sub)}</button></div>`}
                <div class="grp"><label class="frow"><span class="k">Limite por mês</span><span style="margin-left:auto;display:flex;align-items:center;gap:6px;color:var(--muted)">R$<input id="ce-l" type="number" inputmode="decimal" value="${e.limit}" placeholder="Sem limite" style="width:120px"></span></label></div>
                ${e.k && !sys ? `<button class="btn block red" data-act="catDel" data-k="${e.k}">${ic('trash-2')}Excluir categoria</button>` : ''}`});
    }
    const syncCe = () => { const n = $('#ce-n'), l = $('#ce-l'); if (n) state.catEdit.name = n.value; if (l) state.catEdit.limit = l.value; };
    ACT.ceLook = a => { syncCe(); state.catEdit.look = a.dataset.v; catEditSheet(); };
    ACT.ceIcon = a => { syncCe(); state.catEdit.icon = a.dataset.v; catEditSheet(); };
    ACT.ceColor = a => { syncCe(); state.catEdit.color = a.dataset.v; catEditSheet(); };
    ACT.ceBrand = a => { syncCe(); state.catEdit.brand = {short: a.dataset.s || 'A', color: a.dataset.c}; if (!state.catEdit.name) state.catEdit.name = a.dataset.n; catEditSheet(); };
    ACT.ceSub = () => { syncCe(); state.catEdit.sub = !state.catEdit.sub; catEditSheet(); };
    ACT.catEditSave = () => {
        syncCe();
        const e = state.catEdit, k = e.k || 'c' + state.nextId++;
        const c = D.categories[k] || {systemDefault: false};
        if (!c.systemDefault) Object.assign(c, {name: e.name.trim() || 'Nova categoria', icon: e.icon, color: e.look === 'brand' && e.brand ? e.brand.color : e.color, sub: e.sub, brand: e.look === 'brand' ? e.brand : undefined});
        D.categories[k] = c;
        const v = +e.limit, l = state.limits.find(x => x.cat === k);
        if (v > 0) { if (l) l.limit = v; else state.limits.push({cat: k, limit: v, alertPct: 80}); } else if (l) state.limits = state.limits.filter(x => x !== l);
        closeOv(); refresh(); toast(e.k ? 'Categoria salva' : 'Categoria criada', {icon: 'tag'});
    };
    ACT.catDel = a => { const k = a.dataset.k, c = D.categories[k]; delete D.categories[k]; closeOv(); refresh(); toast(`“${esc(c.name)}” excluída`, {action: 'Restaurar', fn: () => { D.categories[k] = c; refresh(); }}); };

    /* ---------- contatos ---------- */
    S.contacts = {
        title: 'Contatos', parent: 'more',
        render() {
            const pend = monthTx(BASE.y, BASE.m).filter(x => !x.paid);
            const owe = name => sum(pend.filter(x => x.contact === name && x.type === 'R')) - sum(pend.filter(x => x.contact === name && x.type !== 'R'));
            const me = sum(pend.filter(x => x.type === 'R' && x.contact)), i = sum(pend.filter(x => x.type !== 'R' && D.contacts.some(c => c.name === x.contact)));
            const q = norm(state.cq);
            const list = D.contacts.filter(c => (state.ccat === 'all' || c.category === state.ccat) && (!q || norm(c.name).includes(q)));
            return `${navb({title: 'Contatos', large: true, right: `${gbtn('users', 'data-act="contactsImport"', 'Importar dos Contatos do iPhone')}<button class="gb tint" data-act="contactNew" aria-label="Novo contato">${ic('plus')}</button>`})}
            <div class="scroll">${largeTitle('Contatos', 'Clientes, fornecedores e funcionários')}
                <div class="pad"><div class="kpis">${kpi('Me devem', money(me), 'in', '<span class="d">em aberto no mês</span>')}${kpi('Eu devo', money(i), 'out', '<span class="d">em aberto no mês</span>')}</div></div>
                <label class="search">${ic('search')}<input id="cq2" data-cq value="${esc(state.cq)}" placeholder="Buscar contato" autocomplete="off"></label>
                <div class="pad">${seg([['all', 'Todos'], ['CLIENT', 'Clientes'], ['SUPPLIER', 'Fornec.'], ['WORKER', 'Funcion.']], state.ccat, 'cCat')}</div>
                <div class="sec"><div class="grp av-rows">${list.map(c => { const o = owe(c.name); return `<button class="row" data-act="contactSheet" data-n="${esc(c.name)}"><span class="av solid" style="--c:${CONTACT_COLOR[c.category]}">${initials(c.name)}</span><span class="rt"><span class="t">${esc(c.name)}</span><span class="s">${CONTACT_CAT[c.category]}${c.phone ? ' · ' + c.phone : ''}</span></span>${o ? `<span class="rv num ${o > 0 ? 'in' : ''}" style="${o < 0 ? 'color:var(--expense)' : ''}">${money(Math.abs(o))}<small>${o > 0 ? 'te deve' : 'você deve'}</small></span>` : ''}${ic('chevron-right', 'chev')}</button>`; }).join('') || '<div class="row"><span class="rt"><span class="s">Nenhum contato encontrado.</span></span></div>'}</div></div>
            </div>`;
        },
        notes: {d: 'Clientes, fornecedores e funcionários com quanto cada um te deve ou você deve no mês. Dá para trazer dos Contatos do iPhone.', c: ['List com .searchable e Picker de tipo', 'CNContactPickerViewController para importar do iPhone', 'Cartão do contato com ligar, mensagem e e-mail', 'Excluir com “Restaurar”'], a: ['/api/contact', '/api/transaction/find-analise-dividas-contatos']}
    };
    ACT.cCat = a => { state.ccat = a.dataset.v; refresh(); };
    ACT.contactsImport = () => toast('Abriria os Contatos do iPhone para escolher', {icon: 'users'});
    ACT.contactSheet = a => {
        const c = D.contacts.find(x => x.name === a.dataset.n), list = monthTx(BASE.y, BASE.m).filter(t => t.contact === c.name);
        sheet({title: 'Contato', right: gtxt('Editar', 'data-act="toastMsg" data-m="Editar contato"'), body: `<div class="dhero"><span class="av xl solid" style="--c:${CONTACT_COLOR[c.category]}">${initials(c.name)}</span><h2>${esc(c.name)}</h2><p>${CONTACT_CAT[c.category]}</p></div>
            <div class="quick" style="padding:0">${[['phone', 'Ligar'], ['message-circle', 'Mensagem'], ['message-square', 'WhatsApp'], ['mail', 'E-mail']].map(([i, l]) => `<button data-act="toastMsg" data-m="${l}: ${esc(c.phone || c.email || 'sem dado')}" data-i="${i}"><i>${ic(i)}</i>${l}</button>`).join('')}</div>
            <div class="grp"><div class="kv">${c.phone ? `<div><span>Telefone</span><b>${c.phone}</b></div>` : ''}${c.email ? `<div><span>E-mail</span><b>${c.email}</b></div>` : ''}<div><span>Tipo</span><b>${CONTACT_CAT[c.category]}</b></div></div></div>
            ${list.length ? `${shSmall(`Lançamentos em ${MONTHS[BASE.m]}`)}<div class="grp av-rows" style="margin-top:-6px">${list.map(t => txItem(t, {swipe: false})).join('')}</div>` : `<p class="foot-note">Sem lançamentos em ${MONTHS[BASE.m]}.</p>`}
            <button class="btn block red" data-act="contactDel" data-n="${esc(c.name)}">${ic('trash-2')}Excluir contato</button>`});
    };
    ACT.contactDel = a => { const i = D.contacts.findIndex(x => x.name === a.dataset.n), c = D.contacts[i]; D.contacts.splice(i, 1); closeOv(); refresh(); toast(`${esc(c.name)} excluído`, {action: 'Restaurar', fn: () => { D.contacts.splice(i, 0, c); refresh(); }}); };
    ACT.contactNew = () => sheet({title: 'Novo contato', right: `<button class="gb tint" data-act="contactCreate" aria-label="Salvar">${ic('check')}</button>`,
        body: `<div class="grp"><label class="frow"><span class="k">Nome</span><input id="nc" placeholder="Nome ou razão social"></label><label class="frow"><span class="k">Celular</span><input id="nt" type="tel" placeholder="(11) 90000-0000"></label><label class="frow"><span class="k">E-mail</span><input id="ne" type="email" placeholder="Opcional"></label></div>
            ${seg([['CLIENT', 'Cliente'], ['SUPPLIER', 'Fornecedor'], ['WORKER', 'Funcionário']], 'CLIENT', 'segOne')}
            <button class="btn block gray" data-act="contactsImport">${ic('users')}Escolher nos Contatos do iPhone</button>`});
    ACT.segOne = a => { [...a.parentElement.children].forEach(b => b.classList.toggle('on', b === a)); };
    ACT.contactCreate = () => { const n = ($('#nc').value || '').trim() || 'Novo contato', cat = ($('.sheet .seg .on') || {dataset: {v: 'CLIENT'}}).dataset.v; D.contacts.unshift({name: n, category: cat, phone: $('#nt').value, email: $('#ne').value}); closeOv(); refresh(); toast(`Contato “${esc(n)}” criado`, {icon: 'user-plus'}); };

    /* ---------- centros de custo ---------- */
    S.costcenters = {
        title: 'Centros de custo', parent: 'more',
        render() {
            const exp = monthTx(BASE.y, BASE.m, 'cc').filter(t => t.type !== 'R'), classified = sum(exp.filter(t => t.cc)), budget = sum(Object.values(D.costCenters), c => c.monthlyBudget);
            return `${navb({title: 'Centros de custo', large: true, right: `<button class="gb tint" data-act="ccNew" aria-label="Novo centro de custo">${ic('plus')}</button>`})}<div class="scroll">${largeTitle('Centros de custo')}
                <div class="pad"><div class="kpis">${kpi('Despesas classificadas', money(classified), '', `<span class="d">${pct(classified, sum(exp))}% das despesas</span>`)}${kpi('Orçamento do mês', money(budget), '', `<span class="d">${pct(classified, budget)}% usado</span>`)}</div></div>
                <div class="sec"><div class="grp">${Object.entries(D.costCenters).map(([k, c]) => { const items = exp.filter(t => t.cc === k), s = sum(items), p = s / c.monthlyBudget * 100, st = p >= 100 ? 'over' : p >= 85 ? 'warn' : 'ok';
                    return `<button class="limr" data-act="ccEdit" data-k="${k}"><span class="head">${catAv(c, 'sm')}<span class="grow"><b>${c.name}</b><small>${c.description} · ${plural(items.length, 'lançamento', 'lançamentos')}</small></span><span class="lp ${st}">${Math.round(p)}%</span></span><span class="prog" style="--c:${c.color}"><i style="width:${Math.min(p, 100)}%"></i></span><span class="lsub">${money(s)} de ${money(c.monthlyBudget)}</span></button>`; }).join('')}</div></div>
                <p class="foot-note">${ic('info')} Separe despesas por área e acompanhe um orçamento mensal para cada uma.</p>
            </div>`;
        },
        notes: {d: 'Centros de custo com orçamento mensal e quanto já foi usado em cada um.', c: ['List com barra de orçamento na cor do centro', 'Folha com nome, descrição, orçamento, cor e ícone', 'Excluir com “Restaurar”'], a: ['/api/cost-center']}
    };
    ACT.ccNew = () => sheet({title: 'Novo centro de custo', right: `<button class="gb tint" data-act="closeOv" aria-label="Salvar">${ic('check')}</button>`, body: `<div class="grp"><label class="frow"><span class="k">Nome</span><input placeholder="Ex.: Viagens"></label><label class="frow"><span class="k">Descrição</span><input placeholder="Opcional"></label><label class="frow"><span class="k">Orçamento</span><input type="number" placeholder="R$ por mês"></label></div>`});
    ACT.ccEdit = a => { const k = a.dataset.k, c = D.costCenters[k]; sheet({title: c.name, right: `<button class="gb tint" data-act="closeOv" aria-label="Salvar">${ic('check')}</button>`, body: `<div class="dhero">${catAv(c, 'xl')}</div><div class="grp"><label class="frow"><span class="k">Nome</span><input value="${esc(c.name)}"></label><label class="frow"><span class="k">Descrição</span><input value="${esc(c.description)}"></label><label class="frow"><span class="k">Orçamento</span><input type="number" value="${c.monthlyBudget}"></label></div><button class="btn block red" data-act="ccDel" data-k="${k}">${ic('trash-2')}Excluir centro de custo</button>`}); };
    ACT.ccDel = a => { const k = a.dataset.k, c = D.costCenters[k]; delete D.costCenters[k]; closeOv(); refresh(); toast(`“${c.name}” excluído`, {action: 'Restaurar', fn: () => { D.costCenters[k] = c; refresh(); }}); };

    /* ---------- empresas e contas ---------- */
    S.companies = {
        title: 'Empresas e contas', parent: 'more',
        render: () => `${navb({title: 'Empresas e contas', large: true, right: gbtn('plus', 'data-act="coNew"', 'Nova empresa')})}<div class="scroll">${largeTitle('Empresas e contas')}
            <div class="pad"><div class="alert info">${ic('crown')}<div class="grow"><b>${D.companies.length} de 3 empresas</b><p>No plano Premium. O Enterprise permite até 50.</p></div></div></div>
            ${D.companies.map(co => `<section class="sec"><div class="sh" style="align-items:center"><span class="av solid sq sm" style="--c:${co.color}">${initials(co.name)}</span><span style="flex:1;min-width:0"><b style="font-size:17px;font-weight:600;display:block">${esc(co.name)}</b><small style="font-size:13px;color:var(--muted)">${co.typeLabel} · ${plural(co.accounts.length, 'conta', 'contas')}</small></span><b class="num" style="font-size:15px">${money(sum(co.accounts.filter(a => a.kind !== 'CREDIT'), acctBalance))}</b></div>
                <div class="grp av-rows">${co.accounts.map(a => { const on = state.ws.company === co.id && state.ws.account === a.id; return `<button class="row" data-act="pickWs" data-co="${co.id}" data-ac="${a.id}">${acctAv({...a, co})}<span class="rt"><span class="t">${esc(a.name)}</span><span class="s">${a.currency}${a.defaultAccount ? ' · padrão' : ''} ${E.modeTag(a)}</span></span><span class="rv num">${money(a.kind === 'CREDIT' ? -acctBalance(a) : acctBalance(a))}</span>${on ? ic('check', 'ck') : '<span style="width:20px"></span>'}</button>`; }).join('')}
                <button class="row tint" data-act="toastMsg" data-m="Nova conta: nome, moeda e se é a padrão"><span class="av sm" style="--c:${co.color}">${ic('plus')}</span><span class="rt"><span class="t" style="color:var(--tint);font-weight:500">Nova conta manual</span></span></button></div></section>`).join('')}
            <p class="foot-note">As contas do banco entram aqui quando você conecta um banco na aba Contas. Toque numa conta para passar a usá-la.</p>
        </div>`,
        notes: {d: 'Empresas (Familiar ou Empresa) e suas contas: manuais, do banco e congeladas, com moeda, saldo e conta padrão. A conta marcada é a que está em uso no app (e na web).', c: ['List agrupada por empresa', 'Folha para nova empresa e nova conta'], a: ['GET /api/workspace/overview', '/api/company', '/api/transaction/account', 'PUT /api/workspace (conta em uso, salva no servidor)']}
    };
    ACT.coNew = () => sheet({title: 'Nova empresa', right: `<button class="gb tint" data-act="closeOv" aria-label="Criar">${ic('check')}</button>`, body: `<div class="grp"><label class="frow"><span class="k">Nome</span><input placeholder="Ex.: Minha loja"></label></div>${seg([['FAMILY', 'Familiar'], ['BUSINESS', 'Empresa']], 'BUSINESS', 'segOne')}<p class="foot-note">Já vem com uma conta padrão em reais.</p>`});

    /* ---------- minha conta e exclusão ---------- */
    S.profile = {
        title: 'Minha conta', parent: 'more',
        render: () => `${navb({title: 'Minha conta', right: `<span class="tag green" style="height:30px;padding:0 12px">${ic('circle-check')}Salvo</span>`})}<div class="scroll">
            <div class="dhero" style="padding-top:8px"><span class="av xl solid" style="--c:#0B2545">${D.user.initials}</span><button class="link" data-act="toastMsg" data-m="Escolher nas Fotos ou tirar uma foto" data-i="camera">Trocar foto</button></div>
            <div class="sec"><div class="grp">
                <label class="frow"><span class="k">Nome</span><input value="${D.user.first}"></label>
                <label class="frow"><span class="k">Sobrenome</span><input value="${D.user.last}"></label>
                <div class="frow"><span class="k">E-mail</span><span class="val">${D.user.email}</span>${ic('lock', 'chev-sm')}</div>
                <label class="frow"><span class="k">CPF</span><input value="***.456.789-**"></label>
                <button class="frow" data-act="toastMsg" data-m="Real · Euro · Dólar"><span class="k">Moeda de exibição</span><span class="val">Real (R$)</span>${ic('chevrons-up-down', 'chev-sm')}</button>
                <label class="frow"><span class="k">Cidade</span><input value="São Paulo"></label>
            </div><p class="foot-note">Para trocar o e-mail, fale com o suporte. Tudo aqui se salva sozinho.</p></div>
            <section class="sec">${sh('Quem acessa a conta', '2 de 5 usuários')}<div class="grp av-rows">${D.users.map(u => `<div class="row"><span class="av solid" style="--c:${u.me ? '#0B2545' : '#7C3AED'}">${u.initials}</span><span class="rt"><span class="t">${u.name}${u.me ? ' (você)' : ''}</span><span class="s">${u.role}</span></span>${u.me ? '' : ic('chevron-right', 'chev')}</div>`).join('')}<button class="row" data-act="toastMsg" data-m="Convite enviado por e-mail (exemplo)" data-i="mail"><span class="av" style="--c:#047857">${ic('user-plus')}</span><span class="rt"><span class="t" style="color:var(--tint);font-weight:500">Convidar pessoa</span></span></button></div></section>
            <section class="sec">${shSmall('Privacidade e dados')}<div class="grp ic-rows" style="margin-top:-4px">${srow('shield-check', '#64748B', 'Política de privacidade', goAttr('web', {page: 'privacy'}), {web: true})}${srow('user-minus', '#DC2626', 'Excluir minha conta', goAttr('delete_account'), {red: true, sub: state.deletion ? `Pedido enviado em ${state.deletion}` : ''})}</div></section>
        </div>`,
        notes: {d: 'Dados do perfil, que se salvam sozinhos, as pessoas que acessam a conta e a área de privacidade, com a exclusão da conta.', c: ['Form com salvamento automático', 'PhotosPicker para a foto', 'Convite por e-mail'], a: ['GET/PUT /api/users']}
    };
    S.delete_account = {
        title: 'Excluir conta', parent: 'profile',
        render() {
            const d = state.deletion;
            return `${navb({title: 'Excluir conta'})}<div class="scroll">
                <div class="dhero"><span class="av xl" style="--c:#DC2626">${ic('user-minus')}</span><h2>Excluir sua conta do e-Finances</h2><p>Vale para você e para todas as empresas da conta.</p></div>
                ${d ? `<div class="pad"><div class="alert green">${ic('circle-check')}<div class="grow"><b>Pedido enviado em ${d}</b><p>A equipe confirma em até 2 dias úteis. Até 10/11/2026 você ainda pode reativar tudo entrando com a sua senha.</p><div class="acts"><button class="btn sm" data-act="delCancel">Cancelar o pedido</button></div></div></div></div>` : ''}
                <section class="sec">${sh('O que acontece')}<div class="grp ic-rows">${[['clock', '#0EA5E9', 'O pedido é analisado', 'Vira um chamado “Exclusão de conta” e a equipe confirma.'], ['lock', '#64748B', 'Ninguém mais entra', 'As sessões são encerradas, inclusive na web.'], ['rotate-ccw', '#16A34A', '30 dias para voltar atrás', 'Entrando com a senha: reativar tudo ou começar do zero.'], ['trash-2', '#DC2626', 'Depois, tudo é apagado', 'Empresas, lançamentos, comprovantes, bancos conectados e o seu acesso.'], ['file-text', '#CA8A04', 'O que a lei obriga a guardar', 'As faturas pagas ficam, com o titular anonimizado.']].map(([i, c, t, s]) => `<div class="row" style="align-items:flex-start">${si(i, c)}<span class="rt"><span class="t" style="font-weight:600">${t}</span><span class="s wrap">${s}</span></span></div>`).join('')}</div></section>
                ${d ? '' : `<section class="sec">${shSmall('Conte o motivo (opcional)')}<div class="chips wrap" style="padding:0 4px">${['Não uso mais', 'Achei difícil', 'Falta algum recurso', 'Preço', 'Outro'].map((l, i) => `<button class="chip" data-act="chipToggle">${l}</button>`).join('')}</div></section>
                <div class="pad"><button class="btn block red-fill" data-act="delAsk">Pedir a exclusão da conta</button></div>`}
                <p class="foot-note">Também dá para pedir pela web, em efinances.top/excluir-conta.</p>
            </div>`;
        },
        notes: {d: 'Exclusão da conta feita dentro do app, como a Apple exige: explica o que acontece, pede o motivo (opcional) e abre o pedido. São 30 dias para reativar; depois tudo é apagado, menos o que a lei obriga a guardar.', c: ['Form com explicação em linhas', 'Alerta de confirmação destrutivo', 'Estado do pedido com “Cancelar o pedido”'], a: ['POST /api/ticket (categoria Exclusão de conta) ou a rota de exclusão da web', 'Reativação no login: Reativar tudo / Começar do zero'], warn: 'App Store (diretriz 5.1.1(v)): app que deixa criar conta precisa deixar pedir a exclusão dentro do app. A web já tem o fluxo (PR #39); o app usa o mesmo.'}
    };
    ACT.chipToggle = a => a.classList.toggle('on');
    ACT.delAsk = () => alertBox({title: 'Excluir sua conta?', text: 'Você e as pessoas convidadas perdem o acesso agora. Você tem 30 dias para reativar; depois disso, os dados são apagados.', buttons: [{label: 'Cancelar'}, {label: 'Excluir', cls: 'red', fn: () => { state.deletion = '11/10/2026'; refresh(); toast('Pedido de exclusão enviado', {icon: 'circle-check'}); }}]});
    ACT.delCancel = () => { state.deletion = null; refresh(); toast('Pedido cancelado. Sua conta continua ativa.', {icon: 'rotate-ccw'}); };

    /* ---------- preferências ---------- */
    S.notif_prefs = {
        title: 'Notificações', parent: 'more',
        render: () => `${navb({title: 'Notificações', large: true})}<div class="scroll">${largeTitle('Notificações')}
            <section class="sec">${shSmall('Canais')}<div class="grp">${toggleRow('push', 'No iPhone', 'Notificações com som e na tela bloqueada')}${toggleRow('email', 'Por e-mail', D.user.email)}${toggleRow('sms', 'Por SMS', 'Em breve · plano Enterprise', true)}</div></section>
            <section class="sec">${shSmall('O que avisar')}<div class="grp">${toggleRow('due', 'Contas a vencer', 'Um dia antes e no dia, com “Marcar como pago”')}${toggleRow('limit', 'Limite de categoria', 'Ao chegar no % de alerta e ao passar')}${toggleRow('payment', 'Pagamentos e plano', 'Faturas e renovação')}${toggleRow('support', 'Respostas do suporte')}${toggleRow('security', 'Novo acesso à conta', 'Recomendado')}</div></section>
            <section class="sec">${shSmall('Quando')}<div class="grp">${checkRow('when', 'now', 'Na hora')}${checkRow('when', 'window', 'Só em dias e horários escolhidos', 'Seg a sex, das 8h às 20h')}</div></section>
            <section class="sec">${shSmall('Fechamento do mês')}<div class="grp">${checkRow('story', 'MONTHLY', 'Todo mês', 'Padrão')}${checkRow('story', 'WEEKLY', 'Toda semana')}${checkRow('story', 'DAILY', 'Todo dia')}${checkRow('story', 'NONE', 'Não mostrar')}</div></section>
            <div class="sec"><div class="grp ic-rows">${srow('settings', '#64748B', 'Abrir os Ajustes do iPhone', 'data-act="toastMsg" data-m="Abriria Ajustes › Notificações › e-Finances" data-i="settings"', {web: true})}</div><p class="foot-note">Estilo dos avisos, sons e resumo programado ficam nos Ajustes do iPhone.</p></div>
        </div>`,
        notes: {d: 'O que avisar, por qual canal e quando, e com que frequência aparece o fechamento do mês.', c: ['Toggle e linhas com ✓ (List)', 'UNUserNotificationCenter com categorias e ações', 'Atalho para os Ajustes do app'], a: ['GET/PUT /api/notification-preferences', 'GET/PUT /api/story/preferences']}
    };
    S.appearance = {
        title: 'Aparência', parent: 'more', themeAware: true,
        render: () => `${navb({title: 'Aparência', large: true})}<div class="scroll">${largeTitle('Aparência')}
            <section class="sec">${shSmall('Tema')}<div class="card"><div class="themes">${[['system', 'Automático'], ['light', 'Claro'], ['dark', 'Escuro']].map(([k, l]) => `<button class="thm ${state.theme === k ? 'on' : ''}" data-act="setTheme" data-v="${k}"><span class="tp ${k}"><i></i><i></i><i></i></span>${l}<span class="radio ${state.theme === k ? 'on' : ''}">${state.theme === k ? ic('check') : ''}</span></button>`).join('')}</div></div></section>
            <section class="sec">${shSmall('Ícone do app')}<div class="card"><div class="icons-alt">${[['navy', 'Marinho', '#0B2545', '#FFFFFF', '#10B981'], ['green', 'Verde', '#10B981', '#0B2545', '#FFFFFF'], ['dark', 'Escuro', '#05080D', '#FFFFFF', '#34D399'], ['light', 'Claro', '#FFFFFF', '#0B2545', '#10B981']].map(([k, l, bg, fg, bar]) => `<button class="${state.prefs.icon === k ? 'on' : ''}" data-act="prefIcon" data-v="${k}"><span class="appic" style="background:${bg}">${appIcon(bg, fg, bar)}</span>${l}</button>`).join('')}</div></div><p class="foot-note">O iOS também cria as versões escura e colorida do ícone sozinho.</p></section>
            <section class="sec">${shSmall('Idioma')}<div class="grp ic-rows">${srow('globe', '#0EA5E9', 'Idioma do app', 'data-act="toastMsg" data-m="Abriria Ajustes › e-Finances › Idioma" data-i="globe"', {val: 'Português', web: true})}</div><p class="foot-note">No iPhone, o idioma de cada app muda nos Ajustes.</p></section>
            <section class="sec">${shSmall('Privacidade na tela')}<div class="grp">${toggleRow('hideOnOpen', 'Esconder valores ao abrir', 'Mostra R$ •••• até você tocar no olho')}</div></section>
        </div>`,
        notes: {d: 'Tema automático, claro ou escuro, ícone alternativo do app, idioma e esconder valores ao abrir.', c: ['preferredColorScheme com as cores da marca nos dois modos', 'Ícones alternativos (setAlternateIconName)', 'Idioma por app pelos Ajustes do iOS'], a: ['PUT /api/users (aparência salva na conta, como na web)'], tip: 'Troque o tema aqui ou no seletor “Tema do app” ao lado.'}
    };
    ACT.setTheme = a => setTheme(a.dataset.v);
    ACT.prefIcon = a => { state.prefs.icon = a.dataset.v; refresh(); alertBox({title: 'Você alterou o ícone de “e-Finances”.', buttons: [{label: 'OK', cls: 'pri'}]}); };
    S.security = {
        title: 'Face ID e segurança', parent: 'more',
        render: () => `${navb({title: 'Segurança', large: true})}<div class="scroll">${largeTitle('Face ID e segurança')}
            <div class="sec"><div class="grp">${toggleRow('bio', 'Desbloquear com Face ID', 'Ao abrir o app. Sem Face ID, vale o código do iPhone.')}${toggleRow('blur', 'Cobrir no alternador de apps', 'Esconde os valores quando você troca de app')}</div></div>
            <section class="sec">${shSmall('Bloquear o app depois de')}<div class="grp">${[['0', 'Na hora'], ['1', '1 minuto'], ['5', '5 minutos'], ['15', '15 minutos']].map(([k, l]) => checkRow('lock', k, l)).join('')}</div></section>
            <div class="sec"><div class="grp ic-rows">${srow('key-round', '#1D4E89', 'Trocar senha', 'data-act="toastMsg" data-m="Enviamos um link para trocar a senha" data-i="mail"', {sub: 'Enviamos um link para o seu e-mail'})}</div></div>
            <section class="sec">${sh('Sessões abertas')}<div class="grp ic-rows">${D.sessions.map(s => `<div class="row">${si(s.icon, '#1D4E89')}<span class="rt"><span class="t">${s.device}</span><span class="s">${s.detail} · ${s.when}</span></span>${s.current ? '<span class="tag green">Este</span>' : `<button class="btn sm gray" data-act="toastMsg" data-m="Sessão encerrada">Encerrar</button>`}</div>`).join('')}</div>
                <button class="btn block gray" data-act="toastMsg" data-m="Outras sessões encerradas" data-i="log-out">${ic('log-out')}Sair dos outros aparelhos</button></section>
        </div>`,
        notes: {d: 'Face ID, bloqueio automático, tela coberta no alternador de apps, sessões abertas e troca de senha.', c: ['LocalAuthentication', 'Tokens no Keychain (kSecAttrAccessibleWhenUnlockedThisDeviceOnly)', 'Cobertura da tela ao ir para segundo plano (scenePhase)', 'App Transport Security só com HTTPS'], a: ['/api/auth (sessões e bloqueio)'], warn: 'O iOS não deixa bloquear prints como o Android (FLAG_SECURE). O app cobre a tela no alternador e pode esconder os valores ao abrir.'}
    };

    /* ---------- plano ---------- */
    S.billing = {
        title: 'Plano e faturas', parent: 'more',
        render: () => `${navb({title: 'Plano e faturas', large: true})}<div class="scroll">${largeTitle('Plano e faturas')}
            <div class="pad"><section class="hero">${WM}<span class="lab">Seu plano</span><div class="big">Premium</div><p class="fore">Mensal · válido até <b>12/11/2026</b></p>
                <div class="split"><div><span class="k">${ic('building-2')}Empresas</span><span class="v">2 de 3</span><span class="bar"><i style="width:66%"></i></span></div><div><span class="k">${ic('cloud')}Comprovantes</span><span class="v">340 MB</span><span class="bar"><i style="width:17%"></i></span><span class="s">de 2 GB</span></div></div></section>
            <button class="btn block green" ${goAttr('plans')}>${ic('crown')}Mudar de plano</button></div>
            <section class="sec">${sh('Faturas')}<div class="grp ic-rows">${D.invoices.map(i => `<button class="row" data-act="shareSheet" data-what="fatura-${i.date.replace(/\//g, '-')}.pdf">${si('receipt-text', '#059669')}<span class="rt"><span class="t">${i.desc}</span><span class="s">${i.date}</span></span><span class="rv num">${money(i.value)}<small>${i.status}</small></span>${ic('chevron-right', 'chev')}</button>`).join('')}</div></section>
        </div>`,
        notes: {d: 'Plano atual, uso (empresas e espaço de comprovantes) e faturas.', c: ['Cartão do plano com o uso', 'Lista de faturas em PDF'], a: ['GET /api/plan', 'GET /api/invoice/find']}
    };
    S.plans = {
        title: 'Mudar de plano', parent: 'billing',
        render() {
            const disc = {MONTHLY: 0, QUARTERLY: .05, SEMESTERLY: .1, YEARLY: .2};
            return `${navb({title: 'Mudar de plano'})}<div class="scroll">
                <div class="dhero"><span class="av xl" style="--c:#CA8A04">${ic('crown')}</span><h2>Escolha o seu plano</h2><p>Troque ou cancele quando quiser.</p></div>
                <div class="pad">${seg([['MONTHLY', 'Mensal'], ['QUARTERLY', 'Trimestral'], ['SEMESTERLY', 'Semestral'], ['YEARLY', 'Anual']], state.planPeriod, 'planPeriod')}
                ${state.planPeriod !== 'MONTHLY' ? `<p class="foot-note" style="text-align:center;color:var(--tint);font-weight:600">${Math.round(disc[state.planPeriod] * 100)}% de desconto no período</p>` : ''}
                ${D.plans.map(p => `<button class="plan ${state.planPick === p.id ? 'on' : ''}" data-act="planPick" data-v="${p.id}"><span class="pn"><h3>${p.name}</h3>${p.id === 'PREMIUN' ? '<span class="tag green">Seu plano</span>' : `<span class="radio ${state.planPick === p.id ? 'on' : ''}">${state.planPick === p.id ? ic('check') : ''}</span>`}</span><span class="pr num">${fmt(p.price * (1 - disc[state.planPeriod]))}<small> /mês</small></span><ul>${p.features.map(f => `<li>${ic('check')}${f}</li>`).join('')}</ul></button>`).join('')}
                <button class="btn block" data-act="planBuy" ${state.planPick === 'PREMIUN' ? 'disabled' : ''}>${state.planPick === 'PREMIUN' ? 'Este já é o seu plano' : 'Assinar pela App Store'}</button>
                <div style="display:flex;justify-content:center;gap:18px"><button class="link" data-act="toastMsg" data-m="Compras restauradas">Restaurar compras</button><button class="link" ${goAttr('web', {page: 'terms'})}>Termos</button><button class="link" ${goAttr('web', {page: 'privacy'})}>Privacidade</button></div>
                <p class="foot-note" style="text-align:center">Preços ilustrativos. A assinatura renova sozinha e é cobrada pela conta Apple; cancele em Ajustes › Assinaturas.</p></div>
            </div>`;
        },
        notes: {d: 'Comparação dos planos (Basic, Premium, Enterprise) por período e troca de plano pela App Store.', c: ['StoreKit 2 (assinaturas com renovação automática)', 'Restaurar compras e links de termos e privacidade (exigidos pela Apple)'], a: ['/api/plan', '/api/voucher', 'Novo no backend: validar a compra pela App Store Server API'], warn: 'Na App Store, plano digital comprado dentro do app tem que usar a compra da Apple (In-App Purchase). Duas saídas: (1) ligar o StoreKit e validar no backend; (2) na 1ª versão, deixar a compra de fora do app, como fizemos no Android (o app mostra o plano, sem preços nem link para pagar). Precisamos decidir antes de publicar.'}
    };
    ACT.planPeriod = a => { state.planPeriod = a.dataset.v; refresh(); };
    ACT.planPick = a => { state.planPick = a.dataset.v; refresh(); };
    ACT.planBuy = () => toast('Abriria a compra da App Store (StoreKit)', {icon: 'crown'});

    /* ---------- ajuda e suporte ---------- */
    S.help = {
        title: 'Ajuda e suporte', parent: 'more',
        render: () => `${navb({title: 'Ajuda e suporte', large: true, right: `<button class="gb tint" ${goAttr('ticket_new')} aria-label="Novo chamado">${ic('plus')}</button>`})}<div class="scroll">${largeTitle('Ajuda e suporte')}
            <label class="search">${ic('search')}<input placeholder="Buscar nas perguntas frequentes" aria-label="Buscar ajuda"></label>
            <section class="sec">${sh('Meus chamados', '', linkBtn('Novo', goAttr('ticket_new')))}<div class="grp ic-rows">${D.tickets.map(t => `<button class="row" data-act="ticketSheet" data-id="${t.id}">${si(t.category === 'DUVIDA' ? 'circle-help' : 'bug', t.tone === 'amber' ? '#D97706' : '#64748B')}<span class="rt"><span class="t">${esc(t.subject)}</span><span class="s">#${t.id} · ${t.when}</span></span><span class="tag ${t.tone === 'amber' ? 'amber' : ''}">${t.status}</span></button>`).join('')}</div></section>
            <section class="sec">${sh('Perguntas frequentes')}<div class="grp">${D.faq.map((f, i) => `<div class="acc ${state.openFaq === i ? 'open' : ''}"><button class="q" data-act="faq" data-i="${i}" aria-expanded="${state.openFaq === i}">${f.q}${ic('chevron-right')}</button><p class="a">${f.a}</p></div>`).join('')}</div></section>
            <div class="sec"><div class="grp ic-rows">${srow('headset', '#0EA5E9', 'Falar com o suporte', goAttr('ticket_new'), {sub: 'Respondemos aqui e por e-mail'})}${srow('quote', '#7C3AED', 'Deixar um depoimento', 'data-act="testimony"', {sub: 'Pode aparecer no site do e-Finances'})}</div></div>
        </div>`,
        notes: {d: 'Busca nas perguntas frequentes (o mesmo conteúdo da web), chamados com as respostas, novo chamado e depoimento.', c: ['DisclosureGroup para as perguntas', 'Conversa do chamado em folha', 'Folha de depoimento com nota e autorização'], a: ['GET/POST /api/ticket', 'POST /api/testimonial (depoimento)']}
    };
    ACT.faq = a => { const i = +a.dataset.i; state.openFaq = state.openFaq === i ? -1 : i; refresh(); };
    ACT.ticketSheet = a => { const t = D.tickets.find(x => x.id === +a.dataset.id); sheet({title: t.subject, sub: `#${t.id} · ${t.status}`, large: true, body: `<div class="msgs">${t.messages.map(m => `<div class="msg ${m.me ? 'me' : ''}">${esc(m.text)}<small>${m.me ? 'Você' : 'Suporte e-Finances'} · ${m.at}</small></div>`).join('')}</div>${t.tone === 'amber' ? `<div class="inp" style="border-radius:24px;margin-top:auto">${ic('message-circle')}<input placeholder="Responder" aria-label="Responder"><button class="gb tint" style="width:34px;height:34px;margin-right:-8px" data-act="toastMsg" data-m="Resposta enviada" aria-label="Enviar">${ic('arrow-up')}</button></div>` : ''}`, foot: t.tone === 'amber' ? '<button class="btn gray" data-act="closeOv">Resolvido, obrigado</button>' : ''}); };
    ACT.testimony = () => sheet({title: 'Seu depoimento', right: `<button class="gb tint" data-act="testSend" aria-label="Enviar">${ic('check')}</button>`, body: `<div style="display:flex;justify-content:center;gap:10px">${[1, 2, 3, 4, 5].map(n => `<button data-act="stars" data-v="${n}" aria-label="${n} estrelas" style="font-size:34px;color:${n <= state.stars ? '#F59E0B' : 'var(--fill-2)'}">★</button>`).join('')}</div>
        <div class="inp ta"><textarea placeholder="Conte como o e-Finances ajuda você"></textarea></div>
        ${seg([['full', 'Nome completo'], ['first', 'Só o primeiro nome'], ['anon', 'Anônimo']], 'first', 'segOne')}
        <div class="grp"><button class="row" data-act="tgSelf"><span class="rt"><span class="t">Autorizo publicar no site</span><span class="s wrap">A equipe revisa antes. Dá para pedir para tirar quando quiser.</span></span>${tg(true)}</button></div>`});
    ACT.stars = a => { state.stars = +a.dataset.v; [...a.parentElement.children].forEach((b, i) => { b.style.color = i < state.stars ? '#F59E0B' : 'var(--fill-2)'; }); };
    ACT.tgSelf = a => $('.tg', a).classList.toggle('on');
    ACT.testSend = () => { closeOv(); toast('Obrigado! A equipe vai revisar seu depoimento.', {icon: 'quote'}); };
    S.ticket_new = {
        title: 'Novo chamado', parent: 'help', modal: true,
        render: () => `${navb({back: false, title: 'Novo chamado', left: `<button class="gb glass" data-back aria-label="Cancelar">${ic('x')}</button>`, right: `<button class="gb tint" data-act="ticketSend" aria-label="Enviar">${ic('arrow-up')}</button>`})}<div class="scroll">
            <section class="sec">${shSmall('Sobre o quê?')}<div class="grp ic-rows">${[['DUVIDA', 'Dúvida', 'Como fazer algo no app', 'circle-help'], ['PROBLEMA', 'Problema ou erro', 'Algo não funcionou como deveria', 'bug'], ['FINANCEIRO', 'Plano e cobrança', 'Plano, pagamento, faturas', 'credit-card'], ['CONTA', 'Minha conta e acesso', 'Login, usuários, dados', 'user-round'], ['SUGESTAO', 'Sugestão', 'Uma ideia para melhorar', 'lightbulb']].map(([k, l, h, i]) => `<button class="row" data-act="tCat" data-v="${k}">${si(i, '#1D4E89')}<span class="rt"><span class="t">${l}</span><span class="s">${h}</span></span>${state.ticketCat === k ? ic('check', 'ck') : ''}</button>`).join('')}</div></section>
            <div class="sec"><div class="grp"><label class="frow"><span class="k">Assunto</span><input placeholder="Resuma em poucas palavras"></label><label class="frow stack"><span class="k">Mensagem</span><textarea placeholder="Conte o que aconteceu" style="min-height:110px"></textarea></label></div></div>
            <div class="pad"><button class="file add" data-act="attach" style="height:56px">${ic('image')}Anexar print da tela</button>
            <p class="foot-note" style="padding:0">${ic('smartphone')} Enviamos junto o modelo do iPhone, a versão do iOS e a do app para agilizar.</p></div>
        </div>`,
        notes: {d: 'Novo chamado com categoria, assunto, mensagem e print. O app envia junto o aparelho e a versão.', c: ['Folha em tela cheia com X e enviar', 'PhotosPicker para o print'], a: ['POST /api/ticket']}
    };
    ACT.tCat = a => { state.ticketCat = a.dataset.v; refresh(); };
    ACT.ticketSend = () => { back(); setTimeout(() => toast('Chamado #493 aberto. Respondemos aqui e por e-mail.', {icon: 'headset'}), 420); };

    /* ---------- páginas que abrem na web (Safari dentro do app) ---------- */
    const WEB = {
        import: ['Importar extrato', '/finances/import', 'Envie o XLSX ou XLS do seu banco (até 10 MB). A web reconhece Banco do Brasil, Millennium bcp, ActivoBank e o modelo e-Finances, mostra a prévia e importa para a conta em uso.'],
        export: ['Exportar transações', '/finances/export', 'Escolha o período, a situação e os tipos. Sai um Excel com resumo por mês ou um CSV, pronto para o contador.'],
        receipts: ['Modelos de recibo', '/finances/receipts', 'Crie até 12 modelos com campos dinâmicos e pré-visualização. No app, o recibo é emitido a partir de um lançamento.'],
        privacy: ['Política de privacidade', '/privacidade', 'Quem cuida dos seus dados, o que é coletado, para quê, por quanto tempo e como pedir a exclusão.'],
        terms: ['Termos de uso', '/termos', 'As regras de uso do e-Finances.']
    };
    S.web = {
        title: 'Abre na web', parent: 'more', modal: true,
        render(p) {
            const [t, path, d] = WEB[p.page] || WEB.import;
            return `<header class="navb solid" data-nav style="grid-template-columns:auto 1fr auto"><div class="nl"><button class="gb glass txt" data-back>OK</button></div><div class="nt" style="max-width:none;display:flex;align-items:center;justify-content:center;gap:6px;font-size:15px;font-weight:500">${ic('lock')}efinances.top</div><div class="nr">${gbtn('external-link', 'data-act="toastMsg" data-m="Abriria no Safari" data-i="globe"', 'Abrir no Safari')}</div></header>
                <div class="scroll"><div class="pad" style="padding-top:8px">
                    <div style="display:flex;align-items:center;gap:10px"><span style="width:34px;height:34px">${markSvg(isDark())}</span><b class="disp" style="font-size:18px">e<span style="color:#10B981">·</span>finances</b><span style="margin-left:auto;font-size:13px;color:var(--muted)">${path}</span></div>
                    <h1 class="disp" style="font-size:28px;font-weight:700;margin-top:10px">${t}</h1><p style="font-size:16px;line-height:1.5;color:var(--text)">${d}</p>
                    <div class="card" style="height:220px;background:repeating-linear-gradient(-45deg, var(--surface), var(--surface) 12px, var(--surface-2) 12px, var(--surface-2) 24px);align-items:center;justify-content:center;color:var(--muted);font-size:14px">A página da web aparece aqui, já com a sua sessão</div>
                </div></div>`;
        },
        notes: {d: 'Importar e exportar extrato, modelos de recibo, termos e privacidade abrem a página da web dentro do app (sem sair dele), já com a sessão. Mesmo combinado do Android.', c: ['SFSafariViewController / ASWebAuthenticationSession', 'Botão OK para voltar ao app'], a: ['Páginas da web em efinances.top']}
    };

    /* ---------- extras do iPhone: widgets, atalhos e tela bloqueada ---------- */
    const efIco = () => `<span class="ico" style="background:#0B2545">${appIcon()}</span>`;
    S.extras_home = {
        title: 'Widgets e atalhos', parent: 'more', bare: true, light: true,
        render() {
            const list = monthTx(BASE.y, BASE.m, 'cc'), T = totals(list), bal = acctBalance(D.companies[0].accounts[0]);
            const due = list.filter(t => !t.paid && E.days(t.date) <= 4).sort((a, b) => a.date.localeCompare(b.date)).slice(0, 3);
            const lims = limitRows().sort((a, b) => b.p - a.p).slice(0, 2);
            return `<div class="home-ios" data-act="closeQa">
                <div class="wgrid">
                    <button class="wgt m" data-act="wOpen"><span class="wh"><span style="width:16px;height:16px;border-radius:5px;background:#0B2545;display:inline-flex;align-items:center;justify-content:center">${appIcon()}</span>e-Finances · Casa</span>
                        <span style="display:flex;gap:14px;align-items:flex-start"><span style="flex:none"><span style="font-size:12px;color:#66768D">Saldo</span><span class="wb num" style="display:block">${fmt(bal).replace(/,\d+$/, '')}</span><span style="font-size:12px;color:#66768D">${state.hide ? '' : 'fecha em ' + fmt(bal + T.inc - T.incPaid - (T.exp - T.expPaid)).replace(/,\d+$/, '')}</span></span>
                        <span style="flex:1;min-width:0;display:flex;flex-direction:column;gap:7px">${due.map(t => `<span class="wl"><span class="pchk ${t.paid ? 'on' : ''}" data-act="wPay" data-id="${t.id}" role="button" aria-label="Marcar ${esc(t.desc)} como pago">${t.paid ? ic('check') : ''}</span><span class="grow">${esc(t.desc)}</span><b class="num" style="font-size:12.5px">${fmt(t.value).replace('R$ ', '')}</b></span>`).join('')}</span></span></button>
                    <button class="wgt s" data-act="wOpen"><span class="wh">${ic('calendar-clock')}Vence hoje</span><span class="wb" style="font-size:22px">R$ 164</span><span style="font-size:13px;color:#66768D">Ração e banho</span><span style="margin-top:auto;font-size:12px;font-weight:600;color:#B45309">+ 2 atrasadas</span></button>
                    <button class="wgt s" data-act="wOpen"><span class="wh">${ic('flag')}Limites</span>${lims.map(l => `<span style="display:flex;flex-direction:column;gap:4px"><span style="display:flex;justify-content:space-between;font-size:13px"><span>${D.categories[l.cat].name}</span><b class="lp ${l.status}" style="font-size:13px">${Math.round(l.p)}%</b></span><span class="prog ${l.status}" style="height:5px;background:rgba(112,128,156,.18)"><i style="width:${Math.min(l.p, 100)}%"></i></span></span>`).join('')}</button>
                    <span class="appi" data-act="qaMenu" role="button" tabindex="0" aria-label="e-Finances: segure para atalhos">${efIco()}e-Finances</span>
                    ${[['Fotos', '#F59E0B', 'image'], ['Câmera', '#475569', 'camera'], ['Ajustes', '#64748B', 'settings']].map(([n, c, i]) => `<span class="appi"><span class="ico" style="background:${c}">${ic(i)}</span>${n}</span>`).join('')}
                </div>
                <p style="font-size:13px;opacity:.85;text-align:center;line-height:1.4;margin-top:4px">Toque no ícone do e-Finances para ver os atalhos.<br>Toque no círculo de uma conta para pagar sem abrir o app.</p>
                <div class="dock">${[['Telefone', '#16A34A', 'phone'], ['Safari', '#0EA5E9', 'globe'], ['Mensagens', '#22C55E', 'message-circle'], ['Música', '#EF4444', 'music']].map(([n, c, i]) => `<span class="appi"><span class="ico" style="background:${c}">${ic(i)}</span></span>`).join('')}</div>
                ${state.qa ? `<div class="qa-menu" style="left:22px;top:526px" role="menu">${[['arrow-down-left', 'Novo recebimento', 'R'], ['arrow-up-right', 'Nova despesa', 'V'], ['calendar-clock', 'Contas a pagar', ''], ['search', 'Buscar lançamento', 's']].map(([i, l, k]) => `<button data-act="qaGo" data-k="${k}">${ic(i)}${l}</button>`).join('')}</div>` : ''}
            </div>`;
        },
        notes: {d: 'Proposta de extras do iPhone: widgets na tela de início (saldo e contas que vencem, com o círculo para pagar sem abrir o app; o que vence hoje; limites) e atalhos ao segurar o ícone. Também dá para lançar pela Siri (“lançar despesa no e-Finances”).', c: ['WidgetKit com widgets interativos (App Intents)', 'Home Screen Quick Actions', 'App Shortcuts (Siri e Spotlight)', 'App Group para o widget ler os dados'], a: ['Os widgets usam os mesmos dados do app, atualizados em segundo plano'], warn: 'Extras propostos para o iPhone, fora do que o Android tem. Diga se quer na 1ª versão ou depois.'}
    };
    S.extras_lock = {
        title: 'Tela bloqueada', parent: 'more', bare: true, light: true,
        render: () => `<div class="lock-ios"><span class="ld">domingo, 11 de outubro</span><span class="lt2">9:41</span>
            <div class="lw"><div><span>Saldo · Casa</span><b>${state.hide ? 'R$ ••••' : 'R$ 8.432'}</b></div><div><span>Vence hoje</span><b>R$ 164,00</b></div></div>
            <div style="flex:1"></div>
            <button class="lnotif" data-act="lockOpen"><span class="ico" style="background:#0B2545;display:flex;align-items:center;justify-content:center">${appIcon()}</span><span class="grow"><span style="display:flex;justify-content:space-between"><b>Condomínio está atrasado</b><time>agora</time></span><p>Venceu em 07/10 · R$ 680,00 · Cond. Jardim das Flores</p></span></button>
            <div class="lnotif-acts">${state.lockPaid ? '<button style="justify-content:center;color:#047857">✓ Marcado como pago</button>' : `<button data-act="lockPay">Marcar como pago ${ic('circle-check')}</button><button data-act="lockLater">Lembrar amanhã ${ic('clock')}</button>`}</div>
            <p style="font-size:13px;opacity:.75;margin-top:10px">Segure a notificação para ver as ações. Ao marcar como pago, o app pede o Face ID.</p>
        </div>`,
        notes: {d: 'Proposta: avisos de conta a vencer com ações direto da tela bloqueada (“Marcar como pago”, “Lembrar amanhã”) e widgets da tela bloqueada com saldo e o que vence hoje.', c: ['Notificações com UNNotificationAction (pedem Face ID para ações sensíveis)', 'Widgets da tela bloqueada (WidgetKit, família accessory)'], a: ['Push com a categoria “conta a vencer”', 'POST /api/transaction/update (pagar)'], warn: 'Extra proposto para o iPhone. Diga se quer na 1ª versão.'}
    };
    ACT.closeQa = (a, e) => { if (state.qa && !e.target.closest('.qa-menu')) { state.qa = false; refresh(); } };
    ACT.qaMenu = (a, e) => { e.stopPropagation(); state.qa = !state.qa; refresh(); };
    ACT.qaGo = (a, e) => {
        e.stopPropagation(); state.qa = false; const k = a.dataset.k;
        state.ws = {company: 1, account: 'cc'};
        if (k === 'R' || k === 'V') { resetTo('home'); setTimeout(() => { state.draft = E.newDraft(k); go('tx_form'); }, 300); }
        else if (k === 's') { resetTo('tx'); setTimeout(() => { const q = $('#q'); q && q.focus(); }, 300); }
        else ACT.goPending();
    };
    ACT.wOpen = (a, e) => { if (e.target.closest('[data-act="wPay"]')) return; state.ws = {company: 1, account: 'cc'}; resetTo('home'); };
    ACT.wPay = (a, e) => { e.stopPropagation(); const t = E.findTx(a.dataset.id); E.setPaid(t, true); refresh(); toast(`${esc(t.desc)}: pago pelo widget`, {icon: 'circle-check'}); };
    ACT.lockPay = () => { E.openOv(`<div class="scrim clear"></div><div class="fid-wrap"><div class="fidbox">${FACEID.replace('class="faceid"', 'class="faceid scan"')}Face ID</div></div>`); setTimeout(() => { closeOv(); const t = E.findTx(5); E.setPaid(t, true); state.lockPaid = true; refresh(); }, 800); };
    ACT.lockLater = () => toast('Vamos lembrar amanhã às 9h', {icon: 'clock'});
    ACT.lockOpen = () => { state.ws = {company: 1, account: 'cc'}; resetTo('tx_detail', {id: 5}); };
})();
