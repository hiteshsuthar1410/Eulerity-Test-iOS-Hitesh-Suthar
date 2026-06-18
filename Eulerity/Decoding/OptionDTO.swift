//
//  OptionDTO.swift
//  Eulerity
//
//  A single DROPDOWN option as sent by the server.
//

import Foundation

/// A dropdown option. `id` is the value tracked in state; `label` is what the user
/// sees. Both decode leniently (D1) — a malformed option degrades its fields to
/// `nil` rather than throwing. The factory (M2) drops options lacking a usable
/// `id`/`label`.
struct OptionDTO: Decodable, Equatable {
    let id: String?
    let label: String?

    private enum CodingKeys: String, CodingKey {
        case id, label
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenient(String.self, .id)
        label = c.lenient(String.self, .label)
    }
}
