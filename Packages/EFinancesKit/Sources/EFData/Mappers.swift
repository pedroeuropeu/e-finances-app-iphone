import Foundation
import EFCore

/* Conversões API → modelos do app. Campo ausente vira valor neutro, nunca erro. */

extension Optional where Wrapped == String {
    /// Texto com conteúdo ou nil ("" e só espaços viram nil).
    var clean: String? {
        guard let s = self?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }
}

func money(_ v: Double?) -> Decimal { Decimal(api: v) }

func enumValue<E: RawRepresentable & CaseIterable>(_ raw: String?) -> E? where E.RawValue == String {
    guard let raw else { return nil }
    return E.allCases.first { $0.rawValue.caseInsensitiveCompare(raw) == .orderedSame }
}

/// "PREMIUN" (como está no banco) e "PREMIUM" viram "Premium"; os outros com a primeira letra maiúscula.
func planLabel(_ name: String?) -> String {
    guard let name else { return "Plano" }
    if ["PREMIUN", "PREMIUM"].contains(name.uppercased()) { return "Premium" }
    return name.lowercased().capitalizedFirst
}

extension CategoryDTO {
    func toDomain() -> TransactionCategory? {
        guard let id else { return nil }
        return TransactionCategory(id: id, name: name ?? "", systemDefault: systemDefault == true, description: description.clean, subscription: subscription == true,
                        brand: brand.clean, icon: icon.clean, color: color.clean, logo: logo.clean)
    }
}

extension CategoryOverviewDTO {
    func toDomain(fallback: YearMonth) -> CategoryOverview {
        CategoryOverview(
            month: YearMonth.parse(month) ?? fallback,
            currency: currency ?? "BRL",
            spent: money(spent).magnitude,
            categories: (categories ?? []).map { c in
                CategoryView(
                    category: TransactionCategory(id: c.id, name: c.name ?? "", systemDefault: c.systemDefault == true, description: c.description.clean,
                                       subscription: c.subscription == true, brand: c.brand.clean, icon: c.icon.clean, color: c.color.clean, logo: c.logo.clean),
                    spent: money(c.spent).magnitude, income: money(c.income).magnitude, count: c.count ?? 0, usage: c.usage ?? 0,
                    limitId: c.limitId, limit: c.limit.map { money($0) }, limitPercent: c.limitPercent,
                    limitStatus: c.limitStatus.flatMap { LimitStatus(rawValue: $0.lowercased()) }, alertPercent: c.alertPercent ?? 80
                )
            }
        )
    }
}

extension ContactDTO {
    func toDomain() -> Contact? {
        guard let id else { return nil }
        return Contact(id: id, name: name ?? "", category: enumValue(category), phone: cellphone.clean ?? phone.clean, email: personalEmail.clean ?? companyEmail.clean)
    }
}

extension CostCenterDTO {
    func toDomain() -> CostCenter? {
        guard let id else { return nil }
        return CostCenter(id: id, name: name ?? "", description: description.clean, color: color.clean, monthlyBudget: monthlyBudget.map { money($0) }, systemDefault: false)
    }

    /// Lista de centros de custo (a tela própria): sem dono = padrão do sistema.
    func toManaged() -> CostCenter? {
        guard let id else { return nil }
        return CostCenter(id: id, name: name ?? "", description: description.clean, color: color.clean, monthlyBudget: monthlyBudget.map { money($0) }, systemDefault: idUserOwner == nil)
    }
}

extension TransactionDTO {
    func toDomain(today: LocalDate) -> Transaction {
        Transaction(
            id: id,
            description: description ?? "",
            value: money(value).magnitude,
            type: enumValue(transactionType) ?? .variable,
            date: DateFormats.parse(transactionDate) ?? today,
            paid: payed == true,
            refDate: DateFormats.parse(transactionRef),
            paymentType: enumValue(paymentType),
            paymentMode: enumValue(paymentMode) ?? .oneTime,
            recurrence: enumValue(paymentModeRecurrence),
            plot: plotDescription.clean,
            category: category?.toDomain(),
            contact: contact?.toDomain(),
            costCenter: costCenter?.toDomain(),
            docNumber: docNumber.clean,
            details: details.clean,
            accountName: account?.name,
            rootNumber: transactionRootNumber.clean
        )
    }
}

