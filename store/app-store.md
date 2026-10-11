# App Store Connect: o que preencher

Tudo o que a App Store Connect pede para publicar o e-Finances (`top.efinances.app`), com o que já está pronto neste
repositório. Os itens marcados com **(você)** dependem de uma decisão, de um dado ou de uma conta sua.

## Antes de começar (você)

- Conta no **Apple Developer Program** (US$ 99/ano). Se for publicar como empresa, a Apple pede o D-U-N-S.
- **Xcode 26** instalado neste Mac (App Store) e `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- `Config/Signing.xcconfig` com o seu Team ID (copie de `Config/Signing.example.xcconfig`; fica fora do git).
- Uma **conta de produção só para a revisão da Apple** (e-mail e senha), com alguns lançamentos, para colocar nas notas
  da revisão. Não use a sua conta pessoal.

## Arquivos

| O quê | Onde |
|---|---|
| App para enviar | Xcode → esquema **EFinances** → Any iOS Device → Product → Archive → Distribute App |
| Ícone 1024 × 1024 (claro, escuro e tingido) | `App/Assets.xcassets/AppIcon.appiconset/` (gerado por `swift scripts/make-icons.swift`) |
| Manifesto de privacidade | `App/PrivacyInfo.xcprivacy` |
| Capturas do iPhone 6,9" (1320 × 2868) **(a fazer)** | no simulador do iPhone 17 Pro Max com o esquema **EFinances Demo** (dados de exemplo): Início, Transações, novo lançamento, Contas, Planejar, Relatórios e o fechamento do mês |

## Informações do app

- **Nome** (até 30): `e-Finances`
- **Subtítulo** (até 30): `Finanças da casa e do negócio`
- **Categoria principal**: Finanças. **Secundária**: Negócios.
- **Idioma principal**: Português (Brasil)
- **Classificação etária**: responder "não"/"nenhum" a todo o questionário (sem violência, conteúdo adulto, jogos de
  azar, compras de itens digitais nem conversa entre usuários; o chamado é só com o suporte) → **4+**.
- **Direitos de conteúdo**: o app não mostra conteúdo de terceiros além dos logos dos bancos (vêm do agregador) e das
  marcas das categorias (Simple Icons, CC0).

## Página do app (versão 1.0)

- **Texto promocional** (até 170, muda sem nova versão):
  `Saiba quanto tem hoje e quanto vai sobrar no fim do mês. Contas, bancos conectados, limites e assinaturas num lugar só.`
- **Palavras-chave** (até 100, separadas por vírgula, sem repetir o nome):
  `finanças,orçamento,contas a pagar,gastos,open finance,mei,controle financeiro,assinaturas,limites,fluxo de caixa`
- **URL de suporte** **(você)**: ex. `https://efinances.top` (precisa ter um jeito de falar com vocês)
- **URL de marketing**: `https://efinances.top`
- **URL da política de privacidade**: `https://efinances.top/privacidade`
- **Descrição** (até 4000):

```
O e-Finances organiza o dinheiro da sua casa e do seu negócio num lugar só: contas a pagar e a receber, bancos conectados pelo Open Finance, limites por categoria, assinaturas e relatórios. É o mesmo e-Finances da web, com a sua conta de sempre.

SEU DIA A DIA
• Saldo da conta em uso e a previsão de fechamento do mês
• Contas atrasadas e as que vencem nos próximos dias: deslize para marcar como pago, com Desfazer
• Agenda do mês com os dias que têm lançamentos
• Lançamentos à vista, parcelados (a sobra dos centavos fica na 1ª parcela) ou recorrentes, com "Termina em"
• Editar ou excluir um recorrente: só este, este e os próximos ou todos
• Todo mês, o fechamento em telas no estilo stories: quanto entrou, saiu e sobrou

BANCOS CONECTADOS (OPEN FINANCE)
• As contas e os cartões do seu banco aparecem como contas do e-Finances
• Os lançamentos chegam sozinhos; você organiza descrição, categoria, contato e observações
• Faturas, limite disponível e a situação de cada conexão
• O e-Finances só lê os dados: nunca movimenta dinheiro

PLANEJAMENTO
• Limites por categoria, com aviso quando chega perto ou passa
• Parcelamentos em andamento: quanto falta e quando termina
• Assinaturas (streaming, música, academia...) com o total por mês e por ano e aviso de aumento de preço

PARA O SEU NEGÓCIO
• Várias empresas e contas, em reais, euros ou dólares
• Relatórios com a evolução mês a mês, os gastos por dia, a composição das despesas e as maiores despesas
• Contatos (clientes, fornecedores e funcionários): quem te deve e a quem você deve
• Categorias com ícone e cor, a marca ou um logo seu; centros de custo com orçamento

SEGURANÇA E PRIVACIDADE
• Entre com o mesmo e-mail e senha da web
• Desbloqueio com Face ID ou o código do iPhone
• Sessão guardada no Keychain do iPhone; tela coberta no alternador de apps
• Opção de esconder os valores ao abrir o app
• Sem anúncios e sem rastreamento

Precisa de ajuda? Abra um chamado pelo próprio app (Mais › Ajuda e suporte).
```

