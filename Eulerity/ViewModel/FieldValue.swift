//
//  FieldValue.swift
//  Eulerity
//
//  The mutable per-field state, plus the Save-payload value shape.
//

import Foundation

/// The mutable state of a single field, uniform across the engine.
///
/// NUMBER is stored as `.text` like every other text input (D15): the engine treats
/// all text as strings and lets the server coerce types. Dropdown state tracks option
/// **ids**, never labels.
enum FieldValue: Equatable {
    case text(String)
    case selection(Set<String>)
    case bool(Bool)
}

/// A field's value in the Save payload, in the server's expected JSON shape:
/// **scalars for single values, arrays for multi-select dropdowns** (D15).
enum FormOutputValue: Equatable {
    case string(String)
    case bool(Bool)
    case array([String])

    /// A `JSONSerialization`-compatible representation, so the printed payload is
    /// real JSON with the correct scalar/array shapes.
    var jsonValue: Any {
        switch self {
        case .string(let value): return value
        case .bool(let value): return value
        case .array(let value): return value
        }
    }
}

/// One entry of the Save payload, preserving render order.
struct OutputPair: Equatable {
    let id: String
    let value: FormOutputValue
}

/// The outcome of a Save attempt.
enum SaveResult: Equatable {
    /// Validation failed; carries `id -> message` for every invalid field.
    case invalid([String: String])
    /// Validation passed; carries the ordered key-value payload.
    case valid([OutputPair])
}
