//
//  FormTextField.swift
//  Eulerity
//
//  Text input for all five subtypes (PLAIN, MULTILINE, NUMBER, URI, SECURE).
//

import SwiftUI
import UIKit

/// Renders a `TEXT` field. One component switches on subtype to pick the right
/// control + keyboard. Binds through the view model (so `max_length` truncation and
/// error-clear-on-edit apply, D19) and reports its length to `FieldContainer` for the
/// live counter.
@MainActor
struct FormTextField: View {
    @ObservedObject var viewModel: FormViewModel
    @Environment(\.formPalette) private var palette
    let field: RenderableField

    private var model: RenderableField.Text? {
        if case .text(let model) = field.kind { return model }
        return nil
    }

    var body: some View {
        FieldContainer(field: field,
                       error: viewModel.errors[field.id],
                       characterCount: currentCount) {
            input
        }
    }

    /// Only report a count when there's a limit to show it against.
    private var currentCount: Int? {
        guard model?.maxLength != nil else { return nil }
        if case .text(let value)? = viewModel.values[field.id] { return value.count }
        return 0
    }

    @ViewBuilder
    private var input: some View {
        let text = viewModel.textBinding(for: field.id)
        let subtype = model?.subtype ?? .plain

        Group {
            switch subtype {
            case .secure:
                SecureField(placeholder, text: text)
            case .multiline:
                TextField(placeholder, text: text, axis: .vertical)
                    .lineLimit(3...6)
            default:
                TextField(placeholder, text: text)
                    .keyboardType(keyboardType(for: subtype))
                    .textInputAutocapitalization(subtype == .uri ? .never : .sentences)
                    .autocorrectionDisabled(subtype == .uri)
            }
        }
        .font(Typography.input)
        .foregroundColor(palette.text)
        .padding(10)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: 1))
        .accessibilityIdentifier(field.id)
    }

    private var placeholder: String { model?.placeholder ?? "" }

    private var borderColor: Color {
        viewModel.errors[field.id] != nil ? palette.error : palette.border
    }

    private func keyboardType(for subtype: FieldSubtype) -> UIKeyboardType {
        switch subtype {
        case .number: return .decimalPad   // allows "50.00" — validated as Double (D15)
        case .uri: return .URL
        default: return .default
        }
    }
}

// MARK: - Previews

@MainActor
private func previewViewModel(_ json: String) -> FormViewModel {
    let viewModel = FormViewModel()
    if case .success(let schema) = FormParser.parse(Data(json.utf8)) {
        viewModel.apply(schema)
    }
    return viewModel
}

private let textPreviewJSON = """
{ "fields": [
    { "id": "name", "type": "TEXT", "subtype": "PLAIN", "label": "Campaign Name",
      "placeholder": "e.g., Summer Sale", "max_length": 30, "required": true },
    { "id": "budget", "type": "TEXT", "subtype": "NUMBER", "label": "Daily Budget ($)",
      "placeholder": "0.00", "required": true },
    { "id": "site", "type": "TEXT", "subtype": "URI", "label": "Landing Page" },
    { "id": "secret", "type": "TEXT", "subtype": "SECURE", "label": "API Key" },
    { "id": "notes", "type": "TEXT", "subtype": "MULTILINE", "label": "Notes",
      "supporting_text": "Optional." }
] }
"""

private struct FormTextFieldPreview: View {
    @StateObject var viewModel = previewViewModel(textPreviewJSON)
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(viewModel.fields) { field in
                    FormTextField(viewModel: viewModel, field: field)
                }
            }
            .padding()
        }
        .environment(\.formPalette, .adaptive)
    }
}

#Preview("Light") { FormTextFieldPreview() }
#Preview("Dark") { FormTextFieldPreview().preferredColorScheme(.dark) }
