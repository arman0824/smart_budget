import Foundation
import SwiftData

@Model
public final class Subscription {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var merchant: String
    public var amount: Decimal
    public var currencyCode: String
    public var billingCycleRawValue: String
    public var nextBillingDate: Date?
    public var categoryID: UUID?
    public var statusRawValue: String
    public var trialEndDate: Date?
    public var reminderDaysBefore: Int
    public var notes: String
    public var website: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isSampleData: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        merchant: String = "",
        amount: Decimal,
        currencyCode: String = "INR",
        billingCycle: SubscriptionBillingCycle = .monthly,
        nextBillingDate: Date? = nil,
        categoryID: UUID? = nil,
        status: SubscriptionStatus = .active,
        trialEndDate: Date? = nil,
        reminderDaysBefore: Int = 3,
        notes: String = "",
        website: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSampleData: Bool = false
    ) {
        self.id = id
        self.name = name
        self.merchant = merchant
        self.amount = amount < Decimal.zero ? -amount : amount
        self.currencyCode = currencyCode
        self.billingCycleRawValue = billingCycle.rawValue
        self.nextBillingDate = nextBillingDate
        self.categoryID = categoryID
        self.statusRawValue = status.rawValue
        self.trialEndDate = trialEndDate
        self.reminderDaysBefore = max(0, reminderDaysBefore)
        self.notes = notes
        self.website = website
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSampleData = isSampleData
    }

    public var billingCycle: SubscriptionBillingCycle {
        get { SubscriptionBillingCycle(rawValue: billingCycleRawValue) ?? .monthly }
        set { billingCycleRawValue = newValue.rawValue }
    }

    public var status: SubscriptionStatus {
        get { SubscriptionStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    public var isActive: Bool {
        status == .active || status == .trial
    }

    public var monthlyEquivalent: Decimal {
        FinancialCalculator.subscriptionMonthlyEquivalent(amount: amount, billingCycle: billingCycle)
    }

    public var annualEquivalent: Decimal {
        FinancialCalculator.subscriptionAnnualEquivalent(amount: amount, billingCycle: billingCycle)
    }
}
