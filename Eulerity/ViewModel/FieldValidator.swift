//
//  FieldValidator.swift
//  Eulerity
//
//  Pure, headless validation. Runs on Save (D13).
//

import Foundation

/// Validates a field against its current value.
///
/// Precedence is **required → numeric (NUMBER only) → regex** (D13, D15); the first
/// failing rule's message wins. `max_length` is *not* validated here — it is enforced
/// as a hard typing limit in `FormViewModel.setText`, so it can never be violated.
enum FieldValidator {

    /// Returns an error message if the field is invalid, or `nil` if it passes.
    static func validate(_ field: RenderableField, value: FieldValue) -> String? {
        if let requiredError = requiredError(field, value) {
            return requiredError
        }

        // Text-only rules. Skip when the (trimmed) value is empty — emptiness is the
        // required rule's concern, not numeric/regex.
        guard case .text(let raw) = value, case .text(let text) = field.kind else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if text.subtype == .number, !isNumeric(trimmed) {
            return field.errorMessage ?? "Enter a valid number."
        }
        if let pattern = text.regex, !matchesFully(raw, pattern: pattern) {
            return field.errorMessage ?? "Invalid format."
        }
        return nil
    }

    // MARK: - Rules

    private static func requiredError(_ field: RenderableField, _ value: FieldValue) -> String? {
        guard field.isRequired else { return nil }
        let isEmpty: Bool
        switch value {
        case .text(let string):
            isEmpty = string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .selection(let ids):
            isEmpty = ids.isEmpty
        case .bool(let isOn):
            isEmpty = !isOn // a required checkbox/toggle must be on (e.g. accept terms)
        }
        return isEmpty ? (field.errorMessage ?? "This field is required.") : nil
    }

    /// Light numeric guard (D15): cheap defense against pasted junk like "50abc" that
    /// the numeric keypad can't stop. Rejects non-numbers and non-finite (inf/nan).
    private static func isNumeric(_ string: String) -> Bool {
        guard let value = Double(string) else { return false }
        return value.isFinite
    }

    /// Full-string regex match. An uncompilable server pattern is skipped (returns
    /// `true`) rather than locking the user out.
    private static func matchesFully(_ string: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            #if DEBUG
            debugPrint("⚠️ [FieldValidator] uncompilable regex skipped: \(pattern)")
            #endif
            return true
        }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let match = regex.firstMatch(in: string, range: range) else { return false }
        return match.range == range
    }
}
