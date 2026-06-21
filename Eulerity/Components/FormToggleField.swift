//
//  FormToggleField.swift
//  Eulerity
//
//  A boolean TOGGLE field.
//

import SwiftUI

/// Renders a `TOGGLE`. The label sits beside the switch (so `FieldContainer` suppresses
/// its top label, D21); the footer (error/supporting) still comes from the container.
/// The control is tinted with `palette.text` — the schema has no accent channel, so the
/// strongest theme color signals the on-state (D21).
@MainActor
struct FormToggleField: View {
    @ObservedObject var viewModel: FormViewModel
    @Environment(\.formPalette) private var palette
    let field: RenderableField

    var body: some View {
        FieldContainer(field: field, error: viewModel.errors[field.id], showsLabel: false) {
            Toggle(isOn: viewModel.boolBinding(for: field.id)) {
                inlineLabel(field, palette: palette)
            }
            .tint(palette.text)
        }
    }
}

/// Shared inline label (text + required marker) for toggle/checkbox.
@MainActor
func inlineLabel(_ field: RenderableField, palette: FormPalette) -> Text {
    Text(field.label ?? "").foregroundColor(palette.text)
        + (field.isRequired ? Text(" *").foregroundColor(palette.error) : Text(""))
}

// MARK: - Previews

private let togglePreviewJSON = """
{ "fields": [
    { "id": "notify", "type": "TOGGLE", "label": "Send me email updates" },
    { "id": "terms", "type": "TOGGLE", "label": "Enable advanced mode", "required": true,
      "supporting_text": "Unlocks experimental options." }
] }
"""

private struct FormToggleFieldPreview: View {
    @StateObject var viewModel: FormViewModel = {
        let vm = FormViewModel()
        if case .success(let schema) = FormParser.parse(Data(togglePreviewJSON.utf8)) { vm.apply(schema) }
        return vm
    }()
    var body: some View {
        VStack(spacing: 24) {
            ForEach(viewModel.fields) { field in
                FormToggleField(viewModel: viewModel, field: field)
            }
        }
        .padding()
        .environment(\.formPalette, .adaptive)
    }
}

#Preview("Light") { FormToggleFieldPreview() }
#Preview("Dark") { FormToggleFieldPreview().preferredColorScheme(.dark) }
