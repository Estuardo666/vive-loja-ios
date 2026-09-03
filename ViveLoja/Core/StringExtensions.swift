import Foundation

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Optional-friendly trim: form fields send `nil` rather than an empty
    /// string, which is what the API's optional fields expect.
    var nilIfEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }
}
