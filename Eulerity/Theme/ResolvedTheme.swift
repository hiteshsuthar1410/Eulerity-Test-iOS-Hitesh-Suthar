//
//  ResolvedTheme.swift
//  Eulerity
//
//  The server theme after hex validation — as optional channels.
//

import Foundation

/// The server theme after hex validation, as **optional** channels: a channel is
/// `nil` when the server omitted it or sent malformed hex.
///
/// The fallback decision is deliberately deferred to the UI layer (`FormPalette`),
/// which substitutes adaptive system colors for nil channels so a theme-less form
/// follows Light/Dark (D17, superseding D11's fixed fallback). Headless (no SwiftUI)
/// so resolution stays unit-testable.
struct ResolvedTheme: Equatable {
    let background: RGBAColor?
    let text: RGBAColor?
    let border: RGBAColor?
    let error: RGBAColor?

    init(background: RGBAColor? = nil,
         text: RGBAColor? = nil,
         border: RGBAColor? = nil,
         error: RGBAColor? = nil) {
        self.background = background
        self.text = text
        self.border = border
        self.error = error
    }

    /// Validates each channel independently: present, well-formed hex → an `RGBAColor`;
    /// absent or malformed → `nil`. One bad channel never affects the others.
    static func resolve(_ dto: ThemeDTO?) -> ResolvedTheme {
        ResolvedTheme(
            background: dto?.backgroundColor.flatMap { RGBAColor(hex: $0) },
            text: dto?.textColor.flatMap { RGBAColor(hex: $0) },
            border: dto?.borderColor.flatMap { RGBAColor(hex: $0) },
            error: dto?.errorColor.flatMap { RGBAColor(hex: $0) }
        )
    }
}
