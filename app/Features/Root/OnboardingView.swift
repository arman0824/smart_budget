import SwiftUI
import SwiftData

struct OnboardingView: View {
    @EnvironmentObject private var appStore: AppStore

    @State private var page = 0
    @State private var currencyCode = "INR"
    @State private var monthlyAllowance = "40000"
    @State private var incomeTarget = ""
    @State private var savingsGoal = ""
    @State private var useSampleData = false
    @State private var notificationsEnabled = false
    @State private var notificationMessage: String?

    private let currencies = [
        ("INR", "Indian rupee"),
        ("USD", "US dollar"),
        ("EUR", "Euro"),
        ("GBP", "British pound"),
        ("AUD", "Australian dollar"),
        ("CAD", "Canadian dollar"),
        ("SGD", "Singapore dollar"),
        ("JPY", "Japanese yen")
    ]

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    if page > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                page -= 1
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Back")
                    } else {
                        Spacer().frame(width: 44)
                    }

                    Spacer()

                    Text("Step \(page + 1) of 3")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)

                    Spacer()
                    Spacer().frame(width: 44)
                }
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.top, DesignSystem.Spacing.small)

                ProgressView(value: Double(page + 1), total: 3)
                    .tint(DesignSystem.Colors.success)
                    .padding(.horizontal, DesignSystem.Spacing.xLarge)
                    .padding(.top, DesignSystem.Spacing.small)

                TabView(selection: $page) {
                    welcomePage.tag(0)
                    setupPage.tag(1)
                    remindersPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Button {
                    advance()
                } label: {
                    Text(page == 2 ? "Open my dashboard" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.medium)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.success)
                .padding(.horizontal, DesignSystem.Spacing.xLarge)
                .padding(.bottom, DesignSystem.Spacing.large)
                .accessibilityIdentifier("onboarding-continue")
            }
        }
    }

    private var welcomePage: some View {
        VStack(spacing: DesignSystem.Spacing.xLarge) {
            Spacer()

            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.successSurface)
                    .frame(width: 112, height: 112)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.success)
            }

            VStack(spacing: DesignSystem.Spacing.small) {
                Text("A clearer view of your money")
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .multilineTextAlignment(.center)

                Text("Track everyday spending, plan a calm monthly budget, and stay ahead of recurring payments — all on your device.")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DesignSystem.Spacing.xLarge)

            FinancialSurface {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.medium) {
                    Image(systemName: "lock.shield")
                        .font(.title3)
                        .foregroundStyle(DesignSystem.Colors.success)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                        Text("Private by design")
                            .font(.headline)
                        Text("Your entries stay in the app's local SwiftData store. No account or bank connection is required.")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.xLarge)

            Spacer()
        }
        .padding(.top, DesignSystem.Spacing.large)
    }

    private var setupPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xLarge) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Set up your baseline")
                        .font(.system(.title, design: .rounded).weight(.semibold))
                    Text("These are optional starting points. You can change them anytime in Settings.")
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Currency")
                        .font(.headline)
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(currencies, id: \.0) { currency in
                            Text("\(currency.0) · \(currency.1)")
                                .tag(currency.0)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.vertical, DesignSystem.Spacing.small)
                    .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                            .stroke(DesignSystem.Colors.divider)
                    }
                    .accessibilityLabel("Currency")
                }

                VStack(spacing: DesignSystem.Spacing.medium) {
                    DecimalField(title: "Monthly spending allowance", text: $monthlyAllowance, prompt: "e.g. 40000")
                    DecimalField(title: "Monthly income target", text: $incomeTarget, prompt: "Optional")
                    DecimalField(title: "Monthly savings goal", text: $savingsGoal, prompt: "Optional")
                }

                Toggle(isOn: $useSampleData) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                        Text("Explore with sample data")
                            .font(.headline)
                        Text("See the complete experience with clearly labeled example entries. Your real data stays separate.")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                }
                .tint(DesignSystem.Colors.success)
                .padding(DesignSystem.Spacing.medium)
                .background(DesignSystem.Colors.successSurface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.large))

                Text("You can start with a zero budget and add entries as you go. Nothing is uploaded.")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.xLarge)
            .padding(.top, DesignSystem.Spacing.large)
            .padding(.bottom, DesignSystem.Spacing.xLarge)
        }
    }

    private var remindersPage: some View {
        VStack(spacing: DesignSystem.Spacing.xLarge) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.warning)
                .frame(width: 112, height: 112)
                .background(Color(hex: "#FFF8E9"), in: Circle())

            VStack(spacing: DesignSystem.Spacing.small) {
                Text("Stay ahead of renewals")
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Choose whether Smart Budget should remind you before a subscription renews. You can change this later.")
                    .font(.body)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            FinancialSurface {
                Toggle(isOn: $notificationsEnabled) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                        Text("Enable renewal reminders")
                            .font(.headline)
                        Text(notificationMessage ?? "We only schedule reminders for subscriptions you add.")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                }
                .tint(DesignSystem.Colors.success)
                .onChange(of: notificationsEnabled) { _, isEnabled in
                    if isEnabled {
                        Task {
                            let granted = await appStore.requestNotificationPermission()
                            if !granted {
                                notificationsEnabled = false
                                notificationMessage = "Notifications are off. You can enable them later in iOS Settings."
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.xLarge)
    }

    private func advance() {
        guard page < 2 else {
            if let preferences = appStore.preferences {
                preferences.notificationsEnabled = notificationsEnabled
            }
            appStore.completeOnboarding(
                currencyCode: currencyCode,
                monthlyAllowance: decimalValue(monthlyAllowance),
                incomeTarget: decimalValue(incomeTarget),
                savingsGoal: decimalValue(savingsGoal),
                useSampleData: useSampleData
            )
            return
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            page += 1
        }
    }

    private func decimalValue(_ text: String) -> Decimal {
        let normalized = text
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Decimal(string: normalized) ?? .zero
    }
}

private struct DecimalField: View {
    let title: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
            Text(title)
                .font(.headline)
            HStack {
                TextField(prompt, text: $text)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .font(.body.monospacedDigit())
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear \(title)")
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                    .stroke(DesignSystem.Colors.divider)
            }
        }
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .environmentObject(PreviewSupport.store)
        .modelContainer(PreviewSupport.container)
}
