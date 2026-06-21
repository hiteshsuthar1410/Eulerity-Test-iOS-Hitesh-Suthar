//
//  FormPalette.swift
//  Eulerity
//
//  The SwiftUI color palette for the form, and where the SDUI-vs-appearance tension
//  is resolved (D17).
//

import SwiftUI
import UIKit

extension Color {
    /// Bridges a headless `RGBAColor` into a SwiftUI sRGB `Color`.
    init(_ rgba: RGBAColor) {
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}

/// The form's resolved SwiftUI colors.
///
/// **The SDUI-vs-appearance tradeoff lives here (D17):** server-provided channels are
/// used **verbatim** (the backend owns the branded surface, and a coherent server
/// palette is legible in either system appearance); channels the server *omitted*
/// fall back to **adaptive** system colors so a theme-less form follows Light/Dark.
/// Distributed to components via `@Environment(\.formPalette)`.
struct FormPalette {
    let background: Color
    let text: Color
    let border: Color
    let error: Color

    /// System-adaptive defaults (follow Light/Dark).
    static let adaptive = FormPalette(
        background: Color(uiColor: .systemBackground),
        text: Color(uiColor: .label),
        border: Color(uiColor: .separator),
        error: Color(uiColor: .systemRed)
    )

    init(background: Color, text: Color, border: Color, error: Color) {
        self.background = background
        self.text = text
        self.border = border
        self.error = error
    }

    /// Maps a validated theme to colors, substituting the adaptive fallback for any
    /// channel the server didn't provide.
    init(_ theme: ResolvedTheme) {
        background = theme.background.map { Color($0) } ?? Self.adaptive.background
        text = theme.text.map { Color($0) } ?? Self.adaptive.text
        border = theme.border.map { Color($0) } ?? Self.adaptive.border
        error = theme.error.map { Color($0) } ?? Self.adaptive.error
    }
}

private struct FormPaletteKey: EnvironmentKey {
    static let defaultValue = FormPalette.adaptive
}

extension EnvironmentValues {
    var formPalette: FormPalette {
        get { self[FormPaletteKey.self] }
        set { self[FormPaletteKey.self] = newValue }
    }
}
