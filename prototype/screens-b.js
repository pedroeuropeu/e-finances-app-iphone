/* e-Finances iPhone · protótipo: Contas (bancos conectados), Planejar, fechamento do mês, notificações e relatórios. */
'use strict';
(() => {
    const E = window.EF, D = E.D, S = E.S, ACT = E.ACT, state = E.state;
    const {$, $$, esc, ic, fmt, sum, pct, norm, initials, goAttr, plural, cap, TODAY, BASE, MONTHS, MON, parse, dm, dmy, days, PAY, CONTACT_CAT, CONTACT_COLOR, NCAT, NSEV, markSvg, WM,
        company, account, acctBalance, bankOf, catOf, monthTx, totals, byCategory, groupBy, limitRows, avg3, subsMonthly, bankAccounts, bankTotals,
        money, signed, bigMoney, compactMoney, navb, largeTitle, gbtn, gtxt, gbs, sh, linkBtn, tg, seg, catAv, bankAv, acctAv, si, txItem, pring, donut, barChart, limRow, kpi, delta, calendar,
        sheet, alertBox, actionSheet, contextMenu, toast, closeOv, cur, refresh, go, back, tab, resetTo} = E;

    /* ---------- contas (bancos conectados + contas do e-Finances) ---------- */
    S.banks = {
        title: 'Contas', tab: 'banks', root: true,
        render() {
            const T = bankTotals(), kind = state.bankKind, need = D.banks.filter(b => b.status !== 'UPDATED');
            const banks = D.banks.map(b => ({...b, accounts: b.accounts.filter(a => kind === 'all' || a.kind === kind)})).filter(b => b.accounts.length);
            const manual = D.companies.map(co => ({co, list: co.accounts.filter(a => a.mode === 'MANUAL')}));
            const frozenL = E.allAccounts().filter(a => a.mode === 'FROZEN');
            return `${navb({back: false, large: true, title: 'Contas', right: `${gbs(['refresh-cw', 'data-act="syncAll"', 'Atualizar todos'], ['eye' + (state.hide ? '-off' : ''), 'data-act="toggleHide"', state.hide ? 'Mostrar valores' : 'Esconder valores'])}<button class="gb tint" data-act="connectSheet" aria-label="Conectar banco">${ic('plus')}</button>`})}
            <div class="scroll">
                ${largeTitle('Contas', 'Bancos conectados e contas do e-Finances')}
                <div class="pad"><section class="hero">${WM}
                    <span class="lab">Saldo nos bancos conectados</span><div class="big num">${bigMoney(T.bal)}</div>
                    <p class="fore">${plural(D.banks.length, 'banco', 'bancos')} · ${T.n} contas e cartões</p>
                    <div class="split">
                        <div><span class="k">${ic('credit-card')}Faturas abertas</span><span class="v num">${money(T.inv)}</span><span class="bar ex"><i style="width:${pct(T.limit - T.avail, T.limit)}%"></i></span><span class="s">${pct(T.limit - T.avail, T.limit)}% do limite usado</span></div>
                        <div><span class="k">${ic('piggy-bank')}Limite disponível</span><span class="v num">${money(T.avail)}</span><span class="bar"><i style="width:${pct(T.avail, T.limit)}%"></i></span><span class="s">de ${money(T.limit)}</span></div>
                    </div></section></div>
                ${need.map(b => `<div class="pad"><div class="alert">${ic('refresh-cw')}<div class="grow"><b>${b.name} precisa de você</b><p>A autorização expirou ${b.updated}. Reconecte para voltar a sincronizar.</p><div class="acts"><button class="btn sm" data-act="reconnect" data-b="${b.id}">Reconectar</button></div></div></div></div>`).join('')}
                <div class="pad">${seg([['all', 'Todas'], ['BANK', 'Contas'], ['CREDIT', 'Cartões']], kind, 'bankKind')}</div>
                ${banks.map(b => `<section class="sec"><div class="sh" style="align-items:center">${bankAv(b, 'sm')}<span style="flex:1;min-width:0"><b style="font-size:17px;font-weight:600;display:block">${b.name}</b><small style="font-size:13px;color:${b.status === 'UPDATED' ? 'var(--muted)' : 'var(--warn)'}">em ${esc(company(b.company).name)} · ${b.status === 'UPDATED' ? `atualizado ${b.updated}` : 'precisa reconectar'}</small></span>${gbtn('ellipsis', `data-act="bankMenu" data-b="${b.id}"`, `Opções do ${b.name}`)}</div>
                    <div class="grp av-rows">${b.accounts.map(a => `<button class="row" ${goAttr('bank_account', {b: b.id, a: a.id})}><span class="av sq" style="--c:${b.color}">${ic(a.kind === 'CREDIT' ? 'credit-card' : 'landmark')}</span><span class="rt"><span class="t">${a.name}${state.ws.account === a.id ? ' <span class="tag green">Em uso</span>' : ''}</span><span class="s">${a.kind === 'CREDIT' ? `Fecha em ${a.due} · disponível ${money(a.available)}` : 'Conta bancária'}</span></span><span class="rv num">${money(a.kind === 'CREDIT' ? a.invoice : a.balance)}<small>${a.kind === 'CREDIT' ? 'fatura' : 'saldo'}</small></span>${ic('chevron-right', 'chev')}</button>`).join('')}</div></section>`).join('')}
                <section class="sec">${sh('Contas no e-Finances', 'Manuais: aqui você lança', linkBtn('Gerenciar', goAttr('companies')))}
                    ${manual.map(({co, list}) => `<div class="grp av-rows">${list.map(a => `<button class="row" data-act="pickWs" data-co="${co.id}" data-ac="${a.id}">${acctAv({...a, co})}<span class="rt"><span class="t">${esc(a.name)}${state.ws.account === a.id ? ' <span class="tag green">Em uso</span>' : ''}</span><span class="s">${esc(co.name)} · ${plural(a.transactions, 'lançamento', 'lançamentos')}</span></span><span class="rv num">${money(acctBalance(a))}</span></button>`).join('')}</div>`).join('')}</section>
                ${frozenL.length ? `<section class="sec">${sh('Congeladas', 'Banco desconectado · só consulta')}<div class="grp av-rows">${frozenL.map(a => `<button class="row" data-act="pickWs" data-co="${a.co.id}" data-ac="${a.id}">${acctAv(a)}<span class="rt"><span class="t">${esc(a.name)}</span><span class="s">Desde ${a.frozenSince} · ${plural(a.transactions, 'lançamento', 'lançamentos')}</span></span><span class="rv num">${money(acctBalance(a))}</span></button>`).join('')}</div></section>` : ''}
                <div class="pad"><button class="row" style="border-radius:22px" data-act="planTab" data-t="subs">${si('repeat', '#C026D3')}<span class="rt"><span class="t">${plural(D.subscriptions.length, 'assinatura', 'assinaturas')}</span><span class="s">${money(subsMonthly())} por mês, nos cartões e nos lançamentos</span></span>${ic('chevron-right', 'chev')}</button></div>
                <p class="foot-note" style="text-align:center">${ic('lock')} Somente leitura, pelo Open Finance. O e-Finances não movimenta seu dinheiro.</p>
            </div>`;
        },
        notes: {d: 'Aba principal das contas: os bancos conectados pelo Open Finance (saldo, faturas, limite, situação de cada conexão) e as contas do e-Finances. Cada conta do banco também é uma conta do e-Finances: aparece no seletor do Início e em Transações, só para organizar.', c: ['Aba própria na TabView', 'List agrupada por banco com Menu de opções', 'ASWebAuthenticationSession para autorizar no banco e voltar ao app', 'BackgroundTasks para atualizar e avisar quando uma conexão expira'], a: ['GET /api/open-finance', 'POST /api/open-finance (conectar, atualizar, reconectar)', 'PUT /api/open-finance/connections/{id}/company', 'DELETE /api/open-finance/connections/{id}?removeAccounts=&accounts='], tip: 'Toque nos “•••” de um banco para mudar a empresa ou desconectar escolhendo as contas.'}
    };
    S.bank_account = {
        title: 'Conta do banco', parent: 'banks',
        render(p) {
            const b = D.banks.find(x => x.id === (p.b || 'nu')), a = b.accounts.find(x => x.id === p.a) || b.accounts[0];
            const credit = a.kind === 'CREDIT', txs = state.tx.filter(t => t.acct === a.id).sort((x, y) => y.date.localeCompare(x.date));
            const f = state.bankFilter / 30, inn = txs.filter(t => t.type === 'R'), out = txs.filter(t => t.type !== 'R');
            const cats = byCategory(out).slice(0, 5);
            return `${navb({title: b.name, sub: a.name, right: gbtn('refresh-cw', `data-act="toastMsg" data-m="Atualizando ${b.name}…" data-i="refresh-cw"`, 'Atualizar')})}
            <div class="scroll">
                <div class="chips">${bankAccounts().map(x => `<button class="chip ${x.id === a.id ? 'on' : ''}" data-act="bankSwitch" data-b="${x.bank.id}" data-a="${x.id}"><span class="av xs solid" style="--c:${x.bank.color}">${x.bank.short}</span>${esc(x.name)}</button>`).join('')}</div>
                <div class="pad"><section class="hero bank" style="--bc:${b.color}">${WM}<span class="lab">${esc(a.name)} · ${credit ? 'fatura atual' : 'saldo'}</span><div class="big num">${bigMoney(credit ? a.invoice : a.balance)}</div>
                    ${credit ? `<p class="fore">Fecha em ${a.due} · disponível <b class="num">${money(a.available)}</b> de ${money(a.limit)}</p><span class="bar ex" style="height:6px;margin-top:10px"><i style="width:${pct(a.limit - a.available, a.limit)}%;background:#FFFFFF"></i></span>` : `<p class="fore">Atualizado ${b.updated} · em ${esc(company(b.company).name)}</p>`}</section></div>
                ${b.status !== 'UPDATED' ? `<div class="pad"><button class="btn block" data-act="reconnect" data-b="${b.id}">${ic('refresh-cw')}Reconectar ${b.name}</button></div>` : ''}
                <div class="pad">${seg([[30, 'Últimos 30 dias'], [90, 'Últimos 90 dias']].map(([k, l]) => [String(k), l]), String(state.bankFilter), 'bankFilter')}
                <div class="kpis">${kpi('Entradas', money(sum(inn) * f), 'in')}${kpi('Saídas', money(sum(out) * f), 'out')}</div></div>
                ${cats.length ? `<section class="sec">${sh('Saídas por categoria')}<div class="card">${cats.map(c => `<div style="display:flex;flex-direction:column;gap:6px"><span style="display:flex;justify-content:space-between;align-items:center;font-size:15px"><span style="display:flex;align-items:center;gap:8px">${catAv(c, 'xs')}${esc(c.name)}</span><b class="num" style="font-weight:600">${money(c.v * f)}</b></span><span class="prog" style="--c:${c.color}"><i style="width:${c.pct}%"></i></span></div>`).join('')}</div></section>` : ''}
                <section class="sec">${sh('Lançamentos recentes', 'Vindos do banco · organize categoria e contato')}<div class="grp av-rows">${txs.length ? txs.map(t => txItem(t)).join('') : '<div class="row"><span class="rt"><span class="s">Nada nos últimos dias.</span></span></div>'}</div></section>
                <div class="pad">
                    <button class="btn block gray" data-act="useBankAcct" data-a="${a.id}" data-co="${b.company}">${ic('receipt-text')}Ver e organizar em Transações</button>
                    <div class="btns"><button class="btn gray" data-act="bankCompany" data-b="${b.id}">${ic('building-2')}Mudar empresa</button><button class="btn red" data-act="bankDisconnect" data-b="${b.id}">${ic('unlink')}Desconectar</button></div>
                </div>
            </div>`;
        },
        mount(el) { const on = $('.chips .chip.on', el); if (on) { const c = on.parentElement; c.scrollLeft = on.offsetLeft - (c.clientWidth - on.offsetWidth) / 2; } },
        notes: {d: 'Detalhe de uma conta ou cartão conectado, com troca rápida entre as contas no topo: saldo ou fatura e limite, entradas e saídas, gastos por categoria e os lançamentos que vieram do banco (dá para organizar).', c: ['Cartão com a cor do banco', 'Barras por categoria (Swift Charts)', 'Lista paginada'], a: ['GET /api/open-finance/account/{id}', 'GET /api/transaction?account={id}']}
    };
    ACT.bankKind = a => { state.bankKind = a.dataset.v; refresh(); };
    ACT.bankSwitch = a => { state.stack[state.stack.length - 1] = {id: 'bank_account', params: {b: a.dataset.b, a: a.dataset.a}}; refresh(); };
    ACT.bankFilter = a => { state.bankFilter = +a.dataset.v; refresh(); };
    ACT.syncAll = () => toast(`Atualizando ${plural(D.banks.length, 'banco', 'bancos')}…`, {icon: 'refresh-cw'});
    ACT.useBankAcct = a => { state.ws = {company: +a.dataset.co, account: a.dataset.a}; state.month = {...BASE}; tab('tx'); toast(`Usando ${esc(account().name)}`, {icon: 'link'}); };
    ACT.connectSheet = () => sheet({title: 'Conectar banco', body: `<div class="dhero" style="padding:4px 0 8px"><span class="av xl" style="--c:#059669">${ic('link')}</span><h2>Traga seus bancos para o e-Finances</h2></div>
        <div class="grp ic-rows">${[['eye', 'Somente leitura', 'O e-Finances vê saldos e lançamentos. Nunca movimenta dinheiro.'], ['shield-check', 'Regulado pelo Banco Central', 'Conexão pelo Open Finance.'], ['scan-face', 'Você autoriza no app do banco', 'Escolha o banco e confirme lá, com o Face ID do banco.'], ['unlink', 'Cancele quando quiser', 'Aqui no app ou no próprio banco.']].map(([i, t, d]) => `<div class="row" style="align-items:flex-start">${si(i, '#059669')}<span class="rt"><span class="t" style="font-weight:600">${t}</span><span class="s wrap">${d}</span></span></div>`).join('')}</div>`,
        foot: '<button class="btn green" data-act="bankPick">Escolher banco</button>'});
    ACT.bankPick = () => sheet({title: 'Escolha o banco', body: `<label class="search in-pad">${ic('search')}<input placeholder="Buscar banco" aria-label="Buscar banco"></label><div class="pick">${[['Nubank', '#820AD1', 'Nu'], ['Itaú', '#EC7000', 'it'], ['Bradesco', '#CC092F', 'B'], ['Banco do Brasil', '#FCD116', 'BB', '#0038A8'], ['Caixa', '#005CA9', 'CX'], ['Santander', '#EC0000', 'S'], ['Inter', '#FF7A00', 'in'], ['C6 Bank', '#242424', 'C6']].map(([n, c, s, fg]) => `<button data-act="bankGo" data-n="${n}"><span class="av solid sq" style="--c:${c};${fg ? '--fg:' + fg : ''}">${s}</span>${n}</button>`).join('')}</div>`});
    ACT.bankGo = a => { closeOv(); toast(`Abrindo o ${a.dataset.n} para você autorizar…`, {icon: 'external-link'}); };
    ACT.reconnect = a => { closeOv(); const b = D.banks.find(x => x.id === a.dataset.b); toast(`Abrindo o ${b.name} para reconectar…`, {icon: 'external-link'}); setTimeout(() => { b.status = 'UPDATED'; b.updated = 'agora'; b.next = 'hoje, 23:00'; refresh(); toast(`${b.name} reconectado`, {icon: 'circle-check'}); }, 1600); };
    ACT.bankMenu = a => { const b = D.banks.find(x => x.id === a.dataset.b); contextMenu(a, [
        {header: b.status === 'UPDATED' ? `Próxima atualização ${b.next}` : 'A autorização expirou'},
        b.status === 'UPDATED' ? {label: 'Atualizar agora', icon: 'refresh-cw', fn: () => toast(`Atualizando ${b.name}…`, {icon: 'refresh-cw'})} : {label: 'Reconectar', icon: 'refresh-cw', fn: () => ACT.reconnect({dataset: {b: b.id}})},
        {label: 'Mudar empresa', icon: 'building-2', fn: () => ACT.bankCompany({dataset: {b: b.id}})}, {},
        {label: 'Desconectar…', icon: 'unlink', red: true, fn: () => ACT.bankDisconnect({dataset: {b: b.id}})}]); };
    ACT.bankCompany = a => { const b = D.banks.find(x => x.id === a.dataset.b); actionSheet({title: `Levar o ${b.name} para qual empresa?`, text: 'As contas do banco e os lançamentos vão junto.', items: D.companies.map(co => ({label: `${co.name}${co.id === b.company ? ' ✓' : ''}`, fn: () => { b.company = co.id; refresh(); toast(`${b.name} agora em ${co.name}`, {icon: 'building-2'}); }}))}); };
    ACT.bankDisconnect = a => {
        const b = D.banks.find(x => x.id === a.dataset.b);
        state.disc = {b: b.id, pick: new Set(b.accounts.map(x => x.id)), keep: 'freeze'};
        discSheet();
    };
    function discSheet() {
        const d = state.disc, b = D.banks.find(x => x.id === d.b), all = d.pick.size === b.accounts.length;
        sheet({title: `Desconectar ${b.name}`, body: `<p style="font-size:15px;color:var(--text);padding:0 4px">Escolha as contas que saem do e-Finances.</p>
            <div class="grp av-rows">${b.accounts.map(x => `<button class="row" data-act="discPick" data-a="${x.id}"><span class="radio ${d.pick.has(x.id) ? 'on' : ''}">${d.pick.has(x.id) ? ic('check') : ''}</span><span class="rt"><span class="t">${x.name}</span><span class="s">${x.kind === 'CREDIT' ? 'Cartão' : 'Conta'} · ${money(x.kind === 'CREDIT' ? x.invoice : x.balance)}</span></span></button>`).join('')}</div>
            ${E.shSmall('O que fazer com os lançamentos')}
            <div class="grp" style="margin-top:-6px">${[['freeze', 'Manter como conta congelada', 'Fica só para consulta, com tudo o que já veio.'], ['delete', 'Apagar as contas e os lançamentos', 'Some do e-Finances. Não dá para desfazer.']].map(([k, t, s]) => `<button class="row" data-act="discKeep" data-v="${k}"><span class="rt"><span class="t ${k === 'delete' ? 'red' : ''}">${t}</span><span class="s wrap">${s}</span></span>${d.keep === k ? ic('check', 'ck') : ''}</button>`).join('')}</div>
            <p class="foot-note">${all ? `Saindo todas as contas, o acesso ao ${b.name} é revogado.` : 'As contas que ficarem continuam sincronizando.'}</p>`,
            foot: `<button class="btn red-fill" data-act="discGo" ${d.pick.size ? '' : 'disabled'}>Desconectar ${plural(d.pick.size, 'conta', 'contas')}</button>`});
    }
    ACT.discPick = a => { const s = state.disc.pick; s.has(a.dataset.a) ? s.delete(a.dataset.a) : s.add(a.dataset.a); discSheet(); };
    ACT.discKeep = a => { state.disc.keep = a.dataset.v; discSheet(); };
    ACT.discGo = () => { const d = state.disc, b = D.banks.find(x => x.id === d.b); closeOv(); toast(`${b.name}: ${plural(d.pick.size, 'conta', 'contas')} ${d.keep === 'freeze' ? 'congeladas' : 'apagadas'} (exemplo)`, {icon: d.keep === 'freeze' ? 'snowflake' : 'trash-2'}); };

    /* ---------- planejar ---------- */
    S.plan = {
        title: 'Planejar', tab: 'plan', root: true,
        render() {
            const t = state.planTab;
            let body;
            if (t === 'limits') {
                const rows = limitRows().sort((a, b) => b.p - a.p), tot = sum(rows, r => r.limit), spent = sum(rows, r => r.spent), att = rows.filter(r => r.status !== 'ok').length;
                const has = new Set(state.limits.map(l => l.cat));
                const sugg = ['educacao', 'moradia', 'impostos', 'pets'].filter(k => !has.has(k)).map(k => ({k, avg: avg3(k)})).filter(s => s.avg > 0).slice(0, 3);
                body = `<div class="pad"><div class="kpis">${kpi('Limites somados', money(tot))}${kpi(`Gasto em ${MONTHS[BASE.m]}`, money(spent))}${kpi('Ainda dá para gastar', money(Math.max(tot - spent, 0)), 'in')}${kpi('Pedem atenção', att, att ? 'out' : '')}</div></div>
                    <div class="sec"><div class="grp">${rows.map(r => limRow(r, true)).join('')}</div></div>
                    ${sugg.length ? `<section class="sec">${sh('Sugestões', 'Pela média dos últimos 3 meses')}<div class="grp av-rows">${sugg.map(s => { const c = D.categories[s.k]; return `<div class="row">${catAv(c)}<span class="rt"><span class="t">${c.name}</span><span class="s">Média de ${money(s.avg)} por mês</span></span><button class="btn sm tinted" data-act="limitSheet" data-cat="${s.k}" data-sug="${Math.ceil(s.avg / 50) * 50}">Criar</button></div>`; }).join('')}</div></section>` : ''}
                    <p class="foot-note">${ic('bell-ring')} Avisamos no iPhone e por e-mail quando uma categoria chega no % de alerta e quando passa do limite.</p>`;
            } else if (t === 'inst') {
                const I = D.installments, rem = sum(I, i => (i.total - i.paid) * i.value), mo = sum(I, i => i.value);
                body = `<div class="pad"><section class="hero sm">${WM}<span class="lab">Falta pagar</span><div class="big num">${bigMoney(rem)}</div><p class="fore">${plural(I.length, 'parcelamento', 'parcelamentos')} · <b class="num">${money(mo)}</b> por mês</p></section></div>
                    <div class="sec"><div class="grp" style="--sl:74px">${I.map(i => `<${i.txId ? `button data-tx="${i.txId}"` : 'div'} class="row">${pring(i.paid, i.total)}<span class="rt"><span class="t">${esc(i.name)}</span><span class="s">${money(i.value)}/mês · termina em ${i.ends}</span><span class="s" style="margin-top:3px"><span class="tag ${i.source === 'LEDGER' ? 'info' : 'navy'}">${ic(i.source === 'LEDGER' ? 'receipt-text' : 'link')}${i.source === 'LEDGER' ? 'Lançamentos' : esc(i.origin)}</span></span></span><span class="rv num"><small>Falta</small>${money((i.total - i.paid) * i.value)}</span></${i.txId ? 'button' : 'div'}>`).join('')}</div></div>
                    <p class="foot-note">${ic('info')} Parcelas dos seus lançamentos e as que vêm dos cartões conectados.</p>`;
            } else {
                const mo = subsMonthly(), up = D.subscriptions.filter(s => s.oldValue);
                body = `<div class="pad"><section class="hero sm">${WM}<span class="lab">Assinaturas</span><div class="big num">${bigMoney(mo)}<small> /mês</small></div><p class="fore">${plural(D.subscriptions.length, 'assinatura', 'assinaturas')} · <b class="num">${money(mo * 12)}</b> por ano</p></section>
                    ${up.map(s => { const c = D.categories[s.cat]; return `<div class="alert">${ic('trending-up')}<div class="grow"><b>${c.name} ficou ${Math.round((s.value / s.oldValue - 1) * 100)}% mais cara</b><p>Passou de ${money(s.oldValue)} para ${money(s.value)} por mês.</p></div></div>`; }).join('')}</div>
                    <div class="sec"><div class="grp av-rows">${D.subscriptions.map(s => { const c = D.categories[s.cat]; return `<button class="row" data-act="subFilter" data-cat="${s.cat}">${catAv(c)}<span class="rt"><span class="t">${c.name}</span><span class="s">${s.freq === 'YEARLY' ? 'Anual' : 'Mensal'} · próxima em ${s.next} · ${esc(s.origin)}</span></span><span class="rv num">${money(s.value)}</span>${ic('chevron-right', 'chev')}</button>`; }).join('')}</div></div>
                    <section class="sec">${sh('Outras cobranças recorrentes', 'Contas fixas encontradas no banco')}<div class="grp av-rows">${D.otherRecurring.map(o => `<div class="row"><span class="av" style="--c:#64748B">${ic('repeat')}</span><span class="rt"><span class="t">${o.name}</span><span class="s">${o.detail}</span></span><span class="rv num">${money(o.value)}</span></div>`).join('')}</div></section>
                    <p class="foot-note">${ic('info')} Assinatura é todo lançamento, manual ou do banco, numa categoria marcada como assinatura. Marque em Mais › Categorias.</p>`;
            }
            return `${navb({back: false, large: true, title: 'Planejar', right: `${gbtn('chart-column', goAttr('reports'), 'Relatórios')}${t === 'limits' ? `<button class="gb tint" data-act="limitSheet" aria-label="Novo limite">${ic('plus')}</button>` : ''}`})}
                <div class="scroll">${largeTitle('Planejar')}<div class="pad">${seg([['limits', 'Limites'], ['inst', 'Parcelas'], ['subs', 'Assinaturas']], t, 'planTab2', 'big')}</div>${body}</div>`;
        },
        notes: {d: 'Planejamento em três partes: limites por categoria (com sugestões pela média), parcelamentos em andamento e assinaturas (pelas categorias de assinatura, com a marca).', c: ['Picker segmentado', 'ProgressView com cor por situação (ok, alerta, passou)', 'Anel de progresso das parcelas', 'Folha (.medium) para criar e editar limite, com Slider do % de alerta'], a: ['GET/POST/DELETE /api/limits', 'GET /api/transaction/installments', 'GET /api/transaction/subscriptions'], tip: 'Toque num limite para mudar o valor e o % de alerta. Excluir o limite também tem “Desfazer”.'}
    };
    ACT.planTab2 = a => { state.planTab = a.dataset.v; refresh(); };
    ACT.subFilter = a => { state.f = {kind: 'all', status: null, q: '', cat: a.dataset.cat}; state.ws = {company: 1, account: 'cc'}; state.month = {...BASE}; tab('tx'); };
    ACT.limitSheet = a => {
        const cat = a.dataset.cat;
        if (!cat) { state.pickFor = 'limit'; E.catSheet('Limite para qual categoria?', null); return; }
        const l = state.limits.find(x => x.cat === cat), c = D.categories[cat], avg = avg3(cat);
        const val = l ? l.limit : +(a.dataset.sug || Math.ceil(avg / 50) * 50 || 300), al = l ? l.alertPct : 80;
        sheet({title: l ? 'Editar limite' : 'Novo limite', right: `<button class="gb tint" data-act="limitSave" data-cat="${cat}" aria-label="Salvar">${ic('check')}</button>`,
            body: `<div class="dhero" style="padding:0">${catAv(c, 'lg')}<h2>${c.name}</h2><p>Média dos últimos 3 meses: ${money(avg)}</p></div>
                <div class="grp"><label class="frow"><span class="k">Limite por mês</span><span style="margin-left:auto;display:flex;align-items:center;gap:6px;color:var(--muted)">R$<input id="lv" type="number" inputmode="decimal" value="${val}" min="1" style="width:110px"></span></label>
                <div class="frow stack"><span style="display:flex;justify-content:space-between"><span class="k">Avisar quando chegar em</span><b id="lav" style="color:var(--tint)">${al}%</b></span><input id="la" type="range" min="50" max="100" step="5" value="${al}" style="accent-color:#10B981;width:100%" oninput="document.getElementById('lav').textContent=this.value+'%'"></div></div>
                <p class="foot-note">${ic('bell-ring')} Aviso no iPhone e por e-mail, uma vez por nível em cada mês.</p>`,
            foot: l ? `<button class="btn red" data-act="limitDel" data-cat="${cat}">${ic('trash-2')}Excluir limite</button>` : ''});
    };
    ACT.limitSave = a => {
        const cat = a.dataset.cat, v = Math.max(1, +$('#lv').value || 0), al = +$('#la').value;
        const l = state.limits.find(x => x.cat === cat);
        if (l) Object.assign(l, {limit: v, alertPct: al}); else state.limits.push({cat, limit: v, alertPct: al});
        closeOv(); refresh(); toast(l ? 'Limite atualizado' : 'Limite criado', {icon: 'flag'});
    };
    ACT.limitDel = a => { const old = state.limits.find(x => x.cat === a.dataset.cat); state.limits = state.limits.filter(x => x !== old); closeOv(); refresh(); toast('Limite excluído', {action: 'Desfazer', fn: () => { state.limits.push(old); refresh(); }}); };

    /* ---------- fechamento do mês (story) ---------- */
    function storySlides() {
        const y = 2026, m = 8, list = monthTx(y, m, 'cc'), prev = monthTx(y, m - 1, 'cc'), T = totals(list), P = totals(prev);
        const bal = T.inc - T.exp, rate = T.inc ? Math.round(bal / T.inc * 100) : 0, dExp = Math.round((T.exp - P.exp) / P.exp * 100);
        const exp = list.filter(t => t.type !== 'R'), cats = byCategory(exp).slice(0, 3), big = exp.slice().sort((a, b) => b.value - a.value)[0];
        const lims = limitRows(y, m), within = lims.filter(l => l.status !== 'over').length, over = lims.length - within;
        const parts = v => { const s = fmt(v); const i = s.lastIndexOf(','); return `<span>${s.slice(0, i)}</span><small>${s.slice(i)}</small>`; };
        const tag = '<span class="st-tag">Setembro de 2026</span>';
        const conf = Array.from({length: 26}, (_, i) => `<i class="${i % 3 ? '' : 'r'}" style="left:${(i * 37) % 100}%;background:${['#34D399', '#FBBF24', '#F472B6', '#60A5FA', '#fff'][i % 5]};animation-duration:${2.6 + (i % 5) * .5}s;animation-delay:${(i % 7) * .25}s"></i>`).join('');
        return [
            {theme: 'cover', html: `${tag}<h2 class="st-hero">Seu fechamento do mês</h2><p class="st-sub">Casa · Conta corrente</p><p class="st-note">${ic('receipt-text')}${list.length} lançamentos em setembro</p><span class="st-hint">Toque para avançar · segure para pausar</span>`},
            {theme: 'income', html: `${tag}<p class="st-kick">Entrou</p><p class="st-money">${parts(T.inc)}</p><p class="st-sub">em recebimentos no mês</p>`},
            {theme: 'expenses', html: `${tag}<p class="st-kick">Saiu</p><p class="st-money">${parts(T.exp)}</p><p class="st-sub">em despesas no mês</p><p class="st-chip">${ic(dExp <= 0 ? 'arrow-down' : 'arrow-up')}${Math.abs(dExp)}% ${dExp <= 0 ? 'a menos' : 'a mais'} que agosto</p>`},
            {theme: 'balance', html: `${bal > 0 ? `<div class="confetti" aria-hidden="true">${conf}</div>` : ''}${tag}<p class="st-money" style="font-size:56px">${parts(Math.abs(bal))}</p><p class="st-kick" style="font-weight:600;opacity:1">${bal >= 0 ? 'guardados' : 'no vermelho'}</p><p class="st-sub">${bal >= 0 ? `Você guardou ${rate}% do que entrou.` : 'As despesas passaram dos recebimentos. Que tal definir limites?'}</p>`},
            {theme: 'categories', html: `${tag}<p class="st-kick">Onde mais foi o dinheiro</p><div class="st-cats">${cats.map((c, i) => `<div class="st-cat"><span class="row2"><b>${i + 1}. ${c.name}</b><span>${fmt(c.v)}</span></span><span class="bar2"><i style="width:${c.pct}%;animation-delay:${.3 + i * .15}s"></i></span><small>${c.pct}% das despesas</small></div>`).join('')}</div>`},
            {theme: 'biggest', html: `${tag}<p class="st-kick">Maior gasto</p><p class="st-money">${parts(big.value)}</p><p class="st-sub">${esc(big.desc)}</p><p class="st-note">${ic('calendar')}${dmy(big.date)}</p>`},
            {theme: 'limits', html: `${tag}<p class="st-money"><span>${within}</span><small> de ${lims.length}</small></p><p class="st-kick" style="font-weight:600;opacity:1">categorias dentro do limite</p><p class="st-sub">${over ? `${over} ${over === 1 ? 'passou' : 'passaram'} do limite. Vale ajustar em outubro.` : 'Nenhuma estourou. Mandou bem!'}</p>`},
            {theme: 'subs', html: `${tag}<p class="st-kick">Suas assinaturas</p><p class="st-money">${parts(subsMonthly())}</p><p class="st-sub">por mês em ${plural(D.subscriptions.length, 'assinatura', 'assinaturas')}</p>`},
            {theme: 'end', html: `${tag}<h2 class="st-hero">${bal >= 0 ? 'Bom trabalho!' : 'Novo mês, nova chance'}</h2><p class="st-sub">Veja tudo em detalhe ou siga em frente.</p><div class="st-acts"><button class="btn white block" data-act="storyGo" data-to="reports">${ic('chart-column')}Ver relatórios</button><button class="btn ghost-white block" data-act="storyGo" data-to="limits">${ic('flag')}Limites por categoria</button><button class="btn ghost-white block" data-act="storyShare">${ic('share')}Compartilhar este resumo</button></div>`}
        ];
    }
    S.story = {
        title: 'Fechamento do mês', light: true, parent: 'home', modal: true, cover: true, bare: true,
        render: () => `<div class="story t-cover"><div class="st-bars">${storySlides().map(() => '<span><i></i></span>').join('')}</div>
            <div class="st-top"><span class="br">${markSvg(true)}<span>Fechamento do mês<br><small>Casa · setembro de 2026</small></span></span><button class="gb" data-act="stPause" aria-label="Pausar">${ic('pause')}</button><button class="gb" data-back aria-label="Fechar">${ic('x')}</button></div>
            <div class="st-body" aria-live="polite"></div></div>`,
        mount(el) {
            const slides = storySlides(), root = $('.story', el), body = $('.st-body', el), bars = $$('.st-bars i', el);
            let i = 0, prog = 0, paused = false, held = false, last = performance.now(), raf, holdT;
            const show = () => { root.className = 'story t-' + slides[i].theme; body.innerHTML = slides[i].html; bars.forEach((b, k) => { b.style.width = (k < i ? 100 : 0) + '%'; }); prog = 0; };
            const next = () => { if (i < slides.length - 1) { i++; show(); } else prog = 1; };
            const prev = () => { if (i > 0) { i--; show(); } else prog = 0; };
            const loop = now => {
                const dt = now - last; last = now;
                if (!paused && prog < 1) { prog += dt / 5200; if (prog >= 1 && i < slides.length - 1) next(); }
                if (bars[i]) bars[i].style.width = Math.min(prog, 1) * 100 + '%';
                raf = requestAnimationFrame(loop);
            };
            body.addEventListener('pointerdown', e => { if (e.target.closest('button')) return; held = false; holdT = setTimeout(() => { held = true; paused = true; }, 240); });
            body.addEventListener('pointerup', e => {
                if (e.target.closest('button')) return;
                clearTimeout(holdT);
                if (held) { held = false; paused = false; return; }
                const r = body.getBoundingClientRect();
                (e.clientX - r.left < r.width / 3) ? prev() : next();
            });
            show(); raf = requestAnimationFrame(loop);
            el._story = {toggle: () => (paused = !paused)};
            el._cleanup = () => cancelAnimationFrame(raf);
        },
        notes: {d: 'Fechamento do mês no estilo stories: entrou, saiu, guardou, onde mais gastou, maior gasto, limites e assinaturas. Aparece depois do login, na frequência escolhida.', c: ['.fullScreenCover com barras de progresso', 'Toque à direita avança, à esquerda volta, segurar pausa', 'Compartilhar o resumo como imagem (ImageRenderer + ShareLink)'], a: ['GET /api/story', 'GET /api/story/pending', 'POST /api/story/seen']}
    };
    ACT.stPause = a => { const p = state.curEl._story.toggle(); a.innerHTML = ic(p ? 'play' : 'pause'); a.setAttribute('aria-label', p ? 'Continuar' : 'Pausar'); };
    ACT.storyGo = a => { const to = a.dataset.to; if (to === 'limits') { state.planTab = 'limits'; resetTo('plan'); } else resetTo(to); };
    ACT.storyShare = () => ACT.shareSheet({dataset: {what: 'fechamento-setembro.png'}});

    /* ---------- notificações ---------- */
    S.notifications = {
        title: 'Notificações', parent: 'home',
        render() {
            const unread = state.notifs.filter(n => n.unread).length;
            const list = state.notifs.filter(n => state.notifTab === 'all' || n.unread).filter(n => !state.notifCat || n.category === state.notifCat);
            let body = ['Hoje', 'Ontem', 'Esta semana', 'Anteriores'].map(g => { const it = list.filter(n => n.when === g); return it.length ? `<section class="sec"><div class="glab">${g}</div><div class="grp ic-rows">${it.map(n => `<button class="row" style="align-items:flex-start" data-act="openNotif" data-id="${n.id}">${si(NCAT[n.category][1], NSEV[n.severity])}<span class="rt"><span class="t" style="font-weight:${n.unread ? 600 : 400}">${esc(n.title)}</span><span class="s wrap">${esc(n.body)}</span></span><span class="rv"><small>${n.time}</small>${n.unread ? '<i style="width:9px;height:9px;border-radius:50%;background:var(--info);display:block;margin-top:4px" aria-label="Não lida"></i>' : ''}</span></button>`).join('')}</div></section>` : ''; }).join('');
            if (!list.length) body = `<div class="empty">${ic('bell-off')}<b>Nenhuma notificação</b><span>${state.notifTab === 'unread' ? 'Você leu tudo.' : 'Quando algo acontecer, avisamos aqui.'}</span></div>`;
            return `${navb({title: 'Notificações', large: true, right: gbs(['check-check', 'data-act="readAll"', 'Marcar todas como lidas'], ['settings', goAttr('notif_prefs'), 'Preferências'])})}
                <div class="scroll">${largeTitle('Notificações')}
                <div class="pad">${seg([['all', 'Todas'], ['unread', `Não lidas${unread ? ` (${unread})` : ''}`]], state.notifTab, 'nTab')}</div>
                <div class="chips">${Object.entries(NCAT).map(([k, [l, i]]) => `<button class="chip ${state.notifCat === k ? 'on' : ''}" data-act="nCat" data-v="${k}">${ic(i)}${l}</button>`).join('')}</div>${body}
                ${list.some(n => !n.unread) ? '<div class="pad"><button class="btn plain" data-act="clearRead">Limpar as lidas</button></div>' : ''}</div>`;
        },
        notes: {d: 'Central de avisos: limites, vencimentos, pagamentos, suporte e segurança. Os mesmos avisos chegam como notificação no iPhone, com ações rápidas (ex.: “Marcar como pago” direto da tela bloqueada).', c: ['List com seções por dia', 'Apple Push Notification service (APNs) com categorias e ações', 'Selo no ícone do app com as não lidas'], a: ['GET /api/notifications', 'PUT /api/notifications (marcar como lidas, limpar)', 'Novo no backend: registrar o token do iPhone (APNs) para push'], tip: 'Toque num aviso para ir direto à tela dele.'}
    };
    ACT.openNotif = a => { const n = state.notifs.find(x => x.id === +a.dataset.id); n.unread = false; if (n.go[0] === 'plan') { state.planTab = n.go[1].tab; tab('plan'); } else if (n.go[0] === 'story') go('story', {}, 'up'); else go(n.go[0], n.go[1]); };
    ACT.readAll = () => { state.notifs.forEach(n => { n.unread = false; }); refresh(); toast('Todas marcadas como lidas', {icon: 'check-check'}); };
    ACT.clearRead = () => { const before = state.notifs; state.notifs = state.notifs.filter(n => n.unread); refresh(); toast('Lidas removidas', {action: 'Desfazer', fn: () => { state.notifs = before; refresh(); }}); };
    ACT.nTab = a => { state.notifTab = a.dataset.v; refresh(); };
    ACT.nCat = a => { state.notifCat = state.notifCat === a.dataset.v ? null : a.dataset.v; refresh(); };

    /* ---------- relatórios ---------- */
    S.reports = {
        title: 'Relatórios', parent: 'more',
        render() {
            const P = state.rep.period, months = [];
            const n = P === 'year' ? BASE.m + 1 : P;
            for (let i = n - 1; i >= 0; i--) { const d = new Date(BASE.y, BASE.m - i, 1); months.push({y: d.getFullYear(), m: d.getMonth()}); }
            const prevMonths = months.map(({y, m}) => { const d = new Date(y, m - n, 1); return {y: d.getFullYear(), m: d.getMonth()}; });
            const tx = months.flatMap(({y, m}) => monthTx(y, m)), ptx = prevMonths.flatMap(({y, m}) => monthTx(y, m));
            const T = totals(tx), PT = totals(ptx), res = T.inc - T.exp, pres = PT.inc - PT.exp;
            const ctOf = name => (D.contacts.find(c => c.name === name) || {}).category;
            let exp = tx.filter(t => t.type !== 'R');
            const by = state.rep.by, ct = state.rep.ctype;
            if ((by === 'contact') && ct !== 'all') exp = exp.filter(t => ctOf(t.contact) === ct);
            const open = sum(tx.filter(t => !t.paid && t.type !== 'R'));
            const rows = months.map(({y, m}) => { const t = totals(monthTx(y, m)); return {label: n > 8 ? MON[m][0].toUpperCase() : MON[m], name: MONTHS[m], inc: t.inc, exp: t.exp}; });
            const palette = ['#4338CA', '#0EA5E9', '#F97316', '#DB2777', '#10B981', '#CA8A04', '#7C3AED', '#64748B'];
            const comp = by === 'cat' ? byCategory(exp)
                : by === 'contact' ? groupBy(exp, t => t.contact, k => k, (k, i) => palette[i % 8])
                : by === 'ctype' ? groupBy(exp, t => ctOf(t.contact) || 'NONE', k => CONTACT_CAT[k] || 'Sem contato cadastrado', k => CONTACT_COLOR[k] || '#94A3B8')
                : by === 'cc' ? groupBy(exp, t => t.cc, k => D.costCenters[k]?.name || 'Sem centro de custo', k => D.costCenters[k]?.color || '#94A3B8')
                : groupBy(exp, t => t.pay, k => PAY[k] || k, (k, i) => palette[i % 8]);
            const top5 = comp.slice(0, 5), restC = comp.slice(5);
            if (restC.length) top5.push({name: 'Outros', color: '#94A3B8', v: sum(restC, c => c.v), pct: sum(restC, c => c.pct)});
            const biggest = exp.slice().sort((a, b) => b.value - a.value).slice(0, 5);
            const cur = monthTx(BASE.y, BASE.m).filter(t => t.type !== 'R'), perDay = {};
            cur.forEach(t => { const d = parse(t.date).getDate(); perDay[d] = (perDay[d] || 0) + t.value; });
            const maxDay = Math.max(...Object.values(perDay), 1);
            const periods = [[1, 'Este mês'], [3, '3 meses'], [6, '6 meses'], [12, '12 meses'], ['year', 'Este ano']];
            return `${navb({title: 'Relatórios', large: true, right: gbtn('share', 'data-act="shareSheet" data-what="relatorio-outubro.pdf"', 'Compartilhar relatório')})}
            <div class="scroll">${largeTitle('Relatórios', `${esc(company().name)} · ${esc(account().name)}`)}
                <div class="chips">${periods.map(([k, l]) => `<button class="chip ${P === k ? 'on' : ''}" data-act="repPeriod" data-v="${k}">${l}</button>`).join('')}</div>
                <div class="pad"><div class="kpis">
                    ${kpi('Receitas', money(T.inc), 'in', delta(T.inc, PT.inc))}${kpi('Despesas', money(T.exp), 'out', delta(T.exp, PT.exp, false))}
                    ${kpi('Resultado', money(res), res >= 0 ? 'in' : 'out', delta(res, pres))}${kpi('Margem', `${pct(res, T.inc)}%`, '', '<span class="d">do que entrou</span>')}
                    ${kpi('Despesa média', money(T.exp / n), '', '<span class="d">por mês</span>')}${kpi('Em aberto', money(open), open ? 'out' : '', '<span class="d">despesas a pagar</span>')}
                </div></div>
                <section class="sec">${sh('Evolução mensal', `${MONTHS[months[0].m]} a ${MONTHS[BASE.m]}`)}<div class="card">${barChart(rows)}<div class="legend"><span style="--c:var(--accent)"><i></i>Receitas</span><span style="--c:var(--expense)"><i></i>Despesas</span></div></div></section>
                <section class="sec">${sh('Gastos por dia', `${cap(MONTHS[BASE.m])} · toque num dia`)}<div class="card">${calendar(BASE.y, BASE.m, {act: 'repDay', heat: true, dayFn: d => ({h: perDay[d] ? 12 + perDay[d] / maxDay * 70 : 0})})}
                    <div class="legend"><span style="--c:color-mix(in srgb, var(--expense) 18%, transparent)"><i></i>Pouco</span><span style="--c:color-mix(in srgb, var(--expense) 80%, transparent)"><i></i>Muito</span></div></div></section>
                <section class="sec">${sh('Composição das despesas')}
                    <div class="chips" style="margin:0 -16px">${[['cat', 'Categoria'], ['contact', 'Contato'], ['ctype', 'Tipo de contato'], ['cc', 'Centro de custo'], ['pay', 'Pagamento']].map(([k, l]) => `<button class="chip ${by === k ? 'on' : ''}" data-act="repBy" data-v="${k}">${l}</button>`).join('')}</div>
                    ${by === 'contact' ? seg([['all', 'Todos'], ['CLIENT', 'Clientes'], ['SUPPLIER', 'Fornecedores'], ['WORKER', 'Funcionários']], ct, 'repCtype') : ''}
                    <div class="card"><div class="donut-wrap">${donut(top5.map(c => ({v: c.v, c: c.color})), 'Despesas', compactMoney(sum(exp)))}<div class="lg">${top5.map(c => `<div class="dl" style="--c:${c.color}"><i></i><span>${esc(c.name)}</span><b>${c.pct}%</b></div>`).join('')}</div></div></div>
                    <div class="grp">${comp.slice(0, 6).map((c, i) => `<div class="row"><b style="width:22px;color:var(--muted);font-weight:600">${i + 1}</b><span class="rt"><span class="t">${esc(c.name)}</span><span class="prog" style="--c:${c.color};height:6px;margin-top:6px"><i style="width:${c.pct}%"></i></span></span><span class="rv num">${money(c.v)}<small>${c.pct}%</small></span></div>`).join('') || '<div class="row"><span class="rt"><span class="s">Nada no período.</span></span></div>'}</div></section>
                <section class="sec">${sh('Maiores despesas')}<div class="grp av-rows">${biggest.map(t => `<button class="row" data-tx="${t.id}">${catAv(catOf(t))}<span class="rt"><span class="t">${esc(t.desc)}</span><span class="s">${dmy(t.date)} · ${esc(catOf(t).name)}</span></span><span class="rv num">${money(t.value)}</span></button>`).join('')}</div></section>
            </div>`;
        },
        notes: {d: 'Relatórios do período: receitas, despesas, resultado e margem com variação, evolução mensal, gastos por dia (toque num dia para ver as despesas), composição por categoria, contato, tipo de contato, centro de custo ou pagamento, e as maiores despesas.', c: ['Swift Charts (barras e setores)', 'Calendário de calor com popover do dia', 'Compartilhar o relatório em PDF (ShareLink)'], a: ['GET /api/reports/overview', 'GET /api/reports/day (despesas do dia)'], tip: 'Troque o período e a composição: os números são recalculados. Toque num dia do calendário.'}
    };
    ACT.repPeriod = a => { state.rep.period = a.dataset.v === 'year' ? 'year' : +a.dataset.v; refresh(); };
    ACT.repBy = a => { state.rep.by = a.dataset.v; refresh(); };
    ACT.repCtype = a => { state.rep.ctype = a.dataset.v; refresh(); };
    ACT.repDay = a => {
        const d = +a.dataset.d, list = monthTx(BASE.y, BASE.m).filter(t => t.type !== 'R' && parse(t.date).getDate() === d);
        const open = list.filter(t => !t.paid);
        sheet({title: `${d} de ${MONTHS[BASE.m]}`, sub: list.length ? `${plural(list.length, 'despesa', 'despesas')} · ${money(sum(list))}` : 'Sem despesas',
            body: list.length ? `<div class="grp av-rows">${list.map(t => `<button class="row" data-tx="${t.id}">${catAv(catOf(t))}<span class="rt"><span class="t">${esc(t.desc)}</span><span class="s">${esc(t.contact || catOf(t).name)}${t.paid ? '' : ' · em aberto'}</span></span><span class="rv num">${money(t.value)}</span></button>`).join('')}</div>${open.length ? `<p class="foot-note">${money(sum(open))} ainda em aberto.</p>` : ''}` : '<div class="empty" style="padding:20px">Nenhuma despesa neste dia.</div>',
            foot: '<button class="btn gray" data-act="repToTx">Abrir em Transações</button>'});
    };
    ACT.repToTx = () => { closeOv(); state.month = {...BASE}; tab('tx'); };
})();
