//
//  FieldDiagnostic.swift
//  Eulerity
//
//  A record of every drop or degrade the factory performs.
//

import Foundation

/// Why a field was dropped, or how it was adjusted, during mapping.
///
/// Returned from `FieldFactory` as a value (so tests can assert on it) and
/// `debugPrint`'d in `DEBUG` builds (D7) — so a malformed server payload is loud in
/// development and silent in production.
struct FieldDiagnostic: Equatable, CustomStringConvertible {
    enum Reason: Equatable {
        case missingID
        case duplicateID(String)
        case unknownType(raw: String?)
        case dropdownHasNoValidOptions
        case droppedInvalidOptions(count: Int)
        case unknownSubtypeDegradedToPlain(raw: String)
        case ignoredNonPositiveMaxLength(Int)
        case filteredUnknownDefaultValues([String])
        case reducedMultipleDefaultsForSingleSelect
    }

    /// Source-array index of the offending field — a stable reference even when the
    /// field has no usable `id`.
    let sourceIndex: Int
    /// The field's id, or `nil` when it was missing.
    let fieldID: String?
    /// `true` if the whole field was dropped; `false` if it was kept with an adjustment.
    let wasDropped: Bool
    let reason: Reason

    var description: String {
        let idPart = fieldID.map { "id=\($0)" } ?? "id=<missing>"
        return "\(wasDropped ? "DROPPED" : "ADJUSTED") field[\(sourceIndex)] \(idPart): \(reason)"
    }
}
