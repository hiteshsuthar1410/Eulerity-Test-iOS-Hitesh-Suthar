//
//  FormParser.swift
//  Eulerity
//
//  Turns raw bytes into a FormSchemaDTO. Isolated from loading so it can be
//  unit-tested directly with handcrafted JSON Data — no bundle or network.
//

import Foundation

/// Decodes raw form bytes into a `FormSchemaDTO`.
///
/// The two resilience nets live *inside* decoding (per-element failable decode +
/// unknown-tolerant enums), so the only way `parse` fails outright is genuinely
/// un-decodable input (non-JSON, or a root that isn't an object). That surfaces as
/// `.failure`, never a crash. A well-formed-but-garbage-content payload still
/// succeeds here and is cleaned up downstream by `FieldFactory` (M2).
enum FormParser {
    enum ParseError: Error, Equatable {
        /// The bytes are not a decodable form object (non-JSON or wrong root shape).
        case notDecodable(reason: String)
    }

    static func parse(_ data: Data) -> Result<FormSchemaDTO, ParseError> {
        do {
            let schema = try JSONDecoder().decode(FormSchemaDTO.self, from: data)
            return .success(schema)
        } catch {
            return .failure(.notDecodable(reason: String(describing: error)))
        }
    }
}
