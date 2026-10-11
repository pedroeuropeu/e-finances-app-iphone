/* Dados de exemplo do protótipo (outubro de 2026, empresa "Casa" · conta "Conta corrente").
   Os mesmos do protótipo Android, com o que a web ganhou depois: contas do banco integradas às manuais (conectada e
   congelada), categorias de assinatura com a marca, exclusão com Desfazer e exclusão de conta.
   Os nomes dos campos e enums seguem os DTOs da API do e-Finances. Os ícones são nomes do Lucide (no app: SF Symbols). */
window.EF_DATA = (() => {

    const user = {first: 'Pedro', last: 'Europeu', email: 'pedro@exemplo.com', plan: 'Premium', initials: 'PE'};

    /** Bancos conectados (Open Finance). Cada conta do banco vira uma conta do e-Finances (accountId). */
    const banks = [
        {id: 'nu', name: 'Nubank', short: 'Nu', color: '#820AD1', company: 1, status: 'UPDATED', updated: 'há 2 h', next: 'hoje, 21:00', accounts: [
            {id: 'nu-cc', kind: 'BANK', name: 'Conta', balance: 3214.55},
            {id: 'nu-cr', kind: 'CREDIT', name: 'Cartão Ultravioleta', invoice: 2148.90, limit: 8000, available: 5851.10, due: '15/10'}
        ]},
        {id: 'in', name: 'Inter', short: 'in', color: '#FF7A00', company: 1, status: 'UPDATED', updated: 'há 40 min', next: 'hoje, 22:30', accounts: [
            {id: 'in-cc', kind: 'BANK', name: 'Conta digital', balance: 1045.00}
        ]},
        {id: 'it', name: 'Itaú', short: 'it', color: '#EC7000', company: 2, status: 'LOGIN_ERROR', updated: 'há 6 dias', next: '', accounts: [
            {id: 'it-cc', kind: 'BANK', name: 'Conta corrente', balance: 6880.20},
            {id: 'it-cr', kind: 'CREDIT', name: 'Itaú Click Visa', invoice: 1312.44, limit: 6000, available: 4687.56, due: '20/10'}
        ]}
    ];

    /** Empresas e contas (seletor do topo, /api/workspace). mode: MANUAL | BANK (conectada) | FROZEN (banco desconectado, só consulta). */
    const companies = [
        {id: 1, name: 'Casa', type: 'FAMILY', typeLabel: 'Familiar', color: '#4338CA', accounts: [
            {id: 'cc', name: 'Conta corrente', mode: 'MANUAL', currency: 'BRL', balance: 8432.17, defaultAccount: true, transactions: 25},
            {id: 'res', name: 'Reserva de emergência', mode: 'MANUAL', currency: 'BRL', balance: 21500.00, transactions: 2},
            {id: 'nu-cc', name: 'Nubank · Conta', mode: 'BANK', bank: 'nu', currency: 'BRL', balance: 3214.55, transactions: 6},
            {id: 'nu-cr', name: 'Nubank · Cartão Ultravioleta', mode: 'BANK', bank: 'nu', kind: 'CREDIT', currency: 'BRL', balance: -2148.90, transactions: 9},
            {id: 'in-cc', name: 'Inter · Conta digital', mode: 'BANK', bank: 'in', currency: 'BRL', balance: 1045.00, transactions: 3},
            {id: 'it-old', name: 'Itaú · Poupança', mode: 'FROZEN', bankName: 'Itaú', bankColor: '#EC7000', bankShort: 'it', currency: 'BRL', balance: 412.30, transactions: 14, frozenSince: '02/08/2026'}
        ]},
        {id: 2, name: 'Ateliê Aurora', type: 'BUSINESS', typeLabel: 'Empresa', color: '#0E7490', accounts: [
            {id: 'pj', name: 'Conta PJ', mode: 'MANUAL', currency: 'BRL', balance: 12880.35, defaultAccount: true, transactions: 5},
            {id: 'cx', name: 'Caixa da loja', mode: 'MANUAL', currency: 'BRL', balance: 4210.90, transactions: 0},
            {id: 'it-cc', name: 'Itaú · Conta corrente', mode: 'BANK', bank: 'it', currency: 'BRL', balance: 6880.20, transactions: 0},
            {id: 'it-cr', name: 'Itaú · Click Visa', mode: 'BANK', bank: 'it', kind: 'CREDIT', currency: 'BRL', balance: -1312.44, transactions: 0}
        ]}
    ];

    /** Categorias (TransactionCategory). systemDefault = padrão do sistema (só muda o limite).
        sub = categoria de assinatura; brand = marca com logo (catálogo de marcas da web). */
    const categories = {
        moradia:     {name: 'Moradia', icon: 'house', color: '#6366F1', systemDefault: true},
        contas:      {name: 'Contas de consumo', icon: 'zap', color: '#CA8A04', systemDefault: true},
        alimentacao: {name: 'Alimentação', icon: 'utensils', color: '#EA580C', systemDefault: true},
        transporte:  {name: 'Transporte', icon: 'car', color: '#0284C7', systemDefault: true},
        saude:       {name: 'Saúde', icon: 'heart', color: '#DB2777', systemDefault: true},
        educacao:    {name: 'Educação', icon: 'graduation-cap', color: '#7C3AED', systemDefault: true},
        lazer:       {name: 'Lazer', icon: 'party-popper', color: '#F97316', systemDefault: true},
        compras:     {name: 'Compras', icon: 'shopping-bag', color: '#0D9488', systemDefault: true},
        impostos:    {name: 'Impostos e taxas', icon: 'landmark', color: '#64748B', systemDefault: true},
        salario:     {name: 'Salário', icon: 'banknote', color: '#059669', systemDefault: true, income: true},
        servicos:    {name: 'Serviços prestados', icon: 'briefcase', color: '#16A34A', systemDefault: false, income: true},
        alugueis:    {name: 'Aluguéis', icon: 'building', color: '#0F766E', systemDefault: false, income: true},
        pets:        {name: 'Pets', icon: 'dog', color: '#B45309', systemDefault: false},
        netflix:     {name: 'Netflix', icon: 'tv', color: '#E50914', systemDefault: false, sub: true, brand: {short: 'N', color: '#E50914'}},
        spotify:     {name: 'Spotify', icon: 'music', color: '#1DB954', systemDefault: false, sub: true, brand: {short: 'S', color: '#1DB954'}},
        smartfit:    {name: 'Smart Fit', icon: 'dumbbell', color: '#F5B800', systemDefault: false, sub: true, brand: {short: 'SF', color: '#F5B800', fg: '#1A1A1A'}},
        youtube:     {name: 'YouTube Premium', icon: 'play', color: '#FF0033', systemDefault: false, sub: true, brand: {short: 'YT', color: '#FF0033'}},
        prime:       {name: 'Amazon Prime', icon: 'shopping-bag', color: '#00A8E1', systemDefault: false, sub: true, brand: {short: 'a', color: '#00A8E1'}},
        disney:      {name: 'Disney+', icon: 'sparkles', color: '#113CCF', systemDefault: false, sub: true, brand: {short: 'D+', color: '#113CCF'}}
    };

    /** Centros de custo (CostCenter). */
    const costCenters = {
        casa:     {name: 'Casa', description: 'Despesas do apartamento', icon: 'house', color: '#4338CA', monthlyBudget: 5000},
        carro:    {name: 'Carro', description: 'Combustível, IPVA e manutenção', icon: 'car', color: '#0284C7', monthlyBudget: 900},
        filhos:   {name: 'Filhos', description: 'Escola, saúde e atividades', icon: 'baby', color: '#7C3AED', monthlyBudget: 2200},
        trabalho: {name: 'Trabalho', description: 'Ferramentas e equipamentos', icon: 'briefcase', color: '#059669', monthlyBudget: 700}
    };

    /** Contatos (Contact). category: CLIENT | SUPPLIER | WORKER. */
    const contacts = [
        {name: 'Acme Tecnologia', category: 'CLIENT', phone: '(11) 3000-1200', email: 'rh@acme.com.br'},
        {name: 'Bistrô Central', category: 'CLIENT', phone: '(11) 98877-1020', email: 'contato@bistrocentral.com.br'},
        {name: 'Marina Costa', category: 'CLIENT', phone: '(11) 99123-4455', email: 'marina.costa@email.com'},
        {name: 'Imobiliária Lar', category: 'SUPPLIER', phone: '(11) 3222-8000', email: 'financeiro@imoblar.com.br'},
        {name: 'Cond. Jardim das Flores', category: 'SUPPLIER', phone: '(11) 3333-1010', email: 'sindico@jdflores.com.br'},
        {name: 'Colégio Horizonte', category: 'SUPPLIER', phone: '(11) 3456-7890', email: 'secretaria@horizonte.edu.br'},
        {name: 'Unimed', category: 'SUPPLIER', phone: '0800 000 0000', email: ''},
        {name: 'Enel', category: 'SUPPLIER', phone: '0800 72 72 196', email: ''},
        {name: 'Vivo', category: 'SUPPLIER', phone: '*8486', email: ''},
        {name: 'Magazine Luiza', category: 'SUPPLIER', phone: '', email: ''},
        {name: 'Joana Lima', category: 'WORKER', phone: '(11) 97654-3210', email: 'joana.lima@email.com'}
    ];

    /* Lançamentos. type: R = RECEBIMENTO, F = DESPESAS_FIXAS, V = DESPESAS_VARIAVEIS.
       acct = conta do e-Finances (sem acct = "cc"); src: BANK = veio do banco (só organizar).
       pay = paymentType, mode = paymentMode (ONE_TIME | MANY_TIMES | REPEATABLE), plot = parcela "n/N". */
    const tx = [
        {id: 1, desc: 'Salário de outubro', type: 'R', value: 9800.00, date: '2026-10-05', paid: true, cat: 'salario', contact: 'Acme Tecnologia', pay: 'TED', mode: 'REPEATABLE', rec: 'MONTHLY', cc: 'trabalho'},
        {id: 2, desc: 'Projeto site do bistrô (2ª parte)', type: 'R', value: 2400.00, date: '2026-10-15', paid: false, cat: 'servicos', contact: 'Bistrô Central', pay: 'TED', mode: 'ONE_TIME', doc: 'NF 0193', cc: 'trabalho'},
        {id: 3, desc: 'Aluguel da sala comercial', type: 'R', value: 1350.00, date: '2026-10-20', paid: false, cat: 'alugueis', contact: 'Marina Costa', pay: 'TED', mode: 'REPEATABLE', rec: 'MONTHLY'},
        {id: 4, desc: 'Aluguel do apartamento', type: 'F', value: 2300.00, date: '2026-10-05', paid: true, cat: 'moradia', contact: 'Imobiliária Lar', pay: 'BOLETO_BANCARIO', mode: 'REPEATABLE', rec: 'MONTHLY', cc: 'casa', doc: '34191.79001 01043', files: 1},
        {id: 5, desc: 'Condomínio', type: 'F', value: 680.00, date: '2026-10-07', paid: false, cat: 'moradia', contact: 'Cond. Jardim das Flores', pay: 'BOLETO_BANCARIO', mode: 'REPEATABLE', rec: 'MONTHLY', cc: 'casa'},
        {id: 6, desc: 'Energia elétrica', type: 'F', value: 248.37, date: '2026-10-10', paid: false, cat: 'contas', contact: 'Enel', pay: 'DEBITO_AUTOMATICO', mode: 'REPEATABLE', rec: 'MONTHLY', cc: 'casa'},
        {id: 7, desc: 'Internet fibra', type: 'F', value: 129.90, date: '2026-10-12', paid: false, cat: 'contas', contact: 'Vivo', pay: 'DEBITO_AUTOMATICO', mode: 'REPEATABLE', rec: 'MONTHLY', cc: 'casa'},
        {id: 8, desc: 'Plano de saúde', type: 'F', value: 890.00, date: '2026-10-15', paid: false, cat: 'saude', contact: 'Unimed', pay: 'BOLETO_BANCARIO', mode: 'REPEATABLE', rec: 'MONTHLY', cc: 'filhos'},
        {id: 9, desc: 'Mensalidade escolar', type: 'F', value: 1450.00, date: '2026-10-20', paid: false, cat: 'educacao', contact: 'Colégio Horizonte', pay: 'BOLETO_BANCARIO', mode: 'REPEATABLE', rec: 'MONTHLY', cc: 'filhos', ends: 'dez/2026'},
        {id: 10, desc: 'Netflix', type: 'F', value: 55.90, date: '2026-10-03', paid: true, cat: 'netflix', contact: 'Netflix', pay: 'CARTAO_CREDITO', mode: 'REPEATABLE', rec: 'MONTHLY'},
        {id: 11, desc: 'Spotify Família', type: 'F', value: 34.90, date: '2026-10-03', paid: true, cat: 'spotify', contact: 'Spotify', pay: 'CARTAO_CREDITO', mode: 'REPEATABLE', rec: 'MONTHLY'},
        {id: 12, desc: 'Smart Fit', type: 'F', value: 129.90, date: '2026-10-08', paid: true, cat: 'smartfit', contact: 'Smart Fit', pay: 'CARTAO_CREDITO', mode: 'REPEATABLE', rec: 'MONTHLY'},
        {id: 13, desc: 'Supermercado', type: 'V', value: 487.32, date: '2026-10-02', paid: true, cat: 'alimentacao', contact: 'Pão de Açúcar', pay: 'CARTAO_DEBITO', mode: 'ONE_TIME', cc: 'casa', files: 1},
        {id: 14, desc: 'Combustível', type: 'V', value: 250.00, date: '2026-10-04', paid: true, cat: 'transporte', contact: 'Posto Shell', pay: 'CARTAO_CREDITO', mode: 'ONE_TIME', cc: 'carro'},
        {id: 15, desc: 'iFood', type: 'V', value: 89.90, date: '2026-10-06', paid: true, cat: 'alimentacao', contact: 'iFood', pay: 'CARTAO_CREDITO', mode: 'ONE_TIME'},
        {id: 16, desc: 'Farmácia', type: 'V', value: 73.45, date: '2026-10-07', paid: true, cat: 'saude', contact: 'Drogasil', pay: 'CARTAO_DEBITO', mode: 'ONE_TIME', cc: 'filhos'},
        {id: 17, desc: 'Uber', type: 'V', value: 32.80, date: '2026-10-08', paid: true, cat: 'transporte', contact: 'Uber', pay: 'CARTAO_CREDITO', mode: 'ONE_TIME'},
        {id: 18, desc: 'Padaria', type: 'V', value: 18.50, date: '2026-10-09', paid: true, cat: 'alimentacao', contact: 'Padaria Real', pay: 'DINHEIRO', mode: 'ONE_TIME'},
        {id: 19, desc: 'Notebook Dell', type: 'V', value: 412.90, date: '2026-10-01', paid: true, cat: 'compras', contact: 'Dell', pay: 'CARTAO_CREDITO', mode: 'MANY_TIMES', rec: 'MONTHLY', plot: '3/10', cc: 'trabalho'},
        {id: 20, desc: 'Geladeira Brastemp', type: 'V', value: 349.00, date: '2026-10-10', paid: false, cat: 'compras', contact: 'Magazine Luiza', pay: 'BOLETO_BANCARIO', mode: 'MANY_TIMES', rec: 'MONTHLY', plot: '5/12', cc: 'casa'},
        {id: 21, desc: 'Jantar de aniversário', type: 'V', value: 210.00, date: '2026-10-05', paid: true, cat: 'lazer', contact: 'Restaurante Mar Azul', pay: 'CARTAO_CREDITO', mode: 'ONE_TIME', notes: 'Aniversário da Ana, 6 pessoas.'},
        {id: 22, desc: 'IPVA 2026', type: 'V', value: 520.00, date: '2026-10-28', paid: false, cat: 'impostos', contact: 'Sefaz-SP', pay: 'BOLETO_BANCARIO', mode: 'MANY_TIMES', rec: 'MONTHLY', plot: '3/3', cc: 'carro'},
        {id: 23, desc: 'Diarista', type: 'F', value: 600.00, date: '2026-10-30', paid: false, cat: 'moradia', contact: 'Joana Lima', pay: 'TED', mode: 'REPEATABLE', rec: 'MONTHLY', cc: 'casa'},
        {id: 24, desc: 'YouTube Premium', type: 'F', value: 26.90, date: '2026-10-17', paid: false, cat: 'youtube', contact: 'Google', pay: 'CARTAO_CREDITO', mode: 'REPEATABLE', rec: 'MONTHLY'},
        {id: 25, desc: 'Ração e banho', type: 'V', value: 164.00, date: '2026-10-11', paid: false, cat: 'pets', contact: 'Pet Shop Amigo', pay: 'CARTAO_DEBITO', mode: 'ONE_TIME'},

        // Reserva de emergência (manual)
        {id: 40, acct: 'res', desc: 'Aporte mensal', type: 'R', value: 1500.00, date: '2026-10-06', paid: true, cat: 'salario', pay: 'TED', mode: 'REPEATABLE', rec: 'MONTHLY'},
        {id: 41, acct: 'res', desc: 'Rendimento CDB', type: 'R', value: 182.40, date: '2026-10-31', paid: false, cat: 'servicos', pay: 'TED', mode: 'ONE_TIME'},

        // Nubank · Conta (veio do banco: só organizar)
        {id: 60, acct: 'nu-cc', src: 'BANK', desc: 'Pix recebido · Marina Costa', type: 'R', value: 1350.00, date: '2026-10-08', paid: true, cat: 'alugueis', contact: 'Marina Costa', pay: 'TED', mode: 'ONE_TIME'},
        {id: 61, acct: 'nu-cc', src: 'BANK', desc: 'Pix enviado · Imobiliária Lar', type: 'F', value: 2300.00, date: '2026-10-05', paid: true, cat: 'moradia', contact: 'Imobiliária Lar', pay: 'TED', mode: 'ONE_TIME'},
        {id: 62, acct: 'nu-cc', src: 'BANK', desc: 'TED recebida · Acme Tecnologia', type: 'R', value: 9800.00, date: '2026-10-05', paid: true, cat: 'salario', contact: 'Acme Tecnologia', pay: 'TED', mode: 'ONE_TIME'},
        {id: 63, acct: 'nu-cc', src: 'BANK', desc: 'Pagamento de fatura', type: 'F', value: 1980.12, date: '2026-10-09', paid: true, cat: null, pay: 'TED', mode: 'ONE_TIME'},
        {id: 64, acct: 'nu-cc', src: 'BANK', desc: 'Pix enviado · Joana Lima', type: 'F', value: 150.00, date: '2026-10-03', paid: true, cat: 'moradia', contact: 'Joana Lima', pay: 'TED', mode: 'ONE_TIME'},
        {id: 65, acct: 'nu-cc', src: 'BANK', desc: 'Débito automático · Enel', type: 'F', value: 231.80, date: '2026-10-01', paid: true, cat: 'contas', contact: 'Enel', pay: 'DEBITO_AUTOMATICO', mode: 'ONE_TIME'},

        // Nubank · Cartão (veio do banco)
        {id: 70, acct: 'nu-cr', src: 'BANK', desc: 'iFood *Restaurante', type: 'V', value: 89.90, date: '2026-10-06', paid: true, cat: 'alimentacao', contact: 'iFood', pay: 'CARTAO_CREDITO', mode: 'ONE_TIME'},
        {id: 71, acct: 'nu-cr', src: 'BANK', desc: 'Uber *Trip', type: 'V', value: 32.80, date: '2026-10-08', paid: true, cat: 'transporte', contact: 'Uber', pay: 'CARTAO_CREDITO', mode: 'ONE_TIME'},
        {id: 72, acct: 'nu-cr', src: 'BANK', desc: 'Netflix.com', type: 'F', value: 55.90, date: '2026-10-03', paid: true, cat: 'netflix', pay: 'CARTAO_CREDITO', mode: 'ONE_TIME'},
        {id: 73, acct: 'nu-cr', src: 'BANK', desc: 'Spotify', type: 'F', value: 34.90, date: '2026-10-03', paid: true, cat: 'spotify', pay: 'CARTAO_CREDITO', mode: 'ONE_TIME'},
        {id: 74, acct: 'nu-cr', src: 'BANK', desc: 'Amazon Prime', type: 'F', value: 19.90, date: '2026-10-02', paid: true, cat: 'prime', pay: 'CARTAO_CREDITO', mode: 'ONE_TIME'},
        {id: 75, acct: 'nu-cr', src: 'BANK', desc: 'Apple.com/bill', type: 'V', value: 541.58, date: '2026-10-01', paid: true, cat: 'compras', pay: 'CARTAO_CREDITO', mode: 'ONE_TIME', plot: '9/12'},
        {id: 76, acct: 'nu-cr', src: 'BANK', desc: 'Posto Shell', type: 'V', value: 250.00, date: '2026-10-04', paid: true, cat: 'transporte', pay: 'CARTAO_CREDITO', mode: 'ONE_TIME'},
        {id: 77, acct: 'nu-cr', src: 'BANK', desc: 'Restaurante Mar Azul', type: 'V', value: 210.00, date: '2026-10-05', paid: true, cat: 'lazer', pay: 'CARTAO_CREDITO', mode: 'ONE_TIME'},
        {id: 78, acct: 'nu-cr', src: 'BANK', desc: 'Drogasil', type: 'V', value: 73.45, date: '2026-10-07', paid: true, cat: null, pay: 'CARTAO_CREDITO', mode: 'ONE_TIME'},

        // Inter · Conta digital (veio do banco)
        {id: 80, acct: 'in-cc', src: 'BANK', desc: 'Pix recebido · Bistrô Central', type: 'R', value: 1200.00, date: '2026-10-02', paid: true, cat: 'servicos', contact: 'Bistrô Central', pay: 'TED', mode: 'ONE_TIME'},
        {id: 81, acct: 'in-cc', src: 'BANK', desc: 'Cashback', type: 'R', value: 12.40, date: '2026-10-04', paid: true, cat: null, pay: 'TED', mode: 'ONE_TIME'},
        {id: 82, acct: 'in-cc', src: 'BANK', desc: 'Pix enviado · Colégio Horizonte', type: 'F', value: 300.00, date: '2026-10-07', paid: true, cat: 'educacao', contact: 'Colégio Horizonte', pay: 'TED', mode: 'ONE_TIME'},

        // Itaú · Poupança (congelada: banco desconectado, só consulta)
        {id: 90, acct: 'it-old', src: 'BANK', desc: 'Rendimento poupança', type: 'R', value: 2.31, date: '2026-07-28', paid: true, cat: null, pay: 'TED', mode: 'ONE_TIME'},
        {id: 91, acct: 'it-old', src: 'BANK', desc: 'Transferência para conta corrente', type: 'F', value: 600.00, date: '2026-07-15', paid: true, cat: null, pay: 'TED', mode: 'ONE_TIME'},

        // Ateliê Aurora · Conta PJ (manual)
        {id: 100, acct: 'pj', desc: 'Venda de peças · feira', type: 'R', value: 3480.00, date: '2026-10-04', paid: true, cat: 'servicos', pay: 'TED', mode: 'ONE_TIME'},
        {id: 101, acct: 'pj', desc: 'Encomenda Bistrô Central', type: 'R', value: 1900.00, date: '2026-10-18', paid: false, cat: 'servicos', contact: 'Bistrô Central', pay: 'BOLETO_BANCARIO', mode: 'ONE_TIME'},
        {id: 102, acct: 'pj', desc: 'Aluguel do ateliê', type: 'F', value: 1800.00, date: '2026-10-10', paid: false, cat: 'moradia', pay: 'BOLETO_BANCARIO', mode: 'REPEATABLE', rec: 'MONTHLY'},
        {id: 103, acct: 'pj', desc: 'Argila e esmaltes', type: 'V', value: 642.70, date: '2026-10-06', paid: true, cat: 'compras', pay: 'CARTAO_CREDITO', mode: 'ONE_TIME'},
        {id: 104, acct: 'pj', desc: 'DAS do Simples', type: 'F', value: 212.40, date: '2026-10-20', paid: false, cat: 'impostos', pay: 'BOLETO_BANCARIO', mode: 'REPEATABLE', rec: 'MONTHLY'}
    ];

    /** Limites por categoria (/api/limits): valor mensal e % de alerta. */
    const limits = [
        {cat: 'alimentacao', limit: 700, alertPct: 80},
        {cat: 'saude', limit: 1000, alertPct: 80},
        {cat: 'lazer', limit: 180, alertPct: 80},
        {cat: 'contas', limit: 450, alertPct: 90},
        {cat: 'compras', limit: 1000, alertPct: 80},
        {cat: 'transporte', limit: 500, alertPct: 80}
    ];

    /** Parcelamentos (lançamentos em parcelas e os que vêm dos cartões conectados). */
    const installments = [
        {name: 'Notebook Dell', value: 412.90, paid: 3, total: 10, ends: 'jul/2027', source: 'LEDGER', txId: 19},
        {name: 'Geladeira Brastemp', value: 349.00, paid: 4, total: 12, ends: 'mai/2027', source: 'LEDGER', txId: 20},
        {name: 'IPVA 2026', value: 520.00, paid: 2, total: 3, ends: 'out/2026', source: 'LEDGER', txId: 22},
        {name: 'iPhone 17', value: 541.58, paid: 9, total: 12, ends: 'jan/2027', source: 'BANK', origin: 'Nubank · Cartão Ultravioleta'},
        {name: 'Passagens aéreas', value: 287.30, paid: 2, total: 6, ends: 'mar/2027', source: 'BANK', origin: 'Itaú · Click Visa'}
    ];

    /** Assinaturas: lançamentos (manuais ou do banco) nas categorias de assinatura. */
    const subscriptions = [
        {cat: 'netflix', value: 55.90, freq: 'MONTHLY', next: '03/11', origin: 'Nubank · Cartão Ultravioleta'},
        {cat: 'spotify', value: 34.90, freq: 'MONTHLY', next: '03/11', origin: 'Nubank · Cartão Ultravioleta'},
        {cat: 'smartfit', value: 129.90, freq: 'MONTHLY', next: '08/11', origin: 'Lançamento manual', oldValue: 119.90},
        {cat: 'youtube', value: 26.90, freq: 'MONTHLY', next: '17/10', origin: 'Lançamento manual'},
        {cat: 'prime', value: 19.90, freq: 'MONTHLY', next: '02/11', origin: 'Nubank · Cartão Ultravioleta'},
        {cat: 'disney', value: 299.90, freq: 'YEARLY', next: '14/03/2027', origin: 'Itaú · Click Visa'}
    ];
    /** Contas fixas detectadas no banco que não estão numa categoria de assinatura. */
    const otherRecurring = [
        {name: 'Enel', detail: 'Energia · todo dia 1 · Nubank', value: 231.80},
        {name: 'Vivo Fibra', detail: 'Internet · todo dia 12 · Nubank', value: 129.90},
        {name: 'Cond. Jardim das Flores', detail: 'Condomínio · todo dia 7 · Inter', value: 680.00}
    ];

    /** Notificações (/api/notifications). category: LIMIT | PAYMENT | SUPPORT | SECURITY | SYSTEM; severity: INFO | SUCCESS | WARNING | DANGER. */
    const notifications = [
        {id: 1, category: 'LIMIT', severity: 'DANGER', title: 'Lazer passou do limite', body: 'Você gastou R$ 210,00 de R$ 180,00 em outubro.', when: 'Hoje', time: '08:12', unread: true, go: ['plan', {tab: 'limits'}]},
        {id: 2, category: 'SYSTEM', severity: 'WARNING', title: 'Condomínio está atrasado', body: 'Venceu em 07/10 · R$ 680,00 · Cond. Jardim das Flores', when: 'Hoje', time: '07:00', unread: true, go: ['tx_detail', {id: 5}]},
        {id: 3, category: 'SYSTEM', severity: 'INFO', title: 'Fechamento de setembro pronto', body: 'Veja quanto entrou, quanto saiu e o que sobrou.', when: 'Ontem', time: '09:30', unread: true, go: ['story', {}]},
        {id: 4, category: 'SUPPORT', severity: 'SUCCESS', title: 'Seu chamado foi respondido', body: '#482 · Como exporto as transações para o contador?', when: 'Ontem', time: '16:45', unread: false, go: ['help', {}]},
        {id: 5, category: 'LIMIT', severity: 'WARNING', title: 'Saúde chegou a 96% do limite', body: 'Ainda dá para gastar R$ 36,55 este mês.', when: 'Esta semana', time: 'qua, 18:20', unread: false, go: ['plan', {tab: 'limits'}]},
        {id: 6, category: 'SYSTEM', severity: 'INFO', title: 'Smart Fit ficou mais cara', body: 'De R$ 119,90 para R$ 129,90 por mês (+8%).', when: 'Esta semana', time: 'seg, 10:02', unread: false, go: ['plan', {tab: 'subs'}]},
        {id: 7, category: 'SECURITY', severity: 'INFO', title: 'Novo acesso à sua conta', body: 'iPhone · São Paulo, SP. Não foi você? Encerre a sessão.', when: 'Esta semana', time: 'seg, 07:41', unread: false, go: ['security', {}]},
        {id: 8, category: 'PAYMENT', severity: 'SUCCESS', title: 'Pagamento aprovado', body: 'Plano Premium mensal · R$ 29,90. Válido até 12/11/2026.', when: 'Anteriores', time: '12/09', unread: false, go: ['billing', {}]}
    ];

    /** Chamados (/api/ticket). */
    const tickets = [
        {id: 482, subject: 'Como exporto as transações para o contador?', category: 'DUVIDA', status: 'Respondido', tone: 'amber', when: 'ontem',
            messages: [
                {me: true, text: 'Preciso mandar todo mês um arquivo para o meu contador. Como faço?', at: '07/10 14:02'},
                {me: false, text: 'Oi, Pedro! Em Mais › Exportar transações, escolha o período e o formato Excel. O arquivo já sai com o resumo por mês.', at: '08/10 16:45'}
            ]},
        {id: 455, subject: 'Erro ao importar extrato do Banco do Brasil', category: 'PROBLEMA', status: 'Encerrado', tone: 'gray', when: '18/09',
            messages: [
                {me: true, text: 'O extrato de agosto não foi reconhecido.', at: '16/09 10:10'},
                {me: false, text: 'Corrigimos o leitor do modelo do BB. Pode importar de novo.', at: '18/09 09:00'}
            ]}
    ];

    const faq = [
        {q: 'Como lanço uma transação?', a: 'Toque em + no topo do Início ou de Transações, escolha recebimento, despesa fixa ou variável, digite o valor e salve. Categoria, contato e comprovante são opcionais.'},
        {q: 'Como marco um lançamento como pago ou recebido?', a: 'Na lista, toque no círculo ao lado do valor ou deslize o lançamento para a direita. Dá para desfazer pelo aviso que aparece embaixo.'},
        {q: 'Por que não consigo editar um lançamento do banco?', a: 'O que vem do banco conectado é o que aconteceu na conta: valor e data não mudam. Dá para organizar: descrição, categoria, contato, centro de custo e observações.'},
        {q: 'Como troco de empresa ou de conta?', a: 'Toque no nome da empresa no topo do Início. As contas dos bancos conectados aparecem junto com as manuais.'},
        {q: 'Como conecto o meu banco?', a: 'Na aba Contas, toque em +. A conexão é só de leitura e regulada pelo Banco Central (Open Finance).'},
        {q: 'Posso anexar comprovantes às transações?', a: 'Sim. No lançamento, em Comprovantes, escaneie o papel com a câmera, escolha uma foto ou um arquivo PDF.'},
        {q: 'Como exporto minhas transações?', a: 'Em Mais › Exportar transações. Excel com resumo por mês ou CSV.'},
        {q: 'Como excluo minha conta?', a: 'Em Mais › Minha conta › Excluir minha conta. Você tem 30 dias para reativar; depois, os dados são apagados.'}
    ];

    const receiptModels = [
        {name: 'Recibo de aluguel', kind: 'Recebimentos', fields: 7, updated: '02/09/2026'},
        {name: 'Prestação de serviço', kind: 'Recebimentos', fields: 6, updated: '14/08/2026'},
        {name: 'Recibo de pagamento', kind: 'Pagamentos', fields: 5, updated: '30/07/2026'}
    ];

    const invoices = [
        {date: '12/10/2026', desc: 'Premium · mensal', value: 29.90, status: 'Paga'},
        {date: '12/09/2026', desc: 'Premium · mensal', value: 29.90, status: 'Paga'},
        {date: '12/08/2026', desc: 'Premium · mensal', value: 29.90, status: 'Paga'},
        {date: '12/07/2026', desc: 'Basic · mensal', value: 14.90, status: 'Paga'}
    ];

    /** Planos (BASIC, PREMIUN, ENTERPRISE no backend). Preços ilustrativos. */
    const plans = [
        {id: 'BASIC', name: 'Basic', price: 14.90, features: ['Painel e lançamentos', 'Recibos', '1 empresa', '500 MB para comprovantes']},
        {id: 'PREMIUN', name: 'Premium', price: 29.90, features: ['Tudo do Basic', 'Relatórios completos', 'Até 3 empresas', '2 GB para comprovantes']},
        {id: 'ENTERPRISE', name: 'Enterprise', price: 79.90, features: ['Tudo do Premium', 'Até 50 empresas', 'Avisos por SMS', '10 GB para comprovantes']}
    ];

    const sessions = [
        {device: 'Este iPhone', detail: 'iPhone 17 Pro · São Paulo, SP', when: 'agora', current: true, icon: 'smartphone'},
        {device: 'Chrome no macOS', detail: 'efinances.top · São Paulo, SP', when: 'há 2 h', icon: 'laptop'},
        {device: 'Safari no iPad', detail: 'efinances.top · Campinas, SP', when: 'há 5 dias', icon: 'tablet'}
    ];

    const users = [
        {name: 'Pedro Europeu', role: 'Administrador', initials: 'PE', me: true},
        {name: 'Ana Europeu', role: 'Pode ver e lançar', initials: 'AE'}
    ];

    return {user, companies, categories, costCenters, contacts, tx, limits, installments, subscriptions, otherRecurring,
        banks, notifications, tickets, faq, receiptModels, invoices, plans, sessions, users};
})();