- **Novidades desta versão**: `Primeira versão do e-Finances para iPhone.`

## Privacidade do app (App Privacy)

"Coletamos dados deste app": **Sim**. Nenhum dado é usado para rastreamento e não há SDK de terceiros. Para cada tipo
abaixo: **vinculado à identidade**, **não usado para rastrear**, finalidade **Funcionalidade do app**.

| Tipo (App Store Connect) | O que é |
|---|---|
| Informações de contato → Nome | nome e sobrenome do cadastro |
| Informações de contato → E-mail | e-mail de login |
| Informações financeiras → Outras informações financeiras | lançamentos, contas, saldos, limites e dados vindos do Open Finance |
| Identificadores → ID do usuário | identificador da conta no e-Finances |
| Conteúdo do usuário → Suporte ao cliente | mensagens dos chamados (com modelo do iPhone e versões) |

O mesmo está em `App/PrivacyInfo.xcprivacy` (que também declara o uso do UserDefaults só para as preferências do app).

## Revisão do app (App Review)

- **Login necessário**: sim. Informar a conta de revisão **(você)**.
- **Notas para a revisão** (cole e complete):

```
O e-Finances é um app de gestão financeira pessoal e de pequenos negócios (orçamento, contas a pagar e a receber, relatórios). É o cliente iPhone do serviço web https://efinances.top; a conta é criada no próprio app (Criar conta) ou na web.

Conta de teste: [e-mail] / [senha]

Pontos que costumam gerar dúvida:
- Bancos conectados: a conexão é feita pelo Open Finance Brasil por um agregador regulado pelo Banco Central, só leitura. O app não movimenta dinheiro, não faz pagamentos nem oferece crédito ou investimento. A autorização é feita na página segura do e-Finances aberta dentro do app (SFSafariViewController).
- Assinatura do serviço: nesta versão não há compra dentro do app nem link ou preço para comprar fora dele; o app só mostra o plano atual e as faturas (Mais › Plano e faturas).
- Excluir a conta: Mais › Minha conta › Excluir minha conta. O pedido vira um chamado de exclusão, a equipe confirma e há 30 dias para reativar; depois tudo é apagado.
- Face ID: usado só para desbloquear o app; a senha não fica guardada no iPhone.
- Importar/exportar extrato e modelos de recibo abrem a versão web dentro do app.
```

- **Criptografia (export compliance)**: o app só usa HTTPS do sistema → "não usa criptografia além da isenta"
  (`ITSAppUsesNonExemptEncryption = NO` já está no Info.plist, então a pergunta não aparece a cada envio).
- **Login social**: o app não oferece login com Google/Facebook. Se a web ligar o login com Google e ele vier para o
  app, a Apple exige oferecer também "Iniciar sessão com a Apple" (diretriz 4.8).

## Diretrizes que já estão atendidas

| Diretriz | Como |
|---|---|
| 3.1.1 Compras dentro do app | sem compra, preço ou link de pagamento na 1ª versão (só consulta do plano) |
| 5.1.1(v) Exclusão da conta | pedido de exclusão dentro do app (Mais › Minha conta › Excluir minha conta) |
| 5.1.1 Privacidade | política em `/privacidade`, manifesto de privacidade, Face ID com texto de uso, nenhum rastreamento |
| 5.1.2 Uso de dados | dados só para o app funcionar; nada vendido ou compartilhado para anúncios |
| 2.1 Completude | modo demonstração para testar sem servidor (esquema EFinances Demo), conta de teste para a revisão |
| 4.2 Funcionalidade mínima | app nativo completo (não é a web embrulhada): telas, gestos, Face ID, modo escuro e acessibilidade do iOS |
