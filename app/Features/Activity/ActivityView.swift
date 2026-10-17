import SwiftUI
import SwiftData

struct ActivityView: View {
    @EnvironmentObject private var appStore: AppStore
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]

    @State private var selectedMonth = Date()
    @State private var searchText = ""
    @State private var typeFilter: ActivityTypeFilter = .all
    @State private var categoryFilter: UUID?
    @State private var sortOrder: ActivitySortOrder = .date
    @State private var showFilters = false
    @State private var showTransactionForm = false
    @State private var selectedTransaction: Transaction?

    private var currencyCode: String {
        appStore.preferences?.currencyCode ?? "INR"
    }

    private var visibleCategories: [BudgetCategory] {
        categories.filter { !$0.isArchived }.sorted {
            $0.sortOrder == $1.sortOrder ? $0.name < $1.name : $0.sortOrder < $1.sortOrder
        }
    }

    private var filteredTransactions: [Transaction] {
        transactions
            .filter { transaction in
                guard appStore.calendar.isDate(transaction.date, equalTo: selectedMonth, toGranularity: .month) else { return false }
                switch typeFilter {
                case .all: break
                case .expenses where transaction.kind != .expense && transaction.kind != .refund: return false
                case .income where transaction.kind != .income: return false
                default: break
                }
                if let categoryFilter, transaction.categoryID != categoryFilter { return false }
                guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
                let categoryName = visibleCategories.first(where: { $0.id == transaction.categoryID })?.name ?? ""
                let query = searchText.lowercased()
                return transaction.merchant.lowercased().contains(query)
                    || transaction.note.lowercased().contains(query)
                    || categoryName.lowercased().contains(query)
                    || transaction.kind.displayName.lowercased().contains(query)
            }
            .sorted { left, right in
                switch sortOrder {
                case .date:
                    return left.date == right.date ? left.id.uuidString > right.id.uuidString : left.date > right.date
                case .amount:
                    return left.normalizedAmount == right.normalizedAmount ? left.date > right.date : left.normalizedAmount > right.normalizedAmount
                }
            }
    }

    private var groupedTransactions: [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) {
            appStore.calendar.startOfDay(for: $0.date)
        }
        return grouped.keys.sorted(by: >).map { date in
            (date, grouped[date] ?? [])
        }
    }

    private var summary: MonthSummary {
        FinancialCalculator.monthSummary(for: selectedMonth, transactions: transactions, calendar: appStore.calendar)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                header
                summarySurface
                filterBar
                transactionContent
            }
            .padding(.horizontal, DesignSystem.Spacing.large)
            .padding(.top, DesignSystem.Spacing.small)
            .padding(.bottom, DesignSystem.Spacing.xxLarge)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .navigationTitle("Activity")
        .platformLargeNavigationTitle()
#if os(iOS)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search transactions")
#elseif os(macOS)
        .searchable(text: $searchText, prompt: "Search transactions")
#endif
        .toolbar {
            ToolbarItem(placement: .platformTrailing) {
                Button {
                    selectedTransaction = nil
                    showTransactionForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add transaction")
            }
        }
        .sheet(isPresented: $showTransactionForm) {
            TransactionFormView(transaction: selectedTransaction)
        }
        .onAppear {
            selectedMonth = appStore.selectedMonth
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                Text("Money in motion")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Text("Every entry, in one place")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
            }
            Spacer()
            MonthSelector(month: $selectedMonth, calendar: appStore.calendar)
        }
    }

    private var summarySurface: some View {
        FinancialSurface {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                    Text("Monthly spending")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    MoneyText(summary.spending, currencyCode: currencyCode, font: .title2.monospacedDigit().weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxxSmall) {
                    Text("Income")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    MoneyText(summary.income, currencyCode: currencyCode, font: .subheadline.monospacedDigit().weight(.medium), color: DesignSystem.Colors.success)
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Picker("Transaction type", selection: $typeFilter) {
                ForEach(ActivityTypeFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.small) {
                    FilterChip(title: categoryFilterTitle, isSelected: categoryFilter != nil, systemImage: "line.3.horizontal.decrease") {
                        showFilters = true
                    }
                    FilterChip(title: sortOrder.title, systemImage: "arrow.up.arrow.down") {
                        sortOrder = sortOrder == .date ? .amount : .date
                    }
                    if categoryFilter != nil || !searchText.isEmpty {
                        Button("Clear") {
                            categoryFilter = nil
                            searchText = ""
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.success)
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.xxxSmall)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheet(isPresented: $showFilters) {
                CategoryFilterSheet(
                    categories: visibleCategories,
                    selection: $categoryFilter
                )
            }
        }
    }

    @ViewBuilder
    private var transactionContent: some View {
        if filteredTransactions.isEmpty {
            EmptyStateView(
                systemImage: searchText.isEmpty ? "list.bullet.rectangle" : "magnifyingglass",
                title: searchText.isEmpty ? "No transactions this month" : "No matching transactions",
                message: searchText.isEmpty ? "Add an expense or income entry to start building your activity history." : "Try a different merchant, category, or month.",
                actionTitle: searchText.isEmpty ? "Add transaction" : nil,
                action: searchText.isEmpty ? {
                    selectedTransaction = nil
                    showTransactionForm = true
                } : nil
            )
            .frame(maxWidth: .infinity)
        } else {
            ForEach(groupedTransactions, id: \.0) { date, dayTransactions in
                VStack(alignment: .leading, spacing: 0) {
                    Text(dayLabel(for: date))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                        .padding(.bottom, DesignSystem.Spacing.xxxSmall)

                    FinancialSurface(padding: EdgeInsets(top: 4, leading: DesignSystem.Spacing.medium, bottom: 4, trailing: DesignSystem.Spacing.medium)) {
                        ForEach(dayTransactions, id: \.id) { transaction in
                            Button {
                                selectedTransaction = transaction
                                showTransactionForm = true
                            } label: {
                                TransactionRow(
                                    transaction: transaction,
                                    category: visibleCategories.first(where: { $0.id == transaction.categoryID }),
                                    currencyCode: currencyCode
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    appStore.deleteTransaction(transaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            if transaction.id != dayTransactions.last?.id {
                                Divider().overlay(DesignSystem.Colors.divider)
                            }
                        }
                    }
                }
            }
        }
    }

    private func dayLabel(for date: Date) -> String {
        if appStore.calendar.isDateInToday(date) { return "Today" }
        if appStore.calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private var categoryFilterTitle: String {
        guard let categoryFilter else { return "Category" }
        return visibleCategories.first(where: { $0.id == categoryFilter })?.name ?? "Category"
    }
}

private enum ActivityTypeFilter: String, CaseIterable, Identifiable {
    case all
    case expenses
    case income

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .expenses: return "Expenses"
        case .income: return "Income"
        }
    }
}

private enum ActivitySortOrder: String {
    case date
    case amount

    var title: String {
        switch self {
        case .date: return "Latest"
        case .amount: return "Largest"
        }
    }
}

private struct CategoryFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [BudgetCategory]
    @Binding var selection: UUID?

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selection = nil
                    dismiss()
                } label: {
                    Label("All categories", systemImage: selection == nil ? "checkmark" : "circle")
                }

                ForEach(categories, id: \.id) { category in
                    Button {
                        selection = category.id
                        dismiss()
                    } label: {
                        Label(category.name, systemImage: selection == category.id ? "checkmark" : category.iconName)
                    }
                }
            }
            .navigationTitle("Filter category")
            .platformInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .platformSheetFrame(minWidth: 460, idealWidth: 560, minHeight: 360, idealHeight: 440)
#if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
#endif
    }
}
