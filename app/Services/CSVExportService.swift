import Foundation
import SwiftUI
import UniformTypeIdentifiers

public enum CSVExportError: Error, LocalizedError, Sendable {
    case invalidUTF8

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "The CSV contents could not be encoded as UTF-8."
        }
    }
}

public enum CSVExportService {
    public static func csvString(
        for transactions: [Transaction],
        categoryNames: [UUID: String] = [:]
    ) -> String {
        var lines = [
            ["Date", "Merchant", "Category", "Type", "Amount", "Note"]
                .map(escaped)
                .joined(separator: ",")
        ]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let utc = TimeZone(secondsFromGMT: 0) {
            formatter.timeZone = utc
        }

        let sortedTransactions = transactions.sorted {
            if $0.date != $1.date {
                return $0.date < $1.date
            }
            return $0.id.uuidString < $1.id.uuidString
        }

        for transaction in sortedTransactions {
            let category = transaction.categoryID.flatMap { categoryNames[$0] } ?? ""
            let row = [
                formatter.string(from: transaction.date),
                transaction.merchant,
                category,
                transaction.kind.rawValue,
                NSDecimalNumber(decimal: transaction.normalizedAmount).stringValue,
                transaction.note
            ]
            lines.append(row.map(escaped).joined(separator: ","))
        }

        return lines.joined(separator: "\r\n") + "\r\n"
    }

    public static func document(
        for transactions: [Transaction],
        categoryNames: [UUID: String] = [:]
    ) -> TransactionCSVDocument {
        TransactionCSVDocument(
            csvText: csvString(for: transactions, categoryNames: categoryNames)
        )
    }

    private nonisolated static func escaped(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

public struct TransactionCSVDocument: FileDocument {
    public static var readableContentTypes: [UTType] {
        [.commaSeparatedText]
    }

    public static var writableContentTypes: [UTType] {
        [.commaSeparatedText]
    }

    public var csvText: String

    public init(csvText: String = "") {
        self.csvText = csvText
    }

    public init(
        transactions: [Transaction],
        categoryNames: [UUID: String] = [:]
    ) {
        self.csvText = CSVExportService.csvString(
            for: transactions,
            categoryNames: categoryNames
        )
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CSVExportError.invalidUTF8
        }
        self.csvText = text
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = csvText.data(using: .utf8) else {
            throw CSVExportError.invalidUTF8
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
