//
//  ResolvedTheme.swift
//  Eulerity
//
//  The theme after validation, with every channel guaranteed present.
//

import Foundation

/// A fully-resolved palette. Built from a possibly-`nil`, possibly-partially-bad
/// `ThemeDTO` with **per-channel** fallback to defaults, so one malformed hex can
/// never break the whole theme (D11). UI-framework-free; M4 maps each channel to a
/// SwiftUI `Color`.
struct ResolvedTheme: Equatable {
    let background: RGBAColor
    let text: RGBAColor
    let border: RGBAColor
    let error: RGBAColor

    /// Light-mode defaults (mirror the sample payload's palette).
    static let `default` = ResolvedTheme(
        background: RGBAColor(hex: "#FFFFFF")!,
        text: RGBAColor(hex: "#111827")!,
        border: RGBAColor(hex: "#D1D5DB")!,
        error: RGBAColor(hex: "#B91C1C")!
    )

    /// Resolves a DTO into a complete theme. Each channel independently falls back
    /// to its default when the hex is missing or malformed.
    static func resolve(_ dto: ThemeDTO?) -> ResolvedTheme {
        func channel(_ hex: String?, _ fallback: RGBAColor) -> RGBAColor {
            guard let hex, let color = RGBAColor(hex: hex) else { return fallback }
            return color
        }
        return ResolvedTheme(
            background: channel(dto?.backgroundColor, `default`.background),
            text: channel(dto?.textColor, `default`.text),
            border: channel(dto?.borderColor, `default`.border),
            error: channel(dto?.errorColor, `default`.error)
        )
    }
}