extension SeriesDTO {
    func toDomain() -> SeriesInfo {
        SeriesInfo(frequency: enumValue(frequency), endDate: DateFormats.parse(endDate), nextDate: DateFormats.parse(nextDate), active: active != false)
    }
}

extension WorkspaceDTO {
    func toDomain() -> Workspace {
        Workspace(companyId: companyId, accountId: accountId, companies: (companies ?? []).map { c in
            Company(
                id: c.id, name: c.name ?? "", type: enumValue(c.type),
                typeLabel: c.typeLabel ?? (c.type == "FAMILY" ? "Familiar" : "Empresa"),
                accounts: (c.accounts ?? []).map { a in
                    Account(id: a.id, name: a.name ?? "", currency: a.currency ?? "BRL", balance: money(a.balance), defaultAccount: a.defaultAccount == true,
                            transactions: a.transactions ?? 0, mode: a.frozen == true ? .frozen : a.connected == true ? .connected : .manual,
                            bankName: a.bankName.clean, bankLogoUrl: a.bankLogoUrl.clean, bankColor: a.bankColor.clean)
                }
            )
        })
    }
}

/// O backend monta completeName concatenando campos e pode vir "null " quando o nome não foi preenchido.
func cleanName(_ s: String?) -> String? {
    guard let s else { return nil }
    let words = s.split(separator: " ").filter { !$0.isEmpty && $0.lowercased() != "null" }
    return words.isEmpty ? nil : words.joined(separator: " ")
}

extension UserDTO {
    func toDomain(fallbackEmail: String) -> UserProfile {
        let complete = cleanName(completeName)
        let first = cleanName(firstName) ?? complete.map { String($0.split(separator: " ").first ?? "") } ?? ""
        let last = cleanName(lastName) ?? complete.map { $0.split(separator: " ").dropFirst().joined(separator: " ") } ?? ""
        return UserProfile(firstName: first, lastName: last, email: email ?? fallbackEmail,
                           planName: userPlan?.plan?.name.map(planLabel), planEndDate: DateFormats.parse(userPlan?.endDate))
    }
}

extension InstallmentsDTO {
    func toDomain() -> Installments {
        Installments(
            items: (items ?? []).map { i in
                InstallmentItem(key: i.key ?? "\(i.name ?? "")-\(i.transactionId ?? 0)", name: i.name ?? "", paid: i.paid ?? 0, total: i.total ?? 0,
                                amount: money(i.amount), remainingAmount: money(i.remainingAmount), endDate: DateFormats.parse(i.endDate),
                                source: InstallmentSource(rawValue: i.source ?? "") ?? .ledger, accountName: i.accountName, transactionId: i.transactionId)
            },
            remainingTotal: money(remainingTotal),
            monthlyTotal: money(monthlyTotal)
        )
    }
}

extension LimitsDTO {
    func toDomain(fallback: YearMonth) -> LimitsOverview {
        LimitsOverview(
            month: YearMonth.parse(month) ?? fallback,
            totalLimit: money(totalLimit),
            totalSpent: money(totalSpent),
            items: (items ?? []).map { $0.toDomain() },
            suggestions: (suggestions ?? []).compactMap { s in
                s.categoryId.map { LimitSuggestion(categoryId: $0, categoryName: s.categoryName ?? "", average: money(s.average), suggested: money(s.suggested)) }
            }
        )
    }
}

extension LimitItemDTO {
    func toDomain() -> LimitItem {
        LimitItem(id: id ?? 0, categoryId: categoryId ?? 0, categoryName: categoryName ?? "", limit: money(limit), spent: money(spent),
                  percent: percent ?? 0, alertPercent: alertPercent ?? 80, status: LimitStatus(rawValue: (status ?? "").lowercased()) ?? .ok)
    }
}

extension Optional where Wrapped == ReportTotalsDTO {
    func toDomain() -> ReportTotals {
        guard let t = self else { return .zero }
        return ReportTotals(income: money(t.income), expenseFixed: money(t.expenseFixed), expenseVariable: money(t.expenseVariable),
                            paidIncome: money(t.paidIncome), paidExpense: money(t.paidExpense), openIncome: money(t.openIncome),
                            openExpense: money(t.openExpense), count: t.count ?? 0)
    }
}

