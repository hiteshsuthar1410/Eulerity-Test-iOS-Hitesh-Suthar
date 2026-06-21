//
//  RenderableField.swift
//  Eulerity
//
//  The trusted domain model the ViewModel and Views consume. By the time a value
//  of this type exists, every invariant below is guaranteed by FieldFactory:
//  non-empty unique id, a known kind, dropdowns with at least one option, no
//  non-positive max lengths, default selections that reference real options.
//

import Foundation

/// A validated, renderable field. The common header is uniform across kinds (so the
/// ViewModel can key state and sort without switching); kind-specific data lives in
/// `Kind`, making illegal states unrepresentable (a toggle has no `options`; a text
/// field has no `allowMultiple`) — see DECISIONS.md → D9.
struct RenderableField: Identifiable, Equatable {
    let id: String
    let order: Int?
    /// Original decoded-array position; drives the D4 total-order tie-break.
    let sourceIndex: Int
    let label: String?
    let isRequired: Bool
    let supportingText: String?
    let errorMessage: String?
    let kind: Kind

    enum Kind: Equatable {
        case text(Text)
        case dropdown(Dropdown)
        case toggle(Toggle)
        case checkbox(Checkbox)
    }

    /// A text input. `subtype` is never `.unknown` (degraded to `.plain` at mapping);
    /// `maxLength` is either `nil` (no limit) or a positive value.
    struct Text: Equatable {
        let subtype: FieldSubtype
        let placeholder: String?
        let maxLength: Int?
        let regex: String?
    }

    /// A single- or multi-select dropdown. `options` is guaranteed non-empty;
    /// `defaultSelection` contains only ids that exist in `options`.
    struct Dropdown: Equatable {
        let options: [Option]
        let allowMultiple: Bool
        let defaultSelection: Set<String>

        struct Option: Equatable, Identifiable {
            let id: String
            let label: String
        }
    }

    struct Toggle: Equatable {
        let defaultOn: Bool
    }

    /// A checkbox with optional rich-text metadata links (tappable substrings of the
    /// label → URL, rendered in M5). `clickableColor` is `nil` when absent/malformed,
    /// in which case M5 falls back to a default link color.
    struct Checkbox: Equatable {
        let defaultOn: Bool
        let metadata: [MetadataLink]
        let clickableColor: RGBAColor?

        struct MetadataLink: Equatable {
            let text: String
            let urlString: String
        }
    }
}
