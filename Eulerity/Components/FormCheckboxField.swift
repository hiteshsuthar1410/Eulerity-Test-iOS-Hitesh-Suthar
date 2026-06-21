//
//  FormCheckboxField.swift
//  Eulerity
//
//  A boolean CHECKBOX field. M5 renders a plain label; M6 swaps in the rich-text
//  (tappable metadata) label without touching this layout.
//

import SwiftUI
import UIKit

/// Renders a `CHECKBOX`: a tappable box plus a label beside it (so `FieldContainer`
/// suppresses its top label, D21). Only the box toggles state — the label is a
/// separate, swappable subview so M6 can make metadata substrings tappable links
/// without the row-tap stealing those taps.
@MainActor
struct FormCheckboxField: View {
    @ObservedObject var viewModel: FormViewModel
    @Environment(\.formPalette) private var palette
    let field: RenderableField

    private var isOn: Bool {
        if case .bool(let value)? = viewModel.values[field.id] { return value }
        return false
    }

    var body: some View {
        FieldContainer(field: field, error: viewModel.errors[field.id], showsLabel: false) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Button {
                    viewModel.setBool(!isOn, for: field.id)
                } label: {
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundColor(isOn ? palette.text : palette.border)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(field.label ?? "Checkbox")
                .accessibilityValue(isOn ? "Checked" : "Unchecked")

                label
            }
        }
    }

    private var checkboxModel: RenderableField.Checkbox? {
        if case .checkbox(let model) = field.kind { return model }
        return nil
    }

    /// `clickable_text_color` verbatim when given, else the adaptive system link color
    /// (consistent with D17).
    private var linkColor: Color {
        checkboxModel?.clickableColor.map { Color($0) } ?? Color(uiColor: .link)
    }

    /// Rich-text label: metadata substrings become tappable links to Safari (M6).
    private var label: some View {
        RichTextLabel(
            label: field.label ?? "",
            links: checkboxModel?.metadata ?? [],
            linkColor: linkColor,
            textColor: palette.text,
            required: field.isRequired,
            requiredColor: palette.error
        )
    }
}

// MARK: - Previews

private let checkboxPreviewJSON = """
{ "fields": [
    { "id": "legal", "type": "CHECKBOX", "label": "I agree to the Terms of Service.",
      "required": true },
    { "id": "promo", "type": "CHECKBOX", "label": "Send me promotional offers." }
] }
"""

private struct FormCheckboxFieldPreview: View {
    @StateObject var viewModel: FormViewModel = {
        let vm = FormViewModel()
        if case .success(let schema) = FormParser.parse(Data(checkboxPreviewJSON.utf8)) { vm.apply(schema) }
        return vm
    }()
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(viewModel.fields) { field in
                FormCheckboxField(viewModel: viewModel, field: field)
            }
        }
        .padding()
        .environment(\.formPalette, .adaptive)
    }
}

#Preview("Light") { FormCheckboxFieldPreview() }
#Preview("Dark") { FormCheckboxFieldPreview().preferredColorScheme(.dark) }
