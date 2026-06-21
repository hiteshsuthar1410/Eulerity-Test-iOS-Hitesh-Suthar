//
//  RichTextLabel.swift
//  Eulerity
//
//  Renders a label with metadata substrings as tappable links (M6). The builder is
//  pure (testable); the View is a thin wrapper around a single Text.
//

import SwiftUI

/// Pure builder for the rich-text label. Extracted from the View so the linking logic
/// (range matching, URL safety, color, overlap handling) is unit-testable (D22).
enum RichText {

    /// Builds an `AttributedString`: the whole label in `textColor`, each metadata
    /// substring turned into an `http(s)` link styled in `linkColor` and underlined,
    /// plus a trailing required `*` in `requiredColor`.
    ///
    /// Keys are applied **longest-first** and any occurrence overlapping an
    /// already-linked range is skipped, so a short key (e.g. "Terms") can't corrupt a
    /// longer link (e.g. "Terms of Service"). First occurrence per key (D22).
    static func make(label: String,
                     links: [RenderableField.Checkbox.MetadataLink],
                     linkColor: Color,
                     textColor: Color,
                     required: Bool,
                     requiredColor: Color) -> AttributedString {
        var attributed = AttributedString(label)
        attributed.foregroundColor = textColor

        var linkedRanges: [Range<AttributedString.Index>] = []
        let longestFirst = links.sorted { $0.text.count > $1.text.count }

        for link in longestFirst {
            guard !link.text.isEmpty,
                  let url = safeURL(link.urlString),
                  let range = attributed.range(of: link.text),
                  !linkedRanges.contains(where: { $0.overlaps(range) })
            else { continue }

            attributed[range].link = url
            attributed[range].foregroundColor = linkColor
            attributed[range].underlineStyle = .single
            linkedRanges.append(range)
        }

        if required {
            var marker = AttributedString(" *")
            marker.foregroundColor = requiredColor
            attributed.append(marker)
        }
        return attributed
    }

    /// Only `http`/`https` URLs become links — never a malformed string or a custom
    /// scheme like `javascript:` from a server payload (D22).
    static func safeURL(_ string: String) -> URL? {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }
}

/// A label whose metadata substrings are tappable links. Tapping a `.link` run uses
/// SwiftUI's default `OpenURLAction`, opening the URL in Safari (the brief). Renders as
/// one `Text` so links flow inline with the surrounding label.
struct RichTextLabel: View {
    let label: String
    let links: [RenderableField.Checkbox.MetadataLink]
    let linkColor: Color
    let textColor: Color
    var required: Bool = false
    var requiredColor: Color = .red

    var body: some View {
        Text(RichText.make(label: label, links: links, linkColor: linkColor,
                           textColor: textColor, required: required, requiredColor: requiredColor))
            .font(Typography.input)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - Previews

private struct RichTextLabelPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            RichTextLabel(
                label: "I agree to the Terms of Service.",
                links: [.init(text: "Terms of Service", urlString: "https://example.com/terms")],
                linkColor: Color(RGBAColor(hex: "#2563EB")!),
                textColor: .primary, required: true, requiredColor: .red)

            RichTextLabel(
                label: "Read our Privacy Policy and Terms before continuing.",
                links: [.init(text: "Privacy Policy", urlString: "https://example.com/privacy"),
                        .init(text: "Terms", urlString: "https://example.com/terms")],
                linkColor: .blue, textColor: .primary)
        }
        .padding()
    }
}

#Preview("Light") { RichTextLabelPreview() }
#Preview("Dark") { RichTextLabelPreview().preferredColorScheme(.dark) }
