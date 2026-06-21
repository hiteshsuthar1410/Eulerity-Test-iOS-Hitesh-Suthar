//
//  FieldContainer.swift
//  Eulerity
//
//  Shared chrome every field component sits in: label (+ required marker), the field
//  content, and a footer with supporting text / error and a live character counter.
//

import SwiftUI

/// Wraps a field's interactive content with consistent label/footer chrome built from
/// the `RenderableField` header (D18), so every component gets the same look for free.
/// Reads colors from `@Environment(\.formPalette)` and fonts from `Typography`.
struct FieldContainer<Content: View>: View {
    @Environment(\.formPalette) private var palette

    let field: RenderableField
    let error: String?
    /// Current character count; when non-nil and the field has a `max_length`, the
    /// live counter is shown.
    let characterCount: Int?
    let content: Content

    init(field: RenderableField,
         error: String? = nil,
         characterCount: Int? = nil,
         @ViewBuilder content: () -> Content) {
        self.field = field
        self.error = error
        self.characterCount = characterCount
        self.content = content()
    }

    private var maxLength: Int? {
        if case .text(let text) = field.kind { return text.maxLength }
        return nil
    }

    private var showsCounter: Bool { characterCount != nil && maxLength != nil }
    private var hasFooter: Bool { error != nil || field.supportingText != nil || showsCounter }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = field.label {
                labelView(label)
            }
            content
            if hasFooter { footer }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labelView(_ text: String) -> some View {
        (Text(text).foregroundColor(palette.text)
            + (field.isRequired ? Text(" *").foregroundColor(palette.error) : Text("")))
            .font(Typography.fieldLabel)
            .accessibilityLabel(field.isRequired ? "\(text), required" : text)
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let error {
                Text(error)
                    .font(Typography.error)
                    .foregroundColor(palette.error)
            } else if let supportingText = field.supportingText {
                Text(supportingText)
                    .font(Typography.supporting)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
            if showsCounter, let characterCount, let maxLength {
                Text("\(characterCount)/\(maxLength)")
                    .font(Typography.counter)
                    .monospacedDigit()
                    .foregroundColor(characterCount >= maxLength ? palette.error : .secondary)
            }
        }
    }
}

// MARK: - Previews

private extension RenderableField {
    static func previewText(label: String,
                            required: Bool = false,
                            supporting: String? = nil,
                            maxLength: Int? = nil) -> RenderableField {
        RenderableField(id: label, order: nil, sourceIndex: 0, label: label,
                        isRequired: required, supportingText: supporting, errorMessage: nil,
                        kind: .text(.init(subtype: .plain, placeholder: nil,
                                          maxLength: maxLength, regex: nil)))
    }
}

private struct FieldContainerPreview: View {
    var body: some View {
        VStack(spacing: 28) {
            FieldContainer(field: .previewText(label: "Campaign Name", required: true,
                                               supporting: "Shown in reports.", maxLength: 30),
                           characterCount: 12) {
                inputBox("Summer Sale")
            }
            FieldContainer(field: .previewText(label: "Daily Budget", required: true),
                           error: "Enter a valid number.") {
                inputBox("50abc")
            }
            FieldContainer(field: .previewText(label: "Notes")) {
                inputBox("")
            }
        }
        .padding(20)
    }

    private func inputBox(_ text: String) -> some View {
        Text(text.isEmpty ? "—" : text)
            .font(Typography.input)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(uiColor: .separator)))
    }
}

#Preview("Light") {
    FieldContainerPreview().environment(\.formPalette, .adaptive)
}

#Preview("Dark") {
    FieldContainerPreview().environment(\.formPalette, .adaptive).preferredColorScheme(.dark)
}