func monthFlows(_ months: [ReportMonthDTO]?, today: LocalDate) -> [MonthFlow] {
    (months ?? []).map { m in
        let ym = YearMonth(m.year, m.month)
        return MonthFlow(month: ym, income: money(m.income), expense: money(m.expense), projected: ym > today.yearMonth)
    }
}

extension ReportFullDTO {
    func toDomain(start s: LocalDate, end e: LocalDate, today: LocalDate) -> ReportOverview {
        var breakdown: [ReportDimension: [ReportSlice]] = [:]
        for (k, v) in self.breakdown ?? [:] {
            guard let dim: ReportDimension = enumValue(k) else { continue }
            breakdown[dim] = v.map { ReportSlice(key: $0.key ?? "none", label: $0.label ?? "—", type: enumValue($0.type), total: money($0.total).magnitude,
                                                 count: $0.count ?? 0, group: enumValue($0.group)) }
        }
        return ReportOverview(
            start: DateFormats.parse(start) ?? s, end: DateFormats.parse(end) ?? e, currency: currency ?? "BRL", accountName: accountName ?? "",
            current: current.toDomain(), previous: previous.toDomain(), months: monthFlows(months, today: today), breakdown: breakdown,
            topExpenses: (topExpenses ?? []).map { ReportExpense(id: $0.id ?? 0, date: DateFormats.parse($0.date), description: $0.description ?? "",
                                                                 contact: $0.contact.clean, category: $0.category.clean, value: money($0.value).magnitude, paid: $0.paid == true) },
            days: (days ?? []).compactMap { d in DateFormats.parse(d.date).map { ReportDay(date: $0, income: money(d.income).magnitude, expense: money(d.expense).magnitude) } }
        )
    }
}

extension ReportDayDetailDTO {
    func toDomain(fallback: LocalDate) -> DayExpenses {
        let list = (items ?? []).map { i in
            ReportDayItem(id: i.id ?? 0, description: i.description ?? "", contact: i.contact.clean,
                          category: i.category.clean.map { TransactionCategory(id: 0, name: $0, brand: i.categoryBrand.clean, icon: i.categoryIcon.clean, color: i.categoryColor.clean, logo: i.categoryLogo.clean) },
                          type: enumValue(i.type) ?? .variable, value: money(i.value).magnitude, paid: i.paid == true)
        }
        return DayExpenses(date: DateFormats.parse(date) ?? fallback, total: money(total).magnitude, count: count ?? list.count, items: list)
    }
}

extension OfAccountDTO {
    func toDomain(fallbackConnection: Int64 = 0) -> BankAccount {
        let credit = type?.uppercased() == "CREDIT"
        return BankAccount(id: id, connectionId: connectionId ?? fallbackConnection, name: marketingName.clean ?? name.clean ?? (credit ? "Cartão" : "Conta"),
                           kind: credit ? .credit : .bank, balance: money(balance), creditLimit: creditLimit.map { money($0) },
                           availableCredit: availableCreditLimit.map { money($0) }, currency: currencyCode ?? "BRL", number: number, ledgerAccountId: ledgerAccountId)
    }
}

extension ConnectionDTO {
    func toDomain() -> BankConnection {
        let st = status ?? "UPDATED"
        return BankConnection(
            id: id, bankName: connectorName ?? "Banco", color: connectorPrimaryColor, imageUrl: connectorImageUrl.clean, status: st,
            needsUserAction: needsUserAction == true || st.uppercased() == "LOGIN_ERROR" || st.uppercased() == "OUTDATED",
            syncing: syncing == true, lastSyncAt: DateFormats.parseDateTime(lastSyncAt), nextSyncAt: DateFormats.parseDateTime(nextAutoSyncAt),
            accounts: (accounts ?? []).map { $0.toDomain(fallbackConnection: id) }, companyId: companyId, companyName: companyName,
            disconnectedAccounts: disconnectedAccounts ?? 0
        )
    }
}

