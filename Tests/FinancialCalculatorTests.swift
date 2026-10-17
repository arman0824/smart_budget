import Foundation
import SwiftData
import XCTest
@testable import app

@MainActor
final class FinancialCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var month: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)) ?? Date()
    }

    func testExpenseIncomeTransferAndRefundUseSeparateTotals() {
        let groceriesID = UUID()
        let transactions = [
            Transaction(date: month, amount: Decimal(100), merchant: "Groceries", categoryID: groceriesID, kind: .expense),
            Transaction(date: month, amount: Decimal(20), merchant: "Refund", categoryID: groceriesID, kind: .refund),
            Transaction(date: month, amount: Decimal(250), merchant: "Salary", kind: .income),
            Transaction(date: month, amount: Decimal(75), merchant: "Transfer", kind: .transfer)
        ]

        let summary = FinancialCalculator.monthSummary(for: month, transactions: transactions, calendar: calendar)

        XCTAssertEqual(summary.expenses, Decimal(100))
        XCTAssertEqual(summary.refunds, Decimal(20))
        XCTAssertEqual(summary.income, Decimal(250))
        XCTAssertEqual(summary.transfers, Decimal(75))
        XCTAssertEqual(summary.spending, Decimal(80))
        XCTAssertEqual(summary.netCashFlow, Decimal(170))
        XCTAssertEqual(summary.categoryTotals[groceriesID], Decimal(80))
    }

    func testZeroBudgetHasNoPercentageAndOverBudgetIsExplicit() {
        XCTAssertNil(FinancialCalculator.budgetPercentage(spent: Decimal(10), limit: .zero))

        let categoryID = UUID()
        let plan = BudgetPlan(monthStart: month, categoryID: categoryID, limit: Decimal(50))
        let transaction = Transaction(date: month, amount: Decimal(75), categoryID: categoryID, kind: .expense)
        let status = FinancialCalculator.budgetStatus(for: plan, transactions: [transaction], calendar: calendar)

        XCTAssertEqual(status.spent, Decimal(75))
        XCTAssertEqual(status.remaining, Decimal(-25))
        XCTAssertTrue(status.isOverBudget)
        XCTAssertEqual(status.percentage, Decimal(150))
    }

    func testBillingDateStaysAtMonthEnd() {
        let january31 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 12)) ?? Date()
        let february = FinancialCalculator.advance(date: january31, by: .monthly, calendar: calendar)
        let march = february.flatMap { FinancialCalculator.advance(date: $0, by: .monthly, calendar: calendar) }

        XCTAssertEqual(february.map { calendar.component(.day, from: $0) }, 28)
        XCTAssertEqual(march.map { calendar.component(.day, from: $0) }, 28)
        XCTAssertEqual(march.map { calendar.component(.month, from: $0) }, 3)
    }

    func testSubscriptionEquivalentsAndCancelledCostPolicy() {
        XCTAssertEqual(
            FinancialCalculator.subscriptionMonthlyEquivalent(amount: Decimal(1200), billingCycle: .quarterly),
            Decimal(400)
        )
        XCTAssertEqual(
            FinancialCalculator.subscriptionAnnualEquivalent(amount: Decimal(100), billingCycle: .monthly),
            Decimal(1200)
        )

        let active = Subscription(name: "Active", amount: Decimal(100), status: .active)
        let cancelled = Subscription(name: "Cancelled", amount: Decimal(900), status: .cancelled)
        let insights = FinancialCalculator.deterministicInsights(
            for: month,
            transactions: [],
            subscriptions: [active, cancelled],
            calendar: calendar
        )

        XCTAssertTrue(insights.contains { $0.kind == .subscriptionCost && $0.detail.contains("100") })
        XCTAssertFalse(insights.contains { $0.kind == .subscriptionCost && $0.detail.contains("1000") })
    }

    func testCSVExportContainsHeaderAndEscapesCommas() {
        let transaction = Transaction(
            date: month,
            amount: Decimal(12.50),
            merchant: "Coffee, corner",
            note: "Morning \"flat white\"",
            kind: .expense
        )

        let csv = CSVExportService.csvString(for: [transaction])

        XCTAssertTrue(csv.hasPrefix("Date,Merchant,Category,Type,Amount,Note"))
        XCTAssertTrue(csv.contains("\"Coffee, corner\""))
        XCTAssertTrue(csv.contains("\"Morning \"\"flat white\"\"\""))
    }

    func testContainerSeedsPreferencesAndCategoriesWithoutSampleTransactions() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = container.mainContext
        let preferences = try context.fetch(FetchDescriptor<AppPreferences>())
        let categories = try context.fetch(FetchDescriptor<BudgetCategory>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())

        XCTAssertEqual(preferences.first?.currencyCode, "INR")
        XCTAssertFalse(categories.isEmpty)
        XCTAssertTrue(transactions.isEmpty)
    }
}
