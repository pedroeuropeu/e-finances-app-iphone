# e-Finances para iPhone

App nativo do [e-Finances](https://efinances.top) para iPhone (iOS 17 ou mais novo), em Swift e SwiftUI. É o mesmo
e-Finances da web e do Android, com a mesma conta: contas a pagar e a receber, bancos conectados pelo Open Finance,
limites, parcelas, assinaturas, relatórios e o fechamento do mês.

O protótipo navegável aprovado está em [`prototype/`](prototype/) (abra `prototype/index.html` ou rode o preview
`prototipo` do `.claude/launch.json`).

## O que tem

| Aba | Telas |
|---|---|
| **Início** | saldo e previsão de fechamento, carrossel das contas da empresa (manuais e do banco), vencimentos, agenda do mês, para onde foi o dinheiro, limites, parcelas, assinaturas e fluxo de caixa; troca de empresa/conta no topo |
| **Transações** | busca, mês, "Resultado do mês", filtros por tipo, situação e categoria, grupos (atrasadas, 7 dias, agendadas, pagas), deslizar para pagar ou excluir, menu do toque longo, seleção de vários, detalhe, novo/editar/organizar |
| **Contas** | bancos conectados (saldo, faturas, limite, reconectar, mudar empresa, desconectar escolhendo as contas e se congela ou apaga), contas manuais e congeladas, detalhe da conta do banco |
| **Planejar** | limites (com sugestões pela média), parcelamentos e assinaturas (aumento de preço, outras cobranças) |
| **Mais** | relatórios, categorias (ícone e cor, marca do catálogo da web ou logo das Fotos), contatos, centros de custo, empresas e contas, plano e faturas (só consulta), notificações, aparência, Face ID e segurança, ajuda e suporte (perguntas frequentes da web, chamados, depoimento), excluir conta, sobre |

Regras iguais às da web e do Android: excluir sem perguntar com **Desfazer** (recorrente e parcela perguntam o escopo),
a 1ª parcela leva os centavos que sobram, "Termina em" do recorrente, conta do banco só organiza e conta congelada só
consulta, exclusão da conta vira o chamado "Exclusão de conta" (30 dias para voltar atrás).

Ficou de fora da 1ª versão (decidido com o dono do produto): compra de plano dentro do app (App Store, diretriz 3.1.1;
o app só mostra o plano e as faturas, sem preços nem link para pagar) e os extras só do iPhone (widgets, atalhos do
ícone e ações na tela bloqueada), previstos para a 1.1. Importar e exportar extrato e os modelos de recibo abrem a web
dentro do app, como no Android.

## Como o código está organizado

```
App/                      ponto de entrada, Info.plist, ícone, manifesto de privacidade
Config/                   ambientes (Demo, Local, Produção) e a assinatura (Signing.xcconfig, fora do git)
Packages/EFinancesKit/    todo o código, em camadas:
  EFCore                  modelos, regras, datas e dinheiro, contratos dos repositórios (sem UI e sem rede)
  EFData                  API (URLSession + Keycloak), sessão no Keychain, modo demonstração
  EFFeatures              estado e ações de cada tela (@Observable), avisos com Desfazer, preferências
  EFUI                    telas em SwiftUI e o design system (Sora, cores da marca, vidro do iOS 26)
project.yml               projeto do Xcode (XcodeGen)
scripts/                  testes, geração do projeto, build, ícones e o conteúdo copiado da web
store/                    o que preencher na App Store Connect
```

Segurança: tokens só no Keychain (`WhenUnlockedThisDeviceOnly`), renovação do token 30 s antes de vencer com uma
renovação por vez, sessão encerrada pelo servidor volta ao login, bloqueio por Face ID/código com tempo escolhido,
tela coberta no alternador de apps, opção de esconder valores ao abrir, só HTTPS fora do ambiente local, nenhum SDK de
terceiros e nada de rastreamento.

## Ambientes

| Esquema | Configuração | Bundle | Servidor |
|---|---|---|---|
| EFinances Demo | Demo | `top.efinances.app.demo` | nenhum: dados de exemplo, qualquer senha entra |
| EFinances Local | Local | `top.efinances.app.local` | `localhost:8080` (API), `:8088` (Keycloak), `:4200` (web) |
| EFinances | Release | `top.efinances.app` | `https://efinances.top` |

O simulador enxerga o `localhost` do Mac direto. Num iPhone de verdade, troque `localhost` pelo IP do Mac em
`Config/Local.xcconfig`.

## Rodar

Pré-requisitos: **Xcode 26** (App Store) e o XcodeGen.

```bash
brew install xcodegen
```

```bash
scripts/xcode.sh
```

O script gera o `EFinances.xcodeproj` a partir do `project.yml` e abre no Xcode. Escolha o esquema **EFinances Demo** e
um iPhone do simulador e rode. Para compilar pelo terminal:

```bash
scripts/build.sh Demo
```

Testes (rodam neste Mac, sem simulador; também funcionam só com as Command Line Tools):

```bash
scripts/test.sh
```

São 84 testes: regras (datas, dinheiro, parcelas, vencimentos), API (login, renovação do token, erros), mapeamento do
JSON, modo demonstração e os modelos de cada tela (login, bloqueio, Desfazer, parcelas, escopo do recorrente, conta do
banco, limites, exclusão de conta, depoimento).

## Assinar e publicar

1. Entrar no Apple Developer Program (US$ 99/ano) com a conta da empresa ou a sua.
2. Copiar `Config/Signing.example.xcconfig` para `Config/Signing.xcconfig` e colocar o Team ID (o arquivo fica fora do git).
3. Criar o app na App Store Connect com o bundle `top.efinances.app` e preencher o que está em [`store/app-store.md`](store/app-store.md).
4. No Xcode: esquema **EFinances**, destino "Any iOS Device", Product → Archive → Distribute App → App Store Connect.

## Acompanhar a web

O app segue as funcionalidades da web (`../e-finances`): ao surgir um PR novo (`git log --merges origin/main`), confira
se ele muda algo que o app mostra. O conteúdo da ajuda e o catálogo de marcas vêm da web pelos scripts de
`scripts/web-content/`.
