//
//  FieldDTO.swift
//  Eulerity
//
//  The permissive wire model for a single field.
//

import Foundation

/// A single form field exactly as the server sends it.
///
/// Decoding is lenient *per property* (D1): each optional value is decoded with its
/// own leniency, so a malformed property (e.g. `order` sent as a string) degrades to
/// `nil` instead of throwing and dropping the whole field. A field is only lost when
/// the array element isn't even a JSON object, which the `FailableDecodable` net
/// catches one level up.
///
/// Every semantic rule — required `id`, unknown `type`, empty `options`, duplicate
/// `id` (D6), bad hex, conflicting constraints — is enforced later in `FieldFactory`
/// (M2), never here. This file does mechanics only.
struct FieldDTO: Decodable, Equatable {
    let id: String?
    let order: Int?
    let type: FieldType?
    let subtype: FieldSubtype?
    let label: String?
    let placeholder: String?
    let supportingText: String?
    let maxLength: Int?
    let errorMessage: String?
    let regex: String?
    let required: Bool?
    let allowMultiple: Bool?
    let defaultValues: [String]?
    let options: [OptionDTO]?
    let metadata: [String: String]?
    let clickableTextColor: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case order
        case type
        case subtype
        case label
        case placeholder
        case supportingText = "supporting_text"
        case maxLength = "max_length"
        case errorMessage = "error_message"
        case regex
        case required
        case allowMultiple = "allow_multiple"
        case defaultValues = "default_values"
        case options
        case metadata
        case clickableTextColor = "clickable_text_color"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = c.lenient(String.self, .id)
        order = c.lenient(Int.self, .order)
        type = c.lenient(String.self, .type).map(FieldType.init(raw:))
        subtype = c.lenient(String.self, .subtype).map(FieldSubtype.init(raw:))
        label = c.lenient(String.self, .label)
        placeholder = c.lenient(String.self, .placeholder)
        supportingText = c.lenient(String.self, .supportingText)
        maxLength = c.lenient(Int.self, .maxLength)
        errorMessage = c.lenient(String.self, .errorMessage)
        regex = c.lenient(String.self, .regex)
        required = c.lenient(Bool.self, .required)
        allowMultiple = c.lenient(Bool.self, .allowMultiple)
        defaultValues = c.lenient([String].self, .defaultValues)

        // Options decode element-by-element through Net 1: a malformed option
        // degrades to nil and is dropped while the rest survive.
        if let lossy = c.lenient([FailableDecodable<OptionDTO>].self, .options) {
            options = lossy.compactMap(\.value)
        } else {
            options = nil
        }

        metadata = c.lenient([String: String].self, .metadata)
        clickableTextColor = c.lenient(String.self, .clickableTextColor)
    }
}
