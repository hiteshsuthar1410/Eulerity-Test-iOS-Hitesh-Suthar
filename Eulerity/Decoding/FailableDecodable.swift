//
//  FailableDecodable.swift
//  Eulerity
//
//  Net 1 of the decoding boundary (see DECISIONS.md → D3).
//

import Foundation

/// Wraps a `Decodable` so a single malformed element in a collection degrades to
/// `nil` instead of throwing and collapsing the *entire* decode.
///
/// Each array element is decoded through its own single-value container, so the
/// `try?` here swallows only *that element's* error while the surrounding array
/// decode advances cleanly to the next element. This sidesteps the classic trap
/// where decoding `[Field].self` throws for the whole array if any one element is
/// malformed, and avoids the manual-unkeyed-container approach where a mid-stream
/// throw can leave the decode cursor unadvanced.
struct FailableDecodable<Wrapped: Decodable>: Decodable {
    let value: Wrapped?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try? container.decode(Wrapped.self)
    }
}

extension KeyedDecodingContainer {
    /// Decodes a value if the key is present *and* the value is well-typed;
    /// returns `nil` on absence **or** type mismatch instead of throwing.
    ///
    /// This is the per-property leniency from DECISIONS.md → D1: a single
    /// wrong-typed property (e.g. `order` sent as a string) degrades to `nil`
    /// rather than dropping the whole field.
    func lenient<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }
}