extension OfTransactionDTO {
    func toDomain(today: LocalDate) -> BankTransaction {
        BankTransaction(id: id ?? 0, date: DateFormats.parse(transactionDate) ?? today, description: merchantName.clean ?? description ?? "",
                        amount: money(amount), categoryName: categoryName,
                        installment: (installmentNumber != nil && totalInstallments != nil) ? "\(installmentNumber!)/\(totalInstallments!)" : nil)
    }
}

extension OfSummaryDTO {
    func toDomain() -> BankAccountSummary {
        BankAccountSummary(income: money(income), expense: money(expense).magnitude,
                           expenseByCategory: (expenseByCategory ?? []).map { CategoryTotal(name: $0.category ?? "Outros", total: money($0.total).magnitude) }.sorted { $0.total > $1.total })
    }
}

extension RecurringItemDTO {
    func toDomain() -> RecurringItem {
        RecurringItem(key: key ?? name ?? "", name: name ?? "", brand: brand.clean, frequency: enumValue(frequency) ?? .monthly, amount: money(amount),
                      previousAmount: previousAmount.map { money($0) }, monthlyAmount: money(monthlyAmount ?? amount), nextDate: DateFormats.parse(nextDate),
                      accountName: accountName, lastDate: DateFormats.parse(lastDate), category: category, currency: currency ?? "BRL",
                      icon: icon.clean, color: color.clean, logo: logo.clean)
    }
}

extension SubscriptionsDTO {
    /// Totais por moeda: fica o da moeda com mais assinaturas (normalmente a da conta em uso).
    func toDomain() -> Subscriptions {
        let subs = (subscriptions ?? []).map { $0.toDomain() }.sorted { ($0.nextDate ?? LocalDate(9999, 12, 31)) < ($1.nextDate ?? LocalDate(9999, 12, 31)) }
        let total = (totals ?? []).max { ($0.count ?? 0) < ($1.count ?? 0) }
        let monthly = total?.monthly.map { money($0) } ?? subs.reduce(Decimal(0)) { $0 + $1.monthlyAmount }
        return Subscriptions(subscriptions: subs, bills: (bills ?? []).map { $0.toDomain() }, monthlyTotal: monthly,
                             yearlyTotal: total?.yearly.map { money($0) } ?? monthly * 12, currency: total?.currency ?? subs.first?.currency ?? "BRL",
                             connected: connected == true)
    }
}

extension StoryDTO {
    func toDomain() -> Story {
        Story(periodKey: periodKey ?? "", title: title ?? "Fechamento do mês", periodLabel: periodLabel ?? "", tag: tag ?? periodLabel ?? "",
              accountName: accountName ?? "", income: money(income), expenses: money(expenses), balance: money(balance), savingsRate: savingsRate,
              count: count ?? 0, openExpenses: openExpenses ?? 0, expensesDeltaPct: expensesDeltaPct,
              categories: (categories ?? []).map { StoryCategory(name: $0.name ?? "", value: money($0.value), percent: $0.percent ?? 0) },
              biggestExpense: biggestExpense.map { StoryExpense(description: $0.description ?? "", value: money($0.value), date: DateFormats.parse($0.date)) },
              limitsWithin: limits?.within ?? 0, limitsTotal: limits?.total ?? 0, limitsOver: limits?.over ?? 0,
              subscriptionsMonthly: money(subscriptions?.monthly), subscriptionsCount: subscriptions?.count ?? 0, currency: currency ?? "BRL")
    }
}

extension NotificationDTO {
    func toDomain() -> AppNotification {
        AppNotification(id: id, category: enumValue(category) ?? .system, severity: enumValue(severity) ?? .info, title: title ?? "", body: body ?? "",
                        link: link, createdAt: DateFormats.parseDateTime(createdAt), read: readAt != nil)
    }
}

extension ContactFullDTO {
    func toDetails() -> ContactDetails? {
        guard let id else { return nil }
        return ContactDetails(contact: Contact(id: id, name: name ?? "", category: enumValue(category), phone: cellphone.clean ?? phone.clean,
                                               email: personalEmail.clean ?? companyEmail.clean),
                              personType: enumValue(type), document: identificationNumber.clean, city: city.clean, state: state.clean, description: description.clean)
    }
}

