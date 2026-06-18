//
//  FieldType.swift
//  Eulerity
//
//  Net 2 of the decoding boundary (see DECISIONS.md → D3): unknown server values
//  decode successfully as `.unknown(raw)` rather than throwing. The decision to
//  drop an unknown is made deliberately in FieldFactory (M2), not at decode time.
//

import Foundation

/// The field's primary kind.
enum FieldType: Equatable {
    case text
    case dropdown
    case toggle
    case checkbox
    case unknown(String)

    /// Case-insensitive so a sloppy server (`"text"`, `"Text"`, `"TEXT"`) still
    /// resolves. Anything unrecognized is preserved verbatim as `.unknown`.
    init(raw: String) {
        switch raw.uppercased() {
        case "TEXT": self = .text
        case "DROPDOWN": self = .dropdown
        case "TOGGLE": self = .toggle
        case "CHECKBOX": self = .checkbox
        default: self = .unknown(raw)
        }
    }
}

/// The subtype of a `TEXT` field. Unknown values decode as `.unknown(raw)`; the
/// factory chooses the fallback (treat as PLAIN vs. drop) in M2.
enum FieldSubtype: Equatable {
    case plain
    case multiline
    case number
    case uri
    case secure
    case unknown(String)

    init(raw: String) {
        switch raw.uppercased() {
        case "PLAIN": self = .plain
        case "MULTILINE": self = .multiline
        case "NUMBER": self = .number
        case "URI": self = .uri
        case "SECURE": self = .secure
        default: self = .unknown(raw)
        }
    }
}
