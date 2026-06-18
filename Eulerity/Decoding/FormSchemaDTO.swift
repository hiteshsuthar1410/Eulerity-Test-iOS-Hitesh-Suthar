//
//  FormSchemaDTO.swift
//  Eulerity
//
//  The decoded form envelope.
//

import Foundation

/// The form envelope. Everything is optional/lenient so a sparse or partial server
/// payload still produces a usable schema:
/// - missing `theme` → `nil` (default palette applied in M2/M4)
/// - missing `fields` → empty array (renders title + empty state, never crashes)
///
/// `fields` decodes through `FailableDecodable` (Net 1): array elements that aren't
/// decodable objects are dropped, and **source order is preserved** so the M2 sort
/// can assign `sourceIndex` for the total-order tie-break (D4).
struct FormSchemaDTO: Decodable, Equatable {
    let formTitle: String?
    let theme: ThemeDTO?
    let fields: [FieldDTO]

    private enum CodingKeys: String, CodingKey {
        case formTitle = "form_title"
        case theme
        case fields
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        formTitle = c.lenient(String.self, .formTitle)
        theme = c.lenient(ThemeDTO.self, .theme)

        if let lossy = c.lenient([FailableDecodable<FieldDTO>].self, .fields) {
            fields = lossy.compactMap(\.value)
        } else {
            fields = []
        }
    }
}
