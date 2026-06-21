//
//  Typography.swift
//  Eulerity
//
//  The single font engine (D16). All fonts the form engine uses live here.
//

import SwiftUI

/// The one place fonts are defined. Views reference these *semantic roles*
/// (`Typography.fieldLabel`) instead of raw `.system(size:)`, so a global font change
/// — heavier labels, a custom family — is a one-file edit.
///
/// Every role is built from a Dynamic Type text style, so the engine scales with the
/// user's accessibility text size (HIG) for free.
enum Typography {
    /// The form's main heading.
    static let formTitle = Font.system(.largeTitle, design: .default).weight(.bold)
    /// A grouping / section heading.
    static let sectionTitle = Font.system(.title3, design: .default).weight(.semibold)
    /// A field's label.
    static let fieldLabel = Font.system(.subheadline, design: .default).weight(.semibold)
    /// Text the user types / selects.
    static let input = Font.system(.body, design: .default)
    /// Secondary helper text under a field.
    static let supporting = Font.system(.footnote, design: .default)
    /// Validation error text.
    static let error = Font.system(.footnote, design: .default).weight(.medium)
    /// The live character counter (monospaced so digits don't shift width).
    static let counter = Font.system(.caption, design: .monospaced)
    /// Primary action button (Save).
    static let button = Font.system(.headline, design: .default)
}
