import Foundation

/// Parses user-entered money amounts without assuming that a comma is a
/// thousands separator. Both `1,234.56` and `1.234,56` resolve to the same
/// decimal, and the active locale decides how a single separator is read.
enum AmountParser {
    /// Returns nil when the text does not contain a usable number. Callers use
    /// nil rather than `.zero` so that invalid input can be reported instead of
    /// silently saving a zero-value transaction.
    static func decimal(from text: String, locale: Locale = .current) -> Decimal? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        // Drop currency symbols, letters, and ordinary spaces. Keep digits,
        // signs, and the two characters that can act as a decimal separator.
        value = value.filter { character in
            character.isNumber
                || character == "."
                || character == ","
                || character == "-"
                || character == "\u{2212}" // Unicode minus
                || character == "'"
                || character == "\u{2019}"
                || character == " "
                || character == "\u{00A0}"
                || character == "\u{202F}"
        }
        value = value
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
            .replacingOccurrences(of: "\u{2212}", with: "-")

        guard value.contains(where: \.isNumber) else { return nil }

        let decimalSeparator = locale.decimalSeparator ?? "."
        let groupingSeparator = locale.groupingSeparator ?? ","
        let hasDot = value.contains(".")
        let hasComma = value.contains(",")

        if hasDot && hasComma {
            // Whichever separator appears last is the decimal separator.
            let lastDot = value.lastIndex(of: ".")!
            let lastComma = value.lastIndex(of: ",")!
            let decimalIsDot = lastDot > lastComma
            let grouping: String = decimalIsDot ? "," : "."
            let decimal: String = decimalIsDot ? "." : ","
            value = value.replacingOccurrences(of: grouping, with: "")
            value = value.replacingOccurrences(of: decimal, with: ".")
        } else if hasDot || hasComma {
            let separator: String = hasDot ? "." : ","
            let separatorChar = separator.first!
            let occurrences = value.filter { $0 == separatorChar }.count

            if occurrences > 1 {
                // Repeated separators can only be grouping separators.
                value = value.filter { $0 != separatorChar }
            } else if separator == decimalSeparator {
                value = value.replacingOccurrences(of: separator, with: ".")
            } else if separator == groupingSeparator {
                // A lone grouping separator is ambiguous: "1,234" is usually a
                // grouped integer, while "12,5" is a decimal in many locales.
                let digitsAfter = value.split(separator: separatorChar, omittingEmptySubsequences: false).last?.count ?? 0
                if digitsAfter == 3 {
                    value = value.filter { $0 != separatorChar }
                } else {
                    value = value.replacingOccurrences(of: separator, with: ".")
                }
            } else {
                let digitsAfter = value.split(separator: separatorChar, omittingEmptySubsequences: false).last?.count ?? 0
                if digitsAfter == 3 {
                    value = value.filter { $0 != separatorChar }
                } else {
                    value = value.replacingOccurrences(of: separator, with: ".")
                }
            }
        }

        guard value != "-" else { return nil }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// A locale-formatted decimal string suitable for an editable amount field.
    /// Using the display locale means a prefilled `12.345` is never mistaken for
    /// a grouped integer in locales where `.` separates thousands.
    static func editingString(_ amount: Decimal, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? NSDecimalNumber(decimal: amount).stringValue
    }

    /// Locale-aware placeholder that shows the user the expected shape of an
    /// amount without pre-filling a specific amount.
    static func placeholder(for locale: Locale = .current) -> String {
        let example = Decimal(1_250)
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: example)) ?? "1,250"
    }
}
