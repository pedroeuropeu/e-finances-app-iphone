/* e-Finances iPhone · protótipo: acesso, Início, Transações, detalhe e formulário do lançamento. */
'use strict';
(() => {
    const E = window.EF, D = E.D, S = E.S, ACT = E.ACT, state = E.state;
    const {$, esc, ic, fmt, sum, pct, pad, norm, initials, goAttr, plural, cap, TODAY, BASE, MONTHS, MON, parse, iso, dm, dmy, days, addMonths, monthLabel, longDate, greeting,
        TYPES, PAY, PAY_ICON, MODE, REC, REC_STEP, CONTACT_CAT, CONTACT_COLOR, markSvg, WM, FACEID,
        company, account, acctBalance, balance, bankOf, catOf, isBase, locked, frozen, monthTx, findTx, removeTx, restoreTx, totals, status, byCategory, limitRows, yearFlow, subsMonthly, setPaid,
        money, signed, bigMoney, compactMoney, navb, largeTitle, gbtn, gtxt, gbs, sh, linkBtn, tg, seg, catAv, acctAv, si, modeTag, txItem, pring, donut, barChart, limRow, calendar,
        sheet, alertBox, actionSheet, contextMenu, toast, closeOv, cur, refresh, go, replace, back, tab, resetTo, isDark} = E;

    /* ---------- acesso ---------- */
    S.splash = {
        title: 'Abertura', light: true, bare: true,
        render: () => `<div class="splash" data-act="skipSplash" role="button" aria-label="Abrir">${markSvg(true)}<div class="wm2">e<i>·</i>finances</div></div>`,
        mount(el) { el._t = setTimeout(() => { if (E.cur().id === 'splash') replace('onboarding'); }, 2000); el._cleanup = () => clearTimeout(el._t); },
        notes: {d: 'Tela de abertura com a marca enquanto o app confere a sessão guardada no Keychain e renova o token em segundo plano.', c: ['Launch Screen do iOS (cor da marca e símbolo)', 'Transição para o Início ou para o login'], a: ['Renova o token no Keycloak com o refresh token guardado no Keychain do iPhone']}
    };

    const OB = [
        {h: 'Seu dinheiro <em>num lugar só</em>', p: 'Contas manuais e bancos conectados na mesma tela. Saiba quanto tem hoje e quanto vai sobrar no fim do mês.'},
        {h: 'Parcelas e assinaturas <em>sob controle</em>', p: 'Veja quanto falta de cada parcelamento e quanto as assinaturas custam por mês e por ano.'},
        {h: 'Limites que <em>avisam antes</em>', p: 'Defina quanto quer gastar por categoria e receba um aviso no iPhone quando chegar perto. Todo mês, um resumo do que aconteceu.'}
    ];
    const obArt = i => [
        `<div class="mock hero" style="width:262px;left:50%;top:52%;transform:translate(-50%,-62%) rotate(-4deg);border-radius:26px">${WM}<span class="lab">Saldo da conta</span><div class="big" style="font-size:30px">R$ 8.432<small>,17</small></div><p class="fore">Previsão de fechamento <b>R$ 7.314,90</b></p></div>
         <div class="mock" style="left:30px;top:62%;display:flex;gap:10px;align-items:center;transform:rotate(3deg)"><span class="av solid sq" style="--c:#820AD1">Nu</span><span><b style="font-size:14px">Nubank</b><br><small style="color:var(--muted);font-size:13px">R$ 3.214,55</small></span></div>
         <div class="mock" style="right:26px;top:72%;display:flex;gap:10px;align-items:center;transform:rotate(-2deg)"><span class="av solid sq" style="--c:#FF7A00">in</span><span><b style="font-size:14px">Inter</b><br><small style="color:var(--muted);font-size:13px">R$ 1.045,00</small></span></div>`,
        `<div class="mock" style="width:262px;left:50%;top:44%;transform:translate(-50%,-70%) rotate(-3deg);display:flex;gap:12px;align-items:center">${pring(3, 10, 52)}<span><b style="font-size:15px">Notebook Dell</b><br><small style="color:var(--muted);font-size:13px">R$ 412,90/mês · até jul/2027</small></span></div>
         <div class="mock" style="width:250px;left:50%;top:56%;transform:translate(-44%,-14%) rotate(2deg);display:flex;flex-direction:column;gap:10px">
            ${[['N', '#E50914', 'Netflix', 'R$ 55,90'], ['S', '#1DB954', 'Spotify', 'R$ 34,90'], ['SF', '#F5B800', 'Smart Fit', '+8%']].map(([s, c, n, v], k) => `<span style="display:flex;align-items:center;gap:10px"><span class="av solid sm" style="--c:${c}${k === 2 ? ';--fg:#1A1A1A' : ''}">${s}</span><span style="flex:1;font-size:14px">${n}</span>${k === 2 ? `<span class="tag amber">${v}</span>` : `<b style="font-size:14px">${v}</b>`}</span>`).join('')}</div>`,
        `<div class="mock" style="width:270px;left:50%;top:52%;transform:translate(-50%,-56%) rotate(-2deg);display:flex;flex-direction:column;gap:10px">
            ${[['Alimentação', 85, 'warn'], ['Transporte', 57, 'ok'], ['Lazer', 117, 'over']].map(([n, p, s]) => `<span style="display:flex;font-size:14px"><b style="flex:1;font-weight:600">${n}</b><span class="lp ${s}">${p}%</span></span><span class="prog ${s}"><i style="width:${Math.min(p, 100)}%"></i></span>`).join('')}</div>
         <div class="mock glass" style="left:18px;right:18px;top:15%;display:flex;gap:10px;align-items:center;padding:10px 12px;border-radius:22px;transform:rotate(1.5deg)"><span class="si" style="--c:#0B2545;width:36px;height:36px;border-radius:9px">${ic('flag')}</span><span style="font-size:13px;line-height:1.35"><b>Lazer passou do limite</b><br><span style="color:var(--muted)">R$ 210,00 de R$ 180,00 em outubro</span></span></div>`
    ][i];
    S.onboarding = {
        title: 'Apresentação', bare: true,
        render() {
            const i = state.ob, last = i === OB.length - 1;
            return `<div class="ob">
                <div class="ob-art" style="padding-top:var(--st)">${obArt(i)}</div>
                <div class="ob-txt"><h2>${OB[i].h}</h2><p>${OB[i].p}</p></div>
                <div class="ob-foot">
                    <div class="dots" aria-label="Página ${i + 1} de ${OB.length}">${OB.map((_, k) => `<i class="${k === i ? 'on' : ''}"></i>`).join('')}</div>
                    ${last ? `<button class="btn block green" ${goAttr('register')}>Criar conta grátis</button><button class="btn block gray" ${goAttr('login')}>Já tenho conta</button>`
                        : `<button class="btn block" data-act="obNext">Continuar</button><button class="btn block plain" data-act="obSkip">Pular</button>`}
                </div></div>`;
        },
        mount(el) {
            const art = $('.ob-art', el);
            let x0 = null;
            art.addEventListener('pointerdown', e => { x0 = e.clientX; });
            art.addEventListener('pointerup', e => {
                if (x0 === null) return;
                const dx = e.clientX - x0; x0 = null;
                if (dx < -40 && state.ob < OB.length - 1) { state.ob++; refresh(); }
                if (dx > 40 && state.ob > 0) { state.ob--; refresh(); }
            });
        },
        notes: {d: 'Três telas de apresentação na primeira abertura. Arraste para os lados ou toque em Continuar.', c: ['TabView com estilo de página (indicador de pontos)', 'Ilustrações feitas com os próprios componentes do app'], a: ['Nenhuma: aparece só na primeira abertura (UserDefaults)']}
    };

    S.login = {
        title: 'Entrar', bare: true, themeAware: true,
        render: () => `<div class="scroll" style="padding:0"><div class="auth">
            <div class="hd">${markSvg(isDark())}<h1>Entrar</h1><p class="sub">Use o mesmo e-mail e senha do e-Finances na web.</p></div>
            <div class="grp">
                <label class="frow stack"><span class="s" style="font-size:13px;color:var(--muted)">E-mail</span><input id="lg-email" type="email" value="${D.user.email}" autocomplete="username"></label>
                <label class="frow stack"><span class="s" style="font-size:13px;color:var(--muted)">Senha</span><span style="display:flex;align-items:center;gap:8px"><input id="lg-pass" style="flex:1" type="${state.showPass ? 'text' : 'password'}" value="exemplo-123" autocomplete="current-password"><button data-act="togglePass" aria-label="${state.showPass ? 'Esconder senha' : 'Mostrar senha'}" style="color:var(--muted)">${ic(state.showPass ? 'eye-off' : 'eye')}</button></span></label>
            </div>
            <button class="pwbar" data-act="pwFill">${ic('key-round')}<span style="flex:1;text-align:left"><b>Usar senha salva</b><small>${D.user.email} · Senhas do iPhone</small></span></button>
            <div style="display:flex;justify-content:space-between;align-items:center;padding:0 4px"><button style="display:flex;align-items:center;gap:10px;font-size:15px" data-act="keep">${tg(state.prefs.keep)}Manter conectado</button><button class="link" ${goAttr('forgot')}>Esqueci a senha</button></div>
            <button class="btn block" data-act="login" id="btn-login">Entrar</button>
            <button class="btn block gray" ${goAttr('unlock')}>${ic('scan-face')}Entrar com Face ID</button>
            <p class="alt">Ainda não tem conta? <button ${goAttr('register')}>Criar conta</button></p>
        </div></div>`,
        notes: {d: 'Login com o mesmo e-mail e senha da web. As Senhas do iPhone (iCloud Keychain) preenchem sozinhas; “Manter conectado” guarda o token no Keychain e, nas próximas vezes, basta o Face ID.', c: ['TextField com textContentType .username e SecureField .password (preenchimento automático e sugestão de senha)', 'Toggle e botões no padrão do iOS', 'Teclado de e-mail com a tecla “Entrar”'], a: ['POST /public/auth/login → tokens do Keycloak (realm finances-realm, client finances-client)'], tip: 'Toque em Entrar para ver o pedido do Face ID e o fechamento do mês.', warn: 'O login com Google está desligado na web. Se for ligado, a Apple exige oferecer também “Iniciar sessão com a Apple” (diretriz 4.8).'}
    };
    S.register = {
        title: 'Criar conta', parent: 'login', themeAware: true,
        render: () => `${navb({title: 'Criar conta'})}<div class="scroll">
            ${largeTitle('Criar conta', 'Comece pelo período grátis. Sem cartão de crédito.')}
            <div class="sec"><div class="grp">
                <label class="frow"><span class="k">Nome</span><input id="rg-n" value="Pedro"></label>
                <label class="frow"><span class="k">Sobrenome</span><input id="rg-s" value="Europeu"></label>
                <label class="frow"><span class="k">E-mail</span><input id="rg-e" type="email" value="${D.user.email}"></label>
            </div></div>
            <div class="sec"><div class="grp">
                <label class="frow"><span class="k">Família ou empresa</span><input id="rg-c" value="Casa"></label>
                <button class="frow" data-act="toastMsg" data-m="País: Brasil · Portugal · Estados Unidos"><span class="k">País</span><span class="val">Brasil</span>${ic('chevrons-up-down', 'chev-sm')}</button>
                <button class="frow" data-act="toastMsg" data-m="Moeda: Real · Euro · Dólar"><span class="k">Moeda</span><span class="val">Real (R$)</span>${ic('chevrons-up-down', 'chev-sm')}</button>
            </div><p class="foot-note">Dá para criar outras depois, como a sua empresa.</p></div>
            <div class="sec"><button class="row" style="border-radius:22px;align-items:flex-start" data-act="accept"><span class="radio ${state.accepted ? 'on' : ''}">${state.accepted ? ic('check') : ''}</span><span class="rt"><span class="t wrap" style="font-size:15px;line-height:1.4">Li e aceito os <b style="color:var(--tint)">Termos de uso</b> e a <b style="color:var(--tint)">Política de privacidade</b>.</span></span></button></div>
            <div class="pad"><button class="btn block" data-act="register" ${state.accepted ? '' : 'disabled'}>Criar conta</button>
            <p class="alt" style="text-align:center;font-size:15px;color:var(--muted)">Já tem conta? <button data-back style="color:var(--tint);font-weight:600">Entrar</button></p></div>
        </div>`,
        notes: {d: 'Cadastro rápido. A conta é criada pela fila do backend e o link para criar a senha chega por e-mail.', c: ['Form com seções (List .insetGrouped)', 'Picker de país e moeda em menu', 'Validação enquanto digita'], a: ['POST /public/registerNewUser (responde 202 Accepted)']}
    };
    S.register_done = {
        title: 'Conta criada', parent: 'login', bare: true,
        render: () => `<div class="unlock"><span></span><div style="display:flex;flex-direction:column;align-items:center;gap:16px"><span class="av xl" style="--c:#059669">${ic('mail-check')}</span><h1 class="disp" style="font-size:28px;font-weight:700">Confira seu e-mail</h1><p style="font-size:16px;line-height:1.5;max-width:300px;color:var(--text)">Enviamos para <b style="color:var(--ink)">${D.user.email}</b> o link para criar sua senha. Ele vale por 24 horas.</p></div>
            <div style="display:flex;flex-direction:column;gap:10px;width:100%"><button class="btn block" data-act="openMail">${ic('mail')}Abrir o Mail</button><button class="btn block plain" data-act="toLogin">Voltar para o login</button></div></div>`,
        notes: {d: 'Confirmação do cadastro com atalho para o app de e-mail.', c: ['Abre o Mail pelo esquema message://'], a: []}
    };
    S.forgot = {
        title: 'Esqueci a senha', parent: 'login',
        render: () => `${navb({title: 'Esqueci a senha'})}<div class="scroll">${largeTitle('Esqueci a senha', 'Informe o e-mail da sua conta. Enviaremos um link para criar uma senha nova.')}
            <div class="sec"><div class="grp"><label class="frow"><span class="k">E-mail</span><input id="fg-e" type="email" value="${D.user.email}"></label></div></div>
            <div class="pad"><button class="btn block" data-act="forgot">Enviar link</button></div></div>`,
        notes: {d: 'Pede o link para redefinir a senha.', c: ['Form com um campo', 'Aviso de confirmação'], a: ['POST /public/auth (esqueci a senha)']}
    };
    S.unlock = {
        title: 'Desbloqueio', bare: true, themeAware: true,
        render: () => `<div class="unlock">
            <div style="display:flex;flex-direction:column;align-items:center;gap:14px"><span style="width:60px;height:60px">${markSvg(isDark())}</span><h1 class="disp" style="font-size:28px;font-weight:700">Olá, ${D.user.first}</h1><p style="color:var(--muted);font-size:16px">O e-Finances está bloqueado</p></div>
            <button data-act="unlockOk" aria-label="Desbloquear com Face ID" style="display:flex;flex-direction:column;align-items:center;gap:12px;color:var(--tint);font-weight:600">${FACEID.replace('class="faceid"', 'class="faceid scan"')}Usar Face ID</button>
            <div style="display:flex;flex-direction:column;gap:4px;width:100%"><button class="btn block plain" ${goAttr('login')}>Entrar com e-mail e senha</button><button class="btn block plain" data-act="logout" style="color:var(--muted)">Não é você? Sair</button></div>
        </div>`,
        mount(el) { el._t = setTimeout(() => { if (E.cur().id === 'unlock') ACT.unlockOk(); }, 1600); el._cleanup = () => clearTimeout(el._t); },
        notes: {d: 'Ao abrir de novo, ou depois do tempo escolhido em segundo plano, o app pede o Face ID antes de mostrar valores. Sem Face ID, vale o código do iPhone.', c: ['LocalAuthentication (Face ID / Touch ID / código)', 'Chave do Keychain protegida por biometria (SecAccessControl)', 'Tela coberta no alternador de apps'], a: ['POST /api/auth/lock (mesmo bloqueio de tela da web)'], tip: 'O Face ID “lê” sozinho em instantes. Também dá para tocar no símbolo.'}
    };

    ACT.skipSplash = () => replace('onboarding');
    ACT.obNext = () => { state.ob = Math.min(state.ob + 1, OB.length - 1); refresh(); };
    ACT.obSkip = () => resetTo('login');
    ACT.togglePass = () => { state.showPass = !state.showPass; refresh(); };
    ACT.pwFill = () => toast('Senha preenchida pelas Senhas do iPhone', {icon: 'key-round'});
    ACT.keep = () => { state.prefs.keep = !state.prefs.keep; refresh(); };
    ACT.accept = () => { state.accepted = !state.accepted; refresh(); };
    ACT.login = a => {
        a.classList.add('busy'); a.innerHTML = '<span class="spin"></span>Entrando…';
        setTimeout(() => alertBox({title: 'Permitir que “e-Finances” use o Face ID?', text: 'Para abrir o app e ver seus valores sem digitar a senha. A senha não fica guardada no iPhone.',
            buttons: [{label: 'Não Permitir', fn: () => { state.prefs.bio = false; afterLogin(); }}, {label: 'OK', cls: 'pri', fn: () => { state.prefs.bio = true; afterLogin(); }}]}), 700);
    };
    const afterLogin = () => { resetTo('home'); setTimeout(() => go('story', {}, 'up'), 650); };
    ACT.unlockOk = () => {
        E.openOv(`<div class="scrim clear"></div><div class="fid-wrap"><div class="fidbox">${FACEID.replace('class="faceid"', 'class="faceid scan"')}Face ID</div></div>`);
        setTimeout(() => { closeOv(); resetTo('home'); }, 750);
    };
    ACT.register = a => { a.classList.add('busy'); a.innerHTML = '<span class="spin"></span>Criando…'; setTimeout(() => replace('register_done'), 700); };
    ACT.openMail = () => toast('Abrindo o Mail…', {icon: 'mail'});
    ACT.toLogin = () => resetTo('login');
    ACT.forgot = () => { back(); setTimeout(() => toast(`Enviamos o link para ${D.user.email}`, {icon: 'mail-check'}), 420); };
    ACT.logout = () => alertBox({title: 'Sair do e-Finances?', text: 'Você vai precisar do e-mail e da senha para entrar de novo.', buttons: [{label: 'Cancelar'}, {label: 'Sair', cls: 'red', fn: () => resetTo('login')}]});

    /* ---------- início ---------- */
    const wsButton = () => {
        const co = company(), ac = account();
        return `<button class="gbs glass" data-act="wsSheet" aria-label="Trocar empresa e conta" style="padding:0 12px 0 6px;gap:8px;max-width:220px"><span class="av sm solid sq" style="--c:${co.color};width:32px;height:32px;border-radius:10px">${initials(co.name)}</span><span style="display:flex;flex-direction:column;align-items:flex-start;min-width:0;line-height:1.15"><b style="font-size:15px;font-weight:600">${esc(co.name)}</b><small style="font-size:12px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:150px">${esc(ac.name)}</small></span>${ic('chevron-down', 'chev-sm')}</button>`;
    };
    const plusBtn = () => E.modeNow() === 'MANUAL' ? `<button class="gb tint" data-act="plusMenu" aria-label="Novo lançamento">${ic('plus')}</button>` : '';
    const heroFor = (ac, T, bal, forecast) => {
        const b = bankOf(ac);
        if (ac.mode === 'BANK' && ac.kind === 'CREDIT') {
            const bk = b.accounts.find(x => x.id === ac.id);
            return `<section class="hero bank" style="--bc:${b.color}" data-tab="tx" role="button" tabindex="0">${WM}<span class="lab">Fatura atual <span class="tag">${ic('link')}Do banco</span></span><div class="big num">${bigMoney(bk.invoice)}</div>
                <p class="fore">Fecha em ${bk.due} · disponível <b class="num">${money(bk.available)}</b> de ${money(bk.limit)}</p><span class="bar ex" style="height:6px;margin-top:10px"><i style="width:${pct(bk.limit - bk.available, bk.limit)}%;background:#FFFFFF"></i></span>
                <p class="fore" style="margin-top:6px;font-size:13px">${b.name} · atualizado ${b.updated}</p></section>`;
        }
        if (ac.mode === 'BANK') return `<section class="hero bank" style="--bc:${b.color}" data-tab="tx" role="button" tabindex="0">${WM}<span class="lab">Saldo no banco <span class="tag">${ic('link')}Do banco</span></span><div class="big num">${bigMoney(bal)}</div><p class="fore">${b.name} · atualizado ${b.updated}</p>
            <div class="split"><div><span class="k">${ic('arrow-down-left')}Entrou no mês</span><span class="v num">${money(T.inc)}</span></div><div><span class="k">${ic('arrow-up-right')}Saiu no mês</span><span class="v num">${money(T.exp)}</span></div></div></section>`;
        if (ac.mode === 'FROZEN') return `<section class="hero" style="--hero-a:#334155;--hero-b:#1E293B">${WM}<span class="lab">Saldo guardado <span class="tag">${ic('snowflake')}Congelada</span></span><div class="big num">${bigMoney(bal)}</div><p class="fore">O ${ac.bankName} foi desconectado em ${ac.frozenSince}. Esta conta fica só para consulta.</p></section>`;
        return `<section class="hero" data-tab="tx" role="button" tabindex="0" aria-label="Ver transações do mês">${WM}
            <span class="lab">Saldo da conta</span><div class="big num">${bigMoney(bal)}</div>
            <p class="fore">Previsão de fechamento <b class="num">${money(forecast)}</b></p>
            <div class="split">
                <div><span class="k">${ic('arrow-down-left')}Receitas do mês</span><span class="v num">${money(T.inc)}</span><span class="bar"><i style="width:${pct(T.incPaid, T.inc)}%"></i></span><span class="s">${pct(T.incPaid, T.inc)}% recebido</span></div>
                <div><span class="k">${ic('arrow-up-right')}Despesas do mês</span><span class="v num">${money(T.exp)}</span><span class="bar ex"><i style="width:${pct(T.expPaid, T.exp)}%"></i></span><span class="s">${pct(T.expPaid, T.exp)}% pago</span></div>
            </div></section>`;
    };
    const acctCard = a => {
        const on = state.ws.account === a.id, b = bankOf(a);
        const sub = a.mode === 'BANK' ? (a.kind === 'CREDIT' ? `fatura · fecha ${b.accounts.find(x => x.id === a.id).due}` : `saldo · ${b.updated}`) : a.mode === 'FROZEN' ? 'congelada · só consulta' : 'conta manual';
        const v = a.kind === 'CREDIT' ? b.accounts.find(x => x.id === a.id).invoice : acctBalance(a);
        const warn = b && b.status !== 'UPDATED';
        return `<button class="acard${on ? ' on' : ''}" data-act="pickWs" data-co="${state.ws.company}" data-ac="${a.id}"><span class="top">${acctAv(a, 'xs')}<span class="grow">${a.mode === 'MANUAL' ? 'e-Finances' : esc(b ? b.name : a.bankName)}</span>${warn ? ic('refresh-cw', 'wi') : on ? `<span class="tag green">Em uso</span>` : ''}</span>
            <span class="an">${esc(a.mode === 'BANK' ? a.name.split(' · ')[1] : a.mode === 'FROZEN' ? a.name.split(' · ')[1] : a.name)}</span><span class="av2 num">${money(v)}</span><span class="as">${sub}</span></button>`;
    };
    S.home = {
        title: 'Início', tab: 'home', root: true,
        render() {
            const co = company(), ac = account(), list = monthTx(BASE.y, BASE.m), T = totals(list), bal = balance();
            const forecast = bal + (T.inc - T.incPaid) - (T.exp - T.expPaid);
            const manual = ac.mode === 'MANUAL';
            const late = list.filter(t => !t.paid && days(t.date) < 0), soon = list.filter(t => !t.paid && days(t.date) >= 0 && days(t.date) <= 7);
            const due = [...late, ...soon].sort((a, b) => a.date.localeCompare(b.date)).slice(0, 4);
            const unread = state.notifs.filter(n => n.unread).length;
            const cats = byCategory(list.filter(t => t.type !== 'R'));
            const topCats = cats.slice(0, 4), rest = cats.slice(4);
            if (rest.length) topCats.push({name: 'Outras', color: '#94A3B8', v: sum(rest, c => c.v), pct: sum(rest, c => c.pct)});
            const lims = limitRows(), att = lims.filter(l => l.status !== 'ok').length;
            const flow = yearFlow(), yr = flow.filter(f => !f.proj), res = sum(yr, f => f.inc - f.exp), best = yr.reduce((a, b) => (b.inc - b.exp > a.inc - a.exp ? b : a));
            const inst = D.installments;
            const alertTxt = [late.length ? plural(late.length, 'conta atrasada', 'contas atrasadas') : '', soon.length ? `${soon.length} ${soon.length === 1 ? 'vence' : 'vencem'} nos próximos 7 dias` : ''].filter(Boolean).join(' e ');
            const dayList = list.filter(t => parse(t.date).getDate() === state.agendaDay).sort((a, b) => a.type.localeCompare(b.type));
            const subs = D.subscriptions;
            return `${navb({back: false, large: true, title: '', left: wsButton(), right: `${gbs(['eye' + (state.hide ? '-off' : ''), 'data-act="toggleHide"', state.hide ? 'Mostrar valores' : 'Esconder valores'], ['bell', goAttr('notifications'), `Notificações, ${unread} não lidas`, unread ? `<span class="bdg">${unread}</span>` : ''])}${plusBtn()}`})}
            <div class="scroll">
                ${largeTitle(`${greeting()}, ${D.user.first}`, cap(longDate(TODAY)))}
                <div class="pad">${heroFor(ac, T, bal, forecast)}</div>
                <section class="sec">${sh(`Contas em ${esc(co.name)}`, `${co.accounts.length} contas · manuais e do banco`, linkBtn('Ver todas', 'data-tab="banks"'))}
                    <div class="hscroll">${co.accounts.map(acctCard).join('')}<button class="acard add" data-act="connectSheet"><span class="av" style="--c:#059669">${ic('link')}</span><span class="an">Conectar banco</span><span class="as">Open Finance, só leitura</span></button></div></section>
                ${alertTxt && ac.mode !== 'FROZEN' ? `<div class="pad"><div class="alert ${late.length ? 'danger' : ''}">${ic(late.length ? 'circle-alert' : 'clock')}<div class="grow"><b>Fechamento do mês</b><p>${alertTxt}.</p><div class="acts"><button class="btn sm ${late.length ? 'red-fill' : ''}" data-act="goPending">Ver contas</button></div></div></div></div>` : ''}
                <div class="quick">
                    ${manual ? `<button data-act="newTx" data-type="R"><i>${ic('arrow-down-left')}</i>Recebimento</button><button data-act="newTx" data-type="V"><i>${ic('arrow-up-right')}</i>Despesa</button>`
                        : `<button data-tab="tx"><i>${ic('tags')}</i>Organizar</button><button data-act="toastMsg" data-m="Atualizando ${esc((bankOf(ac) || {name: 'o banco'}).name)}…" data-i="refresh-cw"><i>${ic('refresh-cw')}</i>Atualizar</button>`}
                    <button data-act="goPending"><i>${ic('calendar-clock')}</i>Contas a pagar</button>
                    <button ${goAttr('reports')}><i>${ic('chart-column')}</i>Relatórios</button>
                </div>
                <div class="pad"><button class="storyc" data-act="openStory"><span class="ring"><span>${markSvg(false)}</span></span><span style="flex:1;min-width:0"><b>Fechamento de setembro</b><span class="d">Quanto entrou, saiu e sobrou. Toque para ver.</span></span>${ic('chevron-right', 'chev-sm')}</button></div>
                ${due.length ? `<section class="sec">${sh('Vencem em breve', 'Atrasadas e próximos 7 dias', linkBtn('Ver todas', 'data-act="goPending"'))}<div class="grp av-rows">${due.map(t => txItem(t)).join('')}</div></section>` : ''}
                <section class="sec">${sh('Agenda', `${cap(MONTHS[BASE.m])} de ${BASE.y}`, linkBtn('Transações', 'data-tab="tx"'))}
                    <div class="card">${calendar(BASE.y, BASE.m, {sel: state.agendaDay, dayFn: d => { const it = list.filter(t => parse(t.date).getDate() === d); return {dots: [...new Set(it.map(t => !t.paid && days(t.date) < 0 ? '#D97706' : t.type === 'R' ? '#16A34A' : '#DC2626'))].slice(0, 3)}; }})}
                        <div class="legend"><span style="--c:#16A34A"><i></i>Recebimento</span><span style="--c:#DC2626"><i></i>Despesa</span><span style="--c:#D97706"><i></i>Atrasada</span></div></div>
                    <span class="glab" style="padding:4px 4px 0">${state.agendaDay} de ${MONTHS[BASE.m]}<span class="cnt">${dayList.length ? plural(dayList.length, 'lançamento', 'lançamentos') : ''}</span></span>
                    ${dayList.length ? `<div class="grp av-rows">${dayList.map(t => txItem(t)).join('')}</div>` : `<div class="card" style="align-items:center;color:var(--muted);font-size:15px">Nada marcado para este dia.${manual ? `<button class="btn sm tinted" data-act="newTxOn" data-d="${state.agendaDay}">${ic('plus')}Lançar neste dia</button>` : ''}</div>`}</section>
                ${cats.length ? `<section class="sec">${sh('Para onde foi o dinheiro', `Despesas de ${MONTHS[BASE.m]}`, linkBtn('Relatórios', goAttr('reports')))}
                    <div class="card"><div class="donut-wrap">${donut(topCats.map(c => ({v: c.v, c: c.color})), 'Despesas', compactMoney(T.exp))}<div class="lg">${topCats.map(c => `<div class="dl" style="--c:${c.color}"><i></i><span>${esc(c.name)}</span><b>${c.pct}%</b></div>`).join('')}</div></div></div></section>` : ''}
                <section class="sec">${sh('Limites por categoria', att ? `${att} ${att === 1 ? 'pede' : 'pedem'} atenção` : 'Tudo dentro do limite', linkBtn('Ver todos', 'data-act="planTab" data-t="limits"'))}
                    <div class="grp">${lims.sort((a, b) => b.p - a.p).slice(0, 3).map(l => limRow(l)).join('')}</div></section>
                <section class="sec">${sh('Parcelamentos', `Falta pagar ${money(sum(inst, i => (i.total - i.paid) * i.value))}`, linkBtn('Ver todos', 'data-act="planTab" data-t="inst"'))}
                    <div class="hscroll">${inst.map(i => `<button class="acard" style="width:200px" data-act="planTab" data-t="inst"><span style="display:flex;gap:10px;align-items:center">${pring(i.paid, i.total, 44)}<span style="min-width:0"><span class="an" style="display:block">${esc(i.name)}</span><span class="as">${money(i.value)}/mês</span></span></span><span class="as">Termina em ${i.ends}</span></button>`).join('')}</div></section>
                <section class="sec">${sh('Assinaturas', `${money(subsMonthly())} por mês · ${subs.length} ativas`, linkBtn('Ver todas', 'data-act="planTab" data-t="subs"'))}
                    <button class="card" style="flex-direction:row;align-items:center;gap:0" data-act="planTab" data-t="subs">${subs.slice(0, 6).map((s, k) => `<span style="margin-left:${k ? -8 : 0}px;box-shadow:0 0 0 2.5px var(--surface);border-radius:50%">${catAv(D.categories[s.cat], 'sm')}</span>`).join('')}<span style="flex:1;margin-left:12px;font-size:14px;color:var(--muted);text-align:left">${money(subsMonthly() * 12)} por ano</span>${ic('chevron-right', 'chev-sm')}</button></section>
                <section class="sec">${sh(`Fluxo de caixa ${BASE.y}`, `Resultado até agora ${money(res)} · melhor mês: ${best.name}`)}
                    <div class="card">${barChart(flow)}<div class="legend"><span style="--c:var(--accent)"><i></i>Receitas</span><span style="--c:var(--expense)"><i></i>Despesas</span><span style="--c:var(--faint)"><i></i>Nov e dez: previsto</span></div></div></section>
                <p class="foot">Dados de exemplo · atualizado agora</p>
            </div>`;
        },
        mount(el) { const on = $('.acard.on', el); if (on) { const c = on.parentElement; c.scrollLeft = on.offsetLeft - 16; } },
        notes: {d: 'Resumo da empresa e conta em uso: saldo e previsão, as contas da empresa (manuais e do banco) num carrossel, contas que vencem, agenda do mês, para onde foi o dinheiro, limites, parcelamentos, assinaturas e fluxo de caixa.', c: ['NavigationStack com título grande e barra em vidro (Liquid Glass)', 'Botão + com menu (recebimento, despesa fixa ou variável)', 'TabView com 5 abas flutuantes', 'ScrollView com carrossel paginado', 'Gráficos com Swift Charts', 'Puxar para atualizar (.refreshable)'], a: ['GET /api/workspace', 'GET /api/transaction (mês)', 'GET /api/limits', 'GET /api/transaction/installments', 'GET /api/transaction/subscriptions', 'GET /api/story/pending'], tip: 'Toque em “Casa” no topo ou numa conta do carrossel para trocar de conta. Numa conta do banco o app só deixa organizar.'}
    };

    ACT.plusMenu = a => contextMenu(a, [
        {label: 'Recebimento', icon: 'arrow-down-left', fn: () => newTx('R')},
        {label: 'Despesa fixa', icon: 'repeat', fn: () => newTx('F')},
        {label: 'Despesa variável', icon: 'arrow-up-right', fn: () => newTx('V')}
    ]);
    ACT.agendaDay = a => { state.agendaDay = +a.dataset.d; refresh(); };
    ACT.newTxOn = a => { newTx('V'); state.draft.date = iso(new Date(BASE.y, BASE.m, +a.dataset.d)); refresh(); };
    ACT.openStory = () => go('story', {}, 'up');
    ACT.wsSheet = () => {
        const body = D.companies.map(co => `${E.shSmall(`${esc(co.name)} · ${co.typeLabel}`)}<div class="grp av-rows" style="margin-top:-6px">${co.accounts.map(a => {
            const on = state.ws.company === co.id && state.ws.account === a.id, b = bankOf(a);
            const sub = a.mode === 'BANK' ? `${b.name} · ${b.status === 'UPDATED' ? 'atualizado ' + b.updated : 'precisa reconectar'}` : a.mode === 'FROZEN' ? `Congelada em ${a.frozenSince} · só consulta` : `${a.currency} · ${plural(a.transactions, 'lançamento', 'lançamentos')}${a.defaultAccount ? ' · padrão' : ''}`;
            const v = a.kind === 'CREDIT' ? -acctBalance(a) : acctBalance(a);
            return `<button class="row" data-act="pickWs" data-co="${co.id}" data-ac="${a.id}">${acctAv(a)}<span class="rt"><span class="t">${esc(a.name)}</span><span class="s">${sub}</span></span><span class="rv num">${money(v)}${a.kind === 'CREDIT' ? '<small>fatura</small>' : ''}</span>${on ? ic('check', 'ck') : '<span style="width:20px"></span>'}</button>`;
        }).join('')}</div>`).join('');
        sheet({title: 'Empresa e conta', body: `${body}<p class="foot-note">As contas do banco aparecem junto com as manuais. Nelas o app não lança: só organiza o que veio do banco.</p>
            <button class="btn block gray" data-act="goCompanies">${ic('building-2')}Gerenciar empresas e contas</button>`});
    };
    ACT.pickWs = a => {
        state.ws = {company: +a.dataset.co, account: a.dataset.ac};
        state.agendaDay = 11;
        closeOv();
        if (cur().id === 'companies' || cur().id === 'banks') refresh(); else if (cur().id !== 'home') tab('home'); else refresh();
        const ac = account();
        toast(`Usando ${esc(ac.name)}`, {icon: ac.mode === 'BANK' ? 'link' : ac.mode === 'FROZEN' ? 'snowflake' : 'wallet'});
    };
    ACT.goCompanies = () => { closeOv(); go('companies'); };
    ACT.goPending = () => { state.f = {...state.f, kind: 'all', status: 'pending', q: ''}; state.month = {...BASE}; tab('tx'); };
    ACT.planTab = a => { state.planTab = a.dataset.t; if (cur().id === 'plan') refresh(); else tab('plan'); };

    /* ---------- transações ---------- */
    S.tx = {
        title: 'Transações', tab: 'tx', root: true,
        render() {
            const {y, m} = state.month, all = monthTx(y, m), T = totals(all), f = state.f, ac = account();
            let list = all.filter(t => f.kind === 'all' || t.type === f.kind);
            if (f.status === 'pending') list = list.filter(t => !t.paid);
            if (f.status === 'late') list = list.filter(t => !t.paid && days(t.date) < 0);
            if (f.status === 'paid') list = list.filter(t => t.paid);
            if (f.cat) list = list.filter(t => t.cat === f.cat);
            if (f.q) { const q = norm(f.q); list = list.filter(t => norm(`${t.desc} ${t.contact || ''} ${catOf(t).name}`).includes(q)); }
            const groups = [['late', 'Atrasadas'], ['soon', 'Próximos 7 dias'], ['sched', 'Agendadas'], ['paid', ac.mode === 'MANUAL' ? 'Pagas e recebidas' : 'Lançamentos do banco']];
            const inst = D.installments.filter(i => i.source === 'LEDGER');
            const res = T.inc - T.exp;
            let body = '';
            for (const [g, label] of groups) {
                const items = list.filter(t => status(t).k === g).sort((a, b) => g === 'paid' ? b.date.localeCompare(a.date) : a.date.localeCompare(b.date));
                if (!items.length) continue;
                const tot = sum(items, t => t.type === 'R' ? t.value : -t.value);
                body += `<section class="sec"><div class="glab ${g}">${label}<span class="cnt">${items.length} · ${money(Math.abs(tot))}</span></div><div class="grp av-rows">${items.map(t => txItem(t)).join('')}</div></section>`;
            }
            if (!body) body = `<div class="empty">${ic('search')}<b>Nada por aqui</b><span>${all.length ? 'Mude os filtros ou a busca.' : `Nenhum lançamento em ${MONTHS[m]}.`}</span>${all.length ? '<button class="btn sm tinted" data-act="clearFilters">Limpar filtros</button>' : ac.mode === 'MANUAL' ? '<button class="btn sm tinted" data-act="newTx" data-type="V">Lançar agora</button>' : ''}</div>`;
            const kinds = [['all', 'Todas'], ['R', 'Recebimentos'], ['F', 'Despesas fixas'], ['V', 'Despesas variáveis']];
            const stats = [['pending', 'Pendentes'], ['late', 'Atrasadas'], ['paid', 'Pagas']];
            const lateN = all.filter(t => !t.paid && days(t.date) < 0).length;
            let nav;
            if (state.sel) {
                const n = state.sel.size;
                nav = navb({back: false, solid: true, title: n ? `${n} ${n === 1 ? 'selecionado' : 'selecionados'}` : 'Selecionar itens', left: E.gtxt('Selecionar tudo', 'data-act="selAll"'), right: E.gtxt('OK', 'data-act="selClose"', 'tint')});
            } else {
                nav = navb({back: false, large: true, title: 'Transações', right: `${gbs(['list-filter', 'data-act="filters"', 'Filtrar por categoria', f.cat ? '<span class="bdg">1</span>' : ''], ['ellipsis', 'data-act="txMenu"', 'Mais opções'])}${plusBtn()}`});
            }
            const notice = ac.mode === 'BANK' ? `<div class="pad"><div class="alert info">${ic('link')}<div class="grow"><b>Conta do ${esc(bankOf(ac).name)}</b><p>Os lançamentos vêm do banco. Dá para organizar descrição, categoria, contato, centro de custo e observações.</p></div></div></div>`
                : ac.mode === 'FROZEN' ? `<div class="pad"><div class="alert">${ic('snowflake')}<div class="grow"><b>Conta congelada</b><p>O ${esc(ac.bankName)} foi desconectado em ${ac.frozenSince}. Os lançamentos ficam só para consulta.</p></div></div></div>` : '';
            return `${nav}
            <div class="scroll">
                ${state.sel ? '<div style="height:4px"></div>' : largeTitle('Transações', `${esc(company().name)} · ${esc(ac.name)}`)}
                ${state.sel ? '' : `<label class="search">${ic('search')}<input id="q" data-q value="${esc(f.q)}" placeholder="Buscar descrição, contato ou categoria" autocomplete="off">${f.q ? `<button data-act="searchClear" aria-label="Limpar busca">${ic('circle-x')}</button>` : ''}</label>`}
                <div class="msel">${gbtn('chevron-left', 'data-act="month" data-d="-1"', 'Mês anterior')}<button class="mlabel" data-act="monthNow">${cap(MONTHS[m])} de ${y}${isBase(y, m) ? '' : '<span class="tag info">Hoje</span>'}</button>${gbtn('chevron-right', 'data-act="month" data-d="1"', 'Próximo mês')}</div>
                <div class="summ">
                    <div><span class="k">Resultado do mês</span><span class="v num" style="color:${res >= 0 ? 'var(--income)' : 'var(--expense)'}">${money(res)}</span><span class="s">receitas − despesas</span></div>
                    <div><span class="k">Recebido</span><span class="v">${pct(T.incPaid, T.inc)}%</span><span class="s">de ${compactMoney(T.inc)}</span></div>
                    <div><span class="k">Pago</span><span class="v">${pct(T.expPaid, T.exp)}%</span><span class="s">de ${compactMoney(T.exp)}</span></div>
                </div>
                <div style="display:flex;flex-direction:column;gap:8px">
                    <div class="chips" role="tablist">${kinds.map(([k, l]) => `<button class="chip ${f.kind === k ? 'on' : ''}" data-act="fKind" data-v="${k}" role="tab" aria-selected="${f.kind === k}">${l}</button>`).join('')}</div>
                    <div class="chips">${stats.map(([k, l]) => `<button class="chip ${f.status === k ? 'on' : ''}" data-act="fStatus" data-v="${k}">${f.status === k ? ic('check') : ''}${l}${k === 'late' && lateN ? ` <span class="n">${lateN}</span>` : ''}</button>`).join('')}
                        ${f.cat ? `<button class="chip on" data-act="fCatClear">${D.categories[f.cat].name}${ic('x')}</button>` : ''}</div>
                </div>
                ${notice}
                ${inst.length && isBase(y, m) && !f.q && !state.sel && ac.id === 'cc' ? `<div class="pad"><button class="row" style="border-radius:20px" data-act="planTab" data-t="inst">${si('layers', '#0B2545')}<span class="rt"><span class="t">${plural(inst.length, 'parcelamento', 'parcelamentos')} em andamento</span><span class="s">${money(sum(inst, i => i.value))} por mês nos lançamentos</span></span>${ic('chevron-right', 'chev')}</button></div>` : ''}
                ${body}
            </div>
            ${state.sel ? `<div class="selbar glass"><button data-act="selPay" ${state.sel.size ? '' : 'disabled'}>${ic('check-check')}Pagar</button><button data-act="selCat" ${state.sel.size ? '' : 'disabled'}>${ic('tag')}Categoria</button><button class="red" data-act="selDel" ${state.sel.size ? '' : 'disabled'}>${ic('trash-2')}Excluir</button></div>` : ''}`;
        },
        notes: {d: 'Lançamentos do mês em uso, agrupados em atrasadas, próximos 7 dias, agendadas e pagas. Busca, filtros por tipo, situação e categoria, seleção de vários e o “Resultado do mês”. Na conta do banco só dá para organizar; na congelada, só consultar.', c: ['List com seções e .searchable', 'swipeActions: direita marca como pago, esquerda abre Mais e Excluir (deslize até o fim para excluir)', 'contextMenu no toque longo', 'EditMode para selecionar vários, com barra de ações embaixo', 'Excluir sem perguntar, com “Desfazer” (igual à web)'], a: ['GET /api/transaction (por mês)', 'POST /api/transaction/update (pagar, categoria)', 'DELETE /api/transaction (com escopo para recorrentes e parcelas)'], tip: 'Deslize um lançamento para a direita (pagar) ou para a esquerda (mais, excluir). Segure um lançamento para ver o menu.'}
    };

    ACT.month = a => { const d = new Date(state.month.y, state.month.m + +a.dataset.d, 1); state.month = {y: d.getFullYear(), m: d.getMonth()}; refresh(); };
    ACT.monthNow = () => { state.month = {...BASE}; refresh(); };
    ACT.fKind = a => { state.f.kind = a.dataset.v; refresh(); };
    ACT.fStatus = a => { state.f.status = state.f.status === a.dataset.v ? null : a.dataset.v; refresh(); };
    ACT.fCatClear = () => { state.f.cat = null; refresh(); };
    ACT.clearFilters = () => { state.f = {kind: 'all', status: null, q: '', cat: null}; refresh(); };
    ACT.searchClear = () => { state.f.q = ''; refresh({focus: '#q'}); };
    ACT.filters = () => { state.pickFor = 'filter'; catSheet('Filtrar por categoria', state.f.cat, true); };
    ACT.txMenu = a => contextMenu(a, [
        ...(E.modeNow() === 'MANUAL' ? [{label: 'Selecionar', icon: 'list-checks', fn: () => { state.sel = new Set(); refresh(); }}] : []),
        {label: 'Exportar', icon: 'share', fn: () => go('web', {page: 'export'})},
        {label: 'Importar extrato', icon: 'file-up', fn: () => go('web', {page: 'import'})},
        {label: 'Parcelamentos', icon: 'layers', fn: () => { state.planTab = 'inst'; tab('plan'); }}
    ]);
    ACT.selAll = () => { const {y, m} = state.month; monthTx(y, m).forEach(t => state.sel.add(String(t.id))); refresh(); };
    ACT.selClose = () => { state.sel = null; refresh(); };
    ACT.selPay = () => { if (!state.sel.size) return; const items = [...state.sel].map(findTx).filter(t => !t.paid); items.forEach(t => setPaid(t, true)); state.sel = null; refresh(); toast(`${plural(items.length, 'marcado como pago', 'marcados como pagos')}`, {action: 'Desfazer', fn: () => { items.forEach(t => setPaid(t, false)); refresh(); }}); };
    ACT.selCat = () => { if (!state.sel.size) return; state.pickFor = 'batch'; catSheet('Alterar categoria', null); };
    ACT.selDel = () => {
        if (!state.sel.size) return;
        const items = [...state.sel].map(findTx);
        items.forEach(t => { if (t.paid) setPaid(t, false); removeTx(t.id); });
        state.sel = null; refresh();
        toast(`${plural(items.length, 'lançamento excluído', 'lançamentos excluídos')}`, {action: 'Desfazer', fn: () => { items.forEach(restoreTx); refresh(); }});
    };

    // menu do toque longo e "Mais"
    E.txMenu = (row, t) => {
        const fz = frozen(t), lk = locked(t);
        const items = fz ? [{label: 'Ver detalhe', icon: 'file-text', fn: () => go('tx_detail', {id: t.id})}]
            : lk ? [{label: 'Organizar', icon: 'tags', fn: () => organize(t)}, {label: 'Ver detalhe', icon: 'file-text', fn: () => go('tx_detail', {id: t.id})}, {label: 'Emitir recibo', icon: 'receipt', fn: () => receiptSheet(t)}]
            : [{label: t.paid ? 'Voltar para pendente' : t.type === 'R' ? 'Marcar como recebido' : 'Marcar como pago', icon: t.paid ? 'rotate-ccw' : 'circle-check', fn: () => togglePaid(t)},
                {label: 'Editar', icon: 'pencil', fn: () => editTx(t)}, {label: 'Duplicar', icon: 'copy', fn: () => dupTx(t)},
                {label: 'Mover de tipo', icon: 'arrow-left-right', fn: () => moveType(t)}, {label: 'Emitir recibo', icon: 'receipt', fn: () => receiptSheet(t)}, {},
                {label: 'Excluir', icon: 'trash-2', red: true, fn: () => delTx(t)}];
        contextMenu(row, items);
    };
    ACT.txMore = a => { const t = findTx(a.dataset.id); E.closeSwipes(); actionSheet({title: esc(t.desc), items: [
        {label: 'Editar', fn: () => editTx(t)}, {label: 'Duplicar', fn: () => dupTx(t)}, {label: 'Mover de tipo', fn: () => moveType(t)}, {label: 'Emitir recibo', fn: () => receiptSheet(t)}]}); };
    function togglePaid(t) {
        setPaid(t, !t.paid); refresh();
        toast(t.paid ? (t.type === 'R' ? 'Marcado como recebido' : 'Marcado como pago') : 'Voltou para pendente', {action: 'Desfazer', fn: () => { setPaid(t, !t.paid); refresh(); }});
    }
    ACT.togglePaid = a => togglePaid(findTx(a.dataset.id));
    const isSeries = t => t.mode === 'REPEATABLE' || !!t.plot;
    /** Excluir sem perguntar; recorrente e parcela pedem o escopo (como na web). */
    function delTx(t, after) {
        const run = scope => {
            const victims = [t];
            if (scope !== 'one') {
                const base = String(t.id).split('-')[0];
                E.allTx().filter(x => x !== t && String(x.id).split('-')[0] === base && (scope === 'all' || x.date > t.date)).forEach(x => victims.push(x));
            }
            const base = String(t.id).split('-')[0];
            if (scope !== 'one') state.cut[base] = scope === 'all' ? '0000-00-00' : t.date;
            const wasPaid = victims.filter(x => x.paid && !x.gen);
            victims.forEach(x => { if (wasPaid.includes(x)) setPaid(x, false); removeTx(x.id); });
            if (after) after(); else refresh();
            const msg = scope === 'one' ? 'Lançamento excluído' : scope === 'next' ? 'Este e os próximos excluídos' : 'Série excluída';
            toast(msg, {action: 'Desfazer', fn: () => { delete state.cut[base]; victims.forEach(restoreTx); wasPaid.forEach(x => setPaid(x, true)); refresh(); }});
        };
        if (!isSeries(t)) return run('one');
        const rec = t.mode === 'REPEATABLE';
        actionSheet({title: rec ? 'Este lançamento se repete' : `Parcela ${t.plot}`, text: 'O que você quer excluir?', items: [
            {label: rec ? 'Só este' : 'Só esta parcela', red: true, fn: () => run('one')},
            {label: rec ? 'Este e os próximos' : 'Esta e as próximas', red: true, fn: () => run('next')},
            {label: rec ? 'Todos da série' : 'Todas as parcelas', red: true, fn: () => run('all')}]});
    }
    ACT.delTx = a => delTx(findTx(a.dataset.id));
    function dupTx(t) { const n = {...t, id: E.state.nextId++, paid: false, base: false, gen: false, src: undefined, acct: t.acct === 'cc' || E.findAcct(t.acct).mode === 'MANUAL' ? t.acct : 'cc'}; state.tx.push(n); go('tx_detail', {id: n.id}); toast('Lançamento duplicado', {icon: 'copy'}); }
    function moveType(t) { actionSheet({title: 'Mover de tipo', items: Object.entries(TYPES).map(([k, l]) => ({label: `${l}${t.type === k ? ' ✓' : ''}`, fn: () => { t.type = k; refresh(); toast(`Agora é ${l.toLowerCase()}`); }}))}); }
    function editTx(t) { state.draft = newDraft(null, t); go('tx_form'); }
    function organize(t) { state.draft = newDraft(null, t); state.draft.organize = true; go('tx_form'); }
    ACT.organize = a => organize(findTx(a.dataset.id));
    function receiptSheet(t) {
        const R = t.type === 'R';
        sheet({title: 'Recibo', right: `<button class="gb glass" data-act="shareSheet" data-what="recibo-${t.id}.pdf" aria-label="Compartilhar">${ic('share')}</button>`,
            body: `<div class="receipt"><h4><span>RECIBO</span><span class="num">${fmt(t.value)}</span></h4><div class="ln"></div>
                <p>Recebi de <b>${R ? esc(t.contact || '—') : `${D.user.first} ${D.user.last}`}</b> a quantia de <b>${fmt(t.value)}</b>, referente a <b>${esc(t.desc.toLowerCase())}</b>, competência ${MONTHS[parse(t.date).getMonth()]}/${parse(t.date).getFullYear()}.</p>
                <p>Forma de pagamento: ${PAY[t.pay] || '—'}.</p><p>São Paulo, ${parse(t.date).getDate()} de ${MONTHS[parse(t.date).getMonth()]} de ${parse(t.date).getFullYear()}.</p>
                <div class="sig">${R ? `${D.user.first} ${D.user.last}` : esc(t.contact || '—')}</div></div>
                <div class="fld"><span class="lab">Modelo</span><div class="chips wrap">${D.receiptModels.map((r, i) => `<button class="chip ${i === 0 ? 'on' : ''}" data-act="chipOne">${r.name}</button>`).join('')}</div></div>`,
            foot: `<button class="btn gray" data-act="toastMsg" data-m="PDF salvo em Arquivos" data-i="download">${ic('download')}Salvar em Arquivos</button><button class="btn" data-act="shareSheet" data-what="recibo-${t.id}.pdf">${ic('share')}Compartilhar</button>`});
    }
    ACT.receipt = a => receiptSheet(findTx(a.dataset.id));
    ACT.chipOne = a => { [...a.parentElement.children].forEach(c => c.classList.toggle('on', c === a)); };
    ACT.shareSheet = a => {
        const what = a.dataset.what || 'arquivo';
        sheet({title: what, sub: 'Documento PDF · 84 KB', body: `<div style="display:flex;gap:16px;overflow-x:auto;padding:4px 2px">${[['WhatsApp', '#25D366', 'message-circle'], ['Mail', '#2563EB', 'mail'], ['Mensagens', '#16A34A', 'message-square'], ['Arquivos', '#0EA5E9', 'folder-open'], ['Notas', '#CA8A04', 'sticky-note']].map(([n, c, i]) => `<button style="display:flex;flex-direction:column;align-items:center;gap:6px;font-size:12px;flex:none" data-act="shared" data-n="${n}"><span class="si" style="--c:${c};width:58px;height:58px;border-radius:15px">${ic(i)}</span>${n}</button>`).join('')}</div>
            <div class="grp"><button class="row" data-act="shared" data-n="Copiar"><span class="rt"><span class="t">Copiar</span></span>${ic('copy')}</button><button class="row" data-act="shared" data-n="Imprimir"><span class="rt"><span class="t">Imprimir</span></span>${ic('file-text')}</button><button class="row" data-act="shared" data-n="Salvar em Arquivos"><span class="rt"><span class="t">Salvar em Arquivos</span></span>${ic('folder-open')}</button></div>`});
    };
    ACT.shared = a => { closeOv(); toast(`${a.dataset.n}: pronto`, {icon: 'circle-check'}); };

    /* ---------- detalhe ---------- */
    S.tx_detail = {
        title: 'Detalhe do lançamento', parent: 'tx',
        render(p) {
            const t = findTx(p.id);
            if (!t) return `${navb({title: 'Lançamento'})}<div class="scroll"><div class="empty">${ic('trash-2')}<b>Lançamento excluído</b></div></div>`;
            const c = catOf(t), s = status(t), R = t.type === 'R', cc = t.cc && D.costCenters[t.cc], fz = frozen(t), lk = locked(t);
            const acc = E.findAcct(t.acct), b = bankOf(acc);
            const plot = t.plot ? t.plot.split('/').map(Number) : null;
            const files = t.files ? [{n: R ? 'comprovante-pix.pdf' : (t.pay === 'BOLETO_BANCARIO' ? 'boleto-outubro.pdf' : 'nota-fiscal.jpg'), s: '182 KB'}] : [];
            const right = fz ? '' : `${E.gtxt(lk ? 'Organizar' : 'Editar', `data-act="${lk ? 'organize' : 'editTx'}" data-id="${t.id}"`)}${lk ? '' : gbtn('ellipsis', `data-act="detailMenu" data-id="${t.id}"`, 'Mais ações')}`;
            return `${navb({title: esc(t.desc), right, large: true})}
            <div class="scroll">
                <div class="dhero">${catAv(c, 'lg')}<h2>${esc(t.desc)}</h2><p>${E.TYPES[t.type]}${t.contact ? ' · ' + esc(t.contact) : ''}</p>
                    <div class="dval num ${R ? 'in' : ''}">${signed(t.value, t.type)}</div>
                    ${lk ? `<span class="tag navy">${ic('link')}Veio do ${esc(b ? b.name : acc.bankName)} · ${dmy(t.date)}</span>` : `<span class="tag ${s.k}" style="height:28px;padding:0 12px;font-size:13px">${ic(t.paid ? 'circle-check' : s.k === 'late' ? 'circle-alert' : 'clock')}${s.label}${t.paid ? ` em ${dm(t.date)}` : ''}</span>`}</div>
                ${fz ? `<div class="pad"><div class="alert">${ic('snowflake')}<div class="grow"><b>Conta congelada</b><p>Só consulta: o banco foi desconectado em ${acc.frozenSince}.</p></div></div></div>`
                    : lk ? `<div class="pad"><div class="alert info">${ic('lock')}<div class="grow"><b>Valor e data vêm do banco</b><p>Você pode organizar: descrição, categoria, contato, centro de custo e observações.</p></div></div></div>`
                    : `<div class="pad">${t.paid ? `<button class="btn block gray" data-act="togglePaid" data-id="${t.id}">${ic('rotate-ccw')}Voltar para pendente</button>` : `<button class="btn block ${s.k === 'late' ? 'red-fill' : ''}" data-act="togglePaid" data-id="${t.id}">${ic('check')}${R ? 'Marcar como recebido' : 'Marcar como pago'}</button>`}</div>`}
                ${plot ? `<div class="pad"><div class="card"><div style="display:flex;justify-content:space-between;align-items:baseline"><b style="font-weight:600">Parcela ${plot[0]} de ${plot[1]}</b><span style="font-size:14px;color:var(--muted)">Faltam ${plot[1] - plot[0]} · ${money((plot[1] - plot[0]) * t.value)}</span></div><span class="prog"><i style="width:${plot[0] / plot[1] * 100}%"></i></span></div></div>` : ''}
                <div class="sec"><div class="grp"><div class="kv">
                    <div><span>${R ? 'Recebimento em' : 'Vencimento'}</span><b>${dmy(t.date)}</b></div>
                    <div><span>Competência</span><b>${MONTHS[parse(t.date).getMonth()]} de ${parse(t.date).getFullYear()}</b></div>
                    <div><span>Categoria</span><b>${esc(c.name)}</b></div>
                    <div><span>${R ? 'Recebido de' : 'Pago a'}</span><b>${esc(t.contact || '—')}</b></div>
                    <div><span>Conta</span><b>${esc(acc.co.name)} · ${esc(acc.name)}</b></div>
                    <div><span>Centro de custo</span><b>${cc ? esc(cc.name) : '—'}</b></div>
                    <div><span>Forma de pagamento</span><b>${PAY[t.pay] || '—'}</b></div>
                    <div><span>Repetição</span><b>${MODE[t.mode]}${t.rec && t.mode !== 'ONE_TIME' ? ' · ' + REC[t.rec].toLowerCase() : ''}${t.ends ? ` · termina em ${t.ends}` : ''}</b></div>
                    ${t.doc ? `<div><span>Nº do documento</span><b class="num">${esc(t.doc)}</b></div>` : ''}
                    ${t.notes ? `<div><span>Observações</span><b>${esc(t.notes)}</b></div>` : ''}
                </div></div></div>
                <section class="sec">${sh('Comprovantes', files.length ? '1 arquivo' : 'Nenhum anexo')}<div class="files">${files.map(f => `<button class="file" data-act="toastMsg" data-m="Abrindo ${f.n} na Visualização Rápida" data-i="file-text">${catAv({icon: 'file-text', color: '#DC2626'}, 'sm')}<span class="tx2"><b>${f.n}</b><small>${f.s}</small></span></button>`).join('')}${fz ? '' : `<button class="file add" data-act="attach">${ic('camera')}Anexar</button>`}</div></section>
                <div class="pad"><div class="btns"><button class="btn gray" data-act="receipt" data-id="${t.id}">${ic('receipt')}Recibo</button>${lk || fz ? '' : `<button class="btn gray" data-act="dupTx" data-id="${t.id}">${ic('copy')}Duplicar</button>`}</div>
                ${lk || fz ? '' : `<button class="btn block red" data-act="delDetail" data-id="${t.id}">${ic('trash-2')}Excluir lançamento</button>`}</div>
            </div>`;
        },
        notes: {d: 'Tudo sobre um lançamento: situação, parcela, categoria, contato, conta, centro de custo, pagamento, repetição e comprovantes. Lançamento do banco mostra “Organizar” no lugar de “Editar”.', c: ['NavigationStack com Editar e menu no topo', 'Form com LabeledContent', 'QuickLook para abrir o comprovante', 'Excluir sem perguntar, com “Desfazer”'], a: ['GET /api/transaction/{id}', 'GET /api/transaction-receipt (comprovantes)', 'GET /api/receipt (recibo em PDF)']}
    };
    ACT.editTx = a => editTx(findTx(a.dataset.id));
    ACT.dupTx = a => dupTx(findTx(a.dataset.id));
    ACT.delDetail = a => { const t = findTx(a.dataset.id); delTx(t, () => back()); };
    ACT.detailMenu = a => { const t = findTx(a.dataset.id); contextMenu(a, [{label: 'Duplicar', icon: 'copy', fn: () => dupTx(t)}, {label: 'Mover de tipo', icon: 'arrow-left-right', fn: () => moveType(t)}, {label: 'Emitir recibo', icon: 'receipt', fn: () => receiptSheet(t)}, {label: 'Compartilhar', icon: 'share', fn: () => ACT.shareSheet({dataset: {what: `lancamento-${t.id}.pdf`}})}, {}, {label: 'Excluir', icon: 'trash-2', red: true, fn: () => delTx(t, () => back())}]); };
    ACT.attach = () => actionSheet({title: 'Anexar comprovante', items: [
        {label: 'Escanear documento', fn: attachDo}, {label: 'Tirar foto', fn: attachDo}, {label: 'Escolher das Fotos', fn: attachDo}, {label: 'Escolher em Arquivos (PDF)', fn: attachDo}]});
    function attachDo() {
        if (cur().id === 'tx_form' && state.draft) { state.draft.files.push(`comprovante-${pad(state.draft.files.length + 1)}.pdf`); refresh(); }
        toast('Comprovante anexado', {icon: 'paperclip'});
    }

    /* ---------- novo lançamento / editar / organizar ---------- */
    function newDraft(type = 'V', from) {
        const t = from;
        return {
            id: t ? t.id : null, type: t ? t.type : type, value: t ? Math.round(t.value * 100) : 0, desc: t ? t.desc : '', date: t ? t.date : iso(TODAY),
            cat: t ? t.cat : null, contact: t ? t.contact || '' : '', paid: t ? t.paid : false, pay: t ? t.pay : (type === 'R' ? 'TED' : 'CARTAO_CREDITO'),
            mode: t ? t.mode : 'ONE_TIME', n: 3, totalMode: 'total', rec: t ? t.rec || 'MONTHLY' : 'MONTHLY', cc: t ? t.cc || null : null, endKind: t && t.ends ? 'date' : 'never', endDate: t && t.ends ? t.ends : 'dez/2026', endN: 12,
            ref: t ? t.date.slice(0, 7) : iso(TODAY).slice(0, 7), doc: t ? t.doc || '' : '', notes: t ? t.notes || '' : '', files: [], more: !!(t && (t.cc || t.doc || t.notes)), errors: {},
            account: t ? t.acct : (E.modeNow() === 'MANUAL' ? state.ws.account : 'cc'), organize: false
        };
    }
    E.newDraft = newDraft;
    function newTx(type) { state.draft = newDraft(type); go('tx_form'); }
    ACT.newTx = a => newTx(a.dataset.type || 'V');
    /** Parcelas: a primeira leva os centavos que sobram (igual à web). */
    function splitInstallments(totalCents, n) { const base = Math.floor(totalCents / n), rest = totalCents - base * n; return Array.from({length: n}, (_, i) => base + (i === 0 ? rest : 0)); }
    S.tx_form = {
        title: 'Novo lançamento', parent: 'tx', modal: true,
        render() {
            if (!state.draft) state.draft = newDraft('V');
            const d = state.draft, R = d.type === 'R', c = d.cat ? D.categories[d.cat] : null, cc = d.cc ? D.costCenters[d.cc] : null, org = d.organize;
            const isToday = d.date === iso(TODAY), isTom = d.date === iso(new Date(2026, 9, 12));
            const totalC = d.totalMode === 'total' ? d.value : d.value * d.n, parts = splitInstallments(totalC, d.n);
            const acc = E.findAcct(d.account) || account();
            const title = org ? 'Organizar' : d.id ? 'Editar lançamento' : 'Novo lançamento';
            const field = (k, inner, cls = '') => `<div class="frow ${cls}">${inner}</div>`;
            return `${navb({back: false, title, left: `<button class="gb glass" data-act="formClose" aria-label="Cancelar">${ic('x')}</button>`, right: `<button class="gb tint" data-act="saveDraft" aria-label="Salvar">${ic('check')}</button>`})}
            <div class="scroll">
                ${org ? `<div class="pad"><div class="alert info">${ic('lock')}<div class="grow"><b>Veio do banco</b><p>Valor, data e situação não mudam. Organize a descrição, a categoria, o contato, o centro de custo e as observações.</p></div></div></div>` : `<div class="pad">${seg(Object.entries(TYPES), d.type, 'dType', d.type === 'R' ? 'R big' : 'big')}</div>`}
                <button class="amt" data-act="${org ? 'noop' : 'keypad'}" aria-label="Valor">
                    <span class="lab">${R ? 'Valor a receber' : 'Valor a pagar'}${org ? ` ${ic('lock')}` : ''}</span>
                    <span class="val num ${R ? 'R' : ''} ${d.value ? '' : 'zero'}" id="amtv">${fmt(d.value / 100)}</span>
                    <span class="help ${d.errors.value ? 'err' : ''}">${org ? `${dmy(d.date)} · ${d.paid ? 'pago' : 'pendente'}` : d.errors.value || 'Toque para digitar'}</span></button>
                <div class="sec"><div class="grp">
                    <label class="frow ${d.errors.desc ? 'err' : ''}"><span class="k">${d.errors.desc ? 'Descrição obrigatória' : 'Descrição'}</span><input id="f-desc" data-bind="desc" value="${esc(d.desc)}" placeholder="${R ? 'Ex.: Aluguel recebido' : 'Ex.: Conta de luz'}" autocomplete="off"></label>
                    ${org ? '' : field('date', `<span class="k">${R ? 'Recebimento' : 'Vencimento'}</span><span style="margin-left:auto;display:flex;gap:6px"><button class="datep ${isToday ? 'on' : ''}" data-act="dDate" data-v="0">Hoje</button><button class="datep ${isTom ? 'on' : ''}" data-act="dDate" data-v="1">Amanhã</button><button class="datep ${!isToday && !isTom ? 'on' : ''}" data-act="datePick">${!isToday && !isTom ? dmy(d.date) : ic('calendar')}</button></span>`)}
                    <button class="frow" data-act="catPick">${c ? catAv(c, 'xs') : ''}<span class="k">Categoria</span><span class="val ${c ? '' : 'ph'}">${c ? esc(c.name) : 'Escolher'}</span>${ic('chevron-right', 'chev-sm')}</button>
                    <button class="frow" data-act="contactPick"><span class="k">${R ? 'Recebido de' : 'Pago a'}</span><span class="val ${d.contact ? '' : 'ph'}">${d.contact ? esc(d.contact) : 'Opcional'}</span>${ic('chevron-right', 'chev-sm')}</button>
                    ${org ? '' : `<button class="frow" data-act="acctPick"><span class="k">Conta</span><span class="val">${esc(acc.name)}</span>${ic('chevrons-up-down', 'chev-sm')}</button>
                    <button class="frow" data-act="dPaid"><span class="k">${R ? 'Já foi recebido' : 'Já foi pago'}</span><span style="margin-left:auto">${tg(d.paid)}</span></button>
                    <button class="frow" data-act="payPick"><span class="k">Pagamento</span><span class="val">${PAY[d.pay]}</span>${ic('chevrons-up-down', 'chev-sm')}</button>`}
                </div>${!org && !d.paid ? '' : org ? '' : `<p class="foot-note">Entra no saldo da conta agora.</p>`}</div>
                ${org ? '' : `<section class="sec">${E.shSmall('Repetição').replace('sh small', 'sh small" style="padding:0 4px')}
                    ${seg(Object.entries(MODE), d.mode, 'dMode')}
                    ${d.mode === 'MANY_TIMES' ? `<div class="grp">
                        <div class="frow"><span class="k">Parcelas</span><span style="margin-left:auto;display:flex;align-items:center;gap:12px"><b class="num" style="font-weight:600">${d.n}×</b><span class="stepper"><button data-act="dN" data-v="-1" aria-label="Menos">${ic('minus')}</button><i></i><button data-act="dN" data-v="1" aria-label="Mais">${ic('plus')}</button></span></span></div>
                        <div class="frow">${seg([['total', 'Valor é o total'], ['parcela', 'Valor é a parcela']], d.totalMode, 'dTotal').replace('class="seg ', 'style="flex:1" class="seg ')}</div>
                        ${parts.slice(0, 3).map((v, i) => `<div class="frow"><span class="k" style="color:var(--muted)">${i + 1}ª parcela</span><span class="val num" style="color:var(--ink)">${fmt(v / 100)}</span><span class="val" style="margin-left:12px">${dmy(addMonths(d.date, Math.round(i * REC_STEP[d.rec])))}</span></div>`).join('')}
                        ${d.n > 3 ? `<div class="frow"><span class="k" style="color:var(--muted)">… até a ${d.n}ª</span><span class="val">${dmy(addMonths(d.date, Math.round((d.n - 1) * REC_STEP[d.rec])))}</span></div>` : ''}
                    </div><p class="foot-note">${d.n}× · total ${fmt(totalC / 100)}${parts[0] !== parts[1] ? '. A 1ª parcela leva os centavos que sobram.' : ''} Dá para mudar a data de cada parcela depois.</p>` : ''}
                    ${d.mode === 'REPEATABLE' ? `<div class="chips wrap">${Object.entries(REC).map(([k, l]) => `<button class="chip ${d.rec === k ? 'on' : ''}" data-act="dRec" data-v="${k}">${l}</button>`).join('')}</div>
                        <div class="grp"><div class="frow"><span class="k">Termina</span>${seg([['never', 'Nunca'], ['date', 'Em uma data'], ['n', 'Depois de']], d.endKind, 'dEnd').replace('class="seg ', 'style="margin-left:auto;width:250px" class="seg ')}</div>
                        ${d.endKind === 'date' ? `<button class="frow" data-act="dEndDate"><span class="k">Último mês</span><span class="val">${d.endDate}</span>${ic('chevrons-up-down', 'chev-sm')}</button>` : ''}
                        ${d.endKind === 'n' ? `<div class="frow"><span class="k">Vezes</span><span style="margin-left:auto;display:flex;align-items:center;gap:12px"><b class="num">${d.endN}</b><span class="stepper"><button data-act="dEndN" data-v="-1" aria-label="Menos">${ic('minus')}</button><i></i><button data-act="dEndN" data-v="1" aria-label="Mais">${ic('plus')}</button></span></span></div>` : ''}</div>
                        <p class="foot-note">Lançamos o próximo automaticamente, ${REC[d.rec].toLowerCase()}${d.endKind === 'never' ? ', até você parar' : d.endKind === 'date' ? `, até ${d.endDate}` : `, ${d.endN} vezes`}.</p>` : ''}
                </section>`}
                <section class="sec"><button class="row" style="border-radius:22px" data-act="dMore"><span class="rt"><span class="t">Mais detalhes</span><span class="s">Centro de custo, competência, documento, observações${org ? '' : ', comprovantes'}</span></span>${ic(d.more ? 'chevron-up' : 'chevron-down', 'chev')}</button>
                ${d.more ? `<div class="grp">
                    <button class="frow" data-act="ccPick">${cc ? catAv(cc, 'xs') : ''}<span class="k">Centro de custo</span><span class="val ${cc ? '' : 'ph'}">${cc ? cc.name : 'Opcional'}</span>${ic('chevron-right', 'chev-sm')}</button>
                    ${org ? '' : `<label class="frow"><span class="k">Competência</span><input type="month" data-bind="ref" value="${d.ref}" style="max-width:170px"></label>
                    <label class="frow"><span class="k">Nº do documento</span><input data-bind="doc" value="${esc(d.doc)}" placeholder="Nota fiscal, boleto…"></label>`}
                    <label class="frow stack"><span class="k">Observações</span><textarea data-bind="notes" placeholder="Opcional">${esc(d.notes)}</textarea></label>
                </div>
                ${org ? '' : `<div class="files">${d.files.map(f => `<div class="file">${catAv({icon: 'file-text', color: '#0284C7'}, 'sm')}<span class="tx2"><b>${f}</b><small>1,2 MB</small></span></div>`).join('')}<button class="file add" data-act="attach">${ic('camera')}Anexar</button></div>`}` : ''}</section>
                <div class="pad"><button class="btn block" data-act="saveDraft">${ic('check')}${org ? 'Salvar organização' : 'Salvar lançamento'}</button></div>
            </div>`;
        },
        notes: {d: 'Lançar, editar ou organizar em uma folha que sobe por cima da tela: tipo, valor no teclado numérico, vencimento, categoria e contato (criados na hora), pago ou não, à vista, parcelado (a 1ª leva os centavos) ou recorrente com “Termina em”. Para o que veio do banco, só os campos de organizar.', c: ['.sheet em tela cheia com X e ✓ na barra (iOS 26)', 'Picker segmentado para tipo e repetição', 'Teclado numérico (.decimalPad) com centavos pela direita', 'DatePicker gráfico', 'Stepper para parcelas', 'VisionKit para escanear o comprovante'], a: ['POST /api/transaction (ou PUT ao editar)', 'POST /api/transaction/update só com os campos de organizar (lançamentos do banco)', 'POST /api/transaction-receipt (anexos)'], tip: 'Escolha “Parcelado” e um valor quebrado (ex.: R$ 100,00 em 3×) para ver a 1ª parcela levar os centavos. Puxe a folha pelo topo… ou toque no X.'}
    };
    ACT.noop = () => {};
    ACT.formClose = () => {
        const d = state.draft;
        if (d && (d.value || d.desc) && !d.id) actionSheet({items: [{label: 'Descartar alterações', red: true, fn: () => { state.draft = null; back(); }}]});
        else { state.draft = null; back(); }
    };
    ACT.dType = a => { const d = state.draft; d.type = a.dataset.v; const inc = d.cat && D.categories[d.cat].income; if (d.type === 'R' && d.cat && !inc) d.cat = null; if (d.type !== 'R' && inc) d.cat = null; refresh(); };
    ACT.dDate = a => { state.draft.date = iso(new Date(2026, 9, 11 + +a.dataset.v)); refresh(); };
    ACT.dPaid = () => { state.draft.paid = !state.draft.paid; refresh(); };
    ACT.dMode = a => { state.draft.mode = a.dataset.v; refresh(); };
    ACT.dN = a => { state.draft.n = Math.max(2, Math.min(48, state.draft.n + +a.dataset.v)); refresh(); };
    ACT.dTotal = a => { state.draft.totalMode = a.dataset.v; refresh(); };
    ACT.dRec = a => { state.draft.rec = a.dataset.v; refresh(); };
    ACT.dEnd = a => { state.draft.endKind = a.dataset.v; refresh(); };
    ACT.dEndN = a => { state.draft.endN = Math.max(2, Math.min(120, state.draft.endN + +a.dataset.v)); refresh(); };
    ACT.dEndDate = () => actionSheet({title: 'Último mês', items: ['dez/2026', 'jun/2027', 'dez/2027'].map(v => ({label: v, fn: () => { state.draft.endDate = v; refresh(); }}))});
    ACT.dMore = () => { state.draft.more = !state.draft.more; refresh(); };
    // data
    ACT.datePick = () => { const d = parse(state.draft.date); state.dp = {y: d.getFullYear(), m: d.getMonth()}; dateSheet(); };
    function dateSheet() {
        const {y, m} = state.dp, sel = parse(state.draft.date), selDay = sel.getFullYear() === y && sel.getMonth() === m ? sel.getDate() : null;
        sheet({title: state.draft.type === 'R' ? 'Recebimento em' : 'Vencimento', right: `<button class="gb tint" data-act="closeOv" aria-label="OK">${ic('check')}</button>`,
            body: `<div class="msel" style="padding:0">${gbtn('chevron-left', 'data-act="dpMonth" data-d="-1"', 'Mês anterior')}<span class="mlabel">${cap(MONTHS[m])} de ${y}</span>${gbtn('chevron-right', 'data-act="dpMonth" data-d="1"', 'Próximo mês')}</div>
                <div class="card">${calendar(y, m, {sel: selDay, act: 'dpDay'})}</div>`});
    }
    ACT.dpMonth = a => { const d = new Date(state.dp.y, state.dp.m + +a.dataset.d, 1); state.dp = {y: d.getFullYear(), m: d.getMonth()}; dateSheet(); };
    ACT.dpDay = a => { state.draft.date = iso(new Date(state.dp.y, state.dp.m, +a.dataset.d)); closeOv(); refresh(); };
    // teclado numérico
    ACT.keypad = () => {
        const d = state.draft;
        E.openOv(`<div class="scrim clear" data-act="keyOk"></div><div class="sheet" style="left:0;right:0;bottom:0;border-radius:0;background:var(--kbd)"><div class="kpad-wrap" style="background:none">
            <div class="kpad-bar"><span class="num disp" id="kpv" style="font-size:22px;font-weight:600">${fmt(d.value / 100)}</span><button class="link" data-act="keyOk" style="font-size:17px">OK</button></div>
            <div class="kpad">${[['1', ''], ['2', 'ABC'], ['3', 'DEF'], ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'], ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'], ['00', ''], ['0', ''], ['del', '']].map(([k, l]) => `<button class="${k === 'del' ? 'fn' : ''}" data-act="key" data-k="${k}" aria-label="${k === 'del' ? 'Apagar' : k}">${k === 'del' ? ic('delete') : k}${l ? `<small>${l}</small>` : ''}</button>`).join('')}</div></div></div>`);
        const av = $('#amtv'); if (av) av.insertAdjacentHTML('afterend', '');
    };
    ACT.key = a => pressKey(a.dataset.k);
    function pressKey(k) {
        const d = state.draft;
        let v = d.value;
        if (k === 'del') v = Math.floor(v / 10); else if (k === '00') v = v * 100; else v = v * 10 + +k;
        if (v > 9999999999) return;
        d.value = v;
        const kp = $('#kpv'), av = $('#amtv');
        if (kp) kp.textContent = fmt(v / 100);
        if (av) { av.textContent = fmt(v / 100); av.classList.toggle('zero', !v); }
    }
    ACT.keyOk = () => { closeOv(); if (state.draft.errors.value && state.draft.value) delete state.draft.errors.value; refresh(); };
    E.onKey = e => {
        if ($('#kpv') && state.draft) {
            if (/^[0-9]$/.test(e.key)) { pressKey(e.key); e.preventDefault(); return true; }
            if (e.key === 'Backspace') { pressKey('del'); e.preventDefault(); return true; }
            if (e.key === 'Enter') { ACT.keyOk(); e.preventDefault(); return true; }
        }
        return false;
    };
    // categoria
    function catSheet(title, current, filter = false) {
        const d = state.draft, R = state.pickFor === 'draft' && d && d.type === 'R';
        const keys = Object.keys(D.categories).filter(k => state.pickFor === 'filter' || state.pickFor === 'batch' ? true : state.pickFor === 'limit' ? !D.categories[k].income : R ? D.categories[k].income : !D.categories[k].income);
        sheet({title, body: `<label class="search in-pad">${ic('search')}<input id="catq" placeholder="Buscar categoria" autocomplete="off"></label><div class="pick" id="catpick">${keys.map(k => { const c = D.categories[k]; return `<button class="${current === k ? 'on' : ''}" data-act="catSet" data-k="${k}" data-n="${esc(norm(c.name))}">${catAv(c)}${esc(c.name)}</button>`; }).join('')}
            ${filter ? '' : `<button data-act="catNew">${catAv({icon: 'plus', color: '#64748B'})}Nova</button>`}</div>`,
            foot: filter && current ? '<button class="btn gray" data-act="catSet" data-k="">Limpar filtro</button>' : ''});
    }
    E.catSheet = catSheet;
    ACT.catPick = () => { state.pickFor = 'draft'; catSheet('Categoria', state.draft.cat); };
    ACT.catSet = a => {
        const k = a.dataset.k || null;
        closeOv();
        if (state.pickFor === 'draft') { state.draft.cat = k; refresh(); }
        else if (state.pickFor === 'filter') { state.f.cat = k; refresh(); }
        else if (state.pickFor === 'batch') { const n = state.sel.size; [...state.sel].forEach(id => { findTx(id).cat = k; }); state.sel = null; refresh(); toast(`Categoria alterada em ${plural(n, 'lançamento', 'lançamentos')}`, {icon: 'tag'}); }
        else if (state.pickFor === 'limit') { setTimeout(() => ACT.limitSheet({dataset: {cat: k}}), 380); }
    };
    ACT.catNew = () => sheet({title: 'Nova categoria', right: `<button class="gb tint" data-act="catCreate" aria-label="Criar">${ic('check')}</button>`,
        body: `<div class="grp"><label class="frow"><span class="k">Nome</span><input id="cn" placeholder="Ex.: Viagens"></label></div>
            <div class="fld"><span class="lab">Ícone e cor</span><div class="chips wrap">${['plane', 'coffee', 'gift', 'dumbbell', 'wrench', 'baby', 'shirt', 'popcorn'].map((i, k) => `<button class="chip ${k === 0 ? 'on' : ''}" data-act="chipOne" aria-label="${i}" style="width:44px;padding:0;justify-content:center">${ic(i)}</button>`).join('')}</div></div>
            <p class="foot-note" style="padding:0 4px">Também dá para usar a marca com logo (Netflix, Spotify…) ou um logo seu em Mais › Categorias.</p>`});
    ACT.catCreate = () => {
        const name = (($('#cn') || {}).value || 'Viagens').trim() || 'Viagens';
        const k = 'c' + state.nextId++;
        D.categories[k] = {name, icon: 'plane', color: '#0EA5E9', systemDefault: false};
        closeOv();
        if (state.pickFor === 'draft' && state.draft) state.draft.cat = k;
        refresh(); toast(`Categoria “${esc(name)}” criada`, {icon: 'tag'});
    };
    // contato
    ACT.contactPick = () => {
        const R = state.draft.type === 'R';
        sheet({title: R ? 'Recebido de' : 'Pago a', flush: true, body: `<div style="padding:0 16px"><label class="search in-pad">${ic('search')}<input id="cq" placeholder="Buscar ou criar contato" autocomplete="off"></label></div>
            <div class="sec"><div class="grp av-rows" id="clist">${D.contacts.map(c => `<button class="row" data-act="contactSet" data-n="${esc(c.name)}"><span class="av solid sm" style="--c:${CONTACT_COLOR[c.category]}">${initials(c.name)}</span><span class="rt"><span class="t">${esc(c.name)}</span><span class="s">${CONTACT_CAT[c.category]}</span></span>${state.draft.contact === c.name ? ic('check', 'ck') : ''}</button>`).join('')}</div>
            <button class="btn block tinted" data-act="contactSet" data-new="1">${ic('user-plus')}Criar contato com o nome digitado</button></div>`});
    };
    ACT.contactSet = a => { const name = a.dataset.new ? (($('#cq') || {}).value || '').trim() || 'Novo contato' : a.dataset.n; state.draft.contact = name; closeOv(); refresh(); if (a.dataset.new) toast(`Contato “${esc(name)}” criado`, {icon: 'user-plus'}); };
    // conta, pagamento, centro de custo
    ACT.acctPick = () => sheet({title: 'Conta', body: `<div class="grp av-rows">${company().accounts.map(a => { const ok = a.mode === 'MANUAL'; return `<button class="row ${ok ? '' : 'dim'}" ${ok ? `data-act="acctSet" data-v="${a.id}"` : 'disabled'}>${acctAv(a, 'sm')}<span class="rt"><span class="t">${esc(a.name)}</span><span class="s">${ok ? `${a.currency} · ${money(acctBalance(a))}` : a.mode === 'BANK' ? 'Do banco: não aceita lançamentos' : 'Congelada: só consulta'}</span></span>${state.draft.account === a.id ? ic('check', 'ck') : ''}</button>`; }).join('')}</div>`});
    ACT.acctSet = a => { state.draft.account = a.dataset.v; closeOv(); refresh(); };
    ACT.payPick = () => sheet({title: 'Forma de pagamento', body: `<div class="grp ic-rows">${Object.entries(PAY).map(([k, l]) => `<button class="row" data-act="paySet" data-v="${k}">${si(PAY_ICON[k], '#1D4E89')}<span class="rt"><span class="t">${l}</span></span>${state.draft.pay === k ? ic('check', 'ck') : ''}</button>`).join('')}</div>`});
    ACT.paySet = a => { state.draft.pay = a.dataset.v; closeOv(); refresh(); };
    ACT.ccPick = () => sheet({title: 'Centro de custo', body: `<div class="grp av-rows">${Object.entries(D.costCenters).map(([k, c]) => `<button class="row" data-act="ccSet" data-v="${k}">${catAv(c, 'sm')}<span class="rt"><span class="t">${c.name}</span><span class="s">${c.description}</span></span>${state.draft.cc === k ? ic('check', 'ck') : ''}</button>`).join('')}<button class="row" data-act="ccSet" data-v=""><span class="av sm" style="--c:#64748B">${ic('circle-minus')}</span><span class="rt"><span class="t">Sem centro de custo</span></span>${!state.draft.cc ? ic('check', 'ck') : ''}</button></div>`});
    ACT.ccSet = a => { state.draft.cc = a.dataset.v || null; closeOv(); refresh(); };
    // salvar
    ACT.saveDraft = () => {
        const d = state.draft, errs = {};
        if (!d.organize && !d.value) errs.value = 'Informe o valor';
        if (!d.desc.trim()) errs.desc = 'Informe uma descrição';
        if (Object.keys(errs).length) { d.errors = errs; refresh(); toast('Confira os campos em vermelho', {icon: 'circle-alert'}); return; }
        if (d.organize) {
            const t = findTx(d.id);
            Object.assign(t, {desc: d.desc.trim(), cat: d.cat, contact: d.contact, cc: d.cc, notes: d.notes});
            state.draft = null; back(); setTimeout(() => toast('Lançamento organizado', {icon: 'tags'}), 420); return;
        }
        const fields = {desc: d.desc.trim(), type: d.type, cat: d.cat || (d.type === 'R' ? 'servicos' : 'compras'), contact: d.contact, pay: d.pay, mode: d.mode, rec: d.rec, cc: d.cc, doc: d.doc, notes: d.notes, files: d.files.length, acct: d.account,
            ends: d.mode === 'REPEATABLE' && d.endKind === 'date' ? d.endDate : undefined};
        const finish = msg => {
            const dt = parse(d.date);
            state.draft = null;
            if (state.stack.length > 1 && state.stack[state.stack.length - 2].id === 'tx') state.month = {y: dt.getFullYear(), m: dt.getMonth()};
            back();
            setTimeout(() => toast(msg, {icon: 'circle-check'}), 420);
        };
        if (d.id) {
            const t = findTx(d.id);
            const apply = () => { const wasPaid = t.paid; if (wasPaid) setPaid(t, false); Object.assign(t, fields, {value: d.value / 100, date: d.date}); if (d.paid) setPaid(t, true); };
            if (isSeries(t)) {
                const rec = t.mode === 'REPEATABLE';
                actionSheet({title: 'Salvar alterações', text: rec ? 'Este lançamento se repete.' : `Parcela ${t.plot}.`, items: [
                    {label: rec ? 'Só neste' : 'Só nesta parcela', fn: () => { apply(); finish('Lançamento atualizado'); }},
                    {label: rec ? 'Neste e nos próximos' : 'Nesta e nas próximas', fn: () => { apply(); finish('Este e os próximos atualizados'); }},
                    {label: rec ? 'Em todos da série' : 'Em todas as parcelas', fn: () => { apply(); finish('Série atualizada'); }}]});
                return;
            }
            apply(); finish('Lançamento atualizado');
        } else if (d.mode === 'MANY_TIMES') {
            const totalC = d.totalMode === 'total' ? d.value : d.value * d.n, parts = splitInstallments(totalC, d.n);
            parts.forEach((v, i) => {
                const t = {...fields, id: state.nextId++, value: v / 100, date: addMonths(d.date, Math.round(i * REC_STEP[d.rec])), plot: `${i + 1}/${d.n}`, paid: false, base: false};
                state.tx.push(t);
                if (i === 0 && d.paid) setPaid(t, true);
            });
            finish(`${d.n} parcelas lançadas`);
        } else {
            const t = {...fields, id: state.nextId++, value: d.value / 100, date: d.date, paid: false, base: false};
            state.tx.push(t);
            if (d.paid) setPaid(t, true);
            finish('Lançamento salvo');
        }
    };

    // entradas de texto
    const app = $('#app');
    app.addEventListener('input', e => {
        const t = e.target;
        if (t.dataset.bind && state.draft) {
            state.draft[t.dataset.bind] = t.value;
            if (t.dataset.bind === 'desc' && state.draft.errors.desc && t.value.trim()) { delete state.draft.errors.desc; const r = t.closest('.frow'); r.classList.remove('err'); $('.k', r).textContent = 'Descrição'; }
        }
        if (t.hasAttribute('data-q')) { state.f.q = t.value; refresh({focus: '#q'}); }
        if (t.id === 'cq') { const q = norm(t.value); [...document.querySelectorAll('#clist .row')].forEach(li => { li.hidden = !norm(li.dataset.n).includes(q); }); }
        if (t.id === 'catq') { const q = norm(t.value); [...document.querySelectorAll('#catpick button[data-n]')].forEach(b => { b.hidden = !b.dataset.n.includes(q); }); }
    });
})();