extension InvoiceDTO {
    func toDomain() -> Invoice {
        Invoice(id: id, status: InvoiceStatus(rawValue: statusInvoice ?? "") ?? .waiting, description: description.clean ?? planLabel(plan?.name),
                planName: plan?.name.map(planLabel), period: enumValue(subscriptionType), total: money(totalValue),
                totalFormatted: totalValueFormatted ?? Money.format(money(totalValue)), date: DateFormats.parse(invoiceDate), paidAt: paidAt)
    }
}

extension TicketDTO {
    func toDomain() -> Ticket {
        Ticket(id: id, protocolNumber: self.protocol ?? "#\(id)", title: title ?? "", category: enumValue(category), status: TicketStatus(rawValue: ticketStatus ?? "") ?? .open,
               createdAt: DateFormats.parseDateTime(createdAt), lastMessageAt: DateFormats.parseDateTime(lastMessageAt), unread: unread == true,
               lastMessage: lastMessage, lastFromSupport: lastFromSupport == true,
               messages: (messages ?? []).map { TicketMessage(id: $0.id ?? 0, message: $0.message ?? "", fromSupport: $0.fromSupport == true, authorName: $0.authorName, createdAt: DateFormats.parseDateTime($0.createdAt)) })
    }
}

// MARK: - rascunho → API

extension TransactionDraft {
    func contactRef() -> RefDTO? {
        if let c = contact { return RefDTO(id: c.id) }
        guard let n = newContactName.clean else { return nil }
        return RefDTO(name: n, category: type.isIncome ? "CLIENT" : "SUPPLIER")
    }

    func categoryRef() -> RefDTO? {
        if let c = category { return RefDTO(id: c.id) }
        return newCategoryName.clean.map { RefDTO(name: $0) }
    }

    /// Só a organização (lançamento que veio do banco). Observações e documento vazios só vão como "" se antes tinham texto (para apagar).
    func toOrganizeDTO(id: Int64, original: Transaction?) -> TransactionOrganizeDTO {
        let det = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let doc = docNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return TransactionOrganizeDTO(
            id: id, description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            details: (!det.isEmpty || original?.details.clean != nil) ? det : nil,
            docNumber: (!doc.isEmpty || original?.docNumber.clean != nil) ? doc : nil,
            paymentType: paymentTypeChosen ? paymentType.rawValue : nil,
            contact: contactRef(), category: categoryRef(), costCenter: costCenter.map { RefDTO(id: $0.id) }
        )
    }

    /// Atualização (o mesmo formato serve para criar parcelas em lote).
    func toUpdateDTO(id: Int64?, value: Decimal, date: LocalDate, plot: String? = nil) -> TransactionUpdateDTO {
        TransactionUpdateDTO(
            id: id, description: description.trimmingCharacters(in: .whitespacesAndNewlines), value: value.doubleValue, transactionDate: DateFormats.api(date),
            transactionRef: refMonth.map { DateFormats.api($0.firstDay) }, details: details.clean, docNumber: docNumber.clean, payed: paid,
            paymentType: paymentType.rawValue, paymentMode: paymentMode.rawValue,
            paymentModeRecurrence: paymentMode == .oneTime ? nil : recurrence.rawValue, plotDescription: plot, transactionType: type.rawValue,
            contact: contactRef(), category: categoryRef(), costCenter: costCenter.map { RefDTO(id: $0.id) }
        )
    }
}

extension String {
    var clean: String? { Optional(self).clean }
}

extension TestimonialDTO {
    func toDomain() -> Testimonial {
        Testimonial(authorName: authorName ?? "", authorRole: authorRole ?? "", rating: rating ?? 0, text: text ?? "", consent: consent ?? false,
                    status: status.flatMap(TestimonialStatus.init(rawValue:)))
    }

    init(_ t: Testimonial) {
        let role = t.authorRole.trimmingCharacters(in: .whitespaces)
        self.init(id: nil, authorName: t.authorName.trimmingCharacters(in: .whitespaces), authorRole: role.isEmpty ? nil : role, rating: t.rating,
                  text: t.text.trimmingCharacters(in: .whitespacesAndNewlines), consent: t.consent, status: nil, createdAt: nil, initials: nil)
    }
}
