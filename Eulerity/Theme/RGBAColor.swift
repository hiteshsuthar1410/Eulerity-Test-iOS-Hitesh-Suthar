//
//  RGBAColor.swift
//  Eulerity
//
//  A UI-framework-free color so theme resolution stays headless and testable.
//

import Foundation

/// A resolved color as channel values in `0...1`. Deliberately free of SwiftUI so
/// the theme-resolution layer can be unit-tested without a UI host; `Color+Theme`
/// (M4) wraps this into a SwiftUI `Color`.
struct RGBAColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

extension RGBAColor {
    /// Parses a hex string, returning `nil` on any malformed input so callers can
    /// fall back per-channel (theme resilience — D11). Accepts an optional leading
    /// `#` and the forms `RGB`, `RGBA`, `RRGGBB`, `RRGGBBAA` (case-insensitive).
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard !s.isEmpty, s.allSatisfy(\.isHexDigit) else { return nil }

        // Expand shorthand (RGB/RGBA) by doubling each nibble.
        let normalized: String
        switch s.count {
        case 3, 4: normalized = String(s.flatMap { [$0, $0] })
        case 6, 8: normalized = s
        default: return nil
        }

        guard let value = UInt64(normalized, radix: 16) else { return nil }

        if normalized.count == 8 {
            red   = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue  = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        } else {
            red   = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue  = Double(value & 0xFF) / 255
            alpha = 1
        }
    }
}
