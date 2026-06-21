//
//  FormDropdownField.swift
//  Eulerity
//
//  A DROPDOWN field: single-select via a Menu, multi-select via a sheet (D20).
//  Always shows option labels while tracking option ids in state.
//

import SwiftUI

/// Renders a `DROPDOWN`. Single-select uses an HIG pull-down `Menu`; multi-select opens
/// a checkmark sheet (D20). The collapsed row shows the selected **labels** (or a
/// placeholder), while state tracks the option **ids**.
@MainActor
struct FormDropdownField: View {
    @ObservedObject var viewModel: FormViewModel
    @Environment(\.formPalette) private var palette
    let field: RenderableField
    @State private var isPresentingSheet = false

    private var model: RenderableField.Dropdown? {
        if case .dropdown(let model) = field.kind { return model }
        return nil
    }

    private var selectedIDs: Set<String> {
        if case .selection(let ids)? = viewModel.values[field.id] { return ids }
        return []
    }

    var body: some View {
        FieldContainer(field: field, error: viewModel.errors[field.id]) {
            if let model {
                if model.allowMultiple {
                    Button { isPresentingSheet = true } label: { row(model) }
                        .buttonStyle(.plain)
                } else {
                    singleSelectMenu(model)
                }
            }
        }
        .sheet(isPresented: $isPresentingSheet) {
            if let model {
                MultiSelectSheet(field: field, model: model, viewModel: viewModel)
            }
        }
    }

    private func singleSelectMenu(_ model: RenderableField.Dropdown) -> some View {
        Menu {
            ForEach(model.options) { option in
                Button {
                    viewModel.setSingleSelection(option.id, for: field.id)
                } label: {
                    if selectedIDs.contains(option.id) {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            row(model)
        }
    }

    private func row(_ model: RenderableField.Dropdown) -> some View {
        let labels = model.options.filter { selectedIDs.contains($0.id) }.map(\.label)
        let isEmpty = labels.isEmpty
        return HStack {
            Text(isEmpty ? "Select…" : labels.joined(separator: ", "))
                .font(Typography.input)
                .foregroundColor(isEmpty ? palette.text.opacity(0.5) : palette.text)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.footnote)
                .foregroundColor(palette.border)
        }
        .padding(10)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: 1))
        .contentShape(Rectangle())
    }

    private var borderColor: Color {
        viewModel.errors[field.id] != nil ? palette.error : palette.border
    }
}

/// Multi-select picker. System-styled (it's a modal, so it stays adaptive); toggling
/// updates the view model live.
@MainActor
private struct MultiSelectSheet: View {
    let field: RenderableField
    let model: RenderableField.Dropdown
    @ObservedObject var viewModel: FormViewModel
    @Environment(\.dismiss) private var dismiss

    private func isSelected(_ id: String) -> Bool {
        if case .selection(let ids)? = viewModel.values[field.id] { return ids.contains(id) }
        return false
    }

    var body: some View {
        NavigationStack {
            List(model.options) { option in
                Button {
                    viewModel.toggleSelection(option.id, for: field.id)
                } label: {
                    HStack {
                        Text(option.label)
                        Spacer()
                        if isSelected(option.id) {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle(field.label ?? "Select")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Previews

private let dropdownPreviewJSON = """
{ "fields": [
    { "id": "single", "type": "DROPDOWN", "label": "Primary Network",
      "options": [ { "id": "g", "label": "Google Search" }, { "id": "m", "label": "Meta Platforms" } ] },
    { "id": "multi", "type": "DROPDOWN", "label": "Ad Networks", "allow_multiple": true,
      "default_values": ["m"],
      "options": [ { "id": "g", "label": "Google Search" }, { "id": "m", "label": "Meta Platforms" },
                   { "id": "t", "label": "TikTok Ads" } ] }
] }
"""

private struct FormDropdownFieldPreview: View {
    @StateObject var viewModel: FormViewModel = {
        let vm = FormViewModel()
        if case .success(let schema) = FormParser.parse(Data(dropdownPreviewJSON.utf8)) { vm.apply(schema) }
        return vm
    }()
    var body: some View {
        VStack(spacing: 24) {
            ForEach(viewModel.fields) { field in
                FormDropdownField(viewModel: viewModel, field: field)
            }
        }
        .padding()
        .environment(\.formPalette, .adaptive)
    }
}

#Preview("Light") { FormDropdownFieldPreview() }
#Preview("Dark") { FormDropdownFieldPreview().preferredColorScheme(.dark) }
