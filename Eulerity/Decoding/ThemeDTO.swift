//
//  ThemeDTO.swift
//  Eulerity
//
//  Raw theme palette from the server.
//

import Foundation

/// Raw theme palette. All hex strings are optional and decoded leniently; hex
/// validation and `hex → Color` resolution (with per-channel fallback) happen
/// later (M2 logic / M4 styling). A missing `theme` object yields `nil` and the
/// engine falls back to a default palette.
struct ThemeDTO: Decodable, Equatable {
    let backgroundColor: String?
    let textColor: String?
    let borderColor: String?
    let errorColor: String?

    private enum CodingKeys: String, CodingKey {
        case backgroundColor = "background_color"
        case textColor = "text_color"
        case borderColor = "border_color"
        case errorColor = "error_color"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        backgroundColor = c.lenient(String.self, .backgroundColor)
        textColor = c.lenient(String.self, .textColor)
        borderColor = c.lenient(String.self, .borderColor)
        errorColor = c.lenient(String.self, .errorColor)
    }
}
